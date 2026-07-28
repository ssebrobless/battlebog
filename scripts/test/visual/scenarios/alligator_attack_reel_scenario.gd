extends Node2D

const AttackTimeline := preload("res://scripts/sim/combat/attack_timeline.gd")
const VisualStyle := preload("res://scripts/visual/visual_style.gd")

const CREATURE_ORIGIN := Vector2(470.0, 350.0)
const STRIKE_HEADING := Vector2.RIGHT
const BODY_RADIUS := 72.0
const ATTACK_REACH := 205.0
const HIT_START_FRAME := 6
const WHIFF_START_FRAME := 60
const INTERRUPT_START_FRAME := 138
const INTERRUPT_FRAME := 147
const COUNTER_FLASH_FIRST_FRAME := 24
const COUNTER_FLASH_FINAL_FRAME := 30
const COUNTER_FLASH_COLOR := Color(1.0, 0.88, 0.24, 1.0)
const ATTACK_CONFIG := {
	"startup": 0.30,
	"active": 0.10,
	"recovery": {
		"hit": 0.48,
		"whiff": 0.80,
		"released": 0.40,
		"interrupted": 0.50,
	},
	"movement_mult": {
		"startup": 1.0,
		"active": 1.0,
		"recovery": 1.0,
	},
	"blocks_abilities": {
		"startup": true,
		"active": false,
		"recovery": true,
	},
	"phase_tags": {
		"startup": ["warning"],
		"active": ["contact"],
		"recovery": ["punishable"],
	},
	"recovery_allows_dash_cancel": false,
}

var _timeline: RefCounted = AttackTimeline.new()
var _clock_state := {
	"frame_index": 0,
	"fixed_step_hz": 60,
	"delta_seconds": 1.0 / 60.0,
	"elapsed_seconds": 0.0,
	"seed": 0,
}
var _viewport_size := Vector2(1280.0, 720.0)
var _resolver_outcome := "hit"
var _reel_segment := "neutral"
var _timeline_snapshot := {}


func configure(context: Dictionary) -> void:
	_viewport_size = Vector2(
		float(context.get("viewport_width", 1280)),
		float(context.get("viewport_height", 720))
	)
	_rebuild_to_frame(0, int(context.get("fixed_step_hz", 60)))
	queue_redraw()


func apply_clock(clock: RefCounted) -> void:
	_clock_state = clock.snapshot()
	_rebuild_to_frame(
		int(_clock_state["frame_index"]),
		int(_clock_state["fixed_step_hz"])
	)
	queue_redraw()


func get_capture_state() -> Dictionary:
	return {
		"reel_segment": _reel_segment,
		"attack_phase": String(_timeline_snapshot.get("attack_phase_name", "idle")),
		"attack_outcome": String(_timeline_snapshot.get("attack_outcome_name", "none")),
		"phase_t": float(_timeline_snapshot.get("phase_t", 0.0)),
		"attack_sequence_id": int(_timeline_snapshot.get("attack_sequence_id", 0)),
		"attack_started_tick": int(_timeline_snapshot.get("attack_started_tick", -1)),
		"attack_active_tick": int(_timeline_snapshot.get("attack_active_tick", -1)),
		"attack_interrupted_tick": int(
			_timeline_snapshot.get("attack_interrupted_tick", -1)
		),
		"counter_flash_t": _counter_flash_t(),
		"counter_flash_color": COUNTER_FLASH_COLOR.to_html(),
		"strike_heading": {
			"x": float(STRIKE_HEADING.x),
			"y": float(STRIKE_HEADING.y),
		},
	}


