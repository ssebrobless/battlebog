class_name CreaturePresentationSnapshot
extends RefCounted

const SCHEMA_VERSION := 1
const EPSILON := 0.00001
const SCHEMA_PATH := "res://data/battle_bog_presentation_schema.json"

const ROOT_FIELDS: Array[StringName] = [
	&"schema_version",
	&"simulation_tick",
	&"render_revision",
	&"actor_id",
	&"creature_id",
	&"team",
	&"alive",
	&"world_position_px",
	&"velocity_px_per_sec",
	&"speed_px_per_sec",
	&"speed_ratio",
	&"locomotion_state",
	&"body_heading",
	&"travel_heading",
	&"attention_heading",
	&"has_strike_heading",
	&"strike_heading",
	&"signed_body_turn_radians",
	&"turn_intensity",
	&"body_radius_px",
	&"footprint_kind",
	&"footprint_radius_px",
	&"capsule_half_length_px",
	&"model_scale",
	&"visual_radius_px",
	&"surface",
	&"previous_surface",
	&"transition_kind",
	&"transition_progress",
	&"elevation_state",
	&"height_units",
	&"altitude_units",
	&"submerged_depth_units",
	&"low_window_open",
	&"low_window_t",
	&"ground_anchor_px",
	&"active_actions",
	&"health_ratio",
	&"resources",
	&"stealth_state",
	&"latch_role",
	&"latch_target_id",
	&"has_latch_anchor",
	&"latch_anchor_px",
	&"grip_ratio",
	&"weakpoint_id",
	&"weakpoint_state",
	&"death_sequence_id",
	&"death_t",
	&"respawn_remaining_sec",
	&"kit_cues",
	&"hitstop_frames_remaining",
	&"counter_flash_t",
]

const ACTION_FIELDS: Array[StringName] = [
	&"action_id",
	&"owner_id",
	&"sequence_id",
	&"phase",
	&"phase_t",
	&"remaining_sec",
	&"variant",
	&"outcome",
	&"has_strike_heading",
	&"strike_heading",
	&"projected_shape",
	&"has_contact_point",
	&"contact_point_px",
	&"movement_multiplier",
	&"blocks_action_starts",
	&"counter_vulnerable",
]

const SHAPE_FIELDS := {
	&"none": [&"kind"],
	&"point": [&"kind", &"point_px"],
	&"circle": [&"kind", &"center_px", &"radius_px"],
	&"capsule": [
		&"kind",
		&"center_px",
		&"axis",
		&"radius_px",
		&"half_length_px",
	],
	&"arc": [
		&"kind",
		&"origin_px",
		&"heading",
		&"radius_px",
		&"half_angle_rad",
	],
	&"line": [&"kind", &"start_px", &"end_px", &"half_width_px"],
	&"rect": [&"kind", &"center_px", &"heading", &"half_extents_px"],
}

var _data: Dictionary = {}
var _schema: Dictionary = {}
static var _canonical_schema_contract: Dictionary = {}


static func create(
	data: Dictionary,
	schema: Dictionary
) -> CreaturePresentationSnapshot:
	if not validation_errors(data, schema).is_empty():
		return null
	return _create_validated(data)


static func create_canonical(data: Dictionary) -> CreaturePresentationSnapshot:
	var schema := _canonical_schema()
	if schema.is_empty() \
			or not _validation_errors_internal(data, schema, false).is_empty():
		return null
	return _create_validated(data)


static func _create_validated(data: Dictionary) -> CreaturePresentationSnapshot:
	var snapshot := CreaturePresentationSnapshot.new()
	snapshot._schema = _canonical_schema()
	snapshot._data = _canonicalize(data)
	return snapshot


static func validation_errors(data: Dictionary, schema: Dictionary) -> Array[String]:
	return _validation_errors_internal(data, schema, true)


