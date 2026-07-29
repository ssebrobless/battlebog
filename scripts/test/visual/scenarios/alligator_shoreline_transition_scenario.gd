extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const SCENARIO_ID := "alligator_shoreline_transition"
const ACTOR_ID := "fixture:alligator_shoreline_transition:0"
const TARGET_ID := "fixture:alligator_shoreline_transition:1"
const FIXED_STEP_HZ := 60
const UNIT_PX := 16.0
const WATER_EDGE_X := -22.0 * UNIT_PX
const PATH_Y := -30.0 * UNIT_PX
const START_OUTSIDE_PX := 8.0
const TURN_INSIDE_PX := 20.0
const MUD_DISTANCE_PX := 0.25 * UNIT_PX
const SHALLOW_DISTANCE_PX := 0.75 * UNIT_PX
const END_SETTLE_FRAMES := 20

var _arena: Node = null
var _actor: Node = null
var _target: Node = null
var _capture_mode := "Diagnostic"
var _viewport_width := 0
var _viewport_height := 0
var _clock_state := {
	"frame_index": 0,
	"fixed_step_hz": FIXED_STEP_HZ,
	"delta_seconds": 1.0 / float(FIXED_STEP_HZ),
	"elapsed_seconds": 0.0,
	"seed": 0,
}
var _last_applied_frame := -1
var _input_applied := false
var _returning := false
var _return_frame := -1
var _anchors := {"DRY_START": 0}
var _last_band := "dry"


static func get_fixture_descriptor() -> Dictionary:
	return {
		"blue_roster": ["alligator", "chorus_frog", "mink"],
		"red_roster": ["snapping_turtle", "beaver", "otter"],
	}


func configure(context: Dictionary) -> void:
	_arena = context.get("arena")
	_capture_mode = String(context.get("capture_mode", "Diagnostic"))
	_viewport_width = int(context.get("viewport_width", 0))
	_viewport_height = int(context.get("viewport_height", 0))
	if _arena == null:
		return
	_actor = _find_fixture_actor(0, "alligator")
	_target = _find_fixture_actor(1, "snapping_turtle")
	if _actor == null or _target == null:
		return
	_actor.set_presentation_actor_id(StringName(ACTOR_ID))
	_target.set_presentation_actor_id(StringName(TARGET_ID))
	_actor.global_position = Vector2(WATER_EDGE_X - START_OUTSIDE_PX, PATH_Y)
	_target.global_position = Vector2(WATER_EDGE_X - 8.0 * UNIT_PX, PATH_Y)
	_actor.set("primary_timer", 0.0)
	_actor.set("q_timer", 0.0)
	_actor.set("e_timer", 0.0)
	_apply_camera(context)
	_hide_undeclared_creatures()
	_apply_inputs(Vector2.RIGHT)


func apply_clock(clock: RefCounted) -> void:
	_clock_state = clock.snapshot()
	var requested_frame := int(_clock_state["frame_index"])
	for frame_index in range(_last_applied_frame + 1, requested_frame + 1):
		_step_frame(frame_index, float(_clock_state["delta_seconds"]))
	_last_applied_frame = requested_frame


func get_named_anchors() -> Dictionary:
	return _anchors.duplicate()


func get_capture_state() -> Dictionary:
	var snapshot := _snapshot_for(_actor)
	var target_snapshot := _snapshot_for(_target)
	var terrain := _terrain_for(_actor)
	var edge_distance := _edge_distance_px()
	var band := _presentation_band(terrain, edge_distance)
	return {
		"action_id": "shoreline_traversal",
		"actor_id": String(snapshot.get("actor_id", "")),
		"target_id": String(target_snapshot.get("actor_id", "")),
		"snapshot": snapshot,
		"tick": int(snapshot.get("simulation_tick", 0)),
		"phase": "active" if not _anchors.has("DRY_RETURN") else "recovery",
		"outcome": "none",
		"projected_contact": false,
		"contact_truth": "none",
		"terrain": terrain,
		"depth": {
			"elevation_state": String(snapshot.get("elevation_state", "ground")),
			"height_units": float(snapshot.get("height_units", 0.0)),
		},
		"critical_regions_px": {
			"body": [_body_rect(_actor, snapshot)],
			"contact": [],
			"telegraph": [],
		},
		"diagnostic_labels": false,
		"input_frame_applied": _input_applied,
		"scenario_evidence": {
			"action_phase": "shoreline_return" if _returning else "shoreline_outbound",
			"presentation_band": band,
			"edge_distance_px": edge_distance,
			"simulation_terrain": terrain,
			"actors": [
				_actor_summary(_actor, snapshot),
				_actor_summary(_target, target_snapshot),
			],
		},
	}


func _step_frame(frame_index: int, delta: float) -> void:
	if _actor == null or _target == null:
		return
	var edge_distance := _edge_distance_px()
	if not _returning and edge_distance >= TURN_INSIDE_PX:
		_returning = true
		_return_frame = frame_index
	var move_direction := Vector2.LEFT if _returning else Vector2.RIGHT
	if _anchors.has("DRY_RETURN"):
		move_direction = Vector2.ZERO
	_apply_inputs(move_direction)
	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	if _arena.has_method("resolve_body_separation"):
		_arena.resolve_body_separation()
	for creature in [_actor, _target]:
		if creature != null and is_instance_valid(creature):
			creature.tick_sim(delta)
			creature._process(delta)
	if _arena.has_method("_tick_telegraphs"):
		_arena._tick_telegraphs(delta)
	_record_band_anchor(frame_index)
	if _anchors.has("DRY_RETURN") \
			and frame_index >= int(_anchors["DRY_RETURN"]) + END_SETTLE_FRAMES:
		_set_anchor_once("SCENARIO_END", frame_index)


