extends RefCounted

# Creature rendering: shared body-base archetypes reskinned per creature.
# Combat footprint remains the source of truth; render scale/height metadata
# can adjust silhouettes for readability without changing collision.

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

# base: which body archetype draws this creature.
# main/dark/accent/belly: real-life palette. Extra keys tune the base.
const SKINS := {
	"bullfrog": {"base": "frog", "main": Color(0.3, 0.45, 0.18), "dark": Color(0.18, 0.28, 0.1), "belly": Color(0.62, 0.66, 0.42), "eye": Color(0.75, 0.6, 0.25), "strike": "tongue", "tympanum": true},
	"chorus_frog": {"base": "frog", "main": Color(0.36, 0.42, 0.2), "dark": Color(0.2, 0.25, 0.11), "belly": Color(0.6, 0.62, 0.44), "eye": Color(0.82, 0.72, 0.35), "strike": "tongue", "stripes": true, "call_sac": true},
	"cane_toad": {"base": "frog", "main": Color(0.46, 0.36, 0.2), "dark": Color(0.28, 0.21, 0.11), "belly": Color(0.66, 0.58, 0.42), "eye": Color(0.7, 0.55, 0.2), "strike": "tongue", "warts": true},
	"newt": {"base": "mustelid", "main": Color(0.3, 0.2, 0.13), "dark": Color(0.19, 0.12, 0.08), "accent": Color(0.92, 0.5, 0.14), "tail": "fin", "smooth": true, "spots": true},
	"snapping_turtle": {"base": "turtle", "shell": Color(0.26, 0.3, 0.16), "rim": Color(0.18, 0.21, 0.11), "skin": Color(0.45, 0.4, 0.24), "keels": true, "lunge_scale": 0.2},
	"water_snake": {"base": "serpent", "main": Color(0.36, 0.26, 0.15), "dark": Color(0.2, 0.14, 0.09), "belly": Color(0.6, 0.5, 0.34)},
	"bog_turtle": {"base": "turtle", "shell": Color(0.26, 0.2, 0.12), "rim": Color(0.16, 0.12, 0.07), "skin": Color(0.34, 0.28, 0.18), "neck_patch": Color(0.95, 0.55, 0.12), "lunge_scale": 0.2},
	"alligator": {"base": "croc", "main": Color(0.2, 0.26, 0.17), "dark": Color(0.12, 0.16, 0.1), "belly": Color(0.5, 0.52, 0.4)},
	"owl": {"base": "bird", "main": Color(0.42, 0.32, 0.22), "dark": Color(0.26, 0.19, 0.13), "breast": Color(0.62, 0.54, 0.42), "beak": Color(0.75, 0.65, 0.4), "beak_len": 0.25, "tufts": true, "facial_disc": true, "head_scale": 1.45, "barred": true},
	"great_blue_heron": {"base": "bird", "main": Color(0.44, 0.5, 0.56), "dark": Color(0.26, 0.31, 0.36), "breast": Color(0.68, 0.7, 0.72), "beak": Color(0.85, 0.7, 0.3), "beak_len": 0.95, "neck": 0.7},
	"kingfisher": {"base": "bird", "main": Color(0.14, 0.44, 0.68), "dark": Color(0.08, 0.26, 0.42), "breast": Color(0.85, 0.5, 0.2), "beak": Color(0.15, 0.13, 0.12), "beak_len": 0.7},
	"duck": {"base": "bird", "main": Color(0.4, 0.32, 0.24), "dark": Color(0.24, 0.19, 0.14), "breast": Color(0.55, 0.45, 0.36), "beak": Color(0.85, 0.72, 0.2), "beak_len": 0.45, "flat_bill": true, "head_color": Color(0.1, 0.38, 0.2)},
	"water_shrew": {"base": "mustelid", "main": Color(0.16, 0.16, 0.18), "dark": Color(0.1, 0.1, 0.12), "belly": Color(0.55, 0.55, 0.5), "snout": 1.4, "bulk": 0.9},
	"beaver": {"base": "mustelid", "main": Color(0.36, 0.23, 0.12), "dark": Color(0.22, 0.14, 0.07), "tail": "paddle", "bulk": 1.25},
	"otter": {"base": "mustelid", "main": Color(0.4, 0.28, 0.16), "dark": Color(0.26, 0.18, 0.1), "belly": Color(0.6, 0.5, 0.36), "tail": "thick", "bulk": 1.05},
	"mink": {"base": "mustelid", "main": Color(0.24, 0.14, 0.09), "dark": Color(0.17, 0.1, 0.06), "belly": Color(0.93, 0.9, 0.82), "tail": "bushy"},
	"leech": {"base": "cluster", "main": Color(0.27, 0.11, 0.08), "dark": Color(0.16, 0.06, 0.05)},
	"crayfish": {"base": "crustacean", "main": Color(0.5, 0.2, 0.1), "dark": Color(0.32, 0.12, 0.06)},
	"mosquito_swarm": {"base": "swarm", "main": Color(0.4, 0.4, 0.42), "dark": Color(0.2, 0.2, 0.22)},
	"wolf_spider": {"base": "spider", "main": Color(0.3, 0.22, 0.12), "dark": Color(0.18, 0.13, 0.07), "accent": Color(0.55, 0.45, 0.3)},
	"firefly": {"base": "bug", "main": Color(0.22, 0.16, 0.1), "dark": Color(0.12, 0.09, 0.06), "glow": Color(0.95, 0.9, 0.4)}
}

const SILHOUETTE_CONTRACTS := {
	"frog": {"filled_mass_mult": 0.98, "thin_overhang_mult": 1.08, "features": ["squat_body", "leg_arc"]},
	"turtle": {"filled_mass_mult": 1.0, "thin_overhang_mult": 1.12, "features": ["shell_mass", "short_head"]},
	"mustelid": {"filled_mass_mult": 0.96, "thin_overhang_mult": 1.28, "features": ["long_spine", "thin_tail"]},
	"bird": {"filled_mass_mult": 0.88, "thin_overhang_mult": 1.42, "features": ["compact_body", "thin_beak_neck", "thin_wings"]},
	"serpent": {"filled_mass_mult": 0.92, "thin_overhang_mult": 1.55, "features": ["coiled_mass", "thin_body_axis"]},
	"croc": {"filled_mass_mult": 1.04, "thin_overhang_mult": 1.62, "features": ["long_body", "thin_snout_tail"]},
	"crustacean": {"filled_mass_mult": 0.98, "thin_overhang_mult": 1.25, "features": ["low_carapace", "thin_claws"]},
	"spider": {"filled_mass_mult": 0.78, "thin_overhang_mult": 1.42, "features": ["central_body", "thin_legs"]},
	"swarm": {"filled_mass_mult": 0.36, "thin_overhang_mult": 1.18, "features": ["distributed_dots", "readability_cloud"]},
	"cluster": {"filled_mass_mult": 0.94, "thin_overhang_mult": 1.06, "features": ["flat_blob_chain"]},
	"bug": {"filled_mass_mult": 0.72, "thin_overhang_mult": 1.16, "features": ["tiny_body", "glow_shell"]}
}

static func creature_color(creature_id: String) -> Color:
	var skin: Dictionary = SKINS.get(creature_id, {})
	if skin.has("main"):
		return skin["main"]
	if skin.has("shell"):
		return skin["shell"]
	var creature_hash: int = abs(hash(creature_id))
	return Color.from_hsv(float(creature_hash % 360) / 360.0, 0.58, 0.92)

static func creature_silhouette_contract(creature_id: String, body_radius: float, model_scale := 1.0, capsule_half_len_px := 0.0) -> Dictionary:
	var skin: Dictionary = SKINS.get(creature_id, {})
	var base := String(skin.get("base", "blob"))
	var contract: Dictionary = SILHOUETTE_CONTRACTS.get(base, {
		"filled_mass_mult": 1.0,
		"thin_overhang_mult": 1.0,
		"features": ["fallback_blob"]
	})
	var visual_radius := body_radius * clampf(model_scale, 0.72, 1.35)
	var filled_mass_mult := float(contract.get("filled_mass_mult", 1.0))
	var thin_overhang_mult := float(contract.get("thin_overhang_mult", 1.0))
	var footprint_length_px := body_radius * 2.0 + maxf(capsule_half_len_px, 0.0) * 2.0
	var long_body_visual_length_px := visual_radius * thin_overhang_mult * 2.0
	if capsule_half_len_px > 0.0 and (base == "serpent" or base == "croc"):
		long_body_visual_length_px = maxf(long_body_visual_length_px, footprint_length_px)
	return {
		"creature_id": creature_id,
		"archetype": base,
		"silhouette_features": contract.get("features", []),
		"combat_radius_px": body_radius,
		"truth_ring_radius_px": body_radius,
		"visual_radius_px": visual_radius,
		"filled_mass_radius_px": body_radius * filled_mass_mult,
		"filled_mass_radius_mult": filled_mass_mult,
		"wide_filled_overhang_limit_mult": 1.15,
		"thin_overhang_radius_px": body_radius * thin_overhang_mult,
		"thin_overhang_radius_mult": thin_overhang_mult,
		"capsule_half_len_px": maxf(capsule_half_len_px, 0.0),
		"footprint_length_px": footprint_length_px,
		"long_body_visual_length_px": long_body_visual_length_px,
		"contact_shadow_ellipse": true
	}

