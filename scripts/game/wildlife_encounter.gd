extends Node2D

const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

var arena: Node = null
var team := -1
var zone_id := ""
var zone_side := ""
var zone_group := ""
var species_id := ""
var actor_name := "Wildlife"
var boss := false
var max_health := 60.0
var health := 60.0
var body_radius := 10.0
var body_capsule_half_len_px := 0.0
var alive := true

var anchor_position := Vector2.ZERO
var zone_center := Vector2.ZERO
var zone_radius := Vector2.ZERO
var wander_phase := 0.0
var wander_time := 0.0
var wander_radius := 3.0
var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
var _last_valid_constrained_position := Vector2.ZERO
var _has_valid_constrained_position := false

func setup(next_arena: Node, zone: Dictionary, next_species_id: String, spawn_position: Vector2, index := 0) -> void:
	arena = next_arena
	zone_id = String(zone.get("id", ""))
	zone_side = String(zone.get("side", "neutral"))
	zone_group = String(zone.get("group", ""))
	species_id = next_species_id
	boss = bool(zone.get("boss", false))
	actor_name = _species_label()
	body_radius = _species_radius()
	body_capsule_half_len_px = _species_capsule_half_len()
	max_health = _species_health(index)
	health = max_health
	anchor_position = spawn_position
	zone_center = Vector2(zone.get("center", spawn_position))
	zone_radius = Vector2(zone.get("radius", Vector2.ZERO))
	anchor_position = _resolve_constrained_position(spawn_position, zone_center)
	global_position = anchor_position
	wander_phase = float(abs(species_id.hash() + zone_id.hash()) % 628) / 100.0
	wander_time = 0.0
	wander_radius = 1.5 if boss else 3.0 + float(index % 3)
	z_index = 6 if boss else 5
	queue_redraw()

func is_alive() -> bool:
	return alive

func is_scored_actor() -> bool:
	return false

func is_wildlife_encounter() -> bool:
	return true

func get_actor_name() -> String:
	return actor_name

func take_damage(amount: float, _source_team := -1, source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, source_actor, "wildlife")
	take_damage_event(event)

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	var amount := maxf(float(event.amount), 0.0)
	health = maxf(health - amount, 0.0)
	_emit_hit_event(event, amount)
	queue_redraw()
	if health <= 0.0:
		_die(event.source_actor)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if knockback_timer > 0.0:
		var knockback_step := minf(delta, knockback_timer)
		anchor_position = _resolve_knockback_anchor(
			anchor_position + knockback_velocity * knockback_step
		)
		knockback_timer = maxf(knockback_timer - delta, 0.0)
		if knockback_timer <= 0.0:
			knockback_velocity = Vector2.ZERO
	wander_time += delta
	var t := wander_time
	var pace := 0.8 if boss else 1.1
	var wander_position := anchor_position + Vector2(
		cos(t * pace + wander_phase),
		sin(t * (pace * 0.7) + wander_phase * 0.6)
	) * wander_radius
	global_position = _resolve_constrained_position(wander_position, anchor_position)

func receive_knockback(direction: Vector2, distance_px: float, duration: float) -> void:
	if direction == Vector2.ZERO:
		return
	knockback_velocity = direction.normalized() * (distance_px / maxf(duration, 0.01))
	knockback_timer = maxf(duration, 0.01)

func _resolve_knockback_anchor(point: Vector2) -> Vector2:
	return _resolve_constrained_position(point, anchor_position)

