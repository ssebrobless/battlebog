extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["alligator", "water_snake", "kingfisher"])
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("alligator timeline check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame

	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null:
		push_error("alligator timeline check expected a playable Arena")
		quit(1)
		return
	_check_presentation_startup_truth(arena, failures)
	_check_presentation_contact_and_completion(arena, failures)
	_check_timeline_owned_legacy_timer_suppression(arena, failures)
	_check_malformed_timeline_swing_fails_closed(arena, failures)
	_check_hit_lock_once_and_release(arena, failures)
	_check_release_before_active(arena, failures)
	_check_whiff_and_interrupt_recovery(arena, failures)
	_check_ambush_acceptance(arena, failures)
	_check_ambush_blocked_while_primary_committed(arena, failures)
	_check_coarse_contact_preserves_latch_duration(arena, failures)
	_check_death_roll_and_bot_finalization(arena, failures)
	_check_reactive_attacker_death_does_not_latch(arena, failures)
	print("alligator_timeline failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_presentation_startup_truth(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	arena.telegraphs.clear()
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(500.0, 0.0)
	var request := _frame(
		actor.global_position + Vector2.RIGHT * 1000.0,
		InputFrameScript.BUTTON_PRIMARY
	)
	_tick_actor(arena, actor, request, 0.016)
	var accepted: Dictionary = actor.get_primary_attack_snapshot()
	var sequence_id := int(accepted["attack_sequence_id"])
	var projected_value: Variant = accepted["projected_shape"]
	var projected: Dictionary = (
		projected_value if typeof(projected_value) == TYPE_DICTIONARY else {}
	)
	var initial_origin: Vector2 = projected.get("origin", Vector2.INF)
	var exact_initial: bool = not projected.is_empty() \
		and initial_origin.is_equal_approx(actor.global_position) \
		and (projected.get("aim", Vector2.ZERO) as Vector2).dot(Vector2.RIGHT) > 0.99 \
		and is_equal_approx(
			float(projected.get("radius", 0.0)),
			float(projected.get("reach_px", 0.0)) + actor.body_radius
		) \
		and accepted["contact_point"] == null \
		and int(accepted["presentation_sequence_id"]) == sequence_id

	var stationary_revision := int(accepted["presentation_revision"])
	var stationary_signature: String = actor.get_render_signature()
	actor.kit.refresh_primary_attack_presentation(actor)
	actor.kit.refresh_primary_attack_presentation(actor)
	var stationary_snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var stationary_refresh_idempotent: bool = (
		int(stationary_snapshot["presentation_revision"]) == stationary_revision
		and actor.get_render_signature() == stationary_signature
	)

	projected["origin"] = Vector2(999.0, 999.0)
	var fresh: Dictionary = actor.get_primary_attack_snapshot()
	var fresh_shape: Dictionary = fresh["projected_shape"]
	var defensive_copy: bool = (
		(fresh_shape.get("origin", Vector2.INF) as Vector2)
		.is_equal_approx(initial_origin)
		and not actor.update_primary_attack_presentation(
			sequence_id + 1,
			{"contact_point": Vector2.ZERO}
		)
		and not actor.update_primary_attack_presentation(
			sequence_id,
			{"projected_shape": {"unsafe_actor": actor}}
		)
	)

	var signature_before: String = actor.get_render_signature()
	var follow := _frame(
		actor.global_position + Vector2.LEFT * 1000.0,
		InputFrameScript.BUTTON_PRIMARY
	)
	follow.move = Vector2.DOWN
	_tick_actor(arena, actor, follow, 0.05)
	var followed: Dictionary = actor.get_primary_attack_snapshot()
	var followed_shape: Dictionary = followed["projected_shape"]
	var origin_followed: bool = String(followed["attack_phase_name"]) == "startup" \
		and (followed_shape["origin"] as Vector2).is_equal_approx(actor.global_position) \
		and not (followed_shape["origin"] as Vector2).is_equal_approx(initial_origin) \
		and (followed_shape["aim"] as Vector2).dot(Vector2.RIGHT) > 0.99 \
		and (followed["strike_heading"] as Vector2).dot(Vector2.RIGHT) > 0.99
	var signature_changed: bool = signature_before != actor.get_render_signature()

	var windup := _find_telegraph(
		arena,
		"windup",
		actor,
		sequence_id
	)
	var telegraph_locked: bool = not windup.is_empty() \
		and bool(windup.get("timeline_owned", false)) \
		and (windup.get("locked_aim", Vector2.ZERO) as Vector2).dot(
			Vector2.RIGHT
		) > 0.99 \
		and is_equal_approx(
			float(windup.get("radius", 0.0)),
			float(followed_shape.get("radius", -1.0))
		) \
		and is_equal_approx(
			float(windup.get("facing_dot_min", -2.0)),
			float(followed_shape.get("facing_dot_min", -1.0))
		) \
		and not arena._telegraph_lost_anchor(windup)
	actor.interrupt_primary_attack("presentation_test", false)
	var interrupted_stale: bool = arena._telegraph_lost_anchor(windup)
	var rejected_before_tick: bool = not arena._telegraph_should_draw(windup) \
		and not _find_telegraph(
			arena,
			"windup",
			actor,
			sequence_id
		).is_empty()
	arena._tick_telegraphs(0.0)
	var removed_after_interrupt := _find_telegraph(
		arena,
		"windup",
		actor,
		sequence_id
	).is_empty()
	if not (
		exact_initial
		and stationary_refresh_idempotent
		and defensive_copy
		and origin_followed
		and signature_changed
		and telegraph_locked
		and interrupted_stale
		and rejected_before_tick
		and removed_after_interrupt
	):
		failures.append(
			(
				"startup presentation truth failed; initial=%s stationary=%s "
				+ "defensive=%s follow=%s signature=%s telegraph=%s stale=%s "
				+ "draw_rejected=%s removed=%s "
				+ "accepted=%s followed=%s"
			)
			% [
				str(exact_initial),
				str(stationary_refresh_idempotent),
				str(defensive_copy),
				str(origin_followed),
				str(signature_changed),
				str(telegraph_locked),
				str(interrupted_stale),
				str(rejected_before_tick),
				str(removed_after_interrupt),
				str(accepted),
				str(followed),
			]
		)


func _check_presentation_contact_and_completion(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	arena.telegraphs.clear()
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	var held := _frame(
		actor.global_position + Vector2.RIGHT * 1000.0,
		InputFrameScript.BUTTON_PRIMARY
	)
	_tick_actor(arena, actor, held, 0.016)
	var startup: Dictionary = actor.get_primary_attack_snapshot()
	var sequence_id := int(startup["attack_sequence_id"])
	var startup_shape: Dictionary = startup["projected_shape"]
	var expected_contacts := MeleeHit.query(actor, startup_shape)
	var expected_point: Variant = (
		expected_contacts[0].get("point")
		if not expected_contacts.is_empty()
		else null
	)
	var startup_signature: String = actor.get_render_signature()
	var turned := _frame(
		actor.global_position + Vector2.LEFT * 1000.0,
		InputFrameScript.BUTTON_PRIMARY
	)
	_tick_actor(arena, actor, turned, 0.301)
	var active: Dictionary = actor.get_primary_attack_snapshot()
	var active_shape: Dictionary = active["projected_shape"]
	var active_signature: String = actor.get_render_signature()
	var contact_after: Variant = active["contact_point"]
	var contact_truth: bool = startup["contact_point"] == null \
		and expected_point is Vector2 \
		and contact_after is Vector2 \
		and (contact_after as Vector2).is_equal_approx(expected_point as Vector2) \
		and String(active["attack_phase_name"]) == "active" \
		and (active_shape["origin"] as Vector2).is_equal_approx(
			actor.global_position
		) \
		and (active_shape["aim"] as Vector2).dot(Vector2.RIGHT) > 0.99 \
		and startup_signature != active_signature

	var swing := _find_telegraph(arena, "swing", actor, sequence_id)
	var swing_exact: bool = not swing.is_empty() \
		and bool(swing.get("timeline_owned", false)) \
		and (swing.get("locked_aim", Vector2.ZERO) as Vector2).dot(
			Vector2.RIGHT
		) > 0.99 \
		and is_equal_approx(
			float(swing.get("radius", 0.0)),
			float(active_shape.get("radius", -1.0))
		) \
		and is_equal_approx(
			float(swing.get("facing_dot_min", -2.0)),
			float(active_shape.get("facing_dot_min", -1.0))
		)
	_tick_actor(arena, actor, turned, 0.10)
	var recovery_signature: String = actor.get_render_signature()
	var recovery_phase := String(
		actor.get_primary_attack_snapshot()["attack_phase_name"]
	) == "recovery"
	_tick_actor(arena, actor, turned, 0.40)
	var completed: Dictionary = actor.get_primary_attack_snapshot()
	var completion_cleared: bool = String(completed["attack_phase_name"]) == "idle" \
		and int(completed["attack_sequence_id"]) == 0 \
		and String(completed["attack_variant"]) == "" \
		and String(completed["attack_outcome_name"]) == "none" \
		and (completed["payload"] as Dictionary).is_empty() \
		and int(completed["hit_count"]) == 0 \
		and String(completed["hit_region"]) == "" \
		and String(completed["interruption_reason"]) == "" \
		and int(completed["presentation_sequence_id"]) == 0 \
		and completed["projected_shape"] == null \
		and completed["contact_point"] == null
	if not (
		contact_truth
		and swing_exact
		and recovery_phase
		and active_signature != recovery_signature
		and completion_cleared
	):
		failures.append(
			(
				"active presentation truth failed; contact=%s swing=%s "
				+ "recovery=%s signature=%s cleared=%s startup=%s active=%s "
				+ "completed=%s"
			)
			% [
				str(contact_truth),
				str(swing_exact),
				str(recovery_phase),
				str(active_signature != recovery_signature),
				str(completion_cleared),
				str(startup),
				str(active),
				str(completed),
			]
		)


func _check_timeline_owned_legacy_timer_suppression(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	arena.telegraphs.clear()
	actor.anim_windup_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.emit_vfx_event("windup_started", {
		"actor": actor,
		"duration": 0.2,
		"timeline_owned": true,
	})
	var timeline_windup_suppressed := is_zero_approx(actor.anim_windup_timer)
	actor.begin_stealth(1.0, "presentation_test")
	actor.emit_vfx_event("attack_swung", {
		"actor": actor,
		"timeline_owned": true,
	})
	var timeline_swing_suppressed: bool = is_zero_approx(actor.anim_attack_timer) \
		and not actor.is_stealthed()
	actor.emit_vfx_event("windup_started", {
		"actor": actor,
		"duration": 0.2,
	})
	var legacy_windup_preserved: bool = actor.anim_windup_timer > 0.19
	actor.emit_vfx_event("attack_swung", {
		"actor": actor,
		"aim": Vector2.RIGHT,
		"reach_px": 30.0,
	})
	var legacy_swing_preserved: bool = actor.anim_attack_timer > 0.0 \
		and is_zero_approx(actor.anim_windup_timer)
	if not (
		timeline_windup_suppressed
		and timeline_swing_suppressed
		and legacy_windup_preserved
		and legacy_swing_preserved
	):
		failures.append(
			(
				"timeline-owned legacy timer suppression failed; windup=%s "
				+ "swing=%s legacy_windup=%s legacy_swing=%s "
				+ "timers=%.3f/%.3f"
			)
			% [
				str(timeline_windup_suppressed),
				str(timeline_swing_suppressed),
				str(legacy_windup_preserved),
				str(legacy_swing_preserved),
				actor.anim_windup_timer,
				actor.anim_attack_timer,
			]
		)


func _check_malformed_timeline_swing_fails_closed(
	arena: Node,
	failures: Array[String]
) -> void:
	var valid: Dictionary = arena._timeline_swing_shape({
		"origin": Vector2(10.0, 20.0),
		"locked_aim": Vector2.RIGHT,
		"radius": 30.0,
		"facing_dot_min": 0.15,
	})
	var malformed: Array[Dictionary] = [
		{
			"origin": Vector2.INF,
			"locked_aim": Vector2.RIGHT,
			"radius": 30.0,
			"facing_dot_min": 0.15,
		},
		{
			"origin": Vector2.ZERO,
			"locked_aim": Vector2.ZERO,
			"radius": 30.0,
			"facing_dot_min": 0.15,
		},
		{
			"origin": Vector2.ZERO,
			"locked_aim": Vector2.RIGHT,
			"radius": INF,
			"facing_dot_min": 0.15,
		},
		{
			"origin": Vector2.ZERO,
			"locked_aim": Vector2.RIGHT,
			"radius": -1.0,
			"facing_dot_min": 0.15,
		},
		{
			"origin": Vector2.ZERO,
			"locked_aim": Vector2.RIGHT,
			"radius": 30.0,
			"facing_dot_min": 1.01,
		},
	]
	var malformed_rejected := true
	for telegraph: Dictionary in malformed:
		if not arena._timeline_swing_shape(telegraph).is_empty():
			malformed_rejected = false
			break
	var valid_preserved: bool = not valid.is_empty() \
		and (valid["origin"] as Vector2).is_equal_approx(Vector2(10.0, 20.0)) \
		and (valid["aim"] as Vector2).is_equal_approx(Vector2.RIGHT) \
		and is_equal_approx(float(valid["radius"]), 30.0) \
		and is_equal_approx(float(valid["facing_dot_min"]), 0.15)
	if not valid_preserved or not malformed_rejected:
		failures.append(
			"timeline swing validation must preserve valid geometry and reject "
			+ "malformed numeric inputs; valid=%s rejected=%s"
			% [str(valid), str(malformed_rejected)]
		)


func _check_hit_lock_once_and_release(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	var held_right := _frame(Vector2(100.0, 0.0), InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, held_right, 0.016)
	var accepted: Dictionary = actor.get_primary_attack_snapshot()
	var health_before: float = target.health
	var held_left := _frame(Vector2(-100.0, 0.0), InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, held_left, 0.299)
	var no_early_damage := is_equal_approx(target.health, health_before)
	_tick_actor(arena, actor, held_left, 0.002)
	var health_after_active: float = target.health
	var active: Dictionary = actor.get_primary_attack_snapshot()
	var locked_hit: bool = health_after_active < health_before \
		and actor.latch_victim == target \
		and (active["strike_heading"] as Vector2).dot(Vector2.RIGHT) > 0.99

	var suppressed := _frame(Vector2.LEFT, 0)
	suppressed.suppress_buttons(InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, suppressed, 0.04)
	var suppression_preserved: bool = actor.latch_victim == target
	_tick_actor(arena, actor, held_left, 0.06)
	var exactly_once := is_equal_approx(target.health, health_after_active)
	var hit_recovery: Dictionary = actor.get_primary_attack_snapshot()
	_tick_actor(arena, actor, held_left, 0.398)
	var hit_still_recovering := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "recovery"
	_tick_actor(arena, actor, held_left, 0.002)
	var hit_recovery_done := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "idle"

	var released := _frame(Vector2.LEFT, 0)
	_tick_actor(arena, actor, released, 0.01)
	var genuine_release := actor.latch_victim == null and target.latched_attacker == null
	if not (
		String(accepted["attack_phase_name"]) == "startup"
		and no_early_damage
		and locked_hit
		and suppression_preserved
		and exactly_once
		and String(hit_recovery["attack_outcome_name"]) == "hit"
		and hit_still_recovering
		and hit_recovery_done
		and genuine_release
	):
		failures.append(
			"bite hit contract failed; accepted=%s early=%s locked_hit=%s suppressed=%s once=%s recovery=%s still=%s done=%s release=%s health=%.2f/%.2f"
			% [
				str(accepted),
				str(no_early_damage),
				str(locked_hit),
				str(suppression_preserved),
				str(exactly_once),
				str(hit_recovery),
				str(hit_still_recovering),
				str(hit_recovery_done),
				str(genuine_release),
				health_before,
				target.health,
			]
		)


func _check_release_before_active(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY), 0.016)
	var before: float = target.health
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, 0), 0.301)
	var damaged_without_latch: bool = target.health < before \
		and actor.latch_victim == null \
		and target.latched_attacker == null
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, 0), 0.50)

	_reset_pair(actor, target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY), 0.016)
	var suppressed_contact := _frame(Vector2.RIGHT, 0)
	suppressed_contact.suppress_buttons(InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, suppressed_contact, 0.301)
	var suppression_latched: bool = actor.latch_victim == target and target.latched_attacker == actor
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, 0), 0.01)
	var release_after_suppression: bool = actor.latch_victim == null and target.latched_attacker == null
	if not damaged_without_latch or not suppression_latched or not release_after_suppression:
		failures.append(
			"active hold contract failed; release should damage/no-latch and suppressed contact should latch until a genuine up-frame; released=%s suppressed=%s final_release=%s health=%.2f/%.2f"
			% [
				str(damaged_without_latch),
				str(suppression_latched),
				str(release_after_suppression),
				before,
				target.health,
			]
		)


