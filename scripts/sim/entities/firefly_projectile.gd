extends Node2D

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const Hurtbox := preload("res://scripts/sim/combat/hurtbox.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

const HOMING_RANGE_PX := 180.0
const TURN_RATE_RAD_PER_SEC := PI * 2.0
const REVEAL_SEC := 2.0

var arena: Node = null
var source_actor: Node = null
var team := 0
var velocity := Vector2.RIGHT
var speed := 180.0
var damage := 3.0
var radius := 5.0
var lifetime := 1.0
var hit_entities: Array[Node] = []
var target: Node = null
var harvested_food := false

func setup(projectile_arena: Node, source_actor: Node, start_position: Vector2, direction: Vector2, range_px: float, projectile_damage: float) -> void:
	arena = projectile_arena
	self.source_actor = source_actor
	team = int(source_actor.team)
	global_position = start_position
	velocity = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	damage = projectile_damage
	lifetime = range_px / maxf(speed, 1.0)
	target = _find_target()

func _physics_process(delta: float) -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	target = _find_target() if target == null or not is_instance_valid(target) or not _target_ok(target) else target
	if target != null:
		var desired: Vector2 = (target.global_position - global_position).normalized()
		if desired != Vector2.ZERO:
			var angle_delta := wrapf(velocity.angle_to(desired), -PI, PI)
			velocity = velocity.rotated(clampf(angle_delta, -TURN_RATE_RAD_PER_SEC * delta, TURN_RATE_RAD_PER_SEC * delta)).normalized()
	global_position += velocity * speed * delta
	lifetime = maxf(lifetime - delta, 0.0)
	_hit_scan()
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func _hit_scan() -> void:
	if arena == null:
		return
	if not harvested_food and arena.has_method("try_harvest_food_with_hit_shape"):
		var hit_shape := {
			"kind": "circle",
			"center": global_position,
			"radius": radius
		}
		harvested_food = arena.try_harvest_food_with_hit_shape(source_actor, hit_shape, "Firefly Spark")
	for entity in arena.entities:
		if hit_entities.has(entity) or not _target_ok(entity):
			continue
		if not Hurtbox.overlaps_circle(Hurtbox.hull_of(entity), global_position, radius):
			continue
		var event := DamageEventScript.new()
		event.setup(_outgoing_damage(damage), DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, source_actor, "Firefly Spark")
		entity.take_damage_event(event)
		if entity.has_method("break_stealth"):
			entity.break_stealth()
		if entity.has_method("add_modifier"):
			entity.add_modifier("Firefly Reveal", {"revealed": 2.0}, REVEAL_SEC)
		if arena.has_method("reveal_entity_to_team"):
			arena.reveal_entity_to_team(entity, team, REVEAL_SEC)
		hit_entities.append(entity)
		queue_free()
		return

func _find_target() -> Node:
	if arena == null:
		return null
	var closest: Node = null
	var closest_distance := HOMING_RANGE_PX
	for entity in arena.entities:
		if not _target_ok(entity):
			continue
		var distance: float = global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _target_ok(entity: Node) -> bool:
	return TargetFilter.is_live_damage_target(source_actor, entity, {"allow_stealthed": true})

func _outgoing_damage(amount: float) -> float:
	if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("modify_outgoing_damage"):
		return source_actor.modify_outgoing_damage(amount)
	return amount

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 3.0, Color(1.0, 0.92, 0.25, 0.25))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.95, 0.35, 0.9))
