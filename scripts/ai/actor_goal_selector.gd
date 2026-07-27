extends RefCounted

const LegalWorldViewScript := preload("res://scripts/ai/legal_world_view.gd")

const GOAL_DEPOSIT := "deposit"
const GOAL_FORAGE := "forage"
const GOAL_FORAGE_SEARCH := "forage_search"
const GOAL_RETURN_READY := "return_ready"

const FORAGE_ENTER_HUNGER := 70.0
const CRITTER_ONLY_FORAGE_ENTER_HUNGER := 100.0
const ECONOMY_THREAT_RANGE := 260.0
const FOOD_RESERVATION_TTL_FRAMES := 12

var world_view: RefCounted = LegalWorldViewScript.new()
var forage_commitments: Dictionary = {}
var forage_search_indices: Dictionary = {}
var food_reservations: Dictionary = {}


func choose_goal(actor: Node, allow_autonomous_deposit := true) -> Dictionary:
	_prune_actor_state()
	if not _valid_live_actor(actor):
		reset_actor(actor)
		return {}
	var nearby_threat: Node = world_view.nearest_visible_enemy(actor, ECONOMY_THREAT_RANGE)
	if actor.has_method("is_satiated") and actor.is_satiated():
		reset_actor(actor)
		if nearby_threat != null:
			return {}
		var habitat: Rect2 = world_view.home_habitat_rect(actor)
		if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
			return {}
		return {
			"mode": GOAL_DEPOSIT if allow_autonomous_deposit else GOAL_RETURN_READY,
			"point": habitat.get_center(),
			"habitat": habitat
		}
	if nearby_threat != null:
		_release_actor_food(actor)
		return {}
	if _is_critter_only(actor) and not world_view.is_designated_resource_searcher(actor):
		reset_actor(actor)
		return {}
	var hunger := float(actor.get("hunger") if actor.get("hunger") != null else 100.0)
	if hunger <= _forage_enter_hunger(actor):
		_commit_forage(actor)
	if not _is_forage_committed(actor):
		return {}
	var food: Array[Dictionary] = world_view.known_food(actor)
	if food.is_empty():
		return {}
	var observation := _select_food_observation(actor, food)
	if observation.is_empty():
		return {}
	_reserve_food(actor, observation)
	return {
		"mode": GOAL_FORAGE,
		"point": observation.get("point", actor.global_position),
		"food": observation
	}


func choose_search_goal(actor: Node) -> Dictionary:
	_prune_actor_state()
	if not _valid_live_actor(actor):
		reset_actor(actor)
		return {}
	if world_view.nearest_visible_enemy(actor, ECONOMY_THREAT_RANGE) != null:
		_release_actor_food(actor)
		return {}
	if actor.has_method("is_satiated") and actor.is_satiated():
		reset_actor(actor)
		return {}
	if not _is_forage_committed(actor) or not world_view.known_food(actor).is_empty():
		return {}
	var cues: Array[Dictionary] = world_view.resource_search_cues(actor)
	if cues.is_empty():
		return {}
	var actor_id := actor.get_instance_id()
	var cue_index := int(forage_search_indices.get(actor_id, _initial_search_index(actor, cues.size())))
	cue_index = posmod(cue_index, cues.size())
	var cue: Dictionary = cues[cue_index]
	var point: Vector2 = cue.get("point", Vector2.INF)
	var hold_radius := maxf(float(cue.get("hold_radius", 32.0)), 1.0)
	forage_search_indices[actor_id] = cue_index
	if point == Vector2.INF:
		return {}
	return {
		"mode": GOAL_FORAGE_SEARCH,
		"point": point,
		"cue_id": String(cue.get("cue_id", "")),
		"hold_radius": hold_radius
	}


