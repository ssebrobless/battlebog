extends RefCounted

enum Phase {
	IDLE,
	STARTUP,
	ACTIVE,
	RECOVERY,
}

enum Outcome {
	NONE,
	HIT,
	WHIFF,
	RELEASED,
	INTERRUPTED,
}

const _PHASE_NAMES := {
	Phase.IDLE: "idle",
	Phase.STARTUP: "startup",
	Phase.ACTIVE: "active",
	Phase.RECOVERY: "recovery",
}
const _OUTCOME_NAMES := {
	Outcome.NONE: "none",
	Outcome.HIT: "hit",
	Outcome.WHIFF: "whiff",
	Outcome.RELEASED: "released",
	Outcome.INTERRUPTED: "interrupted",
}
const _RECOVERY_KEYS := ["hit", "whiff", "released", "interrupted"]
const _POLICY_PHASES := ["startup", "active", "recovery"]
var _phase: Phase = Phase.IDLE
var _outcome: Outcome = Outcome.NONE
var _phase_elapsed := 0.0
var _phase_duration := 0.0
var _durations: Dictionary = {}
var _movement_multipliers: Dictionary = {}
var _ability_blocks: Dictionary = {}
var _recovery_allows_dash_cancel := false
var _phase_tags: Dictionary = {}
var _payload: Dictionary = {}
var _strike_heading := Vector2.RIGHT
var _sequence_counter := 0
var _attack_sequence_id := 0
var _attack_started_tick := -1
var _attack_active_tick := -1
var _attack_interrupted_tick := -1
var _active_resolved := false
var _hit_count := 0
var _hit_region: Variant = ""
var _interruption_reason := ""


func start(
	config: Dictionary,
	payload: Dictionary,
	strike_direction: Vector2,
	simulation_tick: int,
	time_scale: float
) -> bool:
	if not is_idle() \
		or simulation_tick < 0 \
		or not strike_direction.is_finite() \
		or strike_direction.is_zero_approx() \
		or not _is_positive_finite(time_scale):
		return false

	var normalized := normalize_config(config)
	if normalized.is_empty():
		return false
	var payload_copy_result := _copy_value_data(payload)
	if not bool(payload_copy_result["valid"]):
		return false

	_sequence_counter += 1
	_attack_sequence_id = _sequence_counter
	_attack_started_tick = simulation_tick
	_attack_active_tick = -1
	_attack_interrupted_tick = -1
	_outcome = Outcome.NONE
	_payload = payload_copy_result["value"]
	_strike_heading = strike_direction.normalized()
	_hit_count = 0
	_hit_region = ""
	_interruption_reason = ""
	_active_resolved = false

	_durations = normalized["durations"].duplicate(true)
	for key: String in _durations:
		_durations[key] = float(_durations[key]) / time_scale
	_movement_multipliers = normalized["movement_multipliers"].duplicate(true)
	_ability_blocks = normalized["ability_blocks"].duplicate(true)
	_recovery_allows_dash_cancel = bool(normalized["recovery_allows_dash_cancel"])
	_phase_tags = normalized["phase_tags"].duplicate(true)
	_enter_phase(Phase.STARTUP, float(_durations["startup"]))
	return true


