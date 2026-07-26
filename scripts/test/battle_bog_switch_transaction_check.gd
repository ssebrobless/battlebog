extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BLUE := 0
const TEAM_SIZE := 3
const LOCAL_HUMAN := "local_human"
const AI := "ai"
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const ACTION_BUTTONS := (
	InputFrameScript.BUTTON_PRIMARY
	| InputFrameScript.BUTTON_ABILITY_Q
	| InputFrameScript.BUTTON_ABILITY_E
)


class ActionLocalInput:
	extends Node

	func build_frame(aim: Vector2) -> Resource:
		var frame: Resource = InputFrameScript.new()
		frame.move = Vector2(0.5, -0.25)
		frame.aim = aim
		frame.buttons = ACTION_BUTTONS
		return frame


class ActionBotBrain:
	extends RefCounted

	var action_actor_ids: Dictionary = {}

	func mark_actor(actor: Node) -> void:
		action_actor_ids[actor.get_instance_id()] = true

	func build_frame(actor: Node, _allow_autonomous_deposit := true, _order: Dictionary = {}) -> Resource:
		var frame: Resource = InputFrameScript.new()
		frame.move = Vector2(-0.25, 0.5)
		frame.aim = actor.global_position + Vector2.RIGHT * 64.0
		frame.buttons = ACTION_BUTTONS if action_actor_ids.has(actor.get_instance_id()) else 0
		return frame

	func reset_actor(_actor: Node) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("switch transaction check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	config.selected_mode = "Play vs AI"
	config.set_selected_squad_ids(TEST_SQUAD)
	config.selected_creature_id = TEST_SQUAD[0]
	config.wake_boss = false
	config.center_boss = false

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		_restore_config(config, original_config)
		push_error("switch transaction check failed to boot Arena: error=%d" % error)
		quit(1)
		return
	await process_frame
	await physics_frame
	await process_frame

	var arena := current_scene
	if arena == null:
		_restore_config(config, original_config)
		push_error("switch transaction check could not inspect Arena")
		quit(1)
		return

	var initial_ok := _check_blue_control_contract(arena, 0, "initial", failures)
	var original_local_input: Node = arena.local_input
	var original_bot_brain: RefCounted = arena.bot_brain
	var action_local := ActionLocalInput.new()
	arena.local_input = action_local

	var forward_ok := await _check_successful_switch(
		arena,
		original_bot_brain,
		0,
		1,
		"forward",
		failures
	)
	var backward_ok := await _check_successful_switch(
		arena,
		original_bot_brain,
		1,
		0,
		"backward",
		failures
	)
	var rejected_registry_ok := _check_rejected_registry_transfers(arena, failures)
	var lifecycle_rejection_ok := _check_lifecycle_rejections(arena, failures)

	arena.local_input = original_local_input
	arena.bot_brain = original_bot_brain
	action_local.free()
	_restore_config(config, original_config)

	var passed := (
		initial_ok
		and forward_ok
		and backward_ok
		and rejected_registry_ok
		and lifecycle_rejection_ok
	)
	print(
		"switch_transaction initial=%s forward=%s backward=%s registry_rejections=%s lifecycle_rejections=%s"
		% [
			str(initial_ok),
			str(forward_ok),
			str(backward_ok),
			str(rejected_registry_ok),
			str(lifecycle_rejection_ok)
		]
	)
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _check_successful_switch(
	arena: Node,
	brain: RefCounted,
	from_index: int,
	to_index: int,
	label: String,
	failures: Array[String]
) -> bool:
	var from_actor: Node = arena.player_squad[from_index]
	var to_actor: Node = arena.player_squad[to_index]
	_seed_brain_caches(brain, from_actor, to_actor)

	arena.bot_brain = brain
	arena._set_active_squad_index(to_index, false)

	var contract_ok := _check_blue_control_contract(arena, to_index, label, failures)
	var immediate_ok: bool = (
		arena.active_squad_index == to_index
		and arena.player == to_actor
		and int(arena.switch_action_neutral_ticks.get(from_actor.get_instance_id(), 0)) == 1
		and int(arena.switch_action_neutral_ticks.get(to_actor.get_instance_id(), 0)) == 1
	)
	var caches_ok := _brain_caches_clear(brain, from_actor) \
		and _brain_caches_clear(brain, to_actor)
	if not immediate_ok:
		failures.append(
			(
				"%s switch should atomically update player/index and schedule one neutral tick; "
				+ "index=%d player=%s tokens=%s"
			)
			% [
				label,
				arena.active_squad_index,
				str(arena.player),
				str(arena.switch_action_neutral_ticks)
			]
		)
	if not caches_ok:
		failures.append("%s switch should clear BotBrain caches for both transitioned actors" % label)

	var action_brain := ActionBotBrain.new()
	action_brain.mark_actor(from_actor)
	arena.bot_brain = action_brain
	arena._feed_registered_inputs()

	var from_frame: Resource = from_actor.input_frame
	var to_frame: Resource = to_actor.input_frame
	var neutral_frames_ok := (
		from_frame != null
		and to_frame != null
		and int(from_frame.buttons) == 0
		and int(to_frame.buttons) == 0
	)
	var tokens_consumed_ok: bool = (
		not arena.switch_action_neutral_ticks.has(from_actor.get_instance_id())
		and not arena.switch_action_neutral_ticks.has(to_actor.get_instance_id())
	)
	var routing_ok := _routing_is_valid_and_side_effect_free(
		arena.get_input_routing_state(),
		label,
		failures
	)
	if not neutral_frames_ok or not tokens_consumed_ok:
		failures.append(
			(
				"%s switch should route one action-neutral frame to both actors and consume both "
				+ "tokens; from_buttons=%s to_buttons=%s tokens=%s"
			)
			% [
				label,
				str(from_frame.buttons if from_frame != null else null),
				str(to_frame.buttons if to_frame != null else null),
				str(arena.switch_action_neutral_ticks)
			]
		)
	arena.bot_brain = brain
	return contract_ok and immediate_ok and caches_ok \
		and neutral_frames_ok and tokens_consumed_ok and routing_ok


func _check_rejected_registry_transfers(arena: Node, failures: Array[String]) -> bool:
	var plan_before_same: Array = arena.slot_registry.get_controller_plan()
	var same_slot_accepted: bool = arena.slot_registry.transfer_controller(BLUE, 0, 0)
	var same_slot_ok: bool = (
		not same_slot_accepted
		and arena.slot_registry.get_controller_plan() == plan_before_same
	)

	var plan_before_nonlocal: Array = arena.slot_registry.get_controller_plan()
	var nonlocal_accepted: bool = arena.slot_registry.transfer_controller(BLUE, 1, 2)
	var nonlocal_ok: bool = (
		not nonlocal_accepted
		and arena.slot_registry.get_controller_plan() == plan_before_nonlocal
	)
	if not same_slot_ok or not nonlocal_ok:
		failures.append(
			"same-slot and source-not-local transfers must fail without changing the controller "
			+ "plan; same=%s nonlocal=%s plan=%s"
			% [
				str(same_slot_ok),
				str(nonlocal_ok),
				str(arena.slot_registry.get_controller_plan())
			]
		)
	return same_slot_ok and nonlocal_ok


func _check_lifecycle_rejections(arena: Node, failures: Array[String]) -> bool:
	var respawning_actor: Node = arena.player_squad[1]
	respawning_actor.health = 0.0
	var respawn_result: Dictionary = arena.stock_manager.record_ko(respawning_actor, 10.0)
	respawning_actor.alive = false
	var before_respawn := _transaction_snapshot(arena)
	arena._set_active_squad_index(1, false)
	var after_respawn := _transaction_snapshot(arena)
	var respawning_ok: bool = (
		String(respawn_result.get("state", "")) == "respawning"
		and arena.squad_switch_feedback_state == "respawning"
		and before_respawn == after_respawn
	)

	var exhausted_actor: Node = arena.player_squad[2]
	exhausted_actor.health = 0.0
	while arena.stock_manager.stocks_remaining(exhausted_actor) > 0:
		arena.stock_manager.mark_respawned(exhausted_actor)
		arena.stock_manager.record_ko(exhausted_actor, 10.0)
	exhausted_actor.alive = false
	var exhausted_slot: Dictionary = arena.stock_manager.get_slot_for_actor(exhausted_actor)
	var before_exhausted := _transaction_snapshot(arena)
	arena._set_active_squad_index(2, false)
	var after_exhausted := _transaction_snapshot(arena)
	var exhausted_ok: bool = (
		String(exhausted_slot.get("state", "")) == "exhausted"
		and arena.squad_switch_feedback_state == "exhausted"
		and before_exhausted == after_exhausted
	)

	if not respawning_ok or not exhausted_ok:
		failures.append(
			(
				"respawning/exhausted switch attempts need distinct feedback and no plan/player/index/"
				+ "release-mask mutation; respawning=%s exhausted=%s before_respawn=%s "
				+ "after_respawn=%s before_exhausted=%s after_exhausted=%s"
			)
			% [
				str(respawning_ok),
				str(exhausted_ok),
				str(before_respawn),
				str(after_respawn),
				str(before_exhausted),
				str(after_exhausted)
			]
		)
	return respawning_ok and exhausted_ok


func _check_blue_control_contract(
	arena: Node,
	local_index: int,
	label: String,
	failures: Array[String]
) -> bool:
	var slots: Array = arena.slot_registry.get_team_slots(BLUE)
	var ok := slots.size() == TEAM_SIZE
	for index in TEAM_SIZE:
		if index >= slots.size():
			break
		var slot: Dictionary = slots[index]
		var controller: Dictionary = slot.get("controller", {})
		var fallback: Dictionary = slot.get("ai_fallback", {})
		var expected_kind := LOCAL_HUMAN if index == local_index else AI
		var expected_controller_id := "local:0" if index == local_index else "ai:0:%d" % index
		ok = (
			ok
			and String(slot.get("owner_id", "")) == "local:0"
			and String(fallback.get("kind", "")) == AI
			and String(fallback.get("controller_id", "")) == "ai:0:%d" % index
			and String(controller.get("kind", "")) == expected_kind
			and String(controller.get("controller_id", "")) == expected_controller_id
		)
	if not ok:
		failures.append(
			(
				"%s expected local:0 on Blue%d with immutable local ownership and slot-bound "
				+ "ai:0:N fallbacks; slots=%s"
			)
			% [label, local_index, str(slots)]
		)
	return ok


func _seed_brain_caches(brain: RefCounted, first: Node, second: Node) -> void:
	for actor: Node in [first, second]:
		var key := int(actor.get_instance_id())
		brain.sticky_targets[key] = second if actor == first else first
		brain.retreating_actors[key] = true
		brain.intent_cache[key] = {"mode": "fight", "target": second if actor == first else first}
		brain.intent_cache_frames[key] = Engine.get_physics_frames()


func _brain_caches_clear(brain: RefCounted, actor: Node) -> bool:
	var key := int(actor.get_instance_id())
	return (
		not brain.sticky_targets.has(key)
		and not brain.retreating_actors.has(key)
		and not brain.intent_cache.has(key)
		and not brain.intent_cache_frames.has(key)
	)


func _routing_is_valid_and_side_effect_free(
	state: Dictionary,
	label: String,
	failures: Array[String]
) -> bool:
	var actor_ids: Array = state.get("actor_ids", [])
	var unique_ids: Dictionary = {}
	for actor_id in actor_ids:
		unique_ids[String(actor_id)] = true
	var ok := (
		bool(state.get("sealed", false))
		and bool(state.get("routing_valid", false))
		and int(state.get("assignments", -1)) == TEAM_SIZE * 2
		and int(state.get("routed", -1)) == TEAM_SIZE * 2
		and int(state.get("duplicates", -1)) == 0
		and int(state.get("unsupported", -1)) == 0
		and int(state.get("committed_actions", -1)) == 0
		and int(state.get("local", -1)) == 1
		and int(state.get("ai", -1)) == 5
		and actor_ids.size() == TEAM_SIZE * 2
		and unique_ids.size() == TEAM_SIZE * 2
	)
	if not ok:
		failures.append(
			(
				"%s neutral tick expected six unique valid routes and zero committed side effects; "
				+ "routing=%s"
			)
			% [label, str(state)]
		)
	return ok


func _transaction_snapshot(arena: Node) -> Dictionary:
	return {
		"plan": arena.slot_registry.get_controller_plan(),
		"player_id": arena.player.get_instance_id() if arena.player != null else 0,
		"active_index": int(arena.active_squad_index),
		"release_mask": int(arena.switch_release_mask)
	}


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
