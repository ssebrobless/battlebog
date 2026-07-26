extends SceneTree

const Knockback := preload("res://scripts/sim/abilities/knockback.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const WildlifeScript := preload("res://scripts/game/wildlife_encounter.gd")


class DashTarget extends Node2D:
	var dash_velocity := Vector2.ZERO
	var dash_timer := 0.0
	var steering_velocity := Vector2.ONE
	var residual_velocity := Vector2.ONE


class UnsupportedTarget extends Node2D:
	var steering_velocity := Vector2.ONE
	var residual_velocity := Vector2.ONE
	var latch_broken := false

	func break_latch(_reason: String) -> void:
		latch_broken = true


class VfxSource extends Node:
	var last_event_type := ""
	var last_payload: Dictionary = {}

	func emit_vfx_event(event_type: String, payload: Dictionary) -> void:
		last_event_type = event_type
		last_payload = payload.duplicate()


class ObstacleArena extends Node:
	var obstacle := Rect2(10.0, -5.0, 20.0, 10.0)

	func resolve_body_position(point: Vector2, radius: float) -> Vector2:
		var expanded := obstacle.grow(radius)
		if not expanded.has_point(point):
			return point
		var left_distance := absf(point.x - expanded.position.x)
		var right_distance := absf(expanded.end.x - point.x)
		var top_distance := absf(point.y - expanded.position.y)
		var bottom_distance := absf(expanded.end.y - point.y)
		var smallest := minf(
			minf(left_distance, right_distance),
			minf(top_distance, bottom_distance)
		)
		var resolved := point
		if smallest == left_distance:
			resolved.x = expanded.position.x
		elif smallest == right_distance:
			resolved.x = expanded.end.x
		elif smallest == top_distance:
			resolved.y = expanded.position.y
		else:
			resolved.y = expanded.end.y
		return resolved


func _initialize() -> void:
	var failures: Array[String] = []
	_check_creature_contract(failures)
	_check_minion_contract(failures)
	_check_wildlife_contract(failures)
	_check_unsupported_contract(failures)
	_check_duration_contract(failures)
	_check_wildlife_constraint_contract(failures)
	print("knockback_target_contract passed=%s" % str(failures.is_empty()))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_creature_contract(failures: Array[String]) -> void:
	var target := DashTarget.new()
	get_root().add_child(target)
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)
	if target.dash_velocity != Vector2(100.0, 0.0) \
		or not is_equal_approx(target.dash_timer, 0.2) \
		or target.steering_velocity != Vector2.ZERO \
		or target.residual_velocity != Vector2.ZERO:
		failures.append("creature-style dash properties did not receive knockback")
	target.free()


func _check_minion_contract(failures: Array[String]) -> void:
	var target := MinionScript.new()
	get_root().add_child(target)
	target.kind = "melee"
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)
	target.call("_tick_minion", 0.1)
	if not is_equal_approx(target.global_position.x, 10.0) \
		or not is_equal_approx(target.knockback_timer, 0.1):
		failures.append("minion adapter did not advance the requested knockback")
	target.knockback_timer = 0.0
	target.health = 0.0
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)
	if target.knockback_timer != 0.0:
		failures.append("dead minions should reject knockback")
	target.free()


func _check_wildlife_contract(failures: Array[String]) -> void:
	var target := WildlifeScript.new()
	get_root().add_child(target)
	target.setup(null, {
		"id": "test_zone",
		"side": "neutral",
		"group": "test",
		"center": Vector2.ZERO,
		"radius": Vector2(30.0, 20.0)
	}, "newt", Vector2.ZERO)
	target.wander_radius = 0.0
	Knockback.apply(null, target, Vector2.RIGHT, 30.0, 0.3)
	target._physics_process(0.1)
	if not is_equal_approx(target.global_position.x, 10.0) \
		or not is_equal_approx(target.knockback_timer, 0.2):
		failures.append("wildlife adapter did not advance the requested knockback")
	target._physics_process(0.2)
	var usable_radius: Vector2 = target.call("_zone_usable_radius")
	var normalized := Vector2(
		target.anchor_position.x / usable_radius.x,
		target.anchor_position.y / usable_radius.y
	)
	if normalized.length_squared() > 1.0001:
		failures.append("wildlife knockback should remain leashed inside its encounter zone")
	target.wander_radius = 100.0
	target._physics_process(0.0)
	var visible_offset: Vector2 = target.global_position - target.zone_center
	var visible_normalized := Vector2(
		visible_offset.x / usable_radius.x,
		visible_offset.y / usable_radius.y
	)
	if visible_normalized.length_squared() > 1.0001:
		failures.append("wildlife ambient wander should remain inside its encounter zone")
	target.knockback_timer = 0.0
	target.alive = false
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)
	if target.knockback_timer != 0.0:
		failures.append("dead wildlife should reject knockback")
	target.free()


