extends Node

const DEFAULT_SQUAD_IDS := ["snapping_turtle", "chorus_frog", "mink"]
const PLAYABLE_SQUAD_POOL := ["snapping_turtle", "chorus_frog", "mink", "beaver", "otter", "leech", "owl", "duck", "bullfrog", "cane_toad", "crayfish", "bog_turtle", "water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake", "alligator", "wolf_spider", "firefly", "mosquito_swarm"]

var selected_mode := "1v1"
var selected_creature_id := "snapping_turtle"
var selected_squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
var selected_red_squad_ids: Array[String] = []
var blue_draft_bans: Array[String] = []
var red_draft_bans: Array[String] = []
var wake_boss := false
var center_boss := false
var simulation_seed := -1
var simulation_config_errors: Array[String] = []
var _visual_fixture_blue_squad_ids: Array[String] = []
var _visual_fixture_red_squad_ids: Array[String] = []

func _ready() -> void:
	var perf_requested := false
	var requested_blue_squad: Array = []
	var requested_red_squad: Array = []
	var requested_seed_text := ""
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--mode="):
			selected_mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--creature="):
			set_selected_creature(argument.trim_prefix("--creature="))
		elif argument == "--bb-perf" or argument.begins_with("--bb-perf-frames="):
			perf_requested = true
		elif argument == "--bb-wake-boss":
			wake_boss = true
		elif argument == "--bb-center-boss":
			center_boss = true
		elif argument.begins_with("--bb-sim-seed="):
			requested_seed_text = argument.trim_prefix("--bb-sim-seed=")
		elif argument.begins_with("--bb-blue-squad="):
			requested_blue_squad = argument.trim_prefix("--bb-blue-squad=").split(",")
		elif argument.begins_with("--bb-red-squad="):
			requested_red_squad = argument.trim_prefix("--bb-red-squad=").split(",")
	if selected_mode.strip_edges().to_lower() in ["all bots", "all_bots"]:
		if not requested_seed_text.is_valid_int():
			simulation_config_errors.append("simulation seed must be a nonnegative integer")
		else:
			set_simulation_request(requested_blue_squad, requested_red_squad, int(requested_seed_text))
	if perf_requested:
		add_child(preload("res://scripts/game/perf_harness.gd").new())

func set_simulation_request(blue_ids: Array, red_ids: Array, seed_value: int) -> bool:
	simulation_config_errors = _simulation_request_errors(blue_ids, red_ids, seed_value)
	if not simulation_config_errors.is_empty():
		return false
	selected_squad_ids.assign(blue_ids)
	selected_creature_id = selected_squad_ids[0]
	selected_red_squad_ids.assign(red_ids)
	simulation_seed = seed_value
	return true

func get_simulation_request_errors() -> Array[String]:
	var errors := _simulation_request_errors(selected_squad_ids, selected_red_squad_ids, simulation_seed)
	for error in simulation_config_errors:
		if not errors.has(error):
			errors.append(error)
	return errors

func clear_simulation_request() -> void:
	simulation_seed = -1
	simulation_config_errors.clear()
	selected_red_squad_ids.clear()

func _simulation_request_errors(blue_ids: Array, red_ids: Array, seed_value: int) -> Array[String]:
	var errors: Array[String] = []
	_validate_exact_simulation_roster("blue", blue_ids, errors)
	_validate_exact_simulation_roster("red", red_ids, errors)
	if seed_value < 0:
		errors.append("simulation seed must be a nonnegative integer")
	return errors

func _validate_exact_simulation_roster(side: String, creature_ids: Array, errors: Array[String]) -> void:
	if creature_ids.size() != 3:
		errors.append("%s simulation roster must contain exactly three creatures" % side)
		return
	var seen: Dictionary = {}
	for creature_value in creature_ids:
		var creature_id := String(creature_value).strip_edges()
		if not PLAYABLE_SQUAD_POOL.has(creature_id):
			errors.append("%s simulation roster has unknown creature: %s" % [side, creature_id])
		elif seen.has(creature_id):
			errors.append("%s simulation roster has duplicate creature: %s" % [side, creature_id])
		seen[creature_id] = true

func set_selected_creature(creature_id: String) -> void:
	var playable_id := _playable_or_default(creature_id)
	selected_creature_id = playable_id
	selected_squad_ids = _build_squad_around(playable_id)

func get_selected_squad_ids() -> Array[String]:
	if _visual_fixture_blue_squad_ids.size() == 3:
		return _visual_fixture_blue_squad_ids.duplicate()
	return _normalize_squad_ids(selected_squad_ids)

func set_selected_squad_ids(creature_ids: Array) -> void:
	selected_squad_ids = _normalize_squad_ids(creature_ids)
	if not selected_squad_ids.is_empty():
		selected_creature_id = selected_squad_ids[0]

