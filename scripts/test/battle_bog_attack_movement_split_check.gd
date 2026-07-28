extends SceneTree

const AttackTimeline := preload("res://scripts/sim/combat/attack_timeline.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const VARIANT := "split_test"
const TIME_EPSILON := 0.00001
const POSITION_EPSILON := 0.0001
const TEST_SPEED_PX := 100.0
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
		"active": 0.50,
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
		"recovery": ["punishable"],
	},
	"cooldown_sec": 1.0,
}


class TestArena:
	extends Node

	var simulation_tick := 0
	var match_over := false
	var entities: Array[Node] = []
	var cores := {}
	var death_count := 0
	var movement_limit_x := INF
	var resolve_body_calls := 0

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func get_terrain_zone(_point: Vector2) -> String:
		return "land"

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		resolve_body_calls += 1
		if is_finite(movement_limit_x):
			point.x = minf(point.x, movement_limit_x)
		return point

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		death_count += 1

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)

	func record_vfx_event(_event: Dictionary) -> void:
		pass


class ResolverProbe:
	extends RefCounted

	var calls := 0
	var result := {
		"outcome": "hit",
		"hit_count": 1,
		"hit_region": "body",
	}

	func resolve() -> Dictionary:
		calls += 1
		return result.duplicate(true)


class TickProbe:
	extends RefCounted

	var tick_calls := 0
	var match_end_calls := 0

	func tick(_actor: Node, _delta: float) -> void:
		tick_calls += 1

	func tick_match_end(_actor: Node, _delta: float) -> void:
		match_end_calls += 1


class RepeatingBoundaryTimeline:
	extends RefCounted

	const BOUNDARY_SEC := 0.01
	const SEQUENCE_ID := 77

	var pending := true
	var boundary_commits := 0
	var timed_advances := 0
	var consumed_time := 0.0

	func is_idle() -> bool:
		return false

	func snapshot() -> Dictionary:
		return {
			"attack_phase": AttackTimeline.Phase.ACTIVE,
			"attack_phase_name": "active",
			"phase_t": 1.0 if pending else 0.0,
			"attack_outcome": AttackTimeline.Outcome.HIT,
			"attack_outcome_name": "hit",
			"attack_sequence_id": SEQUENCE_ID,
			"attack_started_tick": 1200,
			"attack_active_tick": 1200,
			"attack_interrupted_tick": -1,
			"strike_heading": Vector2.RIGHT,
			"payload": {},
			"hit_count": 1,
			"hit_region": "body",
			"interruption_reason": "",
		}

	func movement_multiplier() -> float:
		return 0.50

	func current_phase_name() -> StringName:
		return &"active"

	func time_to_phase_boundary() -> float:
		return 0.0 if pending else BOUNDARY_SEC

	func advance(
		delta: float,
		_simulation_tick: int,
		_active_resolver: Callable
	) -> Array[Dictionary]:
		if pending:
			return []
		timed_advances += 1
		consumed_time += delta
		pending = true
		return []

	func advance_pending_boundary(
		_simulation_tick: int,
		_active_resolver: Callable
	) -> Array[Dictionary]:
		if not pending:
			return []
		boundary_commits += 1
		pending = false
		return [{"event": "recovery_started"}]

	func reset() -> void:
		pending = false