static func draw_battle_creature(canvas: CanvasItem, creature_id: String, team: int, radius: float, facing: Vector2, flash_alpha := 0.0, alpha := 1.0, airborne := false, anim: Dictionary = {}) -> void:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var alligator_bite_pose := alligator_bite_pose(anim, forward)
	if bool(alligator_bite_pose["active"]):
		forward = alligator_bite_pose["forward"]
	var outline := _with_alpha(VisualGrammar.team_color(team), alpha)
	var skin: Dictionary = SKINS.get(creature_id, {})
	var model_scale := clampf(float(anim.get("model_scale", 1.0)), 0.72, 1.35)
	var visual_radius := maxf(radius * model_scale, radius * 0.5)
	var height_units := maxf(float(anim.get("height_units", 0.45)), 0.0)
	var air_lift_px := maxf(radius * 0.5, height_units * SimConstants.UNIT_PX) if airborne else 0.0
	var low_window_t := clampf(float(anim.get("low_window_t", 0.0)), 0.0, 1.0)
	var readable_air_attack := airborne and bool(anim.get("air_attack_cue_pose", low_window_t > 0.0))
	var air_attack_cue_intensity := clampf(float(anim.get("air_attack_cue_intensity", low_window_t)), 0.0, 1.0) if readable_air_attack else 0.0
	var takeoff_charge_t := clampf(float(anim.get("takeoff_charge_t", 0.0)), 0.0, 1.0)
	var takeoff_flap_t := clampf(float(anim.get("takeoff_flap_t", 0.0)), 0.0, 1.0)
	var landing_flap_t := clampf(float(anim.get("landing_flap_t", 0.0)), 0.0, 1.0)
	var grounded_lockout_t := clampf(float(anim.get("grounded_lockout_t", 0.0)), 0.0, 1.0)
	var terrain_splash_t := clampf(float(anim.get("terrain_splash_t", 0.0)), 0.0, 1.0)
	var terrain_scuff_t := clampf(float(anim.get("terrain_scuff_t", 0.0)), 0.0, 1.0)

	var attack_t := float(anim.get("attack_t", -1.0))
	var windup_t := float(anim.get("windup_t", -1.0))
	var walk_phase := float(anim.get("walk_phase", 0.0))
	var moving := bool(anim.get("moving", false))
	var attack_aim: Vector2 = anim.get("attack_aim", forward)
	if attack_aim == Vector2.ZERO:
		attack_aim = forward
	var attack_reach := float(anim.get("attack_reach", visual_radius * 1.6))
	var off_balance := bool(anim.get("off_balance_pose", false))
	var landing_t := clampf(float(anim.get("landing_t", 0.0)), 0.0, 1.0)
	var landing_impact := clampf(float(anim.get("landing_impact", 0.0)), 0.0, 1.5)

	var body_offset := Vector2.ZERO
	var strike := 0.0
	var lunge_scale := float(skin.get("lunge_scale", 1.0))
	if attack_t >= 0.0:
		strike = _strike_curve(attack_t)
		body_offset = attack_aim.normalized() * maxf(visual_radius * 0.8, 8.0) * strike * lunge_scale
	elif windup_t >= 0.0:
		body_offset = -forward * maxf(visual_radius * 0.4, 6.0) * windup_t * lunge_scale
	elif off_balance:
		body_offset = -forward * maxf(visual_radius * 0.18, 3.0) + Vector2(-forward.y, forward.x) * maxf(visual_radius * 0.12, 2.0)
	if bool(alligator_bite_pose["active"]):
		var pose_side := Vector2(-forward.y, forward.x)
		body_offset = forward * visual_radius * float(alligator_bite_pose["translation_forward"]) \
			+ pose_side * visual_radius * float(alligator_bite_pose["translation_side"])

	var rock := 0.0
	if moving and attack_t < 0.0:
		rock = sin(walk_phase) * 0.1
	if off_balance and attack_t < 0.0 and windup_t < 0.0:
		rock += 0.16
	if bool(alligator_bite_pose["active"]):
		rock = float(alligator_bite_pose["rotation"])
	var rocked_forward := forward.rotated(rock)
	var side := Vector2(-rocked_forward.y, rocked_forward.x)
	var movement_bob := Vector2(0.0, -float(anim.get("movement_bob", 0.0))) if moving and attack_t < 0.0 else Vector2.ZERO

	var origin: Vector2 = anim.get("origin", Vector2.ZERO)
	var shake_offset: Vector2 = origin + anim.get("shake_offset", Vector2.ZERO)
	if takeoff_charge_t > 0.0:
		var charge_color := _with_alpha(Color(0.74, 0.9, 1.0, 0.16 + takeoff_charge_t * 0.22), alpha)
		var charge_radius := visual_radius * (0.92 + takeoff_charge_t * 0.38)
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_arc(Vector2.ZERO, charge_radius, -PI * 0.84, -PI * 0.16, 22, charge_color, maxf(1.5, visual_radius * 0.08))
		canvas.draw_arc(Vector2.ZERO, charge_radius, PI * 0.16, PI * 0.84, 22, charge_color, maxf(1.5, visual_radius * 0.08))
		for wing_side: float in [-1.0, 1.0]:
			canvas.draw_line(
				side * wing_side * visual_radius * (0.72 + takeoff_charge_t * 0.18) - forward * visual_radius * 0.1,
				side * wing_side * visual_radius * (1.12 + takeoff_charge_t * 0.34) - forward * visual_radius * (0.38 + takeoff_charge_t * 0.18),
				Color(charge_color.r, charge_color.g, charge_color.b, charge_color.a * 0.7),
				maxf(1.2, visual_radius * 0.06)
			)
	if grounded_lockout_t > 0.0 and not airborne:
		var lock_color := _with_alpha(Color(1.0, 0.55, 0.25, 0.12 + grounded_lockout_t * 0.18), alpha)
		var lock_radius := visual_radius * (1.2 + (1.0 - grounded_lockout_t) * 0.12)
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		for segment: int in 4:
			var start_angle := float(segment) * PI * 0.5 + PI * 0.08
			canvas.draw_arc(Vector2.ZERO, lock_radius, start_angle, start_angle + PI * 0.27, 10, lock_color, maxf(1.6, visual_radius * 0.08))
	if terrain_splash_t > 0.0 and not airborne:
		var splash_color := _with_alpha(Color(0.48, 0.78, 0.92, 0.18 + terrain_splash_t * 0.22), alpha)
		var splash_radius := visual_radius * (0.86 + (1.0 - terrain_splash_t) * 0.34)
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_arc(Vector2.ZERO, splash_radius, PI * 0.08, PI * 0.92, 22, splash_color, maxf(1.5, visual_radius * 0.08))
		canvas.draw_arc(Vector2.ZERO, splash_radius, PI * 1.08, PI * 1.92, 22, Color(splash_color.r, splash_color.g, splash_color.b, splash_color.a * 0.72), maxf(1.2, visual_radius * 0.06))
		for splash_side: float in [-1.0, 1.0]:
			canvas.draw_line(
				-forward * visual_radius * 0.15 + side * splash_side * visual_radius * 0.45,
				-forward * visual_radius * (0.72 + terrain_splash_t * 0.22) + side * splash_side * visual_radius * (0.88 + terrain_splash_t * 0.18),
				Color(splash_color.r, splash_color.g, splash_color.b, splash_color.a * 0.82),
				maxf(1.1, visual_radius * 0.06)
			)
	if terrain_scuff_t > 0.0 and not airborne:
		var scuff_color := _with_alpha(Color(0.42, 0.32, 0.2, 0.16 + terrain_scuff_t * 0.2), alpha)
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		for scuff_side: float in [-1.0, 1.0]:
			var scuff_center := -forward * visual_radius * 0.38 + side * scuff_side * visual_radius * 0.52
			canvas.draw_arc(scuff_center, visual_radius * (0.24 + terrain_scuff_t * 0.1), PI * 0.08, PI * 0.92, 10, scuff_color, maxf(1.1, visual_radius * 0.06))
			canvas.draw_line(
				scuff_center,
				scuff_center - forward * visual_radius * (0.48 + terrain_scuff_t * 0.2) + side * scuff_side * visual_radius * 0.18,
				Color(scuff_color.r, scuff_color.g, scuff_color.b, scuff_color.a * 0.7),
				maxf(1.0, visual_radius * 0.05)
			)
	if airborne:
		var height_ratio := clampf(air_lift_px / maxf(radius, 1.0), 0.0, 2.4)
		var shadow_alpha := clampf(float(anim.get("height_shadow_alpha", 0.32 - height_ratio * 0.07 + low_window_t * 0.18)), 0.12, 0.5)
		var shadow_radius := visual_radius * clampf(float(anim.get("height_shadow_radius_mult", 0.82 + height_ratio * 0.08 + low_window_t * 0.18)), 0.75, 1.3)
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_circle(Vector2(0.0, visual_radius * 0.55), shadow_radius, _with_alpha(VisualGrammar.shadow_color(shadow_alpha), alpha))
		if takeoff_flap_t > 0.0:
			var lift_color := _with_alpha(Color(0.78, 0.9, 1.0, 0.24 * takeoff_flap_t), alpha)
			var lift_radius := visual_radius * (1.05 + (1.0 - takeoff_flap_t) * 0.42)
			canvas.draw_arc(Vector2.ZERO, lift_radius, 0.0, TAU, 42, lift_color, maxf(2.0, visual_radius * 0.1))
			for wing_side: float in [-1.0, 1.0]:
				canvas.draw_line(
					side * wing_side * visual_radius * 0.92,
					side * wing_side * visual_radius * (1.55 + takeoff_flap_t * 0.25) + Vector2(0.0, visual_radius * (0.24 + takeoff_flap_t * 0.2)),
					Color(lift_color.r, lift_color.g, lift_color.b, lift_color.a * 0.7),
					maxf(1.4, visual_radius * 0.07)
				)
		if readable_air_attack:
			var cue_color := _with_alpha(Color(1.0, 0.84, 0.34, 0.54 * air_attack_cue_intensity), alpha)
			var cue_radius := float(anim.get("air_attack_cue_radius_px", visual_radius * (1.12 + air_attack_cue_intensity * 0.22)))
			canvas.draw_arc(Vector2.ZERO, cue_radius, 0.0, TAU, 44, cue_color, maxf(2.0, visual_radius * 0.13))
			canvas.draw_arc(Vector2.ZERO, cue_radius * 0.62, 0.0, TAU, 36, Color(cue_color.r, cue_color.g, cue_color.b, cue_color.a * 0.48), maxf(1.4, visual_radius * 0.07))
			canvas.draw_line(
				-forward * visual_radius * 0.32,
				forward * cue_radius * 0.72,
				Color(cue_color.r, cue_color.g, cue_color.b, cue_color.a * 0.62),
				maxf(1.5, visual_radius * 0.075)
			)
			for bracket_side: float in [-1.0, 1.0]:
				var bracket_origin := side * bracket_side * cue_radius * 0.96 - forward * visual_radius * 0.1
				canvas.draw_line(bracket_origin, bracket_origin - side * bracket_side * visual_radius * (0.32 + 0.08 * air_attack_cue_intensity), cue_color, maxf(1.6, visual_radius * 0.08))
				canvas.draw_line(bracket_origin, bracket_origin + forward * visual_radius * (0.3 + 0.08 * air_attack_cue_intensity), cue_color, maxf(1.4, visual_radius * 0.07))
			canvas.draw_line(
				Vector2.ZERO,
				Vector2(0.0, -air_lift_px + visual_radius * 0.24),
				Color(cue_color.r, cue_color.g, cue_color.b, cue_color.a * 0.72),
				maxf(1.6, visual_radius * 0.07)
			)
		if height_units >= 0.75:
			canvas.draw_line(
				Vector2.ZERO,
				Vector2(0.0, -air_lift_px + visual_radius * 0.22),
				_with_alpha(Color(0.72, 0.84, 0.95, 0.18 + low_window_t * 0.2), alpha),
				maxf(1.0, visual_radius * (0.05 + low_window_t * 0.03))
			)
	elif (landing_t > 0.0 and landing_impact > 0.0) or landing_flap_t > 0.0:
		var thump_strength := maxf(landing_t * landing_impact, landing_flap_t * 0.85)
		var thump_color := _with_alpha(Color(0.58, 0.64, 0.42, 0.24 * thump_strength), alpha)
		var thump_radius := visual_radius * (1.05 + (1.0 - landing_t) * 0.45 * maxf(landing_impact, landing_flap_t))
		canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)
		canvas.draw_arc(Vector2.ZERO, thump_radius, 0.0, TAU, 40, thump_color, maxf(2.0, visual_radius * 0.12))
		canvas.draw_arc(Vector2.ZERO, thump_radius * 0.72, 0.0, TAU, 32, Color(thump_color.r, thump_color.g, thump_color.b, thump_color.a * 0.6), maxf(1.5, visual_radius * 0.08))
	if not airborne:
		_draw_ground_truth_footprint(canvas, shake_offset, radius, outline, alpha)
	canvas.draw_set_transform(shake_offset + body_offset + movement_bob + (Vector2(0.0, -air_lift_px) if airborne else Vector2.ZERO), 0.0, Vector2.ONE)
	if airborne:
		canvas.draw_arc(Vector2.ZERO, visual_radius + 3.0, 0.0, TAU, 40, outline, 2.5)

	match String(skin.get("base", "blob")):
		"frog":
			_base_frog(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		"turtle":
			_base_turtle(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, windup_t, strike, attack_aim.normalized(), attack_reach, anim)
		"mustelid":
			_base_mustelid(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, strike, anim)
		"bird":
			_base_bird(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, airborne, anim)
		"serpent":
			_base_serpent(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		"croc":
			_base_croc(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		"crustacean":
			_base_crustacean(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, strike, anim)
		"spider":
			_base_spider(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		"swarm":
			_base_swarm(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		"cluster":
			_base_cluster(canvas, visual_radius, rocked_forward, side, skin, walk_phase, anim)
		"bug":
			_base_bug(canvas, visual_radius, rocked_forward, side, skin, walk_phase, moving, anim)
		_:
			canvas.draw_circle(Vector2.ZERO, visual_radius + 2.0, _with_alpha(Color(0.05, 0.06, 0.06), alpha))
			canvas.draw_circle(Vector2.ZERO, visual_radius, _with_alpha(creature_color(creature_id), alpha))

	if strike > 0.0:
		match String(skin.get("strike", "")):
			"tongue":
				_strike_tongue(canvas, visual_radius, attack_aim.normalized(), attack_reach, strike)
	_draw_open_region_outlines(canvas, anim, visual_radius, alpha)

	if flash_alpha > 0.0:
		var flash_mult := clampf(float(anim.get("flash_region_mult", 1.0)), 0.75, 1.35)
		var flash_color := _region_flash_color(flash_mult)
		flash_color.a = clampf(flash_alpha, 0.0, 1.0) * 0.85
		canvas.draw_circle(Vector2.ZERO, visual_radius + 3.0, flash_color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _draw_open_region_outlines(canvas: CanvasItem, anim: Dictionary, visual_radius: float, alpha: float) -> void:
	var regions: Array = anim.get("open_hurtbox_regions", [])
	if regions.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var local_center: Vector2 = region.get("local_center", Vector2.ZERO)
		var radius := maxf(float(region.get("radius", 0.0)), visual_radius * 0.18)
		var mult := clampf(float(region.get("region_mult", 1.0)), 0.75, 1.35)
		var region_color := _region_flash_color(mult)
		region_color.a = (0.18 + pulse * 0.1) * alpha
		canvas.draw_arc(local_center, radius, 0.0, TAU, 28, region_color, maxf(1.2, visual_radius * 0.055))
		canvas.draw_arc(local_center, radius * 0.66, -PI * 0.15, PI * 0.85, 16, Color(region_color.r, region_color.g, region_color.b, region_color.a * 0.55), maxf(1.0, visual_radius * 0.035))

static func _draw_ground_truth_footprint(canvas: CanvasItem, origin: Vector2, radius: float, outline: Color, alpha: float) -> void:
	var shadow_color := _with_alpha(VisualGrammar.shadow_color(0.32), alpha)
	canvas.draw_set_transform(origin + Vector2(radius * 0.14, radius * 0.18), 0.0, Vector2(1.0, 0.58))
	canvas.draw_circle(Vector2.ZERO, radius, shadow_color)
	canvas.draw_set_transform(origin, 0.0, Vector2.ONE)
	canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline, 2.2)

static func _region_flash_color(region_mult: float) -> Color:
	if region_mult > 1.05:
		return Color(1.0, 0.72, 0.45)
	if region_mult < 0.95:
		return Color(0.72, 0.88, 1.0)
	return Color.WHITE

# Snap out fast, HOLD the extended pose, then ease back — the hold is what
# makes small creatures' attacks readable.
static func _strike_curve(t: float) -> float:
	if t < 0.18:
		return t / 0.18
	if t < 0.6:
		return 1.0
	return 1.0 - (t - 0.6) / 0.4

static func alligator_bite_pose(anim: Dictionary, fallback_forward: Vector2) -> Dictionary:
	var safe_forward := fallback_forward.normalized()
	if safe_forward == Vector2.ZERO:
		safe_forward = Vector2.RIGHT
	var pose := {
		"active": false,
		"mode": "none",
		"forward": safe_forward,
		"phase_t": 0.0,
		"translation_forward": 0.0,
		"translation_side": 0.0,
		"rotation": 0.0,
		"longitudinal_scale": 1.0,
		"lateral_scale": 1.0,
		"head_extension": 0.0,
		"jaw_open": 0.0,
		"jaw_clamp": 0.0,
		"brace": 0.0,
		"off_balance": 0.0,
		"recoil": 0.0,
	}
	if String(anim.get("creature_id", "")) != "alligator":
		return pose
	if bool(anim.get("alligator_death_roll_pose", false)):
		pose["mode"] = "death_roll"
		return pose

	var attack_variant := String(anim.get("attack_variant", ""))
	var phase_name := String(anim.get("attack_phase_name", "idle"))
	var bite_timeline_active := attack_variant == "bite" and phase_name != "idle"
	var strike_heading_value: Variant = anim.get("strike_heading", safe_forward)
	if bite_timeline_active \
		and typeof(strike_heading_value) == TYPE_VECTOR2 \
		and not (strike_heading_value as Vector2).is_zero_approx():
		safe_forward = (strike_heading_value as Vector2).normalized()
	pose["forward"] = safe_forward

	var jaw_hold := bool(anim.get("alligator_jaw_hold_pose", false)) \
		or bool(anim.get("latch_attacker_pose", false))
	if jaw_hold:
		pose.merge({
			"active": true,
			"mode": "jaw_hold",
			"translation_forward": 0.16,
			"longitudinal_scale": 1.04,
			"lateral_scale": 0.96,
			"head_extension": 0.24,
			"jaw_open": 0.04,
			"jaw_clamp": 1.0,
			"brace": 0.72,
		}, true)
		return pose
	if attack_variant != "bite":
		return pose

	var phase_t := clampf(float(anim.get("phase_t", 0.0)), 0.0, 1.0)
	var outcome_name := String(anim.get("attack_outcome_name", "none"))
	pose["phase_t"] = phase_t
	match phase_name:
		"startup":
			var anticipation := phase_t * phase_t * (3.0 - 2.0 * phase_t)
			pose.merge({
				"active": true,
				"mode": "startup",
				"translation_forward": -0.22 * anticipation,
				"longitudinal_scale": 1.0 - 0.10 * anticipation,
				"lateral_scale": 1.0 + 0.08 * anticipation,
				"head_extension": -0.16 * anticipation,
				"jaw_open": 0.18 + 0.72 * anticipation,
				"brace": 0.35 + 0.65 * anticipation,
			}, true)
		"active":
			pose.merge({
				"active": true,
				"mode": "active",
				"translation_forward": 0.18,
				"longitudinal_scale": 1.08,
				"lateral_scale": 0.94,
				"head_extension": 0.34,
				"jaw_open": 0.42,
				"jaw_clamp": phase_t,
				"brace": 0.82,
			}, true)
		"recovery":
			match outcome_name:
				"whiff":
					var imbalance := lerpf(1.0, 0.58, phase_t)
					pose.merge({
						"active": true,
						"mode": "whiff",
						"translation_forward": lerpf(0.12, -0.10, phase_t),
						"translation_side": 0.15 * imbalance,
						"rotation": 0.24 * imbalance,
						"longitudinal_scale": 1.06,
						"lateral_scale": 0.95,
						"head_extension": lerpf(0.30, 0.08, phase_t),
						"jaw_open": lerpf(0.78, 0.34, phase_t),
						"brace": 0.34,
						"off_balance": imbalance,
					}, true)
				"interrupted":
					var recoil := lerpf(1.0, 0.32, phase_t)
					pose.merge({
						"active": true,
						"mode": "interrupted",
						"translation_forward": -0.30 * recoil,
						"translation_side": -0.05 * recoil,
						"rotation": -0.12 * recoil,
						"longitudinal_scale": 1.0 - 0.08 * recoil,
						"lateral_scale": 1.0 + 0.06 * recoil,
						"head_extension": -0.13 * recoil,
						"jaw_open": 0.24 * recoil,
						"brace": 0.78,
						"recoil": recoil,
					}, true)
				"hit":
					pose.merge({
						"active": true,
						"mode": "hit_hold",
						"translation_forward": lerpf(0.15, 0.04, phase_t),
						"longitudinal_scale": lerpf(1.04, 1.0, phase_t),
						"lateral_scale": lerpf(0.96, 1.0, phase_t),
						"head_extension": lerpf(0.22, 0.06, phase_t),
						"jaw_open": 0.05,
						"jaw_clamp": lerpf(1.0, 0.52, phase_t),
						"brace": lerpf(0.76, 0.34, phase_t),
					}, true)
	return pose

# ---------- bases ----------

static func _base_frog(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.36, 0.42, 0.2))
	var dark: Color = skin.get("dark", main.darkened(0.4))
	var belly: Color = skin.get("belly", main.lightened(0.25))
	var eye_color: Color = skin.get("eye", Color(0.8, 0.7, 0.3))
	var rooted_pose := bool(anim.get("rooted_pose", false))
	var toxic_recoil_t := clampf(float(anim.get("toxic_recoil_t", 0.0)), 0.0, 1.0)
	var chorus_hop := String(anim.get("creature_id", "")) == "chorus_frog" and bool(anim.get("chorus_hop_pose", false))
	var chorus_hop_intensity := clampf(float(anim.get("chorus_hop_intensity", 0.0)), 0.0, 1.25)
	var bullfrog_coil := String(anim.get("creature_id", "")) == "bullfrog" and bool(anim.get("bullfrog_coil_pose", false))
	var bullfrog_coil_intensity := clampf(float(anim.get("bullfrog_coil_intensity", 0.0)), 0.0, 1.25)
	var bullfrog_lunge := String(anim.get("creature_id", "")) == "bullfrog" and bool(anim.get("bullfrog_lunge_pose", false))
	var bullfrog_lunge_intensity := clampf(float(anim.get("bullfrog_lunge_intensity", 0.0)), 0.0, 1.25)
	var bullfrog_heavy_hop := String(anim.get("creature_id", "")) == "bullfrog" and bool(anim.get("bullfrog_heavy_hop_pose", false))
	var bullfrog_heavy_hop_intensity := clampf(float(anim.get("bullfrog_heavy_hop_intensity", 0.0)), 0.0, 1.25)
	var camouflage_eye_cue := String(anim.get("creature_id", "")) == "bullfrog" and bool(anim.get("camouflage_eye_cue", false))
	var cane_squat_hop := String(anim.get("creature_id", "")) == "cane_toad" and bool(anim.get("cane_squat_hop_pose", false))
	var cane_squat_hop_intensity := clampf(float(anim.get("cane_squat_hop_intensity", 0.0)), 0.0, 1.25)

	var raw_hop := sin(walk_phase * 1.2) * 0.5 + 0.5 if moving and not rooted_pose else 0.0
	var ground_contact := clampf(float(anim.get("ground_contact", 0.6)), 0.1, 0.95)
	var hop := maxf(0.0, (raw_hop - ground_contact) / maxf(1.0 - ground_contact, 0.001)) if moving else 0.0
	var leg_extend := 0.55 + hop * 0.55 * float(anim.get("hop_leg_scale", 1.0))
	if chorus_hop:
		leg_extend += 0.16 * chorus_hop_intensity * (0.35 + hop)
	if bullfrog_heavy_hop:
		leg_extend += 0.14 * bullfrog_heavy_hop_intensity * (0.4 + hop)
	if bullfrog_coil:
		leg_extend = maxf(0.32, leg_extend - 0.22 * bullfrog_coil_intensity)
	if bullfrog_lunge:
		leg_extend += 0.22 * bullfrog_lunge_intensity
	if cane_squat_hop:
		leg_extend = maxf(0.36, leg_extend - 0.18 * cane_squat_hop_intensity)
	if rooted_pose:
		leg_extend = 0.38
	var landing_squash := (1.0 - hop) * float(anim.get("landing_squash", 0.0)) if moving else 0.0
	if bullfrog_heavy_hop:
		landing_squash = maxf(landing_squash, 0.08 * bullfrog_heavy_hop_intensity * (1.0 - hop * 0.25))
	if bullfrog_coil:
		landing_squash = maxf(landing_squash, 0.16 * bullfrog_coil_intensity)
	if cane_squat_hop:
		landing_squash = maxf(landing_squash, 0.08 * cane_squat_hop_intensity * (1.0 - hop * 0.35))
	var landing_t := clampf(float(anim.get("landing_t", 0.0)), 0.0, 1.0)
	var landing_impact := clampf(float(anim.get("landing_impact", 0.0)), 0.0, 1.5)
	landing_squash = maxf(landing_squash, landing_t * landing_impact * 0.18)
	if rooted_pose:
		landing_squash = maxf(landing_squash, 0.22)

	if bullfrog_coil:
		for ring_side: float in [-1.0, 1.0]:
			var ring_origin := -forward * radius * 0.44 + side * ring_side * radius * 0.32
			var ring_alpha := 0.18 + 0.08 * bullfrog_coil_intensity
			canvas.draw_arc(ring_origin, radius * (0.44 + 0.1 * bullfrog_coil_intensity), PI * 0.08, PI * 0.92, 12, Color(dark.r, dark.g, dark.b, ring_alpha), maxf(radius * 0.045, 1.0))
	if bullfrog_lunge:
		for streak_side: float in [-0.55, 0.0, 0.55]:
			var streak_start := -forward * radius * (0.45 + 0.12 * bullfrog_lunge_intensity) + side * streak_side * radius
			var streak_end := streak_start - forward * radius * (0.52 + 0.18 * bullfrog_lunge_intensity)
			canvas.draw_line(streak_start, streak_end, Color(belly.r, belly.g, belly.b, 0.2 + 0.1 * bullfrog_lunge_intensity), maxf(radius * 0.055, 1.0))
	if bullfrog_heavy_hop:
		var thump_color := Color(dark.r, dark.g, dark.b, 0.14 + 0.08 * bullfrog_heavy_hop_intensity)
		for thump_side: float in [-1.0, 1.0]:
			var thump_center := -forward * radius * 0.42 + side * thump_side * radius * 0.42
			canvas.draw_arc(thump_center, radius * (0.34 + 0.1 * bullfrog_heavy_hop_intensity), PI * 0.08, PI * 0.92, 10, thump_color, maxf(radius * 0.055, 1.0))
		canvas.draw_arc(-forward * radius * 0.12, radius * (0.74 + 0.1 * bullfrog_heavy_hop_intensity), PI * 0.08, PI * 0.92, 16, Color(thump_color.r, thump_color.g, thump_color.b, thump_color.a * 0.82), maxf(radius * 0.07, 1.2))
		canvas.draw_circle(-forward * radius * 0.18, maxf(radius * (0.075 + 0.025 * bullfrog_heavy_hop_intensity), 1.2), Color(thump_color.r, thump_color.g, thump_color.b, thump_color.a * 0.88))
		canvas.draw_line(-forward * radius * 0.7, -forward * radius * (1.16 + 0.18 * bullfrog_heavy_hop_intensity), Color(thump_color.r, thump_color.g, thump_color.b, thump_color.a * 0.72), maxf(radius * 0.06, 1.1))
	if cane_squat_hop:
		var squat_scuff := Color(dark.r, dark.g, dark.b, 0.16 + 0.08 * cane_squat_hop_intensity)
		for squat_side: float in [-1.0, 1.0]:
			var squat_center := -forward * radius * 0.2 + side * squat_side * radius * 0.54
			canvas.draw_arc(squat_center, radius * (0.2 + 0.06 * cane_squat_hop_intensity), PI * 0.05, PI * 0.88, 8, squat_scuff, maxf(radius * 0.045, 1.0))
			canvas.draw_line(squat_center, squat_center - forward * radius * (0.28 + 0.1 * cane_squat_hop_intensity) + side * squat_side * radius * 0.1, Color(squat_scuff.r, squat_scuff.g, squat_scuff.b, squat_scuff.a * 0.82), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(squat_center - forward * radius * 0.1, maxf(radius * (0.045 + 0.016 * cane_squat_hop_intensity), 1.0), Color(squat_scuff.r, squat_scuff.g, squat_scuff.b, squat_scuff.a * 0.9))
	if chorus_hop:
		var pulse_alpha := 0.14 + 0.08 * chorus_hop_intensity
		for pulse_side: float in [-1.0, 0.0, 1.0]:
			var pulse_center := forward * radius * (0.18 + 0.08 * absf(pulse_side)) + side * pulse_side * radius * 0.28
			canvas.draw_arc(pulse_center, radius * (0.24 + 0.08 * chorus_hop_intensity), -PI * 0.1, PI * 0.85, 10, Color(belly.r, belly.g, belly.b, pulse_alpha), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(pulse_center + forward * radius * 0.1, maxf(radius * (0.04 + 0.014 * chorus_hop_intensity), 1.0), Color(belly.r, belly.g, belly.b, pulse_alpha * 0.9))
		canvas.draw_arc(forward * radius * 0.72, radius * (0.42 + 0.12 * chorus_hop_intensity), -PI * 0.18, TAU * 0.72, 18, Color(belly.r, belly.g, belly.b, 0.18 + 0.08 * chorus_hop_intensity), maxf(radius * 0.045, 1.0))

	for leg_side: float in [-1.0, 1.0]:
		var hip := -forward * radius * 0.45 + side * leg_side * radius * 0.62
		var knee := hip - forward * radius * 0.35 * leg_extend + side * leg_side * radius * 0.4
		var foot := knee - forward * radius * 0.55 * leg_extend - side * leg_side * radius * 0.08
		if bullfrog_coil:
			var coil_shadow := foot - forward * radius * (0.12 + 0.1 * bullfrog_coil_intensity)
			canvas.draw_arc(coil_shadow, radius * (0.22 + 0.04 * bullfrog_coil_intensity), -0.25, PI * 0.85, 8, Color(dark.r, dark.g, dark.b, 0.2 + 0.08 * bullfrog_coil_intensity), maxf(radius * 0.045, 1.0))
		if bullfrog_heavy_hop:
			var heel_drag := foot - forward * radius * (0.2 + 0.12 * bullfrog_heavy_hop_intensity)
			canvas.draw_line(foot, heel_drag + side * leg_side * radius * 0.06, Color(dark.r, dark.g, dark.b, 0.26 + 0.08 * bullfrog_heavy_hop_intensity), maxf(radius * 0.055, 1.0))
			canvas.draw_arc(heel_drag - forward * radius * 0.06, radius * (0.2 + 0.05 * bullfrog_heavy_hop_intensity), PI * 0.08, PI * 0.9, 8, Color(dark.r, dark.g, dark.b, 0.18 + 0.08 * bullfrog_heavy_hop_intensity), maxf(radius * 0.045, 1.0))
		if chorus_hop:
			var toe_trail := foot - forward * radius * (0.22 + 0.12 * chorus_hop_intensity)
			canvas.draw_line(foot, toe_trail + side * leg_side * radius * 0.08, Color(dark.r, dark.g, dark.b, 0.32 + 0.12 * chorus_hop_intensity), maxf(radius * 0.06, 1.1))
			canvas.draw_arc(toe_trail + side * leg_side * radius * 0.1, radius * (0.14 + 0.04 * chorus_hop_intensity), PI * 0.08, PI * 0.9, 8, Color(belly.r, belly.g, belly.b, 0.18 + 0.08 * chorus_hop_intensity), maxf(radius * 0.035, 1.0))
		if cane_squat_hop:
			var scuff := foot - forward * radius * (0.18 + 0.12 * cane_squat_hop_intensity)
			canvas.draw_arc(scuff, radius * (0.18 + 0.05 * cane_squat_hop_intensity), PI * 0.08, PI * 0.9, 8, Color(dark.r, dark.g, dark.b, 0.2 + 0.08 * cane_squat_hop_intensity), maxf(radius * 0.05, 1.0))
		canvas.draw_line(hip, knee, dark, maxf(radius * 0.24, 3.0))
		canvas.draw_line(knee, foot, dark, maxf(radius * 0.18, 2.5))
		for toe in 3:
			canvas.draw_line(foot, foot + (-forward).rotated((float(toe) - 1.0) * 0.4) * radius * 0.22, dark, 1.5)

	for foot_side: float in [-1.0, 1.0]:
		var front_step := sin(walk_phase * 1.2 + PI * 0.5) * radius * 0.08 if moving else 0.0
		var front_foot := forward * (radius * 0.55 + front_step) + side * foot_side * radius * 0.4
		if cane_squat_hop:
			front_foot += side * foot_side * radius * 0.1 * cane_squat_hop_intensity - forward * radius * 0.08 * cane_squat_hop_intensity
		canvas.draw_circle(front_foot, radius * 0.13, dark)
		if cane_squat_hop:
			canvas.draw_arc(front_foot - forward * radius * 0.08, radius * (0.16 + 0.04 * cane_squat_hop_intensity), PI * 0.08, PI * 0.9, 8, Color(dark.r, dark.g, dark.b, 0.2 + 0.08 * cane_squat_hop_intensity), 1.0)
		if chorus_hop:
			canvas.draw_arc(front_foot - forward * radius * 0.08, radius * (0.16 + 0.04 * chorus_hop_intensity), PI * 0.1, PI * 0.9, 8, Color(dark.r, dark.g, dark.b, 0.25), 1.0)

	var body_points := PackedVector2Array()
	for i in 16:
		var body_angle := TAU * float(i) / 16.0
		var ry := radius * lerpf(0.85, 0.6, (cos(body_angle) * 0.5 + 0.5))
		body_points.append(forward * cos(body_angle) * radius * (0.95 - landing_squash * 0.16) + side * sin(body_angle) * ry * (1.0 + landing_squash))
	canvas.draw_colored_polygon(body_points, dark)
	var inner := PackedVector2Array()
	for point in body_points:
		inner.append(point * 0.88)
	canvas.draw_colored_polygon(inner, main)

	if bool(skin.get("stripes", false)):
		canvas.draw_colored_polygon(PackedVector2Array([
			forward * radius * 0.62 + side * radius * 0.22,
			forward * radius * 0.62 - side * radius * 0.22,
			forward * radius * 0.3
		]), dark.darkened(0.15))
		for stripe: float in [-0.3, 0.0, 0.3]:
			canvas.draw_line(forward * radius * 0.15 + side * radius * stripe, -forward * radius * 0.72 + side * radius * stripe * 1.4, dark.darkened(0.12), maxf(radius * 0.09, 1.5))
	if bool(skin.get("warts", false)):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			var wart := forward * rng.randf_range(-0.6, 0.5) * radius + side * rng.randf_range(-0.5, 0.5) * radius
			var wart_radius := maxf(radius * rng.randf_range(0.05, 0.09), 1.2)
			if toxic_recoil_t > 0.0:
				canvas.draw_circle(wart, wart_radius * (1.8 + toxic_recoil_t * 0.6), Color(0.48, 0.9, 0.28, 0.18 * toxic_recoil_t))
			canvas.draw_circle(wart, wart_radius, dark.lightened(0.12 + toxic_recoil_t * 0.18))
		for gland_side: float in [-1.0, 1.0]:
			var gland := forward * radius * 0.35 + side * gland_side * radius * 0.42
			if cane_squat_hop:
				canvas.draw_arc(gland - forward * radius * 0.06, radius * (0.2 + 0.04 * cane_squat_hop_intensity), PI * 0.1, PI * 0.9, 10, Color(dark.r, dark.g, dark.b, 0.16 + 0.06 * cane_squat_hop_intensity), 1.0)
			if toxic_recoil_t > 0.0:
				canvas.draw_circle(gland, radius * (0.34 + toxic_recoil_t * 0.18), Color(0.58, 1.0, 0.34, 0.28 * toxic_recoil_t))
				canvas.draw_line(gland, gland + side * gland_side * radius * (0.55 + toxic_recoil_t * 0.16), Color(0.58, 1.0, 0.34, 0.35 * toxic_recoil_t), maxf(radius * 0.08, 1.5))
			canvas.draw_circle(gland, radius * (0.16 + toxic_recoil_t * 0.04), dark.lightened(0.06 + toxic_recoil_t * 0.18))
	if bool(skin.get("tympanum", false)):
		for ear_side: float in [-1.0, 1.0]:
			canvas.draw_arc(forward * radius * 0.42 + side * ear_side * radius * 0.5, radius * 0.12, 0.0, TAU, 12, dark, 1.5)

	for eye_side: float in [-1.0, 1.0]:
		var eye := forward * radius * 0.68 + side * eye_side * radius * 0.42
		canvas.draw_circle(eye, radius * 0.22, dark)
		canvas.draw_circle(eye, radius * 0.17, eye_color)
		canvas.draw_circle(eye + forward * radius * 0.05, maxf(radius * 0.08, 1.3), Color(0.08, 0.07, 0.04))
		if camouflage_eye_cue:
			var glint := eye + forward * radius * 0.12 - side * eye_side * radius * 0.06
			canvas.draw_circle(glint, maxf(radius * 0.045, 1.0), Color(0.94, 0.9, 0.42, 0.82))
			canvas.draw_arc(eye + forward * radius * 0.02, radius * 0.26, -0.25, PI + 0.25, 12, Color(0.94, 0.9, 0.42, 0.28), maxf(radius * 0.04, 1.0))

	if bool(skin.get("call_sac", false)):
		var sac_pulse := (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.35
		if chorus_hop:
			sac_pulse += 0.28 * chorus_hop_intensity * (sin(walk_phase * 1.2) * 0.5 + 0.5)
			var pulse_center := forward * radius * 0.88
			canvas.draw_arc(pulse_center, radius * (0.34 + 0.12 * chorus_hop_intensity), -0.25, TAU * 0.75, 18, Color(belly.r, belly.g, belly.b, 0.24), maxf(radius * 0.05, 1.0))
		canvas.draw_circle(forward * radius * 0.88, radius * (0.14 + sac_pulse * 0.14), belly)

static func _base_turtle(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, windup_t: float, strike := 0.0, attack_aim := Vector2.ZERO, attack_reach := 0.0, anim: Dictionary = {}) -> void:
	var shell_color: Color = skin.get("shell", Color(0.26, 0.3, 0.16))
	var shell_rim: Color = skin.get("rim", shell_color.darkened(0.3))
	var skin_color: Color = skin.get("skin", Color(0.45, 0.4, 0.24))
	var skin_dark := skin_color.darkened(0.22)
	var turtle_stride := float(anim.get("turtle_stride", 1.0))
	var turtle_swim := bool(anim.get("turtle_swim_pose", false))
	var turtle_swim_intensity := clampf(float(anim.get("turtle_swim_intensity", 0.0)), 0.0, 1.25)
	var turtle_plod := String(anim.get("creature_id", "")) == "snapping_turtle" and bool(anim.get("turtle_plod_pose", false))
	var turtle_plod_intensity := clampf(float(anim.get("turtle_plod_intensity", 0.0)), 0.0, 1.25)
	var bog_creep := String(anim.get("creature_id", "")) == "bog_turtle" and bool(anim.get("bog_turtle_creep_pose", false))
	var bog_creep_intensity := clampf(float(anim.get("bog_turtle_creep_intensity", 0.0)), 0.0, 1.25)
	var bog_paddle := String(anim.get("creature_id", "")) == "bog_turtle" and bool(anim.get("bog_turtle_paddle_pose", false))
	var bog_paddle_intensity := clampf(float(anim.get("bog_turtle_paddle_intensity", 0.0)), 0.0, 1.25)
	var swim_intensity := maxf(turtle_swim_intensity, bog_paddle_intensity * 0.82)
	var shell_stability := float(anim.get("shell_stability", 0.0)) + turtle_swim_intensity * 0.1 + turtle_plod_intensity * 0.1 + bog_creep_intensity * 0.12 + bog_paddle_intensity * 0.08
	var turtle_water := Color(0.42, 0.68, 0.82, 0.22 + 0.1 * swim_intensity)
	var turtle_scuff := Color(0.34, 0.29, 0.18, 0.16 + 0.08 * turtle_plod_intensity)
	var bog_scuff := Color(0.48, 0.37, 0.24, 0.16 + 0.1 * bog_creep_intensity)
	var bog_water := Color(0.38, 0.62, 0.76, 0.16 + 0.1 * bog_paddle_intensity)

	var tail_direction := (-forward).rotated(sin(walk_phase * 0.5) * 0.15 * maxf(turtle_stride, 0.2))
	if turtle_swim or bog_paddle:
		for wake_side: float in [-1.0, 1.0]:
			var wake_origin := -forward * radius * (0.2 + 0.12 * swim_intensity) + side * wake_side * radius * (0.62 if bog_paddle else 0.72)
			var wake_color := bog_water if bog_paddle else turtle_water
			canvas.draw_arc(wake_origin, radius * (0.34 + 0.12 * swim_intensity), -0.55, 0.95, 12, wake_color, 1.2 + swim_intensity * 0.45)
			canvas.draw_line(wake_origin - forward * radius * 0.2, wake_origin - forward * radius * (0.78 + 0.2 * swim_intensity) + side * wake_side * radius * 0.16, Color(wake_color.r, wake_color.g, wake_color.b, wake_color.a * 0.7), maxf(radius * 0.055, 1.1))
	if turtle_swim:
		var shell_push := Color(turtle_water.r, turtle_water.g, turtle_water.b, 0.18 + 0.08 * turtle_swim_intensity)
		canvas.draw_arc(-forward * radius * 0.18, radius * (0.62 + 0.08 * turtle_swim_intensity), PI * 0.05, PI * 0.95, 18, shell_push, maxf(radius * 0.08, 1.2))
		canvas.draw_arc(forward * radius * 0.44, radius * (0.34 + 0.08 * turtle_swim_intensity), -PI * 0.85, PI * 0.85, 14, Color(shell_push.r, shell_push.g, shell_push.b, shell_push.a * 0.86), maxf(radius * 0.06, 1.0))
		for push_side: float in [-1.0, 1.0]:
			var push_start := -forward * radius * 0.12 + side * push_side * radius * 0.58
			canvas.draw_line(push_start, push_start - forward * radius * (0.56 + 0.18 * turtle_swim_intensity) + side * push_side * radius * 0.18, shell_push, maxf(radius * 0.06, 1.0))
			canvas.draw_circle(push_start - forward * radius * (0.42 + 0.12 * turtle_swim_intensity) + side * push_side * radius * 0.1, maxf(radius * (0.045 + 0.018 * turtle_swim_intensity), 1.0), turtle_water.lightened(0.22))
	if bog_creep:
		for scuff_side: float in [-1.0, 1.0]:
			var scuff_center := -forward * radius * 0.55 + side * scuff_side * radius * 0.48
			canvas.draw_arc(scuff_center, radius * (0.18 + 0.04 * bog_creep_intensity), PI * 0.1, PI * 0.9, 8, bog_scuff, 1.0)
			var toe_center := -forward * radius * 0.16 + side * scuff_side * radius * 0.34
			canvas.draw_line(toe_center, toe_center - forward * radius * (0.16 + 0.06 * bog_creep_intensity), Color(bog_scuff.r, bog_scuff.g, bog_scuff.b, bog_scuff.a * 0.82), 1.0)
			canvas.draw_line(toe_center, toe_center + side * scuff_side * radius * (0.1 + 0.05 * bog_creep_intensity), Color(bog_scuff.r, bog_scuff.g, bog_scuff.b, bog_scuff.a * 0.72), 1.0)
			canvas.draw_circle(toe_center - forward * radius * 0.1, maxf(radius * (0.035 + 0.012 * bog_creep_intensity), 1.0), Color(bog_scuff.r, bog_scuff.g, bog_scuff.b, bog_scuff.a * 0.86))
			canvas.draw_circle(toe_center + side * scuff_side * radius * 0.1, maxf(radius * 0.03, 1.0), Color(bog_scuff.r, bog_scuff.g, bog_scuff.b, bog_scuff.a * 0.68))
	if bog_paddle:
		for bubble_side: float in [-1.0, 1.0]:
			var bubble_center := forward * radius * 0.46 + side * bubble_side * radius * 0.26
			canvas.draw_circle(bubble_center, maxf(radius * (0.045 + 0.015 * bog_paddle_intensity), 1.0), bog_water.lightened(0.22))
			canvas.draw_circle(bubble_center - forward * radius * 0.24 + side * bubble_side * radius * 0.08, maxf(radius * 0.03, 1.0), Color(bog_water.r, bog_water.g, bog_water.b, bog_water.a * 0.75))
		var tiny_paddle := Color(bog_water.r, bog_water.g, bog_water.b, 0.18 + 0.08 * bog_paddle_intensity)
		for paddle_side: float in [-1.0, 1.0]:
			var paddle_center := -forward * radius * 0.08 + side * paddle_side * radius * 0.36
			canvas.draw_arc(paddle_center, radius * (0.15 + 0.04 * bog_paddle_intensity), PI * 0.05, PI * 0.9, 8, tiny_paddle, maxf(radius * 0.035, 1.0))
	if turtle_plod:
		for scuff_side: float in [-1.0, 1.0]:
			var scuff_center := -forward * radius * 0.46 + side * scuff_side * radius * 0.62
			canvas.draw_arc(scuff_center, radius * (0.24 + 0.05 * turtle_plod_intensity), PI * 0.08, PI * 0.92, 10, turtle_scuff, maxf(radius * 0.055, 1.0))
			canvas.draw_circle(scuff_center - forward * radius * (0.18 + 0.06 * turtle_plod_intensity), maxf(radius * (0.045 + 0.018 * turtle_plod_intensity), 1.0), Color(turtle_scuff.r, turtle_scuff.g, turtle_scuff.b, turtle_scuff.a * 0.86))
		canvas.draw_line(-forward * radius * 0.62, -forward * radius * (1.0 + 0.18 * turtle_plod_intensity), Color(turtle_scuff.r, turtle_scuff.g, turtle_scuff.b, turtle_scuff.a * 0.82), maxf(radius * 0.075, 1.1))
	canvas.draw_line(tail_direction * radius * 0.9, tail_direction * radius * 1.45, skin_dark, maxf(radius * 0.16, 3.0))

	for leg_index in 4:
		var angle := [0.96, -0.96, 2.18, -2.18][leg_index] as float
		var step := (sin(walk_phase + (PI if leg_index % 2 == 0 else 0.0)) * radius * 0.12 * turtle_stride) if moving else 0.0
		if turtle_plod:
			step *= 0.72
		if bog_creep:
			step *= 0.55
		var leg_side := 1.0 if angle > 0.0 else -1.0
		var paddle_sweep := sin(walk_phase * 1.15 + (PI if leg_index % 2 == 0 else 0.0)) * radius * 0.18 * swim_intensity if turtle_swim or bog_paddle else 0.0
		var leg_center := (forward.rotated(angle) * radius * 0.92) + forward * step + side * leg_side * paddle_sweep
		canvas.draw_circle(leg_center, radius * 0.26, skin_dark)
		canvas.draw_circle(leg_center, radius * 0.2, skin_color)
		var claw_direction := leg_center.normalized()
		for claw in 3:
			canvas.draw_line(leg_center + claw_direction.rotated((float(claw) - 1.0) * 0.35) * radius * 0.18, leg_center + claw_direction.rotated((float(claw) - 1.0) * 0.35) * radius * 0.34, Color(0.85, 0.82, 0.7), 1.5)
		if turtle_swim:
			canvas.draw_circle(leg_center - forward * radius * 0.08, maxf(radius * (0.07 + 0.02 * turtle_swim_intensity), 1.2), turtle_water.lightened(0.18))
			canvas.draw_arc(leg_center - forward * radius * 0.1, radius * (0.18 + 0.04 * turtle_swim_intensity), PI * 0.05, PI * 0.9, 8, turtle_water, maxf(radius * 0.045, 1.0))
		if turtle_plod:
			canvas.draw_line(leg_center - forward * radius * 0.05, leg_center - forward * radius * (0.32 + 0.08 * turtle_plod_intensity), turtle_scuff, maxf(radius * 0.04, 1.0))
		if bog_paddle:
			canvas.draw_circle(leg_center - forward * radius * 0.08, maxf(radius * (0.055 + 0.02 * bog_paddle_intensity), 1.0), bog_water.lightened(0.2))
		if bog_creep:
			canvas.draw_line(leg_center - forward * radius * 0.08, leg_center - forward * radius * (0.28 + 0.08 * bog_creep_intensity), bog_scuff, 1.0)

	# One head, three states: striking (neck extends along the attack aim),
	# winding up (retracted under the shell), or idle. Drawn BEFORE the shell
	# so the neck always emerges from underneath the carapace.
	var head_direction := forward
	var head_reach := radius * 1.05
	var neck_width := maxf(radius * 0.3, 4.0)
	if strike > 0.0 and attack_aim != Vector2.ZERO:
		head_direction = attack_aim
		head_reach = radius * 0.6 + (maxf(attack_reach, radius * 1.2) - radius * 0.6) * strike
	elif windup_t >= 0.0:
		head_reach = radius * (1.05 - 0.45 * windup_t)
	elif bog_creep:
		head_reach = radius * (0.88 + 0.05 * sin(walk_phase))
	elif bog_paddle:
		head_reach = radius * (0.98 + 0.04 * sin(walk_phase * 0.8))
	var head_center := head_direction * head_reach
	var head_side := Vector2(-head_direction.y, head_direction.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		head_side * neck_width * 0.7,
		head_center + head_side * neck_width * 0.45,
		head_center - head_side * neck_width * 0.45,
		-head_side * neck_width * 0.7
	]), skin_dark)
	canvas.draw_circle(head_center, radius * 0.32, skin_dark)
	canvas.draw_circle(head_center, radius * 0.26, skin_color)
	if skin.has("neck_patch"):
		var patch: Color = skin["neck_patch"]
		if bog_creep or bog_paddle:
			canvas.draw_arc(head_center, radius * (0.22 + 0.04 * maxf(bog_creep_intensity, bog_paddle_intensity)), -PI * 0.15, PI * 1.1, 12, Color(patch.r, patch.g, patch.b, 0.18 + 0.06 * maxf(bog_creep_intensity, bog_paddle_intensity)), 1.0)
		canvas.draw_circle(head_center + head_side * radius * 0.2, radius * 0.1, patch)
		canvas.draw_circle(head_center - head_side * radius * 0.2, radius * 0.1, patch)
	if strike > 0.0:
		var jaw_open := (1.0 - strike) * 0.7 + 0.15
		canvas.draw_line(head_center, head_center + head_direction.rotated(jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)
		canvas.draw_line(head_center, head_center + head_direction.rotated(-jaw_open) * neck_width * 1.2, Color(0.95, 0.95, 0.9), 2.5)
	else:
		canvas.draw_line(head_center + head_direction * radius * 0.2, head_center + head_direction * radius * 0.4, skin_dark.darkened(0.2), 2.5)
	canvas.draw_circle(head_center + head_side * radius * 0.13 + head_direction * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))
	canvas.draw_circle(head_center - head_side * radius * 0.13 + head_direction * radius * 0.08, maxf(radius * 0.05, 1.2), Color(0.1, 0.09, 0.05))

	var shell_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		shell_points.append(forward * cos(shell_angle) * radius * (1.02 + shell_stability * 0.03) + side * sin(shell_angle) * radius * (0.88 + shell_stability * 0.02))
	canvas.draw_colored_polygon(shell_points, shell_rim)
	if turtle_swim or bog_paddle:
		var shell_wake_color := bog_water if bog_paddle else turtle_water
		canvas.draw_arc(-forward * radius * 0.1, radius * (0.9 + swim_intensity * 0.04), PI * 0.9, PI * 2.1, 18, Color(shell_wake_color.r, shell_wake_color.g, shell_wake_color.b, shell_wake_color.a * 0.75), maxf(radius * 0.06, 1.2))
	if bog_creep:
		canvas.draw_arc(-forward * radius * 0.08, radius * (0.76 + bog_creep_intensity * 0.03), PI * 0.08, PI * 0.92, 12, bog_scuff, maxf(radius * 0.06, 1.0))
	if turtle_plod:
		canvas.draw_arc(-forward * radius * 0.12, radius * (0.9 + turtle_plod_intensity * 0.04), PI * 0.08, PI * 0.92, 14, turtle_scuff, maxf(radius * 0.06, 1.1))
	var inner_points := PackedVector2Array()
	for i in 18:
		var shell_angle := TAU * float(i) / 18.0
		inner_points.append(forward * cos(shell_angle) * radius * 0.88 + side * sin(shell_angle) * radius * 0.74)
	canvas.draw_colored_polygon(inner_points, shell_color)
	if bool(skin.get("keels", false)):
		for keel: float in [-0.34, 0.0, 0.34]:
			canvas.draw_line(forward * radius * -0.7 + side * radius * keel, forward * radius * 0.72 + side * radius * keel, shell_rim.darkened(0.1), 2.0)
	for cross: float in [-0.42, 0.0, 0.42]:
		canvas.draw_line(forward * radius * cross - side * radius * 0.55, forward * radius * cross + side * radius * 0.55, shell_rim.darkened(0.06), 1.5)
	canvas.draw_line(forward * radius * -0.7, forward * radius * 0.72, shell_color.lightened(0.18), 1.5)

static func _base_mustelid(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, strike := 0.0, anim: Dictionary = {}) -> void:
	var fur: Color = skin.get("main", Color(0.24, 0.14, 0.09))
	var fur_dark: Color = skin.get("dark", fur.darkened(0.3))
	var belly: Color = skin.get("belly", fur.lightened(0.3))
	var bulk := float(skin.get("bulk", 1.0))
	var snout := float(skin.get("snout", 1.0))
	var stretch := 1.0 + strike * 0.5
	var body_wiggle := float(anim.get("body_wiggle", 1.0))
	var tail_wave := float(anim.get("tail_wave", 1.0))
	var is_water_shrew := String(anim.get("creature_id", "")) == "water_shrew"
	var is_newt := String(anim.get("creature_id", "")) == "newt"
	var is_beaver := String(anim.get("creature_id", "")) == "beaver"
	var is_mink := String(anim.get("creature_id", "")) == "mink"
	var is_otter := String(anim.get("creature_id", "")) == "otter"
	var surface_walk := bool(anim.get("surface_walk", false))
	var surface_wake_intensity := clampf(float(anim.get("surface_wake_intensity", 0.0)), 0.0, 1.25)
	var submerged_shrew := is_water_shrew and bool(anim.get("submerged_shrew_pose", bool(anim.get("in_water", false)) and not surface_walk))
	var submerged_shrew_intensity := clampf(float(anim.get("submerged_shrew_intensity", 0.0)), 0.0, 1.25)
	var shrew_land_skitter := is_water_shrew and bool(anim.get("shrew_land_skitter_pose", false))
	var shrew_land_skitter_intensity := clampf(float(anim.get("shrew_land_skitter_intensity", 0.0)), 0.0, 1.25)
	var slick_crawl := is_newt and bool(anim.get("slick_crawl_pose", false))
	var slick_crawl_intensity := clampf(float(anim.get("slick_crawl_intensity", 0.0)), 0.0, 1.25)
	var newt_swim := is_newt and bool(anim.get("newt_swim_pose", false))
	var newt_swim_intensity := clampf(float(anim.get("newt_swim_intensity", 0.0)), 0.0, 1.25)
	var tail_lost_pose := is_newt and bool(anim.get("tail_lost_pose", false))
	var beaver_swim := is_beaver and bool(anim.get("beaver_swim_pose", false))
	var beaver_swim_intensity := clampf(float(anim.get("beaver_swim_intensity", 0.0)), 0.0, 1.25)
	var beaver_lumber := is_beaver and bool(anim.get("beaver_lumber_pose", false))
	var beaver_lumber_intensity := clampf(float(anim.get("beaver_lumber_intensity", 0.0)), 0.0, 1.25)
	var mink_bound := is_mink and bool(anim.get("mink_bound_pose", false))
	var mink_bound_intensity := clampf(float(anim.get("mink_bound_intensity", 0.0)), 0.0, 1.25)
	var mink_swim := is_mink and bool(anim.get("mink_swim_pose", false))
	var mink_swim_intensity := clampf(float(anim.get("mink_swim_intensity", 0.0)), 0.0, 1.25)
	var mink_choke := is_mink and bool(anim.get("mink_choke_pose", false))
	var otter_swim := is_otter and bool(anim.get("otter_swim_pose", false))
	var otter_land_slide := is_otter and bool(anim.get("otter_land_slide_pose", false))
	var otter_motion_intensity := clampf(float(anim.get("otter_motion_intensity", 0.0)), 0.0, 1.25)
	var otter_pack_latch := is_otter and bool(anim.get("otter_pack_latch_pose", false))
	if surface_walk:
		body_wiggle += 0.42 * surface_wake_intensity
		tail_wave += 0.25 * surface_wake_intensity
	if submerged_shrew:
		body_wiggle += 0.16 * submerged_shrew_intensity
		tail_wave += 0.22 * submerged_shrew_intensity
	if shrew_land_skitter:
		stretch += 0.06 * shrew_land_skitter_intensity
		body_wiggle += 0.34 * shrew_land_skitter_intensity
		tail_wave += 0.28 * shrew_land_skitter_intensity
	if slick_crawl:
		body_wiggle += 0.35 * slick_crawl_intensity
		tail_wave += 0.32 * slick_crawl_intensity
	if newt_swim:
		stretch += 0.06 * newt_swim_intensity
		body_wiggle += 0.24 * newt_swim_intensity
		tail_wave += 0.62 * newt_swim_intensity
	if beaver_swim:
		body_wiggle += 0.16 * beaver_swim_intensity
		tail_wave += 0.58 * beaver_swim_intensity
	if beaver_lumber:
		stretch = maxf(0.94, stretch - 0.05 * beaver_lumber_intensity)
		body_wiggle += 0.08 * beaver_lumber_intensity
		tail_wave += 0.18 * beaver_lumber_intensity
	if mink_bound:
		stretch += 0.12 * mink_bound_intensity
		body_wiggle += 0.22 * mink_bound_intensity
		tail_wave += 0.34 * mink_bound_intensity
	if mink_swim:
		stretch += 0.08 * mink_swim_intensity
		body_wiggle += 0.18 * mink_swim_intensity
		tail_wave += 0.58 * mink_swim_intensity
	if mink_choke:
		stretch += 0.18
		body_wiggle += 0.28
		tail_wave += 0.22
	if otter_swim:
		stretch += 0.1 * otter_motion_intensity
		body_wiggle += 0.2 * otter_motion_intensity
		tail_wave += 0.62 * otter_motion_intensity
	if otter_land_slide:
		stretch += 0.08 * otter_motion_intensity
		body_wiggle += 0.12 * otter_motion_intensity
		tail_wave += 0.28 * otter_motion_intensity
	if otter_pack_latch:
		stretch += 0.1
		body_wiggle += 0.22
		tail_wave += 0.32
	var water_tint := Color(0.2, 0.6, 0.85, 0.32 + 0.14 * surface_wake_intensity)
	var submerged_tint := Color(0.28, 0.56, 0.74, 0.16 + 0.1 * submerged_shrew_intensity)
	var shrew_dust := Color(0.48, 0.46, 0.42, 0.14 + 0.08 * shrew_land_skitter_intensity)
	var slick_tint := Color(0.86, 0.58, 0.32, 0.20 + 0.10 * slick_crawl_intensity)
	var newt_water := Color(0.38, 0.64, 0.78, 0.18 + 0.12 * newt_swim_intensity)
	var beaver_water := Color(0.42, 0.68, 0.82, 0.20 + 0.12 * beaver_swim_intensity)
	var beaver_dust := Color(0.42, 0.32, 0.22, 0.16 + 0.08 * beaver_lumber_intensity)
	var mink_dust := Color(0.72, 0.66, 0.56, 0.18 + 0.08 * mink_bound_intensity)
	var mink_water := Color(0.38, 0.66, 0.82, 0.20 + 0.12 * mink_swim_intensity)
	var otter_water := Color(0.36, 0.66, 0.82, 0.22 + 0.12 * otter_motion_intensity)
	var otter_slide_dust := Color(0.58, 0.52, 0.42, 0.14 + 0.08 * otter_motion_intensity)

	if surface_walk:
		for wake_side: float in [-1.0, 1.0]:
			var wake_center := -forward * radius * 0.2 + side * wake_side * radius * 0.55
			canvas.draw_arc(wake_center, radius * (0.42 + 0.16 * surface_wake_intensity), -0.5, 0.9, 10, water_tint, 1.5 + surface_wake_intensity)
			var streak_origin := -forward * radius * (0.45 + 0.16 * surface_wake_intensity) + side * wake_side * radius * 0.44
			canvas.draw_line(streak_origin, streak_origin - forward * radius * (0.62 + 0.24 * surface_wake_intensity) + side * wake_side * radius * 0.18, Color(water_tint.r, water_tint.g, water_tint.b, water_tint.a * 0.7), maxf(1.0, radius * 0.07))
			canvas.draw_arc(wake_center + forward * radius * 0.18, radius * (0.18 + 0.05 * surface_wake_intensity), PI * 0.08, PI * 0.9, 8, Color(water_tint.r, water_tint.g, water_tint.b, water_tint.a * 0.82), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(wake_center + forward * radius * 0.32, maxf(radius * (0.045 + 0.018 * surface_wake_intensity), 1.0), water_tint.lightened(0.22))
	if shrew_land_skitter:
		for dust_side: float in [-1.0, 1.0]:
			var dust_start := -forward * radius * 0.36 + side * dust_side * radius * 0.32
			canvas.draw_line(dust_start, dust_start - forward * radius * (0.52 + 0.16 * shrew_land_skitter_intensity) + side * dust_side * radius * 0.12, shrew_dust, maxf(radius * 0.045, 1.0))
			canvas.draw_arc(dust_start + forward * radius * 0.12, radius * (0.22 + 0.05 * shrew_land_skitter_intensity), PI * 0.1, PI * 0.9, 8, shrew_dust, maxf(radius * 0.04, 1.0))
			canvas.draw_line(dust_start + forward * radius * 0.18, dust_start + forward * radius * 0.4 + side * dust_side * radius * 0.08, Color(shrew_dust.r, shrew_dust.g, shrew_dust.b, shrew_dust.a * 0.8), maxf(radius * 0.035, 1.0))
	if mink_bound:
		var bound_phase := sin(walk_phase * 1.4)
		var shadow_center := -forward * radius * (0.18 + 0.12 * bound_phase)
		canvas.draw_arc(shadow_center, radius * (0.74 + 0.1 * mink_bound_intensity), PI * 0.08, PI * 0.92, 14, mink_dust, maxf(radius * 0.07, 1.4))
		canvas.draw_line(-forward * radius * 0.72, -forward * radius * (1.35 + 0.26 * mink_bound_intensity), Color(mink_dust.r, mink_dust.g, mink_dust.b, mink_dust.a * 0.75), maxf(radius * 0.06, 1.2))
	if beaver_lumber:
		var stomp_phase := sin(walk_phase * 0.72)
		var drag_center := -forward * radius * (0.72 + 0.08 * stomp_phase)
		canvas.draw_arc(drag_center, radius * (0.82 + 0.08 * beaver_lumber_intensity), PI * 0.08, PI * 0.92, 14, beaver_dust, maxf(radius * 0.08, 1.4))
		canvas.draw_line(-forward * radius * 0.86, -forward * radius * (1.52 + 0.18 * beaver_lumber_intensity), Color(beaver_dust.r, beaver_dust.g, beaver_dust.b, beaver_dust.a * 0.78), maxf(radius * 0.08, 1.3))
		canvas.draw_line(-forward * radius * 0.42, -forward * radius * (1.2 + 0.14 * beaver_lumber_intensity), Color(beaver_dust.r, beaver_dust.g, beaver_dust.b, beaver_dust.a * 0.64), maxf(radius * 0.11, 1.5))
		for drag_side: float in [-1.0, 1.0]:
			var foot_drag := -forward * radius * 0.22 + side * drag_side * radius * 0.5
			canvas.draw_line(foot_drag, foot_drag - forward * radius * (0.42 + 0.12 * beaver_lumber_intensity), Color(beaver_dust.r, beaver_dust.g, beaver_dust.b, 0.16 + 0.08 * beaver_lumber_intensity), maxf(radius * 0.055, 1.0))
	if mink_swim:
		for wake_side: float in [-1.0, 1.0]:
			var wake_start := -forward * radius * 0.45 + side * wake_side * radius * 0.38
			canvas.draw_line(wake_start, wake_start - forward * radius * (0.76 + 0.24 * mink_swim_intensity) + side * wake_side * radius * 0.16, mink_water, maxf(radius * 0.06, 1.2))
			canvas.draw_arc(wake_start + forward * radius * 0.1, radius * (0.28 + 0.08 * mink_swim_intensity), -0.35, 0.85, 12, Color(mink_water.r, mink_water.g, mink_water.b, mink_water.a * 0.75), maxf(radius * 0.04, 1.0))
	if newt_swim:
		for wake_side: float in [-1.0, 1.0]:
			var wake_start := -forward * radius * 0.5 + side * wake_side * radius * 0.26
			canvas.draw_line(wake_start, wake_start - forward * radius * (0.62 + 0.2 * newt_swim_intensity) + side * wake_side * radius * 0.14, newt_water, maxf(radius * 0.045, 1.0))
			canvas.draw_arc(wake_start + forward * radius * 0.08, radius * (0.16 + 0.05 * newt_swim_intensity), -0.28, TAU * 0.62, 10, Color(newt_water.r, newt_water.g, newt_water.b, newt_water.a * 0.72), maxf(radius * 0.035, 1.0))
			canvas.draw_circle(wake_start - forward * radius * (0.42 + 0.12 * newt_swim_intensity), maxf(radius * (0.032 + 0.014 * newt_swim_intensity), 1.0), newt_water.lightened(0.28))
	if submerged_shrew and submerged_shrew_intensity > 0.0:
		canvas.draw_line(-forward * radius * 0.2, -forward * radius * (0.86 + 0.18 * submerged_shrew_intensity), Color(submerged_tint.r, submerged_tint.g, submerged_tint.b, submerged_tint.a * 0.72), maxf(radius * 0.045, 1.0))
		for dive_side: float in [-1.0, 1.0]:
			var dive_start := -forward * radius * 0.18 + side * dive_side * radius * 0.26
			canvas.draw_line(dive_start, dive_start - forward * radius * (0.56 + 0.16 * submerged_shrew_intensity) + side * dive_side * radius * 0.12, Color(submerged_tint.r, submerged_tint.g, submerged_tint.b, submerged_tint.a * 0.66), maxf(radius * 0.04, 1.0))
	if otter_land_slide:
		var slide_center := -forward * radius * 0.35
		canvas.draw_arc(slide_center, radius * (0.72 + 0.1 * otter_motion_intensity), PI * 0.12, PI * 0.88, 14, otter_slide_dust, maxf(radius * 0.07, 1.2))
		canvas.draw_line(-forward * radius * 0.65, -forward * radius * (1.5 + 0.24 * otter_motion_intensity), Color(otter_slide_dust.r, otter_slide_dust.g, otter_slide_dust.b, otter_slide_dust.a * 0.75), maxf(radius * 0.05, 1.1))
		canvas.draw_arc(slide_center + forward * radius * 0.18, radius * (0.46 + 0.08 * otter_motion_intensity), PI * 0.08, PI * 0.92, 12, Color(otter_slide_dust.r, otter_slide_dust.g, otter_slide_dust.b, otter_slide_dust.a * 0.62), maxf(radius * 0.045, 1.0))
		for skid_side: float in [-1.0, 1.0]:
			var skid_start := -forward * radius * 0.15 + side * skid_side * radius * 0.46
			canvas.draw_line(skid_start, skid_start - forward * radius * (0.82 + 0.22 * otter_motion_intensity) + side * skid_side * radius * 0.08, Color(otter_slide_dust.r, otter_slide_dust.g, otter_slide_dust.b, 0.16 + 0.08 * otter_motion_intensity), maxf(radius * 0.055, 1.1))
			canvas.draw_circle(skid_start + forward * radius * 0.2, maxf(radius * (0.08 + 0.025 * otter_motion_intensity), 1.0), Color(otter_slide_dust.r, otter_slide_dust.g, otter_slide_dust.b, 0.15 + 0.07 * otter_motion_intensity))
	if otter_swim:
		for wake_side: float in [-1.0, 1.0]:
			var wake_start := -forward * radius * 0.55 + side * wake_side * radius * 0.46
			canvas.draw_line(wake_start, wake_start - forward * radius * (0.85 + 0.32 * otter_motion_intensity) + side * wake_side * radius * 0.18, otter_water, maxf(radius * 0.07, 1.3))
			canvas.draw_arc(wake_start + forward * radius * 0.16, radius * (0.32 + 0.08 * otter_motion_intensity), -0.35, 0.92, 12, Color(otter_water.r, otter_water.g, otter_water.b, otter_water.a * 0.76), maxf(radius * 0.045, 1.0))
			canvas.draw_circle(wake_start + forward * radius * 0.32, maxf(radius * (0.05 + 0.02 * otter_motion_intensity), 1.0), Color(otter_water.r, otter_water.g, otter_water.b, otter_water.a * 0.7))
		canvas.draw_line(-forward * radius * 0.22, -forward * radius * (1.35 + 0.22 * otter_motion_intensity), Color(otter_water.r, otter_water.g, otter_water.b, 0.18 + 0.08 * otter_motion_intensity), maxf(radius * 0.05, 1.0))

	var spine: Array[Vector2] = []
	var segment_radii: Array[float] = []
	for i in 7:
		var t := float(i) / 6.0
		var along := lerpf(-1.35, 1.15, t) * radius * stretch
		var wiggle := 0.0
		if moving and strike <= 0.0:
			wiggle = sin(walk_phase * 1.2 - t * 2.2) * radius * 0.07 * body_wiggle * (1.0 - t * 0.5)
		spine.append(forward * along + side * wiggle)
		segment_radii.append(radius * lerpf(0.42, 0.5, sin(t * PI)) * bulk)
	if mink_choke:
		var hold_color := Color(0.95, 0.78, 0.42, 0.34)
		canvas.draw_line(spine[5] + side * radius * 0.18, spine[6] + forward * radius * 0.72 + side * radius * 0.34, hold_color, maxf(radius * 0.08, 1.4))
		canvas.draw_line(spine[5] - side * radius * 0.18, spine[6] + forward * radius * 0.72 - side * radius * 0.34, hold_color, maxf(radius * 0.08, 1.4))
		canvas.draw_arc(spine[6] + forward * radius * 0.28, radius * 0.42, -PI * 0.35, PI * 0.35, 16, Color(hold_color.r, hold_color.g, hold_color.b, 0.26), maxf(radius * 0.08, 1.2))
	if otter_pack_latch:
		var pack_color := Color(0.52, 0.76, 0.88, 0.28)
		for pack_side: float in [-1.0, 1.0]:
			canvas.draw_line(spine[3] + side * pack_side * radius * 0.72, spine[6] + forward * radius * 0.9 + side * pack_side * radius * 0.42, pack_color, maxf(radius * 0.08, 1.4))
			canvas.draw_arc(spine[4] + side * pack_side * radius * 0.36, radius * 0.44, -PI * 0.2, PI * 0.8, 16, Color(pack_color.r, pack_color.g, pack_color.b, 0.18), maxf(radius * 0.06, 1.1))

	var tail_style := String(skin.get("tail", "bushy"))
	var tail_direction := (-forward).rotated((sin(walk_phase * 1.4 + 1.8) * 0.3 * tail_wave) if moving else 0.12)
	var tail_base: Vector2 = spine[0]
	match tail_style:
		"paddle":
			if beaver_swim:
				for wake_side: float in [-1.0, 1.0]:
					var wake_start := tail_base + tail_direction * radius * 0.65 + side * wake_side * radius * 0.24
					canvas.draw_line(wake_start, wake_start + tail_direction * radius * (0.8 + 0.28 * beaver_swim_intensity) + side * wake_side * radius * 0.28, beaver_water, maxf(radius * 0.08, 1.5))
					canvas.draw_arc(wake_start + tail_direction * radius * 0.25, radius * (0.26 + 0.08 * beaver_swim_intensity), -0.35, TAU * 0.68, 12, Color(beaver_water.r, beaver_water.g, beaver_water.b, beaver_water.a * 0.78), maxf(radius * 0.05, 1.0))
			if beaver_lumber:
				tail_direction = (-forward).rotated(sin(walk_phase * 0.72) * 0.12 * beaver_lumber_intensity)
			var paddle_center := tail_base + tail_direction * radius * (1.0 + 0.18 * beaver_swim_intensity)
			var paddle_points := PackedVector2Array()
			for i in 12:
				var paddle_angle := TAU * float(i) / 12.0
				paddle_points.append(paddle_center + tail_direction * cos(paddle_angle) * radius * (0.7 + 0.08 * beaver_swim_intensity) + side * sin(paddle_angle) * radius * (0.42 + 0.08 * beaver_swim_intensity))
			canvas.draw_colored_polygon(paddle_points, Color(0.16, 0.12, 0.1))
			canvas.draw_line(paddle_center - side * radius * 0.3, paddle_center + side * radius * 0.3, Color(0.1, 0.08, 0.07), 1.5)
			if beaver_swim:
				canvas.draw_arc(paddle_center - tail_direction * radius * 0.08, radius * (0.54 + 0.1 * beaver_swim_intensity), -PI * 0.1, PI * 0.9, 16, Color(beaver_water.r, beaver_water.g, beaver_water.b, 0.24 + 0.08 * beaver_swim_intensity), maxf(radius * 0.07, 1.2))
				canvas.draw_line(paddle_center - tail_direction * radius * 0.18, paddle_center + tail_direction * radius * (0.72 + 0.18 * beaver_swim_intensity), Color(beaver_water.r, beaver_water.g, beaver_water.b, 0.2 + 0.1 * beaver_swim_intensity), maxf(radius * 0.08, 1.2))
				canvas.draw_circle(paddle_center + tail_direction * radius * 0.36, maxf(radius * (0.06 + 0.025 * beaver_swim_intensity), 1.1), Color(beaver_water.r, beaver_water.g, beaver_water.b, 0.22 + 0.1 * beaver_swim_intensity))
				for slap_side: float in [-1.0, 1.0]:
					canvas.draw_circle(paddle_center + tail_direction * radius * (0.52 + 0.08 * beaver_swim_intensity) + side * slap_side * radius * 0.24, maxf(radius * (0.04 + 0.018 * beaver_swim_intensity), 1.0), Color(beaver_water.r, beaver_water.g, beaver_water.b, 0.2 + 0.09 * beaver_swim_intensity))
			if beaver_lumber:
				canvas.draw_line(paddle_center, paddle_center - forward * radius * (0.38 + 0.08 * beaver_lumber_intensity), Color(beaver_dust.r, beaver_dust.g, beaver_dust.b, beaver_dust.a * 0.8), maxf(radius * 0.06, 1.1))
				canvas.draw_arc(paddle_center - forward * radius * 0.18, radius * (0.34 + 0.06 * beaver_lumber_intensity), PI * 0.08, PI * 0.92, 10, Color(beaver_dust.r, beaver_dust.g, beaver_dust.b, beaver_dust.a * 0.62), maxf(radius * 0.045, 1.0))
		"fin":
			if tail_lost_pose:
				canvas.draw_circle(tail_base + tail_direction * radius * 0.25, radius * 0.2, fur_dark.lightened(0.15))
				canvas.draw_circle(tail_base + tail_direction * radius * 0.38, radius * 0.08, Color(0.95, 0.38, 0.24, 0.85))
			else:
				if newt_swim:
					for wake_side: float in [-1.0, 1.0]:
						var wake_start := tail_base + tail_direction * radius * 0.82 + side * wake_side * radius * 0.12
						canvas.draw_line(wake_start, wake_start + tail_direction * radius * (0.46 + 0.2 * newt_swim_intensity) + side * wake_side * radius * 0.16, newt_water, maxf(radius * 0.05, 1.0))
						canvas.draw_circle(wake_start + tail_direction * radius * (0.32 + 0.12 * newt_swim_intensity), maxf(radius * (0.035 + 0.014 * newt_swim_intensity), 1.0), newt_water.lightened(0.25))
				canvas.draw_colored_polygon(PackedVector2Array([
					tail_base + side * radius * 0.16,
					tail_base + tail_direction * radius * (1.3 + 0.1 * newt_swim_intensity),
					tail_base - side * radius * 0.16
				]), fur_dark.lightened(0.08))
		"thick":
			for i in 4:
				var t := float(i) / 3.0
				var tail_pos := tail_base + tail_direction * radius * (0.35 + t * (1.1 + 0.16 * otter_motion_intensity))
				canvas.draw_circle(tail_pos, radius * lerpf(0.32 + 0.04 * otter_motion_intensity, 0.14, t), fur_dark)
				if otter_swim and t > 0.2:
					canvas.draw_circle(tail_pos - forward * radius * 0.12, maxf(radius * lerpf(0.08, 0.04, t), 1.0), otter_water.lightened(0.2))
				if otter_land_slide and t > 0.2:
					canvas.draw_line(tail_pos, tail_pos - forward * radius * (0.24 + 0.1 * otter_motion_intensity), Color(otter_slide_dust.r, otter_slide_dust.g, otter_slide_dust.b, 0.2 + 0.08 * otter_motion_intensity), maxf(radius * 0.045, 1.0))
		_:
			for i in 4:
				var t := float(i) / 3.0
				canvas.draw_circle(tail_base + tail_direction * radius * (0.35 + t * 1.0), radius * lerpf(0.3, 0.12, t), fur_dark)

	if moving and strike <= 0.0:
		for paw_index in 4:
			var paw_t := [0.22, 0.36, 0.72, 0.86][paw_index] as float
			var paw_side := 1.0 if paw_index % 2 == 0 else -1.0
			var paw_step := sin(walk_phase * 1.4 + PI * float(paw_index)) * radius * 0.14
			var paw_reach := radius * (0.66 if slick_crawl else 0.5) * bulk
			if mink_bound:
				paw_step += sin(walk_phase * 1.4 + PI * float(paw_index)) * radius * 0.13 * mink_bound_intensity
				paw_reach += radius * 0.08 * mink_bound_intensity
			if mink_swim:
				paw_step += sin(walk_phase * 1.6 + PI * float(paw_index)) * radius * 0.1 * mink_swim_intensity
				paw_reach += radius * 0.06 * mink_swim_intensity
			if beaver_lumber:
				paw_step += sin(walk_phase * 0.72 + PI * float(paw_index)) * radius * 0.05 * beaver_lumber_intensity
				paw_reach += radius * 0.05 * beaver_lumber_intensity
			if shrew_land_skitter:
				paw_step += sin(walk_phase * 2.1 + PI * float(paw_index)) * radius * 0.08 * shrew_land_skitter_intensity
				paw_reach += radius * 0.08 * shrew_land_skitter_intensity
			var paw := spine[2].lerp(spine[5], paw_t) + side * paw_side * paw_reach + forward * paw_step
			canvas.draw_circle(paw, radius * (0.09 if slick_crawl else 0.13), fur_dark)
			if slick_crawl:
				canvas.draw_line(paw, paw + side * paw_side * radius * 0.2 + forward * radius * 0.05, fur_dark.lightened(0.1), 1.0)
			if newt_swim:
				canvas.draw_circle(paw - forward * radius * 0.08, maxf(radius * (0.04 + 0.025 * newt_swim_intensity), 1.0), newt_water.lightened(0.2))
			if mink_bound:
				canvas.draw_line(paw, paw - forward * radius * (0.22 + 0.08 * mink_bound_intensity), fur_dark.lightened(0.08), 1.0)
			if mink_swim:
				canvas.draw_circle(paw - forward * radius * 0.1, maxf(radius * (0.045 + 0.025 * mink_swim_intensity), 1.0), mink_water.lightened(0.18))
			if otter_land_slide:
				canvas.draw_line(paw, paw - forward * radius * (0.18 + 0.08 * otter_motion_intensity), fur_dark.lightened(0.08), 1.0)
			if surface_walk:
				canvas.draw_circle(paw + side * paw_side * radius * 0.08, maxf(radius * (0.08 + 0.03 * surface_wake_intensity), 1.2), water_tint.lightened(0.2))
			if shrew_land_skitter:
				canvas.draw_line(paw, paw - forward * radius * (0.2 + 0.08 * shrew_land_skitter_intensity), fur_dark.lightened(0.08), 1.0)
			if beaver_swim:
				canvas.draw_circle(paw - forward * radius * 0.1, maxf(radius * (0.06 + 0.03 * beaver_swim_intensity), 1.1), beaver_water.lightened(0.2))
			if beaver_lumber:
				canvas.draw_arc(paw - forward * radius * 0.1, radius * (0.2 + 0.04 * beaver_lumber_intensity), PI * 0.1, PI * 0.9, 8, beaver_dust, maxf(radius * 0.05, 1.0))
			if otter_swim:
				canvas.draw_circle(paw - forward * radius * 0.12, maxf(radius * (0.05 + 0.03 * otter_motion_intensity), 1.0), otter_water.lightened(0.2))

	if slick_crawl:
		for trail_index in 4:
			var t := float(trail_index) / 3.0
			var trail_center := -forward * radius * (0.2 + t * 1.1) + side * sin(walk_phase * 1.1 + t * 2.0) * radius * 0.16
			canvas.draw_arc(trail_center, radius * (0.2 + t * 0.08), -0.3, TAU * 0.65, 12, slick_tint, 1.0)
		for crawl_side: float in [-1.0, 1.0]:
			var track_start := -forward * radius * 0.22 + side * crawl_side * radius * 0.5
			canvas.draw_line(track_start, track_start - forward * radius * (0.52 + 0.14 * slick_crawl_intensity) + side * crawl_side * radius * 0.12, Color(slick_tint.r, slick_tint.g, slick_tint.b, slick_tint.a * 0.72), maxf(radius * 0.045, 1.0))
			canvas.draw_circle(track_start + forward * radius * 0.12, maxf(radius * (0.045 + 0.018 * slick_crawl_intensity), 1.0), Color(slick_tint.r, slick_tint.g, slick_tint.b, slick_tint.a * 0.66))
			canvas.draw_circle(track_start - forward * radius * (0.3 + 0.08 * slick_crawl_intensity) + side * crawl_side * radius * 0.08, maxf(radius * (0.032 + 0.014 * slick_crawl_intensity), 1.0), Color(slick_tint.r, slick_tint.g, slick_tint.b, slick_tint.a * 0.58))

	for i in 7:
		canvas.draw_circle(spine[i], segment_radii[i] + 2.0, fur_dark)
	for i in 7:
		canvas.draw_circle(spine[i], segment_radii[i], fur.darkened(0.28) if submerged_shrew else fur)
	if slick_crawl:
		var belly_sheen := Color(slick_tint.r, slick_tint.g, slick_tint.b, 0.14 + 0.06 * slick_crawl_intensity)
		for sheen_index in 4:
			var t := 0.22 + float(sheen_index) * 0.16
			var sheen_center := spine[1].lerp(spine[5], t) + side * sin(walk_phase * 1.1 + float(sheen_index)) * radius * 0.08
			canvas.draw_circle(sheen_center, radius * (0.1 + 0.02 * slick_crawl_intensity), belly_sheen)
	if otter_land_slide:
		var belly_slick := Color(belly.r, belly.g, belly.b, 0.16 + 0.06 * otter_motion_intensity)
		for slick_index in 3:
			var t := 0.32 + float(slick_index) * 0.18
			canvas.draw_circle(spine[2].lerp(spine[5], t) - forward * radius * 0.05, radius * (0.16 + 0.03 * otter_motion_intensity), belly_slick)
	if mink_bound:
		var bound_flash := Color(belly.r, belly.g, belly.b, 0.22 + 0.08 * mink_bound_intensity)
		for flash_index in 3:
			var t := 0.36 + float(flash_index) * 0.16
			var flash_center := spine[2].lerp(spine[5], t) + side * sin(walk_phase * 1.4 + float(flash_index)) * radius * 0.1
			canvas.draw_circle(flash_center, radius * (0.13 + 0.025 * mink_bound_intensity), bound_flash)
		for snap_side: float in [-1.0, 1.0]:
			var snap_start := spine[4] + side * snap_side * radius * 0.5 - forward * radius * 0.1
			canvas.draw_line(snap_start, snap_start - forward * radius * (0.55 + 0.16 * mink_bound_intensity) + side * snap_side * radius * 0.16, Color(mink_dust.r, mink_dust.g, mink_dust.b, 0.22 + 0.08 * mink_bound_intensity), maxf(radius * 0.045, 1.0))
			canvas.draw_circle(snap_start + forward * radius * 0.18, maxf(radius * (0.055 + 0.02 * mink_bound_intensity), 1.0), Color(mink_dust.r, mink_dust.g, mink_dust.b, 0.22 + 0.08 * mink_bound_intensity))
			canvas.draw_line(snap_start + forward * radius * 0.08, snap_start + forward * radius * 0.36 + side * snap_side * radius * 0.08, Color(mink_dust.r, mink_dust.g, mink_dust.b, 0.2 + 0.08 * mink_bound_intensity), maxf(radius * 0.035, 1.0))
	if bool(skin.get("spots", false)):
		var accent: Color = skin.get("accent", Color(0.9, 0.5, 0.15))
		for i in 6:
			canvas.draw_circle(spine[i] + side * (radius * 0.18 if i % 2 == 0 else radius * -0.18), maxf(radius * 0.08, 1.5), accent)
	if surface_walk:
		for bubble_index in 6:
			var t := float(bubble_index) / 5.0
			var bubble := -forward * radius * (0.45 + t * (1.0 + 0.45 * surface_wake_intensity)) + side * sin(walk_phase * 1.6 + t * 3.1) * radius * (0.2 + 0.22 * surface_wake_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.04 + t * 0.035 + surface_wake_intensity * 0.015), 1.0), water_tint.lightened(0.25))
	elif submerged_shrew:
		for bubble_index in 4:
			var t := float(bubble_index) / 3.0
			var bubble := -forward * radius * (0.12 + t * (0.62 + 0.18 * submerged_shrew_intensity)) + side * sin(walk_phase * 1.25 + t * 2.6) * radius * (0.18 + 0.16 * submerged_shrew_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.045 + t * 0.025), 1.0), submerged_tint.lightened(0.3))
	elif newt_swim:
		for bubble_index in 4:
			var t := float(bubble_index) / 3.0
			var bubble := -forward * radius * (0.25 + t * 0.86) + side * sin(walk_phase * 1.15 + t * 2.8) * radius * (0.14 + 0.14 * newt_swim_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.035 + t * 0.03), 1.0), newt_water.lightened(0.25))
	elif beaver_swim:
		for bubble_index in 4:
			var t := float(bubble_index) / 3.0
			var bubble := -forward * radius * (0.35 + t * 0.95) + side * sin(walk_phase * 0.9 + t * 2.7) * radius * (0.2 + 0.12 * beaver_swim_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.04 + t * 0.035), 1.0), beaver_water.lightened(0.25))
	elif mink_swim:
		for bubble_index in 4:
			var t := float(bubble_index) / 3.0
			var bubble := -forward * radius * (0.32 + t * 0.95) + side * sin(walk_phase * 1.25 + t * 2.4) * radius * (0.16 + 0.14 * mink_swim_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.035 + t * 0.03), 1.0), mink_water.lightened(0.25))
		canvas.draw_line(-forward * radius * 0.28, -forward * radius * (1.18 + 0.18 * mink_swim_intensity), Color(mink_water.r, mink_water.g, mink_water.b, 0.18 + 0.08 * mink_swim_intensity), maxf(radius * 0.04, 1.0))
		canvas.draw_circle(-forward * radius * 0.64, maxf(radius * (0.045 + 0.02 * mink_swim_intensity), 1.0), Color(mink_water.r, mink_water.g, mink_water.b, 0.24 + 0.08 * mink_swim_intensity))
	elif otter_swim:
		for bubble_index in 5:
			var t := float(bubble_index) / 4.0
			var bubble := -forward * radius * (0.35 + t * 1.2) + side * sin(walk_phase * 1.35 + t * 2.4) * radius * (0.18 + 0.16 * otter_motion_intensity)
			canvas.draw_circle(bubble, maxf(radius * (0.035 + t * 0.03), 1.0), otter_water.lightened(0.25))

	var head: Vector2 = spine[6]
	if not bool(skin.get("smooth", false)):
		canvas.draw_circle(head + side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
		canvas.draw_circle(head - side * radius * 0.28 - forward * radius * 0.1, radius * 0.14, fur_dark)
	canvas.draw_circle(head, radius * 0.4 * bulk, fur)
	canvas.draw_circle(head + forward * radius * 0.28 * snout, radius * 0.18, fur.lightened(0.18))
	canvas.draw_circle(head + forward * radius * (0.34 * snout), maxf(radius * 0.07, 1.2), Color(0.1, 0.07, 0.05))
	canvas.draw_circle(head + forward * radius * 0.16, maxf(radius * 0.09, 1.4), belly)
	canvas.draw_circle(head + side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_circle(head - side * radius * 0.16 + forward * radius * 0.16, maxf(radius * 0.05, 1.0), Color(0.08, 0.05, 0.04))
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 + side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)
	canvas.draw_line(head + forward * radius * 0.24, head + forward * radius * 0.44 - side * radius * 0.22, Color(0.8, 0.78, 0.7, 0.7), 1.0)

	if strike > 0.25:
		var fang_origin := head + forward * radius * 0.4
		canvas.draw_line(fang_origin + side * 2.0, fang_origin + forward * radius * 0.4 + side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)
		canvas.draw_line(fang_origin - side * 2.0, fang_origin + forward * radius * 0.4 - side * 2.0, Color(0.98, 0.98, 0.92, strike), 2.0)
	if mink_choke:
		var fang_origin := head + forward * radius * 0.38
		canvas.draw_line(fang_origin + side * radius * 0.12, fang_origin + forward * radius * 0.58 + side * radius * 0.28, Color(0.98, 0.92, 0.72, 0.82), maxf(radius * 0.09, 1.6))
		canvas.draw_line(fang_origin - side * radius * 0.12, fang_origin + forward * radius * 0.58 - side * radius * 0.28, Color(0.98, 0.92, 0.72, 0.82), maxf(radius * 0.09, 1.6))
	if otter_pack_latch:
		canvas.draw_arc(head + forward * radius * 0.28, radius * 0.68, -PI * 0.28, PI * 0.28, 16, Color(0.72, 0.9, 1.0, 0.22), maxf(radius * 0.08, 1.4))

static func _base_bird(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, airborne: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.4, 0.32, 0.22))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var breast: Color = skin.get("breast", main.lightened(0.25))
	var beak: Color = skin.get("beak", Color(0.8, 0.7, 0.35))
	var beak_len := float(skin.get("beak_len", 0.4))
	var neck := float(skin.get("neck", 0.0))
	var head_color: Color = skin.get("head_color", main)
	var bird_stride := float(anim.get("bird_stride", 1.0))
	var wingbeat := float(anim.get("wingbeat_mult", 1.0))
	var perch_flutter := float(anim.get("perch_flutter", 1.0))
	var waddle_sway := float(anim.get("waddle_sway", 0.0))
	var perched_pose := bool(anim.get("perched_pose", false))
	var plunge_t := clampf(float(anim.get("plunge_t", 0.0)), 0.0, 1.0)
	var plunge_pose := String(anim.get("creature_id", "")) == "kingfisher" and plunge_t > 0.0
	var wading_pose := String(anim.get("creature_id", "")) == "great_blue_heron" and bool(anim.get("wading_pose", false))
	var wading_stride := clampf(float(anim.get("wading_stride", 0.0)), 0.0, 1.25)
	var heron_stalk := String(anim.get("creature_id", "")) == "great_blue_heron" and bool(anim.get("heron_stalk_pose", false))
	var heron_stalk_intensity := clampf(float(anim.get("heron_stalk_intensity", 0.0)), 0.0, 1.25)
	var duck_paddle := String(anim.get("creature_id", "")) == "duck" and bool(anim.get("duck_paddle_pose", false))
	var duck_paddle_intensity := clampf(float(anim.get("duck_paddle_intensity", 0.0)), 0.0, 1.25)
	var duck_waddle := String(anim.get("creature_id", "")) == "duck" and bool(anim.get("duck_waddle_pose", false))
	var duck_waddle_intensity := clampf(float(anim.get("duck_waddle_intensity", 0.0)), 0.0, 1.25)
	var owl_glide := String(anim.get("creature_id", "")) == "owl" and bool(anim.get("owl_glide_pose", false))
	var owl_glide_intensity := clampf(float(anim.get("owl_glide_intensity", 0.0)), 0.0, 1.25)
	var owl_silent := String(anim.get("creature_id", "")) == "owl" and bool(anim.get("owl_silent_flight_pose", false))
	var kingfisher_dart := String(anim.get("creature_id", "")) == "kingfisher" and bool(anim.get("kingfisher_dart_pose", false))
	var kingfisher_dart_intensity := clampf(float(anim.get("kingfisher_dart_intensity", 0.0)), 0.0, 1.25)
	var low_window_t := clampf(float(anim.get("low_window_t", 0.0)), 0.0, 1.0)
	var takeoff_charge_t := clampf(float(anim.get("takeoff_charge_t", 0.0)), 0.0, 1.0)
	var takeoff_flap_t := clampf(float(anim.get("takeoff_flap_t", 0.0)), 0.0, 1.0)
	var landing_flap_t := clampf(float(anim.get("landing_flap_t", 0.0)), 0.0, 1.0)
	var grounded_lockout_t := clampf(float(anim.get("grounded_lockout_t", 0.0)), 0.0, 1.0)

	# Tail fan.
	canvas.draw_colored_polygon(PackedVector2Array([
		-forward * radius * 0.5 + side * radius * 0.22,
		-forward * radius * (1.15 + (0.1 if airborne else 0.0)) + side * radius * 0.4,
		-forward * radius * (1.2 + (0.1 if airborne else 0.0)),
		-forward * radius * (1.15 + (0.1 if airborne else 0.0)) - side * radius * 0.4,
		-forward * radius * 0.5 - side * radius * 0.22
	]), dark)

	if airborne:
		# Extended flapping wings.
		var flap_amp := (0.12 if owl_glide else 0.48 if kingfisher_dart else 0.35) + takeoff_flap_t * 0.26 + landing_flap_t * 0.16
		var flap := sin(Time.get_ticks_msec() * 0.012 * wingbeat + walk_phase * perch_flutter) * flap_amp
		for wing_side: float in [-1.0, 1.0]:
			var glide_width := 0.52 * owl_glide_intensity if owl_glide else 0.0
			var glide_forward := -0.18 * owl_glide_intensity if owl_glide else 0.0
			var dart_tuck := 0.26 * kingfisher_dart_intensity if kingfisher_dart else 0.0
			var dart_forward := 0.24 * kingfisher_dart_intensity if kingfisher_dart else 0.0
			var transition_width := takeoff_flap_t * 0.28 + landing_flap_t * 0.34
			var transition_forward := takeoff_flap_t * -0.18 + landing_flap_t * 0.18
			var wing_tip := side * wing_side * radius * (1.9 + glide_width + transition_width - plunge_t * 0.45 - low_window_t * 0.32 - dart_tuck) + forward * radius * (0.1 + glide_forward + transition_forward + dart_forward + flap * wing_side * wing_side + plunge_t * 0.32 + low_window_t * 0.28)
			canvas.draw_colored_polygon(
				_bird_wing_points(radius, forward, side, wing_side, wing_tip, flap),
				Color(dark.r, dark.g, dark.b, 0.72 if owl_silent else 1.0)
			)
			canvas.draw_line(forward * radius * 0.2 + side * wing_side * radius * 0.4, wing_tip, main.lightened(0.1), 2.0)
			if takeoff_flap_t > 0.0 or landing_flap_t > 0.0:
				var transition_color := Color(breast.r, breast.g, breast.b, 0.22 + maxf(takeoff_flap_t, landing_flap_t) * 0.16)
				canvas.draw_line(forward * radius * 0.02 + side * wing_side * radius * 0.76, wing_tip - forward * radius * 0.22, transition_color, 1.3)
			if owl_glide:
				canvas.draw_line(forward * radius * 0.05 + side * wing_side * radius * 0.62, wing_tip - forward * radius * 0.12, Color(breast.r, breast.g, breast.b, 0.28), 1.0)
				canvas.draw_arc(wing_tip - forward * radius * 0.12, radius * (0.34 + 0.08 * owl_glide_intensity), PI * 0.05, PI * 0.9, 12, Color(breast.r, breast.g, breast.b, 0.16 if owl_silent else 0.24), maxf(radius * 0.04, 1.0))
				for feather_index in 3:
					var feather_t := float(feather_index + 1) / 4.0
					var feather_root := wing_tip.lerp(forward * radius * 0.12 + side * wing_side * radius * 0.62, feather_t)
					var feather_tip := feather_root + side * wing_side * radius * (0.18 + 0.05 * owl_glide_intensity) - forward * radius * (0.22 + 0.04 * feather_t)
					canvas.draw_line(feather_root, feather_tip, Color(breast.r, breast.g, breast.b, 0.20 if owl_silent else 0.3), maxf(radius * 0.035, 1.0))
					canvas.draw_circle(feather_tip, maxf(radius * (0.035 + 0.012 * owl_glide_intensity), 1.0), Color(breast.r, breast.g, breast.b, 0.18 if owl_silent else 0.26))
				canvas.draw_circle(wing_tip - forward * radius * (0.24 + 0.06 * owl_glide_intensity), maxf(radius * (0.04 + 0.014 * owl_glide_intensity), 1.0), Color(breast.r, breast.g, breast.b, 0.16 if owl_silent else 0.24))
			if kingfisher_dart:
				canvas.draw_line(forward * radius * 0.12 + side * wing_side * radius * 0.55, wing_tip - forward * radius * (0.1 + 0.12 * kingfisher_dart_intensity), Color(0.52, 0.82, 1.0, 0.24 + 0.08 * kingfisher_dart_intensity), maxf(radius * 0.045, 1.0))
				canvas.draw_line(wing_tip + forward * radius * 0.12, wing_tip - forward * radius * (0.46 + 0.16 * kingfisher_dart_intensity), Color(0.86, 0.96, 1.0, 0.22 + 0.08 * kingfisher_dart_intensity), maxf(radius * 0.04, 1.0))
		if owl_silent:
			canvas.draw_colored_polygon(PackedVector2Array([
				-forward * radius * 0.85 + side * radius * 1.0,
				forward * radius * 0.22 + side * radius * 1.42,
				forward * radius * 0.82,
				forward * radius * 0.22 - side * radius * 1.42,
				-forward * radius * 0.85 - side * radius * 1.0
			]), Color(0.08, 0.09, 0.1, 0.16))
			canvas.draw_arc(Vector2.ZERO, radius * (1.18 + 0.08 * owl_glide_intensity), PI * 0.08, PI * 0.92, 24, Color(0.58, 0.62, 0.68, 0.12), maxf(radius * 0.055, 1.0))
			for hush_side: float in [-1.0, 1.0]:
				var hush_start := -forward * radius * 0.22 + side * hush_side * radius * 0.82
				canvas.draw_line(hush_start, hush_start - forward * radius * 0.78 + side * hush_side * radius * 0.18, Color(0.58, 0.62, 0.68, 0.12), maxf(radius * 0.045, 1.0))
				canvas.draw_circle(hush_start - forward * radius * 0.46 + side * hush_side * radius * 0.1, maxf(radius * 0.04, 1.0), Color(0.58, 0.62, 0.68, 0.12))
		if kingfisher_dart:
			var dart_color := Color(0.42, 0.76, 1.0, 0.18 + 0.1 * kingfisher_dart_intensity)
			canvas.draw_line(-forward * radius * 0.28, -forward * radius * (1.18 + 0.32 * kingfisher_dart_intensity), dart_color, maxf(radius * 0.08, 1.2))
			canvas.draw_line(forward * radius * 0.54, forward * radius * (1.22 + 0.24 * kingfisher_dart_intensity), Color(0.86, 0.96, 1.0, 0.26 + 0.08 * kingfisher_dart_intensity), maxf(radius * 0.07, 1.1))
			canvas.draw_circle(forward * radius * (0.82 + 0.12 * kingfisher_dart_intensity), maxf(radius * (0.055 + 0.018 * kingfisher_dart_intensity), 1.0), Color(0.86, 0.96, 1.0, 0.28 + 0.08 * kingfisher_dart_intensity))
			canvas.draw_line(forward * radius * (0.78 + 0.08 * kingfisher_dart_intensity), forward * radius * (1.46 + 0.18 * kingfisher_dart_intensity), Color(0.93, 0.98, 1.0, 0.22 + 0.1 * kingfisher_dart_intensity), maxf(radius * 0.035, 1.0))
			for streak_side: float in [-1.0, 1.0]:
				var streak_start := -forward * radius * 0.18 + side * streak_side * radius * 0.36
				canvas.draw_line(streak_start, streak_start - forward * radius * (0.78 + 0.28 * kingfisher_dart_intensity) + side * streak_side * radius * 0.12, Color(dart_color.r, dart_color.g, dart_color.b, dart_color.a * 0.78), maxf(radius * 0.045, 1.0))
				canvas.draw_circle(streak_start - forward * radius * (0.44 + 0.1 * kingfisher_dart_intensity), maxf(radius * 0.04, 1.0), Color(dart_color.r, dart_color.g, dart_color.b, dart_color.a * 0.72))
	else:
		# Folded wings hugging the body.
		for wing_side: float in [-1.0, 1.0]:
			var perch_tuck := 0.18 if perched_pose else 0.0
			var preflight_spread := takeoff_charge_t * 0.5 + landing_flap_t * 0.32
			canvas.draw_colored_polygon(PackedVector2Array([
				forward * radius * 0.4 + side * wing_side * radius * 0.35,
				-forward * radius * (0.9 - perch_tuck + preflight_spread * 0.16) + side * wing_side * radius * (0.55 - perch_tuck + preflight_spread * 0.72),
				-forward * radius * (0.2 + preflight_spread * 0.08) + side * wing_side * radius * (0.7 - perch_tuck + preflight_spread * 0.88)
			]), dark.lightened(0.06))
			if grounded_lockout_t > 0.0:
				canvas.draw_line(
					side * wing_side * radius * 0.48 - forward * radius * 0.18,
					side * wing_side * radius * (0.78 + grounded_lockout_t * 0.2) - forward * radius * 0.72,
					Color(1.0, 0.55, 0.25, 0.18 + grounded_lockout_t * 0.16),
					maxf(radius * 0.08, 1.3)
				)

	# Body.
	var body_points := PackedVector2Array()
	var duck_body_sway := sin(walk_phase * 0.82) * radius * 0.08 * duck_waddle_intensity if duck_waddle else 0.0
	for i in 14:
		var body_angle := TAU * float(i) / 14.0
		body_points.append(forward * cos(body_angle) * radius * 0.8 + side * (sin(body_angle) * radius * (0.62 + waddle_sway * 0.04) + duck_body_sway))
	if duck_paddle:
		var water_color := Color(0.48, 0.74, 0.86, 0.22 + duck_paddle_intensity * 0.08)
		for wake_side: float in [-1.0, 1.0]:
			var wake_center := -forward * radius * 0.2 + side * wake_side * radius * 0.56
			canvas.draw_arc(wake_center, radius * (0.38 + duck_paddle_intensity * 0.12), -0.35, 0.92, 14, water_color, 1.2 + duck_paddle_intensity * 0.6)
			var v_start := -forward * radius * 0.42 + side * wake_side * radius * 0.22
			canvas.draw_line(v_start, v_start - forward * radius * (0.74 + duck_paddle_intensity * 0.18) + side * wake_side * radius * 0.34, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.72), maxf(radius * 0.055, 1.0))
			canvas.draw_arc(v_start + side * wake_side * radius * 0.18, radius * (0.16 + 0.04 * duck_paddle_intensity), -0.25, TAU * 0.62, 10, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.66), maxf(radius * 0.035, 1.0))
			canvas.draw_circle(v_start + side * wake_side * radius * 0.14, maxf(radius * (0.04 + 0.014 * duck_paddle_intensity), 1.0), Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.74))
		canvas.draw_line(-forward * radius * 0.8, -forward * radius * (1.45 + duck_paddle_intensity * 0.16), Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.75), maxf(radius * 0.08, 1.3))
	if duck_waddle:
		var dust_color := Color(0.46, 0.36, 0.22, 0.16 + duck_waddle_intensity * 0.08)
		for dust_side: float in [-1.0, 1.0]:
			var dust_center := -forward * radius * 0.46 + side * dust_side * radius * (0.42 + 0.08 * duck_waddle_intensity)
			canvas.draw_arc(dust_center, radius * (0.22 + 0.04 * duck_waddle_intensity), PI * 0.06, PI * 0.9, 8, dust_color, maxf(radius * 0.045, 1.0))
			canvas.draw_line(dust_center + forward * radius * 0.04, dust_center + forward * radius * 0.22 + side * dust_side * radius * 0.12, Color(dust_color.r, dust_color.g, dust_color.b, dust_color.a * 0.78), maxf(radius * 0.035, 1.0))
			canvas.draw_circle(dust_center - forward * radius * 0.02 + side * dust_side * radius * 0.12, maxf(radius * 0.035, 1.0), Color(dust_color.r, dust_color.g, dust_color.b, dust_color.a * 0.82))
	if heron_stalk:
		var stalk_dust := Color(0.42, 0.36, 0.26, 0.12 + heron_stalk_intensity * 0.07)
		for dust_side: float in [-1.0, 1.0]:
			var dust_center := -forward * radius * 0.28 + side * dust_side * radius * 0.32
			canvas.draw_arc(dust_center, radius * (0.18 + 0.05 * heron_stalk_intensity), PI * 0.08, PI * 0.9, 8, stalk_dust, maxf(radius * 0.04, 1.0))
			canvas.draw_line(dust_center, dust_center + forward * radius * (0.2 + 0.08 * heron_stalk_intensity), Color(stalk_dust.r, stalk_dust.g, stalk_dust.b, stalk_dust.a * 0.78), maxf(radius * 0.035, 1.0))
	canvas.draw_colored_polygon(body_points, main)
	canvas.draw_circle(forward * radius * 0.3, radius * 0.34, breast)
	if bool(skin.get("barred", false)):
		for bar: float in [-0.45, -0.15, 0.15]:
			canvas.draw_line(forward * radius * bar - side * radius * 0.4, forward * radius * (bar - 0.12), dark.lightened(0.05), 1.5)
			canvas.draw_line(forward * radius * bar + side * radius * 0.4, forward * radius * (bar - 0.12), dark.lightened(0.05), 1.5)

	# Legs when grounded.
	if not airborne and (moving or perched_pose or wading_pose or heron_stalk or duck_paddle or duck_waddle):
		for leg_side: float in [-1.0, 1.0]:
			var leg_step := 0.0 if perched_pose else sin(walk_phase * 1.6 + (PI if leg_side > 0.0 else 0.0)) * radius * 0.12 * bird_stride
			if wading_pose:
				var wade_step := sin(walk_phase * 0.78 + (PI if leg_side > 0.0 else 0.0)) * radius * (0.28 + 0.16 * wading_stride)
				var hip := side * leg_side * radius * 0.18 - forward * radius * 0.05
				var knee := side * leg_side * radius * 0.26 + forward * wade_step
				var foot := side * leg_side * radius * 0.34 + forward * (wade_step + radius * 0.28)
				var water_color := Color(0.52, 0.78, 0.9, 0.28 + 0.12 * wading_stride)
				canvas.draw_arc(foot, radius * (0.22 + 0.08 * wading_stride), -0.2, TAU * 0.72, 16, water_color, 1.2 + wading_stride)
				canvas.draw_line(foot - forward * radius * 0.16, foot - forward * radius * (0.46 + 0.12 * wading_stride), Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.66), maxf(radius * 0.045, 1.0))
				canvas.draw_arc(foot - forward * radius * 0.22, radius * (0.34 + 0.08 * wading_stride), PI * 0.05, PI * 0.95, 12, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.62), maxf(radius * 0.04, 1.0))
				canvas.draw_circle(foot + forward * radius * 0.12, maxf(radius * (0.045 + 0.018 * wading_stride), 1.0), water_color.lightened(0.2))
				canvas.draw_line(hip, knee, beak.darkened(0.22), 1.6)
				canvas.draw_line(knee, foot, beak.darkened(0.18), 1.6)
			elif heron_stalk:
				var stalk_step := sin(walk_phase * 0.62 + (PI if leg_side > 0.0 else 0.0)) * radius * (0.22 + 0.12 * heron_stalk_intensity)
				var hip := side * leg_side * radius * 0.16 - forward * radius * 0.04
				var knee := side * leg_side * radius * 0.24 + forward * stalk_step
				var foot := side * leg_side * radius * 0.34 + forward * (stalk_step + radius * 0.32)
				canvas.draw_line(hip, knee, beak.darkened(0.25), 1.6)
				canvas.draw_line(knee, foot, beak.darkened(0.18), 1.6)
				canvas.draw_arc(foot - forward * radius * 0.08, radius * (0.16 + 0.04 * heron_stalk_intensity), PI * 0.08, PI * 0.9, 8, Color(0.42, 0.36, 0.26, 0.16 + 0.08 * heron_stalk_intensity), maxf(radius * 0.04, 1.0))
				canvas.draw_line(foot, foot + forward * radius * (0.18 + 0.06 * heron_stalk_intensity), Color(0.42, 0.36, 0.26, 0.18 + 0.08 * heron_stalk_intensity), maxf(radius * 0.035, 1.0))
				canvas.draw_circle(foot + forward * radius * (0.24 + 0.06 * heron_stalk_intensity), maxf(radius * (0.035 + 0.012 * heron_stalk_intensity), 1.0), Color(0.42, 0.36, 0.26, 0.18 + 0.08 * heron_stalk_intensity))
			elif duck_paddle:
				var paddle_step := sin(walk_phase * 1.8 + (PI if leg_side > 0.0 else 0.0)) * radius * (0.16 + 0.08 * duck_paddle_intensity)
				var hip := -forward * radius * 0.12 + side * leg_side * radius * 0.18
				var foot := -forward * radius * 0.48 + side * leg_side * radius * 0.42 + forward * paddle_step
				var paddle_water := Color(0.48, 0.74, 0.86, 0.24 + duck_paddle_intensity * 0.08)
				canvas.draw_line(hip, foot, beak.darkened(0.25), 1.4)
				canvas.draw_arc(foot - forward * radius * 0.08, radius * (0.2 + 0.06 * duck_paddle_intensity), -0.35, TAU * 0.72, 14, paddle_water, maxf(radius * 0.045, 1.0))
				canvas.draw_circle(foot - forward * radius * (0.28 + 0.06 * duck_paddle_intensity), maxf(radius * (0.04 + 0.014 * duck_paddle_intensity), 1.0), Color(paddle_water.r, paddle_water.g, paddle_water.b, paddle_water.a * 0.82))
				canvas.draw_colored_polygon(PackedVector2Array([
					foot + forward * radius * 0.08,
					foot - forward * radius * 0.12 + side * leg_side * radius * 0.18,
					foot - forward * radius * 0.18,
					foot - forward * radius * 0.12 - side * leg_side * radius * 0.08
				]), beak.darkened(0.05))
			elif duck_waddle:
				var waddle_step := sin(walk_phase * 0.82 + (PI if leg_side > 0.0 else 0.0)) * radius * (0.1 + 0.08 * duck_waddle_intensity)
				var hip := -forward * radius * 0.06 + side * leg_side * radius * 0.18
				var foot := -forward * radius * 0.44 + side * leg_side * radius * (0.34 + 0.08 * duck_waddle_intensity) + forward * waddle_step
				canvas.draw_line(hip, foot, beak.darkened(0.25), 1.5)
				canvas.draw_line(foot, foot - forward * radius * (0.16 + 0.05 * duck_waddle_intensity), beak.darkened(0.1), 1.2)
				canvas.draw_line(foot, foot - forward * radius * 0.08 + side * leg_side * radius * 0.12, beak.darkened(0.08), 1.1)
				canvas.draw_line(foot, foot - forward * radius * 0.08 - side * leg_side * radius * 0.08, beak.darkened(0.08), 1.1)
				canvas.draw_arc(foot - forward * radius * 0.08, radius * (0.16 + 0.04 * duck_waddle_intensity), PI * 0.08, PI * 0.9, 8, Color(0.46, 0.36, 0.22, 0.18 + 0.08 * duck_waddle_intensity), maxf(radius * 0.045, 1.0))
			else:
				canvas.draw_line(side * leg_side * radius * 0.2, side * leg_side * radius * 0.24 + forward * leg_step - forward * radius * 0.05, beak.darkened(0.2), 1.5)

	# Head (long neck for heron), beak, eyes.
	var head_scale := float(skin.get("head_scale", 1.0))
	var neck_pose_offset := 0.44 if wading_pose else 0.5 if heron_stalk else 0.55
	var head_sway := wading_stride if wading_pose else heron_stalk_intensity * 0.75 if heron_stalk else 0.0
	var head_center := forward * radius * (0.75 + neck * neck_pose_offset) + side * sin(walk_phase * 0.42) * radius * 0.06 * head_sway
	if neck > 0.0:
		if wading_pose or heron_stalk:
			var neck_mid := forward * radius * 0.72 - side * radius * 0.1
			canvas.draw_line(forward * radius * 0.42, neck_mid, main, maxf(radius * 0.18, 2.2))
			canvas.draw_line(neck_mid, head_center, main, maxf(radius * 0.16, 2.0))
		else:
			canvas.draw_line(forward * radius * 0.5, head_center, main, maxf(radius * 0.2, 2.5))
	canvas.draw_circle(head_center, radius * 0.3 * head_scale, head_color)
	if bool(skin.get("facial_disc", false)):
		canvas.draw_circle(head_center, radius * 0.26 * head_scale, breast)
		canvas.draw_arc(head_center, radius * 0.26 * head_scale, 0.0, TAU, 20, dark, 1.5)
	if bool(skin.get("tufts", false)):
		for tuft_side: float in [-1.0, 1.0]:
			canvas.draw_line(head_center + side * tuft_side * radius * 0.18 - forward * radius * 0.1, head_center + side * tuft_side * radius * 0.32 - forward * radius * 0.26, dark, 2.0)
	if bool(skin.get("flat_bill", false)):
		canvas.draw_colored_polygon(PackedVector2Array([
			head_center + forward * radius * 0.2 + side * radius * 0.14,
			head_center + forward * radius * (0.2 + beak_len) + side * radius * 0.1,
			head_center + forward * radius * (0.2 + beak_len) - side * radius * 0.1,
			head_center + forward * radius * 0.2 - side * radius * 0.14
		]), beak)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([
			head_center + forward * radius * 0.16 + side * radius * 0.1,
			head_center + forward * radius * (0.16 + beak_len),
			head_center + forward * radius * 0.16 - side * radius * 0.1
		]), beak)
	var has_disc := bool(skin.get("facial_disc", false))
	var eye_offset := radius * 0.14 * head_scale
	var eye_size := maxf(radius * (0.11 if has_disc else 0.06), 1.2)
	canvas.draw_circle(head_center + side * eye_offset + forward * radius * 0.06, eye_size, Color(0.95, 0.85, 0.3) if has_disc else Color(0.08, 0.06, 0.05))
	canvas.draw_circle(head_center - side * eye_offset + forward * radius * 0.06, eye_size, Color(0.95, 0.85, 0.3) if has_disc else Color(0.08, 0.06, 0.05))
	if has_disc:
		canvas.draw_circle(head_center + side * eye_offset + forward * radius * 0.08, maxf(eye_size * 0.45, 1.0), Color(0.06, 0.05, 0.04))
		canvas.draw_circle(head_center - side * eye_offset + forward * radius * 0.08, maxf(eye_size * 0.45, 1.0), Color(0.06, 0.05, 0.04))
	if plunge_pose:
		var streak_color := Color(0.58, 0.82, 1.0, 0.34 * plunge_t)
		canvas.draw_line(head_center + forward * radius * 0.7, head_center + forward * radius * (1.85 + 0.45 * plunge_t), streak_color, maxf(radius * 0.12, 2.0))
		for streak_side: float in [-1.0, 1.0]:
			canvas.draw_line(-forward * radius * 0.1 + side * streak_side * radius * 0.72, -forward * radius * (0.92 + plunge_t * 0.22) + side * streak_side * radius * 1.05, Color(streak_color.r, streak_color.g, streak_color.b, streak_color.a * 0.75), maxf(radius * 0.08, 1.4))
	if airborne and low_window_t > 0.0:
		var strike_cue := Color(1.0, 0.86, 0.38, 0.32 * low_window_t)
		canvas.draw_line(head_center + forward * radius * 0.3, head_center + forward * radius * (1.28 + 0.28 * low_window_t), strike_cue, maxf(radius * 0.12, 2.0))
		canvas.draw_arc(Vector2.ZERO, radius * (1.0 + 0.16 * low_window_t), -PI * 0.15, PI * 1.15, 26, Color(strike_cue.r, strike_cue.g, strike_cue.b, strike_cue.a * 0.78), maxf(radius * 0.08, 1.4))

