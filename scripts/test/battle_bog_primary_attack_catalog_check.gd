extends SceneTree

const CreatureCatalog := preload("res://scripts/data/creature_catalog.gd")

var failures: Array[String] = []
var fixture_index := 0


func _initialize() -> void:
	_check_field_absent()
	_check_valid_variants()
	_check_invalid_cases()

	print("primary attack catalog failures=%d" % failures.size())
	for failure: String in failures:
		print("FAIL: %s" % failure)
	quit(0 if failures.is_empty() else 1)


func _check_field_absent() -> void:
	var creature := _base_creature("field_absent")
	_expect_catalog_valid("field absent", creature)


func _check_valid_variants() -> void:
	var creature := _base_creature("valid_variants")
	creature["primary_attack_timelines"] = {
		"default": _valid_timeline(),
		"heavy": _valid_timeline({
			"aim_policy": "locked_at_acceptance",
			"cooldown_sec": 1.25,
		}),
	}
	_expect_catalog_valid("valid variants", creature)


func _check_invalid_cases() -> void:
	_expect_timelines_invalid("timelines must be an object", [], "must be an object")
	_expect_timelines_invalid("timelines must not be empty", {}, "at least one variant")
	_expect_timelines_invalid("variant name must not be empty", {"   ": _valid_timeline()}, "name must not be empty")
	_expect_timelines_invalid("variant must be an object", {"default": []}, "variant default must be an object")
	_expect_timelines_invalid("variant config must not be empty", {"default": {}}, "invalid timeline config")

	var invalid_config := _valid_timeline()
	invalid_config.erase("active")
	_expect_timelines_invalid(
		"timeline config must normalize",
		{"default": invalid_config},
		"invalid timeline config"
	)

	_expect_timelines_invalid(
		"tracked aim is not supported",
		{"default": _valid_timeline({"aim_policy": "tracked"})},
		"aim_policy"
	)
	_expect_timelines_invalid(
		"aim policy must be a string",
		{"default": _valid_timeline({"aim_policy": 7})},
		"aim_policy"
	)
	_expect_timelines_invalid(
		"zero cooldown is invalid",
		{"default": _valid_timeline({"cooldown_sec": 0.0})},
		"cooldown_sec"
	)
	_expect_timelines_invalid(
		"string cooldown is invalid",
		{"default": _valid_timeline({"cooldown_sec": "1.0"})},
		"cooldown_sec"
	)


func _expect_timelines_invalid(label: String, timelines: Variant, error_fragment: String) -> void:
	var creature := _base_creature("invalid_%d" % fixture_index)
	creature["primary_attack_timelines"] = timelines
	_expect_catalog_invalid(label, creature, error_fragment)


func _expect_catalog_valid(label: String, creature: Dictionary) -> void:
	var result := _load_fixture(creature)
	if not bool(result["valid"]):
		failures.append("%s should be valid; errors=%s" % [label, str(result["errors"])])


func _expect_catalog_invalid(
	label: String,
	creature: Dictionary,
	error_fragment: String
) -> void:
	var result := _load_fixture(creature)
	if bool(result["valid"]):
		failures.append("%s should be rejected" % label)
		return

	var found := false
	for error: String in result["errors"]:
		if error_fragment in error:
			found = true
			break
	if not found:
		failures.append(
			"%s should report %s; errors=%s" % [label, error_fragment, str(result["errors"])]
		)


func _load_fixture(creature: Dictionary) -> Dictionary:
	fixture_index += 1
	var path := "user://primary_attack_catalog_%d.json" % fixture_index
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("could not create fixture %s" % path)
		return {"valid": false, "errors": []}
	file.store_string(JSON.stringify({"creatures": [creature]}))
	file.close()

	var catalog: Node = CreatureCatalog.new()
	var valid: bool = catalog.load_catalog(path, false)
	var errors: Array[String] = catalog.get_validation_errors()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"valid": valid, "errors": errors}


func _base_creature(creature_id: String) -> Dictionary:
	return {
		"id": creature_id,
		"name": "Primary Attack Catalog Probe",
		"family": "test",
		"movement": ["ground_walker"],
		"role": ["test"],
		"diet": "omnivore",
		"footprint": {"shape": "circle", "radius_units": 1.0},
		"stats": {"health": 100, "speed": 1.0},
	}


func _valid_timeline(overrides := {}) -> Dictionary:
	var timeline := {
		"startup": 0.20,
		"active": 0.10,
		"recovery": {
			"hit": 0.40,
			"whiff": 0.60,
			"released": 0.25,
			"interrupted": 0.50,
		},
		"movement_mult": {
			"startup": 0.50,
			"active": 0.20,
			"recovery": 0.35,
		},
		"blocks_abilities": {
			"startup": true,
			"active": true,
			"recovery": false,
		},
		"phase_tags": {
			"startup": ["warning"],
			"active": ["contact"],
			"recovery": ["punishable"],
		},
	}
	timeline.merge(overrides, true)
	return timeline
