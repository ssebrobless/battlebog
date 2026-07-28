extends RefCounted

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const MeleeHit := preload("res://scripts/sim/abilities/melee_hit.gd")
const Latch := preload("res://scripts/sim/abilities/latch.gd")
const KitHelpers := preload("res://scripts/sim/kits/kit_helpers.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")

const BITE_LATCH_SEC := 3.0
const DEATH_ROLL_DPS := 30.0
const DEATH_ROLL_SEC := 5.0
const DEATH_ROLL_TURN_RAD_PER_SEC := TAU * 1.4
const AMBUSH_STEALTH_SEC := 9999.0
const AMBUSH_SLOW_MULT := 0.70
const DEVOUR_HEAL_RATIO := 0.50

var death_roll_timer := 0.0
var ambush_active := false

func setup(actor: Node) -> void:
	actor.primary_timer = 0.0
	actor.q_timer = 0.0
	actor.e_timer = 0.0
	death_roll_timer = 0.0
	ambush_active = false

func reset_for_respawn(actor: Node) -> void:
	death_roll_timer = 0.0
	ambush_active = false
	if actor.has_method("remove_modifiers_from_source"):
		actor.remove_modifiers_from_source("Ambush")

func tick(actor: Node, delta: float) -> void:
	_tick_death_roll(actor, delta)
	_sync_ambush(actor)
	if actor.input_frame == null:
		return
	if not actor.can_act():
		return

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY):
		if actor.latch_victim == null and actor.primary_timer <= 0.0:
			if _request_bite(actor):
				return
	elif actor.latch_victim != null \
		and actor.latch_source == "Bite" \
		and actor.input_frame.is_intentional_release(InputFrameScript.BUTTON_PRIMARY):
		actor.release_latch("primary_release")

	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_Q) and actor.q_timer <= 0.0:
		_try_death_roll(actor)
	if actor.input_frame.is_pressed(InputFrameScript.BUTTON_ABILITY_E) \
		and actor.e_timer <= 0.0 \
		and not ambush_active \
		and not actor.is_primary_attack_committed():
		_start_ambush(actor)

func on_damage_taken(actor: Node, _event: Resource, _amount: float, _before_health: float) -> void:
	_end_ambush(actor)

func on_kill(actor: Node, victim: Node) -> void:
	if victim != null and is_instance_valid(victim):
		actor.heal(float(victim.max_health) * DEVOUR_HEAL_RATIO)

func _request_bite(actor: Node) -> bool:
	var damage := float(actor.stats.get("primary_damage", 0.0))
	var reach_px := KitHelpers.range_units(actor.stats, 1.0) * SimConstants.UNIT_PX
	var payload := {
		"damage": damage,
		"reach_px": reach_px,
		"delivery": DamageEventScript.DELIVERY_MELEE,
		"plane": DamageEventScript.PLANE_GROUND,
		"source_ability": "Bite",
		"max_hits": 1,
	}
	if not actor.request_primary_attack(
		"bite",
		payload,
		Callable(self, "_resolve_bite").bind(actor)
	):
		return false

	var snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var strike_heading: Vector2 = snapshot.get("strike_heading", actor.get_aim_direction())
	var attack_sequence_id := int(snapshot.get("attack_sequence_id", 0))
	var preview_shape := _bite_shape_from_snapshot(actor, snapshot)
	if preview_shape.is_empty() or not actor.update_primary_attack_presentation(
		attack_sequence_id,
		{
			"projected_shape": preview_shape,
			"contact_point": null,
		}
	):
		actor.interrupt_primary_attack("invalid_bite_presentation", true)
		return false
	_end_ambush(actor)
	var windup_payload := preview_shape.duplicate(true)
	windup_payload.merge({
		"actor": actor,
		"position": actor.global_position,
		"aim": strike_heading,
		"locked_aim": strike_heading,
		"attack_sequence_id": attack_sequence_id,
		"duration": _bite_startup_duration(actor),
		"source_ability": "Bite",
		"timeline_owned": true,
	})
	actor.emit_vfx_event("windup_started", windup_payload)
	return true