static func _bird_wing_points(
	radius: float,
	forward: Vector2,
	side: Vector2,
	wing_side: float,
	wing_tip: Vector2,
	flap: float
) -> PackedVector2Array:
	var tip_leading_offset := maxf(-0.25, 0.25 + flap)
	return PackedVector2Array([
		forward * radius * 0.35 + side * wing_side * radius * 0.3,
		wing_tip + forward * radius * tip_leading_offset,
		wing_tip - forward * radius * 0.35,
		-forward * radius * 0.45 + side * wing_side * radius * 0.3
	])


static func _base_serpent(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.36, 0.26, 0.15))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var segments := 9
	var slither_amp := float(anim.get("slither_amp", 1.0))
	var water_slither := String(anim.get("creature_id", "")) == "water_snake" and bool(anim.get("water_slither_pose", false))
	var water_slither_intensity := clampf(float(anim.get("water_slither_intensity", 0.0)), 0.0, 1.25)
	var land_slither := String(anim.get("creature_id", "")) == "water_snake" and bool(anim.get("water_snake_land_slither_pose", false))
	var land_slither_intensity := clampf(float(anim.get("water_snake_land_slither_intensity", 0.0)), 0.0, 1.25)
	var mud_slither := land_slither and bool(anim.get("water_snake_mud_slither", false))
	var coil_pose := String(anim.get("creature_id", "")) == "water_snake" and bool(anim.get("water_snake_coil_pose", false))
	var slither := slither_amp if moving else 0.3 * slither_amp
	var visual_length := maxf(float(anim.get("long_body_visual_length_px", radius * 3.1)), radius * 3.1)
	var point_span := maxf(radius * 3.1, visual_length - radius * 0.8)
	var head_along := point_span * 0.34
	var tail_along := -point_span * 0.66
	if water_slither:
		slither += 0.42 * water_slither_intensity
	if land_slither:
		slither += 0.22 * land_slither_intensity
	if coil_pose:
		slither += 0.65
	var points: Array[Vector2] = []
	for i in segments:
		var t := float(i) / float(segments - 1)
		var along := lerpf(head_along, tail_along, t)
		var sway := sin(walk_phase * 1.6 + t * 4.2) * radius * 0.3 * slither * t
		points.append(forward * along + side * sway)
	if water_slither:
		var water_color := Color(0.44, 0.72, 0.86, 0.26 + 0.10 * water_slither_intensity)
		for wake_index in range(1, segments - 1, 2):
			var t := float(wake_index) / float(segments - 1)
			var wake_side := 1.0 if wake_index % 4 == 1 else -1.0
			var wake_center := points[wake_index] + side * wake_side * radius * (0.28 + 0.08 * water_slither_intensity)
			canvas.draw_arc(wake_center, radius * (0.28 + t * 0.18 + water_slither_intensity * 0.05), -0.45, 0.85, 12, water_color, 1.1 + water_slither_intensity * 0.6)
			var s_ripple_start := points[wake_index] - forward * radius * 0.14
			var s_ripple_end := points[min(wake_index + 1, segments - 1)] - forward * radius * (0.28 + 0.08 * water_slither_intensity)
			canvas.draw_line(s_ripple_start, s_ripple_end, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.72), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(wake_center - forward * radius * 0.12, maxf(radius * (0.035 + t * 0.018), 1.0), Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.58))
		canvas.draw_line(points[0] - forward * radius * 0.2, points[segments - 1] - forward * radius * 0.35, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.45), maxf(radius * 0.05, 1.0))
		canvas.draw_line(points[0] + side * radius * 0.22, points[0] + forward * radius * 0.58 + side * radius * 0.46, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.64), maxf(radius * 0.045, 1.0))
		canvas.draw_line(points[0] - side * radius * 0.22, points[0] + forward * radius * 0.58 - side * radius * 0.46, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.64), maxf(radius * 0.045, 1.0))
	if land_slither:
		var scuff_color := Color(0.34, 0.25, 0.17, 0.18 + 0.10 * land_slither_intensity)
		if mud_slither:
			scuff_color = Color(0.22, 0.16, 0.11, 0.26 + 0.12 * land_slither_intensity)
		canvas.draw_line(points[0] - forward * radius * 0.1, points[segments - 1] - forward * radius * 0.2, Color(scuff_color.r, scuff_color.g, scuff_color.b, scuff_color.a * 0.45), maxf(radius * 0.045, 1.0))
		for scuff_index in range(1, segments - 1, 2):
			var t := float(scuff_index) / float(segments - 1)
			var contact := points[scuff_index]
			var scuff_side := 1.0 if scuff_index % 4 == 1 else -1.0
			var scuff_center := contact - forward * radius * 0.08 + side * scuff_side * radius * 0.18
			canvas.draw_arc(scuff_center, radius * (0.14 + t * 0.08 + land_slither_intensity * 0.03), PI * 0.1, PI * 0.9, 8, scuff_color, maxf(radius * 0.04, 1.0))
			var belly_dash_color := Color(scuff_color.r, scuff_color.g, scuff_color.b, scuff_color.a * (0.68 if mud_slither else 0.54))
			canvas.draw_line(contact - forward * radius * 0.08, contact + forward * radius * (0.14 + 0.04 * land_slither_intensity), belly_dash_color, maxf(radius * 0.035, 1.0))
			canvas.draw_circle(contact + side * scuff_side * radius * 0.1, maxf(radius * (0.035 + 0.015 * land_slither_intensity), 1.0), Color(scuff_color.r, scuff_color.g, scuff_color.b, scuff_color.a * (0.72 if mud_slither else 0.5)))
			if mud_slither:
				canvas.draw_line(contact - forward * radius * 0.1, contact - forward * radius * (0.34 + 0.12 * land_slither_intensity) + side * scuff_side * radius * 0.1, Color(scuff_color.r, scuff_color.g, scuff_color.b, scuff_color.a * 0.8), maxf(radius * 0.04, 1.0))
	for i in range(segments - 1, -1, -1):
		var t := float(i) / float(segments - 1)
		var seg_radius := radius * lerpf(0.42, 0.12, t)
		canvas.draw_circle(points[i], seg_radius + 1.5, dark)
	for i in range(segments - 1, -1, -1):
		var t := float(i) / float(segments - 1)
		var seg_radius := radius * lerpf(0.42, 0.12, t)
		canvas.draw_circle(points[i], seg_radius, dark if i % 2 == 1 else main)
	if coil_pose:
		var coil_color := Color(0.72, 0.52, 0.28, 0.36)
		for coil_index in [1, 3, 5]:
			var center := points[coil_index]
			var coil_radius := radius * (0.62 - float(coil_index) * 0.035)
			canvas.draw_arc(center, coil_radius, -PI * 0.2, PI * 1.12, 24, coil_color, maxf(radius * 0.08, 1.5))
		canvas.draw_line(points[0] + side * radius * 0.18, points[2] - side * radius * 0.24, Color(coil_color.r, coil_color.g, coil_color.b, 0.42), maxf(radius * 0.09, 1.6))
	# Head with flicking tongue.
	var head: Vector2 = points[0]
	canvas.draw_circle(head, radius * 0.45, main)
	canvas.draw_circle(head + side * radius * 0.18 + forward * radius * 0.16, maxf(radius * 0.07, 1.2), Color(0.85, 0.6, 0.1))
	canvas.draw_circle(head - side * radius * 0.18 + forward * radius * 0.16, maxf(radius * 0.07, 1.2), Color(0.85, 0.6, 0.1))
	if fmod(Time.get_ticks_msec() * 0.001, 1.6) < 0.25:
		var tongue_tip := head + forward * radius * 0.85
		canvas.draw_line(head + forward * radius * 0.4, tongue_tip, Color(0.85, 0.2, 0.25), 1.5)
		canvas.draw_line(tongue_tip, tongue_tip + forward.rotated(0.5) * radius * 0.15, Color(0.85, 0.2, 0.25), 1.5)
		canvas.draw_line(tongue_tip, tongue_tip + forward.rotated(-0.5) * radius * 0.15, Color(0.85, 0.2, 0.25), 1.5)