func _check_unsupported_contract(failures: Array[String]) -> void:
	var target := UnsupportedTarget.new()
	get_root().add_child(target)
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)
	if target.global_position != Vector2.ZERO \
		or target.steering_velocity != Vector2.ONE \
		or target.residual_velocity != Vector2.ONE \
		or target.latch_broken:
		failures.append("unsupported targets should reject knockback without side effects")
	target.queue_free()
	Knockback.apply(null, target, Vector2.RIGHT, 20.0, 0.2)


func _check_duration_contract(failures: Array[String]) -> void:
	var source := VfxSource.new()
	var target := DashTarget.new()
	get_root().add_child(source)
	get_root().add_child(target)
	Knockback.apply(source, target, Vector2.RIGHT, 20.0, 0.0)
	if not is_equal_approx(target.dash_timer, 0.01) \
		or not is_equal_approx(target.dash_velocity.x, 2000.0) \
		or source.last_event_type != "dash_started" \
		or not is_equal_approx(float(source.last_payload.get("duration", 0.0)), 0.01):
		failures.append("knockback duration should normalize once for movement and VFX")
	source.free()
	target.free()


func _check_wildlife_constraint_contract(failures: Array[String]) -> void:
	var obstacle_arena := ObstacleArena.new()
	get_root().add_child(obstacle_arena)
	var obstacle_target := WildlifeScript.new()
	get_root().add_child(obstacle_target)
	obstacle_target.setup(obstacle_arena, {
		"id": "obstacle_zone",
		"side": "neutral",
		"group": "test",
		"center": Vector2.ZERO,
		"radius": Vector2(30.0, 20.0)
	}, "newt", Vector2.ZERO)
	obstacle_target.wander_radius = 0.0
	Knockback.apply(null, obstacle_target, Vector2.RIGHT, 20.0, 0.2)
	obstacle_target._physics_process(0.2)
	obstacle_target.wander_radius = 100.0
	obstacle_target._physics_process(0.0)
	var usable_radius: Vector2 = obstacle_target.call("_zone_usable_radius")
	var offset: Vector2 = obstacle_target.global_position - obstacle_target.zone_center
	var normalized := Vector2(offset.x / usable_radius.x, offset.y / usable_radius.y)
	var terrain_resolved: Vector2 = obstacle_arena.resolve_body_position(
		obstacle_target.global_position,
		obstacle_target.body_radius
	)
	if normalized.length_squared() > 1.0001 \
		or not terrain_resolved.is_equal_approx(obstacle_target.global_position):
		failures.append("wildlife movement should satisfy zone and obstacle constraints together")
	obstacle_target.free()
	obstacle_arena.free()

	var capsule_target := WildlifeScript.new()
	get_root().add_child(capsule_target)
	capsule_target.setup(null, {
		"id": "capsule_zone",
		"side": "neutral",
		"group": "test",
		"center": Vector2.ZERO,
		"radius": Vector2(80.0, 40.0)
	}, "alligator", Vector2.ZERO)
	capsule_target.wander_radius = 0.0
	Knockback.apply(null, capsule_target, Vector2.RIGHT, 120.0, 0.2)
	capsule_target._physics_process(0.2)
	var capsule_extent := (
		capsule_target.body_radius + capsule_target.body_capsule_half_len_px
	)
	if capsule_target.anchor_position.x + capsule_extent > capsule_target.zone_radius.x + 0.01:
		failures.append("capsule wildlife should keep its full horizontal hull inside the zone")
	capsule_target.free()
