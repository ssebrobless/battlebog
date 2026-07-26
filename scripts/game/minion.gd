extends Node2D
class_name Minion

# Mud minions. Kinds:
#   lane   — marches down its lane toward the opposing hut (then core)
#   tank   — hut defender, slow and beefy
#   melee  — hut defender, standard chomper
#   pebble — hut defender, ranged pebble thrower
# Defenders leash to their hut and respawn via the hut, not here.

const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")

const RENDER_TIMER_BUCKETS := 8.0
const RENDER_RATIO_BUCKETS := 32.0
const RENDER_ANGLE_BUCKETS := 32.0
const AGGRO_RANGE := 260.0
const DEFENDER_PATROL_RADIUS := 20.0 * SimConstants.UNIT_PX
const DEFENDER_AGGRO_RANGE := DEFENDER_PATROL_RADIUS
const DEFENDER_IDLE_RETURN_RADIUS := 10.0 * SimConstants.UNIT_PX

var arena: Node = null
var team := 0
var kind := "lane"
var max_health := 80.0
var health := 80.0
# Speeds cut 40% (decision #32): lane 145→87, tank 105→63, pebble 125→75.
var speed := 87.0
var damage := 14.0
var attack_range := 34.0
var attack_cooldown := 0.9
var attack_timer := 0.0
var attack_commit_timer := 0.0
var body_radius := 13.0
var march_target := Vector2.ZERO
var leash_hut: Node = null
var defender_slot := 0
var target_refresh_timer := 0.0
var cached_target: Node = null
var facing := Vector2.RIGHT
var velocity := Vector2.ZERO
var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
var visual_walk_phase := 0.0
var _last_render_signature := ""

func setup(minion_arena: Node, minion_team: int, spawn_position: Vector2, minion_kind := "lane", lane_target := Vector2.ZERO, hut: Node = null, slot := 0) -> void:
	arena = minion_arena
	team = minion_team
	position = spawn_position
	kind = minion_kind
	march_target = lane_target
	leash_hut = hut
	defender_slot = slot
	match kind:
		"tank":
			max_health = 220.0
			damage = 10.0
			speed = 63.0
			body_radius = 17.0
			attack_cooldown = 1.2
		"pebble":
			max_health = 70.0
			damage = 10.0
			speed = 75.0
			attack_range = 96.0
			attack_cooldown = 1.4
		"melee":
			max_health = 90.0
		_:
			pass
	health = max_health
	_last_render_signature = ""
	_request_redraw(true)

func is_alive() -> bool:
	return health > 0.0

func _physics_process(delta: float) -> void:
	var perf_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	_tick_minion(delta)
	if PerfStats.enabled:
		PerfStats.add("minions", int(Time.get_ticks_usec() - perf_start))

func _tick_minion(delta: float) -> void:
	if health <= 0.0:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	attack_commit_timer = maxf(attack_commit_timer - delta, 0.0)
	if knockback_timer > 0.0:
		var knockback_step := minf(delta, knockback_timer)
		knockback_timer = maxf(knockback_timer - delta, 0.0)
		velocity = knockback_velocity
		global_position += knockback_velocity * knockback_step
		if arena != null:
			global_position = arena.resolve_body_position(global_position, body_radius)
		if knockback_timer <= 0.0:
			knockback_velocity = Vector2.ZERO
			velocity = Vector2.ZERO
		_request_redraw()
		return
	# Re-query targets on a timer, not every frame — O(n) scans are the cost.
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0:
		var query_range := DEFENDER_AGGRO_RANGE if leash_hut != null and is_instance_valid(leash_hut) else AGGRO_RANGE
		cached_target = arena.get_closest_enemy(self, query_range) if arena != null else null
		target_refresh_timer = 0.2 + float(get_instance_id() % 7) * 0.015
	if cached_target != null and (not is_instance_valid(cached_target) or (cached_target.has_method("is_alive") and not cached_target.is_alive())):
		cached_target = null
	var target: Node = cached_target

	# Defenders stay home: drop distant targets and walk back when leashed out.
	if leash_hut != null and is_instance_valid(leash_hut):
		var from_home: float = global_position.distance_to(leash_hut.global_position)
		if from_home > DEFENDER_PATROL_RADIUS:
			target = null
			_move_toward_point(leash_hut.global_position, delta)
			_request_redraw()
			return

	if target == null:
		if kind == "lane":
			_march(delta)
		elif leash_hut != null and is_instance_valid(leash_hut) and global_position.distance_to(leash_hut.global_position) > DEFENDER_IDLE_RETURN_RADIUS:
			_move_toward_point(leash_hut.global_position, delta)
		else:
			velocity = Vector2.ZERO
		_request_redraw()
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	if distance <= attack_range + target.body_radius:
		velocity = Vector2.ZERO
		facing = to_target.normalized() if to_target != Vector2.ZERO else facing
		if attack_timer <= 0.0:
			_attack(target)
			attack_timer = attack_cooldown
	else:
		# Engagement slots: each minion approaches its own angle around the
		# target so packs fan out into a fighting ring instead of a stack.
		_move_toward_point(target.global_position + _engage_offset(target), delta)
	_request_redraw()

func _engage_offset(target: Node) -> Vector2:
	var slot := defender_slot if leash_hut != null else int(get_instance_id() % 8)
	var angle := TAU * float(slot) / 8.0
	var ring: float = (attack_range + float(target.get("body_radius") if target.get("body_radius") != null else 10.0)) * 0.7
	return Vector2(cos(angle), sin(angle)) * ring