static func _validation_errors_internal(
	data: Dictionary,
	schema: Dictionary,
	validate_schema_contract: bool
) -> Array[String]:
	var errors: Array[String] = []
	if validate_schema_contract:
		_validate_schema(schema, errors)
	elif not is_same(schema, _canonical_schema()):
		errors.append("trusted snapshot construction requires canonical schema")
	if not errors.is_empty():
		return errors

	if not _is_value_only(data):
		errors.append("snapshot contains an unsupported, cyclic, or non-finite value")
		return errors

	_validate_exact_keys(data, ROOT_FIELDS, "snapshot", errors)
	if not errors.is_empty():
		return errors

	_require_int(data, &"schema_version", 0, errors)
	if int(data.get(&"schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must equal %d" % SCHEMA_VERSION)
	_require_int(data, &"simulation_tick", 0, errors)
	_require_int(data, &"render_revision", 0, errors)
	_require_stable_id(data, &"actor_id", false, errors)
	_require_string_name(data, &"creature_id", false, errors)
	_validate_optional_vocab(data, &"creature_id", schema, "creature_ids", errors)
	_require_vocab_int(data, &"team", schema, "team_ids", errors)
	_require_type(data, &"alive", TYPE_BOOL, errors)
	_require_vector2(data, &"world_position_px", true, errors)
	_require_vector2(data, &"velocity_px_per_sec", true, errors)
	_require_nonnegative_number(data, &"speed_px_per_sec", errors)
	_require_ratio(data, &"speed_ratio", errors)
	_require_vocab(data, &"locomotion_state", schema, "locomotion_states", errors)
	_require_heading(data, &"body_heading", errors)
	_require_heading(data, &"travel_heading", errors)
	_require_heading(data, &"attention_heading", errors)
	_validate_optional_vector(
		data,
		&"has_strike_heading",
		&"strike_heading",
		true,
		errors
	)
	_require_finite_number(data, &"signed_body_turn_radians", errors)
	_require_ratio(data, &"turn_intensity", errors)
	_require_nonnegative_number(data, &"body_radius_px", errors)
	_require_vocab(data, &"footprint_kind", schema, "footprint_kinds", errors)
	_require_nonnegative_number(data, &"footprint_radius_px", errors)
	_require_nonnegative_number(data, &"capsule_half_length_px", errors)
	if String(data.get(&"footprint_kind", "")) == "circle" \
			and _number(data.get(&"capsule_half_length_px", -1.0)) != 0.0:
		errors.append("capsule_half_length_px must be zero for a circle footprint")
	_require_positive_number(data, &"model_scale", errors)
	_require_nonnegative_number(data, &"visual_radius_px", errors)
	_require_vocab(data, &"surface", schema, "surfaces", errors)
	_require_vocab(data, &"previous_surface", schema, "surfaces", errors)
	_require_vocab(data, &"transition_kind", schema, "transition_kinds", errors)
	_require_ratio(data, &"transition_progress", errors)
	if String(data.get(&"transition_kind", "")) == "none" \
			and _number(data.get(&"transition_progress", -1.0)) != 0.0:
		errors.append("transition_progress must be zero when transition_kind is none")
	_require_vocab(data, &"elevation_state", schema, "elevation_states", errors)
	_require_nonnegative_number(data, &"height_units", errors)
	_require_nonnegative_number(data, &"altitude_units", errors)
	_require_nonnegative_number(data, &"submerged_depth_units", errors)
	if String(data.get(&"elevation_state", "")) != "submerged" \
			and _number(data.get(&"submerged_depth_units", -1.0)) != 0.0:
		errors.append("submerged_depth_units must be zero unless elevation_state is submerged")
	_require_type(data, &"low_window_open", TYPE_BOOL, errors)
	_require_ratio(data, &"low_window_t", errors)
	if data.get(&"low_window_open", false) == false \
			and _number(data.get(&"low_window_t", -1.0)) != 0.0:
		errors.append("low_window_t must be zero while low_window_open is false")
	_require_vector2(data, &"ground_anchor_px", true, errors)
	_validate_actions(data.get(&"active_actions"), schema, errors)
	_require_ratio(data, &"health_ratio", errors)
	_validate_resources(data.get(&"resources"), schema, errors)
	_require_vocab(data, &"stealth_state", schema, "stealth_states", errors)
	_require_vocab(data, &"latch_role", schema, "latch_roles", errors)
	_validate_latch(data, errors)
	_require_ratio(data, &"grip_ratio", errors)
	_require_string_name(data, &"weakpoint_id", true, errors)
	_require_vocab(data, &"weakpoint_state", schema, "weakpoint_states", errors)
	if String(data.get(&"weakpoint_state", "")) == "closed" \
			and String(data.get(&"weakpoint_id", "")) != "":
		errors.append("weakpoint_id must be empty while weakpoint_state is closed")
	_require_int(data, &"death_sequence_id", 0, errors)
	_require_ratio(data, &"death_t", errors)
	_require_nonnegative_number(data, &"respawn_remaining_sec", errors)
	_validate_death(data, errors)
	_validate_kit_cues(data.get(&"kit_cues"), schema, errors)
	_require_int(data, &"hitstop_frames_remaining", 0, errors)
	var hitstop_frames := int(data.get(&"hitstop_frames_remaining", -1))
	if hitstop_frames > 3:
		errors.append("hitstop_frames_remaining must be between 0 and 3")
	_require_ratio(data, &"counter_flash_t", errors)
	return errors


func get_field(field: StringName) -> Variant:
	if not _data.has(field):
		return null
	return _copy_owned_value(_data[field])


func has_field(field: StringName) -> bool:
	return _data.has(field)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


func to_json_dictionary() -> Dictionary:
	return _to_json_value(_data)


func with_render_feedback(
	hitstop_frames: int,
	counter_flash_t: float,
	render_revision: int
) -> CreaturePresentationSnapshot:
	if hitstop_frames < 0 or hitstop_frames > 3 \
			or not is_finite(counter_flash_t) \
			or counter_flash_t < 0.0 or counter_flash_t > 1.0:
		return null
	var current_hitstop := int(_data[&"hitstop_frames_remaining"])
	var current_counter := float(_data[&"counter_flash_t"])
	var current_revision := int(_data[&"render_revision"])
	var changed := hitstop_frames != current_hitstop \
		or not is_equal_approx(counter_flash_t, current_counter)
	if not changed:
		return self if render_revision == current_revision else null
	if render_revision <= current_revision:
		return null
	var derived := _data.duplicate(true)
	derived[&"hitstop_frames_remaining"] = hitstop_frames
	derived[&"counter_flash_t"] = counter_flash_t
	derived[&"render_revision"] = render_revision
	return create(derived, _schema)


func get_schema_version() -> int: return int(_data[&"schema_version"])
func get_simulation_tick() -> int: return int(_data[&"simulation_tick"])
func get_render_revision() -> int: return int(_data[&"render_revision"])
func get_actor_id() -> StringName: return StringName(_data[&"actor_id"])
func get_creature_id() -> StringName: return StringName(_data[&"creature_id"])
func get_team() -> int: return int(_data[&"team"])
func get_alive() -> bool: return bool(_data[&"alive"])
func get_world_position_px() -> Vector2: return _data[&"world_position_px"]
func get_velocity_px_per_sec() -> Vector2: return _data[&"velocity_px_per_sec"]
func get_speed_px_per_sec() -> float: return float(_data[&"speed_px_per_sec"])
func get_speed_ratio() -> float: return float(_data[&"speed_ratio"])
func get_locomotion_state() -> StringName: return StringName(_data[&"locomotion_state"])
func get_body_heading() -> Vector2: return _data[&"body_heading"]
func get_travel_heading() -> Vector2: return _data[&"travel_heading"]
func get_attention_heading() -> Vector2: return _data[&"attention_heading"]
func get_has_strike_heading() -> bool: return bool(_data[&"has_strike_heading"])
func get_strike_heading() -> Vector2: return _data[&"strike_heading"]
func get_signed_body_turn_radians() -> float: return float(_data[&"signed_body_turn_radians"])
func get_turn_intensity() -> float: return float(_data[&"turn_intensity"])
func get_body_radius_px() -> float: return float(_data[&"body_radius_px"])
func get_footprint_kind() -> StringName: return StringName(_data[&"footprint_kind"])
func get_footprint_radius_px() -> float: return float(_data[&"footprint_radius_px"])
func get_capsule_half_length_px() -> float: return float(_data[&"capsule_half_length_px"])
func get_model_scale() -> float: return float(_data[&"model_scale"])
func get_visual_radius_px() -> float: return float(_data[&"visual_radius_px"])
func get_surface() -> StringName: return StringName(_data[&"surface"])
func get_previous_surface() -> StringName: return StringName(_data[&"previous_surface"])
func get_transition_kind() -> StringName: return StringName(_data[&"transition_kind"])
func get_transition_progress() -> float: return float(_data[&"transition_progress"])
func get_elevation_state() -> StringName: return StringName(_data[&"elevation_state"])
func get_height_units() -> float: return float(_data[&"height_units"])
func get_altitude_units() -> float: return float(_data[&"altitude_units"])
func get_submerged_depth_units() -> float: return float(_data[&"submerged_depth_units"])
func get_low_window_open() -> bool: return bool(_data[&"low_window_open"])
func get_low_window_t() -> float: return float(_data[&"low_window_t"])
func get_ground_anchor_px() -> Vector2: return _data[&"ground_anchor_px"]
func get_active_actions() -> Array: return _data[&"active_actions"].duplicate(true)
func get_health_ratio() -> float: return float(_data[&"health_ratio"])
func get_resources() -> Dictionary: return _data[&"resources"].duplicate(true)
func get_stealth_state() -> StringName: return StringName(_data[&"stealth_state"])
func get_latch_role() -> StringName: return StringName(_data[&"latch_role"])
func get_latch_target_id() -> StringName: return StringName(_data[&"latch_target_id"])
func get_has_latch_anchor() -> bool: return bool(_data[&"has_latch_anchor"])
func get_latch_anchor_px() -> Vector2: return _data[&"latch_anchor_px"]
func get_grip_ratio() -> float: return float(_data[&"grip_ratio"])
func get_weakpoint_id() -> StringName: return StringName(_data[&"weakpoint_id"])
func get_weakpoint_state() -> StringName: return StringName(_data[&"weakpoint_state"])
func get_death_sequence_id() -> int: return int(_data[&"death_sequence_id"])
func get_death_t() -> float: return float(_data[&"death_t"])
func get_respawn_remaining_sec() -> float: return float(_data[&"respawn_remaining_sec"])
func get_kit_cues() -> Dictionary: return _data[&"kit_cues"].duplicate(true)
func get_hitstop_frames_remaining() -> int: return int(_data[&"hitstop_frames_remaining"])
func get_counter_flash_t() -> float: return float(_data[&"counter_flash_t"])


static func _validate_schema(schema: Dictionary, errors: Array[String]) -> void:
	if schema.is_empty():
		errors.append("presentation schema must not be empty")
		return
	var canonical := _canonical_schema()
	if canonical.is_empty():
		errors.append("canonical presentation schema could not be loaded")
		return
	if schema != canonical:
		errors.append("presentation schema must match the canonical closed contract")


static func _canonical_schema() -> Dictionary:
	if not _canonical_schema_contract.is_empty():
		return _canonical_schema_contract
	var file := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_canonical_schema_contract = parsed
	return _canonical_schema_contract


static func _validate_actions(
	value: Variant,
	schema: Dictionary,
	errors: Array[String]
) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("active_actions must be an array")
		return
	var identities: Dictionary = {}
	for index in (value as Array).size():
		var action_value: Variant = (value as Array)[index]
		var path := "active_actions[%d]" % index
		if typeof(action_value) != TYPE_DICTIONARY:
			errors.append("%s must be a dictionary" % path)
			continue
		var action: Dictionary = action_value
		_validate_exact_keys(action, ACTION_FIELDS, path, errors)
		_require_vocab(action, &"action_id", schema, "action_ids", errors, path)
		_require_stable_id(action, &"owner_id", false, errors, path)
		_require_int(action, &"sequence_id", 1, errors, path)
		_require_vocab(action, &"phase", schema, "action_phases", errors, path)
		_require_ratio(action, &"phase_t", errors, path)
		_require_finite_number(action, &"remaining_sec", errors, path)
		var remaining := _number(action.get(&"remaining_sec", -2.0))
		var phase := String(action.get(&"phase", ""))
		if remaining < 0.0 and not (phase == "channel" and remaining == -1.0):
			errors.append("%s.remaining_sec may be -1 only for an indefinite channel" % path)
		_require_string_name(action, &"variant", true, errors, path)
		_require_vocab(action, &"outcome", schema, "action_outcomes", errors, path)
		_validate_optional_vector(
			action,
			&"has_strike_heading",
			&"strike_heading",
			true,
			errors,
			path
		)
		_validate_projected_shape(action.get(&"projected_shape"), schema, errors, path)
		_validate_optional_vector(
			action,
			&"has_contact_point",
			&"contact_point_px",
			false,
			errors,
			path
		)
		_require_nonnegative_number(action, &"movement_multiplier", errors, path)
		_require_type(action, &"blocks_action_starts", TYPE_BOOL, errors, path)
		_require_type(action, &"counter_vulnerable", TYPE_BOOL, errors, path)
		if action.get(&"counter_vulnerable", false) == true and phase != "startup":
			errors.append("%s.counter_vulnerable may be true only during startup" % path)
		var identity := "%s\u001f%s\u001f%d" % [
			String(action.get(&"owner_id", "")),
			String(action.get(&"action_id", "")),
			int(action.get(&"sequence_id", 0)),
		]
		if identities.has(identity):
			errors.append("%s duplicates action identity %s" % [path, identity])
		identities[identity] = true


static func _validate_projected_shape(
	value: Variant,
	schema: Dictionary,
	errors: Array[String],
	parent_path: String
) -> void:
	var path := "%s.projected_shape" % parent_path
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s must be a dictionary" % path)
		return
	var shape: Dictionary = value
	_require_string_name(shape, &"kind", false, errors, path)
	var kind := StringName(shape.get(&"kind", &""))
	if not _shape_declarations(schema).has(kind) \
			and not _shape_declarations(schema).has(String(kind)):
		errors.append("%s.kind is not catalogued" % path)
		return
	if not SHAPE_FIELDS.has(kind):
		errors.append("%s.kind is not supported" % path)
		return
	_validate_exact_keys(shape, SHAPE_FIELDS[kind], path, errors)
	match kind:
		&"point":
			_require_vector2(shape, &"point_px", true, errors, path)
		&"circle":
			_require_vector2(shape, &"center_px", true, errors, path)
			_require_nonnegative_number(shape, &"radius_px", errors, path)
		&"capsule":
			_require_vector2(shape, &"center_px", true, errors, path)
			_require_heading(shape, &"axis", errors, path)
			_require_nonnegative_number(shape, &"radius_px", errors, path)
			_require_nonnegative_number(shape, &"half_length_px", errors, path)
		&"arc":
			_require_vector2(shape, &"origin_px", true, errors, path)
			_require_heading(shape, &"heading", errors, path)
			_require_nonnegative_number(shape, &"radius_px", errors, path)
			_require_nonnegative_number(shape, &"half_angle_rad", errors, path)
			if _number(shape.get(&"half_angle_rad", -1.0)) > PI:
				errors.append("%s.half_angle_rad must not exceed PI" % path)
		&"line":
			_require_vector2(shape, &"start_px", true, errors, path)
			_require_vector2(shape, &"end_px", true, errors, path)
			_require_nonnegative_number(shape, &"half_width_px", errors, path)
		&"rect":
			_require_vector2(shape, &"center_px", true, errors, path)
			_require_heading(shape, &"heading", errors, path)
			_require_vector2(shape, &"half_extents_px", true, errors, path)
			var half_extents: Variant = shape.get(&"half_extents_px")
			if half_extents is Vector2 \
					and ((half_extents as Vector2).x < 0.0 or (half_extents as Vector2).y < 0.0):
				errors.append("%s.half_extents_px components must be non-negative" % path)


static func _validate_resources(
	value: Variant,
	schema: Dictionary,
	errors: Array[String]
) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("resources must be a dictionary")
		return
	var allowed := _schema_vocabulary(schema, "resource_keys")
	for key: Variant in value:
		if typeof(key) != TYPE_STRING_NAME or not _vocabulary_has(allowed, key):
			errors.append("resources contains unknown or non-StringName key %s" % str(key))
			continue
		if typeof((value as Dictionary)[key]) != TYPE_FLOAT \
				or not is_finite(float((value as Dictionary)[key])):
			errors.append("resources.%s must be a finite float" % String(key))


static func _validate_kit_cues(
	value: Variant,
	schema: Dictionary,
	errors: Array[String]
) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("kit_cues must be a dictionary")
		return
	var declarations := _kit_cue_declarations(schema)
	for namespace_value: Variant in value:
		if typeof(namespace_value) != TYPE_STRING_NAME:
			errors.append("kit_cues namespaces must be StringName values")
			continue
		var namespace_name := StringName(namespace_value)
		var declaration: Variant = declarations.get(
			namespace_name,
			declarations.get(String(namespace_name), null)
		)
		if declaration == null:
			errors.append("kit_cues contains unknown namespace %s" % String(namespace_name))
			continue
		var cues_value: Variant = (value as Dictionary)[namespace_value]
		if typeof(cues_value) != TYPE_DICTIONARY:
			errors.append("kit_cues.%s must be a dictionary" % String(namespace_name))
			continue
		var allowed_keys := _declared_names(declaration)
		var compatibility_namespace := namespace_name == &"legacy_motion_state"
		var legacy_contract: Dictionary = (
			schema.get("legacy_motion_state", {})
			if compatibility_namespace
			else {}
		)
		for cue_key: Variant in cues_value:
			var valid_key_type := typeof(cue_key) == TYPE_STRING_NAME \
				or (
					compatibility_namespace
					and typeof(cue_key) == TYPE_STRING
				)
			var catalogued := (
				legacy_contract.has(String(cue_key))
				if compatibility_namespace
				else _vocabulary_has(allowed_keys, cue_key)
			)
			if not valid_key_type or not catalogued:
				errors.append(
					"kit_cues.%s contains unknown or non-StringName key %s"
					% [String(namespace_name), str(cue_key)]
				)


static func _validate_latch(data: Dictionary, errors: Array[String]) -> void:
	var role := String(data.get(&"latch_role", ""))
	var has_latch := role != "none"
	_require_stable_id(data, &"latch_target_id", not has_latch, errors)
	_validate_optional_vector(
		data,
		&"has_latch_anchor",
		&"latch_anchor_px",
		false,
		errors
	)
	if not has_latch:
		if String(data.get(&"latch_target_id", "")) != "":
			errors.append("latch_target_id must be empty while latch_role is none")
		if data.get(&"has_latch_anchor", false) == true:
			errors.append("has_latch_anchor must be false while latch_role is none")
		if _number(data.get(&"grip_ratio", -1.0)) != 0.0:
			errors.append("grip_ratio must be zero while latch_role is none")
	elif String(data.get(&"latch_target_id", "")) == "":
		errors.append("latch_target_id is required while latched")


static func _validate_death(data: Dictionary, errors: Array[String]) -> void:
	var alive_value: Variant = data.get(&"alive", false)
	var alive := bool(alive_value) if typeof(alive_value) == TYPE_BOOL else false
	var sequence_id := int(data.get(&"death_sequence_id", -1))
	var death_t := _number(data.get(&"death_t", -1.0))
	var respawn_remaining := _number(data.get(&"respawn_remaining_sec", -1.0))
	if sequence_id == 0 and death_t != 0.0:
		errors.append("death_t must be zero when death_sequence_id is zero")
	if alive and (sequence_id != 0 or death_t != 0.0 or respawn_remaining != 0.0):
		errors.append("alive snapshots must have neutral death and respawn fields")
	if not alive and sequence_id <= 0:
		errors.append("dead snapshots require a positive death_sequence_id")


static func _canonicalize(data: Dictionary) -> Dictionary:
	var output: Dictionary = data.duplicate(true)
	for field in [&"body_heading", &"travel_heading", &"attention_heading"]:
		output[field] = (output[field] as Vector2).normalized()
	if output[&"has_strike_heading"]:
		output[&"strike_heading"] = (output[&"strike_heading"] as Vector2).normalized()
	var actions: Array = output[&"active_actions"]
	for action_value: Variant in actions:
		var action: Dictionary = action_value
		if action[&"has_strike_heading"]:
			action[&"strike_heading"] = (action[&"strike_heading"] as Vector2).normalized()
		var shape: Dictionary = action[&"projected_shape"]
		match StringName(shape[&"kind"]):
			&"capsule":
				shape[&"axis"] = (shape[&"axis"] as Vector2).normalized()
			&"arc", &"rect":
				shape[&"heading"] = (shape[&"heading"] as Vector2).normalized()
	actions.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_key := [
				String(left[&"owner_id"]),
				String(left[&"action_id"]),
				int(left[&"sequence_id"]),
			]
			var right_key := [
				String(right[&"owner_id"]),
				String(right[&"action_id"]),
				int(right[&"sequence_id"]),
			]
			if left_key[0] != right_key[0]:
				return left_key[0] < right_key[0]
			if left_key[1] != right_key[1]:
				return left_key[1] < right_key[1]
			return left_key[2] < right_key[2]
	)
	return output


