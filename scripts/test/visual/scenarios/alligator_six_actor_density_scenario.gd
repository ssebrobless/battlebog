extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const SCENARIO_ID := "alligator_six_actor_density"
const TEAM_BLUE := 0
const TEAM_RED := 1
const ACTOR_COUNT := 6
const CYCLE_FRAMES := 300

const ANCHORS := {
	"SPREAD": 0,
	"CONVERGENCE": 48,
	"THREE_ATTACKS": 108,
	"PEAK_EFFECTS": 126,
	"REACQUIRE": 180,
	"AFTERMATH": 240,
	"SCENARIO_END": 299,
}

const SPREAD_POSITIONS_UNITS := [
	Vector2(-9.5, -5.0),
	Vector2(-4.5, -5.0),
	Vector2(-9.5, 0.0),
	Vector2(-4.5, 0.0),
	Vector2(-9.5, 5.0),
	Vector2(-4.5, 5.0),
]
const CONVERGENCE_POSITIONS_UNITS := [
	Vector2(-7.5, -5.0),
	Vector2(-6.0, -5.0),
	Vector2(-7.5, 0.0),
	Vector2(-6.0, 0.0),
	Vector2(-7.5, 5.0),
	Vector2(-6.0, 5.0),
]
const REACQUIRE_POSITIONS_UNITS := [
	Vector2(-8.5, -4.0),
	Vector2(-5.0, -6.0),
	Vector2(-8.5, 1.0),
	Vector2(-5.0, -1.0),
	Vector2(-8.5, 6.0),
	Vector2(-5.0, 4.0),
]

var _arena: Node = null
var _actors: Array[Node] = []
var _slot_indices: Array[int] = []
var _capture_mode := "Diagnostic"
var _viewport_width := 0
var _viewport_height := 0
var _fixed_step_hz := 60
var _last_applied_frame := -1
var _input_applied := false
var _clock_state := {
	"frame_index": 0,
	"fixed_step_hz": 60,
	"delta_seconds": 1.0 / 60.0,
	"elapsed_seconds": 0.0,
	"seed": 307,
}


static func get_fixture_descriptor() -> Dictionary:
	return {
		"blue_roster": ["alligator", "alligator", "alligator"],
		"red_roster": ["alligator", "alligator", "alligator"],
	}


func configure(context: Dictionary) -> void:
	_arena = context.get("arena")
	_capture_mode = String(context.get("capture_mode", "Diagnostic"))
	_viewport_width = int(context.get("viewport_width", 0))
	_viewport_height = int(context.get("viewport_height", 0))
	_fixed_step_hz = maxi(int(context.get("fixed_step_hz", 60)), 1)
	_actors.clear()
	_slot_indices.clear()
	_last_applied_frame = -1
	_input_applied = false
	if _arena == null:
		return
	_resolve_registered_actors()
	if _actors.size() != ACTOR_COUNT:
		push_error("%s requires six registered Alligator slots." % SCENARIO_ID)
		return
	for actor_index in ACTOR_COUNT:
		var actor := _actors[actor_index]
		actor.set_presentation_actor_id(
			StringName("fixture:%s:%d" % [SCENARIO_ID, actor_index])
		)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		actor.visible = true
		actor.set("primary_timer", 0.0)
		actor.set("q_timer", 0.0)
		actor.set("e_timer", 0.0)
	_place_spread_formation()
	_apply_camera(context)
	if _capture_mode == "Diagnostic":
		queue_redraw()


func apply_clock(clock: RefCounted) -> void:
	_clock_state = clock.snapshot()
	var requested_frame := int(_clock_state.get("frame_index", 0))
	if requested_frame < _last_applied_frame:
		push_error("%s does not support reverse clock seeks." % SCENARIO_ID)
		return
	var delta := 1.0 / float(_fixed_step_hz)
	for frame_index in range(_last_applied_frame + 1, requested_frame + 1):
		_tick_choreography(frame_index, delta)
	_last_applied_frame = requested_frame
	if _capture_mode == "Diagnostic":
		queue_redraw()


func get_named_anchors() -> Dictionary:
	return ANCHORS.duplicate()


