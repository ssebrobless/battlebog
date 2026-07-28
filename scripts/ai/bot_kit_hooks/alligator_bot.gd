extends RefCounted

const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func apply(actor: Node, _target: Node, frame: Resource, distance: float) -> void:
	if actor.latch_victim != null:
		_maintain_bite_latch(actor, frame)
		return
	if actor.e_timer <= 0.0 and not actor.is_stealthed() and distance > actor.body_radius * 5.0:
		frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)

func finalize_frame(actor: Node, frame: Resource) -> void:
	_maintain_bite_latch(actor, frame)

func _maintain_bite_latch(actor: Node, frame: Resource) -> void:
	if frame == null \
		or actor.latch_victim == null \
		or not is_instance_valid(actor.latch_victim) \
		or actor.latch_source != "Bite":
		return
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	if actor.q_timer <= 0.0 and _is_latched_victim_in_water(actor):
		frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)

func _is_latched_victim_in_water(actor: Node) -> bool:
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim):
		return false
	if actor.latch_victim.has_method("get_current_zone"):
		return String(actor.latch_victim.get_current_zone()) == TerrainMapScript.WATER
	return false
