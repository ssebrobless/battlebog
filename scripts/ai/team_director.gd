extends RefCounted

const SCHEMA := "battle_bog_team_order_v1"
const UPDATE_INTERVAL_SEC := 0.25

const ROLE_FOLLOW := "follow"
const ROLE_AGGRO := "aggro"
const ROLE_CONTEST := "contest"
const ROLE_CLAIM := "claim"
const ROLE_DEFEND := "defend"
const ROLE_FIGHT_BOSS := "fight_boss"
const ROLE_PRESSURE_LANE := "pressure_lane"

const LEASE_EPOCHS := {
	ROLE_CONTEST: 2,
	ROLE_CLAIM: 4,
	ROLE_DEFEND: 4,
	ROLE_FIGHT_BOSS: 4,
	ROLE_PRESSURE_LANE: 6,
	ROLE_FOLLOW: 40,
	ROLE_AGGRO: 40
}

var _orders_by_team: Dictionary = {}


func update(snapshot: Dictionary) -> Dictionary:
	var team := int(snapshot.get("team", -1))
	var previous: Dictionary = _orders_by_team.get(team, {})
	var orders := build_orders(snapshot, previous)
	_orders_by_team[team] = orders.duplicate(true)
	return orders


func build_orders(snapshot: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var epoch := int(snapshot.get("epoch", 0))
	var team := int(snapshot.get("team", -1))
	var available: Array[Dictionary] = []
	for slot: Dictionary in snapshot.get("slots", []):
		if String(slot.get("driver_kind", "")) != "ai":
			continue
		if not bool(slot.get("alive", false)) or not bool(slot.get("field", false)):
			continue
		available.append(slot.duplicate(true))
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("slot_id", "")) < String(b.get("slot_id", ""))
	)

	var orders: Dictionary = {}
	var override: Dictionary = snapshot.get("player_override", {})
	var override_kind := String(override.get("kind", "none"))
	if override_kind == ROLE_FOLLOW or override_kind == ROLE_AGGRO:
		for slot: Dictionary in available:
			var role_key := "player:%s" % override_kind
			orders[String(slot.get("slot_id", ""))] = _make_order(
				epoch,
				team,
				slot,
				override_kind,
				role_key,
				1000,
				override.get("destination", slot.get("position", Vector2.ZERO)),
				{
					"source": "player",
					"follow_slot_id": String(override.get("follow_slot_id", "")),
					"aggro_slot_id": String(override.get("aggro_slot_id", "")),
					"hold_radius": float(override.get("hold_radius", 80.0)),
					"allow_abilities": override_kind == ROLE_AGGRO
				}
			)
		return orders

	var demands: Array[Dictionary] = []
	for objective: Dictionary in snapshot.get("objectives", []):
		var state := String(objective.get("state", "dormant"))
		var scope := String(objective.get("scope", ""))
		var role := ""
		var urgency := 0
		var capacity := 0
		match state:
			"contesting":
				role = ROLE_CONTEST
				urgency = 900
				capacity = 2
			"claimable":
				role = ROLE_CLAIM
				urgency = 800
				capacity = 1
			"active":
				role = ROLE_FIGHT_BOSS
				urgency = 750 if scope == "center" else 725
				capacity = 2
		if role.is_empty():
			continue
		demands.append({
			"role": role,
			"role_key": "%s:%s" % [role, String(objective.get("objective_id", ""))],
			"urgency": urgency,
			"scope_rank": _objective_scope_rank(scope, team),
			"capacity": capacity,
			"destination": objective.get("center", Vector2.ZERO),
			"extra": {
				"objective_id": String(objective.get("objective_id", "")),
				"hold_radius": _objective_hold_radius(objective),
				"allow_abilities": role in [ROLE_FIGHT_BOSS, ROLE_CONTEST]
			}
		})
	for hut: Dictionary in snapshot.get("huts", []):
		if not bool(hut.get("alive", false)) or int(hut.get("visible_threat_count", 0)) <= 0:
			continue
		demands.append({
			"role": ROLE_DEFEND,
			"role_key": "%s:%s" % [ROLE_DEFEND, String(hut.get("hut_id", ""))],
			"urgency": 700,
			"capacity": 1,
			"destination": hut.get("position", Vector2.ZERO),
			"extra": {
				"hut_id": String(hut.get("hut_id", "")),
				"lane_id": int(hut.get("lane_id", -1)),
				"hold_radius": 110.0,
				"allow_abilities": true
			}
		})
	demands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var urgency_a := int(a.get("urgency", 0))
		var urgency_b := int(b.get("urgency", 0))
		if urgency_a != urgency_b:
			return urgency_a > urgency_b
		var scope_rank_a := int(a.get("scope_rank", 0))
		var scope_rank_b := int(b.get("scope_rank", 0))
		if scope_rank_a != scope_rank_b:
			return scope_rank_a > scope_rank_b
		return String(a.get("role_key", "")) < String(b.get("role_key", ""))
	)

	for demand: Dictionary in demands:
		_assign_demand(epoch, team, demand, available, previous, orders)

	var lanes: Array[Dictionary] = snapshot.get("lanes", [])
	lanes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("lane_id", -1)) < int(b.get("lane_id", -1))
	)
	for slot: Dictionary in available:
		var lane: Dictionary = lanes[int(slot.get("slot_index", 0)) % lanes.size()] if not lanes.is_empty() else {}
		var lane_id := int(lane.get("lane_id", 0))
		var destination: Vector2 = lane.get("push_point", slot.get("position", Vector2.ZERO))
		orders[String(slot.get("slot_id", ""))] = _make_order(
			epoch,
			team,
			slot,
			ROLE_PRESSURE_LANE,
			"%s:%d" % [ROLE_PRESSURE_LANE, lane_id],
			400,
			destination,
			{
				"lane_id": lane_id,
				"hold_radius": 90.0,
				"allow_abilities": true
			}
		)
	return orders


