extends Node2D

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const SCENARIO_ID := "alligator_player_camera_attack"
const ACTOR_ID := "fixture:alligator_player_camera_attack:0"
const TARGET_ID := "fixture:alligator_player_camera_attack:1"
const FIXED_STEP_HZ := 60
const ATTACK_START_FRAME := 5
const STARTUP_HALF_FRAMES := 9
const INTER_ATTACK_GAP_FRAMES := 8
const END_SETTLE_FRAMES := 8
const UNIT_PX := 16.0
const ACTOR_START := Vector2(-30.0 * UNIT_PX, -30.0 * UNIT_PX)
const INTERRUPT_SOURCE := "r2c_fixture_interrupt"

enum Segment {
	HIT,
	WAIT_WHIFF,
	WHIFF,
	WAIT_INTERRUPT,
	INTERRUPT,
	DONE,
}

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
var _segment := Segment.HIT
var _segment_started_frame := -1
var _attack_started_frame := -1
var _interrupt_applied := false
var _anchors := {}


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
	_actor.global_position = ACTOR_START
	_actor.set("primary_timer", 0.0)
	_actor.set("q_timer", 0.0)
	_actor.set("e_timer", 0.0)
	_place_target_for_hit()
	_apply_camera(context)
	_hide_undeclared_creatures()
	_apply_inputs(false)


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
	var attack := _primary_attack_state(snapshot)
	var phase := String(attack.get("phase", "idle"))
	var outcome := String(attack.get("outcome", "none"))
	var projected_shape: Dictionary = attack.get("projected_shape", {})
	var contact_point_value: Variant = attack.get("contact_point_px")
	var contact_point := Vector2.ZERO
	var has_contact_point := _json_vector2(contact_point_value, contact_point)
	if has_contact_point:
		contact_point = _vector2_from_json(contact_point_value)
	var terrain := _terrain_for(_actor)
	var projected_contact := not projected_shape.is_empty()
	var contact_truth := "none"
	if outcome == "hit":
		contact_truth = "hit"
	elif outcome == "whiff":
		contact_truth = "whiff"
	var action_phase := phase
	if _segment == Segment.WAIT_WHIFF:
		action_phase = "hit_end"
	elif _segment == Segment.WAIT_INTERRUPT:
		action_phase = "whiff_end"
	elif _segment == Segment.DONE:
		action_phase = "scenario_end"

	var contact_regions := []
	if has_contact_point:
		contact_regions.append(_point_rect(contact_point, 10.0))
	var telegraph_regions := []
	if phase == "startup" and not projected_shape.is_empty():
		var shape_rect := _shape_rect(projected_shape)
		if not shape_rect.is_empty():
			telegraph_regions.append(shape_rect)

	return {
		"action_id": "alligator_bite",
		"actor_id": String(snapshot.get("actor_id", "")),
		"target_id": String(target_snapshot.get("actor_id", "")),
		"snapshot": snapshot,
		"tick": int(snapshot.get("simulation_tick", 0)),
		"phase": phase,
		"outcome": outcome,
		"projected_contact": projected_contact,
		"contact_truth": contact_truth,
		"terrain": terrain,
		"depth": {
			"elevation_state": String(snapshot.get("elevation_state", "ground")),
			"height_units": float(snapshot.get("height_units", 0.0)),
		},
		"critical_regions_px": {
			"body": [_body_rect(_actor, snapshot), _body_rect(_target, target_snapshot)],
			"contact": contact_regions,
			"telegraph": telegraph_regions,
		},
		"diagnostic_labels": false,
		"input_frame_applied": _input_applied,
		"scenario_evidence": {
			"action_phase": action_phase,
			"presentation_band": "dry",
			"edge_distance_px": -1.0,
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
	_update_choreography_before_tick(frame_index)
	_apply_inputs(_should_press_primary(frame_index))
	_arena.set("simulation_tick", int(_arena.get("simulation_tick")) + 1)
	if _arena.has_method("resolve_body_separation"):
		_arena.resolve_body_separation()
	for creature in [_actor, _target]:
		if creature != null and is_instance_valid(creature):
			creature.tick_sim(delta)
			creature._process(delta)
	if _arena.has_method("_tick_telegraphs"):
		_arena._tick_telegraphs(delta)
	_record_phase_anchors(frame_index)
	_advance_segment_after_tick(frame_index)


func _update_choreography_before_tick(frame_index: int) -> void:
	if _segment == Segment.WAIT_WHIFF and _ready_for_next_attack(frame_index):
		_segment = Segment.WHIFF
		_segment_started_frame = frame_index
		_attack_started_frame = -1
		_place_target_for_whiff()
	elif _segment == Segment.WAIT_INTERRUPT and _ready_for_next_attack(frame_index):
		_segment = Segment.INTERRUPT
		_segment_started_frame = frame_index
		_attack_started_frame = -1
		_interrupt_applied = false
		_place_target_for_hit()
	if _segment == Segment.INTERRUPT \
			and _attack_started_frame >= 0 \
			and not _interrupt_applied \
			and frame_index == _attack_started_frame + STARTUP_HALF_FRAMES:
		_actor.add_modifier(
			INTERRUPT_SOURCE,
			{"can_act_mult": 0.0},
			0.25
		)
		_interrupt_applied = true
		_anchors["INTERRUPT_APPLIED"] = frame_index


func _apply_inputs(primary_pressed: bool) -> void:
	for creature in [_actor, _target]:
		if creature == null or not is_instance_valid(creature):
			continue
		var input_frame := InputFrameScript.new()
		input_frame.move = Vector2.ZERO
		input_frame.aim = creature.global_position + Vector2.RIGHT
		if creature == _actor:
			input_frame.set_button(InputFrameScript.BUTTON_PRIMARY, primary_pressed)
		creature.set_input_frame(input_frame)
	_input_applied = true


func _should_press_primary(frame_index: int) -> bool:
	match _segment:
		Segment.HIT:
			return frame_index == ATTACK_START_FRAME
		Segment.WHIFF, Segment.INTERRUPT:
			return frame_index == _segment_started_frame
	return false


func _record_phase_anchors(frame_index: int) -> void:
	var snapshot := _snapshot_for(_actor)
	var attack := _primary_attack_state(snapshot)
	var phase := String(attack.get("phase", "idle"))
	var outcome := String(attack.get("outcome", "none"))
	match _segment:
		Segment.HIT:
			if phase == "startup":
				_set_anchor_once("HIT_TEL", frame_index)
				if _attack_started_frame < 0:
					_attack_started_frame = frame_index
			elif phase == "active":
				_set_anchor_once("HIT_ACTIVE", frame_index)
			elif phase == "recovery" and outcome == "hit":
				_set_anchor_once("HIT_RECOVERY", frame_index)
		Segment.WHIFF:
			if phase == "startup":
				_set_anchor_once("WHIFF_TEL", frame_index)
				if _attack_started_frame < 0:
					_attack_started_frame = frame_index
			elif phase == "active":
				_set_anchor_once("WHIFF_ACTIVE", frame_index)
			elif phase == "recovery" and outcome == "whiff":
				_set_anchor_once("WHIFF_RECOVERY", frame_index)
		Segment.INTERRUPT:
			if phase == "startup":
				_set_anchor_once("INTERRUPT_TEL", frame_index)
				if _attack_started_frame < 0:
					_attack_started_frame = frame_index
			elif phase == "recovery" and outcome == "interrupted":
				_set_anchor_once("INTERRUPT_RECOVERY", frame_index)


func _advance_segment_after_tick(frame_index: int) -> void:
	var attack := _primary_attack_state(_snapshot_for(_actor))
	var phase := String(attack.get("phase", "idle"))
	if _segment == Segment.HIT \
			and _anchors.has("HIT_RECOVERY") \
			and phase == "idle":
		_anchors["HIT_END"] = frame_index
		_segment = Segment.WAIT_WHIFF
		_segment_started_frame = frame_index
	elif _segment == Segment.WHIFF \
			and _anchors.has("WHIFF_RECOVERY") \
			and phase == "idle":
		_anchors["WHIFF_END"] = frame_index
		_segment = Segment.WAIT_INTERRUPT
		_segment_started_frame = frame_index
	elif _segment == Segment.INTERRUPT \
			and _anchors.has("INTERRUPT_RECOVERY") \
			and phase == "idle":
		_segment = Segment.DONE
		_segment_started_frame = frame_index
	elif _segment == Segment.DONE \
			and frame_index >= _segment_started_frame + END_SETTLE_FRAMES:
		_set_anchor_once("SCENARIO_END", frame_index)


func _ready_for_next_attack(frame_index: int) -> bool:
	return frame_index >= _segment_started_frame + INTER_ATTACK_GAP_FRAMES \
		and float(_actor.get("primary_timer")) <= 0.0


func _place_target_for_hit() -> void:
	var actor_radius := float(_actor.get("body_radius"))
	var target_radius := float(_target.get("body_radius"))
	var reach_px := UNIT_PX
	_target.global_position = _actor.global_position \
		+ Vector2.RIGHT * (actor_radius + reach_px + target_radius)


func _place_target_for_whiff() -> void:
	_place_target_for_hit()
	_target.global_position += Vector2.RIGHT * float(_target.get("body_radius"))


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


func _primary_attack_state(snapshot: Dictionary) -> Dictionary:
	var actions_value: Variant = snapshot.get("active_actions", [])
	if actions_value is Array:
		for action_value in actions_value:
			if action_value is Dictionary \
					and String(action_value.get("action_id", "")) == "alligator_bite":
				return {
					"phase": String(action_value.get("phase", "idle")),
					"outcome": String(action_value.get("outcome", "none")),
					"projected_shape": action_value.get("projected_shape", {}),
					"contact_point_px": action_value.get("contact_point_px"),
				}
	return {"phase": "idle", "outcome": "none", "projected_shape": {}}


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
		"action_phase": String(_primary_attack_state(snapshot).get("phase", "idle")),
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
	return _screen_rect(center, Vector2(extent, extent))


func _shape_rect(shape: Dictionary) -> Dictionary:
	var origin := _vector2_from_json(shape.get("origin_px", [0.0, 0.0]))
	var radius := float(shape.get("radius_px", 1.0))
	var heading := _vector2_from_json(shape.get("heading", [1.0, 0.0]))
	var center := origin + heading * radius
	var origin_screen := _world_to_screen(origin)
	var center_screen := _world_to_screen(center)
	var minimum := Vector2(
		minf(origin_screen.x, center_screen.x) - radius,
		minf(origin_screen.y, center_screen.y) - radius
	)
	var maximum := Vector2(
		maxf(origin_screen.x, center_screen.x) + radius,
		maxf(origin_screen.y, center_screen.y) + radius
	)
	return _screen_rect((minimum + maximum) * 0.5, (maximum - minimum) * 0.5)


func _point_rect(world_point: Vector2, radius: float) -> Dictionary:
	return _screen_rect(_world_to_screen(world_point), Vector2(radius, radius))


func _world_to_screen(world_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_point


func _screen_rect(center: Vector2, extent: Vector2) -> Dictionary:
	var left := clampi(int(floor(center.x - extent.x)), 0, _viewport_width)
	var top := clampi(int(floor(center.y - extent.y)), 0, _viewport_height)
	var right := clampi(int(ceil(center.x + extent.x)), 0, _viewport_width)
	var bottom := clampi(int(ceil(center.y + extent.y)), 0, _viewport_height)
	return {
		"x": left,
		"y": top,
		"width": maxi(right - left, 1),
		"height": maxi(bottom - top, 1),
	}


func _json_vector2(value: Variant, _fallback: Vector2) -> bool:
	return value is Array and value.size() == 2


func _vector2_from_json(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _set_anchor_once(anchor_name: String, frame_index: int) -> void:
	if not _anchors.has(anchor_name):
		_anchors[anchor_name] = frame_index