static func _validate_exact_keys(
	data: Dictionary,
	expected: Variant,
	path: String,
	errors: Array[String]
) -> void:
	var expected_names := _declared_names(expected)
	var actual_names: Array = data.keys()
	if not _same_name_set(actual_names, expected_names):
		errors.append("%s must contain exactly the declared keys" % path)


static func _require_type(
	data: Dictionary,
	field: StringName,
	expected_type: int,
	errors: Array[String],
	path := ""
) -> void:
	if typeof(data.get(field)) != expected_type:
		errors.append("%s must be %s" % [_field_path(path, field), type_string(expected_type)])


static func _require_int(
	data: Dictionary,
	field: StringName,
	minimum: int,
	errors: Array[String],
	path := ""
) -> void:
	if typeof(data.get(field)) != TYPE_INT or int(data.get(field, minimum - 1)) < minimum:
		errors.append("%s must be an integer >= %d" % [_field_path(path, field), minimum])


static func _require_string_name(
	data: Dictionary,
	field: StringName,
	allow_empty: bool,
	errors: Array[String],
	path := ""
) -> void:
	if typeof(data.get(field)) != TYPE_STRING_NAME:
		errors.append("%s must be a StringName" % _field_path(path, field))
	elif not allow_empty and String(data[field]).is_empty():
		errors.append("%s must not be empty" % _field_path(path, field))