func advance_search_goal(actor: Node, goal: Dictionary) -> Dictionary:
	if String(goal.get("mode", "")) != GOAL_FORAGE_SEARCH:
		return goal
	var point: Vector2 = goal.get("point", Vector2.INF)
	var hold_radius := maxf(float(goal.get("hold_radius", 32.0)), 1.0)
	if point == Vector2.INF \
		or actor.global_position.distance_squared_to(point) > hold_radius * hold_radius:
		return goal
	var cues: Array[Dictionary] = world_view.resource_search_cues(actor)
	if cues.is_empty():
		return {}
	var actor_id := actor.get_instance_id()
	var cue_index := int(forage_search_indices.get(actor_id, _initial_search_index(actor, cues.size())))
	forage_search_indices[actor_id] = (cue_index + 1) % cues.size()
	return choose_search_goal(actor)


func goal_is_valid(actor: Node, goal: Dictionary) -> bool:
	_prune_actor_state()
	if not _valid_live_actor(actor):
		reset_actor(actor)
		return false
	match String(goal.get("mode", "")):
		GOAL_DEPOSIT, GOAL_RETURN_READY:
			return actor.has_method("is_satiated") and actor.is_satiated()
		GOAL_FORAGE:
			if actor.has_method("is_satiated") and actor.is_satiated():
				reset_actor(actor)
				return false
			if world_view.nearest_visible_enemy(actor, ECONOMY_THREAT_RANGE) != null:
				_release_actor_food(actor)
				return false
			if not _is_forage_committed(actor):
				return false
			var observation: Dictionary = goal.get("food", {})
			if not world_view.food_observation_is_current(actor, observation):
				_release_food(actor, int(observation.get("resource_id", 0)))
				return false
			_reserve_food(actor, observation)
			return true
		GOAL_FORAGE_SEARCH:
			if actor.has_method("is_satiated") and actor.is_satiated():
				reset_actor(actor)
				return false
			if world_view.nearest_visible_enemy(actor, ECONOMY_THREAT_RANGE) != null:
				_release_actor_food(actor)
				return false
			if not _is_forage_committed(actor) or not world_view.known_food(actor).is_empty():
				return false
			var point: Vector2 = goal.get("point", Vector2.INF)
			var cues: Array[Dictionary] = world_view.resource_search_cues(actor)
			if cues.is_empty():
				return false
			var cue_index := int(forage_search_indices.get(
				actor.get_instance_id(),
				_initial_search_index(actor, cues.size())
			))
			var current_cue: Dictionary = cues[posmod(cue_index, cues.size())]
			return point != Vector2.INF \
				and String(goal.get("cue_id", "")) == String(current_cue.get("cue_id", ""))
	return false


func _forage_enter_hunger(actor: Node) -> float:
	if _is_critter_only(actor):
		return CRITTER_ONLY_FORAGE_ENTER_HUNGER
	return FORAGE_ENTER_HUNGER


func _is_critter_only(actor: Node) -> bool:
	return actor.has_method("can_eat_food_kind") \
		and actor.can_eat_food_kind("critter") \
		and not actor.can_eat_food_kind("plant")


