extends RefCounted

const HitShape := preload("res://scripts/sim/combat/hit_shape.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

static func build_shape(actor: Node, reach_px: float, strike_heading: Vector2, opts: Dictionary = {}) -> Dictionary:
	if actor == null or not is_instance_valid(actor) or not actor is Node2D:
		return {}
	if not is_finite(reach_px) or reach_px < 0.0:
		return {}
	if not strike_heading.is_finite() or strike_heading.is_zero_approx():
		return {}
	var facing_value: Variant = opts.get("facing_dot_min", HitShape.DEFAULT_MELEE_DOT_MIN)
	if not _is_finite_number(facing_value):
		return {}
	var facing_dot_min := float(facing_value)
	if facing_dot_min < -1.0 or facing_dot_min > 1.0:
		return {}
	var origin: Vector2 = (actor as Node2D).global_position
	var has_actor_radius := "body_radius" in actor
	var actor_radius_value: Variant = actor.get("body_radius") if has_actor_radius else null
	var actor_radius: float = float(actor_radius_value) if actor_radius_value != null else 0.0
	if not is_finite(actor_radius) or actor_radius < 0.0:
		return {}
	return HitShape.melee_arc_from(origin, strike_heading, reach_px, actor_radius, facing_dot_min)

static func query(actor: Node, shape: Dictionary, opts: Dictionary = {}) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if not _is_valid_melee_shape(shape):
		return contacts
	var arena := _actor_arena(actor)
	if arena == null:
		return contacts
	var entities_value: Variant = arena.get("entities")
	if not entities_value is Array:
		return contacts

	var target_opts := {"allow_wildlife": bool(opts.get("allow_wildlife", true))}
	var entity_snapshot: Array = (entities_value as Array).duplicate()
	for value in entity_snapshot:
		if typeof(value) != TYPE_OBJECT or not is_instance_valid(value) or not value is Node:
			continue
		var target := value as Node
		if not TargetFilter.is_live_blind_damage_target(actor, target, target_opts):
			continue
		var hit_info := HitShape.melee_arc_hit(shape, target)
		if not bool(hit_info.get("hit", false)):
			continue
		contacts.append({
			"target": target,
			"point": hit_info.get("point", Vector2.ZERO),
			"normal": hit_info.get("normal", Vector2.ZERO),
			"region": String(hit_info.get("region", "hull")),
			"region_mult": float(hit_info.get("region_mult", 1.0))
		})
	return contacts

static func resolve(
	actor: Node,
	shape: Dictionary,
	contacts: Array[Dictionary],
	damage: float,
	delivery: int,
	plane: int,
	source_ability: String,
	opts: Dictionary = {}
) -> Dictionary:
	var result := _empty_resolution()
	if not _is_valid_melee_shape(shape):
		return result
	var arena := _actor_arena(actor)
	if arena == null:
		return result
	var shape_snapshot := shape.duplicate(true)
	var contact_snapshot := _snapshot_contacts(contacts)
	var core_center: Vector2 = shape_snapshot["center"]
	var core_reach: float = float(shape_snapshot["reach_px"])

	if int(plane) == 0 and bool(opts.get("allow_harvest", true)) and arena.has_method("try_harvest_food_with_hit_shape"):
		result["harvest_hit"] = bool(arena.try_harvest_food_with_hit_shape(actor, shape_snapshot, source_ability))
	if not is_instance_valid(actor) or not is_instance_valid(arena):
		if bool(result["harvest_hit"]):
			result["outcome"] = "harvest"
		return result

	var hits: Array = result["hits"]
	var hit_records: Array = result["hit_records"]
	var max_hits := int(opts.get("max_hits", 0))
	var normal_hit_count := 0
	var target_opts := {"allow_wildlife": bool(opts.get("allow_wildlife", true))}
	for contact in contact_snapshot:
		if max_hits > 0 and normal_hit_count >= max_hits:
			break
		if not is_instance_valid(actor):
			break
		var target_value: Variant = contact.get("target")
		if typeof(target_value) != TYPE_OBJECT or not is_instance_valid(target_value) or not target_value is Node:
			continue
		var target := target_value as Node
		if not TargetFilter.is_live_blind_damage_target(actor, target, target_opts):
			continue
		var event: Resource = actor.make_damage_event(damage, delivery, plane, source_ability)
		var point: Vector2 = contact.get("point", Vector2.ZERO)
		var normal: Vector2 = contact.get("normal", Vector2.ZERO)
		var region := String(contact.get("region", "hull"))
		var region_mult := float(contact.get("region_mult", 1.0))
		event.set_hit(point, normal, region, region_mult)
		target.take_damage_event(event)
		hits.append(target)
		hit_records.append({
			"target": target,
			"point": point,
			"normal": normal,
			"region": region,
			"region_mult": region_mult,
			"contact_kind": "normal"
		})
		normal_hit_count += 1

	if not is_instance_valid(actor):
		return _finalize_resolution(result)

	# Thrashing (decision #33): a victim's melee always connects with its own
	# latcher, regardless of facing, arc, or the normal-contact max_hits cap.
	var latcher_value: Variant = actor.get("latched_attacker") if "latched_attacker" in actor else null
	if typeof(latcher_value) == TYPE_OBJECT and is_instance_valid(latcher_value) and latcher_value is Node:
		var latcher := latcher_value as Node
		var latch_victim: Variant = latcher.get("latch_victim") if "latch_victim" in latcher else null
		if is_instance_valid(latcher) and latch_victim == actor and not hits.has(latcher) and TargetFilter.is_live_blind_damage_target(actor, latcher, target_opts):
			latcher.take_damage_event(actor.make_damage_event(damage, delivery, plane, source_ability))
			hits.append(latcher)
			hit_records.append({
				"target": latcher,
				"point": Vector2.ZERO,
				"normal": Vector2.ZERO,
				"region": "",
				"region_mult": 1.0,
				"contact_kind": "latcher"
			})

	if is_instance_valid(actor) and is_instance_valid(arena) and actor.has_method("damage_enemy_cores_near"):
		var core_result: Variant = actor.damage_enemy_cores_near(
			core_center,
			core_reach,
			damage,
			source_ability
		)
		if core_result is Array:
			var core_hits: Array = result["core_hits"]
			for core in core_result:
				if typeof(core) == TYPE_OBJECT and is_instance_valid(core) and core is Node:
					core_hits.append(core)

	return _finalize_resolution(result)

static func _finalize_resolution(result: Dictionary) -> Dictionary:
	var hits: Array = result["hits"]
	result["hit_count"] = hits.size()
	if not hits.is_empty() or not (result["core_hits"] as Array).is_empty():
		result["outcome"] = "hit"
	elif bool(result["harvest_hit"]):
		result["outcome"] = "harvest"
	return result

static func hit(actor: Node, reach_px: float, damage: float, delivery: int, plane: int, source_ability: String, opts: Dictionary = {}) -> Array:
	if _actor_arena(actor) == null:
		return []
	var shape := HitShape.melee_arc(actor, reach_px)
	if actor.has_method("emit_vfx_event"):
		var payload := shape.duplicate()
		payload.merge({
			"actor": actor,
			"position": actor.global_position,
			"source_ability": source_ability
		})
		actor.emit_vfx_event("attack_swung", payload)
	var contacts := query(actor, shape, opts)
	var resolution := resolve(actor, shape, contacts, damage, delivery, plane, source_ability, opts)
	return resolution["hits"]

static func _empty_resolution() -> Dictionary:
	return {
		"outcome": "whiff",
		"hits": [],
		"hit_records": [],
		"hit_count": 0,
		"harvest_hit": false,
		"core_hits": []
	}

static func _actor_arena(actor: Node) -> Node:
	if actor == null or not is_instance_valid(actor) or not "arena" in actor:
		return null
	var arena_value: Variant = actor.get("arena")
	if typeof(arena_value) != TYPE_OBJECT or not is_instance_valid(arena_value) or not arena_value is Node:
		return null
	return arena_value as Node

static func _is_valid_melee_shape(shape: Dictionary) -> bool:
	if String(shape.get("kind", "")) != "melee_arc":
		return false
	for field in ["origin", "position", "center", "aim"]:
		var vector_value: Variant = shape.get(field)
		if not vector_value is Vector2 or not (vector_value as Vector2).is_finite():
			return false
	var aim: Vector2 = shape["aim"]
	if aim.is_zero_approx() or not is_equal_approx(aim.length(), 1.0):
		return false
	for field in ["reach_px", "radius", "facing_dot_min"]:
		var number_value: Variant = shape.get(field)
		if not _is_finite_number(number_value):
			return false
	var reach_px := float(shape["reach_px"])
	var radius := float(shape["radius"])
	var facing_dot_min := float(shape["facing_dot_min"])
	if reach_px < 0.0 or radius < reach_px:
		return false
	if facing_dot_min < -1.0 or facing_dot_min > 1.0:
		return false
	var origin: Vector2 = shape["origin"]
	var position: Vector2 = shape["position"]
	var center: Vector2 = shape["center"]
	return position.is_equal_approx(origin) and center.is_equal_approx(origin + aim * reach_px)

static func _snapshot_contacts(contacts: Array[Dictionary]) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for contact in contacts:
		var target: Variant = contact.get("target")
		var point: Variant = contact.get("point")
		var normal: Variant = contact.get("normal")
		var region: Variant = contact.get("region")
		var region_mult: Variant = contact.get("region_mult")
		if typeof(target) != TYPE_OBJECT or not is_instance_valid(target) or not target is Node:
			continue
		if not point is Vector2 or not (point as Vector2).is_finite():
			continue
		if not normal is Vector2 or not (normal as Vector2).is_finite():
			continue
		if not region is String or not _is_finite_number(region_mult) or float(region_mult) < 0.0:
			continue
		snapshot.append({
			"target": target,
			"point": point,
			"normal": normal,
			"region": region,
			"region_mult": float(region_mult)
		})
	return snapshot

static func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))
