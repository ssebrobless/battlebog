extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const FIXED_STEP := 1.0 / 60.0
const BREEDING_STEP := 45.01
const CLAIM_STEP := 0.2
const BLUE_SQUAD: Array[String] = ["duck", "snapping_turtle", "chorus_frog"]
const RED_SQUAD: Array[String] = ["mink", "firefly", "otter"]


class DepositLocalInput extends Node:
	var deposit_enabled := false

	func build_frame(_mouse_position: Vector2) -> Resource:
		var frame := InputFrameScript.new()
		frame.set_button(InputFrameScript.BUTTON_HABITAT_DEPOSIT, deposit_enabled)
		return frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("pvai objective participation check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	_configure_play_vs_ai(config)
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("pvai objective participation check failed to boot Arena")
		_restore_config(config, original_config)
		quit(1)
		return
	await process_frame
	await physics_frame
	await physics_frame

	var arena := current_scene
	if arena == null \
		or not arena.has_method("get_match_slot_state") \
		or not arena.has_method("get_side_boss_state"):
		failures.append("Play vs AI Arena did not expose the competitive runtime APIs")
	else:
		_prepare_manual_simulation(arena)
		_check_exact_red_roster(arena, failures)
		_run_red_owner_objective(arena, failures)
		_run_red_steal_objective(arena, failures)

	_restore_config(config, original_config)
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame

	print("pvai_objective_participation failures=%d red_roster=%s" % [
		failures.size(),
		str(RED_SQUAD)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _configure_play_vs_ai(config: Node) -> void:
	config.selected_mode = "Play vs AI"
	config.clear_draft_bans()
	config.set_selected_squad_ids(BLUE_SQUAD)
	config.set_selected_red_squad_ids(RED_SQUAD)
	config.wake_boss = false
	config.center_boss = false


func _prepare_manual_simulation(arena: Node) -> void:
	arena.set_process(false)
	arena.set_physics_process(false)
	for team in [BLUE, RED]:
		for index in TEAM_SIZE:
			var actor := _slot_actor(arena, int(team), index)
			if actor == null:
				continue
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.health = actor.max_health
			actor.hunger = 100.0
			actor.hunger_satiated = false


func _check_exact_red_roster(arena: Node, failures: Array[String]) -> void:
	var actual: Array[String] = []
	for index in TEAM_SIZE:
		var slot: Dictionary = arena.slot_registry.get_slot(RED, index)
		actual.append(String(slot.get("creature_id", "")))
		var controller: Dictionary = slot.get("controller", {})
		if String(controller.get("kind", "")) != "ai":
			failures.append("Red slot %d should boot under AI control; slot=%s" % [index, str(slot)])
	if actual != RED_SQUAD:
		failures.append("Play vs AI should boot the exact configured Red roster; expected=%s actual=%s" % [
			str(RED_SQUAD),
			str(actual)
		])


func _run_red_owner_objective(arena: Node, failures: Array[String]) -> void:
	var deposits_before := int(arena.team_stats[RED].get("deposits", 0))
	var routed_deposits := _run_ai_deposit_cycles(arena, RED, 5, failures)
	var boss_state: Dictionary = arena.get_side_boss_state(RED)
	var boss := _boss_actor(arena, "red:Boss")
	if routed_deposits != 5 \
		or int(arena.team_stats[RED].get("deposits", 0)) != deposits_before + 5 \
		or int(boss_state.get("activations", 0)) != 1 \
		or String(boss_state.get("objective_state", "")) != "active" \
		or boss == null:
		failures.append(
			(
				"five normal Red AI deposit/breed cycles should wake one Red side boss; "
				+ "routed=%d deposits=%d->%d state=%s boss=%s"
			)
			% [
				routed_deposits,
				deposits_before,
				int(arena.team_stats[RED].get("deposits", 0)),
				str(boss_state),
				str(boss)
			]
		)
		return

	boss.set_process(false)
	boss.set_physics_process(false)
	var fight_result := _drive_red_boss_combat(arena, boss)
	if int(fight_result.get("fight_orders", 0)) < 1 \
		or int(fight_result.get("damaging_inputs", 0)) < 1 \
		or float(fight_result.get("damage", 0.0)) <= 0.0:
		failures.append(
			(
				"Red director/brain/actor simulation should issue fight_boss and damage the live boss; "
				+ "result=%s orders=%s"
			)
			% [str(fight_result), str(arena.get_team_order_state(RED))]
		)

	if boss != null and is_instance_valid(boss) and boss.is_alive():
		var source := _slot_actor(arena, RED, 0)
		boss.take_damage(float(boss.get("health")) + 1.0, RED, source)
	var claimable: Dictionary = arena.get_side_boss_state(RED)
	if String(claimable.get("objective_state", "")) != "claimable":
		failures.append("public boss damage should enter the normal Red claim window; state=%s" % str(claimable))
		return

	var owner_zone := _boss_zone(arena, "red")
	var claimant := _place_red_presence(arena, owner_zone)
	var claim_order := _refresh_order_and_route(arena, claimant)
	var claimed := _drive_animal_zone_ticks(arena, RED)
	if String(claim_order.get("role", "")) != "claim" \
		or String(claimed.get("objective_state", "")) != "claimed" \
		or int(claimed.get("claimed_team", -1)) != RED:
		failures.append(
			(
				"Red presence should receive a normal claim order and resolve through animal-zone ticks; "
				+ "order=%s state=%s"
			)
			% [str(claim_order), str(claimed)]
		)


func _run_red_steal_objective(arena: Node, failures: Array[String]) -> void:
	var fake_local := DepositLocalInput.new()
	arena.local_input = fake_local
	var deposits_before := int(arena.team_stats[BLUE].get("deposits", 0))
	var routed_deposits := _run_local_deposit_cycles(arena, fake_local, 5, failures)
	var boss_state: Dictionary = arena.get_side_boss_state(BLUE)
	var boss := _boss_actor(arena, "blue:Boss")
	if routed_deposits != 5 \
		or int(arena.team_stats[BLUE].get("deposits", 0)) != deposits_before + 5 \
		or int(boss_state.get("activations", 0)) != 1 \
		or String(boss_state.get("objective_state", "")) != "active" \
		or boss == null:
		failures.append(
			(
				"five normal routed Blue deposits should prepare the enemy-side steal scenario; "
				+ "routed=%d deposits=%d->%d state=%s boss=%s"
			)
			% [
				routed_deposits,
				deposits_before,
				int(arena.team_stats[BLUE].get("deposits", 0)),
				str(boss_state),
				str(boss)
			]
		)
		return

	boss.set_process(false)
	boss.set_physics_process(false)
	var source := _slot_actor(arena, RED, 0)
	boss.take_damage(float(boss.get("health")) + 1.0, RED, source)
	var claimable: Dictionary = arena.get_side_boss_state(BLUE)
	if String(claimable.get("objective_state", "")) != "claimable":
		failures.append("public boss damage should enter the normal Blue claim window; state=%s" % str(claimable))
		return

	var enemy_zone := _boss_zone(arena, "blue")
	var claimant := _place_red_presence(arena, enemy_zone)
	var claim_order := _refresh_order_and_route(arena, claimant)
	var stolen := _drive_animal_zone_ticks(arena, BLUE)
	if String(claim_order.get("role", "")) != "claim" \
		or String(stolen.get("objective_state", "")) != "stolen" \
		or int(stolen.get("claimed_team", -1)) != RED:
		failures.append(
			(
				"Red presence should receive a normal enemy-zone claim order and resolve as stolen; "
				+ "order=%s state=%s"
			)
			% [str(claim_order), str(stolen)]
		)


func _run_ai_deposit_cycles(
	arena: Node,
	team: int,
	cycle_count: int,
	failures: Array[String]
) -> int:
	var routed := 0
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(team)
	for cycle in cycle_count:
		var actor := _slot_actor(arena, team, cycle % TEAM_SIZE)
		if actor == null:
			failures.append("Red deposit cycle %d could not resolve its registered actor" % cycle)
			break
		_prepare_satiated_actor(arena, actor, habitat.get_center())
		arena.team_director_timer = 0.0
		arena._tick_team_directors(0.25)
		var before := int(arena.team_stats[team].get("deposits", 0))
		arena._feed_registered_inputs()
		var frame: Resource = actor.input_frame
		if frame == null \
			or not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
			or int(arena.team_stats[team].get("deposits", 0)) != before + 1:
			failures.append(
				"Red deposit cycle %d should commit through the routed BotBrain frame; frame=%s deposits=%d->%d"
				% [
					cycle,
					str(frame),
					before,
					int(arena.team_stats[team].get("deposits", 0))
				]
			)
			break
		routed += 1
		arena._tick_breeding(BREEDING_STEP)
	return routed


func _run_local_deposit_cycles(
	arena: Node,
	fake_local: DepositLocalInput,
	cycle_count: int,
	failures: Array[String]
) -> int:
	var routed := 0
	var actor := _slot_actor(arena, BLUE, 0)
	if actor == null:
		failures.append("Blue local deposit cycles could not resolve Blue slot 0")
		return routed
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(BLUE)
	for cycle in cycle_count:
		_prepare_satiated_actor(arena, actor, habitat.get_center())
		arena.habitat_deposit_feedback_timer = 0.0
		fake_local.deposit_enabled = true
		var before := int(arena.team_stats[BLUE].get("deposits", 0))
		arena._feed_registered_inputs()
		fake_local.deposit_enabled = false
		var frame: Resource = actor.input_frame
		if frame == null \
			or not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
			or int(arena.team_stats[BLUE].get("deposits", 0)) != before + 1:
			failures.append(
				"Blue deposit cycle %d should commit through the normal local-controller route; frame=%s deposits=%d->%d"
				% [
					cycle,
					str(frame),
					before,
					int(arena.team_stats[BLUE].get("deposits", 0))
				]
			)
			break
		routed += 1
		arena._tick_breeding(BREEDING_STEP)
	return routed


func _prepare_satiated_actor(arena: Node, actor: Node, point: Vector2) -> void:
	actor.global_position = point
	actor.health = actor.max_health
	actor.hunger = 100.0
	actor.hunger_satiated = true
	if arena.bot_brain.has_method("reset_actor"):
		arena.bot_brain.reset_actor(actor)


func _drive_red_boss_combat(arena: Node, boss: Node) -> Dictionary:
	var red_actors := _team_actors(arena, RED)
	var offsets := [Vector2(-52.0, 0.0), Vector2(-58.0, 20.0), Vector2(-64.0, -20.0)]
	for index in red_actors.size():
		var actor: Node = red_actors[index]
		actor.global_position = boss.global_position + offsets[index]
		actor.health = actor.max_health
		actor.hunger = 100.0
		actor.hunger_satiated = false
		actor.primary_timer = 0.0
		actor.q_timer = 0.0
		actor.e_timer = 0.0
		arena.bot_brain.reset_actor(actor)

	arena.team_director_timer = 0.0
	arena._tick_team_directors(0.25)
	arena._feed_registered_inputs()
	var fight_orders := 0
	var damaging_inputs := 0
	var orders: Dictionary = arena.get_team_order_state(RED)
	for actor in red_actors:
		var slot: Dictionary = arena.slot_registry.get_slot_for_actor(actor)
		var order: Dictionary = orders.get(String(slot.get("slot_id", "")), {})
		if String(order.get("role", "")) != "fight_boss":
			continue
		fight_orders += 1
		var frame: Resource = actor.input_frame
		if frame != null \
			and frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
			and frame.aim.distance_to(boss.global_position) <= 0.01:
			damaging_inputs += 1

	var health_before := float(boss.get("health"))
	for _step in 12:
		arena._feed_registered_inputs()
		for actor in red_actors:
			actor.tick_sim(FIXED_STEP)
			_tick_actor_projectiles(actor, FIXED_STEP)
		if not boss.is_alive():
			break
	return {
		"fight_orders": fight_orders,
		"damaging_inputs": damaging_inputs,
		"damage": health_before - float(boss.get("health")),
		"health_before": health_before,
		"health_after": float(boss.get("health"))
	}


func _tick_actor_projectiles(actor: Node, delta: float) -> void:
	var kit: Variant = actor.get("kit")
	if kit == null or not ("projectiles" in kit):
		return
	for projectile: Node in kit.projectiles.duplicate():
		if projectile != null \
			and is_instance_valid(projectile) \
			and projectile.has_method("_physics_process"):
			projectile._physics_process(delta)


func _place_red_presence(arena: Node, zone: Dictionary) -> Node:
	var center: Vector2 = zone.get("center", Vector2.ZERO)
	var red_actors := _team_actors(arena, RED)
	var blue_actors := _team_actors(arena, BLUE)
	for index in red_actors.size():
		var actor: Node = red_actors[index]
		actor.global_position = center if index == 0 else arena.get_team_spawn(RED) + Vector2(0.0, index * 80.0)
		actor.hunger = 100.0
		actor.hunger_satiated = false
		arena.bot_brain.reset_actor(actor)
	for index in blue_actors.size():
		blue_actors[index].global_position = arena.get_team_spawn(BLUE) + Vector2(0.0, index * 80.0)
	return red_actors[0] if not red_actors.is_empty() else null


func _refresh_order_and_route(arena: Node, actor: Node) -> Dictionary:
	arena.team_director_timer = 0.0
	arena._tick_team_directors(0.25)
	arena._feed_registered_inputs()
	if actor == null:
		return {}
	var slot: Dictionary = arena.slot_registry.get_slot_for_actor(actor)
	return arena.get_team_order_state(RED).get(String(slot.get("slot_id", "")), {})


func _drive_animal_zone_ticks(arena: Node, owner_team: int) -> Dictionary:
	arena.animal_zone_tick_timer = 0.0
	for _tick in 40:
		arena._tick_animal_zones(CLAIM_STEP)
		var state: Dictionary = arena.get_side_boss_state(owner_team)
		if String(state.get("objective_state", "")) in ["claimed", "stolen"]:
			return state
	return arena.get_side_boss_state(owner_team)


func _boss_actor(arena: Node, zone_id: String) -> Node:
	for encounter: Node in arena.wildlife_encounters:
		if encounter != null \
			and is_instance_valid(encounter) \
			and String(encounter.get("zone_id")) == zone_id \
			and encounter.has_method("is_boss_actor") \
			and encounter.is_boss_actor():
			return encounter
	return null


func _boss_zone(arena: Node, side: String) -> Dictionary:
	for zone: Dictionary in arena.animal_zone_states:
		if bool(zone.get("boss", false)) \
			and String(zone.get("side", "")) == side \
			and not bool(zone.get("center_boss", false)):
			return zone
	return {}


func _team_actors(arena: Node, team: int) -> Array[Node]:
	var actors: Array[Node] = []
	for index in TEAM_SIZE:
		var actor := _slot_actor(arena, team, index)
		if actor != null:
			actors.append(actor)
	return actors


func _slot_actor(arena: Node, team: int, slot_index: int) -> Node:
	var slot: Dictionary = arena.slot_registry.get_slot(team, slot_index)
	var actor: Node = slot.get("actor", null)
	return actor if actor != null and is_instance_valid(actor) else null


func _capture_config(config: Node) -> Dictionary:
	return {
		"selected_mode": String(config.selected_mode),
		"selected_creature_id": String(config.selected_creature_id),
		"selected_squad_ids": config.selected_squad_ids.duplicate(),
		"selected_red_squad_ids": config.selected_red_squad_ids.duplicate(),
		"blue_draft_bans": config.blue_draft_bans.duplicate(),
		"red_draft_bans": config.red_draft_bans.duplicate(),
		"wake_boss": bool(config.wake_boss),
		"center_boss": bool(config.center_boss)
	}


func _restore_config(config: Node, state: Dictionary) -> void:
	config.selected_mode = String(state.get("selected_mode", "1v1"))
	config.selected_creature_id = String(state.get("selected_creature_id", "snapping_turtle"))
	config.selected_squad_ids.assign(state.get("selected_squad_ids", []))
	config.selected_red_squad_ids.assign(state.get("selected_red_squad_ids", []))
	config.blue_draft_bans.assign(state.get("blue_draft_bans", []))
	config.red_draft_bans.assign(state.get("red_draft_bans", []))
	config.wake_boss = bool(state.get("wake_boss", false))
	config.center_boss = bool(state.get("center_boss", false))
