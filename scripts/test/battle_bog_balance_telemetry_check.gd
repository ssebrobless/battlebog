extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const INPUT_FRAME := preload("res://scripts/sim/input_frame.gd")
const BLUE_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const RED_SQUAD: Array[String] = ["beaver", "duck", "firefly"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("balance telemetry check could not find GameConfig")
		quit(1)
		return
	var original := _capture_config(config)
	config.selected_mode = "All Bots"
	config.clear_draft_bans()
	if not config.set_simulation_request(BLUE_SQUAD, RED_SQUAD, 43):
		failures.append("valid telemetry simulation request was rejected")

	if change_scene_to_file(ARENA_SCENE) != OK:
		failures.append("telemetry Arena failed to boot")
	else:
		await process_frame
		await physics_frame
		await physics_frame
		_check_arena(current_scene, failures)

	_restore_config(config, original)
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	print("balance_telemetry failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_arena(arena: Node, failures: Array[String]) -> void:
	if arena == null:
		failures.append("telemetry boot produced no Arena")
		return
	if not arena.has_method("_reset_match_telemetry"):
		failures.append("Arena script did not load")
		return
	arena.set_physics_process(false)
	arena._reset_match_telemetry()
	var source: Node = arena.get_actor_for_slot_id("blue:0")
	var target: Node = arena.get_actor_for_slot_id("red:0")
	if source == null or target == null:
		failures.append("telemetry check needs stable blue:0 and red:0 actors")
		return

	var active := INPUT_FRAME.new()
	active.move = Vector2.RIGHT
	active.buttons = INPUT_FRAME.BUTTON_PRIMARY | INPUT_FRAME.BUTTON_ABILITY_Q
	arena.simulation_tick = 100
	arena._record_balance_slot_tick(source, active, true)
	source.global_position += Vector2(3.0, 4.0)
	arena.simulation_tick += 1
	arena._record_balance_slot_tick(source, active, true)

	var neutral := INPUT_FRAME.new()
	for _index in 2:
		arena.simulation_tick += 1
		arena._record_balance_slot_tick(source, neutral, true)
	var ability := INPUT_FRAME.new()
	ability.buttons = INPUT_FRAME.BUTTON_ABILITY_E
	arena.simulation_tick += 1
	arena._record_balance_slot_tick(source, ability, true)

	arena._record_landed_hit_telemetry({
		"type": "hit_landed",
		"source": source,
		"target": target,
		"amount": 12.0,
		"position": target.global_position
	})
	arena._record_landed_hit_telemetry({
		"type": "hit_landed",
		"source": source,
		"target": target,
		"amount": 0.0
	})
	arena._record_landed_hit_telemetry({
		"type": "hit_landed",
		"source": source,
		"target": source,
		"amount": 12.0
	})

	var telemetry: Dictionary = arena.get_balance_telemetry_state()
	var rows: Array = telemetry.get("slot_activity", [])
	var source_row := _row_for_slot(rows, "blue:0")
	if rows.size() != 6:
		failures.append("balance telemetry should expose all six stable slots; rows=%s" % str(rows))
	if int(source_row.get("sample_ticks", -1)) != 5 \
		or int(source_row.get("alive_ticks", -1)) != 5 \
		or int(source_row.get("active_ticks", -1)) != 3 \
		or int(source_row.get("idle_ticks", -1)) != 2 \
		or int(source_row.get("current_idle_ticks", -1)) != 0 \
		or int(source_row.get("max_idle_ticks", -1)) != 2 \
		or int(source_row.get("move_input_ticks", -1)) != 2 \
		or int(source_row.get("primary_press_count", -1)) != 1 \
		or int(source_row.get("ability_press_count", -1)) != 2 \
		or int(source_row.get("ability_q_press_count", -1)) != 1 \
		or int(source_row.get("ability_e_press_count", -1)) != 1 \
		or int(source_row.get("landed_hit_count", -1)) != 1 \
		or not is_equal_approx(float(source_row.get("distance_traveled_px", -1.0)), 5.0):
		failures.append("slot activity counters or rising-edge attribution were incorrect: %s" % str(source_row))

	arena.boss_lifecycle_events.clear()
	arena.boss_lifecycle_event_sequence = 0
	arena.elapsed = 12.5
	arena.simulation_tick = 750
	arena.debug_wake_boss(0)
	var blue_zone: Dictionary = arena._team_boss_zone(0)
	blue_zone["active"] = false
	blue_zone["objective_state"] = "claimable"
	blue_zone["contested"] = true
	arena._advance_boss_claim(blue_zone, 0.25)
	blue_zone["contested"] = false
	blue_zone["control_team"] = 0
	arena._advance_boss_claim(blue_zone, 0.25)
	arena._resolve_boss_claim(blue_zone, 0)

	arena.debug_wake_boss(1)
	var red_zone: Dictionary = arena._team_boss_zone(1)
	red_zone["active"] = false
	red_zone["objective_state"] = "claimable"
	arena._resolve_boss_claim(red_zone, 0)

	arena._spawn_center_boss("teratornis")
	var center_index: int = arena._center_boss_zone_index()
	if center_index < 0:
		failures.append("center boss telemetry probe did not create a live zone")
	else:
		var center_zone: Dictionary = arena.animal_zone_states[center_index]
		center_zone["active"] = false
		center_zone["objective_state"] = "claimable"
		arena._resolve_boss_claim(center_zone, 1)

	telemetry = arena.get_balance_telemetry_state()
	var events: Array = telemetry.get("boss_lifecycle_events", [])
	for event_name in ["active", "contested", "claimable", "claimed", "stolen"]:
		if not _has_boss_event(events, event_name, false):
			failures.append("side boss lifecycle is missing '%s': %s" % [event_name, str(events)])
	if not _has_boss_event(events, "active", true) or not _has_boss_event(events, "claimed", true):
		failures.append("center boss lifecycle needs active and claimed events: %s" % str(events))
	for event: Dictionary in events:
		if not is_equal_approx(float(event.get("elapsed_sec", -1.0)), 12.5) \
			or int(event.get("simulation_tick", -1)) != 750 \
			or String(event.get("zone_id", "")).is_empty() \
			or String(event.get("family", "")).is_empty():
			failures.append("boss event lacks deterministic timestamp or identity: %s" % str(event))
			break

	var summary: Dictionary = arena.get_match_summary_data("", "telemetry_probe")
	var summary_telemetry: Dictionary = summary.get("balance_telemetry", {})
	if (summary_telemetry.get("slot_activity", []) as Array).size() != 6 \
		or int(summary_telemetry.get("boss_lifecycle_total_events", 0)) != events.size():
		failures.append("battle_bog_match_summary_v1 did not retain balance telemetry")


func _row_for_slot(rows: Array, slot_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row.get("slot_id", "")) == slot_id:
			return row
	return {}


func _has_boss_event(events: Array, event_name: String, center: bool) -> bool:
	for event: Dictionary in events:
		if String(event.get("event", "")) == event_name and bool(event.get("center", false)) == center:
			return true
	return false


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
