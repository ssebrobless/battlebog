extends SceneTree

const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const VARIANT := "test"
const TIMELINE_CONFIG := {
	"startup": 0.20,
	"active": 0.10,
	"recovery": {
		"hit": 0.30,
		"whiff": 0.40,
		"released": 0.25,
		"interrupted": 0.35,
	},
	"movement_mult": {
		"startup": 0.25,
		"active": 0.5,
		"recovery": 0.75,
	},
	"blocks_abilities": {
		"startup": true,
		"active": true,
		"recovery": false,
	},
	"phase_tags": {
		"startup": ["warning"],
		"active": ["contact"],
		"recovery": ["vulnerable"],
	},
	"cooldown_sec": 1.20,
}


class TestArena:
	extends Node

	var simulation_tick := 0
	var match_over := false
	var entities: Array[Node] = []
	var cores := {}
	var death_snapshots: Array[Dictionary] = []
	var respawns := 0

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func get_terrain_zone(_point: Vector2) -> String:
		return "land"

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_death(victim: Node, _killer: Node = null) -> void:
		death_snapshots.append(victim.get_primary_attack_snapshot())

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)

	func get_actor_respawn_position(_actor: Node) -> Vector2:
		return Vector2(32.0, 48.0)

	func on_actor_respawned(_actor: Node) -> void:
		respawns += 1

	func record_vfx_event(_event: Dictionary) -> void:
		pass


class ResolverProbe:
	extends RefCounted

	var calls := 0
	var result := {
		"outcome": "hit",
		"hit_count": 1,
		"hit_region": "hull",
	}

	func resolve() -> Dictionary:
		calls += 1
		return result.duplicate(true)


class InputProbeKit:
	extends RefCounted

	var tick_calls := 0
	var observed_buttons := 0

	func tick(actor: Node, _delta: float) -> void:
		tick_calls += 1
		observed_buttons = int(actor.input_frame.buttons) if actor.input_frame != null else 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	_check_acceptance_order_and_snapshot(failures)
	_check_cooldown_fallbacks(failures)
	_check_movement_and_ability_policy(failures)
	_check_interrupt_lifecycle(failures)
	_check_death_respawn_and_species_reset(failures)
	_check_legacy_fail_closed(failures)
	print("creature_attack_timeline failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_acceptance_order_and_snapshot(failures: Array[String]) -> void:
	var fixture := _fixture("chorus_frog")
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	_enable_timeline(actor)
	actor.add_modifier("Haste", {"attack_speed_mult": 2.0}, 10.0)
	arena.simulation_tick = 10
	actor.set_input_frame(_frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY))
	var probe := ResolverProbe.new()
	var accepted: bool = actor.request_primary_attack(
		VARIANT,
		{"marker": "accepted"},
		Callable(probe, "resolve")
	)
	var accepted_snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var accepted_ok: bool = (
		accepted
		and actor.is_primary_attack_committed()
		and actor.primary_attack_has_phase_tag("warning")
		and int(accepted_snapshot["attack_started_tick"]) == 10
		and int(accepted_snapshot["attack_sequence_id"]) > 0
		and String(accepted_snapshot["attack_variant"]) == VARIANT
		and (accepted_snapshot["strike_heading"] as Vector2).dot(Vector2.RIGHT) > 0.99
		and absf(actor.primary_timer - 0.60) < 0.001
		and not actor.request_primary_attack(
			VARIANT,
			{},
			Callable(probe, "resolve")
		)
	)
	if not accepted_ok:
		failures.append(
			"request should atomically lock aim/tick/time scale/cooldown and reject duplicates; snapshot=%s timer=%.3f"
			% [str(accepted_snapshot), actor.primary_timer]
		)

	actor.set_input_frame(_frame(Vector2.LEFT, InputFrameScript.BUTTON_PRIMARY))
	actor.tick_sim(0.25)
	var same_tick_snapshot: Dictionary = actor.get_primary_attack_snapshot()
	if probe.calls != 0 \
		or String(same_tick_snapshot["attack_phase_name"]) != "startup" \
		or float(same_tick_snapshot["phase_t"]) != 0.0:
		failures.append(
			"request tick must retain full startup and cannot resolve; calls=%d snapshot=%s"
			% [probe.calls, str(same_tick_snapshot)]
		)

	actor.add_modifier("Late Slow", {"attack_speed_mult": 0.1}, 10.0)
	arena.simulation_tick = 11
	actor.tick_sim(0.16)
	var resolved_snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var render_state: Dictionary = actor.get_render_motion_state()
	var resolved_ok: bool = (
		probe.calls == 1
		and int(resolved_snapshot["attack_active_tick"]) == 11
		and String(resolved_snapshot["attack_phase_name"]) == "recovery"
		and String(resolved_snapshot["attack_outcome_name"]) == "hit"
		and (resolved_snapshot["strike_heading"] as Vector2).dot(Vector2.RIGHT) > 0.99
		and render_state["contact_point"] == null
		and render_state["projected_shape"] == null
		and int(render_state["attack_sequence_id"]) == int(resolved_snapshot["attack_sequence_id"])
	)
	if not resolved_ok:
		failures.append(
			"later tick should resolve once from snapshotted speed/aim and export canonical render state; calls=%d snapshot=%s render=%s"
			% [probe.calls, str(resolved_snapshot), str(render_state)]
		)
	_cleanup_fixture(fixture)


