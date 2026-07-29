extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const SCENARIO_ID := "alligator_death_respawn"
const ACTOR_ID := "fixture:alligator_death_respawn:0"
const TARGET_ID := "fixture:alligator_death_respawn:1"
const START_FRAME := 30
const LETHAL_OFFSET_FRAMES := 9
const RESPAWN_SETTLE_FRAMES := 15
const SCENARIO_END_OFFSET_FRAMES := 30
const FIXED_AIM_DISTANCE_PX := 100.0
const CONTACT_OFFSET_PX := 34.0
const FIXTURE_HOLD_SOURCE := "R2C Death Fixture Hold"
const FIXTURE_HOLD_SECONDS := 10.0

const REQUIRED_ANCHORS := [
	"BITE_TEL",
	"LETHAL_DAMAGE",
	"DEATH",
	"RESPAWN",
	"RESPAWN_SETTLED",
	"SCENARIO_END",
]

var _arena: Node = null
var _actor: Node = null
var _target: Node = null
var _capture_mode := "Diagnostic"
var _viewport_width := 1280
var _viewport_height := 720
var _delta_seconds := 1.0 / 60.0
var _last_applied_frame := -1
var _anchors := {}
var _lethal_frame := START_FRAME + LETHAL_OFFSET_FRAMES
var _respawn_frame := -1
var _input_applied := false
var _last_known_actor_footprint := {"x": 0, "y": 0, "width": 1, "height": 1}
var _last_known_actor_position := Vector2.ZERO


static func get_fixture_descriptor() -> Dictionary:
	return {
		"blue_roster": ["alligator", "chorus_frog", "mink"],
		"red_roster": ["alligator", "beaver", "otter"],
	}


func configure(context: Dictionary) -> void:
	_arena = context.get("arena")
	_capture_mode = String(context.get("capture_mode", "Diagnostic"))
	_viewport_width = int(context.get("viewport_width", 1280))
	_viewport_height = int(context.get("viewport_height", 720))
	_delta_seconds = 1.0 / float(maxi(int(context.get("fixed_step_hz", 60)), 1))
	if _arena == null:
		return
	_actor = _arena.get("player")
	_target = _first_enemy_creature()
	if not _is_live_node(_actor) or not _is_live_node(_target):
		return

	_actor.set_presentation_actor_id(StringName(ACTOR_ID))
	_target.set_presentation_actor_id(StringName(TARGET_ID))
	_zero_action_debt(_actor)
	_zero_action_debt(_target)
	_target.add_modifier(
		FIXTURE_HOLD_SOURCE,
		{"move_speed_mult": 0.0, "can_act_mult": 0.0},
		FIXTURE_HOLD_SECONDS
	)
	var land_point := _stable_land_point()
	_actor.global_position = land_point
	_target.global_position = land_point + Vector2.RIGHT * CONTACT_OFFSET_PX
	_actor.last_aim_direction = Vector2.RIGHT
	_actor.body_heading = Vector2.RIGHT
	_target.last_aim_direction = Vector2.LEFT
	_target.body_heading = Vector2.LEFT
	_apply_camera(context)
	_hide_undeclared_creatures()
	_apply_inputs(0)
	_refresh_last_known_footprint()
	if _capture_mode == "Diagnostic":
		queue_redraw()


func apply_clock(clock: RefCounted) -> void:
	var clock_state: Dictionary = clock.snapshot()
	var requested_frame := int(clock_state.get("frame_index", 0))
	if requested_frame < _last_applied_frame:
		return
	for frame_index in range(_last_applied_frame + 1, requested_frame + 1):
		_advance_one_frame(frame_index)
	_last_applied_frame = requested_frame
	if _capture_mode == "Diagnostic":
		queue_redraw()


func get_named_anchors() -> Dictionary:
	return _anchors.duplicate(true)