static func _base_croc(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.2, 0.26, 0.17))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var bite_pose := alligator_bite_pose(anim, forward)
	var bite_active := bool(bite_pose["active"])
	var longitudinal_scale := float(bite_pose["longitudinal_scale"]) if bite_active else 1.0
	var lateral_scale := float(bite_pose["lateral_scale"]) if bite_active else 1.0
	var head_extension := float(bite_pose["head_extension"]) if bite_active else 0.0
	var jaw_open := float(bite_pose["jaw_open"]) if bite_active else 0.0
	var jaw_clamp := float(bite_pose["jaw_clamp"]) if bite_active else 0.0
	var bite_brace := float(bite_pose["brace"]) if bite_active else 0.0
	var bite_mode := String(bite_pose["mode"])
	var tail_sway := float(anim.get("tail_sway", 1.0))
	var crawl_weight := float(anim.get("crawl_weight", 0.0))
	var ambush_pose := bool(anim.get("ambush_pose", false))
	var high_walk_pose := bool(anim.get("high_walk_pose", false))
	var water_cruise_pose := String(anim.get("creature_id", "")) == "alligator" and bool(anim.get("alligator_water_cruise_pose", false))
	var water_cruise_intensity := clampf(float(anim.get("alligator_water_cruise_intensity", 0.0)), 0.0, 1.25)
	var jaw_hold_pose := bool(anim.get("alligator_jaw_hold_pose", false))
	var death_roll_pose := bool(anim.get("alligator_death_roll_pose", false))
	if ambush_pose:
		crawl_weight = maxf(crawl_weight, 0.72)
		tail_sway *= 0.35
	elif high_walk_pose:
		crawl_weight = minf(crawl_weight, 0.16)
		tail_sway *= 1.18
	elif water_cruise_pose:
		crawl_weight = maxf(crawl_weight, 0.5)
		tail_sway *= 1.55
	if jaw_hold_pose:
		crawl_weight = maxf(crawl_weight, 0.42)
		tail_sway *= 1.28
	if death_roll_pose:
		crawl_weight = maxf(crawl_weight, 0.62)
		tail_sway *= 2.1

	if high_walk_pose:
		var high_step_dust := Color(0.32, 0.28, 0.18, 0.14)
		canvas.draw_colored_polygon(PackedVector2Array([
			-forward * radius * 1.0 + side * radius * 0.48,
			forward * radius * 1.38 + side * radius * 0.36,
			forward * radius * 1.38 - side * radius * 0.36,
			-forward * radius * 1.0 - side * radius * 0.48
		]), Color(0.02, 0.03, 0.02, 0.18))
		for step_side: float in [-1.0, 1.0]:
			var step_center := -forward * radius * 0.18 + side * step_side * radius * 0.66
			canvas.draw_arc(step_center, radius * 0.34, PI * 0.08, PI * 0.92, 10, high_step_dust, maxf(radius * 0.055, 1.0))
			canvas.draw_line(step_center - forward * radius * 0.1, step_center - forward * radius * 0.52 + side * step_side * radius * 0.08, Color(high_step_dust.r, high_step_dust.g, high_step_dust.b, 0.16), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(step_center + forward * radius * 0.18, maxf(radius * 0.09, 1.1), Color(high_step_dust.r, high_step_dust.g, high_step_dust.b, 0.18))
			canvas.draw_circle(step_center - forward * radius * 0.18, maxf(radius * 0.075, 1.0), Color(high_step_dust.r, high_step_dust.g, high_step_dust.b, 0.24))
	if death_roll_pose:
		var churn := Color(0.46, 0.72, 0.82, 0.26)
		canvas.draw_arc(Vector2.ZERO, radius * 1.52, -PI * 0.15, PI * 1.18, 42, churn, maxf(radius * 0.12, 2.0))
		canvas.draw_arc(Vector2.ZERO, radius * 1.08, PI * 0.22, PI * 1.48, 34, Color(churn.r, churn.g, churn.b, 0.18), maxf(radius * 0.1, 1.5))
		for roll_side: float in [-1.0, 1.0]:
			canvas.draw_line(-forward * radius * 0.7 + side * roll_side * radius * 0.55, forward * radius * 1.15 - side * roll_side * radius * 0.36, Color(churn.r, churn.g, churn.b, 0.22), maxf(radius * 0.08, 1.3))
	elif bite_mode == "whiff":
		var skid_color := Color(0.34, 0.28, 0.18, 0.24)
		var imbalance := float(bite_pose["off_balance"])
		for skid_side: float in [-1.0, 1.0]:
			var skid_start := -forward * radius * 0.18 + side * skid_side * radius * 0.58
			canvas.draw_line(
				skid_start,
				skid_start - forward * radius * (0.52 + 0.28 * imbalance) - side * skid_side * radius * 0.08,
				skid_color,
				maxf(radius * 0.06, 1.1)
			)
			canvas.draw_arc(
				skid_start - forward * radius * 0.24,
				radius * (0.18 + 0.07 * imbalance),
				PI * 0.08,
				PI * 0.92,
				10,
				Color(skid_color.r, skid_color.g, skid_color.b, skid_color.a * 0.72),
				maxf(radius * 0.045, 1.0)
			)
	elif bite_mode == "interrupted":
		var recoil_color := Color(0.3, 0.25, 0.17, 0.2)
		var recoil := float(bite_pose["recoil"])
		for recoil_side: float in [-1.0, 1.0]:
			var recoil_start := forward * radius * 0.24 + side * recoil_side * radius * 0.52
			canvas.draw_line(
				recoil_start,
				recoil_start + forward * radius * (0.34 + 0.18 * recoil),
				recoil_color,
				maxf(radius * 0.05, 1.0)
			)
	if water_cruise_pose:
		var cruise_water := Color(0.36, 0.62, 0.74, 0.2 + 0.1 * water_cruise_intensity)
		for wake_side: float in [-1.0, 1.0]:
			var wake_origin := -forward * radius * 0.45 + side * wake_side * radius * 0.58
			canvas.draw_line(wake_origin, wake_origin - forward * radius * (0.92 + 0.28 * water_cruise_intensity) + side * wake_side * radius * 0.18, cruise_water, maxf(radius * 0.08, 1.3))
			canvas.draw_arc(wake_origin + forward * radius * 0.18, radius * (0.36 + 0.1 * water_cruise_intensity), -0.35, 0.85, 12, Color(cruise_water.r, cruise_water.g, cruise_water.b, cruise_water.a * 0.82), maxf(radius * 0.055, 1.0))
			canvas.draw_circle(wake_origin - forward * radius * (0.72 + 0.18 * water_cruise_intensity) + side * wake_side * radius * 0.12, maxf(radius * (0.045 + 0.018 * water_cruise_intensity), 1.0), cruise_water.lightened(0.22))
		canvas.draw_line(forward * radius * 1.16, -forward * radius * (1.34 + 0.22 * water_cruise_intensity), Color(cruise_water.r, cruise_water.g, cruise_water.b, cruise_water.a * 0.62), maxf(radius * 0.065, 1.1))
		canvas.draw_arc(forward * radius * 1.0, radius * (0.42 + 0.08 * water_cruise_intensity), -PI * 0.05, PI * 1.05, 16, Color(cruise_water.r, cruise_water.g, cruise_water.b, cruise_water.a * 0.55), maxf(radius * 0.05, 1.0))
		canvas.draw_circle(forward * radius * 1.22, maxf(radius * (0.07 + 0.025 * water_cruise_intensity), 1.1), Color(cruise_water.r, cruise_water.g, cruise_water.b, cruise_water.a * 0.74))
		canvas.draw_circle(forward * radius * 0.68 + side * radius * 0.28, maxf(radius * 0.045, 1.0), Color(0.78, 0.86, 0.58, 0.3 + 0.1 * water_cruise_intensity))
		canvas.draw_circle(forward * radius * 0.68 - side * radius * 0.28, maxf(radius * 0.045, 1.0), Color(0.78, 0.86, 0.58, 0.3 + 0.1 * water_cruise_intensity))

	# Keeled tail, swaying.
	var tail_direction := (-forward).rotated((sin(walk_phase * 0.9) * 0.25 * tail_sway) if moving else 0.08)
	for i in 5:
		var t := float(i) / 4.0
		var tail_lift := side * sin(walk_phase * 0.7) * radius * 0.08 * (1.0 - t) if high_walk_pose else Vector2.ZERO
		var tail_point := -forward * radius * 0.7 * longitudinal_scale \
			+ tail_direction * radius * (0.3 + t * 1.5) * longitudinal_scale + tail_lift
		canvas.draw_circle(tail_point, radius * lerpf(0.34, 0.08, t), dark)
		if i < 4:
			canvas.draw_line(tail_point, tail_point + tail_direction.rotated(PI * 0.5) * radius * 0.12, dark.darkened(0.15), 1.5)

	# Stubby legs.
	for leg_index in 4:
		var angle := [1.1, -1.1, 2.2, -2.2][leg_index] as float
		var stride_mult := 1.45 if high_walk_pose else 1.0
		var step := (sin(walk_phase + (PI if leg_index % 2 == 0 else 0.0)) * radius * 0.1 * (1.0 - crawl_weight * 0.35) * stride_mult) if moving else 0.0
		var leg_reach := 0.9 if high_walk_pose else 0.78
		if bite_active:
			leg_reach += bite_brace * 0.08
		if water_cruise_pose:
			step *= 0.42
			leg_reach = 0.66
		var leg_center := forward.rotated(angle) * radius * (leg_reach + crawl_weight * 0.08) + forward * step
		canvas.draw_circle(leg_center, radius * (0.18 + crawl_weight * 0.03), dark)
		if high_walk_pose:
			canvas.draw_line(leg_center, leg_center + leg_center.normalized() * radius * 0.18, dark, maxf(radius * 0.08, 1.5))
			canvas.draw_arc(leg_center - forward * radius * 0.08, radius * 0.18, PI * 0.1, PI * 0.9, 8, Color(0.32, 0.28, 0.18, 0.2), maxf(radius * 0.04, 1.0))
		if water_cruise_pose and leg_index % 2 == 0:
			canvas.draw_circle(leg_center - forward * radius * 0.08, maxf(radius * (0.05 + 0.025 * water_cruise_intensity), 1.0), Color(0.36, 0.62, 0.74, 0.18 + 0.08 * water_cruise_intensity))

	# Body: broad armored oval.
	var body_points := PackedVector2Array()
	for i in 16:
		var body_angle := TAU * float(i) / 16.0
		body_points.append(
			forward * cos(body_angle) * radius * (0.95 + crawl_weight * 0.05) * longitudinal_scale
			+ side * sin(body_angle) * radius * (0.6 - crawl_weight * 0.06) * lateral_scale
		)
	canvas.draw_colored_polygon(body_points, dark)
	var inner := PackedVector2Array()
	for point in body_points:
		inner.append(point * 0.86)
	canvas.draw_colored_polygon(inner, main)
	# Scute rows.
	for row: float in [-0.24, 0.0, 0.24]:
		for i in 4:
			var scute := forward * radius * (-0.5 + float(i) * 0.32) + side * radius * row
			canvas.draw_circle(scute, maxf(radius * 0.06, 1.5), dark.lightened(0.08))

	# Long snout with nostrils and raised eyes.
	var snout_tip := 1.55 + head_extension
	var snout_nose := 1.62 + head_extension
	var snout_points := PackedVector2Array([
		forward * radius * 0.7 + side * radius * 0.3,
		forward * radius * snout_tip + side * radius * 0.18,
		forward * radius * snout_nose,
		forward * radius * snout_tip - side * radius * 0.18,
		forward * radius * 0.7 - side * radius * 0.3
	])
	canvas.draw_colored_polygon(snout_points, main)
	if jaw_open > 0.01 and not death_roll_pose:
		var mouth_half_width := radius * (0.04 + jaw_open * 0.13)
		var mouth_root := forward * radius * 0.82
		var mouth_tip := forward * radius * (snout_tip - 0.05)
		canvas.draw_colored_polygon(PackedVector2Array([
			mouth_root + side * mouth_half_width,
			mouth_tip + side * mouth_half_width * 0.58,
			mouth_tip - side * mouth_half_width * 0.58,
			mouth_root - side * mouth_half_width,
		]), Color(0.16, 0.06, 0.05, 0.88))
		for tooth_side: float in [-1.0, 1.0]:
			for tooth_index in 3:
				var tooth_t := 0.24 + float(tooth_index) * 0.24
				var tooth_center := mouth_root.lerp(mouth_tip, tooth_t) \
					+ side * tooth_side * mouth_half_width * 0.72
				canvas.draw_circle(
					tooth_center,
					maxf(radius * 0.027, 0.8),
					Color(0.9, 0.86, 0.68, 0.9)
				)
	if jaw_hold_pose or death_roll_pose or jaw_clamp > 0.01:
		var clamp_strength := maxf(jaw_clamp, 1.0 if jaw_hold_pose or death_roll_pose else 0.0)
		var clamp_color := Color(0.96, 0.82, 0.42, (0.28 + clamp_strength * 0.12) if not death_roll_pose else 0.48)
		canvas.draw_line(forward * radius * 1.18 + side * radius * 0.24, forward * radius * 1.78 + side * radius * 0.28, clamp_color, maxf(radius * 0.09, 1.5))
		canvas.draw_line(forward * radius * 1.18 - side * radius * 0.24, forward * radius * 1.78 - side * radius * 0.28, clamp_color, maxf(radius * 0.09, 1.5))
		canvas.draw_arc(forward * radius * 1.42, radius * 0.42, -PI * 0.34, PI * 0.34, 16, Color(clamp_color.r, clamp_color.g, clamp_color.b, clamp_color.a * 0.7), maxf(radius * 0.08, 1.3))
	canvas.draw_circle(forward * radius * (1.52 + head_extension) + side * radius * 0.08, maxf(radius * 0.04, 1.0), dark)
	canvas.draw_circle(forward * radius * (1.52 + head_extension) - side * radius * 0.08, maxf(radius * 0.04, 1.0), dark)
	canvas.draw_circle(forward * radius * 0.78 + side * radius * 0.22, radius * 0.1, dark)
	canvas.draw_circle(forward * radius * 0.78 - side * radius * 0.22, radius * 0.1, dark)
	canvas.draw_circle(forward * radius * 0.78 + side * radius * 0.22, maxf(radius * 0.05, 1.2), Color(0.85, 0.75, 0.3))
	canvas.draw_circle(forward * radius * 0.78 - side * radius * 0.22, maxf(radius * 0.05, 1.2), Color(0.85, 0.75, 0.3))
	if ambush_pose:
		canvas.draw_line(-forward * radius * 0.75 - side * radius * 0.5, forward * radius * 1.05 - side * radius * 0.38, Color(0.08, 0.16, 0.08, 0.65), 2.0)
		canvas.draw_line(-forward * radius * 0.75 + side * radius * 0.5, forward * radius * 1.05 + side * radius * 0.38, Color(0.08, 0.16, 0.08, 0.65), 2.0)
	elif high_walk_pose:
		canvas.draw_line(-forward * radius * 0.35 - side * radius * 0.18, forward * radius * 0.7 - side * radius * 0.12, dark.lightened(0.22), 1.5)
		canvas.draw_line(-forward * radius * 0.35 + side * radius * 0.18, forward * radius * 0.7 + side * radius * 0.12, dark.lightened(0.22), 1.5)
	elif water_cruise_pose:
		canvas.draw_line(-forward * radius * 0.62 - side * radius * 0.28, forward * radius * 1.08 - side * radius * 0.18, Color(0.48, 0.72, 0.78, 0.34), maxf(radius * 0.05, 1.0))
		canvas.draw_line(-forward * radius * 0.62 + side * radius * 0.28, forward * radius * 1.08 + side * radius * 0.18, Color(0.48, 0.72, 0.78, 0.34), maxf(radius * 0.05, 1.0))

static func _base_crustacean(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, strike := 0.0, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.5, 0.2, 0.1))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var scuttle_stride := float(anim.get("scuttle_stride", 1.0))
	var display_stance := bool(anim.get("display_stance", false))
	var escape_dash := bool(anim.get("escape_dash", false))
	var escape_curl_t := clampf(float(anim.get("escape_curl_t", 0.0)), 0.0, 1.0)
	var crayfish_scuttle := String(anim.get("creature_id", "")) == "crayfish" and bool(anim.get("crayfish_scuttle_pose", false))
	var crayfish_tail_flick_swim := String(anim.get("creature_id", "")) == "crayfish" and bool(anim.get("crayfish_tail_flick_swim_pose", false))
	var crayfish_motion_intensity := clampf(float(anim.get("crayfish_motion_intensity", 0.0)), 0.0, 1.25)
	var tail_curl := float(anim.get("tail_curl", 0.0)) if moving or escape_dash else 0.0
	if crayfish_tail_flick_swim:
		tail_curl = maxf(tail_curl, 0.46 + 0.24 * crayfish_motion_intensity)
	tail_curl = maxf(tail_curl, escape_curl_t * 0.9)
	if escape_dash:
		tail_curl = maxf(tail_curl, 0.95)

	# Fan tail.
	if crayfish_tail_flick_swim:
		var swim_wake := Color(0.44, 0.72, 0.86, 0.18 + 0.1 * crayfish_motion_intensity)
		for wake_side: float in [-1.0, 1.0]:
			var tail_origin := -forward * radius * 0.92 + side * wake_side * radius * 0.25
			canvas.draw_line(tail_origin, tail_origin - forward * radius * (0.78 + 0.24 * crayfish_motion_intensity) + side * wake_side * radius * 0.28, swim_wake, maxf(radius * 0.07, 1.2))
			canvas.draw_arc(tail_origin - forward * radius * 0.16, radius * (0.26 + 0.08 * crayfish_motion_intensity), PI * 0.08, PI * 0.88, 10, swim_wake, maxf(radius * 0.045, 1.0))
			canvas.draw_circle(tail_origin - forward * radius * (0.48 + 0.12 * crayfish_motion_intensity), maxf(radius * (0.045 + 0.018 * crayfish_motion_intensity), 1.0), swim_wake.lightened(0.22))
			canvas.draw_circle(tail_origin - forward * radius * (0.76 + 0.16 * crayfish_motion_intensity) + side * wake_side * radius * 0.18, maxf(radius * (0.035 + 0.015 * crayfish_motion_intensity), 1.0), swim_wake.lightened(0.3))
		canvas.draw_arc(-forward * radius * 1.05, radius * (0.42 + 0.12 * crayfish_motion_intensity), PI * 0.02, PI * 0.98, 14, swim_wake, maxf(radius * 0.065, 1.1))
		canvas.draw_line(-forward * radius * 0.68, -forward * radius * (1.62 + 0.22 * crayfish_motion_intensity), Color(swim_wake.r, swim_wake.g, swim_wake.b, swim_wake.a * 0.72), maxf(radius * 0.08, 1.2))
	if crayfish_scuttle:
		var lateral_scratch := Color(dark.r, dark.g, dark.b, 0.14 + 0.08 * crayfish_motion_intensity)
		for scratch_side: float in [-1.0, 1.0]:
			var scratch_origin := -forward * radius * 0.18 + side * scratch_side * radius * 0.72
			canvas.draw_line(scratch_origin, scratch_origin + side * scratch_side * radius * (0.5 + 0.14 * crayfish_motion_intensity) - forward * radius * 0.1, lateral_scratch, maxf(radius * 0.045, 1.0))
			canvas.draw_arc(scratch_origin - forward * radius * 0.18, radius * (0.18 + 0.05 * crayfish_motion_intensity), PI * 0.1, PI * 0.9, 8, lateral_scratch, maxf(radius * 0.04, 1.0))
			canvas.draw_circle(scratch_origin + side * scratch_side * radius * (0.34 + 0.08 * crayfish_motion_intensity), maxf(radius * (0.035 + 0.018 * crayfish_motion_intensity), 1.0), Color(dark.r, dark.g, dark.b, lateral_scratch.a * 0.9))
			canvas.draw_circle(scratch_origin - forward * radius * 0.1 - side * scratch_side * radius * 0.12, maxf(radius * (0.03 + 0.015 * crayfish_motion_intensity), 1.0), Color(dark.r, dark.g, dark.b, lateral_scratch.a * 0.72))
	if escape_curl_t > 0.0:
		var wake := Color(0.95, 0.72, 0.45, 0.22 * escape_curl_t)
		for wake_side: float in [-1.0, 1.0]:
			canvas.draw_line(-forward * radius * 1.05 + side * wake_side * radius * 0.32, -forward * radius * (1.7 + 0.25 * escape_curl_t) + side * wake_side * radius * 0.62, wake, maxf(radius * 0.08, 1.5))
	canvas.draw_colored_polygon(PackedVector2Array([
		-forward * radius * 0.6,
		-forward * radius * (1.25 - tail_curl * 0.12) + side * radius * (0.4 + tail_curl * 0.18),
		-forward * radius * (1.35 - tail_curl * 0.22),
		-forward * radius * (1.25 - tail_curl * 0.12) - side * radius * (0.4 + tail_curl * 0.18)
	]), dark)

	# Walking legs.
	for leg_index in 8:
		var leg_side := 1.0 if leg_index % 2 == 0 else -1.0
		var leg_t := float(leg_index / 2) / 3.0
		var leg_base := forward * lerpf(0.3, -0.5, leg_t) * radius
		var leg_step := sin(walk_phase * 1.8 + float(leg_index) * PI * 0.5) * 0.15 * scuttle_stride if moving else 0.0
		var side_reach := radius * (0.82 + 0.08 * scuttle_stride)
		var leg_tip := leg_base + side * leg_side * side_reach + forward * radius * leg_step
		canvas.draw_line(leg_base, leg_tip, dark, 1.5)
		if crayfish_scuttle and leg_index % 2 == 0:
			var scuff_alpha := 0.18 + 0.08 * crayfish_motion_intensity
			canvas.draw_arc(leg_tip - forward * radius * 0.08, radius * (0.12 + 0.04 * crayfish_motion_intensity), PI * 0.08, PI * 0.9, 8, Color(dark.r, dark.g, dark.b, scuff_alpha), maxf(radius * 0.035, 1.0))
			canvas.draw_line(leg_tip, leg_tip + side * leg_side * radius * (0.18 + 0.08 * crayfish_motion_intensity), Color(dark.r, dark.g, dark.b, scuff_alpha * 0.82), maxf(radius * 0.035, 1.0))
		elif crayfish_tail_flick_swim and leg_index % 3 == 0:
			canvas.draw_circle(leg_tip - forward * radius * 0.08, maxf(radius * (0.04 + 0.02 * crayfish_motion_intensity), 1.0), Color(0.44, 0.72, 0.86, 0.16 + 0.06 * crayfish_motion_intensity))

	# Segmented abdomen + carapace.
	for i in 3:
		canvas.draw_circle(-forward * radius * (0.25 + float(i) * 0.22), radius * (0.42 - float(i) * 0.06), dark if i % 2 == 1 else main)
	canvas.draw_circle(forward * radius * 0.15, radius * 0.5, main)
	canvas.draw_line(forward * radius * 0.5, forward * radius * 0.0, dark, 1.5)

	# Big claws, opening on strike.
	var claw_open := 0.25 + strike * 0.6 + (0.32 if display_stance else 0.0)
	for claw_side: float in [-1.0, 1.0]:
		var arm_base := forward * radius * 0.4 + side * claw_side * radius * 0.35
		var stance_spread := 0.22 if display_stance else 0.0
		var claw_center := forward * radius * (0.85 + strike * 0.3) + side * claw_side * radius * (0.55 + stance_spread)
		canvas.draw_line(arm_base, claw_center, main, maxf(radius * 0.14, 2.0))
		canvas.draw_circle(claw_center, radius * 0.24, dark)
		canvas.draw_circle(claw_center, radius * 0.19, main)
		canvas.draw_line(claw_center, claw_center + forward.rotated(claw_open * claw_side) * radius * 0.3, dark, 2.0)
		canvas.draw_line(claw_center, claw_center + forward.rotated(-claw_open * 0.4 * claw_side) * radius * 0.3, dark, 2.0)

	# Antennae.
	for antenna_side: float in [-1.0, 1.0]:
		canvas.draw_line(forward * radius * 0.55 + side * antenna_side * radius * 0.12, forward * radius * 1.15 + side * antenna_side * radius * 0.45, dark.lightened(0.1), 1.0)
	canvas.draw_circle(forward * radius * 0.5 + side * radius * 0.14, maxf(radius * 0.06, 1.2), Color(0.08, 0.05, 0.04))
	canvas.draw_circle(forward * radius * 0.5 - side * radius * 0.14, maxf(radius * 0.06, 1.2), Color(0.08, 0.05, 0.04))