func _attack(target: Node) -> void:
	# Attack commit (decision #32): swinging/throwing roots the minion
	# briefly so it can't hard-chase while hitting.
	attack_commit_timer = 0.25
	facing = (target.global_position - global_position).normalized()
	if kind == "pebble":
		var direction: Vector2 = (target.global_position - global_position).normalized()
		if arena != null:
			arena.spawn_projectile(team, global_position + direction * (body_radius + 4.0), direction, damage, 340.0, Color(0.6, 0.55, 0.45), false, 5.0, 0.6, self)
		return
	if _is_enemy_core(target):
		if arena != null and not arena.can_damage_core(target.team):
			return
		var core_damage: float = damage * arena.get_core_damage_multiplier(team)
		target.take_damage(core_damage, team, self)
		arena.record_core_damage(team, core_damage, self)
		return
	target.take_damage(damage, team, self)

func _march(_delta: float) -> void:
	var destination := march_target
	if arena != null and arena.has_method("get_lane_destination"):
		destination = arena.get_lane_destination(team, march_target)
	# When the lane is clear the destination becomes the enemy core: attack
	# it on arrival instead of idling next to it.
	var enemy_core: Node = arena.get_enemy_core(team) if arena != null else null
	if enemy_core != null and destination.distance_to(enemy_core.global_position) < 1.0:
		var core_distance: float = global_position.distance_to(enemy_core.global_position)
		if core_distance <= attack_range + enemy_core.radius:
			velocity = Vector2.ZERO
			if attack_timer <= 0.0:
				_attack(enemy_core)
				attack_timer = attack_cooldown
			return
	if global_position.distance_to(destination) < 40.0:
		velocity = Vector2.ZERO
		return
	_move_toward_point(destination, _delta)

func _move_toward_point(point: Vector2, delta := SimConstants.TICK_DELTA) -> void:
	if attack_commit_timer > 0.0:
		velocity = Vector2.ZERO
		return
	var move_direction := (point - global_position).normalized()
	if arena != null:
		move_direction = arena.get_steering_direction(global_position, point, body_radius, team)
	velocity = move_direction * speed
	global_position += velocity * delta
	if velocity.length() > 4.0:
		visual_walk_phase = wrapf(visual_walk_phase + delta * speed * 0.08, 0.0, TAU)
	if arena != null:
		global_position = arena.resolve_body_position(global_position, body_radius)

func receive_knockback(direction: Vector2, distance_px: float, duration: float) -> void:
	if direction == Vector2.ZERO:
		return
	knockback_velocity = direction.normalized() * (distance_px / maxf(duration, 0.01))
	knockback_timer = maxf(duration, 0.01)


func _is_enemy_core(target: Node) -> bool:
	return arena != null and target == arena.get_enemy_core(team)

func _request_redraw(force := false) -> void:
	if not _is_near_render_view():
		return
	var signature := _render_signature()
	if force or signature != _last_render_signature:
		_last_render_signature = signature
		queue_redraw()

func _is_near_render_view() -> bool:
	return arena == null or not arena.has_method("is_near_view") or arena.is_near_view(global_position)

func get_render_signature() -> String:
	return _render_signature()

func _render_signature() -> String:
	var parts := PackedStringArray()
	parts.append(kind)
	parts.append(str(team))
	parts.append(str(_quantized_ratio(health, max_health, RENDER_RATIO_BUCKETS)))
	parts.append(str(_timer_bucket(attack_commit_timer, 0.25)))
	parts.append(str(_timer_bucket(attack_timer, attack_cooldown)))
	parts.append(str(_angle_bucket(facing)))
	var moving := velocity.length() > 4.0
	parts.append(str(moving))
	parts.append(str(_timer_bucket(visual_walk_phase, TAU) if moving else 0))
	return "|".join(parts)

func _timer_bucket(value: float, duration: float) -> int:
	if value <= 0.0 or duration <= 0.0:
		return 0
	return _quantized_ratio(value, duration, RENDER_TIMER_BUCKETS)

func _quantized_ratio(value: float, max_value: float, buckets: float) -> int:
	if max_value <= 0.0:
		return 0
	return int(round(clampf(value / max_value, 0.0, 1.0) * buckets))

func _angle_bucket(direction: Vector2) -> int:
	if direction == Vector2.ZERO:
		return -1
	var angle := wrapf(direction.angle(), 0.0, TAU)
	return int(round(angle / TAU * RENDER_ANGLE_BUCKETS))

func uses_manual_movement_body() -> bool:
	return true

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	if health <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	_request_redraw(true)

	if health <= 0.0:
		if leash_hut != null and is_instance_valid(leash_hut) and leash_hut.has_method("on_defender_died"):
			leash_hut.on_defender_died(kind, defender_slot)
		if arena != null:
			arena.unregister_entity(self)
		queue_free()

func take_damage_event(event: Resource) -> void:
	take_damage(event.amount, -1, event.source_actor)

func _draw() -> void:
	# Attack-commit lunge (decision #32 readability): the body snaps toward
	# the target and eases back over the 0.25 s commit, so attack speed is
	# visible in motion, not just numbers.
	var lunge := Vector2.ZERO
	if attack_commit_timer > 0.0:
		var swing_t := 1.0 - attack_commit_timer / 0.25
		var punch: float = sin(swing_t * PI) * (body_radius * 0.6)
		lunge = facing * (punch if kind != "pebble" else -punch * 0.6)
	draw_set_transform(lunge, 0.0, Vector2.ONE)
	VisualStyle.draw_minion(self, kind, team, body_radius, facing, {
		"attack_commit_t": clampf(attack_commit_timer / 0.25, 0.0, 1.0),
		"moving": velocity.length() > 4.0,
		"walk_phase": visual_walk_phase
	})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0, 4.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 8.0), Vector2(body_radius * 2.0 * (health / max_health), 4.0)), Color(0.3, 1.0, 0.45))

func get_render_style_state() -> Dictionary:
	return VisualStyle.minion_render_metrics(kind, body_radius)