func _check_whiff_and_interrupt_recovery(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(500.0, 0.0)
	var held := _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, held, 0.016)
	_tick_actor(arena, actor, held, 0.301)
	_tick_actor(arena, actor, held, 0.10)
	var whiff_state: Dictionary = actor.get_primary_attack_snapshot()
	var whiff_pose := bool(actor.get_render_motion_state().get("off_balance_pose", false))
	_tick_actor(arena, actor, held, 0.798)
	var whiff_still_recovering := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "recovery"
	_tick_actor(arena, actor, held, 0.002)
	var whiff_done := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "idle"
	var cadence_independent: bool = actor.primary_timer > 0.45

	_reset_pair(actor, target)
	target.global_position = Vector2(34.0, 0.0)
	_tick_actor(arena, actor, held, 0.016)
	var before: float = target.health
	actor.add_modifier("Timeline Test Stun", {"can_act_mult": 0.0}, 0.60)
	var interrupted: Dictionary = actor.get_primary_attack_snapshot()
	_tick_actor(arena, actor, held, 0.499)
	var interrupt_still_recovering := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "recovery"
	_tick_actor(arena, actor, held, 0.002)
	var interrupt_done := String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "idle"
	var no_interrupted_damage := is_equal_approx(target.health, before)
	if not (
		String(whiff_state["attack_outcome_name"]) == "whiff"
		and whiff_pose
		and whiff_still_recovering
		and whiff_done
		and cadence_independent
		and String(interrupted["attack_outcome_name"]) == "interrupted"
		and interrupt_still_recovering
		and interrupt_done
		and no_interrupted_damage
	):
		failures.append(
			"whiff/interrupted recovery contract failed; whiff=%s pose=%s still=%s done=%s cadence=%.3f interrupted=%s still=%s done=%s no_damage=%s"
			% [
				str(whiff_state),
				str(whiff_pose),
				str(whiff_still_recovering),
				str(whiff_done),
				actor.primary_timer,
				str(interrupted),
				str(interrupt_still_recovering),
				str(interrupt_done),
				str(no_interrupted_damage),
			]
		)
	actor.remove_modifiers_from_source("Timeline Test Stun")


