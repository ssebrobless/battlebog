extends Node2D

const VisualManifest := preload("res://scripts/test/visual/visual_manifest.gd")
const VisualRegressionClock := preload("res://scripts/test/visual/visual_regression_clock.gd")
const ScenarioCatalog := preload("res://scripts/test/visual/scenario_catalog.gd")
const DEFAULT_MANIFEST_PATH := "res://tests/visual/manifest.json"
const DEFAULT_OUTPUT_ROOT := "res://artifacts/visual-regression"
const FIXTURE_BLUE_ROSTER := ["snapping_turtle", "chorus_frog", "mink"]
const FIXTURE_RED_ROSTER := ["beaver", "otter", "alligator"]
const DRY_RUN_FRAME_LIMIT := 3600

var _mode := "capture"
var _manifest_path := DEFAULT_MANIFEST_PATH
var _selected_scenario_id := ""
var _run_id := ""
var _output_path := ""
var _camera_preset := "PvAI"
var _capture_mode := "Diagnostic"
var _failed := false
var _runtime_renderer_info := {}
var _arguments_parsed := false
var _real_arena: Node = null


func _enter_tree() -> void:
	_parse_arguments()
	_configure_fixture_game()


func _ready() -> void:
	_real_arena = get_node_or_null("Arena")
	call_deferred("_run")


func _parse_arguments() -> void:
	if _arguments_parsed:
		return
	_arguments_parsed = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bb-visual-mode="):
			_mode = argument.trim_prefix("--bb-visual-mode=").to_lower()
		elif argument.begins_with("--bb-visual-manifest="):
			_manifest_path = argument.trim_prefix("--bb-visual-manifest=")
		elif argument.begins_with("--bb-visual-scenario="):
			_selected_scenario_id = argument.trim_prefix("--bb-visual-scenario=")
		elif argument.begins_with("--bb-visual-run-id="):
			_run_id = argument.trim_prefix("--bb-visual-run-id=")
		elif argument.begins_with("--bb-visual-output="):
			_output_path = argument.trim_prefix("--bb-visual-output=")
		elif argument.begins_with("--bb-camera-preset="):
			_camera_preset = argument.trim_prefix("--bb-camera-preset=")
		elif argument.begins_with("--bb-capture-mode="):
			_capture_mode = argument.trim_prefix("--bb-capture-mode=")


func _configure_fixture_game() -> void:
	GameConfig.selected_mode = "1v1"
	GameConfig.set_selected_squad_ids(FIXTURE_BLUE_ROSTER)
	GameConfig.set_selected_red_squad_ids(FIXTURE_RED_ROSTER)
	GameConfig.simulation_seed = 424242
	GameConfig.wake_boss = false
	GameConfig.center_boss = false


func _reset_real_arena(seed: int) -> bool:
	if _real_arena != null and is_instance_valid(_real_arena):
		if _real_arena.get_parent() == self:
			remove_child(_real_arena)
		_real_arena.free()
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn")
	if arena_scene == null:
		return false
	GameConfig.simulation_seed = seed
	_real_arena = arena_scene.instantiate()
	_real_arena.name = "Arena"
	_real_arena.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_real_arena)
	_real_arena.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func _run() -> void:
	if not _mode in ["capture", "list", "validate"]:
		_fail("Unknown mode '%s'. Expected capture, list, or validate." % _mode)
		return
	if not ScenarioCatalog.is_camera_preset_supported(_camera_preset):
		_fail("Unknown camera preset '%s'." % _camera_preset)
		return
	if not ScenarioCatalog.is_capture_mode_supported(_capture_mode):
		_fail("Unknown capture mode '%s'." % _capture_mode)
		return
	if _real_arena == null:
		_fail("VisualRegressionArena must instance scenes/Arena.tscn as child 'Arena'.")
		return
	_real_arena.process_mode = Node.PROCESS_MODE_DISABLED

	var load_result := VisualManifest.load_and_validate(_manifest_path)
	if not bool(load_result.get("ok", false)):
		_fail(str(load_result.get("error", "Unknown manifest error.")))
		return

	var manifest: Dictionary = load_result["manifest"]
	var scenarios := _select_scenarios(manifest["scenarios"])
	if scenarios.is_empty():
		_fail("No scenario matched '%s'." % _selected_scenario_id)
		return
	if _capture_mode == "Evaluator":
		for scenario in scenarios:
			if not bool(scenario.get("evaluator_safe", false)):
				_fail("Scenario '%s' is not evaluator-safe." % scenario["id"])
				return

	var resolved_scenarios := await _resolve_scenarios(scenarios, manifest["viewport"])
	if _failed:
		return
	if not await _validate_scenario_scripts(resolved_scenarios, manifest["viewport"]):
		return

	if _mode == "list":
		for scenario in resolved_scenarios:
			print(
				"BB_VISUAL_SCENARIO id=%s seed=%d frames=%s anchors=%s"
				% [
					scenario["id"],
					int(scenario["seed"]),
					str(scenario["_resolved_capture_frames"]),
					str(scenario["_named_anchors"]),
				]
			)
		print("BB_VISUAL_LIST_COMPLETE count=%d" % resolved_scenarios.size())
		get_tree().quit(0)
		return

	if _mode == "validate":
		print(
			"BB_VISUAL_VALIDATE_OK scenarios=%d manifest=%s"
			% [resolved_scenarios.size(), _manifest_path]
		)
		get_tree().quit(0)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	if not _validate_render_contract(manifest["viewport"]):
		return
	if not _prepare_output_directory():
		return

	for scenario in resolved_scenarios:
		await _capture_scenario(scenario, manifest["viewport"])
		if _failed:
			return

	print(
		"BB_VISUAL_CAPTURE_COMPLETE run_id=%s scenarios=%d output=%s"
		% [_run_id, resolved_scenarios.size(), _output_path]
	)
	get_tree().quit(0)


