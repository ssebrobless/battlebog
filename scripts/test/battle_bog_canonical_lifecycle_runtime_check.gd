extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const BLUE := 0
const RED := 1
const TEAM_SIZE := 3
const STOCKS_PER_SLOT := 3
const TEST_SQUAD: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
const MATCH_LOG_DIR := "user://battle_bog_match_logs"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("canonical lifecycle runtime check could not find GameConfig")
		quit(1)
		return

	var original_config := _capture_config(config)
	var existing_logs := _match_log_files()
	config.selected_mode = "3v3"
	config.set_selected_squad_ids(TEST_SQUAD)
	config.selected_creature_id = TEST_SQUAD[0]
	config.wake_boss = false
	config.center_boss = false

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		_restore_config(config, original_config)
		push_error("canonical lifecycle runtime check failed to boot Arena: error=%d" % error)
		quit(1)
		return
	await process_frame
	await physics_frame
	await physics_frame

	var arena := current_scene
	if arena == null or not arena.has_method("get_match_slot_state"):
		_restore_config(config, original_config)
		push_error("canonical lifecycle runtime check could not inspect Arena")
		quit(1)
		return

	var topology_ok := _check_topology_and_stocks(arena, failures)
	var core_ok := _check_core_immunity(arena, failures)
	var lifecycle_ok := _check_stock_lifecycle(arena, failures)
	var economy_ok := _check_deposit_and_breeding(arena, failures)
	var elimination_ok := _check_stock_elimination(arena, failures)

	_restore_config(config, original_config)
	_remove_new_match_logs(existing_logs)

	print("canonical_lifecycle topology=%s core=%s stock=%s economy=%s elimination=%s" % [
		str(topology_ok),
		str(core_ok),
		str(lifecycle_ok),
		str(economy_ok),
		str(elimination_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if topology_ok and core_ok and lifecycle_ok and economy_ok and elimination_ok else 1)


func _check_topology_and_stocks(arena: Node, failures: Array[String]) -> bool:
	var state: Dictionary = arena.get_match_slot_state()
	var blue: Array = state.get("blue", [])
	var red: Array = state.get("red", [])
	var all_slots: Array = blue + red
	var all_registered := (
		bool(state.get("sealed", false))
		and bool(state.get("stock_sealed", false))
		and blue.size() == TEAM_SIZE
		and red.size() == TEAM_SIZE
	)
	for slot: Dictionary in all_slots:
		var actor: Node = slot.get("actor", null)
		all_registered = all_registered and actor != null and arena.uses_stock_respawn(actor)

	var blue_totals := _stock_totals(arena.stock_manager.get_team_slots(BLUE))
	var red_totals := _stock_totals(arena.stock_manager.get_team_slots(RED))
	var totals_ok := (
		blue_totals == Vector2i(TEAM_SIZE * STOCKS_PER_SLOT, TEAM_SIZE * STOCKS_PER_SLOT)
		and red_totals == Vector2i(TEAM_SIZE * STOCKS_PER_SLOT, TEAM_SIZE * STOCKS_PER_SLOT)
	)
	var ok := all_registered and totals_ok
	if not ok:
		failures.append(
			"legacy 3v3 expected six sealed stock actors and 9/9 stocks per team; "
			+ "state=%s blue=%s red=%s"
			% [str(state), str(blue_totals), str(red_totals)]
		)
	return ok


func _check_core_immunity(arena: Node, failures: Array[String]) -> bool:
	var red_core: Node = arena.cores.get(RED)
	if red_core == null:
		failures.append("legacy 3v3 did not spawn a Red core")
		return false

	arena.huts_lost[RED] = 2
	var protected_after_huts: bool = not arena.can_damage_core(RED)
	red_core.take_damage(float(red_core.max_health), BLUE)
	var signal_ignored: bool = not arena.match_over
	arena._on_core_destroyed(red_core)
	var direct_callback_ignored: bool = not arena.match_over
	var ok: bool = protected_after_huts and signal_ignored and direct_callback_ignored
	if not ok:
		failures.append(
			"canonical core should stay non-targetable after hut losses and ignore destroyed "
			+ "signal/direct callback; protected=%s signal=%s direct=%s match_over=%s"
			% [
				str(protected_after_huts),
				str(signal_ignored),
				str(direct_callback_ignored),
				str(arena.match_over)
			]
		)
	return ok


func _check_stock_lifecycle(arena: Node, failures: Array[String]) -> bool:
	var actor: Node = _slot_actor(arena, BLUE, 0)
	if actor == null:
		failures.append("could not find Blue0 for canonical stock lifecycle")
		return false

	actor.health = 0.0
	var before_stock: int = arena.stock_manager.stocks_remaining(actor)
	var before_losses := int(arena.team_stats[BLUE].get("stock_losses", 0))
	arena._consume_stock_for_death(actor)
	var first_slot: Dictionary = arena.stock_manager.get_slot_for_actor(actor)
	var first_stock: int = arena.stock_manager.stocks_remaining(actor)
	var first_losses := int(arena.team_stats[BLUE].get("stock_losses", 0))
	arena._consume_stock_for_death(actor)
	var duplicate_slot: Dictionary = arena.stock_manager.get_slot_for_actor(actor)
	var duplicate_stock: int = arena.stock_manager.stocks_remaining(actor)
	var duplicate_losses := int(arena.team_stats[BLUE].get("stock_losses", 0))

	var timer_before := float(duplicate_slot.get("respawn_timer", -1.0))
	var addressable_while_dead: bool = arena.stock_manager.has_actor(actor) \
		and arena.uses_stock_respawn(actor)
	arena.tick_stock_respawn(actor, 0.25)
	var ticked_slot: Dictionary = arena.stock_manager.get_slot_for_actor(actor)
	var timer_after := float(ticked_slot.get("respawn_timer", -1.0))
	var ticked_while_dead := timer_before >= 0.0 \
		and is_equal_approx(timer_after, maxf(timer_before - 0.25, 0.0))

	var first_ok: bool = (
		first_stock == before_stock - 1
		and first_losses == before_losses + 1
		and String(first_slot.get("state", "")) == "respawning"
	)
	var duplicate_ok: bool = duplicate_stock == first_stock and duplicate_losses == first_losses
	var ok: bool = first_ok and duplicate_ok and addressable_while_dead and ticked_while_dead
	if not ok:
		failures.append(
			"stock lifecycle expected one consumption/telemetry increment, duplicate immunity, "
			+ "and dead-actor ticking; stocks=%d->%d->%d losses=%d->%d->%d "
			+ "addressable=%s timer=%.3f->%.3f first=%s duplicate=%s"
			% [
				before_stock,
				first_stock,
				duplicate_stock,
				before_losses,
				first_losses,
				duplicate_losses,
				str(addressable_while_dead),
				timer_before,
				timer_after,
				str(first_slot),
				str(duplicate_slot)
			]
		)
	return ok


func _check_deposit_and_breeding(arena: Node, failures: Array[String]) -> bool:
	var actor: Node = _slot_actor(arena, RED, 0)
	if actor == null:
		failures.append("could not find Red0 for canonical deposit lifecycle")
		return false

	actor.global_position = arena.terrain_map.get_team_habitat_rect(RED).get_center()
	actor.hunger = 100.0
	actor.hunger_satiated = true
	arena.habitat_deposit_feedback_timer = 0.0
	var before_cues: int = arena.stock_manager.get_breeding_cues(RED).size()
	var before_actors: int = arena.breeding_actors.size()
	var before_deposits := int(arena.team_stats[RED].get("deposits", 0))
	var deposited: bool = arena._try_manual_habitat_deposit(actor)
	var cues: Array = arena.stock_manager.get_breeding_cues(RED)
	var cue: Dictionary = cues.back() if not cues.is_empty() else {}
	var breeding_actor: Node = arena._breeding_actor_for_cue(String(cue.get("id", "")))
	var ok: bool = (
		deposited
		and bool(cue.get("accepted", false))
		and cue.get("actor", null) == actor
		and cues.size() == before_cues + 1
		and arena.breeding_actors.size() == before_actors + 1
		and breeding_actor != null
		and int(arena.team_stats[RED].get("deposits", 0)) == before_deposits + 1
		and not bool(actor.hunger_satiated)
	)
	if not ok:
		failures.append(
			"registered 3v3 actor should deposit in its habitat and create an accepted cue/actor; "
			+ "deposited=%s cue=%s cues=%d->%d actors=%d->%d breeding_actor=%s deposits=%d->%d"
			% [
				str(deposited),
				str(cue),
				before_cues,
				cues.size(),
				before_actors,
				arena.breeding_actors.size(),
				str(breeding_actor),
				before_deposits,
				int(arena.team_stats[RED].get("deposits", 0))
			]
		)
	return ok


func _check_stock_elimination(arena: Node, failures: Array[String]) -> bool:
	var actors: Array[Node] = []
	for slot: Dictionary in arena.get_match_slot_state().get("blue", []):
		var actor: Node = slot.get("actor", null)
		if actor != null:
			actors.append(actor)
	if actors.size() != TEAM_SIZE:
		failures.append("could not find all three Blue actors for stock elimination")
		return false

	var premature_finish := false
	for actor: Node in actors:
		while arena.stock_manager.stocks_remaining(actor) > 0:
			arena.stock_manager.mark_respawned(actor)
			arena._consume_stock_for_death(actor)
			if arena.match_over and not arena.stock_manager.team_exhausted(BLUE):
				premature_finish = true

	var path_before_repeat := String(arena.get_last_match_summary_log_path())
	var log_data := _read_json_dictionary(path_before_repeat)
	var losses_before_repeat := int(arena.team_stats[BLUE].get("stock_losses", 0))
	arena._finish_match("Blue", "should_not_replace", "should not replace stock result")
	arena._check_stock_victory(BLUE)
	var path_after_repeat := String(arena.get_last_match_summary_log_path())
	var log_after_repeat := _read_json_dictionary(path_after_repeat)

	var blue_summary: Dictionary = log_data.get("teams", {}).get("blue", {})
	var red_summary: Dictionary = log_data.get("teams", {}).get("red", {})
	var ok: bool = (
		not premature_finish
		and arena.match_over
		and arena.stock_manager.team_exhausted(BLUE)
		and not arena.stock_manager.team_exhausted(RED)
		and losses_before_repeat == TEAM_SIZE * STOCKS_PER_SLOT
		and int(arena.team_stats[BLUE].get("stock_losses", 0)) == losses_before_repeat
		and not path_before_repeat.is_empty()
		and path_after_repeat == path_before_repeat
		and String(log_data.get("reason", "")) == "stock_elimination"
		and String(log_data.get("winner", "")) == "Red"
		and String(log_after_repeat.get("reason", "")) == "stock_elimination"
		and int(blue_summary.get("stocks_remaining", -1)) == 0
		and int(red_summary.get("stocks_remaining", -1)) == TEAM_SIZE * STOCKS_PER_SLOT
	)
	if not ok:
		failures.append(
			"three-by-three stock exhaustion should finish exactly once as Red stock_elimination; "
			+ "premature=%s over=%s blue_exhausted=%s red_exhausted=%s losses=%d "
			+ "path=%s repeat_path=%s log=%s repeat_log=%s"
			% [
				str(premature_finish),
				str(arena.match_over),
				str(arena.stock_manager.team_exhausted(BLUE)),
				str(arena.stock_manager.team_exhausted(RED)),
				losses_before_repeat,
				path_before_repeat,
				path_after_repeat,
				str(log_data),
				str(log_after_repeat)
			]
		)
	return ok


func _slot_actor(arena: Node, team: int, slot_index: int) -> Node:
	var slot: Dictionary = arena.slot_registry.get_slot(team, slot_index)
	return slot.get("actor", null)


func _stock_totals(slots: Array) -> Vector2i:
	var remaining := 0
	var maximum := 0
	for slot: Dictionary in slots:
		remaining += int(slot.get("stocks_remaining", 0))
		maximum += int(slot.get("max_stocks", 0))
	return Vector2i(remaining, maximum)


func _read_json_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _match_log_files() -> Dictionary:
	var files: Dictionary = {}
	var directory := DirAccess.open(MATCH_LOG_DIR)
	if directory == null:
		return files
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir():
			files[filename] = true
		filename = directory.get_next()
	directory.list_dir_end()
	return files


func _remove_new_match_logs(existing: Dictionary) -> void:
	var directory := DirAccess.open(MATCH_LOG_DIR)
	if directory == null:
		return
	directory.list_dir_begin()
	var filename := directory.get_next()
	var created: Array[String] = []
	while not filename.is_empty():
		if not directory.current_is_dir() and not existing.has(filename):
			created.append(filename)
		filename = directory.get_next()
	directory.list_dir_end()
	for created_file in created:
		directory.remove(created_file)


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
	config.selected_creature_id = String(state.get("selected_creature_id", "snapping_turtle"))
	config.selected_squad_ids.assign(state.get("selected_squad_ids", []))
	config.blue_draft_bans.assign(state.get("blue_draft_bans", []))
	config.red_draft_bans.assign(state.get("red_draft_bans", []))
	config.wake_boss = bool(state.get("wake_boss", false))
	config.center_boss = bool(state.get("center_boss", false))