func _rebuild_to_frame(frame_index: int, fixed_step_hz: int) -> void:
	# A fresh timeline makes every seek independent of prior validation/capture calls.
	_timeline = AttackTimeline.new()
	_resolver_outcome = "hit"
	var safe_hz := maxi(fixed_step_hz, 1)
	var delta := 1.0 / float(safe_hz)

	for simulation_frame in range(frame_index + 1):
		var started_this_frame := false
		if simulation_frame == HIT_START_FRAME:
			_resolver_outcome = "hit"
			started_this_frame = _start_attack(simulation_frame, "hit_demo")
		elif simulation_frame == WHIFF_START_FRAME:
			_resolver_outcome = "whiff"
			started_this_frame = _start_attack(simulation_frame, "whiff_demo")
		elif simulation_frame == INTERRUPT_START_FRAME:
			_resolver_outcome = "hit"
			started_this_frame = _start_attack(simulation_frame, "interrupt_demo")

		if simulation_frame == INTERRUPT_FRAME:
			_timeline.interrupt("fixture_stagger", simulation_frame, false)
			continue
		if not started_this_frame:
			_timeline.advance(
				delta,
				simulation_frame,
				Callable(self, "_resolve_active")
			)

	_timeline_snapshot = _timeline.snapshot()
	_reel_segment = _segment_for_frame(frame_index)


func _start_attack(simulation_frame: int, demo_name: String) -> bool:
	return _timeline.start(
		ATTACK_CONFIG,
		{"attack_variant": "alligator_bite", "demo": demo_name},
		STRIKE_HEADING,
		simulation_frame,
		1.0
	)


func _resolve_active() -> Dictionary:
	return {
		"outcome": _resolver_outcome,
		"hit_count": 1 if _resolver_outcome == "hit" else 0,
		"hit_region": "body" if _resolver_outcome == "hit" else "",
	}


func _segment_for_frame(_frame_index: int) -> String:
	var phase_name := String(_timeline_snapshot.get("attack_phase_name", "idle"))
	var outcome_name := String(_timeline_snapshot.get("attack_outcome_name", "none"))
	match phase_name:
		"startup":
			var payload_value: Variant = _timeline_snapshot.get("payload", {})
			if typeof(payload_value) == TYPE_DICTIONARY \
				and String((payload_value as Dictionary).get("demo", "")) \
				== "interrupt_demo":
				return "interrupt_startup"
			return "startup"
		"active":
			return "active"
		"recovery":
			match outcome_name:
				"hit":
					return "hit_recovery"
				"whiff":
					return "whiff_recovery"
				"interrupted":
					return "interrupted_recovery"
				"released":
					return "released_recovery"
	return "neutral"


func _draw() -> void:
	_draw_backdrop()
	_draw_attack_geometry()

	var anim := _timeline_render_state()
	VisualStyle.draw_battle_creature(
		self,
		"alligator",
		0,
		BODY_RADIUS,
		STRIKE_HEADING,
		0.0,
		1.0,
		false,
		anim
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_header()
	_draw_state_panel()
	_draw_reel_timeline()


func _timeline_render_state() -> Dictionary:
	var phase_name := String(_timeline_snapshot.get("attack_phase_name", "idle"))
	var outcome_name := String(_timeline_snapshot.get("attack_outcome_name", "none"))
	var phase_t := clampf(float(_timeline_snapshot.get("phase_t", 0.0)), 0.0, 1.0)
	var anim := {
		"origin": CREATURE_ORIGIN,
		"creature_id": "alligator",
		"model_scale": 1.0,
		"height_units": 0.45,
		"moving": false,
		"walk_phase": 0.0,
		"attack_aim": STRIKE_HEADING,
		"attack_reach": ATTACK_REACH,
		"attack_variant": "bite",
		"counter_flash_t": _counter_flash_t(),
		"counter_flash_color": COUNTER_FLASH_COLOR,
		"attack_phase_name": phase_name,
		"attack_outcome_name": outcome_name,
		"phase_t": phase_t,
		"strike_heading": STRIKE_HEADING,
	}

	if phase_name == "recovery" and outcome_name == "hit":
		# A normal creature hit enters the live Bite latch pose during recovery.
		anim["alligator_jaw_hold_pose"] = true
	return anim


func _counter_flash_t() -> float:
	var frame_index := int(_clock_state.get("frame_index", 0))
	if frame_index < COUNTER_FLASH_FIRST_FRAME \
		or frame_index > COUNTER_FLASH_FINAL_FRAME:
		return 0.0
	return float(COUNTER_FLASH_FINAL_FRAME - frame_index + 1) \
		/ float(COUNTER_FLASH_FINAL_FRAME - COUNTER_FLASH_FIRST_FRAME + 1)


func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color("#102f35"))
	draw_rect(
		Rect2(Vector2(0.0, 505.0), Vector2(_viewport_size.x, 215.0)),
		Color("#214d48")
	)
	draw_circle(Vector2(290.0, 382.0), 255.0, Color("#173e40"))
	draw_circle(Vector2(290.0, 382.0), 205.0, Color("#1d4a49"))
	draw_arc(
		Vector2(290.0, 382.0),
		255.0,
		0.0,
		TAU,
		64,
		Color(0.48, 0.72, 0.66, 0.22),
		3.0
	)
	for x in range(0, int(_viewport_size.x) + 1, 80):
		draw_line(
			Vector2(float(x), 0.0),
			Vector2(float(x), _viewport_size.y),
			Color(0.34, 0.55, 0.52, 0.10),
			1.0
		)
	for y in range(0, int(_viewport_size.y) + 1, 80):
		draw_line(
			Vector2(0.0, float(y)),
			Vector2(_viewport_size.x, float(y)),
			Color(0.34, 0.55, 0.52, 0.10),
			1.0
		)


