extends SceneTree

const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")

class FakeEntity extends Node2D:
	var team := 0
	var health := 100.0
	var body_radius := 4.0
	var arena: Node = null
	var aim := Vector2.RIGHT
	var wildlife := false
	var stealthed := false
	var damage_events := 0
	var vfx_events := 0
	var core_damage_attempts := 0

	func is_alive() -> bool:
		return health > 0.0

	func is_wildlife_encounter() -> bool:
		return wildlife

	func is_stealthed() -> bool:
		return stealthed

	func get_aim_direction() -> Vector2:
		return aim

	func take_damage_event(_event: Resource) -> void:
		damage_events += 1

	func emit_vfx_event(_event_type: String, _payload: Dictionary = {}) -> void:
		vfx_events += 1

	func damage_enemy_cores_near(_center: Vector2, _reach_px: float, _damage: float, _source_ability: String) -> void:
		core_damage_attempts += 1

class MutatingEntity extends FakeEntity:
	var remove_target: Node = null
	var add_target: Node = null
	var mutated := false

	func is_alive() -> bool:
		if not mutated and arena != null:
			mutated = true
			var entities_value: Variant = arena.get("entities")
			if entities_value is Array:
				var entities := entities_value as Array
				entities.erase(remove_target)
				entities.append(add_target)
		return health > 0.0

class NoDamageEntity extends Node2D:
	var team := 1
	var health := 100.0
	var body_radius := 4.0

	func is_alive() -> bool:
		return true

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var harvest_attempts := 0

	func add_entity(entity: Node, include_in_entities := true) -> Node:
		add_child(entity)
		if "arena" in entity:
			entity.set("arena", self)
		if include_in_entities:
			entities.append(entity)
		return entity

	func try_harvest_food_with_hit_shape(_actor: Node, _shape: Dictionary, _source_ability: String) -> bool:
		harvest_attempts += 1
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	_check_heading_commitment(failures)
	_check_order_and_uncapped_query(failures)
	_check_filtering_and_no_side_effects(failures)
	_check_entity_snapshot(failures)
	print("melee_query failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_heading_commitment(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO)) as FakeEntity
	var committed_target := arena.add_entity(_entity(1, Vector2(0.0, -20.0))) as FakeEntity
	var live_aim_target := arena.add_entity(_entity(1, Vector2(20.0, 0.0))) as FakeEntity
	var shape := MeleeHit.build_shape(actor, 24.0, Vector2.UP)

	actor.aim = Vector2.RIGHT
	actor.global_position = Vector2(100.0, 100.0)
	var contacts := MeleeHit.query(actor, shape)
	var targets := _targets(contacts)
	var ok := targets == [committed_target]
	ok = ok and shape.get("origin", Vector2.INF) == Vector2.ZERO
	ok = ok and (shape.get("aim", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.UP)
	ok = ok and not targets.has(live_aim_target)
	if not ok:
		failures.append("heading commitment expected the captured origin/up heading only; shape=%s targets=%s" % [str(shape), str(targets)])
	arena.free()

func _check_order_and_uncapped_query(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO)) as FakeEntity
	var far_target := arena.add_entity(_entity(1, Vector2(28.0, 0.0))) as FakeEntity
	var near_target := arena.add_entity(_entity(1, Vector2(12.0, 0.0))) as FakeEntity
	var middle_target := arena.add_entity(_entity(1, Vector2(20.0, 0.0))) as FakeEntity
	var contacts := MeleeHit.query(actor, MeleeHit.build_shape(actor, 28.0, Vector2.RIGHT), {"max_hits": 1})
	var targets := _targets(contacts)
	var ok := targets == [far_target, near_target, middle_target]
	ok = ok and contacts.size() == 3
	for contact in contacts:
		ok = ok and contact.has("target")
		ok = ok and contact.get("point") is Vector2
		ok = ok and contact.get("normal") is Vector2
		ok = ok and String(contact.get("region", "")) == "hull"
		ok = ok and is_equal_approx(float(contact.get("region_mult", 0.0)), 1.0)
	if not ok:
		failures.append("ordered query expected arena order and no max_hits cap; targets=%s contacts=%s" % [str(targets), str(contacts)])
	arena.free()

func _check_filtering_and_no_side_effects(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO)) as FakeEntity
	var ally := arena.add_entity(_entity(0, Vector2(12.0, 0.0))) as FakeEntity
	var dead_enemy := arena.add_entity(_entity(1, Vector2(14.0, 0.0))) as FakeEntity
	dead_enemy.health = 0.0
	var behind_enemy := arena.add_entity(_entity(1, Vector2(-12.0, 0.0))) as FakeEntity
	var distant_enemy := arena.add_entity(_entity(1, Vector2(80.0, 0.0))) as FakeEntity
	var stealthed_enemy := arena.add_entity(_entity(1, Vector2(18.0, 0.0))) as FakeEntity
	stealthed_enemy.stealthed = true
	var wildlife := arena.add_entity(_entity(1, Vector2(22.0, 0.0))) as FakeEntity
	wildlife.wildlife = true
	var missing_api := NoDamageEntity.new()
	missing_api.global_position = Vector2(16.0, 0.0)
	arena.add_entity(missing_api)

	var shape := MeleeHit.build_shape(actor, 24.0, Vector2.RIGHT)
	var default_contacts := MeleeHit.query(actor, shape)
	var filtered_contacts := MeleeHit.query(actor, shape, {"allow_wildlife": false})
	var default_targets := _targets(default_contacts)
	var filtered_targets := _targets(filtered_contacts)
	var ok := default_targets == [stealthed_enemy, wildlife]
	ok = ok and filtered_targets == [stealthed_enemy]
	ok = ok and not default_targets.has(actor)
	ok = ok and not default_targets.has(ally)
	ok = ok and not default_targets.has(dead_enemy)
	ok = ok and not default_targets.has(behind_enemy)
	ok = ok and not default_targets.has(distant_enemy)
	ok = ok and not default_targets.has(missing_api)
	ok = ok and actor.vfx_events == 0
	ok = ok and stealthed_enemy.damage_events == 0 and stealthed_enemy.stealthed
	ok = ok and wildlife.damage_events == 0
	ok = ok and arena.harvest_attempts == 0 and actor.core_damage_attempts == 0
	if not ok:
		failures.append("filtering query changed compatibility semantics or caused side effects; default=%s filtered=%s damage=%d/%d vfx=%d harvest=%d cores=%d" % [
			str(default_targets),
			str(filtered_targets),
			stealthed_enemy.damage_events,
			wildlife.damage_events,
			actor.vfx_events,
			arena.harvest_attempts,
			actor.core_damage_attempts
		])
	arena.free()

