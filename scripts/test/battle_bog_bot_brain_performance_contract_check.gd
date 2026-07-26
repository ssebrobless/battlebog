extends SceneTree

const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")


class CountingEntity extends Node2D:
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 12.0
	var creature_id := "chorus_frog"
	var arena: Node = null
	var alive_checks := 0
	var scored := true
	var stealthed := false
	var untargetable := false
	var wildlife := false

	func is_alive() -> bool:
		alive_checks += 1
		return health > 0.0

	func is_scored_actor() -> bool:
		return scored

	func is_stealthed() -> bool:
		return stealthed

	func is_untargetable() -> bool:
		return untargetable

	func is_wildlife_encounter() -> bool:
		return wildlife


class MissingTeamEntity extends Node2D:
	var health := 100.0
	var alive_checks := 0

	func is_alive() -> bool:
		alive_checks += 1
		return health > 0.0


class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []
	var hidden_ids := {}
	var visibility_checks := {}
	var enemy_core: Node = null
	var core_damageable := false

	func add_entity(entity: CountingEntity) -> CountingEntity:
		add_child(entity)
		entity.arena = self
		entities.append(entity)
		return entity

	func add_untyped_entity(entity: Node) -> Node:
		add_child(entity)
		entities.append(entity)
		return entity

	func is_entity_visible_to_team(entity: Node, _team: int) -> bool:
		var key := int(entity.get_instance_id())
		visibility_checks[key] = int(visibility_checks.get(key, 0)) + 1
		return not hidden_ids.has(key)

	func get_enemy_core(_team: int) -> Node:
		return enemy_core

	func can_damage_core(_defending_team: int) -> bool:
		return core_damageable