static func _base_spider(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.3, 0.22, 0.12))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var accent: Color = skin.get("accent", main.lightened(0.3))
	var scuttle_stride := float(anim.get("scuttle_stride", 1.0))
	var low_slung := float(anim.get("low_slung", 0.0))
	var lunge_pose := bool(anim.get("spider_lunge_pose", false))
	var burrowed_pose := bool(anim.get("spider_burrowed_pose", false))
	var latch_pose := bool(anim.get("spider_latch_pose", false))
	var skitter_pose := bool(anim.get("spider_skitter_pose", false))
	var skitter_intensity := clampf(float(anim.get("spider_skitter_intensity", 0.0)), 0.0, 1.25)
	if skitter_pose:
		low_slung = maxf(low_slung, 0.22 + 0.08 * skitter_intensity)
		scuttle_stride += 0.16 * skitter_intensity
	if lunge_pose:
		low_slung = maxf(low_slung, 0.48)
	if burrowed_pose:
		low_slung = maxf(low_slung, 0.74)

	if burrowed_pose:
		canvas.draw_colored_polygon(PackedVector2Array([
			-forward * radius * 1.05 + side * radius * 0.95,
			forward * radius * 0.72 + side * radius * 0.78,
			forward * radius * 0.9,
			forward * radius * 0.72 - side * radius * 0.78,
			-forward * radius * 1.05 - side * radius * 0.95,
			-forward * radius * 1.22
		]), Color(0.1, 0.07, 0.04, 0.42))
	if lunge_pose:
		canvas.draw_line(-forward * radius * 0.85, -forward * radius * 1.45, Color(accent.r, accent.g, accent.b, 0.24), maxf(radius * 0.12, 2.0))
	if skitter_pose:
		for trail_side: float in [-1.0, 1.0]:
			var trail_start := -forward * radius * 0.36 + side * trail_side * radius * 0.52
			canvas.draw_line(trail_start, trail_start - forward * radius * (0.42 + 0.18 * skitter_intensity) + side * trail_side * radius * 0.16, Color(accent.r, accent.g, accent.b, 0.14 + 0.08 * skitter_intensity), maxf(radius * 0.045, 1.0))
			canvas.draw_arc(trail_start + side * trail_side * radius * 0.16, radius * (0.16 + 0.05 * skitter_intensity), PI * 0.08, PI * 0.9, 8, Color(accent.r, accent.g, accent.b, 0.16 + 0.06 * skitter_intensity), maxf(radius * 0.035, 1.0))
			canvas.draw_circle(trail_start - forward * radius * (0.22 + 0.08 * skitter_intensity) + side * trail_side * radius * 0.1, maxf(radius * (0.03 + 0.012 * skitter_intensity), 1.0), Color(accent.r, accent.g, accent.b, 0.2 + 0.08 * skitter_intensity))

	# Eight legs, two joints each, alternating gait.
	for leg_index in 8:
		var leg_side := 1.0 if leg_index % 2 == 0 else -1.0
		var pair := leg_index / 2
		var base_angle := lerpf(0.45, 2.2, float(pair) / 3.0) * leg_side
		var step := sin(walk_phase * 2.0 + float(pair) * PI * 0.5 + (PI if leg_side > 0.0 else 0.0)) * 0.18 * scuttle_stride if moving else 0.0
		var foreleg := pair == 0
		var rearleg := pair == 3
		var lunge_reach := 0.34 if lunge_pose and foreleg else 0.0
		var burrow_tuck := 0.26 if burrowed_pose else 0.0
		var knee := forward.rotated(base_angle + step) * radius * (0.78 + scuttle_stride * 0.07 - burrow_tuck * 0.4) + forward * radius * lunge_reach
		var foot := forward.rotated(base_angle + step * 1.4) * radius * (1.22 + scuttle_stride * 0.13 - burrow_tuck) + forward * radius * (lunge_reach * 1.7 - (0.18 if lunge_pose and rearleg else 0.0))
		canvas.draw_line(Vector2.ZERO, knee, dark, maxf(radius * 0.09, 1.5))
		canvas.draw_line(knee, foot, dark, maxf(radius * 0.06, 1.2))
		if skitter_pose and pair % 2 == 0:
			canvas.draw_line(foot, foot - forward * radius * (0.18 + 0.1 * skitter_intensity), Color(accent.r, accent.g, accent.b, 0.2 + 0.08 * skitter_intensity), maxf(radius * 0.035, 1.0))
			canvas.draw_line(foot, foot + side * leg_side * radius * (0.16 + 0.08 * skitter_intensity), Color(accent.r, accent.g, accent.b, 0.18 + 0.07 * skitter_intensity), maxf(radius * 0.035, 1.0))
			canvas.draw_circle(foot + forward * radius * 0.05, maxf(radius * (0.035 + 0.014 * skitter_intensity), 1.0), Color(accent.r, accent.g, accent.b, 0.22 + 0.08 * skitter_intensity))

	# Abdomen + cephalothorax with dorsal stripe.
	var body_push := forward * radius * (0.18 if lunge_pose else 0.0)
	canvas.draw_circle(-forward * radius * 0.45 + body_push * 0.35, radius * (0.52 - low_slung * 0.08), dark)
	canvas.draw_circle(-forward * radius * 0.45 + body_push * 0.35, radius * (0.45 - low_slung * 0.07), main)
	canvas.draw_circle(forward * radius * 0.25 + body_push, radius * (0.4 - low_slung * 0.05), main)
	canvas.draw_line(-forward * radius * 0.85, forward * radius * 0.55, accent, maxf(radius * 0.12, 2.0))

	# Eye cluster: wolf spiders have two big forward eyes.
	var eye_anchor := forward * radius * 0.52 + body_push
	canvas.draw_circle(eye_anchor + side * radius * 0.1, maxf(radius * 0.08, 1.4), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(eye_anchor - side * radius * 0.1, maxf(radius * 0.08, 1.4), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(eye_anchor + forward * radius * 0.06 + side * radius * 0.22, maxf(radius * 0.04, 1.0), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(eye_anchor + forward * radius * 0.06 - side * radius * 0.22, maxf(radius * 0.04, 1.0), Color(0.05, 0.04, 0.03))
	if latch_pose:
		var fang_origin := eye_anchor + forward * radius * 0.15
		canvas.draw_line(fang_origin + side * radius * 0.06, fang_origin + forward * radius * 0.34 + side * radius * 0.12, Color(0.9, 0.86, 0.72, 0.82), maxf(radius * 0.06, 1.2))
		canvas.draw_line(fang_origin - side * radius * 0.06, fang_origin + forward * radius * 0.34 - side * radius * 0.12, Color(0.9, 0.86, 0.72, 0.82), maxf(radius * 0.06, 1.2))

static func _base_swarm(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.4, 0.4, 0.42))
	var dark: Color = skin.get("dark", Color(0.2, 0.2, 0.22))
	var radius_mult := float(anim.get("swarm_radius_mult", 1.0))
	var jitter := float(anim.get("swarm_jitter", 0.0)) * (1.0 if moving else 0.45)
	var swarm_pose := String(anim.get("creature_id", "")) == "mosquito_swarm" and bool(anim.get("mosquito_swarm_pose", false))
	var swarm_intensity := clampf(float(anim.get("mosquito_swarm_intensity", 0.0)), 0.0, 1.25)
	var trail_pose := bool(anim.get("mosquito_trail_pose", false))
	var blood_ratio := clampf(float(anim.get("mosquito_blood_ratio", 0.0)), 0.0, 1.0)
	var attack_t := float(anim.get("attack_t", -1.0))
	var engorged := Color(0.58, 0.12, 0.12)
	var swarm_dark := dark.lerp(engorged, blood_ratio * 0.55)
	var swarm_main := main.lerp(Color(0.72, 0.22, 0.18), blood_ratio * 0.45)
	var cloud_radius := radius * radius_mult * (1.0 + blood_ratio * 0.12 + swarm_intensity * 0.04)
	if attack_t >= 0.0:
		var sting_t := clampf(attack_t, 0.0, 1.0)
		var sting_color := Color(swarm_main.r, swarm_main.g, swarm_main.b, 0.24 + 0.18 * (1.0 - sting_t))
		canvas.draw_line(forward * radius * 0.34, forward * radius * (1.42 + 0.28 * sting_t), sting_color, maxf(radius * 0.08, 1.3))
		canvas.draw_circle(forward * radius * (1.12 + 0.22 * sting_t), maxf(radius * (0.07 + 0.02 * blood_ratio), 1.1), Color(sting_color.r, sting_color.g, sting_color.b, sting_color.a * 0.72))
	if trail_pose or swarm_pose:
		var trail_count := 4 if trail_pose else 3
		for trail_index in trail_count:
			var t := float(trail_index + 1) / float(trail_count)
			var trail_alpha := (0.10 + t * 0.035) if trail_pose else (0.07 + t * 0.03) * swarm_intensity
			var trail_length := 0.75 if trail_pose else 0.48
			var trail_center := -forward * radius * (0.42 + t * trail_length) + side * sin(walk_phase * 1.3 + t * 2.6) * radius * (0.18 + 0.1 * swarm_intensity)
			canvas.draw_circle(trail_center, radius * radius_mult * (0.28 + t * 0.15), Color(swarm_dark.r, swarm_dark.g, swarm_dark.b, trail_alpha))
	if swarm_pose:
		for stream_side: float in [-1.0, 1.0]:
			var stream_start := -forward * radius * 0.18 + side * stream_side * radius * 0.44
			var stream_end := stream_start - forward * radius * (0.82 + 0.24 * swarm_intensity) + side * stream_side * radius * 0.18
			canvas.draw_line(stream_start, stream_end, Color(swarm_main.r, swarm_main.g, swarm_main.b, 0.16 + 0.08 * swarm_intensity), maxf(radius * 0.045, 1.0))
			canvas.draw_circle(stream_end + forward * radius * 0.18, maxf(radius * (0.075 + 0.02 * swarm_intensity), 1.0), Color(swarm_dark.r, swarm_dark.g, swarm_dark.b, 0.2 + 0.06 * swarm_intensity))
			canvas.draw_circle(stream_start.lerp(stream_end, 0.62), maxf(radius * (0.052 + 0.018 * swarm_intensity), 1.0), Color(swarm_main.r, swarm_main.g, swarm_main.b, 0.18 + 0.08 * blood_ratio))
		for eddy_side: float in [-1.0, 0.0, 1.0]:
			var eddy_center := -forward * radius * (0.05 + 0.18 * absf(eddy_side)) + side * eddy_side * radius * 0.34
			canvas.draw_arc(eddy_center, radius * (0.28 + 0.07 * swarm_intensity), -0.4, TAU * 0.68, 14, Color(swarm_dark.r, swarm_dark.g, swarm_dark.b, 0.16 + 0.06 * swarm_intensity), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(eddy_center + forward * radius * 0.14, maxf(radius * (0.05 + 0.018 * swarm_intensity), 1.0), Color(swarm_main.r, swarm_main.g, swarm_main.b, 0.22 + 0.06 * blood_ratio))
	canvas.draw_circle(Vector2.ZERO, cloud_radius, Color(swarm_dark.r, swarm_dark.g, swarm_dark.b, 0.22 + blood_ratio * 0.06))
	if swarm_pose:
		for lobe_side: float in [-1.0, 1.0]:
			var lobe_center := side * lobe_side * radius * (0.32 + 0.08 * swarm_intensity) - forward * radius * 0.05
			canvas.draw_circle(lobe_center, cloud_radius * 0.58, Color(swarm_dark.r, swarm_dark.g, swarm_dark.b, 0.14 + 0.04 * swarm_intensity + blood_ratio * 0.04))
	var time_now := Time.get_ticks_msec() * 0.001
	for i in 12:
		var orbit_angle := time_now * (1.2 + float(i % 4) * 0.35) + float(i) * TAU / 12.0
		var trail_pull := -0.22 if trail_pose and i % 3 == 0 else (-0.1 * swarm_intensity if swarm_pose and i % 3 == 0 else 0.0)
		var pulse := sin(walk_phase * 1.7 + float(i) * 2.31) * jitter
		var orbit_radius := cloud_radius * (0.3 + 0.6 * float((i * 7) % 10) / 10.0 + pulse * 0.12)
		var dot := forward * cos(orbit_angle) * orbit_radius + side * sin(orbit_angle) * orbit_radius
		dot += forward * trail_pull * radius
		var dot_radius := maxf(radius * (0.09 + blood_ratio * 0.025), 1.6)
		canvas.draw_circle(dot, dot_radius, swarm_dark)
		canvas.draw_line(dot - side * 2.0 - forward * 1.0, dot + side * 2.0 - forward * 1.0, Color(swarm_main.r, swarm_main.g, swarm_main.b, 0.6), 1.0)

static func _base_cluster(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.27, 0.11, 0.08))
	var dark: Color = skin.get("dark", Color(0.16, 0.06, 0.05))
	var cluster_spread := float(anim.get("cluster_spread", 1.0))
	var inchworm_pulse := float(anim.get("inchworm_pulse", 0.0))
	var body_wiggle := float(anim.get("body_wiggle", 1.0))
	var tail_wave := float(anim.get("tail_wave", 1.0))
	var leech_undulate := String(anim.get("creature_id", "")) == "leech" and bool(anim.get("leech_undulate_pose", false))
	var leech_inchworm := String(anim.get("creature_id", "")) == "leech" and bool(anim.get("leech_inchworm_pose", false))
	var leech_motion_intensity := clampf(float(anim.get("leech_motion_intensity", 0.0)), 0.0, 1.25)
	var water_color := Color(0.35, 0.62, 0.76, 0.18 + 0.1 * leech_motion_intensity)
	if leech_undulate:
		cluster_spread += 0.16 * leech_motion_intensity
		body_wiggle += 0.32 * leech_motion_intensity
		tail_wave += 0.44 * leech_motion_intensity
		for wake_side: float in [-1.0, 1.0]:
			var wake_start := -forward * radius * 0.45 + side * wake_side * radius * 0.4
			canvas.draw_line(wake_start, wake_start - forward * radius * (0.82 + 0.24 * leech_motion_intensity) + side * wake_side * radius * 0.18, water_color, maxf(radius * 0.06, 1.0))
			canvas.draw_circle(wake_start - forward * radius * (0.7 + 0.16 * leech_motion_intensity) + side * wake_side * radius * 0.14, maxf(radius * (0.032 + 0.016 * leech_motion_intensity), 1.0), water_color.lightened(0.28))
		for ripple_index in 3:
			var t := float(ripple_index) / 2.0
			var ripple_center := -forward * radius * (0.18 + t * 0.72) + side * sin(walk_phase * 1.25 + t * 2.4) * radius * 0.22
			canvas.draw_arc(ripple_center, radius * (0.18 + t * 0.08 + 0.05 * leech_motion_intensity), -0.35, TAU * 0.65, 12, Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.75), maxf(radius * 0.04, 1.0))
			canvas.draw_line(ripple_center - forward * radius * 0.12, ripple_center - forward * radius * (0.34 + 0.12 * leech_motion_intensity), Color(water_color.r, water_color.g, water_color.b, water_color.a * 0.52), maxf(radius * 0.035, 1.0))
	if leech_inchworm:
		cluster_spread = maxf(0.45, cluster_spread - 0.12 * leech_motion_intensity)
		inchworm_pulse += 0.22 * leech_motion_intensity
		var sucker_phase := sin(walk_phase * 1.2)
		canvas.draw_arc(-forward * radius * 0.28, radius * (0.5 + 0.07 * leech_motion_intensity), PI * 0.1, PI * 0.9, 12, Color(dark.r, dark.g, dark.b, 0.18 + 0.08 * leech_motion_intensity), maxf(radius * 0.06, 1.0))
		for anchor_side: float in [-1.0, 1.0]:
			var anchor_center := forward * radius * (0.32 * anchor_side + 0.08 * sucker_phase * anchor_side)
			canvas.draw_arc(anchor_center, radius * (0.18 + 0.04 * leech_motion_intensity), 0.0, TAU, 14, Color(dark.r, dark.g, dark.b, 0.28 + 0.08 * leech_motion_intensity), maxf(radius * 0.045, 1.0))
			canvas.draw_line(anchor_center - forward * radius * 0.12, anchor_center - forward * radius * (0.36 + 0.12 * leech_motion_intensity), Color(dark.r, dark.g, dark.b, 0.18 + 0.06 * leech_motion_intensity), maxf(radius * 0.04, 1.0))
			canvas.draw_circle(anchor_center + forward * radius * 0.08, maxf(radius * (0.045 + 0.02 * leech_motion_intensity), 1.0), Color(dark.r, dark.g, dark.b, 0.24 + 0.08 * leech_motion_intensity))
			canvas.draw_circle(anchor_center - forward * radius * (0.2 + 0.06 * leech_motion_intensity), maxf(radius * (0.034 + 0.016 * leech_motion_intensity), 1.0), Color(dark.r, dark.g, dark.b, 0.18 + 0.08 * leech_motion_intensity))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wriggle := Time.get_ticks_msec() * 0.002 * tail_wave
	for i in 12:
		var offset := Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) * radius * cluster_spread
		var pulse := sin(walk_phase * 1.2 + float(i) * 0.75) * inchworm_pulse
		if leech_inchworm:
			offset += forward * pulse * radius * 0.36
		if leech_undulate:
			offset += side * sin(walk_phase * 1.25 + float(i) * 0.65) * radius * 0.18 * leech_motion_intensity
		var leech_forward := forward.rotated(rng.randf_range(-PI, PI) + sin(wriggle + float(i)) * 0.3 * body_wiggle)
		if leech_inchworm:
			leech_forward = forward.rotated(sin(walk_phase * 1.1 + float(i)) * 0.28)
		elif leech_undulate:
			leech_forward = forward.rotated(sin(wriggle + float(i) * 0.45) * 0.62)
		var leech_side := Vector2(-leech_forward.y, leech_forward.x)
		var half_len := radius * (0.28 + pulse * 0.08 + (0.06 * leech_motion_intensity if leech_undulate else 0.0))
		var points := PackedVector2Array([
			offset - leech_forward * half_len + leech_side * radius * 0.08,
			offset + leech_forward * half_len + leech_side * radius * 0.05,
			offset + leech_forward * (half_len + radius * 0.08),
			offset + leech_forward * half_len - leech_side * radius * 0.05,
			offset - leech_forward * half_len - leech_side * radius * 0.08
		])
		canvas.draw_colored_polygon(points, dark if i % 3 == 0 else main)
		if leech_undulate and i % 4 == 0:
			canvas.draw_circle(offset - forward * radius * 0.16, maxf(radius * 0.035, 1.0), water_color.lightened(0.25))

