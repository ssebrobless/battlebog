extends RefCounted


static func cone_polygon_points(
	origin: Vector2,
	aim: Vector2,
	reach: float,
	spread: float,
	steps := 10
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not origin.is_finite() \
		or not aim.is_finite() \
		or aim.is_zero_approx() \
		or is_nan(reach) \
		or is_inf(reach) \
		or reach < 0.5 \
		or is_nan(spread) \
		or is_inf(spread) \
		or absf(spread) < 0.01 \
		or steps < 2:
		return points
	var direction := aim.normalized()
	var safe_spread := safe_cone_spread(spread)
	points.append(origin)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := -safe_spread * 0.5 + safe_spread * t
		var point := origin + direction.rotated(angle) * reach
		if not point.is_finite():
			return PackedVector2Array()
		points.append(point)
	if Geometry2D.triangulate_polygon(points).is_empty():
		return PackedVector2Array()
	return points


static func safe_cone_spread(spread: float) -> float:
	if is_nan(spread) or is_inf(spread) or absf(spread) < 0.01:
		return 0.0
	return clampf(absf(spread), 0.01, PI)
