extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BLUE_SQUAD: Array[String] = ["beaver", "duck", "firefly"]
const RED_SQUAD: Array[String] = ["alligator", "water_snake", "bullfrog"]
const TEST_SEED := 149


class SpyLocalInput extends Node:
	var build_calls := 0

	func build_frame(_mouse_position: Vector2) -> Resource:
		build_calls += 1
		return preload("res://scripts/sim/input_frame.gd").new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("all-bots runtime check could not find GameConfig")
		quit(1)
		return
	var original := _capture_config(config)
	config.selected_mode = "All Bots"
	config.clear_draft_bans()
	if not config.set_simulation_request(BLUE_SQUAD, RED_SQUAD, TEST_SEED):
		failures.append("valid All Bots request was rejected: %s" % str(config.get_simulation_request_errors()))

	if change_scene_to_file(ARENA_SCENE) != OK:
		failures.append("All Bots Arena failed to boot")
	else:
		await process_frame
		await physics_frame
		await physics_frame
		_check_arena(current_scene, failures)

	_restore_config(config, original)
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame

	print("all_bots_runtime failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_arena(arena: Node, failures: Array[String]) -> void:
	if arena == null:
		failures.append("All Bots boot produced no Arena")
		return
	arena.set_physics_process(false)
	var state: Dictionary = arena.get_match_slot_state()
	var controllers: Array = state.get("controllers", [])
	var actual_blue := _roster(state.get("blue", []))
	var actual_red := _roster(state.get("red", []))
	var all_ai := controllers.size() == 6
	for controller: Dictionary in controllers:
		all_ai = all_ai and String(controller.get("kind", "")) == "ai"
	if not bool(state.get("sealed", false)) \
		or not bool(state.get("stock_sealed", false)) \
		or not all_ai \
		or arena.player != null \
		or arena.bots.size() != 6 \
		or actual_blue != BLUE_SQUAD \
		or actual_red != RED_SQUAD:
		failures.append(
			"All Bots should seal exact rosters under six AI controllers; state=%s blue=%s red=%s bots=%d player=%s"
			% [str(state), str(actual_blue), str(actual_red), arena.bots.size(), str(arena.player)]
		)

	arena._tick_team_directors(0.25)
	var spy := SpyLocalInput.new()
	arena.local_input = spy
	arena._feed_registered_inputs()
	var routing: Dictionary = arena.get_input_routing_state()
	if not bool(routing.get("routing_valid", false)) \
		or int(routing.get("assignments", 0)) != 6 \
		or int(routing.get("routed", 0)) != 6 \
		or int(routing.get("local", -1)) != 0 \
		or int(routing.get("ai", 0)) != 6 \
		or int(routing.get("duplicates", -1)) != 0:
		failures.append("All Bots should route exactly six unique AI frames and no local frame; routing=%s" % str(routing))
	if spy.build_calls != 0:
		failures.append("All Bots must never consult LocalInput; calls=%d" % spy.build_calls)

	var tick_before := int(arena.get_simulation_tick())
	arena._physics_process(1.0 / 60.0)
	if int(arena.get_simulation_tick()) != tick_before + 1:
		failures.append("manual fixed step should advance the Arena-owned simulation tick exactly once")

	var side_before: Dictionary = arena.get_side_boss_state(0)
	var center_before: Dictionary = arena.get_center_boss_state()
	var f9 := InputEventKey.new()
	f9.pressed = true
	f9.keycode = KEY_F9
	arena._input(f9)
	var f10 := InputEventKey.new()
	f10.pressed = true
	f10.keycode = KEY_F10
	arena._input(f10)
	if arena.get_side_boss_state(0) != side_before or arena.get_center_boss_state() != center_before:
		failures.append("All Bots should ignore local F9/F10 objective debug input")

	var summary: Dictionary = arena.get_match_summary_data("", "simulation_probe")
	var resolved: Dictionary = summary.get("resolved_rosters", {})
	if String(summary.get("control_topology_id", "")) != "all_bots" \
		or int(summary.get("simulation_seed", -1)) != TEST_SEED \
		or _strings(resolved.get("blue", [])) != BLUE_SQUAD \
		or _strings(resolved.get("red", [])) != RED_SQUAD:
		failures.append("simulation summary should retain topology, seed, and exact resolved rosters; summary=%s" % str(summary))
	var players: Array = summary.get("players", [])
	var stable_identities := players.size() == 6
	for row: Dictionary in players:
		stable_identities = stable_identities \
			and not String(row.get("slot_id", "")).is_empty() \
			and int(row.get("slot_index", -1)) in [0, 1, 2] \
			and not String(row.get("creature_id", "")).is_empty()
	if not stable_identities:
		failures.append("all six simulation player rows need stable slot and creature identity; players=%s" % str(players))

	var actor: Node = arena.get_actor_for_slot_id("blue:0")
	arena.elapsed = 12.5
	for _index in 130:
		arena._record_economy_event(actor, "food_consumed", {"team": 0})
	var economy: Dictionary = arena.get_economy_summary_state()
	var blue_economy: Dictionary = economy.get("by_team", {}).get("blue", {})
	if int(economy.get("total_events", 0)) != 130 \
		or int(economy.get("retained_events", 0)) != 128 \
		or int(economy.get("truncated_events", 0)) != 2 \
		or int(economy.get("counts", {}).get("food_consumed", 0)) != 130 \
		or int(blue_economy.get("counts", {}).get("food_consumed", 0)) != 130 \
		or not is_equal_approx(float(economy.get("first_elapsed_sec", {}).get("food_consumed", -1.0)), 12.5):
		failures.append("cumulative economy totals should survive ring-buffer rollover; economy=%s" % str(economy))


func _roster(slots: Array) -> Array[String]:
	var out: Array[String] = []
	for slot: Dictionary in slots:
		out.append(String(slot.get("creature_id", "")))
	return out


func _strings(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		out.append(String(value))
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
		"center_boss": bool(config.center_boss),
		"simulation_seed": int(config.simulation_seed),
		"simulation_config_errors": config.simulation_config_errors.duplicate()
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
	config.simulation_seed = int(state.get("simulation_seed", -1))
	config.simulation_config_errors.assign(state.get("simulation_config_errors", []))
