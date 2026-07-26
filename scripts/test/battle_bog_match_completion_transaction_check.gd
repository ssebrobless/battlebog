extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const STOCKS_PER_SLOT := 3
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const MATCH_LOG_DIR := "user://battle_bog_match_logs"
const TEST_WINNER := "Blue"
const TEST_REASON := "match_completion_transaction_check"
const TEST_STATUS := "Blue wins transaction check"
const ACTION_BUTTONS := (
	InputFrameScript.BUTTON_PRIMARY
	| InputFrameScript.BUTTON_ABILITY_Q
	| InputFrameScript.BUTTON_ABILITY_E
	| InputFrameScript.BUTTON_HABITAT_DEPOSIT
)


class PhysicsFinishProbe extends CharacterBody2D:
	var arena: Node = null
	var ran := false
	var moved_after_finish := false

	func _physics_process(_delta: float) -> void:
		if ran or arena == null:
			return
		ran = true
		velocity = Vector2.RIGHT * 60.0
		var before := global_position
		arena._finish_match(TEST_WINNER, TEST_REASON, TEST_STATUS)
		move_and_slide()
		moved_after_finish = global_position != before


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("match completion transaction check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	var existing_logs := _match_log_files()
	_configure_play_vs_ai(config)

	var arena := await _boot_arena(failures)
	if arena == null:
		_restore_config(config, original_config)
		_remove_new_match_logs(existing_logs)
		for failure in failures:
			push_error(failure)
		quit(1)
		return

	var boot_ok := _check_fresh_match(arena, "initial boot", failures)
	var finish_state: Dictionary = await _finish_and_capture(arena, existing_logs, failures)
	var finish_ok := bool(finish_state.get("ok", false))
	var freeze_ok := await _check_world_frozen(arena, finish_state, failures)
	var restart_ok := await _check_ui_accept_restart(arena, failures)

	_restore_config(config, original_config)
	_remove_new_match_logs(existing_logs)

	var passed := boot_ok and finish_ok and freeze_ok and restart_ok
	print(
		"match_completion_transaction boot=%s finish=%s freeze=%s restart=%s"
		% [str(boot_ok), str(finish_ok), str(freeze_ok), str(restart_ok)]
	)
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _boot_arena(failures: Array[String]) -> Node:
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("Play vs AI Arena boot failed with error=%d" % error)
		return null
	await process_frame
	await physics_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		failures.append("Play vs AI Arena boot produced no current scene")
		return null
	if not arena.has_method("get_match_result_state"):
		failures.append("Arena does not expose get_match_result_state() required by item 5C")
		return null
	return arena


func _finish_and_capture(
	arena: Node,
	existing_logs: Dictionary,
	failures: Array[String]
) -> Dictionary:
	var actors := _registered_actors(arena)
	for actor: Node in actors:
		var action_frame: Resource = InputFrameScript.new()
		action_frame.move = Vector2(0.75, -0.25)
		action_frame.aim = actor.global_position + Vector2.RIGHT * 80.0
		action_frame.buttons = ACTION_BUTTONS
		actor.set_input_frame(action_frame)

	# Arena advances elapsed before child physics callbacks.
	arena.elapsed = 73.25 - (1.0 / 60.0)
	var finish_probe := PhysicsFinishProbe.new()
	finish_probe.arena = arena
	arena.add_child(finish_probe)
	await physics_frame
	await process_frame
	var physics_finish_ok := finish_probe.ran and finish_probe.moved_after_finish

	var result: Dictionary = arena.get_match_result_state()
	var result_panel: Node = arena.get("match_result_panel")
	var panel_state: Dictionary = (
		result_panel.get_display_state()
		if result_panel != null and result_panel.has_method("get_display_state")
		else {}
	)
	var log_path := String(arena.get_last_match_summary_log_path())
	var new_logs := _new_match_log_files(existing_logs)
	var frozen_snapshot := _world_snapshot(arena)
	var direct_children_stopped := true
	for child: Node in arena.get_children():
		direct_children_stopped = (
			direct_children_stopped
			and not child.is_processing()
			and not child.is_physics_processing()
		)

	var result_contract_ok := (
		bool(arena.match_over)
		and String(result.get("winner", "")) == TEST_WINNER
		and String(result.get("reason", "")) == TEST_REASON
		and String(result.get("status_text", "")) == TEST_STATUS
		and is_equal_approx(float(result.get("elapsed_sec", -1.0)), 73.25)
		and result_panel != null
		and bool(result_panel.visible)
		and String(panel_state.get("winner", "")) == TEST_WINNER
		and String(panel_state.get("time", "")) == "01:13"
		and int(panel_state.get("blue", {}).get("max_stocks", 0)) == 9
		and int(panel_state.get("red", {}).get("max_stocks", 0)) == 9
	)
	var neutral_ok := _all_actor_inputs_neutral(actors)
	var post_finish_tick_ok := true
	for actor: Node in actors:
		var before_tick_position: Vector2 = actor.global_position
		actor.tick_sim(1.0 / 60.0)
		post_finish_tick_ok = (
			post_finish_tick_ok
			and actor.global_position == before_tick_position
		)
	var one_log_ok := (
		not log_path.is_empty()
		and FileAccess.file_exists(log_path)
		and new_logs.size() == 1
		and String(new_logs[0]) == log_path.get_file()
	)

	var immutable_probe: Dictionary = arena.get_match_result_state()
	immutable_probe["winner"] = "Mutated"
	immutable_probe["elapsed_sec"] = -999.0
	var probe_teams: Dictionary = immutable_probe.get("teams", {})
	var probe_blue: Dictionary = probe_teams.get("blue", {})
	probe_blue["stocks_remaining"] = -999
	var immutable_ok: bool = arena.get_match_result_state() == result

	arena.elapsed = 999.0
	arena.team_stats[BLUE]["deposits"] = 999
	arena._finish_match("Red", "replacement_attempt", "must not replace")
	var idempotent_result: Dictionary = arena.get_match_result_state()
	var idempotent_path := String(arena.get_last_match_summary_log_path())
	var idempotent_logs := _new_match_log_files(existing_logs)
	var idempotent_ok := (
		idempotent_result == result
		and idempotent_path == log_path
		and idempotent_logs.size() == 1
	)

	# Restore the captured values so the frame-freeze check starts at the commit boundary.
	arena.elapsed = float(frozen_snapshot.get("elapsed", 0.0))
	arena.team_stats = frozen_snapshot.get("team_stats", {}).duplicate(true)
	frozen_snapshot = _world_snapshot(arena)

	var ok: bool = (
		result_contract_ok
		and immutable_ok
		and idempotent_ok
		and one_log_ok
		and neutral_ok
		and post_finish_tick_ok
		and direct_children_stopped
		and physics_finish_ok
	)
	if not ok:
		failures.append(
			(
				"finish should capture one immutable/idempotent result, write exactly one log, "
				+ "neutralize every registered actor, stop direct child processing, and allow the "
				+ "finishing physics callback to leave the physics space safely; "
				+ "result_ok=%s immutable=%s idempotent=%s log=%s neutral=%s post_tick=%s children=%s physics_finish=%s "
				+ "result=%s repeat=%s path=%s repeat_path=%s new_logs=%s"
			)
			% [
				str(result_contract_ok),
				str(immutable_ok),
				str(idempotent_ok),
				str(one_log_ok),
				str(neutral_ok),
				str(post_finish_tick_ok),
				str(direct_children_stopped),
				str(physics_finish_ok),
				str(result),
				str(idempotent_result),
				log_path,
				idempotent_path,
				str(idempotent_logs)
			]
		)
	return {
		"ok": ok,
		"result": result,
		"log_path": log_path,
		"snapshot": frozen_snapshot
	}


func _check_world_frozen(
	arena: Node,
	finish_state: Dictionary,
	failures: Array[String]
) -> bool:
	var before: Dictionary = finish_state.get("snapshot", {})
	for _frame_index in 6:
		await process_frame
		await physics_frame
	var after := _world_snapshot(arena)
	var neutral_ok := _all_actor_inputs_neutral(_registered_actors(arena))
	var children_disabled := true
	for child: Node in arena.get_children():
		children_disabled = (
			children_disabled
			and child.process_mode == Node.PROCESS_MODE_DISABLED
		)
	var ok := (
		bool(arena.match_over)
		and before == after
		and neutral_ok
		and children_disabled
		and not arena.is_physics_processing()
	)
	if not ok:
		failures.append(
			(
				"finished match must hold elapsed time, entity positions, health, and telemetry "
				+ "constant across frames with neutral actor inputs; physics=%s neutral=%s children=%s "
				+ "before=%s after=%s"
			)
			% [
				str(arena.is_physics_processing()),
				str(neutral_ok),
				str(children_disabled),
				str(before),
				str(after)
			]
		)
	return ok


func _check_ui_accept_restart(arena: Node, failures: Array[String]) -> bool:
	var previous_arena_id := arena.get_instance_id()
	var restart_event := InputEventAction.new()
	restart_event.action = "ui_accept"
	restart_event.pressed = true
	arena._input(restart_event)

	for _frame_index in 8:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != previous_arena_id:
			break
	if current_scene == null or current_scene.get_instance_id() == previous_arena_id:
		failures.append("ui_accept did not reload the completed Play vs AI match")
		return false
	await physics_frame
	await process_frame

	var restarted := current_scene
	var fresh_ok := _check_fresh_match(restarted, "ui_accept restart", failures)
	var result_empty: bool = (
		restarted.has_method("get_match_result_state")
		and restarted.get_match_result_state().is_empty()
	)
	var children_active := true
	for child: Node in restarted.get_children():
		children_active = children_active and child.process_mode != Node.PROCESS_MODE_DISABLED
	var ok: bool = (
		fresh_ok
		and result_empty
		and not bool(restarted.match_over)
		and restarted.is_physics_processing()
		and children_active
	)
	if not ok:
		failures.append(
			(
				"ui_accept restart should create a fresh active match with no carried result; "
				+ "fresh=%s empty_result=%s over=%s physics=%s children_active=%s"
			)
			% [
				str(fresh_ok),
				str(result_empty),
				str(restarted.match_over),
				str(restarted.is_physics_processing()),
				str(children_active)
			]
		)
	return ok


func _check_fresh_match(arena: Node, label: String, failures: Array[String]) -> bool:
	if arena == null or not arena.has_method("get_match_slot_state"):
		failures.append("%s did not expose competitive slot state" % label)
		return false
	var state: Dictionary = arena.get_match_slot_state()
	var blue: Array = state.get("blue", [])
	var red: Array = state.get("red", [])
	var blue_stocks := _stock_totals(arena.stock_manager.get_team_slots(BLUE))
	var red_stocks := _stock_totals(arena.stock_manager.get_team_slots(RED))
	var ok := (
		String(arena.legacy_mode_snapshot) == "Play vs AI"
		and bool(state.get("sealed", false))
		and bool(state.get("stock_sealed", false))
		and blue.size() == TEAM_SIZE
		and red.size() == TEAM_SIZE
		and blue_stocks == Vector2i(TEAM_SIZE * STOCKS_PER_SLOT, TEAM_SIZE * STOCKS_PER_SLOT)
		and red_stocks == Vector2i(TEAM_SIZE * STOCKS_PER_SLOT, TEAM_SIZE * STOCKS_PER_SLOT)
	)
	if not ok:
		failures.append(
			(
				"%s expected a sealed six-slot Play vs AI match with 9/9 stocks per team; "
				+ "mode=%s state=%s blue=%s red=%s"
			)
			% [
				label,
				String(arena.legacy_mode_snapshot),
				str(state),
				str(blue_stocks),
				str(red_stocks)
			]
		)
	return ok


func _world_snapshot(arena: Node) -> Dictionary:
	var entity_state: Dictionary = {}
	for entity: Node in arena.entities:
		if entity == null or not is_instance_valid(entity):
			continue
		var state := {
			"position": entity.global_position if entity is Node2D else Vector2.ZERO
		}
		if entity.get("health") != null:
			state["health"] = float(entity.get("health"))
		entity_state[str(entity.get_instance_id())] = state
	return {
		"elapsed": float(arena.elapsed),
		"entities": entity_state,
		"team_stats": arena.team_stats.duplicate(true),
		"actor_stats": arena.actor_stats.duplicate(true)
	}


func _registered_actors(arena: Node) -> Array[Node]:
	var actors: Array[Node] = []
	var state: Dictionary = arena.get_match_slot_state()
	for slot: Dictionary in state.get("blue", []) + state.get("red", []):
		var actor: Node = slot.get("actor", null)
		if actor != null and is_instance_valid(actor):
			actors.append(actor)
	return actors


func _all_actor_inputs_neutral(actors: Array[Node]) -> bool:
	for actor: Node in actors:
		var frame: Resource = actor.input_frame
		if frame == null or frame.move != Vector2.ZERO or int(frame.buttons) != 0:
			return false
	return true


func _stock_totals(slots: Array) -> Vector2i:
	var remaining := 0
	var maximum := 0
	for slot: Dictionary in slots:
		remaining += int(slot.get("stocks_remaining", 0))
		maximum += int(slot.get("max_stocks", 0))
	return Vector2i(remaining, maximum)


func _configure_play_vs_ai(config: Node) -> void:
	config.selected_mode = "Play vs AI"
	config.set_selected_squad_ids(TEST_SQUAD)
	config.selected_creature_id = TEST_SQUAD[0]
	config.wake_boss = false
	config.center_boss = false


func _capture_config(config: Node) -> Dictionary:
	return {
		"selected_mode": String(config.selected_mode),
		"selected_creature_id": String(config.selected_creature_id),
		"selected_squad_ids": config.selected_squad_ids.duplicate(),
		"blue_draft_bans": config.blue_draft_bans.duplicate(),
		"red_draft_bans": config.red_draft_bans.duplicate(),
		"wake_boss": bool(config.wake_boss),
		"center_boss": bool(config.center_boss)
	}


func _restore_config(config: Node, state: Dictionary) -> void:
	config.selected_mode = String(state.get("selected_mode", "1v1"))
	config.selected_creature_id = String(
		state.get("selected_creature_id", "snapping_turtle")
	)
	config.selected_squad_ids.assign(state.get("selected_squad_ids", []))
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


func _new_match_log_files(existing: Dictionary) -> Array[String]:
	var new_files: Array[String] = []
	for filename: String in _match_log_files().keys():
		if not existing.has(filename):
			new_files.append(filename)
	new_files.sort()
	return new_files


func _remove_new_match_logs(existing: Dictionary) -> void:
	var directory := DirAccess.open(MATCH_LOG_DIR)
	if directory == null:
		return
	for filename: String in _new_match_log_files(existing):
		directory.remove(filename)
