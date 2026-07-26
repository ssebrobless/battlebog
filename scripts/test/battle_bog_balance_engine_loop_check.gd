extends SceneTree

const RUNNER_PATH := "res://scripts/test/run_balance_sim.gd"
const OBSERVER_PRIORITY := 2147483647
const CHECKSUM_TEST_ROSTER := "snapping_turtle,chorus_frog,mink"
const CHECKSUM_TEST_SECONDS := "0.016"

var failures: Array[String] = []
var probe_ticks := 0
var observer_ticks := 0
var queued_probe_seen_on_next_tick := false
var probe: CharacterBody2D
var observer: Node
var test_phase := ""
var freeze_arena: Node
var freeze_completion_observed := false


class PhysicsProbe:
	extends CharacterBody2D

	signal physics_ran(tick: int, in_physics_frame: bool)

	var ticks := 0

	func _physics_process(_delta: float) -> void:
		ticks += 1
		velocity = Vector2(60.0, 0.0)
		move_and_slide()
		physics_ran.emit(ticks, Engine.is_in_physics_frame())


class FinalObserver:
	extends Node

	signal observed(tick: int)

	var ticks := 0

	func _physics_process(_delta: float) -> void:
		ticks += 1
		observed.emit(ticks)


class FreezeArenaAnalogue:
	extends Node

	var ticks := 0
	var frozen := false

	func _physics_process(_delta: float) -> void:
		ticks += 1
		if ticks != 2:
			return
		frozen = true
		for child: Node in get_children():
			child.process_mode = Node.PROCESS_MODE_DISABLED
		set_physics_process(false)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_runner_source_contract()
	await _run_baseline_engine_loop_check()
	await _run_completion_freeze_check()
	_run_gameplay_checksum_check()

	if failures.is_empty():
		print("BATTLE_BOG_BALANCE_ENGINE_LOOP_CHECK PASS")
	else:
		for failure in failures:
			printerr("BATTLE_BOG_BALANCE_ENGINE_LOOP_CHECK FAIL: %s" % failure)
	paused = false
	quit(0 if failures.is_empty() else 1)


func _run_baseline_engine_loop_check() -> void:
	paused = true
	test_phase = "baseline"
	probe_ticks = 0
	observer_ticks = 0
	queued_probe_seen_on_next_tick = false

	probe = PhysicsProbe.new()
	probe.name = "PhysicsProbe"
	get_root().add_child(probe)
	probe.physics_ran.connect(_on_probe_physics)

	observer = FinalObserver.new()
	observer.name = "FinalObserver"
	observer.process_physics_priority = OBSERVER_PRIORITY
	get_root().add_child(observer)
	observer.observed.connect(_on_observer_physics)

	paused = false
	while observer_ticks < 3:
		await observer.observed
	await physics_frame
	paused = true
	await process_frame

	_expect(probe_ticks == 3, "probe must receive exactly three engine physics ticks")
	_expect(observer_ticks == 3, "observer must receive exactly three engine physics ticks")
	_expect(
		is_equal_approx(probe.position.x, 3.0),
		"move_and_slide must advance through real 60 Hz physics; x=%s" % probe.position.x
	)
	_expect(
		queued_probe_seen_on_next_tick,
		"queue_free must remove the disposable node before the following physics tick"
	)
	probe.free()
	observer.free()
	probe = null
	observer = null


func _run_completion_freeze_check() -> void:
	paused = true
	test_phase = "freeze"
	probe_ticks = 0
	observer_ticks = 0
	freeze_completion_observed = false

	freeze_arena = FreezeArenaAnalogue.new()
	freeze_arena.name = "FreezeArenaAnalogue"
	get_root().add_child(freeze_arena)

	probe = PhysicsProbe.new()
	probe.name = "FrozenArenaChild"
	freeze_arena.add_child(probe)
	probe.physics_ran.connect(_on_probe_physics)

	var trapped_observer := FinalObserver.new()
	trapped_observer.name = "ArenaChildObserver"
	trapped_observer.process_physics_priority = OBSERVER_PRIORITY
	freeze_arena.add_child(trapped_observer)

	observer = FinalObserver.new()
	observer.name = "RootExternalObserver"
	observer.process_physics_priority = OBSERVER_PRIORITY
	get_root().add_child(observer)
	observer.observed.connect(_on_observer_physics)

	paused = false
	while not freeze_completion_observed:
		await observer.observed
	await physics_frame
	paused = true
	await process_frame

	_expect(
		freeze_arena.frozen,
		"freeze analogue must execute its Arena-style direct-child freeze"
	)
	_expect(
		int(freeze_arena.ticks) == 2,
		"freeze analogue must stop at its completing tick"
	)
	_expect(
		trapped_observer.ticks == 1,
		"an Arena-child observer must demonstrate the original freeze failure"
	)
	_expect(
		observer_ticks == 2 and freeze_completion_observed,
		"root observer must report the completing tick after Arena children freeze"
	)
	_expect(
		observer.get_parent() == get_root(),
		"completion observer must remain outside the frozen Arena subtree"
	)
	observer.free()
	freeze_arena.free()
	observer = null
	freeze_arena = null
	probe = null


