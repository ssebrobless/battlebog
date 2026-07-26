extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TurtleHook := preload("res://scripts/ai/bot_kit_hooks/snapping_turtle_bot.gd")
const WaterSnakeHook := preload("res://scripts/ai/bot_kit_hooks/water_snake_bot.gd")
const AlligatorHook := preload("res://scripts/ai/bot_kit_hooks/alligator_bot.gd")
const WolfSpiderHook := preload("res://scripts/ai/bot_kit_hooks/wolf_spider_bot.gd")
const FireflyHook := preload("res://scripts/ai/bot_kit_hooks/firefly_bot.gd")
const MosquitoSwarmHook := preload("res://scripts/ai/bot_kit_hooks/mosquito_swarm_bot.gd")
const FrogHook := preload("res://scripts/ai/bot_kit_hooks/chorus_frog_bot.gd")
const NewtHook := preload("res://scripts/ai/bot_kit_hooks/newt_bot.gd")
const MinkHook := preload("res://scripts/ai/bot_kit_hooks/mink_bot.gd")
const BullfrogHook := preload("res://scripts/ai/bot_kit_hooks/bullfrog_bot.gd")
const CaneToadHook := preload("res://scripts/ai/bot_kit_hooks/cane_toad_bot.gd")
const CrayfishHook := preload("res://scripts/ai/bot_kit_hooks/crayfish_bot.gd")
const BogTurtleHook := preload("res://scripts/ai/bot_kit_hooks/bog_turtle_bot.gd")
const WaterShrewHook := preload("res://scripts/ai/bot_kit_hooks/water_shrew_bot.gd")
const BeaverHook := preload("res://scripts/ai/bot_kit_hooks/beaver_bot.gd")
const OtterHook := preload("res://scripts/ai/bot_kit_hooks/otter_bot.gd")
const LeechHook := preload("res://scripts/ai/bot_kit_hooks/leech_bot.gd")
const OwlHook := preload("res://scripts/ai/bot_kit_hooks/owl_bot.gd")
const HeronHook := preload("res://scripts/ai/bot_kit_hooks/great_blue_heron_bot.gd")
const KingfisherHook := preload("res://scripts/ai/bot_kit_hooks/kingfisher_bot.gd")
const DuckHook := preload("res://scripts/ai/bot_kit_hooks/duck_bot.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const ActorGoalSelectorScript := preload("res://scripts/ai/actor_goal_selector.gd")
const TeamDirectorScript := preload("res://scripts/ai/team_director.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")

const FIGHT_SCAN_RANGE := 620.0
const RETREAT_HEALTH_RATIO := 0.28
const RETREAT_EXIT_HEALTH_RATIO := 0.42
const RETREAT_THREAT_RANGE := 360.0
const DEFEND_HUT_RADIUS := 430.0
const DEFEND_ACTOR_RANGE := 980.0
const TARGET_STICKINESS_BONUS := 60.0
const TARGET_QUERY_REFRESH_FRAMES := 8
const FIGHT_SCAN_RANGE_SQUARED := FIGHT_SCAN_RANGE * FIGHT_SCAN_RANGE
const LIVE_DAMAGE_QUERY := {"require_damage_api": false}
const ORDER_DAMAGE_QUERY := {
	"require_damage_api": false,
	"allow_wildlife": true
}
const VALID_TARGET_QUERY := {
	"ignore_team": true,
	"require_damage_api": false,
	"allow_self": true,
	"allow_stealthed": true
}

var hooks := {}
var sticky_targets := {}
var retreating_actors := {}
var intent_cache := {}
var intent_cache_frames := {}
var actor_slot_ids := {}
var goal_selector: RefCounted = ActorGoalSelectorScript.new()

func build_frame(actor: Node, allow_autonomous_deposit := true, order: Dictionary = {}) -> Resource:
	var frame := InputFrameScript.new()
	if actor == null or actor.arena == null:
		frame.move = Vector2.ZERO
		return frame

	var perf_intent_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	var intent: Dictionary = _cached_intent(actor, allow_autonomous_deposit)
	if PerfStats.enabled:
		PerfStats.add("bot_intent", int(Time.get_ticks_usec() - perf_intent_start))
	var intent_mode := String(intent.get("mode", ""))
	var order_source := String(order.get("source", ""))
	var valid_order := _order_is_valid(actor, order)
	if intent_mode != "retreat" and valid_order and order_source == "player":
		var player_order_frame := _order_frame(actor, order)
		if player_order_frame != null:
			return player_order_frame
	var actor_priority_goal := _is_return_goal(intent) \
		or intent_mode == ActorGoalSelectorScript.GOAL_FORAGE
	if intent_mode != "retreat" and not actor_priority_goal and valid_order:
		var director_order_frame := _order_frame(actor, order)
		if director_order_frame != null:
			return director_order_frame
	var target: Node = intent.get("target", null)
	var point: Vector2 = intent.get("point", actor.global_position + Vector2.RIGHT)
	var mode := String(intent.get("mode", "idle"))
	if mode == ActorGoalSelectorScript.GOAL_DEPOSIT or mode == ActorGoalSelectorScript.GOAL_RETURN_READY:
		return _deposit_frame(actor, intent)
	if mode == ActorGoalSelectorScript.GOAL_FORAGE:
		return _forage_frame(actor, intent)
	var target_position: Vector2 = target.global_position if _valid_target(target) else point
	if mode == "retreat":
		target_position = point
	if target_position == actor.global_position:
		target_position += Vector2.RIGHT

	var offset: Vector2 = target_position - actor.global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized() if distance > 0.001 else Vector2.RIGHT
	frame.aim = _aim_point(actor, target, target_position, mode)

	if mode == "retreat":
		frame.move = _steered_move(actor, target_position, direction)
		return frame

	var hold_range: float = _preferred_range(actor) + _target_radius(target)
	frame.move = _steered_move(actor, target_position, direction) if distance > hold_range else _strafe_direction(direction, actor.team)
	if _valid_target(target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= _primary_range(actor, target))
		_hook(actor).apply(actor, target, frame, distance)
	return frame


func get_goal_snapshot(actor: Node, allow_autonomous_deposit := true) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {}
	var intent := _cached_intent(actor, allow_autonomous_deposit)
	var target: Node = intent.get("target", null)
	var observation: Dictionary = intent.get("food", {})
	return {
		"goal": String(intent.get("mode", "idle")),
		"target_id": target.get_instance_id() if target != null and is_instance_valid(target) else 0,
		"destination": intent.get("point", actor.global_position),
		"information_state": String(observation.get("state", "visible" if target != null else "none"))
	}


func reset_actor(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var key := int(actor.get_instance_id())
	sticky_targets.erase(key)
	retreating_actors.erase(key)
	intent_cache.erase(key)
	intent_cache_frames.erase(key)
	actor_slot_ids.erase(key)
	if goal_selector.has_method("reset_actor"):
		goal_selector.reset_actor(actor)

func _cached_intent(actor: Node, allow_autonomous_deposit := true) -> Dictionary:
	var key := int(actor.get_instance_id())
	var frame_index := _simulation_tick(actor)
	var cached: Dictionary = intent_cache.get(key, {})
	var cached_frame := int(intent_cache_frames.get(key, -TARGET_QUERY_REFRESH_FRAMES * 2))
	if _cached_intent_valid(actor, cached, frame_index - cached_frame, allow_autonomous_deposit):
		return cached
	var intent := _choose_intent(actor, allow_autonomous_deposit)
	intent["_allow_autonomous_deposit"] = allow_autonomous_deposit
	intent_cache[key] = intent
	intent_cache_frames[key] = frame_index
	return intent

func _simulation_tick(actor: Node) -> int:
	if actor != null and is_instance_valid(actor) and actor.get("arena") != null:
		var arena: Node = actor.get("arena")
		if arena.has_method("get_simulation_tick"):
			return int(arena.get_simulation_tick())
	return Engine.get_physics_frames()

func _cached_intent_valid(actor: Node, intent: Dictionary, age_frames: int, allow_autonomous_deposit := true) -> bool:
	if intent.is_empty() or age_frames >= TARGET_QUERY_REFRESH_FRAMES:
		return false
	if bool(intent.get("_allow_autonomous_deposit", true)) != allow_autonomous_deposit:
		return false
	var mode := String(intent.get("mode", ""))
	if mode in [
		ActorGoalSelectorScript.GOAL_DEPOSIT,
		ActorGoalSelectorScript.GOAL_RETURN_READY,
		ActorGoalSelectorScript.GOAL_FORAGE
	]:
		return goal_selector.goal_is_valid(actor, intent)
	var target: Node = intent.get("target", null)
	if target != null and not TargetFilter.is_live_damage_target(actor, target, LIVE_DAMAGE_QUERY):
		return false
	if target != null and not _can_perceive(actor, target):
		return false  # target slipped into fog -> re-choose (may become an investigate)
	if String(intent.get("mode", "")) == "retreat" and _health_ratio(actor) > RETREAT_EXIT_HEALTH_RATIO:
		return false
	return true

func _choose_intent(actor: Node, allow_autonomous_deposit := true) -> Dictionary:
	var perf_candidates_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	var candidates := _target_candidates(actor)
	if PerfStats.enabled:
		PerfStats.add("bot_target_candidates", int(Time.get_ticks_usec() - perf_candidates_start))
	var retreat_intent := _retreat_intent(actor, candidates)
	if not retreat_intent.is_empty():
		return retreat_intent

	var actor_goal: Dictionary = goal_selector.choose_goal(actor, allow_autonomous_deposit)
	if not actor_goal.is_empty():
		return actor_goal

	var defense: Dictionary = _defense_intent(actor, candidates)
	if not defense.is_empty():
		return defense

	var target_intent := _best_target_intent(actor, candidates)
	if not target_intent.is_empty():
		return target_intent

	var investigate := _investigate_intent(actor)
	if not investigate.is_empty():
		return investigate

	return {"mode": "idle", "point": actor.global_position + Vector2.RIGHT}


func _retreat_intent(actor: Node, candidates: Variant = null) -> Dictionary:
	var visible_candidates: Array[Node] = candidates if candidates is Array else _target_candidates(actor)
	var close_threat: Node = _closest_candidate_to_point(
		visible_candidates,
		actor.global_position,
		RETREAT_THREAT_RANGE
	)
	var health_ratio := _health_ratio(actor)
	var should_retreat := close_threat != null and (
		health_ratio <= RETREAT_HEALTH_RATIO or (
			_is_retreating(actor) and health_ratio <= RETREAT_EXIT_HEALTH_RATIO
		)
	)
	if should_retreat:
		_set_retreating(actor, true)
		return {
			"mode": "retreat",
			"target": close_threat,
			"point": _retreat_point(actor)
		}
	_set_retreating(actor, false)
	return {}


func _is_return_goal(goal: Dictionary) -> bool:
	return String(goal.get("mode", "")) in [
		ActorGoalSelectorScript.GOAL_DEPOSIT,
		ActorGoalSelectorScript.GOAL_RETURN_READY
	]


func _order_frame(actor: Node, order: Dictionary) -> Resource:
	var role := String(order.get("role", ""))
	if role.is_empty():
		return null
	var destination: Vector2 = order.get("destination", actor.global_position)
	var target: Node = null
	match role:
		"follow":
			target = _actor_for_slot_id(actor, String(order.get("follow_slot_id", "")))
			if _valid_follow_target(actor, target):
				destination = target.global_position
			return _travel_frame(actor, destination, float(order.get("hold_radius", 80.0)), destination)
		"aggro":
			target = _actor_for_slot_id(actor, String(order.get("aggro_slot_id", "")))
			if not _valid_order_target(actor, target) or not _can_perceive(actor, target):
				var follow_actor := _actor_for_slot_id(actor, String(order.get("follow_slot_id", "")))
				if _valid_follow_target(actor, follow_actor):
					destination = follow_actor.global_position
				return _travel_frame(actor, destination, float(order.get("hold_radius", 80.0)), destination)
		"fight_boss":
			if actor.arena.has_method("get_live_objective_actor"):
				target = actor.arena.get_live_objective_actor(String(order.get("objective_id", "")))
		"defend":
			target = _closest_enemy_near_point(actor, destination, DEFEND_HUT_RADIUS)
		"contest":
			target = _closest_enemy_near_point(
				actor,
				destination,
				maxf(float(order.get("hold_radius", 80.0)) * 1.5, 80.0)
			)
		"pressure_lane":
			target = goal_selector.world_view.nearest_visible_enemy(actor, FIGHT_SCAN_RANGE)
	if _valid_order_target(actor, target) and _can_perceive(actor, target):
		return _order_combat_frame(actor, target, bool(order.get("allow_abilities", false)))
	return _travel_frame(
		actor,
		destination,
		float(order.get("hold_radius", 80.0)),
		destination
	)


func _order_combat_frame(actor: Node, target: Node, allow_abilities: bool) -> Resource:
	var frame := InputFrameScript.new()
	var target_position: Vector2 = target.global_position
	var offset: Vector2 = target_position - actor.global_position
	var distance: float = offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector2.RIGHT
	frame.aim = target_position
	var target_radius := _target_radius(target)
	var hold_range := _preferred_range(actor) + target_radius
	frame.move = _steered_move(actor, target_position, direction) if distance > hold_range else _strafe_direction(direction, actor.team)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, distance <= _preferred_range(actor) + actor.body_radius * 1.5 + target_radius)
	var ability_target: bool = target.has_method("is_scored_actor") and target.is_scored_actor()
	ability_target = ability_target or (
		target.has_method("is_boss_actor") and target.is_boss_actor()
	)
	if allow_abilities and ability_target:
		_hook(actor).apply(actor, target, frame, distance)
	return frame


func _travel_frame(actor: Node, destination: Vector2, hold_radius: float, aim: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = aim
	var offset: Vector2 = destination - actor.global_position
	if offset.length_squared() > hold_radius * hold_radius:
		frame.move = _steered_move(actor, destination, offset.normalized())
	return frame


func _actor_for_slot_id(actor: Node, slot_id: String) -> Node:
	if actor.arena != null and actor.arena.has_method("get_actor_for_slot_id"):
		return actor.arena.get_actor_for_slot_id(slot_id)
	return null


func _order_is_valid(actor: Node, order: Dictionary) -> bool:
	if order.is_empty() \
		or String(order.get("schema", "")) != TeamDirectorScript.SCHEMA \
		or int(order.get("team", -1)) != int(actor.team):
		return false
	if actor.arena == null or actor.arena.get("slot_registry") == null:
		return false
	if _slot_id_for_actor(actor) != String(order.get("slot_id", "")):
		return false
	var current_epoch := int(actor.arena.get("team_director_epoch"))
	return int(order.get("epoch", -1)) == current_epoch \
		and int(order.get("issued_epoch", current_epoch + 1)) <= current_epoch \
		and int(order.get("lease_until_epoch", current_epoch - 1)) >= current_epoch


func _valid_follow_target(actor: Node, target: Node) -> bool:
	return target != null \
		and is_instance_valid(target) \
		and target.get("team") != null \
		and int(target.get("team")) == int(actor.team) \
		and (not target.has_method("is_alive") or target.is_alive())


func _valid_order_target(actor: Node, target: Node) -> bool:
	return TargetFilter.is_live_damage_target(actor, target, ORDER_DAMAGE_QUERY)


func _slot_id_for_actor(actor: Node) -> String:
	var key := int(actor.get_instance_id())
	if actor_slot_ids.has(key):
		return String(actor_slot_ids[key])
	var slot: Dictionary = actor.arena.slot_registry.get_slot_for_actor(actor)
	var slot_id := String(slot.get("slot_id", ""))
	actor_slot_ids[key] = slot_id
	return slot_id


func _deposit_frame(actor: Node, intent: Dictionary) -> Resource:
	var frame := InputFrameScript.new()
	var point: Vector2 = intent.get("point", actor.global_position)
	frame.aim = point
	var habitat: Rect2 = intent.get("habitat", Rect2())
	if String(intent.get("mode", "")) == ActorGoalSelectorScript.GOAL_DEPOSIT \
		and habitat.size.x > 0.0 \
		and habitat.size.y > 0.0 \
		and habitat.grow(16.0).has_point(actor.global_position):
		frame.set_button(InputFrameScript.BUTTON_HABITAT_DEPOSIT, true)
		return frame
	var offset: Vector2 = point - actor.global_position
	if offset.length_squared() > 16.0:
		frame.move = _steered_move(actor, point, offset.normalized())
	return frame


func _forage_frame(actor: Node, intent: Dictionary) -> Resource:
	var frame := InputFrameScript.new()
	var observation: Dictionary = intent.get("food", {})
	var point: Vector2 = observation.get("point", intent.get("point", actor.global_position))
	frame.aim = point
	var resource: Node = observation.get("resource", null)
	var resource_radius := 0.0
	if resource != null and is_instance_valid(resource) and resource.get("body_radius") != null:
		resource_radius = float(resource.get("body_radius"))
	var requires_attack := bool(observation.get("requires_attack", false))
	var hold_radius := float(actor.body_radius) + resource_radius + 4.0
	if requires_attack:
		hold_radius = _preferred_range(actor) + float(actor.body_radius) * 1.5 + resource_radius
	var offset: Vector2 = point - actor.global_position
	var offset_length_squared := offset.length_squared()
	if offset_length_squared > hold_radius * hold_radius:
		frame.move = _steered_move(actor, point, offset.normalized() if offset_length_squared > 0.000001 else Vector2.RIGHT)
	elif requires_attack and String(observation.get("state", "")) == "visible":
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	return frame

# No visible target: move toward the nearest degraded marker for an enemy we lost sight of
# (last_known) or currently only hear (heard). Heard markers are coarse, not live exact pos.
func _investigate_intent(actor: Node) -> Dictionary:
	if actor.arena == null or not actor.arena.has_method("get_info_marker_point"):
		return {}
	if not _has_property(actor.arena, "entities"):
		return {}
	var best_point := Vector2.INF
	var best_distance := INF
	for entity in actor.arena.entities:
		if not _is_fog_gated_unit(actor, entity):
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		var state := String(actor.arena.get_entity_info_state(entity, actor.team))
		if state != "last_known" and state != "heard":
			continue
		var marker_point: Vector2 = actor.arena.get_info_marker_point(actor.team, entity)
		if marker_point == Vector2.INF:
			continue
		var distance: float = actor.global_position.distance_to(marker_point)
		if distance < best_distance:
			best_distance = distance
			best_point = marker_point
	if best_point == Vector2.INF:
		return {}
	return {"mode": "investigate", "point": best_point}

func _defense_intent(actor: Node, candidates: Variant = null) -> Dictionary:
	if actor.arena.get("huts") == null:
		return {}
	var visible_candidates: Array[Node] = candidates if candidates is Array else _target_candidates(actor)
	var best_enemy: Node = null
	var best_hut: Node = null
	var best_score: float = INF
	for hut in actor.arena.huts:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var enemy: Node = _closest_candidate_to_point(visible_candidates, hut.global_position, DEFEND_HUT_RADIUS)
		if enemy == null:
			continue
		var distance_to_hut: float = actor.global_position.distance_to(hut.global_position)
		if distance_to_hut > DEFEND_ACTOR_RANGE:
			continue
		var hut_ratio: float = _health_ratio(hut)
		var score: float = distance_to_hut + hut_ratio * 220.0
		if score < best_score:
			best_score = score
			best_hut = hut
			best_enemy = enemy
	if best_enemy != null:
		return {
			"mode": "defend",
			"target": best_enemy,
			"point": best_hut.global_position
		}
	return {}

func _best_target_intent(actor: Node, candidates: Variant = null) -> Dictionary:
	var best_target: Node = null
	var best_mode := "fight"
	var best_score := -INF
	var sticky_target := _sticky_target(actor)
	var visible_candidates: Array[Node] = candidates if candidates is Array else _target_candidates(actor)
	for candidate in visible_candidates:
		var score := _target_candidate_score(actor, candidate, sticky_target)
		if score > best_score:
			best_score = score
			best_target = candidate
			best_mode = "objective" if _is_objective_target(actor, candidate) else "fight"
	if best_target == null:
		_set_sticky_target(actor, null)
		return {}
	_set_sticky_target(actor, best_target)
	return {"mode": best_mode, "target": best_target}

func _target_candidates(actor: Node) -> Array[Node]:
	var candidates: Array[Node] = []
	if actor.arena == null:
		return candidates
	var actor_position: Vector2 = actor.global_position
	var actor_team := int(actor.team)
	if actor.arena.get("entities") != null:
		for entity in actor.arena.entities:
			if entity == null or not is_instance_valid(entity) or entity == actor:
				continue
			if not _has_property(entity, "team") or int(entity.get("team")) == actor_team:
				continue
			var is_hut_candidate := _is_hut(actor, entity)
			if not is_hut_candidate \
				and actor_position.distance_squared_to(entity.global_position) > FIGHT_SCAN_RANGE_SQUARED:
				continue
			if not TargetFilter.is_live_damage_target(actor, entity, LIVE_DAMAGE_QUERY):
				continue
			if not _can_perceive(actor, entity):
				continue
			candidates.append(entity)
	var core := _open_enemy_core(actor)
	if core != null:
		candidates.append(core)
	return candidates

func _target_candidate_score(actor: Node, target: Node, sticky_target: Node) -> float:
	var distance: float = actor.global_position.distance_to(target.global_position)
	var missing_health := 1.0 - _health_ratio(target)
	var score := 0.0
	if _is_core(actor, target):
		score = 1500.0 - distance * 0.2 + missing_health * 120.0
	elif _is_hut(actor, target):
		score = 850.0 - distance * 0.25 + missing_health * 220.0
	elif _is_combatant_target(target):
		score = 520.0 - distance * 0.45 + missing_health * 220.0 + _target_threat_score(target)
	else:
		score = 140.0 - distance * 0.45 + missing_health * 90.0
	if target == sticky_target:
		score += TARGET_STICKINESS_BONUS
	return score

func _target_threat_score(target: Node) -> float:
	var score := 0.0
	if target.has_method("is_scored_actor") and target.is_scored_actor():
		score += 90.0
	if _has_property(target, "creature_id") and String(target.get("creature_id")) != "":
		score += 70.0
	if _has_property(target, "damage"):
		score += clampf(float(target.get("damage")) * 2.5, 0.0, 120.0)
	if _has_property(target, "attack_range"):
		score += clampf(float(target.get("attack_range")) * 0.25, 0.0, 55.0)
	if _has_property(target, "kind"):
		match String(target.get("kind")):
			"tank":
				score += 70.0
			"pebble":
				score += 60.0
			"melee":
				score += 45.0
			"lane":
				score += 35.0
			_:
				score += 25.0
	return score

func _open_enemy_core(actor: Node) -> Node:
	if actor.arena == null or not actor.arena.has_method("get_enemy_core"):
		return null
	var core: Node = actor.arena.get_enemy_core(actor.team)
	if not _valid_target(core) or not _has_property(core, "team") or int(core.get("team")) == actor.team:
		return null
	if actor.arena.has_method("can_damage_core") and not actor.arena.can_damage_core(int(core.get("team"))):
		return null
	return core

func _is_objective_target(actor: Node, target: Node) -> bool:
	return _is_hut(actor, target) or _is_core(actor, target)

func _is_core(actor: Node, target: Node) -> bool:
	if actor.arena == null or not actor.arena.has_method("get_enemy_core"):
		return false
	return target == actor.arena.get_enemy_core(actor.team)

# BB-VIS-3: bots only act on enemy mobile units their team can currently see. Structures
# (huts/cores) and neutral objectives stay public; own units are never gated. Falls back to
# legacy always-perceive when the arena has no vision system.
func _can_perceive(actor: Node, target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if actor == null or actor.arena == null or not actor.arena.has_method("is_entity_visible_to_team"):
		return true
	if not _is_fog_gated_unit(actor, target):
		return true
	return actor.arena.is_entity_visible_to_team(target, actor.team)

func _is_fog_gated_unit(actor: Node, target: Node) -> bool:
	if not _has_property(target, "team"):
		return false
	var t := int(target.get("team"))
	if t < 0 or t == int(actor.team):
		return false
	if target.has_method("is_scored_actor") and target.is_scored_actor():
		return true
	# Enemy mobile minions carry `kind`; huts and cores do not. Bosses and
	# wildlife are neutral and returned above, so structures remain public.
	return _has_property(target, "kind")

func _is_combatant_target(target: Node) -> bool:
	if target.has_method("is_scored_actor") and target.is_scored_actor():
		return true
	if _has_property(target, "creature_id") and String(target.get("creature_id")) != "":
		return true
	return _has_property(target, "kind")

func _closest_enemy_near_point(actor: Node, point: Vector2, radius: float) -> Node:
	return _closest_candidate_to_point(_target_candidates(actor), point, radius)

func _closest_candidate_to_point(candidates: Array[Node], point: Vector2, radius: float) -> Node:
	var closest: Node = null
	var closest_distance_squared := radius * radius
	for candidate: Node in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var distance_squared: float = candidate.global_position.distance_squared_to(point)
		if distance_squared < closest_distance_squared:
			closest = candidate
			closest_distance_squared = distance_squared
	return closest

func _closest_live_enemy(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance_squared := max_distance * max_distance
	if actor.arena == null:
		return null
	if _has_property(actor.arena, "entities"):
		for entity in actor.arena.entities:
			if not TargetFilter.is_live_damage_target(actor, entity, LIVE_DAMAGE_QUERY):
				continue
			if not _can_perceive(actor, entity):
				continue
			var distance_squared: float = actor.global_position.distance_squared_to(entity.global_position)
			if distance_squared < closest_distance_squared:
				closest = entity
				closest_distance_squared = distance_squared
		return closest
	if actor.arena.has_method("get_closest_enemy"):
		var candidate: Node = actor.arena.get_closest_enemy(actor, max_distance)
		if TargetFilter.is_live_damage_target(actor, candidate, {"require_damage_api": false}):
			return candidate
	return null

func _retreat_point(actor: Node) -> Vector2:
	var best_point: Vector2 = actor.global_position
	var best_distance_squared: float = INF
	if actor.arena.has_method("get_team_spawn"):
		best_point = actor.arena.get_team_spawn(actor.team)
	for hut in actor.arena.huts if actor.arena.get("huts") != null else []:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var distance_squared: float = actor.global_position.distance_squared_to(hut.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_point = hut.global_position
	return best_point

func _aim_point(actor: Node, target: Node, fallback: Vector2, mode: String) -> Vector2:
	if mode == "retreat" and _valid_target(target):
		return target.global_position
	return fallback

func _valid_target(target: Node) -> bool:
	return TargetFilter.is_live_damage_target(null, target, VALID_TARGET_QUERY)

func _health_ratio(target: Node) -> float:
	var max_health := float(target.max_health)
	if max_health <= 0.0:
		return 1.0
	var health := float(target.health)
	return clampf(health / max_health, 0.0, 1.0)

func _target_radius(target: Node) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	if _has_property(target, "body_radius"):
		return float(target.body_radius)
	if _has_property(target, "radius"):
		return float(target.radius)
	return 0.0

func _is_hut(actor: Node, target: Node) -> bool:
	if actor.arena.get("huts") == null:
		return false
	return actor.arena.huts.has(target)

# PERF: O(1) `in` check — see target_filter.gd note; get_property_list()
# here cost ~110 ms per bot per tick (the 2026-07-05 unplayable-lag bug).
func _has_property(target: Object, property_name: String) -> bool:
	return property_name in target

func _sticky_target(actor: Node) -> Node:
	var key := int(actor.get_instance_id())
	var target: Node = sticky_targets.get(key, null)
	if TargetFilter.is_live_damage_target(actor, target, LIVE_DAMAGE_QUERY):
		return target
	sticky_targets.erase(key)
	return null

func _set_sticky_target(actor: Node, target: Node) -> void:
	var key := int(actor.get_instance_id())
	if target == null:
		sticky_targets.erase(key)
		return
	sticky_targets[key] = target

func _is_retreating(actor: Node) -> bool:
	return bool(retreating_actors.get(int(actor.get_instance_id()), false))

func _set_retreating(actor: Node, retreating: bool) -> void:
	var key := int(actor.get_instance_id())
	if retreating:
		retreating_actors[key] = true
	else:
		retreating_actors.erase(key)

# Bots route long moves through the arena's cover-aware steering so they
# slide around walls instead of walking into them (2026-07-05 playtest fix).
func _steered_move(actor: Node, destination: Vector2, fallback: Vector2) -> Vector2:
	if actor.arena != null and actor.arena.has_method("get_steering_direction"):
		var steered: Vector2 = actor.arena.get_steering_direction(actor.global_position, destination, float(actor.body_radius), actor.team)
		if steered != Vector2.ZERO:
			return steered
	return fallback

func _strafe_direction(direction: Vector2, team: int) -> Vector2:
	return Vector2(-direction.y, direction.x) * (1.0 if team == 0 else -1.0)

func _hook(actor: Node) -> RefCounted:
	if hooks.has(actor.creature_id):
		return hooks[actor.creature_id]
	var hook: RefCounted
	match actor.creature_id:
		"snapping_turtle":
			hook = TurtleHook.new()
		"water_snake":
			hook = WaterSnakeHook.new()
		"alligator":
			hook = AlligatorHook.new()
		"wolf_spider":
			hook = WolfSpiderHook.new()
		"firefly":
			hook = FireflyHook.new()
		"mosquito_swarm":
			hook = MosquitoSwarmHook.new()
		"chorus_frog":
			hook = FrogHook.new()
		"newt":
			hook = NewtHook.new()
		"mink":
			hook = MinkHook.new()
		"bullfrog":
			hook = BullfrogHook.new()
		"cane_toad":
			hook = CaneToadHook.new()
		"crayfish":
			hook = CrayfishHook.new()
		"bog_turtle":
			hook = BogTurtleHook.new()
		"water_shrew":
			hook = WaterShrewHook.new()
		"beaver":
			hook = BeaverHook.new()
		"otter":
			hook = OtterHook.new()
		"leech":
			hook = LeechHook.new()
		"owl":
			hook = OwlHook.new()
		"great_blue_heron":
			hook = HeronHook.new()
		"kingfisher":
			hook = KingfisherHook.new()
		"duck":
			hook = DuckHook.new()
		_:
			hook = FrogHook.new()
	hooks[actor.creature_id] = hook
	return hook

func _preferred_range(actor: Node) -> float:
	match actor.creature_id:
		"chorus_frog":
			return 46.0
		"newt":
			return 26.0
		"snapping_turtle":
			return 24.0
		"water_snake":
			return 22.0
		"alligator":
			return 24.0
		"wolf_spider":
			return 26.0
		"firefly":
			return 88.0
		"mosquito_swarm":
			return 72.0
		"mink":
			return 18.0
		"bullfrog":
			return 34.0
		"cane_toad":
			return 58.0
		"crayfish":
			return 28.0
		"bog_turtle":
			return 20.0
		"water_shrew":
			return 20.0
		"beaver":
			return 22.0
		"otter":
			return 20.0
		"leech":
			return 88.0
		"owl":
			return 60.0
		"great_blue_heron":
			return 52.0
		"kingfisher":
			return 24.0
		"duck":
			return 20.0
		_:
			return 32.0

func _primary_range(actor: Node, target: Node) -> float:
	return _preferred_range(actor) + actor.body_radius * 1.5 + _target_radius(target)
