extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"

const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const LOCAL_HUMAN := "local_human"
const AI := "ai"
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const OBJECTIVE_ROLES := ["fight_boss", "claim", "contest"]
const LEGAL_ROLES := [
	"follow",
	"aggro",
	"contest",
	"claim",
	"defend",
	"fight_boss",
	"pressure_lane"
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("team director runtime check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	config.selected_mode = "Play vs AI"
	config.set_selected_squad_ids(TEST_SQUAD)
	config.selected_creature_id = TEST_SQUAD[0]
	config.wake_boss = false
	config.center_boss = false

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		_restore_config(config, original_config)
		push_error("team director runtime check failed to boot Arena: error=%d" % error)
		quit(1)
		return
	await process_frame
	await physics_frame
	await process_frame

	var arena := current_scene
	if arena == null \
		or not arena.has_method("get_team_order_state") \
		or not arena.has_method("get_match_slot_state") \
		or not arena.has_method("get_actor_for_slot_id"):
		_restore_config(config, original_config)
		push_error("team director runtime check could not inspect Arena APIs")
		quit(1)
		return

	arena.set_physics_process(false)
	var baseline_ok := _check_baseline_orders(arena, failures)
	var overrides_ok := _check_player_overrides(arena, failures)
	var objectives_ok := _check_objective_roles(arena, failures)
	_restore_config(config, original_config)

	var passed := baseline_ok and overrides_ok and objectives_ok
	print(
		"team_director_runtime baseline=%s overrides=%s objectives=%s failures=%d"
		% [str(baseline_ok), str(overrides_ok), str(objectives_ok), failures.size()]
	)
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _check_baseline_orders(arena: Node, failures: Array[String]) -> bool:
	arena._issue_squad_farm(false)
	_force_director_tick(arena)
	var coverage_ok := _check_legal_ai_coverage(arena, "baseline", failures)
	var blue_orders: Dictionary = arena.get_team_order_state(BLUE)
	var red_orders: Dictionary = arena.get_team_order_state(RED)
	var local_slot_id := _local_slot_id(arena)
	var shape_ok := (
		blue_orders.size() == TEAM_SIZE - 1
		and red_orders.size() == TEAM_SIZE
		and not blue_orders.has(local_slot_id)
	)
	if not shape_ok:
		failures.append(
			"baseline expected two inactive Blue orders, three Red orders, and no local order; "
			+ "local=%s blue=%s red=%s"
			% [local_slot_id, str(blue_orders), str(red_orders)]
		)
	return coverage_ok and shape_ok


func _check_player_overrides(arena: Node, failures: Array[String]) -> bool:
	var player_slot_id := _local_slot_id(arena)
	var player: Node = arena.get_actor_for_slot_id(player_slot_id)
	var blue_ai_ids := _ai_slot_ids(arena, BLUE)
	var target_slot_id := _first_ai_slot_id(arena, RED)
	var target: Node = arena.get_actor_for_slot_id(target_slot_id)
	if player == null or target == null or blue_ai_ids.size() != TEAM_SIZE - 1:
		failures.append(
			"override fixture actors unavailable; player=%s target=%s blue_ai=%s"
			% [str(player), str(target), str(blue_ai_ids)]
		)
		return false

	var actors: Array[Node] = [player, target]
	for slot_id: String in blue_ai_ids:
		var actor: Node = arena.get_actor_for_slot_id(slot_id)
		if actor != null:
			actors.append(actor)
	var saved_states := _capture_actor_states(actors)
	_prepare_override_fixture(arena, player, target, blue_ai_ids)

	arena._issue_squad_follow(false)
	_force_director_tick(arena)
	var follow_orders_ok := _blue_player_orders_match(
		arena,
		blue_ai_ids,
		"follow",
		"follow_slot_id",
		player_slot_id
	)
	var follow_coverage_ok := _check_legal_ai_coverage(arena, "follow", failures)
	arena._feed_registered_inputs()
	var follow_frames_ok := _frames_aim_at(arena, blue_ai_ids, player.global_position)
	if not follow_orders_ok or not follow_frames_ok:
		failures.append(
			"follow should apply only to inactive Blue AI and route them toward the local actor; "
			+ "orders=%s frames_ok=%s"
			% [str(arena.get_team_order_state(BLUE)), str(follow_frames_ok)]
		)

	arena.reveal_entity_to_team(target, BLUE, 5.0)
	arena._issue_squad_aggro(target)
	_force_director_tick(arena)
	var aggro_orders_ok := _blue_player_orders_match(
		arena,
		blue_ai_ids,
		"aggro",
		"aggro_slot_id",
		target_slot_id
	)
	var aggro_coverage_ok := _check_legal_ai_coverage(arena, "aggro", failures)
	arena._feed_registered_inputs()
	var aggro_frames_ok := _frames_aim_at(arena, blue_ai_ids, target.global_position)
	if not aggro_orders_ok or not aggro_frames_ok:
		failures.append(
			"visible aggro should assign the target to inactive Blue AI and route toward it; "
			+ "orders=%s frames_ok=%s"
			% [str(arena.get_team_order_state(BLUE)), str(aggro_frames_ok)]
		)

	target.global_position = player.global_position + Vector2(2400.0, 0.0)
	arena._tick_team_vision(6.0)
	_force_director_tick(arena)
	arena._feed_registered_inputs()
	var target_hidden: bool = not arena.is_entity_visible_to_team(target, BLUE)
	var hidden_fallback_ok := _frames_aim_at(arena, blue_ai_ids, player.global_position)
	if not target_hidden or not hidden_fallback_ok:
		failures.append(
			"hidden aggro target should degrade to follow without an illegal target frame; "
			+ "hidden=%s frames_ok=%s orders=%s"
			% [
				str(target_hidden),
				str(hidden_fallback_ok),
				str(arena.get_team_order_state(BLUE))
			]
		)

	target.health = 0.0
	target.alive = false
	_force_director_tick(arena)
	arena._feed_registered_inputs()
	var invalid_fallback_ok := _frames_aim_at(arena, blue_ai_ids, player.global_position)
	if not invalid_fallback_ok:
		failures.append(
			"invalid aggro target should degrade to follow without stale target input; orders=%s"
			% str(arena.get_team_order_state(BLUE))
		)

	_restore_actor_states(saved_states)
	arena._issue_squad_farm(false)
	_force_director_tick(arena)
	return (
		follow_orders_ok
		and follow_coverage_ok
		and follow_frames_ok
		and aggro_orders_ok
		and aggro_coverage_ok
		and aggro_frames_ok
		and target_hidden
		and hidden_fallback_ok
		and invalid_fallback_ok
	)


func _check_objective_roles(arena: Node, failures: Array[String]) -> bool:
	var zone_index := _boss_zone_index(arena, "blue")
	if zone_index < 0:
		failures.append("objective fixture could not find the existing blue boss zone")
		return false
	var original_zone: Dictionary = arena.animal_zone_states[zone_index].duplicate(true)
	var objective_id := String(original_zone.get("id", ""))
	var all_ok := true
	var cases := [
		{"state": "active", "role": "fight_boss", "capacity": 2},
		{"state": "claimable", "role": "claim", "capacity": 1},
		{"state": "contesting", "role": "contest", "capacity": 2}
	]

	arena._issue_squad_farm(false)
	for fixture: Dictionary in cases:
		_set_boss_zone_state(arena, zone_index, String(fixture["state"]))
		_force_director_tick(arena)
		var coverage_ok := _check_legal_ai_coverage(
			arena,
			"objective " + String(fixture["state"]),
			failures
		)
		var bounds_ok := true
		for team_value in [BLUE, RED]:
			var team := int(team_value)
			var expected := mini(_ai_slot_ids(arena, team).size(), int(fixture["capacity"]))
			var matching := _matching_objective_orders(
				arena.get_team_order_state(team),
				String(fixture["role"]),
				objective_id
			)
			if matching.size() != expected:
				bounds_ok = false
		if not coverage_ok or not bounds_ok:
			failures.append(
				"%s objective should produce bounded %s assignments; blue=%s red=%s"
				% [
					String(fixture["state"]),
					String(fixture["role"]),
					str(arena.get_team_order_state(BLUE)),
					str(arena.get_team_order_state(RED))
				]
			)
		all_ok = all_ok and coverage_ok and bounds_ok

	_set_boss_zone_state(arena, zone_index, "dormant")
	_force_director_tick(arena)
	var resolved_coverage_ok := _check_legal_ai_coverage(arena, "objective resolved", failures)
	var stale_count := 0
	for team_value in [BLUE, RED]:
		for order: Dictionary in arena.get_team_order_state(int(team_value)).values():
			if String(order.get("objective_id", "")) == objective_id \
				or OBJECTIVE_ROLES.has(String(order.get("role", ""))):
				stale_count += 1
	var resolved_ok := stale_count == 0
	if not resolved_ok:
		failures.append(
			"resolved objective should clear leased objective roles without stale orders; "
			+ "blue=%s red=%s"
			% [
				str(arena.get_team_order_state(BLUE)),
				str(arena.get_team_order_state(RED))
			]
		)

	arena.animal_zone_states[zone_index] = original_zone
	_force_director_tick(arena)
	return all_ok and resolved_coverage_ok and resolved_ok


func _check_legal_ai_coverage(
	arena: Node,
	label: String,
	failures: Array[String]
) -> bool:
	var slot_state: Dictionary = arena.get_match_slot_state()
	var all_ok := true
	for team_value in [BLUE, RED]:
		var team := int(team_value)
		var orders: Dictionary = arena.get_team_order_state(team)
		var expected_ids := _ai_slot_ids(arena, team)
		var actual_ids: Array[String] = []
		for order_key in orders:
			actual_ids.append(String(order_key))
			var order: Dictionary = orders[order_key]
			var destination = order.get("destination", null)
			var order_ok := (
				String(order.get("schema", "")) == "battle_bog_team_order_v1"
				and int(order.get("team", -1)) == team
				and String(order.get("slot_id", "")) == String(order_key)
				and LEGAL_ROLES.has(String(order.get("role", "")))
				and destination is Vector2
				and (destination as Vector2).is_finite()
				and int(order.get("lease_until_epoch", -1))
					>= int(order.get("issued_epoch", 0))
				and arena.get_actor_for_slot_id(String(order_key)) != null
			)
			all_ok = all_ok and order_ok
		actual_ids.sort()
		expected_ids.sort()
		all_ok = all_ok and actual_ids == expected_ids

	var local_ids: Array[String] = []
	for team_key in ["blue", "red"]:
		for slot: Dictionary in slot_state.get(team_key, []):
			var controller: Dictionary = slot.get("controller", {})
			if String(controller.get("kind", "")) == LOCAL_HUMAN:
				local_ids.append(String(slot.get("slot_id", "")))
	for local_id: String in local_ids:
		all_ok = (
			all_ok
			and not arena.get_team_order_state(BLUE).has(local_id)
			and not arena.get_team_order_state(RED).has(local_id)
		)
	if not all_ok:
		failures.append(
			"%s expected exactly one legal order per live AI slot and none for local humans; "
			+ "slots=%s orders=%s"
			% [label, str(slot_state), str(arena.get_team_order_state())]
		)
	return all_ok


func _blue_player_orders_match(
	arena: Node,
	blue_ai_ids: Array[String],
	role: String,
	target_key: String,
	target_slot_id: String
) -> bool:
	var orders: Dictionary = arena.get_team_order_state(BLUE)
	if orders.size() != blue_ai_ids.size() or orders.has(_local_slot_id(arena)):
		return false
	for slot_id: String in blue_ai_ids:
		var order: Dictionary = orders.get(slot_id, {})
		if String(order.get("role", "")) != role \
			or String(order.get("source", "")) != "player" \
			or String(order.get(target_key, "")) != target_slot_id:
			return false
	return true


func _frames_aim_at(arena: Node, slot_ids: Array[String], point: Vector2) -> bool:
	for slot_id: String in slot_ids:
		var actor: Node = arena.get_actor_for_slot_id(slot_id)
		if actor == null or actor.input_frame == null:
			return false
		if (actor.input_frame.aim as Vector2).distance_to(point) > 1.0:
			return false
	return true


func _matching_objective_orders(
	orders: Dictionary,
	role: String,
	objective_id: String
) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for order: Dictionary in orders.values():
		if String(order.get("role", "")) == role \
			and String(order.get("objective_id", "")) == objective_id:
			matching.append(order)
	return matching


func _force_director_tick(arena: Node) -> void:
	arena._tick_team_directors(1.0)


func _prepare_override_fixture(
	arena: Node,
	player: Node,
	target: Node,
	blue_ai_ids: Array[String]
) -> void:
	player.health = player.max_health
	player.hunger = 75.0
	for index in blue_ai_ids.size():
		var actor: Node = arena.get_actor_for_slot_id(blue_ai_ids[index])
		actor.health = actor.max_health
		actor.hunger = 75.0
		actor.global_position = player.global_position + Vector2(-160.0, (float(index) - 0.5) * 180.0)
	target.health = target.max_health
	target.alive = true
	target.global_position = player.global_position + Vector2(500.0, 0.0)


func _capture_actor_states(actors: Array[Node]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for actor: Node in actors:
		states.append({
			"actor": actor,
			"position": actor.global_position,
			"health": float(actor.health),
			"hunger": float(actor.hunger),
			"alive": bool(actor.alive)
		})
	return states


func _restore_actor_states(states: Array[Dictionary]) -> void:
	for state: Dictionary in states:
		var actor: Node = state.get("actor", null)
		if actor == null or not is_instance_valid(actor):
			continue
		actor.global_position = state.get("position", actor.global_position)
		actor.health = float(state.get("health", actor.health))
		actor.hunger = float(state.get("hunger", actor.hunger))
		actor.alive = bool(state.get("alive", actor.alive))


func _set_boss_zone_state(arena: Node, zone_index: int, state: String) -> void:
	var zone: Dictionary = arena.animal_zone_states[zone_index].duplicate(true)
	zone["objective_state"] = state
	zone["active"] = state == "active"
	zone["contested"] = state == "contesting"
	zone["claim_team"] = BLUE if state in ["claimable", "contesting"] else -1
	zone["control_team"] = -1
	arena.animal_zone_states[zone_index] = zone


func _boss_zone_index(arena: Node, side: String) -> int:
	for index in arena.animal_zone_states.size():
		var zone: Dictionary = arena.animal_zone_states[index]
		if bool(zone.get("boss", false)) and String(zone.get("side", "")) == side:
			return index
	return -1


func _ai_slot_ids(arena: Node, team: int) -> Array[String]:
	var key := "blue" if team == BLUE else "red"
	var ids: Array[String] = []
	for slot: Dictionary in arena.get_match_slot_state().get(key, []):
		var controller: Dictionary = slot.get("controller", {})
		if String(controller.get("kind", "")) == AI:
			ids.append(String(slot.get("slot_id", "")))
	ids.sort()
	return ids


func _local_slot_id(arena: Node) -> String:
	for slot: Dictionary in arena.get_match_slot_state().get("blue", []):
		var controller: Dictionary = slot.get("controller", {})
		if String(controller.get("kind", "")) == LOCAL_HUMAN:
			return String(slot.get("slot_id", ""))
	return ""


func _first_ai_slot_id(arena: Node, team: int) -> String:
	var ids := _ai_slot_ids(arena, team)
	return ids[0] if not ids.is_empty() else ""


func _capture_config(config: Node) -> Dictionary:
	return {
		"selected_mode": String(config.selected_mode),
		"selected_creature_id": String(config.selected_creature_id),
		"selected_squad_ids": config.selected_squad_ids.duplicate(),
		"blue_draft_bans": config.blue_draft_bans.duplicate(),
		"red_draft_bans": config.red_draft_bans.duplicate(),
		"wake_boss": bool(config.wake_boss),
		"center_boss": bool(config.center_boss)
	}


func _restore_config(config: Node, state: Dictionary) -> void:
	config.selected_mode = String(state.get("selected_mode", "1v1"))
	config.selected_creature_id = String(
		state.get("selected_creature_id", "snapping_turtle")
	)
	config.selected_squad_ids.assign(state.get("selected_squad_ids", []))
	config.blue_draft_bans.assign(state.get("blue_draft_bans", []))
	config.red_draft_bans.assign(state.get("red_draft_bans", []))
	config.wake_boss = bool(state.get("wake_boss", false))
	config.center_boss = bool(state.get("center_boss", false))
