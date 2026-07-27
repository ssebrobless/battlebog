extends SceneTree

const LegalWorldViewScript := preload("res://scripts/ai/legal_world_view.gd")
const ActorGoalSelectorScript := preload("res://scripts/ai/actor_goal_selector.gd")
const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")


class FakeFood extends Node2D:
	var kind := "berry"
	var body_radius := 8.0
	var attack_harvest := false
	var alive := true

	func is_alive() -> bool:
		return alive

	func requires_attack_harvest() -> bool:
		return attack_harvest


class FakeActor extends Node2D:
	var team := 0
	var health := 100.0
	var max_health := 100.0
	var body_radius := 12.0
	var creature_id := "chorus_frog"
	var hunger := 100.0
	var satiated := false
	var arena: Node = null
	var allowed_food_kinds: Array[String] = ["berry"]
	var q_timer := 10.0
	var e_timer := 10.0
	var primary_timer := 0.0

	func is_alive() -> bool:
		return health > 0.0

	func is_satiated() -> bool:
		return satiated

	func can_eat_food_kind(food_kind: String) -> bool:
		return food_kind in allowed_food_kinds

	func is_stealthed() -> bool:
		return false

	func is_scored_actor() -> bool:
		return true


class FakeSlotRegistry extends RefCounted:
	var actor_slots := {}
	var team_slots := {0: [], 1: []}

	func register_actor(actor: Node, slot_id: String, controller_kind := "ai") -> void:
		var team := 0 if slot_id.begins_with("blue:") else 1
		var separator := slot_id.rfind(":")
		var slot_index := int(slot_id.substr(separator + 1)) if separator >= 0 else 0
		var slot := {
			"slot_id": slot_id,
			"slot_index": slot_index,
			"actor": actor,
			"controller": {"kind": controller_kind}
		}
		actor_slots[actor.get_instance_id()] = slot
		team_slots[team].append(slot)

	func get_slot_for_actor(actor: Object) -> Dictionary:
		if actor == null or not is_instance_valid(actor):
			return {}
		return actor_slots.get(actor.get_instance_id(), {})

	func get_team_slots(team: int) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for slot: Dictionary in team_slots.get(team, []):
			out.append(slot)
		return out


class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []
	var food_sources: Array[Node] = []
	var food_states := {}
	var visible_entities := {}
	var habitat := Rect2(-50.0, -50.0, 100.0, 100.0)
	var slot_registry: RefCounted = null
	var animal_zones: Array[Dictionary] = [
		{"id": "blue:A", "side": "blue", "group": "A", "center": Vector2(100.0, 0.0), "boss": false},
		{"id": "blue:B", "side": "blue", "group": "B", "center": Vector2(200.0, 0.0), "boss": false},
		{"id": "blue:C", "side": "blue", "group": "C", "center": Vector2(300.0, 0.0), "boss": false},
		{"id": "blue:D", "side": "blue", "group": "D", "center": Vector2(400.0, 0.0), "boss": false},
		{"id": "blue:Boss", "side": "blue", "group": "Boss", "center": Vector2(500.0, 0.0), "boss": true}
	]

	func add_actor(actor: FakeActor) -> FakeActor:
		add_child(actor)
		actor.arena = self
		entities.append(actor)
		return actor

	func add_food(food: FakeFood) -> FakeFood:
		add_child(food)
		food_sources.append(food)
		set_food_state(food, true, "visible", food.global_position)
		return food

	func set_food_state(food: Node, visible: bool, state: String, point: Vector2) -> void:
		food_states[food.get_instance_id()] = {
			"visible": visible,
			"state": state,
			"point": point,
			"stale": state == "last_known"
		}

	func set_entity_visible(entity: Node, visible: bool) -> void:
		visible_entities[entity.get_instance_id()] = visible

	func get_food_minimap_state(food: Node, _team: int) -> Dictionary:
		return food_states.get(food.get_instance_id(), {
			"visible": false,
			"state": "hidden",
			"point": Vector2.INF,
			"stale": false
		})

	func is_entity_visible_to_team(entity: Node, _team: int) -> bool:
		return bool(visible_entities.get(entity.get_instance_id(), false))

	func get_team_habitat_rect(_team: int) -> Rect2:
		return habitat

	func get_team_spawn(_team: int) -> Vector2:
		return habitat.get_center()

	func get_animal_zone_state(side := "") -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for zone: Dictionary in animal_zones:
			if not String(side).is_empty() and String(zone.get("side", "")) != String(side):
				continue
			out.append(zone.duplicate(true))
		return out

	func get_enemy_core(_team: int) -> Node:
		return null

	func can_damage_core(_team: int) -> bool:
		return false

	func get_steering_direction(
		from: Vector2,
		destination: Vector2,
		_body_radius: float,
		_team: int
	) -> Vector2:
		return from.direction_to(destination)


