extends SceneTree

# M4 unit checks run against a stub arena because arena.gd references the
# GameConfig autoload global, which does not exist in --script mode. The
# real arena boot (huts spawning in a live 3v3) is validated separately by
# running scenes/Arena.tscn headless with --quit-after.

const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const MudHutScript := preload("res://scripts/game/mud_hut.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

class StubArena extends Node2D:
	var entities: Array[Node] = []
	var destroyed_huts: Array[Node] = []
	var tracked := 0
	var last_enemy_query_range := 0.0
	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)
	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)
	func track_minion(_minion: Node) -> void:
		tracked += 1
	func on_hut_destroyed(hut: Node) -> void:
		destroyed_huts.append(hut)
	func get_closest_enemy(_source: Node, max_distance: float) -> Node:
		last_enemy_query_range = max_distance
		return null
	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point
	func get_steering_direction(from: Vector2, to: Vector2, _radius: float, _team: int) -> Vector2:
		return (to - from).normalized()
	func get_enemy_core(_team: int) -> Node:
		return null

func _initialize() -> void:
	# The legacy 1v1 adapter uses the same competitive hut and wave layout as
	# 3v3: two lane huts per side and three minion offsets per surviving hut.
	var terrain := TerrainMapScript.new()
	var unit := SimConstants.UNIT_PX
	terrain.configure("3v3")
	var competitive_huts: bool = terrain.hut_positions[0].size() == 2 \
		and terrain.hut_positions[1].size() == 2 \
		and terrain.hut_positions[0][0] / unit == Vector2(-198.0, -34.0) \
		and terrain.hut_positions[0][1] / unit == Vector2(-198.0, 34.0) \
		and terrain.hut_positions[1][0] / unit == Vector2(198.0, -34.0) \
		and terrain.hut_positions[1][1] / unit == Vector2(198.0, 34.0)
	var competitive_wave_offsets: bool = terrain.wave_minion_offsets.size() == 3 \
		and terrain.wave_minion_offsets[0] / unit == Vector2(0.0, -8.0) \
		and terrain.wave_minion_offsets[1] == Vector2.ZERO \
		and terrain.wave_minion_offsets[2] / unit == Vector2(0.0, 8.0)
	var expected_hut_positions: Dictionary = terrain.hut_positions.duplicate(true)
	var expected_wave_offsets: Array[Vector2] = terrain.wave_minion_offsets.duplicate()
	terrain.configure("1v1")
	var legacy_hut_parity: bool = terrain.hut_positions == expected_hut_positions
	var legacy_wave_parity: bool = terrain.wave_minion_offsets == expected_wave_offsets

	var stub := StubArena.new()
	get_root().add_child(stub)

	# Hut spawns its 5-defender squad (1 tank, 2 melee, 2 pebble).
	var hut = MudHutScript.new()
	stub.add_child(hut)
	hut.setup(stub, 1, 0, Vector2.ZERO)
	var hut_color_ok: bool = _color_matches(hut.get_team_accent_color(0.72), VisualGrammar.team_color(1, 0.72))
	var hut_visual_ok: bool = hut.has_method("uses_event_driven_redraw") \
		and hut.has_method("get_visual_damage_state") \
		and hut.has_method("get_damage_visual_features") \
		and bool(hut.call("uses_event_driven_redraw")) \
		and String(hut.call("get_visual_damage_state")) == "intact"
	var kinds := {"tank": 0, "melee": 0, "pebble": 0}
	for entity in stub.entities:
		if entity is MinionScript:
			kinds[entity.kind] = int(kinds.get(entity.kind, 0)) + 1
	var squad_ok: bool = kinds["tank"] == 1 and kinds["melee"] == 2 and kinds["pebble"] == 2 and stub.tracked == 5
	var defender: Node = null
	for entity in stub.entities:
		if entity is MinionScript and entity.leash_hut == hut:
			defender = entity
			break
	if defender != null:
		defender._physics_process(0.25)
	var patrol_radius_ok: bool = absf(MinionScript.DEFENDER_PATROL_RADIUS / unit - 20.0) < 0.001 \
		and absf(MinionScript.DEFENDER_IDLE_RETURN_RADIUS / unit - 10.0) < 0.001 \
		and absf(stub.last_enemy_query_range - MinionScript.DEFENDER_AGGRO_RANGE) < 0.001

	# Defender death queues a 5s respawn; hut respawns it after the delay.
	var victim: Node = null
	for entity in stub.entities:
		if entity is MinionScript and entity.kind == "tank":
			victim = entity
			break
	victim.take_damage(10000.0)
	var queued: bool = hut.respawn_queue.size() == 1
	hut._physics_process(5.1)
	var respawned := 0
	for entity in stub.entities:
		if entity is MinionScript and entity.kind == "tank":
			respawned += 1
	var respawn_ok: bool = queued and respawned == 1 and hut.respawn_queue.is_empty()

	hut.take_damage(hut.max_health * 0.4)
	var damaged_visual_ok: bool = String(hut.call("get_visual_damage_state")) == "damaged"
	hut.take_damage(hut.max_health * 0.35)
	var critical_visual_ok: bool = String(hut.call("get_visual_damage_state")) == "critical"
	var critical_features: Dictionary = hut.call("get_damage_visual_features")
	var critical_features_ok: bool = bool(critical_features.get("cracks", false)) \
		and bool(critical_features.get("notched_silhouette", false)) \
		and bool(critical_features.get("exposed_framing", false)) \
		and bool(critical_features.get("fallen_clods", false))
	hut_visual_ok = hut_visual_ok and damaged_visual_ok and critical_visual_ok and critical_features_ok

	# Hut destruction notifies the arena and unregisters it.
	hut.take_damage(hut.max_health)
	var destroy_ok: bool = stub.destroyed_huts.size() == 1 and not stub.entities.has(hut)

	# Minion kind stats differentiate.
	var pebble = MinionScript.new()
	stub.add_child(pebble)
	pebble.setup(stub, 0, Vector2.ZERO, "pebble")
	var tank = MinionScript.new()
	stub.add_child(tank)
	tank.setup(stub, 0, Vector2.ZERO, "tank")
	var melee = MinionScript.new()
	stub.add_child(melee)
	melee.setup(stub, 0, Vector2.ZERO, "melee")
	var lane = MinionScript.new()
	stub.add_child(lane)
	lane.setup(stub, 0, Vector2.ZERO, "lane")
	var kinds_ok: bool = pebble.attack_range > 90.0 and tank.max_health > 200.0 and tank.speed < 145.0
	var tank_style: Dictionary = tank.get_render_style_state()
	var pebble_style: Dictionary = pebble.get_render_style_state()
	var melee_style: Dictionary = melee.get_render_style_state()
	var lane_style: Dictionary = lane.get_render_style_state()
	var lane_idle_signature := lane.get_render_signature()
	lane._move_toward_point(Vector2.RIGHT * 200.0, 0.25)
	var lane_walk_signature := lane.get_render_signature()
	var minion_visual_ok: bool = _all_truth_rings_match([tank_style, pebble_style, melee_style, lane_style]) \
		and String(tank_style.get("kind", "")) == "tank" \
		and String(pebble_style.get("kind", "")) == "pebble" \
		and String(melee_style.get("kind", "")) == "melee" \
		and String(lane_style.get("kind", "")) == "lane" \
		and String(tank_style.get("silhouette", "")) == "dome_tank" \
		and String(pebble_style.get("silhouette", "")) == "sling_thrower" \
		and String(melee_style.get("silhouette", "")) == "mandible_chomper" \
		and String(lane_style.get("silhouette", "")) == "lane_chomper" \
		and _features_have(tank_style, ["team_shell_arc", "wide_body", "slow_bob"]) \
		and _features_have(pebble_style, ["team_back_stripe", "sling_arm", "held_pebble"]) \
		and _features_have(melee_style, ["team_back_stripe", "mandibles"]) \
		and _features_have(lane_style, ["team_back_stripe", "mandibles", "march_bob"]) \
		and lane_walk_signature != lane_idle_signature \
		and float(tank_style.get("visual_radius_px", 0.0)) > float(tank_style.get("combat_radius_px", 0.0)) \
		and float(pebble_style.get("visual_radius_px", 99.0)) < float(pebble_style.get("combat_radius_px", 0.0)) \
		and float(melee_style.get("visual_radius_px", 99.0)) < float(melee_style.get("combat_radius_px", 0.0)) \
		and float(lane_style.get("visual_radius_px", 99.0)) < float(lane_style.get("combat_radius_px", 0.0))

	var passed := competitive_huts and competitive_wave_offsets and legacy_hut_parity and legacy_wave_parity and squad_ok and patrol_radius_ok and respawn_ok and destroy_ok and kinds_ok and minion_visual_ok and hut_color_ok and hut_visual_ok
	print("m4 competitive_huts=%s competitive_waves=%s legacy_hut_parity=%s legacy_wave_parity=%s squad=%s patrol=%s respawn=%s destroy=%s kinds=%s visual=%s hut_color=%s hut_visual=%s" % [
		str(competitive_huts), str(competitive_wave_offsets), str(legacy_hut_parity), str(legacy_wave_parity), str(squad_ok), str(patrol_radius_ok), str(respawn_ok), str(destroy_ok), str(kinds_ok), str(minion_visual_ok), str(hut_color_ok), str(hut_visual_ok)
	])
	quit(0 if passed else 1)

func _truth_ring_matches(state: Dictionary) -> bool:
	var combat_radius := float(state.get("combat_radius_px", -1.0))
	var truth_radius := float(state.get("truth_ring_radius_px", -2.0))
	return combat_radius > 0.0 and absf(truth_radius - combat_radius) < 0.001

func _all_truth_rings_match(states: Array) -> bool:
	for state: Dictionary in states:
		if not _truth_ring_matches(state):
			return false
	return true

func _features_have(state: Dictionary, expected: Array) -> bool:
	var features: Array = state.get("role_features", [])
	for feature: String in expected:
		if not features.has(feature):
			return false
	return true

func _color_matches(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001 and absf(a.a - b.a) < 0.001
