extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")
const MatchRulesScript := preload("res://scripts/game/match_rules.gd")

const LAND := "land"
const SHALLOW := "shallow"
const WATER := "water"
const COVER := "cover"
const HABITAT_BLUE := "habitat_blue"
const HABITAT_RED := "habitat_red"
const PERCH_ANCHOR_RADIUS_UNITS := 2.75

var mode := MatchRulesScript.RULESET_COMPETITIVE_3V3
var rules_snapshot: Dictionary = MatchRulesScript.competitive_3v3()
var zone_layers: Array[Dictionary] = []
var perch_anchors: Array[Vector2] = []
var arena_rect := Rect2()
var blue_core_position := Vector2.ZERO
var red_core_position := Vector2.ZERO
var blue_minion_spawn := Vector2.ZERO
var red_minion_spawn := Vector2.ZERO
var team_spawns := {}
var bot_spawns := {}
var wave_minion_offsets: Array[Vector2] = []
var objective_position := Vector2.ZERO
var objective_radius := 0.0
var hut_positions := {}
var food_spawn_points: Array = []
var animal_zones: Array = []
var environmental_obstacles: Array = []
var land_bridge_rects: Array[Rect2] = []
var water_body_rect_groups: Array = []

func configure(next_config: Variant) -> void:
	var resolved_rules := _resolve_rules(next_config)
	if resolved_rules.is_empty():
		push_error("TerrainMap rejected invalid match rules")
		return
	rules_snapshot = resolved_rules.duplicate(true)
	mode = String(rules_snapshot.get("id", ""))
	_configure_unified_map()
	_rebuild_water_body_groups()
	_rebuild_perch_anchors()

func _resolve_rules(next_config: Variant) -> Dictionary:
	if typeof(next_config) == TYPE_DICTIONARY:
		var supplied_rules: Dictionary = next_config
		if MatchRulesScript.validate_rules(supplied_rules).is_empty():
			return supplied_rules.duplicate(true)
		return {}
	var legacy_mode := String(next_config)
	if legacy_mode == "Hero Lab":
		return MatchRulesScript.competitive_3v3()
	var adapter := MatchRulesScript.for_legacy_mode(legacy_mode)
	return adapter.get("rules", {}).duplicate(true) if not adapter.is_empty() else {}

func get_zone_at(point: Vector2) -> String:
	for i in range(zone_layers.size() - 1, -1, -1):
		var layer := zone_layers[i]
		for rect: Rect2 in layer["rects"]:
			if rect.has_point(point):
				return String(layer["zone"])
	return LAND

func get_environment_profile_at(point: Vector2, movement_tags: Array = [], swim_time_remaining := -1.0) -> Dictionary:
	return EnvironmentProfileScript.for_zone(get_zone_at(point), movement_tags, swim_time_remaining)

func get_environment_profile_for_zone(zone: String, movement_tags: Array = [], swim_time_remaining := -1.0) -> Dictionary:
	return EnvironmentProfileScript.for_zone(zone, movement_tags, swim_time_remaining)

func get_rects(zone: String) -> Array:
	for layer in zone_layers:
		if String(layer["zone"]) == zone:
			return layer["rects"].duplicate()
	return []

func get_water_body_id_at(point: Vector2) -> int:
	for i in water_body_rect_groups.size():
		for rect: Rect2 in water_body_rect_groups[i]:
			if rect.has_point(point):
				return i
	return -1

func water_points_share_body(a: Vector2, b: Vector2) -> bool:
	var a_body: int = get_water_body_id_at(a)
	return a_body >= 0 and a_body == get_water_body_id_at(b)

func get_cover_rects() -> Array:
	return get_rects(COVER)

func get_perch_anchors() -> Array:
	return perch_anchors.duplicate()

func get_perch_anchor_radius_px() -> float:
	return PERCH_ANCHOR_RADIUS_UNITS * SimConstants.UNIT_PX

