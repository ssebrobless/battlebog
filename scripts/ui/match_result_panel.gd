extends Control

const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")

const PANEL_SIZE := Vector2(760.0, 470.0)
const PANEL_MIN_MARGIN := Vector2(24.0, 18.0)
const POLL_INTERVAL := 0.1

const BACKDROP_COLOR := Color(0.012, 0.018, 0.016, 0.78)
const PANEL_COLOR := Color(0.035, 0.045, 0.04, 0.98)
const PANEL_BORDER_COLOR := Color(0.62, 0.7, 0.58, 0.7)
const PRIMARY_TEXT := Color(0.95, 0.97, 0.92, 0.98)
const SECONDARY_TEXT := Color(0.68, 0.74, 0.67, 0.92)
const DIVIDER_COLOR := Color(0.38, 0.44, 0.37, 0.5)
const FOOTER_COLOR := Color(0.055, 0.07, 0.062, 0.98)

var arena: Node = null
var poll_accumulator := 0.0
var display_state: Dictionary = {}
var result_signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	visible = false
	_refresh_from_arena()

func _process(delta: float) -> void:
	poll_accumulator += delta
	if poll_accumulator < POLL_INTERVAL:
		return
	poll_accumulator = 0.0
	_refresh_from_arena()

func _notification(what: int) -> void:
	# Arena freezes direct children after capturing its immutable result. Refreshing
	# here lets the final frame reveal without relying on another gameplay tick.
	if what == NOTIFICATION_DISABLED and is_node_ready():
		_refresh_from_arena()

func get_display_state() -> Dictionary:
	_refresh_from_arena()
	return display_state.duplicate(true)

func _refresh_from_arena() -> void:
	if arena == null or not is_instance_valid(arena) or not arena.has_method("get_match_result_state"):
		_apply_display_state({})
		return
	var result: Dictionary = arena.get_match_result_state()
	if result.is_empty():
		_apply_display_state({})
		return
	_apply_display_state(_normalize_result(result))

func _apply_display_state(next_state: Dictionary) -> void:
	var next_signature := JSON.stringify(next_state)
	if next_signature == result_signature:
		return
	result_signature = next_signature
	display_state = next_state
	visible = not display_state.is_empty()
	queue_redraw()

func _normalize_result(result: Dictionary) -> Dictionary:
	var teams: Dictionary = _as_dictionary(result.get("teams", {}))
	var blue_source := _team_source(teams, "blue", 0)
	var red_source := _team_source(teams, "red", 1)
	var winner := _normalize_winner(result.get("winner", ""))
	var elapsed_sec := maxf(float(result.get("elapsed_sec", 0.0)), 0.0)
	var formatted_time := String(result.get("time", "")).strip_edges()
	if formatted_time.is_empty():
		formatted_time = _format_time(elapsed_sec)
	var reason := String(result.get("reason", "")).strip_edges()

	return {
		"visible": true,
		"winner": winner,
		"headline": "%s WINS" % winner.to_upper() if not winner.is_empty() else "MATCH COMPLETE",
		"reason": _format_reason(reason),
		"reason_key": reason,
		"time": formatted_time,
		"elapsed_sec": elapsed_sec,
		"mode": String(result.get("mode", "")).strip_edges(),
		"blue": _normalize_team(blue_source, "Blue"),
		"red": _normalize_team(red_source, "Red")
	}

func _team_source(teams: Dictionary, string_key: String, numeric_key: int) -> Dictionary:
	if teams.has(string_key):
		return _as_dictionary(teams[string_key])
	if teams.has(StringName(string_key)):
		return _as_dictionary(teams[StringName(string_key)])
	if teams.has(numeric_key):
		return _as_dictionary(teams[numeric_key])
	if teams.has(str(numeric_key)):
		return _as_dictionary(teams[str(numeric_key)])
	return {}

