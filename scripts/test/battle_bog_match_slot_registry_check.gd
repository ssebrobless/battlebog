extends SceneTree

const MatchSlotRegistry := preload("res://scripts/game/match_slot_registry.gd")

const BLUE := 0
const RED := 1
const TEAM_SIZE := 3

func _initialize() -> void:
	var failures: Array[String] = []
	var six_slots_ok := _check_six_stable_slots(failures)
	var solo_ok := _check_solo_controller_plan(failures)
	var all_bots_ok := _check_all_bot_plan(failures)
	var rejection_ok := _check_rejections(failures)
	var duplicate_controller_ok := _check_duplicate_controller_id_rejection(failures)
	var null_actor_ok := _check_null_actor_rejection(failures)
	var sealed_ok := _check_seal_and_actor_replacement(failures)
	var transfer_ok := _check_atomic_controller_transfer(failures)
	var copy_ok := _check_copy_isolation(failures)
	var passed: bool = (
		six_slots_ok
		and solo_ok
		and all_bots_ok
		and rejection_ok
		and duplicate_controller_ok
		and null_actor_ok
		and sealed_ok
		and transfer_ok
		and copy_ok
	)

	print("match_slot_registry slots=%s solo=%s bots=%s rejection=%s duplicate_controller=%s null_actor=%s sealed=%s transfer=%s copy=%s" % [
		str(six_slots_ok),
		str(solo_ok),
		str(all_bots_ok),
		str(rejection_ok),
		str(duplicate_controller_ok),
		str(null_actor_ok),
		str(sealed_ok),
		str(transfer_ok),
		str(copy_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_six_stable_slots(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()
	var blue_slots: Array = registry.get_team_slots(BLUE)
	var red_slots: Array = registry.get_team_slots(RED)
	var plan: Array = registry.get_controller_plan()

	var order_ok: bool = (
		blue_slots.size() == TEAM_SIZE
		and red_slots.size() == TEAM_SIZE
		and plan.size() == TEAM_SIZE * 2
	)
	if order_ok:
		for index in TEAM_SIZE:
			order_ok = (
				order_ok
				and _slot_matches(blue_slots[index], BLUE, index)
				and _slot_matches(red_slots[index], RED, index)
				and _slot_matches(plan[index], BLUE, index)
				and _slot_matches(plan[TEAM_SIZE + index], RED, index)
			)

	var lookup_ok: bool = true
	for index in actors.size():
		var expected_team: int = BLUE if index < TEAM_SIZE else RED
		var expected_slot: int = index if index < TEAM_SIZE else index - TEAM_SIZE
		var slot: Dictionary = registry.get_slot(expected_team, expected_slot)
		var actor_slot: Dictionary = registry.get_slot_for_actor(actors[index])
		lookup_ok = (
			lookup_ok
			and _slot_matches(slot, expected_team, expected_slot)
			and _slot_matches(actor_slot, expected_team, expected_slot)
			and slot.get("actor") == actors[index]
			and not String(slot.get("creature_id", "")).is_empty()
			and not _controller_kind(slot).is_empty()
		)

	var ok: bool = (
		seal_errors.is_empty()
		and registry.is_sealed()
		and order_ok
		and lookup_ok
		and plan == registry.get_controller_plan()
	)
	if not ok:
		failures.append(
			"registry should seal exactly six stable slots in Blue0..2, Red0..2 order; "
			+ "errors=%s blue=%s red=%s plan=%s" % [
				str(seal_errors),
				str(blue_slots),
				str(red_slots),
				str(plan)
			]
		)
	_free_actors(actors)
	return ok

func _check_solo_controller_plan(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()
	var plan: Array = registry.get_controller_plan()
	var ok: bool = seal_errors.is_empty() and plan.size() == TEAM_SIZE * 2

	for index in actors.size():
		var expected: String = (
			MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
			if index == 0
			else MatchSlotRegistry.CONTROLLER_AI
		)
		var actor_controller: Dictionary = registry.controller_for_actor(actors[index])
		ok = (
			ok
			and String(actor_controller.get("kind", "")) == expected
			and String(plan[index].get("kind", "")) == expected
			and not String(plan[index].get("controller_id", "")).is_empty()
		)

	if not ok:
		failures.append(
			"solo plan should assign Blue0 to local_human and the other five slots to ai; "
			+ "errors=%s plan=%s" % [str(seal_errors), str(plan)]
		)
	_free_actors(actors)
	return ok

func _check_all_bot_plan(failures: Array[String]) -> bool:
	var fixture := _make_registry(true)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()
	var plan: Array = registry.get_controller_plan()
	var ok: bool = seal_errors.is_empty() and plan.size() == TEAM_SIZE * 2
	for actor in actors:
		var controller: Dictionary = registry.controller_for_actor(actor)
		ok = ok and String(controller.get("kind", "")) == MatchSlotRegistry.CONTROLLER_AI
	for entry in plan:
		ok = (
			ok
			and String(entry.get("kind", "")) == MatchSlotRegistry.CONTROLLER_AI
			and not String(entry.get("controller_id", "")).is_empty()
		)

	if not ok:
		failures.append(
			"all-bot plan should assign ai exactly once to every slot; errors=%s plan=%s"
			% [str(seal_errors), str(plan)]
		)
	_free_actors(actors)
	return ok

func _check_rejections(failures: Array[String]) -> bool:
	var missing_registry = MatchSlotRegistry.new()
	missing_registry.reset(TEAM_SIZE)
	var missing_actors := _make_actors(TEAM_SIZE * 2 - 1, "missing")
	for index in missing_actors.size():
		var team: int = BLUE if index < TEAM_SIZE else RED
		var slot_index: int = index if index < TEAM_SIZE else index - TEAM_SIZE
		missing_registry.register_slot(team, slot_index, "creature_%d" % index, missing_actors[index])
		missing_registry.assign_controller(
			team,
			slot_index,
			MatchSlotRegistry.CONTROLLER_AI,
			"missing_ai_%d" % index
		)
	var missing_errors: Array[String] = missing_registry.seal()
	var missing_ok: bool = not missing_errors.is_empty() and not missing_registry.is_sealed()

	var duplicate_registry = MatchSlotRegistry.new()
	duplicate_registry.reset(TEAM_SIZE)
	var duplicate_actors := _make_actors(3, "duplicate")
	duplicate_registry.register_slot(BLUE, 0, "newt", duplicate_actors[0])
	duplicate_registry.register_slot(BLUE, 0, "mink", duplicate_actors[1])
	var duplicate_slot_errors: Array[String] = duplicate_registry.validation_errors()
	duplicate_registry.register_slot(BLUE, 1, "owl", duplicate_actors[0])
	var duplicate_actor_errors: Array[String] = duplicate_registry.validation_errors()
	var duplicate_ok: bool = (
		not duplicate_slot_errors.is_empty()
		and not duplicate_actor_errors.is_empty()
		and duplicate_registry.get_slot(BLUE, 0).get("actor") == duplicate_actors[0]
		and duplicate_registry.get_slot(BLUE, 1).is_empty()
	)

	var invalid_registry = MatchSlotRegistry.new()
	invalid_registry.reset(TEAM_SIZE)
	var invalid_actor := Node.new()
	invalid_registry.register_slot(-1, 0, "newt", invalid_actor)
	var invalid_error_count: int = invalid_registry.validation_errors().size()
	invalid_registry.register_slot(BLUE, TEAM_SIZE, "newt", invalid_actor)
	invalid_error_count += invalid_registry.validation_errors().size()
	invalid_registry.register_slot(BLUE, 0, "", invalid_actor)
	invalid_error_count += invalid_registry.validation_errors().size()
	invalid_registry.assign_controller(BLUE, 0, "invalid_controller", "invalid")
	invalid_error_count += invalid_registry.validation_errors().size()
	invalid_registry.assign_controller(BLUE, 0, MatchSlotRegistry.CONTROLLER_AI, "")
	invalid_error_count += invalid_registry.validation_errors().size()
	var invalid_ok: bool = (
		invalid_error_count >= 5
		and invalid_registry.get_team_slots(BLUE).is_empty()
		and invalid_registry.get_team_slots(RED).is_empty()
	)

	var constants_ok: bool = (
		MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN == "local_human"
		and MatchSlotRegistry.CONTROLLER_AI == "ai"
		and MatchSlotRegistry.CONTROLLER_FUTURE_NETWORK == "future_network"
	)
	var ok: bool = missing_ok and duplicate_ok and invalid_ok and constants_ok
	if not ok:
		failures.append(
			"registry should reject missing, duplicate, and invalid slot/controller data; "
			+ "missing=%s duplicate=%s invalid=%s constants=%s" % [
				str(missing_errors),
				str(duplicate_slot_errors + duplicate_actor_errors),
				str(invalid_error_count),
				str(constants_ok)
			]
		)
	_free_actors(missing_actors)
	_free_actors(duplicate_actors)
	invalid_actor.free()
	return ok

func _check_duplicate_controller_id_rejection(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var reassigned: bool = registry.assign_controller(
		BLUE,
		1,
		MatchSlotRegistry.CONTROLLER_AI,
		"local_player_0"
	)
	var seal_errors: Array[String] = registry.seal()
	var duplicate_error_found := false
	for error in seal_errors:
		if error.contains("duplicate controller_id"):
			duplicate_error_found = true
			break
	var plan: Array = registry.get_controller_plan()
	var reused_count := 0
	for entry in plan:
		if String(entry.get("controller_id", "")) == "local_player_0":
			reused_count += 1
	var ok: bool = (
		reassigned
		and duplicate_error_found
		and not registry.is_sealed()
		and plan.size() == TEAM_SIZE * 2
		and reused_count == 2
	)
	if not ok:
		failures.append(
			"seal should reject a controller_id reused across two otherwise complete slots; "
			+ "reassigned=%s errors=%s sealed=%s reused=%d plan=%s" % [
				str(reassigned),
				str(seal_errors),
				str(registry.is_sealed()),
				reused_count,
				str(plan)
			]
		)
	_free_actors(actors)
	return ok

func _check_null_actor_rejection(failures: Array[String]) -> bool:
	var registry = MatchSlotRegistry.new()
	registry.reset(TEAM_SIZE)
	var registered: bool = registry.register_slot(BLUE, 0, "newt", null)
	var registration_errors: Array[String] = registry.validation_errors()
	var seal_errors: Array[String] = registry.seal()
	var ok: bool = (
		not registered
		and not registration_errors.is_empty()
		and registry.get_slot(BLUE, 0).is_empty()
		and not seal_errors.is_empty()
		and not registry.is_sealed()
	)
	if not ok:
		failures.append(
			"null actors must be rejected during registration and must not satisfy seal completeness; "
			+ "registered=%s registration_errors=%s seal_errors=%s slot=%s sealed=%s" % [
				str(registered),
				str(registration_errors),
				str(seal_errors),
				str(registry.get_slot(BLUE, 0)),
				str(registry.is_sealed())
			]
		)
	return ok

func _check_seal_and_actor_replacement(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()
	var original: Dictionary = registry.get_slot(BLUE, 1)
	var original_actor: Node = actors[1]
	var replacement := Node.new()
	replacement.name = "blue_1_replacement"

	registry.register_slot(BLUE, 1, "replacement_registration", replacement)
	var sealed_register_errors: Array[String] = registry.validation_errors()
	registry.assign_controller(
		BLUE,
		1,
		MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN,
		"replacement_human"
	)
	var sealed_assignment_errors: Array[String] = registry.validation_errors()
	var after_immutable_attempts: Dictionary = registry.get_slot(BLUE, 1)
	var immutable_ok: bool = (
		_slot_matches(after_immutable_attempts, BLUE, 1)
		and after_immutable_attempts.get("slot_id") == "blue:1"
		and after_immutable_attempts.get("creature_id") == original.get("creature_id")
		and after_immutable_attempts.get("actor") == original_actor
		and after_immutable_attempts.get("controller") == original.get("controller")
	)

	registry.update_actor(BLUE, 1, replacement)
	var updated: Dictionary = registry.get_slot(BLUE, 1)
	var stale_lookup: Dictionary = registry.get_slot_for_actor(original_actor)
	var replacement_lookup: Dictionary = registry.get_slot_for_actor(replacement)
	var replacement_ok: bool = (
		_slot_matches(updated, BLUE, 1)
		and updated.get("slot_id") == original.get("slot_id")
		and updated.get("creature_id") == original.get("creature_id")
		and updated.get("controller") == original.get("controller")
		and updated.get("actor") == replacement
		and stale_lookup.is_empty()
		and registry.controller_for_actor(original_actor).is_empty()
		and _slot_matches(replacement_lookup, BLUE, 1)
		and registry.controller_for_actor(replacement).get("kind") == _controller_kind(original)
	)
	var ok: bool = (
		seal_errors.is_empty()
		and registry.is_sealed()
		and immutable_ok
		and replacement_ok
		and not sealed_register_errors.is_empty()
		and not sealed_assignment_errors.is_empty()
	)
	if not ok:
		failures.append(
			"sealed registry should freeze slot/controller identity while permitting actor replacement; "
			+ "original=%s updated=%s stale=%s errors=%s" % [
				str(original),
				str(updated),
				str(stale_lookup),
				str(sealed_register_errors + sealed_assignment_errors)
			]
		)
	_free_actors(actors)
	replacement.free()
	return ok

func _check_atomic_controller_transfer(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()
	var initial_plan: Array = registry.get_controller_plan()
	var initial_blue_zero: Dictionary = registry.controller_for_actor(actors[0])
	var initial_blue_one: Dictionary = registry.controller_for_actor(actors[1])
	var blue_zero_slot: Dictionary = registry.get_slot(BLUE, 0)
	var blue_one_slot: Dictionary = registry.get_slot(BLUE, 1)
	var blue_zero_fallback: Dictionary = blue_zero_slot.get("ai_fallback", {})
	var blue_one_fallback: Dictionary = blue_one_slot.get("ai_fallback", {})
	var owner_zero := String(blue_zero_slot.get("owner_id", ""))
	var owner_one := String(blue_one_slot.get("owner_id", ""))

	var transferred: bool = registry.transfer_controller(BLUE, 0, 1)
	var transferred_plan: Array = registry.get_controller_plan()
	var blue_zero: Dictionary = registry.controller_for_actor(actors[0])
	var blue_one: Dictionary = registry.controller_for_actor(actors[1])
	var assignments_ok: bool = (
		String(initial_blue_zero.get("kind", "")) == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
		and String(initial_blue_one.get("kind", "")) == MatchSlotRegistry.CONTROLLER_AI
		and String(blue_zero.get("kind", "")) == MatchSlotRegistry.CONTROLLER_AI
		and String(blue_one.get("kind", "")) == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
		and blue_zero.get("controller_id") == blue_zero_fallback.get("controller_id")
		and blue_one.get("controller_id") == initial_blue_zero.get("controller_id")
		and registry.get_slot(BLUE, 0).get("owner_id") == owner_zero
		and registry.get_slot(BLUE, 1).get("owner_id") == owner_one
		and registry.get_slot(BLUE, 0).get("ai_fallback") == blue_zero_fallback
		and registry.get_slot(BLUE, 1).get("ai_fallback") == blue_one_fallback
	)
	var plan_ok: bool = transferred_plan.size() == TEAM_SIZE * 2
	var addresses: Dictionary = {}
	var local_human_count: int = 0
	for entry in transferred_plan:
		var address: String = "%d:%d" % [
			int(entry.get("team", -1)),
			int(entry.get("slot_index", -1))
		]
		addresses[address] = int(addresses.get(address, 0)) + 1
		if String(entry.get("kind", "")) == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN:
			local_human_count += 1
	for count in addresses.values():
		plan_ok = plan_ok and int(count) == 1
	plan_ok = (
		plan_ok
		and addresses.size() == TEAM_SIZE * 2
		and local_human_count == 1
	)

	var switched_back: bool = registry.transfer_controller(BLUE, 1, 0)
	var restored_plan: Array = registry.get_controller_plan()
	var switch_back_ok: bool = switched_back and restored_plan == initial_plan

	var before_invalid: Array = restored_plan.duplicate(true)
	var invalid_transfer: bool = registry.transfer_controller(BLUE, 0, 0)
	var invalid_errors: Array[String] = registry.validation_errors()
	var after_invalid: Array = registry.get_controller_plan()
	var invalid_ok: bool = (
		not invalid_transfer
		and not invalid_errors.is_empty()
		and after_invalid == before_invalid
	)

	registry.assign_controller(
		BLUE,
		0,
		MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN,
		"forbidden_direct_assignment"
	)
	var direct_assignment_errors: Array[String] = registry.validation_errors()
	var forbidden_actor := Node.new()
	registry.register_slot(BLUE, 0, "forbidden_roster_change", forbidden_actor)
	var roster_errors: Array[String] = registry.validation_errors()
	forbidden_actor.free()
	var sealed_plan_unchanged: bool = registry.get_controller_plan() == after_invalid

	var ok: bool = (
		seal_errors.is_empty()
		and initial_plan.size() == TEAM_SIZE * 2
		and transferred
		and assignments_ok
		and plan_ok
		and switch_back_ok
		and invalid_ok
		and not direct_assignment_errors.is_empty()
		and not roster_errors.is_empty()
		and sealed_plan_unchanged
	)
	if not ok:
		failures.append(
			(
				"post-seal transfer should move local control while preserving slot-bound AI "
				+ "fallbacks/owners, switch back cleanly, and reject invalid/direct mutations; "
				+ "initial=%s transferred=%s final=%s invalid_errors=%s assignment_errors=%s "
				+ "roster_errors=%s"
			) % [
				str(initial_plan),
				str(transferred),
				str(registry.get_controller_plan()),
				str(invalid_errors),
				str(direct_assignment_errors),
				str(roster_errors)
			]
		)
	_free_actors(actors)
	return ok

func _check_copy_isolation(failures: Array[String]) -> bool:
	var fixture := _make_registry(false)
	var registry = fixture["registry"]
	var actors: Array[Node] = fixture["actors"]
	var seal_errors: Array[String] = registry.seal()

	var slot: Dictionary = registry.get_slot(BLUE, 0)
	var team_slots: Array = registry.get_team_slots(BLUE)
	var plan: Array = registry.get_controller_plan()
	slot["creature_id"] = "mutated"
	slot["controller"]["kind"] = "mutated"
	team_slots[0]["controller"]["kind"] = "mutated"
	team_slots.clear()
	plan[0]["kind"] = "mutated"
	plan.clear()

	var fresh_slot: Dictionary = registry.get_slot(BLUE, 0)
	var fresh_team_slots: Array = registry.get_team_slots(BLUE)
	var fresh_plan: Array = registry.get_controller_plan()
	var ok: bool = (
		seal_errors.is_empty()
		and fresh_slot.get("creature_id") == "blue_0"
		and _controller_kind(fresh_slot) == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
		and fresh_team_slots.size() == TEAM_SIZE
		and _controller_kind(fresh_team_slots[0]) == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
		and fresh_plan.size() == TEAM_SIZE * 2
		and fresh_plan[0].get("kind") == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
	)
	if not ok:
		failures.append(
			"registry query results should be deep-copy isolated; slot=%s team=%s plan=%s"
			% [str(fresh_slot), str(fresh_team_slots), str(fresh_plan)]
		)
	_free_actors(actors)
	return ok

func _make_registry(all_bots: bool) -> Dictionary:
	var registry = MatchSlotRegistry.new()
	registry.reset(TEAM_SIZE)
	var actors := _make_actors(TEAM_SIZE * 2, "valid")
	for team in [BLUE, RED]:
		for slot_index in TEAM_SIZE:
			var team_index: int = int(team)
			var actor_index: int = team_index * TEAM_SIZE + slot_index
			var creature_id: String = "%s_%d" % ["blue" if team_index == BLUE else "red", slot_index]
			registry.register_slot(team_index, slot_index, creature_id, actors[actor_index])
			var controller: String = MatchSlotRegistry.CONTROLLER_AI
			if not all_bots and team_index == BLUE and slot_index == 0:
				controller = MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
			var controller_id: String = (
				"local_player_0"
				if controller == MatchSlotRegistry.CONTROLLER_LOCAL_HUMAN
				else "ai_%d_%d" % [team_index, slot_index]
			)
			registry.assign_ai_fallback(
				team_index,
				slot_index,
				"ai_%d_%d" % [team_index, slot_index]
			)
			registry.assign_controller(team_index, slot_index, controller, controller_id)
	return {
		"registry": registry,
		"actors": actors
	}

func _make_actors(count: int, prefix: String) -> Array[Node]:
	var actors: Array[Node] = []
	for index in count:
		var actor := Node.new()
		actor.name = "%s_actor_%d" % [prefix, index]
		actors.append(actor)
	return actors

func _free_actors(actors: Array[Node]) -> void:
	for actor in actors:
		if is_instance_valid(actor):
			actor.free()

func _slot_matches(value: Variant, team: int, slot_index: int) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var slot: Dictionary = value
	return (
		int(slot.get("team", -1)) == team
		and int(slot.get("slot_index", -1)) == slot_index
		and String(slot.get("slot_id", "")) == _expected_slot_id(team, slot_index)
	)

func _controller_kind(slot: Dictionary) -> String:
	var controller: Dictionary = slot.get("controller", {})
	return String(controller.get("kind", ""))

func _expected_slot_id(team: int, slot_index: int) -> String:
	return "%s:%d" % ["blue" if team == BLUE else "red", slot_index]