func get_nearest_perch_anchor(point: Vector2, max_distance_px := -1.0) -> Variant:
	var nearest := Vector2.ZERO
	var nearest_distance := INF
	for anchor in perch_anchors:
		var distance := point.distance_to(anchor)
		if distance < nearest_distance:
			nearest = anchor
			nearest_distance = distance
	var allowed_distance := get_perch_anchor_radius_px() if max_distance_px < 0.0 else max_distance_px
	if nearest_distance <= allowed_distance:
		return nearest
	return null

func get_team_habitat_rect(team: int) -> Rect2:
	var habitat_zone := HABITAT_BLUE if team == 0 else HABITAT_RED
	var rects := get_rects(habitat_zone)
	return rects[0] if not rects.is_empty() else Rect2()

func get_food_spawn_points() -> Array:
	return food_spawn_points.duplicate(true)

func get_animal_zones() -> Array:
	return animal_zones.duplicate(true)

func get_environmental_obstacles() -> Array:
	return environmental_obstacles.duplicate(true)

func get_land_bridge_rects() -> Array[Rect2]:
	return land_bridge_rects.duplicate()

func _rebuild_perch_anchors() -> void:
	perch_anchors.clear()
	for rect: Rect2 in get_cover_rects():
		perch_anchors.append(rect.get_center())

func _rebuild_water_body_groups() -> void:
	water_body_rect_groups.clear()
	var water_rects: Array = get_rects(WATER)
	var assigned: Array[bool] = []
	for _rect: Rect2 in water_rects:
		assigned.append(false)
	for i in water_rects.size():
		if assigned[i]:
			continue
		var group: Array[Rect2] = []
		var stack: Array[int] = [i]
		assigned[i] = true
		while not stack.is_empty():
			var rect_index: int = stack.pop_back()
			var rect: Rect2 = water_rects[rect_index]
			group.append(rect)
			for j in water_rects.size():
				if assigned[j]:
					continue
				if _water_rects_connect(rect, water_rects[j]):
					assigned[j] = true
					stack.append(j)
		water_body_rect_groups.append(group)

func _water_rects_connect(a: Rect2, b: Rect2) -> bool:
	return a.grow(0.5).intersects(b.grow(0.5))

