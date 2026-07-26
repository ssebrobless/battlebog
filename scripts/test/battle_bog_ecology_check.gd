extends SceneTree

# Pass 4 ecology acceptance: deterministic day refresh, diet-gated wild food,
# hunger/deposit loop, and visible habitat reserve/cue data.

const ARENA_SCENE := "res://scenes/Arena.tscn"
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["chorus_frog", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("ecology check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or not arena.has_method("get_day_state"):
		push_error("Arena scene did not load ecology methods; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_day_and_spawns(arena, failures)
	_check_solo_pvai_hunger_parity(arena, failures)
	_check_diet_gates(arena, failures)
	_check_attack_harvest(arena, failures)
	_check_deposit_cue(arena, failures)
	_check_starvation(arena, failures)

	print("ecology failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_day_and_spawns(arena: Node, failures: Array[String]) -> void:
	var expected_count: int = arena.terrain_map.get_food_spawn_points().size()
	var day: Dictionary = arena.get_day_state()
	if int(day.get("day", 0)) != 1 or float(day.get("length", 0.0)) != 120.0:
		failures.append("day state expected day 1 / 120s, got %s" % str(day))
	if arena.food_sources.size() != expected_count:
		failures.append("food spawn count expected %d got %d" % [expected_count, arena.food_sources.size()])

	var before_day: int = int(arena.day_index)
	if not arena.food_sources.is_empty():
		var food = arena.food_sources.pop_back()
		if food != null and is_instance_valid(food):
			food.queue_free()
	arena._tick_day_cycle(120.0)
	if arena.day_index != before_day + 1 or arena.food_sources.size() != expected_count:
		failures.append("dawn refresh expected day %d and %d food sources, got day %d count %d" % [
			before_day + 1,
			expected_count,
			arena.day_index,
			arena.food_sources.size()
		])

func _check_solo_pvai_hunger_parity(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.hunger = 100.0
	actor.hunger_satiated = false
	actor._tick_hunger(1.0)
	var expected := 100.0 - 100.0 / 105.0
	var pace_ok := arena.has_method("get_hunger_full_to_empty_sec") \
		and absf(float(arena.get_hunger_full_to_empty_sec()) - 105.0) < 0.001 \
		and absf(float(actor.hunger) - expected) < 0.01
	if not pace_ok:
		failures.append("solo PvAI should match canonical competitive hunger pace; pace=%.2f hunger=%.2f expected=%.2f" % [
			float(arena.get_hunger_full_to_empty_sec()) if arena.has_method("get_hunger_full_to_empty_sec") else -1.0,
			float(actor.hunger),
			expected
		])

func _check_diet_gates(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.hunger = 60.0
	actor.hunger_satiated = false
	var plant := _first_food(arena, "plant")
	if plant == null:
		failures.append("expected at least one plant food source")
		return
	actor.global_position = plant.global_position
	if arena.try_eat_nearby_food(actor):
		failures.append("carnivore chorus frog should not eat plants")

	var critter := _first_food(arena, "critter")
	if critter == null:
		failures.append("expected at least one critter food source")
		return
	actor.global_position = critter.global_position
	var ate: bool = arena.try_eat_nearby_food(actor)
	if not ate or actor.hunger <= 60.0:
		failures.append("carnivore should eat critter and gain hunger; ate=%s hunger=%.2f" % [str(ate), actor.hunger])

func _check_deposit_cue(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var reserve_visuals: Array = arena.get_habitat_stock_visuals(0)
	if reserve_visuals.size() < 6:
		failures.append("expected visible reserve stock data for blue trio, got %d" % reserve_visuals.size())

	actor.global_position = arena.terrain_map.get_team_habitat_rect(actor.team).get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true
	var before_cues: int = arena.stock_manager.get_breeding_cues(actor.team).size()
	var deposited: bool = arena._try_manual_habitat_deposit(actor)
	var after_cues: int = arena.stock_manager.get_breeding_cues(actor.team).size()
	if not deposited or after_cues != before_cues + 1 or actor.hunger_satiated:
		failures.append("satiated habitat deposit expected cue+reset, deposited=%s cues %d->%d satiated=%s" % [
			str(deposited),
			before_cues,
			after_cues,
			str(actor.hunger_satiated)
		])

func _check_starvation(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.hunger = 0.01
	actor.hunger_satiated = false
	actor._tick_hunger(1.0)
	if actor.is_alive():
		failures.append("starvation should eliminate a creature at 0 hunger")

func _check_attack_harvest(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("duck")
	actor.hunger = 40.0
	actor.hunger_satiated = false
	var tree := _first_food(arena, "plant", "tree")
	if tree == null:
		failures.append("expected at least one tree harvest resource")
		return
	var start_count: int = arena.food_sources.size()
	_aim_actor_at_food(actor, tree, 1.5)
	var contact_ate: bool = arena.try_eat_nearby_food(actor)
	if contact_ate or actor.hunger > 40.01:
		failures.append("plant resources should not be eaten by contact; contact=%s hunger=%.2f" % [str(contact_ate), actor.hunger])
	for _i in 2:
		MeleeHit.hit(actor, 3.0 * SimConstants.UNIT_PX, 0.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Harvest Test")
	var tree_partial: bool = arena.food_sources.has(tree) and int(tree.get("harvest_hits_remaining")) == 1 and actor.hunger <= 40.01
	MeleeHit.hit(actor, 3.0 * SimConstants.UNIT_PX, 0.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Harvest Test")
	var tree_done: bool = not arena.food_sources.has(tree) and arena.food_sources.size() == start_count - 1 and actor.hunger > 40.0
	if not tree_partial or not tree_done:
		failures.append("tree harvest should require 3 attack hits before giving hunger; partial=%s done=%s remaining=%s hunger=%.2f count=%d->%d" % [
			str(tree_partial),
			str(tree_done),
			str(tree.get("harvest_hits_remaining") if tree != null and is_instance_valid(tree) else "freed"),
			actor.hunger,
			start_count,
			arena.food_sources.size()
		])

	var flower := _first_food(arena, "plant", "flower")
	if flower == null:
		failures.append("expected at least one flower harvest resource")
		return
	actor.hunger = 40.0
	actor.hunger_satiated = false
	var line_count: int = arena.food_sources.size()
	_aim_actor_at_food(actor, flower, 3.0)
	Projectile.instant_line(actor, 4.0 * SimConstants.UNIT_PX, 0.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Harvest Line")
	var line_harvested: bool = not arena.food_sources.has(flower) and arena.food_sources.size() == line_count - 1 and actor.hunger > 40.0
	if not line_harvested:
		failures.append("line primary harvest should resolve one-hit plants; harvested=%s hunger=%.2f count=%d->%d" % [
			str(line_harvested),
			actor.hunger,
			line_count,
			arena.food_sources.size()
		])

	var seed := _first_food(arena, "plant", "seed")
	if seed == null:
		failures.append("expected at least one seed harvest resource")
		return
	actor.apply_creature("chorus_frog")
	actor.hunger = 40.0
	var seed_remaining := int(seed.get("harvest_hits_remaining"))
	_aim_actor_at_food(actor, seed, 1.5)
	MeleeHit.hit(actor, 3.0 * SimConstants.UNIT_PX, 0.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Carnivore Harvest Probe")
	var carnivore_blocked: bool = arena.food_sources.has(seed) and int(seed.get("harvest_hits_remaining")) == seed_remaining and actor.hunger <= 40.01
	if not carnivore_blocked:
		failures.append("carnivores should not harvest plant resources they cannot eat; blocked=%s remaining %d->%s hunger=%.2f" % [
			str(carnivore_blocked),
			seed_remaining,
			str(seed.get("harvest_hits_remaining") if seed != null and is_instance_valid(seed) else "freed"),
			actor.hunger
		])

func _aim_actor_at_food(actor: Node, food: Node, distance_units: float) -> void:
	actor.global_position = food.global_position - Vector2.RIGHT * distance_units * SimConstants.UNIT_PX
	actor.velocity = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT
	var frame := InputFrameScript.new()
	frame.aim = food.global_position
	actor.set_input_frame(frame)

func _first_food(arena: Node, kind: String, plant_type: String = "") -> Node:
	for food in arena.food_sources:
		if food != null and is_instance_valid(food) and String(food.kind) == kind:
			if kind == "plant" and not plant_type.is_empty() and String(food.get("plant_type")) != plant_type:
				continue
			return food
	return null
