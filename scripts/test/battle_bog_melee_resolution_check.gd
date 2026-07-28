extends SceneTree

const CreatureScript := preload("res://scripts/sim/creature.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")

class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var event_order: Array[String] = []
	var harvest_result := false
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
		event_order.append("harvest")
		return harvest_result

class FakeEntity extends Node2D:
	var team := 0
	var health := 100.0
	var body_radius := 4.0
	var body_capsule_half_len_px := 0.0
	var body_heading := Vector2.RIGHT
	var last_aim_direction := Vector2.RIGHT
	var creature_data: Dictionary = {}
	var arena: Node = null
	var latch_victim: Node = null
	var received_events: Array[Resource] = []
	var damage_hook := Callable()

	func is_alive() -> bool:
		return health > 0.0

	func is_wildlife_encounter() -> bool:
		return false

	func get_aim_direction() -> Vector2:
		return last_aim_direction

	func take_damage_event(event: Resource) -> void:
		received_events.append(event)
		if arena != null and "event_order" in arena:
			arena.event_order.append(name)
		if damage_hook.is_valid():
			damage_hook.call()

class FakeActor extends FakeEntity:
	var latched_attacker: Node = null
	var vfx_events: Array[Dictionary] = []
	var outgoing_modifier_calls := 0
	var core_calls := 0
	var returned_cores: Array[Node] = []

	func make_damage_event(amount: float, delivery: int, plane: int, source_ability: String) -> Resource:
		outgoing_modifier_calls += 1
		var event := DamageEventScript.new()
		event.setup(amount + float(outgoing_modifier_calls), delivery, plane, self, source_ability)
		return event

	func emit_vfx_event(event_type: String, payload: Dictionary = {}) -> void:
		var event := payload.duplicate()
		event["type"] = event_type
		vfx_events.append(event)
		if arena != null and "event_order" in arena:
			arena.event_order.append("swing")

	func damage_enemy_cores_near(_center: Vector2, _radius: float, _damage: float, _source_ability: String) -> Array[Node]:
		core_calls += 1
		outgoing_modifier_calls += 1
		if arena != null and "event_order" in arena:
			arena.event_order.append("core")
		return returned_cores.duplicate()

class FakeCore extends Node2D:
	var team := 0
	var radius := 5.0
	var health := 100.0
	var damage_events: Array[Dictionary] = []

	func take_damage(amount: float, source_team: int, source_actor: Node) -> void:
		health -= amount
		damage_events.append({"amount": amount, "source_team": source_team, "source_actor": source_actor})

