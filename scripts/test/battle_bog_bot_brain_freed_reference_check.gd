extends SceneTree

const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")


class FakeEntity extends Node2D:
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 12.0
	var creature_id := "chorus_frog"
	var arena: Node = null

	func is_alive() -> bool:
		return health > 0.0

	func is_stealthed() -> bool:
		return false


class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []


func _initialize() -> void:
	var failures: Array[String] = []
	var arena := FakeArena.new()
	get_root().add_child(arena)

	var actor := FakeEntity.new()
	actor.team = 0
	actor.arena = arena
	arena.add_child(actor)
	arena.entities.append(actor)

	var brain := BotBrainScript.new()
	_check_cached_combat_target(brain, arena, actor, failures)
	_check_cached_food_target(brain, arena, actor, failures)
	_check_sticky_target(brain, arena, actor, failures)

	print("bot_brain_freed_reference passed=%s" % str(failures.is_empty()))
	for failure: String in failures:
		push_error(failure)
	arena.free()
	quit(0 if failures.is_empty() else 1)


func _check_cached_combat_target(
	brain: RefCounted,
	arena: FakeArena,
	actor: FakeEntity,
	failures: Array[String]
) -> void:
	var live_target := _add_target(arena)
	var live_intent := {
		"mode": "fight",
		"target": live_target,
		"_allow_autonomous_deposit": true
	}
	if not brain._cached_intent_valid(actor, live_intent, 1, true):
		failures.append("live cached combat target should remain valid")

	var freed_target := _add_target(arena)
	var freed_intent := {
		"mode": "fight",
		"target": freed_target,
		"_allow_autonomous_deposit": true
	}
	freed_target.free()
	if brain._cached_intent_valid(actor, freed_intent, 1, true):
		failures.append("freed cached combat target should invalidate without an error")

	var queued_target := _add_target(arena)
	var queued_intent := {
		"mode": "fight",
		"target": queued_target,
		"_allow_autonomous_deposit": true
	}
	queued_target.queue_free()
	if brain._cached_intent_valid(actor, queued_intent, 1, true):
		failures.append("queued cached combat target should invalidate without an error")


func _check_cached_food_target(
	brain: RefCounted,
	arena: FakeArena,
	actor: FakeEntity,
	failures: Array[String]
) -> void:
	var food := Node2D.new()
	arena.add_child(food)
	var forage_intent := {
		"mode": "forage",
		"food": {
			"resource": food,
			"resource_id": food.get_instance_id(),
			"point": Vector2(40.0, 0.0)
		},
		"_allow_autonomous_deposit": true
	}
	food.free()
	if brain._cached_intent_valid(actor, forage_intent, 1, true):
		failures.append("freed cached food target should invalidate before goal validation")


func _check_sticky_target(
	brain: RefCounted,
	arena: FakeArena,
	actor: FakeEntity,
	failures: Array[String]
) -> void:
	var actor_key := actor.get_instance_id()
	var live_target := _add_target(arena)
	brain.sticky_targets[actor_key] = live_target
	if brain._sticky_target(actor) != live_target:
		failures.append("live sticky target should remain selected")

	var freed_target := _add_target(arena)
	brain.sticky_targets[actor_key] = freed_target
	freed_target.free()
	if brain._sticky_target(actor) != null:
		failures.append("freed sticky target should clear without an error")
	if brain.sticky_targets.has(actor_key):
		failures.append("freed sticky target should be erased from the cache")

	var queued_target := _add_target(arena)
	brain.sticky_targets[actor_key] = queued_target
	queued_target.queue_free()
	if brain._sticky_target(actor) != null:
		failures.append("queued sticky target should clear without an error")
	if brain.sticky_targets.has(actor_key):
		failures.append("queued sticky target should be erased from the cache")


func _add_target(arena: FakeArena) -> FakeEntity:
	var target := FakeEntity.new()
	target.team = 1
	target.arena = arena
	arena.add_child(target)
	return target