func _resolve_constrained_position(point: Vector2, fallback: Vector2) -> Vector2:
	var desired := _clamp_anchor_to_zone(point)
	if arena == null or not arena.has_method("resolve_body_position"):
		_last_valid_constrained_position = desired
		_has_valid_constrained_position = true
		return desired
	var resolved: Vector2 = arena.resolve_body_position(desired, body_radius)
	resolved = _clamp_anchor_to_zone(resolved)
	if _is_terrain_safe(resolved):
		_last_valid_constrained_position = resolved
		_has_valid_constrained_position = true
		return resolved
	for step in range(1, 17):
		var candidate := _clamp_anchor_to_zone(
			desired.lerp(zone_center, float(step) / 16.0)
		)
		if _is_terrain_safe(candidate):
			_last_valid_constrained_position = candidate
			_has_valid_constrained_position = true
			return candidate
	var fallback_candidate := _clamp_anchor_to_zone(fallback)
	if _is_terrain_safe(fallback_candidate):
		_last_valid_constrained_position = fallback_candidate
		_has_valid_constrained_position = true
		return fallback_candidate
	var usable_radius := _zone_usable_radius()
	for ring in range(0, 9):
		var radius_ratio := float(ring) / 8.0
		for direction_index in 16:
			var angle := TAU * float(direction_index) / 16.0
			var candidate := zone_center + Vector2(
				cos(angle) * usable_radius.x,
				sin(angle) * usable_radius.y
			) * radius_ratio
			if _is_terrain_safe(candidate):
				_last_valid_constrained_position = candidate
				_has_valid_constrained_position = true
				return candidate
	if _has_valid_constrained_position:
		return _last_valid_constrained_position
	var terrain_fallback := fallback_candidate
	for _iteration in 32:
		var next_fallback: Vector2 = arena.resolve_body_position(
			terrain_fallback,
			body_radius
		)
		if next_fallback.is_equal_approx(terrain_fallback):
			push_error(
				"Wildlife encounter zone has no terrain-safe in-zone position: %s"
				% zone_id
			)
			return terrain_fallback
		terrain_fallback = next_fallback
	push_error(
		"Wildlife encounter terrain fallback did not converge: %s"
		% zone_id
	)
	return terrain_fallback

func _is_terrain_safe(point: Vector2) -> bool:
	return arena == null \
		or not arena.has_method("resolve_body_position") \
		or arena.resolve_body_position(point, body_radius).is_equal_approx(point)

func _clamp_anchor_to_zone(point: Vector2) -> Vector2:
	if zone_radius.x <= 0.0 or zone_radius.y <= 0.0:
		return point
	var usable_radius := _zone_usable_radius()
	var offset := point - zone_center
	var normalized := Vector2(offset.x / usable_radius.x, offset.y / usable_radius.y)
	if normalized.length_squared() <= 1.0:
		return point
	normalized = normalized.normalized()
	return zone_center + Vector2(
		normalized.x * usable_radius.x,
		normalized.y * usable_radius.y
	)

func _zone_usable_radius() -> Vector2:
	return Vector2(
		maxf(zone_radius.x - body_radius - body_capsule_half_len_px, 1.0),
		maxf(zone_radius.y - body_radius, 1.0)
	)


func _die(source_actor: Node = null) -> void:
	alive = false
	visible = false
	if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("on_kill"):
		source_actor.on_kill(self)
	if arena != null and is_instance_valid(arena) and arena.has_method("on_wildlife_defeated"):
		arena.on_wildlife_defeated(self, source_actor)
	elif arena != null and is_instance_valid(arena) and arena.has_method("unregister_entity"):
		arena.unregister_entity(self)
	queue_free()

func _emit_hit_event(event: Resource, amount: float) -> void:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("record_vfx_event"):
		return
	var hit_position: Vector2 = event.hit_position if event.hit_position != Vector2.ZERO else global_position
	arena.record_vfx_event({
		"type": "hit_landed",
		"source": event.source_actor,
		"target": self,
		"amount": amount,
		"heavy": amount >= 50.0,
		"counter_hit": false,
		"position": global_position,
		"hit_position": hit_position,
		"hit_normal": event.hit_normal,
		"region": event.region,
		"region_mult": event.region_mult,
		"source_ability": event.source_ability
	})