func get_capture_state() -> Dictionary:
	var snapshot := _snapshot_of(_actor)
	var target_snapshot := _snapshot_of(_target)
	var alive := bool(snapshot.get("alive", false))
	var action_phase := _lifecycle_action_phase(snapshot)
	var phase := _canonical_phase(action_phase)
	var body_rect := (
		_body_rect(_actor, snapshot)
		if alive
		else _last_known_actor_footprint.duplicate(true)
	)
	var target_rect := _body_rect(_target, target_snapshot)
	var simulation_terrain := _terrain_at(
		_actor.global_position if alive else _last_known_actor_position
	)
	var edge_distance := _water_edge_distance_px(
		_actor.global_position if alive else _last_known_actor_position
	)
	var primary_action := _find_action(snapshot, "alligator_bite")

	return {
		"action_id": "alligator_death_respawn",
		"actor_id": String(snapshot.get("actor_id", ACTOR_ID)),
		"target_id": String(target_snapshot.get("actor_id", TARGET_ID)),
		"snapshot": snapshot,
		"tick": int(snapshot.get("simulation_tick", 0)),
		"phase": phase,
		"outcome": String(primary_action.get("outcome", "none")),
		"projected_contact": phase == "startup",
		"contact_truth": "none",
		"terrain": simulation_terrain,
		"depth": {
			"elevation_state": String(snapshot.get("elevation_state", "ground")),
			"height_units": float(snapshot.get("height_units", 0.0)),
		},
		"critical_regions_px": {
			"body": [body_rect],
			"contact": [],
			"telegraph": [_pair_region(body_rect, target_rect)] if phase == "startup" else [],
		},
		"scenario_evidence": {
			"action_phase": action_phase,
			"presentation_band": _presentation_band(simulation_terrain, edge_distance),
			"edge_distance_px": edge_distance,
			"simulation_terrain": simulation_terrain,
			"actors": [
				_actor_summary(
					_actor,
					snapshot,
					body_rect,
					action_phase,
					_last_known_actor_position if not alive else _actor.global_position
				),
				_actor_summary(_target, target_snapshot, target_rect, "idle", _target.global_position),
			],
		},
		"diagnostic_labels": _capture_mode == "Diagnostic",
		"input_frame_applied": _input_applied,
	}


func _advance_one_frame(frame_index: int) -> void:
	if not _is_live_node(_actor) or not _is_live_node(_target):
		return
	if bool(_actor.get("alive")):
		_refresh_last_known_footprint()
	_apply_inputs(frame_index)
	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	if _arena.has_method("resolve_body_separation"):
		_arena.resolve_body_separation()
	if frame_index == _lethal_frame and bool(_actor.get("alive")):
		_record_anchor("LETHAL_DAMAGE", frame_index)
		_actor.take_damage(
			float(_actor.get("max_health")) * 2.0,
			int(_target.get("team")),
			_target
		)
	_actor.tick_sim(_delta_seconds)
	_target.tick_sim(_delta_seconds)
	_actor._process(_delta_seconds)
	_target._process(_delta_seconds)
	if _arena.has_method("_tick_telegraphs"):
		_arena._tick_telegraphs(_delta_seconds)
	_discover_anchors(frame_index)


func _apply_inputs(frame_index: int) -> void:
	var actor_buttons := (
		InputFrameScript.BUTTON_PRIMARY
		if frame_index >= START_FRAME and frame_index < _lethal_frame
		else 0
	)
	_actor.set_input_frame(_input_frame(_actor, Vector2.RIGHT, actor_buttons))
	_target.set_input_frame(_input_frame(_target, Vector2.LEFT, 0))
	_input_applied = true


func _discover_anchors(frame_index: int) -> void:
	var snapshot := _snapshot_of(_actor)
	var bite := _find_action(snapshot, "alligator_bite")
	if String(bite.get("phase", "")) == "startup":
		_record_anchor("BITE_TEL", frame_index)
	if not bool(snapshot.get("alive", true)) \
			and _anchors.has("LETHAL_DAMAGE") \
			and frame_index > int(_anchors["LETHAL_DAMAGE"]):
		_record_anchor("DEATH", frame_index)
	elif _anchors.has("DEATH"):
		_record_anchor("RESPAWN", frame_index)
		if _respawn_frame < 0:
			_respawn_frame = frame_index
	if _respawn_frame >= 0 and frame_index >= _respawn_frame + RESPAWN_SETTLE_FRAMES:
		_record_anchor("RESPAWN_SETTLED", frame_index)
	if _respawn_frame >= 0 and frame_index >= _respawn_frame + SCENARIO_END_OFFSET_FRAMES:
		_record_anchor("SCENARIO_END", frame_index)


func _record_anchor(anchor_name: String, frame_index: int) -> void:
	if not _anchors.has(anchor_name):
		_anchors[anchor_name] = frame_index