func get_capture_state() -> Dictionary:
	var snapshots: Array[Dictionary] = []
	var body_regions: Array[Dictionary] = []
	var actor_summaries: Array[Dictionary] = []
	for actor_index in _actors.size():
		var snapshot := _snapshot_for(_actors[actor_index])
		var body_region := _actor_body_rect(_actors[actor_index], snapshot)
		snapshots.append(snapshot)
		body_regions.append(body_region)
		actor_summaries.append(
			_actor_summary(snapshot, body_region)
		)

	var primary_snapshot: Dictionary = snapshots[0] if not snapshots.is_empty() else {}
	var target_snapshot: Dictionary = snapshots[1] if snapshots.size() > 1 else {}
	var action_state := _active_action_state(primary_snapshot)
	var simulation_terrain := _terrain_for(_actors[0]) if not _actors.is_empty() else "unknown"
	var edge_distance_px := (
		_signed_water_edge_distance_px(_actors[0].global_position)
		if not _actors.is_empty()
		else 0.0
	)
	var action_outcome := String(action_state.get("outcome", "none"))
	return {
		"action_id": SCENARIO_ID,
		"actor_id": String(primary_snapshot.get("actor_id", "")),
		"target_id": String(target_snapshot.get("actor_id", "")),
		"snapshot": primary_snapshot,
		"tick": int(primary_snapshot.get("simulation_tick", 0)),
		"phase": _visual_phase(String(action_state.get("phase", "idle"))),
		"outcome": _visual_outcome(action_outcome),
		"projected_contact": bool(action_state.get("projected_contact", false)),
		"contact_truth": _contact_truth(action_outcome),
		"terrain": simulation_terrain,
		"depth": {
			"elevation_state": String(
				primary_snapshot.get("elevation_state", "ground")
			),
			"height_units": float(primary_snapshot.get("height_units", 0.0)),
		},
		"critical_regions_px": {
			"body": body_regions,
			"contact": [],
			"telegraph": [],
		},
		"scenario_evidence": {
			"action_phase": String(action_state.get("phase", "idle")),
			"presentation_band": _presentation_band(
				simulation_terrain,
				edge_distance_px
			),
			"edge_distance_px": edge_distance_px,
			"simulation_terrain": simulation_terrain,
			"actors": actor_summaries,
		},
		"diagnostic_labels": _capture_mode == "Diagnostic",
		"input_frame_applied": _input_applied,
	}


func _resolve_registered_actors() -> void:
	var registry: Variant = _arena.get("slot_registry")
	if registry == null or not registry.has_method("get_slot"):
		return
	for slot_index in 3:
		for team in [TEAM_BLUE, TEAM_RED]:
			var slot: Dictionary = registry.get_slot(team, slot_index)
			var actor: Variant = slot.get("actor")
			if actor == null or not is_instance_valid(actor) or not actor is Node:
				continue
			if String(slot.get("creature_id", "")) != "alligator":
				continue
			_actors.append(actor)
			_slot_indices.append(slot_index)


func _tick_choreography(frame_index: int, delta: float) -> void:
	if _actors.size() != ACTOR_COUNT:
		return
	var cycle_frame := posmod(frame_index, CYCLE_FRAMES)
	if cycle_frame == 0:
		_place_spread_formation()

	for actor_index in ACTOR_COUNT:
		var input_frame := InputFrameScript.new()
		input_frame.move = _movement_for(actor_index, cycle_frame)
		input_frame.aim = _actors[actor_index].global_position + Vector2.RIGHT
		if cycle_frame == int(ANCHORS["THREE_ATTACKS"]) \
			and actor_index in [0, 2, 4]:
			input_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		_actors[actor_index].set_input_frame(input_frame)

	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	if _arena.has_method("resolve_body_separation"):
		_arena.resolve_body_separation()
	for actor in _actors:
		actor.tick_sim(delta)
	for actor in _actors:
		actor.call("_process", delta)
	if _arena.has_method("_tick_telegraphs"):
		_arena.call("_tick_telegraphs", delta)
	_input_applied = true


func _movement_for(actor_index: int, cycle_frame: int) -> Vector2:
	var actor := _actors[actor_index]
	var target: Vector2 = actor.global_position
	if cycle_frame < int(ANCHORS["CONVERGENCE"]):
		target = _unit_position(SPREAD_POSITIONS_UNITS[actor_index])
	elif cycle_frame < int(ANCHORS["THREE_ATTACKS"]):
		target = _unit_position(CONVERGENCE_POSITIONS_UNITS[actor_index])
	elif cycle_frame < int(ANCHORS["REACQUIRE"]):
		target = _unit_position(CONVERGENCE_POSITIONS_UNITS[actor_index])
	elif cycle_frame < int(ANCHORS["AFTERMATH"]):
		target = _unit_position(REACQUIRE_POSITIONS_UNITS[actor_index])
	else:
		target = _unit_position(SPREAD_POSITIONS_UNITS[actor_index])
	var offset: Vector2 = target - actor.global_position
	return offset.normalized() if offset.length_squared() > 4.0 else Vector2.ZERO


func _place_spread_formation() -> void:
	for actor_index in mini(_actors.size(), ACTOR_COUNT):
		var actor := _actors[actor_index]
		actor.global_position = _unit_position(SPREAD_POSITIONS_UNITS[actor_index])
		actor.set("velocity", Vector2.ZERO)
		actor.set("steering_velocity", Vector2.ZERO)


func _unit_position(value: Vector2) -> Vector2:
	return value * SimConstants.UNIT_PX


func _apply_camera(context: Dictionary) -> void:
	var arena_camera: Variant = _arena.get("camera")
	if not arena_camera is Camera2D:
		return
	arena_camera.zoom = Vector2(
		float(context.get("camera_zoom_x", 2.6)),
		float(context.get("camera_zoom_y", 2.6))
	)
	arena_camera.position_smoothing_enabled = false
	arena_camera.offset = Vector2.ZERO


func _snapshot_for(actor: Node) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {}
	var presentation: Variant = actor.get_presentation_snapshot()
	if presentation == null:
		return {}
	return presentation.to_json_dictionary()