func _check_cooldown_fallbacks(failures: Array[String]) -> void:
	var interval_fixture := _fixture("chorus_frog")
	var interval_arena: TestArena = interval_fixture["arena"]
	var interval_actor: Node = interval_fixture["actor"]
	var fallback_config: Dictionary = TIMELINE_CONFIG.duplicate(true)
	fallback_config.erase("cooldown_sec")
	_enable_timeline(interval_actor, fallback_config)
	interval_actor.stats["attack_interval_sec"] = 0.90
	interval_arena.simulation_tick = 12
	interval_actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	var interval_probe := ResolverProbe.new()
	var interval_accepted: bool = interval_actor.request_primary_attack(
		VARIANT,
		{},
		Callable(interval_probe, "resolve")
	)

	var rate_fixture := _fixture("kingfisher")
	var rate_arena: TestArena = rate_fixture["arena"]
	var rate_actor: Node = rate_fixture["actor"]
	_enable_timeline(rate_actor, fallback_config)
	rate_actor.stats.erase("attack_interval_sec")
	rate_actor.stats["attack_rate_per_sec"] = 0.50
	rate_arena.simulation_tick = 13
	rate_actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	var rate_probe := ResolverProbe.new()
	var rate_accepted: bool = rate_actor.request_primary_attack(
		VARIANT,
		{},
		Callable(rate_probe, "resolve")
	)
	if not interval_accepted \
		or absf(interval_actor.primary_timer - 0.90) > 0.001 \
		or not rate_accepted \
		or absf(rate_actor.primary_timer - 2.0) > 0.001:
		failures.append(
			"cooldown fallback should support attack_interval_sec and reciprocal attack_rate_per_sec; interval=%s/%.3f rate=%s/%.3f"
			% [
				str(interval_accepted),
				interval_actor.primary_timer,
				str(rate_accepted),
				rate_actor.primary_timer,
			]
		)
	_cleanup_fixture(interval_fixture)
	_cleanup_fixture(rate_fixture)


