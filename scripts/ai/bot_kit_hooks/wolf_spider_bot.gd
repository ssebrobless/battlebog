extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const BURROW_CHARGE_RANGE_PX := 4.0 * SimConstants.UNIT_PX

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.state == CreatureStateScript.State.BURROWED:
		if distance <= BURROW_CHARGE_RANGE_PX:
			frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		else:
			frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
		return
	if actor.latch_victim != null:
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		return
	if actor.q_timer <= 0.0 \
		and distance > actor.body_radius * 5.0 \
		and distance <= BURROW_CHARGE_RANGE_PX:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	if actor.e_timer <= 0.0 and actor.health <= actor.max_health * 0.8:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)


func finalize_frame(actor: Node, frame: Resource) -> void:
	if actor.state == CreatureStateScript.State.BURROWED \
		and not frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
		and not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
