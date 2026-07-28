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
const SWITCH_TIMELINE_CONFIG := {
	"startup": 10.0,
	"active": 0.1,
	"recovery": {
		"hit": 0.1,
		"whiff": 0.1,
		"released": 0.1,
		"interrupted": 0.1,
	},
	"movement_mult": {
		"startup": 1.0,
		"active": 1.0,
		"recovery": 1.0,
	},
	"blocks_abilities": {
		"startup": false,
		"active": false,
		"recovery": false,
	},
	"phase_tags": {
		"startup": [],
		"active": [],
		"recovery": [],
	},
	"cooldown_sec": 10.0,
}


class ActionLocalInput:
	extends Node

	var buttons := ACTION_BUTTONS

	func build_frame(aim: Vector2) -> Resource:
		var frame: Resource = InputFrameScript.new()
		frame.move = Vector2(0.5, -0.25)
		frame.aim = aim
		frame.buttons = buttons
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


class NoopResolver:
	extends RefCounted

	func resolve() -> Dictionary:
		return {"outcome": "whiff", "hit_count": 0}


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
	var unregistered_reset_ok := _check_unregistered_actor_reset(
		original_bot_brain,
		failures
	)
	var invalid_routing_suppression_ok := _check_invalid_routing_suppression(
		arena,
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
		and unregistered_reset_ok
		and invalid_routing_suppression_ok
		and rejected_registry_ok
		and lifecycle_rejection_ok
	)
	print(
		"switch_transaction initial=%s forward=%s backward=%s invalid_routing=%s registry_rejections=%s lifecycle_rejections=%s"
		% [
			str(initial_ok),
			str(forward_ok),
			str(backward_ok),
			str(invalid_routing_suppression_ok),
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
	var timeline_data: Dictionary = from_actor.creature_data.duplicate(true)
	var timeline_stats: Dictionary = timeline_data.get("stats", {}).duplicate(true)
	timeline_stats["action_timelines"] = {
		"switch_probe": SWITCH_TIMELINE_CONFIG.duplicate(true),
	}
	timeline_data["stats"] = timeline_stats
	from_actor.creature_data = timeline_data
	from_actor.stats = timeline_stats
	var target_timeline_data: Dictionary = to_actor.creature_data.duplicate(true)
	var target_timeline_stats: Dictionary = target_timeline_data.get("stats", {}).duplicate(true)
	target_timeline_stats["action_timelines"] = {
		"switch_probe": SWITCH_TIMELINE_CONFIG.duplicate(true),
	}
	target_timeline_data["stats"] = target_timeline_stats
	to_actor.creature_data = target_timeline_data
	to_actor.stats = target_timeline_stats
	var source_was_committed: bool = from_actor.is_primary_attack_committed()
	var target_was_committed: bool = to_actor.is_primary_attack_committed()
	if not source_was_committed:
		from_actor.primary_timer = 0.0
	if not target_was_committed:
		to_actor.primary_timer = 0.0
	var source_resolver := NoopResolver.new()
	var target_resolver := NoopResolver.new()
	var source_timeline_accepted := false
	if not source_was_committed:
		source_timeline_accepted = from_actor.request_primary_attack(
			"switch_probe",
			{"label": label, "role": "source"},
			Callable(source_resolver, "resolve")
		)
	var target_timeline_accepted := false
	if not target_was_committed:
		target_timeline_accepted = to_actor.request_primary_attack(
			"switch_probe",
			{"label": label, "role": "target"},
			Callable(target_resolver, "resolve")
		)
	var source_sequence_before := int(
		from_actor.get_primary_attack_snapshot().get("attack_sequence_id", 0)
	)
	var target_sequence_before := int(
		to_actor.get_primary_attack_snapshot().get("attack_sequence_id", 0)
	)

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
	var source_timeline_after_switch: Dictionary = from_actor.get_primary_attack_snapshot()
	var target_timeline_after_switch: Dictionary = to_actor.get_primary_attack_snapshot()
	var timeline_switch_ok: bool = (
		(source_was_committed or source_timeline_accepted)
		and (target_was_committed or target_timeline_accepted)
		and from_actor.is_primary_attack_committed()
		and to_actor.is_primary_attack_committed()
		and int(source_timeline_after_switch.get("attack_sequence_id", 0))
			== source_sequence_before
		and int(target_timeline_after_switch.get("attack_sequence_id", 0))
			== target_sequence_before
		and int(source_timeline_after_switch.get("attack_started_tick", -1)) >= 0
		and int(source_timeline_after_switch.get("attack_started_tick", -1))
			<= int(arena.simulation_tick)
		and int(target_timeline_after_switch.get("attack_started_tick", -1)) >= 0
		and int(target_timeline_after_switch.get("attack_started_tick", -1))
			<= int(arena.simulation_tick)
	)
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
	if not timeline_switch_ok:
		failures.append(
			"%s switch must preserve both committed attack timelines; source=%d/%s target=%d/%s"
			% [
				label,
				source_sequence_before,
				str(source_timeline_after_switch),
				target_sequence_before,
				str(target_timeline_after_switch),
			]
		)

	var action_brain := ActionBotBrain.new()
	action_brain.mark_actor(from_actor)
	arena.bot_brain = action_brain
	arena._feed_registered_inputs()

	var from_frame: Resource = from_actor.input_frame
	var to_frame: Resource = to_actor.input_frame
	var source_timeline_after_neutral: Dictionary = from_actor.get_primary_attack_snapshot()
	var target_timeline_after_neutral: Dictionary = to_actor.get_primary_attack_snapshot()
	var timelines_survive_neutral: bool = (
		from_actor.is_primary_attack_committed()
		and to_actor.is_primary_attack_committed()
		and int(source_timeline_after_neutral.get("attack_sequence_id", 0))
			== source_sequence_before
		and int(target_timeline_after_neutral.get("attack_sequence_id", 0))
			== target_sequence_before
	)
	var neutral_frames_ok: bool = (
		from_frame != null
		and to_frame != null
		and int(from_frame.buttons) == 0
		and int(to_frame.buttons) == 0
		and int(from_frame.suppressed_buttons) == int(arena.SWITCH_RELEASE_BUTTONS)
		and int(to_frame.suppressed_buttons) == int(arena.SWITCH_RELEASE_BUTTONS)
		and not from_frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
		and not to_frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
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
				str(
					{
						"buttons": from_frame.buttons,
						"suppressed": from_frame.suppressed_buttons,
					}
					if from_frame != null
					else null
				),
				str(
					{
						"buttons": to_frame.buttons,
						"suppressed": to_frame.suppressed_buttons,
					}
					if to_frame != null
					else null
				),
				str(arena.switch_action_neutral_ticks)
			]
		)
	if not timelines_survive_neutral:
		failures.append(
			"%s action-neutral transfer frame must not cancel either committed timeline"
			% label
		)

	arena._feed_registered_inputs()
	var held_gate_frame: Resource = to_actor.input_frame
	var held_gate_ok: bool = (
		held_gate_frame != null
		and int(held_gate_frame.buttons) == 0
		and int(held_gate_frame.suppressed_buttons) == ACTION_BUTTONS
		and not held_gate_frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
		and int(arena.switch_release_mask) == ACTION_BUTTONS
	)
	if not held_gate_ok:
		failures.append(
			"%s held switch-release gate should suppress exactly held action bits; frame=%s mask=%d"
			% [
				label,
				str(
					{
						"buttons": held_gate_frame.buttons,
						"suppressed": held_gate_frame.suppressed_buttons,
					}
					if held_gate_frame != null
					else null
				),
				int(arena.switch_release_mask),
			]
		)

	var action_local: ActionLocalInput = arena.local_input
	action_local.buttons = 0
	arena._feed_registered_inputs()
	var released_frame: Resource = to_actor.input_frame
	var genuine_release_ok: bool = (
		released_frame != null
		and int(released_frame.buttons) == 0
		and int(released_frame.suppressed_buttons) == 0
		and released_frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
		and int(arena.switch_release_mask) == 0
	)
	action_local.buttons = ACTION_BUTTONS
	if not genuine_release_ok:
		failures.append(
			"%s physical button-up should clear the gate and remain intentional; frame=%s mask=%d"
			% [
				label,
				str(
					{
						"buttons": released_frame.buttons,
						"suppressed": released_frame.suppressed_buttons,
					}
					if released_frame != null
					else null
				),
				int(arena.switch_release_mask),
			]
		)
	arena.bot_brain = brain
	return contract_ok and immediate_ok and caches_ok and timeline_switch_ok \
		and neutral_frames_ok and tokens_consumed_ok and routing_ok \
		and timelines_survive_neutral and held_gate_ok and genuine_release_ok


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


func _check_invalid_routing_suppression(
	arena: Node,
	failures: Array[String]
) -> bool:
	var frame: Resource = arena._invalid_routing_frame()
	var ok: bool = frame != null \
		and int(frame.buttons) == 0 \
		and int(frame.suppressed_buttons) == int(arena.SWITCH_RELEASE_BUTTONS) \
		and not frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY) \
		and not frame.is_intentional_release(InputFrameScript.BUTTON_ABILITY_Q) \
		and not frame.is_intentional_release(InputFrameScript.BUTTON_ABILITY_E)
	if not ok:
		failures.append(
			"invalid routing fallback must be an action-suppressed blank frame; frame=%s"
			% str(
				{
					"buttons": frame.buttons,
					"suppressed": frame.suppressed_buttons,
				}
				if frame != null
				else null
			)
		)
	return ok


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
		brain.actor_slot_ids[key] = "seeded:%d" % key


func _brain_caches_clear(brain: RefCounted, actor: Node) -> bool:
	var key := int(actor.get_instance_id())
	return (
		not brain.sticky_targets.has(key)
		and not brain.retreating_actors.has(key)
		and not brain.intent_cache.has(key)
		and not brain.intent_cache_frames.has(key)
		and not brain.actor_slot_ids.has(key)
	)


func _check_unregistered_actor_reset(
	brain: RefCounted,
	failures: Array[String]
) -> bool:
	var actor := Node2D.new()
	get_root().add_child(actor)
	_seed_brain_caches(brain, actor, actor)
	brain.reset_actor(actor)
	var ok := _brain_caches_clear(brain, actor)
	if not ok:
		failures.append(
			"reset_actor must clear every cache, including actor_slot_ids, for a valid actor "
			+ "that was never registered to a match slot"
		)
	actor.free()
	return ok


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