func reset_actor(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	forage_commitments.erase(actor.get_instance_id())
	forage_search_indices.erase(actor.get_instance_id())
	_release_actor_food(actor)


func _release_actor_food(actor: Node) -> void:
	var owner_id := _reservation_owner_id(actor)
	for resource_id in food_reservations.keys():
		var reservation: Dictionary = food_reservations.get(resource_id, {})
		if String(reservation.get("owner_id", "")) == owner_id:
			food_reservations.erase(resource_id)


func _commit_forage(actor: Node) -> void:
	forage_commitments[actor.get_instance_id()] = weakref(actor)


func _is_forage_committed(actor: Node) -> bool:
	return forage_commitments.has(actor.get_instance_id())


func _initial_search_index(actor: Node, cue_count: int) -> int:
	if cue_count <= 0:
		return 0
	var owner_id := _reservation_owner_id(actor)
	if not owner_id.begins_with("blue:") and not owner_id.begins_with("red:"):
		return 0
	var separator := owner_id.rfind(":")
	if separator >= 0:
		var suffix := owner_id.substr(separator + 1)
		if suffix.is_valid_int():
			return posmod(suffix.to_int(), cue_count)
	return 0


func _select_food_observation(actor: Node, food: Array[Dictionary]) -> Dictionary:
	var owner_id := _reservation_owner_id(actor)
	var actor_team := int(actor.get("team"))
	for observation: Dictionary in food:
		var resource_id := int(observation.get("resource_id", 0))
		var reservation: Dictionary = food_reservations.get(resource_id, {})
		if String(reservation.get("owner_id", "")) == owner_id:
			return observation
	for observation: Dictionary in food:
		var resource_id := int(observation.get("resource_id", 0))
		var reservation: Dictionary = food_reservations.get(resource_id, {})
		if reservation.is_empty() \
			or int(reservation.get("team", -1)) != actor_team \
			or String(reservation.get("owner_id", "")) == owner_id:
			return observation
	return food.front() if not food.is_empty() else {}


func _reserve_food(actor: Node, observation: Dictionary) -> void:
	var resource_id := int(observation.get("resource_id", 0))
	var resource_value: Variant = observation.get("resource", null)
	if typeof(resource_value) != TYPE_OBJECT \
		or not is_instance_valid(resource_value) \
		or not resource_value is Node \
		or (resource_value as Node).is_queued_for_deletion():
		observation.erase("resource")
		_release_food(actor, resource_id)
		return
	var resource: Node = resource_value as Node
	if resource == null or resource_id == 0:
		return
	var owner_id := _reservation_owner_id(actor)
	for reserved_id in food_reservations.keys():
		var prior: Dictionary = food_reservations.get(reserved_id, {})
		if String(prior.get("owner_id", "")) == owner_id and int(reserved_id) != resource_id:
			food_reservations.erase(reserved_id)
	food_reservations[resource_id] = {
		"owner_id": owner_id,
		"team": int(actor.get("team")),
		"actor": weakref(actor),
		"resource": weakref(resource),
		"expires_frame": _simulation_tick(actor) + FOOD_RESERVATION_TTL_FRAMES
	}


func _release_food(actor: Node, resource_id: int) -> void:
	if resource_id == 0 or not food_reservations.has(resource_id):
		return
	var reservation: Dictionary = food_reservations.get(resource_id, {})
	if String(reservation.get("owner_id", "")) == _reservation_owner_id(actor):
		food_reservations.erase(resource_id)


func _reservation_owner_id(actor: Node) -> String:
	if actor != null and is_instance_valid(actor) and actor.get("arena") != null:
		var registry = actor.arena.get("slot_registry")
		if registry != null and registry.has_method("get_slot_for_actor"):
			var slot: Dictionary = registry.get_slot_for_actor(actor)
			var slot_id := String(slot.get("slot_id", ""))
			if not slot_id.is_empty():
				return slot_id
	return "actor:%d" % actor.get_instance_id()


func _prune_actor_state() -> void:
	for actor_id in forage_commitments.keys():
		var actor_ref: WeakRef = forage_commitments.get(actor_id)
		if actor_ref == null or actor_ref.get_ref() == null:
			forage_commitments.erase(actor_id)
			forage_search_indices.erase(actor_id)
	for resource_id in food_reservations.keys():
		var reservation: Dictionary = food_reservations.get(resource_id, {})
		var actor_ref: WeakRef = reservation.get("actor")
		var resource_ref: WeakRef = reservation.get("resource")
		var reserved_actor: Node = actor_ref.get_ref() if actor_ref != null else null
		if actor_ref == null \
			or reserved_actor == null \
			or resource_ref == null \
			or resource_ref.get_ref() == null \
			or _simulation_tick(reserved_actor) >= int(reservation.get("expires_frame", -1)):
			food_reservations.erase(resource_id)


func _simulation_tick(actor: Node) -> int:
	if actor != null and is_instance_valid(actor) and actor.get("arena") != null:
		var arena: Node = actor.get("arena")
		if arena.has_method("get_simulation_tick"):
			return int(arena.get_simulation_tick())
	return Engine.get_physics_frames()


func _valid_live_actor(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor) or actor.get("arena") == null:
		return false
	if actor.has_method("is_alive") and not actor.is_alive():
		return false
	return true
