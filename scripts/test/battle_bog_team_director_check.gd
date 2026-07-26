extends SceneTree

const TeamDirector := preload("res://scripts/ai/team_director.gd")

const BLUE := 0


func _initialize() -> void:
	var failures: Array[String] = []
	var deterministic_ok: bool = _check_determinism_capacities_and_fallback(failures)
	var ai_only_ok: bool = _check_ai_only_assignment(failures)
	var lease_ok: bool = _check_stable_short_lease(failures)
	var passed: bool = deterministic_ok and ai_only_ok and lease_ok

	print("team_director deterministic=%s ai_only=%s lease=%s" % [
		str(deterministic_ok),
		str(ai_only_ok),
		str(lease_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)


func _check_determinism_capacities_and_fallback(failures: Array[String]) -> bool:
	var slots: Array[Dictionary] = [
		_slot(0, Vector2(-102.0, 0.0)),
		_slot(1, Vector2(-98.0, 0.0)),
		_slot(2, Vector2(0.0, 0.0)),
		_slot(3, Vector2(98.0, 0.0)),
		_slot(4, Vector2(102.0, 0.0)),
		_slot(5, Vector2(220.0, 0.0))
	]
	var objectives: Array[Dictionary] = [
		_objective("contest", "contesting", Vector2(-100.0, 0.0)),
		_objective("claim", "claimable", Vector2.ZERO),
		_objective("boss", "active", Vector2(100.0, 0.0))
	]
	var lanes: Array[Dictionary] = [
		{"lane_id": 0, "push_point": Vector2(160.0, -30.0)},
		{"lane_id": 1, "push_point": Vector2(160.0, 30.0)}
	]
	var snapshot := _snapshot(10, slots, objectives, lanes)
	var reversed_snapshot := _snapshot(
		10,
		_reversed(slots),
		_reversed(objectives),
		_reversed(lanes)
	)
	var forward_orders: Dictionary = TeamDirector.new().build_orders(snapshot)
	var reversed_orders: Dictionary = TeamDirector.new().build_orders(reversed_snapshot)

	var contest_count := _role_count(forward_orders, TeamDirector.ROLE_CONTEST)
	var claim_count := _role_count(forward_orders, TeamDirector.ROLE_CLAIM)
	var fight_count := _role_count(forward_orders, TeamDirector.ROLE_FIGHT_BOSS)
	var pressure_count := _role_count(forward_orders, TeamDirector.ROLE_PRESSURE_LANE)
	var pressure_order: Dictionary = forward_orders.get("blue:5", {})
	var ok: bool = (
		forward_orders == reversed_orders
		and forward_orders.size() == 6
		and contest_count == 2
		and claim_count == 1
		and fight_count == 2
		and pressure_count == 1
		and String(pressure_order.get("role", "")) == TeamDirector.ROLE_PRESSURE_LANE
		and int(pressure_order.get("lane_id", -1)) == 1
		and pressure_order.get("destination", Vector2.ZERO) == Vector2(160.0, 30.0)
	)
	if not ok:
		failures.append(
			(
				"reversed snapshot input should produce identical stable orders with "
				+ "contest=2, claim=1, fight_boss=2, and one lane fallback; "
				+ "forward=%s reversed=%s counts=%s/%s/%s/%s"
			) % [
				str(forward_orders),
				str(reversed_orders),
				str(contest_count),
				str(claim_count),
				str(fight_count),
				str(pressure_count)
			]
		)
	return ok


func _check_ai_only_assignment(failures: Array[String]) -> bool:
	var slots: Array[Dictionary] = [
		_slot(0, Vector2.ZERO),
		_slot(1, Vector2(10.0, 0.0), "local_human"),
		_slot(2, Vector2(20.0, 0.0), "ai", false, true),
		_slot(3, Vector2(30.0, 0.0), "ai", true, false)
	]
	var orders: Dictionary = TeamDirector.new().build_orders(
		_snapshot(20, slots, [], [{"lane_id": 0, "push_point": Vector2(80.0, 0.0)}])
	)
	var ok: bool = (
		orders.size() == 1
		and orders.has("blue:0")
		and not orders.has("blue:1")
		and not orders.has("blue:2")
		and not orders.has("blue:3")
	)
	if not ok:
		failures.append(
			"only live, fielded AI slots should receive orders; orders=%s" % str(orders)
		)
	return ok


func _check_stable_short_lease(failures: Array[String]) -> bool:
	var objective := _objective("claim", "claimable", Vector2.ZERO)
	var initial_slots: Array[Dictionary] = [
		_slot(0, Vector2(1.0, 0.0)),
		_slot(1, Vector2(100.0, 0.0))
	]
	var director := TeamDirector.new()
	var initial: Dictionary = director.update(_snapshot(30, initial_slots, [objective], []))
	var moved_slots: Array[Dictionary] = [
		_slot(0, Vector2(100.0, 0.0)),
		_slot(1, Vector2(1.0, 0.0))
	]
	var during_lease: Dictionary = director.update(_snapshot(31, moved_slots, [objective], []))
	for epoch in range(32, 35):
		during_lease = director.update(_snapshot(epoch, moved_slots, [objective], []))
	var after_lease: Dictionary = director.update(_snapshot(35, moved_slots, [objective], []))
	var initial_claim := _slot_for_role(initial, TeamDirector.ROLE_CLAIM)
	var retained_claim := _slot_for_role(during_lease, TeamDirector.ROLE_CLAIM)
	var reassigned_claim := _slot_for_role(after_lease, TeamDirector.ROLE_CLAIM)
	var initial_order: Dictionary = initial.get(initial_claim, {})
	var ok: bool = (
		initial_claim == "blue:0"
		and retained_claim == "blue:0"
		and int(initial_order.get("lease_until_epoch", -1)) == 34
		and reassigned_claim == "blue:1"
	)
	if not ok:
		failures.append(
			(
				"claim assignment should remain stable through its short lease and "
				+ "re-evaluate after expiry; initial=%s during=%s after=%s"
			) % [str(initial), str(during_lease), str(after_lease)]
		)
	return ok


func _snapshot(
	epoch: int,
	slots: Array[Dictionary],
	objectives: Array,
	lanes: Array
) -> Dictionary:
	var typed_objectives: Array[Dictionary] = []
	for objective: Dictionary in objectives:
		typed_objectives.append(objective)
	var typed_lanes: Array[Dictionary] = []
	for lane: Dictionary in lanes:
		typed_lanes.append(lane)
	return {
		"epoch": epoch,
		"team": BLUE,
		"slots": slots,
		"objectives": typed_objectives,
		"huts": [] as Array[Dictionary],
		"lanes": typed_lanes,
		"player_override": {"kind": "none"}
	}


func _slot(
	slot_index: int,
	position: Vector2,
	driver_kind: String = "ai",
	alive: bool = true,
	field: bool = true
) -> Dictionary:
	return {
		"slot_id": "blue:%d" % slot_index,
		"slot_index": slot_index,
		"driver_kind": driver_kind,
		"alive": alive,
		"field": field,
		"position": position
	}


func _objective(
	objective_id: String,
	state: String,
	center: Vector2
) -> Dictionary:
	return {
		"objective_id": objective_id,
		"state": state,
		"center": center,
		"radius": Vector2(80.0, 60.0)
	}


func _reversed(source: Array) -> Array:
	var result := source.duplicate(true)
	result.reverse()
	return result


func _role_count(orders: Dictionary, role: String) -> int:
	var count := 0
	for order: Dictionary in orders.values():
		if String(order.get("role", "")) == role:
			count += 1
	return count


func _slot_for_role(orders: Dictionary, role: String) -> String:
	var slot_ids: Array[String] = []
	for slot_id: String in orders:
		var order: Dictionary = orders[slot_id]
		if String(order.get("role", "")) == role:
			slot_ids.append(slot_id)
	slot_ids.sort()
	return slot_ids[0] if not slot_ids.is_empty() else ""