func _check_entity_snapshot(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_entity(0, Vector2.ZERO)) as FakeEntity
	var mutator := MutatingEntity.new()
	mutator.team = 1
	mutator.global_position = Vector2(12.0, 0.0)
	arena.add_entity(mutator)
	var removed_during_query := arena.add_entity(_entity(1, Vector2(18.0, 0.0))) as FakeEntity
	var added_during_query := _entity(1, Vector2(22.0, 0.0))
	arena.add_entity(added_during_query, false)
	mutator.remove_target = removed_during_query
	mutator.add_target = added_during_query

	var contacts := MeleeHit.query(actor, MeleeHit.build_shape(actor, 24.0, Vector2.RIGHT))
	var targets := _targets(contacts)
	var ok := targets == [mutator, removed_during_query]
	ok = ok and not targets.has(added_during_query)
	ok = ok and arena.entities == [actor, mutator, added_during_query]
	if not ok:
		failures.append("snapshot query expected original targets in original order; targets=%s live_entities=%s" % [str(targets), str(arena.entities)])
	arena.free()

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _entity(team: int, position: Vector2) -> FakeEntity:
	var entity := FakeEntity.new()
	entity.team = team
	entity.global_position = position
	return entity

func _targets(contacts: Array[Dictionary]) -> Array:
	var targets := []
	for contact in contacts:
		targets.append(contact.get("target"))
	return targets
