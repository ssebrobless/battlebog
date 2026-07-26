extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BLUE := 0
const RED := 1
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var arena := await _boot_arena_mode("1v1", ["duck", "snapping_turtle", "mink"], failures)
	if arena == null or not arena.has_method("get_match_summary_data"):
		push_error("Arena scene did not expose M8 summary data; current_scene=%s" % str(arena))
		quit(1)
		return

	_check_match_summary_telemetry(arena, failures)
	await _check_summary_mode_tuning("3v3", 105, 20, 3, 2, "legacy_single_lead", "Pace: hunger 105s, wave 20s, 2/2 huts, 3 minions/hut", failures)
	await _check_summary_mode_tuning("Hero Lab", 105, 18, 3, 2, "", "Pace: hunger 105s, wave 18s, 2/2 huts, 3 minions/hut", failures)

	print("m8_summary failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boot_arena_mode(mode: String, squad_ids: Array, failures: Array[String]) -> Node:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = mode
		config.clear_draft_bans()
		config.set_selected_squad_ids(squad_ids)

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("m8 summary check failed to boot Arena mode %s: %d" % [mode, error])
		return null
	await process_frame
	await process_frame
	return current_scene

func _check_summary_mode_tuning(mode: String, expected_hunger: int, expected_wave: int, expected_minions: int, expected_huts_per_side: int, expected_control_topology: String, expected_line: String, failures: Array[String]) -> void:
	var arena := await _boot_arena_mode(mode, ["snapping_turtle", "chorus_frog", "mink"], failures)
	if arena == null or not arena.has_method("get_match_summary_data"):
		failures.append("summary mode tuning check could not boot %s; arena=%s" % [mode, str(arena)])
		return
	var summary: Dictionary = arena.get_match_summary_data("Blue", "mode_tuning_check")
	var tuning: Dictionary = summary.get("mode_tuning", {})
	var huts: Dictionary = tuning.get("huts_per_side", {})
	var text: String = arena._get_match_summary("Blue")
	var expects_competitive := not expected_control_topology.is_empty()
	var ok := String(summary.get("mode", "")) == mode \
		and (String(summary.get("ruleset_id", "")) == "competitive_3v3") == expects_competitive \
		and (int(summary.get("rules_schema_version", 0)) == 1) == expects_competitive \
		and (not String(summary.get("rules_fingerprint", "")).is_empty()) == expects_competitive \
		and String(summary.get("control_topology_id", "")) == expected_control_topology \
		and int(tuning.get("hunger_full_to_empty_sec", 0)) == expected_hunger \
		and int(tuning.get("wave_interval_sec", 0)) == expected_wave \
		and int(tuning.get("lane_minions_per_hut", 0)) == expected_minions \
		and int(huts.get("blue", 0)) == expected_huts_per_side \
		and int(huts.get("red", 0)) == expected_huts_per_side \
		and text.contains("Mode: %s" % mode) \
		and text.contains("Draft: off") \
		and text.contains(expected_line)
	if not ok:
		failures.append("summary mode tuning for %s should report shared-map pressure tuning; summary=%s text=%s" % [
			mode,
			str(summary),
			text
		])

func _check_match_summary_telemetry(arena: Node, failures: Array[String]) -> void:
	arena.elapsed = 125.0
	var blue_actor: Node = arena.player
	var blue_second: Node = arena.player_squad[1]
	var red_actor: Node = arena.bots[0]
	var red_hut: Node = _first_hut(arena, RED)
	if blue_actor == null or blue_second == null or red_actor == null or red_hut == null:
		failures.append("summary check expected blue squad, red bot, and red hut to exist.")
		return

	arena.record_core_damage(BLUE, 123.0, blue_actor)
	red_hut.take_damage(red_hut.health, BLUE, blue_actor)
	arena._consume_stock_for_death(blue_actor)

	arena.habitat_deposit_feedback_timer = 0.0
	_satiate_in_habitat(blue_actor, arena)
	var deposited: bool = arena._try_manual_habitat_deposit(blue_actor)
	arena._tick_breeding(StockManagerScript.BREEDING_DURATION_SEC + 0.1)

	arena.habitat_deposit_feedback_timer = 0.0
	_satiate_in_habitat(blue_second, arena)
	var deny_deposit: bool = arena._try_manual_habitat_deposit(blue_second)
	var denied := false
	if deny_deposit and not arena.breeding_actors.is_empty():
		arena.on_breeding_actor_defeated(arena.breeding_actors[0], red_actor)
		denied = true

	var summary: Dictionary = arena.get_match_summary_data("Blue")
	var teams: Dictionary = summary.get("teams", {})
	var blue: Dictionary = teams.get("blue", {})
	var red: Dictionary = teams.get("red", {})
	var deltas: Dictionary = summary.get("balance_deltas", {})
	var flags: Array = summary.get("balance_flags", [])
	var review_priority := int(summary.get("balance_review_priority", -1))
	var review_focus: Array = summary.get("balance_review_focus", [])
	var review_summary := String(summary.get("balance_review_summary", ""))
	var mode_tuning: Dictionary = summary.get("mode_tuning", {})
	var mode_huts: Dictionary = mode_tuning.get("huts_per_side", {})
	var draft: Dictionary = summary.get("draft", {})
	var selected_squad: Array = summary.get("selected_squad_ids", [])
	var text: String = arena._get_match_summary("Blue")
	var scoreboard_text: String = arena._get_scoreboard_text()
	var player_rows: Array = summary.get("players", [])
	var top_players: Dictionary = summary.get("top_players", {})
	var top_blue: Dictionary = top_players.get("blue", {})
	var top_red: Dictionary = top_players.get("red", {})

	var data_ok := String(summary.get("schema", "")) == "battle_bog_match_summary_v1" \
		and String(summary.get("winner", "")) == "Blue" \
		and String(summary.get("time", "")) == "02:05" \
		and String(summary.get("ruleset_id", "")) == "competitive_3v3" \
		and int(summary.get("rules_schema_version", 0)) == 1 \
		and not String(summary.get("rules_fingerprint", "")).is_empty() \
		and String(summary.get("control_topology_id", "")) == "solo_swap" \
		and int(blue.get("stock_losses", 0)) == 1 \
		and int(blue.get("deposits", 0)) == 2 \
		and int(blue.get("breeds_completed", 0)) == 1 \
		and int(red.get("breeds_denied", 0)) == 1 \
		and int(blue.get("huts_destroyed", 0)) == 1 \
		and float(blue.get("hut_damage", 0.0)) >= 799.0 \
		and int(blue.get("core_damage", 0)) == 123 \
		and int(blue.get("max_stocks", 0)) == 9 \
		and int(blue.get("stocks_remaining", 0)) == 8 \
		and String(summary.get("selected_creature_id", "")) == "duck" \
		and int(mode_tuning.get("hunger_full_to_empty_sec", 0)) == 105 \
		and int(mode_tuning.get("wave_interval_sec", 0)) == 20 \
		and int(mode_tuning.get("lane_minions_per_hut", 0)) == 3 \
		and int(mode_huts.get("blue", 0)) == 2 \
		and int(mode_huts.get("red", 0)) == 2 \
		and selected_squad.size() == 3 \
		and selected_squad.has("duck") \
		and bool(draft.get("enabled", false)) \
		and int(draft.get("ban_slots_per_team", 0)) == 1 \
		and int(deltas.get("stock_remaining_delta", 99)) == -1 \
		and int(deltas.get("stock_loss_delta", 99)) == 1 \
		and int(deltas.get("deposit_delta", 0)) == 2 \
		and int(deltas.get("breed_complete_delta", 0)) == 1 \
		and int(deltas.get("breed_deny_delta", 0)) == -1 \
		and int(deltas.get("hut_damage_delta", 0)) == 800 \
		and int(deltas.get("core_damage_delta", 0)) == 123 \
		and int(deltas.get("buff_stack_delta", 0)) == 1 \
		and flags.has("blue_objective_pressure") \
		and flags.has("blue_breeding_tempo") \
		and flags.has("red_raid_pressure") \
		and not flags.has("balanced_flow") \
		and review_priority == 5 \
		and _focus_has(review_focus, "hut_damage_delta", "Blue", 800) \
		and _focus_has(review_focus, "deposit_delta", "Blue", 2) \
		and _focus_has(review_focus, "breed_deny_delta", "Red", 1) \
		and review_summary.contains("P5:") \
		and review_summary.contains("Blue hut damage +800") \
		and review_summary.contains("Red denials +1") \
		and String(top_blue.get("name", "")).contains("Duck") \
		and int(top_blue.get("hut_damage", 0)) >= 799 \
		and float(top_blue.get("summary_score", 0.0)) > 140.0 \
		and _score_breakdown_has(top_blue, "hut_damage", 79.0) \
		and _score_breakdown_has(top_blue, "deposits", 50.0) \
		and String(top_red.get("name", "")).contains("Red") \
		and int(top_red.get("breeds_denied", 0)) == 1 \
		and float(top_red.get("summary_score", 0.0)) >= 80.0 \
		and _score_breakdown_has(top_red, "breeds_denied", 80.0)
	var text_ok: bool = text.contains("Stocks lost 1/9") \
		and text.contains("Deposits 2") \
		and text.contains("Breeds 1/0 denied") \
		and text.contains("Breeds 0/1 denied") \
		and text.contains("HutDmg") \
		and text.contains("CoreDmg 123") \
		and text.contains("Buffs") \
		and text.contains("Mode: 1v1") \
		and text.contains("Squad: Duck / Snapping Turtle / Mink") \
		and text.contains("Draft: pick 3, ban 1/team") \
		and text.contains("Pace: hunger 105s, wave 20s, 2/2 huts, 3 minions/hut") \
		and text.contains("Review flags:") \
		and text.contains("Blue objective pressure") \
		and text.contains("Blue breeding tempo") \
		and text.contains("Red raid pressure") \
		and text.contains("Priority 5/5") \
		and text.contains("Review focus:") \
		and text.contains("Blue hut damage +800") \
		and text.contains("Blue deposits +2") \
		and text.contains("Red denials +1") \
		and text.contains("Top Blue:") \
		and text.contains("Top Red:") \
		and text.contains("Dep 1") \
		and text.contains("deny")
	var player_rows_ok := _row_has_stat(player_rows, "Duck", "deposits", 1) \
		and _row_has_stat(player_rows, "Duck", "stock_losses", 1) \
		and _row_has_stat(player_rows, "Duck", "hut_damage", 799.0) \
		and _row_has_stat(player_rows, "Red", "breeds_denied", 1) \
		and _row_has_score_component(player_rows, "Duck", "hut_damage", 79.0) \
		and _row_has_score_component(player_rows, "Red", "breeds_denied", 80.0) \
		and _row_has_ranks(player_rows, "Duck", 1, 1) \
		and _row_has_ranks(player_rows, "Red", 2, 1)
	var scoreboard_ok := scoreboard_text.contains("Flow") \
		and scoreboard_text.contains("Stocks 8/9") \
		and scoreboard_text.contains("Lost1") \
		and scoreboard_text.contains("Dep2") \
		and scoreboard_text.contains("Hut800") \
		and scoreboard_text.contains("Dep1") \
		and scoreboard_text.contains("Review P5:") \
		and scoreboard_text.contains("Blue hut damage +800") \
		and scoreboard_text.contains("Red denials +1")
	arena._finish_match("Blue", "test_summary", "Blue wins test")
	var log_path: String = arena.get_last_match_summary_log_path()
	var log_state: Dictionary = _read_summary_log(log_path)
	var log_data: Dictionary = log_state.get("data", {})
	var log_teams: Dictionary = log_data.get("teams", {})
	var log_blue: Dictionary = log_teams.get("blue", {})
	var log_red: Dictionary = log_teams.get("red", {})
	var log_deltas: Dictionary = log_data.get("balance_deltas", {})
	var log_flags: Array = log_data.get("balance_flags", [])
	var log_review_priority := int(log_data.get("balance_review_priority", -1))
	var log_review_focus: Array = log_data.get("balance_review_focus", [])
	var log_review_summary := String(log_data.get("balance_review_summary", ""))
	var log_mode_tuning: Dictionary = log_data.get("mode_tuning", {})
	var log_mode_huts: Dictionary = log_mode_tuning.get("huts_per_side", {})
	var log_draft: Dictionary = log_data.get("draft", {})
	var log_squad: Array = log_data.get("selected_squad_ids", [])
	var log_top_players: Dictionary = log_data.get("top_players", {})
	var log_top_blue: Dictionary = log_top_players.get("blue", {})
	var log_top_red: Dictionary = log_top_players.get("red", {})
	var log_player_rows: Array = log_data.get("players", [])
	var log_ok := bool(log_state.get("ok", false)) \
		and bool(arena.match_over) \
		and String(log_data.get("schema", "")) == "battle_bog_match_summary_v1" \
		and String(log_data.get("winner", "")) == "Blue" \
		and String(log_data.get("reason", "")) == "test_summary" \
		and log_path.contains("_p5_test_summary.json") \
		and String(log_data.get("selected_creature_id", "")) == "duck" \
		and String(log_data.get("ruleset_id", "")) == "competitive_3v3" \
		and int(log_data.get("rules_schema_version", 0)) == 1 \
		and not String(log_data.get("rules_fingerprint", "")).is_empty() \
		and String(log_data.get("control_topology_id", "")) == "solo_swap" \
		and int(log_mode_tuning.get("hunger_full_to_empty_sec", 0)) == 105 \
		and int(log_mode_tuning.get("wave_interval_sec", 0)) == 20 \
		and int(log_mode_tuning.get("lane_minions_per_hut", 0)) == 3 \
		and int(log_mode_huts.get("blue", 0)) == 2 \
		and int(log_mode_huts.get("red", 0)) == 2 \
		and log_squad.has("snapping_turtle") \
		and bool(log_draft.get("enabled", false)) \
		and int(log_draft.get("pick_slots_per_team", 0)) == 3 \
		and int(log_blue.get("stock_losses", 0)) == 1 \
		and int(log_blue.get("deposits", 0)) == 2 \
		and int(log_blue.get("breeds_completed", 0)) == 1 \
		and int(log_red.get("breeds_denied", 0)) == 1 \
		and int(log_blue.get("core_damage", 0)) == 123 \
		and int(log_deltas.get("deposit_delta", 0)) == 2 \
		and int(log_deltas.get("breed_deny_delta", 0)) == -1 \
		and _row_has_score_component(log_player_rows, "Duck", "hut_damage", 79.0) \
		and _row_has_score_component(log_player_rows, "Red", "breeds_denied", 80.0) \
		and _row_has_ranks(log_player_rows, "Duck", 1, 1) \
		and _row_has_ranks(log_player_rows, "Red", 2, 1) \
		and log_flags.has("blue_objective_pressure") \
		and log_flags.has("blue_breeding_tempo") \
		and log_flags.has("red_raid_pressure") \
		and not log_flags.has("balanced_flow") \
		and log_review_priority == 5 \
		and _focus_has(log_review_focus, "hut_damage_delta", "Blue", 800) \
		and _focus_has(log_review_focus, "deposit_delta", "Blue", 2) \
		and _focus_has(log_review_focus, "breed_deny_delta", "Red", 1) \
		and log_review_summary.contains("P5:") \
		and log_review_summary.contains("Blue hut damage +800") \
		and log_review_summary.contains("Red denials +1") \
		and String(log_top_blue.get("name", "")).contains("Duck") \
		and int(log_top_blue.get("hut_damage", 0)) >= 799 \
		and float(log_top_blue.get("summary_score", 0.0)) > 140.0 \
		and _score_breakdown_has(log_top_blue, "hut_damage", 79.0) \
		and _score_breakdown_has(log_top_blue, "deposits", 50.0) \
		and String(log_top_red.get("name", "")).contains("Red") \
		and int(log_top_red.get("breeds_denied", 0)) == 1 \
		and float(log_top_red.get("summary_score", 0.0)) >= 80.0 \
		and _score_breakdown_has(log_top_red, "breeds_denied", 80.0)

	if not deposited or not denied or not data_ok or not text_ok or not player_rows_ok or not scoreboard_ok or not log_ok:
		failures.append("M8 summary should report stocks, deposits, breeding, hut damage, core damage, player rows, live scoreboard flow, and a JSON match log; deposited=%s denied=%s data_ok=%s text_ok=%s player_rows_ok=%s scoreboard_ok=%s log_ok=%s summary=%s text=%s scoreboard=%s rows=%s log=%s" % [
			str(deposited),
			str(denied),
			str(data_ok),
			str(text_ok),
			str(player_rows_ok),
			str(scoreboard_ok),
			str(log_ok),
			str(summary),
			text,
			scoreboard_text,
			str(player_rows),
			str(log_state)
		])

func _first_hut(arena: Node, team: int) -> Node:
	for hut in arena.huts:
		if hut != null and is_instance_valid(hut) and int(hut.team) == team:
			return hut
	return null

func _satiate_in_habitat(actor: Node, arena: Node) -> void:
	var habitat: Rect2 = arena.terrain_map.get_team_habitat_rect(actor.team)
	actor.global_position = habitat.get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true

func _row_has_stat(rows: Array, name_part: String, stat: String, minimum: Variant) -> bool:
	for row: Dictionary in rows:
		if not String(row.get("name", "")).contains(name_part):
			continue
		if typeof(minimum) == TYPE_FLOAT:
			return float(row.get(stat, 0.0)) >= float(minimum)
		return int(row.get(stat, 0)) >= int(minimum)
	return false

func _focus_has(focus: Array, key: String, side: String, value: int) -> bool:
	for entry: Dictionary in focus:
		if String(entry.get("key", "")) == key \
			and String(entry.get("side", "")) == side \
			and int(entry.get("value", -1)) == value:
			return true
	return false

func _score_breakdown_has(row: Dictionary, key: String, minimum_score: float) -> bool:
	var breakdown: Array = row.get("summary_score_breakdown", [])
	for entry: Dictionary in breakdown:
		if String(entry.get("key", "")) == key and float(entry.get("score", 0.0)) >= minimum_score:
			return true
	return false

func _row_has_score_component(rows: Array, name_part: String, key: String, minimum_score: float) -> bool:
	for row: Dictionary in rows:
		if not String(row.get("name", "")).contains(name_part):
			continue
		if float(row.get("summary_score", 0.0)) <= 0.0:
			return false
		return _score_breakdown_has(row, key, minimum_score)
	return false

func _row_has_ranks(rows: Array, name_part: String, summary_rank: int, team_rank: int) -> bool:
	for row: Dictionary in rows:
		if not String(row.get("name", "")).contains(name_part):
			continue
		return int(row.get("summary_rank", -1)) == summary_rank \
			and int(row.get("team_summary_rank", -1)) == team_rank
	return false

func _read_summary_log(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"ok": false, "path": path, "reason": "missing_file"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "path": path, "reason": "open_failed", "error": FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "parse_failed", "text": text}
	return {"ok": true, "path": path, "data": parsed}