func _initialize() -> void:
	var failures: Array[String] = []
	var candidates_ok := _check_candidate_eligibility_and_order(failures)
	var core_ok := _check_core_gate(failures)
	print(
		"bot_brain_performance_contract candidate_table=%s core_gate=%s"
		% [str(candidates_ok), str(core_ok)]
	)
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_candidate_eligibility_and_order(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)

	var actor := CountingEntity.new()
	actor.team = 0
	actor.global_position = Vector2.ZERO
	arena.add_entity(actor)

	var allies: Array[CountingEntity] = []
	for index in 128:
		var ally := CountingEntity.new()
		ally.team = 0
		ally.global_position = Vector2(float(index), 20.0)
		allies.append(arena.add_entity(ally))

	var specs: Array[Dictionary] = [
		{"label": "visible_enemy", "position": Vector2(100.0, 0.0), "expected": true},
		{"label": "friendly", "position": Vector2(55.0, 0.0), "team": 0},
		{"label": "dead_enemy", "position": Vector2(60.0, 0.0), "health": 0.0},
		{"label": "stealthed_enemy", "position": Vector2(70.0, 0.0), "stealthed": true},
		{"label": "untargetable_enemy", "position": Vector2(75.0, 0.0), "untargetable": true},
		{"label": "wildlife", "position": Vector2(78.0, 0.0), "wildlife": true},
		{"label": "hidden_enemy", "position": Vector2(80.0, 0.0), "hidden": true},
		{"label": "boundary_enemy", "position": Vector2(620.0, 0.0), "expected": true},
		{"label": "outside_enemy", "position": Vector2(620.01, 0.0)},
		{
			"label": "far_hut",
			"position": Vector2(900.0, 0.0),
			"scored": false,
			"hut": true,
			"expected": true
		}
	]
	var entities_by_label := {}
	var expected: Array[Node] = []
	for spec: Dictionary in specs:
		var entity := CountingEntity.new()
		entity.team = int(spec.get("team", 1))
		entity.global_position = spec.get("position", Vector2.ZERO)
		entity.health = float(spec.get("health", 100.0))
		entity.scored = bool(spec.get("scored", true))
		entity.stealthed = bool(spec.get("stealthed", false))
		entity.untargetable = bool(spec.get("untargetable", false))
		entity.wildlife = bool(spec.get("wildlife", false))
		arena.add_entity(entity)
		var label := String(spec.get("label", ""))
		entities_by_label[label] = entity
		if bool(spec.get("hidden", false)):
			arena.hidden_ids[int(entity.get_instance_id())] = true
		if bool(spec.get("hut", false)):
			arena.huts.append(entity)
		if bool(spec.get("expected", false)):
			expected.append(entity)

	var missing_team := MissingTeamEntity.new()
	missing_team.global_position = Vector2(65.0, 0.0)
	arena.add_untyped_entity(missing_team)

	var brain := BotBrainScript.new()
	var candidates: Array[Node] = brain._target_candidates(actor)
	if candidates != expected:
		failures.append(
			"candidate table must preserve entity order, include the exact range boundary and public huts, "
			+ "and exclude dead/stealthed/untargetable/wildlife/hidden/out-of-range/missing-team "
			+ "entities; expected=%s actual=%s"
			% [str(expected), str(candidates)]
		)

	var ally_alive_checks := 0
	var ally_visibility_checks := 0
	for ally: CountingEntity in allies:
		ally_alive_checks += ally.alive_checks
		ally_visibility_checks += int(arena.visibility_checks.get(int(ally.get_instance_id()), 0))
	if actor.alive_checks != 0 or ally_alive_checks != 0 or ally_visibility_checks != 0:
		failures.append(
			"same-team entities must be rejected before live-target and visibility work; "
			+ "actor_alive=%d ally_alive=%d ally_visibility=%d"
			% [actor.alive_checks, ally_alive_checks, ally_visibility_checks]
		)
	var friendly: CountingEntity = entities_by_label["friendly"]
	if friendly.alive_checks != 0 \
		or int(arena.visibility_checks.get(int(friendly.get_instance_id()), 0)) != 0:
		failures.append(
			"table-driven friendly must be rejected before live-target and visibility work; "
			+ "alive=%d visibility=%d"
			% [
				friendly.alive_checks,
				int(arena.visibility_checks.get(int(friendly.get_instance_id()), 0))
			]
		)

	var hidden_enemy: CountingEntity = entities_by_label["hidden_enemy"]
	var hidden_visibility_checks := int(
		arena.visibility_checks.get(int(hidden_enemy.get_instance_id()), 0)
	)
	if hidden_visibility_checks != 1 or hidden_enemy.alive_checks < 1:
		failures.append(
			"enemy candidates must still pass live-target and legal visibility checks; "
			+ "hidden_alive=%d hidden_visibility=%d"
			% [hidden_enemy.alive_checks, hidden_visibility_checks]
		)
	var outside_enemy: CountingEntity = entities_by_label["outside_enemy"]
	if outside_enemy.alive_checks != 0 \
		or int(arena.visibility_checks.get(int(outside_enemy.get_instance_id()), 0)) != 0:
		failures.append(
			"out-of-range non-structures must be rejected before live-target and visibility work; "
			+ "alive=%d visibility=%d"
			% [
				outside_enemy.alive_checks,
				int(arena.visibility_checks.get(int(outside_enemy.get_instance_id()), 0))
			]
		)

	var wildlife: CountingEntity = entities_by_label["wildlife"]
	var wildlife_semantics_ok := not candidates.has(wildlife) \
		and brain._valid_order_target(actor, wildlife)
	if not wildlife_semantics_ok:
		failures.append(
			"routine candidate scans must reject wildlife while explicit damage orders allow it; "
			+ "candidate=%s ordered=%s"
			% [str(candidates.has(wildlife)), str(brain._valid_order_target(actor, wildlife))]
		)
	if missing_team.alive_checks != 0:
		failures.append(
			"missing-team entities must be rejected before live-target work; alive_checks=%d"
			% missing_team.alive_checks
		)

	var ok := candidates == expected \
		and actor.alive_checks == 0 \
		and ally_alive_checks == 0 \
		and ally_visibility_checks == 0 \
		and friendly.alive_checks == 0 \
		and hidden_visibility_checks == 1 \
		and outside_enemy.alive_checks == 0 \
		and missing_team.alive_checks == 0 \
		and wildlife_semantics_ok
	arena.free()
	return ok


func _check_core_gate(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := CountingEntity.new()
	actor.team = 0
	arena.add_entity(actor)

	var core := CountingEntity.new()
	core.team = 1
	core.scored = false
	core.global_position = Vector2(1200.0, 0.0)
	arena.add_child(core)
	core.arena = arena
	arena.enemy_core = core

	var brain := BotBrainScript.new()
	arena.core_damageable = false
	var closed_candidates: Array[Node] = brain._target_candidates(actor)
	arena.core_damageable = true
	var open_candidates: Array[Node] = brain._target_candidates(actor)
	core.health = 0.0
	var dead_candidates: Array[Node] = brain._target_candidates(actor)
	core.health = 100.0
	core.team = 0
	var friendly_candidates: Array[Node] = brain._target_candidates(actor)

	var ok := closed_candidates.is_empty() \
		and open_candidates == [core] \
		and dead_candidates.is_empty() \
		and friendly_candidates.is_empty()
	if not ok:
		failures.append(
			"enemy core must be appended after entity candidates only while live, enemy-owned, "
			+ "and damageable; closed=%s open=%s dead=%s friendly=%s"
			% [
				str(closed_candidates),
				str(open_candidates),
				str(dead_candidates),
				str(friendly_candidates)
			]
		)
	arena.free()
	return ok
