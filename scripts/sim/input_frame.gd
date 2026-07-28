extends Resource
class_name InputFrame

const BUTTON_PRIMARY := 1
const BUTTON_ABILITY_Q := 2
const BUTTON_ABILITY_E := 4
const BUTTON_HUT_DEFEND := 8
const BUTTON_HABITAT_DEPOSIT := 16
const BUTTON_CONTEXT_ACTION := 32
const BUTTON_FLIGHT_TOGGLE := 64

var move := Vector2.ZERO
var aim := Vector2.RIGHT
var buttons := 0
var suppressed_buttons := 0

func is_pressed(button: int) -> bool:
	return (buttons & button) != 0

func suppress_buttons(mask: int) -> void:
	suppressed_buttons |= mask

func is_suppressed(button: int) -> bool:
	return (suppressed_buttons & button) != 0

func is_intentional_release(button: int) -> bool:
	return not is_pressed(button) and not is_suppressed(button)

func set_button(button: int, pressed: bool) -> void:
	if pressed:
		buttons |= button
	else:
		buttons &= ~button
