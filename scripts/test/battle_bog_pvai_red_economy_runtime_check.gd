extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const FoodSourceScript := preload("res://scripts/game/food_source.gd")
const RED := 1
const STEP_SEC := 0.05
const NATURAL_LOOP_TIMEOUT_SEC := 24.0
const MATCH_LOG_DIR := "user://battle_bog_match_logs"
const RED_ROSTER: Array[String] = ["mink", "beaver", "firefly"]
const EXPECTED_FOOD_KIND := {
	"red:0": FoodSourceScript.KIND_CRITTER,
	"red:1": FoodSourceScript.KIND_PLANT,
	"red:2": FoodSourceScript.KIND_PLANT
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("PvAI Red economy runtime check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	var existing_logs := _match_log_files()
	_configure_match(config)

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("failed to boot Play vs AI Arena: error=%d" % error)
	else:
		await process_frame
		await physics_frame
		await physics_frame
		await _check_natural_red_economy(current_scene, failures)

	_restore_config(config, original_config)
	_remove_new_match_logs(existing_logs)
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame

	print("pvai_red_economy_runtime failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _configure_match(config: Node) -> void:
	config.selected_mode = "1v1"
	config.clear_draft_bans()
	config.set_selected_squad_ids(["snapping_turtle", "chorus_frog", "otter"])
	config.set_selected_red_squad_ids(RED_ROSTER)
	config.wake_boss = false
	config.center_boss = false


func _check_natural_red_economy(arena: Node, failures: Array[String]) -> void:
	if arena == null \
		or not arena.has_method("get_economy_event_state") \
		or not arena.has_method("get_match_slot_state"):
		failures.append("booted Arena does not expose the PvAI economy inspection APIs")
		return

	arena.set_physics_process(false)
	_disable_automatic_gameplay(arena)
	var actors := _red_actors_by_slot(arena)
	if actors.size() != RED_ROSTER.size():
		failures.append("expected three registered Red actors, got %s" % str(actors.keys()))
		return
	for index in RED_ROSTER.size():
		var slot_id := "red:%d" % index
		var actor: Node = actors.get(slot_id, null)
		if actor == null or String(actor.get("creature_id")) != RED_ROSTER[index]:
			failures.append(
				"exact Red roster mismatch at %s: expected=%s actor=%s"
				% [slot_id, RED_ROSTER[index], str(actor)]
			)
			return

	_clear_food(arena)
	var habitat: Rect2 = arena.get_team_habitat_rect(RED)
	var outside_x := habitat.position.x - 58.0
	var food_x := habitat.position.x - 30.0
	var lanes := {
		"red:0": habitat.get_center().y - 230.0,
		"red:1": habitat.get_center().y,
		"red:2": habitat.get_center().y + 230.0
	}
	for slot_id in actors:
		var actor: Node = actors[slot_id]
		actor.global_position = Vector2(outside_x, float(lanes[slot_id]))
		actor.health = actor.max_health
		actor.hunger = 70.0
		actor.hunger_satiated = false
		if arena.bot_brain.has_method("reset_actor"):
			arena.bot_brain.reset_actor(actor)

	_add_food(arena, FoodSourceScript.KIND_CRITTER, Vector2(food_x, float(lanes["red:0"])), 18.0)
	_add_food(arena, FoodSourceScript.KIND_CRITTER, Vector2(food_x + 24.0, float(lanes["red:0"])), 18.0)
	_add_food(arena, FoodSourceScript.KIND_PLANT, Vector2(food_x, float(lanes["red:1"])), 35.0)
	_add_food(arena, FoodSourceScript.KIND_PLANT, Vector2(food_x, float(lanes["red:2"])), 35.0)

	var initial_deposits := int(arena.team_stats[RED].get("deposits", 0))
	var initial_breeds := int(arena.team_stats[RED].get("breeds_completed", 0))
	var initial_cues: int = arena.stock_manager.get_breeding_cues(RED).size()
	var initial_meter := int(arena.get_side_boss_state(RED).get("meter", -1))
	var food_seen: Dictionary = {}
	var satiated_outside: Dictionary = {}
	var returned_home: Dictionary = {}
	var deposit_event: Dictionary = {}
	var deposit_actor_hunger := -1.0
	var deposit_actor_satiated := true
	var elapsed := 0.0

	while elapsed < NATURAL_LOOP_TIMEOUT_SEC:
		arena._physics_process(STEP_SEC)
		for slot_id in actors:
			var actor: Node = actors[slot_id]
			if actor != null and is_instance_valid(actor) and actor.is_alive():
				actor.tick_sim(STEP_SEC)
		_tick_firefly_projectiles(arena, STEP_SEC)
		elapsed += STEP_SEC

		for event: Dictionary in arena.get_economy_event_state():
			var slot_id := String(event.get("slot_id", ""))
			if String(event.get("event", "")) == "food_consumed" and actors.has(slot_id):
				food_seen[slot_id] = event.duplicate(true)
			elif String(event.get("event", "")) == "deposit_committed" \
				and slot_id.begins_with("red:") \
				and deposit_event.is_empty():
				deposit_event = event.duplicate(true)
				var deposited_actor: Node = actors.get(slot_id, null)
				if deposited_actor != null:
					deposit_actor_hunger = float(deposited_actor.hunger)
					deposit_actor_satiated = bool(deposited_actor.hunger_satiated)

		for slot_id in actors:
			var actor: Node = actors[slot_id]
			if actor.is_satiated() and not habitat.grow(16.0).has_point(actor.global_position):
				satiated_outside[slot_id] = true
			if satiated_outside.has(slot_id) and habitat.grow(16.0).has_point(actor.global_position):
				returned_home[slot_id] = true

		if food_seen.size() == RED_ROSTER.size() and not deposit_event.is_empty():
			break

	var natural_events: Array[Dictionary] = arena.get_economy_event_state()
	for slot_id in EXPECTED_FOOD_KIND:
		var event: Dictionary = food_seen.get(slot_id, {})
		if event.is_empty():
			failures.append(
				"%s never consumed diet-legal food through normal AI simulation; events=%s"
				% [slot_id, str(natural_events)]
			)
			continue
		var expected_kind := String(EXPECTED_FOOD_KIND[slot_id])
		if String(event.get("food_kind", "")) != expected_kind:
			failures.append(
				"%s consumed wrong food kind: expected=%s event=%s"
				% [slot_id, expected_kind, str(event)]
			)
		var hunger_after := float(event.get("hunger_after", -1.0))
		var satiated := bool(event.get("satiated", false))
		if hunger_after < 0.0 or satiated != is_equal_approx(hunger_after, 100.0):
			failures.append(
				"%s food telemetry should capture post-consumption hunger and satiation; event=%s"
				% [slot_id, str(event)]
			)

	if deposit_event.is_empty():
		failures.append(
			(
				"no Red AI completed the satiate-return-routed-deposit transaction in %.1fs; "
				+ "food=%s satiated_outside=%s returned=%s events=%s positions=%s hunger=%s"
			)
			% [
				elapsed,
				str(food_seen.keys()),
				str(satiated_outside.keys()),
				str(returned_home.keys()),
				str(natural_events),
				str(_actor_positions(actors)),
				str(_actor_hunger(actors))
			]
		)
		return

	var deposit_slot := String(deposit_event.get("slot_id", ""))
	var food_event: Dictionary = food_seen.get(deposit_slot, {})
	var causal_order_ok := not food_event.is_empty() \
		and int(food_event.get("sequence", 0)) < int(deposit_event.get("sequence", 0))
	var cue_spawned: bool = arena.stock_manager.get_breeding_cues(RED).size() == initial_cues + 1
	var deposit_routed: bool = int(arena.team_stats[RED].get("deposits", 0)) == initial_deposits + 1
	var returned_before_deposit: bool = bool(satiated_outside.get(deposit_slot, false)) \
		and bool(returned_home.get(deposit_slot, false))
	var hunger_reset: bool = absf(deposit_actor_hunger - 80.0) <= 0.1 \
		and not deposit_actor_satiated
	if not causal_order_ok or not cue_spawned or not deposit_routed \
		or not returned_before_deposit or not hunger_reset:
		failures.append(
			(
				"Red deposit transaction was incomplete: slot=%s causal=%s returned=%s routed=%s "
				+ "cue=%s hunger=%.2f satiated=%s food_event=%s deposit_event=%s"
			)
			% [
				deposit_slot,
				str(causal_order_ok),
				str(returned_before_deposit),
				str(deposit_routed),
				str(cue_spawned),
				deposit_actor_hunger,
				str(deposit_actor_satiated),
				str(food_event),
				str(deposit_event)
			]
		)
		return

	var breeding_elapsed := 0.0
	while breeding_elapsed < 46.0 and not arena.stock_manager.get_breeding_cues(RED).is_empty():
		arena._tick_breeding(0.25)
		breeding_elapsed += 0.25

	var completed_events := _events_named(arena.get_economy_event_state(), "breed_completed")
	var completed: bool = arena.stock_manager.get_breeding_cues(RED).is_empty() \
		and int(arena.team_stats[RED].get("breeds_completed", 0)) == initial_breeds + 1 \
		and int(arena.get_side_boss_state(RED).get("meter", -1)) == initial_meter + 1 \
		and not completed_events.is_empty() \
		and int(completed_events.back().get("sequence", 0)) > int(deposit_event.get("sequence", 0))
	if not completed:
		failures.append(
			(
				"normal breeding clock did not complete the Red economy transaction: "
				+ "elapsed=%.2f cues=%d breeds=%d->%d meter=%d->%d completed_events=%s"
			)
			% [
				breeding_elapsed,
				arena.stock_manager.get_breeding_cues(RED).size(),
				initial_breeds,
				int(arena.team_stats[RED].get("breeds_completed", 0)),
				initial_meter,
				int(arena.get_side_boss_state(RED).get("meter", -1)),
				str(completed_events)
			]
		)


func _disable_automatic_gameplay(arena: Node) -> void:
	for node in arena.find_children("*", "", true, false):
		if node != arena:
			node.set_physics_process(false)


func _red_actors_by_slot(arena: Node) -> Dictionary:
	var out: Dictionary = {}
	var state: Dictionary = arena.get_match_slot_state()
	for slot: Dictionary in state.get("red", []):
		var slot_id := String(slot.get("slot_id", ""))
		var actor: Node = arena.get_actor_for_slot_id(slot_id)
		if actor != null and is_instance_valid(actor):
			out[slot_id] = actor
	return out


func _clear_food(arena: Node) -> void:
	for food: Node in arena.food_sources:
		if food != null and is_instance_valid(food):
			food.queue_free()
	arena.food_sources.clear()
	arena.team_food_vision = {0: {}, 1: {}}


func _add_food(
	arena: Node,
	kind: String,
	position: Vector2,
	food_value: float
) -> Node:
	var food := FoodSourceScript.new()
	arena.add_child(food)
	if kind == FoodSourceScript.KIND_PLANT:
		food.setup_from_entry({
			"kind": kind,
			"plant_type": FoodSourceScript.PLANT_BERRY,
			"position": position,
			"food_value": food_value,
			"heal_fraction": 0.0,
			"harvest_hits": 1
		})
	else:
		food.setup(kind, position, food_value, 0.0)
	food.set_physics_process(false)
	arena.food_sources.append(food)
	return food


func _tick_firefly_projectiles(arena: Node, delta: float) -> void:
	for child: Node in arena.get_children():
		if child == null or not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		var script: Script = child.get_script()
		if script == null \
			or not String(script.resource_path).ends_with("/firefly_projectile.gd"):
			continue
		child.set_physics_process(false)
		child._physics_process(delta)


func _events_named(events: Array[Dictionary], event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("event", "")) == event_name:
			out.append(event)
	return out


func _actor_positions(actors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot_id in actors:
		var actor: Node = actors[slot_id]
		out[slot_id] = actor.global_position
	return out


func _actor_hunger(actors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot_id in actors:
		var actor: Node = actors[slot_id]
		out[slot_id] = {
			"hunger": actor.hunger,
			"satiated": actor.hunger_satiated
		}
	return out


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


func _match_log_files() -> Dictionary:
	var files: Dictionary = {}
	var directory := DirAccess.open(MATCH_LOG_DIR)
	if directory == null:
		return files
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir():
			files[filename] = true
		filename = directory.get_next()
	directory.list_dir_end()
	return files


func _remove_new_match_logs(existing: Dictionary) -> void:
	var directory := DirAccess.open(MATCH_LOG_DIR)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	var created: Array[String] = []
	while not filename.is_empty():
		if not directory.current_is_dir() and not existing.has(filename):
			created.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	for created_file in created:
		directory.remove(created_file)
