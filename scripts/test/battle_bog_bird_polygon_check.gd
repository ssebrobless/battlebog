extends SceneTree

const VisualStyle := preload("res://scripts/visual/visual_style.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var radius := 20.0
	var forward := Vector2.RIGHT
	var side := Vector2.DOWN
	for wing_side: float in [-1.0, 1.0]:
		for flap_step in range(-20, 21):
			var flap := float(flap_step) * 0.05
			for width: float in [0.9, 1.4, 1.9, 2.5, 3.0]:
				var wing_tip := side * wing_side * radius * width \
					+ forward * radius * (0.1 + flap)
				var points: PackedVector2Array = VisualStyle._bird_wing_points(
					radius,
					forward,
					side,
					wing_side,
					wing_tip,
					flap
				)
				var triangles := Geometry2D.triangulate_polygon(points)
				if triangles.size() != 6:
					failures.append(
						"wing polygon failed triangulation side=%.1f flap=%.2f width=%.1f"
						% [wing_side, flap, width]
					)
					break
			if not failures.is_empty():
				break
		if not failures.is_empty():
			break
	print("bird_polygon triangulation=%s" % str(failures.is_empty()))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
