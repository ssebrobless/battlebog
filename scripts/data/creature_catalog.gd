extends Node

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const AttackTimeline := preload("res://scripts/sim/combat/attack_timeline.gd")
const ROSTER_PATH := "res://data/battle_bog_roster.json"
const PRESENTATION_SCHEMA_PATH := "res://data/battle_bog_presentation_schema.json"
const DEFAULT_PRIMARY_ATTACK_AIM_POLICY := "locked_at_acceptance"
const PRIMARY_ATTACK_AIM_POLICIES := [
	DEFAULT_PRIMARY_ATTACK_AIM_POLICY,
]
const ALLIGATOR_ID := "alligator"
const ALLIGATOR_BITE_ACTION_ID := "alligator_bite"
const PRODUCTION_HIT_RECOVERY_RATIO := 0.60
const FLOAT_EPSILON := 0.0001
const PRESENTATION_ROOT_FIELDS := {
	"schema_version": "int",
	"simulation_tick": "int",
	"render_revision": "int",
	"actor_id": "StringName",
	"creature_id": "StringName",
	"team": "int",
	"alive": "bool",
	"world_position_px": "Vector2",
	"velocity_px_per_sec": "Vector2",
	"speed_px_per_sec": "float",
	"speed_ratio": "float",
	"locomotion_state": "StringName",
	"body_heading": "Vector2",
	"travel_heading": "Vector2",
	"attention_heading": "Vector2",
	"has_strike_heading": "bool",
	"strike_heading": "Vector2",
	"signed_body_turn_radians": "float",
	"turn_intensity": "float",
	"body_radius_px": "float",
	"footprint_kind": "StringName",
	"footprint_radius_px": "float",
	"capsule_half_length_px": "float",
	"model_scale": "float",
	"visual_radius_px": "float",
	"surface": "StringName",
	"previous_surface": "StringName",
	"transition_kind": "StringName",
	"transition_progress": "float",
	"elevation_state": "StringName",
	"height_units": "float",
	"altitude_units": "float",
	"submerged_depth_units": "float",
	"low_window_open": "bool",
	"low_window_t": "float",
	"ground_anchor_px": "Vector2",
	"active_actions": "Array[Dictionary]",
	"health_ratio": "float",
	"resources": "Dictionary[StringName,float]",
	"stealth_state": "StringName",
	"latch_role": "StringName",
	"latch_target_id": "StringName",
	"has_latch_anchor": "bool",
	"latch_anchor_px": "Vector2",
	"grip_ratio": "float",
	"weakpoint_id": "StringName",
	"weakpoint_state": "StringName",
	"death_sequence_id": "int",
	"death_t": "float",
	"respawn_remaining_sec": "float",
	"kit_cues": "Dictionary[StringName,Dictionary]",
	"hitstop_frames_remaining": "int",
	"counter_flash_t": "float",
}
const PRESENTATION_ACTION_FIELDS := {
	"action_id": "StringName",
	"owner_id": "StringName",
	"sequence_id": "int",
	"phase": "StringName",
	"phase_t": "float",
	"remaining_sec": "float",
	"variant": "StringName",
	"outcome": "StringName",
	"has_strike_heading": "bool",
	"strike_heading": "Vector2",
	"projected_shape": "Dictionary",
	"has_contact_point": "bool",
	"contact_point_px": "Vector2",
	"movement_multiplier": "float",
	"blocks_action_starts": "bool",
	"counter_vulnerable": "bool",
}
const PRESENTATION_VOCABULARIES := {
	"team_ids": [0, 1],
	"action_ids": ["alligator_bite", "alligator_death_roll"],
	"phases": ["startup", "active", "recovery", "channel", "armed", "travel", "aftermath", "teardown"],
	"outcomes": ["none", "hit", "whiff", "released", "interrupted", "expired", "owner_lost"],
	"locomotion_states": ["idle", "start", "travel", "turn", "reverse", "stop", "forced", "dead"],
	"transition_kinds": ["none", "land_to_mud", "mud_to_land", "mud_to_shallow", "shallow_to_mud", "shallow_to_deep", "deep_to_shallow", "takeoff", "landing", "submerge", "emerge"],
	"elevation_states": ["ground", "perched", "airborne", "low", "submerged"],
	"surfaces": ["solid", "mud", "water", "cover", "habitat"],
	"footprint_kinds": ["circle", "capsule"],
	"stealth_states": ["none", "hidden", "revealed", "broken"],
	"latch_roles": ["none", "attacker", "victim"],
	"weakpoint_states": ["closed", "warning", "open", "hit"],
}
const PRESENTATION_SHAPES := {
	"none": {"kind": "StringName"},
	"point": {"kind": "StringName", "point_px": "Vector2"},
	"circle": {"kind": "StringName", "center_px": "Vector2", "radius_px": "float"},
	"capsule": {"kind": "StringName", "center_px": "Vector2", "axis": "Vector2", "radius_px": "float", "half_length_px": "float"},
	"arc": {"kind": "StringName", "origin_px": "Vector2", "heading": "Vector2", "radius_px": "float", "half_angle_rad": "float"},
	"line": {"kind": "StringName", "start_px": "Vector2", "end_px": "Vector2", "half_width_px": "float"},
	"rect": {"kind": "StringName", "center_px": "Vector2", "heading": "Vector2", "half_extents_px": "Vector2"},
}