func _record_band_anchor(frame_index: int) -> void:
	var terrain := _terrain_for(_actor)
	var band := _presentation_band(terrain, _edge_distance_px())
	if band == _last_band:
		return
	if not _returning:
		if band == "mud":
			_set_anchor_once("MUD_IN", frame_index)
		elif band == "shallow":
			_set_anchor_once("SHALLOW_IN", frame_index)
		elif band == "deep":
			_set_anchor_once("DEEP_IN", frame_index)
	else:
		if _last_band == "deep" and band == "shallow":
			_set_anchor_once("SHALLOW_OUT", frame_index)
		elif band == "mud":
			_set_anchor_once("MUD_OUT", frame_index)
		elif band == "dry":
			_set_anchor_once("DRY_RETURN", frame_index)
	_last_band = band


func _apply_inputs(move_direction: Vector2) -> void:
	for creature in [_actor, _target]:
		if creature == null or not is_instance_valid(creature):
			continue
		var input_frame := InputFrameScript.new()
		input_frame.move = move_direction if creature == _actor else Vector2.ZERO
		input_frame.aim = creature.global_position + Vector2.RIGHT
		creature.set_input_frame(input_frame)
	_input_applied = true


func _presentation_band(simulation_terrain: String, edge_distance_px: float) -> String:
	if simulation_terrain == "land":
		return "mud" if absf(edge_distance_px) <= MUD_DISTANCE_PX else "dry"
	if edge_distance_px <= SHALLOW_DISTANCE_PX:
		return "shallow"
	return "deep"


func _edge_distance_px() -> float:
	if _actor == null or not is_instance_valid(_actor):
		return -START_OUTSIDE_PX
	return _actor.global_position.x - WATER_EDGE_X


func _find_fixture_actor(team: int, creature_id: String) -> Node:
	var entities_value: Variant = _arena.get("entities")
	if not entities_value is Array:
		return null
	for entity in entities_value:
		if entity == null or not is_instance_valid(entity):
			continue
		var team_value: Variant = entity.get("team")
		var creature_value: Variant = entity.get("creature_id")
		if team_value == null or creature_value == null:
			continue
		if int(team_value) == team and str(creature_value) == creature_id:
			return entity
	return null


func _hide_undeclared_creatures() -> void:
	var entities_value: Variant = _arena.get("entities")
	if not entities_value is Array:
		return
	for entity in entities_value:
		if entity == null or not is_instance_valid(entity) or not entity is CanvasItem:
			continue
		if entity.has_method("get_presentation_snapshot"):
			entity.visible = entity == _actor or entity == _target


func _apply_camera(context: Dictionary) -> void:
	var arena_camera: Variant = _arena.get("camera")
	if arena_camera is Camera2D:
		if arena_camera.get_parent() != _actor:
			var parent: Node = arena_camera.get_parent()
			if parent != null:
				parent.remove_child(arena_camera)
			_actor.add_child(arena_camera)
		arena_camera.position = Vector2.ZERO
		arena_camera.zoom = Vector2(
			float(context.get("camera_zoom_x", 2.6)),
			float(context.get("camera_zoom_y", 2.6))
		)
		arena_camera.position_smoothing_enabled = false
		arena_camera.offset = Vector2.ZERO
		arena_camera.make_current()


func _snapshot_for(creature: Node) -> Dictionary:
	if creature == null or not is_instance_valid(creature):
		return {}
	var presentation: Variant = creature.get_presentation_snapshot()
	return presentation.to_json_dictionary() if presentation != null else {}


func _actor_summary(creature: Node, snapshot: Dictionary) -> Dictionary:
	var footprint := _body_rect(creature, snapshot)
	var position_values: Array = snapshot.get("world_position_px", [0.0, 0.0])
	var world_position := {"x": 0.0, "y": 0.0}
	if position_values.size() == 2:
		world_position = {
			"x": float(position_values[0]),
			"y": float(position_values[1]),
		}
	return {
		"actor_id": String(snapshot.get("actor_id", "")),
		"creature_id": String(snapshot.get("creature_id", "")),
		"team": int(snapshot.get("team", -1)),
		"alive": bool(snapshot.get("alive", false)),
		"world_position_px": world_position,
		"footprint_px": footprint,
		"action_phase": "shoreline_return" if _returning else "shoreline_outbound",
	}


func _terrain_for(creature: Node) -> String:
	if creature != null and _arena != null and _arena.has_method("get_terrain_zone"):
		return String(_arena.get_terrain_zone(creature.global_position))
	return "unknown"


func _body_rect(creature: Node, snapshot: Dictionary) -> Dictionary:
	if creature == null or not is_instance_valid(creature) or not creature is Node2D:
		return {}
	var center := (creature as Node2D).get_global_transform_with_canvas() * Vector2.ZERO
	var extent := maxf(
		float(snapshot.get("visual_radius_px", snapshot.get("body_radius_px", 1.0))),
		float(snapshot.get("body_radius_px", 1.0))
			+ float(snapshot.get("capsule_half_length_px", 0.0))
	) * 1.25
	var left := clampi(int(floor(center.x - extent)), 0, _viewport_width)
	var top := clampi(int(floor(center.y - extent)), 0, _viewport_height)
	var right := clampi(int(ceil(center.x + extent)), 0, _viewport_width)
	var bottom := clampi(int(ceil(center.y + extent)), 0, _viewport_height)
	return {
		"x": left,
		"y": top,
		"width": maxi(right - left, 1),
		"height": maxi(bottom - top, 1),
	}


func _set_anchor_once(anchor_name: String, frame_index: int) -> void:
	if not _anchors.has(anchor_name):
		_anchors[anchor_name] = frame_index
