extends RefCounted

const MAX_STOCKS := 3
const STATE_FIELD := "field"
const STATE_RESPAWNING := "respawning"
const STATE_EXHAUSTED := "exhausted"
const BREEDING_DURATION_SEC := 45.0

var slots: Dictionary = {}
var actor_keys: Dictionary = {}
var habitat_visits: Array[Dictionary] = []
var breeding_cues: Array[Dictionary] = []
var breeding_cue_sequence := 0
var required_team_size := 0
var configured_initial_stocks := MAX_STOCKS
var registration_sealed := false
var _validation_errors: Array[String] = []

func reset() -> void:
	slots.clear()
	actor_keys.clear()
	habitat_visits.clear()
	breeding_cues.clear()
	breeding_cue_sequence = 0
	required_team_size = 0
	configured_initial_stocks = MAX_STOCKS
	registration_sealed = false
	_validation_errors.clear()

func configure_required_slots(team_size: int, initial_stocks := MAX_STOCKS) -> bool:
	if registration_sealed:
		return _reject_registration("registration is already sealed")
	if not slots.is_empty():
		return _reject_registration("required slots must be configured before registering actors")
	if team_size <= 0:
		return _reject_registration("team size must be positive")
	if initial_stocks <= 0:
		return _reject_registration("initial stocks must be positive")
	required_team_size = team_size
	configured_initial_stocks = initial_stocks
	_validation_errors.clear()
	return true

func seal_registration() -> Array[String]:
	if registration_sealed:
		return []
	_validation_errors = _collect_registration_errors()
	if _validation_errors.is_empty():
		registration_sealed = true
	return validation_errors()

func is_registration_sealed() -> bool:
	return registration_sealed

func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func register_slot(team: int, slot_index: int, creature_id: String, actor: Node, max_stocks := -1) -> bool:
	if registration_sealed:
		return _reject_registration("registration is sealed")
	if creature_id.strip_edges().is_empty():
		return _reject_registration("creature id must not be empty")
	if not _is_alive_actor(actor):
		return _reject_registration("actor must be a valid live instance")
	if required_team_size > 0 and (team < 0 or team > 1):
		return _reject_registration("team must be 0 or 1")
	if required_team_size > 0 and (slot_index < 0 or slot_index >= required_team_size):
		return _reject_registration("slot index must be within the configured team size")
	var resolved_stocks := max_stocks
	if resolved_stocks < 0:
		resolved_stocks = configured_initial_stocks if required_team_size > 0 else MAX_STOCKS
	if resolved_stocks <= 0:
		return _reject_registration("stock count must be positive")
	if required_team_size > 0 and resolved_stocks != configured_initial_stocks:
		return _reject_registration("stock count must match the configured initial stock count")
	var key := _slot_key(team, slot_index)
	var actor_key := _actor_key(actor)
	var existing_actor_key := String(actor_keys.get(actor_key, ""))
	if not existing_actor_key.is_empty() and existing_actor_key != key:
		return _reject_registration("actor is already registered to another slot")
	if slots.has(key) and required_team_size > 0:
		return _reject_registration("slot is already registered")
	if not slots.has(key):
		slots[key] = {
			"team": team,
			"slot_index": slot_index,
			"slot_id": _slot_id(team, slot_index),
			"creature_id": creature_id,
			"actor": actor,
			"stocks_remaining": resolved_stocks,
			"max_stocks": resolved_stocks,
			"state": STATE_FIELD,
			"respawn_timer": 0.0
		}
	else:
		_erase_actor_mappings_for_slot(key)
		slots[key]["actor"] = actor
		slots[key]["slot_id"] = _slot_id(team, slot_index)
		slots[key]["creature_id"] = creature_id
	actor_keys[actor_key] = key
	_validation_errors.clear()
	return true

func update_actor(team: int, slot_index: int, actor: Node) -> bool:
	if not _is_valid_actor_identity(actor):
		return _reject_registration("replacement actor must be a valid instance")
	var key := _slot_key(team, slot_index)
	if not slots.has(key):
		return _reject_registration("slot is not registered")
	var actor_key := _actor_key(actor)
	var existing_key := String(actor_keys.get(actor_key, ""))
	if not existing_key.is_empty() and existing_key != key:
		return _reject_registration("actor is already registered to another slot")
	_erase_actor_mappings_for_slot(key)
	slots[key]["actor"] = actor
	actor_keys[actor_key] = key
	_validation_errors.clear()
	return true

func has_actor(actor: Node) -> bool:
	return _is_valid_actor_identity(actor) and not _key_for_actor(actor).is_empty()

