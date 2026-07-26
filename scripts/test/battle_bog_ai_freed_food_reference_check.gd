extends SceneTree

const LegalWorldViewScript := preload("res://scripts/ai/legal_world_view.gd")
const ActorGoalSelectorScript := preload("res://scripts/ai/actor_goal_selector.gd")


class FakeFood extends Node2D:
	var kind := "berry"

	func is_alive() -> bool:
		return true

	func requires_attack_harvest() -> bool:
		return false


class FakeActor extends Node2D:
	var team := 0
	var hunger := 20.0
	var arena: Node = null

	func is_alive() -> bool:
		return true

	func is_satiated() -> bool:
		return false

	func can_eat_food_kind(food_kind: String) -> bool:
		return food_kind == "berry"


class FakeHut extends Node2D:
	var team := 0
	var lane_index := 0
	var health := 100.0
	var max_health := 100.0

	func is_alive() -> bool:
		return true


class FakeSlotRegistry extends RefCounted:
	var slots: Array[Dictionary] = []

	func get_team_slots(_team: int) -> Array[Dictionary]:
		return slots


class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var food_sources: Array[Node] = []
	var huts: Array[Node] = []
	var slot_registry: RefCounted = null
	var simulation_tick := 0

	func add_actor(actor: FakeActor) -> FakeActor:
		add_child(actor)
		actor.arena = self
		entities.append(actor)
		return actor

	func add_food(food: FakeFood) -> FakeFood:
		add_child(food)
		food_sources.append(food)
		return food

	func get_food_minimap_state(food: Node, _team: int) -> Dictionary:
		return {
			"visible": true,
			"state": "visible",
			"point": food.global_position,
			"stale": false
		}

	func get_team_habitat_rect(_team: int) -> Rect2:
		return Rect2(-50.0, -50.0, 100.0, 100.0)

	func get_simulation_tick() -> int:
		return simulation_tick


func _initialize() -> void:
	var failures: Array[String] = []
	var view_ok := _check_world_view_invalidates_freed_observation(failures)
	var goal_ok := _check_goal_rejects_freed_food_and_releases_reservation(failures)
	var reserve_ok := _check_reservation_boundary_rejects_freed_food(failures)
	var collections_ok := _check_world_view_skips_freed_collection_entries(failures)
	var snapshot_ok := _check_snapshot_skips_freed_collection_entries(failures)
	var passed := view_ok and goal_ok and reserve_ok and collections_ok and snapshot_ok
	print("ai_freed_food_reference view=%s goal=%s reserve=%s collections=%s snapshot=%s" % [
		str(view_ok),
		str(goal_ok),
		str(reserve_ok),
		str(collections_ok),
		str(snapshot_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _check_world_view_invalidates_freed_observation(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	var freed_food := arena.add_food(FakeFood.new())
	var freed_observation := {
		"resource": freed_food,
		"resource_id": freed_food.get_instance_id(),
		"kind": freed_food.kind,
		"point": Vector2.ZERO
	}
	freed_food.free()
	var view := LegalWorldViewScript.new()
	var freed_current: bool = view.food_observation_is_current(actor, freed_observation)
	var queued_food := arena.add_food(FakeFood.new())
	var queued_observation := {
		"resource": queued_food,
		"resource_id": queued_food.get_instance_id(),
		"kind": queued_food.kind,
		"point": Vector2.ZERO
	}
	queued_food.queue_free()
	var queued_current: bool = view.food_observation_is_current(actor, queued_observation)
	var ok := not freed_current \
		and not freed_observation.has("resource") \
		and not queued_current \
		and not queued_observation.has("resource")
	if not ok:
		failures.append("world_view expected queued and freed food observations to be rejected and cleared")
	arena.free()
	return ok


func _check_snapshot_skips_freed_collection_entries(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var stale_actor := arena.add_actor(FakeActor.new())
	var stale_hut := FakeHut.new()
	arena.add_child(stale_hut)
	arena.huts.append(stale_hut)
	var slots := FakeSlotRegistry.new()
	slots.slots.append({
		"slot_id": "blue:0",
		"slot_index": 0,
		"actor": stale_actor,
		"controller": {"kind": "bot"}
	})
	stale_actor.free()
	stale_hut.free()
	var snapshot: Dictionary = LegalWorldViewScript.new().team_snapshot(arena, 0, slots, 1)
	var slot: Dictionary = snapshot.get("slots", [{}]).front()
	var ok: bool = snapshot.get("huts", []).is_empty() \
		and not bool(slot.get("alive", true)) \
		and not bool(slot.get("field", true))
	if not ok:
		failures.append("team_snapshot expected freed slot actors and huts to be represented safely")
	arena.free()
	return ok


func _check_world_view_skips_freed_collection_entries(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	var food := arena.add_food(FakeFood.new())
	var enemy := arena.add_actor(FakeActor.new())
	enemy.team = 1
	food.free()
	enemy.free()
	var view := LegalWorldViewScript.new()
	var food_known := view.known_food(actor)
	var enemies_visible := view.visible_enemies(actor)
	var ok := food_known.is_empty() and enemies_visible.is_empty()
	if not ok:
		failures.append("world_view expected freed collection entries to be ignored")
	arena.free()
	return ok


func _check_goal_rejects_freed_food_and_releases_reservation(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(24.0, 0.0)
	var resource_id := food.get_instance_id()
	var selector := ActorGoalSelectorScript.new()
	var goal: Dictionary = selector.choose_goal(actor)
	var reserved_before := selector.food_reservations.has(resource_id)
	food.free()
	var valid: bool = selector.goal_is_valid(actor, goal)
	var observation: Dictionary = goal.get("food", {})
	var ok := reserved_before \
		and not valid \
		and not observation.has("resource") \
		and not selector.food_reservations.has(resource_id)
	if not ok:
		failures.append("goal_validation expected freed food to invalidate goal and release reservation")
	arena.free()
	return ok


func _check_reservation_boundary_rejects_freed_food(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	var food := arena.add_food(FakeFood.new())
	var resource_id := food.get_instance_id()
	var observation := {
		"resource": food,
		"resource_id": resource_id
	}
	food.free()
	var selector := ActorGoalSelectorScript.new()
	selector.call("_reserve_food", actor, observation)
	var ok := not observation.has("resource") \
		and not selector.food_reservations.has(resource_id)
	if not ok:
		failures.append("reservation expected freed food reference to be cleared without reservation")
	arena.free()
	return ok
