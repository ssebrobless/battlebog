extends Node2D

const VisualManifest := preload("res://scripts/test/visual/visual_manifest.gd")
const VisualRegressionClock := preload("res://scripts/test/visual/visual_regression_clock.gd")
const DEFAULT_MANIFEST_PATH := "res://tests/visual/manifest.json"
const DEFAULT_OUTPUT_ROOT := "res://artifacts/visual-regression"

var _mode := "capture"
var _manifest_path := DEFAULT_MANIFEST_PATH
var _selected_scenario_id := ""
var _run_id := ""
var _output_path := ""
var _failed := false
var _runtime_renderer_info := {}


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _parse_arguments() -> void:
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


func _run() -> void:
	if not _mode in ["capture", "list", "validate"]:
		_fail("Unknown mode '%s'. Expected capture, list, or validate." % _mode)
		return

	var load_result := VisualManifest.load_and_validate(_manifest_path)
	if not bool(load_result.get("ok", false)):
		_fail(str(load_result.get("error", "Unknown manifest error.")))
		return

	var manifest: Dictionary = load_result["manifest"]
	var scenarios := _select_scenarios(manifest["scenarios"])
	if scenarios.is_empty():
		_fail("No scenario matched '%s'." % _selected_scenario_id)
		return

	var exercise_scenarios := _mode in ["validate", "capture"]
	if not await _validate_scenario_scripts(
		scenarios,
		manifest["viewport"],
		exercise_scenarios
	):
		return

	if _mode == "list":
		for scenario in scenarios:
			print(
				"BB_VISUAL_SCENARIO id=%s seed=%d frames=%s"
				% [scenario["id"], int(scenario["seed"]), str(scenario["capture_frames"])]
			)
		print("BB_VISUAL_LIST_COMPLETE count=%d" % scenarios.size())
		get_tree().quit(0)
		return

	if _mode == "validate":
		print(
			"BB_VISUAL_VALIDATE_OK scenarios=%d manifest=%s"
			% [scenarios.size(), _manifest_path]
		)
		get_tree().quit(0)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	if not _validate_render_contract(manifest["viewport"]):
		return
	if not _prepare_output_directory():
		return

	for scenario in scenarios:
		await _capture_scenario(scenario, manifest["viewport"])
		if _failed:
			return

	print(
		"BB_VISUAL_CAPTURE_COMPLETE run_id=%s scenarios=%d output=%s"
		% [_run_id, scenarios.size(), _output_path]
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


func _validate_scenario_scripts(
	scenarios: Array,
	viewport_contract: Dictionary,
	exercise_scenarios: bool
) -> bool:
	for scenario in scenarios:
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
		if exercise_scenarios:
			instance.process_mode = Node.PROCESS_MODE_DISABLED
			instance.configure(_scenario_context(scenario, viewport_contract))
			add_child(instance)
			instance.process_mode = Node.PROCESS_MODE_DISABLED

			var clock := VisualRegressionClock.new()
			clock.configure(
				int(scenario["seed"]),
				int(viewport_contract["fixed_step_hz"])
			)
			var validation_frames: Array[int] = [int(scenario["capture_frames"].front())]
			var final_frame := int(scenario["capture_frames"].back())
			if final_frame != validation_frames.front():
				validation_frames.append(final_frame)
			for frame_index in validation_frames:
				clock.seek(frame_index)
				instance.apply_clock(clock)
				await get_tree().process_frame
				var state: Variant = instance.get_capture_state()
				if not state is Dictionary:
					_free_scenario_node(instance)
					_fail(
						"Scenario '%s' get_capture_state() must return a Dictionary."
						% scenario["id"]
					)
					return false
				var safety_error := _json_safety_error(
					state,
					"scenario '%s' state" % scenario["id"]
				)
				if not safety_error.is_empty():
					_free_scenario_node(instance)
					_fail(safety_error)
					return false
			_free_scenario_node(instance)
			continue
		instance.free()
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
	var scenario_id := str(scenario["id"])
	var script_resource: Script = load(str(scenario["script"]))
	var scenario_node: Node2D = script_resource.new()
	scenario_node.process_mode = Node.PROCESS_MODE_DISABLED
	scenario_node.configure(_scenario_context(scenario, viewport_contract))
	add_child(scenario_node)
	scenario_node.process_mode = Node.PROCESS_MODE_DISABLED

	var clock := VisualRegressionClock.new()
	clock.configure(int(scenario["seed"]), int(viewport_contract["fixed_step_hz"]))
	var capture_frames: Array = scenario["capture_frames"]
	var final_frame := int(capture_frames.back())

	for frame_index in range(final_frame + 1):
		clock.seek(frame_index)
		scenario_node.apply_clock(clock)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if capture_frames.has(frame_index):
			if not _write_capture(
				scenario_id,
				frame_index,
				clock,
				scenario_node,
				viewport_contract
			):
				_free_scenario_node(scenario_node)
				return

	_free_scenario_node(scenario_node)


func _write_capture(
	scenario_id: String,
	frame_index: int,
	clock: RefCounted,
	scenario_node: Node2D,
	viewport_contract: Dictionary
) -> bool:
	var basename := "%s.frame_%06d" % [scenario_id, frame_index]
	var png_path := _output_path.path_join("%s.png" % basename)
	var state_path := _output_path.path_join("%s.json" % basename)
	if FileAccess.file_exists(png_path) or FileAccess.file_exists(state_path):
		_fail("Capture would overwrite an existing artifact: %s." % basename)
		return false
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Screenshot for %s frame %d is empty." % [scenario_id, frame_index])
		return false

	var expected_width := int(viewport_contract["width"])
	var expected_height := int(viewport_contract["height"])
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
		_fail(
			"Screenshot write failed for '%s': %s."
			% [png_path, error_string(save_error)]
		)
		return false
	var png_file := FileAccess.open(png_path, FileAccess.READ)
	if png_file == null or png_file.get_length() <= 0:
		_fail("Screenshot file is missing or empty: %s." % png_path)
		return false
	png_file.close()
	var png_sha256 := FileAccess.get_sha256(png_path)
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

	var state := {
		"schema_version": 1,
		"scenario_id": scenario_id,
		"capture_frame": frame_index,
		"seed": clock.seed,
		"clock": clock.snapshot(),
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
		"scenario_state": scenario_state,
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
		% [scenario_id, frame_index, png_path, state_path]
	)
	return true


func _scenario_context(scenario: Dictionary, viewport_contract: Dictionary) -> Dictionary:
	return {
		"scenario_id": str(scenario["id"]),
		"seed": int(scenario["seed"]),
		"viewport_width": int(viewport_contract["width"]),
		"viewport_height": int(viewport_contract["height"]),
		"fixed_step_hz": int(viewport_contract["fixed_step_hz"]),
	}


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