func _check_movement_and_ability_policy(failures: Array[String]) -> void:
	var committed_fixture := _fixture("chorus_frog")
	var baseline_fixture := _fixture("chorus_frog")
	var arena: TestArena = committed_fixture["arena"]
	var actor: Node = committed_fixture["actor"]
	var baseline: Node = baseline_fixture["actor"]
	_enable_timeline(actor)
	arena.simulation_tick = 20
	actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	baseline.set_input_frame(_frame(Vector2.RIGHT, 0))
	var probe := ResolverProbe.new()
	if not actor.request_primary_attack(VARIANT, {}, Callable(probe, "resolve")):
		failures.append("movement policy setup attack should be accepted")
	actor.velocity = Vector2.ZERO
	baseline.velocity = Vector2.ZERO
	arena.simulation_tick = 21
	(committed_fixture["arena"] as TestArena).simulation_tick = 21
	(baseline_fixture["arena"] as TestArena).simulation_tick = 21
	actor.tick_sim(0.20)
	baseline.tick_sim(0.20)
	if actor.velocity.length() >= baseline.velocity.length() * 0.5:
		failures.append(
			"startup movement multiplier should reduce normal movement; committed=%.3f baseline=%.3f"
			% [actor.velocity.length(), baseline.velocity.length()]
		)

	actor.dash_timer = 1.0
	actor.dash_velocity = Vector2(333.0, 0.0)
	arena.simulation_tick = 22
	actor.tick_sim(0.01)
	if absf(actor.velocity.length() - 333.0) > 0.01:
		failures.append(
			"timeline movement policy must not scale dash velocity; velocity=%s"
			% str(actor.velocity)
		)

	var ability_fixture := _fixture("chorus_frog")
	var ability_arena: TestArena = ability_fixture["arena"]
	var ability_actor: Node = ability_fixture["actor"]
	_enable_timeline(ability_actor)
	var input_probe := InputProbeKit.new()
	ability_actor.kit = input_probe
	ability_arena.simulation_tick = 30
	ability_actor.set_input_frame(
		_frame(
			Vector2.RIGHT,
			InputFrameScript.BUTTON_PRIMARY
				| InputFrameScript.BUTTON_ABILITY_Q
				| InputFrameScript.BUTTON_ABILITY_E
		)
	)
	var ability_resolver := ResolverProbe.new()
	ability_actor.request_primary_attack(
		VARIANT,
		{},
		Callable(ability_resolver, "resolve")
	)
	ability_arena.simulation_tick = 31
	ability_actor.tick_sim(0.01)
	if input_probe.tick_calls != 1 \
		or input_probe.observed_buttons != InputFrameScript.BUTTON_PRIMARY:
		failures.append(
			"timeline ability blocking should remove Q/E while preserving primary; calls=%d buttons=%d"
			% [input_probe.tick_calls, input_probe.observed_buttons]
		)
	_cleanup_fixture(committed_fixture)
	_cleanup_fixture(baseline_fixture)
	_cleanup_fixture(ability_fixture)


func _check_interrupt_lifecycle(failures: Array[String]) -> void:
	var startup_fixture := _fixture("chorus_frog")
	var startup_arena: TestArena = startup_fixture["arena"]
	var startup_actor: Node = startup_fixture["actor"]
	_enable_timeline(startup_actor)
	startup_arena.simulation_tick = 40
	startup_actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	var startup_probe := ResolverProbe.new()
	startup_actor.request_primary_attack(
		VARIANT,
		{},
		Callable(startup_probe, "resolve")
	)
	startup_actor.add_modifier("Test Stun", {"can_act_mult": 0.0}, 1.0)
	var interrupted: Dictionary = startup_actor.get_primary_attack_snapshot()
	if String(interrupted["attack_phase_name"]) != "recovery" \
		or String(interrupted["attack_outcome_name"]) != "interrupted" \
		or String(interrupted["interruption_reason"]) != "Test Stun" \
		or startup_probe.calls != 0:
		failures.append(
			"true-to-false can_act transition should softly interrupt startup only; snapshot=%s calls=%d"
			% [str(interrupted), startup_probe.calls]
		)

	var active_fixture := _fixture("chorus_frog")
	var active_arena: TestArena = active_fixture["arena"]
	var active_actor: Node = active_fixture["actor"]
	_enable_timeline(active_actor)
	active_arena.simulation_tick = 50
	active_actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	var active_probe := ResolverProbe.new()
	active_actor.request_primary_attack(VARIANT, {}, Callable(active_probe, "resolve"))
	active_arena.simulation_tick = 51
	active_actor.tick_sim(0.21)
	active_actor.add_modifier("Active Stun", {"can_act_mult": 0.0}, 1.0)
	var active_snapshot: Dictionary = active_actor.get_primary_attack_snapshot()
	active_actor.remove_modifiers_from_source("Active Stun")
	active_arena.simulation_tick = 52
	active_actor.tick_sim(0.10)
	active_actor.add_modifier("Recovery Stun", {"can_act_mult": 0.0}, 1.0)
	var recovery_snapshot: Dictionary = active_actor.get_primary_attack_snapshot()
	if active_probe.calls != 1 \
		or String(active_snapshot["attack_phase_name"]) != "active" \
		or String(active_snapshot["attack_outcome_name"]) != "hit" \
		or String(recovery_snapshot["attack_phase_name"]) != "recovery" \
		or String(recovery_snapshot["attack_outcome_name"]) != "hit":
		failures.append(
			"active/recovery stun must not roll back resolved contact; calls=%d active=%s recovery=%s"
			% [active_probe.calls, str(active_snapshot), str(recovery_snapshot)]
		)
	_cleanup_fixture(startup_fixture)
	_cleanup_fixture(active_fixture)