static func _require_stable_id(
	data: Dictionary,
	field: StringName,
	allow_empty: bool,
	errors: Array[String],
	path := ""
) -> void:
	_require_string_name(data, field, allow_empty, errors, path)
	if typeof(data.get(field)) != TYPE_STRING_NAME:
		return
	var value := String(data[field])
	if value.is_empty() and allow_empty:
		return
	if not _is_stable_actor_id(value):
		errors.append("%s is not a stable actor ID" % _field_path(path, field))


static func _require_vector2(
	data: Dictionary,
	field: StringName,
	allow_zero: bool,
	errors: Array[String],
	path := ""
) -> void:
	var value: Variant = data.get(field)
	if typeof(value) != TYPE_VECTOR2 or not (value as Vector2).is_finite():
		errors.append("%s must be a finite Vector2" % _field_path(path, field))
	elif not allow_zero and (value as Vector2).is_zero_approx():
		errors.append("%s must be nonzero" % _field_path(path, field))


static func _require_heading(
	data: Dictionary,
	field: StringName,
	errors: Array[String],
	path := ""
) -> void:
	_require_vector2(data, field, false, errors, path)


static func _validate_optional_vector(
	data: Dictionary,
	flag_field: StringName,
	value_field: StringName,
	normalize: bool,
	errors: Array[String],
	path := ""
) -> void:
	_require_type(data, flag_field, TYPE_BOOL, errors, path)
	_require_vector2(data, value_field, true, errors, path)
	if typeof(data.get(flag_field)) != TYPE_BOOL or typeof(data.get(value_field)) != TYPE_VECTOR2:
		return
	var enabled := bool(data[flag_field])
	var value: Vector2 = data[value_field]
	if enabled and normalize and value.is_zero_approx():
		errors.append("%s must be nonzero when %s is true" % [
			_field_path(path, value_field),
			_field_path(path, flag_field),
		])
	elif not enabled and not value.is_zero_approx():
		errors.append("%s must be Vector2.ZERO when %s is false" % [
			_field_path(path, value_field),
			_field_path(path, flag_field),
		])


