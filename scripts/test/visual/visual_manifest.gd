extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1


static func load_and_validate(manifest_path: String) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		return _failure("Manifest does not exist: %s" % manifest_path)

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return _failure("Manifest could not be opened: %s" % manifest_path)

	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return _failure(
			"Manifest JSON is invalid at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)

	var manifest: Variant = parser.data
	if not manifest is Dictionary:
		return _failure("Manifest root must be a JSON object.")

	var validation_error := _validate_manifest(manifest)
	if not validation_error.is_empty():
		return _failure(validation_error)

	return {
		"ok": true,
		"manifest": manifest,
	}


static func _validate_manifest(manifest: Dictionary) -> String:
	var schema_version: Variant = manifest.get("schema_version")
	if (
		not _is_integral_number(schema_version)
		or int(schema_version) != SUPPORTED_SCHEMA_VERSION
	):
		return "Manifest schema_version must be %d." % SUPPORTED_SCHEMA_VERSION

	var viewport: Variant = manifest.get("viewport")
	if not viewport is Dictionary:
		return "Manifest viewport must be an object."
	var viewport_width: Variant = viewport.get("width")
	var viewport_height: Variant = viewport.get("height")
	if (
		not _is_integral_number(viewport_width)
		or not _is_integral_number(viewport_height)
	):
		return "Manifest viewport width and height must be integers."
	if int(viewport_width) != 1280 or int(viewport_height) != 720:
		return "Manifest viewport must be exactly 1280x720."
	if str(viewport.get("renderer", "")) != "mobile":
		return "Manifest viewport renderer must be 'mobile'."
	var fixed_step_hz: Variant = viewport.get("fixed_step_hz")
	if not _is_integral_number(fixed_step_hz):
		return "Manifest viewport fixed_step_hz must be an integer."
	if int(fixed_step_hz) <= 0:
		return "Manifest viewport fixed_step_hz must be positive."

	var scenarios: Variant = manifest.get("scenarios")
	if not scenarios is Array or scenarios.is_empty():
		return "Manifest scenarios must be a non-empty array."

	var seen_ids := {}
	for scenario_index in range(scenarios.size()):
		var scenario: Variant = scenarios[scenario_index]
		if not scenario is Dictionary:
			return "Scenario %d must be an object." % scenario_index
		var scenario_error := _validate_scenario(scenario, scenario_index, seen_ids)
		if not scenario_error.is_empty():
			return scenario_error

	return ""


static func _validate_scenario(
	scenario: Dictionary,
	scenario_index: int,
	seen_ids: Dictionary
) -> String:
	var scenario_id := str(scenario.get("id", "")).strip_edges()
	if scenario_id.is_empty():
		return "Scenario %d has an empty id." % scenario_index
	if scenario_id in [".", ".."] or not scenario_id.is_valid_filename():
		return "Scenario id '%s' is not filename-safe." % scenario_id
	if seen_ids.has(scenario_id):
		return "Scenario id '%s' is duplicated." % scenario_id
	seen_ids[scenario_id] = true

	var script_path := str(scenario.get("script", "")).strip_edges()
	if not script_path.begins_with("res://") or not script_path.ends_with(".gd"):
		return "Scenario '%s' script must be a res:// GDScript path." % scenario_id
	if not ResourceLoader.exists(script_path, "Script"):
		return "Scenario '%s' script does not exist: %s" % [scenario_id, script_path]

	var seed_value: Variant = scenario.get("seed")
	if not _is_integral_number(seed_value):
		return "Scenario '%s' seed must be an integer." % scenario_id
	scenario["seed"] = int(seed_value)

	var capture_frames: Variant = scenario.get("capture_frames")
	if not capture_frames is Array or capture_frames.is_empty():
		return "Scenario '%s' capture_frames must be a non-empty array." % scenario_id

	var previous_frame := -1
	var normalized_frames: Array[int] = []
	for frame_value in capture_frames:
		if not _is_integral_number(frame_value):
			return "Scenario '%s' capture frames must be integers." % scenario_id
		if int(frame_value) < 0:
			return "Scenario '%s' capture frames must be non-negative integers." % scenario_id
		var frame_index := int(frame_value)
		if frame_index <= previous_frame:
			return "Scenario '%s' capture_frames must be unique and ascending." % scenario_id
		previous_frame = frame_index
		normalized_frames.append(frame_index)
	scenario["capture_frames"] = normalized_frames

	return ""


static func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and value == floorf(value)
	return false


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