func refresh_primary_attack_presentation(actor: Node) -> void:
	var snapshot: Dictionary = actor.get_primary_attack_snapshot()
	if String(snapshot.get("attack_variant", "")) != "bite" \
		or String(snapshot.get("attack_phase_name", "")) != "startup":
		return
	var shape := _bite_shape_from_snapshot(actor, snapshot)
	if shape.is_empty():
		return
	actor.update_primary_attack_presentation(
		int(snapshot.get("attack_sequence_id", 0)),
		{"projected_shape": shape}
	)

func _resolve_bite(actor: Node) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {"outcome": "whiff", "hit_count": 0, "hit_region": ""}
	var snapshot: Dictionary = actor.get_primary_attack_snapshot()
	var payload_value: Variant = snapshot.get("payload", {})
	if typeof(payload_value) != TYPE_DICTIONARY:
		return {"outcome": "whiff", "hit_count": 0, "hit_region": ""}
	var payload: Dictionary = payload_value
	var strike_heading: Vector2 = snapshot.get("strike_heading", Vector2.RIGHT)
	var attack_sequence_id := int(snapshot.get("attack_sequence_id", 0))
	var shape := _bite_shape_from_snapshot(actor, snapshot)
	if shape.is_empty():
		return {"outcome": "whiff", "hit_count": 0, "hit_region": ""}
	actor.update_primary_attack_presentation(
		attack_sequence_id,
		{"projected_shape": shape}
	)

	var swing_payload := shape.duplicate(true)
	swing_payload.merge({
		"actor": actor,
		"position": actor.global_position,
		"aim": strike_heading,
		"locked_aim": strike_heading,
		"attack_sequence_id": attack_sequence_id,
		"source_ability": String(payload.get("source_ability", "Bite")),
		"timeline_owned": true,
	})
	actor.emit_vfx_event("attack_swung", swing_payload)
	var contacts := MeleeHit.query(actor, shape)
	var resolution := MeleeHit.resolve(
		actor,
		shape,
		contacts,
		float(payload.get("damage", 0.0)),
		int(payload.get("delivery", DamageEventScript.DELIVERY_MELEE)),
		int(payload.get("plane", DamageEventScript.PLANE_GROUND)),
		String(payload.get("source_ability", "Bite")),
		{"max_hits": int(payload.get("max_hits", 1))}
	)
	var hits: Array = resolution.get("hits", [])
	if _is_live_latch_attacker(actor) and _primary_effectively_held(actor):
		for hit in hits:
			if _is_live_latch_target(hit):
				Latch.start(actor, hit, BITE_LATCH_SEC, "Bite")
				break

	var hit_region := ""
	var hit_records: Array = resolution.get("hit_records", [])
	var contact_point: Variant = null
	if not hit_records.is_empty():
		for record_value: Variant in hit_records:
			if typeof(record_value) != TYPE_DICTIONARY:
				continue
			var record: Dictionary = record_value
			if String(record.get("contact_kind", "")) != "normal":
				continue
			hit_region = String(record.get("region", ""))
			var point_value: Variant = record.get("point")
			if typeof(point_value) == TYPE_VECTOR2 \
				and (point_value as Vector2).is_finite():
				contact_point = point_value
			break
	actor.update_primary_attack_presentation(
		attack_sequence_id,
		{
			"projected_shape": shape,
			"contact_point": contact_point,
		}
	)
	return {
		"outcome": "hit" if not hits.is_empty() else "whiff",
		"hit_count": hits.size(),
		"hit_region": hit_region,
	}

func _bite_shape_from_snapshot(actor: Node, snapshot: Dictionary) -> Dictionary:
	var payload_value: Variant = snapshot.get("payload", {})
	if typeof(payload_value) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = payload_value
	var strike_heading_value: Variant = snapshot.get(
		"strike_heading",
		Vector2.RIGHT
	)
	if typeof(strike_heading_value) != TYPE_VECTOR2:
		return {}
	return MeleeHit.build_shape(
		actor,
		float(payload.get("reach_px", 0.0)),
		strike_heading_value as Vector2
	)

func _primary_effectively_held(actor: Node) -> bool:
	if actor.input_frame == null:
		return false
	return actor.input_frame.is_pressed(InputFrameScript.BUTTON_PRIMARY) \
		or actor.input_frame.is_suppressed(InputFrameScript.BUTTON_PRIMARY)

func _is_live_latch_attacker(actor: Variant) -> bool:
	return typeof(actor) == TYPE_OBJECT \
		and is_instance_valid(actor) \
		and actor is Node \
		and actor.has_method("is_alive") \
		and actor.is_alive()