func _active_action_state(snapshot: Dictionary) -> Dictionary:
	var actions_value: Variant = snapshot.get("active_actions", [])
	if not actions_value is Array or actions_value.is_empty():
		return {
			"phase": "idle",
			"outcome": "none",
			"projected_contact": false,
		}
	var action_value: Variant = actions_value[0]
	if not action_value is Dictionary:
		return {
			"phase": "idle",
			"outcome": "none",
			"projected_contact": false,
		}
	var action: Dictionary = action_value
	var projected_shape: Variant = action.get("projected_shape", {})
	var projected_contact := projected_shape is Dictionary \
		and String(projected_shape.get("kind", "none")) != "none"
	return {
		"phase": String(action.get("phase", "idle")),
		"outcome": String(action.get("outcome", "none")),
		"projected_contact": projected_contact,
	}


func _actor_summary(snapshot: Dictionary, footprint: Dictionary) -> Dictionary:
	var action_state := _active_action_state(snapshot)
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
		"action_phase": String(action_state.get("phase", "idle")),
	}


func _terrain_for(actor: Node) -> String:
	if _arena != null and _arena.has_method("get_terrain_zone"):
		return String(_arena.get_terrain_zone(actor.global_position))
	return "unknown"


func _signed_water_edge_distance_px(point: Vector2) -> float:
	var terrain_map: Variant = _arena.get("terrain_map") if _arena != null else null
	if terrain_map == null or not terrain_map.has_method("get_rects"):
		return 0.0
	var nearest_distance := INF
	var inside_water := false
	for rect_value in terrain_map.get_rects("water"):
		if typeof(rect_value) != TYPE_RECT2:
			continue
		var rect: Rect2 = rect_value
		if rect.has_point(point):
			inside_water = true
			nearest_distance = minf(
				nearest_distance,
				minf(
					minf(point.x - rect.position.x, rect.end.x - point.x),
					minf(point.y - rect.position.y, rect.end.y - point.y)
				)
			)
		else:
			var nearest := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y)
			)
			nearest_distance = minf(nearest_distance, point.distance_to(nearest))
	if nearest_distance == INF:
		return 0.0
	return nearest_distance if inside_water else -nearest_distance


func _presentation_band(simulation_terrain: String, edge_distance_px: float) -> String:
	var edge_magnitude := absf(edge_distance_px)
	if simulation_terrain == "water":
		return "shallow" if edge_magnitude <= 0.75 * SimConstants.UNIT_PX else "deep"
	return "mud" if edge_magnitude <= 0.25 * SimConstants.UNIT_PX else "dry"


func _visual_phase(action_phase: String) -> String:
	match action_phase:
		"startup":
			return "startup"
		"active", "channel":
			return "active"
		"recovery", "exit", "teardown", "aftermath":
			return "recovery"
	return "idle"


func _visual_outcome(action_outcome: String) -> String:
	if action_outcome in ["hit", "whiff", "released", "interrupted"]:
		return action_outcome
	return "none"


func _contact_truth(action_outcome: String) -> String:
	if action_outcome == "hit":
		return "hit"
	if action_outcome == "whiff":
		return "whiff"
	return "none"


func _actor_body_rect(actor: Node, snapshot: Dictionary) -> Dictionary:
	var canvas_transform := (actor as Node2D).get_global_transform_with_canvas()
	var center := canvas_transform * Vector2.ZERO
	var body_radius := float(snapshot.get("body_radius_px", 1.0))
	var visual_radius := float(snapshot.get("visual_radius_px", body_radius))
	var long_extent := maxf(
		visual_radius,
		float(snapshot.get("capsule_half_length_px", 0.0)) + body_radius
	) * 1.25
	var side_extent := maxf(visual_radius, body_radius) * 1.25
	var heading_values: Array = snapshot.get("body_heading", [1.0, 0.0])
	var heading := Vector2.RIGHT
	if heading_values.size() == 2:
		heading = Vector2(
			float(heading_values[0]),
			float(heading_values[1])
		).normalized()
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
	var left := clampi(int(floor(center.x - radius_x)), 0, _viewport_width - 1)
	var top := clampi(int(floor(center.y - radius_y)), 0, _viewport_height - 1)
	var right := clampi(int(ceil(center.x + radius_x)), left + 1, _viewport_width)
	var bottom := clampi(int(ceil(center.y + radius_y)), top + 1, _viewport_height)
	return {
		"x": left,
		"y": top,
		"width": right - left,
		"height": bottom - top,
	}


func _draw() -> void:
	if _capture_mode != "Diagnostic":
		return
	var font := ThemeDB.fallback_font
	for actor_index in _actors.size():
		var actor := _actors[actor_index]
		if actor == null or not is_instance_valid(actor):
			continue
		var label := "B%d" % _slot_indices[actor_index] \
			if actor_index % 2 == 0 \
			else "R%d" % _slot_indices[actor_index]
		draw_string(
			font,
			actor.global_position + Vector2(-10.0, -28.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color.WHITE
		)
