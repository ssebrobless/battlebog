extends SceneTree

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

func _initialize() -> void:
	var terrain := TerrainMapScript.new()
	terrain.configure("3v3")
	var unit := SimConstants.UNIT_PX
	var arena_units := terrain.arena_rect.size / unit
	var arena_origin_units := terrain.arena_rect.position / unit
	var blue_habitat: Rect2 = terrain.get_team_habitat_rect(0)
	var red_habitat: Rect2 = terrain.get_team_habitat_rect(1)
	var blue_habitat_units := Rect2(blue_habitat.position / unit, blue_habitat.size / unit)
	var red_habitat_units := Rect2(red_habitat.position / unit, red_habitat.size / unit)
	var habitats_ok: bool = blue_habitat_units.position == Vector2(-240.0, -40.0) \
		and blue_habitat_units.size == Vector2(40.0, 80.0) \
		and red_habitat_units.position == Vector2(200.0, -40.0) \
		and red_habitat_units.size == Vector2(40.0, 80.0)
	var cores_in_habitat := blue_habitat.has_point(terrain.blue_core_position) and red_habitat.has_point(terrain.red_core_position)
	var core_positions_ok: bool = terrain.blue_core_position / unit == Vector2(-223.0, 0.0) \
		and terrain.red_core_position / unit == Vector2(223.0, 0.0) \
		and terrain.team_spawns[0] / unit == Vector2(-218.0, 10.0) \
		and terrain.team_spawns[1] / unit == Vector2(218.0, -10.0)
	var center_zone := terrain.get_zone_at(Vector2.ZERO)
	var shallow_zone := terrain.get_zone_at(Vector2(16.0 * unit, 0.0))
	var upper_bridge_zone := terrain.get_zone_at(Vector2(0.0, -42.0 * unit))
	var lower_bridge_zone := terrain.get_zone_at(Vector2(0.0, 55.0 * unit))
	var bridge_rects := terrain.get_land_bridge_rects()
	var bridge_rects_ok: bool = _bridge_rects_ok(terrain, bridge_rects)
	var shallow_land_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.SHALLOW, ["land_walker"])
	var shallow_comfort_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.SHALLOW, ["semi_aquatic"])
	var deep_land_profile := EnvironmentProfileScript.for_zone(TerrainMapScript.WATER, ["land_walker"])
	var habitat_profile := terrain.get_environment_profile_for_zone(TerrainMapScript.HABITAT_BLUE)
	var cover_rects := terrain.get_cover_rects()
	var perch_anchors := terrain.get_perch_anchors()
	var first_anchor: Vector2 = perch_anchors[0] if not perch_anchors.is_empty() else Vector2(1.0e20, 1.0e20)
	var nearest_first_anchor: Variant = terrain.get_nearest_perch_anchor(first_anchor)
	var far_anchor: Variant = terrain.get_nearest_perch_anchor(terrain.arena_rect.position)
	var anchors_ok: bool = perch_anchors.size() == cover_rects.size() \
		and not perch_anchors.is_empty() \
		and cover_rects[0].has_point(first_anchor) \
		and typeof(nearest_first_anchor) == TYPE_VECTOR2 \
		and far_anchor == null
	var deep_land_dragged: bool = bool(deep_land_profile["wrong_terrain_now"]) \
		and absf(float(deep_land_profile["speed_mult"]) - EnvironmentProfileScript.DEEP_WATER_LAND_DRAG_MULTIPLIER) < 0.001
	var profiles_ok: bool = float(shallow_land_profile["speed_mult"]) < 1.0 \
		and float(shallow_comfort_profile["speed_mult"]) > 1.0 \
		and deep_land_dragged \
		and String(habitat_profile["danger"]) == EnvironmentProfileScript.DANGER_SAFE
	var animal_zones_ok: bool = _animal_zones_ok(terrain, terrain.get_animal_zones())
	var zones_clear_huts_ok: bool = _animal_zones_clear_hut_patrols(terrain)
	var food_resources_ok: bool = _food_resources_ok(terrain.get_food_spawn_points())
	var obstacles_ok: bool = _environmental_obstacles_ok(terrain.get_environmental_obstacles())
	var palette_ok: bool = _visual_palette_ok()

	terrain.configure("1v1")
	var duel_units := terrain.arena_rect.size / unit
	var duel_origin_units := terrain.arena_rect.position / unit
	var duel_anchor_count := terrain.get_perch_anchors().size()

	var shared_bounds_ok: bool = arena_units == Vector2(480.0, 170.0) \
		and arena_origin_units == Vector2(-240.0, -85.0) \
		and duel_units == Vector2(480.0, 170.0) \
		and duel_origin_units == Vector2(-240.0, -85.0)
	var bridges_ok: bool = upper_bridge_zone == TerrainMapScript.LAND and lower_bridge_zone == TerrainMapScript.LAND and bridge_rects_ok
	var passed: bool = shared_bounds_ok and habitats_ok and core_positions_ok and cores_in_habitat and center_zone == TerrainMapScript.WATER and shallow_zone == TerrainMapScript.SHALLOW and bridges_ok and profiles_ok and anchors_ok and animal_zones_ok and zones_clear_huts_ok and food_resources_ok and obstacles_ok and palette_ok and duel_anchor_count == terrain.get_cover_rects().size()
	print("terrain_3v3_units=%sx%s terrain_1v1_units=%sx%s habitats=%s cores=%s center=%s shallow=%s bridges=%s profiles_ok=%s anchors_ok=%s zones=%s zone_hut_clear=%s food=%s obstacles=%s palette=%s duel_anchor_count=%d" % [
		str(arena_units.x),
		str(arena_units.y),
		str(duel_units.x),
		str(duel_units.y),
		str(habitats_ok),
		str(cores_in_habitat and core_positions_ok),
		center_zone,
		shallow_zone,
		str(bridges_ok),
		str(profiles_ok),
		str(anchors_ok),
		str(animal_zones_ok),
		str(zones_clear_huts_ok),
		str(food_resources_ok),
		str(obstacles_ok),
		str(palette_ok),
		duel_anchor_count
	])
	quit(0 if passed else 1)