static func _base_bug(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, skin: Dictionary, walk_phase: float, moving: bool, anim: Dictionary = {}) -> void:
	var main: Color = skin.get("main", Color(0.22, 0.16, 0.1))
	var dark: Color = skin.get("dark", main.darkened(0.35))
	var glow: Color = skin.get("glow", Color(0.95, 0.9, 0.4))
	var breathe := float(anim.get("glow_breathe", 0.0))
	var pulse := sin(Time.get_ticks_msec() * 0.006 + walk_phase * 0.4) * 0.5 + 0.5
	var wingbeat := float(anim.get("wingbeat_mult", 1.0))
	var hover_pose := String(anim.get("creature_id", "")) == "firefly" and bool(anim.get("firefly_hover_pose", false))
	var hover_intensity := clampf(float(anim.get("firefly_hover_intensity", 0.0)), 0.0, 1.25)
	var flash_pose := String(anim.get("creature_id", "")) == "firefly" and bool(anim.get("firefly_flash_pose", false))
	var attack_t := float(anim.get("attack_t", -1.0))
	var glow_scale := 1.0 + breathe * pulse + (0.24 if flash_pose else 0.0)
	var hover_drift := side * sin(walk_phase * 0.72) * radius * 0.16 * hover_intensity if hover_pose else Vector2.ZERO
	# Bioluminescent glow halo.
	canvas.draw_circle(-forward * radius * 0.4 + hover_drift, radius * (1.55 + pulse * 0.5) * glow_scale, Color(glow.r, glow.g, glow.b, 0.1 + pulse * 0.08))
	canvas.draw_circle(-forward * radius * 0.4 + hover_drift, radius * 0.55 * glow_scale, Color(glow.r, glow.g, glow.b, 0.55 + pulse * 0.35))
	if hover_pose:
		canvas.draw_arc(-forward * radius * 0.4 + hover_drift, radius * (0.82 + 0.14 * hover_intensity), -PI * 0.15, TAU * 0.72, 20, Color(glow.r, glow.g, glow.b, 0.22 + 0.08 * hover_intensity), maxf(radius * 0.055, 1.0))
		for trail_index in 3:
			var t := float(trail_index + 1) / 3.0
			var trail := -forward * radius * (0.8 + t * 0.55) + side * sin(walk_phase * 0.9 + t * 2.4) * radius * 0.18 + hover_drift
			canvas.draw_circle(trail, radius * (0.18 + 0.08 * t) * hover_intensity, Color(glow.r, glow.g, glow.b, (0.18 - t * 0.04) * hover_intensity))
		for drift_side: float in [-1.0, 1.0]:
			var shimmer := -forward * radius * 0.22 + side * drift_side * radius * (0.62 + 0.08 * hover_intensity) + hover_drift
			canvas.draw_line(shimmer, shimmer - forward * radius * (0.44 + 0.12 * hover_intensity) + side * drift_side * radius * 0.16, Color(glow.r, glow.g, glow.b, 0.16 + 0.08 * hover_intensity), maxf(radius * 0.045, 1.0))
			canvas.draw_circle(shimmer - forward * radius * (0.26 + 0.08 * hover_intensity) + side * drift_side * radius * 0.08, maxf(radius * (0.04 + 0.015 * hover_intensity), 1.0), Color(glow.r, glow.g, glow.b, 0.24 + 0.08 * pulse))
		var lantern_drop := -forward * radius * (0.62 + 0.1 * pulse) + hover_drift
		canvas.draw_circle(lantern_drop, maxf(radius * (0.18 + 0.04 * hover_intensity), 1.4), Color(glow.r, glow.g, glow.b, 0.42 + 0.14 * pulse))
		canvas.draw_line(lantern_drop + side * radius * 0.12, lantern_drop - side * radius * 0.12, Color(glow.r, glow.g, glow.b, 0.44 + 0.16 * pulse), maxf(radius * 0.04, 1.0))
		canvas.draw_arc(lantern_drop, radius * (0.34 + 0.08 * hover_intensity), PI * 0.1, PI * 0.9, 12, Color(glow.r, glow.g, glow.b, 0.22 + 0.08 * pulse), maxf(radius * 0.04, 1.0))
	if flash_pose:
		canvas.draw_arc(-forward * radius * 0.4 + hover_drift, radius * 2.05, -0.25, TAU * 0.72, 28, Color(glow.r, glow.g, glow.b, 0.32 + pulse * 0.16), maxf(radius * 0.1, 1.5))
	if attack_t >= 0.0:
		var spark_t := clampf(attack_t, 0.0, 1.0)
		var spark_color := Color(glow.r, glow.g, glow.b, 0.28 + 0.22 * (1.0 - spark_t))
		var spark_origin := forward * radius * 0.44 + hover_drift
		canvas.draw_line(spark_origin, spark_origin + forward * radius * (1.08 + 0.28 * spark_t), spark_color, maxf(radius * 0.08, 1.3))
		canvas.draw_circle(spark_origin + forward * radius * (0.86 + 0.22 * spark_t), maxf(radius * (0.08 + 0.03 * breathe), 1.2), Color(spark_color.r, spark_color.g, spark_color.b, spark_color.a * 0.82))
	# Wings blurred mid-beat.
	for wing_side: float in [-1.0, 1.0]:
		var wing_flare := sin(walk_phase * wingbeat + wing_side) * radius * (0.08 + 0.05 * hover_intensity) if moving else 0.0
		canvas.draw_circle(side * wing_side * (radius * 0.5 + wing_flare) + forward * radius * 0.1 + hover_drift, radius * (0.4 + 0.05 * hover_intensity), Color(0.8, 0.85, 0.9, 0.25 + 0.07 * hover_intensity))
	# Body + head.
	canvas.draw_circle(hover_drift, radius * 0.42, dark)
	canvas.draw_circle(forward * radius * 0.42 + hover_drift, radius * 0.28, main)
	canvas.draw_circle(forward * radius * 0.55 + side * radius * 0.1 + hover_drift, maxf(radius * 0.07, 1.2), Color(0.05, 0.04, 0.03))
	canvas.draw_circle(forward * radius * 0.55 - side * radius * 0.1 + hover_drift, maxf(radius * 0.07, 1.2), Color(0.05, 0.04, 0.03))

