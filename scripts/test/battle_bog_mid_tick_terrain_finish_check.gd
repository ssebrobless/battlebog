extends SceneTree

const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")


class MatchEndingArena extends Node:
	var match_over := false
	var death_count := 0

	func record_death(_victim: Node, _source: Node) -> void:
		death_count += 1
		match_over = true

	func unregister_entity(_entity: Node) -> void:
		pass

	func get_terrain_zone(_position: Vector2) -> String:
		return "water"

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := MatchEndingArena.new()
	get_root().add_child(arena)
	var actor := CreatureScript.new()
	get_root().add_child(actor)
	actor.arena = arena
	actor.team = 0
	actor.apply_creature("water_snake")
	actor.global_position = Vector2(120.0, 120.0)
	actor.swim_time_remaining = 0.0
	actor.health = 0.001
	var input_frame := InputFrameScript.new()
	input_frame.move = Vector2.RIGHT
	input_frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	actor.set_input_frame(input_frame)
	var before := actor.global_position

	await physics_frame
	await process_frame

	var passed := (
		arena.match_over
		and arena.death_count == 1
		and not actor.alive
		and actor.global_position == before
	)
	print(
		"mid_tick_terrain_finish passed=%s deaths=%d moved=%.3f"
		% [str(passed), arena.death_count, actor.global_position.distance_to(before)]
	)
	if not passed:
		push_error(
			"fatal wrong-terrain damage should stop movement in the active physics callback; "
			+ "over=%s deaths=%d alive=%s before=%s after=%s"
			% [
				str(arena.match_over),
				arena.death_count,
				str(actor.alive),
				str(before),
				str(actor.global_position)
			]
		)
	quit(0 if passed else 1)