func record_ko(actor: Node, respawn_duration: float) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) != STATE_FIELD:
		var duplicate_snapshot := slot.duplicate(true)
		duplicate_snapshot["consumed"] = false
		return duplicate_snapshot
	var stocks := maxi(0, int(slot.get("stocks_remaining", MAX_STOCKS)) - 1)
	slot["stocks_remaining"] = stocks
	slot["respawn_timer"] = maxf(respawn_duration, 0.0)
	slot["state"] = STATE_RESPAWNING if stocks > 0 else STATE_EXHAUSTED
	slots[key] = slot
	var consumed_snapshot := slot.duplicate(true)
	consumed_snapshot["consumed"] = true
	return consumed_snapshot

func tick_actor_respawn(actor: Node, delta: float) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) != STATE_RESPAWNING:
		return slot.duplicate(true)
	slot["respawn_timer"] = maxf(float(slot.get("respawn_timer", 0.0)) - delta, 0.0)
	slots[key] = slot
	return slot.duplicate(true)

func can_respawn(actor: Node) -> bool:
	var slot := get_slot_for_actor(actor)
	return not slot.is_empty() and String(slot.get("state", "")) == STATE_RESPAWNING and float(slot.get("respawn_timer", 0.0)) <= 0.0

func mark_respawned(actor: Node) -> void:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return
	var slot: Dictionary = slots[key]
	if String(slot.get("state", STATE_FIELD)) == STATE_RESPAWNING:
		slot["state"] = STATE_FIELD
		slot["respawn_timer"] = 0.0
		slots[key] = slot

func get_slot_for_actor(actor: Node) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty():
		return {}
	return slots[key].duplicate(true)

func get_slot(team: int, slot_index: int) -> Dictionary:
	var key := _slot_key(team, slot_index)
	if not slots.has(key):
		return {}
	return slots[key].duplicate(true)

func get_team_slots(team: int) -> Array[Dictionary]:
	var team_slots: Array[Dictionary] = []
	for slot: Dictionary in slots.values():
		if int(slot.get("team", -1)) == team:
			team_slots.append(slot.duplicate(true))
	team_slots.sort_custom(Callable(self, "_sort_slots_by_index"))
	return team_slots

func stocks_remaining(actor: Node) -> int:
	var slot := get_slot_for_actor(actor)
	if slot.is_empty():
		return 0
	return int(slot.get("stocks_remaining", 0))

func max_stocks(actor: Node) -> int:
	var slot := get_slot_for_actor(actor)
	if slot.is_empty():
		return 0
	return int(slot.get("max_stocks", 0))

func is_exhausted(actor: Node) -> bool:
	var slot := get_slot_for_actor(actor)
	return not slot.is_empty() and String(slot.get("state", "")) == STATE_EXHAUSTED

func team_exhausted(team: int) -> bool:
	if not registration_sealed or required_team_size <= 0 or (team != 0 and team != 1):
		return false
	for slot_index in range(required_team_size):
		var key := _slot_key(team, slot_index)
		if not slots.has(key):
			return false
		var slot: Dictionary = slots[key]
		if String(slot.get("state", STATE_FIELD)) != STATE_EXHAUSTED:
			return false
	return true

func record_habitat_visit(actor: Node) -> Dictionary:
	var slot := get_slot_for_actor(actor)
	if slot.is_empty():
		return {}
	var team := int(slot.get("team", -1))
	var slot_index := int(slot.get("slot_index", -1))
	var creature_id := String(slot.get("creature_id", ""))
	var family := _family_for_actor(actor)
	if _has_active_breeding_cue(team, creature_id):
		return {
			"accepted": false,
			"reason": "already_breeding",
			"team": team,
			"slot_index": slot_index,
			"creature_id": creature_id,
			"family": family,
			"actor": actor
		}
	var cue := {
		"accepted": true,
		"id": _next_breeding_cue_id(team, slot_index, creature_id),
		"team": team,
		"slot_index": slot_index,
		"creature_id": creature_id,
		"family": family,
		"actor": actor,
		"remaining": BREEDING_DURATION_SEC,
		"duration": BREEDING_DURATION_SEC
	}
	habitat_visits.append(cue.duplicate())
	breeding_cues.append(cue)
	return cue.duplicate(true)

func remove_breeding_cue(cue_id: String) -> Dictionary:
	if cue_id.is_empty():
		return {}
	for i in range(breeding_cues.size() - 1, -1, -1):
		if String(breeding_cues[i].get("id", "")) != cue_id:
			continue
		var cue := breeding_cues[i].duplicate(true)
		breeding_cues.remove_at(i)
		return cue
	return {}