class FakeCoreArena extends Node2D:
	var cores := {}
	var records: Array[Dictionary] = []
	var damage_allowed := true

	func can_damage_core(_defending_team: int) -> bool:
		return damage_allowed

	func record_core_damage(source_team: int, amount: float, source_actor: Node = null) -> void:
		records.append({"source_team": source_team, "amount": amount, "source_actor": source_actor})

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	_check_compatibility_order_and_caps(failures)
	_check_outcomes_and_no_arena(failures)
	_check_contact_snapshot_and_revalidation(failures)
	_check_shape_validation(failures)
	_check_capsule_region_metadata(failures)
	_check_creature_core_return_contract(failures)
	print("melee_resolution failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_compatibility_order_and_caps(failures: Array[String]) -> void:
	var arena := _arena()
	arena.harvest_result = true
	var actor := arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	var normal := arena.add_entity(_entity("normal", 1, Vector2(16.0, 0.0))) as FakeEntity
	arena.add_entity(_entity("capped", 1, Vector2(20.0, 0.0)))
	var latcher := arena.add_entity(_entity("latcher", 1, Vector2(-20.0, 0.0)), false) as FakeEntity
	latcher.latch_victim = actor
	actor.latched_attacker = latcher
	var core := FakeCore.new()
	arena.add_child(core)
	actor.returned_cores = [core]

	var hits := MeleeHit.hit(
		actor,
		24.0,
		10.0,
		DamageEventScript.DELIVERY_MELEE,
		DamageEventScript.PLANE_GROUND,
		"compat",
		{"max_hits": 1}
	)
	var ok := hits == [normal, latcher]
	ok = ok and arena.event_order == ["swing", "harvest", "normal", "latcher", "core"]
	ok = ok and normal.received_events.size() == 1 and latcher.received_events.size() == 1
	ok = ok and is_equal_approx(normal.received_events[0].amount, 11.0)
	ok = ok and is_equal_approx(latcher.received_events[0].amount, 12.0)
	ok = ok and actor.outgoing_modifier_calls == 3 and actor.core_calls == 1
	if not ok:
		failures.append("compatibility wrapper order/cap/latcher/core mismatch; hits=%s order=%s modifier_calls=%d core_calls=%d" % [
			str(hits), str(arena.event_order), actor.outgoing_modifier_calls, actor.core_calls
		])
	arena.free()

	var duplicate_arena := _arena()
	var duplicate_actor := duplicate_arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	var duplicate_latcher := duplicate_arena.add_entity(_entity("latcher", 1, Vector2(16.0, 0.0))) as FakeEntity
	duplicate_latcher.latch_victim = duplicate_actor
	duplicate_actor.latched_attacker = duplicate_latcher
	var duplicate_hits := MeleeHit.hit(
		duplicate_actor,
		24.0,
		10.0,
		DamageEventScript.DELIVERY_MELEE,
		DamageEventScript.PLANE_GROUND,
		"duplicate",
		{"max_hits": 1, "allow_harvest": false}
	)
	if duplicate_hits != [duplicate_latcher] or duplicate_latcher.received_events.size() != 1:
		failures.append("latcher already resolved as a normal contact must not duplicate; hits=%s events=%d" % [
			str(duplicate_hits), duplicate_latcher.received_events.size()
		])
	duplicate_arena.free()

func _check_outcomes_and_no_arena(failures: Array[String]) -> void:
	var orphan := _actor("orphan", 0, Vector2.ZERO)
	var orphan_shape := MeleeHit.build_shape(orphan, 20.0, Vector2.RIGHT)
	var orphan_result := MeleeHit.resolve(
		orphan, orphan_shape, [], 5.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "orphan"
	)
	var orphan_hits := MeleeHit.hit(
		orphan, 20.0, 5.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "orphan"
	)
	if String(orphan_result.outcome) != "whiff" or not orphan_hits.is_empty() or not orphan.vfx_events.is_empty():
		failures.append("no-arena attacks must whiff/return empty without swing; result=%s hits=%s vfx=%s" % [
			str(orphan_result), str(orphan_hits), str(orphan.vfx_events)
		])
	orphan.free()

	var arena := _arena()
	arena.harvest_result = true
	var actor := arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	var shape := MeleeHit.build_shape(actor, 20.0, Vector2.RIGHT)
	var harvest_result := MeleeHit.resolve(
		actor, shape, [], 5.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "harvest"
	)
	var core := FakeCore.new()
	arena.add_child(core)
	actor.returned_cores = [core]
	arena.harvest_result = false
	var core_result := MeleeHit.resolve(
		actor, shape, [], 5.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_AIR, "core"
	)
	var ok := String(harvest_result.outcome) == "harvest" and bool(harvest_result.harvest_hit)
	ok = ok and String(core_result.outcome) == "hit"
	ok = ok and (core_result.hits as Array).is_empty() and int(core_result.hit_count) == 0
	ok = ok and (core_result.core_hits as Array) == [core]
	if not ok:
		failures.append("resolution outcome precedence mismatch; harvest=%s core=%s" % [str(harvest_result), str(core_result)])
	arena.free()

func _check_contact_snapshot_and_revalidation(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	var first := arena.add_entity(_entity("first", 1, Vector2(12.0, 0.0))) as FakeEntity
	var second := arena.add_entity(_entity("second", 1, Vector2(18.0, 0.0))) as FakeEntity
	var stale := arena.add_entity(_entity("stale", 1, Vector2(22.0, 0.0))) as FakeEntity
	var freed := arena.add_entity(_entity("freed", 1, Vector2(24.0, 0.0))) as FakeEntity
	var shape := MeleeHit.build_shape(actor, 24.0, Vector2.RIGHT)
	var contacts := MeleeHit.query(actor, shape)
	contacts[1]["region"] = "authored"
	contacts[1]["region_mult"] = 1.25
	first.damage_hook = func() -> void:
		contacts[1]["region"] = "corrupted"
		contacts[1]["region_mult"] = 99.0
		contacts.clear()
	stale.health = 0.0
	freed.free()
	var refreshed_contacts := MeleeHit.query(actor, shape)

	var result := MeleeHit.resolve(
		actor, shape, contacts, 7.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_AIR, "snapshot",
		{"allow_harvest": false}
	)
	var records: Array = result.hit_records
	var ok := (result.hits as Array) == [first, second]
	ok = ok and refreshed_contacts.size() == 2
	ok = ok and refreshed_contacts[0].target == first and refreshed_contacts[1].target == second
	ok = ok and second.received_events.size() == 1
	ok = ok and String(second.received_events[0].region) == "authored"
	ok = ok and is_equal_approx(float(second.received_events[0].region_mult), 1.25)
	ok = ok and records.size() == 2 and String(records[1].region) == "authored"
	ok = ok and int(result.hit_count) == 2
	if not ok:
		failures.append("resolver must own contact metadata/order and revalidate stale targets; result=%s second_event=%s" % [
			str(result), str(second.received_events)
		])
	arena.free()

func _check_shape_validation(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	arena.add_entity(_entity("target", 1, Vector2(12.0, 0.0)))
	if not MeleeHit.build_shape(null, 20.0, Vector2.RIGHT).is_empty() \
		or not MeleeHit.build_shape(actor, -1.0, Vector2.RIGHT).is_empty() \
		or not MeleeHit.build_shape(actor, 20.0, Vector2.ZERO).is_empty() \
		or not MeleeHit.build_shape(actor, 20.0, Vector2.RIGHT, {"facing_dot_min": 2.0}).is_empty():
		failures.append("build_shape must fail closed for invalid actor, reach, heading, or facing policy")
	var valid := MeleeHit.build_shape(actor, 20.0, Vector2.RIGHT)
	var invalid_shapes: Array[Dictionary] = []
	var wrong_kind := valid.duplicate()
	wrong_kind["kind"] = "circle"
	invalid_shapes.append(wrong_kind)
	var negative := valid.duplicate()
	negative["reach_px"] = -1.0
	invalid_shapes.append(negative)
	var non_finite := valid.duplicate()
	non_finite["center"] = Vector2(INF, 0.0)
	invalid_shapes.append(non_finite)
	var malformed := valid.duplicate()
	malformed["aim"] = "right"
	invalid_shapes.append(malformed)

	for shape in invalid_shapes:
		var contacts := MeleeHit.query(actor, shape)
		var result := MeleeHit.resolve(
			actor, shape, [], 5.0,
			DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "invalid"
		)
		if not contacts.is_empty() or String(result.outcome) != "whiff":
			failures.append("invalid shape must fail closed; shape=%s contacts=%s result=%s" % [str(shape), str(contacts), str(result)])
	if arena.harvest_attempts != 0 or actor.core_calls != 0:
		failures.append("invalid shapes caused side effects; harvest=%d cores=%d" % [arena.harvest_attempts, actor.core_calls])
	arena.free()

func _check_capsule_region_metadata(failures: Array[String]) -> void:
	var arena := _arena()
	var actor := arena.add_entity(_actor("actor", 0, Vector2.ZERO)) as FakeActor
	var target := arena.add_entity(_entity("capsule", 1, Vector2(28.0, 0.0))) as FakeEntity
	target.body_capsule_half_len_px = 12.0
	target.creature_data = {
		"hurtbox_regions": [{
			"name": "tail",
			"offset_units": [-1.0, 0.0],
			"radius_units": 0.5,
			"mult": 1.3
		}]
	}
	var shape := MeleeHit.build_shape(actor, 16.0, Vector2.RIGHT)
	var contacts := MeleeHit.query(actor, shape)
	var result := MeleeHit.resolve(
		actor, shape, contacts, 9.0,
		DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_AIR, "capsule",
		{"allow_harvest": false}
	)
	var ok := contacts.size() == 1 and (result.hits as Array) == [target]
	ok = ok and String(contacts[0].region) == "tail"
	ok = ok and is_equal_approx(float(contacts[0].region_mult), 1.3)
	ok = ok and target.received_events.size() == 1
	ok = ok and String(target.received_events[0].region) == "tail"
	ok = ok and is_equal_approx(float(target.received_events[0].region_mult), 1.3)
	if not ok:
		failures.append("capsule/authored region metadata did not survive query and resolve; contacts=%s result=%s events=%s" % [
			str(contacts), str(result), str(target.received_events)
		])
	arena.free()

func _check_creature_core_return_contract(failures: Array[String]) -> void:
	var arena := FakeCoreArena.new()
	get_root().add_child(arena)
	var actor := CreatureScript.new()
	actor.team = 0
	actor.arena = arena
	arena.add_child(actor)
	var own_core := FakeCore.new()
	own_core.team = 0
	own_core.global_position = Vector2.ZERO
	arena.add_child(own_core)
	var enemy_core := FakeCore.new()
	enemy_core.team = 1
	enemy_core.global_position = Vector2(10.0, 0.0)
	arena.add_child(enemy_core)
	var distant_core := FakeCore.new()
	distant_core.team = 2
	distant_core.global_position = Vector2(100.0, 0.0)
	arena.add_child(distant_core)
	arena.cores = {0: own_core, 1: enemy_core, 2: distant_core}

	var damaged := actor.damage_enemy_cores_near(Vector2.ZERO, 12.0, 10.0, "core_contract")
	var ok := damaged == [enemy_core]
	ok = ok and own_core.damage_events.is_empty()
	ok = ok and enemy_core.damage_events.size() == 1 and is_equal_approx(enemy_core.health, 90.0)
	ok = ok and distant_core.damage_events.is_empty()
	ok = ok and arena.records.size() == 1
	if not ok:
		failures.append("Creature core return contract changed side effects; damaged=%s own=%s enemy=%s distant=%s records=%s" % [
			str(damaged), str(own_core.damage_events), str(enemy_core.damage_events), str(distant_core.damage_events), str(arena.records)
		])
	arena.free()

func _arena() -> FakeArena:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	return arena

func _actor(node_name: String, team: int, position: Vector2) -> FakeActor:
	var actor := FakeActor.new()
	actor.name = node_name
	actor.team = team
	actor.global_position = position
	return actor

func _entity(node_name: String, team: int, position: Vector2) -> FakeEntity:
	var entity := FakeEntity.new()
	entity.name = node_name
	entity.team = team
	entity.global_position = position
	return entity
