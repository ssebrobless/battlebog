extends RefCounted

static func apply(source: Node, target: Node, direction: Vector2, distance_px: float, duration := 0.18) -> void:
	if target == null \
		or not is_instance_valid(target) \
		or target.is_queued_for_deletion() \
		or not target is Node2D \
		or direction == Vector2.ZERO:
		return
	if target.has_method("is_alive") and not target.is_alive():
		return
	var uses_dash_contract := "dash_velocity" in target and "dash_timer" in target
	var uses_receiver_contract := target.has_method("receive_knockback")
	if not uses_dash_contract and not uses_receiver_contract:
		return
	var normalized_duration := maxf(duration, 0.01)
	if target.has_method("break_latch"):
		target.break_latch("knockback")
	if target.get("steering_velocity") != null:
		target.set("steering_velocity", Vector2.ZERO)
	if target.get("residual_velocity") != null:
		target.set("residual_velocity", Vector2.ZERO)
	if uses_dash_contract:
		target.set(
			"dash_velocity",
			direction.normalized() * (distance_px / normalized_duration)
		)
		target.set("dash_timer", normalized_duration)
	else:
		target.receive_knockback(direction, distance_px, normalized_duration)
	if source != null and source.has_method("emit_vfx_event"):
		source.emit_vfx_event("dash_started", {
			"actor": target,
			"from": target.global_position,
			"to": target.global_position + direction.normalized() * distance_px,
			"duration": normalized_duration
		})
