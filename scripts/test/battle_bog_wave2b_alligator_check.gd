extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["alligator", "water_snake", "kingfisher"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave2b alligator check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "alligator":
		push_error("expected alligator active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_bite_latch_release_and_whiff(arena, failures)
	_check_death_roll_water_gate(arena, failures)
	_check_ambush_and_devour(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave2b_alligator failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_bite_latch_release_and_whiff(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.apply_creature("alligator")
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT
	target.global_position = Vector2(34.0, 0.0)
	target.health = target.max_health
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	_tick_actor(arena, actor, frame, 0.016)
	var no_early_damage: bool = is_equal_approx(target.health, target.max_health)
	_tick_actor(arena, actor, frame, 0.30)
	var latched: bool = actor.latch_victim == target and target.latched_attacker == actor
	var damaged: bool = target.health < target.max_health
	var bite_gap: bool = actor.primary_timer > 1.45
	var start_position: Vector2 = target.global_position
	_tick_actor(arena, actor, frame, 0.05)
	var dragged: bool = target.global_position.distance_to(start_position) > 0.1
	var release := InputFrameScript.new()
	release.aim = target.global_position
	_tick_actor(arena, actor, release, 0.05)
	var released: bool = actor.latch_victim == null and target.latched_attacker == null

	_tick_actor(arena, actor, release, 0.50)
	actor.primary_timer = 0.0
	target.global_position = Vector2(260.0, 80.0)
	_tick_actor(arena, actor, frame, 0.016)
	_tick_actor(arena, actor, frame, 0.30)
	_tick_actor(arena, actor, frame, 0.10)
	var whiff_gap: bool = actor.primary_timer > 1.35 and actor.latch_victim == null
	var whiff_pose: bool = bool(actor.get_render_motion_state().get("off_balance_pose", false))
	if not no_early_damage or not latched or not damaged or not bite_gap or not dragged or not released or not whiff_gap or not whiff_pose:
		failures.append("Alligator bite should wait for active, capsule-latch, damage once, drag, release on real primary up, and expose whiff recovery; early=%s latched=%s damaged=%s bite_gap=%s dragged=%s released=%s whiff_gap=%s whiff_pose=%s timer=%.2f" % [
			str(no_early_damage),
			str(latched),
			str(damaged),
			str(bite_gap),
			str(dragged),
			str(released),
			str(whiff_gap),
			str(whiff_pose),
			actor.primary_timer
		])
	_tick_actor(arena, actor, release, 0.80)

func _check_death_roll_water_gate(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var victim: Node = arena.bots[0]
	victim.apply_creature("cane_toad")
	actor.release_latch("test_reset")
	actor.q_timer = 0.0
	var land_point := _zone_point(arena, TerrainMapScript.LAND)
	actor.global_position = land_point
	victim.global_position = land_point + Vector2.RIGHT * 18.0
	victim.health = victim.max_health
	actor.attach_to_victim(victim, 2.0, "Bite")
	victim.receive_latch(actor, 2.0, "Bite")
	var q_frame := InputFrameScript.new()
	q_frame.aim = victim.global_position
	q_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	q_frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(q_frame)
	actor.kit.tick(actor, 0.2)
	var blocked_on_land: bool = actor.kit.death_roll_timer == 0.0 and actor.q_timer == 0.0 and victim.health == victim.max_health

	var water_point := _water_point(arena)
	actor.kit.death_roll_timer = 0.0
	actor.release_latch("test_reset")
	actor.q_timer = 0.0
	actor.global_position = water_point
	victim.global_position = water_point + Vector2.RIGHT * 18.0
	victim.health = victim.max_health
	actor.attach_to_victim(victim, 2.0, "Bite")
	victim.receive_latch(actor, 2.0, "Bite")
	actor.set_input_frame(q_frame)
	actor.kit.tick(actor, 0.016)
	# The canonical Death Roll now owns a 0.35 s non-damaging startup.
	actor.kit.tick(actor, 1.35)
	var started_in_water: bool = actor.kit.death_roll_timer > 3.8 and actor.q_timer > 4.0
	var dealt_30: bool = victim.health <= victim.max_health - 29.0
	if not blocked_on_land or not started_in_water or not dealt_30:
		failures.append("Death Roll should be water-only and deal 30 DPS for 5s; blocked_land=%s started_water=%s dealt_30=%s health=%.2f timer=%.2f q=%.2f zone=%s" % [
			str(blocked_on_land),
			str(started_in_water),
			str(dealt_30),
			victim.health,
			actor.kit.death_roll_timer,
			actor.q_timer,
			str(victim.get_current_zone())
		])
	actor.release_latch("test_reset")
	actor.kit.death_roll_timer = 0.0

func _check_ambush_and_devour(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.health = actor.max_health * 0.25
	actor.e_timer = 0.0
	var e_frame := InputFrameScript.new()
	e_frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(e_frame)
	actor.kit.tick(actor, 0.016)
	var stealthed: bool = actor.is_stealthed()
	var slowed: bool = actor.get_modifier_value("move_speed_mult", 1.0) < 0.75
	var ambush_state: Dictionary = actor.get_render_motion_state()
	var ambush_low: bool = bool(ambush_state.get("ambush_pose", false)) and not bool(ambush_state.get("high_walk_pose", false))
	var attack := InputFrameScript.new()
	attack.aim = actor.global_position + Vector2.RIGHT * 100.0
	attack.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.primary_timer = 0.0
	actor.set_input_frame(attack)
	actor.kit.tick(actor, 0.016)
	var broke: bool = not actor.is_stealthed() and actor.get_modifier_value("move_speed_mult", 1.0) >= 0.99 and actor.e_timer > 8.5
	actor.global_position = _zone_point(arena, TerrainMapScript.LAND)
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * 80.0
	var high_walk_state: Dictionary = actor.get_render_motion_state()
	var high_walk: bool = bool(high_walk_state.get("high_walk_pose", false)) \
		and not bool(high_walk_state.get("ambush_pose", false)) \
		and not bool(high_walk_state.get("alligator_water_cruise_pose", false)) \
		and not bool(high_walk_state.get("water_snake_land_slither_pose", false)) \
		and not bool(high_walk_state.get("turtle_plod_pose", false))

	var victim: Node = arena.bots[1]
	victim.apply_creature("mink")
	victim.health = victim.max_health
	actor.health = actor.max_health * 0.25
	var before_devour: float = actor.health
	var expected_devour_heal: float = victim.max_health * 0.50
	actor.on_kill(victim)
	var devoured: bool = actor.health >= before_devour + expected_devour_heal - 0.001
	if not stealthed or not slowed or not ambush_low or not broke or not high_walk or not devoured:
		failures.append("Ambush should stealth+slow into low posture, then break to distinct high-walk on attack; Devour should heal 50%% victim max HP; stealth=%s slowed=%s ambush_low=%s broke=%s high_walk=%s devoured=%s health=%.2f e=%.2f speed=%.2f states=%s/%s/%s" % [
			str(stealthed),
			str(slowed),
			str(ambush_low),
			str(broke),
			str(high_walk),
			str(devoured),
			actor.health,
			actor.e_timer,
			actor.get_modifier_value("move_speed_mult", 1.0),
			str(ambush_state),
			str(high_walk_state),
			str(actor.get_render_motion_state())
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("alligator")
	actor.e_timer = 0.0
	var far_frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, far_frame, actor.body_radius * 8.0)
	var ambushes: bool = far_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E)

	var victim: Node = arena.player
	victim.global_position = _water_point(arena)
	actor.global_position = victim.global_position + Vector2.LEFT * 18.0
	actor.attach_to_victim(victim, 2.0, "Bite")
	victim.receive_latch(actor, 2.0, "Bite")
	actor.q_timer = 0.0
	var latch_frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, victim, latch_frame, actor.body_radius * 2.0)
	var rolls: bool = latch_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) and latch_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
	actor.release_latch("test_reset")
	if not ambushes or not rolls:
		failures.append("alligator bot should ambush before contact and hold/roll latched water prey; ambushes=%s rolls=%s buttons=%d/%d" % [
			str(ambushes),
			str(rolls),
			far_frame.buttons,
			latch_frame.buttons
		])

func _water_point(arena: Node) -> Vector2:
	return _zone_point(arena, TerrainMapScript.WATER)

func _zone_point(arena: Node, zone: String) -> Vector2:
	var rects: Array = arena.terrain_map.get_rects(zone)
	for rect: Rect2 in rects:
		for x_step in 5:
			for y_step in 5:
				var point := Vector2(
					lerpf(rect.position.x + 16.0, rect.end.x - 16.0, float(x_step) / 4.0),
					lerpf(rect.position.y + 16.0, rect.end.y - 16.0, float(y_step) / 4.0)
				)
				if String(arena.terrain_map.get_zone_at(point)) == zone:
					return point
	return Vector2.ZERO

func _tick_actor(arena: Node, actor: Node, frame: Resource, delta: float) -> void:
	arena.simulation_tick += 1
	actor.set_input_frame(frame)
	actor.tick_sim(delta)
