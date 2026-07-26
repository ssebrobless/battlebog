extends SceneTree

const MatchRulesScript := preload("res://scripts/game/match_rules.gd")
const BLUE_SQUAD := ["snapping_turtle", "chorus_frog", "mink"]
const RED_SQUAD := ["beaver", "duck", "firefly"]


func _initialize() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("simulation request check could not find GameConfig")
		quit(1)
		return
	var original := {
		"selected_creature_id": config.selected_creature_id,
		"selected_squad_ids": config.selected_squad_ids.duplicate(),
		"selected_red_squad_ids": config.selected_red_squad_ids.duplicate(),
		"simulation_seed": config.simulation_seed,
		"simulation_config_errors": config.simulation_config_errors.duplicate()
	}
	if not config.set_simulation_request(BLUE_SQUAD, RED_SQUAD, 71):
		failures.append("valid exact simulation request should be accepted: %s" % str(config.get_simulation_request_errors()))
	if config.selected_squad_ids != BLUE_SQUAD \
		or config.selected_red_squad_ids != RED_SQUAD \
		or config.simulation_seed != 71:
		failures.append("valid request should preserve exact ordered rosters and seed")

	_expect_invalid(config, ["snapping_turtle", "mink"], RED_SQUAD, 71, "exactly three", failures)
	_expect_invalid(config, ["mink", "mink", "duck"], RED_SQUAD, 71, "duplicate", failures)
	_expect_invalid(config, ["missing_creature", "mink", "duck"], RED_SQUAD, 71, "unknown creature", failures)
	_expect_invalid(config, BLUE_SQUAD, RED_SQUAD, -1, "nonnegative integer", failures)

	for alias in ["All Bots", "all_bots"]:
		var adapter := MatchRulesScript.for_legacy_mode(alias)
		var topology: Dictionary = adapter.get("control_topology", {})
		if String(topology.get("id", "")) != MatchRulesScript.TOPOLOGY_ALL_BOTS \
			or int(topology.get("active_human_slots", -1)) != 0 \
			or int(topology.get("ai_controlled_slots", -1)) != 6:
			failures.append("All Bots alias should resolve to zero-human/six-AI topology: %s=%s" % [alias, str(adapter)])

	config.selected_creature_id = String(original.selected_creature_id)
	config.selected_squad_ids.assign(original.selected_squad_ids)
	config.selected_red_squad_ids.assign(original.selected_red_squad_ids)
	config.simulation_seed = int(original.simulation_seed)
	config.simulation_config_errors.assign(original.simulation_config_errors)
	print("simulation_request failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect_invalid(
	config: Node,
	blue: Array,
	red: Array,
	seed_value: int,
	error_fragment: String,
	failures: Array[String]
) -> void:
	if config.set_simulation_request(blue, red, seed_value):
		failures.append("invalid simulation request should fail closed: blue=%s red=%s seed=%d" % [str(blue), str(red), seed_value])
		return
	var errors: Array = config.get_simulation_request_errors()
	var found := false
	for error in errors:
		if String(error).contains(error_fragment):
			found = true
			break
	if not found:
		failures.append("invalid request should explain '%s': errors=%s" % [error_fragment, str(errors)])