func tick_breeding_cues(delta: float) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for i in range(breeding_cues.size() - 1, -1, -1):
		breeding_cues[i]["remaining"] = float(breeding_cues[i].get("remaining", 0.0)) - delta
		if float(breeding_cues[i]["remaining"]) <= 0.0:
			completed.append(breeding_cues[i].duplicate(true))
			breeding_cues.remove_at(i)
	completed.reverse()
	return completed

func get_breeding_cues(team := -1) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	for cue: Dictionary in breeding_cues:
		if team >= 0 and int(cue.get("team", -1)) != team:
			continue
		cues.append(cue.duplicate(true))
	return cues

func _key_for_actor(actor: Node) -> String:
	if not _is_valid_actor_identity(actor):
		return ""
	var key := String(actor_keys.get(_actor_key(actor), ""))
	if key.is_empty() or not slots.has(key):
		return ""
	var registered_actor: Node = slots[key].get("actor", null)
	if registered_actor != actor:
		return ""
	return key

func _collect_registration_errors() -> Array[String]:
	var errors: Array[String] = []
	if required_team_size <= 0:
		errors.append("required slots are not configured")
		return errors
	var seen_actor_keys: Dictionary = {}
	for team in range(2):
		for slot_index in range(required_team_size):
			var key := _slot_key(team, slot_index)
			if not slots.has(key):
				errors.append("missing required slot %s" % key)
				continue
			var slot: Dictionary = slots[key]
			if int(slot.get("team", -1)) != team or int(slot.get("slot_index", -1)) != slot_index:
				errors.append("slot %s has inconsistent team or index data" % key)
			if String(slot.get("slot_id", "")) != _slot_id(team, slot_index):
				errors.append("slot %s has an inconsistent stable slot id" % key)
			if String(slot.get("creature_id", "")).strip_edges().is_empty():
				errors.append("slot %s has an empty creature id" % key)
			if int(slot.get("max_stocks", 0)) != configured_initial_stocks:
				errors.append("slot %s has an invalid maximum stock count" % key)
			if int(slot.get("stocks_remaining", 0)) <= 0:
				errors.append("slot %s must begin with positive stocks" % key)
			var actor: Node = slot.get("actor", null)
			if not _is_alive_actor(actor):
				errors.append("slot %s has no valid live actor" % key)
				continue
			var actor_key := _actor_key(actor)
			if seen_actor_keys.has(actor_key):
				errors.append("actor is registered to multiple slots")
			seen_actor_keys[actor_key] = true
			if String(actor_keys.get(actor_key, "")) != key:
				errors.append("slot %s has an inconsistent actor lookup" % key)
	if slots.size() != required_team_size * 2:
		errors.append("registered slot count does not match the configured requirement")
	if actor_keys.size() != slots.size():
		errors.append("actor lookup count does not match registered slots")
	return errors

func _reject_registration(message: String) -> bool:
	_validation_errors.assign([message])
	return false

func _erase_actor_mappings_for_slot(key: String) -> void:
	for actor_key: Variant in actor_keys.keys():
		if String(actor_keys.get(actor_key, "")) == key:
			actor_keys.erase(actor_key)

func _is_valid_actor_identity(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	return true

func _is_alive_actor(actor: Node) -> bool:
	if not _is_valid_actor_identity(actor):
		return false
	if actor.has_method("is_alive") and not bool(actor.call("is_alive")):
		return false
	return true

func _has_active_breeding_cue(team: int, creature_id: String) -> bool:
	if creature_id.is_empty():
		return false
	for cue: Dictionary in breeding_cues:
		if int(cue.get("team", -1)) == team and String(cue.get("creature_id", "")) == creature_id:
			return true
	return false

func _family_for_actor(actor: Node) -> String:
	if actor == null:
		return ""
	var data_value: Variant = actor.get("creature_data")
	if typeof(data_value) == TYPE_DICTIONARY:
		var data: Dictionary = data_value
		return String(data.get("family", ""))
	return ""

func _next_breeding_cue_id(team: int, slot_index: int, creature_id: String) -> String:
	breeding_cue_sequence += 1
	return "%d:%d:%s:%d" % [team, slot_index, creature_id, breeding_cue_sequence]

func _actor_key(actor: Node) -> String:
	return str(actor.get_instance_id())

func _slot_key(team: int, slot_index: int) -> String:
	return "%d:%d" % [team, slot_index]

func _slot_id(team: int, slot_index: int) -> String:
	if team == 0:
		return "blue:%d" % slot_index
	if team == 1:
		return "red:%d" % slot_index
	return "team_%d:%d" % [team, slot_index]

func _sort_slots_by_index(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
