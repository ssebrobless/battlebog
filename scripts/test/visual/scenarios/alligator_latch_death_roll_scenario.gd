extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

const SCENARIO_ID := "alligator_latch_death_roll"
const ACTOR_ID := "fixture:alligator_latch_death_roll:0"
const TARGET_ID := "fixture:alligator_latch_death_roll:1"
const START_FRAME := 30
const SETTLE_FRAMES := 15
const FIXED_AIM_DISTANCE_PX := 100.0
const CONTACT_OFFSET_PX := 34.0
const FIXTURE_HOLD_SOURCE := "R2C Latch Fixture Hold"
const FIXTURE_HOLD_SECONDS := 10.0

const REQUIRED_ANCHORS := [
	"BITE_TEL",
	"BITE_ACTIVE",
	"LATCH_ATTACHED",
	"ROLL_STARTUP",
	"ROLL_CHANNEL",
	"ROLL_EXIT",
	"LATCH_RELEASED",
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
var _scenario_end_frame := -1
var _initial_target_health := 0.0
var _input_applied := false


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
	var deep_water := _deep_water_point()
	_actor.global_position = deep_water - Vector2.RIGHT * CONTACT_OFFSET_PX * 0.5
	_target.global_position = deep_water + Vector2.RIGHT * CONTACT_OFFSET_PX * 0.5
	_actor.last_aim_direction = Vector2.RIGHT
	_actor.body_heading = Vector2.RIGHT
	_target.last_aim_direction = Vector2.LEFT
	_target.body_heading = Vector2.LEFT
	_initial_target_health = float(_target.get("health"))
	_apply_camera(context)
	_hide_undeclared_creatures()
	_apply_inputs(0)
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
	var action_phase := _exact_action_phase(snapshot)
	var primary_action := _find_action(snapshot, "alligator_bite")
	var phase := _canonical_phase(action_phase)
	var outcome := String(primary_action.get("outcome", "none"))
	var simulation_terrain := _terrain_at(_actor.global_position)
	var edge_distance := _water_edge_distance_px(_actor.global_position)
	var body_rect := _body_rect(_actor, snapshot)
	var target_rect := _body_rect(_target, target_snapshot)
	var latch_attached: bool = _actor.get("latch_victim") == _target

	return {
		"action_id": (
			"alligator_death_roll"
			if action_phase in ["startup", "channel", "exit"]
			else "alligator_bite"
		),
		"actor_id": String(snapshot.get("actor_id", ACTOR_ID)),
		"target_id": String(target_snapshot.get("actor_id", TARGET_ID)),
		"snapshot": snapshot,
		"tick": int(snapshot.get("simulation_tick", 0)),
		"phase": phase,
		"outcome": outcome,
		"projected_contact": latch_attached or _anchors.has("BITE_ACTIVE"),
		"contact_truth": "hit" if _anchors.has("BITE_ACTIVE") else "none",
		"terrain": simulation_terrain,
		"depth": {
			"elevation_state": String(snapshot.get("elevation_state", "ground")),
			"height_units": float(snapshot.get("height_units", 0.0)),
		},
		"critical_regions_px": {
			"body": [body_rect, target_rect],
			"contact": [_pair_region(body_rect, target_rect)] if _anchors.has("BITE_ACTIVE") else [],
			"telegraph": [_pair_region(body_rect, target_rect)] if phase == "startup" else [],
		},
		"scenario_evidence": {
			"action_phase": action_phase,
			"presentation_band": _presentation_band(simulation_terrain, edge_distance),
			"edge_distance_px": edge_distance,
			"simulation_terrain": simulation_terrain,
			"actors": [
				_actor_summary(_actor, snapshot, body_rect, action_phase),
				_actor_summary(
					_target,
					target_snapshot,
					target_rect,
					"latched" if latch_attached else "idle"
				),
			],
		},
		"diagnostic_labels": _capture_mode == "Diagnostic",
		"input_frame_applied": _input_applied,
	}


func _advance_one_frame(frame_index: int) -> void:
	if not _is_live_node(_actor) or not _is_live_node(_target):
		return
	_apply_inputs(frame_index)
	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	if _arena.has_method("resolve_body_separation"):
		_arena.resolve_body_separation()
	_actor.tick_sim(_delta_seconds)
	_target.tick_sim(_delta_seconds)
	_actor._process(_delta_seconds)
	_target._process(_delta_seconds)
	if _arena.has_method("_tick_telegraphs"):
		_arena._tick_telegraphs(_delta_seconds)
	_discover_anchors(frame_index)


func _apply_inputs(frame_index: int) -> void:
	var actor_buttons := 0
	if frame_index >= START_FRAME and not _anchors.has("ROLL_EXIT"):
		actor_buttons = (
			InputFrameScript.BUTTON_PRIMARY
			| InputFrameScript.BUTTON_ABILITY_Q
		)
	_actor.set_input_frame(_input_frame(_actor, Vector2.RIGHT, actor_buttons))
	_target.set_input_frame(_input_frame(_target, Vector2.LEFT, 0))
	_input_applied = true


func _discover_anchors(frame_index: int) -> void:
	var snapshot := _snapshot_of(_actor)
	var bite := _find_action(snapshot, "alligator_bite")
	var roll := _find_action(snapshot, "alligator_death_roll")
	var bite_phase := String(bite.get("phase", ""))
	var roll_phase := String(roll.get("phase", ""))
	if bite_phase == "startup":
		_record_anchor("BITE_TEL", frame_index)
	if float(_target.get("health")) < _initial_target_health:
		_record_anchor("BITE_ACTIVE", frame_index)
	if _actor.get("latch_victim") == _target \
			and _anchors.has("BITE_ACTIVE") \
			and frame_index > int(_anchors["BITE_ACTIVE"]):
		_record_anchor("LATCH_ATTACHED", frame_index)
	if roll_phase == "startup" \
			and _anchors.has("LATCH_ATTACHED") \
			and frame_index > int(_anchors["LATCH_ATTACHED"]):
		_record_anchor("ROLL_STARTUP", frame_index)
	elif roll_phase == "channel":
		_record_anchor("ROLL_CHANNEL", frame_index)
	elif roll_phase == "teardown":
		_record_anchor("ROLL_EXIT", frame_index)
	if _anchors.has("ROLL_EXIT") \
			and frame_index > int(_anchors["ROLL_EXIT"]) \
			and _actor.get("latch_victim") == null:
		_record_anchor("LATCH_RELEASED", frame_index)
		if _scenario_end_frame < 0:
			_scenario_end_frame = frame_index + SETTLE_FRAMES
	if _scenario_end_frame >= 0 and frame_index >= _scenario_end_frame:
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


func _deep_water_point() -> Vector2:
	var terrain_map: Variant = _arena.get("terrain_map")
	if terrain_map == null or not terrain_map.has_method("get_rects"):
		return Vector2.ZERO
	var offsets := [
		Vector2.ZERO,
		Vector2(64.0, 0.0),
		Vector2(-64.0, 0.0),
		Vector2(0.0, 64.0),
		Vector2(0.0, -64.0),
	]
	for rect_value in terrain_map.get_rects(TerrainMapScript.WATER):
		if not rect_value is Rect2:
			continue
		var candidate: Vector2 = (rect_value as Rect2).get_center()
		var surrounded := true
		for offset in offsets:
			if String(terrain_map.get_zone_at(candidate + offset)) != TerrainMapScript.WATER:
				surrounded = false
				break
		if surrounded:
			return candidate
	return Vector2.ZERO


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


func _exact_action_phase(snapshot: Dictionary) -> String:
	var roll := _find_action(snapshot, "alligator_death_roll")
	if not roll.is_empty():
		var phase := String(roll.get("phase", "idle"))
		return "exit" if phase == "teardown" else phase
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
	action_phase: String
) -> Dictionary:
	var position: Vector2 = creature.global_position if _is_live_node(creature) else Vector2.ZERO
	return {
		"actor_id": String(snapshot.get("actor_id", "")),
		"creature_id": String(snapshot.get("creature_id", "")),
		"team": int(snapshot.get("team", 0)),
		"alive": bool(snapshot.get("alive", false)),
		"world_position_px": {"x": position.x, "y": position.y},
		"footprint_px": footprint,
		"action_phase": action_phase,
	}


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
	var phase := _exact_action_phase(_snapshot_of(_actor))
	var resolved_count := 0
	for anchor_name in REQUIRED_ANCHORS:
		if _anchors.has(anchor_name):
			resolved_count += 1
	draw_rect(Rect2(18.0, 18.0, 356.0, 72.0), Color(0.02, 0.07, 0.08, 0.90))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(34.0, 48.0),
		"ALLIGATOR LATCH / DEATH ROLL",
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