func _visual_palette_ok() -> bool:
	var palette: Dictionary = VisualGrammar.environment_palette()
	var required_keys := [
		"land_dark", "land", "moss", "mud_dark", "mud",
		"reed", "water_deep", "water_shallow", "water_foam", "shadow"
	]
	for key: String in required_keys:
		if not palette.has(key):
			return false
	if not _visual_constitution_palette_matches(palette):
		return false
	var land: Color = VisualGrammar.terrain_color(TerrainMapScript.LAND)
	var shallow: Color = VisualGrammar.terrain_color(TerrainMapScript.SHALLOW)
	var water: Color = VisualGrammar.terrain_color(TerrainMapScript.WATER)
	var cover: Color = VisualGrammar.terrain_color(TerrainMapScript.COVER)
	var foam: Color = palette["water_foam"]
	var hierarchy_ok: bool = _luminance(water) < _luminance(land) \
		and _luminance(land) <= _luminance(shallow) \
		and _luminance(foam) > _luminance(shallow)
	var value_band_ok: bool = _max_channel(land) <= 0.55 \
		and _max_channel(shallow) <= 0.55 \
		and _max_channel(water) <= 0.55 \
		and _max_channel(cover) <= 0.55
	var shadow_helper_ok := _color_matches(VisualGrammar.shadow_color(0.62), Color(0.04, 0.05, 0.03, 0.62))
	var ecology_palette_ok := _ecology_visual_palette_ok()
	return hierarchy_ok and value_band_ok and shadow_helper_ok and ecology_palette_ok and foam.a < 1.0

func _ecology_visual_palette_ok() -> bool:
	var sampled := [
		VisualGrammar.harvestable_color("berry_leaf"),
		VisualGrammar.harvestable_color("berry_fruit"),
		VisualGrammar.harvestable_color("tree_fruit"),
		VisualGrammar.harvestable_color("flower_petal"),
		VisualGrammar.family_color("amphibian"),
		VisualGrammar.family_color("bird")
	]
	for color: Color in sampled:
		if _max_channel(color) > 0.72:
			return false
	var marker_fill := VisualGrammar.harvestable_color("marker_fill", 0.22)
	var habitat_accent := VisualGrammar.habitat_accent_color(0, 0.65)
	var ecology_control := VisualGrammar.ecology_zone_color("blue_control", 0.34)
	return absf(marker_fill.a - 0.22) < 0.001 \
		and _max_channel(marker_fill) <= 0.14 \
		and absf(habitat_accent.a - 0.65) < 0.001 \
		and absf(ecology_control.a - 0.34) < 0.001 \
		and _max_channel(habitat_accent) <= 0.42 \
		and _max_channel(ecology_control) <= 0.42

