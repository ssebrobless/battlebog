extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const RESULT_SCHEMA := "battle_bog.balance_sim.v1"
const ALL_BOTS_MODE := "All Bots"
const PHYSICS_HZ := 60
const FRAME_FLUSH_INTERVAL_TICKS := 30
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const DEFAULT_BLUE := ["snapping_turtle", "chorus_frog", "mink"]
const DEFAULT_RED := ["snapping_turtle", "chorus_frog", "mink"]
const PLAYABLE_IDS := [
	"snapping_turtle", "chorus_frog", "mink", "beaver", "otter", "leech",
	"owl", "duck", "bullfrog", "cane_toad", "crayfish", "bog_turtle",
	"water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake",
	"alligator", "wolf_spider", "firefly", "mosquito_swarm"
]

var options := {
	"blue": DEFAULT_BLUE.duplicate(),
	"red": DEFAULT_RED.duplicate(),
	"seed": 7,
	"max_seconds": 180.0,
	"checksum_seconds": 30.0,
	"output": "",
	"run_id": "",
	"validate_only": false,
	"profile": false
}
var result_written := false
var profile_buckets_usec: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	PerfStats.enabled = false
	PerfStats.drain()
	var parse_error := _parse_arguments()
	if not parse_error.is_empty():
		_fail("invalid_arguments", parse_error)
		return

	var validation_errors := _validate_options()
	if not validation_errors.is_empty():
		_fail("invalid_arguments", "; ".join(validation_errors))
		return

	if bool(options["validate_only"]):
		var validation_result := _base_result("validation_ok")
		validation_result["validation_only"] = true
		validation_result["integration_checked"] = false
		validation_result["completed"] = false
		validation_result["timed_out"] = false
		_write_and_quit(validation_result, 0)
		return

	var config := get_root().get_node_or_null("GameConfig")
	if config == null:
		_fail("integration_missing", "GameConfig autoload is unavailable")
		return
	if not config.has_method("set_simulation_request"):
		_fail(
			"integration_missing",
			"GameConfig must expose the fail-closed simulation request API"
		)
		return
	if not _object_has_property(config, "simulation_seed"):
		_fail(
			"integration_missing",
			"GameConfig must expose the simulation_seed property"
		)
		return

	config.set("selected_mode", ALL_BOTS_MODE)
	if not bool(config.call("set_simulation_request", options["blue"], options["red"], int(options["seed"]))):
		_fail(
			"invalid_arguments",
			"GameConfig rejected the exact simulation request: %s"
			% str(config.call("get_simulation_request_errors"))
		)
		return
	if _object_has_property(config, "wake_boss"):
		config.set("wake_boss", false)
	if _object_has_property(config, "center_boss"):
		config.set("center_boss", false)

	var scene_error := change_scene_to_file(ARENA_SCENE)
	if scene_error != OK:
		_fail(
			"arena_boot_failed",
			"change_scene_to_file returned error %d" % scene_error
		)
		return
	await process_frame
	await process_frame

	var arena := current_scene
	var integration_error := _validate_arena(arena)
	if not integration_error.is_empty():
		_fail("integration_missing", integration_error)
		return
	_disable_automatic_processing(arena)
	PerfStats.enabled = bool(options["profile"])
	if _object_has_property(arena, "ui_refresh_accumulator"):
		arena.set("ui_refresh_accumulator", -1.0e12)

	var wall_started_msec := Time.get_ticks_msec()
	var max_ticks := int(ceil(float(options["max_seconds"]) * PHYSICS_HZ))
	var checksum_tick_interval := maxi(
		1,
		int(round(float(options["checksum_seconds"]) * PHYSICS_HZ))
	)
	var next_checksum_tick := checksum_tick_interval
	var ticks := 0
	var checksums: Array[Dictionary] = []
	var completed := false
	var fixed_delta := 1.0 / float(PHYSICS_HZ)

	while ticks < max_ticks:
		_advance_fixed_step(arena, fixed_delta)
		ticks += 1
		if current_scene != arena or not is_instance_valid(arena):
			_fail("arena_lost", "Arena scene changed or was freed during simulation")
			return
		if ticks >= next_checksum_tick:
			checksums.append(_checksum_record(arena, ticks))
			next_checksum_tick += checksum_tick_interval
		var match_result: Dictionary = arena.call("get_match_result_state")
		if not match_result.is_empty():
			completed = true
			break
		if ticks % FRAME_FLUSH_INTERVAL_TICKS == 0:
			await process_frame

	if checksums.is_empty() or int(checksums.back().get("tick", -1)) != ticks:
		checksums.append(_checksum_record(arena, ticks))

	var summary: Dictionary
	if completed:
		summary = arena.call("get_match_result_state")
	else:
		summary = arena.call("get_match_summary_data", "", "simulation_timeout")

	var wall_elapsed_msec := maxi(1, Time.get_ticks_msec() - wall_started_msec)
	var output := _base_result("completed" if completed else "timeout")
	output["completed"] = completed
	output["timed_out"] = not completed
	output["validation_only"] = false
	output["integration_checked"] = true
	output["physics_hz"] = PHYSICS_HZ
	output["frame_flush_interval_ticks"] = FRAME_FLUSH_INTERVAL_TICKS
	output["non_physics_processing_disabled"] = true
	output["headless_ui_refresh_disabled"] = true
	output["physics_ticks"] = ticks
	output["simulated_sec"] = _quantize(float(summary.get("elapsed_sec", 0.0)))
	output["wall_elapsed_msec"] = wall_elapsed_msec
	output["simulation_rate_x"] = _quantize(
		float(output["simulated_sec"]) / (float(wall_elapsed_msec) / 1000.0)
	)
	if bool(options["profile"]):
		output["profile"] = _profile_summary(ticks)
		output["arena_profile_usec"] = PerfStats.drain()
	PerfStats.enabled = false
	output["checksums"] = checksums
	output["final_checksum"] = String(checksums.back().get("sha256", ""))
	output["match"] = summary
	_write_and_quit(output, 0)


