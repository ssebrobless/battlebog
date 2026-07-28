extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const ACTION_BUTTONS := (
	InputFrameScript.BUTTON_PRIMARY
	| InputFrameScript.BUTTON_ABILITY_Q
	| InputFrameScript.BUTTON_ABILITY_E
)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	_check_input_frame_contract(failures)
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		failures.append("failed to boot Arena scene: error=%d" % error)
	else:
		await process_frame
		await process_frame
		var arena: Node = current_scene
		if arena == null:
			failures.append("Arena scene was unavailable after boot")
		else:
			_check_release_gate(arena, failures)
			_check_action_neutral_gate(arena, failures)
			_check_creature_copy_through(arena, failures)

	print("input_suppression failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_input_frame_contract(failures: Array[String]) -> void:
	var frame: Resource = InputFrameScript.new()
	if int(frame.suppressed_buttons) != 0 \
			or not frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY):
		failures.append("ordinary button-up frames should default to an intentional release")

	frame.buttons = InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q
	frame.suppress_buttons(InputFrameScript.BUTTON_PRIMARY)
	frame.suppress_buttons(InputFrameScript.BUTTON_ABILITY_E)
	if not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
			or not frame.is_suppressed(InputFrameScript.BUTTON_PRIMARY) \
			or not frame.is_suppressed(InputFrameScript.BUTTON_ABILITY_E) \
			or frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY) \
			or frame.is_intentional_release(InputFrameScript.BUTTON_ABILITY_E) \
			or not frame.is_intentional_release(InputFrameScript.BUTTON_FLIGHT_TOGGLE):
		failures.append(
			"suppression should accumulate independently from pressed state and release intent"
		)


func _check_release_gate(arena: Node, failures: Array[String]) -> void:
	var frame: Resource = InputFrameScript.new()
	frame.buttons = InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q
	arena.switch_release_mask = ACTION_BUTTONS
	arena._apply_switch_release_gate(frame)
	var first_ok: bool = (
		int(frame.buttons) == 0
		and int(frame.suppressed_buttons)
			== (InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q)
		and int(arena.switch_release_mask)
			== (InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q)
		and not frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
		and frame.is_intentional_release(InputFrameScript.BUTTON_ABILITY_E)
	)

	var held_primary: Resource = InputFrameScript.new()
	held_primary.buttons = InputFrameScript.BUTTON_PRIMARY
	arena._apply_switch_release_gate(held_primary)
	var held_ok: bool = (
		int(held_primary.buttons) == 0
		and int(held_primary.suppressed_buttons) == InputFrameScript.BUTTON_PRIMARY
		and int(arena.switch_release_mask) == InputFrameScript.BUTTON_PRIMARY
	)

	var released: Resource = InputFrameScript.new()
	arena._apply_switch_release_gate(released)
	var release_ok: bool = (
		int(released.suppressed_buttons) == 0
		and int(arena.switch_release_mask) == 0
		and released.is_intentional_release(InputFrameScript.BUTTON_PRIMARY)
	)
	if not first_ok or not held_ok or not release_ok:
		failures.append(
			"release gate should tag only currently held bits until a genuine button-up; "
			+ "first=%s held=%s released=%s mask=%d"
			% [str(first_ok), str(held_ok), str(release_ok), int(arena.switch_release_mask)]
		)
	arena.switch_release_mask = 0


func _check_action_neutral_gate(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var frame: Resource = InputFrameScript.new()
	frame.buttons = ACTION_BUTTONS
	arena.switch_action_neutral_ticks[actor.get_instance_id()] = 1
	arena._apply_switch_action_neutral_gate(actor, frame)
	var expected_mask := int(arena.SWITCH_RELEASE_BUTTONS)
	if int(frame.buttons) != 0 \
			or int(frame.suppressed_buttons) != expected_mask \
			or frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY) \
			or frame.is_intentional_release(InputFrameScript.BUTTON_CONTEXT_ACTION):
		failures.append(
			"action-neutral gate should clear actions while tagging the complete switch mask"
		)
	arena.switch_action_neutral_ticks.erase(actor.get_instance_id())


func _check_creature_copy_through(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var frame: Resource = InputFrameScript.new()
	frame.move = Vector2(0.25, -0.75)
	frame.aim = Vector2.LEFT
	frame.buttons = ACTION_BUTTONS
	frame.suppress_buttons(InputFrameScript.BUTTON_PRIMARY)
	var filtered: Resource = actor._without_action_buttons(
		frame,
		InputFrameScript.BUTTON_ABILITY_Q | InputFrameScript.BUTTON_ABILITY_E
	)
	if filtered == frame \
			or filtered.move != frame.move \
			or filtered.aim != frame.aim \
			or int(filtered.buttons) != InputFrameScript.BUTTON_PRIMARY \
			or int(filtered.suppressed_buttons) != ACTION_BUTTONS \
			or filtered.is_intentional_release(InputFrameScript.BUTTON_PRIMARY):
		failures.append(
			"Creature ability filtering should preserve movement, aim, primary, and provenance"
		)
