extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const STOCKS_PER_SLOT := 3
const LOCAL_HUMAN := "local_human"
const AI := "ai"
const SOLO_SWAP := "solo_swap"
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("stable slots runtime check could not find GameConfig")
		quit(1)
		return

	var original := _capture_config(config)
	var solo_ok := await _check_mode("1v1", true, config, failures)
	var play_vs_ai_ok := await _check_mode("Play vs AI", false, config, failures)
	var clash_ok := await _check_mode("3v3", false, config, failures)
	_restore_config(config, original)

	print("stable_slots_runtime solo=%s play_vs_ai=%s clash=%s" % [
		str(solo_ok),
		str(play_vs_ai_ok),
		str(clash_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if solo_ok and play_vs_ai_ok and clash_ok else 1)


func _check_mode(mode: String, check_transfer: bool, config: Node, failures: Array[String]) -> bool:
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
	if arena == null:
		failures.append("%s Arena was not current_scene after startup frames" % mode)
		return false
	if not arena.has_method("get_match_slot_state") or not arena.has_method("get_input_routing_state"):
		failures.append("%s Arena is missing stable-slot runtime inspection APIs" % mode)
		return false

	var slot_state: Dictionary = arena.get_match_slot_state()
	var slots_ok := _check_slot_state(mode, arena, slot_state, failures)
	var routing_ok := _check_routing_state(mode, arena.get_input_routing_state(), failures)
	var profile_ok := _check_mode_profile(mode, arena, failures)
	var transfer_ok := true
	var release_gate_ok := true
	if check_transfer:
		transfer_ok = _check_atomic_transfer(arena, failures)
		release_gate_ok = _check_switch_release_gate(arena, failures)
	return slots_ok and routing_ok and profile_ok and transfer_ok and release_gate_ok


func _check_mode_profile(mode: String, arena: Node, failures: Array[String]) -> bool:
	var topology_id := String(arena.control_topology.get("id", ""))
	var camera: Camera2D = arena.camera
	var camera_zoom := camera.zoom if camera != null else Vector2.ZERO
	var expects_solo_swap := mode == "1v1" or mode == "Play vs AI"
	var ok := true
	if expects_solo_swap:
		ok = (
			topology_id == SOLO_SWAP
			and is_equal_approx(camera_zoom.x, 2.6)
			and is_equal_approx(camera_zoom.y, 2.6)
		)
	if not ok:
		failures.append("%s expected solo_swap topology and 2.6 zoom; topology=%s zoom=%s" % [
			mode,
			topology_id,
			str(camera_zoom)
		])
	return ok


func _check_slot_state(
	mode: String,
	arena: Node,
	state: Dictionary,
	failures: Array[String]
) -> bool:
	var blue: Array = state.get("blue", [])
	var red: Array = state.get("red", [])
	var controllers: Array = state.get("controllers", [])
	var blue_stocks: Array = arena.stock_manager.get_team_slots(BLUE)
	var red_stocks: Array = arena.stock_manager.get_team_slots(RED)

	var sealed_ok := bool(state.get("sealed", false)) and bool(state.get("stock_sealed", false))
	var blue_ok := _ordered_slots_match(blue, BLUE, "blue")
	var red_ok := _ordered_slots_match(red, RED, "red")
	var blue_stock_ok := _ordered_stocks_match(blue_stocks, BLUE, "blue")
	var red_stock_ok := _ordered_stocks_match(red_stocks, RED, "red")
	var controllers_ok := _controller_plan_matches(controllers, BLUE, 0)
	var totals_ok := (
		_stock_total(blue_stocks) == TEAM_SIZE * STOCKS_PER_SLOT
		and _stock_total(red_stocks) == TEAM_SIZE * STOCKS_PER_SLOT
	)
	var ok := (
		sealed_ok
		and blue_ok
		and red_ok
		and blue_stock_ok
		and red_stock_ok
		and controllers_ok
		and totals_ok
	)
	if not ok:
		failures.append(
			"%s expected sealed 3v3 slots, three stocks per slot, 9 stocks per team, "
			+ "and Blue0 as the sole local controller; state=%s blue_stocks=%s red_stocks=%s"
			% [mode, str(state), str(blue_stocks), str(red_stocks)]
		)
	return ok


func _check_routing_state(mode: String, state: Dictionary, failures: Array[String]) -> bool:
	var actor_ids: Array = state.get("actor_ids", [])
	var unique_actor_ids: Dictionary = {}
	for actor_id in actor_ids:
		unique_actor_ids[String(actor_id)] = true
	var ok := (
		bool(state.get("sealed", false))
		and int(state.get("assignments", -1)) == TEAM_SIZE * 2
		and int(state.get("routed", -1)) == TEAM_SIZE * 2
		and int(state.get("duplicates", -1)) == 0
		and int(state.get("local", -1)) == 1
		and int(state.get("ai", -1)) == 5
		and actor_ids.size() == TEAM_SIZE * 2
		and unique_actor_ids.size() == TEAM_SIZE * 2
	)
	if not ok:
		failures.append("%s expected six unique routed actors with 1 local and 5 AI; got %s" % [
			mode,
			str(state)
		])
	return ok


func _check_atomic_transfer(arena: Node, failures: Array[String]) -> bool:
	var before_state: Dictionary = arena.get_match_slot_state()
	var before_blue: Array = before_state.get("blue", [])
	if before_blue.size() != TEAM_SIZE:
		failures.append("1v1 could not inspect three Blue slots before controller transfer")
		return false

	var previous_actor: Node = before_blue[0].get("actor", null)
	var next_actor: Node = before_blue[1].get("actor", null)
	if previous_actor == null or next_actor == null:
		failures.append("1v1 Blue0/Blue1 actors were missing before controller transfer")
		return false

	var previous_before := _actor_state(previous_actor)
	var next_before := _actor_state(next_actor)
	arena._set_active_squad_index(1, false)

	var after_state: Dictionary = arena.get_match_slot_state()
	var controllers: Array = after_state.get("controllers", [])
	var controller_ok := _controller_plan_matches(controllers, BLUE, 1)
	var player_ok: bool = arena.player == next_actor and arena.player == arena.player_squad[1]
	var assignments_ok := controllers.size() == TEAM_SIZE * 2 and _unique_controller_slots(controllers) == TEAM_SIZE * 2
	var state_ok := (
		_actor_state_matches(previous_before, _actor_state(previous_actor))
		and _actor_state_matches(next_before, _actor_state(next_actor))
	)

	arena._feed_registered_inputs()
	var routing_ok := _check_routing_state("1v1 post-transfer", arena.get_input_routing_state(), failures)
	var ok := controller_ok and player_ok and assignments_ok and state_ok and routing_ok
	if not ok:
		failures.append(
			"1v1 transfer should atomically move local control Blue0->Blue1 without changing "
			+ "health, hunger, or cooldowns; controllers=%s player_ok=%s assignments_ok=%s "
			+ "state_ok=%s previous_before=%s previous_after=%s next_before=%s next_after=%s"
			% [
				str(controllers),
				str(player_ok),
				str(assignments_ok),
				str(state_ok),
				str(previous_before),
				str(_actor_state(previous_actor)),
				str(next_before),
				str(_actor_state(next_actor))
			]
		)
	return ok


func _check_switch_release_gate(arena: Node, failures: Array[String]) -> bool:
	var held_buttons := (
		InputFrameScript.BUTTON_PRIMARY
		| InputFrameScript.BUTTON_ABILITY_Q
		| InputFrameScript.BUTTON_ABILITY_E
		| InputFrameScript.BUTTON_HUT_DEFEND
		| InputFrameScript.BUTTON_HABITAT_DEPOSIT
		| InputFrameScript.BUTTON_CONTEXT_ACTION
		| InputFrameScript.BUTTON_FLIGHT_TOGGLE
	)
	var move := Vector2(0.75, -0.25)
	var aim := Vector2(321.0, 654.0)
	arena.switch_release_mask = held_buttons

	var held_frame_1 := _make_input_frame(move, aim, held_buttons)
	arena._apply_switch_release_gate(held_frame_1)
	var first_held_ok: bool = (
		int(held_frame_1.buttons) == 0
		and arena.switch_release_mask == held_buttons
		and held_frame_1.move == move
		and held_frame_1.aim == aim
	)

	var held_frame_2 := _make_input_frame(move, aim, held_buttons)
	arena._apply_switch_release_gate(held_frame_2)
	var second_held_ok: bool = (
		int(held_frame_2.buttons) == 0
		and arena.switch_release_mask == held_buttons
		and held_frame_2.move == move
		and held_frame_2.aim == aim
	)

	var release_frame := _make_input_frame(move, aim, 0)
	arena._apply_switch_release_gate(release_frame)
	var release_ok: bool = (
		arena.switch_release_mask == 0
		and release_frame.buttons == 0
		and release_frame.move == move
		and release_frame.aim == aim
	)

	var newly_pressed_frame := _make_input_frame(
		move,
		aim,
		InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q
	)
	arena._apply_switch_release_gate(newly_pressed_frame)
	var newly_pressed_ok: bool = (
		newly_pressed_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
		and newly_pressed_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
		and newly_pressed_frame.move == move
		and newly_pressed_frame.aim == aim
	)

	var ok: bool = first_held_ok and second_held_ok and release_ok and newly_pressed_ok
	if not ok:
		failures.append(
			"switch release gate should suppress held actions across frames, preserve move/aim, "
			+ "clear after release, and pass newly pressed actions; first=%s second=%s release=%s "
			+ "new=%s mask=%d"
			% [
				str(first_held_ok),
				str(second_held_ok),
				str(release_ok),
				str(newly_pressed_ok),
				arena.switch_release_mask
			]
		)
	return ok


func _make_input_frame(move: Vector2, aim: Vector2, buttons: int) -> Resource:
	var frame: Resource = InputFrameScript.new()
	frame.move = move
	frame.aim = aim
	frame.buttons = buttons
	return frame


func _ordered_slots_match(slots: Array, team: int, team_id: String) -> bool:
	if slots.size() != TEAM_SIZE:
		return false
	for index in TEAM_SIZE:
		var slot: Dictionary = slots[index]
		if (
			int(slot.get("team", -1)) != team
			or int(slot.get("slot_index", -1)) != index
			or String(slot.get("slot_id", "")) != "%s:%d" % [team_id, index]
			or slot.get("actor", null) == null
		):
			return false
	return true


func _ordered_stocks_match(slots: Array, team: int, team_id: String) -> bool:
	if slots.size() != TEAM_SIZE:
		return false
	for index in TEAM_SIZE:
		var slot: Dictionary = slots[index]
		if (
			int(slot.get("team", -1)) != team
			or int(slot.get("slot_index", -1)) != index
			or String(slot.get("slot_id", "")) != "%s:%d" % [team_id, index]
			or int(slot.get("stocks_remaining", -1)) != STOCKS_PER_SLOT
			or int(slot.get("max_stocks", -1)) != STOCKS_PER_SLOT
		):
			return false
	return true


func _controller_plan_matches(controllers: Array, local_team: int, local_slot: int) -> bool:
	if controllers.size() != TEAM_SIZE * 2 or _unique_controller_slots(controllers) != TEAM_SIZE * 2:
		return false
	var local_count := 0
	var ai_count := 0
	for assignment: Dictionary in controllers:
		var kind := String(assignment.get("kind", ""))
		var is_local_slot := (
			int(assignment.get("team", -1)) == local_team
			and int(assignment.get("slot_index", -1)) == local_slot
		)
		if kind == LOCAL_HUMAN:
			local_count += 1
			if not is_local_slot:
				return false
		elif kind == AI:
			ai_count += 1
			if is_local_slot:
				return false
		else:
			return false
	return local_count == 1 and ai_count == 5


func _unique_controller_slots(controllers: Array) -> int:
	var unique: Dictionary = {}
	for assignment: Dictionary in controllers:
		unique["%d:%d" % [
			int(assignment.get("team", -1)),
			int(assignment.get("slot_index", -1))
		]] = true
	return unique.size()


func _stock_total(slots: Array) -> int:
	var total := 0
	for slot: Dictionary in slots:
		total += int(slot.get("stocks_remaining", 0))
	return total


func _actor_state(actor: Node) -> Dictionary:
	return {
		"health": float(actor.health),
		"hunger": float(actor.hunger),
		"primary_timer": float(actor.primary_timer),
		"q_timer": float(actor.q_timer),
		"e_timer": float(actor.e_timer)
	}


func _actor_state_matches(expected: Dictionary, actual: Dictionary) -> bool:
	for key in expected:
		if not is_equal_approx(float(expected[key]), float(actual.get(key, INF))):
			return false
	return true


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