func _normalize_team(source: Dictionary, fallback_name: String) -> Dictionary:
	var boss_claim := _optional_int(source, ["boss_claims", "side_boss_claims", "bosses_claimed"])
	var boss_steal := _optional_int(source, ["boss_steals", "side_boss_steals", "bosses_stolen"])
	var center_claim := _optional_int(source, ["center_claims", "center_boss_claims"])
	return {
		"name": String(source.get("name", fallback_name)),
		"stocks_remaining": maxi(int(source.get("stocks_remaining", 0)), 0),
		"max_stocks": maxi(int(source.get("max_stocks", 0)), 0),
		"kills": maxi(int(source.get("kills", 0)), 0),
		"deposits": maxi(int(source.get("deposits", 0)), 0),
		"breeds": maxi(int(source.get("breeds_completed", source.get("breeds", 0))), 0),
		"boss_claims": int(boss_claim.get("value", 0)),
		"boss_claims_present": bool(boss_claim.get("present", false)),
		"boss_steals": int(boss_steal.get("value", 0)),
		"boss_steals_present": bool(boss_steal.get("present", false)),
		"center_claims": int(center_claim.get("value", 0)),
		"center_claims_present": bool(center_claim.get("present", false))
	}

func _optional_int(source: Dictionary, keys: Array[String]) -> Dictionary:
	for key in keys:
		if source.has(key):
			return {"present": true, "value": maxi(int(source.get(key, 0)), 0)}
	return {"present": false, "value": 0}

func _normalize_winner(value: Variant) -> String:
	if value is int or value is float:
		var team := int(value)
		if team == 0:
			return "Blue"
		if team == 1:
			return "Red"
	var winner := String(value).strip_edges()
	if winner.to_lower() == "blue":
		return "Blue"
	if winner.to_lower() == "red":
		return "Red"
	return winner

func _format_reason(reason: String) -> String:
	match reason:
		"core_destroyed":
			return "Enemy core destroyed"
		"stock_elimination", "stocks_depleted":
			return "Enemy team ran out of stocks"
		"time_limit":
			return "Time limit reached"
		"forfeit":
			return "Match forfeited"
		"":
			return "Final result"
		_:
			return reason.replace("_", " ").capitalize()

func _format_time(seconds: float) -> String:
	var total_seconds := maxi(int(floor(seconds)), 0)
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _draw() -> void:
	if display_state.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1280.0, 720.0)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BACKDROP_COLOR)

	var available := viewport_size - PANEL_MIN_MARGIN * 2.0
	var panel_size := Vector2(minf(PANEL_SIZE.x, available.x), minf(PANEL_SIZE.y, available.y))
	var panel := Rect2((viewport_size - panel_size) * 0.5, panel_size)
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel, PANEL_BORDER_COLOR, false, 2.0)

	_draw_header(panel)
	_draw_team_columns(panel)
	_draw_footer(panel)

func _draw_header(panel: Rect2) -> void:
	var winner := String(display_state.get("winner", ""))
	var winner_team := 0 if winner.to_lower() == "blue" else 1
	var accent := VisualGrammar.team_color(winner_team, 0.95) if not winner.is_empty() else PANEL_BORDER_COLOR
	var headline := String(display_state.get("headline", "MATCH COMPLETE"))
	var reason := String(display_state.get("reason", "Final result"))
	var time_text := String(display_state.get("time", "00:00"))
	var mode := String(display_state.get("mode", ""))

	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 6.0)), accent)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(36.0, 58.0),
		headline,
		HORIZONTAL_ALIGNMENT_LEFT,
		panel.size.x - 72.0,
		30,
		PRIMARY_TEXT
	)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(38.0, 89.0),
		"%s  |  %s" % [reason, time_text],
		HORIZONTAL_ALIGNMENT_LEFT,
		panel.size.x - 76.0,
		15,
		SECONDARY_TEXT
	)
	if not mode.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			panel.position + Vector2(panel.size.x - 230.0, 57.0),
			mode,
			HORIZONTAL_ALIGNMENT_RIGHT,
			194.0,
			13,
			SECONDARY_TEXT
		)
	draw_line(
		panel.position + Vector2(36.0, 112.0),
		panel.position + Vector2(panel.size.x - 36.0, 112.0),
		DIVIDER_COLOR,
		1.0
	)