static func _require_finite_number(
	data: Dictionary,
	field: StringName,
	errors: Array[String],
	path := ""
) -> void:
	var value: Variant = data.get(field)
	if typeof(value) != TYPE_FLOAT or not is_finite(float(value)):
		errors.append("%s must be a finite float" % _field_path(path, field))


static func _require_nonnegative_number(
	data: Dictionary,
	field: StringName,
	errors: Array[String],
	path := ""
) -> void:
	_require_finite_number(data, field, errors, path)
	if _is_number(data.get(field)) and float(data[field]) < 0.0:
		errors.append("%s must be non-negative" % _field_path(path, field))


static func _require_positive_number(
	data: Dictionary,
	field: StringName,
	errors: Array[String],
	path := ""
) -> void:
	_require_finite_number(data, field, errors, path)
	if _is_number(data.get(field)) and float(data[field]) <= 0.0:
		errors.append("%s must be positive" % _field_path(path, field))


static func _require_ratio(
	data: Dictionary,
	field: StringName,
	errors: Array[String],
	path := ""
) -> void:
	_require_finite_number(data, field, errors, path)
	if _is_number(data.get(field)):
		var value := float(data[field])
		if value < 0.0 or value > 1.0:
			errors.append("%s must be in [0, 1]" % _field_path(path, field))