func _parse_arguments() -> String:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()
	for argument in arguments:
		var value := String(argument)
		if value.begins_with("--bb-blue="):
			options["blue"] = _parse_roster(value.trim_prefix("--bb-blue="))
		elif value.begins_with("--bb-red="):
			options["red"] = _parse_roster(value.trim_prefix("--bb-red="))
		elif value.begins_with("--bb-seed="):
			var parsed_seed := value.trim_prefix("--bb-seed=")
			if not parsed_seed.is_valid_int():
				return "--bb-seed must be an integer"
			options["seed"] = parsed_seed.to_int()
		elif value.begins_with("--bb-max-seconds="):
			var parsed_max := value.trim_prefix("--bb-max-seconds=")
			if not parsed_max.is_valid_float():
				return "--bb-max-seconds must be numeric"
			options["max_seconds"] = parsed_max.to_float()
		elif value.begins_with("--bb-checksum-seconds="):
			var parsed_interval := value.trim_prefix("--bb-checksum-seconds=")
			if not parsed_interval.is_valid_float():
				return "--bb-checksum-seconds must be numeric"
			options["checksum_seconds"] = parsed_interval.to_float()
		elif value.begins_with("--bb-output="):
			options["output"] = value.trim_prefix("--bb-output=")
		elif value.begins_with("--bb-run-id="):
			options["run_id"] = value.trim_prefix("--bb-run-id=")
		elif value == "--bb-validate-only":
			options["validate_only"] = true
		elif value == "--bb-profile":
			options["profile"] = true
	return ""


func _parse_roster(csv: String) -> Array[String]:
	var roster: Array[String] = []
	for part in csv.split(",", false):
		roster.append(part.strip_edges())
	return roster


func _validate_options() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(_validate_roster("Blue", options["blue"]))
	errors.append_array(_validate_roster("Red", options["red"]))
	if int(options["seed"]) < 0:
		errors.append("simulation seed must be zero or greater")
	if float(options["max_seconds"]) <= 0.0:
		errors.append("max simulated duration must be greater than zero")
	if float(options["checksum_seconds"]) <= 0.0:
		errors.append("checksum interval must be greater than zero")
	if String(options["output"]).is_empty():
		errors.append("--bb-output is required")
	if String(options["run_id"]).is_empty():
		options["run_id"] = "seed-%d" % int(options["seed"])
	return errors


func _validate_roster(label: String, roster: Array) -> Array[String]:
	var errors: Array[String] = []
	if roster.size() != 3:
		errors.append("%s roster must contain exactly three creatures" % label)
		return errors
	var seen := {}
	for creature_id_value in roster:
		var creature_id := String(creature_id_value)
		if not PLAYABLE_IDS.has(creature_id):
			errors.append("%s roster contains unknown creature '%s'" % [label, creature_id])
		elif seen.has(creature_id):
			errors.append("%s roster contains duplicate creature '%s'" % [label, creature_id])
		seen[creature_id] = true
	return errors


