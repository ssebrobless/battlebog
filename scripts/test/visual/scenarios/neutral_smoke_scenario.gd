extends Node2D

var _clock_state := {
	"frame_index": 0,
	"fixed_step_hz": 60,
	"delta_seconds": 1.0 / 60.0,
	"elapsed_seconds": 0.0,
	"seed": 0,
}
var _viewport_size := Vector2(1280.0, 720.0)
var _marker_position := Vector2(360.0, 360.0)
var _pulse_radius := 42.0


func configure(context: Dictionary) -> void:
	_viewport_size = Vector2(
		float(context.get("viewport_width", 1280)),
		float(context.get("viewport_height", 720))
	)
	queue_redraw()


func apply_clock(clock: RefCounted) -> void:
	_clock_state = clock.snapshot()
	var elapsed := float(_clock_state["elapsed_seconds"])
	_marker_position = Vector2(
		360.0 + sin(elapsed * 2.0) * 90.0,
		360.0 + cos(elapsed * 1.5) * 36.0
	)
	_pulse_radius = 42.0 + sin(elapsed * 3.0) * 8.0
	queue_redraw()


func get_capture_state() -> Dictionary:
	return {
		"marker_position": {
			"x": _marker_position.x,
			"y": _marker_position.y,
		},
		"pulse_radius": _pulse_radius,
	}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color("#173f45"))
	draw_rect(Rect2(0.0, 520.0, _viewport_size.x, 200.0), Color("#245a55"))

	for x in range(0, int(_viewport_size.x) + 1, 80):
		draw_line(
			Vector2(float(x), 0.0),
			Vector2(float(x), _viewport_size.y),
			Color(0.26, 0.47, 0.47, 0.22),
			1.0
		)
	for y in range(0, int(_viewport_size.y) + 1, 80):
		draw_line(
			Vector2(0.0, float(y)),
			Vector2(_viewport_size.x, float(y)),
			Color(0.26, 0.47, 0.47, 0.22),
			1.0
		)

	draw_circle(Vector2(960.0, 350.0), 116.0, Color("#315f67"))
	draw_circle(Vector2(960.0, 350.0), 92.0, Color("#2f7f86"))
	draw_arc(
		Vector2(960.0, 350.0),
		116.0,
		0.0,
		TAU,
		64,
		Color("#8db7a9"),
		4.0
	)

	draw_circle(_marker_position, _pulse_radius, Color(0.98, 0.77, 0.32, 0.18))
	draw_arc(
		_marker_position,
		_pulse_radius,
		0.0,
		TAU,
		48,
		Color("#f5c451"),
		4.0
	)
	draw_circle(_marker_position, 19.0, Color("#f4eee1"))
	draw_circle(_marker_position, 9.0, Color("#cf574d"))
	draw_line(
		_marker_position,
		_marker_position + Vector2(64.0, -26.0),
		Color("#f4eee1"),
		5.0
	)

	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(52.0, 66.0),
		"BATTLE BOG VISUAL CAPTURE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		26,
		Color("#f4eee1")
	)
	draw_string(
		font,
		Vector2(52.0, 100.0),
		"neutral_smoke  frame %06d  seed %d"
		% [int(_clock_state["frame_index"]), int(_clock_state["seed"])],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color("#a9d2c1")
	)