static func _require_vocab(
	data: Dictionary,
	field: StringName,
	schema: Dictionary,
	vocabulary: String,
	errors: Array[String],
	path := ""
) -> void:
	_require_string_name(data, field, false, errors, path)
	if typeof(data.get(field)) == TYPE_STRING_NAME \
			and not _vocabulary_has(_schema_vocabulary(schema, vocabulary), data[field]):
		errors.append("%s is not catalogued" % _field_path(path, field))


static func _require_vocab_int(
	data: Dictionary,
	field: StringName,
	schema: Dictionary,
	vocabulary: String,
	errors: Array[String]
) -> void:
	if typeof(data.get(field)) != TYPE_INT:
		errors.append("%s must be an integer" % String(field))
	elif not _vocabulary_has(_schema_vocabulary(schema, vocabulary), data[field]):
		errors.append("%s is not catalogued" % String(field))


static func _validate_optional_vocab(
	data: Dictionary,
	field: StringName,
	schema: Dictionary,
	vocabulary: String,
	errors: Array[String]
) -> void:
	var values := _schema_vocabulary(schema, vocabulary)
	if not values.is_empty() and not _vocabulary_has(values, data.get(field)):
		errors.append("%s is not catalogued" % String(field))


static func _schema_field_names(schema: Dictionary) -> Array:
	for key in ["root_fields", "fields", "root"]:
		var value: Variant = schema.get(key, schema.get(StringName(key), null))
		if value != null:
			return _declared_names(value)
	return []