func _select_scenarios(all_scenarios: Array) -> Array:
	if _selected_scenario_id.is_empty():
		return all_scenarios.duplicate()
	var selected := []
	for scenario in all_scenarios:
		if str(scenario.get("id", "")) == _selected_scenario_id:
			selected.append(scenario)
	return selected


func _resolve_scenarios(
	scenarios: Array,
	viewport_contract: Dictionary
) -> Array:
	var resolved: Array = []
	for scenario_value in scenarios:
		var scenario: Dictionary = scenario_value.duplicate(true)
		var anchors_result := await _dry_resolve_named_anchors(scenario, viewport_contract)
		if not bool(anchors_result.get("ok", false)):
			_fail(String(anchors_result.get("error", "Named-anchor resolution failed.")))
			return []
		var named_anchors: Dictionary = anchors_result["anchors"]
		var frames_result := ScenarioCatalog.resolve_capture_frames(scenario, named_anchors)
		if not bool(frames_result.get("ok", false)):
			_fail(String(frames_result.get("error", "Capture-frame resolution failed.")))
			return []
		scenario["_named_anchors"] = named_anchors
		scenario["_resolved_capture_frames"] = frames_result["frames"]
		resolved.append(scenario)
	return resolved


func _dry_resolve_named_anchors(
	scenario: Dictionary,
	viewport_contract: Dictionary
) -> Dictionary:
	if not _reset_real_arena(int(scenario["seed"])):
		return {"ok": false, "error": "Normal Arena scene could not be instantiated."}
	var script_resource: Script = load(String(scenario["script"]))
	if script_resource == null:
		return {"ok": false, "error": "Scenario '%s' script could not be loaded." % scenario["id"]}
	var instance: Variant = script_resource.new()
	if not instance is Node2D:
		if instance is Object:
			instance.free()
		return {"ok": false, "error": "Scenario '%s' script must instantiate a Node2D." % scenario["id"]}
	if not instance.has_method("configure") or not instance.has_method("apply_clock"):
		instance.free()
		return {"ok": false, "error": "Scenario '%s' cannot run a dry simulation." % scenario["id"]}
	var required := ScenarioCatalog.required_anchors(scenario)
	if not required.is_empty() and not instance.has_method("get_named_anchors"):
		instance.free()
		return {"ok": false, "error": "Scenario '%s' must implement get_named_anchors()." % scenario["id"]}

	_prepare_real_arena(scenario)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.configure(_scenario_context(scenario, viewport_contract))
	add_child(instance)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	var clock := VisualRegressionClock.new()
	clock.configure(int(scenario["seed"]), int(viewport_contract["fixed_step_hz"]))
	var resolved := {}
	var final_frame := 0
	if required.is_empty():
		resolved = {}
	elif instance.has_method("get_named_anchors"):
		for frame_index in range(DRY_RUN_FRAME_LIMIT + 1):
			clock.seek(frame_index)
			instance.apply_clock(clock)
			var reported: Variant = instance.get_named_anchors()
			if reported is Dictionary:
				for anchor_name in required:
					if not resolved.has(anchor_name) and reported.has(anchor_name):
						var value: Variant = reported[anchor_name]
						if not _is_nonnegative_integer(value):
							_free_scenario_node(instance)
							return {
								"ok": false,
								"error": "Scenario '%s' anchor '%s' must be a non-negative integer." % [
									scenario["id"],
									anchor_name,
								],
							}
						if int(value) <= frame_index:
							resolved[anchor_name] = int(value)
			if resolved.size() == required.size():
				final_frame = frame_index
				break
		if resolved.size() != required.size():
			_free_scenario_node(instance)
			return {
				"ok": false,
				"error": "Scenario '%s' did not resolve anchors %s within %d frames." % [
					scenario["id"],
					str(required),
					DRY_RUN_FRAME_LIMIT,
				],
			}
	_free_scenario_node(instance)
	return {
		"ok": true,
		"anchors": resolved,
		"dry_run_final_frame": final_frame,
	}