func _validate_arena(arena: Node) -> String:
	if arena == null:
		return "Arena did not become the current scene"
	if not arena.has_method("get_match_summary_data") \
		or not arena.has_method("get_match_result_state") \
		or not arena.has_method("get_match_slot_state"):
		return "Arena must expose summary, result, and slot-state APIs"
	var summary: Dictionary = arena.call("get_match_summary_data")
	if String(summary.get("control_topology_id", "")) != "all_bots":
		return "All Bots mode did not resolve the all_bots control topology"
	if int(summary.get("simulation_seed", -1)) != int(options["seed"]):
		return "resolved simulation seed does not match the exact request"
	var slot_state: Dictionary = arena.call("get_match_slot_state")
	var controllers: Array = slot_state.get("controllers", [])
	if controllers.size() != 6:
		return "All Bots mode must register exactly six controllers"
	for controller_value in controllers:
		var controller: Dictionary = controller_value
		if String(controller.get("kind", "")) != "ai":
			return "All Bots mode must assign AI control to all six slots"
	var resolved: Dictionary = summary.get("resolved_rosters", {})
	if not resolved.is_empty():
		if Array(resolved.get("blue", [])) != Array(options["blue"]):
			return "resolved Blue roster does not match the exact request"
		if Array(resolved.get("red", [])) != Array(options["red"]):
			return "resolved Red roster does not match the exact request"
	return ""


func _disable_automatic_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_automatic_processing(child)


func _advance_fixed_step(arena: Node, delta: float) -> void:
	var arena_started := Time.get_ticks_usec() if bool(options["profile"]) else 0
	arena.call("_physics_process", delta)
	_profile_add("arena", arena_started)
	if not arena.call("get_match_result_state").is_empty():
		return
	# Gameplay actors, projectiles, summons, huts, food, and bosses are direct
	# Arena children. Preserve scene-tree order and avoid a recursive wildcard
	# scan plus sort on every simulated tick.
	for node: Node in arena.get_children():
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.has_method("_physics_process"):
			var node_started := Time.get_ticks_usec() if bool(options["profile"]) else 0
			node.call("_physics_process", delta)
			var script: Script = node.get_script()
			var bucket := script.resource_path.get_file().get_basename() if script != null else node.get_class()
			_profile_add("node:%s" % bucket, node_started)


func _profile_add(bucket: String, started_usec: int) -> void:
	if not bool(options["profile"]):
		return
	profile_buckets_usec[bucket] = int(profile_buckets_usec.get(bucket, 0)) + Time.get_ticks_usec() - started_usec


func _profile_summary(ticks: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for bucket in profile_buckets_usec:
		var total_usec := int(profile_buckets_usec[bucket])
		rows.append({
			"bucket": String(bucket),
			"total_ms": _quantize(float(total_usec) / 1000.0),
			"avg_ms_per_tick": _quantize(float(total_usec) / 1000.0 / maxf(float(ticks), 1.0))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0))
	)
	return rows


func _checksum_record(arena: Node, tick: int) -> Dictionary:
	var state := _stable_arena_state(arena, tick)
	var canonical_json := JSON.stringify(_canonicalize(state), "", false)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_json.to_utf8_buffer())
	return {
		"tick": tick,
		"simulated_sec": _quantize(float(tick) / PHYSICS_HZ),
		"sha256": context.finish().hex_encode()
	}


func _stable_arena_state(arena: Node, tick: int) -> Dictionary:
	var summary: Dictionary = arena.call("get_match_summary_data")
	var rng: RandomNumberGenerator = arena.get("match_rng")
	return {
		"tick": tick,
		"arena_simulation_tick": int(arena.call("get_simulation_tick")) if arena.has_method("get_simulation_tick") else tick,
		"simulation_seed": int(summary.get("simulation_seed", -1)),
		"match_rng_state": int(rng.state) if rng != null else 0,
		"elapsed_sec": _quantize(float(summary.get("elapsed_sec", 0.0))),
		"teams": summary.get("teams", {}),
		"balance_deltas": summary.get("balance_deltas", {}),
		"economy_events": summary.get("economy_events", []),
		"slots": _stable_slot_state(arena),
		"boss_progress": (
			arena.call("get_boss_progress_state")
			if arena.has_method("get_boss_progress_state")
			else {}
		),
		"center_boss": (
			arena.call("get_center_boss_state")
			if arena.has_method("get_center_boss_state")
			else {}
		),
		"breeding_blue": (
			arena.call("get_breeding_queue_state", 0)
			if arena.has_method("get_breeding_queue_state")
			else {}
		),
		"breeding_red": (
			arena.call("get_breeding_queue_state", 1)
			if arena.has_method("get_breeding_queue_state")
			else {}
		)
	}