func _configure_unified_map() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-240.0, -85.0, 480.0, 170.0)
	var central_shallow_rects: Array = [
		_rect_units(-22.0, -85.0, 12.0, 37.0),
		_rect_units(10.0, -85.0, 12.0, 37.0),
		_rect_units(-22.0, -35.0, 12.0, 83.0),
		_rect_units(10.0, -35.0, 12.0, 83.0),
		_rect_units(-22.0, 61.0, 12.0, 24.0),
		_rect_units(10.0, 61.0, 12.0, 24.0)
	]
	var central_water_rects: Array = [
		_rect_units(-10.0, -85.0, 20.0, 37.0),
		_rect_units(-10.0, -35.0, 20.0, 83.0),
		_rect_units(-10.0, 61.0, 20.0, 24.0)
	]
	var blue_stream_shallow_rects: Array = [
		_rect_units(-236.0, 16.0, 36.0, 24.0),
		_rect_units(-228.0, 21.0, 42.0, 18.0),
		_rect_units(-199.0, 31.0, 44.0, 19.0),
		_rect_units(-181.0, 39.0, 74.0, 20.0),
		_rect_units(-123.0, 50.0, 82.0, 20.0),
		_rect_units(-59.0, 39.0, 32.0, 26.0),
		_rect_units(-55.0, 20.0, 28.0, 43.0),
		_rect_units(-45.0, 13.0, 40.0, 22.0)
	]
	var blue_stream_water_rects: Array = [
		_rect_units(-232.0, 20.0, 24.0, 16.0),
		_rect_units(-222.0, 27.0, 32.0, 8.0),
		_rect_units(-194.0, 36.0, 34.0, 9.0),
		_rect_units(-176.0, 44.0, 66.0, 10.0),
		_rect_units(-118.0, 55.0, 72.0, 10.0),
		_rect_units(-54.0, 46.0, 22.0, 14.0),
		_rect_units(-50.0, 25.0, 18.0, 35.0),
		_rect_units(-40.0, 18.0, 30.0, 12.0)
	]
	var blue_zone_shallow_rects: Array = [
		_rect_units(-149.0, -67.0, 24.0, 18.0),
		_rect_units(-105.0, 35.0, 26.0, 20.0),
		_rect_units(-144.0, -2.0, 24.0, 20.0),
		_rect_units(-76.0, -55.0, 24.0, 20.0),
		_rect_units(-62.0, 8.0, 28.0, 20.0)
	]
	var blue_zone_water_rects: Array = [
		_rect_units(-145.0, -63.0, 16.0, 10.0),
		_rect_units(-101.0, 39.0, 18.0, 12.0),
		_rect_units(-140.0, 2.0, 16.0, 12.0),
		_rect_units(-72.0, -51.0, 16.0, 12.0),
		_rect_units(-57.0, 12.0, 18.0, 12.0)
	]
	var shallow_rects: Array = central_shallow_rects.duplicate()
	shallow_rects.append_array(_with_mirrored_rects(blue_stream_shallow_rects))
	shallow_rects.append_array(_with_mirrored_rects(blue_zone_shallow_rects))
	var water_rects: Array = central_water_rects.duplicate()
	water_rects.append_array(_with_mirrored_rects(blue_stream_water_rects))
	water_rects.append_array(_with_mirrored_rects(blue_zone_water_rects))
	land_bridge_rects = [
		_rect_units(-24.0, -48.0, 48.0, 13.0),
		_rect_units(-24.0, 48.0, 48.0, 13.0)
	]
	animal_zones = _build_animal_zones()
	environmental_obstacles = _build_environmental_obstacles()
	var cover_rects: Array = []
	for obstacle in environmental_obstacles:
		cover_rects.append(obstacle["rect"])
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-240.0, -40.0, 40.0, 80.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(200.0, -40.0, 40.0, 80.0)
		]},
		{"zone": SHALLOW, "rects": shallow_rects},
		{"zone": WATER, "rects": water_rects},
		{"zone": COVER, "rects": cover_rects}
	]
	blue_core_position = Vector2(-223.0 * unit, 0.0)
	red_core_position = Vector2(223.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-198.0 * unit, 0.0)
	red_minion_spawn = Vector2(198.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-218.0 * unit, 10.0 * unit),
		1: Vector2(218.0 * unit, -10.0 * unit)
	}
	bot_spawns = {
		"Blue Guard": Vector2(-218.0 * unit, -10.0 * unit),
		"Blue Ward": Vector2(-226.0 * unit, 24.0 * unit),
		"Red Blade": Vector2(218.0 * unit, -10.0 * unit),
		"Red Scope": Vector2(226.0 * unit, 24.0 * unit),
		"Red Chorus": Vector2(218.0 * unit, 10.0 * unit),
		"Red Rival": Vector2(218.0 * unit, -10.0 * unit)
	}
	wave_minion_offsets = _build_unified_wave_minion_offsets(unit)
	objective_position = Vector2.ZERO
	objective_radius = 9.0 * unit
	hut_positions = _build_unified_hut_positions(unit)
	food_spawn_points = _build_unified_food_spawns()

func _build_unified_wave_minion_offsets(unit: float) -> Array[Vector2]:
	var count := int(rules_snapshot.get("lane_minions_per_hut", 0))
	if count == 3:
		return [Vector2(0.0, -8.0 * unit), Vector2.ZERO, Vector2(0.0, 8.0 * unit)]
	push_error("Unsupported lane minion count in map profile: %d" % count)
	return []

func _build_unified_hut_positions(unit: float) -> Dictionary:
	var hut_count := int(rules_snapshot.get("hut_count_per_team", 0))
	if hut_count != 2:
		push_error("Unsupported hut count in map profile: %d" % hut_count)
		return {}
	return {
		0: [Vector2(-198.0 * unit, -34.0 * unit), Vector2(-198.0 * unit, 34.0 * unit)],
		1: [Vector2(198.0 * unit, -34.0 * unit), Vector2(198.0 * unit, 34.0 * unit)]
	}