func get_orders(team: int) -> Dictionary:
	return _orders_by_team.get(team, {}).duplicate(true)


func reset_team(team: int) -> void:
	_orders_by_team.erase(team)


func _assign_demand(
	epoch: int,
	team: int,
	demand: Dictionary,
	available: Array[Dictionary],
	previous: Dictionary,
	orders: Dictionary
) -> void:
	var capacity := mini(int(demand.get("capacity", 0)), available.size())
	if capacity <= 0:
		return
	var role_key := String(demand.get("role_key", ""))
	var retained: Array[Dictionary] = []
	var retained_orders: Dictionary = {}
	for slot: Dictionary in available:
		var slot_id := String(slot.get("slot_id", ""))
		var prior: Dictionary = previous.get(slot_id, {})
		if String(prior.get("role_key", "")) == role_key \
			and int(prior.get("lease_until_epoch", -1)) >= epoch:
			retained.append(slot)
			retained_orders[slot_id] = prior.duplicate(true)
	retained.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("slot_id", "")) < String(b.get("slot_id", ""))
	)
	var selected: Array[Dictionary] = []
	for slot: Dictionary in retained:
		if selected.size() >= capacity:
			break
		selected.append(slot)
	var remaining_capacity := capacity - selected.size()
	if remaining_capacity > 0:
		var candidates := available.duplicate(true)
		for retained_slot: Dictionary in selected:
			_erase_slot(candidates, String(retained_slot.get("slot_id", "")))
		var destination: Vector2 = demand.get("destination", Vector2.ZERO)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var distance_a := int(round((a.get("position", Vector2.ZERO) as Vector2).distance_to(destination)))
			var distance_b := int(round((b.get("position", Vector2.ZERO) as Vector2).distance_to(destination)))
			if distance_a != distance_b:
				return distance_a < distance_b
			return String(a.get("slot_id", "")) < String(b.get("slot_id", ""))
		)
		for slot: Dictionary in candidates:
			if selected.size() >= capacity:
				break
			selected.append(slot)
	for slot: Dictionary in selected:
		var slot_id := String(slot.get("slot_id", ""))
		var order := _make_order(
			epoch,
			team,
			slot,
			String(demand.get("role", "")),
			role_key,
			int(demand.get("urgency", 0)),
			demand.get("destination", Vector2.ZERO),
			demand.get("extra", {})
		)
		if retained_orders.has(slot_id):
			var retained_order: Dictionary = retained_orders[slot_id]
			order["issued_epoch"] = int(retained_order.get("issued_epoch", epoch))
			order["lease_until_epoch"] = int(retained_order.get("lease_until_epoch", epoch))
		orders[slot_id] = order
		_erase_slot(available, slot_id)


func _make_order(
	epoch: int,
	team: int,
	slot: Dictionary,
	role: String,
	role_key: String,
	urgency: int,
	destination: Vector2,
	extra: Dictionary
) -> Dictionary:
	var order := {
		"schema": SCHEMA,
		"epoch": epoch,
		"team": team,
		"slot_id": String(slot.get("slot_id", "")),
		"role": role,
		"role_key": role_key,
		"source": String(extra.get("source", "director")),
		"issued_epoch": epoch,
		"lease_until_epoch": epoch + int(LEASE_EPOCHS.get(role, 4)),
		"urgency": urgency,
		"destination": destination,
		"hold_radius": float(extra.get("hold_radius", 80.0)),
		"allow_abilities": bool(extra.get("allow_abilities", false))
	}
	for key in ["hut_id", "lane_id", "objective_id", "follow_slot_id", "aggro_slot_id"]:
		if extra.has(key):
			order[key] = extra[key]
	return order


func _objective_hold_radius(objective: Dictionary) -> float:
	var radius: Vector2 = objective.get("radius", Vector2(80.0, 60.0))
	return maxf(minf(radius.x, radius.y) * 0.55, 24.0)


func _objective_scope_rank(scope: String, team: int) -> int:
	if scope == "center":
		return 2
	var home_scope := "blue" if team == 0 else "red"
	return 1 if scope == home_scope else 0


func _erase_slot(slots: Array[Dictionary], slot_id: String) -> void:
	for i in range(slots.size() - 1, -1, -1):
		if String(slots[i].get("slot_id", "")) == slot_id:
			slots.remove_at(i)
			return