func _visual_constitution_palette_matches(palette: Dictionary) -> bool:
	return _color_matches(palette["land_dark"], Color(0.16, 0.19, 0.11)) \
		and _color_matches(palette["land"], Color(0.22, 0.26, 0.15)) \
		and _color_matches(palette["moss"], Color(0.33, 0.38, 0.21)) \
		and _color_matches(palette["mud_dark"], Color(0.19, 0.14, 0.09)) \
		and _color_matches(palette["mud"], Color(0.33, 0.24, 0.14)) \
		and _color_matches(palette["reed"], Color(0.42, 0.44, 0.24)) \
		and _color_matches(palette["water_deep"], Color(0.07, 0.17, 0.22)) \
		and _color_matches(palette["water_shallow"], Color(0.16, 0.30, 0.28)) \
		and _color_matches(palette["water_foam"], Color(0.62, 0.70, 0.62, 0.7)) \
		and _color_matches(palette["shadow"], Color(0.04, 0.05, 0.03, 0.35))

func _color_matches(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < 0.001 \
		and absf(actual.g - expected.g) < 0.001 \
		and absf(actual.b - expected.b) < 0.001 \
		and absf(actual.a - expected.a) < 0.001

func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _max_channel(color: Color) -> float:
	return maxf(maxf(color.r, color.g), color.b)

func _animal_zones_ok(terrain: RefCounted, zones: Array) -> bool:
	if zones.size() != 10:
		return false
	var expected := {
		"A": {"center": Vector2(-137.0, -58.0), "radius": Vector2(38.0, 19.0), "creatures": ["newt", "great_blue_heron", "water_snake", "water_shrew", "crayfish"], "boss": false},
		"B": {"center": Vector2(-92.0, 45.0), "radius": Vector2(43.0, 23.0), "creatures": ["bullfrog", "owl", "beaver", "snapping_turtle", "leeches"], "boss": false},
		"C": {"center": Vector2(-132.0, 8.0), "radius": Vector2(39.0, 22.0), "creatures": ["chorus_frog", "alligator", "duck", "fireflies", "mink"], "boss": false},
		"D": {"center": Vector2(-64.0, -45.0), "radius": Vector2(38.0, 22.0), "creatures": ["cane_toad", "bog_turtle", "kingfisher", "otter", "mosquitos"], "boss": false},
		"Boss": {"center": Vector2(-48.0, 18.0), "radius": Vector2(35.0, 28.0), "creatures": [], "boss": true}
	}
	for group: String in expected.keys():
		var blue_zone := _zone_by_side_group(zones, "blue", group)
		var red_zone := _zone_by_side_group(zones, "red", group)
		if blue_zone.is_empty() or red_zone.is_empty():
			return false
		var spec: Dictionary = expected[group]
		var center: Vector2 = spec["center"]
		var radius: Vector2 = spec["radius"]
		if blue_zone.get("center_units", Vector2.ZERO) != center or red_zone.get("center_units", Vector2.ZERO) != Vector2(-center.x, center.y):
			return false
		if blue_zone.get("radius_units", Vector2.ZERO) != radius or red_zone.get("radius_units", Vector2.ZERO) != radius:
			return false
		if not _zone_water_source_ok(terrain, blue_zone) or not _zone_water_source_ok(terrain, red_zone):
			return false
		if bool(blue_zone.get("boss", false)) != bool(spec["boss"]) or bool(red_zone.get("boss", false)) != bool(spec["boss"]):
			return false
		if bool(spec["boss"]) and (int(blue_zone.get("breed_activation_count", 0)) != 5 or int(red_zone.get("breed_activation_count", 0)) != 5):
			return false
		if not _arrays_equal(blue_zone.get("creatures", []), spec["creatures"]) or not _arrays_equal(red_zone.get("creatures", []), spec["creatures"]):
			return false
	return true

func _zone_water_source_ok(terrain: RefCounted, zone: Dictionary) -> bool:
	var center: Vector2 = zone.get("center_units", Vector2.ZERO)
	var radius: Vector2 = zone.get("radius_units", Vector2.ZERO)
	var water_center: Vector2 = zone.get("water_center_units", Vector2(1.0e20, 1.0e20))
	var water_radius: Vector2 = zone.get("water_radius_units", Vector2.ZERO)
	if water_radius.x < 6.0 or water_radius.y < 4.0:
		return false
	var normalized := Vector2((water_center.x - center.x) / radius.x, (water_center.y - center.y) / radius.y)
	if normalized.length() > 1.0:
		return false
	return terrain.get_zone_at(zone.get("water_center", Vector2.ZERO)) == TerrainMapScript.WATER

func _bridge_rects_ok(terrain: RefCounted, bridge_rects: Array) -> bool:
	var unit := SimConstants.UNIT_PX
	if bridge_rects.size() != 2:
		return false
	var expected := [
		Rect2(Vector2(-24.0, -48.0), Vector2(48.0, 13.0)),
		Rect2(Vector2(-24.0, 48.0), Vector2(48.0, 13.0))
	]
	for i in expected.size():
		var rect: Rect2 = bridge_rects[i]
		var rect_units := Rect2(rect.position / unit, rect.size / unit)
		if rect_units != expected[i]:
			return false
		if terrain.get_zone_at(rect.get_center()) != TerrainMapScript.LAND:
			return false
		if terrain.get_zone_at(rect.get_center() + Vector2(0.0, -10.0 * unit)) != TerrainMapScript.WATER \
			and terrain.get_zone_at(rect.get_center() + Vector2(0.0, 10.0 * unit)) != TerrainMapScript.WATER:
			return false
	return true

func _animal_zones_clear_hut_patrols(terrain: RefCounted) -> bool:
	var unit := SimConstants.UNIT_PX
	var patrol_units := MinionScript.DEFENDER_PATROL_RADIUS / unit
	var hut_centers: Array[Vector2] = []
	for team in [0, 1]:
		for hut_position: Vector2 in terrain.hut_positions[team]:
			hut_centers.append(hut_position / unit)
	for zone: Dictionary in terrain.get_animal_zones():
		var center: Vector2 = zone.get("center_units", Vector2.ZERO)
		var radius: Vector2 = zone.get("radius_units", Vector2.ZERO)
		for hut_center: Vector2 in hut_centers:
			var expanded := Vector2(radius.x + patrol_units, radius.y + patrol_units)
			var normalized := Vector2((hut_center.x - center.x) / expanded.x, (hut_center.y - center.y) / expanded.y)
			if normalized.length() <= 1.0:
				return false
	return true

func _food_resources_ok(food_entries: Array) -> bool:
	var counts := {}
	var critter_count := 0
	var blue_plants: Array[Dictionary] = []
	for entry in food_entries:
		if String(entry.get("kind", "")) != "plant":
			if String(entry.get("kind", "")) == "critter":
				critter_count += 1
				if absf(float(entry.get("food_value", 0.0)) - 24.0) > 0.001:
					return false
			continue
		var side := String(entry.get("side", ""))
		var plant_type := String(entry.get("plant_type", ""))
		if not ["blue", "red"].has(side) or not ["berry", "tree", "seed", "flower"].has(plant_type):
			return false
		var count_key := "%s:%s" % [side, plant_type]
		counts[count_key] = int(counts.get(count_key, 0)) + 1
		if side == "blue":
			blue_plants.append(entry)
		var expected_hits := 3 if plant_type == "tree" else 1
		if int(entry.get("harvest_hits", 0)) != expected_hits:
			return false
		var expected_food_value := 44.0 if plant_type == "tree" else 24.0
		if absf(float(entry.get("food_value", 0.0)) - expected_food_value) > 0.001:
			return false
	for side in ["blue", "red"]:
		for plant_type in ["berry", "tree", "seed", "flower"]:
			var count_key := "%s:%s" % [side, plant_type]
			if int(counts.get(count_key, 0)) != 10:
				return false
	for blue_entry: Dictionary in blue_plants:
		if not _has_mirrored_food_entry(food_entries, blue_entry):
			return false
	return critter_count >= 8 and _plant_scatter_ok(blue_plants)

func _plant_scatter_ok(blue_plants: Array[Dictionary]) -> bool:
	if blue_plants.size() != 40:
		return false
	var unit := SimConstants.UNIT_PX
	for i in blue_plants.size():
		var plant: Dictionary = blue_plants[i]
		var nearest: Array[Dictionary] = blue_plants.duplicate()
		nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var plant_position: Vector2 = plant.get("position", Vector2.ZERO)
			return plant_position.distance_squared_to(a.get("position", Vector2.ZERO)) < plant_position.distance_squared_to(b.get("position", Vector2.ZERO))
		)
		var nearby_types := {}
		for n in mini(4, nearest.size()):
			nearby_types[String(nearest[n].get("plant_type", ""))] = true
		if nearby_types.size() < 2:
			return false
		for j in range(i + 1, blue_plants.size()):
			var other: Dictionary = blue_plants[j]
			var plant_position: Vector2 = plant.get("position", Vector2.ZERO)
			var other_position: Vector2 = other.get("position", Vector2.ZERO)
			var distance_units := plant_position.distance_to(other_position) / unit
			if distance_units < 12.0:
				return false
	var spatial_order: Array[Dictionary] = blue_plants.duplicate()
	spatial_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("position", Vector2.ZERO).x < b.get("position", Vector2.ZERO).x
	)
	var previous_type := ""
	var run_length := 0
	for plant: Dictionary in spatial_order:
		var plant_type := String(plant.get("plant_type", ""))
		if plant_type == previous_type:
			run_length += 1
		else:
			previous_type = plant_type
			run_length = 1
		if run_length > 2:
			return false
	return true

