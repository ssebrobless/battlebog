extends RefCounted

const SCHEMA_VERSION := 1
const RULESET_COMPETITIVE_3V3 := "competitive_3v3"

const TOPOLOGY_SOLO_SWAP := "solo_swap"
const TOPOLOGY_ALL_BOTS := "all_bots"
const TOPOLOGY_LEGACY_SINGLE_LEAD := "legacy_single_lead"
const TOPOLOGY_FUTURE_NETWORK_TEAM := "future_network_team"

const OBJECTIVE_LOOP := [
	"forage",
	"fill_hunger",
	"deposit",
	"breed",
	"boss_meter",
	"claim_or_steal"
]

static func competitive_3v3() -> Dictionary:
	return _canonical_rules().duplicate(true)

static func _canonical_rules() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": RULESET_COMPETITIVE_3V3,
		"team_size": 3,
		"map_profile_id": "unified_large",
		"map_bounds_units": {
			"x": -240.0,
			"y": -85.0,
			"width": 480.0,
			"height": 170.0
		},
		"hut_count_per_team": 2,
		"lane_minions_per_hut": 3,
		"wave_interval_sec": 20.0,
		"hunger_full_to_empty_sec": 105.0,
		"initial_stocks_per_slot": 3,
		"stock_respawns": true,
		"respawn_policy_id": "habitat_stock",
		"core_targetable": false,
		"victory_policy_id": "team_stock_exhaustion",
		"ecology_enabled": true,
		"economy_enabled": true,
		"breeding_enabled": true,
		"side_bosses_enabled": true,
		"center_bosses_enabled": true,
		"visibility_enabled": true,
		"objective_loop": OBJECTIVE_LOOP.duplicate(),
		"objective_loop_text": "forage -> fill hunger -> deposit -> breed -> boss meter -> claim or steal"
	}

static func resolve(ruleset_id: String) -> Dictionary:
	if ruleset_id != RULESET_COMPETITIVE_3V3:
		return {}
	return competitive_3v3()

static func topology(control_topology_id: String) -> Dictionary:
	match control_topology_id:
		TOPOLOGY_SOLO_SWAP:
			return {
				"id": TOPOLOGY_SOLO_SWAP,
				"human_player_count": 1,
				"human_team_count": 1,
				"swappable_team_slots": 3,
				"active_human_slots": 1,
				"ai_controlled_slots": 5
			}.duplicate(true)
		TOPOLOGY_ALL_BOTS:
			return {
				"id": TOPOLOGY_ALL_BOTS,
				"human_player_count": 0,
				"human_team_count": 0,
				"swappable_team_slots": 0,
				"active_human_slots": 0,
				"ai_controlled_slots": 6
			}.duplicate(true)
		TOPOLOGY_LEGACY_SINGLE_LEAD:
			return {
				"id": TOPOLOGY_LEGACY_SINGLE_LEAD,
				"human_player_count": 1,
				"human_team_count": 1,
				"swappable_team_slots": 0,
				"active_human_slots": 1,
				"ai_controlled_slots": 5
			}.duplicate(true)
		TOPOLOGY_FUTURE_NETWORK_TEAM:
			return {
				"id": TOPOLOGY_FUTURE_NETWORK_TEAM,
				"human_player_count": 6,
				"human_team_count": 2,
				"swappable_team_slots": 0,
				"active_human_slots": 6,
				"ai_controlled_slots": 0
			}.duplicate(true)
	return {}

static func for_legacy_mode(mode: String) -> Dictionary:
	var normalized_mode := mode.strip_edges().to_lower()
	var control_topology_id := ""
	match normalized_mode:
		"1v1", "play vs ai":
			control_topology_id = TOPOLOGY_SOLO_SWAP
		"all bots", "all_bots":
			control_topology_id = TOPOLOGY_ALL_BOTS
		"3v3":
			control_topology_id = TOPOLOGY_LEGACY_SINGLE_LEAD
		_:
			return {}
	return {
		"legacy_mode": mode,
		"ruleset_id": RULESET_COMPETITIVE_3V3,
		"control_topology_id": control_topology_id,
		"rules": competitive_3v3(),
		"control_topology": topology(control_topology_id)
	}.duplicate(true)

static func validate_rules(rules: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var required := _canonical_rules()
	for key in required:
		if not rules.has(key):
			errors.append("missing required rule: %s" % key)
		elif rules[key] != required[key]:
			errors.append("wrong canonical value for rule: %s" % key)
	return errors