var creatures_by_id: Dictionary = {}
var creatures: Array[Dictionary] = []
var validation_errors: Array[String] = []
var presentation_schema: Dictionary = {}
var presentation_schema_errors: Array[String] = []

func _ready() -> void:
	load_catalog()
	load_presentation_schema()

func load_catalog(path := ROSTER_PATH, emit_errors := true) -> bool:
	validation_errors.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report_error("Could not open creature roster: %s" % path, emit_errors)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_report_error("Creature roster must be a JSON object: %s" % path, emit_errors)
		return false

	creatures_by_id.clear()
	creatures.clear()

	var roster: Array = parsed.get("creatures", [])
	var valid := true
	for entry: Variant in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			_report_error("Creature roster entry must be an object.", emit_errors)
			valid = false
			continue

		var creature: Dictionary = entry
		var creature_id := String(creature.get("id", ""))
		if creature_id.is_empty():
			_report_error("Creature roster entry is missing id.", emit_errors)
			valid = false
			continue
		if not creature.has("stats") or typeof(creature.get("stats")) != TYPE_DICTIONARY:
			_report_error("Creature %s is missing stats." % creature_id, emit_errors)
			valid = false
		var stats_value: Variant = creature.get("stats", {})
		var stats: Dictionary = stats_value if typeof(stats_value) == TYPE_DICTIONARY else {}
		if not creature.has("footprint") or typeof(creature.get("footprint")) != TYPE_DICTIONARY:
			_report_error("Creature %s is missing footprint." % creature_id, emit_errors)
			valid = false
		if not _validate_hurtbox_regions(creature_id, creature.get("hurtbox_regions", []), emit_errors):
			valid = false
		if creature.has("primary_attack_timelines"):
			_report_error(
				"Creature %s uses legacy top-level primary_attack_timelines; use stats.action_timelines."
				% creature_id,
				emit_errors
			)
			valid = false
		if stats.has("action_timelines") and not _validate_action_timelines(
			creature_id,
			stats.get("action_timelines"),
			emit_errors
		):
			valid = false
		if creature_id == ALLIGATOR_ID and not _validate_alligator_bite_contract(stats, emit_errors):
			valid = false
		if String(creature.get("diet", "")).is_empty():
			_report_error("Creature %s is missing diet." % creature_id, emit_errors)
			valid = false
		if creatures_by_id.has(creature_id):
			_report_error("Duplicate creature id: %s" % creature_id, emit_errors)
			valid = false

		creatures_by_id[creature_id] = creature
		creatures.append(creature)

	return valid