func _environmental_obstacles_ok(obstacles: Array) -> bool:
	if obstacles.size() < 20:
		return false
	var type_counts := {}
	var blue_obstacles: Array[Dictionary] = []
	for obstacle: Dictionary in obstacles:
		var side := String(obstacle.get("side", ""))
		var obstacle_type := String(obstacle.get("type", ""))
		if not ["blue", "red"].has(side) or not ["tree", "rock", "bush"].has(obstacle_type):
			return false
		type_counts[obstacle_type] = int(type_counts.get(obstacle_type, 0)) + 1
		if side == "blue":
			blue_obstacles.append(obstacle)
	for obstacle_type in ["tree", "rock", "bush"]:
		if int(type_counts.get(obstacle_type, 0)) != 10:
			return false
	for blue_obstacle: Dictionary in blue_obstacles:
		if not _has_mirrored_obstacle(obstacles, blue_obstacle):
			return false
	return true

func _zone_by_side_group(zones: Array, side: String, group: String) -> Dictionary:
	for zone: Dictionary in zones:
		if String(zone.get("side", "")) == side and String(zone.get("group", "")) == group:
			return zone
	return {}

func _arrays_equal(actual_value: Variant, expected_value: Variant) -> bool:
	var actual: Array = actual_value as Array
	var expected: Array = expected_value as Array
	if actual.size() != expected.size():
		return false
	for i in expected.size():
		if actual[i] != expected[i]:
			return false
	return true

func _has_mirrored_food_entry(food_entries: Array, blue_entry: Dictionary) -> bool:
	var position: Vector2 = blue_entry.get("position", Vector2.ZERO)
	var mirrored_position := Vector2(-position.x, position.y)
	for entry: Dictionary in food_entries:
		if String(entry.get("side", "")) != "red" or String(entry.get("kind", "")) != String(blue_entry.get("kind", "")):
			continue
		if String(entry.get("plant_type", "")) != String(blue_entry.get("plant_type", "")):
			continue
		if entry.get("position", Vector2.ZERO) == mirrored_position:
			return true
	return false

func _has_mirrored_obstacle(obstacles: Array, blue_obstacle: Dictionary) -> bool:
	var rect: Rect2 = blue_obstacle.get("rect_units", Rect2())
	var mirrored_rect := Rect2(Vector2(-rect.position.x - rect.size.x, rect.position.y), rect.size)
	for obstacle: Dictionary in obstacles:
		if String(obstacle.get("side", "")) != "red" or String(obstacle.get("type", "")) != String(blue_obstacle.get("type", "")):
			continue
		if obstacle.get("rect_units", Rect2()) == mirrored_rect:
			return true
	return false