func get_selected_red_squad_ids() -> Array[String]:
	if _visual_fixture_red_squad_ids.size() == 3:
		return _visual_fixture_red_squad_ids.duplicate()
	return selected_red_squad_ids.duplicate()

func set_visual_fixture_rosters(blue_ids: Array, red_ids: Array) -> bool:
	if not _is_valid_visual_fixture_roster(blue_ids) \
			or not _is_valid_visual_fixture_roster(red_ids):
		return false
	_visual_fixture_blue_squad_ids.assign(blue_ids)
	_visual_fixture_red_squad_ids.assign(red_ids)
	return true

func clear_visual_fixture_rosters() -> void:
	_visual_fixture_blue_squad_ids.clear()
	_visual_fixture_red_squad_ids.clear()

func _is_valid_visual_fixture_roster(creature_ids: Array) -> bool:
	if creature_ids.size() != 3:
		return false
	for creature_value in creature_ids:
		var creature_id := String(creature_value).strip_edges()
		if not PLAYABLE_SQUAD_POOL.has(creature_id):
			return false
	return true

func set_selected_red_squad_ids(creature_ids: Array) -> void:
	var normalized := _normalize_explicit_squad_ids(creature_ids)
	selected_red_squad_ids.assign(normalized)

func clear_selected_red_squad_ids() -> void:
	selected_red_squad_ids.clear()

func clear_draft_bans() -> void:
	blue_draft_bans.clear()
	red_draft_bans.clear()

func set_draft_bans(blue_bans: Array, red_bans: Array) -> void:
	blue_draft_bans = _normalize_ban_ids(blue_bans, 1)
	red_draft_bans = _normalize_ban_ids(red_bans, 1)
	if is_creature_banned(selected_creature_id):
		set_selected_creature(_playable_or_default(""))
	else:
		selected_squad_ids = _normalize_squad_ids(selected_squad_ids)

func is_ranked_draft_stub_enabled() -> bool:
	return selected_mode == "1v1"

func is_creature_banned(creature_id: String) -> bool:
	var normalized_id := String(creature_id)
	return blue_draft_bans.has(normalized_id) or red_draft_bans.has(normalized_id)

func get_draft_stub_state() -> Dictionary:
	return {
		"enabled": is_ranked_draft_stub_enabled(),
		"phase": "pick",
		"ban_slots_per_team": 1,
		"pick_slots_per_team": 3 if selected_mode == "1v1" else 1,
		"enforced": true,
		"blue_bans": blue_draft_bans.duplicate(),
		"red_bans": red_draft_bans.duplicate()
	}

func _build_squad_around(creature_id: String) -> Array[String]:
	var output: Array[String] = []
	if not creature_id.is_empty() and not is_creature_banned(creature_id):
		output.append(creature_id)
	for candidate in PLAYABLE_SQUAD_POOL:
		if output.size() >= 3:
			break
		if not output.has(candidate) and not is_creature_banned(candidate):
			output.append(candidate)
	return _normalize_squad_ids(output)

func _normalize_squad_ids(creature_ids: Array) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() or output.has(normalized_id) or not PLAYABLE_SQUAD_POOL.has(normalized_id) or is_creature_banned(normalized_id):
			continue
		output.append(normalized_id)
	for fallback in DEFAULT_SQUAD_IDS:
		if output.size() >= 3:
			break
		if not output.has(fallback) and not is_creature_banned(fallback):
			output.append(fallback)
	for fallback in PLAYABLE_SQUAD_POOL:
		if output.size() >= 3:
			break
		if not output.has(fallback) and not is_creature_banned(fallback):
			output.append(fallback)
	var normalized: Array[String] = []
	for i in mini(output.size(), 3):
		normalized.append(output[i])
	return normalized

func _playable_or_default(creature_id: String) -> String:
	if PLAYABLE_SQUAD_POOL.has(creature_id) and not is_creature_banned(creature_id):
		return creature_id
	for fallback in DEFAULT_SQUAD_IDS:
		if not is_creature_banned(fallback):
			return fallback
	for fallback in PLAYABLE_SQUAD_POOL:
		if not is_creature_banned(fallback):
			return fallback
	return DEFAULT_SQUAD_IDS[0]

func _normalize_ban_ids(creature_ids: Array, limit: int) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		if output.size() >= limit:
			break
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() or output.has(normalized_id) or not PLAYABLE_SQUAD_POOL.has(normalized_id):
			continue
		output.append(normalized_id)
	return output

func _normalize_explicit_squad_ids(creature_ids: Array) -> Array[String]:
	var output: Array[String] = []
	for creature_id in creature_ids:
		var normalized_id := String(creature_id)
		if normalized_id.is_empty() \
			or output.has(normalized_id) \
			or not PLAYABLE_SQUAD_POOL.has(normalized_id) \
			or is_creature_banned(normalized_id):
			continue
		output.append(normalized_id)
		if output.size() >= 3:
			break
	return output if output.size() == 3 else []