func get_creature(creature_id: String) -> Dictionary:
	return creatures_by_id.get(creature_id, {})

func get_all() -> Array[Dictionary]:
	return creatures.duplicate()

func get_validation_errors() -> Array[String]:
	return validation_errors.duplicate()

func load_presentation_schema(
	path := PRESENTATION_SCHEMA_PATH,
	emit_errors := true
) -> bool:
	presentation_schema_errors.clear()
	presentation_schema.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report_presentation_error(
			"Could not open presentation schema: %s" % path,
			emit_errors
		)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_report_presentation_error(
			"Presentation schema must be a JSON object: %s" % path,
			emit_errors
		)
		return false
	var schema: Dictionary = parsed
	var valid := _validate_presentation_schema(schema, emit_errors)
	if valid:
		presentation_schema = schema.duplicate(true)
	return valid

func get_presentation_schema() -> Dictionary:
	if presentation_schema.is_empty():
		load_presentation_schema(PRESENTATION_SCHEMA_PATH, false)
	return presentation_schema.duplicate(true)

func get_presentation_schema_errors() -> Array[String]:
	return presentation_schema_errors.duplicate()

func units_to_px(units: float) -> float:
	return units * SimConstants.UNIT_PX

func px_to_units(px: float) -> float:
	return px / SimConstants.UNIT_PX

func speed_to_px_per_sec(speed_units: float) -> float:
	return speed_units * SimConstants.SPEED_PX_PER_SEC

func _validate_hurtbox_regions(creature_id: String, regions: Variant, emit_errors: bool) -> bool:
	if regions == null:
		return true
	if typeof(regions) != TYPE_ARRAY:
		_report_error("Creature %s hurtbox_regions must be an array." % creature_id, emit_errors)
		return false
	var valid := true
	for region_value: Variant in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			_report_error("Creature %s hurtbox region must be an object." % creature_id, emit_errors)
			valid = false
			continue
		var region: Dictionary = region_value
		var name := String(region.get("name", ""))
		var open_when := String(region.get("open_when", "always"))
		if name.is_empty():
			_report_error("Creature %s hurtbox region is missing name." % creature_id, emit_errors)
			valid = false
		if not ["always", "lunge", "stunned", "low_window", "bask"].has(open_when):
			_report_error("Creature %s hurtbox region %s has invalid open_when %s." % [creature_id, name, open_when], emit_errors)
			valid = false
		var radius := _number_or_nan(region.get("radius_units", NAN))
		if is_nan(radius) or radius < 0.35:
			_report_error("Creature %s hurtbox region %s radius_units must be >= 0.35." % [creature_id, name], emit_errors)
			valid = false
		var mult := _number_or_nan(region.get("mult", NAN))
		if is_nan(mult) or mult < 0.75 or mult > 1.35:
			_report_error("Creature %s hurtbox region %s mult must be between 0.75 and 1.35." % [creature_id, name], emit_errors)
			valid = false
		if not _valid_region_offset(region.get("offset_units", null)):
			_report_error("Creature %s hurtbox region %s offset_units must be [forward, side] or {forward, side}." % [creature_id, name], emit_errors)
			valid = false
	return valid