func _check_ambush_acceptance(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	target.global_position = actor.global_position + Vector2(500.0, 0.0)
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, InputFrameScript.BUTTON_ABILITY_E), 0.016)
	var entered: bool = actor.kit.ambush_active and actor.is_stealthed()
	var primary_and_e := _frame(
		Vector2.RIGHT,
		InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_E
	)
	_tick_actor(arena, actor, primary_and_e, 0.016)
	var snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var broke_on_acceptance: bool = entered \
		and not actor.kit.ambush_active \
		and not actor.is_stealthed() \
		and actor.e_timer > 8.5 \
		and String(snapshot["attack_phase_name"]) == "startup"
	if not broke_on_acceptance:
		failures.append(
			"accepted bite should end Ambush once and return before PRIMARY+E can re-enter; entered=%s ambush=%s stealth=%s e=%.3f snapshot=%s"
			% [
				str(entered),
				str(actor.kit.ambush_active),
				str(actor.is_stealthed()),
				actor.e_timer,
				str(snapshot),
			]
		)


func _check_ambush_blocked_while_primary_committed(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	target.global_position = actor.global_position + Vector2(500.0, 0.0)
	var primary := _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY)
	var ambush := _frame(Vector2.RIGHT, InputFrameScript.BUTTON_ABILITY_E)
	_tick_actor(arena, actor, primary, 0.016)
	_tick_actor(arena, actor, ambush, 0.301)
	var active_blocked: bool = actor.is_primary_attack_committed() \
		and not actor.kit.ambush_active \
		and is_zero_approx(actor.e_timer)
	_tick_actor(arena, actor, ambush, 0.099)
	var recovery_started: bool = (
		String(actor.get_primary_attack_snapshot()["attack_phase_name"]) == "recovery"
		and not actor.kit.ambush_active
		and is_zero_approx(actor.e_timer)
	)
	_tick_actor(arena, actor, ambush, 0.799)
	var recovery_blocked: bool = actor.is_primary_attack_committed() \
		and not actor.kit.ambush_active \
		and is_zero_approx(actor.e_timer)
	_tick_actor(arena, actor, ambush, 0.002)
	var allowed_after_recovery: bool = not actor.is_primary_attack_committed() \
		and actor.kit.ambush_active \
		and actor.is_stealthed()
	if not active_blocked or not recovery_started or not recovery_blocked \
		or not allowed_after_recovery:
		failures.append(
			"Ambush must stay blocked through active/whiff recovery and become available after "
			+ "the primary commitment ends; active=%s recovery_start=%s recovery=%s after=%s "
			+ "snapshot=%s e=%.3f"
			% [
				str(active_blocked),
				str(recovery_started),
				str(recovery_blocked),
				str(allowed_after_recovery),
				str(actor.get_primary_attack_snapshot()),
				actor.e_timer,
			]
		)


