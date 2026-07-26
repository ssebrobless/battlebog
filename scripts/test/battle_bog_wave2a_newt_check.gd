extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["newt", "water_shrew", "crayfish"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("wave2a newt check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null or String(arena.player.creature_id) != "newt":
		push_error("expected newt active player, got arena=%s player=%s" % [str(arena), str(arena.player if arena != null else null)])
		quit(1)
		return

	_check_unken_reflex(arena, failures)
	_check_toxic_secretion(arena, failures)
	_check_rib_exudation(arena, failures)
	_check_slick_crawl_render(arena, failures)
	_check_caudal_autotomy(arena, failures)
	_check_bot_hook(arena, failures)

	print("wave2a_newt failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_unken_reflex(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[0]
	attacker.apply_creature("mink")
	attacker.break_stealth()
	actor.global_position = Vector2.ZERO
	attacker.global_position = Vector2(22.0, 0.0)
	attacker.health = attacker.max_health
	attacker.modifiers.clear()
	attacker.damage_ticks.clear()
	actor.health = actor.max_health
	actor.q_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	frame.set_button(InputFrameScript.BUTTON_ABILITY_Q, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var pushed: bool = attacker.dash_timer > 0.0 and attacker.dash_velocity.x > 0.0
	var invulnerable: bool = actor.get_modifier_value("invulnerable", 1.0) > 1.5 and actor.get_modifier_value("move_speed_mult", 1.0) == 0.0
	actor.take_damage_event(_event(100.0, DamageEventScript.DELIVERY_MELEE, attacker, "Test Bite"))
	var no_damage: bool = actor.health == actor.max_health
	if not pushed or not invulnerable or not no_damage:
		failures.append("Unken expected invulnerable stop and push; pushed=%s invuln=%s no_damage=%s health=%.2f dash=%.2f vel=%s" % [
			str(pushed),
			str(invulnerable),
			str(no_damage),
			actor.health,
			attacker.dash_timer,
			str(attacker.dash_velocity)
		])
	attacker.dash_timer = 0.0
	attacker.dash_velocity = Vector2.ZERO
	actor.modifiers.clear()

func _check_toxic_secretion(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[0]
	attacker.apply_creature("mink")
	actor.health = actor.max_health
	actor.e_timer = 0.0
	attacker.damage_ticks.clear()
	var frame := InputFrameScript.new()
	frame.set_button(InputFrameScript.BUTTON_ABILITY_E, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	actor.take_damage_event(_event(20.0, DamageEventScript.DELIVERY_MELEE, attacker, "Claw"))
	var melee_reflected: bool = _dot_count(attacker, "Toxic Secretion") == 1
	actor.take_damage_event(_event(20.0, DamageEventScript.DELIVERY_RANGED, attacker, "Shot"))
	var ranged_ignored: bool = _dot_count(attacker, "Toxic Secretion") == 1
	if not melee_reflected or not ranged_ignored:
		failures.append("Toxic Secretion should reflect melee only; dots=%d melee=%s ranged=%s" % [
			_dot_count(attacker, "Toxic Secretion"),
			str(melee_reflected),
			str(ranged_ignored)
		])

func _check_rib_exudation(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var attacker: Node = arena.bots[0]
	attacker.apply_creature("mink")
	actor.modifiers.clear()
	attacker.damage_ticks.clear()
	actor.health = actor.max_health * 0.12
	attacker.health = attacker.max_health
	actor.kit.rib_timer = 0.0
	actor.take_damage_event(_event(actor.max_health * 0.04, DamageEventScript.DELIVERY_MELEE, attacker, "Threshold Bite"))
	var burst: bool = attacker.health <= attacker.max_health - 49.0
	var dot: bool = _dot_count(attacker, "Rib Exudation") == 1
	var cooldown: bool = actor.kit.rib_timer > 9.0
	if not burst or not dot or not cooldown:
		failures.append("Rib Exudation should burst+DOT attacker on 10%% threshold; burst=%s dot=%s cooldown=%s attacker_health=%.2f rib_timer=%.2f" % [
			str(burst),
			str(dot),
			str(cooldown),
			attacker.health,
			actor.kit.rib_timer
		])

func _check_slick_crawl_render(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.modifiers.clear()
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var render_state: Dictionary = actor.get_render_motion_state()
	var crawl_read: bool = bool(render_state.get("slick_crawl_pose", false)) \
		and float(render_state.get("slick_crawl_intensity", 0.0)) > 0.25 \
		and not bool(render_state.get("leech_inchworm_pose", false)) \
		and not bool(render_state.get("water_snake_land_slither_pose", false)) \
		and not bool(render_state.get("crayfish_scuttle_pose", false))
	actor.velocity = Vector2.ZERO
	var idle_state: Dictionary = actor.get_render_motion_state()
	var idle_clear: bool = not bool(idle_state.get("slick_crawl_pose", false)) \
		and not bool(idle_state.get("leech_inchworm_pose", false)) \
		and not bool(idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(idle_state.get("crayfish_scuttle_pose", false)) \
		and float(idle_state.get("slick_crawl_intensity", 1.0)) <= 0.001
	if not crawl_read or not idle_clear:
		failures.append("Newt movement should expose a low slick-crawl render pose without leech/snake/crayfish overlap only while moving; crawl=%s idle=%s state=%s/%s" % [
			str(crawl_read),
			str(idle_clear),
			str(render_state),
			str(idle_state)
		])

func _check_caudal_autotomy(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	target.apply_creature("mink")
	actor.modifiers.clear()
	actor.kit.autotomy_timer = 0.0
	actor.kit.tail_lost_timer = 0.0
	actor.health = 5.0
	actor.take_damage_event(_event(500.0, DamageEventScript.DELIVERY_MELEE, target, "Fatal Bite"))
	var survived: bool = actor.is_alive() and actor.health >= actor.max_health * 0.10 and actor.kit.tail_lost_timer > 9.0 and actor.get_modifier_value("move_speed_mult", 1.0) > 1.1
	var tail_state: Dictionary = actor.get_render_motion_state()
	var tail_read: bool = bool(tail_state.get("tail_lost_pose", false))
	target.health = target.max_health
	actor.primary_timer = 0.0
	var frame := InputFrameScript.new()
	frame.aim = actor.global_position + (target.global_position - actor.global_position)
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(frame)
	actor.kit.tick(actor, 0.016)
	var attack_disabled: bool = target.health == target.max_health
	if not survived or not tail_read or not attack_disabled:
		failures.append("Caudal Autotomy should prevent death, speed up, expose tail-loss pose, and disable attacks; survived=%s tail_read=%s disabled=%s health=%.2f tail=%.2f speed=%.2f target=%.2f state=%s" % [
			str(survived),
			str(tail_read),
			str(attack_disabled),
			actor.health,
			actor.kit.tail_lost_timer,
			actor.get_modifier_value("move_speed_mult", 1.0),
			target.health,
			str(tail_state)
		])

func _check_bot_hook(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	actor.apply_creature("newt")
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	var frame := InputFrameScript.new()
	arena.bot_brain._hook(actor).apply(actor, arena.player, frame, actor.body_radius * 4.0)
	if not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) or not frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E):
		failures.append("newt bot should press Q/E at close range; buttons=%d" % frame.buttons)

func _event(amount: float, delivery: int, source_actor: Node, source_ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(amount, delivery, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
	return event

func _dot_count(target: Node, source_ability: String) -> int:
	var count := 0
	for tick: Dictionary in target.damage_ticks:
		if String(tick.get("source_ability", "")) == source_ability:
			count += 1
	return count
