extends SceneTree

const MatchRules := preload("res://scripts/game/match_rules.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var canonical_ok := _check_canonical(failures)
	var copy_ok := _check_copy_isolation(failures)
	var deterministic_ok := _check_determinism(failures)
	var legacy_ok := _check_legacy_parity(failures)
	var topology_ok := _check_topologies(failures)
	var validation_ok := _check_validation(failures)
	var rejection_ok := _check_unknown_ids(failures)
	var passed := canonical_ok and copy_ok and deterministic_ok and legacy_ok and topology_ok and validation_ok and rejection_ok

	print("match_rules canonical=%s copy=%s deterministic=%s legacy=%s topology=%s validation=%s rejection=%s" % [
		str(canonical_ok),
		str(copy_ok),
		str(deterministic_ok),
		str(legacy_ok),
		str(topology_ok),
		str(validation_ok),
		str(rejection_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_canonical(failures: Array[String]) -> bool:
	var rules: Dictionary = MatchRules.competitive_3v3()
	var bounds: Dictionary = rules.get("map_bounds_units", {})
	var centered := (
		float(bounds.get("x", INF)) + float(bounds.get("width", -INF)) * 0.5 == 0.0
		and float(bounds.get("y", INF)) + float(bounds.get("height", -INF)) * 0.5 == 0.0
	)
	var ok: bool = (
		MatchRules.SCHEMA_VERSION == 1
		and MatchRules.RULESET_COMPETITIVE_3V3 == "competitive_3v3"
		and rules.get("schema_version") == MatchRules.SCHEMA_VERSION
		and rules.get("id") == MatchRules.RULESET_COMPETITIVE_3V3
		and rules.get("team_size") == 3
		and rules.get("map_profile_id") == "unified_large"
		and bounds.get("x") == -240.0
		and bounds.get("y") == -85.0
		and bounds.get("width") == 480.0
		and bounds.get("height") == 170.0
		and centered
		and rules.get("hut_count_per_team") == 2
		and rules.get("lane_minions_per_hut") == 3
		and rules.get("wave_interval_sec") == 20.0
		and rules.get("hunger_full_to_empty_sec") == 105.0
		and rules.get("initial_stocks_per_slot") == 3
		and rules.get("stock_respawns") == true
		and rules.get("respawn_policy_id") == "habitat_stock"
		and rules.get("victory_policy_id") == "team_stock_exhaustion"
		and rules.get("core_targetable") == false
		and rules.get("ecology_enabled") == true
		and rules.get("economy_enabled") == true
		and rules.get("breeding_enabled") == true
		and rules.get("side_bosses_enabled") == true
		and rules.get("center_bosses_enabled") == true
		and rules.get("visibility_enabled") == true
	)
	if not ok:
		failures.append("canonical competitive_3v3 rules do not match the locked Battle Bog contract")
	return ok

func _check_copy_isolation(failures: Array[String]) -> bool:
	var mutated: Dictionary = MatchRules.competitive_3v3()
	mutated["map_bounds_units"]["x"] = 999.0
	mutated["objective_loop"].append("mutated")

	var fresh: Dictionary = MatchRules.competitive_3v3()
	var legacy: Dictionary = MatchRules.for_legacy_mode("Play vs AI")
	legacy["rules"]["map_bounds_units"]["width"] = 1.0
	legacy["control_topology"]["ai_controlled_slots"] = -1
	var fresh_legacy: Dictionary = MatchRules.for_legacy_mode("Play vs AI")

	var ok: bool = (
		fresh["map_bounds_units"]["x"] == -240.0
		and not fresh["objective_loop"].has("mutated")
		and fresh_legacy["rules"]["map_bounds_units"]["width"] == 480.0
		and fresh_legacy["control_topology"]["ai_controlled_slots"] == 5
	)
	if not ok:
		failures.append("rules or topology results leak mutations across calls")
	return ok

func _check_determinism(failures: Array[String]) -> bool:
	var canonical: Dictionary = MatchRules.competitive_3v3()
	var ok: bool = (
		canonical == MatchRules.competitive_3v3()
		and canonical == MatchRules.resolve(MatchRules.RULESET_COMPETITIVE_3V3)
		and MatchRules.resolve(MatchRules.RULESET_COMPETITIVE_3V3) == MatchRules.resolve(MatchRules.RULESET_COMPETITIVE_3V3)
	)
	if not ok:
		failures.append("repeated canonical rule resolution is not deterministic")
	return ok

func _check_legacy_parity(failures: Array[String]) -> bool:
	var canonical: Dictionary = MatchRules.competitive_3v3()
	var duel: Dictionary = MatchRules.for_legacy_mode("1v1")
	var clash: Dictionary = MatchRules.for_legacy_mode("3v3")
	var play_vs_ai: Dictionary = MatchRules.for_legacy_mode("Play vs AI")
	var ok: bool = (
		duel.get("ruleset_id") == MatchRules.RULESET_COMPETITIVE_3V3
		and clash.get("ruleset_id") == MatchRules.RULESET_COMPETITIVE_3V3
		and play_vs_ai.get("ruleset_id") == MatchRules.RULESET_COMPETITIVE_3V3
		and duel.get("rules") == canonical
		and clash.get("rules") == canonical
		and play_vs_ai.get("rules") == canonical
		and duel.get("control_topology_id") == MatchRules.TOPOLOGY_SOLO_SWAP
		and play_vs_ai.get("control_topology_id") == MatchRules.TOPOLOGY_SOLO_SWAP
		and clash.get("control_topology_id") == MatchRules.TOPOLOGY_LEGACY_SINGLE_LEAD
		and duel.get("control_topology_id") != MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM
		and clash.get("control_topology_id") != MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM
		and play_vs_ai.get("control_topology_id") != MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM
	)
	if not ok:
		failures.append("legacy modes do not share canonical rules with topology-only differences")
	return ok

func _check_topologies(failures: Array[String]) -> bool:
	var solo: Dictionary = MatchRules.topology(MatchRules.TOPOLOGY_SOLO_SWAP)
	var bots: Dictionary = MatchRules.topology(MatchRules.TOPOLOGY_ALL_BOTS)
	var legacy: Dictionary = MatchRules.topology(MatchRules.TOPOLOGY_LEGACY_SINGLE_LEAD)
	var network: Dictionary = MatchRules.topology(MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM)
	var ok: bool = (
		MatchRules.TOPOLOGY_SOLO_SWAP == "solo_swap"
		and MatchRules.TOPOLOGY_ALL_BOTS == "all_bots"
		and MatchRules.TOPOLOGY_LEGACY_SINGLE_LEAD == "legacy_single_lead"
		and MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM == "future_network_team"
		and solo.get("id") == MatchRules.TOPOLOGY_SOLO_SWAP
		and solo.get("active_human_slots") == 1
		and solo.get("ai_controlled_slots") == 5
		and bots.get("id") == MatchRules.TOPOLOGY_ALL_BOTS
		and bots.get("active_human_slots") == 0
		and bots.get("ai_controlled_slots") == 6
		and legacy.get("id") == MatchRules.TOPOLOGY_LEGACY_SINGLE_LEAD
		and legacy.get("active_human_slots") == 1
		and legacy.get("swappable_team_slots") == 0
		and legacy.get("ai_controlled_slots") == 5
		and network.get("id") == MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM
		and network.get("active_human_slots") == 6
		and network.get("ai_controlled_slots") == 0
		and solo == MatchRules.topology(MatchRules.TOPOLOGY_SOLO_SWAP)
		and bots == MatchRules.topology(MatchRules.TOPOLOGY_ALL_BOTS)
		and legacy == MatchRules.topology(MatchRules.TOPOLOGY_LEGACY_SINGLE_LEAD)
		and network == MatchRules.topology(MatchRules.TOPOLOGY_FUTURE_NETWORK_TEAM)
	)
	if not ok:
		failures.append("controller topology contracts are missing, overlapping, or non-deterministic")
	return ok

func _check_validation(failures: Array[String]) -> bool:
	var canonical: Dictionary = MatchRules.competitive_3v3()
	var corrupted: Dictionary = canonical.duplicate(true)
	corrupted["team_size"] = 2
	corrupted.erase("visibility_enabled")
	var canonical_errors: Array[String] = MatchRules.validate_rules(canonical)
	var corrupted_errors: Array[String] = MatchRules.validate_rules(corrupted)
	var ok: bool = canonical_errors.is_empty() and corrupted_errors.size() >= 2
	if not ok:
		failures.append("validate_rules did not accept canonical rules and reject a corrupted snapshot")
	return ok

func _check_unknown_ids(failures: Array[String]) -> bool:
	var ok: bool = (
		MatchRules.resolve("unknown_ruleset").is_empty()
		and MatchRules.topology("unknown_topology").is_empty()
		and MatchRules.for_legacy_mode("unknown mode").is_empty()
	)
	if not ok:
		failures.append("unknown ruleset, topology, or legacy mode was not rejected")
	return ok