func _validate_scenario_scripts(
	scenarios: Array,
	viewport_contract: Dictionary
) -> bool:
	for scenario in scenarios:
		if not _reset_real_arena(int(scenario["seed"])):
			_fail("Normal Arena scene could not be instantiated.")
			return false
		var script_resource: Script = load(str(scenario["script"]))
		if script_resource == null:
			_fail("Scenario '%s' script could not be loaded." % scenario["id"])
			return false
		var instance: Variant = script_resource.new()
		if not instance is Node2D:
			if instance is Object:
				instance.free()
			_fail("Scenario '%s' script must instantiate a Node2D." % scenario["id"])
			return false
		for method_name in ["configure", "apply_clock", "get_capture_state"]:
			if not instance.has_method(method_name):
				instance.free()
				_fail(
					"Scenario '%s' is missing required method '%s'."
					% [scenario["id"], method_name]
				)
				return false
		_prepare_real_arena(scenario)
		instance.process_mode = Node.PROCESS_MODE_DISABLED
		instance.configure(_scenario_context(scenario, viewport_contract))
		add_child(instance)
		instance.process_mode = Node.PROCESS_MODE_DISABLED

		var clock := VisualRegressionClock.new()
		clock.configure(int(scenario["seed"]), int(viewport_contract["fixed_step_hz"]))
		var frames: Array = scenario["_resolved_capture_frames"]
		var validation_frames: Array[int] = [int(frames.front())]
		var final_frame := int(frames.back())
		if final_frame != validation_frames.front():
			validation_frames.append(final_frame)
		for frame_index in validation_frames:
			clock.seek(frame_index)
			instance.apply_clock(clock)
			await get_tree().process_frame
			var state: Variant = instance.get_capture_state()
			if not state is Dictionary:
				_free_scenario_node(instance)
				_fail("Scenario '%s' get_capture_state() must return a Dictionary." % scenario["id"])
				return false
			var safety_error := _json_safety_error(state, "scenario '%s' state" % scenario["id"])
			if not safety_error.is_empty():
				_free_scenario_node(instance)
				_fail(safety_error)
				return false
		_free_scenario_node(instance)
	return true


func _validate_render_contract(viewport_contract: Dictionary) -> bool:
	var expected_size := Vector2i(
		int(viewport_contract["width"]),
		int(viewport_contract["height"])
	)
	var actual_size := Vector2i(get_viewport().get_visible_rect().size)
	if actual_size != expected_size:
		_fail(
			"Viewport is %dx%d; expected %dx%d."
			% [actual_size.x, actual_size.y, expected_size.x, expected_size.y]
		)
		return false

	var configured_renderer := str(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	)
	var actual_renderer := RenderingServer.get_current_rendering_method()
	if actual_renderer != str(viewport_contract["renderer"]):
		_fail(
			"Active renderer is '%s'; expected '%s' (project setting is '%s')."
			% [actual_renderer, viewport_contract["renderer"], configured_renderer]
		)
		return false
	_runtime_renderer_info = {
		"configured_method": configured_renderer,
		"actual_method": actual_renderer,
		"actual_driver": RenderingServer.get_current_rendering_driver_name(),
		"display_server": DisplayServer.get_name(),
		"video_adapter_name": RenderingServer.get_video_adapter_name(),
		"video_adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
	}
	return true


