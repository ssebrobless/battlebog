extends CharacterBody2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const AGGRO_RANGE_UNITS := 7.0
const BITE_RANGE_UNITS := 0.8
const BITE_DAMAGE := 4.0
const BITE_INTERVAL := 0.7
const MOVE_SPEED := 1.35
const LIFETIME_SEC := 12.0
const DISABLED_PHYSICS_LAYER := 0
const DISABLED_PHYSICS_MASK := 0

var arena: Node = null
var owner_creature: Node = null
var team := 0
var max_health := 20.0
var health := 20.0
var body_radius := 3.2
var bite_timer := 0.0
var lifetime := LIFETIME_SEC
var retired := false
var walk_phase := 0.0

func setup(pet_arena: Node, pet_owner: Node, pet_team: int, spawn_position: Vector2) -> void:
	arena = pet_arena
	owner_creature = pet_owner
	team = pet_team
	global_position = spawn_position
	collision_layer = DISABLED_PHYSICS_LAYER
	collision_mask = DISABLED_PHYSICS_MASK
	body_radius = 0.2 * SimConstants.UNIT_PX

func is_alive() -> bool:
	return not retired and health > 0.0

func is_scored_actor() -> bool:
	return false

func get_actor_name() -> String:
	return "Spiderling"

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	health -= amount
	if health <= 0.0:
		retire()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func retire() -> void:
	if retired:
		return
	retired = true
	health = 0.0
	velocity = Vector2.ZERO
	if arena != null and is_instance_valid(arena) and arena.has_method("unregister_entity"):
		arena.unregister_entity(self)
	queue_free()

func _physics_process(delta: float) -> void:
	if arena != null and arena.get("match_over") == true:
		return
	if _should_retire():
		retire()
		return
	lifetime = maxf(lifetime - delta, 0.0)
	if lifetime <= 0.0:
		retire()
		return
	bite_timer = maxf(bite_timer - delta, 0.0)
	var target := _find_enemy()
	if target != null:
		var to_enemy: Vector2 = target.global_position - global_position
		if to_enemy.length() <= BITE_RANGE_UNITS * SimConstants.UNIT_PX + target.body_radius:
			velocity = Vector2.ZERO
			if bite_timer <= 0.0:
				target.take_damage(BITE_DAMAGE, team, self)
				bite_timer = BITE_INTERVAL
		else:
			velocity = to_enemy.normalized() * SimConstants.SPEED_PX_PER_SEC * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	if velocity.length() > 4.0:
		walk_phase += delta * 12.0
	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)
	queue_redraw()

func _should_retire() -> bool:
	if owner_creature == null or not is_instance_valid(owner_creature):
		return true
	if owner_creature.has_method("is_alive") and not owner_creature.is_alive():
		return true
	return false

func _find_enemy() -> Node:
	if arena == null:
		return null
	var closest: Node = null
	var closest_distance := AGGRO_RANGE_UNITS * SimConstants.UNIT_PX
	for entity in arena.entities:
		if entity == null or not is_instance_valid(entity) or entity == self:
			continue
		if not ("team" in entity) or int(entity.team) == team:
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if entity.has_method("is_untargetable") and entity.is_untargetable():
			continue
		var distance: float = global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _draw() -> void:
	var facing := velocity.normalized() if velocity.length() > 4.0 else Vector2.RIGHT
	var side := Vector2(-facing.y, facing.x)
	var body := Color(0.22, 0.15, 0.08)
	var leg_phase := sin(walk_phase)
	draw_circle(Vector2.ZERO, body_radius + 1.2, Color(0.09, 0.06, 0.04))
	draw_circle(Vector2.ZERO, body_radius, body)
	draw_circle(facing * body_radius * 0.8, body_radius * 0.55, body.lightened(0.18))
	for i in 4:
		var t := -0.75 + float(i) * 0.5
		var root := facing * body_radius * t
		var wiggle := leg_phase * (1.0 if i % 2 == 0 else -1.0) * 1.5
		draw_line(root + side * body_radius * 0.45, root + side * (body_radius * 1.5 + wiggle), Color(0.08, 0.05, 0.03), 1.2)
		draw_line(root - side * body_radius * 0.45, root - side * (body_radius * 1.5 - wiggle), Color(0.08, 0.05, 0.03), 1.2)
	draw_circle(facing * body_radius * 1.05 + side * 0.9, 0.8, Color(0.85, 0.75, 0.45))
	draw_circle(facing * body_radius * 1.05 - side * 0.9, 0.8, Color(0.85, 0.75, 0.45))
