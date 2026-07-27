extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const MATCH_LOG_DIR := "user://battle_bog_match_logs"


class RecordingBotBrain extends RefCounted:
	var delegate: RefCounted = BotBrainScript.new()
	var calls: Array[Dictionary] = []

	func build_frame(actor: Node, allow_autonomous_deposit := true, order: Dictionary = {}) -> Resource:
		calls.append({
			"actor": actor,
			"allow_autonomous_deposit": allow_autonomous_deposit,
			"order": order.duplicate(true)
		})
		return delegate.build_frame(actor, allow_autonomous_deposit, order)

	func clear_calls(reset_decisions := false) -> void:
		calls.clear()
		if reset_decisions:
			delegate = BotBrainScript.new()

	func reset_actor(actor: Node) -> void:
		delegate.reset_actor(actor)

	func _preferred_range(actor: Node) -> float:
		return delegate._preferred_range(actor)

	func _primary_range(actor: Node, target: Node) -> float:
		return delegate._primary_range(actor, target)

	func _hook(actor: Node) -> RefCounted:
		return delegate._hook(actor)


class TestLocalInput extends Node:
	var press_deposit := false

	func build_frame(aim: Vector2) -> Resource:
		var frame := InputFrameScript.new()
		frame.aim = aim
		frame.set_button(InputFrameScript.BUTTON_HABITAT_DEPOSIT, press_deposit)
		return frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("autonomous AI runtime check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	var existing_logs := _match_log_files()
	var play_vs_ai_ok := await _check_mode("Play vs AI", config, failures)
	var legacy_1v1_ok := await _check_mode("1v1", config, failures)

	_restore_config(config, original_config)
	_remove_new_match_logs(existing_logs)
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame

	print("autonomous_ai_runtime play_vs_ai=%s legacy_1v1=%s" % [
		str(play_vs_ai_ok),
		str(legacy_1v1_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if play_vs_ai_ok and legacy_1v1_ok else 1)


func _check_mode(mode: String, config: Node, failures: Array[String]) -> bool:
	config.selected_mode = mode
	config.set_selected_squad_ids(TEST_SQUAD)
	config.wake_boss = false
	config.center_boss = false

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("%s failed to boot Arena: error=%d" % [mode, error])
		return false
	await process_frame
	await physics_frame
	await physics_frame

	var arena := current_scene
	if arena == null \
		or not arena.has_method("get_match_slot_state") \
		or not arena.has_method("get_input_routing_state"):
		failures.append("%s could not inspect the booted Arena" % mode)
		return false

	arena.set_physics_process(false)
	var recorder := RecordingBotBrain.new()
	arena.bot_brain = recorder

	var default_ok := _check_default_shared_routing(mode, arena, recorder, failures)
	var override_ok := _check_command_overrides(mode, arena, recorder, failures)
	var blue_deposit_ok := _check_inactive_blue_autonomous_deposit(mode, arena, recorder, failures)
	var blue_switch_deposit_ok := _check_inactive_blue_deposit_after_switch(
		mode,
		arena,
		recorder,
		failures
	)
	var red_deposit_ok := _check_red_autonomous_deposit(mode, arena, recorder, failures)
	var routing_ok := _check_routing(mode + " final", arena, failures)
	return default_ok \
		and override_ok \
		and blue_deposit_ok \
		and blue_switch_deposit_ok \
		and red_deposit_ok \
		and routing_ok


func _check_default_shared_routing(
	mode: String,
	arena: Node,
	recorder: RecordingBotBrain,
	failures: Array[String]
) -> bool:
	_prepare_neutral_actors(arena)
	arena._issue_squad_farm(false)
	arena._tick_team_directors(0.0)
	recorder.clear_calls(true)
	arena._feed_registered_inputs()

	var calls_ok := _calls_match(
		arena,
		recorder.calls,
		{
			"blue:1": true,
			"blue:2": true,
			"red:0": true,
			"red:1": true,
			"red:2": true
		}
	)
	var routing_ok := _check_routing(mode + " default farm", arena, failures)
	var ok := calls_ok and routing_ok
	if not ok:
		failures.append(
			(
				"%s default farm should route inactive Blue1/2 and Red0-2 through the shared "
				+ "BotBrain, never Blue0; calls=%s"
			)
			% [mode, str(_describe_calls(arena, recorder.calls))]
		)
	return ok


func _check_command_overrides(
	mode: String,
	arena: Node,
	recorder: RecordingBotBrain,
	failures: Array[String]
) -> bool:
	var player: Node = _slot_actor(arena, BLUE, 0)
	var blue_one: Node = _slot_actor(arena, BLUE, 1)
	var blue_two: Node = _slot_actor(arena, BLUE, 2)
	var red_target: Node = _slot_actor(arena, RED, 0)
	if player == null or blue_one == null or blue_two == null or red_target == null:
		failures.append("%s command override actors were unavailable" % mode)
		return false

	var blue_habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(BLUE)
	var red_habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(RED)
	player.global_position = blue_habitat.get_center()
	blue_one.global_position = player.global_position + Vector2(360.0, -180.0)
	blue_two.global_position = player.global_position + Vector2(360.0, 180.0)
	red_target.global_position = red_habitat.get_center()

	arena._issue_squad_follow(false)
	recorder.clear_calls(true)
	arena._tick_team_directors(0.0)
	arena._feed_registered_inputs()
	var follow_calls_ok := _calls_match(arena, recorder.calls, {
		"blue:1": true,
		"blue:2": true,
		"red:0": true,
		"red:1": true,
		"red:2": true
	})
	var follow_frames_ok: bool = _frame_aims_at(blue_one, player.global_position) \
		and _frame_aims_at(blue_two, player.global_position) \
		and blue_one.input_frame.move != Vector2.ZERO \
		and blue_two.input_frame.move != Vector2.ZERO \
		and _call_order_role_for_actor(recorder.calls, blue_one) == "follow" \
		and _call_order_role_for_actor(recorder.calls, blue_two) == "follow"
	var follow_routing_ok := _check_routing(mode + " follow", arena, failures)

	arena.reveal_entity_to_team(red_target, BLUE, 10.0)
	arena._issue_squad_aggro(red_target)
	recorder.clear_calls(true)
	arena._tick_team_directors(0.0)
	arena._feed_registered_inputs()
	var aggro_calls_ok := _calls_match(arena, recorder.calls, {
		"blue:1": true,
		"blue:2": true,
		"red:0": true,
		"red:1": true,
		"red:2": true
	})
	var aggro_frames_ok: bool = arena.squad_command == "aggro" \
		and _frame_aims_at(blue_one, red_target.global_position) \
		and _frame_aims_at(blue_two, red_target.global_position) \
		and _call_order_role_for_actor(recorder.calls, blue_one) == "aggro" \
		and _call_order_role_for_actor(recorder.calls, blue_two) == "aggro"
	var aggro_routing_ok := _check_routing(mode + " aggro", arena, failures)

	var ok: bool = follow_calls_ok \
		and follow_frames_ok \
		and follow_routing_ok \
		and aggro_calls_ok \
		and aggro_frames_ok \
		and aggro_routing_ok
	if not ok:
		failures.append(
			(
				"%s follow/aggro should override inactive Blue autonomy while Red remains on the "
				+ "shared brain; follow_calls=%s follow_frames=%s aggro_calls=%s "
				+ "aggro_frames=%s command=%s target=%s blue1_aim=%s blue2_aim=%s"
			)
			% [
				mode,
				str(follow_calls_ok),
				str(follow_frames_ok),
				str(aggro_calls_ok),
				str(aggro_frames_ok),
				String(arena.squad_command),
				str(red_target.global_position),
				str(blue_one.input_frame.aim),
				str(blue_two.input_frame.aim)
			]
		)
	return ok


func _check_inactive_blue_autonomous_deposit(
	mode: String,
	arena: Node,
	recorder: RecordingBotBrain,
	failures: Array[String]
) -> bool:
	_prepare_neutral_actors(arena)
	arena._issue_squad_farm(false)
	arena._tick_team_directors(0.0)
	var actor: Node = _slot_actor(arena, BLUE, 1)
	if actor == null:
		failures.append("%s could not find inactive Blue1 for habitat return" % mode)
		return false

	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(BLUE)
	actor.hunger = 100.0
	actor.hunger_satiated = true
	actor.global_position = habitat.get_center() + Vector2(420.0, 0.0)
	var before_deposits := int(arena.team_stats[BLUE].get("deposits", 0))
	var before_cues: int = arena.stock_manager.get_breeding_cues(BLUE).size()

	recorder.clear_calls(true)
	arena._feed_registered_inputs()
	var outside_frame: Resource = actor.input_frame
	var returns_home: bool = outside_frame != null \
		and _vectors_close(outside_frame.aim, habitat.get_center()) \
		and outside_frame.move != Vector2.ZERO \
		and not outside_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)
	var allowed_policy_seen := _call_policy_for_actor(recorder.calls, actor) == 1

	actor.global_position = habitat.get_center()
	recorder.clear_calls(true)
	arena._feed_registered_inputs()
	var inside_frame: Resource = actor.input_frame
	var after_first := int(arena.team_stats[BLUE].get("deposits", 0))
	var cues_after_first: int = arena.stock_manager.get_breeding_cues(BLUE).size()

	recorder.clear_calls()
	arena._feed_registered_inputs()
	var second_frame: Resource = actor.input_frame
	var after_second := int(arena.team_stats[BLUE].get("deposits", 0))
	var cues_after_second: int = arena.stock_manager.get_breeding_cues(BLUE).size()
	var deposits_once: bool = inside_frame != null \
		and inside_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_first == before_deposits + 1 \
		and cues_after_first == before_cues + 1 \
		and not bool(actor.hunger_satiated) \
		and is_equal_approx(float(actor.hunger), 80.0) \
		and second_frame != null \
		and not second_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_second == after_first \
		and cues_after_second == cues_after_first
	var routing_ok := _check_routing(mode + " inactive Blue deposit", arena, failures)

	var ok: bool = returns_home and allowed_policy_seen and deposits_once and routing_ok
	if not ok:
		failures.append(
			(
				"%s satiated inactive Blue1 should return home and autonomously deposit exactly "
				+ "once; returns=%s policy=%d once=%s deposits=%d->%d->%d "
				+ "cues=%d->%d->%d aim=%s move=%s orders=%s"
			)
			% [
				mode,
				str(returns_home),
				_call_policy_for_actor(recorder.calls, actor),
				str(deposits_once),
				before_deposits,
				after_first,
				after_second,
				before_cues,
				cues_after_first,
				cues_after_second,
				str(outside_frame.aim if outside_frame != null else null),
				str(outside_frame.move if outside_frame != null else null),
				str(arena.get_team_order_state(BLUE))
			]
		)
	return ok


func _check_inactive_blue_deposit_after_switch(
	mode: String,
	arena: Node,
	recorder: RecordingBotBrain,
	failures: Array[String]
) -> bool:
	_prepare_neutral_actors(arena)
	arena._set_active_squad_index(2, false)
	recorder.clear_calls(true)
	arena._feed_registered_inputs()
	var inactive_actor: Node = _slot_actor(arena, BLUE, 0)
	var active_actor: Node = _slot_actor(arena, BLUE, 2)
	if inactive_actor == null or active_actor == null:
		failures.append("%s could not inspect Blue actors after controller swap" % mode)
		return false

	inactive_actor.global_position = arena.terrain_map.get_team_habitat_rect(BLUE).get_center()
	inactive_actor.hunger = 100.0
	inactive_actor.hunger_satiated = true
	active_actor.global_position = arena.terrain_map.get_team_habitat_rect(BLUE).get_center()
	active_actor.hunger = 100.0
	active_actor.hunger_satiated = true
	var before_deposits := int(arena.team_stats[BLUE].get("deposits", 0))
	var before_cues: int = arena.stock_manager.get_breeding_cues(BLUE).size()
	var original_local_input: Node = arena.local_input
	var test_local_input := TestLocalInput.new()
	arena.add_child(test_local_input)
	arena.local_input = test_local_input

	recorder.clear_calls(true)
	arena._feed_registered_inputs()
	var first_frame: Resource = inactive_actor.input_frame
	var after_first := int(arena.team_stats[BLUE].get("deposits", 0))
	var cues_after_first: int = arena.stock_manager.get_breeding_cues(BLUE).size()
	var inactive_policy := _call_policy_for_actor(recorder.calls, inactive_actor)
	var active_policy := _call_policy_for_actor(recorder.calls, active_actor)
	var active_waited: bool = bool(active_actor.hunger_satiated) \
		and is_equal_approx(float(active_actor.hunger), 100.0)

	test_local_input.press_deposit = true
	recorder.clear_calls()
	arena._feed_registered_inputs()
	var second_frame: Resource = inactive_actor.input_frame
	var after_second := int(arena.team_stats[BLUE].get("deposits", 0))
	var cues_after_second: int = arena.stock_manager.get_breeding_cues(BLUE).size()
	var active_manual_frame: Resource = active_actor.input_frame

	recorder.clear_calls()
	arena._feed_registered_inputs()
	var after_third := int(arena.team_stats[BLUE].get("deposits", 0))
	var cues_after_third: int = arena.stock_manager.get_breeding_cues(BLUE).size()
	var ok: bool = arena.active_squad_index == 2 \
		and arena.player == active_actor \
		and inactive_policy == 1 \
		and active_policy == -1 \
		and active_waited \
		and first_frame != null \
		and first_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_first == before_deposits + 1 \
		and cues_after_first == before_cues + 1 \
		and second_frame != null \
		and not second_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and active_manual_frame != null \
		and active_manual_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_second == after_first + 1 \
		and cues_after_second == cues_after_first + 1 \
		and after_third == after_second \
		and cues_after_third == cues_after_second
	if not ok:
		failures.append(
			"%s controller swap should auto-deposit only inactive Blue0 and require explicit local input for active Blue1; inactive_policy=%d active_policy=%d active_waited=%s deposits=%d->%d->%d->%d cues=%d->%d->%d->%d"
			% [
				mode,
				inactive_policy,
				active_policy,
				str(active_waited),
				before_deposits,
				after_first,
				after_second,
				after_third,
				before_cues,
				cues_after_first,
				cues_after_second,
				cues_after_third
			]
		)
	arena.local_input = original_local_input
	test_local_input.free()
	arena._set_active_squad_index(0, false)
	return ok


func _check_red_autonomous_deposit(
	mode: String,
	arena: Node,
	recorder: RecordingBotBrain,
	failures: Array[String]
) -> bool:
	_prepare_neutral_actors(arena)
	arena._issue_squad_farm(false)
	arena._tick_team_directors(0.0)
	var actor: Node = _slot_actor(arena, RED, 0)
	if actor == null:
		failures.append("%s could not find Red0 for autonomous deposit" % mode)
		return false

	actor.global_position = arena.terrain_map.get_team_habitat_rect(RED).get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true
	var before_deposits := int(arena.team_stats[RED].get("deposits", 0))
	var before_cues: int = arena.stock_manager.get_breeding_cues(RED).size()

	recorder.clear_calls(true)
	arena._feed_registered_inputs()
	var first_frame: Resource = actor.input_frame
	var after_first := int(arena.team_stats[RED].get("deposits", 0))
	var cues_after_first: int = arena.stock_manager.get_breeding_cues(RED).size()
	var first_policy := _call_policy_for_actor(recorder.calls, actor)

	recorder.clear_calls()
	arena._feed_registered_inputs()
	var second_frame: Resource = actor.input_frame
	var after_second := int(arena.team_stats[RED].get("deposits", 0))
	var cues_after_second: int = arena.stock_manager.get_breeding_cues(RED).size()
	var routing_ok := _check_routing(mode + " Red deposit", arena, failures)

	var ok: bool = first_policy == 1 \
		and first_frame != null \
		and first_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_first == before_deposits + 1 \
		and cues_after_first == before_cues + 1 \
		and not bool(actor.hunger_satiated) \
		and is_equal_approx(float(actor.hunger), 80.0) \
		and second_frame != null \
		and not second_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and after_second == after_first \
		and cues_after_second == cues_after_first \
		and routing_ok
	if not ok:
		failures.append(
			(
				"%s satiated Red0 should autonomously deposit exactly once; policy=%d "
				+ "deposits=%d->%d->%d cues=%d->%d->%d satiated=%s hunger=%.1f "
				+ "first_button=%s second_button=%s"
			)
			% [
				mode,
				first_policy,
				before_deposits,
				after_first,
				after_second,
				before_cues,
				cues_after_first,
				cues_after_second,
				str(actor.hunger_satiated),
				float(actor.hunger),
				str(first_frame != null and first_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)),
				str(second_frame != null and second_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT))
			]
		)
	return ok


