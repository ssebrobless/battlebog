extends Control

const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")

const PREVIEW_REFERENCE_RADIUS_UNITS := 1.6
const PREVIEW_MAX_RADIUS_FRACTION := 0.31
const PREVIEW_MIN_RADIUS_FRACTION := 0.09
const PREVIEW_CAPSULE_MAX_SPAN_FRACTION := 0.68

var hero_id := "snapping_turtle"
var team := 0

func set_hero(next_hero_id: String, next_team := 0) -> void:
	hero_id = next_hero_id
	team = next_team
	queue_redraw()

func set_creature(next_creature_id: String, next_team := 0) -> void:
	set_hero(next_creature_id, next_team)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.07, 0.085, 0.095))
	draw_rect(rect, Color(0.22, 0.28, 0.31), false, 2.0)
	draw_line(Vector2(0.0, size.y - 18.0), Vector2(size.x, size.y - 18.0), Color(0.13, 0.16, 0.17), 2.0)

	var center := size * 0.5 + Vector2(0.0, 10.0)
	var footprint := _preview_footprint()
	var radius := float(footprint["radius_px"])
	var length_px := float(footprint["length_px"])
	var is_capsule := String(footprint["shape"]) == "capsule"
	var max_radius := float(footprint["reference_radius_px"])
	var team_ring := VisualGrammar.team_color(team)
	team_ring.a = 0.42
	draw_arc(center, max_radius + 3.0, 0.0, TAU, 44, Color(0.62, 0.68, 0.62, 0.22), 1.0)
	if is_capsule:
		_draw_capsule_footprint(center, Vector2(0.0, -1.0), radius, length_px, team_ring)
	else:
		draw_arc(center, radius + 4.0, 0.0, TAU, 44, team_ring, 1.5)
	var preview_state := _preview_motion_state()
	preview_state["origin"] = center
	var visual_time_msec := float(Time.get_ticks_msec())
	preview_state["visual_time_msec"] = visual_time_msec
	preview_state["walk_phase"] = visual_time_msec * 0.004
	VisualStyle.draw_battle_creature(self, hero_id, team, radius, Vector2(0.0, -1.0), 0.0, 1.0, bool(preview_state.get("airborne_preview", false)), preview_state)

func _process(_delta: float) -> void:
	queue_redraw()

func _preview_footprint() -> Dictionary:
	var min_dimension := minf(size.x, size.y)
	var max_radius := min_dimension * PREVIEW_MAX_RADIUS_FRACTION
	var min_radius := min_dimension * PREVIEW_MIN_RADIUS_FRACTION
	var radius_units := 0.6
	var length_units := radius_units * 2.0
	var shape := "circle"
	var catalog := get_node_or_null("/root/CreatureCatalog")
	if catalog != null:
		var creature: Dictionary = catalog.get_creature(hero_id)
		var footprint: Dictionary = creature.get("footprint", {})
		radius_units = float(footprint.get("radius_units", radius_units))
		shape = String(footprint.get("shape", shape))
		length_units = float(footprint.get("length_units", radius_units * 2.0))
	var unit_scale := max_radius / PREVIEW_REFERENCE_RADIUS_UNITS
	if shape == "capsule":
		var available_span := maxf(28.0, minf(size.x, maxf(size.y - 36.0, 36.0)) * PREVIEW_CAPSULE_MAX_SPAN_FRACTION)
		unit_scale = minf(unit_scale, available_span / maxf(length_units, 0.1))
	var radius_px := clampf(radius_units * unit_scale, min_radius, max_radius)
	var length_px := maxf(length_units * unit_scale, radius_px * 2.0)
	return {
		"shape": shape,
		"radius_px": radius_px,
		"length_px": length_px,
		"reference_radius_px": max_radius
	}

func _preview_motion_state() -> Dictionary:
	var profile := CreatureScript.visual_size_profile_for(hero_id)
	var airborne_preview := _is_airborne_preview(profile)
	var base_height := float(profile.get("height_units", 0.45))
	var height_units := base_height
	if airborne_preview:
		height_units = maxf(base_height, float(profile.get("flight_height_units", base_height + 0.45)))
	var model_scale := float(profile.get("model_scale", 1.0))
	return {
		"moving": true,
		"model_scale": model_scale,
		"base_model_scale": model_scale,
		"height_units": height_units,
		"height_class": String(profile.get("height_class", "mid")),
		"height_band": CreatureScript.visual_height_band_for(height_units),
		"airborne_preview": airborne_preview,
		"height_shadow_alpha": _preview_height_shadow_alpha(height_units, airborne_preview),
		"height_shadow_radius_mult": _preview_height_shadow_radius_mult(height_units, airborne_preview)
	}

func _is_airborne_preview(profile: Dictionary) -> bool:
	var height_class := String(profile.get("height_class", ""))
	if height_class in ["raptor", "small_diver", "swarm", "tiny_hoverer"]:
		return true
	return false

func _preview_height_shadow_alpha(height_units: float, airborne_preview: bool) -> float:
	if not airborne_preview:
		return 0.0
	var height_t := clampf(height_units / 1.8, 0.0, 1.0)
	return clampf(0.34 - height_t * 0.12, 0.12, 0.5)

func _preview_height_shadow_radius_mult(height_units: float, airborne_preview: bool) -> float:
	if not airborne_preview:
		return 1.0
	var height_t := clampf(height_units / 1.8, 0.0, 1.0)
	return clampf(0.78 + height_t * 0.12, 0.75, 1.18)

func _draw_capsule_footprint(center: Vector2, forward: Vector2, radius: float, length: float, color: Color) -> void:
	var capsule_color := VisualGrammar.with_alpha(color, 0.32)
	var edge_color := VisualGrammar.with_alpha(color.lightened(0.35), 0.65)
	var direction := forward.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	var half_body := maxf((length - radius * 2.0) * 0.5, 0.0)
	var cap_a := center - direction * half_body
	var cap_b := center + direction * half_body
	var body := PackedVector2Array([
		cap_a + side * radius,
		cap_b + side * radius,
		cap_b - side * radius,
		cap_a - side * radius
	])
	draw_colored_polygon(body, capsule_color)
	draw_circle(cap_a, radius, capsule_color)
	draw_circle(cap_b, radius, capsule_color)
	draw_arc(cap_a, radius + 3.0, 0.0, TAU, 32, edge_color, 1.4)
	draw_arc(cap_b, radius + 3.0, 0.0, TAU, 32, edge_color, 1.4)
	draw_line(cap_a + side * (radius + 3.0), cap_b + side * (radius + 3.0), edge_color, 1.4)
	draw_line(cap_a - side * (radius + 3.0), cap_b - side * (radius + 3.0), edge_color, 1.4)
	draw_line(cap_a, cap_b, VisualGrammar.with_alpha(Color(1.0, 1.0, 1.0), 0.18), 1.0)