func _draw_attack_geometry() -> void:
	var phase_name := String(_timeline_snapshot.get("attack_phase_name", "idle"))
	var outcome_name := String(_timeline_snapshot.get("attack_outcome_name", "none"))
	var phase_t := clampf(float(_timeline_snapshot.get("phase_t", 0.0)), 0.0, 1.0)
	var mouth := CREATURE_ORIGIN + STRIKE_HEADING * BODY_RADIUS * 1.45
	var contact := CREATURE_ORIGIN + STRIKE_HEADING * ATTACK_REACH
	var side := Vector2(-STRIKE_HEADING.y, STRIKE_HEADING.x)

	if phase_name == "startup":
		var warning := Color(0.98, 0.76, 0.24, 0.26 + phase_t * 0.28)
		var half_width := BODY_RADIUS * (0.38 + phase_t * 0.10)
		draw_colored_polygon(
			PackedVector2Array([
				mouth + side * half_width,
				contact + side * half_width * 0.62,
				contact - side * half_width * 0.62,
				mouth - side * half_width,
			]),
			Color(warning.r, warning.g, warning.b, warning.a * 0.35)
		)
		draw_line(mouth, contact, warning, 4.0)
		draw_arc(contact, BODY_RADIUS * 0.42, 0.0, TAU, 40, warning, 4.0)
	elif phase_name == "active":
		var contact_color := Color(1.0, 0.35, 0.24, 0.72)
		draw_line(mouth, contact, contact_color, 10.0)
		draw_circle(contact, BODY_RADIUS * 0.36, Color(1.0, 0.28, 0.18, 0.24))
		draw_arc(contact, BODY_RADIUS * 0.48, 0.0, TAU, 40, contact_color, 6.0)
	elif phase_name == "recovery":
		var recovery_color := Color("#74d8bd")
		if outcome_name == "whiff":
			recovery_color = Color("#f2b84b")
		elif outcome_name == "interrupted":
			recovery_color = Color("#da83f5")
		var recovery_radius := BODY_RADIUS * (1.9 - phase_t * 0.25)
		for arc_index in 3:
			var start_angle := -0.75 + float(arc_index) * 0.58
			draw_arc(
				CREATURE_ORIGIN,
				recovery_radius + float(arc_index) * 7.0,
				start_angle,
				start_angle + 0.32,
				14,
				Color(
					recovery_color.r,
					recovery_color.g,
					recovery_color.b,
					0.55 - float(arc_index) * 0.10
				),
				5.0
			)


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(48.0, 58.0),
		"ALLIGATOR ORDINARY ATTACK REEL",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		28,
		Color("#f4eee1")
	)
	draw_string(
		font,
		Vector2(48.0, 91.0),
		"deterministic 60 Hz timeline  |  frame %06d  |  seed %d"
		% [int(_clock_state["frame_index"]), int(_clock_state["seed"])],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		18,
		Color("#a9d2c1")
	)


