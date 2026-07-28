extends SceneTree

const SnapshotScript := preload(
	"res://scripts/sim/presentation/creature_presentation_snapshot.gd"
)
const CreatureScript := preload("res://scripts/sim/creature.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const SCHEMA_PATH := "res://data/battle_bog_presentation_schema.json"
const EPSILON := 0.00001


class TestArena:
	extends Node

	var simulation_tick := 0
	var match_over := false
	var entities: Array[Node] = []
	var cores := {}

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func get_terrain_zone(_point: Vector2) -> String:
		return "land"

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func clamp_to_arena(point: Vector2) -> Vector2:
		return point

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

	func unregister_entity(entity: Node) -> void:
		entities.erase(entity)

	func register_entity(entity: Node) -> void:
		if not entities.has(entity):
			entities.append(entity)

	func record_vfx_event(_event: Dictionary) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var schema := _load_schema(failures)
	if not schema.is_empty():
		_check_schema(schema, failures)
		_check_snapshot_ownership(schema, failures)
		_check_invalid_inputs(schema, failures)
		_check_json_conversion(schema, failures)
		_check_render_feedback(schema, failures)
		_check_creature_integration(schema, failures)
		_check_fixture_identity_and_latch(failures)

	print("creature_presentation_snapshot failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _load_schema(failures: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(SCHEMA_PATH):
		failures.append("presentation schema is missing at %s" % SCHEMA_PATH)
		return {}
	var file := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	if file == null:
		failures.append("presentation schema could not be opened")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("presentation schema must parse as a JSON object")
		return {}
	return parsed


func _check_schema(schema: Dictionary, failures: Array[String]) -> void:
	var expected_root := _string_set(SnapshotScript.ROOT_FIELDS)
	var declared_root := _string_set(
		(schema.get("root_fields", {}) as Dictionary).keys()
	)
	if declared_root != expected_root:
		failures.append("schema root_fields must exactly match snapshot ROOT_FIELDS")

	var expected_actions := _string_set(SnapshotScript.ACTION_FIELDS)
	var declared_actions := _string_set(
		(schema.get("action_fields", {}) as Dictionary).keys()
	)
	if declared_actions != expected_actions:
		failures.append("schema action_fields must exactly match snapshot ACTION_FIELDS")

	var declared_shapes: Dictionary = schema.get("projected_shapes", {})
	if _string_set(declared_shapes.keys()) != _string_set(
		SnapshotScript.SHAPE_FIELDS.keys()
	):
		failures.append("schema projected-shape kinds must be closed")
	else:
		for kind: Variant in SnapshotScript.SHAPE_FIELDS:
			var expected_fields := _string_set(SnapshotScript.SHAPE_FIELDS[kind])
			var declared_fields := _string_set(
				(declared_shapes.get(String(kind), {}) as Dictionary).keys()
			)
			if declared_fields != expected_fields:
				failures.append(
					"schema shape %s must contain exactly its declared fields"
					% String(kind)
				)

	if not schema.has("legacy_motion_state") \
			or (schema.get("legacy_motion_state") as Dictionary).is_empty():
		failures.append("schema must declare the exact legacy motion-state key set")

	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		failures.append("CreatureCatalog autoload is unavailable")
	elif not catalog.has_method("get_presentation_schema"):
		failures.append("CreatureCatalog must expose get_presentation_schema")
	else:
		var catalog_schema: Dictionary = catalog.get_presentation_schema()
		if catalog_schema != schema:
			failures.append("CreatureCatalog must load the canonical presentation schema")
		if catalog.has_method("get_presentation_schema_errors") \
				and not catalog.get_presentation_schema_errors().is_empty():
			failures.append(
				"CreatureCatalog rejected canonical schema: %s"
				% str(catalog.get_presentation_schema_errors())
			)


func _check_snapshot_ownership(
	schema: Dictionary,
	failures: Array[String]
) -> void:
	var source := _valid_data()
	var snapshot: RefCounted = SnapshotScript.create(source, schema)
	if snapshot == null:
		failures.append(
			"canonical snapshot fixture was rejected: %s"
			% str(SnapshotScript.validation_errors(source, schema))
		)
		return

	source[&"world_position_px"] = Vector2(999.0, 999.0)
	source[&"active_actions"][0][&"projected_shape"][&"radius_px"] = 999.0
	source[&"kit_cues"][&"legacy"][&"surface_walk"][&"nested"][0] = 999
	var first: Dictionary = snapshot.to_dictionary()
	if first[&"world_position_px"] != Vector2(10.0, 20.0) \
			or float(
				first[&"active_actions"][0][&"projected_shape"][&"radius_px"]
			) != 18.0 \
			or int(
				first[&"kit_cues"][&"legacy"][&"surface_walk"][&"nested"][0]
			) != 1:
		failures.append("snapshot construction must deep-copy nested input")

	first[&"resources"][&"mosquito_blood_ratio"] = 0.99
	first[&"active_actions"][0][&"projected_shape"][&"origin_px"] = Vector2.ZERO
	first[&"kit_cues"][&"legacy"][&"surface_walk"][&"nested"][1] = 999
	var second: Dictionary = snapshot.to_dictionary()
	if absf(float(second[&"resources"][&"mosquito_blood_ratio"]) - 0.25) > EPSILON \
			or second[&"active_actions"][0][&"projected_shape"][&"origin_px"] \
			!= Vector2(12.0, 20.0) \
			or int(
				second[&"kit_cues"][&"legacy"][&"surface_walk"][&"nested"][1]
			) != 2:
		failures.append("to_dictionary must return a deep mutable copy")

	var actions: Array = snapshot.get_active_actions()
	actions[0][&"variant"] = &"mutated"
	if snapshot.get_active_actions()[0][&"variant"] != &"primary":
		failures.append("nested getter output must not mutate snapshot ownership")

	if snapshot.get_actor_id() != &"fixture:presentation:0" \
			or snapshot.get_creature_id() != &"alligator" \
			or snapshot.get_body_heading() != Vector2.RIGHT:
		failures.append("typed snapshot getters returned incorrect canonical data")


func _check_invalid_inputs(
	schema: Dictionary,
	failures: Array[String]
) -> void:
	var cases: Array[Dictionary] = []

	var extra := _valid_data()
	extra[&"undeclared"] = true
	cases.append({"name": "extra root key", "data": extra})

	var wrong_type := _valid_data()
	wrong_type[&"alive"] = 1
	cases.append({"name": "wrong field type", "data": wrong_type})

	var zero_heading := _valid_data()
	zero_heading[&"body_heading"] = Vector2.ZERO
	cases.append({"name": "zero heading", "data": zero_heading})

	var non_finite := _valid_data()
	non_finite[&"speed_px_per_sec"] = INF
	cases.append({"name": "non-finite value", "data": non_finite})

	var object_value := _valid_data()
	object_value[&"kit_cues"][&"legacy"][&"surface_walk"] = RefCounted.new()
	cases.append({"name": "object leaf", "data": object_value})

	var callable_value := _valid_data()
	callable_value[&"kit_cues"][&"legacy"][&"surface_walk"] = Callable(
		self,
		"_valid_data"
	)
	cases.append({"name": "callable leaf", "data": callable_value})

	var extra_action := _valid_data()
	extra_action[&"active_actions"][0][&"undeclared"] = true
	cases.append({"name": "extra action key", "data": extra_action})

	var extra_shape := _valid_data()
	extra_shape[&"active_actions"][0][&"projected_shape"][&"undeclared"] = true
	cases.append({"name": "extra shape key", "data": extra_shape})

	var unknown_enum := _valid_data()
	unknown_enum[&"locomotion_state"] = &"moonwalk"
	cases.append({"name": "unknown locomotion value", "data": unknown_enum})

	var unknown_team := _valid_data()
	unknown_team[&"team"] = 7
	cases.append({"name": "unknown team value", "data": unknown_team})

	var unknown_action := _valid_data()
	unknown_action[&"active_actions"][0][&"action_id"] = &"unknown_action"
	cases.append({"name": "unknown action value", "data": unknown_action})

	var unknown_phase := _valid_data()
	unknown_phase[&"active_actions"][0][&"phase"] = &"unknown_phase"
	cases.append({"name": "unknown action phase", "data": unknown_phase})

	var unknown_outcome := _valid_data()
	unknown_outcome[&"active_actions"][0][&"outcome"] = &"unknown_outcome"
	cases.append({"name": "unknown action outcome", "data": unknown_outcome})

	var unknown_transition := _valid_data()
	unknown_transition[&"transition_kind"] = &"teleport"
	cases.append({"name": "unknown transition value", "data": unknown_transition})

	var unknown_elevation := _valid_data()
	unknown_elevation[&"elevation_state"] = &"orbiting"
	cases.append({"name": "unknown elevation value", "data": unknown_elevation})

	var unknown_surface := _valid_data()
	unknown_surface[&"surface"] = &"lava"
	cases.append({"name": "unknown surface value", "data": unknown_surface})

	var unknown_footprint := _valid_data()
	unknown_footprint[&"footprint_kind"] = &"triangle"
	cases.append({"name": "unknown footprint value", "data": unknown_footprint})

	var unknown_stealth := _valid_data()
	unknown_stealth[&"stealth_state"] = &"invisible_forever"
	cases.append({"name": "unknown stealth value", "data": unknown_stealth})

	var unknown_latch := _valid_data()
	unknown_latch[&"latch_role"] = &"spectator"
	cases.append({"name": "unknown latch role", "data": unknown_latch})

	var unknown_weakpoint := _valid_data()
	unknown_weakpoint[&"weakpoint_state"] = &"missing"
	cases.append({"name": "unknown weakpoint state", "data": unknown_weakpoint})

	var unknown_resource := _valid_data()
	unknown_resource[&"resources"][&"unknown_resource"] = 0.0
	cases.append({"name": "unknown resource key", "data": unknown_resource})

	var unknown_cue_namespace := _valid_data()
	unknown_cue_namespace[&"kit_cues"][&"unknown_namespace"] = {}
	cases.append({
		"name": "unknown kit-cue namespace",
		"data": unknown_cue_namespace,
	})

	var unknown_cue_key := _valid_data()
	unknown_cue_key[&"kit_cues"][&"legacy"][&"unknown_cue"] = true
	cases.append({"name": "unknown kit-cue key", "data": unknown_cue_key})

	var integer_float := _valid_data()
	integer_float[&"speed_px_per_sec"] = 30
	cases.append({"name": "integer in float field", "data": integer_float})

	var duplicate_action := _valid_data()
	duplicate_action[&"active_actions"].append(
		duplicate_action[&"active_actions"][0].duplicate(true)
	)
	cases.append({"name": "duplicate action identity", "data": duplicate_action})

	var cycle := _valid_data()
	var cyclic_array: Array = []
	cyclic_array.append(cyclic_array)
	cycle[&"kit_cues"][&"legacy"][&"surface_walk"] = cyclic_array
	cases.append({"name": "cyclic value", "data": cycle})

	for test_case: Dictionary in cases:
		var data: Dictionary = test_case["data"]
		var errors: Array[String] = SnapshotScript.validation_errors(data, schema)
		if errors.is_empty() or SnapshotScript.create(data, schema) != null:
			failures.append(
				"snapshot must reject %s" % String(test_case["name"])
			)

	var altered_schema := schema.duplicate(true)
	altered_schema["vocabularies"]["locomotion_states"].append("moonwalk")
	if SnapshotScript.create(_valid_data(), altered_schema) != null:
		failures.append("snapshot must reject altered schema declarations")
	var mutable_schema := schema.duplicate(true)
	if SnapshotScript.create(_valid_data(), mutable_schema) == null:
		failures.append("canonical schema duplicate must construct before mutation")
	else:
		mutable_schema["vocabularies"]["locomotion_states"].append("moonwalk")
		var mutated_schema_data := _valid_data()
		mutated_schema_data[&"locomotion_state"] = &"moonwalk"
		if SnapshotScript.create(mutated_schema_data, mutable_schema) != null:
			failures.append(
				"schema mutation after a successful construction must be rejected"
			)

	var valid_shapes: Array[Dictionary] = [
		{&"kind": &"none"},
		{&"kind": &"point", &"point_px": Vector2(1.0, 2.0)},
		{
			&"kind": &"circle",
			&"center_px": Vector2(1.0, 2.0),
			&"radius_px": 4.0,
		},
		{
			&"kind": &"capsule",
			&"center_px": Vector2(1.0, 2.0),
			&"axis": Vector2.RIGHT,
			&"radius_px": 4.0,
			&"half_length_px": 8.0,
		},
		{
			&"kind": &"arc",
			&"origin_px": Vector2(1.0, 2.0),
			&"heading": Vector2.RIGHT,
			&"radius_px": 4.0,
			&"half_angle_rad": 0.5,
		},
		{
			&"kind": &"line",
			&"start_px": Vector2.ZERO,
			&"end_px": Vector2.RIGHT,
			&"half_width_px": 2.0,
		},
		{
			&"kind": &"rect",
			&"center_px": Vector2.ZERO,
			&"heading": Vector2.RIGHT,
			&"half_extents_px": Vector2(2.0, 3.0),
		},
	]
	for shape: Dictionary in valid_shapes:
		var shape_data := _valid_data()
		shape_data[&"active_actions"][0][&"projected_shape"] = shape
		if SnapshotScript.create(shape_data, schema) == null:
			failures.append(
				"snapshot must accept projected shape %s"
				% String(shape[&"kind"])
			)


func _check_json_conversion(
	schema: Dictionary,
	failures: Array[String]
) -> void:
	var data := _valid_data()
	data[&"kit_cues"][&"legacy"][&"surface_walk"] = {
		&"name": &"value",
		&"point": Vector2(3.0, 4.0),
		&"color": Color(0.1, 0.2, 0.3, 0.4),
		&"path": PackedVector2Array([Vector2(1.0, 2.0), Vector2(5.0, 8.0)]),
	}
	var snapshot: RefCounted = SnapshotScript.create(data, schema)
	if snapshot == null:
		failures.append("JSON conversion fixture must construct")
		return
	var converted: Dictionary = snapshot.to_json_dictionary()
	var invalid_paths: Array[String] = []
	_collect_non_json_values(converted, "root", invalid_paths)
	if not invalid_paths.is_empty():
		failures.append(
			"to_json_dictionary contains non-JSON values: %s"
			% str(invalid_paths)
		)
	var json_text := JSON.stringify(converted)
	if json_text.is_empty() or JSON.parse_string(json_text) == null:
		failures.append("to_json_dictionary output must stringify and parse")


func _check_render_feedback(
	schema: Dictionary,
	failures: Array[String]
) -> void:
	var snapshot: RefCounted = SnapshotScript.create(_valid_data(), schema)
	if snapshot == null:
		failures.append("render-feedback fixture must construct")
		return

	if snapshot.with_render_feedback(0, 0.0, 0) != snapshot:
		failures.append("unchanged feedback with the same revision must preserve identity")
	if snapshot.with_render_feedback(0, 0.0, 1) != null:
		failures.append("unchanged feedback must not advance render_revision")
	if snapshot.with_render_feedback(1, 0.5, 0) != null:
		failures.append("changed feedback must require a newer revision")

	var derived: RefCounted = snapshot.with_render_feedback(1, 0.5, 1)
	if derived == null:
		failures.append("changed feedback with a newer revision must derive a snapshot")
		return
	if derived == snapshot \
			or derived.get_render_revision() != 1 \
			or derived.get_hitstop_frames_remaining() != 1 \
			or absf(derived.get_counter_flash_t() - 0.5) > EPSILON:
		failures.append("derived feedback snapshot has incorrect values or identity")
	if snapshot.get_render_revision() != 0 \
			or snapshot.get_hitstop_frames_remaining() != 0 \
			or snapshot.get_counter_flash_t() != 0.0:
		failures.append("feedback derivation must not mutate its source snapshot")
	if derived.with_render_feedback(4, 0.0, 2) != null \
			or derived.with_render_feedback(0, 1.1, 2) != null:
		failures.append("feedback derivation must reject invalid render values")


func _check_creature_integration(
	schema: Dictionary,
	failures: Array[String]
) -> void:
	var fixture := _creature_fixture()
	var arena: TestArena = fixture["arena"]
	var actor: Node = fixture["actor"]
	if not actor.has_method("get_presentation_snapshot") \
			or not actor.has_method("set_presentation_actor_id"):
		failures.append(
			"BLOCKER: Creature R1B integration must expose "
			+ "set_presentation_actor_id and get_presentation_snapshot"
		)
		_cleanup_fixture(fixture)
		return

	actor.set_presentation_actor_id(&"fixture:presentation:7")
	arena.simulation_tick = 10
	actor.tick_sim(0.0)
	var first: RefCounted = actor.get_presentation_snapshot()
	var repeated: RefCounted = actor.get_presentation_snapshot()
	if first == null:
		failures.append("Creature must cache a base snapshot after tick_sim")
		_cleanup_fixture(fixture)
		return
	if first != repeated:
		failures.append("same-tick Creature snapshot reads must preserve object identity")
	if first.get_actor_id() != &"fixture:presentation:7" \
			or String(first.get_actor_id()).contains(str(actor.get_instance_id())) \
			or String(first.get_actor_id()).contains(String(actor.name)):
		failures.append("Creature actor_id must be stable and unrelated to node/instance IDs")

	actor.name = "RenamedPresentationFixture"
	if actor.get_presentation_snapshot().get_actor_id() != &"fixture:presentation:7":
		failures.append("renaming a Creature node must not change actor identity")
	actor.take_damage(1.0)
	if actor.get_presentation_snapshot() != first:
		failures.append(
			"incoming damage must not replace a completed same-tick base snapshot"
		)

	var idle_data: Dictionary = first.to_dictionary()
	if idle_data[&"has_strike_heading"] \
			or idle_data[&"strike_heading"] != Vector2.ZERO:
		failures.append("idle Creature snapshots must invalidate strike heading")

	actor.body_heading = Vector2.RIGHT
	actor.velocity = Vector2.UP * 20.0
	actor.steering_velocity = actor.velocity
	actor.last_aim_direction = Vector2.LEFT
	arena.simulation_tick = 11
	actor.tick_sim(0.0)
	var headings: RefCounted = actor.get_presentation_snapshot()
	if headings.get_body_heading().dot(Vector2.RIGHT) < 0.99 \
			or headings.get_travel_heading().dot(Vector2.UP) < 0.99 \
			or headings.get_attention_heading().dot(Vector2.LEFT) < 0.99 \
			or headings.get_has_strike_heading() \
			or headings.get_health_ratio() >= first.get_health_ratio():
		failures.append(
			"body, travel, attention and optional strike headings must remain distinct"
		)

	actor.begin_render_terrain_transition("land", "mud", 0.32)
	arena.simulation_tick = 12
	actor.tick_sim(0.0)
	var terrain: RefCounted = actor.get_presentation_snapshot()
	if terrain.get_transition_kind() != &"land_to_mud" \
			or terrain.get_previous_surface() == terrain.get_surface():
		failures.append("terrain snapshot must preserve directional transition semantics")

	actor.apply_creature("newt")
	arena.simulation_tick = 13
	actor.tick_sim(0.0)
	var switched: RefCounted = actor.get_presentation_snapshot()
	if switched.get_actor_id() != &"fixture:presentation:7" \
			or switched.get_creature_id() != &"newt" \
			or switched.get_has_strike_heading() \
			or switched.get_death_sequence_id() != 0:
		failures.append(
			"apply_creature must preserve actor identity and reset species presentation"
		)

	var expected_legacy := _string_set(
		(schema.get("legacy_motion_state", {}) as Dictionary).keys()
	)
	var legacy_a: Dictionary = actor.get_render_motion_state()
	if _string_set(legacy_a.keys()) != expected_legacy:
		failures.append("legacy motion adapter must return the exact declared key set")
	else:
		var snapshot_cues: Dictionary = switched.get_kit_cues()
		var snapshot_legacy: Dictionary = snapshot_cues.get(
			&"legacy_motion_state",
			{}
		)
		if _string_set(snapshot_legacy.keys()) != expected_legacy:
			failures.append(
				"snapshot compatibility payload must preserve every legacy key"
			)
		else:
			for key_value: Variant in legacy_a:
				if snapshot_legacy.get(StringName(key_value)) \
						!= legacy_a[key_value]:
					failures.append(
						"snapshot compatibility value mismatch for %s"
						% String(key_value)
					)
					break
		var original_creature: Variant = legacy_a.get("creature_id")
		legacy_a["creature_id"] = "mutated"
		var legacy_b: Dictionary = actor.get_render_motion_state()
		if legacy_b.get("creature_id") != original_creature:
			failures.append("legacy motion adapter must return an isolated mutable copy")

	actor.take_damage(actor.max_health * 2.0)
	if actor.alive:
		# Newt's first lethal hit intentionally consumes Caudal Autotomy.
		actor.take_damage(actor.max_health * 2.0)
	arena.simulation_tick = 14
	actor.tick_sim(0.0)
	var dead: RefCounted = actor.get_presentation_snapshot()
	if dead.get_alive() \
			or dead.get_death_sequence_id() <= 0 \
			or dead.get_respawn_remaining_sec() <= 0.0:
		failures.append("dead Creature snapshot must expose death and respawn state")
	var death_sequence_id: int = dead.get_death_sequence_id()
	arena.simulation_tick = 15
	actor.tick_sim(0.30)
	var death_progressed: RefCounted = actor.get_presentation_snapshot()
	if death_progressed.get_death_sequence_id() != death_sequence_id \
			or death_progressed.get_death_t() < 0.49 \
			or death_progressed.get_death_t() > 0.51:
		failures.append("death_t must advance deterministically across 0.60 seconds")
	actor._respawn()
	arena.simulation_tick = 16
	actor.tick_sim(0.0)
	var respawned: RefCounted = actor.get_presentation_snapshot()
	if not respawned.get_alive() \
			or respawned.get_death_sequence_id() != 0 \
			or respawned.get_death_t() != 0.0 \
			or respawned.get_respawn_remaining_sec() != 0.0:
		failures.append("respawn must neutralize presentation death fields")
	arena.simulation_tick = 17
	actor._invalidate_presentation_snapshot()
	var pre_tick: RefCounted = actor.get_presentation_snapshot()
	actor.velocity = Vector2.RIGHT * 40.0
	actor.steering_velocity = actor.velocity
	actor.tick_sim(0.0)
	var post_tick: RefCounted = actor.get_presentation_snapshot()
	if pre_tick == post_tick \
			or post_tick.get_velocity_px_per_sec().length() <= 0.0:
		failures.append(
			"a lazy pre-tick read must not suppress the completed tick snapshot"
		)

	_cleanup_fixture(fixture)


func _check_fixture_identity_and_latch(failures: Array[String]) -> void:
	var arena := TestArena.new()
	get_root().add_child(arena)
	var attacker := CreatureScript.new()
	var victim := CreatureScript.new()
	arena.add_actor(attacker)
	arena.add_actor(victim)
	attacker.setup(arena, 0, Vector2(0.0, 0.0), "alligator")
	victim.setup(arena, 1, Vector2(24.0, 0.0), "cane_toad")
	arena.simulation_tick = 20
	attacker.tick_sim(0.0)
	victim.tick_sim(0.0)
	var attacker_id: StringName = (
		attacker.get_presentation_snapshot().get_actor_id()
	)
	var victim_id: StringName = victim.get_presentation_snapshot().get_actor_id()
	if attacker_id == victim_id \
			or attacker_id != &"fixture:arena:0" \
			or victim_id != &"fixture:arena:1":
		failures.append("automatic fixture actor IDs must use unique stable ordinals")

	attacker.attach_to_victim(victim, 2.0, "Bite")
	victim.receive_latch(attacker, 2.0, "Bite")
	arena.simulation_tick = 21
	attacker.tick_sim(0.0)
	victim.tick_sim(0.0)
	var latched: RefCounted = attacker.get_presentation_snapshot()
	var accepted_anchor: Vector2 = latched.get_latch_anchor_px()
	if latched.get_latch_target_id() != victim_id \
			or not latched.get_has_latch_anchor() \
			or latched.get_grip_ratio() < 0.99:
		failures.append("latch snapshot must expose target, anchor, and max grip")
	attacker.global_position += Vector2(40.0, 0.0)
	victim.global_position += Vector2(40.0, 0.0)
	arena.simulation_tick = 22
	attacker.tick_sim(0.0)
	var moved_latch: RefCounted = attacker.get_presentation_snapshot()
	if moved_latch.get_latch_anchor_px() != accepted_anchor:
		failures.append("latch anchor must preserve the accepted world contact point")
	arena.free()


func _valid_data() -> Dictionary:
	return {
		&"schema_version": 1,
		&"simulation_tick": 42,
		&"render_revision": 0,
		&"actor_id": &"fixture:presentation:0",
		&"creature_id": &"alligator",
		&"team": 0,
		&"alive": true,
		&"world_position_px": Vector2(10.0, 20.0),
		&"velocity_px_per_sec": Vector2(30.0, 0.0),
		&"speed_px_per_sec": 30.0,
		&"speed_ratio": 0.5,
		&"locomotion_state": &"travel",
		&"body_heading": Vector2.RIGHT,
		&"travel_heading": Vector2.RIGHT,
		&"attention_heading": Vector2.UP,
		&"has_strike_heading": true,
		&"strike_heading": Vector2.RIGHT,
		&"signed_body_turn_radians": 0.25,
		&"turn_intensity": 0.2,
		&"body_radius_px": 8.0,
		&"footprint_kind": &"capsule",
		&"footprint_radius_px": 8.0,
		&"capsule_half_length_px": 5.0,
		&"model_scale": 1.18,
		&"visual_radius_px": 12.0,
		&"surface": &"water",
		&"previous_surface": &"mud",
		&"transition_kind": &"mud_to_shallow",
		&"transition_progress": 0.25,
		&"elevation_state": &"ground",
		&"height_units": 0.35,
		&"altitude_units": 0.0,
		&"submerged_depth_units": 0.0,
		&"low_window_open": true,
		&"low_window_t": 0.5,
		&"ground_anchor_px": Vector2(10.0, 20.0),
		&"active_actions": [_valid_action()],
		&"health_ratio": 0.75,
		&"resources": {&"mosquito_blood_ratio": 0.25},
		&"stealth_state": &"none",
		&"latch_role": &"none",
		&"latch_target_id": &"",
		&"has_latch_anchor": false,
		&"latch_anchor_px": Vector2.ZERO,
		&"grip_ratio": 0.0,
		&"weakpoint_id": &"",
		&"weakpoint_state": &"closed",
		&"death_sequence_id": 0,
		&"death_t": 0.0,
		&"respawn_remaining_sec": 0.0,
		&"kit_cues": {
			&"legacy": {
				&"surface_walk": {
					&"nested": [1, 2],
					&"color": Color(0.2, 0.4, 0.6, 1.0),
				},
			},
		},
		&"hitstop_frames_remaining": 0,
		&"counter_flash_t": 0.0,
	}


func _valid_action() -> Dictionary:
	return {
		&"action_id": &"alligator_bite",
		&"owner_id": &"fixture:presentation:0",
		&"sequence_id": 3,
		&"phase": &"active",
		&"phase_t": 0.5,
		&"remaining_sec": 0.1,
		&"variant": &"primary",
		&"outcome": &"none",
		&"has_strike_heading": true,
		&"strike_heading": Vector2.RIGHT,
		&"projected_shape": {
			&"kind": &"arc",
			&"origin_px": Vector2(12.0, 20.0),
			&"heading": Vector2.RIGHT,
			&"radius_px": 18.0,
			&"half_angle_rad": 0.5,
		},
		&"has_contact_point": false,
		&"contact_point_px": Vector2.ZERO,
		&"movement_multiplier": 0.5,
		&"blocks_action_starts": true,
		&"counter_vulnerable": false,
	}


func _creature_fixture() -> Dictionary:
	var arena := TestArena.new()
	get_root().add_child(arena)
	var actor := CreatureScript.new()
	arena.add_actor(actor)
	actor.setup(arena, 0, Vector2.ZERO, "alligator")
	var input := InputFrameScript.new()
	input.move = Vector2.ZERO
	input.aim = Vector2.LEFT * 1000.0
	actor.set_input_frame(input)
	return {"arena": arena, "actor": actor}


func _cleanup_fixture(fixture: Dictionary) -> void:
	var arena: Node = fixture.get("arena", null)
	if arena != null and is_instance_valid(arena):
		arena.free()


func _collect_non_json_values(
	value: Variant,
	path: String,
	invalid_paths: Array[String]
) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return
		TYPE_ARRAY:
			var array: Array = value
			for index in array.size():
				_collect_non_json_values(
					array[index],
					"%s[%d]" % [path, index],
					invalid_paths
				)
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for key: Variant in dictionary:
				if typeof(key) != TYPE_STRING:
					invalid_paths.append("%s.<key:%s>" % [path, str(key)])
				_collect_non_json_values(
					dictionary[key],
					"%s.%s" % [path, str(key)],
					invalid_paths
				)
		_:
			invalid_paths.append(path)


func _string_set(values: Variant) -> Dictionary:
	var output: Dictionary = {}
	for value: Variant in values:
		output[String(value)] = true
	return output