func _initialize() -> void:
	var failures: Array[String] = []
	var hidden_ok := _check_hidden_food_excluded(failures)
	var last_known_ok := _check_last_known_food_uses_marker(failures)
	var diet_ok := _check_diet_filtering(failures)
	var threat_ok := _check_visible_threat_suppresses_economy(failures)
	var forage_ok := _check_low_hunger_selects_forage(failures)
	var diet_threshold_ok := _check_diet_aware_forage_threshold(failures)
	var commitment_ok := _check_multi_food_forage_commitment(failures)
	var threat_suspend_ok := _check_threat_suspends_forage_commitment(failures)
	var search_ok := _check_visibility_safe_forage_search(failures)
	var designation_ok := _check_designated_resource_searcher(failures)
	var satiation_cancel_ok := _check_satiation_cancels_forage_commitment(failures)
	var threatened_satiation_ok := _check_threatened_satiation_clears_search(failures)
	var reset_ok := _check_reset_cancels_forage_commitment(failures)
	var fanout_ok := _check_allied_food_reservation_fanout(failures)
	var harvest_ok := _check_attack_harvest_primary(failures)
	var deposit_ok := _check_satiated_auto_deposit(failures)
	var assisted_ok := _check_assisted_manual_returns_without_deposit(failures)
	var deterministic_ok := _check_deterministic_nearest_and_tie(failures)
	var passed := hidden_ok \
		and last_known_ok \
		and diet_ok \
		and threat_ok \
		and forage_ok \
		and diet_threshold_ok \
		and commitment_ok \
		and threat_suspend_ok \
		and search_ok \
		and designation_ok \
		and satiation_cancel_ok \
		and threatened_satiation_ok \
		and reset_ok \
		and fanout_ok \
		and harvest_ok \
		and deposit_ok \
		and assisted_ok \
		and deterministic_ok
	print(
		"actor_goal_selector hidden=%s last_known=%s diet=%s threat=%s forage=%s diet_threshold=%s commitment=%s threat_suspend=%s search=%s designation=%s satiation_cancel=%s threatened_satiation=%s reset=%s fanout=%s harvest=%s deposit=%s assisted=%s deterministic=%s"
		% [
			str(hidden_ok),
			str(last_known_ok),
			str(diet_ok),
			str(threat_ok),
			str(forage_ok),
			str(diet_threshold_ok),
			str(commitment_ok),
			str(threat_suspend_ok),
			str(search_ok),
			str(designation_ok),
			str(satiation_cancel_ok),
			str(threatened_satiation_ok),
			str(reset_ok),
			str(fanout_ok),
			str(harvest_ok),
			str(deposit_ok),
			str(assisted_ok),
			str(deterministic_ok)
		]
	)
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _check_hidden_food_excluded(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 20.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(24.0, 0.0)
	arena.set_food_state(food, false, "hidden", food.global_position)
	var observations: Array[Dictionary] = LegalWorldViewScript.new().known_food(actor)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var ok: bool = observations.is_empty() and goal.is_empty()
	if not ok:
		failures.append("hidden_food expected no legal observation or economy goal")
	arena.free()
	return ok


func _check_last_known_food_uses_marker(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 20.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(500.0, 80.0)
	var marker := Vector2(42.0, -18.0)
	arena.set_food_state(food, true, "last_known", marker)
	var observations: Array[Dictionary] = LegalWorldViewScript.new().known_food(actor)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var observed_point: Vector2 = observations.front().get("point", Vector2.INF) if not observations.is_empty() else Vector2.INF
	var goal_point: Vector2 = goal.get("point", Vector2.INF)
	var ok: bool = observed_point == marker \
		and goal_point == marker \
		and goal_point != food.global_position \
		and String(goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE
	if not ok:
		failures.append("last_known expected stored marker %s instead of live food position %s; observation=%s goal=%s" % [
			str(marker),
			str(food.global_position),
			str(observed_point),
			str(goal_point)
		])
	arena.free()
	return ok


func _check_diet_filtering(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 20.0
	actor.allowed_food_kinds = ["berry"]
	var meat := arena.add_food(FakeFood.new())
	meat.kind = "critter"
	meat.global_position = Vector2(10.0, 0.0)
	arena.set_food_state(meat, true, "visible", meat.global_position)
	var berry := arena.add_food(FakeFood.new())
	berry.kind = "berry"
	berry.global_position = Vector2(80.0, 0.0)
	arena.set_food_state(berry, true, "visible", berry.global_position)
	var observations: Array[Dictionary] = LegalWorldViewScript.new().known_food(actor)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var selected: Node = goal.get("food", {}).get("resource", null)
	var ok: bool = observations.size() == 1 and selected == berry
	if not ok:
		failures.append("diet_filter expected edible berry and rejection of nearer critter")
	arena.free()
	return ok


func _check_visible_threat_suppresses_economy(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 20.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(40.0, 0.0)
	arena.set_food_state(food, true, "visible", food.global_position)
	var enemy := arena.add_actor(FakeActor.new())
	enemy.team = 1
	enemy.global_position = Vector2(120.0, 0.0)
	arena.set_entity_visible(enemy, true)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var ok: bool = goal.is_empty()
	if not ok:
		failures.append("visible_threat expected nearby visible enemy to suppress economy; goal=%s" % str(goal))
	arena.free()
	return ok


func _check_low_hunger_selects_forage(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 35.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(90.0, 0.0)
	arena.set_food_state(food, true, "visible", food.global_position)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var ok: bool = String(goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and goal.get("food", {}).get("resource", null) == food
	if not ok:
		failures.append("low_hunger expected forage goal for visible edible food; goal=%s" % str(goal))
	arena.free()
	return ok


func _check_diet_aware_forage_threshold(failures: Array[String]) -> bool:
	var carnivore_at_threshold := _threshold_case_goal(
		["critter"],
		"critter",
		ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER
	)
	var carnivore_above_threshold := _threshold_case_goal(
		["critter"],
		"critter",
		ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER + 0.01
	)
	var plant_capable_at_88 := _threshold_case_goal(
		["plant", "critter"],
		"plant",
		ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER
	)
	var plant_capable_at_70 := _threshold_case_goal(
		["plant", "critter"],
		"plant",
		ActorGoalSelectorScript.FORAGE_ENTER_HUNGER
	)
	var incompatible_food := _threshold_case_goal(
		["critter"],
		"plant",
		ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER
	)
	var threatened_carnivore := _threshold_case_goal(
		["critter"],
		"critter",
		ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER,
		true
	)
	var ok := (
		String(carnivore_at_threshold.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE
		and carnivore_above_threshold.is_empty()
		and plant_capable_at_88.is_empty()
		and String(plant_capable_at_70.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE
		and incompatible_food.is_empty()
		and threatened_carnivore.is_empty()
	)
	if not ok:
		failures.append(
			"forage_threshold expected critter-only=100, plant-capable=70, and unchanged diet/threat gates; "
			+ "carnivore=%s above=%s plant88=%s plant70=%s incompatible=%s threatened=%s"
			% [
				str(carnivore_at_threshold),
				str(carnivore_above_threshold),
				str(plant_capable_at_88),
				str(plant_capable_at_70),
				str(incompatible_food),
				str(threatened_carnivore)
			]
		)
	return ok


func _threshold_case_goal(
	allowed_food_kinds: Array[String],
	food_kind: String,
	hunger: float,
	with_threat := false
) -> Dictionary:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.allowed_food_kinds = allowed_food_kinds
	actor.hunger = hunger
	var food := arena.add_food(FakeFood.new())
	food.kind = food_kind
	food.global_position = Vector2(80.0, 0.0)
	if with_threat:
		var enemy := arena.add_actor(FakeActor.new())
		enemy.team = 1
		enemy.global_position = Vector2(100.0, 0.0)
		arena.set_entity_visible(enemy, true)
	var goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	arena.free()
	return goal


func _check_multi_food_forage_commitment(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 70.0
	var first_food := arena.add_food(FakeFood.new())
	first_food.global_position = Vector2(40.0, 0.0)
	arena.set_food_state(first_food, true, "visible", first_food.global_position)
	var second_food := arena.add_food(FakeFood.new())
	second_food.global_position = Vector2(90.0, 0.0)
	arena.set_food_state(second_food, true, "visible", second_food.global_position)
	var selector := ActorGoalSelectorScript.new()
	var first_goal: Dictionary = selector.choose_goal(actor)
	actor.hunger = 88.0
	first_food.alive = false
	arena.set_food_state(first_food, false, "hidden", first_food.global_position)
	var first_invalid: bool = not selector.goal_is_valid(actor, first_goal)
	var continued_goal: Dictionary = selector.choose_goal(actor)
	var ok: bool = first_invalid \
		and String(continued_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and continued_goal.get("food", {}).get("resource", null) == second_food \
		and selector.goal_is_valid(actor, continued_goal)
	if not ok:
		failures.append("forage_commitment expected a new food goal above the entry threshold; first_invalid=%s continued=%s" % [
			str(first_invalid),
			str(continued_goal)
		])
	arena.free()
	return ok


func _check_threat_suspends_forage_commitment(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 60.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(40.0, 0.0)
	var selector := ActorGoalSelectorScript.new()
	var initial_goal: Dictionary = selector.choose_goal(actor)
	var resource_id := int(initial_goal.get("food", {}).get("resource_id", 0))
	actor.hunger = 88.0
	var enemy := arena.add_actor(FakeActor.new())
	enemy.team = 1
	enemy.global_position = Vector2(100.0, 0.0)
	arena.set_entity_visible(enemy, true)
	var cached_goal_invalid := not selector.goal_is_valid(actor, initial_goal)
	var reservation_released := resource_id != 0 and not selector.food_reservations.has(resource_id)
	var threatened_goal: Dictionary = selector.choose_goal(actor)
	arena.set_entity_visible(enemy, false)
	var after_threat_goal: Dictionary = selector.choose_goal(actor)
	var uncommitted_actor := arena.add_actor(FakeActor.new())
	uncommitted_actor.hunger = 88.01
	arena.set_entity_visible(enemy, true)
	var uncommitted_threat_goal: Dictionary = selector.choose_goal(uncommitted_actor)
	arena.set_entity_visible(enemy, false)
	var uncommitted_after_goal: Dictionary = selector.choose_goal(uncommitted_actor)
	var ok: bool = String(initial_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and cached_goal_invalid \
		and reservation_released \
		and threatened_goal.is_empty() \
		and String(after_threat_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and uncommitted_threat_goal.is_empty() \
		and uncommitted_after_goal.is_empty()
	if not ok:
		failures.append("threat_suspend expected danger to release the reservation, preserve only an existing commitment, and resume afterward; initial=%s cached_invalid=%s released=%s threatened=%s after=%s uncommitted_threat=%s uncommitted_after=%s" % [
			str(initial_goal),
			str(cached_goal_invalid),
			str(reservation_released),
			str(threatened_goal),
			str(after_threat_goal),
			str(uncommitted_threat_goal),
			str(uncommitted_after_goal)
		])
	arena.free()
	return ok


func _check_visibility_safe_forage_search(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	arena.slot_registry = FakeSlotRegistry.new()
	arena.animal_zones.reverse()
	var actor := arena.add_actor(FakeActor.new())
	actor.allowed_food_kinds = ["critter"]
	actor.hunger = ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER
	arena.slot_registry.register_actor(actor, "blue:1")
	var hidden_food := arena.add_food(FakeFood.new())
	hidden_food.kind = "critter"
	hidden_food.global_position = Vector2(9876.0, 5432.0)
	arena.set_food_state(hidden_food, false, "hidden", Vector2.INF)
	var selector := ActorGoalSelectorScript.new()
	var direct_goal: Dictionary = selector.choose_goal(actor)
	var first_search: Dictionary = selector.choose_search_goal(actor)
	var first_point: Vector2 = first_search.get("point", Vector2.INF)
	actor.global_position = first_point
	var arrived_valid := selector.goal_is_valid(actor, first_search)
	var second_search: Dictionary = selector.advance_search_goal(actor, first_search)
	var visible_food := arena.add_food(FakeFood.new())
	visible_food.kind = "critter"
	visible_food.global_position = actor.global_position + Vector2(20.0, 0.0)
	var visible_goal: Dictionary = selector.choose_goal(actor)
	var search_with_visible_food: Dictionary = selector.choose_search_goal(actor)
	var uncommitted := arena.add_actor(FakeActor.new())
	uncommitted.allowed_food_kinds = ["critter"]
	uncommitted.hunger = ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER + 0.01
	arena.slot_registry.register_actor(uncommitted, "blue:2")
	var uncommitted_search: Dictionary = selector.choose_search_goal(uncommitted)
	var ok := direct_goal.is_empty() \
		and String(first_search.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE_SEARCH \
		and String(first_search.get("cue_id", "")) == "blue:B" \
		and not first_search.has("resource") \
		and not first_search.has("resource_id") \
		and first_point != hidden_food.global_position \
		and arrived_valid \
		and String(second_search.get("cue_id", "")) == "blue:C" \
		and String(visible_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and search_with_visible_food.is_empty() \
		and uncommitted_search.is_empty()
	if not ok:
		failures.append(
			"forage_search expected stable slot-spread public cues, owned-movement arrival advancement, no hidden resource reference, and visible-food preemption; direct=%s first=%s arrived_valid=%s second=%s visible=%s search_visible=%s uncommitted=%s"
			% [
				str(direct_goal),
				str(first_search),
				str(arrived_valid),
				str(second_search),
				str(visible_goal),
				str(search_with_visible_food),
				str(uncommitted_search)
			]
		)
	arena.free()
	return ok


func _check_designated_resource_searcher(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	arena.slot_registry = FakeSlotRegistry.new()
	var human := arena.add_actor(FakeActor.new())
	human.allowed_food_kinds = ["critter"]
	var first_ai := arena.add_actor(FakeActor.new())
	first_ai.allowed_food_kinds = ["critter"]
	var second_ai := arena.add_actor(FakeActor.new())
	second_ai.allowed_food_kinds = ["critter"]
	arena.slot_registry.register_actor(human, "blue:0", "player")
	arena.slot_registry.register_actor(first_ai, "blue:1", "ai")
	arena.slot_registry.register_actor(second_ai, "blue:2", "ai")
	var food := arena.add_food(FakeFood.new())
	food.kind = "critter"
	food.global_position = Vector2(20.0, 0.0)
	var view := LegalWorldViewScript.new()
	var human_cues := view.resource_search_cues(human)
	var first_ai_cues := view.resource_search_cues(first_ai)
	var second_ai_cues := view.resource_search_cues(second_ai)
	var selector := ActorGoalSelectorScript.new()
	var human_goal := selector.choose_goal(human)
	var first_ai_goal := selector.choose_goal(first_ai)
	var second_ai_goal := selector.choose_goal(second_ai)
	first_ai.satiated = true
	var satiated_handoff_cues := view.resource_search_cues(second_ai)
	var satiated_handoff_goal := selector.choose_goal(second_ai)
	first_ai.satiated = false
	first_ai.health = 0.0
	var death_handoff_cues := view.resource_search_cues(second_ai)
	var ok := human_cues.is_empty() \
		and first_ai_cues.size() == 4 \
		and second_ai_cues.is_empty() \
		and human_goal.is_empty() \
		and String(first_ai_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and second_ai_goal.is_empty() \
		and satiated_handoff_cues.size() == 4 \
		and String(satiated_handoff_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and death_handoff_cues.size() == 4
	if not ok:
		failures.append(
			"resource_search_designation expected one eligible live, unsatiated AI to own search and direct forage with handoff; human_cues=%d first_cues=%d second_cues=%d human_goal=%s first_goal=%s second_goal=%s satiated_cues=%d satiated_goal=%s death_cues=%d"
			% [
				human_cues.size(),
				first_ai_cues.size(),
				second_ai_cues.size(),
				str(human_goal),
				str(first_ai_goal),
				str(second_ai_goal),
				satiated_handoff_cues.size(),
				str(satiated_handoff_goal),
				death_handoff_cues.size()
			]
		)
	arena.free()
	return ok


func _check_satiation_cancels_forage_commitment(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 65.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(40.0, 0.0)
	var selector := ActorGoalSelectorScript.new()
	var initial_goal: Dictionary = selector.choose_goal(actor)
	actor.hunger = 100.0
	actor.satiated = true
	var satiated_goal: Dictionary = selector.choose_goal(actor)
	actor.satiated = false
	var after_satiation_goal: Dictionary = selector.choose_goal(actor)
	var ok: bool = String(initial_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and String(satiated_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_DEPOSIT \
		and after_satiation_goal.is_empty()
	if not ok:
		failures.append("satiation_cancel expected deposit then no stale forage commitment; initial=%s satiated=%s after=%s" % [
			str(initial_goal),
			str(satiated_goal),
			str(after_satiation_goal)
		])
	arena.free()
	return ok


func _check_threatened_satiation_clears_search(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.allowed_food_kinds = ["critter"]
	actor.hunger = ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER
	var selector := ActorGoalSelectorScript.new()
	var initial_goal := selector.choose_goal(actor)
	var search_goal := selector.choose_search_goal(actor)
	var enemy := arena.add_actor(FakeActor.new())
	enemy.team = 1
	enemy.global_position = Vector2(100.0, 0.0)
	arena.set_entity_visible(enemy, true)
	actor.satiated = true
	var threatened_goal := selector.choose_goal(actor)
	var actor_id := actor.get_instance_id()
	var state_cleared := not selector.forage_commitments.has(actor_id) \
		and not selector.forage_search_indices.has(actor_id)
	arena.set_entity_visible(enemy, false)
	actor.satiated = false
	actor.hunger = ActorGoalSelectorScript.CRITTER_ONLY_FORAGE_ENTER_HUNGER + 0.01
	var after_goal := selector.choose_goal(actor)
	var after_search := selector.choose_search_goal(actor)
	var ok := initial_goal.is_empty() \
		and String(search_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE_SEARCH \
		and threatened_goal.is_empty() \
		and state_cleared \
		and after_goal.is_empty() \
		and after_search.is_empty()
	if not ok:
		failures.append(
			"threatened_satiation expected danger to suppress deposit while satiation clears forage/search state; search=%s threatened=%s cleared=%s after=%s after_search=%s"
			% [str(search_goal), str(threatened_goal), str(state_cleared), str(after_goal), str(after_search)]
		)
	arena.free()
	return ok


func _check_reset_cancels_forage_commitment(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 55.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(40.0, 0.0)
	var selector := ActorGoalSelectorScript.new()
	var initial_goal: Dictionary = selector.choose_goal(actor)
	actor.hunger = 90.0
	selector.reset_actor(actor)
	var after_reset_goal: Dictionary = selector.choose_goal(actor)
	var ok: bool = String(initial_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and after_reset_goal.is_empty()
	if not ok:
		failures.append("reset expected explicit actor reset to clear forage commitment; initial=%s after=%s" % [
			str(initial_goal),
			str(after_reset_goal)
		])
	arena.free()
	return ok


func _check_allied_food_reservation_fanout(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var registry := FakeSlotRegistry.new()
	arena.slot_registry = registry
	var first_actor := arena.add_actor(FakeActor.new())
	first_actor.hunger = 50.0
	var second_actor := arena.add_actor(FakeActor.new())
	second_actor.hunger = 50.0
	registry.register_actor(first_actor, "blue:0")
	registry.register_actor(second_actor, "blue:1")
	var nearest_food := arena.add_food(FakeFood.new())
	nearest_food.global_position = Vector2(30.0, 0.0)
	var alternate_food := arena.add_food(FakeFood.new())
	alternate_food.global_position = Vector2(60.0, 0.0)
	var selector := ActorGoalSelectorScript.new()
	var first_goal: Dictionary = selector.choose_goal(first_actor)
	var second_goal: Dictionary = selector.choose_goal(second_actor)
	first_actor.hunger = 85.0
	var retained_goal: Dictionary = selector.choose_goal(first_actor)
	var first_resource: Node = first_goal.get("food", {}).get("resource", null)
	var second_resource: Node = second_goal.get("food", {}).get("resource", null)
	var retained_resource: Node = retained_goal.get("food", {}).get("resource", null)
	var reservations: Dictionary = selector.get("food_reservations")
	var first_reservation: Dictionary = reservations.get(nearest_food.get_instance_id(), {})
	var second_reservation: Dictionary = reservations.get(alternate_food.get_instance_id(), {})
	var ok: bool = first_resource == nearest_food \
		and second_resource == alternate_food \
		and retained_resource == nearest_food \
		and String(first_reservation.get("owner_id", "")) == "blue:0" \
		and String(second_reservation.get("owner_id", "")) == "blue:1"
	if not ok:
		failures.append("food_fanout expected stable allied reservations for separate sources; first=%s second=%s retained=%s reservations=%s" % [
			str(first_resource),
			str(second_resource),
			str(retained_resource),
			str(reservations)
		])
	arena.free()
	return ok


func _check_attack_harvest_primary(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 25.0
	var food := arena.add_food(FakeFood.new())
	food.attack_harvest = true
	food.global_position = Vector2(50.0, 0.0)
	arena.set_food_state(food, true, "visible", food.global_position)
	var frame: Resource = BotBrainScript.new().build_frame(actor)
	var ok: bool = frame.aim == food.global_position \
		and frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	if not ok:
		failures.append("attack_harvest expected primary press in range; aim=%s buttons=%d" % [
			str(frame.aim),
			frame.buttons
		])
	arena.free()
	return ok


func _check_satiated_auto_deposit(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.satiated = true
	actor.global_position = Vector2.ZERO
	var frame: Resource = BotBrainScript.new().build_frame(actor, true)
	var ok: bool = frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)
	if not ok:
		failures.append("auto_deposit expected deposit press for satiated autonomous actor in habitat")
	arena.free()
	return ok


func _check_assisted_manual_returns_without_deposit(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.satiated = true
	actor.global_position = Vector2(140.0, 0.0)
	var home := arena.habitat.get_center()
	var frame: Resource = BotBrainScript.new().build_frame(actor, false)
	var home_direction := actor.global_position.direction_to(home)
	var ok: bool = not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT) \
		and frame.aim == home \
		and frame.move.dot(home_direction) > 0.99
	if not ok:
		failures.append("assisted_manual expected return home without deposit; move=%s aim=%s buttons=%d" % [
			str(frame.move),
			str(frame.aim),
			frame.buttons
		])
	arena.free()
	return ok


func _check_deterministic_nearest_and_tie(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 20.0
	var far_food := arena.add_food(FakeFood.new())
	far_food.global_position = Vector2(120.0, 0.0)
	arena.set_food_state(far_food, true, "visible", far_food.global_position)
	var near_food := arena.add_food(FakeFood.new())
	near_food.global_position = Vector2(35.0, 0.0)
	arena.set_food_state(near_food, true, "visible", near_food.global_position)
	var nearest_goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(actor)
	var nearest_ok: bool = nearest_goal.get("food", {}).get("resource", null) == near_food
	arena.free()

	var tie_arena := FakeArena.new()
	get_root().add_child(tie_arena)
	var tie_actor := tie_arena.add_actor(FakeActor.new())
	tie_actor.hunger = 20.0
	var food_a := tie_arena.add_food(FakeFood.new())
	food_a.global_position = Vector2(40.0, 0.0)
	tie_arena.set_food_state(food_a, true, "visible", food_a.global_position)
	var food_b := tie_arena.add_food(FakeFood.new())
	food_b.global_position = Vector2(-40.0, 0.0)
	tie_arena.set_food_state(food_b, true, "visible", food_b.global_position)
	tie_arena.food_sources.reverse()
	var first_goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(tie_actor)
	tie_arena.food_sources.reverse()
	var second_goal: Dictionary = ActorGoalSelectorScript.new().choose_goal(tie_actor)
	var first_selected: Node = first_goal.get("food", {}).get("resource", null)
	var second_selected: Node = second_goal.get("food", {}).get("resource", null)
	var tie_ok: bool = first_selected != null and first_selected == second_selected
	var ok: bool = nearest_ok and tie_ok
	if not ok:
		failures.append("deterministic_selection expected nearest food and stable tie result across candidate order; nearest=%s first=%s second=%s" % [
			str(nearest_goal.get("food", {}).get("resource", null)),
			str(first_selected),
			str(second_selected)
		])
	tie_arena.free()
	return ok
