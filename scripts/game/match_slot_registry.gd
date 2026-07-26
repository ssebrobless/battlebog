extends RefCounted

const TEAM_BLUE := 0
const TEAM_RED := 1
const TEAMS := [TEAM_BLUE, TEAM_RED]

const CONTROLLER_LOCAL_HUMAN := "local_human"
const CONTROLLER_AI := "ai"
const CONTROLLER_FUTURE_NETWORK := "future_network"
const CONTROLLER_KINDS := [
	CONTROLLER_LOCAL_HUMAN,
	CONTROLLER_AI,
	CONTROLLER_FUTURE_NETWORK
]

var _team_size := 3
var _slots: Dictionary = {}
var _actor_slots: Dictionary = {}
var _sealed := false
var _errors: Array[String] = []


func _init() -> void:
	reset()


func reset(team_size := 3) -> void:
	_slots.clear()
	_actor_slots.clear()
	_sealed = false
	_errors.clear()
	if int(team_size) <= 0:
		_team_size = 0
		_errors.append("team_size must be greater than zero")
		return
	_team_size = int(team_size)


func register_slot(
	team: int,
	slot_index: int,
	creature_id: String,
	actor: Object
) -> bool:
	_errors.clear()
	if not _can_mutate():
		return false
	if not _validate_address(team, slot_index):
		return false
	var key := _slot_key(team, slot_index)
	if _slots.has(key):
		_errors.append("slot is already registered: %s" % key)
		return false
	var normalized_creature_id := creature_id.strip_edges()
	if normalized_creature_id.is_empty():
		_errors.append("creature_id must not be empty")
		return false
	if not _validate_new_actor(actor, key):
		return false

	var actor_instance_id := _actor_instance_id(actor)
	_slots[key] = {
		"team": team,
		"slot_index": slot_index,
		"slot_id": _slot_id(team, slot_index),
		"creature_id": normalized_creature_id,
		"actor": actor,
		"actor_instance_id": actor_instance_id,
		"owner_id": "team:%s" % _slot_id(team, slot_index).get_slice(":", 0),
		"ai_fallback": {
			"kind": CONTROLLER_AI,
			"controller_id": "ai:%s" % _slot_id(team, slot_index)
		},
		"controller": {}
	}
	if actor_instance_id != 0:
		_actor_slots[actor_instance_id] = key
	return true


func assign_controller(
	team: int,
	slot_index: int,
	kind: String,
	controller_id: String
) -> bool:
	_errors.clear()
	if not _can_mutate():
		return false
	if not _validate_address(team, slot_index):
		return false
	var key := _slot_key(team, slot_index)
	if not _slots.has(key):
		_errors.append("cannot assign a controller to an unregistered slot: %s" % key)
		return false
	var normalized_kind := kind.strip_edges()
	if not CONTROLLER_KINDS.has(normalized_kind):
		_errors.append("unknown controller kind: %s" % normalized_kind)
		return false
	var normalized_controller_id := controller_id.strip_edges()
	if normalized_controller_id.is_empty():
		_errors.append("controller_id must not be empty")
		return false

	var slot: Dictionary = _slots[key]
	slot["controller"] = {
		"kind": normalized_kind,
		"controller_id": normalized_controller_id
	}
	_slots[key] = slot
	return true


func assign_owner(team: int, slot_index: int, owner_id: String) -> bool:
	_errors.clear()
	if not _can_mutate():
		return false
	if not _validate_address(team, slot_index):
		return false
	var key := _slot_key(team, slot_index)
	if not _slots.has(key):
		_errors.append("cannot assign an owner to an unregistered slot: %s" % key)
		return false
	var normalized_owner_id := owner_id.strip_edges()
	if normalized_owner_id.is_empty():
		_errors.append("owner_id must not be empty")
		return false
	var slot: Dictionary = _slots[key]
	slot["owner_id"] = normalized_owner_id
	_slots[key] = slot
	return true


func assign_ai_fallback(team: int, slot_index: int, controller_id: String) -> bool:
	_errors.clear()
	if not _can_mutate():
		return false
	if not _validate_address(team, slot_index):
		return false
	var key := _slot_key(team, slot_index)
	if not _slots.has(key):
		_errors.append("cannot assign an AI fallback to an unregistered slot: %s" % key)
		return false
	var normalized_controller_id := controller_id.strip_edges()
	if normalized_controller_id.is_empty():
		_errors.append("AI fallback controller_id must not be empty")
		return false
	var slot: Dictionary = _slots[key]
	slot["ai_fallback"] = {
		"kind": CONTROLLER_AI,
		"controller_id": normalized_controller_id
	}
	_slots[key] = slot
	return true