func _prepare_neutral_actors(arena: Node) -> void:
	var blue_habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(BLUE)
	var red_habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(RED)
	for team in [BLUE, RED]:
		for index in TEAM_SIZE:
			var actor: Node = _slot_actor(arena, team, index)
			if actor == null:
				continue
			actor.health = actor.max_health
			actor.hunger = 100.0
			actor.hunger_satiated = false
			var habitat := blue_habitat if team == BLUE else red_habitat
			actor.global_position = habitat.get_center() + Vector2(
				-80.0 if team == BLUE else 80.0,
				float(index - 1) * 80.0
			)


func _check_routing(label: String, arena: Node, failures: Array[String]) -> bool:
	var state: Dictionary = arena.get_input_routing_state()
	var actor_ids: Array = state.get("actor_ids", [])
	var unique_actor_ids: Dictionary = {}
	for actor_id in actor_ids:
		unique_actor_ids[String(actor_id)] = true

	var frame_ids: Dictionary = {}
	var all_frames_present := true
	for team in [BLUE, RED]:
		for index in TEAM_SIZE:
			var actor: Node = _slot_actor(arena, team, index)
			var frame: Resource = actor.input_frame if actor != null else null
			if frame == null:
				all_frames_present = false
			else:
				frame_ids[str(frame.get_instance_id())] = true

	var ok := bool(state.get("sealed", false)) \
		and int(state.get("assignments", -1)) == TEAM_SIZE * 2 \
		and int(state.get("routed", -1)) == TEAM_SIZE * 2 \
		and int(state.get("duplicates", -1)) == 0 \
		and int(state.get("local", -1)) == 1 \
		and int(state.get("ai", -1)) == 5 \
		and actor_ids.size() == TEAM_SIZE * 2 \
		and unique_actor_ids.size() == TEAM_SIZE * 2 \
		and all_frames_present \
		and frame_ids.size() == TEAM_SIZE * 2
	if not ok:
		failures.append(
			"%s expected six unique frames with 1 local and 5 AI; routing=%s frame_ids=%s"
			% [label, str(state), str(frame_ids)]
		)
	return ok


