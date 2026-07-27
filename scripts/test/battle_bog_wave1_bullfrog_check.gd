extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["bullfrog", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave1 bullfrog check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "bullfrog":
		push_error("expected bullfrog active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_camouflage_and_leap(arena, failures)
	_check_lunge(arena, failures)
	_check_swallow(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave1_bullfrog failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_camouflage_and_leap(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 200.0
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 3.1)
	if not actor.is_stealthed():
		failures.append("bullfrog should camouflage after 3s idle")

	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var leaping_far: bool = actor.dash_timer > 0.0 and actor.dash_velocity.length() > 500.0 and actor.pass_obstacles_timer > 0.0 and not actor.is_stealthed()
	if not leaping_far:
		failures.append("camouflage leap expected long obstacle-hop dash; dash_timer=%.2f vel=%.2f pass=%.2f stealth=%s" % [
			actor.dash_timer,
			actor.dash_velocity.length(),
			actor.pass_obstacles_timer,
			str(actor.is_stealthed())
		])
	actor.dash_timer = 0.0
	actor.pass_obstacles_timer = 0.0
	actor.q_timer = 0.0

func _check_lunge(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(28.0, 0.0)
	target.health = target.max_health
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 120.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	actor.dash_timer = 0.0
	actor.set_input_frame(InputFrameScript.new())
	actor.kit.tick(actor, 0.016)
	var knocked: bool = target.dash_timer > 0.0 and target.dash_velocity.x > 0.0
	var charged: bool = actor.e_charges == 2
	if not knocked or not charged:
		failures.append("lunge expected hit knockback and spent charge; knocked=%s charge=%d target_dash=%.2f vel=%s" % [
			str(knocked),
			actor.e_charges,
			target.dash_timer,
			str(target.dash_velocity)
		])
	target.dash_timer = 0.0
	target.dash_velocity = Vector2.ZERO

func _check_swallow(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[1]
	actor.release_latch("test_reset")
	target.release_latch("test_reset")
	actor.modifiers.clear()
	actor.break_stealth()
	actor.kit.lunge_active = false
	actor.kit.lunge_hit_done = false
	actor.kit.lunge_button_was_pressed = false
	for bot in arena.bots:
		if bot == target:
			continue
		bot.release_latch("test_reset")
		bot.health = bot.max_health
		bot.global_position = Vector2(600.0, 600.0)
		bot.velocity = Vector2.ZERO
		bot.dash_velocity = Vector2.ZERO
		bot.dash_timer = 0.0
	target.apply_creature("mink")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(18.0, 0.0)
	actor.velocity = Vector2.ZERO
	actor.dash_velocity = Vector2.ZERO
	actor.dash_timer = 0.0
	target.velocity = Vector2.ZERO
	target.dash_velocity = Vector2.ZERO
	target.dash_timer = 0.0
	target.break_stealth()
	target.health = target.max_health * 0.08
	actor.health = actor.max_health * 0.5
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var executed: bool = not target.is_alive()
	var healed: bool = actor.health > actor.max_health * 0.55
	if not executed or not healed:
		failures.append("swallow expected execute lower-HP target and heal; executed=%s actor_health=%.2f target_alive=%s target_health=%.2f" % [
			str(executed),
			actor.health,
			str(target.is_alive()),
			target.health
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("bullfrog")
	actor.q_timer = 0.0
	actor.e_charges = 3
	var target: Node = arena.player
	target.global_position = actor.global_position + Vector2.RIGHT * 220.0
	arena.reveal_entity_to_team(target, actor.team, 1.0)
	arena.bot_brain.reset_actor(actor)
	var frame: Resource = arena.bot_brain.build_frame(actor)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q):
		failures.append("bullfrog bot should leap toward distant targets")
