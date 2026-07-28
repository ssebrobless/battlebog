extends SceneTree

const AttackTimeline := preload("res://scripts/sim/combat/attack_timeline.gd")
const EPSILON := 0.0001


class ResolverProbe:
	extends RefCounted

	var calls := 0
	var result: Dictionary

	func _init(next_result: Dictionary) -> void:
		result = next_result.duplicate(true)

	func resolve() -> Dictionary:
		calls += 1
		return result.duplicate(true)


class ReentrantResolver:
	extends RefCounted

	var calls := 0
	var timeline: RefCounted
	var replacement_config: Dictionary

	func _init(target: RefCounted, config: Dictionary) -> void:
		timeline = target
		replacement_config = config.duplicate(true)

	func reset_and_restart() -> Dictionary:
		calls += 1
		timeline.reset()
		timeline.start(
			replacement_config,
			{"attack": "replacement"},
			Vector2.UP,
			900,
			1.0
		)
		return {"outcome": "hit", "hit_count": 99, "hit_region": "stale"}

	func reset_only() -> Dictionary:
		calls += 1
		timeline.reset()
		return {"outcome": "hit", "hit_count": 99, "hit_region": "stale"}


class SignalSource:
	extends RefCounted

	signal fired


func _initialize() -> void:
	var failures: Array[String] = []
	_check_boundaries_and_progress(failures)
	_check_pending_boundary_api(failures)
	_check_current_phase_name(failures)
	_check_overshoot_and_single_resolution(failures)
	_check_outcomes(failures)
	_check_interruptions(failures)
	_check_reset_and_defensive_copies(failures)
	_check_phase_policies(failures)
	_check_determinism(failures)
	_check_authoritative_ticks_and_chunking(failures)
	_check_resolver_reentrancy(failures)
	_check_invalid_configs(failures)
	_check_public_config_normalization(failures)
	_check_recovery_dash_cancel_normalization(failures)
	_check_value_only_boundaries(failures)

	print("attack_timeline failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_boundaries_and_progress(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new({"outcome": "hit", "hit_count": 1, "hit_region": "head"})
	if not timeline.start(_config(), {"attack": "bite"}, Vector2(4.0, 0.0), 10, 1.0):
		failures.append("valid timeline should start")
		return
	_expect_state(timeline, AttackTimeline.Phase.STARTUP, 0.0, "startup begins at zero", failures)

	timeline.advance(0.10, 11, probe.resolve)
	_expect_state(timeline, AttackTimeline.Phase.STARTUP, 0.5, "startup midpoint", failures)
	if probe.calls != 0:
		failures.append("resolver must not run before the startup boundary")

	_advance_and_commit(timeline, 0.10, 14, probe.resolve)
	_expect_state(timeline, AttackTimeline.Phase.ACTIVE, 0.0, "exact startup boundary", failures)
	var active: Dictionary = timeline.snapshot()
	if probe.calls != 1 or int(active.attack_active_tick) != 14:
		failures.append("active boundary should use the authoritative simulation tick; calls=%d active_tick=%s" % [
			probe.calls,
			str(active.attack_active_tick)
		])

	timeline.advance(0.05, 15, probe.resolve)
	_expect_state(timeline, AttackTimeline.Phase.ACTIVE, 0.5, "active midpoint", failures)
	_advance_and_commit(timeline, 0.05, 16, probe.resolve)
	_expect_state(timeline, AttackTimeline.Phase.RECOVERY, 0.0, "exact active boundary", failures)
	_advance_and_commit(timeline, 0.40, 17, probe.resolve)
	if not timeline.is_idle() or probe.calls != 1:
		failures.append("exact recovery boundary should return idle without a second resolution")


func _check_pending_boundary_api(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new({"outcome": "hit", "hit_count": 1})
	if not is_inf(timeline.time_to_phase_boundary()):
		failures.append("idle time_to_phase_boundary must return INF")
	timeline.start(_config(), {}, Vector2.RIGHT, 10, 1.0)
	var before: Dictionary = timeline.snapshot()
	if absf(timeline.time_to_phase_boundary() - 0.20) > EPSILON \
		or timeline.snapshot() != before:
		failures.append("time_to_phase_boundary must be exact and non-mutating")
	if not timeline.advance_pending_boundary(11, probe.resolve).is_empty() \
		or probe.calls != 0:
		failures.append("a non-pending boundary call must be a no-op")
	timeline.advance(0.20, 12, probe.resolve)
	if timeline.current_phase_name() != &"startup" \
		or timeline.time_to_phase_boundary() != 0.0 \
		or probe.calls != 0:
		failures.append("exact elapsed startup must remain pending")
	var events: Array = timeline.advance_pending_boundary(13, probe.resolve)
	if events.size() != 1 \
		or String((events[0] as Dictionary).get("event", "")) != "active_started" \
		or timeline.current_phase_name() != &"active" \
		or int(timeline.snapshot().attack_active_tick) != 13 \
		or probe.calls != 1:
		failures.append("pending startup must commit one exact active boundary")
	if not timeline.advance_pending_boundary(14, probe.resolve).is_empty() \
		or probe.calls != 1:
		failures.append("a repeated non-pending call must not resolve twice")


func _check_current_phase_name(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	if timeline.current_phase_name() != &"idle":
		failures.append("current_phase_name should report idle before an attack starts")

	var probe := ResolverProbe.new({"outcome": "hit"})
	timeline.start(_config(), {}, Vector2.RIGHT, 20, 1.0)
	if timeline.current_phase_name() != &"startup":
		failures.append("current_phase_name should report startup after start")

	_advance_and_commit(timeline, 0.20, 21, probe.resolve)
	if timeline.current_phase_name() != &"active":
		failures.append("current_phase_name should report active at the startup boundary")

	_advance_and_commit(timeline, 0.10, 22, probe.resolve)
	if timeline.current_phase_name() != &"recovery":
		failures.append("current_phase_name should report recovery at the active boundary")

	_advance_and_commit(timeline, 0.40, 23, probe.resolve)
	if timeline.current_phase_name() != &"idle":
		failures.append("current_phase_name should return to idle after recovery")

	timeline.start(_config(), {}, Vector2.RIGHT, 30, 1.0)
	timeline.interrupt("stunned", 31)
	if timeline.current_phase_name() != &"recovery":
		failures.append("soft startup interruption should report recovery")

	timeline.reset()
	if timeline.current_phase_name() != &"idle":
		failures.append("reset should make current_phase_name report idle")

	timeline.start(_config(), {}, Vector2.RIGHT, 40, 1.0)
	timeline.interrupt("death", 41, true)
	if timeline.current_phase_name() != &"idle":
		failures.append("hard interruption should make current_phase_name report idle")


func _check_overshoot_and_single_resolution(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new({"outcome": "hit", "hit_count": 2})
	timeline.start(_config(), {}, Vector2.UP, 40, 1.0)
	var events: Array = timeline.advance(2.0, 41, probe.resolve)
	var event_names: Array[String] = []
	for event: Dictionary in events:
		event_names.append(String(event.get("event", "")))
	if not timeline.is_idle() \
		or probe.calls != 1 \
		or event_names != ["active_started", "recovery_started", "completed"]:
		failures.append("overshoot should cross all boundaries once; idle=%s calls=%d events=%s" % [
			str(timeline.is_idle()),
			probe.calls,
			str(event_names)
		])

	timeline.advance(1.0, 42, probe.resolve)
	if probe.calls != 1:
		failures.append("advancing a completed timeline must not invoke the resolver again")


func _check_outcomes(failures: Array[String]) -> void:
	var cases := [
		{"label": "hit", "enum": AttackTimeline.Outcome.HIT, "duration": 0.40, "count": 3},
		{"label": "whiff", "enum": AttackTimeline.Outcome.WHIFF, "duration": 0.60, "count": 0},
		{"label": "released", "enum": AttackTimeline.Outcome.RELEASED, "duration": 0.25, "count": 0},
	]
	for case: Dictionary in cases:
		var timeline: RefCounted = AttackTimeline.new()
		var region := {"name": "jaw", "weight": 2}
		var probe := ResolverProbe.new({
			"outcome": case.label,
			"hit_count": case.count,
			"hit_region": region,
		})
		timeline.start(_config(), {}, Vector2.RIGHT, 0, 1.0)
		timeline.advance(0.31, 1, probe.resolve)
		var recovery: Dictionary = timeline.snapshot()
		if int(recovery.attack_phase) != AttackTimeline.Phase.RECOVERY \
			or int(recovery.attack_outcome) != int(case.enum) \
			or int(recovery.hit_count) != int(case.count) \
			or recovery.hit_region != region:
			failures.append("%s resolver result should populate recovery snapshot; state=%s" % [
				String(case.label),
				str(recovery)
			])
		timeline.advance(float(case.duration) - 0.02, 2, probe.resolve)
		if timeline.is_idle():
			failures.append("%s recovery should remain active before its boundary" % String(case.label))
		_advance_and_commit(timeline, 0.02, 3, probe.resolve)
		if not timeline.is_idle() or probe.calls != 1:
			failures.append("%s recovery should complete exactly once" % String(case.label))


func _check_interruptions(failures: Array[String]) -> void:
	var soft: RefCounted = AttackTimeline.new()
	var soft_probe := ResolverProbe.new({"outcome": "hit"})
	soft.start(_config(), {}, Vector2.RIGHT, 20, 1.0)
	soft.advance(0.05, 21, soft_probe.resolve)
	var soft_event: Dictionary = soft.interrupt("stunned", 22)
	var soft_state: Dictionary = soft.snapshot()
	if not bool(soft_event.changed) \
		or int(soft_state.attack_phase) != AttackTimeline.Phase.RECOVERY \
		or int(soft_state.attack_outcome) != AttackTimeline.Outcome.INTERRUPTED \
		or String(soft_state.interruption_reason) != "stunned" \
		or int(soft_state.attack_interrupted_tick) != 22 \
		or soft_probe.calls != 0:
		failures.append("soft startup interruption should skip active and enter interrupted recovery; event=%s state=%s calls=%d" % [
			str(soft_event),
			str(soft_state),
			soft_probe.calls
		])
	_advance_and_commit(soft, 0.50, 23, soft_probe.resolve)
	if not soft.is_idle():
		failures.append("soft interruption should use interrupted recovery duration")

	var active: RefCounted = AttackTimeline.new()
	var active_probe := ResolverProbe.new({"outcome": "hit"})
	active.start(_config(), {}, Vector2.RIGHT, 30, 1.0)
	_advance_and_commit(active, 0.20, 31, active_probe.resolve)
	var ignored: Dictionary = active.interrupt("late_stun", 32)
	if bool(ignored.changed) \
		or int(active.snapshot().attack_phase) != AttackTimeline.Phase.ACTIVE \
		or int(active.snapshot().attack_outcome) != AttackTimeline.Outcome.HIT:
		failures.append("soft interruption after resolution must not roll back active contact")

	var hard: RefCounted = AttackTimeline.new()
	hard.start(_config(), {"held": true}, Vector2.LEFT, 50, 1.0)
	var hard_event: Dictionary = hard.interrupt("death", 51, true)
	var hard_state: Dictionary = hard.snapshot()
	if not bool(hard_event.changed) \
		or not bool(hard_event.hard) \
		or int(hard_event.interrupted_sequence_id) != 1 \
		or int(hard_event.attack_sequence_id) != 1 \
		or int(hard_event.attack_phase) != AttackTimeline.Phase.STARTUP \
		or int(hard_event.attack_outcome) != AttackTimeline.Outcome.INTERRUPTED \
		or int(hard_event.attack_interrupted_tick) != 51 \
		or String(hard_event.interruption_reason) != "death" \
		or not bool((hard_event.payload as Dictionary).held) \
		or not hard.is_idle() \
		or int(hard_state.attack_sequence_id) != 0 \
		or not (hard_state.payload as Dictionary).is_empty():
		failures.append("hard interruption should report the canceled sequence and reset immediately; event=%s state=%s" % [
			str(hard_event),
			str(hard_state)
		])


func _check_reset_and_defensive_copies(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var config := _config()
	var payload := {"nested": {"value": 7}}
	timeline.start(config, payload, Vector2(10.0, 0.0), 70, 2.0)
	config.movement_mult.startup = 0.99
	payload.nested.value = 99
	var first: Dictionary = timeline.snapshot()
	(first.payload as Dictionary).nested.value = -1
	var second: Dictionary = timeline.snapshot()
	var copied: bool = absf(timeline.movement_multiplier() - 0.50) < EPSILON \
		and int((second.payload as Dictionary).nested.value) == 7 \
		and (second.strike_heading as Vector2).is_equal_approx(Vector2.RIGHT)
	if not copied:
		failures.append("start and snapshot should deep-copy config/payload and normalize heading; state=%s" % str(second))

	var probe := ResolverProbe.new({"outcome": "hit"})
	_advance_and_commit(timeline, 0.10, 71, probe.resolve)
	if int(timeline.snapshot().attack_phase) != AttackTimeline.Phase.ACTIVE:
		failures.append("time_scale=2 should halve the startup duration")
	timeline.reset()
	var reset_state: Dictionary = timeline.snapshot()
	if not timeline.is_idle() \
		or int(reset_state.attack_sequence_id) != 0 \
		or int(reset_state.attack_outcome) != AttackTimeline.Outcome.NONE \
		or int(reset_state.attack_started_tick) != -1 \
		or not (reset_state.payload as Dictionary).is_empty():
		failures.append("reset should clear all active sequence state; state=%s" % str(reset_state))
	if not timeline.start(_config(), {}, Vector2.RIGHT, 80, 1.0) \
		or int(timeline.snapshot().attack_sequence_id) != 2:
		failures.append("sequence ids should remain monotonic across reset")


func _check_phase_policies(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new({"outcome": "hit"})
	timeline.start(_config(), {}, Vector2.RIGHT, 0, 1.0)
	if absf(timeline.movement_multiplier() - 0.50) > EPSILON \
		or not timeline.blocks_abilities() \
		or not timeline.has_phase_tag("warning") \
		or timeline.has_phase_tag("contact"):
		failures.append("startup should expose its movement, block, and tag policy")
	_advance_and_commit(timeline, 0.20, 1, probe.resolve)
	if absf(timeline.movement_multiplier() - 0.20) > EPSILON \
		or not timeline.blocks_abilities() \
		or not timeline.has_phase_tag("contact"):
		failures.append("active should expose its movement, block, and tag policy")
	_advance_and_commit(timeline, 0.10, 2, probe.resolve)
	if absf(timeline.movement_multiplier() - 0.35) > EPSILON \
		or timeline.blocks_abilities() \
		or not timeline.has_phase_tag("punishable"):
		failures.append("recovery should expose its movement, block, and tag policy")
	_advance_and_commit(timeline, 0.40, 3, probe.resolve)
	if absf(timeline.movement_multiplier() - 1.0) > EPSILON \
		or timeline.blocks_abilities() \
		or timeline.has_phase_tag("punishable"):
		failures.append("idle should restore neutral policies")


func _check_determinism(failures: Array[String]) -> void:
	var first := _deterministic_trace()
	var second := _deterministic_trace()
	if first != second:
		failures.append("identical starts and deltas should produce identical traces; first=%s second=%s" % [
			str(first),
			str(second)
		])


func _check_authoritative_ticks_and_chunking(failures: Array[String]) -> void:
	var near_boundary: RefCounted = AttackTimeline.new()
	var near_probe := ResolverProbe.new({"outcome": "hit"})
	near_boundary.start(_config(), {}, Vector2.RIGHT, 100, 1.0)
	near_boundary.advance(0.20 - 0.0000005, 150, near_probe.resolve)
	if int(near_boundary.snapshot().attack_phase) != AttackTimeline.Phase.STARTUP \
		or near_probe.calls != 0:
		failures.append("a delta short of the boundary must not create time or enter active")
	_advance_and_commit(near_boundary, 0.0000005, 177, near_probe.resolve)
	if int(near_boundary.snapshot().attack_phase) != AttackTimeline.Phase.ACTIVE \
		or int(near_boundary.snapshot().attack_active_tick) != 177 \
		or near_probe.calls != 1:
		failures.append("the final conserved delta should enter active at authoritative tick 177")

	var whole: RefCounted = AttackTimeline.new()
	var fragmented: RefCounted = AttackTimeline.new()
	var whole_probe := ResolverProbe.new({"outcome": "whiff"})
	var fragmented_probe := ResolverProbe.new({"outcome": "whiff"})
	var tiny_config := _config()
	tiny_config.startup = 0.00001
	whole.start(tiny_config, {}, Vector2.RIGHT, 200, 1.0)
	fragmented.start(tiny_config, {}, Vector2.RIGHT, 200, 1.0)
	var tiny_delta := 0.0000001
	var total := 0.0
	for index: int in 100:
		total += tiny_delta
		fragmented.advance(tiny_delta, 220, fragmented_probe.resolve)
	whole.advance(total, 220, whole_probe.resolve)
	var whole_state: Dictionary = whole.snapshot()
	var fragmented_state: Dictionary = fragmented.snapshot()
	if int(whole_state.attack_phase) != int(fragmented_state.attack_phase) \
		or absf(float(whole_state.phase_t) - float(fragmented_state.phase_t)) > EPSILON \
		or int(whole_state.attack_active_tick) != int(fragmented_state.attack_active_tick) \
		or whole_probe.calls != fragmented_probe.calls:
		failures.append("finite positive deltas must be conserved across chunking; whole=%s fragmented=%s" % [
			str(whole_state),
			str(fragmented_state)
		])


func _check_resolver_reentrancy(failures: Array[String]) -> void:
	var reset_timeline: RefCounted = AttackTimeline.new()
	reset_timeline.start(_config(), {"attack": "canceled"}, Vector2.RIGHT, 290, 1.0)
	var reset_resolver := ReentrantResolver.new(reset_timeline, _config())
	var reset_events: Array = reset_timeline.advance(2.0, 291, reset_resolver.reset_only)
	if reset_resolver.calls != 1 \
		or not reset_events.is_empty() \
		or not reset_timeline.is_idle():
		failures.append("resolver reset must cancel stale resolution and overshoot; events=%s state=%s" % [
			str(reset_events),
			str(reset_timeline.snapshot())
		])

	var timeline: RefCounted = AttackTimeline.new()
	timeline.start(_config(), {"attack": "original"}, Vector2.RIGHT, 300, 1.0)
	var resolver := ReentrantResolver.new(timeline, _config())
	var events: Array = timeline.advance(2.0, 301, resolver.reset_and_restart)
	var state: Dictionary = timeline.snapshot()
	if resolver.calls != 1 \
		or not events.is_empty() \
		or int(state.attack_sequence_id) != 2 \
		or int(state.attack_phase) != AttackTimeline.Phase.STARTUP \
		or String((state.payload as Dictionary).attack) != "replacement" \
		or int(state.attack_outcome) != AttackTimeline.Outcome.NONE \
		or int(state.hit_count) != 0 \
		or state.hit_region != "":
		failures.append("resolver reentrancy must not overwrite or advance a replacement attack; events=%s state=%s" % [
			str(events),
			str(state)
		])


func _check_invalid_configs(failures: Array[String]) -> void:
	var invalid_configs: Array[Dictionary] = []
	var missing_active := _config()
	missing_active.erase("active")
	invalid_configs.append(missing_active)
	var zero_startup := _config()
	zero_startup.startup = 0.0
	invalid_configs.append(zero_startup)
	var missing_recovery := _config()
	missing_recovery.recovery.erase("released")
	invalid_configs.append(missing_recovery)
	var invalid_movement := _config()
	invalid_movement.movement_mult.active = -0.1
	invalid_configs.append(invalid_movement)
	var invalid_block := _config()
	invalid_block.blocks_abilities.startup = 1
	invalid_configs.append(invalid_block)
	var invalid_tags := _config()
	invalid_tags.phase_tags.active = ["contact", 4]
	invalid_configs.append(invalid_tags)

	for index: int in invalid_configs.size():
		var timeline: RefCounted = AttackTimeline.new()
		if timeline.start(invalid_configs[index], {}, Vector2.RIGHT, 0, 1.0) or not timeline.is_idle():
			failures.append("invalid config %d should be rejected without changing state" % index)

	var timeline: RefCounted = AttackTimeline.new()
	if timeline.start(_config(), {}, Vector2.ZERO, 0, 1.0) \
		or timeline.start(_config(), {}, Vector2.RIGHT, -1, 1.0) \
		or timeline.start(_config(), {}, Vector2.RIGHT, 0, 0.0):
		failures.append("zero heading, negative tick, and non-positive time scale should be rejected")
	if not timeline.start(_config(), {}, Vector2.RIGHT, 0, 1.0):
		failures.append("valid start should still work after rejected starts")
	var busy_state: Dictionary = timeline.snapshot()
	if timeline.start(_config(), {}, Vector2.UP, 1, 1.0) or timeline.snapshot() != busy_state:
		failures.append("starting while busy should reject without mutating the committed attack")


func _check_public_config_normalization(failures: Array[String]) -> void:
	var normalized: Dictionary = AttackTimeline.normalize_config(_config())
	if normalized.is_empty() \
		or absf(float(normalized.durations.startup) - 0.20) > EPSILON \
		or absf(float(normalized.movement_multipliers.active) - 0.20) > EPSILON \
		or not bool(normalized.ability_blocks.startup) \
		or bool(normalized.recovery_allows_dash_cancel) \
		or normalized.phase_tags.active != ["contact"]:
		failures.append("public config normalization should return the canonical config; got=%s" % str(normalized))
		return

	normalized.durations.startup = 99.0
	(normalized.phase_tags.active as Array).append("mutated")
	var fresh: Dictionary = AttackTimeline.normalize_config(_config())
	if absf(float(fresh.durations.startup) - 0.20) > EPSILON \
		or fresh.phase_tags.active != ["contact"]:
		failures.append("public config normalization must not expose shared mutable internals; got=%s" % str(fresh))

	var invalid := _config()
	invalid.recovery.hit = INF
	if not AttackTimeline.normalize_config(invalid).is_empty():
		failures.append("public config normalization should reject invalid catalog data")


func _check_recovery_dash_cancel_normalization(failures: Array[String]) -> void:
	var default_config := _config()
	var default_normalized: Dictionary = AttackTimeline.normalize_config(default_config)
	if default_normalized.is_empty() \
		or not default_normalized.has("recovery_allows_dash_cancel") \
		or bool(default_normalized.recovery_allows_dash_cancel):
		failures.append("recovery dash cancel should normalize to false by default; got=%s" % [
			str(default_normalized)
		])

	var enabled_config := _config()
	enabled_config.recovery_allows_dash_cancel = true
	var enabled_normalized: Dictionary = AttackTimeline.normalize_config(enabled_config)
	if enabled_normalized.is_empty() \
		or not bool(enabled_normalized.recovery_allows_dash_cancel):
		failures.append("an explicit recovery dash cancel true policy should be preserved; got=%s" % [
			str(enabled_normalized)
		])
	var enabled_timeline: RefCounted = AttackTimeline.new()
	var enabled_probe := ResolverProbe.new({"outcome": "hit"})
	enabled_timeline.start(enabled_config, {}, Vector2.RIGHT, 80, 1.0)
	if enabled_timeline.recovery_allows_dash_cancel():
		failures.append("dash-cancel policy must remain inactive before recovery")
	enabled_timeline.advance(0.31, 81, enabled_probe.resolve)
	if not enabled_timeline.recovery_allows_dash_cancel():
		failures.append("an explicit true dash-cancel policy must be owned by recovery")
	enabled_timeline.reset()
	if enabled_timeline.recovery_allows_dash_cancel():
		failures.append("reset must clear the recovery dash-cancel policy")

	for invalid_value: Variant in [0, 1, "false", null, {}, []]:
		var invalid_config := _config()
		invalid_config.recovery_allows_dash_cancel = invalid_value
		if not AttackTimeline.normalize_config(invalid_config).is_empty():
			failures.append("recovery dash cancel should reject non-boolean value %s" % [
				str(invalid_value)
			])

	var arbitrary_recovery_config := _config()
	arbitrary_recovery_config.recovery = {
		"hit": 7.25,
		"whiff": 0.013,
		"released": 19.5,
		"interrupted": 2.75,
	}
	var arbitrary_normalized: Dictionary = AttackTimeline.normalize_config(
		arbitrary_recovery_config
	)
	if arbitrary_normalized.is_empty() \
		or absf(float(arbitrary_normalized.durations.hit) - 7.25) > EPSILON \
		or absf(float(arbitrary_normalized.durations.whiff) - 0.013) > EPSILON \
		or absf(float(arbitrary_normalized.durations.released) - 19.5) > EPSILON \
		or absf(float(arbitrary_normalized.durations.interrupted) - 2.75) > EPSILON:
		failures.append("pure timeline mechanics must preserve arbitrary positive recovery durations; got=%s" % [
			str(arbitrary_normalized)
		])


func _check_value_only_boundaries(failures: Array[String]) -> void:
	var timeline: RefCounted = AttackTimeline.new()
	var allowed_payload := {
		"nil": null,
		"bool": true,
		"int": 7,
		"float": 2.5,
		"string": "bite",
		"name": &"primary",
		"vector2": Vector2(1.0, 2.0),
		"vector2i": Vector2i(3, 4),
		"vector3": Vector3(1.0, 2.0, 3.0),
		"vector3i": Vector3i(4, 5, 6),
		"vector4": Vector4(1.0, 2.0, 3.0, 4.0),
		"vector4i": Vector4i(5, 6, 7, 8),
		"color": Color(0.1, 0.2, 0.3, 0.4),
		"rect": Rect2(1.0, 2.0, 3.0, 4.0),
		"recti": Rect2i(5, 6, 7, 8),
		"transform2d": Transform2D(0.25, Vector2(3.0, 4.0)),
		"transform3d": Transform3D(Basis.IDENTITY, Vector3(5.0, 6.0, 7.0)),
		"nested": [{"region": &"jaw"}, {"weight": 2}],
	}
	if not timeline.start(_config(), allowed_payload, Vector2.RIGHT, 500, 1.0):
		failures.append("deterministic value-only payload should be accepted")
		return
	(allowed_payload.nested as Array)[0].region = &"mutated"
	var accepted_state: Dictionary = timeline.snapshot()
	if StringName((accepted_state.payload as Dictionary).nested[0].region) != &"jaw":
		failures.append("accepted value-only payload should be defensively copied")
	timeline.reset()

	var signal_source := SignalSource.new()
	var cyclic_array: Array = []
	cyclic_array.append(cyclic_array)
	var rejected_payloads: Array[Dictionary] = [
		{"object": RefCounted.new()},
		{"callable": Callable(self, "_config")},
		{"signal": signal_source.fired},
		{"rid": RID()},
		{"nested": [{"unsafe": RefCounted.new()}]},
		{"cycle": cyclic_array},
		{"not_finite": NAN},
	]
	for index: int in rejected_payloads.size():
		var before: Dictionary = timeline.snapshot()
		if timeline.start(_config(), rejected_payloads[index], Vector2.RIGHT, 510 + index, 1.0) \
			or timeline.snapshot() != before:
			failures.append("unsafe payload %d should reject start without changing state" % index)

	var unsafe_probe := ResolverProbe.new({
		"outcome": "hit",
		"hit_count": 1,
		"hit_region": {"node": RefCounted.new()},
	})
	if not timeline.start(_config(), {"attack": "safe"}, Vector2.RIGHT, 600, 1.0):
		failures.append("valid start should still work after unsafe payload rejection")
		return
	_advance_and_commit(timeline, 0.20, 601, unsafe_probe.resolve)
	var resolved: Dictionary = timeline.snapshot()
	if int(resolved.attack_outcome) != AttackTimeline.Outcome.HIT \
		or int(resolved.hit_count) != 1 \
		or resolved.hit_region != "":
		failures.append("unsafe resolver metadata should degrade without corrupting resolution; state=%s" % str(resolved))


func _deterministic_trace() -> Array[Dictionary]:
	var timeline: RefCounted = AttackTimeline.new()
	var probe := ResolverProbe.new({"outcome": "released", "hit_count": 0, "hit_region": "projectile"})
	var trace: Array[Dictionary] = []
	timeline.start(_config(), {"variant": "air"}, Vector2(3.0, 4.0), 100, 1.25)
	trace.append(timeline.snapshot())
	for delta: float in [0.03, 0.07, 0.11, 0.19, 0.40]:
		timeline.advance(delta, 101 + trace.size(), probe.resolve)
		trace.append(timeline.snapshot())
	trace.append({"resolver_calls": probe.calls})
	return trace


func _advance_and_commit(
	timeline: RefCounted,
	delta: float,
	simulation_tick: int,
	resolver: Callable
) -> Array:
	var events: Array = timeline.advance(delta, simulation_tick, resolver)
	if timeline.time_to_phase_boundary() == 0.0:
		events.append_array(
			timeline.advance_pending_boundary(simulation_tick, resolver)
		)
	return events


func _expect_state(
	timeline: RefCounted,
	expected_phase: int,
	expected_progress: float,
	label: String,
	failures: Array[String]
) -> void:
	var state: Dictionary = timeline.snapshot()
	if int(state.attack_phase) != expected_phase \
		or absf(float(state.phase_t) - expected_progress) > EPSILON:
		failures.append("%s expected phase=%d progress=%.3f, got %s" % [
			label,
			expected_phase,
			expected_progress,
			str(state)
		])


func _config() -> Dictionary:
	return {
		"startup": 0.20,
		"active": 0.10,
		"recovery": {
			"hit": 0.40,
			"whiff": 0.60,
			"released": 0.25,
			"interrupted": 0.50,
		},
		"movement_mult": {
			"startup": 0.50,
			"active": 0.20,
			"recovery": 0.35,
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
	}