func _configure_3v3() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-120.0, -67.5, 240.0, 135.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-17.0, -67.5, 8.0, 135.0),
			_rect_units(9.0, -67.5, 8.0, 135.0),
			_rect_units(-82.0, -62.0, 28.0, 22.0),
			_rect_units(54.0, 40.0, 28.0, 22.0)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-9.0, -67.5, 18.0, 135.0),
			_rect_units(-78.0, -58.0, 20.0, 14.0),
			_rect_units(58.0, 44.0, 20.0, 14.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-117.0, -19.0, 30.0, 38.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(87.0, -19.0, 30.0, 38.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-92.0, -48.0, 9.0, 7.0),
			_rect_units(83.0, 41.0, 9.0, 7.0),
			_rect_units(-92.0, 40.0, 9.0, 7.0),
			_rect_units(83.0, -47.0, 9.0, 7.0),
			_rect_units(-60.0, -26.0, 8.0, 6.0),
			_rect_units(52.0, 20.0, 8.0, 6.0),
			_rect_units(-60.0, 20.0, 8.0, 6.0),
			_rect_units(52.0, -26.0, 8.0, 6.0),
			_rect_units(-38.0, -56.0, 10.0, 7.0),
			_rect_units(28.0, 49.0, 10.0, 7.0),
			_rect_units(-38.0, 49.0, 10.0, 7.0),
			_rect_units(28.0, -56.0, 10.0, 7.0),
			_rect_units(-26.0, -8.0, 6.0, 16.0),
			_rect_units(20.0, -8.0, 6.0, 16.0)
		]}
	]
	blue_core_position = Vector2(-103.0 * unit, 0.0)
	red_core_position = Vector2(103.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-84.0 * unit, 0.0)
	red_minion_spawn = Vector2(84.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-98.0 * unit, 10.0 * unit),
		1: Vector2(98.0 * unit, -10.0 * unit)
	}
	bot_spawns = {
		"Blue Guard": Vector2(-100.0 * unit, -11.0 * unit),
		"Blue Ward": Vector2(-106.0 * unit, 6.0 * unit),
		"Red Blade": Vector2(100.0 * unit, -11.0 * unit),
		"Red Scope": Vector2(106.0 * unit, 6.0 * unit),
		"Red Chorus": Vector2(100.0 * unit, 11.0 * unit),
		"Red Rival": Vector2(100.0 * unit, -11.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -4.0 * unit), Vector2.ZERO, Vector2(0.0, 4.0 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 7.0 * unit
	hut_positions = {
		0: [Vector2(-78.0 * unit, -34.0 * unit), Vector2(-78.0 * unit, 34.0 * unit)],
		1: [Vector2(78.0 * unit, -34.0 * unit), Vector2(78.0 * unit, 34.0 * unit)]
	}
	food_spawn_points = [
		{"kind": "plant", "position": Vector2(-64.0 * unit, -50.0 * unit)},
		{"kind": "plant", "position": Vector2(64.0 * unit, 50.0 * unit)},
		{"kind": "plant", "position": Vector2(-36.0 * unit, 28.0 * unit)},
		{"kind": "plant", "position": Vector2(36.0 * unit, -28.0 * unit)},
		{"kind": "critter", "position": Vector2(-26.0 * unit, -36.0 * unit)},
		{"kind": "critter", "position": Vector2(26.0 * unit, 36.0 * unit)},
		{"kind": "critter", "position": Vector2(-12.0 * unit, 16.0 * unit)},
		{"kind": "critter", "position": Vector2(12.0 * unit, -16.0 * unit)}
	]

func _configure_1v1() -> void:
	var unit := SimConstants.UNIT_PX
	arena_rect = _rect_units(-75.0, -42.0, 150.0, 84.0)
	zone_layers = [
		{"zone": LAND, "rects": [arena_rect]},
		{"zone": SHALLOW, "rects": [
			_rect_units(-12.0, -42.0, 6.0, 84.0),
			_rect_units(6.0, -42.0, 6.0, 84.0)
		]},
		{"zone": WATER, "rects": [
			_rect_units(-6.0, -42.0, 12.0, 84.0)
		]},
		{"zone": HABITAT_BLUE, "rects": [
			_rect_units(-73.0, -13.0, 20.0, 26.0)
		]},
		{"zone": HABITAT_RED, "rects": [
			_rect_units(53.0, -13.0, 20.0, 26.0)
		]},
		{"zone": COVER, "rects": [
			_rect_units(-52.0, -30.0, 8.0, 6.0),
			_rect_units(44.0, 24.0, 8.0, 6.0),
			_rect_units(-52.0, 24.0, 8.0, 6.0),
			_rect_units(44.0, -30.0, 8.0, 6.0),
			_rect_units(-20.0, -6.0, 5.0, 12.0),
			_rect_units(15.0, -6.0, 5.0, 12.0)
		]}
	]
	blue_core_position = Vector2(-62.0 * unit, 0.0)
	red_core_position = Vector2(62.0 * unit, 0.0)
	blue_minion_spawn = Vector2(-48.0 * unit, 0.0)
	red_minion_spawn = Vector2(48.0 * unit, 0.0)
	team_spawns = {
		0: Vector2(-58.0 * unit, 7.0 * unit),
		1: Vector2(58.0 * unit, -7.0 * unit)
	}
	bot_spawns = {
		"Red Rival": Vector2(58.0 * unit, -7.0 * unit)
	}
	wave_minion_offsets = [Vector2(0.0, -3.0 * unit), Vector2(0.0, 3.0 * unit)]
	objective_position = Vector2.ZERO
	objective_radius = 5.0 * unit
	hut_positions = {
		0: [Vector2(-45.0 * unit, 0.0)],
		1: [Vector2(45.0 * unit, 0.0)]
	}
	food_spawn_points = [
		{"kind": "plant", "position": Vector2(-34.0 * unit, -24.0 * unit)},
		{"kind": "plant", "position": Vector2(34.0 * unit, 24.0 * unit)},
		{"kind": "plant", "position": Vector2(-20.0 * unit, 18.0 * unit)},
		{"kind": "plant", "position": Vector2(20.0 * unit, -18.0 * unit)},
		{"kind": "critter", "position": Vector2(-18.0 * unit, -10.0 * unit)},
		{"kind": "critter", "position": Vector2(18.0 * unit, 10.0 * unit)}
	]

func _build_animal_zones() -> Array:
	var zones: Array = []
	_append_mirrored_animal_zone(zones, "A", -137.0, -58.0, 38.0, 19.0, [
		"newt", "great_blue_heron", "water_snake", "water_shrew", "crayfish"
	])
	_append_mirrored_animal_zone(zones, "B", -92.0, 45.0, 43.0, 23.0, [
		"bullfrog", "owl", "beaver", "snapping_turtle", "leeches"
	])
	_append_mirrored_animal_zone(zones, "C", -132.0, 8.0, 39.0, 22.0, [
		"chorus_frog", "alligator", "duck", "fireflies", "mink"
	])
	_append_mirrored_animal_zone(zones, "D", -64.0, -45.0, 38.0, 22.0, [
		"cane_toad", "bog_turtle", "kingfisher", "otter", "mosquitos"
	])
	_append_mirrored_animal_zone(zones, "Boss", -48.0, 18.0, 35.0, 28.0, [], true)
	return zones

func _append_mirrored_animal_zone(zones: Array, group: String, x: float, y: float, rx: float, ry: float, creatures: Array, boss := false) -> void:
	zones.append(_animal_zone("blue", group, x, y, rx, ry, creatures, boss))
	zones.append(_animal_zone("red", group, -x, y, rx, ry, creatures, boss))

func _animal_zone(side: String, group: String, x: float, y: float, rx: float, ry: float, creatures: Array, boss: bool) -> Dictionary:
	var unit := SimConstants.UNIT_PX
	return {
		"side": side,
		"group": group,
		"center_units": Vector2(x, y),
		"center": Vector2(x * unit, y * unit),
		"radius_units": Vector2(rx, ry),
		"radius": Vector2(rx * unit, ry * unit),
		"water_center_units": Vector2(x, y),
		"water_center": Vector2(x * unit, y * unit),
		"water_radius_units": Vector2(8.0, 5.0),
		"water_radius": Vector2(8.0 * unit, 5.0 * unit),
		"creatures": creatures.duplicate(),
		"boss": boss,
		"breed_activation_count": 5 if boss else 0
	}

func _build_environmental_obstacles() -> Array:
	var obstacles: Array = []
	_append_mirrored_obstacle(obstacles, "bush", -232.0, -72.0, 7.0, 6.0)
	_append_mirrored_obstacle(obstacles, "tree", -184.0, -78.0, 8.0, 8.0)
	_append_mirrored_obstacle(obstacles, "rock", -150.0, -75.0, 10.0, 6.0)
	_append_mirrored_obstacle(obstacles, "bush", -78.0, -76.0, 8.0, 6.0)
	_append_mirrored_obstacle(obstacles, "rock", -34.0, -74.0, 8.0, 7.0)
	_append_mirrored_obstacle(obstacles, "tree", -160.0, -28.0, 9.0, 9.0)
	_append_mirrored_obstacle(obstacles, "bush", -112.0, -46.0, 8.0, 6.0)
	_append_mirrored_obstacle(obstacles, "rock", -96.0, -6.0, 8.0, 9.0)
	_append_mirrored_obstacle(obstacles, "bush", -70.0, 12.0, 7.0, 6.0)
	_append_mirrored_obstacle(obstacles, "rock", -30.0, -22.0, 8.0, 7.0)
	_append_mirrored_obstacle(obstacles, "tree", -174.0, 70.0, 8.0, 8.0)
	_append_mirrored_obstacle(obstacles, "bush", -146.0, 42.0, 7.0, 7.0)
	_append_mirrored_obstacle(obstacles, "tree", -116.0, 69.0, 8.0, 8.0)
	_append_mirrored_obstacle(obstacles, "rock", -58.0, 36.0, 9.0, 7.0)
	_append_mirrored_obstacle(obstacles, "tree", -34.0, 71.0, 7.0, 7.0)
	return obstacles

func _append_mirrored_obstacle(obstacles: Array, obstacle_type: String, x: float, y: float, width: float, height: float) -> void:
	obstacles.append(_obstacle(obstacle_type, "blue", x, y, width, height))
	obstacles.append(_obstacle(obstacle_type, "red", -x - width, y, width, height))

func _obstacle(obstacle_type: String, side: String, x: float, y: float, width: float, height: float) -> Dictionary:
	var rect: Rect2 = _rect_units(x, y, width, height)
	return {
		"type": obstacle_type,
		"side": side,
		"rect_units": Rect2(Vector2(x, y), Vector2(width, height)),
		"rect": rect,
		"center": rect.get_center()
	}

func _build_unified_food_spawns() -> Array:
	var blue_entries: Array = []
	blue_entries.append(_plant_entry("berry", -226.0, -62.0))
	blue_entries.append(_plant_entry("berry", -210.0, -18.0))
	blue_entries.append(_plant_entry("berry", -188.0, 60.0))
	blue_entries.append(_plant_entry("berry", -160.0, -72.0))
	blue_entries.append(_plant_entry("berry", -142.0, 28.0))
	blue_entries.append(_plant_entry("berry", -118.0, -34.0))
	blue_entries.append(_plant_entry("berry", -92.0, 70.0))
	blue_entries.append(_plant_entry("berry", -74.0, 6.0))
	blue_entries.append(_plant_entry("berry", -46.0, -62.0))
	blue_entries.append(_plant_entry("berry", -28.0, 34.0))
	blue_entries.append(_plant_entry("tree", -232.0, 64.0))
	blue_entries.append(_plant_entry("tree", -214.0, 4.0))
	blue_entries.append(_plant_entry("tree", -182.0, -54.0))
	blue_entries.append(_plant_entry("tree", -154.0, 58.0))
	blue_entries.append(_plant_entry("tree", -136.0, -12.0))
	blue_entries.append(_plant_entry("tree", -104.0, 24.0))
	blue_entries.append(_plant_entry("tree", -86.0, -74.0))
	blue_entries.append(_plant_entry("tree", -62.0, 62.0))
	blue_entries.append(_plant_entry("tree", -40.0, -8.0))
	blue_entries.append(_plant_entry("tree", -24.0, 74.0))
	blue_entries.append(_plant_entry("seed", -222.0, 46.0))
	blue_entries.append(_plant_entry("seed", -204.0, -70.0))
	blue_entries.append(_plant_entry("seed", -174.0, 16.0))
	blue_entries.append(_plant_entry("seed", -150.0, -38.0))
	blue_entries.append(_plant_entry("seed", -126.0, 72.0))
	blue_entries.append(_plant_entry("seed", -98.0, -58.0))
	blue_entries.append(_plant_entry("seed", -76.0, 40.0))
	blue_entries.append(_plant_entry("seed", -54.0, -24.0))
	blue_entries.append(_plant_entry("seed", -36.0, 54.0))
	blue_entries.append(_plant_entry("seed", -18.0, -66.0))
	blue_entries.append(_plant_entry("flower", -230.0, -4.0))
	blue_entries.append(_plant_entry("flower", -196.0, 34.0))
	blue_entries.append(_plant_entry("flower", -166.0, -22.0))
	blue_entries.append(_plant_entry("flower", -146.0, 76.0))
	blue_entries.append(_plant_entry("flower", -116.0, 8.0))
	blue_entries.append(_plant_entry("flower", -90.0, -18.0))
	blue_entries.append(_plant_entry("flower", -70.0, -66.0))
	blue_entries.append(_plant_entry("flower", -52.0, 18.0))
	blue_entries.append(_plant_entry("flower", -34.0, -42.0))
	blue_entries.append(_plant_entry("flower", -22.0, 6.0))
	var food_entries: Array = _with_mirrored_food(blue_entries)
	var blue_critters: Array = [
		_critter_entry(-132.0, -50.0),
		_critter_entry(-88.0, 36.0),
		_critter_entry(-58.0, -44.0),
		_critter_entry(-42.0, 20.0)
	]
	food_entries.append_array(_with_mirrored_food(blue_critters))
	return food_entries

func _plant_entry(plant_type: String, x: float, y: float) -> Dictionary:
	var harvest_hits: int = 3 if plant_type == "tree" else 1
	var food_value: float = 44.0 if plant_type == "tree" else 24.0
	var heal_fraction: float = 0.16 if plant_type == "tree" else 0.08
	return {
		"kind": "plant",
		"side": "blue",
		"position": _point_units(x, y),
		"plant_type": plant_type,
		"harvest_hits": harvest_hits,
		"food_value": food_value,
		"heal_fraction": heal_fraction
	}

func _critter_entry(x: float, y: float) -> Dictionary:
	return {
		"kind": "critter",
		"side": "blue",
		"position": _point_units(x, y),
		"food_value": 24.0,
		"heal_fraction": 0.06
	}

func _with_mirrored_food(blue_entries: Array) -> Array:
	var entries: Array = []
	for entry in blue_entries:
		entries.append(entry)
		var source: Dictionary = entry
		var mirrored: Dictionary = source.duplicate(true)
		var position: Vector2 = mirrored["position"]
		mirrored["position"] = Vector2(-position.x, position.y)
		mirrored["side"] = "red"
		entries.append(mirrored)
	return entries

func _with_mirrored_rects(blue_rects: Array) -> Array:
	var rects: Array = []
	for rect: Rect2 in blue_rects:
		rects.append(rect)
		rects.append(_mirror_rect_x(rect))
	return rects

func _mirror_rect_x(rect: Rect2) -> Rect2:
	return Rect2(Vector2(-rect.position.x - rect.size.x, rect.position.y), rect.size)

func _point_units(x: float, y: float) -> Vector2:
	var unit := SimConstants.UNIT_PX
	return Vector2(x * unit, y * unit)

func _rect_units(x: float, y: float, width: float, height: float) -> Rect2:
	var unit := SimConstants.UNIT_PX
	return Rect2(Vector2(x * unit, y * unit), Vector2(width * unit, height * unit))