func _check_death_respawn_and_species_reset(failures: Array[String]) -> void:
	var fixture := _fixture("chorus_frog")
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	_enable_timeline(actor)
	arena.simulation_tick = 60
	actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	var probe := ResolverProbe.new()
	actor.request_primary_attack(VARIANT, {}, Callable(probe, "resolve"))
	actor.take_damage(actor.max_health * 2.0)
	var death_snapshot: Dictionary = (
		arena.death_snapshots[0]
		if not arena.death_snapshots.is_empty()
		else {}
	)
	if actor.is_primary_attack_committed() \
		or int(death_snapshot.get("attack_sequence_id", -1)) != 0 \
		or String(death_snapshot.get("attack_phase_name", "")) != "idle":
		failures.append(
			"fatal damage must reset timeline before death callbacks; callback=%s current=%s"
			% [str(death_snapshot), str(actor.get_primary_attack_snapshot())]
		)

	actor._respawn()
	if not actor.alive \
		or actor.is_primary_attack_committed() \
		or int(actor.get_primary_attack_snapshot()["attack_sequence_id"]) != 0 \
		or arena.respawns != 1:
		failures.append(
			"respawn should restore an idle cleared timeline; snapshot=%s respawns=%d"
			% [str(actor.get_primary_attack_snapshot()), arena.respawns]
		)

	actor.primary_timer = 0.0
	_enable_timeline(actor)
	arena.simulation_tick = 61
	actor.set_input_frame(_frame(Vector2.RIGHT, 0))
	actor.request_primary_attack(VARIANT, {}, Callable(probe, "resolve"))
	actor.apply_creature("duck")
	if actor.is_primary_attack_committed() \
		or int(actor.get_primary_attack_snapshot()["attack_sequence_id"]) != 0 \
		or String(actor.get_primary_attack_snapshot()["attack_variant"]) != "":
		failures.append(
			"species replacement must clear commitment and bound variant; snapshot=%s"
			% str(actor.get_primary_attack_snapshot())
		)
	_cleanup_fixture(fixture)


func _check_legacy_fail_closed(failures: Array[String]) -> void:
	var fixture := _fixture("chorus_frog")
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	arena.simulation_tick = 70
	actor.set_input_frame(_frame(Vector2.RIGHT, InputFrameScript.BUTTON_PRIMARY))
	var probe := ResolverProbe.new()
	var timer_before: float = actor.primary_timer
	var accepted: bool = actor.request_primary_attack(
		VARIANT,
		{},
		Callable(probe, "resolve")
	)
	if accepted \
		or actor.is_primary_attack_committed() \
		or actor.primary_timer != timer_before:
		failures.append(
			"unmigrated creature data must fail closed without changing legacy cadence; accepted=%s timer=%.3f snapshot=%s"
			% [str(accepted), actor.primary_timer, str(actor.get_primary_attack_snapshot())]
		)
	_cleanup_fixture(fixture)


func _fixture(creature_id: String) -> Dictionary:
	var arena := TestArena.new()
	get_root().add_child(arena)
	var actor := CreatureScript.new()
	arena.add_actor(actor)
	actor.setup(arena, 0, Vector2.ZERO, creature_id)
	actor.global_position = Vector2.ZERO
	return {
		"arena": arena,
		"actor": actor,
	}


func _enable_timeline(actor: Node, config: Dictionary = TIMELINE_CONFIG) -> void:
	var data: Dictionary = actor.creature_data.duplicate(true)
	data["primary_attack_timelines"] = {
		VARIANT: config.duplicate(true),
	}
	actor.creature_data = data
	actor.primary_timer = 0.0


func _frame(direction: Vector2, buttons: int) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = direction
	frame.aim = direction * 100.0
	frame.buttons = buttons
	return frame


func _cleanup_fixture(fixture: Dictionary) -> void:
	var arena: Node = fixture.get("arena", null)
	if arena != null and is_instance_valid(arena):
		arena.free()
