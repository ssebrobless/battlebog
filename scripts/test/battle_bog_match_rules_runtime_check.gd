extends SceneTree

const MatchRulesScript := preload("res://scripts/game/match_rules.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const TEST_CREATURE_ID := "snapping_turtle"

func _initialize() -> void:
	var failures: Array[String] = []
	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		push_error("match rules runtime check could not find GameConfig")
		quit(1)
		return
	var original_mode := String(config.selected_mode)
	var original_creature_id := String(config.selected_creature_id)

	var solo := _capture_mode("1v1", config, failures)
	var clash := _capture_mode("3v3", config, failures)

	config.selected_mode = original_mode
	config.selected_creature_id = original_creature_id

	var solo_ok := _check_mode(
		solo,
		"1v1",
		MatchRulesScript.TOPOLOGY_SOLO_SWAP,
		2.6,
		failures
	)
	var clash_ok := _check_mode(
		clash,
		"3v3",
		MatchRulesScript.TOPOLOGY_LEGACY_SINGLE_LEAD,
		2.2,
		failures
	)
	var rng_ok := (
		solo.has("rng_seed")
		and clash.has("rng_seed")
		and int(solo["rng_seed"]) == int(clash["rng_seed"])
	)
	if not rng_ok:
		failures.append("legacy modes should derive the same RNG seed for the same creature")

	var passed := solo_ok and clash_ok and rng_ok
	print("match_rules_runtime solo=%s clash=%s rng=%s" % [
		str(solo_ok),
		str(clash_ok),
		str(rng_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _capture_mode(mode: String, config: Node, failures: Array[String]) -> Dictionary:
	config.selected_mode = mode
	config.selected_creature_id = TEST_CREATURE_ID

	var ArenaScript = load("res://scripts/game/arena.gd")
	if ArenaScript == null:
		failures.append("Arena script failed to load for legacy mode %s" % mode)
		return {}
	var arena = ArenaScript.new()
	if not arena._configure_mode():
		failures.append("Arena rejected legacy mode %s" % mode)
		arena.free()
		return {}

	arena._seed_match_rng()
	var terrain = arena.terrain_map
	var snapshot := {
		"ruleset_id": String(arena.match_rules.get("id", "")),
		"terrain_ruleset_id": String(terrain.rules_snapshot.get("id", "")),
		"topology_id": String(arena.control_topology.get("id", "")),
		"wave_interval": float(arena.wave_interval),
		"hunger_sec": float(arena.hunger_full_to_empty_sec),
		"blue_hut_count": _team_hut_count(terrain.hut_positions, 0),
		"red_hut_count": _team_hut_count(terrain.hut_positions, 1),
		"lane_minion_offsets": arena.wave_minion_offsets.size(),
		"arena_rect": arena.arena_rect,
		"camera_zoom": arena.camera_zoom,
		"rng_seed": arena.match_rng.seed
	}
	arena.free()
	return snapshot

func _check_mode(
	snapshot: Dictionary,
	mode: String,
	expected_topology_id: String,
	expected_zoom: float,
	failures: Array[String]
) -> bool:
	if snapshot.is_empty():
		return false

	var arena_rect: Rect2 = snapshot.get("arena_rect", Rect2())
	var unit := SimConstants.UNIT_PX
	var bounds_ok := (
		is_equal_approx(arena_rect.position.x / unit, -240.0)
		and is_equal_approx(arena_rect.position.y / unit, -85.0)
		and is_equal_approx(arena_rect.size.x / unit, 480.0)
		and is_equal_approx(arena_rect.size.y / unit, 170.0)
		and is_equal_approx(arena_rect.get_center().x, 0.0)
		and is_equal_approx(arena_rect.get_center().y, 0.0)
	)
	var zoom: Vector2 = snapshot.get("camera_zoom", Vector2.ZERO)
	var ok: bool = (
		snapshot.get("ruleset_id") == MatchRulesScript.RULESET_COMPETITIVE_3V3
		and snapshot.get("terrain_ruleset_id") == MatchRulesScript.RULESET_COMPETITIVE_3V3
		and snapshot.get("topology_id") == expected_topology_id
		and is_equal_approx(float(snapshot.get("wave_interval", -1.0)), 20.0)
		and is_equal_approx(float(snapshot.get("hunger_sec", -1.0)), 105.0)
		and int(snapshot.get("blue_hut_count", -1)) == 2
		and int(snapshot.get("red_hut_count", -1)) == 2
		and int(snapshot.get("lane_minion_offsets", -1)) == 3
		and bounds_ok
		and is_equal_approx(zoom.x, expected_zoom)
		and is_equal_approx(zoom.y, expected_zoom)
	)
	if not ok:
		failures.append(
			"Arena %s runtime rules mismatch: expected competitive_3v3 topology=%s "
			+ "wave=20 hunger=105 huts=2/2 offsets=3 bounds=480x170 centered zoom=%.1f; got %s"
			% [mode, expected_topology_id, expected_zoom, str(snapshot)]
		)
	return ok

func _team_hut_count(hut_positions: Dictionary, team: int) -> int:
	var positions: Array = hut_positions.get(team, [])
	return positions.size()