func _validate_action_timelines(
	creature_id: String,
	timelines_value: Variant,
	emit_errors: bool
) -> bool:
	if typeof(timelines_value) != TYPE_DICTIONARY:
		_report_error(
			"Creature %s stats.action_timelines must be an object." % creature_id,
			emit_errors
		)
		return false

	var timelines: Dictionary = timelines_value
	if timelines.is_empty():
		_report_error(
			"Creature %s stats.action_timelines must define at least one action." % creature_id,
			emit_errors
		)
		return false

	var valid := true
	for action_name_value: Variant in timelines:
		if typeof(action_name_value) != TYPE_STRING and typeof(action_name_value) != TYPE_STRING_NAME:
			_report_error(
				"Creature %s action timeline names must be strings." % creature_id,
				emit_errors
			)
			valid = false
			continue

		var action_name := String(action_name_value).strip_edges()
		if action_name.is_empty():
			_report_error(
				"Creature %s action timeline name must not be empty." % creature_id,
				emit_errors
			)
			valid = false
			continue

		var action_value: Variant = timelines[action_name_value]
		if typeof(action_value) != TYPE_DICTIONARY:
			_report_error(
				"Creature %s action timeline %s must be an object." % [creature_id, action_name],
				emit_errors
			)
			valid = false
			continue

		var action: Dictionary = action_value
		if action.is_empty() or AttackTimeline.normalize_config(action).is_empty():
			_report_error(
				"Creature %s action timeline %s has an invalid timeline config." % [creature_id, action_name],
				emit_errors
			)
			valid = false

		var aim_policy_value: Variant = action.get(
			"aim_policy",
			DEFAULT_PRIMARY_ATTACK_AIM_POLICY
		)
		if (
			typeof(aim_policy_value) != TYPE_STRING
			and typeof(aim_policy_value) != TYPE_STRING_NAME
		) or not PRIMARY_ATTACK_AIM_POLICIES.has(String(aim_policy_value)):
			_report_error(
				"Creature %s action timeline %s aim_policy must be one of %s."
				% [creature_id, action_name, str(PRIMARY_ATTACK_AIM_POLICIES)],
				emit_errors
			)
			valid = false

		if action.has("cooldown_sec"):
			var cooldown := _number_or_nan(action.get("cooldown_sec"))
			if is_nan(cooldown) or is_inf(cooldown) or cooldown <= 0.0:
				_report_error(
					"Creature %s action timeline %s cooldown_sec must be finite and positive."
					% [creature_id, action_name],
					emit_errors
				)
				valid = false

	return valid

func _validate_alligator_bite_contract(stats: Dictionary, emit_errors: bool) -> bool:
	var timelines_value: Variant = stats.get("action_timelines", null)
	if typeof(timelines_value) != TYPE_DICTIONARY:
		_report_error(
			"Creature alligator must define stats.action_timelines.%s." % ALLIGATOR_BITE_ACTION_ID,
			emit_errors
		)
		return false

	var timelines: Dictionary = timelines_value
	var bite_value: Variant = timelines.get(ALLIGATOR_BITE_ACTION_ID, null)
	if typeof(bite_value) != TYPE_DICTIONARY:
		_report_error(
			"Creature alligator must define stats.action_timelines.%s." % ALLIGATOR_BITE_ACTION_ID,
			emit_errors
		)
		return false

	var bite: Dictionary = bite_value
	var recovery_value: Variant = bite.get("recovery", null)
	if typeof(recovery_value) != TYPE_DICTIONARY:
		return false
	var recovery: Dictionary = recovery_value
	var hit := _number_or_nan(recovery.get("hit", NAN))
	var whiff := _number_or_nan(recovery.get("whiff", NAN))
	var valid := true
	if (
		is_nan(hit)
		or is_nan(whiff)
		or absf(hit - whiff * PRODUCTION_HIT_RECOVERY_RATIO) > FLOAT_EPSILON
	):
		_report_error(
			"Creature alligator alligator_bite hit recovery must equal whiff recovery * 0.60.",
			emit_errors
		)
		valid = false

	var blocks_value: Variant = bite.get("blocks_abilities", null)
	if (
		typeof(blocks_value) != TYPE_DICTIONARY
		or (blocks_value as Dictionary).get("recovery", null) != true
	):
		_report_error(
			"Creature alligator alligator_bite recovery must block action starts.",
			emit_errors
		)
		valid = false
	return valid

func _report_error(message: String, emit_errors: bool) -> void:
	validation_errors.append(message)
	if emit_errors:
		push_error(message)