func _prepare_output_directory() -> bool:
	if _run_id.is_empty():
		_run_id = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	if not _is_safe_run_id(_run_id):
		_fail("Run id '%s' is not safe." % _run_id)
		return false
	if _output_path.is_empty():
		_output_path = "%s/%s" % [DEFAULT_OUTPUT_ROOT, _run_id]

	var absolute_output := ProjectSettings.globalize_path(_output_path)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_output)
	if make_error != OK:
		_fail(
			"Could not create output directory '%s': %s."
			% [absolute_output, error_string(make_error)]
		)
		return false
	_output_path = absolute_output
	return true


func _capture_scenario(scenario: Dictionary, viewport_contract: Dictionary) -> void:
	if not _reset_real_arena(int(scenario["seed"])):
		_fail("Normal Arena scene could not be instantiated.")
		return
	var scenario_id := str(scenario["id"])
	var script_resource: Script = load(str(scenario["script"]))
	var scenario_node: Node2D = script_resource.new()
	_prepare_real_arena(scenario)
	scenario_node.process_mode = Node.PROCESS_MODE_DISABLED
	scenario_node.configure(_scenario_context(scenario, viewport_contract))
	add_child(scenario_node)
	scenario_node.process_mode = Node.PROCESS_MODE_DISABLED

	var clock := VisualRegressionClock.new()
	clock.configure(int(scenario["seed"]), int(viewport_contract["fixed_step_hz"]))
	var capture_frames: Array = scenario["_resolved_capture_frames"]
	var final_frame := int(capture_frames.back())

	for frame_index in range(final_frame + 1):
		clock.seek(frame_index)
		scenario_node.apply_clock(clock)
		await get_tree().process_frame
		if _capture_mode != "Performance":
			await RenderingServer.frame_post_draw
		if capture_frames.has(frame_index):
			if not _write_capture(
				scenario,
				frame_index,
				clock,
				scenario_node,
				viewport_contract
			):
				_free_scenario_node(scenario_node)
				return

	_free_scenario_node(scenario_node)