func transfer_controller(team: int, from_slot: int, to_slot: int) -> bool:
	_errors.clear()
	if not _sealed:
		_errors.append("controller transfer requires a sealed registry")
		return false
	if not _validate_address(team, from_slot):
		return false
	if not _validate_address(team, to_slot):
		return false
	if from_slot == to_slot:
		_errors.append("controller transfer requires two different slots")
		return false

	var from_key := _slot_key(team, from_slot)
	var to_key := _slot_key(team, to_slot)
	if not _slots.has(from_key):
		_errors.append("controller transfer source is not registered: %s" % from_key)
		return false
	if not _slots.has(to_key):
		_errors.append("controller transfer target is not registered: %s" % to_key)
		return false

	var from_entry: Dictionary = _slots[from_key]
	var to_entry: Dictionary = _slots[to_key]
	var from_controller: Dictionary = from_entry.get("controller", {})
	var to_controller: Dictionary = to_entry.get("controller", {})
	if not _is_complete_controller(from_controller):
		_errors.append("controller transfer source has no complete assignment: %s" % from_key)
		return false
	if not _is_complete_controller(to_controller):
		_errors.append("controller transfer target has no complete assignment: %s" % to_key)
		return false
	if String(from_controller.get("kind", "")) != CONTROLLER_LOCAL_HUMAN:
		_errors.append("controller transfer source is not locally controlled: %s" % from_key)
		return false
	if String(to_controller.get("kind", "")) != CONTROLLER_AI:
		_errors.append("controller transfer target is not AI controlled: %s" % to_key)
		return false
	var from_fallback: Dictionary = from_entry.get("ai_fallback", {})
	var to_fallback: Dictionary = to_entry.get("ai_fallback", {})
	if not _is_complete_ai_fallback(from_fallback):
		_errors.append("controller transfer source has no complete AI fallback: %s" % from_key)
		return false
	if not _is_complete_ai_fallback(to_fallback) or to_controller != to_fallback:
		_errors.append("controller transfer target is not using its slot-bound AI fallback: %s" % to_key)
		return false
	if String(from_entry.get("owner_id", "")) != String(to_entry.get("owner_id", "")):
		_errors.append("controller transfer requires slots with the same owner")
		return false

	from_entry["controller"] = from_fallback.duplicate(true)
	to_entry["controller"] = from_controller.duplicate(true)
	_slots[from_key] = from_entry
	_slots[to_key] = to_entry
	return true


func seal() -> Array[String]:
	if _sealed:
		_errors.clear()
		return []
	_errors = _collect_validation_errors()
	if _errors.is_empty():
		_sealed = true
	return _errors.duplicate()


func is_sealed() -> bool:
	return _sealed


func get_slot(team: int, slot_index: int) -> Dictionary:
	if not _is_valid_address(team, slot_index):
		return {}
	var key := _slot_key(team, slot_index)
	if not _slots.has(key):
		return {}
	return _slot_snapshot(_slots[key])


func get_slot_for_actor(actor: Object) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty() or not _slots.has(key):
		return {}
	return _slot_snapshot(_slots[key])


func get_team_slots(team: int) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if not TEAMS.has(team):
		return snapshots
	for slot_index in range(_team_size):
		var key := _slot_key(team, slot_index)
		if _slots.has(key):
			snapshots.append(_slot_snapshot(_slots[key]))
	return snapshots


func get_controller_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for team in TEAMS:
		for slot_index in range(_team_size):
			var key := _slot_key(team, slot_index)
			if not _slots.has(key):
				continue
			var slot: Dictionary = _slots[key]
			var controller: Dictionary = slot.get("controller", {})
			if controller.is_empty():
				continue
			plan.append({
				"team": team,
				"slot_index": slot_index,
				"slot_id": _slot_id(team, slot_index),
				"kind": String(controller.get("kind", "")),
				"controller_id": String(controller.get("controller_id", ""))
			})
	return plan.duplicate(true)


func controller_for_actor(actor: Object) -> Dictionary:
	var key := _key_for_actor(actor)
	if key.is_empty() or not _slots.has(key):
		return {}
	var slot: Dictionary = _slots[key]
	var controller: Dictionary = slot.get("controller", {})
	if controller.is_empty():
		return {}
	return {
		"team": int(slot.get("team", -1)),
		"slot_index": int(slot.get("slot_index", -1)),
		"slot_id": String(slot.get("slot_id", "")),
		"kind": String(controller.get("kind", "")),
		"controller_id": String(controller.get("controller_id", ""))
	}.duplicate(true)


func update_actor(team: int, slot_index: int, actor: Object) -> bool:
	_errors.clear()
	if not _validate_address(team, slot_index):
		return false
	var key := _slot_key(team, slot_index)
	if not _slots.has(key):
		_errors.append("cannot update an unregistered slot: %s" % key)
		return false
	if not _validate_new_actor(actor, key):
		return false

	var slot: Dictionary = _slots[key]
	var previous_instance_id := int(slot.get("actor_instance_id", 0))
	if previous_instance_id != 0:
		_actor_slots.erase(previous_instance_id)
	var actor_instance_id := _actor_instance_id(actor)
	slot["actor"] = actor
	slot["actor_instance_id"] = actor_instance_id
	_slots[key] = slot
	if actor_instance_id != 0:
		_actor_slots[actor_instance_id] = key
	return true