func _is_live_latch_target(target: Variant) -> bool:
	if typeof(target) != TYPE_OBJECT \
		or not is_instance_valid(target) \
		or not target is Node \
		or not target.has_method("receive_latch"):
		return false
	return not target.has_method("is_alive") or target.is_alive()

func _bite_startup_duration(actor: Node) -> float:
	var timelines_value: Variant = actor.creature_data.get("primary_attack_timelines", {})
	var timelines: Dictionary = timelines_value if typeof(timelines_value) == TYPE_DICTIONARY else {}
	var bite_value: Variant = timelines.get("bite", {})
	var bite: Dictionary = bite_value if typeof(bite_value) == TYPE_DICTIONARY else {}
	var startup := maxf(float(bite.get("startup", 0.30)), 0.001)
	var attack_speed := maxf(actor.get_modifier_value("attack_speed_mult", 1.0), 0.001)
	return startup / attack_speed

func _try_death_roll(actor: Node) -> void:
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim):
		return
	if actor.latch_source != "Bite":
		return
	var victim: Node = actor.latch_victim
	if not _is_water(victim):
		return
	_end_ambush(actor)
	death_roll_timer = DEATH_ROLL_SEC
	actor.latch_source = "Death Roll"
	victim.latch_source = "Death Roll"
	actor.latch_timer = maxf(actor.latch_timer, DEATH_ROLL_SEC)
	victim.latch_timer = actor.latch_timer
	actor.q_timer = KitHelpers.cooldown_seconds(KitHelpers.ability(actor.creature_data, "Q"))

func _tick_death_roll(actor: Node, delta: float) -> void:
	if death_roll_timer <= 0.0:
		return
	if actor.latch_victim == null or not is_instance_valid(actor.latch_victim):
		death_roll_timer = 0.0
		return
	var victim: Node = actor.latch_victim
	death_roll_timer = maxf(death_roll_timer - delta, 0.0)
	actor.latch_timer = maxf(actor.latch_timer, death_roll_timer + delta)
	victim.latch_timer = actor.latch_timer
	victim.take_damage_event(actor.make_damage_event(DEATH_ROLL_DPS * delta, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, "Death Roll"))
	if actor.latch_victim == victim and is_instance_valid(victim):
		_apply_roll_motion(actor, victim, delta)
	if death_roll_timer <= 0.0 and actor.latch_victim == victim:
		actor.release_latch("death_roll_done")

func _apply_roll_motion(actor: Node, victim: Node, delta: float) -> void:
	var offset: Vector2 = actor.global_position - victim.global_position
	if offset == Vector2.ZERO:
		offset = -actor.get_aim_direction() * maxf(actor.body_radius + victim.body_radius, 1.0)
	var rolled := offset.rotated(DEATH_ROLL_TURN_RAD_PER_SEC * delta)
	actor.global_position = victim.global_position + rolled
	actor.velocity = rolled.normalized() * minf(actor.get_speed_px(), rolled.length() / maxf(delta, 0.001))
	actor.last_aim_direction = -rolled.normalized()

func _start_ambush(actor: Node) -> void:
	ambush_active = true
	actor.begin_stealth(AMBUSH_STEALTH_SEC, "Ambush")
	actor.remove_modifiers_from_source("Ambush")
	actor.add_modifier("Ambush", {"move_speed_mult": AMBUSH_SLOW_MULT}, AMBUSH_STEALTH_SEC)

func _sync_ambush(actor: Node) -> void:
	if ambush_active and not actor.is_stealthed():
		_end_ambush(actor)

func _end_ambush(actor: Node) -> void:
	if not ambush_active:
		return
	ambush_active = false
	actor.break_stealth()
	actor.remove_modifiers_from_source("Ambush")
	var e := KitHelpers.ability(actor.creature_data, "E")
	actor.e_timer = maxf(actor.e_timer, _ambush_cooldown(e))

func _ambush_cooldown(ability_data: Dictionary) -> float:
	if ability_data.has("cooldown_after_break_sec"):
		return float(ability_data["cooldown_after_break_sec"])
	return KitHelpers.cooldown_seconds(ability_data)

func _is_water(actor: Node) -> bool:
	if actor.has_method("get_current_zone"):
		return String(actor.get_current_zone()) == TerrainMapScript.WATER
	return false
