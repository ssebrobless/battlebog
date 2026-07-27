extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["wolf_spider", "alligator", "water_snake"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave3 wolf spider check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "wolf_spider":
		push_error("expected wolf_spider active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_lunge_latch_slow(arena, failures)
	_check_burrow_cap_hide_charge(arena, failures)
	_check_spiderlings_and_trap(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave3_wolf_spider failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_lunge_latch_slow(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("cane_toad")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 42.0
	target.health = target.max_health
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = target.global_position
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var lunge_state: Dictionary = actor.get_render_motion_state()
	var lunge_read: bool = bool(lunge_state.get("spider_lunge_pose", false))
	actor.dash_timer = 0.0
	actor.global_position = target.global_position - Vector2.RIGHT * 12.0
	actor.kit.tick(actor, 0.016)
	var latched: bool = actor.latch_victim == target and target.latched_attacker == actor
	var latch_read: bool = bool(actor.get_render_motion_state().get("spider_latch_pose", false))
	var slowed: bool = target.get_modifier_value("move_speed_mult", 1.0) < 0.7
	var held_frame := InputFrameScript.new()
	held_frame.aim = target.global_position
	held_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(held_frame)
	actor.kit.tick(actor, 0.5)
	var held: bool = actor.latch_victim == target and actor.latch_timer > 0.0
	var release := InputFrameScript.new()
	release.aim = target.global_position
	actor.set_input_frame(release)
	actor.kit.tick(actor, 0.05)
	var released: bool = actor.latch_victim == null and target.latched_attacker == null
	if not lunge_read or not latched or not latch_read or not slowed or not held or not released:
		failures.append("Wolf Spider primary should expose lunge/latch poses, latch, ramp slow while held, and release on primary up; lunge=%s latched=%s latch_pose=%s slowed=%s held=%s released=%s speed=%.2f state=%s" % [
			str(lunge_read),
			str(latched),
			str(latch_read),
			str(slowed),
			str(held),
			str(released),
			target.get_modifier_value("move_speed_mult", 1.0),
			str(lunge_state)
		])

func _check_burrow_cap_hide_charge(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.release_latch("test_reset")
	actor.kit.burrows.clear()
	for i in 5:
		actor.state = CreatureStateScript.State.NORMAL
		actor.remove_modifiers_from_source("Silk-lined Burrow")
		actor.global_position = Vector2(float(i) * 20.0, 60.0)
		actor.q_timer = 0.0
		var q := InputFrameScript.new()
		q.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
		actor.set_input_frame(q)
		actor.kit.tick(actor, 0.016)
	var capped: bool = actor.kit.burrows.size() == 4
	var hidden: bool = actor.state == CreatureStateScript.State.BURROWED and actor.is_untargetable() and not TargetFilter.is_live_damage_target(target, actor)
	var burrow_read: bool = bool(actor.get_render_motion_state().get("spider_burrowed_pose", false))

	target.apply_creature("cane_toad")
	target.global_position = actor.global_position + Vector2.RIGHT * 48.0
	target.health = target.max_health
	var primary := InputFrameScript.new()
	primary.aim = target.global_position
	primary.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(primary)
	actor.kit.tick(actor, 0.016)
	var emerged: bool = actor.state == CreatureStateScript.State.NORMAL and not actor.is_untargetable()
	var charging: bool = actor.dash_timer > 0.0 and actor.dash_velocity.length() > 0.0
	actor.dash_timer = 0.0
	actor.global_position = target.global_position - Vector2.RIGHT * 12.0
	actor.kit.tick(actor, 0.016)
	var hit: bool = target.health < target.max_health
	if not capped or not hidden or not burrow_read or not emerged or not charging or not hit:
		failures.append("Wolf Spider burrows should cap at 4, hide with readable burrow pose, then charge targets within 4u; capped=%s hidden=%s burrow=%s emerged=%s charging=%s hit=%s count=%d health=%.2f" % [
			str(capped),
			str(hidden),
			str(burrow_read),
			str(emerged),
			str(charging),
			str(hit),
			actor.kit.burrows.size(),
			target.health
		])

func _check_spiderlings_and_trap(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.kit._retire_spiderlings()
	actor.kit.trap_hatches.clear()
	actor.e_timer = 0.0
	actor.state = CreatureStateScript.State.NORMAL
	actor.global_position = Vector2(-80.0, -80.0)
	var e := InputFrameScript.new()
	e.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(e)
	actor.kit.tick(actor, 0.016)
	actor.kit.tick(actor, 10.0)
	var hatched_cap: bool = actor.kit.spiderlings.size() == 12
	actor.kit._hatch_spiderlings(actor, actor.global_position, 12)
	var hard_cap: bool = actor.kit.spiderlings.size() == 12

	actor.kit._retire_spiderlings()
	actor.kit.trap_hatches.clear()
	actor.q_timer = 0.0
	var q := InputFrameScript.new()
	q.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(q)
	actor.kit.tick(actor, 0.016)
	actor.e_timer = 0.0
	actor.set_input_frame(e)
	actor.kit.tick(actor, 0.016)
	actor.kit.tick(actor, 10.0)
	var stored: bool = actor.kit.trap_hatches.size() == 1 and actor.kit.spiderlings.is_empty()
	var target: Node = arena.bots[1]
	target.apply_creature("cane_toad")
	target.global_position = actor.kit.trap_hatches[0].get("position", actor.global_position) + Vector2.RIGHT * 10.0 if stored else actor.global_position
	actor.kit.tick(actor, 0.016)
	var trap_hatched: bool = actor.kit.trap_hatches.is_empty() and actor.kit.spiderlings.size() == 12
	if not hatched_cap or not hard_cap or not stored or not trap_hatched:
		failures.append("Wolf Spider eggs should hatch 12 spiderlings, enforce cap, and burrow-hatch as a trap; hatched=%s hard_cap=%s stored=%s trap=%s spiderlings=%d traps=%d" % [
			str(hatched_cap),
			str(hard_cap),
			str(stored),
			str(trap_hatched),
			actor.kit.spiderlings.size(),
			actor.kit.trap_hatches.size()
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("wolf_spider")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.health = actor.max_health * 0.5
	var ambush_range: float = float(actor.body_radius) * 6.0
	var far := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, far, ambush_range)
	var burrows: bool = far.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
	var eggs: bool = far.is_pressed(InputFrameScript.BUTTON_ABILITY_E)
	var distant := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, distant, actor.body_radius * 12.0)
	var travels_when_distant: bool = not distant.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
	actor.state = CreatureStateScript.State.BURROWED
	var ambush := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, ambush, actor.body_radius * 4.0)
	var charges: bool = ambush.is_pressed(InputFrameScript.BUTTON_PRIMARY)
	var surface := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, surface, actor.body_radius * 12.0)
	var surfaces_when_distant: bool = surface.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
	actor.state = CreatureStateScript.State.NORMAL
	actor.remove_modifiers_from_source("Silk-lined Burrow")
	actor.q_timer = 0.0
	actor.e_timer = 1.0
	var enter := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, enter, ambush_range)
	actor.set_input_frame(enter)
	actor.kit.tick(actor, 0.016)
	var rooted_by_kit: bool = actor.state == CreatureStateScript.State.BURROWED \
		and actor.get_modifier_value("move_speed_mult", 1.0) <= 0.0
	var travel_destination: Vector2 = actor.global_position + Vector2.RIGHT * 400.0
	var exit: Resource = arena.bot_brain._finalize_frame(actor, InputFrameScript.new())
	actor.set_input_frame(exit)
	actor.kit.tick(actor, 0.016)
	var restored_by_kit: bool = actor.state == CreatureStateScript.State.NORMAL \
		and actor.get_modifier_value("move_speed_mult", 1.0) >= 0.99
	var before_travel: Vector2 = actor.global_position
	var resumed: Resource = arena.bot_brain._travel_frame(actor, travel_destination, 10.0, travel_destination)
	actor.set_input_frame(resumed)
	actor._move_from_input(0.1)
	var resumed_movement: bool = actor.global_position.distance_to(before_travel) > 0.0
	if not burrows \
		or not eggs \
		or not travels_when_distant \
		or not charges \
		or not surfaces_when_distant \
		or not rooted_by_kit \
		or not restored_by_kit \
		or not resumed_movement:
		failures.append("wolf spider bot should travel at long range, burrow in its ambush band, charge nearby, and surface through the real travel path if the target escapes; burrows=%s eggs=%s travels=%s charges=%s surfaces=%s rooted=%s restored=%s resumed=%s speed=%.2f buttons=%d/%d/%d/%d/%d/%d" % [
			str(burrows),
			str(eggs),
			str(travels_when_distant),
			str(charges),
			str(surfaces_when_distant),
			str(rooted_by_kit),
			str(restored_by_kit),
			str(resumed_movement),
			actor.get_modifier_value("move_speed_mult", 1.0),
			far.buttons,
			distant.buttons,
			ambush.buttons,
			surface.buttons,
			enter.buttons,
			exit.buttons
		])
