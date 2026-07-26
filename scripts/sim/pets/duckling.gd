extends CharacterBody2D

# Duckling pet: follows its owner, pecks nearby enemies. Arena entity.

const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const AGGRO_RANGE_UNITS := 6.0
const PECK_RANGE_UNITS := 1.0
const PECK_DAMAGE := 5.0
const PECK_INTERVAL := 0.8
const FOLLOW_SPEED := 1.1
const DISABLED_PHYSICS_LAYER := 0
const DISABLED_PHYSICS_MASK := 0

var arena: Node = null
var owner_creature: Node = null
var team := 0
var max_health := 80.0
var health := 80.0
var body_radius := 4.8
var slot_index := 0
var peck_timer := 0.0
var walk_phase := 0.0
var modifiers: Array[Dictionary] = []
var retired := false

func setup(pet_arena: Node, pet_owner: Node, pet_team: int, spawn_position: Vector2, slot: int, pet_health: float) -> void:
	arena = pet_arena
	owner_creature = pet_owner
	team = pet_team
	global_position = spawn_position
	collision_layer = DISABLED_PHYSICS_LAYER
	collision_mask = DISABLED_PHYSICS_MASK
	slot_index = slot
	max_health = pet_health
	health = pet_health
	body_radius = 0.3 * SimConstants.UNIT_PX

func is_alive() -> bool:
	return not retired and health > 0.0

func is_scored_actor() -> bool:
	return false

func get_actor_name() -> String:
	return "Duckling"

func add_modifier(source: String, values: Dictionary, duration: float) -> void:
	modifiers.append({"source": source, "values": values, "remaining": duration})

func _modifier_value(key: String, fallback: float) -> float:
	var output := fallback
	for modifier in modifiers:
		var values: Dictionary = modifier.get("values", {})
		if values.has(key):
			output *= float(values[key])
	return output

func heal(amount: float) -> void:
	health = minf(health + amount, max_health)

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	health -= amount * _modifier_value("damage_taken_mult", 1.0)
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
	if _should_retire_for_owner():
		retire()
		return
	peck_timer = maxf(peck_timer - delta, 0.0)
	for i in range(modifiers.size() - 1, -1, -1):
		modifiers[i]["remaining"] = float(modifiers[i]["remaining"]) - delta
		if float(modifiers[i]["remaining"]) <= 0.0:
			modifiers.remove_at(i)

	var speed := SimConstants.SPEED_PX_PER_SEC * FOLLOW_SPEED * _modifier_value("move_speed_mult", 1.0)
	var target := _find_enemy()
	if target != null:
		var to_enemy: Vector2 = target.global_position - global_position
		if to_enemy.length() <= PECK_RANGE_UNITS * SimConstants.UNIT_PX + target.body_radius:
			velocity = Vector2.ZERO
			if peck_timer <= 0.0:
				target.take_damage(PECK_DAMAGE * _modifier_value("damage_dealt_mult", 1.0), team, self)
				peck_timer = PECK_INTERVAL / _modifier_value("attack_speed_mult", 1.0)
		else:
			velocity = to_enemy.normalized() * speed
	elif owner_creature != null and is_instance_valid(owner_creature):
		var slot_offset := Vector2(-14.0 - 9.0 * float(slot_index), 10.0 * float(slot_index % 2 * 2 - 1))
		var follow_point: Vector2 = owner_creature.global_position + slot_offset
		var to_slot := follow_point - global_position
		velocity = to_slot.normalized() * speed if to_slot.length() > 6.0 else Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	if velocity.length() > 4.0:
		walk_phase += delta * 9.0
	move_and_slide()
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)
	queue_redraw()

func _should_retire_for_owner() -> bool:
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
		if entity.team == team:
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if entity.has_method("is_stealthed") and entity.is_stealthed():
			continue
		var distance: float = global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _draw() -> void:
	var facing := velocity.normalized() if velocity.length() > 4.0 else Vector2.RIGHT
	var side := Vector2(-facing.y, facing.x)
	var body := Color(0.92, 0.82, 0.35)
	var rock := sin(walk_phase) * 0.15 if velocity.length() > 4.0 else 0.0
	var forward := facing.rotated(rock)
	draw_circle(Vector2.ZERO, body_radius + 1.5, Color(0.5, 0.42, 0.15))
	draw_circle(Vector2.ZERO, body_radius, body)
	draw_circle(forward * body_radius * 0.8, body_radius * 0.55, body)
	draw_colored_polygon(PackedVector2Array([
		forward * body_radius * 1.1 + side * body_radius * 0.2,
		forward * body_radius * 1.5,
		forward * body_radius * 1.1 - side * body_radius * 0.2
	]), Color(0.9, 0.55, 0.2))
	draw_circle(forward * body_radius * 0.85 + side * body_radius * 0.25, 1.0, Color(0.1, 0.08, 0.05))
	var ratio := clampf(health / max_health, 0.0, 1.0)
	if ratio < 1.0:
		draw_rect(Rect2(Vector2(-body_radius, -body_radius - 5.0), Vector2(body_radius * 2.0 * ratio, 2.0)), Color(0.3, 1.0, 0.45))
