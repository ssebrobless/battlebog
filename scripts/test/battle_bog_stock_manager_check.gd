extends SceneTree

const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

class FakeActor extends Node:
	var team: int
	var creature_id: String
	var creature_data: Dictionary
	var alive := true

	func _init(new_team := 0, new_creature_id := "") -> void:
		team = new_team
		creature_id = new_creature_id
		creature_data = {"family": "%s_family" % new_creature_id}

	func is_alive() -> bool:
		return alive

func _initialize() -> void:
	var failures: Array[String] = []
	var registration_ok := _check_canonical_registration(failures)
	var rejection_ok := _check_registration_rejections(failures)
	var lifecycle_ok := _check_ko_respawn_and_exhaustion(failures)
	var replacement_ok := _check_sealed_actor_update(failures)
	var habitat_ok := _check_habitat_and_unknown_actor(failures)
	var reset_ok := _check_reset(failures)
	var passed := registration_ok \
		and rejection_ok \
		and lifecycle_ok \
		and replacement_ok \
		and habitat_ok \
		and reset_ok

	print("stock_manager registration=%s rejection=%s lifecycle=%s replacement=%s habitat=%s reset=%s" % [
		str(registration_ok),
		str(rejection_ok),
		str(lifecycle_ok),
		str(replacement_ok),
		str(habitat_ok),
		str(reset_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_canonical_registration(failures: Array[String]) -> bool:
	var fixture := _canonical_fixture()
	var manager = fixture["manager"]
	var blue: Array = fixture["blue"]
	var red: Array = fixture["red"]
	var before_seal_ok: bool = not manager.is_registration_sealed() \
		and not manager.team_exhausted(0) \
		and not manager.team_exhausted(1)
	var seal_errors: Array[String] = manager.seal_registration()
	var blue_slots: Array[Dictionary] = manager.get_team_slots(0)
	var red_slots: Array[Dictionary] = manager.get_team_slots(1)
	var ok: bool = before_seal_ok \
		and seal_errors.is_empty() \
		and manager.is_registration_sealed() \
		and manager.slots.size() == 6 \
		and manager.actor_keys.size() == 6 \
		and blue_slots.size() == 3 \
		and red_slots.size() == 3 \
		and _slot_has_canonical_state(blue_slots[0], 0, 0, "blue:0", blue[0]) \
		and _slot_has_canonical_state(blue_slots[2], 0, 2, "blue:2", blue[2]) \
		and _slot_has_canonical_state(red_slots[0], 1, 0, "red:0", red[0]) \
		and _slot_has_canonical_state(red_slots[2], 1, 2, "red:2", red[2]) \
		and manager.seal_registration().is_empty()
	if not ok:
		failures.append("registration expected six canonical slots sealed with stable IDs; errors=%s blue=%s red=%s" % [
			str(seal_errors),
			str(blue_slots),
			str(red_slots)
		])
	return ok

func _check_registration_rejections(failures: Array[String]) -> bool:
	var manager = StockManagerScript.new()
	var configured: bool = manager.configure_required_slots(3, 3)
	var valid := _actor(0, "beaver")
	var dead := _actor(0, "newt")
	dead.alive = false
	var null_actor: Node = null
	var invalid_ok: bool = configured \
		and not manager.register_slot(0, 0, "", valid) \
		and not manager.register_slot(-1, 0, "beaver", valid) \
		and not manager.register_slot(2, 0, "beaver", valid) \
		and not manager.register_slot(0, -1, "beaver", valid) \
		and not manager.register_slot(0, 3, "beaver", valid) \
		and not manager.register_slot(0, 0, "beaver", null_actor) \
		and not manager.register_slot(0, 0, "newt", dead) \
		and not manager.register_slot(0, 0, "beaver", valid, 2)

	var first_registered: bool = manager.register_slot(0, 0, "beaver", valid)
	var duplicate_slot: bool = manager.register_slot(0, 0, "newt", _actor(0, "newt"))
	var duplicate_actor: bool = manager.register_slot(0, 1, "beaver", valid)
	var incomplete_errors: Array[String] = manager.seal_registration()
	var incomplete_ok: bool = not incomplete_errors.is_empty() \
		and not manager.is_registration_sealed() \
		and not manager.team_exhausted(0)

	var fixture := _canonical_fixture()
	var sealed_manager = fixture["manager"]
	var sealed_ok: bool = sealed_manager.seal_registration().is_empty()
	var post_seal_actor := _actor(0, "otter")
	var post_seal_rejected: bool = not sealed_manager.register_slot(0, 0, "otter", post_seal_actor)
	var reconfigure_rejected: bool = not sealed_manager.configure_required_slots(3, 3)
	var ok: bool = invalid_ok \
		and first_registered \
		and not duplicate_slot \
		and not duplicate_actor \
		and incomplete_ok \
		and sealed_ok \
		and post_seal_rejected \
		and reconfigure_rejected
	if not ok:
		failures.append("registration rejection expected invalid, duplicate, null, incomplete, and post-seal mutations to fail; incomplete=%s validation=%s" % [
			str(incomplete_errors),
			str(manager.validation_errors())
		])
	return ok

func _check_ko_respawn_and_exhaustion(failures: Array[String]) -> bool:
	var fixture := _canonical_fixture()
	var manager = fixture["manager"]
	var blue: Array = fixture["blue"]
	manager.seal_registration()
	var active: FakeActor = blue[0]

	var first_ko: Dictionary = manager.record_ko(active, 1.5)
	active.alive = false
	var duplicate_ko: Dictionary = manager.record_ko(active, 9.0)
	var stored_respawning: Dictionary = manager.get_slot_for_actor(active)
	var dead_addressable_ok: bool = manager.has_actor(active) \
		and manager.stocks_remaining(active) == 2 \
		and bool(first_ko.get("consumed", false)) \
		and not bool(duplicate_ko.get("consumed", true)) \
		and int(duplicate_ko.get("stocks_remaining", -1)) == 2 \
		and absf(float(duplicate_ko.get("respawn_timer", -1.0)) - 1.5) < 0.001 \
		and not stored_respawning.has("consumed") \
		and not manager.get_slot(0, 0).has("consumed")
	var ticked: Dictionary = manager.tick_actor_respawn(active, 0.5)
	var ready: Dictionary = manager.tick_actor_respawn(active, 1.1)
	var tick_ok: bool = absf(float(ticked.get("respawn_timer", -1.0)) - 1.0) < 0.001 \
		and absf(float(ready.get("respawn_timer", -1.0))) < 0.001 \
		and manager.can_respawn(active)

	active.alive = true
	manager.mark_respawned(active)
	var respawned: Dictionary = manager.get_slot_for_actor(active)
	var respawned_ok: bool = String(respawned.get("state", "")) == StockManagerScript.STATE_FIELD \
		and int(respawned.get("stocks_remaining", -1)) == 2 \
		and absf(float(respawned.get("respawn_timer", -1.0))) < 0.001

	var exhaustion_steps_ok: bool = _exhaust_slot(manager, blue[0]) \
		and not manager.team_exhausted(0) \
		and _exhaust_slot(manager, blue[1]) \
		and not manager.team_exhausted(0) \
		and _exhaust_slot(manager, blue[2]) \
		and manager.team_exhausted(0) \
		and not manager.team_exhausted(1) \
		and not manager.team_exhausted(99)
	var duplicate_exhausted: Dictionary = manager.record_ko(blue[0], 9.0)
	var stored_exhausted: Dictionary = manager.get_slot_for_actor(blue[0])
	var exhausted_duplicate_ok: bool = not bool(duplicate_exhausted.get("consumed", true)) \
		and int(duplicate_exhausted.get("stocks_remaining", -1)) == 0 \
		and String(duplicate_exhausted.get("state", "")) == StockManagerScript.STATE_EXHAUSTED \
		and not stored_exhausted.has("consumed") \
		and _stored_slots_exclude_consumed(manager)
	var ok: bool = int(first_ko.get("stocks_remaining", -1)) == 2 \
		and String(first_ko.get("state", "")) == StockManagerScript.STATE_RESPAWNING \
		and dead_addressable_ok \
		and tick_ok \
		and respawned_ok \
		and exhaustion_steps_ok \
		and exhausted_duplicate_ok
	if not ok:
		failures.append("lifecycle expected transient consumed flags, canonical stored slots, dead actor ticking, respawn, and three-slot exhaustion; first=%s duplicate=%s exhausted_duplicate=%s stored_respawning=%s stored_exhausted=%s ticked=%s ready=%s respawned=%s" % [
			str(first_ko),
			str(duplicate_ko),
			str(duplicate_exhausted),
			str(stored_respawning),
			str(stored_exhausted),
			str(ticked),
			str(ready),
			str(respawned)
		])
	return ok

func _check_sealed_actor_update(failures: Array[String]) -> bool:
	var fixture := _canonical_fixture()
	var manager = fixture["manager"]
	var blue: Array = fixture["blue"]
	manager.seal_registration()
	var original: FakeActor = blue[1]
	var damaged_state: Dictionary = manager.record_ko(original, 2.0)
	original.alive = false
	var replacement := _actor(0, "chorus_frog")
	var updated: bool = manager.update_actor(0, 1, replacement)
	var slot: Dictionary = manager.get_slot_for_actor(replacement)
	replacement.alive = false
	var ticked: Dictionary = manager.tick_actor_respawn(replacement, 0.75)
	var ok: bool = updated \
		and manager.get_slot_for_actor(original).is_empty() \
		and not manager.has_actor(original) \
		and manager.has_actor(replacement) \
		and String(slot.get("slot_id", "")) == "blue:1" \
		and String(slot.get("creature_id", "")) == "chorus_frog" \
		and int(slot.get("stocks_remaining", -1)) == int(damaged_state.get("stocks_remaining", -2)) \
		and String(slot.get("state", "")) == String(damaged_state.get("state", "missing")) \
		and absf(float(slot.get("respawn_timer", -1.0)) - 2.0) < 0.001 \
		and absf(float(ticked.get("respawn_timer", -1.0)) - 1.25) < 0.001
	if not ok:
		failures.append("replacement expected sealed slot identity and lifecycle state to transfer while stale actor lookup was removed; damaged=%s slot=%s ticked=%s" % [
			str(damaged_state),
			str(slot),
			str(ticked)
		])
	return ok

func _check_habitat_and_unknown_actor(failures: Array[String]) -> bool:
	var fixture := _canonical_fixture()
	var manager = fixture["manager"]
	var blue: Array = fixture["blue"]
	manager.seal_registration()
	var visit: Dictionary = manager.record_habitat_visit(blue[0])
	var duplicate_visit: Dictionary = manager.record_habitat_visit(blue[0])
	var completed: Array[Dictionary] = manager.tick_breeding_cues(StockManagerScript.BREEDING_DURATION_SEC)
	var known_ok: bool = bool(visit.get("accepted", false)) \
		and String(visit.get("slot_id", "")).is_empty() \
		and int(visit.get("team", -1)) == 0 \
		and int(visit.get("slot_index", -1)) == 0 \
		and String(visit.get("creature_id", "")) == "beaver" \
		and String(visit.get("family", "")) == "beaver_family" \
		and not bool(duplicate_visit.get("accepted", true)) \
		and String(duplicate_visit.get("reason", "")) == "already_breeding" \
		and completed.size() == 1 \
		and manager.get_breeding_cues().is_empty()

	var unknown := _actor(0, "otter")
	var unknown_visit: Dictionary = manager.record_habitat_visit(unknown)
	var unknown_ok: bool = manager.stocks_remaining(unknown) == 0 \
		and manager.max_stocks(unknown) == 0 \
		and manager.record_ko(unknown, 1.0).is_empty() \
		and manager.tick_actor_respawn(unknown, 1.0).is_empty() \
		and unknown_visit.is_empty() \
		and manager.habitat_visits.size() == 1 \
		and manager.breeding_cues.is_empty()
	var ok: bool = known_ok and unknown_ok
	if not ok:
		failures.append("habitat expected registered breeding lifecycle and no stock/deposit/breed authority for unknown actors; visit=%s duplicate=%s completed=%s unknown=%s" % [
			str(visit),
			str(duplicate_visit),
			str(completed),
			str(unknown_visit)
		])
	return ok

func _check_reset(failures: Array[String]) -> bool:
	var fixture := _canonical_fixture()
	var manager = fixture["manager"]
	var blue: Array = fixture["blue"]
	manager.seal_registration()
	manager.record_habitat_visit(blue[0])
	manager.reset()
	var ok: bool = manager.slots.is_empty() \
		and manager.actor_keys.is_empty() \
		and manager.habitat_visits.is_empty() \
		and manager.breeding_cues.is_empty() \
		and manager.required_team_size == 0 \
		and manager.configured_initial_stocks == StockManagerScript.MAX_STOCKS \
		and not manager.is_registration_sealed() \
		and manager.validation_errors().is_empty() \
		and not manager.team_exhausted(0)
	if not ok:
		failures.append("reset expected all lifecycle data, canonical configuration, and seal state to clear")
	return ok

func _canonical_fixture() -> Dictionary:
	var manager = StockManagerScript.new()
	manager.configure_required_slots(3, 3)
	var blue: Array = [
		_actor(0, "beaver"),
		_actor(0, "chorus_frog"),
		_actor(0, "newt")
	]
	var red: Array = [
		_actor(1, "mink"),
		_actor(1, "owl"),
		_actor(1, "otter")
	]
	for slot_index in range(3):
		manager.register_slot(0, slot_index, blue[slot_index].creature_id, blue[slot_index])
		manager.register_slot(1, slot_index, red[slot_index].creature_id, red[slot_index])
	return {
		"manager": manager,
		"blue": blue,
		"red": red
	}

func _slot_has_canonical_state(
	slot: Dictionary,
	team: int,
	slot_index: int,
	slot_id: String,
	actor: FakeActor
) -> bool:
	return int(slot.get("team", -1)) == team \
		and int(slot.get("slot_index", -1)) == slot_index \
		and String(slot.get("slot_id", "")) == slot_id \
		and slot.get("actor", null) == actor \
		and int(slot.get("stocks_remaining", -1)) == 3 \
		and int(slot.get("max_stocks", -1)) == 3 \
		and String(slot.get("state", "")) == StockManagerScript.STATE_FIELD \
		and absf(float(slot.get("respawn_timer", -1.0))) < 0.001

func _exhaust_slot(manager, actor: FakeActor) -> bool:
	while manager.stocks_remaining(actor) > 0:
		var result: Dictionary = manager.record_ko(actor, 0.0)
		if result.is_empty() or not bool(result.get("consumed", false)):
			return false
		if manager.stocks_remaining(actor) > 0:
			manager.mark_respawned(actor)
	return manager.is_exhausted(actor)

func _stored_slots_exclude_consumed(manager) -> bool:
	for team in range(2):
		for slot: Dictionary in manager.get_team_slots(team):
			if slot.has("consumed"):
				return false
	return true

func _actor(team: int, creature_id: String) -> FakeActor:
	var actor := FakeActor.new(team, creature_id)
	get_root().add_child(actor)
	return actor
