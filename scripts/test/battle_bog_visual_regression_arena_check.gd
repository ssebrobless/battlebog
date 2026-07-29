extends SceneTree

const ScenarioCatalog := preload("res://scripts/test/visual/scenario_catalog.gd")
const VisualManifest := preload("res://scripts/test/visual/visual_manifest.gd")
const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const FIXTURE_SCENE := "res://scenes/test/VisualRegressionArena.tscn"
const MANIFEST_PATH := "res://tests/visual/manifest.json"
const SEMANTIC_SCHEMA_PATH := "res://tests/visual/semantic_capture.schema.json"

var failures: Array[String] = []


class VisualClockCreature extends CreatureScript:
	func _tick_sim_body(_delta: float) -> void:
		pass

	func _cache_base_presentation_snapshot(_completed_tick: bool) -> void:
		pass


class VisualClockArena extends Node:
	var simulation_tick := 0


func _init() -> void:
	_check_catalog()
	_check_manifest()
	_check_semantic_schema()
	_check_fixture_scene()
	_check_runtime_contract_source()
	_check_visual_clock_producer()
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
	var expected_ids := [
		"neutral_smoke",
		"alligator_player_camera_attack",
		"alligator_shoreline_transition",
		"alligator_latch_death_roll",
		"alligator_death_respawn",
		"alligator_six_actor_density",
	]
	var actual_ids: Array[String] = []
	for scenario in scenarios:
		actual_ids.append(String(scenario.get("id", "")))
	_expect(
		actual_ids == expected_ids,
		"R2C manifest must expose the exact six scenarios in canonical order."
	)
	if scenarios.is_empty():
		return
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
	_expect(
		int(parsed.get("properties", {}).get("schema_version", {}).get("const", 0)) == 2,
		"Semantic capture schema must be version 2."
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
	var evidence_schema: Dictionary = parsed.get("properties", {}).get(
		"scenario_evidence",
		{}
	)
	_expect(
		not evidence_schema.is_empty() \
			and evidence_schema.get("additionalProperties", true) == false,
		"Scenario-evidence schema must exist and be closed."
	)
	var evidence_required: Array = evidence_schema.get("required", [])
	for field in [
		"action_phase", "presentation_band", "edge_distance_px",
		"simulation_terrain", "actors",
	]:
		_expect(
			evidence_required.has(field),
			"Scenario-evidence schema is missing required field '%s'." % field
		)
	var actor_schema: Dictionary = parsed.get("$defs", {}).get("actorSummary", {})
	_expect(
		not actor_schema.is_empty() \
			and actor_schema.get("additionalProperties", true) == false,
		"Scenario-evidence actor summaries must be closed."
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
		"get_fixture_descriptor",
		"PLAYABLE_SQUAD_POOL",
		"fixture_result[\"descriptor\"]",
		"scenario_evidence",
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
	var visual_style_source := FileAccess.get_file_as_string(
		"res://scripts/visual/visual_style.gd"
	)
	var creature_source := FileAccess.get_file_as_string("res://scripts/sim/creature.gd")
	_expect(
		is_equal_approx(
			VisualStyle._visual_time_msec({"visual_time_msec": 125.0}),
			125.0
		) and is_zero_approx(VisualStyle._visual_time_msec({})),
		"Visual style must honor an explicit deterministic visual clock."
	)
	_expect(
		not visual_style_source.contains("Time.") \
			and visual_style_source.contains("_visual_time_msec(anim)"),
		"Procedural creature pulses must share the guarded visual clock helper."
	)
	_expect(
		creature_source.contains("anim[\"visual_time_msec\"] = visual_time_msec") \
			and not creature_source.contains("Time.get_ticks_msec()"),
		"Arena creatures must render from simulation-derived visual time."
	)


func _check_visual_clock_producer() -> void:
	var detached := VisualClockCreature.new()
	detached.tick_sim(0.2)
	detached.tick_sim(0.05)
	_expect(
		is_equal_approx(detached._visual_time_msec(), 250.0),
		"Detached creature visual time must accumulate the supplied simulation delta."
	)
	detached.free()

	var attached := VisualClockCreature.new()
	var arena := VisualClockArena.new()
	arena.simulation_tick = 90
	attached.arena = arena
	var expected_msec := 90.0 * 1000.0 / float(Engine.physics_ticks_per_second)
	_expect(
		is_equal_approx(attached._visual_time_msec(), expected_msec),
		"Attached creature visual time must derive from the arena simulation tick."
	)
	attached.free()
	arena.free()


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