func _calls_match(arena: Node, calls: Array[Dictionary], expected: Dictionary) -> bool:
	var actual: Dictionary = {}
	for call: Dictionary in calls:
		var actor: Node = call.get("actor", null)
		var key := _slot_key_for_actor(arena, actor)
		if key.is_empty() or actual.has(key):
			return false
		actual[key] = bool(call.get("allow_autonomous_deposit", false))
	return actual == expected


func _call_policy_for_actor(calls: Array[Dictionary], actor: Node) -> int:
	for call: Dictionary in calls:
		if call.get("actor", null) == actor:
			return 1 if bool(call.get("allow_autonomous_deposit", false)) else 0
	return -1


func _call_order_role_for_actor(calls: Array[Dictionary], actor: Node) -> String:
	for call: Dictionary in calls:
		if call.get("actor", null) == actor:
			var order: Dictionary = call.get("order", {})
			return String(order.get("role", ""))
	return ""


func _describe_calls(arena: Node, calls: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for call: Dictionary in calls:
		out.append("%s:%s" % [
			_slot_key_for_actor(arena, call.get("actor", null)),
			str(call.get("allow_autonomous_deposit", false))
		])
	return out


func _slot_key_for_actor(arena: Node, actor: Node) -> String:
	for team in [BLUE, RED]:
		for index in TEAM_SIZE:
			if _slot_actor(arena, team, index) == actor:
				return "%s:%d" % ["blue" if team == BLUE else "red", index]
	return ""


func _slot_actor(arena: Node, team: int, slot_index: int) -> Node:
	var slot: Dictionary = arena.slot_registry.get_slot(team, slot_index)
	return slot.get("actor", null)


func _frame_aims_at(actor: Node, point: Vector2) -> bool:
	return actor != null \
		and actor.input_frame != null \
		and _vectors_close(actor.input_frame.aim, point)


func _vectors_close(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 0.01


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
	config.selected_creature_id = String(state.get("selected_creature_id", "snapping_turtle"))
	config.selected_squad_ids.assign(state.get("selected_squad_ids", []))
	config.blue_draft_bans.assign(state.get("blue_draft_bans", []))
	config.red_draft_bans.assign(state.get("red_draft_bans", []))
	config.wake_boss = bool(state.get("wake_boss", false))
	config.center_boss = bool(state.get("center_boss", false))