func _input_frame(actor: Node, heading: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Vector2.ZERO
	frame.aim = actor.global_position + heading * FIXED_AIM_DISTANCE_PX
	frame.buttons = buttons
	return frame


func _first_enemy_creature() -> Node:
	var bots_value: Variant = _arena.get("bots")
	if not bots_value is Array:
		return null
	for candidate in bots_value:
		if _is_live_node(candidate) \
				and candidate.has_method("get_presentation_snapshot") \
				and int(candidate.get("team")) != int(_actor.get("team")):
			return candidate
	return null


func _zero_action_debt(creature: Node) -> void:
	creature.set("primary_timer", 0.0)
	creature.set("q_timer", 0.0)
	creature.set("e_timer", 0.0)
	creature.set("velocity", Vector2.ZERO)
	creature.set("steering_velocity", Vector2.ZERO)
	creature.set("residual_velocity", Vector2.ZERO)


func _stable_land_point() -> Vector2:
	var candidates := [
		Vector2(-1000.0, -480.0),
		Vector2(-800.0, -320.0),
		Vector2(-640.0, 0.0),
		Vector2(640.0, 0.0),
	]
	for candidate in candidates:
		if _terrain_at(candidate) == TerrainMapScript.LAND \
				and _terrain_at(candidate + Vector2.RIGHT * CONTACT_OFFSET_PX) \
				== TerrainMapScript.LAND:
			return candidate
	return _arena.get_team_spawn(int(_actor.get("team")))


func _snapshot_of(creature: Node) -> Dictionary:
	if not _is_live_node(creature) or not creature.has_method("get_presentation_snapshot"):
		return {}
	var presentation: Variant = creature.get_presentation_snapshot()
	return presentation.to_json_dictionary() if presentation != null else {}


func _find_action(snapshot: Dictionary, action_id: String) -> Dictionary:
	var actions_value: Variant = snapshot.get("active_actions", [])
	if not actions_value is Array:
		return {}
	for action_value in actions_value:
		if action_value is Dictionary \
				and String((action_value as Dictionary).get("action_id", "")) == action_id:
			return action_value
	return {}


func _lifecycle_action_phase(snapshot: Dictionary) -> String:
	if not bool(snapshot.get("alive", false)):
		return "dead"
	if _anchors.has("RESPAWN_SETTLED"):
		return "settled"
	if _anchors.has("RESPAWN"):
		return "respawned"
	var bite := _find_action(snapshot, "alligator_bite")
	return String(bite.get("phase", "idle"))


func _canonical_phase(action_phase: String) -> String:
	match action_phase:
		"startup":
			return "startup"
		"active", "channel":
			return "active"
		"recovery", "exit", "teardown":
			return "recovery"
		_:
			return "idle"


func _terrain_at(point: Vector2) -> String:
	return String(_arena.get_terrain_zone(point)) if _arena.has_method("get_terrain_zone") else "unknown"


func _water_edge_distance_px(point: Vector2) -> float:
	var terrain_map: Variant = _arena.get("terrain_map")
	if terrain_map == null or not terrain_map.has_method("get_rects"):
		return 0.0
	var deepest_inside := -INF
	var nearest_outside := INF
	for rect_value in terrain_map.get_rects(TerrainMapScript.WATER):
		if not rect_value is Rect2:
			continue
		var rect: Rect2 = rect_value
		if rect.has_point(point):
			var inside_distance := minf(
				minf(point.x - rect.position.x, rect.end.x - point.x),
				minf(point.y - rect.position.y, rect.end.y - point.y)
			)
			deepest_inside = maxf(deepest_inside, inside_distance)
		else:
			var nearest := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y)
			)
			nearest_outside = minf(nearest_outside, point.distance_to(nearest))
	if deepest_inside > -INF:
		return deepest_inside
	return -nearest_outside if nearest_outside < INF else 0.0


func _presentation_band(simulation_terrain: String, edge_distance_px: float) -> String:
	if simulation_terrain == TerrainMapScript.WATER:
		return "shallow" if edge_distance_px <= 12.0 else "deep"
	if simulation_terrain == TerrainMapScript.SHALLOW:
		return "shallow"
	return "mud" if edge_distance_px >= -4.0 else "dry"


func _actor_summary(
	creature: Node,
	snapshot: Dictionary,
	footprint: Dictionary,
	action_phase: String,
	position: Vector2
) -> Dictionary:
	return {
		"actor_id": String(snapshot.get("actor_id", "")),
		"creature_id": String(snapshot.get("creature_id", "")),
		"team": int(snapshot.get("team", 0)),
		"alive": bool(snapshot.get("alive", false)),
		"world_position_px": {"x": position.x, "y": position.y},
		"footprint_px": footprint,
		"action_phase": action_phase,
	}


