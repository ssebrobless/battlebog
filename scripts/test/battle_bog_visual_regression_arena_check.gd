extends SceneTree

const ScenarioCatalog := preload("res://scripts/test/visual/scenario_catalog.gd")
const VisualManifest := preload("res://scripts/test/visual/visual_manifest.gd")
const FIXTURE_SCENE := "res://scenes/test/VisualRegressionArena.tscn"
const MANIFEST_PATH := "res://tests/visual/manifest.json"
const SEMANTIC_SCHEMA_PATH := "res://tests/visual/semantic_capture.schema.json"

var failures: Array[String] = []


func _init() -> void:
	_check_catalog()
	_check_manifest()
	_check_semantic_schema()
	_check_fixture_scene()
	_check_runtime_contract_source()
	if failures.is_empty():
		print("Battle Bog visual regression arena check passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_catalog() -> void:
	_expect(
		ScenarioCatalog.camera_zoom("PvAI").is_equal_approx(Vector2(2.6, 2.6)),
		"PvAI camera preset must be exactly 2.6."
	)
	_expect(
		ScenarioCatalog.camera_zoom("Competitive").is_equal_approx(Vector2(2.2, 2.2)),
		"Competitive camera preset must be exactly 2.2."
	)
	_expect(
		not ScenarioCatalog.is_camera_preset_supported("Unknown"),
		"Camera presets must be closed."
	)
	for capture_mode in ["Diagnostic", "Evaluator", "Performance"]:
		_expect(
			ScenarioCatalog.is_capture_mode_supported(capture_mode),
			"Capture mode '%s' must be supported." % capture_mode
		)

	var event_scenario := {
		"id": "window_probe",
		"script": "res://scripts/test/visual/scenarios/neutral_real_arena_scenario.gd",
		"seed": 1,
		"environment": "real_arena",
		"evaluator_safe": true,
		"capture_window": {
			"anchor": "HIT+0",
			"before_frames": 2,
			"through": "RECOVERY_END",
		},
		"required_anchors": ["HIT+0", "RECOVERY_END"],
	}
	_expect(
		ScenarioCatalog.validate_scenario_contract(event_scenario).is_empty(),
		"Event-relative scenario contract should validate."
	)
	var result := ScenarioCatalog.resolve_capture_frames(
		event_scenario,
		{"HIT+0": 10, "RECOVERY_END": 12}
	)
	var frames: Array = result.get("frames", [])
	_expect(
		bool(result.get("ok", false)) \
			and frames == [8, 9, 10, 11, 12, 13],
		"Capture windows must include anchor-before through first frame after terminal."
	)


func _check_manifest() -> void:
	var loaded := VisualManifest.load_and_validate(MANIFEST_PATH)
	_expect(bool(loaded.get("ok", false)), "R2A visual manifest must validate.")
	if not bool(loaded.get("ok", false)):
		return
	var scenarios: Array = loaded["manifest"]["scenarios"]
	_expect(scenarios.size() == 1, "R2A manifest should expose only the real neutral smoke.")
	var neutral: Dictionary = scenarios[0]
	_expect(
		String(neutral.get("id", "")) == "neutral_smoke" \
			and String(neutral.get("environment", "")) == "real_arena",
		"neutral_smoke must use the real Arena environment."
	)
	_expect(
		String(neutral.get("script", "")).ends_with("neutral_real_arena_scenario.gd"),
		"neutral_smoke must use a real-Creature scenario."
	)


func _check_semantic_schema() -> void:
	var parsed := _load_json_object(SEMANTIC_SCHEMA_PATH)
	_expect(not parsed.is_empty(), "Semantic capture schema must be valid JSON.")
	if parsed.is_empty():
		return
	_expect(
		parsed.get("additionalProperties", true) == false,
		"Semantic capture schema must be closed."
	)
	var required: Array = parsed.get("required", [])
	for field in [
		"scenario_id", "action_id", "seed", "camera_preset", "capture_mode",
		"frame", "tick", "actor_id", "target_id", "snapshot", "phase", "outcome",
		"projected_contact", "contact_truth", "terrain", "depth", "named_anchors",
		"critical_regions_px",
	]:
		_expect(required.has(field), "Semantic schema is missing required field '%s'." % field)
	var snapshot_schema: Dictionary = parsed.get("properties", {}).get("snapshot", {})
	var snapshot_required: Array = snapshot_schema.get("required", [])
	for field in ["schema_version", "simulation_tick", "actor_id", "creature_id"]:
		_expect(
			snapshot_required.has(field),
			"Semantic schema snapshot is missing canonical field '%s'." % field
		)
	var critical_schema: Dictionary = parsed.get("properties", {}).get(
		"critical_regions_px",
		{}
	)
	_expect(
		critical_schema.get("additionalProperties", true) == false,
		"Critical-region schema must be closed."
	)
	var body_schema: Dictionary = critical_schema.get("properties", {}).get("body", {})
	_expect(
		int(body_schema.get("minItems", 0)) == 1,
		"Critical-region body array must require at least one rectangle."
	)


func _check_fixture_scene() -> void:
	var source := FileAccess.get_file_as_string(FIXTURE_SCENE)
	_expect(not source.is_empty(), "VisualRegressionArena scene must exist.")
	_expect(
		source.contains("path=\"res://scenes/Arena.tscn\""),
		"VisualRegressionArena must instance the normal Arena scene."
	)
	_expect(
		source.contains("[node name=\"Arena\" parent=\".\" instance="),
		"VisualRegressionArena must own an Arena child."
	)
	_expect(
		source.contains("process_mode = 4"),
		"Fixture Arena must not autonomously tick."
	)


func _check_runtime_contract_source() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/test/visual/visual_regression_arena.gd"
	)
	for token in [
		"--bb-camera-preset=",
		"--bb-capture-mode=",
		"get_named_anchors",
		"ScenarioCatalog.resolve_capture_frames",
		"_capture_mode != \"Performance\"",
		"Evaluator mode forbids diagnostic labels",
		"is not evaluator-safe",
	]:
		_expect(source.contains(token), "Visual fixture source is missing contract token '%s'." % token)
	var neutral_source := FileAccess.get_file_as_string(
		"res://scripts/test/visual/scenarios/neutral_real_arena_scenario.gd"
	)
	_expect(
		neutral_source.contains("InputFrameScript.new()") \
			and neutral_source.contains("get_presentation_snapshot()") \
			and neutral_source.contains("get_global_transform_with_canvas()") \
			and neutral_source.contains("long_body_visual_length_px") \
			and neutral_source.contains("\"critical_regions_px\""),
		"Real neutral scenario must apply InputFrame and export a Creature snapshot."
	)


func _load_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