func _write_capture(
	scenario: Dictionary,
	frame_index: int,
	clock: RefCounted,
	scenario_node: Node2D,
	viewport_contract: Dictionary
) -> bool:
	var scenario_id := String(scenario["id"])
	var basename := "%s.frame_%06d" % [scenario_id, frame_index]
	var png_path := _output_path.path_join("%s.png" % basename)
	var state_path := _output_path.path_join("%s.json" % basename)
	if FileAccess.file_exists(state_path) \
		or (_capture_mode != "Performance" and FileAccess.file_exists(png_path)):
		_fail("Capture would overwrite an existing artifact: %s." % basename)
		return false

	var expected_width := int(viewport_contract["width"])
	var expected_height := int(viewport_contract["height"])
	var png_sha256 := ""
	var screenshot_readback_count := 0
	if _capture_mode != "Performance":
		var image := get_viewport().get_texture().get_image()
		screenshot_readback_count = 1
		if image == null or image.is_empty():
			_fail("Screenshot for %s frame %d is empty." % [scenario_id, frame_index])
			return false
		if image.get_width() != expected_width or image.get_height() != expected_height:
			_fail(
				"Screenshot for %s frame %d is %dx%d; expected %dx%d."
				% [
					scenario_id,
					frame_index,
					image.get_width(),
					image.get_height(),
					expected_width,
					expected_height,
				]
			)
			return false

		var save_error := image.save_png(png_path)
		if save_error != OK or not FileAccess.file_exists(png_path):
			_fail("Screenshot write failed for '%s': %s." % [png_path, error_string(save_error)])
			return false
		var png_file := FileAccess.open(png_path, FileAccess.READ)
		if png_file == null or png_file.get_length() <= 0:
			_fail("Screenshot file is missing or empty: %s." % png_path)
			return false
		png_file.close()
		png_sha256 = FileAccess.get_sha256(png_path)
		if png_sha256.is_empty():
			_fail("Screenshot SHA-256 could not be computed: %s." % png_path)
			return false

	var scenario_state: Variant = scenario_node.get_capture_state()
	if not scenario_state is Dictionary:
		_fail(
			"Scenario '%s' get_capture_state() must return a Dictionary."
			% scenario_id
		)
		return false
	var safety_error := _json_safety_error(
		scenario_state,
		"scenario '%s' state" % scenario_id
	)
	if not safety_error.is_empty():
		_fail(safety_error)
		return false

	var semantic := _semantic_state(
		scenario,
		frame_index,
		clock,
		scenario_state,
		viewport_contract,
		png_sha256,
		screenshot_readback_count
	)
	var semantic_error := _validate_semantic_state(semantic)
	if not semantic_error.is_empty():
		_fail("Scenario '%s' semantic capture is invalid: %s" % [scenario_id, semantic_error])
		return false
	var state := {
		"schema_version": 1,
		"scenario_id": scenario_id,
		"action_id": semantic["action_id"],
		"seed": clock.seed,
		"camera_preset": _camera_preset,
		"camera_zoom": semantic["camera_zoom"],
		"capture_mode": _capture_mode,
		"frame": frame_index,
		"tick": semantic["tick"],
		"actor_id": semantic["actor_id"],
		"target_id": semantic["target_id"],
		"snapshot": semantic["snapshot"],
		"phase": semantic["phase"],
		"outcome": semantic["outcome"],
		"projected_contact": semantic["projected_contact"],
		"contact_truth": semantic["contact_truth"],
		"terrain": semantic["terrain"],
		"depth": semantic["depth"],
		"named_anchors": semantic["named_anchors"],
		"diagnostic_labels": semantic["diagnostic_labels"],
		"screenshot_readback_count": screenshot_readback_count,
		"viewport": {
			"width": expected_width,
			"height": expected_height,
			"expected_renderer": str(viewport_contract["renderer"]),
		},
		"png_sha256": png_sha256,
		"runtime": {
			"godot_version": Engine.get_version_info().get("string", "unknown"),
			"renderer": _runtime_renderer_info.duplicate(true),
		},
	}
	var state_file := FileAccess.open(state_path, FileAccess.WRITE)
	if state_file == null:
		_fail("State JSON could not be opened for writing: %s." % state_path)
		return false
	state_file.store_string(JSON.stringify(state, "\t", true, true))
	state_file.close()
	if not FileAccess.file_exists(state_path):
		_fail("State JSON was not written: %s." % state_path)
		return false

	print(
		"BB_VISUAL_CAPTURE scenario=%s frame=%d png=%s state=%s"
		% [
			scenario_id,
			frame_index,
			png_path if _capture_mode != "Performance" else "none",
			state_path,
		]
	)
	return true


func _scenario_context(scenario: Dictionary, viewport_contract: Dictionary) -> Dictionary:
	var zoom := ScenarioCatalog.camera_zoom(_camera_preset)
	return {
		"scenario_id": str(scenario["id"]),
		"seed": int(scenario["seed"]),
		"viewport_width": int(viewport_contract["width"]),
		"viewport_height": int(viewport_contract["height"]),
		"fixed_step_hz": int(viewport_contract["fixed_step_hz"]),
		"camera_preset": _camera_preset,
		"camera_zoom_x": zoom.x,
		"camera_zoom_y": zoom.y,
		"capture_mode": _capture_mode,
		"diagnostic_labels": _capture_mode == "Diagnostic",
		"arena": _real_arena,
	}


func _prepare_real_arena(scenario: Dictionary) -> void:
	if _real_arena == null:
		return
	_real_arena.process_mode = Node.PROCESS_MODE_DISABLED
	_real_arena.visible = String(scenario.get("environment", "procedural")) == "real_arena"
	var arena_camera: Variant = _real_arena.get("camera")
	if arena_camera is Camera2D:
		arena_camera.zoom = ScenarioCatalog.camera_zoom(_camera_preset)
		arena_camera.position_smoothing_enabled = false
		arena_camera.offset = Vector2.ZERO