func _check_runner_source_contract() -> void:
	var file := FileAccess.open(RUNNER_PATH, FileAccess.READ)
	if file == null:
		failures.append("could not read %s" % RUNNER_PATH)
		return
	var source := file.get_as_text()
	file.close()
	_expect(
		source.contains('output["simulation_loop"] = "engine_physics"'),
		"runner must label production output as engine_physics"
	)
	_expect(
		source.contains("await observer.tick_completed"),
		"runner must wait for engine-completed physics ticks"
	)
	_expect(
		source.contains("await physics_frame"),
		"runner must settle each captured tick at the following physics boundary"
	)
	_expect(
		source.contains("process_physics_priority = ENGINE_OBSERVER_PRIORITY"),
		"runner observer must execute after gameplay physics callbacks"
	)
	_expect(
		source.contains("get_root().add_child(observer)"),
		"runner observer must be parented outside Arena"
	)
	_expect(
		not source.contains("arena.add_child(observer)"),
		"runner observer must not be vulnerable to Arena child freezing"
	)
	_expect(
		not source.contains('arena.call("_physics_process"'),
		"runner must not invoke Arena physics manually"
	)
	_expect(
		not source.contains('node.call("_physics_process"'),
		"runner must not invoke child physics manually"
	)
	_expect(
		not source.contains("set_physics_process(false)"),
		"runner must not disable gameplay physics processing"
	)
	_expect(
		source.contains('output["gameplay_checksums"] = gameplay_checksums'),
		"runner must emit an additive gameplay-only checksum series"
	)
	_expect(
		source.contains('output["final_gameplay_checksum"]'),
		"runner must emit an additive final gameplay-only checksum"
	)
	_expect(
		source.contains('state.erase("simulation_seed")')
		and source.contains('state.erase("match_rng_state")'),
		"gameplay-only state must exclude explicit seed and inert RNG state"
	)


func _run_gameplay_checksum_check() -> void:
	var seed_7_a := _run_checksum_case("seed7-a", 7, false)
	var seed_7_b := _run_checksum_case("seed7-b", 7, false)
	var seed_101 := _run_checksum_case("seed101", 101, false)
	var boss_seed_7 := _run_checksum_case("boss-seed7", 7, true)
	var boss_seed_101 := _run_checksum_case("boss-seed101", 101, true)
	if (
		seed_7_a.is_empty()
		or seed_7_b.is_empty()
		or seed_101.is_empty()
		or boss_seed_7.is_empty()
		or boss_seed_101.is_empty()
	):
		return

	_expect(
		String(seed_7_a.get("final_checksum", ""))
		== String(seed_7_b.get("final_checksum", "")),
		"same-seed canonical checksums must repeat exactly"
	)
	_expect(
		String(seed_7_a.get("final_gameplay_checksum", ""))
		== String(seed_7_b.get("final_gameplay_checksum", "")),
		(
			"same-seed gameplay checksums must repeat exactly; %s"
			% _checksum_difference(seed_7_a, seed_7_b)
		)
	)
	_expect(
		String(seed_7_a.get("final_checksum", ""))
		!= String(seed_101.get("final_checksum", "")),
		"legacy canonical checksums must retain seed-sensitive replay identity"
	)
	_expect(
		String(seed_7_a.get("final_gameplay_checksum", ""))
		== String(seed_101.get("final_gameplay_checksum", "")),
		(
			"different seeds must share a gameplay hash before RNG changes gameplay; %s"
			% _checksum_difference(seed_7_a, seed_101)
		)
	)
	_expect(
		String(boss_seed_7.get("final_gameplay_checksum", ""))
		!= String(boss_seed_101.get("final_gameplay_checksum", "")),
		"gameplay hashes must diverge after seeded center-boss selection"
	)
	var boss_7_family := _first_boss_family(boss_seed_7)
	var boss_101_family := _first_boss_family(boss_seed_101)
	_expect(
		not boss_7_family.is_empty()
		and not boss_101_family.is_empty()
		and boss_7_family != boss_101_family,
		"forced RNG runs must select distinct center-boss families; seed7=%s seed101=%s"
		% [boss_7_family, boss_101_family]
	)
	var boss_7_state: Dictionary = boss_seed_7.get("match", {}).get(
		"balance_telemetry",
		{}
	)
	var boss_101_state: Dictionary = boss_seed_101.get("match", {}).get(
		"balance_telemetry",
		{}
	)
	_expect(
		not boss_7_state.is_empty() and not boss_101_state.is_empty(),
		"forced RNG runs must retain normal additive match telemetry"
	)


