extends SceneTree

const VisualStyle := preload("res://scripts/visual/visual_style.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_check_timeline_phases(failures)
	_check_recovery_language(failures)
	_check_pose_priority(failures)
	_check_bounded_dimensions(failures)
	print("alligator_visual_pose failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_timeline_phases(failures: Array[String]) -> void:
	var startup_early := _pose("startup", 0.0, "none")
	var startup_late := _pose("startup", 1.0, "none")
	if not bool(startup_late["active"]) \
			or String(startup_late["mode"]) != "startup" \
			or (startup_late["forward"] as Vector2).dot(Vector2.UP) < 0.999 \
			or float(startup_late["jaw_open"]) <= float(startup_early["jaw_open"]) \
			or float(startup_late["longitudinal_scale"]) >= 1.0 \
			or float(startup_late["translation_forward"]) >= 0.0:
		failures.append("startup must lock strike heading, compress backward, and open the jaw")

	var active_early := _pose("active", 0.0, "none")
	var active_late := _pose("active", 1.0, "none")
	if String(active_early["mode"]) != "active" \
			or float(active_early["head_extension"]) < 0.3 \
			or not is_equal_approx(
				float(active_early["head_extension"]),
				float(active_late["head_extension"])
			) \
			or float(active_early["translation_forward"]) <= 0.0:
		failures.append("active must reach full extension immediately and hold it")


func _check_recovery_language(failures: Array[String]) -> void:
	var whiff_early := _pose("recovery", 0.0, "whiff")
	var whiff_late := _pose("recovery", 1.0, "whiff")
	if String(whiff_early["mode"]) != "whiff" \
			or float(whiff_early["off_balance"]) < 0.95 \
			or float(whiff_late["off_balance"]) < 0.55 \
			or absf(float(whiff_late["rotation"])) < 0.12 \
			or absf(float(whiff_late["translation_side"])) < 0.08:
		failures.append("whiff must remain visibly off-balance through the entire recovery")

	var interrupted := _pose("recovery", 0.0, "interrupted")
	if String(interrupted["mode"]) != "interrupted" \
			or float(interrupted["recoil"]) < 0.95 \
			or float(interrupted["translation_forward"]) >= 0.0 \
			or float(interrupted["rotation"]) >= 0.0 \
			or float(interrupted["jaw_open"]) >= float(whiff_early["jaw_open"]):
		failures.append("interrupted recovery must read as a distinct closed-jaw recoil")

	var hit := _pose("recovery", 0.25, "hit")
	if String(hit["mode"]) != "hit_hold" \
			or float(hit["jaw_clamp"]) < 0.5 \
			or float(hit["jaw_open"]) > 0.08:
		failures.append("hit recovery must visibly hold the closed jaw")


func _check_pose_priority(failures: Array[String]) -> void:
	var death_roll_anim := _anim("recovery", 0.2, "whiff")
	death_roll_anim["alligator_death_roll_pose"] = true
	death_roll_anim["alligator_jaw_hold_pose"] = true
	var death_roll := VisualStyle.alligator_bite_pose(death_roll_anim, Vector2.LEFT)
	if bool(death_roll["active"]) or String(death_roll["mode"]) != "death_roll":
		failures.append("Death Roll must suppress every bite pose")

	var latch_anim := _anim("recovery", 0.9, "whiff")
	latch_anim["alligator_jaw_hold_pose"] = true
	var latch := VisualStyle.alligator_bite_pose(latch_anim, Vector2.LEFT)
	if not bool(latch["active"]) \
			or String(latch["mode"]) != "jaw_hold" \
			or float(latch["jaw_clamp"]) < 0.99 \
			or float(latch["off_balance"]) != 0.0:
		failures.append("a live jaw hold must override ordinary hit or whiff recovery")

	var idle_latch_anim := _anim("idle", 0.0, "none")
	idle_latch_anim["attack_variant"] = ""
	idle_latch_anim["strike_heading"] = Vector2.RIGHT
	idle_latch_anim["alligator_jaw_hold_pose"] = true
	var idle_latch := VisualStyle.alligator_bite_pose(
		idle_latch_anim,
		Vector2.LEFT
	)
	if not (idle_latch["forward"] as Vector2).is_equal_approx(Vector2.LEFT):
		failures.append("a post-timeline jaw hold must follow body heading")

	var other := _anim("startup", 1.0, "none")
	other["creature_id"] = "snapping_turtle"
	if bool(VisualStyle.alligator_bite_pose(other, Vector2.ZERO)["active"]):
		failures.append("Alligator pose logic must not affect another creature")


func _check_bounded_dimensions(failures: Array[String]) -> void:
	for phase_name in ["startup", "active", "recovery"]:
		for outcome_name in ["none", "hit", "whiff", "interrupted"]:
			for step in 11:
				var pose := _pose(phase_name, float(step) / 10.0, outcome_name)
				var longitudinal := float(pose["longitudinal_scale"])
				var lateral := float(pose["lateral_scale"])
				if longitudinal < 0.88 or longitudinal > 1.08 \
					or lateral < 0.94 or lateral > 1.08:
					failures.append(
						"pose dimensions escaped stable bounds: phase=%s outcome=%s pose=%s"
						% [phase_name, outcome_name, str(pose)]
					)
					return
				if pose.has("hit_region") or pose.has("open_hurtbox_regions"):
					failures.append("bite presentation must not invent a damage weakpoint")
					return


func _pose(phase_name: String, phase_t: float, outcome_name: String) -> Dictionary:
	return VisualStyle.alligator_bite_pose(
		_anim(phase_name, phase_t, outcome_name),
		Vector2.LEFT
	)


func _anim(phase_name: String, phase_t: float, outcome_name: String) -> Dictionary:
	return {
		"creature_id": "alligator",
		"attack_variant": "bite",
		"attack_phase_name": phase_name,
		"phase_t": phase_t,
		"attack_outcome_name": outcome_name,
		"strike_heading": Vector2.UP,
		"alligator_jaw_hold_pose": false,
		"alligator_death_roll_pose": false,
		"latch_attacker_pose": false,
	}
