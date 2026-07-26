extends SceneTree

# Decision #27 acceptance (soft body collision) + minion engagement slots.
# Boots the real Arena so resolve_body_separation runs with true wiring.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MinionScript := preload("res://scripts/game/minion.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "3v3"
		config.set_selected_creature("snapping_turtle")
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("separation check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	_check_pair_separates(arena, failures)
	_check_capsule_pair_separates(arena, failures)
	_check_latch_pair_exempt(arena, failures)
	_check_airborne_exempt(arena, failures)
	_check_dashing_exempt(arena, failures)
	_check_push_is_soft(arena, failures)
	_check_midpoint_invariant(arena, failures)
	_check_repeated_resolution_deterministic(arena, failures)
	_check_node2d_minion_separates(arena, failures)
	_check_knocked_minion_exempt(arena, failures)
	_check_minion_slots(arena, failures)
	print("separation failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _two_creatures(arena: Node) -> Array:
	var a: Node = arena.player_squad[0] if arena.get("player_squad") != null and arena.player_squad.size() > 0 else arena.player
	var b: Node = arena.bots[0]
	return [a, b]

func _check_pair_separates(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "snapping_turtle")
	_normalize_grounded(b, "cane_toad")
	var anchor: Vector2 = Vector2(0.0, 0.0)
	a.global_position = anchor
	b.global_position = anchor + Vector2(2.0, 0.0)
	for i in 60:
		arena.resolve_body_separation()
	var gap: float = a.global_position.distance_to(b.global_position)
	var min_gap: float = a.body_radius + b.body_radius
	if gap < min_gap - 0.5:
		failures.append("overlapped creatures should separate to ring contact within 60 ticks (gap=%.1f need %.1f)" % [gap, min_gap])

func _check_capsule_pair_separates(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "alligator")
	_normalize_grounded(b, "cane_toad")
	a.body_heading = Vector2.RIGHT
	a.global_position = Vector2(360.0, 300.0)
	b.global_position = a.global_position + Vector2(a.body_capsule_half_len_px + a.body_radius + b.body_radius - 5.0, 0.0)
	var starting_push: float = HurtboxScript.separation_push(a, b).length()
	for i in 30:
		arena.resolve_body_separation()
	var remaining_push: float = HurtboxScript.separation_push(a, b).length()
	if not (starting_push > 0.0 and remaining_push < 0.5):
		failures.append("capsule-aware separation should resolve long-body overlap (start=%.2f remaining=%.2f)" % [starting_push, remaining_push])

func _check_latch_pair_exempt(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "snapping_turtle")
	_normalize_grounded(b, "cane_toad")
	a.attach_to_victim(b, 5.0, "TestLatch", 99.0)
	b.receive_latch(a, 5.0, "TestLatch")
	a.global_position = b.global_position + Vector2(3.0, 0.0)
	var before: float = a.global_position.distance_to(b.global_position)
	arena.resolve_body_separation()
	var after: float = a.global_position.distance_to(b.global_position)
	if absf(after - before) > 0.01:
		failures.append("latch pair must be exempt from separation (gap %.2f -> %.2f)" % [before, after])
	a.release_latch("test_done")

func _check_airborne_exempt(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "great_blue_heron")
	_normalize_grounded(b, "cane_toad")
	a.state = CreatureStateScript.State.AIRBORNE
	a.global_position = Vector2(480.0, 300.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	var before: float = a.global_position.distance_to(b.global_position)
	arena.resolve_body_separation()
	var after: float = a.global_position.distance_to(b.global_position)
	if absf(after - before) > 0.01:
		failures.append("airborne creatures should pass over body separation (gap %.2f -> %.2f)" % [before, after])

func _check_dashing_exempt(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "bullfrog")
	_normalize_grounded(b, "cane_toad")
	a.dash_timer = 0.2
	a.dash_velocity = Vector2.RIGHT * 500.0
	a.global_position = Vector2(540.0, 300.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	var before: float = a.global_position.distance_to(b.global_position)
	arena.resolve_body_separation()
	var after: float = a.global_position.distance_to(b.global_position)
	if absf(after - before) > 0.01:
		failures.append("dashing creatures should ghost through body separation (gap %.2f -> %.2f)" % [before, after])
	a.dash_timer = 0.0
	a.dash_velocity = Vector2.ZERO

func _check_push_is_soft(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "snapping_turtle")
	_normalize_grounded(b, "cane_toad")
	a.global_position = Vector2(40.0, 40.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	var a_before: Vector2 = a.global_position
	arena.resolve_body_separation()
	var moved: float = a.global_position.distance_to(a_before)
	if moved > arena.SEPARATION_MAX_PUSH_PX + 0.01:
		failures.append("per-tick separation push should be capped at %.1f px (moved %.2f)" % [arena.SEPARATION_MAX_PUSH_PX, moved])

func _check_midpoint_invariant(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	_normalize_grounded(a, "snapping_turtle")
	_normalize_grounded(b, "cane_toad")
	a.global_position = Vector2(620.0, 300.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	var midpoint_before: Vector2 = (a.global_position + b.global_position) * 0.5
	arena.resolve_body_separation()
	var midpoint_after: Vector2 = (a.global_position + b.global_position) * 0.5
	if midpoint_after.distance_to(midpoint_before) > 0.01:
		failures.append("uncollamped separation should preserve pair midpoint (before=%s after=%s)" % [str(midpoint_before), str(midpoint_after)])

func _check_repeated_resolution_deterministic(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var a: Node = pair[0]
	var b: Node = pair[1]
	var first := _resolve_pair_signature(arena, a, b, 700.0)
	var second := _resolve_pair_signature(arena, a, b, 700.0)
	if first != second:
		failures.append("repeated body separation should be bit-identical for the same setup; first=%s second=%s" % [first, second])

func _resolve_pair_signature(arena: Node, a: Node, b: Node, x: float) -> String:
	_normalize_grounded(a, "snapping_turtle")
	_normalize_grounded(b, "cane_toad")
	a.global_position = Vector2(x, 300.0)
	b.global_position = a.global_position + Vector2(1.0, 0.0)
	for i in 120:
		arena.resolve_body_separation()
	return "%s|%s" % [str(a.global_position.snapped(Vector2(0.001, 0.001))), str(b.global_position.snapped(Vector2(0.001, 0.001)))]

func _check_node2d_minion_separates(arena: Node, failures: Array[String]) -> void:
	var pair := _two_creatures(arena)
	var creature: Node = pair[0]
	_normalize_grounded(creature, "snapping_turtle")
	creature.global_position = Vector2(820.0, 300.0)
	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 1, creature.global_position + Vector2(1.0, 0.0), "melee")
	arena.register_entity(minion)
	var was_node2d: bool = minion is Node2D and not _is_character_body(minion)
	var was_manual_body: bool = arena.has_method("_is_separation_body") and bool(arena.call("_is_separation_body", minion))
	for i in 80:
		arena.resolve_body_separation()
	var gap: float = creature.global_position.distance_to(minion.global_position)
	var min_gap: float = creature.body_radius + minion.body_radius
	if gap < min_gap - 0.5 or not was_node2d or not was_manual_body:
		failures.append("Node2D minions should remain in soft separation after dropping CharacterBody2D; node2d=%s manual=%s gap=%.1f need=%.1f" % [
			str(was_node2d),
			str(was_manual_body),
			gap,
			min_gap
		])
	arena.unregister_entity(minion)
	minion.queue_free()

func _is_character_body(node: Node) -> bool:
	return node is CharacterBody2D

func _check_knocked_minion_exempt(arena: Node, failures: Array[String]) -> void:
	var creature: Node = _two_creatures(arena)[0]
	_normalize_grounded(creature, "snapping_turtle")
	creature.global_position = Vector2(900.0, 300.0)
	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 1, creature.global_position + Vector2.RIGHT, "melee")
	minion.knockback_timer = 0.2
	arena.register_entity(minion)
	var gap_before: float = creature.global_position.distance_to(minion.global_position)
	arena.resolve_body_separation()
	var gap_after: float = creature.global_position.distance_to(minion.global_position)
	if not is_equal_approx(gap_before, gap_after):
		failures.append(
			"minions in forced knockback should be exempt from soft separation "
			+ "(gap %.2f -> %.2f)" % [gap_before, gap_after]
		)
	arena.unregister_entity(minion)
	minion.queue_free()

func _check_minion_slots(arena: Node, failures: Array[String]) -> void:
	var target: Node = arena.bots[0]
	var offsets := {}
	for slot in 5:
		var minion := MinionScript.new()
		arena.add_child(minion)
		minion.setup(arena, 0, Vector2.ZERO, "melee", Vector2.ZERO, arena.huts[0] if arena.huts.size() > 0 else null, slot)
		var offset: Vector2 = minion._engage_offset(target)
		offsets[offset.round()] = true
		minion.queue_free()
	if offsets.size() < 4:
		failures.append("defender slots should produce distinct engagement angles (got %d unique of 5)" % offsets.size())

func _normalize_grounded(actor: Node, creature_id: String) -> void:
	actor.apply_creature(creature_id)
	actor.state = CreatureStateScript.State.NORMAL
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	if actor.get("residual_velocity") != null:
		actor.set("residual_velocity", Vector2.ZERO)
	if actor.get("steering_velocity") != null:
		actor.set("steering_velocity", Vector2.ZERO)
	actor.pass_obstacles_timer = 0.0
	actor.break_stealth()
	actor.release_latch("test_reset")