func advance(
	delta: float,
	simulation_tick: int,
	active_resolver: Callable
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_idle() \
		or simulation_tick < 0 \
		or not _is_positive_finite(delta):
		return events

	var advancing_sequence := _attack_sequence_id
	var remaining := delta
	while remaining > 0.0 \
		and not is_idle() \
		and _attack_sequence_id == advancing_sequence:
		var until_boundary := maxf(0.0, _phase_duration - _phase_elapsed)
		if remaining < until_boundary:
			_phase_elapsed += remaining
			remaining = 0.0
			break

		_phase_elapsed = _phase_duration
		remaining = maxf(0.0, remaining - until_boundary)
		_complete_phase(simulation_tick, active_resolver, events)
	return events


func interrupt(reason: String, simulation_tick: int, hard := false) -> Dictionary:
	if is_idle() or simulation_tick < 0:
		var ignored := snapshot()
		ignored["event"] = "interrupt_ignored"
		ignored["changed"] = false
		ignored["hard"] = hard
		return ignored

	if hard:
		var hard_event := snapshot()
		hard_event["attack_outcome"] = Outcome.INTERRUPTED
		hard_event["attack_outcome_name"] = _OUTCOME_NAMES[Outcome.INTERRUPTED]
		hard_event["attack_interrupted_tick"] = simulation_tick
		hard_event["interruption_reason"] = reason
		hard_event["event"] = "hard_interrupted"
		hard_event["changed"] = true
		hard_event["hard"] = true
		hard_event["interrupted_sequence_id"] = _attack_sequence_id
		reset()
		return hard_event

	if _phase != Phase.STARTUP:
		var protected := snapshot()
		protected["event"] = "interrupt_ignored"
		protected["changed"] = false
		protected["hard"] = false
		return protected

	_outcome = Outcome.INTERRUPTED
	_interruption_reason = reason
	_attack_interrupted_tick = simulation_tick
	_enter_phase(Phase.RECOVERY, float(_durations["interrupted"]))
	var event := _event("interrupted")
	event["changed"] = true
	event["hard"] = false
	return event


func reset() -> void:
	_phase = Phase.IDLE
	_outcome = Outcome.NONE
	_phase_elapsed = 0.0
	_phase_duration = 0.0
	_durations.clear()
	_movement_multipliers.clear()
	_ability_blocks.clear()
	_recovery_allows_dash_cancel = false
	_phase_tags.clear()
	_payload.clear()
	_strike_heading = Vector2.RIGHT
	_attack_sequence_id = 0
	_attack_started_tick = -1
	_attack_active_tick = -1
	_attack_interrupted_tick = -1
	_active_resolved = false
	_hit_count = 0
	_hit_region = ""
	_interruption_reason = ""


func snapshot() -> Dictionary:
	return {
		"attack_phase": _phase,
		"attack_phase_name": _PHASE_NAMES[_phase],
		"phase_t": _phase_progress(),
		"attack_outcome": _outcome,
		"attack_outcome_name": _OUTCOME_NAMES[_outcome],
		"attack_sequence_id": _attack_sequence_id,
		"attack_started_tick": _attack_started_tick,
		"attack_active_tick": _attack_active_tick,
		"attack_interrupted_tick": _attack_interrupted_tick,
		"strike_heading": _strike_heading,
		"payload": _payload.duplicate(true),
		"hit_count": _hit_count,
		"hit_region": _copy_variant(_hit_region),
		"interruption_reason": _interruption_reason,
	}


func is_idle() -> bool:
	return _phase == Phase.IDLE


func current_phase_name() -> StringName:
	return StringName(_PHASE_NAMES[_phase])


func movement_multiplier() -> float:
	if is_idle():
		return 1.0
	return float(_movement_multipliers.get(_PHASE_NAMES[_phase], 1.0))


func blocks_abilities() -> bool:
	if is_idle():
		return false
	return bool(_ability_blocks.get(_PHASE_NAMES[_phase], false))

func recovery_allows_dash_cancel() -> bool:
	return _phase == Phase.RECOVERY and _recovery_allows_dash_cancel


func has_phase_tag(tag: String) -> bool:
	if tag.is_empty() or is_idle():
		return false
	var tags: Array = _phase_tags.get(_PHASE_NAMES[_phase], [])
	return tags.has(tag)


static func normalize_config(config: Dictionary) -> Dictionary:
	var duration_value: Variant = config.get("durations", {})
	var duration_source: Dictionary = duration_value if typeof(duration_value) == TYPE_DICTIONARY else {}
	var startup_value: Variant = config.get("startup", config.get("startup_duration", duration_source.get("startup", null)))
	var active_value: Variant = config.get("active", config.get("active_duration", duration_source.get("active", null)))
	if not _is_positive_finite(startup_value) or not _is_positive_finite(active_value):
		return {}

	var recovery_value: Variant = config.get(
		"recovery",
		config.get("recovery_durations", duration_source.get("recovery", null))
	)
	var recovery_source: Dictionary = recovery_value if typeof(recovery_value) == TYPE_DICTIONARY else {}
	var durations := {
		"startup": float(startup_value),
		"active": float(active_value),
	}
	for key: String in _RECOVERY_KEYS:
		var direct_key := "%s_recovery" % key
		var value: Variant = recovery_source.get(key, config.get(direct_key, null))
		if not _is_positive_finite(value):
			return {}
		durations[key] = float(value)

	var movement := _normalize_float_policy(
		config.get("movement_mult", config.get("movement_multipliers", {})),
		1.0
	)
	if movement.is_empty():
		return {}
	var ability_blocks := _normalize_bool_policy(
		config.get("blocks_abilities", config.get("ability_blocks", {})),
		false
	)
	if ability_blocks.is_empty():
		return {}
	var recovery_allows_dash_cancel_value: Variant = config.get(
		"recovery_allows_dash_cancel",
		false
	)
	if typeof(recovery_allows_dash_cancel_value) != TYPE_BOOL:
		return {}
	var tags := _normalize_tags(config.get("phase_tags", {}))
	if tags.is_empty():
		return {}

	return {
		"durations": durations,
		"movement_multipliers": movement,
		"ability_blocks": ability_blocks,
		"recovery_allows_dash_cancel": bool(recovery_allows_dash_cancel_value),
		"phase_tags": tags,
	}


func _complete_phase(
	simulation_tick: int,
	active_resolver: Callable,
	events: Array[Dictionary]
) -> void:
	match _phase:
		Phase.STARTUP:
			var resolving_sequence := _attack_sequence_id
			_enter_phase(Phase.ACTIVE, float(_durations["active"]))
			_attack_active_tick = simulation_tick
			if not _resolve_active(active_resolver, resolving_sequence):
				return
			events.append(_event("active_started"))
		Phase.ACTIVE:
			var recovery_key: String = String(_OUTCOME_NAMES[_outcome])
			if not _RECOVERY_KEYS.has(recovery_key):
				recovery_key = "whiff"
				_outcome = Outcome.WHIFF
			_enter_phase(Phase.RECOVERY, float(_durations[recovery_key]))
			events.append(_event("recovery_started"))
		Phase.RECOVERY:
			_enter_phase(Phase.IDLE, 0.0)
			events.append(_event("completed"))


func _resolve_active(active_resolver: Callable, resolving_sequence: int) -> bool:
	if _active_resolved:
		return true
	_active_resolved = true

	var result: Variant = {}
	if active_resolver.is_valid():
		result = active_resolver.call()
	if _attack_sequence_id != resolving_sequence or _phase != Phase.ACTIVE:
		return false
	if typeof(result) != TYPE_DICTIONARY:
		_outcome = Outcome.WHIFF
		return true

	var result_data: Dictionary = result
	_outcome = _outcome_from_value(result_data.get("outcome", "whiff"))
	if _outcome == Outcome.NONE or _outcome == Outcome.INTERRUPTED:
		_outcome = Outcome.WHIFF
	_hit_count = maxi(0, int(result_data.get("hit_count", 0)))
	var hit_region_copy := _copy_value_data(result_data.get("hit_region", ""))
	_hit_region = hit_region_copy["value"] if bool(hit_region_copy["valid"]) else ""
	return true


func _enter_phase(next_phase: Phase, duration: float) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0
	_phase_duration = duration


func _phase_progress() -> float:
	if is_idle() or _phase_duration <= 0.0:
		return 0.0
	return clampf(_phase_elapsed / _phase_duration, 0.0, 1.0)


func _event(event_name: String) -> Dictionary:
	var event := snapshot()
	event["event"] = event_name
	return event


static func _normalize_float_policy(value: Variant, default_value: float) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var output := {}
	for phase_name: String in _POLICY_PHASES:
		var phase_value: Variant = source.get(phase_name, default_value)
		if not _is_nonnegative_finite(phase_value):
			return {}
		output[phase_name] = float(phase_value)
	return output


static func _normalize_bool_policy(value: Variant, default_value: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var output := {}
	for phase_name: String in _POLICY_PHASES:
		var phase_value: Variant = source.get(phase_name, default_value)
		if typeof(phase_value) != TYPE_BOOL:
			return {}
		output[phase_name] = bool(phase_value)
	return output


static func _normalize_tags(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var output := {}
	for phase_name: String in _POLICY_PHASES:
		var phase_tags_value: Variant = source.get(phase_name, [])
		if typeof(phase_tags_value) != TYPE_ARRAY:
			return {}
		var normalized: Array[String] = []
		for tag_value: Variant in phase_tags_value:
			if typeof(tag_value) != TYPE_STRING and typeof(tag_value) != TYPE_STRING_NAME:
				return {}
			var tag := String(tag_value)
			if tag.is_empty():
				return {}
			if not normalized.has(tag):
				normalized.append(tag)
		output[phase_name] = normalized
	return output


func _outcome_from_value(value: Variant) -> Outcome:
	if typeof(value) == TYPE_INT:
		var numeric := int(value)
		if numeric >= Outcome.HIT and numeric <= Outcome.RELEASED:
			return numeric as Outcome
		return Outcome.WHIFF
	var label := String(value).to_lower()
	match label:
		"hit":
			return Outcome.HIT
		"released":
			return Outcome.RELEASED
		_:
			return Outcome.WHIFF


static func _is_positive_finite(value: Variant) -> bool:
	return _is_nonnegative_finite(value) and float(value) > 0.0


static func _is_nonnegative_finite(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and number >= 0.0


func _copy_variant(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func _copy_value_data(value: Variant, ancestors: Array = []) -> Dictionary:
	var value_type := typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return {"valid": true, "value": value}
		TYPE_FLOAT:
			return {"valid": is_finite(float(value)), "value": value}
		TYPE_VECTOR2:
			return {"valid": (value as Vector2).is_finite(), "value": value}
		TYPE_VECTOR2I, TYPE_RECT2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
			return {"valid": true, "value": value}
		TYPE_RECT2:
			var rect: Rect2 = value
			return {
				"valid": rect.position.is_finite() and rect.size.is_finite(),
				"value": value,
			}
		TYPE_VECTOR3:
			return {"valid": (value as Vector3).is_finite(), "value": value}
		TYPE_TRANSFORM2D:
			return {"valid": (value as Transform2D).is_finite(), "value": value}
		TYPE_VECTOR4:
			return {"valid": (value as Vector4).is_finite(), "value": value}
		TYPE_TRANSFORM3D:
			return {"valid": (value as Transform3D).is_finite(), "value": value}
		TYPE_COLOR:
			var color: Color = value
			return {
				"valid": is_finite(color.r) \
					and is_finite(color.g) \
					and is_finite(color.b) \
					and is_finite(color.a),
				"value": value,
			}
		TYPE_ARRAY, TYPE_DICTIONARY:
			if _contains_same(ancestors, value):
				return {"valid": false, "value": null}
			var nested_ancestors := ancestors.duplicate()
			nested_ancestors.append(value)
			if value_type == TYPE_ARRAY:
				var copied_array: Array = []
				for item: Variant in value:
					var item_copy := _copy_value_data(item, nested_ancestors)
					if not bool(item_copy["valid"]):
						return {"valid": false, "value": null}
					copied_array.append(item_copy["value"])
				return {"valid": true, "value": copied_array}

			var copied_dictionary := {}
			for key: Variant in value:
				var key_copy := _copy_value_data(key, nested_ancestors)
				var item_copy := _copy_value_data(value[key], nested_ancestors)
				if not bool(key_copy["valid"]) or not bool(item_copy["valid"]):
					return {"valid": false, "value": null}
				copied_dictionary[key_copy["value"]] = item_copy["value"]
			return {"valid": true, "value": copied_dictionary}
		_:
			return {"valid": false, "value": null}


static func _contains_same(values: Array, candidate: Variant) -> bool:
	for value: Variant in values:
		if is_same(value, candidate):
			return true
	return false