func validation_errors() -> Array[String]:
	return _errors.duplicate()


func _can_mutate() -> bool:
	if not _sealed:
		return true
	_errors.append("registry is sealed")
	return false


func _validate_address(team: int, slot_index: int) -> bool:
	if not TEAMS.has(team):
		_errors.append("invalid team: %d" % team)
		return false
	if slot_index < 0 or slot_index >= _team_size:
		_errors.append("invalid slot index for team %d: %d" % [team, slot_index])
		return false
	return true


func _is_valid_address(team: int, slot_index: int) -> bool:
	return TEAMS.has(team) and slot_index >= 0 and slot_index < _team_size


func _validate_new_actor(actor: Object, target_key: String) -> bool:
	if actor == null or not is_instance_valid(actor):
		_errors.append("actor must be a valid Object")
		return false
	var actor_instance_id := actor.get_instance_id()
	if not _actor_slots.has(actor_instance_id):
		return true
	var existing_key := String(_actor_slots[actor_instance_id])
	if existing_key == target_key:
		return true
	_errors.append("actor is already registered to slot: %s" % existing_key)
	return false


func _collect_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var controller_slots: Dictionary = {}
	var fallback_slots: Dictionary = {}
	if _team_size <= 0:
		errors.append("team_size must be greater than zero")
		return errors
	for team in TEAMS:
		for slot_index in range(_team_size):
			var key := _slot_key(team, slot_index)
			if not _slots.has(key):
				errors.append("missing registered slot: %s" % key)
				continue
			var slot: Dictionary = _slots[key]
			var expected_slot_id := _slot_id(team, slot_index)
			if String(slot.get("slot_id", "")) != expected_slot_id:
				errors.append("invalid slot_id for slot %s" % key)
			var actor: Object = slot.get("actor")
			if actor == null or not is_instance_valid(actor):
				errors.append("missing valid actor for slot: %s" % key)
			else:
				var actor_instance_id := actor.get_instance_id()
				if int(slot.get("actor_instance_id", 0)) != actor_instance_id:
					errors.append("actor instance id mismatch for slot: %s" % key)
				elif String(_actor_slots.get(actor_instance_id, "")) != key:
					errors.append("actor lookup mismatch for slot: %s" % key)
			var owner_id := String(slot.get("owner_id", ""))
			if owner_id.is_empty():
				errors.append("missing owner_id for slot: %s" % key)
			var ai_fallback: Dictionary = slot.get("ai_fallback", {})
			if not _is_complete_ai_fallback(ai_fallback):
				errors.append("missing AI fallback for slot: %s" % key)
			else:
				var fallback_id := String(ai_fallback.get("controller_id", ""))
				if fallback_slots.has(fallback_id):
					errors.append(
						"duplicate AI fallback for slots %s and %s: %s"
						% [String(fallback_slots[fallback_id]), key, fallback_id]
					)
				else:
					fallback_slots[fallback_id] = key
			var controller: Dictionary = slot.get("controller", {})
			if controller.is_empty():
				errors.append("missing controller assignment: %s" % key)
				continue
			var kind := String(controller.get("kind", ""))
			var controller_id := String(controller.get("controller_id", ""))
			if not CONTROLLER_KINDS.has(kind):
				errors.append("invalid controller kind for slot %s: %s" % [key, kind])
			if kind == CONTROLLER_AI and controller != ai_fallback:
				errors.append("AI controller does not match slot fallback: %s" % key)
			if controller_id.is_empty():
				errors.append("empty controller_id for slot: %s" % key)
			elif controller_slots.has(controller_id):
				errors.append(
					"duplicate controller_id for slots %s and %s: %s"
					% [String(controller_slots[controller_id]), key, controller_id]
				)
			else:
				controller_slots[controller_id] = key
	if _actor_slots.size() != _slots.size():
		errors.append("actor lookup count does not match registered slot count")
	return errors


func _is_complete_controller(controller: Dictionary) -> bool:
	var kind := String(controller.get("kind", ""))
	var controller_id := String(controller.get("controller_id", ""))
	return CONTROLLER_KINDS.has(kind) and not controller_id.is_empty()


func _is_complete_ai_fallback(controller: Dictionary) -> bool:
	return String(controller.get("kind", "")) == CONTROLLER_AI \
		and not String(controller.get("controller_id", "")).is_empty()


func _key_for_actor(actor: Object) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	return String(_actor_slots.get(actor.get_instance_id(), ""))


func _actor_instance_id(actor: Object) -> int:
	if actor == null or not is_instance_valid(actor):
		return 0
	return actor.get_instance_id()


func _slot_snapshot(slot: Dictionary) -> Dictionary:
	return slot.duplicate(true)


func _slot_key(team: int, slot_index: int) -> String:
	return "%d:%d" % [team, slot_index]


func _slot_id(team: int, slot_index: int) -> String:
	var team_id := "blue" if team == TEAM_BLUE else "red"
	return "%s:%d" % [team_id, slot_index]
