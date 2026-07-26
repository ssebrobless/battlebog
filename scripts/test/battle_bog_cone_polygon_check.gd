extends SceneTree

const TelegraphGeometry := preload("res://scripts/visual/telegraph_geometry.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, 0.0, PI * 0.52, 10, "zero reach", failures)
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, -10.0, PI * 0.52, 10, "negative reach", failures)
	_expect_empty(Vector2.ZERO, Vector2.ZERO, 20.0, PI * 0.52, 10, "zero aim", failures)
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, 20.0, 0.0, 10, "zero spread", failures)
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, INF, PI * 0.52, 10, "infinite reach", failures)
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, 20.0, INF, 10, "infinite spread", failures)
	_expect_empty(Vector2.ZERO, Vector2.RIGHT, 20.0, PI * 0.52, 1, "too few steps", failures)
	for remaining: float in [0.16, 0.16 - (1.0 / 60.0), 0.08, 0.0]:
		var progress := 1.0 - clampf(remaining / 0.16, 0.0, 1.0)
		if progress == 0.0:
			_expect_empty(
				Vector2.ZERO,
				Vector2.RIGHT,
				16.0 * progress,
				PI * 0.52,
				10,
				"wolf spider first windup frame",
				failures
			)
		else:
			_expect_valid(
				Vector2.ZERO,
				Vector2.RIGHT,
				16.0 * progress,
				PI * 0.52,
				10,
				"wolf spider windup progress %.3f" % progress,
				failures
			)
	_expect_valid(Vector2(20.0, 30.0), Vector2.RIGHT, 80.0, PI * 0.52, 10, "windup cone", failures)
	_expect_valid(Vector2.ZERO, Vector2(3.0, -2.0), 120.0, TAU, 16, "clamped wide cone", failures)
	if not is_equal_approx(TelegraphGeometry.safe_cone_spread(TAU), PI):
		failures.append("wide cone spreads should clamp to a 180-degree telegraph")

	print("cone_polygon passed=%s" % str(failures.is_empty()))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect_empty(
	origin: Vector2,
	aim: Vector2,
	reach: float,
	spread: float,
	steps: int,
	label: String,
	failures: Array[String]
) -> void:
	var points: PackedVector2Array = TelegraphGeometry.cone_polygon_points(
		origin,
		aim,
		reach,
		spread,
		steps
	)
	if not points.is_empty():
		failures.append("%s should not emit polygon vertices" % label)


func _expect_valid(
	origin: Vector2,
	aim: Vector2,
	reach: float,
	spread: float,
	steps: int,
	label: String,
	failures: Array[String]
) -> void:
	var points: PackedVector2Array = TelegraphGeometry.cone_polygon_points(
		origin,
		aim,
		reach,
		spread,
		steps
	)
	var triangles := Geometry2D.triangulate_polygon(points)
	var invalid_vertex := false
	for point: Vector2 in points:
		invalid_vertex = invalid_vertex or not point.is_finite()
	var invalid_index := false
	for index: int in triangles:
		invalid_index = invalid_index or index < 0 or index >= points.size()
	if points.size() != steps + 2 \
		or triangles.size() != steps * 3 \
		or invalid_vertex \
		or invalid_index:
		failures.append(
			"%s should emit a finite triangulatable fan; points=%d triangles=%d finite=%s indices=%s"
			% [
				label,
				points.size(),
				triangles.size(),
				str(not invalid_vertex),
				str(not invalid_index)
			]
		)