func _validate_presentation_schema(schema: Dictionary, emit_errors: bool) -> bool:
	var expected_top_level := [
		"schema_version",
		"root_fields",
		"action_fields",
		"vocabularies",
		"projected_shapes",
		"resource_keys",
		"kit_cue_keys",
		"legacy_motion_state",
	]
	var valid := _validate_exact_keys(
		"presentation schema",
		schema,
		expected_top_level,
		emit_errors
	)
	if schema.get("schema_version", null) != 1:
		_report_presentation_error("Presentation schema_version must equal 1.", emit_errors)
		valid = false
	if not _validate_exact_dictionary(
		"presentation root_fields",
		schema.get("root_fields"),
		PRESENTATION_ROOT_FIELDS,
		emit_errors
	):
		valid = false
	if not _validate_exact_dictionary(
		"presentation action_fields",
		schema.get("action_fields"),
		PRESENTATION_ACTION_FIELDS,
		emit_errors
	):
		valid = false
	if not _validate_presentation_vocabularies(
		schema.get("vocabularies"),
		emit_errors
	):
		valid = false
	if not _validate_exact_dictionary(
		"presentation projected_shapes",
		schema.get("projected_shapes"),
		PRESENTATION_SHAPES,
		emit_errors
	):
		valid = false
	if not _validate_presentation_key_list(
		"resource_keys",
		schema.get("resource_keys"),
		emit_errors
	):
		valid = false
	if not _validate_kit_cue_keys(schema.get("kit_cue_keys"), emit_errors):
		valid = false
	if not _validate_legacy_motion_state(
		schema.get("legacy_motion_state"),
		schema.get("resource_keys"),
		schema.get("kit_cue_keys"),
		emit_errors
	):
		valid = false
	return valid

func _validate_exact_dictionary(
	label: String,
	value: Variant,
	expected: Dictionary,
	emit_errors: bool
) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value != expected:
		_report_presentation_error("%s does not match the closed contract." % label, emit_errors)
		return false
	return true

