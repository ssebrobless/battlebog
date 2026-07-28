extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const FIRST_ANCHOR := "NEUTRAL+0"
const TERMINAL_ANCHOR := "NEUTRAL_END"
const TERMINAL_FRAME := 30

var _arena: Node = null
var _actor: Node = null
var _target: Node = null
var _clock_state := {
	"frame_index": 0,
	"fixed_step_hz": 60,
	"delta_seconds": 1.0 / 60.0,
	"elapsed_seconds": 0.0,
	"seed": 0,
}
var _capture_mode := "Diagnostic"
var _input_applied := false
var _last_applied_frame := -1
var _viewport_width := 0
var _viewport_height := 0


func configure(context: Dictionary) -> void:
	_arena = context.get("arena")
	_capture_mode = String(context.get("capture_mode", "Diagnostic"))
	_viewport_width = int(context.get("viewport_width", 0))
	_viewport_height = int(context.get("viewport_height", 0))
	if _arena == null:
		return
	_actor = _arena.get("player")
	var arena_bots: Variant = _arena.get("bots")
	if arena_bots is Array:
		for candidate in arena_bots:
			if candidate != null and is_instance_valid(candidate) \
				and int(candidate.get("team")) != int(_actor.get("team")):
				_target = candidate
				break
	_apply_camera(context)
	_hide_undeclared_creatures()
	_apply_neutral_input()


func apply_clock(clock: RefCounted) -> void:
	_clock_state = clock.snapshot()
	var requested_frame := int(_clock_state["frame_index"])
	if requested_frame < _last_applied_frame:
		_last_applied_frame = -1
	for _frame_index in range(_last_applied_frame + 1, requested_frame + 1):
		_tick_declared_creatures(float(_clock_state["delta_seconds"]))
	_last_applied_frame = requested_frame


func get_named_anchors() -> Dictionary:
	return {
		FIRST_ANCHOR: 0,
		TERMINAL_ANCHOR: TERMINAL_FRAME,
	}


func get_capture_state() -> Dictionary:
	var snapshot := {}
	var actor_id := ""
	var terrain_zone := "unknown"
	var elevation_state := "ground"
	var height_units := 0.0
	if _actor != null and is_instance_valid(_actor):
		var presentation: Variant = _actor.get_presentation_snapshot()
		if presentation != null:
			snapshot = presentation.to_json_dictionary()
			actor_id = String(snapshot.get("actor_id", ""))
			elevation_state = String(snapshot.get("elevation_state", "ground"))
			height_units = float(snapshot.get("height_units", 0.0))
		if _arena.has_method("get_terrain_zone"):
			terrain_zone = String(_arena.get_terrain_zone(_actor.global_position))

	var target_id := ""
	if _target != null and is_instance_valid(_target):
		var target_snapshot: Variant = _target.get_presentation_snapshot()
		if target_snapshot != null:
			target_id = String(target_snapshot.to_json_dictionary().get("actor_id", ""))

	return {
		"action_id": "neutral_idle",
		"actor_id": actor_id,
		"target_id": target_id,
		"snapshot": snapshot,
		"tick": int(snapshot.get("simulation_tick", 0)),
		"phase": String(snapshot.get("attack_phase", "idle")),
		"outcome": String(snapshot.get("attack_outcome", "none")),
		"projected_contact": false,
		"contact_truth": "none",
		"terrain": terrain_zone,
		"depth": {
			"elevation_state": elevation_state,
			"height_units": height_units,
		},
		"critical_regions_px": {
			"body": [_actor_body_rect(snapshot)],
			"contact": [],
			"telegraph": [],
		},
		"diagnostic_labels": _capture_mode == "Diagnostic",
		"input_frame_applied": _input_applied,
	}


func _actor_body_rect(snapshot: Dictionary) -> Dictionary:
	if _actor == null or not is_instance_valid(_actor) or not _actor is Node2D:
		return {}
	var canvas_transform := (_actor as Node2D).get_global_transform_with_canvas()
	var center := canvas_transform * Vector2.ZERO
	var legacy_cues: Dictionary = snapshot.get("kit_cues", {}).get(
		"legacy_motion_state",
		{}
	)
	var body_radius := float(snapshot.get("body_radius_px", 0.0))
	var visual_radius := float(snapshot.get("visual_radius_px", body_radius))
	var long_extent := maxf(
		visual_radius,
		float(snapshot.get("capsule_half_length_px", 0.0)) + body_radius
	)
	long_extent = maxf(
		long_extent,
		float(legacy_cues.get("long_body_visual_length_px", 0.0)) * 0.5
	)
	long_extent = maxf(
		long_extent,
		float(legacy_cues.get("footprint_length_px", 0.0)) * 0.5
	)
	var side_extent := maxf(
		visual_radius,
		float(legacy_cues.get("thin_overhang_radius_px", 0.0))
	)
	# Procedural appendages can exceed the core metrics slightly.
	long_extent *= 1.25
	side_extent *= 1.25
	var heading_values: Array = snapshot.get("body_heading", [1.0, 0.0])
	var heading := Vector2.RIGHT
	if heading_values.size() == 2:
		heading = Vector2(float(heading_values[0]), float(heading_values[1])).normalized()
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	var side := heading.orthogonal()
	var screen_forward := (canvas_transform * heading) - center
	var screen_side := (canvas_transform * side) - center
	var radius_x := (
		absf(screen_forward.x) * long_extent
		+ absf(screen_side.x) * side_extent
	)
	var radius_y := (
		absf(screen_forward.y) * long_extent
		+ absf(screen_side.y) * side_extent
	)
	var left := clampi(int(floor(center.x - radius_x)), 0, _viewport_width)
	var top := clampi(int(floor(center.y - radius_y)), 0, _viewport_height)
	var right := clampi(int(ceil(center.x + radius_x)), 0, _viewport_width)
	var bottom := clampi(int(ceil(center.y + radius_y)), 0, _viewport_height)
	return {
		"x": left,
		"y": top,
		"width": right - left,
		"height": bottom - top,
	}


func _apply_camera(context: Dictionary) -> void:
	var arena_camera: Variant = _arena.get("camera")
	if arena_camera is Camera2D:
		arena_camera.zoom = Vector2(
			float(context.get("camera_zoom_x", 2.6)),
			float(context.get("camera_zoom_y", 2.6))
		)
		arena_camera.position_smoothing_enabled = false


func _apply_neutral_input() -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var input_frame := InputFrameScript.new()
	input_frame.move = Vector2.ZERO
	input_frame.aim = Vector2.RIGHT
	_actor.set_input_frame(input_frame)
	_input_applied = true


func _tick_declared_creatures(delta: float) -> void:
	if _arena == null:
		return
	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	for creature in [_actor, _target]:
		if creature == null or not is_instance_valid(creature):
			continue
		var input_frame := InputFrameScript.new()
		input_frame.move = Vector2.ZERO
		input_frame.aim = Vector2.RIGHT
		creature.set_input_frame(input_frame)
		creature.tick_sim(delta)
	_input_applied = true


func _hide_undeclared_creatures() -> void:
	if _arena == null:
		return
	var arena_entities: Variant = _arena.get("entities")
	if not arena_entities is Array:
		return
	for entity in arena_entities:
		if entity == null or not is_instance_valid(entity) or not entity is CanvasItem:
			continue
		if entity.has_method("get_presentation_snapshot"):
			entity.visible = entity == _actor or entity == _target