# ---------- strike overlays ----------

static func _strike_tongue(canvas: CanvasItem, radius: float, aim: Vector2, reach: float, progress: float) -> void:
	# Originates at the mouth (front of the head, between the eyes).
	var mouth := aim * radius * 0.72
	var tongue_tip := aim * (radius * 0.72 + (reach - radius * 0.72) * progress)
	var tongue_color := Color(0.98, 0.42, 0.52)
	canvas.draw_line(mouth, tongue_tip, Color(0.5, 0.14, 0.2), maxf(radius * 0.34, 6.0))
	canvas.draw_line(mouth, tongue_tip, tongue_color, maxf(radius * 0.24, 4.0))
	canvas.draw_circle(tongue_tip, maxf(radius * 0.26, 5.0), tongue_color.lightened(0.15))
	canvas.draw_circle(tongue_tip, maxf(radius * 0.13, 2.5), Color(1.0, 0.85, 0.88))

# ---------- non-creature drawing ----------

static func draw_aim_indicator(canvas: CanvasItem, radius: float, facing: Vector2) -> void:
	# Subtle chevron just off the body edge — orientation cue, not an arrow.
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var tip := forward * (radius + 9.0)
	var faint := Color(1.0, 1.0, 1.0, 0.32)
	canvas.draw_line(tip, tip - forward * 5.0 + side * 4.0, faint, 1.5)
	canvas.draw_line(tip, tip - forward * 5.0 - side * 4.0, faint, 1.5)