static func _schema_vocabulary(schema: Dictionary, name: String) -> Array:
	var aliases := {
		"action_phases": "phases",
		"action_outcomes": "outcomes",
	}
	var schema_name := String(aliases.get(name, name))
	var direct: Variant = schema.get(
		schema_name,
		schema.get(StringName(schema_name), null)
	)
	if direct != null:
		return _declared_names(direct)
	var vocabularies_value: Variant = schema.get(
		"vocabularies",
		schema.get(&"vocabularies", {})
	)
	if typeof(vocabularies_value) == TYPE_DICTIONARY:
		var vocabularies: Dictionary = vocabularies_value
		return _declared_names(
			vocabularies.get(
				schema_name,
				vocabularies.get(StringName(schema_name), [])
			)
		)
	return []


static func _schema_action_field_names(schema: Dictionary) -> Array:
	var value: Variant = schema.get(
		"action_fields",
		schema.get(&"action_fields", null)
	)
	return _declared_names(value) if value != null else []


static func _shape_declarations(schema: Dictionary) -> Dictionary:
	for key in ["projected_shapes", "projected_shape_schemas"]:
		var value: Variant = schema.get(key, schema.get(StringName(key), null))
		if typeof(value) == TYPE_DICTIONARY:
			return value
	return {}


static func _kit_cue_declarations(schema: Dictionary) -> Dictionary:
	for key in ["kit_cue_keys", "kit_cue_namespaces", "kit_cues"]:
		var value: Variant = schema.get(key, schema.get(StringName(key), null))
		if typeof(value) == TYPE_DICTIONARY:
			var declarations: Dictionary = (value as Dictionary).duplicate(true)
			var legacy_value: Variant = schema.get(
				"legacy_motion_state",
				schema.get(&"legacy_motion_state", null)
			)
			if typeof(legacy_value) == TYPE_DICTIONARY:
				declarations["legacy_motion_state"] = (
					legacy_value as Dictionary
				).keys()
			return declarations
	return {}