func _check_coarse_contact_preserves_latch_duration(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	var held := _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, held, 0.016)
	_tick_actor(arena, actor, held, 0.301)
	var full_duration: bool = actor.latch_victim == target \
		and target.latched_attacker == actor \
		and is_equal_approx(actor.latch_timer, 3.0) \
		and is_equal_approx(target.latch_timer, 3.0)
	if not full_duration:
		failures.append(
			"coarse contact tick must create a full-duration latch after latch ticking; "
			+ "linked=%s/%s timers=%.3f/%.3f"
			% [
				str(actor.latch_victim == target),
				str(target.latched_attacker == actor),
				actor.latch_timer,
				target.latch_timer,
			]
		)
	actor.release_latch("test_reset")


func _check_death_roll_and_bot_finalization(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.bots[0]
	var victim: Node = arena.player
	actor.apply_creature("alligator")
	victim.apply_creature("cane_toad")
	var water := _zone_point(arena, TerrainMapScript.WATER)
	actor.global_position = water
	victim.global_position = water + Vector2.RIGHT * 18.0
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	var held := _frame(
		Vector2.RIGHT,
		InputFrameScript.BUTTON_PRIMARY | InputFrameScript.BUTTON_ABILITY_Q
	)
	_tick_actor(arena, actor, held, 0.016)
	_tick_actor(arena, actor, held, 0.301)
	var rolled_from_contact: bool = actor.latch_source == "Death Roll" \
		and actor.kit.death_roll_timer > 4.9 \
		and actor.q_timer > 4.9
	_tick_actor(arena, actor, _frame(Vector2.RIGHT, 0), 0.05)
	var release_independent: bool = actor.latch_victim == victim and actor.latch_source == "Death Roll"
	actor.release_latch("test_reset")
	actor.kit.death_roll_timer = 0.0

	actor.attach_to_victim(victim, 2.0, "Bite")
	victim.receive_latch(actor, 2.0, "Bite")
	actor.q_timer = 0.0
	var finalized_all := true
	for _mode in ["retreat", "forage", "deposit", "travel", "target_reset"]:
		var finalized: Resource = arena.bot_brain._finalize_frame(actor, InputFrameScript.new())
		finalized_all = finalized_all \
			and finalized.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
			and finalized.is_pressed(InputFrameScript.BUTTON_ABILITY_Q)
	actor.release_latch("test_reset")
	if not rolled_from_contact or not release_independent or not finalized_all:
		failures.append(
			"Death Roll/contact and PvAI finalization contract failed; rolled=%s independent=%s finalized=%s source=%s timer=%.3f"
			% [
				str(rolled_from_contact),
				str(release_independent),
				str(finalized_all),
				actor.latch_source,
				actor.kit.death_roll_timer,
			]
		)


func _check_reactive_attacker_death_does_not_latch(
	arena: Node,
	failures: Array[String]
) -> void:
	var actor: Node = arena.player
	var target: Node = arena.bots[0]
	_reset_pair(actor, target)
	target.apply_creature("newt")
	actor.global_position = Vector2.ZERO
	target.global_position = Vector2(34.0, 0.0)
	actor.stats["primary_damage"] = 5.0
	actor.health = 40.0
	target.health = target.max_health * 0.10 + 1.0
	var held := _frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY)
	_tick_actor(arena, actor, held, 0.016)
	_tick_actor(arena, actor, held, 0.301)
	var contract_ok: bool = not actor.is_alive() \
		and target.health < target.max_health * 0.10 \
		and actor.latch_victim == null \
		and target.latched_attacker == null
	if not contract_ok:
		failures.append(
			"synchronous reactive attacker death after melee resolution must prevent latch; "
			+ "actor_alive=%s actor_health=%.2f target_health=%.2f linked=%s/%s"
			% [
				str(actor.is_alive()),
				actor.health,
				target.health,
				str(actor.latch_victim),
				str(target.latched_attacker),
			]
		)