func _draw_team_columns(panel: Rect2) -> void:
	var content_top := panel.position.y + 130.0
	var content_bottom := panel.position.y + panel.size.y - 76.0
	var center_x := panel.position.x + panel.size.x * 0.5
	draw_line(
		Vector2(center_x, content_top),
		Vector2(center_x, content_bottom),
		DIVIDER_COLOR,
		1.0
	)
	_draw_team(panel.position.x + 36.0, content_top, panel.size.x * 0.5 - 55.0, display_state.get("blue", {}), 0)
	_draw_team(center_x + 20.0, content_top, panel.size.x * 0.5 - 56.0, display_state.get("red", {}), 1)

func _draw_team(x: float, y: float, width: float, team_data: Dictionary, team: int) -> void:
	var accent := VisualGrammar.team_color(team, 0.95)
	var team_name := String(team_data.get("name", "Blue" if team == 0 else "Red")).to_upper()
	var stocks := int(team_data.get("stocks_remaining", 0))
	var max_stocks := int(team_data.get("max_stocks", 0))

	draw_string(ThemeDB.fallback_font, Vector2(x, y + 22.0), team_name, HORIZONTAL_ALIGNMENT_LEFT, width, 20, accent)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(x, y + 57.0),
		"%d / %d" % [stocks, max_stocks],
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		26,
		PRIMARY_TEXT
	)
	draw_string(ThemeDB.fallback_font, Vector2(x + 102.0, y + 53.0), "STOCKS", HORIZONTAL_ALIGNMENT_LEFT, width - 102.0, 12, SECONDARY_TEXT)
	draw_line(Vector2(x, y + 72.0), Vector2(x + width, y + 72.0), VisualGrammar.team_color(team, 0.38), 2.0)

	var rows: Array[Dictionary] = [
		{"label": "Kills", "value": int(team_data.get("kills", 0))},
		{"label": "Deposits", "value": int(team_data.get("deposits", 0))},
		{"label": "Breeds", "value": int(team_data.get("breeds", 0))}
	]
	if _show_optional_row("boss_claims_present"):
		rows.append({"label": "Boss claims", "value": int(team_data.get("boss_claims", 0))})
	if _show_optional_row("boss_steals_present"):
		rows.append({"label": "Boss steals", "value": int(team_data.get("boss_steals", 0))})
	if _show_optional_row("center_claims_present"):
		rows.append({"label": "Center claims", "value": int(team_data.get("center_claims", 0))})

	for index in rows.size():
		var row: Dictionary = rows[index]
		var row_y := y + 101.0 + float(index) * 31.0
		draw_string(ThemeDB.fallback_font, Vector2(x, row_y), String(row.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, width - 44.0, 14, SECONDARY_TEXT)
		draw_string(ThemeDB.fallback_font, Vector2(x + width - 44.0, row_y), str(int(row.get("value", 0))), HORIZONTAL_ALIGNMENT_RIGHT, 44.0, 16, PRIMARY_TEXT)

func _show_optional_row(presence_key: String) -> bool:
	var blue: Dictionary = display_state.get("blue", {})
	var red: Dictionary = display_state.get("red", {})
	return bool(blue.get(presence_key, false)) or bool(red.get(presence_key, false))

func _draw_footer(panel: Rect2) -> void:
	var footer := Rect2(
		panel.position + Vector2(0.0, panel.size.y - 58.0),
		Vector2(panel.size.x, 58.0)
	)
	draw_rect(footer, FOOTER_COLOR)
	draw_line(footer.position, footer.position + Vector2(footer.size.x, 0.0), DIVIDER_COLOR, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		footer.position + Vector2(36.0, 36.0),
		"ENTER  REMATCH",
		HORIZONTAL_ALIGNMENT_LEFT,
		220.0,
		15,
		Color(0.62, 0.94, 0.66, 0.96)
	)
	draw_string(
		ThemeDB.fallback_font,
		footer.position + Vector2(footer.size.x - 256.0, 36.0),
		"ESC  MENU",
		HORIZONTAL_ALIGNMENT_RIGHT,
		220.0,
		15,
		SECONDARY_TEXT
	)