static func _declared_names(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate()
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		return Array(value)
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).keys()
	return []


static func _same_name_set(left: Variant, right: Variant) -> bool:
	var left_names := _declared_names(left) if typeof(left) == TYPE_DICTIONARY else Array(left)
	var right_names := _declared_names(right) if typeof(right) == TYPE_DICTIONARY else Array(right)
	if left_names.size() != right_names.size():
		return false
	var expected: Dictionary = {}
	for value: Variant in right_names:
		expected[String(value)] = true
	for value: Variant in left_names:
		if not expected.has(String(value)):
			return false
	return true


static func _has_duplicate_values(values: Array) -> bool:
	var seen: Dictionary = {}
	for value: Variant in values:
		var key := "%d:%s" % [typeof(value), str(value)]
		if seen.has(key):
			return true
		seen[key] = true
	return false


static func _vocabulary_has(values: Array, candidate: Variant) -> bool:
	for value: Variant in values:
		if typeof(value) == typeof(candidate) and value == candidate:
			return true
		if _is_number(value) and _is_number(candidate) \
				and is_equal_approx(float(value), float(candidate)):
			return true
		if (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) \
				and (typeof(candidate) == TYPE_STRING or typeof(candidate) == TYPE_STRING_NAME) \
				and String(value) == String(candidate):
			return true
	return false


static func _is_stable_actor_id(value: String) -> bool:
	var parts := value.split(":")
	if parts.size() == 3 and (parts[0] == "slot" or parts[0] == "fixture"):
		return not parts[1].is_empty() and parts[2].is_valid_int() and int(parts[2]) >= 0
	if parts.size() >= 4 and (parts[0] == "pet" or parts[0] == "child"):
		return not parts[1].is_empty() \
			and not parts[parts.size() - 2].is_empty() \
			and parts[parts.size() - 1].is_valid_int() \
			and int(parts[parts.size() - 1]) >= 0
	return false


static func _is_value_only(value: Variant, ancestors: Array = []) -> bool:
	var value_type := typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_VECTOR2:
			return (value as Vector2).is_finite()
		TYPE_COLOR:
			var color: Color = value
			return is_finite(color.r) and is_finite(color.g) \
				and is_finite(color.b) and is_finite(color.a)
		TYPE_PACKED_VECTOR2_ARRAY:
			var vectors: PackedVector2Array = value
			for vector: Vector2 in vectors:
				if not vector.is_finite():
					return false
			return true
		TYPE_ARRAY, TYPE_DICTIONARY:
			if _contains_same(ancestors, value):
				return false
			var nested_ancestors := ancestors.duplicate()
			nested_ancestors.append(value)
			if value_type == TYPE_ARRAY:
				for item: Variant in value:
					if not _is_value_only(item, nested_ancestors):
						return false
				return true
			for key: Variant in value:
				if not _is_value_only(key, nested_ancestors) \
						or not _is_value_only(value[key], nested_ancestors):
					return false
			return true
		_:
			return false


static func _copy_owned_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if typeof(value) == TYPE_PACKED_VECTOR2_ARRAY:
		return (value as PackedVector2Array).duplicate()
	return value


static func _to_json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return [vector.x, vector.y]
		TYPE_COLOR:
			var color: Color = value
			return [color.r, color.g, color.b, color.a]
		TYPE_PACKED_VECTOR2_ARRAY:
			var output: Array = []
			for vector: Vector2 in (value as PackedVector2Array):
				output.append([vector.x, vector.y])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item: Variant in value:
				output.append(_to_json_value(item))
			return output
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			for key: Variant in value:
				var json_key: Variant = String(key) if typeof(key) == TYPE_STRING_NAME else key
				output[json_key] = _to_json_value(value[key])
			return output
		_:
			return value


static func _contains_same(values: Array, candidate: Variant) -> bool:
	for value: Variant in values:
		if is_same(value, candidate):
			return true
	return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _number(value: Variant) -> float:
	return float(value) if _is_number(value) else NAN


static func _field_path(path: String, field: StringName) -> String:
	return String(field) if path.is_empty() else "%s.%s" % [path, String(field)]