func _semantic_state(
	scenario: Dictionary,
	frame_index: int,
	clock: RefCounted,
	scenario_state: Dictionary,
	viewport_contract: Dictionary,
	png_sha256: String,
	screenshot_readback_count: int
) -> Dictionary:
	var zoom := ScenarioCatalog.camera_zoom(_camera_preset)
	var phase := String(
		scenario_state.get("phase", scenario_state.get("attack_phase", "idle"))
	)
	var outcome := String(
		scenario_state.get("outcome", scenario_state.get("attack_outcome", "none"))
	)
	return {
		"schema_version": 1,
		"scenario_id": String(scenario["id"]),
		"action_id": String(scenario_state.get("action_id", scenario["id"])),
		"seed": int(clock.seed),
		"camera_preset": _camera_preset,
		"camera_zoom": {"x": zoom.x, "y": zoom.y},
		"capture_mode": _capture_mode,
		"frame": frame_index,
		"tick": int(scenario_state.get("tick", frame_index)),
		"actor_id": String(scenario_state.get("actor_id", "")),
		"target_id": String(scenario_state.get("target_id", "")),
		"snapshot": scenario_state.get("snapshot", {}),
		"phase": phase,
		"outcome": outcome,
		"projected_contact": bool(scenario_state.get("projected_contact", false)),
		"contact_truth": String(scenario_state.get("contact_truth", "none")),
		"terrain": String(scenario_state.get("terrain", "unknown")),
		"depth": scenario_state.get(
			"depth",
			{"elevation_state": "ground", "height_units": 0.0}
		),
		"named_anchors": scenario.get("_named_anchors", {}).duplicate(true),
		"diagnostic_labels": bool(scenario_state.get("diagnostic_labels", false)),
		"screenshot_readback_count": screenshot_readback_count,
		"viewport": {
			"width": int(viewport_contract["width"]),
			"height": int(viewport_contract["height"]),
			"expected_renderer": String(viewport_contract["renderer"]),
		},
		"png_sha256": png_sha256,
		"runtime": {},
	}


func _validate_semantic_state(state: Dictionary) -> String:
	var required := [
		"action_id", "actor_id", "target_id", "snapshot", "phase", "outcome",
		"projected_contact", "contact_truth", "terrain", "depth", "named_anchors",
	]
	for key in required:
		if not state.has(key):
			return "missing '%s'" % key
	if not state["snapshot"] is Dictionary:
		return "snapshot must be an object"
	if not String(state["phase"]) in ["idle", "startup", "active", "recovery"]:
		return "phase is outside the closed vocabulary"
	if not String(state["outcome"]) in ["none", "hit", "whiff", "released", "interrupted"]:
		return "outcome is outside the closed vocabulary"
	if not String(state["contact_truth"]) in ["none", "hit", "whiff", "blocked"]:
		return "contact_truth is outside the closed vocabulary"
	if _capture_mode == "Evaluator" and bool(state["diagnostic_labels"]):
		return "Evaluator mode forbids diagnostic labels"
	if _capture_mode == "Performance" and int(state["screenshot_readback_count"]) != 0:
		return "Performance mode forbids screenshot readback"
	return _json_safety_error(state, "semantic capture")


func _free_scenario_node(scenario_node: Node2D) -> void:
	if scenario_node.get_parent() == self:
		remove_child(scenario_node)
	scenario_node.free()


func _is_safe_run_id(candidate: String) -> bool:
	if candidate.is_empty() or candidate in [".", ".."] or ".." in candidate:
		return false
	if candidate.begins_with(".") or candidate.ends_with("."):
		return false
	if not candidate.is_valid_filename():
		return false
	for character in candidate:
		if not character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return false
	return true


func _is_nonnegative_integer(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if value is float:
		return is_finite(value) and value == floorf(value) and value >= 0.0
	return false


func _json_safety_error(value: Variant, path: String, depth: int = 0) -> String:
	if depth > 32:
		return "%s exceeds the maximum JSON nesting depth." % path
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return ""
		TYPE_FLOAT:
			if not is_finite(float(value)):
				return "%s contains a non-finite float." % path
			return ""
		TYPE_ARRAY:
			for index in range(value.size()):
				var array_error := _json_safety_error(
					value[index],
					"%s[%d]" % [path, index],
					depth + 1
				)
				if not array_error.is_empty():
					return array_error
			return ""
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING:
					return "%s contains a non-string Dictionary key." % path
				var dictionary_error := _json_safety_error(
					value[key],
					"%s.%s" % [path, key],
					depth + 1
				)
				if not dictionary_error.is_empty():
					return dictionary_error
			return ""
		_:
			return "%s contains unsupported JSON type %s." % [
				path,
				type_string(typeof(value)),
			]


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("BB_VISUAL_ERROR: %s" % message)
	get_tree().quit(1)