func _draw_state_panel() -> void:
	var font := ThemeDB.fallback_font
	var phase_name := String(_timeline_snapshot.get("attack_phase_name", "idle"))
	var outcome_name := String(_timeline_snapshot.get("attack_outcome_name", "none"))
	var phase_t := clampf(float(_timeline_snapshot.get("phase_t", 0.0)), 0.0, 1.0)
	var panel := Rect2(840.0, 154.0, 378.0, 308.0)
	draw_rect(panel, Color(0.035, 0.09, 0.10, 0.94))
	draw_rect(Rect2(panel.position, Vector2(7.0, panel.size.y)), _segment_color())
	draw_string(
		font,
		Vector2(872.0, 202.0),
		_reel_segment.to_upper().replace("_", " "),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		26,
		Color("#f4eee1")
	)
	draw_string(
		font,
		Vector2(872.0, 248.0),
		"PHASE       %s" % phase_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		19,
		Color("#b6d8cf")
	)
	draw_string(
		font,
		Vector2(872.0, 282.0),
		"OUTCOME     %s" % outcome_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		19,
		Color("#b6d8cf")
	)
	draw_string(
		font,
		Vector2(872.0, 316.0),
		"SEQUENCE    %02d"
		% int(_timeline_snapshot.get("attack_sequence_id", 0)),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		19,
		Color("#b6d8cf")
	)
	draw_string(
		font,
		Vector2(872.0, 350.0),
		"PROGRESS    %03d%%" % int(round(phase_t * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		19,
		Color("#b6d8cf")
	)
	var bar := Rect2(872.0, 378.0, 306.0, 16.0)
	draw_rect(bar, Color("#173136"))
	draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * phase_t, bar.size.y)),
		_segment_color()
	)
	draw_string(
		font,
		Vector2(872.0, 431.0),
		_state_read(),
		HORIZONTAL_ALIGNMENT_LEFT,
		306.0,
		16,
		Color("#d8e8df")
	)


func _draw_reel_timeline() -> void:
	var font := ThemeDB.fallback_font
	var left := 55.0
	var right := 1225.0
	var y := 610.0
	draw_line(Vector2(left, y), Vector2(right, y), Color("#86aaa2"), 3.0)
	var markers := [
		{"frame": 0, "label": "NEUTRAL"},
		{"frame": 12, "label": "STARTUP"},
		{"frame": 24, "label": "ACTIVE"},
		{"frame": 36, "label": "HIT REC."},
		{"frame": 96, "label": "WHIFF REC."},
		{"frame": 153, "label": "INT. REC."},
	]
	var current_frame := int(_clock_state["frame_index"])
	for marker in markers:
		var marker_frame := int(marker["frame"])
		var t := float(marker_frame) / 153.0
		var marker_x := lerpf(left, right, t)
		var selected := marker_frame == current_frame
		draw_circle(
			Vector2(marker_x, y),
			10.0 if selected else 6.0,
			_segment_color() if selected else Color("#a9d2c1")
		)
		draw_string(
			font,
			Vector2(marker_x - 46.0, y + 40.0),
			String(marker["label"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			92.0,
			13,
			Color("#f4eee1") if selected else Color("#a9d2c1")
		)
		draw_string(
			font,
			Vector2(marker_x - 30.0, y - 20.0),
			"%03d" % marker_frame,
			HORIZONTAL_ALIGNMENT_CENTER,
			60.0,
			12,
			Color("#a9d2c1")
		)


func _segment_color() -> Color:
	match _reel_segment:
		"startup", "interrupt_startup":
			return Color("#f3c451")
		"active":
			return Color("#f0604f")
		"hit_recovery":
			return Color("#61d3ad")
		"whiff_recovery":
			return Color("#e9a93f")
		"interrupted_recovery":
			return Color("#d07bea")
		_:
			return Color("#8fbdb0")


func _state_read() -> String:
	match _reel_segment:
		"neutral":
			return "Baseline silhouette and facing."
		"startup", "interrupt_startup":
			return "Warning lane and recoil compression."
		"active":
			return "Contact snap on locked heading."
		"hit_recovery":
			return "Confirmed bite hold; short recovery."
		"whiff_recovery":
			return "Missed bite; long off-balance window."
		"released_recovery":
			return "Released bite; committed recovery."
		"interrupted_recovery":
			return "Startup broken; stagger recoil."
		_:
			return "Deterministic attack presentation."