func _stable_slot_state(arena: Node) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var state: Dictionary = arena.call("get_match_slot_state")
	var controller_by_slot := {}
	for controller_value in state.get("controllers", []):
		var controller: Dictionary = controller_value
		controller_by_slot[String(controller.get("slot_id", ""))] = String(
			controller.get("kind", "")
		)
	for team_key in ["blue", "red"]:
		for slot_value in state.get(team_key, []):
			var slot: Dictionary = slot_value
			var actor: Node = slot.get("actor", null)
			var slot_id := String(slot.get("slot_id", ""))
			var stock_state: Dictionary = {}
			if arena.get("stock_manager") != null:
				stock_state = arena.get("stock_manager").call(
					"get_slot",
					int(slot.get("team", -1)),
					int(slot.get("slot_index", -1))
				)
			var row := {
				"slot_id": slot_id,
				"team": int(slot.get("team", -1)),
				"slot_index": int(slot.get("slot_index", -1)),
				"creature_id": String(slot.get("creature_id", "")),
				"controller": String(controller_by_slot.get(slot_id, "")),
				"stocks_remaining": int(stock_state.get("stocks_remaining", 0)),
				"stock_state": String(stock_state.get("state", ""))
			}
			if actor != null and is_instance_valid(actor):
				row["position"] = actor.global_position if actor is Node2D else Vector2.ZERO
				row["health"] = _quantize(float(actor.get("health")))
				row["hunger"] = _quantize(float(actor.get("hunger")))
				row["hunger_satiated"] = bool(actor.get("hunger_satiated"))
				row["actor_state"] = int(actor.get("state"))
				row["alive"] = bool(actor.call("is_alive")) if actor.has_method("is_alive") else true
			output.append(row)
	return output


func _canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var keys: Array = source.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var output := {}
			for key in keys:
				output[str(key)] = _canonicalize(source[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item in value:
				output.append(_canonicalize(item))
			return output
		TYPE_VECTOR2:
			return {
				"x": _quantize(value.x),
				"y": _quantize(value.y)
			}
		TYPE_FLOAT:
			return _quantize(float(value))
		TYPE_OBJECT:
			return null
		_:
			return value


func _quantize(value: float) -> float:
	return round(value * 1000.0) / 1000.0


func _object_has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _base_result(status: String) -> Dictionary:
	return {
		"schema": RESULT_SCHEMA,
		"run_id": String(options["run_id"]),
		"status": status,
		"requested": {
			"blue_roster": Array(options["blue"]).duplicate(),
			"red_roster": Array(options["red"]).duplicate(),
			"simulation_seed": int(options["seed"]),
			"max_simulated_sec": float(options["max_seconds"]),
			"checksum_interval_sec": float(options["checksum_seconds"])
		}
	}


func _fail(status: String, message: String) -> void:
	var output := _base_result(status)
	output["completed"] = false
	output["timed_out"] = false
	output["error"] = message
	_write_and_quit(output, 2)


func _write_and_quit(output: Dictionary, exit_code: int) -> void:
	if result_written:
		return
	result_written = true
	var output_path := String(options["output"])
	var parent := output_path.get_base_dir()
	if not parent.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(parent)
		if directory_error != OK:
			printerr(
				"BB_SIM_ERROR could not create output directory '%s': %d"
				% [parent, directory_error]
			)
			quit(3)
			return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr(
			"BB_SIM_ERROR could not open output '%s': %d"
			% [output_path, FileAccess.get_open_error()]
		)
		quit(3)
		return
	var json_line := JSON.stringify(_canonicalize(output), "", false)
	file.store_line(json_line)
	file.close()
	print("BB_SIM_RESULT %s" % json_line)
	quit(exit_code)