func _draw() -> void:
	if not alive:
		return
	var base := _species_color()
	var shadow := VisualGrammar.shadow_color(0.62)
	draw_circle(Vector2(1.5, 2.0), body_radius + 2.0, shadow)
	if body_capsule_half_len_px > 0.0:
		_draw_capsule_body(base)
	else:
		draw_circle(Vector2.ZERO, body_radius, base)
		draw_circle(Vector2(body_radius * 0.28, -body_radius * 0.18), body_radius * 0.5, base.lightened(0.14))
	if _is_flyer():
		_draw_wings(base)
	if boss:
		draw_arc(Vector2.ZERO, body_radius + 5.0, 0.0, TAU, 36, Color(1.0, 0.76, 0.28, 0.86), 3.0)
	_draw_health_bar()

func _draw_capsule_body(base: Color) -> void:
	var half_len := body_capsule_half_len_px
	var rect := Rect2(Vector2(-half_len, -body_radius), Vector2(half_len * 2.0, body_radius * 2.0))
	draw_rect(rect, base)
	draw_circle(Vector2(-half_len, 0.0), body_radius, base.darkened(0.04))
	draw_circle(Vector2(half_len, 0.0), body_radius, base.lightened(0.1))
	draw_circle(Vector2(half_len * 0.7, -body_radius * 0.25), body_radius * 0.38, base.lightened(0.18))

func _draw_wings(base: Color) -> void:
	var wing := Color(base.r, base.g, base.b, 0.42)
	draw_line(Vector2(-body_radius * 0.2, 0.0), Vector2(-body_radius * 1.35, -body_radius * 0.8), wing, 3.0)
	draw_line(Vector2(body_radius * 0.2, 0.0), Vector2(body_radius * 1.35, -body_radius * 0.8), wing.lightened(0.08), 3.0)

func _draw_health_bar() -> void:
	if health >= max_health:
		return
	var width := maxf(body_radius * 2.2, 22.0)
	var y := -body_radius - 10.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 3.0)), Color(0.05, 0.03, 0.025, 0.82))
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * ratio, 3.0)), Color(0.95, 0.72, 0.32, 0.95))

func _species_label() -> String:
	return species_id.replace("_", " ").capitalize()

func _species_radius() -> float:
	if boss:
		return 22.0
	match species_id:
		"alligator":
			return 17.0
		"great_blue_heron", "beaver", "otter":
			return 14.0
		"snapping_turtle", "water_snake", "bullfrog", "cane_toad":
			return 12.0
		"duck", "owl", "kingfisher", "mink":
			return 10.5
		"fireflies", "mosquitos", "leeches":
			return 7.5
		"water_shrew", "newt", "crayfish", "bog_turtle":
			return 8.5
		_:
			return 10.0

func _species_capsule_half_len() -> float:
	match species_id:
		"alligator":
			return body_radius * 1.2
		"water_snake":
			return body_radius * 1.6
		"otter":
			return body_radius * 0.8
		_:
			return 0.0

func _species_health(index: int) -> float:
	if boss:
		return 260.0
	return 34.0 + body_radius * 2.5 + float(index) * 3.0

func _species_color() -> Color:
	if boss:
		return Color(0.46, 0.32, 0.16)
	match species_id:
		"great_blue_heron", "owl", "kingfisher":
			return Color(0.48, 0.56, 0.68)
		"duck":
			return Color(0.36, 0.58, 0.34)
		"alligator", "water_snake", "newt":
			return Color(0.28, 0.48, 0.26)
		"snapping_turtle", "bog_turtle", "crayfish":
			return Color(0.48, 0.34, 0.2)
		"bullfrog", "cane_toad", "chorus_frog":
			return Color(0.42, 0.62, 0.26)
		"beaver", "mink", "otter", "water_shrew":
			return Color(0.38, 0.26, 0.16)
		"fireflies":
			return Color(0.9, 0.82, 0.24)
		"mosquitos", "leeches":
			return Color(0.34, 0.34, 0.36)
		_:
			return Color(0.5, 0.46, 0.3)

func _is_flyer() -> bool:
	return species_id in ["great_blue_heron", "owl", "kingfisher", "duck", "fireflies", "mosquitos"]
