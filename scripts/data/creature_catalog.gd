extends Node

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const AttackTimeline := preload("res://scripts/sim/combat/attack_timeline.gd")
const ROSTER_PATH := "res://data/battle_bog_roster.json"
const DEFAULT_PRIMARY_ATTACK_AIM_POLICY := "locked_at_acceptance"
const PRIMARY_ATTACK_AIM_POLICIES := [
	DEFAULT_PRIMARY_ATTACK_AIM_POLICY,
]
const ALLIGATOR_ID := "alligator"
const ALLIGATOR_BITE_ACTION_ID := "alligator_bite"
const PRODUCTION_HIT_RECOVERY_RATIO := 0.60
const FLOAT_EPSILON := 0.0001

var creatures_by_id: Dictionary = {}
var creatures: Array[Dictionary] = []
var validation_errors: Array[String] = []

func _ready() -> void:
	load_catalog()

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
