extends RefCounted

const CAMERA_PRESETS := {
	"PvAI": Vector2(2.6, 2.6),
	"Competitive": Vector2(2.2, 2.2),
}
const CAPTURE_MODES := ["Diagnostic", "Evaluator", "Performance"]
const ENVIRONMENTS := ["procedural", "real_arena"]


static func camera_zoom(camera_preset: String) -> Vector2:
	return CAMERA_PRESETS.get(camera_preset, Vector2.ZERO)


static func is_camera_preset_supported(camera_preset: String) -> bool:
	return CAMERA_PRESETS.has(camera_preset)


static func is_capture_mode_supported(capture_mode: String) -> bool:
	return CAPTURE_MODES.has(capture_mode)


static func validate_scenario_contract(scenario: Dictionary) -> String:
	var environment := String(scenario.get("environment", "procedural"))
	if not ENVIRONMENTS.has(environment):
		return "Scenario '%s' has unsupported environment '%s'." % [
			scenario.get("id", ""),
			environment,
		]

	if typeof(scenario.get("evaluator_safe", true)) != TYPE_BOOL:
		return "Scenario '%s' evaluator_safe must be a boolean." % scenario.get("id", "")

	var has_frames := scenario.has("capture_frames")
	var has_window := scenario.has("capture_window")
	if has_frames == has_window:
		return "Scenario '%s' must define exactly one of capture_frames or capture_window." % scenario.get("id", "")
	if has_frames:
		return _validate_capture_frames(scenario)
	return _validate_capture_window(scenario)


static func resolve_capture_frames(
	scenario: Dictionary,
	named_anchors: Dictionary
) -> Dictionary:
	if scenario.has("capture_frames"):
		return {
			"ok": true,
			"frames": scenario["capture_frames"].duplicate(),
		}

	var window: Dictionary = scenario["capture_window"]
	var anchor_name := String(window["anchor"])
	var terminal_name := String(window["through"])
	if not named_anchors.has(anchor_name):
		return _failure("Required anchor '%s' was not resolved." % anchor_name)
	if not named_anchors.has(terminal_name):
		return _failure("Required terminal anchor '%s' was not resolved." % terminal_name)

	var anchor_frame := int(named_anchors[anchor_name])
	var terminal_frame := int(named_anchors[terminal_name])
	var first_frame := maxi(anchor_frame - int(window["before_frames"]), 0)
	var final_frame := terminal_frame + 1
	if terminal_frame < anchor_frame:
		return _failure("Terminal anchor '%s' occurs before '%s'." % [terminal_name, anchor_name])
	var frames: Array[int] = []
	for frame_index in range(first_frame, final_frame + 1):
		frames.append(frame_index)
	return {
		"ok": true,
		"frames": frames,
	}


static func required_anchors(scenario: Dictionary) -> Array[String]:
	var output: Array[String] = []
	for anchor_value in scenario.get("required_anchors", []):
		output.append(String(anchor_value))
	return output


static func _validate_capture_frames(scenario: Dictionary) -> String:
	var frames: Variant = scenario.get("capture_frames")
	if not frames is Array or frames.is_empty():
		return "Scenario '%s' capture_frames must be a non-empty array." % scenario.get("id", "")
	var previous := -1
	var normalized: Array[int] = []
	for value in frames:
		if not _is_integral_number(value) or int(value) < 0:
			return "Scenario '%s' capture frames must be non-negative integers." % scenario.get("id", "")
		var frame_index := int(value)
		if frame_index <= previous:
			return "Scenario '%s' capture_frames must be unique and ascending." % scenario.get("id", "")
		normalized.append(frame_index)
		previous = frame_index
	scenario["capture_frames"] = normalized
	return ""


static func _validate_capture_window(scenario: Dictionary) -> String:
	var window: Variant = scenario.get("capture_window")
	if not window is Dictionary:
		return "Scenario '%s' capture_window must be an object." % scenario.get("id", "")
	var allowed := ["anchor", "before_frames", "through"]
	for key in window:
		if not allowed.has(String(key)):
			return "Scenario '%s' capture_window has unknown key '%s'." % [
				scenario.get("id", ""),
				key,
			]
	for key in allowed:
		if not window.has(key):
			return "Scenario '%s' capture_window is missing '%s'." % [
				scenario.get("id", ""),
				key,
			]
	var anchor := String(window.get("anchor", "")).strip_edges()
	var through := String(window.get("through", "")).strip_edges()
	if anchor.is_empty() or through.is_empty():
		return "Scenario '%s' capture_window anchors must be non-empty." % scenario.get("id", "")
	var before_value: Variant = window.get("before_frames")
	if not _is_integral_number(before_value) or int(before_value) < 0:
		return "Scenario '%s' before_frames must be a non-negative integer." % scenario.get("id", "")

	var anchors: Variant = scenario.get("required_anchors")
	if not anchors is Array or anchors.is_empty():
		return "Scenario '%s' required_anchors must be a non-empty array." % scenario.get("id", "")
	var seen := {}
	for anchor_value in anchors:
		var anchor_name := String(anchor_value).strip_edges()
		if anchor_name.is_empty() or seen.has(anchor_name):
			return "Scenario '%s' required_anchors must be unique non-empty strings." % scenario.get("id", "")
		seen[anchor_name] = true
	if not seen.has(anchor) or not seen.has(through):
		return "Scenario '%s' required_anchors must include window endpoints." % scenario.get("id", "")
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
