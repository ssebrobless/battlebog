extends RefCounted

const Hurtbox := preload("res://scripts/sim/combat/hurtbox.gd")

const DEFAULT_MELEE_DOT_MIN := 0.15

static func melee_arc(actor: Node, reach_px: float, facing_dot_min := DEFAULT_MELEE_DOT_MIN) -> Dictionary:
	var aim := _aim_direction(actor)
	var origin := _node_position(actor)
	var actor_radius := _body_radius(actor)
	return melee_arc_from(origin, aim, reach_px, actor_radius, facing_dot_min)

static func melee_arc_from(origin: Vector2, heading: Vector2, reach_px: float, actor_radius := 0.0, facing_dot_min := DEFAULT_MELEE_DOT_MIN) -> Dictionary:
	var aim := heading.normalized() if heading != Vector2.ZERO else Vector2.RIGHT
	var radius := reach_px + actor_radius
	return {
		"kind": "melee_arc",
		"origin": origin,
		"position": origin,
		"center": origin + aim * reach_px,
		"aim": aim,
		"reach_px": reach_px,
		"radius": radius,
		"facing_dot_min": facing_dot_min
	}

static func instant_line(actor: Node, range_px: float, half_width_px: float) -> Dictionary:
	var aim := _aim_direction(actor)
	var origin := _node_position(actor)
	return {
		"kind": "line",
		"from": origin,
		"to": origin + aim * range_px,
		"origin": origin,
		"aim": aim,
		"range_px": range_px,
		"half_width_px": half_width_px
	}

# Overlap checks resolve against the target's hurtbox hull (decision #21):
# circles behave exactly as the old center+radius math; capsule bodies
# (Water Snake, Alligator) are hittable along their full length.
static func overlaps_melee_arc(shape: Dictionary, target: Node) -> bool:
	return melee_arc_hit(shape, target).hit

static func melee_arc_hit(shape: Dictionary, target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	var origin: Vector2 = shape.get("origin", Vector2.ZERO)
	var aim: Vector2 = shape.get("aim", Vector2.RIGHT)
	var hull := Hurtbox.hull_of(target)
	if Hurtbox.distance_to_hull(hull, origin) > float(shape.get("radius", 0.0)):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	var to_target: Vector2 = Hurtbox.core_closest_point(hull, origin) - origin
	if to_target.normalized().dot(aim) < float(shape.get("facing_dot_min", DEFAULT_MELEE_DOT_MIN)):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	return _with_region(_point_normal_from_hull(hull, origin), target)

static func overlaps_line(shape: Dictionary, target: Node) -> bool:
	return line_hit(shape, target).hit

static func line_hit(shape: Dictionary, target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	var from: Vector2 = shape.get("from", shape.get("origin", Vector2.ZERO))
	var to: Vector2 = shape.get("to", from)
	var hull := Hurtbox.hull_of(target)
	return _with_region(Hurtbox.segment_hit(hull, from, to, float(shape.get("half_width_px", 0.0))), target)

static func circle_hit(center: Vector2, radius: float, target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	var hull := Hurtbox.hull_of(target)
	if not Hurtbox.overlaps_circle(hull, center, radius):
		return {"hit": false, "point": Vector2.ZERO, "normal": Vector2.ZERO}
	return _with_region(_point_normal_from_hull(hull, center), target)

static func _aim_direction(actor: Node) -> Vector2:
	if actor != null and is_instance_valid(actor) and actor.has_method("get_aim_direction"):
		var aim: Vector2 = actor.get_aim_direction()
		if aim != Vector2.ZERO:
			return aim.normalized()
	return Vector2.RIGHT

static func _node_position(node: Node) -> Vector2:
	if node != null and is_instance_valid(node) and node is Node2D:
		return node.global_position
	return Vector2.ZERO

static func _body_radius(node: Node) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var value: Variant = node.get("body_radius")
	return float(value) if value != null else 0.0

static func _point_normal_from_hull(hull: Dictionary, from: Vector2) -> Dictionary:
	var point := Hurtbox.surface_point(hull, from)
	var core := Hurtbox.core_closest_point(hull, from)
	var normal := (from - core).normalized() if from.distance_to(core) > 0.0001 else Vector2.RIGHT
	return {"hit": true, "point": point, "normal": normal}

static func _with_region(hit: Dictionary, target: Node) -> Dictionary:
	if not bool(hit.get("hit", false)):
		return hit
	var region := Hurtbox.region_at(target, hit.get("point", Vector2.ZERO))
	hit["region"] = String(region.get("region", "hull"))
	hit["region_mult"] = float(region.get("region_mult", 1.0))
	return hit
