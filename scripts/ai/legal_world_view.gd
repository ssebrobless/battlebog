extends RefCounted

const INFO_VISIBLE := "visible"
const INFO_LAST_KNOWN := "last_known"


func visible_enemies(actor: Node) -> Array[Node]:
	var out: Array[Node] = []
	if not _valid_actor(actor):
		return out
	var arena: Node = actor.arena
	if arena.has_method("get_visible_enemy_targets"):
		for enemy: Node in arena.get_visible_enemy_targets(actor):
			if _valid_enemy(actor, enemy):
				out.append(enemy)
		return out
	if arena.get("entities") == null:
		return out
	for entity: Node in arena.entities:
		if not _valid_enemy(actor, entity):
			continue
		if arena.has_method("is_entity_visible_to_team") \
			and not arena.is_entity_visible_to_team(entity, int(actor.team)):
			continue
		out.append(entity)
	return out


func known_food(actor: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _valid_actor(actor) or actor.arena.get("food_sources") == null:
		return out
	var arena: Node = actor.arena
	for food: Node in arena.food_sources:
		if not _valid_food(food):
			continue
		var kind := String(food.get("kind"))
		if actor.has_method("can_eat_food_kind") and not actor.can_eat_food_kind(kind):
			continue
		var state := {
			"visible": true,
			"state": INFO_VISIBLE,
			"point": food.global_position,
			"stale": false
		}
		if arena.has_method("get_food_minimap_state"):
			state = arena.get_food_minimap_state(food, int(actor.team))
		if not bool(state.get("visible", false)):
			continue
		var info_state := String(state.get("state", ""))
		if info_state != INFO_VISIBLE and info_state != INFO_LAST_KNOWN:
			continue
		var point: Vector2 = state.get("point", Vector2.INF)
		if point == Vector2.INF:
			continue
		out.append({
			"resource": food,
			"resource_id": food.get_instance_id(),
			"kind": kind,
			"point": point,
			"state": info_state,
			"stale": bool(state.get("stale", info_state == INFO_LAST_KNOWN)),
			"distance": actor.global_position.distance_to(point),
			"requires_attack": food.has_method("requires_attack_harvest") and food.requires_attack_harvest()
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var distance_a := float(a.get("distance", INF))
		var distance_b := float(b.get("distance", INF))
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		var point_a: Vector2 = a.get("point", Vector2.INF)
		var point_b: Vector2 = b.get("point", Vector2.INF)
		if not is_equal_approx(point_a.x, point_b.x):
			return point_a.x < point_b.x
		if not is_equal_approx(point_a.y, point_b.y):
			return point_a.y < point_b.y
		return String(a.get("kind", "")) < String(b.get("kind", ""))
	)
	return out


func nearest_visible_enemy(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for enemy: Node in visible_enemies(actor):
		var distance: float = actor.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	return closest


func home_habitat_rect(actor: Node) -> Rect2:
	if not _valid_actor(actor):
		return Rect2()
	if actor.arena.has_method("get_team_habitat_rect"):
		return actor.arena.get_team_habitat_rect(int(actor.team))
	var terrain = actor.arena.get("terrain_map")
	if terrain != null and terrain.has_method("get_team_habitat_rect"):
		return terrain.get_team_habitat_rect(int(actor.team))
	return Rect2()


func home_retreat_point(actor: Node) -> Vector2:
	var habitat: Rect2 = home_habitat_rect(actor)
	if habitat.size.x > 0.0 and habitat.size.y > 0.0:
		return habitat.get_center()
	if _valid_actor(actor) and actor.arena.has_method("get_team_spawn"):
		return actor.arena.get_team_spawn(int(actor.team))
	return actor.global_position if actor != null and is_instance_valid(actor) else Vector2.ZERO


func food_observation_is_current(actor: Node, observation: Dictionary) -> bool:
	if not _valid_actor(actor):
		return false
	var resource: Node = observation.get("resource", null)
	if not _valid_food(resource):
		return false
	var kind := String(resource.get("kind"))
	if actor.has_method("can_eat_food_kind") and not actor.can_eat_food_kind(kind):
		return false
	if not actor.arena.has_method("get_food_minimap_state"):
		return true
	var state: Dictionary = actor.arena.get_food_minimap_state(resource, int(actor.team))
	return bool(state.get("visible", false)) \
		and String(state.get("state", "")) in [INFO_VISIBLE, INFO_LAST_KNOWN]


func team_snapshot(
	arena: Node,
	team: int,
	slot_registry: RefCounted,
	epoch: int,
	player_override: Dictionary = {}
) -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot: Dictionary in slot_registry.get_team_slots(team):
		var actor: Node = slot.get("actor", null)
		var controller: Dictionary = slot.get("controller", {})
		var alive: bool = actor != null and is_instance_valid(actor) and (not actor.has_method("is_alive") or actor.is_alive())
		var health_ratio: float = 0.0
		if alive and actor.get("max_health") != null and float(actor.get("max_health")) > 0.0:
			health_ratio = clampf(float(actor.get("health")) / float(actor.get("max_health")), 0.0, 1.0)
		slots.append({
			"slot_id": String(slot.get("slot_id", "")),
			"slot_index": int(slot.get("slot_index", -1)),
			"driver_kind": String(controller.get("kind", "")),
			"alive": alive,
			"field": alive,
			"position": actor.global_position if alive else Vector2.ZERO,
			"health_ratio": health_ratio,
			"hunger": float(actor.get("hunger")) if alive and actor.get("hunger") != null else 0.0,
			"satiated": bool(actor.is_satiated()) if alive and actor.has_method("is_satiated") else false
		})
	var contacts := _visible_team_contacts(arena, team)
	var huts: Array[Dictionary] = []
	if arena.get("huts") != null:
		for hut: Node in arena.huts:
			if hut == null or not is_instance_valid(hut) or int(hut.get("team")) != team:
				continue
			var lane_id := int(hut.get("lane_index") if hut.get("lane_index") != null else 0)
			var threat_count := 0
			for contact: Dictionary in contacts:
				if (contact.get("point", Vector2.INF) as Vector2).distance_to(hut.global_position) <= 430.0:
					threat_count += 1
			huts.append({
				"hut_id": "hut:%d:%d" % [team, lane_id],
				"lane_id": lane_id,
				"alive": not hut.has_method("is_alive") or hut.is_alive(),
				"position": hut.global_position,
				"health_ratio": _node_health_ratio(hut),
				"visible_threat_count": threat_count
			})
	huts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("hut_id", "")) < String(b.get("hut_id", ""))
	)
	return {
		"schema": "battle_bog_team_snapshot_v1",
		"epoch": epoch,
		"team": team,
		"slots": slots,
		"huts": huts,
		"lanes": _public_lane_states(arena, team),
		"objectives": _public_boss_objectives(arena),
		"contacts": contacts,
		"player_override": player_override.duplicate(true)
	}


func _visible_team_contacts(arena: Node, team: int) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if arena == null or arena.get("entities") == null:
		return contacts
	for entity: Node in arena.entities:
		if entity == null or not is_instance_valid(entity) or entity.get("team") == null:
			continue
		var entity_team := int(entity.get("team"))
		if entity_team < 0 or entity_team == team:
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if arena.has_method("is_entity_visible_to_team") and not arena.is_entity_visible_to_team(entity, team):
			continue
		contacts.append({
			"contact_key": _stable_entity_key(entity),
			"point": entity.global_position,
			"state": INFO_VISIBLE,
			"team": entity_team
		})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("contact_key", "")) < String(b.get("contact_key", ""))
	)
	return contacts


