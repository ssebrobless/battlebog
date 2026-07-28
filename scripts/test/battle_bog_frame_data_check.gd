extends SceneTree

const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const ALL_ACTIONS := InputFrameScript.BUTTON_PRIMARY \
	| InputFrameScript.BUTTON_ABILITY_Q \
	| InputFrameScript.BUTTON_ABILITY_E \
	| InputFrameScript.BUTTON_HUT_DEFEND \
	| InputFrameScript.BUTTON_HABITAT_DEPOSIT \
	| InputFrameScript.BUTTON_CONTEXT_ACTION \
	| InputFrameScript.BUTTON_FLIGHT_TOGGLE

const CONFIG := {
	"startup": 0.10,
	"active": 0.20,
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


class TestArena:
	extends Node

	var simulation_tick := 1
	var match_over := false

	func get_terrain_zone(_point: Vector2) -> String:
		return "land"

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_vfx_event(_event: Dictionary) -> void:
		pass


class HitResolver:
	extends RefCounted

	func resolve() -> Dictionary:
		return {"outcome": "hit", "hit_count": 1}


func _initialize() -> void:
	var failures: Array[String] = []
	var arena := TestArena.new()
	get_root().add_child(arena)
	var actor := CreatureScript.new()
	arena.add_child(actor)
	actor.setup(arena, 0, Vector2.ZERO, "chorus_frog")
	var data: Dictionary = actor.creature_data.duplicate(true)
	var next_stats: Dictionary = data.get("stats", {}).duplicate(true)
	next_stats["action_timelines"] = {"probe": CONFIG.duplicate(true)}
	data["stats"] = next_stats
	actor.creature_data = data
	actor.stats = next_stats
	actor.primary_timer = 0.0

	var resolver := HitResolver.new()
	if not actor.request_primary_attack("probe", {}, Callable(resolver, "resolve")):
		failures.append("frame-data fixture could not start its canonical action timeline")
	else:
		var startup_records: Array[Dictionary] = actor.get_authoritative_action_phase_records()
		if startup_records.size() != 1 \
			or String(startup_records[0].get("action_id", "")) != "probe" \
			or String(startup_records[0].get("phase", "")) != "startup" \
			or not bool(startup_records[0].get("counter_vulnerable", false)):
			failures.append(
				"primary startup must expose one authoritative counter-vulnerable record; records=%s"
				% str(startup_records)
			)
		var startup_frame := _frame(ALL_ACTIONS)
		var startup_filtered: Resource = actor.filter_action_start_frame(startup_frame)
		var expected_startup_buttons := ALL_ACTIONS \
			& ~(InputFrameScript.BUTTON_ABILITY_Q | InputFrameScript.BUTTON_ABILITY_E)
		if int(startup_filtered.buttons) != expected_startup_buttons \
			or int(startup_filtered.suppressed_buttons) \
				!= (InputFrameScript.BUTTON_ABILITY_Q | InputFrameScript.BUTTON_ABILITY_E):
			failures.append(
				"startup must suppress Q/E with provenance while preserving other starts; frame=%s/%s"
				% [startup_filtered.buttons, startup_filtered.suppressed_buttons]
			)

		arena.simulation_tick = 2
		actor.set_input_frame(InputFrameScript.new())
		actor.tick_sim(0.11)
		var active_frame := _frame(InputFrameScript.BUTTON_ABILITY_Q)
		var active_filtered: Resource = actor.filter_action_start_frame(active_frame)
		if not active_filtered.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) \
			or active_filtered.is_suppressed(InputFrameScript.BUTTON_ABILITY_Q):
			failures.append("active contact must preserve Q so Death Roll can consume the edge")

		arena.simulation_tick = 3
		actor.set_input_frame(InputFrameScript.new())
		actor.tick_sim(0.20)
		var recovery_frame := _frame(ALL_ACTIONS)
		recovery_frame.suppress_buttons(InputFrameScript.BUTTON_CONTEXT_ACTION)
		var recovery_filtered: Resource = actor.filter_action_start_frame(recovery_frame)
		if actor.primary_attack_timeline.current_phase_name() != &"recovery" \
			or int(recovery_filtered.buttons) != 0 \
			or int(recovery_filtered.suppressed_buttons) != ALL_ACTIONS \
			or recovery_filtered.move != recovery_frame.move \
			or recovery_filtered.aim != recovery_frame.aim:
			failures.append(
				"recovery must neutralize every action start and retain movement/aim/provenance; phase=%s frame=%s/%s"
				% [
					actor.primary_attack_timeline.current_phase_name(),
					recovery_filtered.buttons,
					recovery_filtered.suppressed_buttons,
				]
			)
		var recovery_records: Array[Dictionary] = actor.get_authoritative_action_phase_records()
		if recovery_records.size() != 1 \
			or String(recovery_records[0].get("phase", "")) != "recovery" \
			or bool(recovery_records[0].get("counter_vulnerable", true)):
			failures.append(
				"primary recovery must remain authoritative but not counter-vulnerable; records=%s"
				% str(recovery_records)
			)

	print("frame_data failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	arena.free()
	quit(0 if failures.is_empty() else 1)


func _frame(buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Vector2(0.4, -0.7)
	frame.aim = Vector2.LEFT * 100.0
	frame.buttons = buttons
	return frame