func _validate_presentation_vocabularies(value: Variant, emit_errors: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_report_presentation_error("presentation vocabularies must be an object.", emit_errors)
		return false
	var vocabularies: Dictionary = value
	if not _validate_exact_keys(
		"presentation vocabularies",
		vocabularies,
		PRESENTATION_VOCABULARIES.keys(),
		emit_errors
	):
		return false
	for vocabulary_name: String in PRESENTATION_VOCABULARIES:
		var actual_value: Variant = vocabularies.get(vocabulary_name)
		if typeof(actual_value) != TYPE_ARRAY:
			_report_presentation_error(
				"presentation vocabulary %s must be an array." % vocabulary_name,
				emit_errors
			)
			return false
		var actual: Array = actual_value
		var expected: Array = PRESENTATION_VOCABULARIES[vocabulary_name]
		if actual.size() != expected.size():
			_report_presentation_error(
				"presentation vocabulary %s does not match the closed contract."
				% vocabulary_name,
				emit_errors
			)
			return false
		for index in expected.size():
			if actual[index] != expected[index]:
				_report_presentation_error(
					"presentation vocabulary %s does not match the closed contract."
					% vocabulary_name,
					emit_errors
				)
				return false
	return true

func _validate_exact_keys(
	label: String,
	value: Dictionary,
	expected: Array,
	emit_errors: bool
) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var wanted := expected.duplicate()
	wanted.sort()
	if actual != wanted:
		_report_presentation_error("%s has missing or extra keys." % label, emit_errors)
		return false
	return true

func _validate_presentation_key_list(
	label: String,
	value: Variant,
	emit_errors: bool
) -> bool:
	if typeof(value) != TYPE_ARRAY:
		_report_presentation_error("%s must be an array." % label, emit_errors)
		return false
	var seen := {}
	for key_value: Variant in value:
		if typeof(key_value) != TYPE_STRING or String(key_value).is_empty():
			_report_presentation_error("%s entries must be non-empty strings." % label, emit_errors)
			return false
		if seen.has(key_value):
			_report_presentation_error("%s contains duplicate key %s." % [label, key_value], emit_errors)
			return false
		seen[key_value] = true
	return true

func _validate_kit_cue_keys(value: Variant, emit_errors: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_report_presentation_error("kit_cue_keys must be an object.", emit_errors)
		return false
	var valid := true
	for namespace_value: Variant in value:
		if typeof(namespace_value) != TYPE_STRING or String(namespace_value).is_empty():
			_report_presentation_error("kit_cue_keys namespaces must be non-empty strings.", emit_errors)
			valid = false
			continue
		if not _validate_presentation_key_list(
			"kit_cue_keys.%s" % namespace_value,
			value[namespace_value],
			emit_errors
		):
			valid = false
	return valid

func _validate_legacy_motion_state(
	value: Variant,
	resource_keys_value: Variant,
	kit_cue_keys_value: Variant,
	emit_errors: bool
) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		_report_presentation_error("legacy_motion_state must be an object.", emit_errors)
		return false
	var legacy: Dictionary = value
	if legacy.size() != 169:
		_report_presentation_error(
			"legacy_motion_state must contain exactly 169 mined keys.",
			emit_errors
		)
		return false
	var resource_keys: Array = (
		resource_keys_value if typeof(resource_keys_value) == TYPE_ARRAY else []
	)
	var kit_cue_keys: Dictionary = (
		kit_cue_keys_value if typeof(kit_cue_keys_value) == TYPE_DICTIONARY else {}
	)
	var valid := true
	for key_value: Variant in legacy:
		var key := String(key_value)
		var entry_value: Variant = legacy[key_value]
		if typeof(entry_value) != TYPE_DICTIONARY:
			_report_presentation_error("Legacy key %s must map to an object." % key, emit_errors)
			valid = false
			continue
		var entry: Dictionary = entry_value
		if not _validate_exact_keys(
			"legacy_motion_state.%s" % key,
			entry,
			["type", "destination"],
			emit_errors
		):
			valid = false
		var type_name := String(entry.get("type", ""))
		var destination := String(entry.get("destination", ""))
		if type_name.is_empty() or destination.is_empty():
			_report_presentation_error("Legacy key %s needs type and destination." % key, emit_errors)
			valid = false
		elif destination.begins_with("root."):
			if not PRESENTATION_ROOT_FIELDS.has(destination.trim_prefix("root.")):
				_report_presentation_error("Legacy key %s targets unknown root field." % key, emit_errors)
				valid = false
		elif destination.begins_with("action."):
			if not PRESENTATION_ACTION_FIELDS.has(destination.trim_prefix("action.")):
				_report_presentation_error("Legacy key %s targets unknown action field." % key, emit_errors)
				valid = false
		elif destination.begins_with("resources."):
			if not resource_keys.has(destination.trim_prefix("resources.")):
				_report_presentation_error("Legacy key %s targets unknown resource key." % key, emit_errors)
				valid = false
		elif destination.begins_with("kit_cues."):
			var cue_path := destination.trim_prefix("kit_cues.")
			var namespace_name := cue_path.get_slice(".", 0)
			var cue_key := cue_path.trim_prefix("%s." % namespace_name)
			if not kit_cue_keys.has(namespace_name) \
				or not (kit_cue_keys[namespace_name] as Array).has(cue_key):
				_report_presentation_error("Legacy key %s targets unknown kit cue." % key, emit_errors)
				valid = false
		elif not destination.begins_with("compatibility."):
			_report_presentation_error("Legacy key %s has invalid destination." % key, emit_errors)
			valid = false
	return valid

func _report_presentation_error(message: String, emit_errors: bool) -> void:
	presentation_schema_errors.append(message)
	if emit_errors:
		push_error(message)

func _number_or_nan(value: Variant) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return NAN

func _valid_region_offset(value: Variant) -> bool:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).size() >= 2 and _is_number((value as Array)[0]) and _is_number((value as Array)[1])
	if typeof(value) == TYPE_DICTIONARY:
		var offset: Dictionary = value
		return (_is_number(offset.get("forward", offset.get("x", null))) and _is_number(offset.get("side", offset.get("y", null))))
	return false

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