func _public_boss_objectives(arena: Node) -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	if arena == null or not arena.has_method("get_animal_zone_state"):
		return objectives
	for zone: Dictionary in arena.get_animal_zone_state():
		if not bool(zone.get("boss", false)):
			continue
		objectives.append({
			"objective_id": String(zone.get("id", "")),
			"scope": "center" if bool(zone.get("center_boss", false)) else String(zone.get("side", "")),
			"state": String(zone.get("objective_state", "dormant")),
			"active": bool(zone.get("active", false)),
			"family": String(zone.get("boss_family", "")),
			"center": zone.get("center", Vector2.ZERO),
			"radius": zone.get("radius", Vector2(80.0, 60.0)),
			"control_team": int(zone.get("control_team", -1)),
			"claim_team": int(zone.get("claim_team", -1)),
			"claim_ratio": float(zone.get("claim_ratio", 0.0)),
			"contested": bool(zone.get("contested", false))
		})
	objectives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("objective_id", "")) < String(b.get("objective_id", ""))
	)
	return objectives


func _public_lane_states(arena: Node, team: int) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	var enemy_team := 1 - team
	for lane_id in 2:
		var push_point: Vector2 = arena.get_team_spawn(enemy_team) if arena.has_method("get_team_spawn") else Vector2.ZERO
		if arena.get("huts") != null:
			for hut: Node in arena.huts:
				if hut == null or not is_instance_valid(hut):
					continue
				if int(hut.get("team")) != enemy_team:
					continue
				if int(hut.get("lane_index") if hut.get("lane_index") != null else 0) != lane_id:
					continue
				if not hut.has_method("is_alive") or hut.is_alive():
					push_point = hut.global_position
					break
		lanes.append({
			"lane_id": lane_id,
			"push_point": push_point
		})
	return lanes


func _node_health_ratio(node: Node) -> float:
	if node == null or node.get("max_health") == null or float(node.get("max_health")) <= 0.0:
		return 0.0
	return clampf(float(node.get("health")) / float(node.get("max_health")), 0.0, 1.0)


func _stable_entity_key(entity: Node) -> String:
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		return "creature:%d:%s" % [int(entity.get("team")), String(entity.get("creature_id"))]
	if entity.get("kind") != null:
		return "unit:%d:%s" % [int(entity.get("team")), String(entity.get("kind"))]
	return "entity:%d" % int(entity.get("team"))


func _valid_actor(actor: Node) -> bool:
	return actor != null \
		and is_instance_valid(actor) \
		and actor.get("arena") != null \
		and actor.get("team") != null


func _valid_enemy(actor: Node, target: Node) -> bool:
	if target == null or not is_instance_valid(target) or target == actor:
		return false
	if target.get("team") == null:
		return false
	var target_team := int(target.get("team"))
	if target_team < 0 or target_team == int(actor.team):
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	return true


func _valid_food(food: Node) -> bool:
	if food == null or not is_instance_valid(food):
		return false
	if food.has_method("is_alive") and not food.is_alive():
		return false
	return true