class CreatureResolver:
	extends RefCounted

	enum Mode {
		HIT,
		RESET,
		RESET_RESTART,
		DEATH,
		REPLACEMENT,
		MATCH_END,
		REVERSE,
		LATCH,
	}

	var calls := 0
	var mode: Mode
	var actor: Node
	var victim: Node
	var tick_probe: RefCounted
	var restart_accepted := false
	var restarted_resolver_calls := 0

	func _init(
		next_actor: Node,
		next_mode: Mode,
		next_victim: Node = null,
		next_tick_probe: RefCounted = null
	) -> void:
		actor = next_actor
		mode = next_mode
		victim = next_victim
		tick_probe = next_tick_probe

	func resolve() -> Dictionary:
		calls += 1
		match mode:
			Mode.RESET:
				actor.primary_attack_timeline.reset()
			Mode.RESET_RESTART:
				actor.primary_attack_timeline.reset()
				restart_accepted = actor.primary_attack_timeline.start(
					TIMELINE_CONFIG,
					{"test": "replacement_sequence"},
					Vector2.RIGHT,
					int(actor.arena.simulation_tick),
					1.0
				)
			Mode.DEATH:
				actor.take_damage(actor.max_health * 2.0)
			Mode.REPLACEMENT:
				actor.apply_creature("newt")
				if tick_probe != null:
					actor.kit = tick_probe
			Mode.MATCH_END:
				actor.arena.match_over = true
				actor.on_match_ended()
			Mode.REVERSE:
				actor.input_frame.move = Vector2.LEFT
				actor.input_frame.aim = Vector2.RIGHT * 1000.0
			Mode.LATCH:
				actor.attach_to_victim(victim, 2.0, "Split Test Latch")
				victim.receive_latch(actor, 2.0, "Split Test Latch")
			_:
				pass
		return {
			"outcome": "hit",
			"hit_count": 1,
			"hit_region": "body",
		}

	func resolve_restarted() -> Dictionary:
		restarted_resolver_calls += 1
		return {
			"outcome": "hit",
			"hit_count": 1,
			"hit_region": "replacement",
		}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	_check_pending_boundary_api(failures)
	_check_request_tick_preserves_startup(failures)
	_check_single_boundary_and_endpoint_displacement(failures)
	_check_multi_boundary_and_idle_remainder(failures)
	_check_coarse_partition_equivalence(failures)
	_check_resolver_discard_cases(failures)
	_check_full_tick_lifecycle_invalidation(failures)
	_check_reset_and_restart_discards_tick(failures)
	_check_dash_and_residual_velocity(failures)
	_check_latch_created_tick_protection(failures)
	_check_obstacle_resolution_per_slice(failures)
	_check_eight_boundary_guard(failures)

	print("attack_movement_split failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_pending_boundary_api(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new()
	if not is_inf(timeline.time_to_phase_boundary()):
		failures.append("idle timeline should report INF to its next boundary")
	if not timeline.start(
		TIMELINE_CONFIG,
		{"test": "pending"},
		Vector2.RIGHT,
		10,
		1.0
	):
		failures.append("pending-boundary fixture should start")
		return

	var before_query: Dictionary = timeline.snapshot()
	var first_boundary: float = timeline.time_to_phase_boundary()
	if absf(first_boundary - 0.20) > TIME_EPSILON \
		or timeline.snapshot() != before_query:
		failures.append(
			"time_to_phase_boundary should be exact and non-mutating; boundary=%.8f state=%s"
			% [first_boundary, str(timeline.snapshot())]
		)

	var consume_events: Array = timeline.advance(0.20, 11, probe.resolve)
	if not consume_events.is_empty() \
		or probe.calls != 0 \
		or timeline.current_phase_name() != &"startup" \
		or timeline.time_to_phase_boundary() != 0.0:
		failures.append(
			"exact time consumption should leave startup pending without resolving; calls=%d events=%s state=%s"
			% [probe.calls, str(consume_events), str(timeline.snapshot())]
		)

	var pending_state: Dictionary = timeline.snapshot()
	var blocked_events: Array = timeline.advance(0.05, 12, probe.resolve)
	var invalid_events: Array = timeline.advance_pending_boundary(-1, probe.resolve)
	if not blocked_events.is_empty() \
		or not invalid_events.is_empty() \
		or timeline.snapshot() != pending_state \
		or probe.calls != 0:
		failures.append(
			"pending boundary should block timed advance and reject invalid ticks without mutation"
		)

	var active_events: Array = timeline.advance_pending_boundary(17, probe.resolve)
	if _event_names(active_events) != ["active_started"] \
		or probe.calls != 1 \
		or timeline.current_phase_name() != &"active" \
		or int(timeline.snapshot()["attack_active_tick"]) != 17 \
		or absf(timeline.time_to_phase_boundary() - 0.10) > TIME_EPSILON:
		failures.append(
			"startup boundary should resolve exactly once at the supplied tick; calls=%d events=%s state=%s"
			% [probe.calls, str(_event_names(active_events)), str(timeline.snapshot())]
		)

	timeline.advance(0.10, 18, probe.resolve)
	var recovery_events: Array = timeline.advance_pending_boundary(
		18,
		probe.resolve
	)
	if _event_names(recovery_events) != ["recovery_started"] \
		or timeline.current_phase_name() != &"recovery" \
		or probe.calls != 1 \
		or absf(timeline.time_to_phase_boundary() - 0.30) > TIME_EPSILON:
		failures.append(
			"active boundary should enter hit recovery without resolving twice; events=%s state=%s"
			% [str(_event_names(recovery_events)), str(timeline.snapshot())]
		)

	timeline.advance(0.30, 19, probe.resolve)
	var completed_events: Array = timeline.advance_pending_boundary(
		19,
		probe.resolve
	)
	if _event_names(completed_events) != ["completed"] \
		or not timeline.is_idle() \
		or not is_inf(timeline.time_to_phase_boundary()) \
		or probe.calls != 1:
		failures.append(
			"recovery boundary should complete once and restore idle INF; events=%s state=%s"
			% [str(_event_names(completed_events)), str(timeline.snapshot())]
		)


func _check_request_tick_preserves_startup(failures: Array[String]) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var resolver := CreatureResolver.new(actor, CreatureResolver.Mode.HIT)
	arena.simulation_tick = 100
	if not _request(actor, resolver):
		failures.append("request-tick fixture should accept its attack")
		_cleanup_fixture(fixture)
		return

	actor._integrate_attack_movement_and_timeline(0.80)
	var state: Dictionary = actor.get_primary_attack_snapshot()
	var expected_displacement := TEST_SPEED_PX * 0.25 * 0.80
	if resolver.calls != 0 \
		or String(state["attack_phase_name"]) != "startup" \
		or absf(float(state["phase_t"])) > TIME_EPSILON \
		or absf(actor.global_position.x - expected_displacement) > POSITION_EPSILON \
		or absf(actor.last_move_displacement_px - expected_displacement) > POSITION_EPSILON:
		failures.append(
			"request tick should retain full startup and startup steering; calls=%d pos=%s displacement=%.5f state=%s"
			% [
				resolver.calls,
				str(actor.global_position),
				actor.last_move_displacement_px,
				str(state),
			]
		)
	_cleanup_fixture(fixture)


func _check_single_boundary_and_endpoint_displacement(
	failures: Array[String]
) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var resolver := CreatureResolver.new(
		actor,
		CreatureResolver.Mode.REVERSE
	)
	arena.simulation_tick = 200
	_request(actor, resolver)
	arena.simulation_tick = 201
	var start_position: Vector2 = actor.global_position
	actor._integrate_attack_movement_and_timeline(0.25)

	var expected_endpoint := TEST_SPEED_PX * 0.25 * 0.20 \
		- TEST_SPEED_PX * 0.50 * 0.05
	var endpoint_distance: float = actor.global_position.distance_to(
		start_position
	)
	var state: Dictionary = actor.get_primary_attack_snapshot()
	if resolver.calls != 1 \
		or String(state["attack_phase_name"]) != "active" \
		or absf(float(state["phase_t"]) - 0.50) > TIME_EPSILON \
		or absf(actor.global_position.x - expected_endpoint) > POSITION_EPSILON \
		or absf(actor.last_move_displacement_px - endpoint_distance) > POSITION_EPSILON \
		or actor.last_move_displacement_px >= 7.0:
		failures.append(
			"single crossing should split steering and store endpoint displacement, not path length; calls=%d pos=%s last=%.5f endpoint=%.5f state=%s"
			% [
				resolver.calls,
				str(actor.global_position),
				actor.last_move_displacement_px,
				endpoint_distance,
				str(state),
			]
		)
	_cleanup_fixture(fixture)


func _check_multi_boundary_and_idle_remainder(
	failures: Array[String]
) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var resolver := CreatureResolver.new(actor, CreatureResolver.Mode.HIT)
	arena.simulation_tick = 300
	_request(actor, resolver)
	arena.simulation_tick = 301
	actor._integrate_attack_movement_and_timeline(0.80)

	var expected := TEST_SPEED_PX * (
		0.20 * 0.25
		+ 0.10 * 0.50
		+ 0.30 * 0.75
		+ 0.20
	)
	if resolver.calls != 1 \
		or actor.is_primary_attack_committed() \
		or absf(actor.global_position.x - expected) > POSITION_EPSILON \
		or absf(actor.last_move_displacement_px - expected) > POSITION_EPSILON:
		failures.append(
			"multi-boundary tick should resolve once and move its remainder at idle speed; calls=%d committed=%s pos=%s last=%.5f expected=%.5f"
			% [
				resolver.calls,
				str(actor.is_primary_attack_committed()),
				str(actor.global_position),
				actor.last_move_displacement_px,
				expected,
			]
		)
	_cleanup_fixture(fixture)


func _check_coarse_partition_equivalence(failures: Array[String]) -> void:
	var coarse := _fixture()
	var partitioned := _fixture()
	var coarse_arena: TestArena = coarse["arena"]
	var partitioned_arena: TestArena = partitioned["arena"]
	var coarse_actor: Node = coarse["actor"]
	var partitioned_actor: Node = partitioned["actor"]
	var coarse_resolver := CreatureResolver.new(
		coarse_actor,
		CreatureResolver.Mode.HIT
	)
	var partitioned_resolver := CreatureResolver.new(
		partitioned_actor,
		CreatureResolver.Mode.HIT
	)
	coarse_arena.simulation_tick = 400
	partitioned_arena.simulation_tick = 400
	_request(coarse_actor, coarse_resolver)
	_request(partitioned_actor, partitioned_resolver)

	coarse_arena.simulation_tick = 401
	coarse_actor._integrate_attack_movement_and_timeline(0.80)
	for slice: float in [0.20, 0.10, 0.30, 0.20]:
		partitioned_arena.simulation_tick += 1
		partitioned_actor._integrate_attack_movement_and_timeline(slice)

	if coarse_resolver.calls != 1 \
		or partitioned_resolver.calls != 1 \
		or coarse_actor.is_primary_attack_committed() \
		or partitioned_actor.is_primary_attack_committed() \
		or coarse_actor.global_position.distance_to(
			partitioned_actor.global_position
		) > POSITION_EPSILON:
		failures.append(
			"coarse and boundary-partitioned integration should agree; coarse_calls=%d partitioned_calls=%d coarse=%s partitioned=%s"
			% [
				coarse_resolver.calls,
				partitioned_resolver.calls,
				str(coarse_actor.global_position),
				str(partitioned_actor.global_position),
			]
		)
	_cleanup_fixture(coarse)
	_cleanup_fixture(partitioned)


func _check_resolver_discard_cases(failures: Array[String]) -> void:
	for case: Dictionary in [
		{"label": "reset", "mode": CreatureResolver.Mode.RESET},
		{"label": "death", "mode": CreatureResolver.Mode.DEATH},
		{"label": "replacement", "mode": CreatureResolver.Mode.REPLACEMENT},
	]:
		var fixture := _fixture()
		var arena: TestArena = fixture["arena"]
		var actor: Node = fixture["actor"]
		var resolver := CreatureResolver.new(actor, case["mode"])
		arena.simulation_tick = 500
		_request(actor, resolver)
		arena.simulation_tick = 501
		actor._integrate_attack_movement_and_timeline(0.80)
		var startup_only := TEST_SPEED_PX * 0.25 * 0.20
		if resolver.calls != 1 \
			or absf(actor.global_position.x - startup_only) > POSITION_EPSILON \
			or absf(actor.last_move_displacement_px - startup_only) > POSITION_EPSILON:
			failures.append(
				"%s resolver should discard all post-contact tick remainder; calls=%d pos=%s last=%.5f"
				% [
					String(case["label"]),
					resolver.calls,
					str(actor.global_position),
					actor.last_move_displacement_px,
				]
			)
		if String(case["label"]) == "death" and actor.alive:
			failures.append("death resolver should leave the actor dead")
		if String(case["label"]) == "replacement" \
			and actor.creature_id != "newt":
			failures.append(
				"replacement resolver should preserve the replacement creature"
			)
		_cleanup_fixture(fixture)


func _check_full_tick_lifecycle_invalidation(
	failures: Array[String]
) -> void:
	for case: Dictionary in [
		{
			"label": "replacement",
			"mode": CreatureResolver.Mode.REPLACEMENT,
		},
		{
			"label": "death",
			"mode": CreatureResolver.Mode.DEATH,
		},
		{
			"label": "match_end",
			"mode": CreatureResolver.Mode.MATCH_END,
		},
	]:
		var fixture := _fixture()
		var arena: TestArena = fixture["arena"]
		var actor: Node = fixture["actor"]
		var probe := TickProbe.new()
		actor.kit = probe
		actor.hunger = 72.0
		actor.hunger_satiated = false
		actor.dash_velocity = Vector2.RIGHT * 40.0
		actor.dash_timer = 1.0
		actor.residual_velocity = Vector2.RIGHT * 15.0
		var resolver := CreatureResolver.new(
			actor,
			case["mode"],
			null,
			probe
		)
		arena.simulation_tick = 800
		_request(actor, resolver)
		arena.simulation_tick = 801
		actor.tick_sim(0.80)

		var label := String(case["label"])
		var expected_hunger := (
			100.0
			if label == "replacement"
			else 72.0
		)
		var lifecycle_truth := true
		if label == "replacement":
			lifecycle_truth = actor.creature_id == "newt"
		elif label == "death":
			lifecycle_truth = not actor.alive
		elif label == "match_end":
			lifecycle_truth = arena.match_over \
				and not actor.is_primary_attack_committed() \
				and actor.velocity == Vector2.ZERO \
				and actor.steering_velocity == Vector2.ZERO \
				and actor.dash_velocity == Vector2.ZERO \
				and actor.dash_timer == 0.0 \
				and actor.residual_velocity == Vector2.ZERO \
				and probe.match_end_calls == 1

		if resolver.calls != 1 \
			or probe.tick_calls != 0 \
			or absf(actor.hunger - expected_hunger) > TIME_EPSILON \
			or not lifecycle_truth:
			failures.append(
				"%s contact must terminate the full simulation tick; resolver=%d kit_ticks=%d match_end=%d hunger=%.5f creature=%s alive=%s committed=%s velocity=%s steering=%s dash=%s dash_timer=%.5f residual=%s"
				% [
					label,
					resolver.calls,
					probe.tick_calls,
					probe.match_end_calls,
					actor.hunger,
					actor.creature_id,
					str(actor.alive),
					str(actor.is_primary_attack_committed()),
					str(actor.velocity),
					str(actor.steering_velocity),
					str(actor.dash_velocity),
					actor.dash_timer,
					str(actor.residual_velocity),
				]
			)
		_cleanup_fixture(fixture)


func _check_reset_and_restart_discards_tick(
	failures: Array[String]
) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var probe := TickProbe.new()
	actor.kit = probe
	actor.hunger = 68.0
	actor.hunger_satiated = false
	var resolver := CreatureResolver.new(
		actor,
		CreatureResolver.Mode.RESET_RESTART,
		null,
		probe
	)
	arena.simulation_tick = 900
	_request(actor, resolver)
	arena.simulation_tick = 901
	actor.tick_sim(0.80)
	var state: Dictionary = actor.get_primary_attack_snapshot()
	var startup_only: float = actor.get_speed_px() * 0.25 * 0.20

	if resolver.calls != 1 \
		or not resolver.restart_accepted \
		or resolver.restarted_resolver_calls != 0 \
		or String(state["attack_phase_name"]) != "startup" \
		or int(state["attack_sequence_id"]) != 2 \
		or absf(float(state["phase_t"])) > TIME_EPSILON \
		or absf(actor.global_position.x - startup_only) > POSITION_EPSILON \
		or probe.tick_calls != 0 \
		or absf(actor.hunger - 68.0) > TIME_EPSILON:
		failures.append(
			"resolver reset-and-restart must preserve the replacement startup and terminate the old tick; calls=%d accepted=%s replacement_calls=%d state=%s pos=%s kit_ticks=%d hunger=%.5f"
			% [
				resolver.calls,
				str(resolver.restart_accepted),
				resolver.restarted_resolver_calls,
				str(state),
				str(actor.global_position),
				probe.tick_calls,
				actor.hunger,
			]
		)
	_cleanup_fixture(fixture)


func _check_dash_and_residual_velocity(failures: Array[String]) -> void:
	var dash_fixture := _fixture(Vector2.ZERO)
	var dash_arena: TestArena = dash_fixture["arena"]
	var dash_actor: Node = dash_fixture["actor"]
	var dash_resolver := CreatureResolver.new(
		dash_actor,
		CreatureResolver.Mode.HIT
	)
	dash_arena.simulation_tick = 600
	_request(dash_actor, dash_resolver)
	dash_arena.simulation_tick = 601
	dash_actor.dash_timer = 1.0
	dash_actor.dash_velocity = Vector2.RIGHT * 320.0
	dash_actor._integrate_attack_movement_and_timeline(0.80)
	if absf(dash_actor.global_position.x - 256.0) > POSITION_EPSILON \
		or dash_actor.dash_velocity != Vector2.RIGHT * 320.0:
		failures.append(
			"attack multipliers must not scale dash displacement or velocity; pos=%s dash=%s"
			% [
				str(dash_actor.global_position),
				str(dash_actor.dash_velocity),
			]
		)
	_cleanup_fixture(dash_fixture)

	var residual_fixture := _fixture(Vector2.ZERO)
	var residual_arena: TestArena = residual_fixture["arena"]
	var residual_actor: Node = residual_fixture["actor"]
	var residual_resolver := CreatureResolver.new(
		residual_actor,
		CreatureResolver.Mode.HIT
	)
	residual_arena.simulation_tick = 610
	_request(residual_actor, residual_resolver)
	residual_arena.simulation_tick = 611
	residual_actor.residual_velocity = Vector2.RIGHT * 80.0
	residual_actor.steering_velocity = Vector2.ZERO
	residual_actor._integrate_attack_movement_and_timeline(0.80)
	if absf(residual_actor.global_position.x - 64.0) > POSITION_EPSILON \
		or residual_actor.residual_velocity != Vector2.RIGHT * 80.0:
		failures.append(
			"attack multipliers must not scale or consume residual velocity; pos=%s residual=%s"
			% [
				str(residual_actor.global_position),
				str(residual_actor.residual_velocity),
			]
		)
	_cleanup_fixture(residual_fixture)


func _check_latch_created_tick_protection(failures: Array[String]) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var victim := _actor(arena, "snapping_turtle", Vector2(30.0, 0.0))
	var resolver := CreatureResolver.new(
		actor,
		CreatureResolver.Mode.LATCH,
		victim
	)
	arena.simulation_tick = 700
	_request(actor, resolver)
	arena.simulation_tick = 701
	actor._integrate_attack_movement_and_timeline(0.25)
	var created_tick: int = int(actor.latch_created_simulation_tick)
	actor._tick_latch(0.25)
	var same_tick_timer: float = actor.latch_timer
	arena.simulation_tick = 702
	actor._tick_latch(0.25)
	var next_tick_timer: float = actor.latch_timer

	if resolver.calls != 1 \
		or created_tick != 701 \
		or absf(same_tick_timer - 2.0) > TIME_EPSILON \
		or absf(next_tick_timer - 1.75) > TIME_EPSILON:
		failures.append(
			"new latch should retain full duration on its contact tick then drain next tick; calls=%d created=%d same=%.5f next=%.5f"
			% [
				resolver.calls,
				created_tick,
				same_tick_timer,
				next_tick_timer,
			]
		)
	_cleanup_fixture(fixture)


func _check_obstacle_resolution_per_slice(failures: Array[String]) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var resolver := CreatureResolver.new(actor, CreatureResolver.Mode.HIT)
	arena.movement_limit_x = 8.0
	arena.simulation_tick = 1100
	_request(actor, resolver)
	arena.simulation_tick = 1101
	actor._integrate_attack_movement_and_timeline(0.80)

	if resolver.calls != 1 \
		or actor.global_position.x > 8.0 + POSITION_EPSILON \
		or arena.resolve_body_calls < 4:
		failures.append(
			"every split movement slice must resolve arena obstacles; calls=%d pos=%s resolves=%d"
			% [
				resolver.calls,
				str(actor.global_position),
				arena.resolve_body_calls,
			]
		)
	_cleanup_fixture(fixture)


func _check_eight_boundary_guard(failures: Array[String]) -> void:
	var fixture := _fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	var timeline := RepeatingBoundaryTimeline.new()
	actor.primary_attack_timeline = timeline
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2.ZERO
	actor.steering_velocity = Vector2.ZERO
	arena.simulation_tick = 1201

	var previous_print_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	actor._integrate_attack_movement_and_timeline(0.20)
	Engine.print_error_messages = previous_print_errors

	var expected_time := 7.0 * RepeatingBoundaryTimeline.BOUNDARY_SEC
	var expected_position := (
		TEST_SPEED_PX
		* timeline.movement_multiplier()
		* expected_time
	)
	if timeline.boundary_commits != 8 \
		or timeline.timed_advances != 7 \
		or absf(timeline.consumed_time - expected_time) > TIME_EPSILON \
		or absf(actor.global_position.x - expected_position) > POSITION_EPSILON:
		failures.append(
			"the split loop must allow eight boundaries and reject movement toward the ninth; commits=%d advances=%d time=%.5f pos=%s expected=%.5f"
			% [
				timeline.boundary_commits,
				timeline.timed_advances,
				timeline.consumed_time,
				str(actor.global_position),
				expected_position,
			]
		)
	_cleanup_fixture(fixture)


func _fixture(move_direction := Vector2.RIGHT) -> Dictionary:
	var arena := TestArena.new()
	get_root().add_child(arena)
	var actor := _actor(arena, "chorus_frog", Vector2.ZERO)
	_enable_timeline(actor)
	_configure_deterministic_movement(actor)
	actor.set_input_frame(_move_frame(move_direction))
	return {
		"arena": arena,
		"actor": actor,
	}


func _actor(
	arena: TestArena,
	creature_id: String,
	position: Vector2
) -> Node:
	var actor := CreatureScript.new()
	arena.add_actor(actor)
	actor.setup(arena, 0, position, creature_id)
	actor.global_position = position
	return actor


func _enable_timeline(actor: Node) -> void:
	var data: Dictionary = actor.creature_data.duplicate(true)
	var next_stats: Dictionary = data.get("stats", {}).duplicate(true)
	next_stats["action_timelines"] = {
		VARIANT: TIMELINE_CONFIG.duplicate(true),
	}
	data["stats"] = next_stats
	actor.creature_data = data
	actor.stats = next_stats
	actor.primary_timer = 0.0


func _configure_deterministic_movement(actor: Node) -> void:
	actor.terrain_speed_px = TEST_SPEED_PX
	actor.terrain_speed_target_px = TEST_SPEED_PX
	actor.movement_profile = {
		"accel_time": 0.001,
		"decel_time": 0.001,
		"turn_rate_deg": 36000.0,
		"body_turn_rate_deg": 0.0,
		"forward_speed_mult": 1.0,
		"lateral_speed_mult": 1.0,
		"backward_speed_mult": 1.0,
		"water_profile": {},
	}
	actor.velocity = Vector2.ZERO
	actor.steering_velocity = Vector2.ZERO
	actor.residual_velocity = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT


func _request(actor: Node, resolver: CreatureResolver) -> bool:
	return actor.request_primary_attack(
		VARIANT,
		{"test": "movement_split"},
		Callable(resolver, "resolve")
	)


func _move_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = direction
	frame.aim = Vector2.RIGHT * 1000.0
	return frame


func _event_names(events: Array) -> Array[String]:
	var names: Array[String] = []
	for event: Dictionary in events:
		names.append(String(event.get("event", "")))
	return names


func _cleanup_fixture(fixture: Dictionary) -> void:
	var arena: Node = fixture.get("arena", null)
	if arena != null and is_instance_valid(arena):
		arena.free()
