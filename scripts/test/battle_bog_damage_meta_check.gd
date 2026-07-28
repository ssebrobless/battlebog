extends SceneTree

const CreatureCatalogScript := preload("res://scripts/data/creature_catalog.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Projectile := preload("res://scripts/sim/abilities/projectile.gd")

class FakeArena:
	extends Node
	var entities: Array[Node] = []
	var cores := {}
	var vfx_events: Array[Dictionary] = []
	var terrain := TerrainMapScript.new()

	func _init() -> void:
		terrain.configure("3v3")

	func add_actor(actor: Node) -> void:
		add_child(actor)
		entities.append(actor)

	func get_terrain_zone(point: Vector2) -> String:
		return terrain.get_zone_at(point)

	func resolve_body_position(point: Vector2, _radius: float) -> Vector2:
		return point

	func record_vfx_event(event: Dictionary) -> void:
		vfx_events.append(event.duplicate())

	func record_death(_victim: Node, _killer: Node = null) -> void:
		pass

func _initialize() -> void:
	_ensure_catalog()
	var failures: Array[String] = []
	_check_metadata_from_melee(failures)
	_check_metadata_from_line(failures)
	_check_region_multiplier(failures)
	_check_authored_region_from_line(failures)
	_check_open_region_visual_contract(failures)
	_check_render_hitstop(failures)
	_check_counter_hit(failures)
	print("damage_meta failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _ensure_catalog() -> void:
	var catalog := get_root().get_node_or_null("CreatureCatalog")
	if catalog == null:
		catalog = CreatureCatalogScript.new()
		catalog.name = "CreatureCatalog"
		get_root().add_child(catalog)
	catalog.load_catalog()

func _check_metadata_from_melee(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 24.0)
	MeleeHit.hit(actor, 40.0, 10.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Meta Bite")
	var event := _last_hit(arena)
	if event.is_empty() or not _has_hit_meta(event):
		failures.append("melee hit should populate hit_position/hit_normal/region; event=%s" % str(event))
	arena.queue_free()

func _check_metadata_from_line(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "chorus_frog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 60.0)
	Projectile.instant_line(actor, 100.0, 10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Meta Tongue", {"half_width_px": 8.0})
	var event := _last_hit(arena)
	if target.health >= target.max_health or event.is_empty() or not _has_hit_meta(event):
		failures.append("line hit should damage target and populate hit metadata; health=%.2f event=%s" % [target.health, str(event)])
	arena.queue_free()

func _check_region_multiplier(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 40.0)
	var before: float = target.health
	var event: Resource = actor.make_damage_event(10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Region Probe")
	event.set_hit(target.global_position, Vector2.LEFT, "hull", 1.35)
	target.take_damage_event(event)
	var loss: float = before - target.health
	if absf(loss - 13.5) > 0.01:
		failures.append("region_mult should scale incoming damage; loss=%.2f" % loss)
	arena.queue_free()

func _check_authored_region_from_line(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "chorus_frog", 0, Vector2.ZERO)
	var target := _creature(arena, "water_snake", 1, Vector2.RIGHT * 60.0)
	target.last_aim_direction = Vector2.LEFT
	target.body_heading = Vector2.LEFT
	var before: float = target.health
	Projectile.instant_line(actor, 70.0, 10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Head Probe", {"half_width_px": 8.0})
	var event := _last_hit(arena)
	var loss: float = before - target.health
	if String(event.get("region", "")) != "head" or absf(float(event.get("region_mult", 0.0)) - 1.35) > 0.001 or absf(loss - 13.5) > 0.01:
		failures.append("line hit should resolve authored snake head region; loss=%.2f event=%s" % [loss, str(event)])
	arena.queue_free()

func _check_open_region_visual_contract(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var snake := _creature(arena, "water_snake", 1, Vector2.RIGHT * 60.0)
	snake.last_aim_direction = Vector2.LEFT
	snake.body_heading = Vector2.LEFT
	var snake_state: Dictionary = snake.get_render_motion_state()
	var snake_regions: Array = snake_state.get("open_hurtbox_regions", [])
	var snake_region: Dictionary = snake_regions[0] if not snake_regions.is_empty() else {}
	var snake_ok := bool(snake_state.get("open_region_visuals", false)) \
		and String(snake_region.get("region", "")) == "head" \
		and absf(float(snake_region.get("region_mult", 0.0)) - 1.35) < 0.001 \
		and (snake_region.get("local_center", Vector2.ZERO) as Vector2).distance_to(Vector2.LEFT * 20.0) < 0.01 \
		and absf(float(snake_region.get("radius", 0.0)) - 7.2) < 0.01
	var turtle := _creature(arena, "snapping_turtle", 0, Vector2.ZERO)
	turtle.last_aim_direction = Vector2.RIGHT
	turtle.body_heading = Vector2.RIGHT
	var turtle_state: Dictionary = turtle.get_render_motion_state()
	var turtle_regions: Array = turtle_state.get("open_hurtbox_regions", [])
	var turtle_region: Dictionary = turtle_regions[0] if not turtle_regions.is_empty() else {}
	var turtle_ok := bool(turtle_state.get("open_region_visuals", false)) \
		and String(turtle_region.get("region", "")) == "shell_rear" \
		and absf(float(turtle_region.get("region_mult", 0.0)) - 0.75) < 0.001 \
		and (turtle_region.get("local_center", Vector2.ZERO) as Vector2).distance_to(Vector2.LEFT * 12.0) < 0.01 \
		and absf(float(turtle_region.get("radius", 0.0)) - 8.8) < 0.01
	if not snake_ok or not turtle_ok:
		failures.append("open hurtbox regions should expose visual anchors from authored region offsets; snake=%s state=%s turtle=%s state=%s" % [
			str(snake_region),
			str(snake_state),
			str(turtle_region),
			str(turtle_state)
		])
	arena.queue_free()

func _check_render_hitstop(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 48.0)
	actor.anim_attack_timer = 0.20
	target.anim_attack_timer = 0.20
	target.velocity = Vector2.RIGHT * 120.0
	var event: Resource = actor.make_damage_event(60.0, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Heavy Meta")
	event.set_hit(target.global_position, Vector2.LEFT)
	target.take_damage_event(event)
	var both_stopped: bool = actor.render_hitstop_frames == 3 and target.render_hitstop_frames == 3
	var frozen_before: float = target.anim_attack_timer
	target._process(0.01)
	target._process(0.10)
	target._process(0.001)
	var render_frozen: bool = absf(target.anim_attack_timer - frozen_before) < 0.0001 \
		and target.render_hitstop_frames == 0
	target._process(0.01)
	var resumed_after_three: bool = target.anim_attack_timer < frozen_before
	target.set_input_frame(_frame(Vector2.RIGHT))
	var before_pos: Vector2 = target.global_position
	target.tick_sim(0.10)
	var sim_advanced: bool = target.global_position.distance_to(before_pos) > 0.1
	if not both_stopped or not render_frozen or not resumed_after_three or not sim_advanced:
		failures.append("heavy hitstop should freeze exactly three render frames only; both=%s frozen=%s resumed=%s sim=%s frames=%d/%d pos_delta=%.2f" % [
			str(both_stopped),
			str(render_frozen),
			str(resumed_after_three),
			str(sim_advanced),
			actor.render_hitstop_frames,
			target.render_hitstop_frames,
			target.global_position.distance_to(before_pos)
		])
	arena.queue_free()

func _check_counter_hit(failures: Array[String]) -> void:
	var arena := FakeArena.new()
	get_root().add_child(arena)
	var actor := _creature(arena, "bullfrog", 0, Vector2.ZERO)
	var target := _creature(arena, "cane_toad", 1, Vector2.RIGHT * 40.0)
	target.emit_vfx_event("windup_started", {
		"actor": target,
		"position": target.global_position,
		"aim": Vector2.RIGHT,
		"reach_px": 20.0,
		"duration": 0.2,
		"source_ability": "Counter Probe",
		"counter_hit_window": true
	})
	var windup_window: bool = target.counter_hit_window_timer > 0.19
	var ally := _creature(arena, "bullfrog", 1, Vector2.LEFT * 40.0)
	var ally_before: float = target.health
	var ally_event: Resource = ally.make_damage_event(10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Ally Probe")
	target.take_damage_event(ally_event)
	var ally_loss: float = ally_before - target.health
	var environment_before: float = target.health
	var environment_event := DamageEventScript.new()
	environment_event.setup(10.0, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, null, "Bog Hazard")
	target.take_damage_event(environment_event)
	var environment_loss: float = environment_before - target.health
	var dead_source := _creature(arena, "bullfrog", 0, Vector2.LEFT * 60.0)
	dead_source.alive = false
	var dead_before: float = target.health
	var dead_event: Resource = dead_source.make_damage_event(10.0, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, "Lingering Field")
	target.take_damage_event(dead_event)
	var dead_loss: float = dead_before - target.health
	arena.vfx_events.clear()
	var before: float = target.health
	var event: Resource = actor.make_damage_event(10.0, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, "Counter Probe")
	event.set_hit(target.global_position, Vector2.LEFT)
	target.take_damage_event(event)
	var loss: float = before - target.health
	var landed := _last_hit(arena)
	var counter_event: bool = _has_event(arena, "counter_hit")
	var marked: bool = bool(landed.get("counter_hit", false))
	var flashed: bool = target.render_counter_flash_timer == target.COUNTER_FLASH_SEC
	var flash_state: Dictionary = target.get_render_motion_state()
	var flash_contract: bool = target.COUNTER_FLASH_COLOR == Color(1.0, 0.88, 0.24, 1.0) \
		and absf(float(flash_state.get("counter_flash_t", 0.0)) - 1.0) < 0.001
	if not windup_window \
		or absf(ally_loss - 10.0) > 0.01 \
		or absf(environment_loss - 10.0) > 0.01 \
		or absf(dead_loss - 10.0) > 0.01 \
		or absf(loss - 12.0) > 0.01 \
		or not counter_event \
		or not marked \
		or not flashed \
		or not flash_contract:
		failures.append("counter hit should require a live enemy attribution, scale/mark damage, and start the gold body flash; windup=%s ally=%.2f environment=%.2f dead=%.2f loss=%.2f vfx=%s marked=%s flash=%s event=%s" % [
			str(windup_window),
			ally_loss,
			environment_loss,
			dead_loss,
			loss,
			str(counter_event),
			str(marked),
			str(flash_state),
			str(landed)
		])
	arena.queue_free()

func _has_hit_meta(event: Dictionary) -> bool:
	var hit_position: Vector2 = event.get("hit_position", Vector2.ZERO)
	var hit_normal: Vector2 = event.get("hit_normal", Vector2.ZERO)
	return hit_position != Vector2.ZERO and hit_normal.length() > 0.9 and String(event.get("region", "")) == "hull" and absf(float(event.get("region_mult", 0.0)) - 1.0) < 0.001

func _has_event(arena: FakeArena, event_type: String) -> bool:
	for event in arena.vfx_events:
		if String(event.get("type", "")) == event_type:
			return true
	return false

func _last_hit(arena: FakeArena) -> Dictionary:
	for i in range(arena.vfx_events.size() - 1, -1, -1):
		if String(arena.vfx_events[i].get("type", "")) == "hit_landed":
			return arena.vfx_events[i]
	return {}

func _frame(move: Vector2) -> Resource:
	var frame := preload("res://scripts/sim/input_frame.gd").new()
	frame.move = move
	frame.aim = Vector2.RIGHT
	return frame

func _creature(arena: FakeArena, creature_id: String, team: int, position: Vector2) -> Node:
	var creature := CreatureScript.new()
	arena.add_actor(creature)
	creature.setup(arena, team, position, creature_id, arena.terrain)
	creature.global_position = position
	return creature
