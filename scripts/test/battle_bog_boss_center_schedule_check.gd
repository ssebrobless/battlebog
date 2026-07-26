extends SceneTree
## BB-BOSS-5: the center big boss fires on the elapsed schedule (600/1200s), picks a random
## seeded family, spawns neutral + 50% larger at map center, grants the claiming team a combat
## reward (same family upgrades once), and fires NO directed enemy-side terrain disruption.

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])
	if change_scene_to_file(ARENA_SCENE) != OK:
		push_error("boss_center_schedule check failed to boot Arena")
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_center_schedule check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []

	# Nothing before 10:00.
	arena.elapsed = 300.0
	arena._tick_center_boss_schedule()
	if bool(arena.get_center_boss_state().get("active", false)):
		failures.append("center boss should not spawn before 600s")

	# Fires at 10:00: neutral, +50%, random family from the five.
	arena.elapsed = 600.0
	arena._tick_center_boss_schedule()
	var state: Dictionary = arena.get_center_boss_state()
	if not bool(state.get("active", false)):
		failures.append("center boss should spawn at 600s; state=%s" % str(state))
	var family := String(state.get("family", ""))
	if not arena.SIDE_BOSS_ORDER.has(family):
		failures.append("center family should be one of the five; got %s" % family)
	if not is_equal_approx(float(state.get("size_mult", 0.0)), 1.5):
		failures.append("center boss should be 50%% larger; size_mult=%s" % str(state.get("size_mult")))
	var actor := _center_actor(arena)
	if actor == null:
		failures.append("center boss actor should exist in wildlife_encounters")
	elif int(actor.get("team")) != -1 or not is_equal_approx(float(actor.get("body_radius")), 36.0):
		failures.append("center boss should be neutral + 36px body; team=%s r=%s" % [str(actor.get("team")), str(actor.get("body_radius"))])

	# Claim it for BLUE via the contest window -> combat reward stack 1, still NO disruption.
	if actor != null:
		arena.on_wildlife_defeated(actor, arena.player)
	var zone := _center_zone(arena)
	_drive_claim(arena, zone, 0)
	if String(zone.get("objective_state", "")) != "claimed":
		failures.append("center boss should resolve to claimed; state=%s" % String(zone.get("objective_state", "")))
	var reward: Dictionary = arena.get_team_combat_reward_state(0)
	if int(reward.get(family, {}).get("stack", 0)) != 1:
		failures.append("owner claim should grant combat reward stack 1; reward=%s" % str(reward))
	if not arena.get_active_terrain_events().is_empty():
		failures.append("center boss must NOT fire directed terrain disruption; got %s" % str(arena.get_active_terrain_events()))
	if int(arena.team_stats[0].get("center_claims", 0)) != 1:
		failures.append("center claim should increment Blue center_claims exactly once; stats=%s" % str(arena.team_stats[0]))
	var blue_summary: Dictionary = arena.get_match_summary_data("Blue", "test").get("teams", {}).get("blue", {})
	if int(blue_summary.get("center_claims", 0)) != 1:
		failures.append("match summary should retain center claim telemetry; blue=%s" % str(blue_summary))

	# Same family claimed again upgrades the stack once, capped at 2.
	arena._grant_center_reward(0, family)
	if int(arena.get_team_combat_reward_state(0).get(family, {}).get("stack", 0)) != 2:
		failures.append("repeat family should upgrade to stack 2")
	arena._grant_center_reward(0, family)
	if int(arena.get_team_combat_reward_state(0).get(family, {}).get("stack", 0)) != 2:
		failures.append("combat reward stack should cap at 2")

	# Second scheduled spawn at 20:00.
	arena.elapsed = 1200.0
	arena._tick_center_boss_schedule()
	if not bool(arena.get_center_boss_state().get("active", false)):
		failures.append("second center boss should spawn at 1200s")

	print("boss_center_schedule failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _center_actor(arena: Node) -> Node:
	for enc in arena.wildlife_encounters:
		if enc != null and is_instance_valid(enc) and enc.has_method("is_center_boss") and enc.is_center_boss():
			return enc
	return null

func _center_zone(arena: Node) -> Dictionary:
	for zone: Dictionary in arena.animal_zone_states:
		if bool(zone.get("center_boss", false)) and String(zone.get("objective_state", "")) in ["active", "claimable", "contesting"]:
			return zone
	return {}

func _drive_claim(arena: Node, zone: Dictionary, control_team: int) -> void:
	var guard := 0
	while arena._is_boss_claim_phase(zone) and guard < 100:
		zone["contested"] = false
		zone["control_team"] = control_team
		arena._advance_boss_claim(zone, 1.0)
		guard += 1