func _refresh_last_known_footprint() -> void:
	var snapshot := _snapshot_of(_actor)
	_last_known_actor_footprint = _body_rect(_actor, snapshot)
	_last_known_actor_position = _actor.global_position


func _body_rect(creature: Node, snapshot: Dictionary) -> Dictionary:
	if not _is_live_node(creature) or not creature is Node2D:
		return {"x": 0, "y": 0, "width": 1, "height": 1}
	var transform := (creature as Node2D).get_global_transform_with_canvas()
	var center := transform * Vector2.ZERO
	var radius := maxf(float(snapshot.get("visual_radius_px", 1.0)), 1.0)
	var body_radius := maxf(float(snapshot.get("body_radius_px", radius)), 1.0)
	var half_length := maxf(float(snapshot.get("capsule_half_length_px", 0.0)), 0.0)
	var long_extent := maxf(radius, half_length + body_radius) * 1.25
	var side_extent := maxf(radius, body_radius) * 1.25
	var heading := _heading_from_snapshot(snapshot)
	var side := heading.orthogonal()
	var screen_forward := (transform * heading) - center
	var screen_side := (transform * side) - center
	var radius_x := absf(screen_forward.x) * long_extent + absf(screen_side.x) * side_extent
	var radius_y := absf(screen_forward.y) * long_extent + absf(screen_side.y) * side_extent
	return _clamped_rect(
		center.x - radius_x,
		center.y - radius_y,
		center.x + radius_x,
		center.y + radius_y
	)


func _heading_from_snapshot(snapshot: Dictionary) -> Vector2:
	var values: Variant = snapshot.get("body_heading", [1.0, 0.0])
	if values is Array and values.size() == 2:
		var heading := Vector2(float(values[0]), float(values[1]))
		if not heading.is_zero_approx():
			return heading.normalized()
	return Vector2.RIGHT


func _pair_region(a: Dictionary, b: Dictionary) -> Dictionary:
	var left := minf(float(a["x"]), float(b["x"]))
	var top := minf(float(a["y"]), float(b["y"]))
	var right := maxf(float(a["x"] + a["width"]), float(b["x"] + b["width"]))
	var bottom := maxf(float(a["y"] + a["height"]), float(b["y"] + b["height"]))
	return _clamped_rect(left, top, right, bottom)


func _clamped_rect(left: float, top: float, right: float, bottom: float) -> Dictionary:
	var x := clampi(int(floor(left)), 0, maxi(_viewport_width - 1, 0))
	var y := clampi(int(floor(top)), 0, maxi(_viewport_height - 1, 0))
	var x2 := clampi(int(ceil(right)), x + 1, maxi(_viewport_width, x + 1))
	var y2 := clampi(int(ceil(bottom)), y + 1, maxi(_viewport_height, y + 1))
	return {"x": x, "y": y, "width": x2 - x, "height": y2 - y}


func _apply_camera(context: Dictionary) -> void:
	var arena_camera: Variant = _arena.get("camera")
	if arena_camera is Camera2D:
		arena_camera.zoom = Vector2(
			float(context.get("camera_zoom_x", 2.6)),
			float(context.get("camera_zoom_y", 2.6))
		)
		arena_camera.position_smoothing_enabled = false
		arena_camera.offset = Vector2.ZERO


func _hide_undeclared_creatures() -> void:
	var entities_value: Variant = _arena.get("entities")
	if not entities_value is Array:
		return
	for entity in entities_value:
		if not _is_live_node(entity) or not entity is CanvasItem:
			continue
		if entity.has_method("get_presentation_snapshot"):
			entity.visible = entity == _actor or entity == _target


func _is_live_node(value: Variant) -> bool:
	return value != null and value is Node and is_instance_valid(value)


func _draw() -> void:
	if _capture_mode != "Diagnostic":
		return
	var snapshot := _snapshot_of(_actor)
	var phase := _lifecycle_action_phase(snapshot)
	var resolved_count := 0
	for anchor_name in REQUIRED_ANCHORS:
		if _anchors.has(anchor_name):
			resolved_count += 1
	draw_rect(Rect2(18.0, 18.0, 356.0, 72.0), Color(0.02, 0.07, 0.08, 0.90))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(34.0, 48.0),
		"ALLIGATOR DEATH / RESPAWN",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color(0.92, 0.96, 0.91)
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(34.0, 75.0),
		"phase %s   anchors %d/%d" % [phase, resolved_count, REQUIRED_ANCHORS.size()],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(0.56, 0.83, 0.75)
	)
