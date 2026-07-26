extends SceneTree

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/CharacterSelect.tscn"
const ARENA_SCENE := "res://scenes/Arena.tscn"
const DucklingScript := preload("res://scripts/sim/pets/duckling.gd")
const SpiderlingScript := preload("res://scripts/sim/pets/spiderling.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures: Array[String] = []
	var main_ok: bool = await _check_main_menu(failures)
	var select_ok: bool = await _check_character_select(failures)
	var play_vs_ai_ok: bool = await _check_arena_mode("1v1", 3, 3, 4, 12, 20.0, 105.0, 2.6, failures)
	var arena_3v3_ok: bool = await _check_arena_mode("3v3", 0, 5, 4, 12, 20.0, 105.0, 2.2, failures)
	var hero_lab_ok: bool = await _check_arena_mode("Hero Lab", 0, 1, 4, 12, 18.0, 105.0, 2.8, failures)
	var passed := main_ok and select_ok and play_vs_ai_ok and arena_3v3_ok and hero_lab_ok

	print("scene_boot main=%s select=%s play_vs_ai_canonical=%s arena_3v3=%s hero_lab=%s" % [
		str(main_ok),
		str(select_ok),
		str(play_vs_ai_ok),
		str(arena_3v3_ok),
		str(hero_lab_ok)
	])
	for failure in failures:
		push_error(failure)
	quit(0 if passed else 1)

func _check_main_menu(failures: Array[String]) -> bool:
	var scene: Node = await _boot_scene(MAIN_MENU_SCENE, failures)
	if scene == null:
		return false
	var ok := _node_exists(scene, "Panel/VBox/OneVOneButton", failures) and _node_exists(scene, "Panel/VBox/ThreeVThreeButton", failures) and _node_exists(scene, "Panel/VBox/HeroLabButton", failures)
	if not ok:
		failures.append("MainMenu booted but expected mode buttons were missing.")
	return ok

func _check_character_select(failures: Array[String]) -> bool:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_creature("snapping_turtle")

	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog != null and not catalog.load_catalog():
		failures.append("CreatureCatalog failed to load before CharacterSelect boot.")
		return false

	var scene: Node = await _boot_scene(CHARACTER_SELECT_SCENE, failures)
	if scene == null:
		return false

	var hero_list := scene.get_node_or_null("Root/Content/HeroScroll/HeroList")
	var start_button := scene.get_node_or_null("Root/Footer/StartButton")
	var back_button := scene.get_node_or_null("Root/Footer/BackButton")
	var has_selectables := false
	if hero_list != null:
		for child in hero_list.get_children():
			if child is Button and bool(child.get_meta("selectable", false)):
				has_selectables = true
				break

	var ok := hero_list != null and start_button != null and back_button != null and has_selectables
	if not ok:
		failures.append("CharacterSelect expected hero list, footer buttons, and at least one selectable creature; hero_list=%s start=%s back=%s selectable=%s" % [
			str(hero_list != null),
			str(start_button != null),
			str(back_button != null),
			str(has_selectables)
		])
	return ok

func _check_arena_mode(mode: String, expected_squad_size: int, expected_bot_count: int, expected_hut_count: int, expected_lane_minions: int, expected_wave_interval: float, expected_hunger_sec: float, expected_camera_zoom: float, failures: Array[String]) -> bool:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = mode
		config.set_selected_creature("snapping_turtle")
		if config.has_method("set_selected_squad_ids"):
			var squad_ids: Array[String] = ["snapping_turtle", "chorus_frog", "mink"]
			config.set_selected_squad_ids(squad_ids)

	var scene: Node = await _boot_scene(ARENA_SCENE, failures)
	if scene == null:
		return false

	var squad: Array = scene.get("player_squad")
	var bots: Array = scene.get("bots")
	var cores: Dictionary = scene.get("cores")
	var huts: Array = scene.get("huts")
	var minions: Array = scene.get("minions")
	var player: Node = scene.get("player")
	var camera: Camera2D = scene.get("camera")
	var status_label: Label = scene.get("status_label")
	var minimap: Node = scene.find_child("Minimap", true, false)
	var terrain_layer: Node = scene.find_child("TerrainLayer", false, false)
	var water_layer: Node = scene.find_child("WaterLayer", false, false)
	var lane_minions := _count_lane_minions(minions)
	var wave_interval := float(scene.get("wave_interval"))
	var hunger_sec := float(scene.get_hunger_full_to_empty_sec()) if scene.has_method("get_hunger_full_to_empty_sec") else -1.0
	var camera_zoom := camera.zoom.x if camera != null else -1.0
	var minimap_backdrop_ok := minimap != null and minimap.has_method("has_static_backdrop") and bool(minimap.call("has_static_backdrop"))
	var terrain_layer_ok := terrain_layer != null and terrain_layer.has_method("is_static_cached_layer") and bool(terrain_layer.call("is_static_cached_layer"))
	var shoreline_ok := terrain_layer != null and terrain_layer.has_method("has_shoreline_treatment") and bool(terrain_layer.call("has_shoreline_treatment"))
	var edge_detail_ok := terrain_layer != null and terrain_layer.has_method("uses_edge_detail_budget") and bool(terrain_layer.call("uses_edge_detail_budget"))
	var prop_treatment_ok := terrain_layer != null and terrain_layer.has_method("has_environmental_prop_treatment") and bool(terrain_layer.call("has_environmental_prop_treatment"))
	var habitat_ground_ok := terrain_layer != null and terrain_layer.has_method("has_habitat_ground_treatment") and bool(terrain_layer.call("has_habitat_ground_treatment"))
	var habitat_beacons_ok := terrain_layer != null and terrain_layer.has_method("has_habitat_beacon_treatment") and bool(terrain_layer.call("has_habitat_beacon_treatment"))
	var status_text := String(scene.call("get_status_hud_text")) if scene.has_method("get_status_hud_text") else ""
	var arena_presentation_ok := scene.has_method("uses_diegetic_habitat_markers") \
		and bool(scene.call("uses_diegetic_habitat_markers")) \
		and scene.has_method("uses_diegetic_stock_reserve_tokens") \
		and bool(scene.call("uses_diegetic_stock_reserve_tokens")) \
		and scene.has_method("uses_throttled_world_overlay_redraw") \
		and bool(scene.call("uses_throttled_world_overlay_redraw")) \
		and scene.has_method("get_world_overlay_redraw_interval") \
		and float(scene.call("get_world_overlay_redraw_interval")) >= 0.05
	var status_readability_ok := not status_text.is_empty() and status_text.contains("\n") and not status_text.contains(" | ")
	var debug_hurtbox_ok := _check_debug_hurtbox_overlay(scene)
	var water_layer_ok := water_layer != null \
		and water_layer.has_method("get_redraw_interval") \
		and water_layer.has_method("get_ripple_count") \
		and water_layer.has_method("uses_expanding_ripple_arcs") \
		and water_layer.has_method("get_animation_primitive_budget_per_origin") \
		and float(water_layer.call("get_redraw_interval")) >= 0.05 \
		and int(water_layer.call("get_ripple_count")) > 0 \
		and bool(water_layer.call("uses_expanding_ripple_arcs")) \
		and int(water_layer.call("get_animation_primitive_budget_per_origin")) <= 3
	var collision_hygiene_ok := _check_collision_hygiene(scene, failures)
	var renderer_ok := _check_renderer_mode()
	var expectation_label := "canonical competitive parity" if mode == "1v1" else "implemented mode"

	var ok := squad.size() == expected_squad_size \
		and bots.size() == expected_bot_count \
		and cores.size() == 2 \
		and huts.size() == expected_hut_count \
		and lane_minions == expected_lane_minions \
		and absf(wave_interval - expected_wave_interval) < 0.001 \
		and absf(hunger_sec - expected_hunger_sec) < 0.001 \
		and absf(camera_zoom - expected_camera_zoom) < 0.001 \
		and player != null \
		and camera != null \
		and status_label != null \
		and minimap != null \
		and minimap.has_method("has_static_backdrop") \
		and minimap_backdrop_ok \
		and terrain_layer_ok \
		and shoreline_ok \
		and edge_detail_ok \
		and prop_treatment_ok \
		and habitat_ground_ok \
		and habitat_beacons_ok \
		and arena_presentation_ok \
		and status_readability_ok \
		and debug_hurtbox_ok \
		and water_layer_ok \
		and collision_hygiene_ok \
		and renderer_ok
	if not ok:
		failures.append("Arena %s failed %s expectations: squad=%d bots=%d cores=2 huts=%d lane_minions=%d wave=%.1f hunger=%.1f zoom=%.1f plus player/camera/status/minimap/static terrain/shoreline/edge detail/props/habitat ground/beacons/presentation/status text/debug hurtbox/water/collision hygiene/mobile renderer; got squad=%d bots=%d cores=%d huts=%d lane_minions=%d wave=%.1f hunger=%.1f zoom=%.1f player=%s camera=%s status=%s minimap=%s backdrop=%s terrain=%s shoreline=%s edge_detail=%s props=%s habitat_ground=%s beacons=%s presentation=%s status_text=%s debug_hurtbox=%s water=%s collision=%s renderer=%s" % [
			mode,
			expectation_label,
			expected_squad_size,
			expected_bot_count,
			expected_hut_count,
			expected_lane_minions,
			expected_wave_interval,
			expected_hunger_sec,
			expected_camera_zoom,
			squad.size(),
			bots.size(),
			cores.size(),
			huts.size(),
			lane_minions,
			wave_interval,
			hunger_sec,
			camera_zoom,
			str(player != null),
			str(camera != null),
			str(status_label != null),
			str(minimap != null),
			str(minimap_backdrop_ok),
			str(terrain_layer_ok),
			str(shoreline_ok),
			str(edge_detail_ok),
			str(prop_treatment_ok),
			str(habitat_ground_ok),
			str(habitat_beacons_ok),
			str(arena_presentation_ok),
			str(status_readability_ok),
			str(debug_hurtbox_ok),
			str(water_layer_ok),
			str(collision_hygiene_ok),
			str(renderer_ok)
		])
	return ok

func _check_renderer_mode() -> bool:
	var rendering_method: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var mobile_method: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	return rendering_method == "mobile" and mobile_method == "mobile"

func _check_debug_hurtbox_overlay(scene: Node) -> bool:
	if scene == null \
		or not scene.has_method("has_debug_hurtbox_overlay_contract") \
		or not bool(scene.call("has_debug_hurtbox_overlay_contract")) \
		or not scene.has_method("get_hurtbox_debug_overlays"):
		return false
	var overlays: Array = scene.call("get_hurtbox_debug_overlays")
	var hull_ok := false
	var region_ok := false
	for overlay_value in overlays:
		if typeof(overlay_value) != TYPE_DICTIONARY:
			continue
		var overlay: Dictionary = overlay_value
		match String(overlay.get("type", "")):
			"hull":
				hull_ok = hull_ok \
					or (overlay.get("center", Vector2.INF) is Vector2 \
					and float(overlay.get("radius", 0.0)) > 0.0 \
					and String(overlay.get("shape", "")) in ["circle", "capsule"])
			"region":
				region_ok = region_ok \
					or (String(overlay.get("region", "")) != "" \
					and overlay.get("center", Vector2.INF) is Vector2 \
					and float(overlay.get("radius", 0.0)) > 0.0 \
					and float(overlay.get("region_mult", 0.0)) >= 0.75)
	return hull_ok and region_ok

func _check_collision_hygiene(scene: Node, failures: Array[String]) -> bool:
	var movers_ok := true
	var physics_movers: Array[Node] = []
	var player: Node = scene.get("player")
	if player != null and is_instance_valid(player):
		physics_movers.append(player)
	var squad: Array = scene.get("player_squad")
	for member in squad:
		if member != null and is_instance_valid(member) and not physics_movers.has(member):
			physics_movers.append(member)
	var bots: Array = scene.get("bots")
	for bot in bots:
		if bot != null and is_instance_valid(bot):
			physics_movers.append(bot)
	for mover in physics_movers:
		if not (mover is CharacterBody2D) or int(mover.collision_layer) != 0 or int(mover.collision_mask) != 0:
			movers_ok = false
	var minions_ok := true
	for minion in scene.get("minions"):
		if minion != null and is_instance_valid(minion) and minion is CharacterBody2D:
			minions_ok = false
	var pets_ok := _check_pet_collision_hygiene(scene, player)
	if not movers_ok or not minions_ok or not pets_ok:
		failures.append("scripted movers should stay out of Godot physics collision layers; movers_ok=%s minions_ok=%s pets_ok=%s movers=%s" % [
			str(movers_ok),
			str(minions_ok),
			str(pets_ok),
			str(physics_movers)
		])
	return movers_ok and minions_ok and pets_ok

func _check_pet_collision_hygiene(scene: Node, owner: Node) -> bool:
	var duckling := DucklingScript.new()
	scene.add_child(duckling)
	duckling.setup(scene, owner, 0, Vector2.ZERO, 0, 80.0)
	var duckling_ok: bool = int(duckling.collision_layer) == 0 and int(duckling.collision_mask) == 0
	duckling.queue_free()
	var spiderling := SpiderlingScript.new()
	scene.add_child(spiderling)
	spiderling.setup(scene, owner, 0, Vector2.ZERO)
	var spiderling_ok: bool = int(spiderling.collision_layer) == 0 and int(spiderling.collision_mask) == 0
	spiderling.queue_free()
	return duckling_ok and spiderling_ok

func _count_lane_minions(minions: Array) -> int:
	var count := 0
	for minion in minions:
		if minion != null and is_instance_valid(minion) and String(minion.get("kind")) == "lane":
			count += 1
	return count

func _boot_scene(scene_path: String, failures: Array[String]) -> Node:
	var error := change_scene_to_file(scene_path)
	if error != OK:
		failures.append("failed to change scene to %s: error=%d" % [scene_path, error])
		return null
	await process_frame
	await process_frame
	if current_scene == null:
		failures.append("scene %s did not become current_scene after two frames." % scene_path)
	return current_scene

func _node_exists(root: Node, path: NodePath, failures: Array[String]) -> bool:
	if root.get_node_or_null(path) != null:
		return true
	failures.append("missing node %s under %s" % [str(path), root.name])
	return false