func _run_checksum_case(label: String, seed: int, force_center_boss: bool) -> Dictionary:
	var output_path := ProjectSettings.globalize_path(
		"user://battle_bog_%s_%d.jsonl" % [label, OS.get_process_id()]
	)
	DirAccess.remove_absolute(output_path)
	var arguments := PackedStringArray([
		"--headless",
		"--disable-render-loop",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--fixed-fps",
		"60",
		"--script",
		RUNNER_PATH,
		"--",
		"--bb-blue=%s" % CHECKSUM_TEST_ROSTER,
		"--bb-red=%s" % CHECKSUM_TEST_ROSTER,
		"--bb-seed=%d" % seed,
		"--bb-max-seconds=%s" % CHECKSUM_TEST_SECONDS,
		"--bb-checksum-seconds=1",
		"--bb-output=%s" % output_path,
		"--bb-run-id=%s" % label
	])
	if force_center_boss:
		arguments.append("--bb-force-center-boss-tick=1")
	var child_output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		arguments,
		child_output,
		true
	)
	_expect(
		exit_code == 0,
		"runner case %s must exit zero; output=%s"
		% [label, "\n".join(child_output)]
	)
	if exit_code != 0:
		DirAccess.remove_absolute(output_path)
		return {}
	if not FileAccess.file_exists(output_path):
		failures.append("runner case %s did not write a result" % label)
		return {}
	var text := FileAccess.get_file_as_string(output_path).strip_edges()
	DirAccess.remove_absolute(output_path)
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "runner case %s must write valid JSON" % label)
	if not parsed is Dictionary:
		return {}
	var record: Dictionary = parsed
	_expect(
		String(record.get("schema", "")) == "battle_bog.balance_sim.v1",
		"runner case %s must preserve the v1 schema" % label
	)
	_expect(
		Array(record.get("checksums", [])).size() == 1
		and Array(record.get("gameplay_checksums", [])).size() == 1,
		"runner case %s must emit paired canonical and gameplay hashes" % label
	)
	return record


func _first_boss_family(record: Dictionary) -> String:
	var telemetry: Dictionary = record.get("match", {}).get(
		"balance_telemetry",
		{}
	)
	for event_value in telemetry.get("boss_lifecycle_events", []):
		var event: Dictionary = event_value
		if bool(event.get("center", false)) and String(event.get("event", "")) == "active":
			return String(event.get("family", ""))
	return ""


func _checksum_difference(left: Dictionary, right: Dictionary) -> String:
	var left_record: Dictionary = Array(left.get("gameplay_checksums", []))[0]
	var right_record: Dictionary = Array(right.get("gameplay_checksums", []))[0]
	return (
		"left=%s right=%s sections=%s/%s"
		% [
			String(left_record.get("sha256", "")),
			String(right_record.get("sha256", "")),
			str(left_record.get("section_sha256", {})),
			str(right_record.get("section_sha256", {}))
		]
	)


func _on_probe_physics(tick: int, in_physics_frame: bool) -> void:
	probe_ticks = tick
	_expect(in_physics_frame, "probe physics callback must run inside a physics frame")
	if test_phase == "baseline" and tick == 1:
		var disposable := Node.new()
		disposable.name = "DeferredDeletionProbe"
		get_root().add_child(disposable)
		disposable.queue_free()
	elif test_phase == "baseline" and tick == 2:
		queued_probe_seen_on_next_tick = (
			get_root().get_node_or_null("DeferredDeletionProbe") == null
		)


func _on_observer_physics(tick: int) -> void:
	observer_ticks = tick
	if test_phase == "baseline":
		_expect(
			probe_ticks == tick,
			"final-priority observer tick %d ran before probe tick %d"
			% [tick, probe_ticks]
		)
	elif (
		test_phase == "freeze"
		and freeze_arena != null
		and freeze_arena.frozen
	):
		freeze_completion_observed = true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
