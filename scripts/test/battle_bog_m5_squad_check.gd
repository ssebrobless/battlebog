extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const MinionScript := preload("res://scripts/game/minion.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		var squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
		config.set_selected_squad_ids(squad_ids)

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("failed to boot Arena scene for M5 squad check: error=%d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("Arena scene did not become current_scene for M5 squad check.")
		quit(1)
		return

	var failures: Array[String] = []
	var spawn_ok := _check_spawn(arena, failures)
	var switch_ok := _check_switch(arena, failures)
	var follow_ok := _check_follow(arena, failures)
	var aggro_ok := _check_aggro(arena, failures)
	var farm_ok := _check_farm_cancel(arena, failures)
	var proactive_ok := _check_farm_proactive(arena, failures)
	var passed := spawn_ok and switch_ok and follow_ok and aggro_ok and farm_ok and proactive_ok
	print("m5_squad spawn=%s switch=%s follow=%s aggro=%s farm=%s proactive=%s" % [
		str(spawn_ok),
		str(switch_ok),
		str(follow_ok),
		str(aggro_ok),
		str(farm_ok),
		str(proactive_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_spawn(arena: Node, failures: Array[String]) -> bool:
	var ok: bool = arena.player_squad.size() == 3 and arena.bots.size() == 3 and arena.player == arena.player_squad[0]
	if not ok:
		failures.append("spawn expected 3 blue squad members, 3 red bots, and slot 1 active; got squad=%d bots=%d active=%s" % [
			arena.player_squad.size(),
			arena.bots.size(),
			str(arena.player)
		])
	return ok

func _check_switch(arena: Node, failures: Array[String]) -> bool:
	arena._set_active_squad_index(1, false)
	var ok: bool = arena.active_squad_index == 1 and arena.player == arena.player_squad[1]
	if not ok:
		failures.append("switch expected slot 2 active; index=%d player_match=%s" % [
			arena.active_squad_index,
			str(arena.player == arena.player_squad[1])
		])
	return ok

func _check_follow(arena: Node, failures: Array[String]) -> bool:
	var active: Node = arena.player
	var inactive: Node = arena.player_squad[0]
	inactive.global_position = active.global_position + Vector2.LEFT * 220.0
	arena._issue_squad_follow(false)
	var frame: Resource = arena._build_squad_ai_frame(inactive)
	var toward_active: Vector2 = (active.global_position - inactive.global_position).normalized()
	var moves_to_active: bool = frame.move.dot(toward_active) > 0.7
	var no_deposit: bool = not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)
	var ok: bool = arena.squad_command == "follow" and arena.squad_command_timer > 9.9 and moves_to_active and no_deposit
	if not ok:
		failures.append("follow expected T command, movement toward active, and no deposit; command=%s timer=%.2f move=%s no_deposit=%s" % [
			arena.squad_command,
			arena.squad_command_timer,
			str(frame.move),
			str(no_deposit)
		])
	return ok

func _check_aggro(arena: Node, failures: Array[String]) -> bool:
	arena._issue_squad_follow(false)
	var target: Node = arena.bots[0]
	arena.record_vfx_event({
		"type": "hit_landed",
		"source": arena.player,
		"target": target,
		"position": target.global_position,
		"amount": 10.0,
		"heavy": false
	})
	var inactive: Node = arena.player_squad[0]
	var frame: Resource = arena._build_squad_ai_frame(inactive)
	var no_deposit: bool = not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)
	var ok: bool = arena.squad_command == "aggro" and arena.squad_aggro_target == target and no_deposit
	if not ok:
		failures.append("aggro expected resolved hit to promote follow into aggro; command=%s target_match=%s buttons=%d" % [
			arena.squad_command,
			str(arena.squad_aggro_target == target),
			frame.buttons
		])
	return ok

func _check_farm_cancel(arena: Node, failures: Array[String]) -> bool:
	arena._issue_squad_farm(false)
	var inactive: Node = arena.player_squad[0]
	var enemy: Node = arena.bots[0]
	inactive.health = inactive.max_health
	inactive.global_position = enemy.global_position + Vector2.LEFT * 90.0
	var frame: Resource = arena._build_squad_ai_frame(inactive)
	var avoids_enemy_player: bool = not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	var no_deposit: bool = not frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT)
	var ok: bool = arena.squad_command == "farm" and arena.squad_aggro_target == null and avoids_enemy_player and no_deposit
	if not ok:
		failures.append("farm expected G cancel, no real-player attack, and no deposit; command=%s target=%s buttons=%d" % [
			arena.squad_command,
			str(arena.squad_aggro_target),
			frame.buttons
		])
	return ok

# Uncontrolled squad members must be proactive in farm mode (2026-07-05
# fix): advance to the frontline instead of idling at spawn, chase waves
# from far out, but never contest a wave an enemy creature is holding.
func _check_farm_proactive(arena: Node, failures: Array[String]) -> bool:
	arena._issue_squad_farm(false)
	var inactive: Node = arena.player_squad[1] if arena.player != arena.player_squad[1] else arena.player_squad[0]
	inactive.health = inactive.max_health
	inactive.global_position = arena.get_team_spawn(0)
	for bot in arena.bots:
		bot.global_position = arena.get_team_spawn(1)

	var idle_frame: Resource = arena._build_squad_ai_frame(inactive)
	var leaves_spawn: bool = idle_frame.move != Vector2.ZERO

	var minion := MinionScript.new()
	arena.add_child(minion)
	minion.setup(arena, 1, inactive.global_position + Vector2(400.0, 0.0), "lane", Vector2.ZERO)
	arena.register_entity(minion)
	arena.track_minion(minion)
	var toward: Vector2 = (minion.global_position - inactive.global_position).normalized()
	var chase_frame: Resource = arena._build_squad_ai_frame(inactive)
	var chases_wave: bool = chase_frame.move.dot(toward) > 0.5

	# The frontline fallback can share a direction with the wave, so assert
	# the contested-guard itself: clear before an enemy arrives, contested
	# once one is standing on the farm point.
	var danger_point: Vector2 = inactive.global_position + Vector2.RIGHT * 120.0
	var uncontested: bool = not arena._farm_point_contested(inactive, danger_point)
	arena.bots[0].global_position = danger_point
	arena._tick_team_vision(0.2)
	var respects_danger: bool = uncontested and arena._farm_point_contested(inactive, danger_point)

	arena.unregister_entity(minion)
	minion.queue_free()
	var ok := leaves_spawn and chases_wave and respects_danger
	if not ok:
		failures.append("farm proactive expected leave_spawn/chase/respect_danger, got %s/%s/%s" % [
			str(leaves_spawn),
			str(chases_wave),
			str(respects_danger)
		])
	return ok