static func minion_render_metrics(kind: String, body_radius: float) -> Dictionary:
	var visual_scale := 0.92
	var silhouette := "mandible_chomper"
	var role_features := ["truth_ring", "team_back_stripe", "mandibles"]
	match kind:
		"tank":
			visual_scale = 1.08
			silhouette = "dome_tank"
			role_features = ["truth_ring", "team_shell_arc", "wide_body", "slow_bob"]
		"pebble":
			visual_scale = 0.82
			silhouette = "sling_thrower"
			role_features = ["truth_ring", "team_back_stripe", "sling_arm", "held_pebble"]
		"melee":
			visual_scale = 0.95
			role_features = ["truth_ring", "team_back_stripe", "mandibles"]
		_:
			visual_scale = 0.9
			silhouette = "lane_chomper"
			role_features = ["truth_ring", "team_back_stripe", "mandibles", "march_bob"]
	return {
		"kind": kind,
		"silhouette": silhouette,
		"role_features": role_features,
		"combat_radius_px": body_radius,
		"truth_ring_radius_px": body_radius,
		"visual_radius_px": body_radius * visual_scale
	}

static func draw_minion(canvas: CanvasItem, kind: String, team: int, body_radius: float, facing: Vector2, anim: Dictionary = {}) -> void:
	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	var alpha := clampf(float(anim.get("alpha", 1.0)), 0.0, 1.0)
	var walk_phase := float(anim.get("walk_phase", 0.0))
	var moving := bool(anim.get("moving", false))
	var metrics := minion_render_metrics(kind, body_radius)
	var radius := float(metrics.get("visual_radius_px", body_radius))
	var team_col := _with_alpha(VisualGrammar.team_color(team), alpha)
	var mud := _with_alpha(Color(0.28, 0.22, 0.13), alpha)
	var mud_dark := _with_alpha(Color(0.13, 0.1, 0.06), alpha)
	var mud_light := _with_alpha(Color(0.44, 0.36, 0.2), alpha)
	var eye := _with_alpha(team_col.lightened(0.35), alpha)
	_draw_ground_truth_footprint(canvas, Vector2.ZERO, body_radius, team_col, alpha)
	match kind:
		"tank":
			_draw_minion_tank(canvas, radius, forward, side, mud, mud_dark, mud_light, team_col, eye, walk_phase, moving)
		"pebble":
			_draw_minion_pebble(canvas, radius, forward, side, mud, mud_dark, mud_light, team_col, eye, anim, alpha, walk_phase, moving)
		_:
			_draw_minion_chomper(canvas, radius, forward, side, mud, mud_dark, mud_light, team_col, eye, kind == "lane", walk_phase, moving)

static func _draw_minion_tank(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, mud: Color, mud_dark: Color, mud_light: Color, team_col: Color, eye: Color, walk_phase: float, moving: bool) -> void:
	var bob := absf(sin(walk_phase)) * radius * 0.06 if moving else 0.0
	var center := Vector2(0.0, -bob)
	canvas.draw_circle(center, radius, mud_dark)
	canvas.draw_circle(center - forward * radius * 0.08, radius * 0.86, mud)
	canvas.draw_arc(center - forward * radius * 0.08, radius * 0.62, PI * 1.05, PI * 1.95, 18, mud_light, maxf(radius * 0.09, 1.5))
	canvas.draw_arc(Vector2.ZERO, radius * 0.74, PI * 0.12, PI * 0.88, 18, Color(team_col.r, team_col.g, team_col.b, team_col.a * 0.52), maxf(radius * 0.12, 2.0))
	for rib: float in [-0.46, 0.0, 0.46]:
		canvas.draw_line(center - forward * radius * 0.35 + side * radius * rib, center + forward * radius * 0.45 + side * radius * rib * 0.7, Color(mud_light.r, mud_light.g, mud_light.b, mud_light.a * 0.6), maxf(radius * 0.055, 1.0))
	for foot_side: float in [-1.0, 1.0]:
		var foot_lift := sin(walk_phase + foot_side * PI) * radius * 0.07 if moving else 0.0
		canvas.draw_circle(-forward * radius * 0.26 + side * foot_side * radius * 0.62 + Vector2(0.0, foot_lift), maxf(radius * 0.11, 1.3), mud_dark)
	canvas.draw_circle(center + forward * radius * 0.52 + side * radius * 0.24, maxf(radius * 0.11, 1.4), eye)
	canvas.draw_circle(center + forward * radius * 0.52 - side * radius * 0.24, maxf(radius * 0.11, 1.4), eye)

static func _draw_minion_chomper(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, mud: Color, mud_dark: Color, mud_light: Color, team_col: Color, eye: Color, lane := false, walk_phase := 0.0, moving := false) -> void:
	var body_radius := radius * (0.86 if lane else 0.94)
	var bob := absf(sin(walk_phase)) * radius * (0.1 if lane else 0.06) if moving else 0.0
	var center := Vector2(0.0, -bob)
	canvas.draw_circle(center, body_radius, mud_dark)
	canvas.draw_circle(center - forward * radius * 0.08, body_radius * 0.9, mud)
	canvas.draw_circle(center + forward * radius * 0.42, radius * 0.5, mud_light)
	for jaw_side: float in [-1.0, 1.0]:
		var jaw_root := center + forward * radius * 0.72 + side * jaw_side * radius * 0.18
		var jaw_tip := center + forward * radius * 1.16 + side * jaw_side * radius * 0.36
		canvas.draw_line(jaw_root, jaw_tip, mud_dark, maxf(radius * 0.14, 2.0))
		canvas.draw_circle(jaw_tip, maxf(radius * 0.1, 1.4), mud_dark)
	canvas.draw_line(center - forward * radius * 0.35, center + forward * radius * 0.35, Color(team_col.r, team_col.g, team_col.b, team_col.a * 0.5), maxf(radius * 0.12, 1.6))
	for foot_side: float in [-1.0, 1.0]:
		var stride := sin(walk_phase + foot_side * PI) * radius * 0.1 if moving else 0.0
		canvas.draw_line(center - forward * radius * 0.22 + side * foot_side * radius * 0.52, center - forward * radius * 0.32 + side * foot_side * radius * 0.64 + Vector2(0.0, stride), mud_dark, maxf(radius * 0.055, 1.0))
	canvas.draw_circle(center + forward * radius * 0.58 + side * radius * 0.18, maxf(radius * 0.09, 1.2), eye)
	canvas.draw_circle(center + forward * radius * 0.58 - side * radius * 0.18, maxf(radius * 0.09, 1.2), eye)

static func _draw_minion_pebble(canvas: CanvasItem, radius: float, forward: Vector2, side: Vector2, mud: Color, mud_dark: Color, mud_light: Color, team_col: Color, eye: Color, anim: Dictionary, alpha: float, walk_phase: float, moving: bool) -> void:
	var bob := absf(sin(walk_phase)) * radius * 0.05 if moving else 0.0
	var center := Vector2(0.0, -bob)
	canvas.draw_circle(center, radius * 0.9, mud_dark)
	canvas.draw_circle(center - forward * radius * 0.08, radius * 0.78, mud)
	canvas.draw_circle(center + forward * radius * 0.42, radius * 0.38, mud_light)
	var sling_t := clampf(float(anim.get("attack_commit_t", 0.0)), 0.0, 1.0)
	var arm_back := center - forward * radius * (0.34 + sling_t * 0.2) + side * radius * 0.55
	var arm_tip := center + forward * radius * (0.82 + sling_t * 0.25) + side * radius * (0.42 - sling_t * 0.18)
	canvas.draw_line(arm_back, arm_tip, mud_dark, maxf(radius * 0.1, 1.4))
	canvas.draw_circle(arm_tip, maxf(radius * 0.14, 1.6), Color(0.56, 0.5, 0.38, alpha))
	canvas.draw_line(center - forward * radius * 0.35, center + forward * radius * 0.25, Color(team_col.r, team_col.g, team_col.b, team_col.a * 0.5), maxf(radius * 0.1, 1.4))
	canvas.draw_circle(center + forward * radius * 0.48 - side * radius * 0.18, maxf(radius * 0.08, 1.1), eye)

static func draw_pixel_core(canvas: CanvasItem, team: int, pixel_size := 8.0, alpha := 1.0) -> void:
	var team_col := _with_alpha(VisualGrammar.team_color(team), alpha)
	var dark_col := _with_alpha(Color(0.04, 0.045, 0.055), alpha)
	var core_col := _with_alpha(team_col.darkened(0.12), alpha)
	var glow_col := _with_alpha(team_col.lightened(0.3), alpha)
	for y in range(12):
		for x in range(12):
			if x == 0 or x == 11 or y == 0 or y == 11:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, dark_col, Vector2(6.0, 6.0))
			elif x in [2, 3, 8, 9] or y in [2, 3, 8, 9]:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, core_col, Vector2(6.0, 6.0))
			elif x >= 4 and x <= 7 and y >= 4 and y <= 7:
				_draw_cell(canvas, Vector2i(x, y), pixel_size, glow_col, Vector2(6.0, 6.0))

static func draw_pixel_projectile(canvas: CanvasItem, color: Color, radius: float) -> void:
	var dark_col := Color(0.04, 0.04, 0.045, color.a)
	var size := maxf(radius * 1.3, 7.0)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)), dark_col)
	canvas.draw_rect(Rect2(Vector2(-size * 0.5 + 2.0, -size * 0.5 + 2.0), Vector2(size - 4.0, size - 4.0)), color)
	canvas.draw_rect(Rect2(Vector2(0.0, -size * 0.5 + 2.0), Vector2(size * 0.8, size - 4.0)), color.lightened(0.25))

static func _draw_cells(canvas: CanvasItem, cells: Array, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	for cell in cells:
		_draw_cell(canvas, cell, pixel_size, color, origin)

static func _draw_cell(canvas: CanvasItem, cell: Vector2i, pixel_size: float, color: Color, origin := Vector2(4.0, 4.0)) -> void:
	var cell_position := Vector2((float(cell.x) - origin.x) * pixel_size, (float(cell.y) - origin.y) * pixel_size)
	canvas.draw_rect(Rect2(cell_position, Vector2(pixel_size, pixel_size)), color)

static func _with_alpha(color: Color, alpha: float) -> Color:
	var output := color
	output.a *= alpha
	return output
