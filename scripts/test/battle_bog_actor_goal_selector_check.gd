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

	func register_actor(actor: Node, slot_id: String) -> void:
		actor_slots[actor.get_instance_id()] = slot_id

	func get_slot_for_actor(actor: Object) -> Dictionary:
		if actor == null or not is_instance_valid(actor):
			return {}
		var slot_id := String(actor_slots.get(actor.get_instance_id(), ""))
		return {"slot_id": slot_id} if not slot_id.is_empty() else {}


class FakeArena extends Node2D:
	var entities: Array[Node] = []
	var huts: Array[Node] = []
	var food_sources: Array[Node] = []
	var food_states := {}
	var visible_entities := {}
	var habitat := Rect2(-50.0, -50.0, 100.0, 100.0)
	var slot_registry: RefCounted = null

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
	var commitment_ok := _check_multi_food_forage_commitment(failures)
	var threat_cancel_ok := _check_threat_cancels_forage_commitment(failures)
	var satiation_cancel_ok := _check_satiation_cancels_forage_commitment(failures)
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
		and commitment_ok \
		and threat_cancel_ok \
		and satiation_cancel_ok \
		and reset_ok \
		and fanout_ok \
		and harvest_ok \
		and deposit_ok \
		and assisted_ok \
		and deterministic_ok
	print(
		"actor_goal_selector hidden=%s last_known=%s diet=%s threat=%s forage=%s commitment=%s threat_cancel=%s satiation_cancel=%s reset=%s fanout=%s harvest=%s deposit=%s assisted=%s deterministic=%s"
		% [
			str(hidden_ok),
			str(last_known_ok),
			str(diet_ok),
			str(threat_ok),
			str(forage_ok),
			str(commitment_ok),
			str(threat_cancel_ok),
			str(satiation_cancel_ok),
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


func _check_threat_cancels_forage_commitment(failures: Array[String]) -> bool:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := arena.add_actor(FakeActor.new())
	actor.hunger = 60.0
	var food := arena.add_food(FakeFood.new())
	food.global_position = Vector2(40.0, 0.0)
	var selector := ActorGoalSelectorScript.new()
	var initial_goal: Dictionary = selector.choose_goal(actor)
	actor.hunger = 88.0
	var enemy := arena.add_actor(FakeActor.new())
	enemy.team = 1
	enemy.global_position = Vector2(100.0, 0.0)
	arena.set_entity_visible(enemy, true)
	var threatened_goal: Dictionary = selector.choose_goal(actor)
	arena.set_entity_visible(enemy, false)
	var after_threat_goal: Dictionary = selector.choose_goal(actor)
	var ok: bool = String(initial_goal.get("mode", "")) == ActorGoalSelectorScript.GOAL_FORAGE \
		and threatened_goal.is_empty() \
		and after_threat_goal.is_empty()
	if not ok:
		failures.append("threat_cancel expected danger to clear commitment above entry hunger; initial=%s threatened=%s after=%s" % [
			str(initial_goal),
			str(threatened_goal),
			str(after_threat_goal)
		])
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