func _reset_pair(actor: Node, target: Node) -> void:
	if actor.latch_victim != null:
		actor.release_latch("test_reset")
	actor.apply_creature("alligator")
	target.apply_creature("cane_toad")
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	actor.velocity = Vector2.ZERO
	actor.steering_velocity = Vector2.ZERO
	actor.residual_velocity = Vector2.ZERO
	actor.input_frame = null
	actor.last_aim_direction = Vector2.RIGHT
	actor.body_heading = Vector2.RIGHT
	target.health = target.max_health


func _frame(aim_direction: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = aim_direction
	frame.buttons = buttons
	return frame


func _tick_actor(arena: Node, actor: Node, frame: Resource, delta: float) -> void:
	arena.simulation_tick += 1
	actor.set_input_frame(frame)
	actor.tick_sim(delta)


func _find_telegraph(
	arena: Node,
	type_name: String,
	actor: Node,
	attack_sequence_id: int
) -> Dictionary:
	for telegraph_value: Variant in arena.telegraphs:
		if typeof(telegraph_value) != TYPE_DICTIONARY:
			continue
		var telegraph: Dictionary = telegraph_value
		if String(telegraph.get("type", "")) == type_name \
			and telegraph.get("actor", null) == actor \
			and int(telegraph.get("attack_sequence_id", 0)) \
			== attack_sequence_id:
			return telegraph
	return {}


func _zone_point(arena: Node, zone: String) -> Vector2:
	var rects: Array = arena.terrain_map.get_rects(zone)
	for rect: Rect2 in rects:
		for x_step in 5:
			for y_step in 5:
				var point := Vector2(
					lerpf(rect.position.x + 16.0, rect.end.x - 16.0, float(x_step) / 4.0),
					lerpf(rect.position.y + 16.0, rect.end.y - 16.0, float(y_step) / 4.0)
				)
				if String(arena.terrain_map.get_zone_at(point)) == zone:
					return point
	return Vector2.ZERO
