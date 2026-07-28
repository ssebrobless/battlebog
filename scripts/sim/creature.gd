extends CharacterBody2D

const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const EnvironmentProfileScript := preload("res://scripts/sim/environment_profile.gd")
const MovementFeelScript := preload("res://scripts/sim/movement_feel.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")
const AttackTimelineScript := preload("res://scripts/sim/combat/attack_timeline.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const VisualStyle := preload("res://scripts/visual/visual_style.gd")
const TurtleKitScript := preload("res://scripts/sim/kits/snapping_turtle.gd")
const WaterSnakeKitScript := preload("res://scripts/sim/kits/water_snake.gd")
const AlligatorKitScript := preload("res://scripts/sim/kits/alligator.gd")
const WolfSpiderKitScript := preload("res://scripts/sim/kits/wolf_spider.gd")
const FireflyKitScript := preload("res://scripts/sim/kits/firefly.gd")
const MosquitoSwarmKitScript := preload("res://scripts/sim/kits/mosquito_swarm.gd")
const FrogKitScript := preload("res://scripts/sim/kits/chorus_frog.gd")
const NewtKitScript := preload("res://scripts/sim/kits/newt.gd")
const MinkKitScript := preload("res://scripts/sim/kits/mink.gd")
const BullfrogKitScript := preload("res://scripts/sim/kits/bullfrog.gd")
const CaneToadKitScript := preload("res://scripts/sim/kits/cane_toad.gd")
const CrayfishKitScript := preload("res://scripts/sim/kits/crayfish.gd")
const BogTurtleKitScript := preload("res://scripts/sim/kits/bog_turtle.gd")
const WaterShrewKitScript := preload("res://scripts/sim/kits/water_shrew.gd")
const BeaverKitScript := preload("res://scripts/sim/kits/beaver.gd")
const OtterKitScript := preload("res://scripts/sim/kits/otter.gd")
const LeechKitScript := preload("res://scripts/sim/kits/leech.gd")
const OwlKitScript := preload("res://scripts/sim/kits/owl.gd")
const HeronKitScript := preload("res://scripts/sim/kits/great_blue_heron.gd")
const KingfisherKitScript := preload("res://scripts/sim/kits/kingfisher.gd")
const DuckKitScript := preload("res://scripts/sim/kits/duck.gd")

const WRONG_TERRAIN_GRACE_SEC := 3.0
const WRONG_TERRAIN_EARLY_DPS := 0.02
const WRONG_TERRAIN_LATE_DPS := 0.05
const TAKEOFF_DISTANCE_UNITS := 2.0
const FLIGHT_GROUNDED_LOCKOUT_SEC := 3.0
const TERRAIN_SPEED_LERP_RATE := 9.0
const HUNGER_MAX := 100.0
const HUNGER_FULL_TO_EMPTY_SEC := 105.0
const HITSTOP_FRAMES := 3
const COUNTER_HIT_MULT := 1.2
const COUNTER_FLASH_COLOR := Color(1.0, 0.88, 0.24, 1.0)
const COUNTER_FLASH_SEC := 0.12
const ACTION_START_BUTTONS := InputFrameScript.BUTTON_PRIMARY \
	| InputFrameScript.BUTTON_ABILITY_Q \
	| InputFrameScript.BUTTON_ABILITY_E \
	| InputFrameScript.BUTTON_HUT_DEFEND \
	| InputFrameScript.BUTTON_HABITAT_DEPOSIT \
	| InputFrameScript.BUTTON_CONTEXT_ACTION \
	| InputFrameScript.BUTTON_FLIGHT_TOGGLE
const ABILITY_START_BUTTONS := InputFrameScript.BUTTON_ABILITY_Q \
	| InputFrameScript.BUTTON_ABILITY_E
const RESIDUAL_DASH_DECAY_PER_TICK := 0.68
const RESIDUAL_DASH_STOP_SPEED := 3.0
const LANDING_TELL_SEC := 0.16
const TAKEOFF_FLAP_TELL_SEC := 0.24
const LANDING_FLAP_TELL_SEC := 0.30
const TERRAIN_TRANSITION_TELL_SEC := 0.32
const TOXIC_RECOIL_TELL_SEC := 0.22
const ESCAPE_CURL_TELL_SEC := 0.24
const PLUNGE_TELL_SEC := 0.20
const AIR_ATTACK_STARTUP_TELL_SEC := 0.28
const LOW_WINDOW_VISUAL_MAX_SEC := 0.7
const SPORE_WARD_SOURCE := "Spore Ward"
const SPORE_WARD_PERIOD_SEC := 8.0
const SPORE_WARD_SLOW_DURATION_SEC := 2.0
const SPORE_WARD_SLOW_MULT := 0.75
const IRON_HIDE_OUT_OF_COMBAT_SEC := 4.0
const IRON_HIDE_BASE_REGEN_FRACTION_PER_SEC := 0.025
const DISABLED_PHYSICS_LAYER := 0
const DISABLED_PHYSICS_MASK := 0
const RENDER_TIMER_BUCKETS := 8.0
const RENDER_RATIO_BUCKETS := 32.0
const RENDER_ANGLE_BUCKETS := 32.0
const RENDER_PHASE_BUCKETS := 16.0
const VISUAL_SIZE_PROFILES := {
	"bullfrog": {"model_scale": 1.12, "height_units": 0.32, "height_class": "large_squat"},
	"chorus_frog": {"model_scale": 0.88, "height_units": 0.26, "height_class": "small_hopper"},
	"newt": {"model_scale": 0.9, "height_units": 0.18, "height_class": "slick_low"},
	"cane_toad": {"model_scale": 1.05, "height_units": 0.25, "height_class": "squat"},
	"snapping_turtle": {"model_scale": 1.0, "height_units": 0.28, "height_class": "heavy_low"},
	"water_snake": {"model_scale": 0.96, "height_units": 0.16, "height_class": "long_low"},
	"bog_turtle": {"model_scale": 0.82, "height_units": 0.2, "height_class": "tiny_low"},
	"alligator": {"model_scale": 1.18, "height_units": 0.35, "height_class": "long_low"},
	"owl": {"model_scale": 1.1, "height_units": 0.5, "flight_height_units": 1.45, "low_window_height_units": 0.42, "low_window_model_scale_bonus": 0.16, "air_attack_model_scale_bonus": 0.08, "air_attack_cue_base_mult": 1.22, "air_attack_cue_bonus_mult": 0.38, "height_class": "raptor"},
	"great_blue_heron": {"model_scale": 1.22, "height_units": 1.55, "flight_height_units": 1.65, "low_window_height_units": 0.72, "height_class": "tall_wader"},
	"kingfisher": {"model_scale": 0.96, "height_units": 0.48, "flight_height_units": 1.15, "low_window_height_units": 0.34, "low_window_model_scale_bonus": 0.16, "air_attack_model_scale_bonus": 0.14, "air_attack_cue_base_mult": 1.26, "air_attack_cue_bonus_mult": 0.42, "height_class": "small_diver"},
	"duck": {"model_scale": 1.04, "height_units": 0.45, "flight_height_units": 0.85, "low_window_height_units": 0.36, "air_attack_model_scale_bonus": 0.0, "height_class": "low_paddler"},
	"water_shrew": {"model_scale": 0.85, "height_units": 0.22, "height_class": "tiny_low"},
	"beaver": {"model_scale": 1.18, "height_units": 0.35, "height_class": "heavy_swimmer"},
	"otter": {"model_scale": 1.08, "height_units": 0.3, "height_class": "sleek_swimmer"},
	"mink": {"model_scale": 0.96, "height_units": 0.28, "height_class": "small_mustelid"},
	"leech": {"model_scale": 0.75, "height_units": 0.08, "height_class": "flat_cluster"},
	"crayfish": {"model_scale": 0.98, "height_units": 0.18, "height_class": "low_crustacean"},
	"mosquito_swarm": {"model_scale": 0.94, "height_units": 0.62, "flight_height_units": 0.75, "air_attack_model_scale_bonus": 0.18, "air_attack_cue_base_mult": 1.24, "air_attack_cue_bonus_mult": 0.4, "height_class": "swarm"},
	"wolf_spider": {"model_scale": 0.95, "height_units": 0.18, "height_class": "low_sprawler"},
	"firefly": {"model_scale": 0.82, "height_units": 0.55, "flight_height_units": 0.9, "air_attack_model_scale_bonus": 0.22, "air_attack_cue_base_mult": 1.24, "air_attack_cue_bonus_mult": 0.4, "height_class": "tiny_hoverer"}
}

var arena: Node = null
var terrain_map: RefCounted = null
var team := 0
var creature_id := ""
var creature_data: Dictionary = {}
var stats: Dictionary = {}
var movement_tags: Array = []
var state := CreatureStateScript.State.NORMAL
var input_frame: Resource = null
var action_policy_suppressed_buttons := 0
var max_health := 1.0
var health := 1.0
var body_radius := 8.0
var body_capsule_half_len_px := 0.0
var base_speed_px := 0.0
var terrain_speed_px := 0.0
var terrain_speed_target_px := 0.0
var movement_profile: Dictionary = {}
var current_terrain_zone := TerrainMapScript.LAND
var previous_terrain_zone := TerrainMapScript.LAND
var current_environment_profile: Dictionary = {}
var swim_time_max := 0.0
var swim_time_remaining := 0.0
var wrong_terrain_seconds := 0.0
var flight_time_max := 0.0
var flight_time_remaining := 0.0
var flight_grounded_timer := 0.0
var flight_toggle_was_pressed := false
var flight_toggle_just_pressed := false
var flight_toggle_requires_release := false
var takeoff_distance_px := 0.0
var alive := true
var actor_name := "Creature"
var kit: RefCounted = null
var primary_timer := 0.0
var q_timer := 0.0
var e_timer := 0.0
var q_charges := 0
var e_charges := 0
var steering_velocity := Vector2.ZERO
var dash_velocity := Vector2.ZERO
var dash_timer := 0.0
var residual_velocity := Vector2.ZERO
var pass_obstacles_timer := 0.0
var modifiers: Array[Dictionary] = []
var healing_ticks: Array[Dictionary] = []
var damage_ticks: Array[Dictionary] = []
var spore_ward_timer := 0.0
var spore_ward_absorb := 0.0
var secondary_resource_label := ""
var secondary_resource := 0.0
var secondary_resource_max := 0.0
var latched_attacker: Node = null
var latch_victim: Node = null
var latch_timer := 0.0
var latch_source := ""
var latch_sequence_id := 0
var latch_execute_timer := 0.0
var latch_move_multiplier := 1.0
var last_aim_direction := Vector2.RIGHT
var body_heading := Vector2.RIGHT
var render_hitstop_frames := 0
var render_counter_flash_timer := 0.0
var render_flash_timer := 0.0
var render_flash_region_mult := 1.0
var render_shake_timer := 0.0
var anim_walk_phase := 0.0
var anim_attack_timer := 0.0
var anim_attack_duration := 0.001
var anim_attack_reach := 0.0
var anim_attack_aim := Vector2.RIGHT
var anim_windup_timer := 0.0
var anim_windup_duration := 0.001
var render_landing_timer := 0.0
var render_landing_impact := 0.0
var render_last_hop_airborne := false
var render_takeoff_flap_timer := 0.0
var render_landing_flap_timer := 0.0
var render_terrain_transition_timer := 0.0
var render_terrain_from_surface := ""
var render_terrain_to_surface := ""
var render_toxic_recoil_timer := 0.0
var render_escape_curl_timer := 0.0
var render_plunge_timer := 0.0
var render_air_attack_startup_timer := 0.0
var render_air_attack_startup_duration := AIR_ATTACK_STARTUP_TELL_SEC
var last_move_displacement_px := 0.0
var stealth_timer := 0.0
var low_window_timer := 0.0
var counter_hit_window_timer := 0.0
var undamaged_timer := 0.0  # seconds since last took damage (Teratornis Sky Ambush window)
const AMBUSH_UNDAMAGED_SEC := 8.0
const TIDAL_VENOM_DURATION_SEC := 3.0
const TIDAL_VENOM_SOURCE := "Tidal Venom"
var respawn_timer := 0.0
var respawn_duration := 5.0
var hunger := HUNGER_MAX
var hunger_satiated := false
var primary_attack_timeline: RefCounted = AttackTimelineScript.new()
var _primary_attack_resolver := Callable()
var _primary_attack_variant := ""
var _primary_attack_presentation := {
	"attack_sequence_id": 0,
	"revision": 0,
	"projected_shape": null,
	"contact_point": null,
}
var _last_render_signature := ""

func setup(creature_arena: Node, creature_team: int, spawn_position: Vector2, next_creature_id: String, next_terrain_map: RefCounted = null) -> void:
	arena = creature_arena
	team = creature_team
	position = spawn_position
	terrain_map = next_terrain_map
	_disable_godot_physics_collision()
	apply_creature(next_creature_id)

func apply_creature(next_creature_id: String) -> void:
	_reset_primary_attack_timeline()
	creature_id = next_creature_id
	creature_data = _catalog().get_creature(creature_id)
	stats = creature_data.get("stats", {})
	movement_tags = creature_data.get("movement", [])
	max_health = _stat_float("health", 1.0)
	health = max_health
	body_radius = _effective_body_radius()
	body_capsule_half_len_px = _footprint_capsule_half_len_px()
	movement_profile = MovementFeelScript.profile_for(creature_id)
	base_speed_px = _speed_px_for_ground()
	swim_time_max = _effective_swim_time_max()
	swim_time_remaining = swim_time_max
	_reset_terrain_profile()
	flight_time_max = _numeric_stat("flight_time_sec", 0.0)
	flight_time_remaining = flight_time_max
	flight_grounded_timer = 0.0
	flight_toggle_was_pressed = false
	flight_toggle_just_pressed = false
	flight_toggle_requires_release = false
	takeoff_distance_px = 0.0
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	actor_name = String(creature_data.get("name", creature_id))
	modifiers.clear()
	healing_ticks.clear()
	damage_ticks.clear()
	spore_ward_timer = 0.0
	spore_ward_absorb = 0.0
	secondary_resource_label = ""
	secondary_resource = 0.0
	secondary_resource_max = 0.0
	latched_attacker = null
	latch_victim = null
	latch_timer = 0.0
	latch_source = ""
	latch_sequence_id = 0
	latch_execute_timer = 0.0
	steering_velocity = Vector2.ZERO
	residual_velocity = Vector2.ZERO
	render_landing_timer = 0.0
	render_landing_impact = 0.0
	render_last_hop_airborne = false
	render_takeoff_flap_timer = 0.0
	render_landing_flap_timer = 0.0
	render_terrain_transition_timer = 0.0
	render_terrain_from_surface = ""
	render_terrain_to_surface = ""
	render_toxic_recoil_timer = 0.0
	render_escape_curl_timer = 0.0
	render_plunge_timer = 0.0
	render_air_attack_startup_timer = 0.0
	render_air_attack_startup_duration = AIR_ATTACK_STARTUP_TELL_SEC
	render_hitstop_frames = 0
	render_counter_flash_timer = 0.0
	action_policy_suppressed_buttons = 0
	low_window_timer = 0.0
	counter_hit_window_timer = 0.0
	body_heading = last_aim_direction.normalized() if last_aim_direction != Vector2.ZERO else Vector2.RIGHT
	kit = _make_kit()
	if kit != null:
		kit.setup(self)
	alive = true
	hunger = HUNGER_MAX
	hunger_satiated = false
	_last_render_signature = ""
	_request_render_redraw(true)

func set_input_frame(next_frame: Resource) -> void:
	input_frame = next_frame

func _physics_process(delta: float) -> void:
	var perf_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	tick_sim(delta)
	if PerfStats.enabled:
		PerfStats.add("creatures", int(Time.get_ticks_usec() - perf_start))

func _process(delta: float) -> void:
	if render_hitstop_frames > 0:
		render_hitstop_frames -= 1
		_request_render_redraw()
		return
	render_counter_flash_timer = maxf(render_counter_flash_timer - delta, 0.0)
	render_flash_timer = maxf(render_flash_timer - delta, 0.0)
	render_shake_timer = maxf(render_shake_timer - delta, 0.0)
	render_takeoff_flap_timer = maxf(render_takeoff_flap_timer - delta, 0.0)
	render_landing_flap_timer = maxf(render_landing_flap_timer - delta, 0.0)
	render_terrain_transition_timer = maxf(render_terrain_transition_timer - delta, 0.0)
	render_toxic_recoil_timer = maxf(render_toxic_recoil_timer - delta, 0.0)
	render_escape_curl_timer = maxf(render_escape_curl_timer - delta, 0.0)
	render_plunge_timer = maxf(render_plunge_timer - delta, 0.0)
	render_air_attack_startup_timer = maxf(render_air_attack_startup_timer - delta, 0.0)
	anim_attack_timer = maxf(anim_attack_timer - delta, 0.0)
	anim_windup_timer = maxf(anim_windup_timer - delta, 0.0)
	if velocity.length() > 4.0:
		anim_walk_phase += MovementFeelScript.gait_phase_delta(velocity.length(), delta, _active_movement_profile())
	_update_render_landing(delta)
	_request_render_redraw()

func tick_sim(delta: float) -> void:
	if _match_is_over():
		if kit != null and kit.has_method("tick_match_end"):
			kit.tick_match_end(self, delta)
		action_policy_suppressed_buttons = 0
		return
	if not alive:
		if arena != null and arena.has_method("uses_stock_respawn") and arena.uses_stock_respawn(self):
			if arena.tick_stock_respawn(self, delta):
				_respawn()
		else:
			respawn_timer = maxf(respawn_timer - delta, 0.0)
			if respawn_timer <= 0.0:
				_respawn()
		return

	_tick_timers(delta)
	if not alive or _match_is_over():
		return
	input_frame = filter_action_start_frame(input_frame)
	_update_flight_toggle_edge()
	flight_grounded_timer = maxf(flight_grounded_timer - delta, 0.0)
	stealth_timer = maxf(stealth_timer - delta, 0.0)
	low_window_timer = maxf(low_window_timer - delta, 0.0)
	counter_hit_window_timer = maxf(counter_hit_window_timer - delta, 0.0)
	undamaged_timer += delta
	_update_flight(delta)
	_update_terrain(delta)
	if not alive or _match_is_over():
		return
	_move_from_input(delta)
	_update_body_heading(delta)
	_tick_hunger(delta)
	if not alive or _match_is_over():
		return
	_try_auto_eat()
	_update_takeoff_charge_from_displacement(last_move_displacement_px)
	_tick_latch(delta)
	if _match_is_over():
		return
	_refresh_primary_attack_presentation()
	_advance_primary_attack_timeline(delta)
	if not alive or _match_is_over():
		return
	if kit != null and kit.has_method("tick"):
		kit.tick(self, delta)
		if _match_is_over():
			action_policy_suppressed_buttons = 0
			return
	_commit_flight_toggle_edge()
	action_policy_suppressed_buttons = 0

func _match_is_over() -> bool:
	return arena != null and arena.get("match_over") == true

func on_match_ended() -> void:
	if kit != null and kit.has_method("tick_match_end"):
		kit.tick_match_end(self, 0.0)
	action_policy_suppressed_buttons = 0

func take_damage(amount: float, _source_team: int = -1, _source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, _source_actor, "")
	take_damage_event(event)

func take_area_damage(amount: float, source_ability := "", source_actor: Node = null) -> void:
	var event := DamageEventScript.new()
	event.setup(amount, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
	take_damage_event(event)

func begin_render_hitstop(_duration := 0.0) -> void:
	render_hitstop_frames = maxi(render_hitstop_frames, HITSTOP_FRAMES)
	_request_render_redraw(true)

func begin_render_counter_flash() -> void:
	render_counter_flash_timer = COUNTER_FLASH_SEC
	_request_render_redraw(true)

func begin_counter_hit_window(duration: float) -> void:
	counter_hit_window_timer = maxf(counter_hit_window_timer, duration)

func begin_render_toxic_recoil(duration := TOXIC_RECOIL_TELL_SEC) -> void:
	render_toxic_recoil_timer = maxf(render_toxic_recoil_timer, duration)
	_request_render_redraw(true)

func begin_render_escape_curl(duration := ESCAPE_CURL_TELL_SEC) -> void:
	render_escape_curl_timer = maxf(render_escape_curl_timer, duration)
	_request_render_redraw(true)

func begin_render_plunge(duration := PLUNGE_TELL_SEC) -> void:
	render_plunge_timer = maxf(render_plunge_timer, duration)
	_request_render_redraw(true)

func begin_render_air_attack_startup(duration := AIR_ATTACK_STARTUP_TELL_SEC) -> void:
	render_air_attack_startup_duration = maxf(duration, 0.001)
	render_air_attack_startup_timer = maxf(render_air_attack_startup_timer, render_air_attack_startup_duration)
	_request_render_redraw(true)

func begin_render_takeoff_flap(duration := TAKEOFF_FLAP_TELL_SEC) -> void:
	render_takeoff_flap_timer = maxf(render_takeoff_flap_timer, duration)
	_request_render_redraw(true)

func begin_render_landing_flap(duration := LANDING_FLAP_TELL_SEC, impact := 0.9) -> void:
	render_landing_flap_timer = maxf(render_landing_flap_timer, duration)
	render_landing_timer = maxf(render_landing_timer, LANDING_TELL_SEC)
	render_landing_impact = maxf(render_landing_impact, impact)
	_request_render_redraw(true)

func begin_render_terrain_transition(from_surface: String, to_surface: String, duration := TERRAIN_TRANSITION_TELL_SEC) -> void:
	if from_surface == "" or to_surface == "" or from_surface == to_surface:
		return
	render_terrain_from_surface = from_surface
	render_terrain_to_surface = to_surface
	render_terrain_transition_timer = maxf(render_terrain_transition_timer, duration)
	_request_render_redraw(true)

func begin_stealth(duration: float, _source: String) -> void:
	stealth_timer = duration

func break_stealth() -> void:
	stealth_timer = 0.0

func is_stealthed() -> bool:
	return stealth_timer > 0.0

func can_act() -> bool:
	# Stun/self-lock modifiers (e.g. Lingual Lure) zero out can_act_mult.
	return alive and _modifier_value("can_act_mult", 1.0) > 0.5

func can_use_abilities() -> bool:
	return can_act() and _modifier_value("ability_use_mult", 1.0) > 0.5

func request_primary_attack(variant: String, payload: Dictionary, resolver: Callable) -> bool:
	if variant.is_empty() \
		or not alive \
		or not can_act() \
		or primary_timer > 0.0 \
		or not resolver.is_valid():
		return false

	var timelines_value: Variant = stats.get("action_timelines", {})
	if typeof(timelines_value) != TYPE_DICTIONARY:
		return false
	var timeline_definitions: Dictionary = timelines_value
	var config_value: Variant = timeline_definitions.get(variant, {})
	if typeof(config_value) != TYPE_DICTIONARY:
		return false
	var config: Dictionary = config_value
	if config.is_empty():
		return false

	var simulation_tick := _primary_attack_simulation_tick()
	var time_scale := _modifier_value("attack_speed_mult", 1.0)
	if simulation_tick < 0 or not _is_positive_finite_number(time_scale):
		return false
	var strike_heading := get_aim_direction()
	if not primary_attack_timeline.start(
		config,
		payload,
		strike_heading,
		simulation_tick,
		time_scale
	):
		return false

	_primary_attack_variant = variant
	_primary_attack_resolver = resolver
	_begin_primary_attack_presentation(
		int(primary_attack_timeline.snapshot()["attack_sequence_id"])
	)
	primary_timer = _primary_attack_cooldown_sec(config) / time_scale
	_request_render_redraw(true)
	return true

func interrupt_primary_attack(reason: String, hard := false) -> Dictionary:
	var event: Dictionary = primary_attack_timeline.interrupt(
		reason,
		_primary_attack_simulation_tick(),
		hard
	)
	if bool(event.get("changed", false)):
		if hard:
			_primary_attack_resolver = Callable()
			_primary_attack_variant = ""
			_clear_primary_attack_presentation()
			_request_render_redraw(true)
	return event

func get_primary_attack_snapshot() -> Dictionary:
	var snapshot: Dictionary = primary_attack_timeline.snapshot()
	snapshot["attack_variant"] = _primary_attack_variant
	snapshot["presentation_sequence_id"] = int(
		_primary_attack_presentation["attack_sequence_id"]
	)
	snapshot["presentation_revision"] = int(
		_primary_attack_presentation["revision"]
	)
	snapshot["contact_point"] = _copy_primary_attack_presentation_variant(
		_primary_attack_presentation["contact_point"]
	)
	snapshot["projected_shape"] = _copy_primary_attack_presentation_variant(
		_primary_attack_presentation["projected_shape"]
	)
	return snapshot

func update_primary_attack_presentation(
	attack_sequence_id: int,
	updates: Dictionary
) -> bool:
	if primary_attack_timeline.is_idle() or updates.is_empty():
		return false
	var timeline_snapshot: Dictionary = primary_attack_timeline.snapshot()
	if attack_sequence_id <= 0 \
		or attack_sequence_id != int(timeline_snapshot["attack_sequence_id"]) \
		or attack_sequence_id != int(
			_primary_attack_presentation["attack_sequence_id"]
		):
		return false

	var allowed := {
		"projected_shape": true,
		"contact_point": true,
	}
	var copied_updates := {}
	for key_value: Variant in updates:
		if typeof(key_value) != TYPE_STRING and typeof(key_value) != TYPE_STRING_NAME:
			return false
		var key := String(key_value)
		if not allowed.has(key):
			return false
		var value: Variant = updates[key_value]
		if key == "projected_shape":
			if value != null and typeof(value) != TYPE_DICTIONARY:
				return false
		elif key == "contact_point":
			if value != null and (
				typeof(value) != TYPE_VECTOR2
				or not (value as Vector2).is_finite()
			):
				return false
		var copy_result := _copy_primary_attack_presentation_value(value)
		if not bool(copy_result["valid"]):
			return false
		copied_updates[key] = copy_result["value"]

	var presentation_changed := false
	for key: String in copied_updates:
		if _primary_attack_presentation[key] != copied_updates[key]:
			_primary_attack_presentation[key] = copied_updates[key]
			presentation_changed = true
	if not presentation_changed:
		return true
	_primary_attack_presentation["revision"] = int(
		_primary_attack_presentation["revision"]
	) + 1
	_request_render_redraw()
	return true

func is_primary_attack_committed() -> bool:
	return not primary_attack_timeline.is_idle()

func get_authoritative_action_phase_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var seen := {}
	if is_primary_attack_committed():
		var snapshot := get_primary_attack_snapshot()
		var primary_record := {
			"action_id": StringName(_primary_attack_variant),
			"sequence_id": int(snapshot.get("attack_sequence_id", 0)),
			"phase": StringName(snapshot.get("attack_phase_name", "")),
			"counter_vulnerable": String(snapshot.get("attack_phase_name", "")) == "startup",
		}
		if not _append_valid_action_phase_record(records, seen, primary_record):
			return []
	if kit != null and kit.has_method("get_action_phase_records"):
		var kit_records: Variant = kit.get_action_phase_records()
		if typeof(kit_records) != TYPE_ARRAY:
			return []
		for record_value: Variant in kit_records:
			if typeof(record_value) != TYPE_DICTIONARY \
				or not _append_valid_action_phase_record(records, seen, record_value):
				return []
	records.sort_custom(_action_phase_record_before)
	return records

func _append_valid_action_phase_record(
	records: Array[Dictionary],
	seen: Dictionary,
	record_value: Dictionary
) -> bool:
	var action_value: Variant = record_value.get("action_id", "")
	var sequence_value: Variant = record_value.get("sequence_id", 0)
	var phase_value: Variant = record_value.get("phase", "")
	var counter_value: Variant = record_value.get("counter_vulnerable", null)
	if (typeof(action_value) != TYPE_STRING and typeof(action_value) != TYPE_STRING_NAME) \
		or String(action_value).is_empty() \
		or typeof(sequence_value) != TYPE_INT \
		or int(sequence_value) <= 0 \
		or (typeof(phase_value) != TYPE_STRING and typeof(phase_value) != TYPE_STRING_NAME) \
		or not ["startup", "active", "recovery", "channel", "exit"].has(String(phase_value)) \
		or typeof(counter_value) != TYPE_BOOL \
		or bool(counter_value) != (String(phase_value) == "startup"):
		return false
	var key := "%s:%d" % [String(action_value), int(sequence_value)]
	if seen.has(key):
		return false
	seen[key] = true
	records.append({
		"action_id": StringName(action_value),
		"sequence_id": int(sequence_value),
		"phase": StringName(phase_value),
		"counter_vulnerable": bool(counter_value),
	})
	return true

func _action_phase_record_before(left: Dictionary, right: Dictionary) -> bool:
	var left_id := String(left.get("action_id", ""))
	var right_id := String(right.get("action_id", ""))
	if left_id != right_id:
		return left_id < right_id
	return int(left.get("sequence_id", 0)) < int(right.get("sequence_id", 0))

func primary_attack_has_phase_tag(tag: String) -> bool:
	return primary_attack_timeline.has_phase_tag(tag)

func open_low_window(duration: float) -> void:
	low_window_timer = duration

func is_region_open(open_when: String) -> bool:
	match open_when:
		"always":
			return true
		"low_window":
			return low_window_timer > 0.0
		"stunned":
			return not can_act()
		"bask":
			return _has_modifier_source("Basking")
		"lunge":
			return dash_timer > 0.0
		_:
			return false

func _dodges_event(event: Resource) -> bool:
	# Elevated creatures (true flight or perch, not always-flying bugs) dodge
	# ground melee — except during their low attack window.
	if event.delivery != DamageEventScript.DELIVERY_MELEE or event.plane != DamageEventScript.PLANE_GROUND:
		return false
	if low_window_timer > 0.0 or has_movement("always_flying"):
		return false
	return state == CreatureStateScript.State.AIRBORNE or state == CreatureStateScript.State.PERCHED

func take_damage_event(event: Resource) -> void:
	if not alive:
		return
	if _dodges_event(event):
		emit_vfx_event("attack_dodged", {"target": self, "position": global_position})
		return
	break_stealth()
	var before_health := health
	var amount: float = _modified_incoming_damage(event)
	var counter_hit := amount > 0.0 \
		and _is_valid_enemy_counter_source(event) \
		and _is_counter_vulnerable()
	if counter_hit:
		amount *= COUNTER_HIT_MULT
	amount = _apply_spore_ward_absorb(event, amount)
	if amount > 0.0:
		undamaged_timer = 0.0  # actual health damage resets Sky Ambush and Iron Hide windows
	if health - amount <= 0.0 and kit != null and kit.has_method("intercept_fatal_damage"):
		if kit.intercept_fatal_damage(self, event, amount):
			return
	health = maxf(health - amount, 0.0)
	if event.delivery == DamageEventScript.DELIVERY_MELEE and event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor != self:
		if kit != null and kit.has_method("on_melee_contact_damage"):
			kit.on_melee_contact_damage(self, event.source_actor, amount, event)
	if kit != null and kit.has_method("on_damage_taken"):
		kit.on_damage_taken(self, event, amount, before_health)
	# Struggle hit (decision #33): the victim's melee blows chunk the grip.
	if latch_victim != null and is_instance_valid(latch_victim) and event.source_actor == latch_victim and event.delivery == DamageEventScript.DELIVERY_MELEE:
		latch_timer = maxf(latch_timer - 0.75, 0.0)
		latch_victim.latch_timer = latch_timer
	# Spike rule (decision #20): a heavy ranged hit grounds a flying bird.
	if state == CreatureStateScript.State.AIRBORNE and not has_movement("always_flying") and event.delivery == DamageEventScript.DELIVERY_RANGED and amount >= 30.0:
		state = CreatureStateScript.State.NORMAL
		flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
		flight_toggle_requires_release = true
		begin_render_landing_flap(LANDING_FLAP_TELL_SEC, 1.15)
		emit_vfx_event("spiked", {"target": self, "position": global_position})
	if event.source_actor != null or String(event.source_ability) != "":
		if amount >= 50.0:
			begin_render_hitstop()
			if event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor.has_method("begin_render_hitstop"):
				event.source_actor.begin_render_hitstop()
		if counter_hit:
			begin_render_counter_flash()
			emit_vfx_event("counter_hit", {
				"source": event.source_actor,
				"target": self,
				"position": event.hit_position if event.hit_position != Vector2.ZERO else global_position,
				"source_ability": event.source_ability
			})
		emit_vfx_event("hit_landed", {
			"source": event.source_actor,
			"target": self,
			"amount": amount,
			"heavy": amount >= 50.0,
			"counter_hit": counter_hit,
			"position": global_position,
			"hit_position": event.hit_position,
			"hit_normal": event.hit_normal,
			"region": event.region,
			"region_mult": event.region_mult,
			"source_ability": event.source_ability
		})
		if amount > 0.0 and event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor.has_method("on_damage_dealt"):
			event.source_actor.on_damage_dealt(self, event, amount)
	if health <= 0.0:
		_reset_primary_attack_timeline()
		if event.source_actor != null and is_instance_valid(event.source_actor) and event.source_actor.has_method("on_kill"):
			event.source_actor.on_kill(self)
		if arena != null and arena.has_method("record_death"):
			arena.record_death(self, event.source_actor)
		if latch_victim != null:
			release_latch("death")
		if latched_attacker != null and is_instance_valid(latched_attacker):
			latched_attacker.release_latch("victim_death")
		break_stealth()
		low_window_timer = 0.0
		state = CreatureStateScript.State.NORMAL
		alive = false
		visible = false
		velocity = Vector2.ZERO
		respawn_timer = respawn_duration
		if arena != null and arena.has_method("unregister_entity"):
			arena.unregister_entity(self)

func heal(amount: float) -> void:
	if alive:
		var before := health
		health = minf(health + amount * _modifier_value("healing_received_mult", 1.0) * (1.0 + _team_boss_stock_bonus("healing_received")), max_health)
		var healed := health - before
		if healed > 0.0:
			emit_vfx_event("heal_tick", {
				"target": self,
				"amount": healed,
				"position": global_position
			})

func apply_dot(source_actor: Node, source_ability: String, total_damage: float, duration: float, max_stacks := 0) -> void:
	if not alive or total_damage <= 0.0 or duration <= 0.0:
		return
	if max_stacks > 0:
		var matching := 0
		var oldest_index := -1
		for i in damage_ticks.size():
			var tick: Dictionary = damage_ticks[i]
			if String(tick.get("source_ability", "")) == source_ability and tick.get("source_actor", null) == source_actor:
				matching += 1
				if oldest_index < 0:
					oldest_index = i
		if matching >= max_stacks and oldest_index >= 0:
			damage_ticks.remove_at(oldest_index)
	damage_ticks.append({
		"remaining": duration,
		"amount_remaining": total_damage,
		"per_second": total_damage / duration,
		"source_actor": source_actor,
		"source_ability": source_ability
	})

func get_secondary_resource_state() -> Dictionary:
	var max_value := maxf(secondary_resource_max, 0.0)
	return {
		"visible": max_value > 0.0,
		"label": secondary_resource_label,
		"value": clampf(secondary_resource, 0.0, max_value),
		"max": max_value,
		"ratio": clampf(secondary_resource / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	}

func can_eat_food_kind(food_kind: String) -> bool:
	var diet := String(creature_data.get("diet", "omnivore"))
	if food_kind == "plant":
		return diet == "herbivore" or diet == "omnivore" or diet == "nectarivore"
	if food_kind == "critter":
		return diet == "carnivore" or diet == "omnivore"
	return false

func consume_food(kind: String, food_value: float, heal_fraction: float) -> bool:
	if not alive or not can_eat_food_kind(kind):
		return false
	var before := hunger
	hunger = minf(hunger + food_value, HUNGER_MAX)
	if hunger >= HUNGER_MAX:
		hunger_satiated = true
	heal(max_health * heal_fraction)
	if arena != null and arena.has_method("record_food_consumed"):
		arena.record_food_consumed(self, kind, hunger - before)
	return true

func refresh_team_breeding_buffs() -> void:
	var previous_max := maxf(max_health, 0.001)
	var health_ratio := clampf(health / previous_max, 0.0, 1.0)
	var previous_swim_max := maxf(swim_time_max, 0.001)
	var swim_ratio := clampf(swim_time_remaining / previous_swim_max, 0.0, 1.0) if swim_time_max > 0.0 else 1.0
	max_health = _stat_float("health", 1.0)
	health = clampf(max_health * health_ratio, 0.0, max_health)
	body_radius = _effective_body_radius()  # Arthropleura habitat-stock size buff
	swim_time_max = _effective_swim_time_max()
	swim_time_remaining = clampf(swim_time_max * swim_ratio, 0.0, swim_time_max)
	base_speed_px = _speed_px_for_ground()
	terrain_speed_target_px = _terrain_target_speed_px(current_terrain_zone)
	terrain_speed_px = terrain_speed_target_px
	_request_render_redraw(true)

func _effective_body_radius() -> float:
	return _footprint_radius_px() * (1.0 + _team_boss_stock_bonus("size") + _team_kill_growth_bonus())

func _effective_swim_time_max() -> float:
	var base := _numeric_stat("swim_time_sec", 0.0)
	if base <= 0.0:
		return 0.0
	return base * (1.0 + _team_boss_stock_bonus("swim_duration"))

func is_satiated() -> bool:
	return hunger_satiated

func reset_hunger_after_deposit() -> void:
	hunger_satiated = false
	hunger = HUNGER_MAX * 0.8

func emit_vfx_event(event_type: String, payload: Dictionary = {}) -> void:
	_apply_own_anim(event_type, payload)
	if arena == null or not arena.has_method("record_vfx_event"):
		return
	var event := payload.duplicate()
	event["type"] = event_type
	arena.record_vfx_event(event)

func _apply_own_anim(event_type: String, payload: Dictionary) -> void:
	if payload.get("actor", null) != self:
		return
	match event_type:
		"windup_started":
			var windup_duration := maxf(
				float(payload.get("duration", 0.001)),
				0.001
			)
			if payload.get("counter_hit_window", false) == true:
				begin_counter_hit_window(windup_duration)
			if payload.get("timeline_owned", false) == true:
				return
			anim_windup_duration = windup_duration
			anim_windup_timer = anim_windup_duration
		"attack_swung":
			break_stealth()
			if payload.get("timeline_owned", false) == true:
				return
			anim_attack_duration = clampf(_attack_interval_sec() * 0.55, 0.32, 0.6)
			anim_attack_timer = anim_attack_duration
			anim_attack_reach = float(payload.get("reach_px", body_radius * 1.5))
			anim_attack_aim = payload.get("aim", last_aim_direction)
			anim_windup_timer = 0.0

func apply_render_hit_feedback(amount: float, region_mult := 1.0) -> void:
	render_flash_timer = 0.1
	render_flash_region_mult = clampf(region_mult, 0.75, 1.35)
	if amount >= 50.0:
		render_shake_timer = 0.1
	_request_render_redraw(true)

func is_alive() -> bool:
	return alive

func get_actor_name() -> String:
	return actor_name

func is_scored_actor() -> bool:
	return true

func is_airborne() -> bool:
	return state == CreatureStateScript.State.AIRBORNE or has_movement("always_flying")

func is_untargetable() -> bool:
	return _modifier_value("untargetable", 1.0) > 1.5

func has_movement(tag: String) -> bool:
	if movement_tags.has(tag):
		return true
	if tag == "ground_walker":
		return movement_tags.has("land_walker")
	if tag == "land_walker":
		return movement_tags.has("ground_walker")
	return false

func get_current_zone() -> String:
	if arena != null and arena.has_method("get_terrain_zone"):
		return arena.get_terrain_zone(global_position)
	if terrain_map != null:
		return terrain_map.get_zone_at(global_position)
	return TerrainMapScript.LAND

func get_speed_px() -> float:
	if is_airborne():
		return _speed_px_for_flight()
	return terrain_speed_px if terrain_speed_px > 0.0 else _terrain_target_speed_px(get_current_zone())

func get_render_motion_state() -> Dictionary:
	var surface := String(current_environment_profile.get("surface", ""))
	var moving: bool = velocity.length() > 4.0 or (input_frame != null and input_frame.move.length() > 0.05)
	var water_walk_active: bool = get_modifier_value("water_walk", 1.0) > 1.5
	var backward_dash := dash_timer > 0.0 and dash_velocity.length() > 0.0 and dash_velocity.normalized().dot(-last_aim_direction.normalized()) > 0.55
	var landing_t := clampf(render_landing_timer / LANDING_TELL_SEC, 0.0, 1.0) if LANDING_TELL_SEC > 0.0 else 0.0
	var takeoff_charge_t := _takeoff_charge_render_t()
	var takeoff_flap_t := clampf(render_takeoff_flap_timer / TAKEOFF_FLAP_TELL_SEC, 0.0, 1.0) if TAKEOFF_FLAP_TELL_SEC > 0.0 else 0.0
	var landing_flap_t := clampf(render_landing_flap_timer / LANDING_FLAP_TELL_SEC, 0.0, 1.0) if LANDING_FLAP_TELL_SEC > 0.0 else 0.0
	var grounded_lockout_t := clampf(flight_grounded_timer / FLIGHT_GROUNDED_LOCKOUT_SEC, 0.0, 1.0) if FLIGHT_GROUNDED_LOCKOUT_SEC > 0.0 and has_movement("flight") and not has_movement("always_flying") else 0.0
	var bird_transition_pose := has_movement("flight") and not has_movement("always_flying") and maxf(maxf(takeoff_charge_t, takeoff_flap_t), maxf(landing_flap_t, grounded_lockout_t)) > 0.0
	var terrain_transition_t := clampf(render_terrain_transition_timer / TERRAIN_TRANSITION_TELL_SEC, 0.0, 1.0) if TERRAIN_TRANSITION_TELL_SEC > 0.0 else 0.0
	var water_entry_t := terrain_transition_t if render_terrain_to_surface == EnvironmentProfileScript.SURFACE_WATER and render_terrain_from_surface != EnvironmentProfileScript.SURFACE_WATER else 0.0
	var water_exit_t := terrain_transition_t if render_terrain_from_surface == EnvironmentProfileScript.SURFACE_WATER and render_terrain_to_surface != EnvironmentProfileScript.SURFACE_WATER else 0.0
	var mud_entry_t := terrain_transition_t if render_terrain_to_surface == EnvironmentProfileScript.SURFACE_MUD and render_terrain_from_surface != EnvironmentProfileScript.SURFACE_MUD else 0.0
	var mud_exit_t := terrain_transition_t if render_terrain_from_surface == EnvironmentProfileScript.SURFACE_MUD and render_terrain_to_surface != EnvironmentProfileScript.SURFACE_MUD else 0.0
	var terrain_splash_t := maxf(water_entry_t, water_exit_t)
	var terrain_scuff_t := maxf(mud_entry_t, mud_exit_t)
	var latch_attacking := latch_victim != null and is_instance_valid(latch_victim)
	var latch_being_held := latched_attacker != null and is_instance_valid(latched_attacker)
	var latch_source_name := String(latch_source)
	var predator_hold_t := 1.0 if latch_attacking else 0.0
	var water_snake_coil := creature_id == "water_snake" and latch_attacking and latch_source_name == "Bite"
	var alligator_jaw_hold := creature_id == "alligator" and latch_attacking and latch_source_name == "Bite"
	var alligator_death_roll := creature_id == "alligator" and latch_attacking and latch_source_name == "Death Roll"
	var mink_choke := creature_id == "mink" and latch_attacking and latch_source_name == "Choke"
	var otter_pack_latch := creature_id == "otter" and latch_attacking and (latch_source_name == "Bite" or latch_source_name == "Gang Up")
	var toxic_recoil_t := clampf(render_toxic_recoil_timer / TOXIC_RECOIL_TELL_SEC, 0.0, 1.0) if TOXIC_RECOIL_TELL_SEC > 0.0 else 0.0
	var escape_curl_t := clampf(render_escape_curl_timer / ESCAPE_CURL_TELL_SEC, 0.0, 1.0) if ESCAPE_CURL_TELL_SEC > 0.0 else 0.0
	var plunge_t := clampf(render_plunge_timer / PLUNGE_TELL_SEC, 0.0, 1.0) if PLUNGE_TELL_SEC > 0.0 else 0.0
	var surface_walk := creature_id == "water_shrew" and water_walk_active and moving and surface == EnvironmentProfileScript.SURFACE_WATER
	var wake_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if surface_walk else 0.0
	var shrew_submerged := creature_id == "water_shrew" and surface == EnvironmentProfileScript.SURFACE_WATER and not surface_walk
	var shrew_submerged_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if shrew_submerged and moving else 0.0
	var shrew_land_skitter := creature_id == "water_shrew" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var shrew_land_skitter_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if shrew_land_skitter else 0.0
	var chorus_hop := creature_id == "chorus_frog" and moving and not is_airborne()
	var chorus_hop_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if chorus_hop else 0.0
	var bullfrog_lunge: bool = creature_id == "bullfrog" and kit != null and kit.get("lunge_active") == true
	var bullfrog_camouflage := creature_id == "bullfrog" and stealth_timer > 0.0
	var bullfrog_coil := creature_id == "bullfrog" and (bullfrog_lunge or bullfrog_camouflage)
	var bullfrog_lunge_intensity := clampf(dash_timer / 0.18, 0.0, 1.0) if bullfrog_lunge else 0.0
	var bullfrog_coil_intensity := 1.0 if bullfrog_camouflage else maxf(0.55, bullfrog_lunge_intensity) if bullfrog_lunge else 0.0
	var bullfrog_heavy_hop := creature_id == "bullfrog" and moving and not is_airborne() and not bullfrog_coil
	var bullfrog_heavy_hop_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if bullfrog_heavy_hop else 0.0
	var cane_squat_hop := creature_id == "cane_toad" and moving and not is_airborne() and not _has_modifier_source("Thanatosis")
	var cane_squat_hop_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if cane_squat_hop else 0.0
	var alligator_water_cruise := creature_id == "alligator" and moving and surface == EnvironmentProfileScript.SURFACE_WATER and not is_airborne() and not _has_modifier_source("Ambush")
	var alligator_water_cruise_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if alligator_water_cruise else 0.0
	var alligator_high_walk := creature_id == "alligator" and moving and surface != EnvironmentProfileScript.SURFACE_WATER and not _has_modifier_source("Ambush")
	var heron_wading := creature_id == "great_blue_heron" and surface == EnvironmentProfileScript.SURFACE_WATER and not is_airborne() and state != CreatureStateScript.State.PERCHED
	var heron_stalk := creature_id == "great_blue_heron" and moving and surface != EnvironmentProfileScript.SURFACE_WATER and not is_airborne() and state != CreatureStateScript.State.PERCHED
	var wading_stride := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if heron_wading and moving else 0.0
	var heron_stalk_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if heron_stalk else 0.0
	var newt_crawling := creature_id == "newt" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne() and state != CreatureStateScript.State.PERCHED
	var newt_swimming := creature_id == "newt" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne() and state != CreatureStateScript.State.PERCHED
	var newt_tail_lost := creature_id == "newt" and kit != null and float(kit.get("tail_lost_timer")) > 0.0
	var newt_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if newt_crawling or newt_swimming else 0.0
	var water_snake_swim := creature_id == "water_snake" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var water_snake_land_slither := creature_id == "water_snake" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var water_snake_mud_slither := water_snake_land_slither and (surface == EnvironmentProfileScript.SURFACE_MUD or surface == EnvironmentProfileScript.SURFACE_COVER)
	var water_slither_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if water_snake_swim or water_snake_land_slither else 0.0
	var turtle_swim := creature_id == "snapping_turtle" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var turtle_plod := creature_id == "snapping_turtle" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var turtle_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if turtle_swim or turtle_plod else 0.0
	var bog_turtle_creep := creature_id == "bog_turtle" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var bog_turtle_paddle := creature_id == "bog_turtle" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var bog_turtle_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if bog_turtle_creep or bog_turtle_paddle else 0.0
	var wolf_spider_lunge: bool = creature_id == "wolf_spider" and kit != null and kit.get("lunge_active") == true
	var wolf_spider_burrowed := creature_id == "wolf_spider" and state == CreatureStateScript.State.BURROWED
	var wolf_spider_latched := creature_id == "wolf_spider" and latch_victim != null and latch_source == "Bite"
	var wolf_spider_skitter := creature_id == "wolf_spider" and moving and not is_airborne() and not wolf_spider_lunge and not wolf_spider_burrowed and not wolf_spider_latched
	var wolf_spider_skitter_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if wolf_spider_skitter else 0.0
	var firefly_hover := creature_id == "firefly" and moving
	var firefly_hover_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if firefly_hover else 0.0
	var firefly_flash := creature_id == "firefly" and kit != null and float(kit.get("flash_timer")) > 0.0
	var mosquito_swarm := creature_id == "mosquito_swarm" and moving
	var mosquito_swarm_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if mosquito_swarm else 0.0
	var mosquito_trail := creature_id == "mosquito_swarm" and kit != null and float(kit.get("trail_timer")) > 0.0
	var mosquito_blood_ratio := clampf(secondary_resource / maxf(secondary_resource_max, 1.0), 0.0, 1.0) if creature_id == "mosquito_swarm" else 0.0
	var duck_paddle := creature_id == "duck" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var duck_waddle := creature_id == "duck" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var duck_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if duck_paddle or duck_waddle else 0.0
	var owl_glide := creature_id == "owl" and state == CreatureStateScript.State.AIRBORNE and moving
	var owl_glide_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if owl_glide else 0.0
	var owl_silent := creature_id == "owl" and stealth_timer > 0.0
	var kingfisher_dart := creature_id == "kingfisher" and state == CreatureStateScript.State.AIRBORNE and moving and plunge_t <= 0.0
	var kingfisher_dart_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if kingfisher_dart else 0.0
	var beaver_swim := creature_id == "beaver" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var beaver_lumber := creature_id == "beaver" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var beaver_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if beaver_swim or beaver_lumber else 0.0
	var mink_bound := creature_id == "mink" and moving and surface != EnvironmentProfileScript.SURFACE_WATER and not is_airborne()
	var mink_swim := creature_id == "mink" and moving and surface == EnvironmentProfileScript.SURFACE_WATER and not is_airborne()
	var mink_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if mink_bound or mink_swim else 0.0
	var otter_swim := creature_id == "otter" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var otter_land_slide := creature_id == "otter" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var otter_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if otter_swim or otter_land_slide else 0.0
	var crayfish_scuttle := creature_id == "crayfish" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var crayfish_tail_flick_swim := creature_id == "crayfish" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var crayfish_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if crayfish_scuttle or crayfish_tail_flick_swim else 0.0
	var leech_undulate := creature_id == "leech" and surface == EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var leech_inchworm := creature_id == "leech" and surface != EnvironmentProfileScript.SURFACE_WATER and moving and not is_airborne()
	var leech_motion_intensity := clampf(velocity.length() / maxf(get_speed_px(), 1.0), 0.0, 1.25) if leech_undulate or leech_inchworm else 0.0
	var visual_size_profile := _visual_size_profile()
	var visual_height_units := _visual_height_units(visual_size_profile)
	var low_window_t := _low_window_render_t()
	var base_model_scale := float(visual_size_profile.get("model_scale", 1.0))
	var low_window_scale_bonus := float(visual_size_profile.get("low_window_model_scale_bonus", 0.08)) * low_window_t if is_airborne() and low_window_t > 0.0 else 0.0
	var air_attack_release_t := clampf(anim_attack_timer / maxf(anim_attack_duration, 0.001), 0.0, 1.0) if is_airborne() and anim_attack_timer > 0.0 else 0.0
	var air_attack_startup_t := clampf(render_air_attack_startup_timer / maxf(render_air_attack_startup_duration, 0.001), 0.0, 1.0) if is_airborne() and render_air_attack_startup_timer > 0.0 else 0.0
	var air_attack_cue_t := maxf(maxf(low_window_t, air_attack_release_t), air_attack_startup_t * 0.85)
	var air_attack_cue := is_airborne() and air_attack_cue_t > 0.0
	var air_attack_scale_bonus := float(visual_size_profile.get("air_attack_model_scale_bonus", 0.0)) * air_attack_release_t
	var visual_model_scale := minf(1.35, base_model_scale + low_window_scale_bonus + air_attack_scale_bonus)
	var visual_radius_px := body_radius * visual_model_scale
	var silhouette_contract := VisualStyle.creature_silhouette_contract(creature_id, body_radius, visual_model_scale, body_capsule_half_len_px)
	var open_hurtbox_regions := HurtboxScript.open_regions(self)
	var air_attack_cue_base_mult := float(visual_size_profile.get("air_attack_cue_base_mult", 1.12))
	var air_attack_cue_bonus_mult := float(visual_size_profile.get("air_attack_cue_bonus_mult", 0.22))
	var air_attack_cue_radius_px := visual_radius_px * (air_attack_cue_base_mult + air_attack_cue_t * air_attack_cue_bonus_mult) if air_attack_cue else 0.0
	var airborne_visual := is_airborne() or state == CreatureStateScript.State.PERCHED
	var height_shadow_alpha := _height_shadow_alpha(visual_height_units, low_window_t, airborne_visual)
	var height_shadow_radius_mult := _height_shadow_radius_mult(visual_height_units, low_window_t, airborne_visual)
	var timeline_snapshot: Dictionary = get_primary_attack_snapshot()
	var render_attack_variant := String(timeline_snapshot["attack_variant"])
	if render_attack_variant == "alligator_bite":
		render_attack_variant = "bite"
	return {
		"creature_id": creature_id,
		"terrain_surface": surface,
		"model_scale": visual_model_scale,
		"base_model_scale": base_model_scale,
		"combat_radius_px": body_radius,
		"visual_radius_px": visual_radius_px,
		"truth_ring_radius_px": body_radius,
		"silhouette_archetype": String(silhouette_contract.get("archetype", "")),
		"silhouette_features": silhouette_contract.get("silhouette_features", []),
		"filled_mass_radius_px": float(silhouette_contract.get("filled_mass_radius_px", 0.0)),
		"filled_mass_radius_mult": float(silhouette_contract.get("filled_mass_radius_mult", 0.0)),
		"wide_filled_overhang_limit_mult": float(silhouette_contract.get("wide_filled_overhang_limit_mult", 1.15)),
		"thin_overhang_radius_px": float(silhouette_contract.get("thin_overhang_radius_px", 0.0)),
		"thin_overhang_radius_mult": float(silhouette_contract.get("thin_overhang_radius_mult", 0.0)),
		"capsule_half_len_px": float(silhouette_contract.get("capsule_half_len_px", 0.0)),
		"footprint_length_px": float(silhouette_contract.get("footprint_length_px", body_radius * 2.0)),
		"long_body_visual_length_px": float(silhouette_contract.get("long_body_visual_length_px", visual_radius_px * 2.0)),
		"contact_shadow_ellipse": bool(silhouette_contract.get("contact_shadow_ellipse", false)),
		"open_hurtbox_regions": open_hurtbox_regions,
		"open_region_visuals": not open_hurtbox_regions.is_empty(),
		"counter_flash_t": clampf(
			render_counter_flash_timer / COUNTER_FLASH_SEC,
			0.0,
			1.0
		),
		"counter_flash_color": COUNTER_FLASH_COLOR,
		"low_window_model_scale_bonus": low_window_scale_bonus,
		"air_attack_model_scale_bonus": air_attack_scale_bonus,
		"air_attack_release_t": air_attack_release_t,
		"air_attack_startup_t": air_attack_startup_t,
		"air_attack_cue_t": air_attack_cue_t if air_attack_cue else 0.0,
		"air_attack_cue_radius_px": air_attack_cue_radius_px,
		"height_units": visual_height_units,
		"height_class": String(visual_size_profile.get("height_class", "mid")),
		"height_band": _visual_height_band(visual_height_units),
		"height_shadow_alpha": height_shadow_alpha,
		"height_shadow_radius_mult": height_shadow_radius_mult,
		"low_window_t": low_window_t,
		"low_window_active": low_window_t > 0.0,
		"air_attack_readable": air_attack_cue,
		"air_attack_cue_pose": air_attack_cue,
		"air_attack_cue_intensity": air_attack_cue_t if air_attack_cue else 0.0,
		"in_water": surface == EnvironmentProfileScript.SURFACE_WATER,
		"surface_walk": surface_walk,
		"surface_wake_intensity": wake_intensity,
		"submerged_shrew_pose": shrew_submerged,
		"submerged_shrew_intensity": shrew_submerged_intensity,
		"shrew_land_skitter_pose": shrew_land_skitter,
		"shrew_land_skitter_intensity": shrew_land_skitter_intensity,
		"bullfrog_coil_pose": bullfrog_coil,
		"bullfrog_coil_intensity": bullfrog_coil_intensity,
		"bullfrog_lunge_pose": bullfrog_lunge,
		"bullfrog_lunge_intensity": bullfrog_lunge_intensity,
		"bullfrog_heavy_hop_pose": bullfrog_heavy_hop,
		"bullfrog_heavy_hop_intensity": bullfrog_heavy_hop_intensity,
		"camouflage_eye_cue": bullfrog_camouflage,
		"chorus_hop_pose": chorus_hop,
		"chorus_hop_intensity": chorus_hop_intensity,
		"cane_squat_hop_pose": cane_squat_hop,
		"cane_squat_hop_intensity": cane_squat_hop_intensity,
		"alligator_water_cruise_pose": alligator_water_cruise,
		"alligator_water_cruise_intensity": alligator_water_cruise_intensity,
		"wading_pose": heron_wading,
		"wading_stride": wading_stride,
		"heron_stalk_pose": heron_stalk,
		"heron_stalk_intensity": heron_stalk_intensity,
		"slick_crawl_pose": newt_crawling,
		"slick_crawl_intensity": newt_motion_intensity if newt_crawling else 0.0,
		"newt_swim_pose": newt_swimming,
		"newt_swim_intensity": newt_motion_intensity if newt_swimming else 0.0,
		"tail_lost_pose": newt_tail_lost,
		"water_slither_pose": water_snake_swim,
		"water_slither_intensity": water_slither_intensity if water_snake_swim else 0.0,
		"water_snake_land_slither_pose": water_snake_land_slither,
		"water_snake_land_slither_intensity": water_slither_intensity if water_snake_land_slither else 0.0,
		"water_snake_mud_slither": water_snake_mud_slither,
		"turtle_swim_pose": turtle_swim,
		"turtle_swim_intensity": turtle_motion_intensity if turtle_swim else 0.0,
		"turtle_plod_pose": turtle_plod,
		"turtle_plod_intensity": turtle_motion_intensity if turtle_plod else 0.0,
		"bog_turtle_creep_pose": bog_turtle_creep,
		"bog_turtle_creep_intensity": bog_turtle_motion_intensity if bog_turtle_creep else 0.0,
		"bog_turtle_paddle_pose": bog_turtle_paddle,
		"bog_turtle_paddle_intensity": bog_turtle_motion_intensity if bog_turtle_paddle else 0.0,
		"spider_lunge_pose": wolf_spider_lunge,
		"spider_burrowed_pose": wolf_spider_burrowed,
		"spider_latch_pose": wolf_spider_latched,
		"spider_skitter_pose": wolf_spider_skitter,
		"spider_skitter_intensity": wolf_spider_skitter_intensity,
		"firefly_hover_pose": firefly_hover,
		"firefly_hover_intensity": firefly_hover_intensity,
		"firefly_flash_pose": firefly_flash,
		"mosquito_swarm_pose": mosquito_swarm,
		"mosquito_swarm_intensity": mosquito_swarm_intensity,
		"mosquito_trail_pose": mosquito_trail,
		"mosquito_blood_ratio": mosquito_blood_ratio,
		"duck_paddle_pose": duck_paddle,
		"duck_paddle_intensity": duck_motion_intensity if duck_paddle else 0.0,
		"duck_waddle_pose": duck_waddle,
		"duck_waddle_intensity": duck_motion_intensity if duck_waddle else 0.0,
		"owl_glide_pose": owl_glide,
		"owl_glide_intensity": owl_glide_intensity,
		"owl_silent_flight_pose": owl_silent,
		"kingfisher_dart_pose": kingfisher_dart,
		"kingfisher_dart_intensity": kingfisher_dart_intensity,
		"beaver_swim_pose": beaver_swim,
		"beaver_swim_intensity": beaver_motion_intensity if beaver_swim else 0.0,
		"beaver_lumber_pose": beaver_lumber,
		"beaver_lumber_intensity": beaver_motion_intensity if beaver_lumber else 0.0,
		"mink_bound_pose": mink_bound,
		"mink_bound_intensity": mink_motion_intensity if mink_bound else 0.0,
		"mink_swim_pose": mink_swim,
		"mink_swim_intensity": mink_motion_intensity if mink_swim else 0.0,
		"mink_choke_pose": mink_choke,
		"otter_swim_pose": otter_swim,
		"otter_land_slide_pose": otter_land_slide,
		"otter_motion_intensity": otter_motion_intensity,
		"otter_pack_latch_pose": otter_pack_latch,
		"crayfish_scuttle_pose": crayfish_scuttle,
		"crayfish_tail_flick_swim_pose": crayfish_tail_flick_swim,
		"crayfish_motion_intensity": crayfish_motion_intensity,
		"leech_undulate_pose": leech_undulate,
		"leech_inchworm_pose": leech_inchworm,
		"leech_motion_intensity": leech_motion_intensity,
		"water_walk_active": water_walk_active,
		"rooted_pose": _has_modifier_source("Thanatosis"),
		"display_stance": _has_modifier_source("Meral Display"),
		"escape_dash": creature_id == "crayfish" and backward_dash,
		"ambush_pose": _has_modifier_source("Ambush"),
		"high_walk_pose": alligator_high_walk,
		"off_balance_pose": creature_id == "alligator" \
			and String(timeline_snapshot["attack_variant"]) == "alligator_bite" \
			and String(timeline_snapshot["attack_phase_name"]) == "recovery" \
			and String(timeline_snapshot["attack_outcome_name"]) == "whiff",
		"perched_pose": state == CreatureStateScript.State.PERCHED,
		"landing_t": landing_t,
		"landing_impact": render_landing_impact,
		"takeoff_charge_t": takeoff_charge_t,
		"takeoff_flap_t": takeoff_flap_t,
		"landing_flap_t": landing_flap_t,
		"grounded_lockout_t": grounded_lockout_t,
		"bird_transition_pose": bird_transition_pose,
		"terrain_transition_t": terrain_transition_t,
		"terrain_transition_from_surface": render_terrain_from_surface,
		"terrain_transition_to_surface": render_terrain_to_surface,
		"water_entry_t": water_entry_t,
		"water_exit_t": water_exit_t,
		"mud_entry_t": mud_entry_t,
		"mud_exit_t": mud_exit_t,
		"terrain_splash_t": terrain_splash_t,
		"terrain_scuff_t": terrain_scuff_t,
		"latch_source": latch_source_name,
		"latch_attacker_pose": latch_attacking,
		"latched_victim_pose": latch_being_held,
		"predator_hold_t": predator_hold_t,
		"water_snake_coil_pose": water_snake_coil,
		"alligator_jaw_hold_pose": alligator_jaw_hold,
		"alligator_death_roll_pose": alligator_death_roll,
		"toxic_recoil_t": toxic_recoil_t,
		"escape_curl_t": escape_curl_t,
		"plunge_t": plunge_t,
		"attack_phase": timeline_snapshot["attack_phase"],
		"attack_phase_name": timeline_snapshot["attack_phase_name"],
		"phase_t": timeline_snapshot["phase_t"],
		"attack_sequence_id": timeline_snapshot["attack_sequence_id"],
		"attack_started_tick": timeline_snapshot["attack_started_tick"],
		"attack_active_tick": timeline_snapshot["attack_active_tick"],
		"attack_outcome": timeline_snapshot["attack_outcome"],
		"attack_outcome_name": timeline_snapshot["attack_outcome_name"],
		"attack_variant": render_attack_variant,
		"strike_heading": timeline_snapshot["strike_heading"],
		"hit_count": timeline_snapshot["hit_count"],
		"hit_region": timeline_snapshot["hit_region"],
		"contact_point": timeline_snapshot["contact_point"],
		"projected_shape": timeline_snapshot["projected_shape"],
		"interruption_reason": timeline_snapshot["interruption_reason"]
	}

func _visual_size_profile() -> Dictionary:
	return visual_size_profile_for(creature_id)

static func visual_size_profile_for(next_creature_id: String) -> Dictionary:
	return VISUAL_SIZE_PROFILES.get(next_creature_id, {}).duplicate(true)

func _visual_height_units(profile: Dictionary) -> float:
	var base_height := float(profile.get("height_units", 0.45))
	var elevated_height := base_height
	if state == CreatureStateScript.State.PERCHED:
		elevated_height = maxf(base_height, float(profile.get("perch_height_units", 1.0)))
	elif is_airborne():
		elevated_height = maxf(base_height, float(profile.get("flight_height_units", base_height + 0.45)))
	if low_window_timer > 0.0 and (state == CreatureStateScript.State.PERCHED or is_airborne()):
		return minf(elevated_height, maxf(0.0, float(profile.get("low_window_height_units", base_height))))
	return elevated_height

func _low_window_render_t() -> float:
	if low_window_timer <= 0.0:
		return 0.0
	return clampf(low_window_timer / LOW_WINDOW_VISUAL_MAX_SEC, 0.0, 1.0)

func _takeoff_charge_render_t() -> float:
	if state == CreatureStateScript.State.PERCHED or is_airborne() or flight_time_max <= 0.0 or not has_movement("flight"):
		return 0.0
	if flight_grounded_timer > 0.0 or input_frame == null:
		return 0.0
	if flight_toggle_requires_release or not input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) or input_frame.move.length() <= 0.0:
		return 0.0
	return clampf(takeoff_distance_px / maxf(TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX, 1.0), 0.0, 1.0)

func _visual_height_band(height_units: float) -> String:
	return visual_height_band_for(height_units)

static func visual_height_band_for(height_units: float) -> String:
	if height_units >= 1.25:
		return "high"
	if height_units >= 0.55:
		return "raised"
	if height_units >= 0.25:
		return "body"
	return "low"

func _height_shadow_alpha(height_units: float, low_window_t: float, airborne_visual: bool) -> float:
	if not airborne_visual:
		return 0.0
	var height_t := clampf(height_units / 1.8, 0.0, 1.0)
	return clampf(0.34 - height_t * 0.12 + low_window_t * 0.24, 0.12, 0.5)

func _height_shadow_radius_mult(height_units: float, low_window_t: float, airborne_visual: bool) -> float:
	if not airborne_visual:
		return 1.0
	var height_t := clampf(height_units / 1.8, 0.0, 1.0)
	return clampf(0.82 + height_t * 0.14 + low_window_t * 0.26, 0.75, 1.3)

func get_swim_ratio() -> float:
	if swim_time_max <= 0.0:
		return 1.0
	return clampf(swim_time_remaining / swim_time_max, 0.0, 1.0)

func get_flight_ratio() -> float:
	if flight_time_max <= 0.0:
		return 1.0
	return clampf(flight_time_remaining / flight_time_max, 0.0, 1.0)

func _move_from_input(delta: float) -> void:
	var start_position := global_position
	last_move_displacement_px = 0.0
	if state == CreatureStateScript.State.BURROWED:
		velocity = Vector2.ZERO
		steering_velocity = Vector2.ZERO
		return
	if state == CreatureStateScript.State.PERCHED:
		velocity = Vector2.ZERO
		steering_velocity = Vector2.ZERO
		if input_frame != null and input_frame.aim != Vector2.ZERO:
			last_aim_direction = (input_frame.aim - global_position).normalized()
		return
	var move := Vector2.ZERO
	if input_frame != null:
		move = input_frame.move.normalized()
		if input_frame.aim != Vector2.ZERO:
			last_aim_direction = (input_frame.aim - global_position).normalized()
	if _modifier_value("forward_back_only", 1.0) > 1.5 and move != Vector2.ZERO:
		var axis := last_aim_direction.normalized()
		move = axis * move.dot(axis)
	var speed_multiplier: float = (
		latch_move_multiplier
		* _modifier_value("move_speed_mult", 1.0)
		* primary_attack_timeline.movement_multiplier()
	)
	if dash_timer > 0.0:
		velocity = dash_velocity
		steering_velocity = Vector2.ZERO
	else:
		if residual_velocity == Vector2.ZERO:
			steering_velocity = velocity
		steering_velocity = MovementFeelScript.profiled_velocity(steering_velocity, move, get_speed_px() * speed_multiplier, delta, _active_movement_profile(), last_aim_direction)
		velocity = steering_velocity + residual_velocity
	if Engine.is_in_physics_frame():
		move_and_slide()
	else:
		global_position += velocity * delta
	if arena != null:
		if is_airborne():
			# Airborne creatures pass over obstacles; only the arena bounds apply.
			global_position = arena.clamp_to_arena(global_position)
		elif pass_obstacles_timer <= 0.0 and arena.has_method("resolve_body_position"):
			global_position = arena.resolve_body_position(global_position, body_radius)
	last_move_displacement_px = global_position.distance_to(start_position)

func _update_terrain(delta: float) -> void:
	var zone := get_current_zone()
	var old_zone := current_terrain_zone
	var old_surface := String(current_environment_profile.get("surface", ""))
	previous_terrain_zone = current_terrain_zone
	current_terrain_zone = zone
	current_environment_profile = _environment_profile_for_zone(zone)
	var new_surface := String(current_environment_profile.get("surface", ""))
	if zone != old_zone and not is_airborne():
		begin_render_terrain_transition(old_surface, new_surface)
	terrain_speed_target_px = _terrain_target_speed_px(zone)
	var terrain_lerp_rate := float(movement_profile.get("terrain_lerp_rate", TERRAIN_SPEED_LERP_RATE))
	terrain_speed_px = lerpf(terrain_speed_px if terrain_speed_px > 0.0 else terrain_speed_target_px, terrain_speed_target_px, clampf(delta * terrain_lerp_rate, 0.0, 1.0))

	if not is_airborne() and current_environment_profile.get("drains_swim", false) == true:
		if _has_limited_swim_time():
			swim_time_remaining = maxf(swim_time_remaining - delta, 0.0)

	if not is_airborne() and _is_wrong_terrain():
		wrong_terrain_seconds += delta
		var rate := WRONG_TERRAIN_LATE_DPS if wrong_terrain_seconds > WRONG_TERRAIN_GRACE_SEC else WRONG_TERRAIN_EARLY_DPS
		take_area_damage(max_health * rate * delta)
	elif current_environment_profile.get("restores_swim", true) == true:
		wrong_terrain_seconds = 0.0
		if swim_time_max > 0.0:
			swim_time_remaining = minf(swim_time_remaining + delta, swim_time_max)
	else:
		wrong_terrain_seconds = 0.0

func _update_flight(delta: float) -> void:
	if has_movement("always_flying"):
		state = CreatureStateScript.State.AIRBORNE
		return

	if state == CreatureStateScript.State.PERCHED:
		return

	if is_airborne():
		if _should_voluntary_land():
			state = CreatureStateScript.State.NORMAL
			takeoff_distance_px = 0.0
			flight_toggle_requires_release = true
			begin_render_landing_flap(LANDING_FLAP_TELL_SEC, 0.85)
			break_stealth()
			return
		flight_time_remaining = maxf(flight_time_remaining - delta, 0.0)
		takeoff_distance_px = 0.0
		if flight_time_max > 0.0 and flight_time_remaining <= 0.0:
			state = CreatureStateScript.State.NORMAL
			flight_grounded_timer = FLIGHT_GROUNDED_LOCKOUT_SEC
			flight_toggle_requires_release = true
			begin_render_landing_flap(LANDING_FLAP_TELL_SEC, 1.0)
			break_stealth()
		return

	if flight_time_max <= 0.0 or not has_movement("flight"):
		return

	flight_time_remaining = minf(flight_time_remaining + delta, flight_time_max)
	if flight_grounded_timer > 0.0 or input_frame == null:
		takeoff_distance_px = 0.0
		return

	if flight_toggle_requires_release or not input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) or input_frame.move.length() <= 0.0:
		takeoff_distance_px = 0.0

func _update_flight_toggle_edge() -> void:
	var pressed: bool = input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE)
	flight_toggle_just_pressed = pressed and not flight_toggle_was_pressed
	if not pressed:
		flight_toggle_requires_release = false

func _commit_flight_toggle_edge() -> void:
	flight_toggle_was_pressed = input_frame != null and input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE)
	if not flight_toggle_was_pressed:
		flight_toggle_just_pressed = false

func _should_voluntary_land() -> bool:
	return has_movement("flight") and flight_toggle_just_pressed and not flight_toggle_requires_release

func _update_takeoff_charge_from_displacement(displacement_px: float) -> void:
	if state == CreatureStateScript.State.PERCHED or is_airborne() or flight_time_max <= 0.0 or not has_movement("flight"):
		takeoff_distance_px = 0.0
		return
	if flight_grounded_timer > 0.0 or input_frame == null:
		takeoff_distance_px = 0.0
		return
	if flight_toggle_requires_release or not input_frame.is_pressed(InputFrameScript.BUTTON_FLIGHT_TOGGLE) or input_frame.move.length() <= 0.0:
		takeoff_distance_px = 0.0
		return
	takeoff_distance_px += maxf(displacement_px, 0.0)
	if takeoff_distance_px >= TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX:
		state = CreatureStateScript.State.AIRBORNE
		takeoff_distance_px = 0.0
		flight_toggle_requires_release = true
		begin_render_takeoff_flap()

func get_aim_direction() -> Vector2:
	if input_frame != null and input_frame.aim != Vector2.ZERO:
		var direction: Vector2 = input_frame.aim - global_position
		if direction != Vector2.ZERO:
			last_aim_direction = direction.normalized()
	return last_aim_direction

func get_body_axis() -> Vector2:
	if (body_capsule_half_len_px > 0.0 or _profile_body_turn_rate_deg() > 0.0) and body_heading != Vector2.ZERO:
		return body_heading.normalized()
	if velocity.length() > 20.0:
		return velocity.normalized()
	return last_aim_direction.normalized() if last_aim_direction != Vector2.ZERO else Vector2.RIGHT

func make_damage_event(amount: float, delivery: int, plane: int, source_ability: String) -> Resource:
	var event := DamageEventScript.new()
	event.setup(modify_outgoing_damage(amount), delivery, plane, self, source_ability)
	return event

func modify_outgoing_damage(amount: float) -> float:
	var result := amount * _modifier_value("damage_dealt_mult", 1.0) * _team_buff_multiplier("damage") * (1.0 + _team_kill_growth_bonus())
	# Teratornis center reward (Sky Ambush): after AMBUSH_UNDAMAGED_SEC without taking damage,
	# the next damage instance is empowered, then the window resets.
	if undamaged_timer >= AMBUSH_UNDAMAGED_SEC:
		var burst := _team_combat_reward("teratornis")
		if burst > 0.0:
			result *= 1.0 + burst
			undamaged_timer = 0.0
	return result

func on_damage_dealt(target: Node, event: Resource, amount: float) -> void:
	if target == null or not is_instance_valid(target) or amount <= 0.0:
		return
	if not target.has_method("apply_dot"):
		return
	if String(event.source_ability) == TIDAL_VENOM_SOURCE:
		return
	var venom := _team_combat_reward("champsosaurus")
	if venom <= 0.0:
		return
	target.apply_dot(self, TIDAL_VENOM_SOURCE, amount * venom, TIDAL_VENOM_DURATION_SEC, 1)

func _team_combat_reward(family: String) -> float:
	if arena != null and arena.has_method("get_team_combat_reward_value"):
		return float(arena.get_team_combat_reward_value(team, family))
	return 0.0

func _team_kill_growth_bonus() -> float:
	if arena != null and arena.has_method("get_team_kill_growth_bonus"):
		return float(arena.get_team_kill_growth_bonus(team))
	return 0.0

func get_ability_delta(delta: float) -> float:
	return delta * _team_buff_multiplier("ability_haste")

func add_modifier(source: String, values: Dictionary, duration: float) -> void:
	if _modifier_value("cc_immune", 1.0) > 1.5 and _is_disruption_modifier(values):
		return
	var could_act := can_act()
	modifiers.append({"source": source, "values": values, "remaining": duration})
	if could_act and not can_act():
		interrupt_primary_attack(source, false)

func add_capped_modifier(source: String, values: Dictionary, duration: float, max_stacks: int) -> void:
	if max_stacks > 0:
		var matching := 0
		var oldest_index := -1
		for i in modifiers.size():
			if String(modifiers[i].get("source", "")) == source:
				matching += 1
				if oldest_index < 0:
					oldest_index = i
		if matching >= max_stacks and oldest_index >= 0:
			modifiers.remove_at(oldest_index)
	add_modifier(source, values, duration)

func remove_modifiers_from_source(source: String) -> void:
	for i in range(modifiers.size() - 1, -1, -1):
		if String(modifiers[i].get("source", "")) == source:
			modifiers.remove_at(i)

func _has_modifier_source(source: String) -> bool:
	for modifier in modifiers:
		if String(modifier.get("source", "")) == source:
			return true
	return false

func cleanse_negative_modifiers() -> void:
	for i in range(modifiers.size() - 1, -1, -1):
		var values: Dictionary = modifiers[i].get("values", {})
		if _is_negative_modifier(values):
			modifiers.remove_at(i)

func get_modifier_value(key: String, fallback: float) -> float:
	return _modifier_value(key, fallback)

func filter_action_start_frame(frame: Resource) -> Resource:
	if frame == null:
		return null
	var mask := 0
	if primary_attack_timeline.current_phase_name() == &"recovery" \
		or _has_authoritative_kit_action_commitment():
		mask = ACTION_START_BUTTONS
	elif not can_use_abilities() or primary_attack_timeline.blocks_abilities():
		mask = ABILITY_START_BUTTONS
	if mask == 0:
		return frame
	return _without_action_buttons(frame, mask)

func _has_authoritative_kit_action_commitment() -> bool:
	if kit == null or not kit.has_method("get_action_phase_records"):
		return false
	return not kit.get_action_phase_records().is_empty()

func was_action_start_suppressed_by_policy(button: int) -> bool:
	return (action_policy_suppressed_buttons & button) != 0

func _without_action_buttons(frame: Resource, mask: int) -> Resource:
	var filtered := InputFrameScript.new()
	filtered.move = frame.move
	filtered.aim = frame.aim
	filtered.buttons = int(frame.buttons)
	filtered.suppressed_buttons = int(frame.suppressed_buttons)
	var held_starts := int(frame.buttons) & mask
	action_policy_suppressed_buttons |= held_starts
	filtered.buttons &= ~mask
	filtered.suppressed_buttons |= held_starts
	return filtered

func _has_authoritative_action_phase_source() -> bool:
	return is_primary_attack_committed() \
		or (kit != null and kit.has_method("get_action_phase_records"))

func _is_counter_vulnerable() -> bool:
	if _has_authoritative_action_phase_source():
		for record: Dictionary in get_authoritative_action_phase_records():
			if bool(record.get("counter_vulnerable", false)):
				return true
		return false
	return counter_hit_window_timer > 0.0

func _is_valid_enemy_counter_source(event: Resource) -> bool:
	if event == null:
		return false
	var source: Variant = event.source_actor
	if source == null \
		or not is_instance_valid(source) \
		or source == self \
		or not source.has_method("is_alive") \
		or not source.is_alive():
		return false
	var source_team: Variant = source.get("team")
	return typeof(source_team) == TYPE_INT and int(source_team) != team

func _advance_primary_attack_timeline(delta: float) -> void:
	if primary_attack_timeline.is_idle():
		return
	var simulation_tick := _primary_attack_simulation_tick()
	var snapshot: Dictionary = primary_attack_timeline.snapshot()
	if simulation_tick < 0 or simulation_tick <= int(snapshot["attack_started_tick"]):
		return
	primary_attack_timeline.advance(delta, simulation_tick, _primary_attack_resolver)
	if primary_attack_timeline.is_idle():
		_reset_primary_attack_timeline()
	_request_render_redraw()

func _reset_primary_attack_timeline() -> void:
	primary_attack_timeline.reset()
	_primary_attack_resolver = Callable()
	_primary_attack_variant = ""
	_clear_primary_attack_presentation()

func _refresh_primary_attack_presentation() -> void:
	if kit != null and kit.has_method("refresh_primary_attack_presentation"):
		kit.refresh_primary_attack_presentation(self)

func _begin_primary_attack_presentation(attack_sequence_id: int) -> void:
	_primary_attack_presentation = {
		"attack_sequence_id": attack_sequence_id,
		"revision": int(_primary_attack_presentation.get("revision", 0)) + 1,
		"projected_shape": null,
		"contact_point": null,
	}

func _clear_primary_attack_presentation() -> void:
	_primary_attack_presentation = {
		"attack_sequence_id": 0,
		"revision": int(_primary_attack_presentation.get("revision", 0)) + 1,
		"projected_shape": null,
		"contact_point": null,
	}

static func _copy_primary_attack_presentation_variant(value: Variant) -> Variant:
	var result := _copy_primary_attack_presentation_value(value)
	return result["value"] if bool(result["valid"]) else null

static func _copy_primary_attack_presentation_value(
	value: Variant,
	ancestors: Array = []
) -> Dictionary:
	var value_type := typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return {"valid": true, "value": value}
		TYPE_FLOAT:
			return {"valid": is_finite(float(value)), "value": value}
		TYPE_VECTOR2:
			return {
				"valid": (value as Vector2).is_finite(),
				"value": value,
			}
		TYPE_VECTOR2I, TYPE_RECT2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
			return {"valid": true, "value": value}
		TYPE_RECT2:
			var rect: Rect2 = value
			return {
				"valid": rect.position.is_finite() and rect.size.is_finite(),
				"value": value,
			}
		TYPE_VECTOR3:
			return {"valid": (value as Vector3).is_finite(), "value": value}
		TYPE_VECTOR4:
			return {"valid": (value as Vector4).is_finite(), "value": value}
		TYPE_COLOR:
			var color: Color = value
			return {
				"valid": is_finite(color.r)
					and is_finite(color.g)
					and is_finite(color.b)
					and is_finite(color.a),
				"value": value,
			}
		TYPE_TRANSFORM2D:
			return {
				"valid": (value as Transform2D).is_finite(),
				"value": value,
			}
		TYPE_TRANSFORM3D:
			return {
				"valid": (value as Transform3D).is_finite(),
				"value": value,
			}
		TYPE_ARRAY, TYPE_DICTIONARY:
			for ancestor: Variant in ancestors:
				if is_same(ancestor, value):
					return {"valid": false, "value": null}
			var nested_ancestors := ancestors.duplicate()
			nested_ancestors.append(value)
			if value_type == TYPE_ARRAY:
				var copied_array: Array = []
				for item: Variant in value:
					var item_copy := _copy_primary_attack_presentation_value(
						item,
						nested_ancestors
					)
					if not bool(item_copy["valid"]):
						return {"valid": false, "value": null}
					copied_array.append(item_copy["value"])
				return {"valid": true, "value": copied_array}
			var copied_dictionary := {}
			for key: Variant in value:
				var key_copy := _copy_primary_attack_presentation_value(
					key,
					nested_ancestors
				)
				var item_copy := _copy_primary_attack_presentation_value(
					value[key],
					nested_ancestors
				)
				if not bool(key_copy["valid"]) or not bool(item_copy["valid"]):
					return {"valid": false, "value": null}
				copied_dictionary[key_copy["value"]] = item_copy["value"]
			return {"valid": true, "value": copied_dictionary}
		_:
			return {"valid": false, "value": null}

func _primary_attack_simulation_tick() -> int:
	if arena == null or not is_instance_valid(arena):
		return -1
	var tick_value: Variant = arena.get("simulation_tick")
	if typeof(tick_value) != TYPE_INT:
		return -1
	return int(tick_value)

func _primary_attack_cooldown_sec(config: Dictionary) -> float:
	var configured: Variant = config.get("cooldown_sec", null)
	if _is_positive_finite_number(configured):
		return float(configured)
	var interval: Variant = stats.get("attack_interval_sec", null)
	if _is_positive_finite_number(interval):
		return float(interval)
	var rate: Variant = stats.get("attack_rate_per_sec", null)
	if _is_positive_finite_number(rate):
		return 1.0 / float(rate)
	return 1.0

static func _is_positive_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return number > 0.0 and is_finite(number)

func break_latch(_reason: String) -> void:
	if latched_attacker != null and is_instance_valid(latched_attacker) and latched_attacker.has_method("release_latch"):
		latched_attacker.release_latch("victim_displacement")
	if latch_victim != null:
		release_latch("self_displacement")

func attach_to_victim(victim: Node, duration: float, source_ability: String, execute_after := 0.0) -> void:
	# One latch at a time: starting a new one cleanly releases the old, and
	# stealing a victim releases their previous attacker.
	if latch_victim != null:
		release_latch("relatch")
	if victim.latched_attacker != null and is_instance_valid(victim.latched_attacker) and victim.latched_attacker != self:
		victim.latched_attacker.release_latch("victim_stolen")
	latch_sequence_id += 1
	latch_victim = victim
	latch_timer = duration
	latch_source = source_ability
	latch_execute_timer = execute_after
	state = CreatureStateScript.State.LATCHED
	emit_vfx_event("latch_started", {
		"attacker": self,
		"victim": victim,
		"duration": duration,
		"execute_after": execute_after,
		"source_ability": source_ability
	})

func receive_latch(attacker: Node, duration: float, source_ability: String) -> void:
	latched_attacker = attacker
	latch_timer = duration
	latch_source = source_ability
	# Decision #33: the latched pair moves at 45% of the victim's base speed.
	latch_move_multiplier = 0.45

func release_latch(_reason: String) -> void:
	var released_latch := latch_victim != null or latched_attacker != null
	if latch_victim != null:
		emit_vfx_event("latch_ended", {
			"attacker": self,
			"victim": latch_victim,
			"reason": _reason,
			"source_ability": latch_source
		})
	elif latched_attacker != null:
		emit_vfx_event("latch_ended", {
			"attacker": latched_attacker,
			"victim": self,
			"reason": _reason,
			"source_ability": latch_source
		})
	if latch_victim != null and is_instance_valid(latch_victim) and latch_victim.latched_attacker == self:
		latch_victim.latched_attacker = null
		latch_victim.latch_move_multiplier = 1.0
	latch_victim = null
	latched_attacker = null
	latch_timer = 0.0
	latch_source = ""
	latch_execute_timer = 0.0
	latch_move_multiplier = 1.0
	if not is_airborne():
		state = CreatureStateScript.State.NORMAL
	if released_latch and kit != null and kit.has_method("on_latch_released"):
		kit.on_latch_released(self, _reason)

func has_latch() -> bool:
	return latch_victim != null or latched_attacker != null

func on_kill(_victim: Node) -> void:
	if arena != null and arena.has_method("record_center_reward_kill"):
		arena.record_center_reward_kill(self, _victim)
	var diet := String(creature_data.get("diet", ""))
	if diet == "carnivore" or diet == "omnivore":
		healing_ticks.append({"remaining": 2.0, "amount_remaining": max_health * 0.05})
	if kit != null and kit.has_method("on_kill"):
		kit.on_kill(self, _victim)

func damage_enemy_cores_near(center: Vector2, radius: float, damage: float, source_ability: String) -> Array[Node]:
	var damaged_cores: Array[Node] = []
	if arena == null or not is_instance_valid(arena) or not arena.has_method("record_core_damage"):
		return damaged_cores
	var final_damage := modify_outgoing_damage(damage)
	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core.team == team:
			continue
		if arena.has_method("can_damage_core") and not arena.can_damage_core(core.team):
			continue
		if core.global_position.distance_to(center) <= radius + core.radius:
			core.take_damage(final_damage, team, self)
			arena.record_core_damage(team, final_damage, self)
			damaged_cores.append(core)
	return damaged_cores

func damage_enemy_cores_line(range_px: float, damage: float, source_ability: String) -> void:
	if arena == null:
		return
	var final_damage := modify_outgoing_damage(damage)
	var aim := get_aim_direction()
	for core_team in arena.cores.keys():
		var core = arena.cores[core_team]
		if core.team == team:
			continue
		if arena.has_method("can_damage_core") and not arena.can_damage_core(core.team):
			continue
		var offset: Vector2 = core.global_position - global_position
		var along := offset.dot(aim)
		if along >= 0.0 and along <= range_px and absf(offset.cross(aim)) <= core.radius:
			core.take_damage(final_damage, team, self)
			arena.record_core_damage(team, final_damage, self)

func _respawn() -> void:
	_reset_primary_attack_timeline()
	alive = true
	visible = true
	health = max_health
	modifiers.clear()
	healing_ticks.clear()
	damage_ticks.clear()
	spore_ward_timer = 0.0
	spore_ward_absorb = 0.0
	if kit != null and kit.has_method("reset_for_respawn"):
		kit.reset_for_respawn(self)
	swim_time_remaining = swim_time_max
	flight_time_remaining = flight_time_max
	flight_grounded_timer = 0.0
	flight_toggle_was_pressed = false
	flight_toggle_just_pressed = false
	flight_toggle_requires_release = false
	takeoff_distance_px = 0.0
	wrong_terrain_seconds = 0.0
	_reset_terrain_profile()
	steering_velocity = Vector2.ZERO
	dash_velocity = Vector2.ZERO
	dash_timer = 0.0
	residual_velocity = Vector2.ZERO
	render_landing_timer = 0.0
	render_landing_impact = 0.0
	render_last_hop_airborne = false
	render_takeoff_flap_timer = 0.0
	render_landing_flap_timer = 0.0
	render_terrain_transition_timer = 0.0
	render_terrain_from_surface = ""
	render_terrain_to_surface = ""
	render_toxic_recoil_timer = 0.0
	render_escape_curl_timer = 0.0
	render_plunge_timer = 0.0
	render_air_attack_startup_timer = 0.0
	render_air_attack_startup_duration = AIR_ATTACK_STARTUP_TELL_SEC
	pass_obstacles_timer = 0.0
	primary_timer = 0.4
	q_timer = maxf(q_timer, 1.0)
	e_timer = maxf(e_timer, 1.0)
	state = CreatureStateScript.State.AIRBORNE if has_movement("always_flying") else CreatureStateScript.State.NORMAL
	if arena != null:
		if arena.has_method("get_actor_respawn_position"):
			global_position = arena.get_actor_respawn_position(self)
		elif arena.has_method("get_team_spawn"):
			global_position = arena.get_team_spawn(team)
		if arena.has_method("register_entity"):
			arena.register_entity(self)
		if arena.has_method("on_actor_respawned"):
			arena.on_actor_respawned(self)
		if arena.has_method("add_circle_telegraph"):
			arena.add_circle_telegraph(global_position, body_radius + 26.0, Color(0.45, 0.72, 1.0, 0.75) if team == 0 else Color(1.0, 0.4, 0.35, 0.75), 0.6, 4.0, true)
	hunger = HUNGER_MAX
	hunger_satiated = false
	_last_render_signature = ""
	_request_render_redraw(true)

func _tick_timers(delta: float) -> void:
	var ability_delta := get_ability_delta(delta)
	primary_timer = maxf(primary_timer - delta, 0.0)
	q_timer = maxf(q_timer - ability_delta, 0.0)
	e_timer = maxf(e_timer - ability_delta, 0.0)
	_tick_breeding_regen(delta)
	_tick_iron_hide_regen(delta)
	_tick_spore_ward(delta)
	var previous_dash_timer := dash_timer
	var previous_dash_velocity := dash_velocity
	dash_timer = maxf(dash_timer - delta, 0.0)
	pass_obstacles_timer = maxf(pass_obstacles_timer - delta, 0.0)
	if residual_velocity.length() > 0.0:
		residual_velocity *= pow(RESIDUAL_DASH_DECAY_PER_TICK, delta * 60.0)
		if residual_velocity.length() < RESIDUAL_DASH_STOP_SPEED:
			residual_velocity = Vector2.ZERO
	if previous_dash_timer > 0.0 and dash_timer <= 0.0 and previous_dash_velocity.length() > RESIDUAL_DASH_STOP_SPEED:
		residual_velocity = previous_dash_velocity
	if dash_timer <= 0.0:
		dash_velocity = Vector2.ZERO
	for i in range(modifiers.size() - 1, -1, -1):
		modifiers[i]["remaining"] = float(modifiers[i]["remaining"]) - delta
		if float(modifiers[i]["remaining"]) <= 0.0:
			modifiers.remove_at(i)
	for i in range(healing_ticks.size() - 1, -1, -1):
		var tick: Dictionary = healing_ticks[i]
		var heal_amount: float = minf(float(tick["amount_remaining"]), max_health * 0.05 * delta / 2.0)
		heal(heal_amount)
		tick["amount_remaining"] = float(tick["amount_remaining"]) - heal_amount
		tick["remaining"] = float(tick["remaining"]) - delta
		healing_ticks[i] = tick
		if float(tick["remaining"]) <= 0.0 or float(tick["amount_remaining"]) <= 0.0:
			healing_ticks.remove_at(i)
	for i in range(damage_ticks.size() - 1, -1, -1):
		if not alive:
			break
		var tick: Dictionary = damage_ticks[i]
		var tick_amount: float = minf(float(tick["amount_remaining"]), float(tick["per_second"]) * delta)
		if tick_amount > 0.0:
			var source_actor: Node = tick.get("source_actor", null)
			if source_actor != null and not is_instance_valid(source_actor):
				source_actor = null
			var event := DamageEventScript.new()
			event.setup(tick_amount, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, source_actor, String(tick.get("source_ability", "")))
			take_damage_event(event)
		tick["amount_remaining"] = float(tick["amount_remaining"]) - tick_amount
		tick["remaining"] = float(tick["remaining"]) - delta
		damage_ticks[i] = tick
		if float(tick["remaining"]) <= 0.0 or float(tick["amount_remaining"]) <= 0.0:
			damage_ticks.remove_at(i)

func _tick_breeding_regen(delta: float) -> void:
	var regen_bonus := _team_buff_bonus("regen")
	if regen_bonus <= 0.0 or health <= 0.0 or health >= max_health:
		return
	heal(max_health * regen_bonus * delta)

func _tick_iron_hide_regen(delta: float) -> void:
	var reward := _team_combat_reward("american_mastodon")
	if reward <= 0.0 or health <= 0.0 or health >= max_health:
		return
	if undamaged_timer < IRON_HIDE_OUT_OF_COMBAT_SEC:
		return
	heal(max_health * IRON_HIDE_BASE_REGEN_FRACTION_PER_SEC * reward * delta)

func _tick_spore_ward(delta: float) -> void:
	var reward := _team_combat_reward("platyhystrix")
	if reward <= 0.0:
		spore_ward_timer = 0.0
		spore_ward_absorb = 0.0
		return
	spore_ward_timer = maxf(spore_ward_timer - delta, 0.0)
	if spore_ward_timer > 0.0 or spore_ward_absorb > 0.0:
		return
	spore_ward_absorb = maxf(max_health * reward, 0.0)
	spore_ward_timer = SPORE_WARD_PERIOD_SEC
	emit_vfx_event("shield_refreshed", {
		"target": self,
		"source_ability": SPORE_WARD_SOURCE,
		"amount": spore_ward_absorb,
		"position": global_position
	})

func _apply_spore_ward_absorb(event: Resource, amount: float) -> float:
	if amount <= 0.0 or spore_ward_absorb <= 0.0:
		return amount
	var absorbed := minf(amount, spore_ward_absorb)
	spore_ward_absorb = maxf(spore_ward_absorb - absorbed, 0.0)
	emit_vfx_event("shield_absorbed", {
		"target": self,
		"source": event.source_actor,
		"source_ability": SPORE_WARD_SOURCE,
		"amount": absorbed,
		"remaining": spore_ward_absorb,
		"position": global_position
	})
	if spore_ward_absorb <= 0.0:
		_break_spore_ward(event.source_actor)
	return amount - absorbed

func _break_spore_ward(source_actor: Node) -> void:
	emit_vfx_event("shield_broken", {
		"target": self,
		"source": source_actor,
		"source_ability": SPORE_WARD_SOURCE,
		"position": global_position
	})
	if source_actor == null or not is_instance_valid(source_actor) or source_actor == self:
		return
	if not source_actor.has_method("add_capped_modifier"):
		return
	source_actor.add_capped_modifier(SPORE_WARD_SOURCE, {"move_speed_mult": SPORE_WARD_SLOW_MULT}, SPORE_WARD_SLOW_DURATION_SEC, 1)

func _tick_hunger(delta: float) -> void:
	if hunger_satiated:
		return
	var full_to_empty_sec := _hunger_full_to_empty_sec()
	# Arthropleura habitat-stock buff: hunger_depletion is negative -> drains slower.
	var depletion_scale := maxf(1.0 + _team_boss_stock_bonus("hunger_depletion"), 0.0)
	hunger = maxf(hunger - (HUNGER_MAX / full_to_empty_sec) * depletion_scale * delta, 0.0)
	if hunger <= 0.0 and alive:
		take_area_damage(max_health * 10.0, "Starvation")

func _hunger_full_to_empty_sec() -> float:
	if arena != null and arena.has_method("get_hunger_full_to_empty_sec"):
		return maxf(float(arena.get_hunger_full_to_empty_sec()), 1.0)
	return HUNGER_FULL_TO_EMPTY_SEC

func _try_auto_eat() -> void:
	if arena != null and arena.has_method("try_eat_nearby_food"):
		arena.try_eat_nearby_food(self)

func _tick_latch(delta: float) -> void:
	if latch_victim != null and is_instance_valid(latch_victim):
		var offset: Vector2 = global_position - latch_victim.global_position
		if offset == Vector2.ZERO:
			offset = Vector2.LEFT
		var drag_direction: Vector2 = offset.normalized()
		# Grip meter (decision #33): the victim struggling — moving against
		# the drag — drains the latch 1.5x. Attacker owns the grip; the
		# victim's timer mirrors it so both sides read the same value.
		var grip_drain := delta
		var victim_velocity: Vector2 = latch_victim.velocity
		if victim_velocity.length() > 8.0 and victim_velocity.normalized().dot(drag_direction) < -0.3:
			grip_drain = delta * 1.5
		if latch_source != "Death Roll":
			latch_timer = maxf(latch_timer - grip_drain, 0.0)
		latch_victim.latch_timer = latch_timer
		latch_execute_timer = maxf(latch_execute_timer - delta, 0.0)
		if max_health > latch_victim.max_health:
			latch_victim.global_position += drag_direction * get_speed_px() * 0.18 * delta
		global_position = latch_victim.global_position + drag_direction * (body_radius + latch_victim.body_radius * 0.5)
		if latch_execute_timer == 0.0 and latch_source == "Choke":
			latch_victim.take_damage_event(make_damage_event(latch_victim.health, DamageEventScript.DELIVERY_MELEE, DamageEventScript.PLANE_GROUND, latch_source))
			release_latch("execute")
		elif latch_timer <= 0.0:
			release_latch("timeout")
	elif latched_attacker != null and is_instance_valid(latched_attacker):
		if latched_attacker.latch_victim == self:
			# Attacker mirrors the grip onto us each tick; no double drain.
			if latch_timer <= 0.0:
				latched_attacker.release_latch("timeout")
		else:
			# Stale link: our attacker moved on to someone else.
			latch_timer = maxf(latch_timer - delta, 0.0)
			if latch_timer <= 0.0:
				latched_attacker = null
				latch_move_multiplier = 1.0

func _modified_incoming_damage(event: Resource) -> float:
	if _modifier_value("invulnerable", 1.0) > 1.5:
		return 0.0
	var amount: float = event.amount
	amount *= float(event.region_mult)
	amount *= _modifier_value("damage_taken_mult", 1.0)
	# American Mastodon habitat-stock buff: flat damage reduction from all sources.
	amount *= maxf(1.0 - _team_boss_stock_bonus("damage_reduction"), 0.0)
	# Decision #33: while latched on, third parties deal 75% — the victim's
	# own fight-back stays the premier answer to a latch.
	if latch_victim != null and is_instance_valid(latch_victim) and event.source_actor != null and event.source_actor != latch_victim:
		amount *= 0.75
	if creature_id == "snapping_turtle":
		amount *= 1.0 - _passive_percent("Protective Shell", 0.0)
	var source_actor = event.source_actor
	if source_actor != null and is_instance_valid(source_actor):
		var source_max_health_value: Variant = source_actor.get("max_health")
		var source_creature_id_value: Variant = source_actor.get("creature_id")
		var source_max_health := float(source_max_health_value) if source_max_health_value != null else 0.0
		var source_creature_id := String(source_creature_id_value) if source_creature_id_value != null else ""
		if creature_id == "mink" and source_max_health > max_health:
			amount *= 1.0 - _passive_percent("Fearless", 0.0)
		if source_creature_id == "mink" and max_health > source_max_health and source_actor.has_method("get_passive_percent"):
			amount *= 1.0 + source_actor.get_passive_percent("Fearless", 1, 0.0)
	if kit != null and kit.has_method("modify_incoming_damage"):
		amount = kit.modify_incoming_damage(self, event, amount)
	return amount

func _modifier_value(key: String, fallback: float) -> float:
	var output := fallback
	for modifier in modifiers:
		var values: Dictionary = modifier.get("values", {})
		if values.has(key):
			output *= float(values[key])
	return output

func _is_disruption_modifier(values: Dictionary) -> bool:
	if values.has("can_act_mult") and float(values["can_act_mult"]) <= 0.5:
		return true
	if values.has("ability_use_mult") and float(values["ability_use_mult"]) <= 0.5:
		return true
	return values.has("move_speed_mult") and float(values["move_speed_mult"]) <= 0.0

func _is_negative_modifier(values: Dictionary) -> bool:
	for key in values.keys():
		var value := float(values[key])
		match String(key):
			"can_act_mult", "ability_use_mult", "move_speed_mult", "attack_speed_mult", "damage_dealt_mult", "healing_received_mult":
				if value < 1.0:
					return true
			"damage_taken_mult":
				if value > 1.0:
					return true
	return false

func _passive_percent(passive_name: String, fallback: float) -> float:
	return get_passive_percent(passive_name, 0, fallback)

func get_passive_percent(passive_name: String, index: int = 0, fallback: float = 0.0) -> float:
	for passive: Dictionary in creature_data.get("passives", []):
		if String(passive.get("name", "")) == passive_name:
			return _nth_percent(String(passive.get("summary", "")), index, fallback)
	return fallback

static var _percent_regex: RegEx = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")

func _first_percent(text: String, fallback: float) -> float:
	return _nth_percent(text, 0, fallback)

func _nth_percent(text: String, index: int, fallback: float) -> float:
	if _percent_regex == null:
		_percent_regex = RegEx.create_from_string("(\\d+(?:\\.\\d+)?)%")
	if _percent_regex == null:
		return fallback
	var results := _percent_regex.search_all(text)
	if index < 0 or index >= results.size():
		return fallback
	return float(results[index].get_string(1)) / 100.0

func _make_kit() -> RefCounted:
	match creature_id:
		"snapping_turtle":
			return TurtleKitScript.new()
		"water_snake":
			return WaterSnakeKitScript.new()
		"alligator":
			return AlligatorKitScript.new()
		"wolf_spider":
			return WolfSpiderKitScript.new()
		"firefly":
			return FireflyKitScript.new()
		"mosquito_swarm":
			return MosquitoSwarmKitScript.new()
		"chorus_frog":
			return FrogKitScript.new()
		"newt":
			return NewtKitScript.new()
		"mink":
			return MinkKitScript.new()
		"bullfrog":
			return BullfrogKitScript.new()
		"cane_toad":
			return CaneToadKitScript.new()
		"crayfish":
			return CrayfishKitScript.new()
		"bog_turtle":
			return BogTurtleKitScript.new()
		"water_shrew":
			return WaterShrewKitScript.new()
		"beaver":
			return BeaverKitScript.new()
		"otter":
			return OtterKitScript.new()
		"leech":
			return LeechKitScript.new()
		"owl":
			return OwlKitScript.new()
		"great_blue_heron":
			return HeronKitScript.new()
		"kingfisher":
			return KingfisherKitScript.new()
		"duck":
			return DuckKitScript.new()
		_:
			return null

func _is_wrong_terrain() -> bool:
	if current_environment_profile.is_empty():
		current_environment_profile = _environment_profile_for_zone(get_current_zone())
	return current_environment_profile.get("wrong_terrain_now", false) == true

func _uses_deep_water_swim_speed() -> bool:
	return EnvironmentProfileScript.uses_swim_speed_in_deep_water(_effective_movement_tags())

func _has_limited_swim_time() -> bool:
	return EnvironmentProfileScript.has_limited_swim_time(_effective_movement_tags()) and swim_time_max > 0.0

func _reset_terrain_profile() -> void:
	current_terrain_zone = get_current_zone()
	previous_terrain_zone = current_terrain_zone
	current_environment_profile = _environment_profile_for_zone(current_terrain_zone)
	render_terrain_transition_timer = 0.0
	render_terrain_from_surface = ""
	render_terrain_to_surface = ""
	terrain_speed_target_px = _terrain_target_speed_px(current_terrain_zone)
	terrain_speed_px = terrain_speed_target_px

func _environment_profile_for_zone(zone: String) -> Dictionary:
	if terrain_map != null and terrain_map.has_method("get_environment_profile_for_zone"):
		return terrain_map.get_environment_profile_for_zone(zone, _effective_movement_tags(), swim_time_remaining)
	return EnvironmentProfileScript.for_zone(zone, _effective_movement_tags(), swim_time_remaining)

func _active_movement_profile() -> Dictionary:
	if is_airborne():
		return movement_profile
	return MovementFeelScript.profile_for_surface(movement_profile, String(current_environment_profile.get("surface", "")))

func _update_body_heading(delta: float) -> void:
	var desired := last_aim_direction.normalized() if last_aim_direction != Vector2.ZERO else body_heading
	if velocity.length() > 20.0:
		desired = velocity.normalized()
	if desired == Vector2.ZERO:
		desired = Vector2.RIGHT
	var profile_turn_rate := _profile_body_turn_rate_deg()
	if body_capsule_half_len_px <= 0.0 and profile_turn_rate <= 0.0:
		body_heading = desired
		return
	if body_heading == Vector2.ZERO:
		body_heading = desired
		return
	var turn_rate := profile_turn_rate if profile_turn_rate > 0.0 else float(_active_movement_profile().get("turn_rate_deg", 900.0))
	var max_angle := deg_to_rad(turn_rate) * delta
	body_heading = body_heading.normalized().rotated(clampf(body_heading.normalized().angle_to(desired), -max_angle, max_angle)).normalized()

func _profile_body_turn_rate_deg() -> float:
	return float(_active_movement_profile().get("body_turn_rate_deg", 0.0))

func _effective_movement_tags() -> Array:
	var tags := movement_tags.duplicate()
	if tags.has("land_walker") and not tags.has("ground_walker"):
		tags.append("ground_walker")
	if tags.has("ground_walker") and not tags.has("land_walker"):
		tags.append("land_walker")
	if _modifier_value("water_walk", 1.0) > 1.5 and not tags.has("water_walk"):
		tags.append("water_walk")
	return tags

func _terrain_target_speed_px(zone: String) -> float:
	var profile := _environment_profile_for_zone(zone)
	var speed_mult := float(profile.get("speed_mult", 1.0))
	if zone == TerrainMapScript.WATER and _uses_deep_water_swim_speed():
		return _speed_px_for_water() * speed_mult
	return _speed_px_for_ground() * speed_mult

func _speed_px_for_ground() -> float:
	if stats.has("speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("speed", 1.0))
	if stats.has("ground_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("ground_speed", 1.0))
	return _catalog().speed_to_px_per_sec(1.0)

func _speed_px_for_water() -> float:
	if stats.has("swim_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("swim_speed", 1.0))
	return _speed_px_for_ground()

func _speed_px_for_flight() -> float:
	if stats.has("flight_speed"):
		return _catalog().speed_to_px_per_sec(_stat_float("flight_speed", 1.0))
	return _speed_px_for_ground()

func _attack_interval_sec() -> float:
	var interval := _numeric_stat("attack_interval_sec", 0.0)
	if interval > 0.0:
		return interval
	var rate := _numeric_stat("attack_rate_per_sec", 0.0)
	if rate > 0.0:
		return 1.0 / rate
	return 0.9

func _footprint_radius_px() -> float:
	var footprint: Dictionary = creature_data.get("footprint", {})
	return _catalog().units_to_px(float(footprint.get("radius_units", 0.5)))

# Capsule bodies (decision #19: Water Snake 0.4x2.5, Alligator 0.9x3.0) keep
# body_radius as the capsule radius and expose the core-segment half length
# so the hurtbox hull (decision #21) covers the full designed body.
func _footprint_capsule_half_len_px() -> float:
	var footprint: Dictionary = creature_data.get("footprint", {})
	if String(footprint.get("shape", "circle")) != "capsule":
		return 0.0
	var length_px: float = _catalog().units_to_px(float(footprint.get("length_units", 0.0)))
	return maxf(0.0, length_px * 0.5 - _footprint_radius_px())

func get_hurtbox_hull() -> Dictionary:
	return HurtboxScript.hull_of(self)

func _disable_godot_physics_collision() -> void:
	collision_layer = DISABLED_PHYSICS_LAYER
	collision_mask = DISABLED_PHYSICS_MASK

func _request_render_redraw(force := false) -> void:
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
	parts.append(creature_id)
	parts.append(str(team))
	parts.append(str(alive))
	parts.append(str(visible))
	parts.append(str(state))
	parts.append(str(_quantized_ratio(health, max_health, RENDER_RATIO_BUCKETS)))
	parts.append(str(_quantized_ratio(hunger, HUNGER_MAX, RENDER_RATIO_BUCKETS)))
	parts.append(str(hunger_satiated))
	parts.append(str(_quantized_ratio(swim_time_remaining, swim_time_max, RENDER_RATIO_BUCKETS)))
	parts.append(str(_quantized_ratio(flight_time_remaining, flight_time_max, RENDER_RATIO_BUCKETS)))
	parts.append(str(_quantized_ratio(secondary_resource, secondary_resource_max, RENDER_RATIO_BUCKETS)))
	parts.append(secondary_resource_label)
	parts.append(str(is_airborne()))
	parts.append(str(is_stealthed()))
	parts.append(str(has_latch()))
	parts.append(str(_quantized_ratio(latch_timer, 5.0, RENDER_RATIO_BUCKETS)))
	parts.append(str(render_hitstop_frames))
	parts.append(str(_timer_bucket(render_counter_flash_timer, COUNTER_FLASH_SEC)))
	parts.append(str(_timer_bucket(render_flash_timer, 0.1)))
	parts.append(str(_timer_bucket(render_shake_timer, 0.1)))
	parts.append(str(_timer_bucket(render_takeoff_flap_timer, TAKEOFF_FLAP_TELL_SEC)))
	parts.append(str(_timer_bucket(render_landing_flap_timer, LANDING_FLAP_TELL_SEC)))
	parts.append(str(_timer_bucket(render_landing_timer, LANDING_TELL_SEC)))
	parts.append(str(_timer_bucket(render_terrain_transition_timer, TERRAIN_TRANSITION_TELL_SEC)))
	parts.append(str(_timer_bucket(render_toxic_recoil_timer, TOXIC_RECOIL_TELL_SEC)))
	parts.append(str(_timer_bucket(render_escape_curl_timer, ESCAPE_CURL_TELL_SEC)))
	parts.append(str(_timer_bucket(render_plunge_timer, PLUNGE_TELL_SEC)))
	parts.append(str(_timer_bucket(render_air_attack_startup_timer, render_air_attack_startup_duration)))
	parts.append(str(_timer_bucket(anim_attack_timer, anim_attack_duration)))
	parts.append(str(_timer_bucket(anim_windup_timer, anim_windup_duration)))
	var attack_snapshot := get_primary_attack_snapshot()
	parts.append(str(attack_snapshot["attack_sequence_id"]))
	parts.append(str(attack_snapshot["attack_phase"]))
	parts.append(str(_quantized_ratio(
		float(attack_snapshot["phase_t"]),
		1.0,
		RENDER_TIMER_BUCKETS
	)))
	parts.append(str(attack_snapshot["attack_outcome"]))
	parts.append(str(_angle_bucket(attack_snapshot["strike_heading"])))
	parts.append(str(attack_snapshot["presentation_sequence_id"]))
	parts.append(str(attack_snapshot["presentation_revision"]))
	parts.append(str(_timer_bucket(low_window_timer, LOW_WINDOW_VISUAL_MAX_SEC)))
	parts.append(str(_quantized_ratio(wrong_terrain_seconds, WRONG_TERRAIN_GRACE_SEC, RENDER_TIMER_BUCKETS)))
	parts.append(str(_angle_bucket(get_body_axis())))
	parts.append(str(_angle_bucket(last_aim_direction)))
	parts.append(str(velocity.length() > 4.0))
	parts.append(str(_walk_phase_bucket()))
	parts.append(str(_quantized_ratio(render_landing_impact, 1.5, RENDER_TIMER_BUCKETS)))
	parts.append(str(_quantized_ratio(render_flash_region_mult, 2.0, RENDER_TIMER_BUCKETS)))
	parts.append(_open_hurtbox_region_signature())
	parts.append(render_terrain_from_surface)
	parts.append(render_terrain_to_surface)
	parts.append(String(current_environment_profile.get("surface", "")))
	return "|".join(parts)

func _open_hurtbox_region_signature() -> String:
	var parts: Array[String] = []
	for region: Dictionary in HurtboxScript.open_regions(self):
		parts.append("%s:%d" % [
			String(region.get("region", "")),
			_quantized_ratio(float(region.get("region_mult", 1.0)), 2.0, RENDER_TIMER_BUCKETS)
		])
	return ",".join(parts)

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

func _walk_phase_bucket() -> int:
	if velocity.length() <= 4.0:
		return 0
	return int(round(wrapf(anim_walk_phase, 0.0, TAU) / TAU * RENDER_PHASE_BUCKETS))

func _stat_float(key: String, fallback: float) -> float:
	var value := _numeric_stat(key, fallback)
	match key:
		"health":
			value *= _team_buff_multiplier("max_health")
		"speed", "ground_speed", "swim_speed", "flight_speed":
			value *= _team_buff_multiplier("move_speed")
	return value

func _numeric_stat(key: String, fallback: float) -> float:
	var value: Variant = stats.get(key, fallback)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback

func _team_breeding_bonus(effect: String) -> float:
	if arena != null and arena.has_method("get_team_breeding_effect"):
		return float(arena.get_team_breeding_effect(team, effect))
	return 0.0

func _team_boss_stock_bonus(effect: String) -> float:
	if arena != null and arena.has_method("get_team_boss_stock_effect"):
		return float(arena.get_team_boss_stock_effect(team, effect))
	return 0.0

# Combined team buff bonus: capped breeding channel + boss-stock channel. The two stay
# separate stacks arena-side (BB-BOSS-4); only their final stat effect is summed here.
func _team_buff_bonus(effect: String) -> float:
	return _team_breeding_bonus(effect) + _team_boss_stock_bonus(effect)

func _team_buff_multiplier(effect: String) -> float:
	return 1.0 + _team_buff_bonus(effect)

func _catalog() -> Node:
	return Engine.get_main_loop().root.get_node("CreatureCatalog")

func _draw() -> void:
	if not alive:
		return
	var shake_offset := Vector2.ZERO
	if render_shake_timer > 0.0:
		var shake_phase := render_shake_timer * 120.0
		shake_offset = Vector2(sin(shake_phase), cos(shake_phase * 1.37)) * 2.0
	var anim := MovementFeelScript.render_anim(_active_movement_profile(), anim_walk_phase)
	anim.merge({
		"walk_phase": anim_walk_phase,
		"moving": velocity.length() > 4.0,
		"attack_t": 1.0 - anim_attack_timer / anim_attack_duration if anim_attack_timer > 0.0 else -1.0,
		"attack_reach": anim_attack_reach,
		"attack_aim": anim_attack_aim,
		"windup_t": 1.0 - anim_windup_timer / anim_windup_duration if anim_windup_timer > 0.0 else -1.0,
		"flash_region_mult": render_flash_region_mult,
		"shake_offset": shake_offset
	})
	anim.merge(get_render_motion_state(), true)
	var draw_alpha := 0.4 if is_stealthed() else 1.0
	if wrong_terrain_seconds > 0.0:
		_draw_wrong_terrain_warning()
	VisualStyle.draw_battle_creature(self, creature_id, team, body_radius, get_body_axis(), render_flash_timer / 0.1, draw_alpha, is_airborne() or state == CreatureStateScript.State.PERCHED, anim)
	if arena != null and arena.get("player") == self:
		VisualStyle.draw_aim_indicator(self, body_radius, last_aim_direction)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0, 5.0)), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(Vector2(-body_radius, -body_radius - 12.0), Vector2(body_radius * 2.0 * (health / max_health), 5.0)), Color(0.3, 1.0, 0.45))
	if swim_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 6.0), body_radius * 2.0, get_swim_ratio(), Color(0.2, 0.7, 1.0))
	if flight_time_max > 0.0:
		_draw_meter(Vector2(-body_radius, body_radius + 12.0), body_radius * 2.0, get_flight_ratio(), Color(0.9, 0.9, 0.45))
	if has_latch():
		draw_rect(Rect2(Vector2(-body_radius, body_radius + 18.0), Vector2(body_radius * 2.0, 3.0)), Color(1.0, 0.35, 0.25))
	_draw_meter(Vector2(-body_radius, body_radius + 24.0), body_radius * 2.0, clampf(hunger / HUNGER_MAX, 0.0, 1.0), Color(0.92, 0.7, 0.28) if not hunger_satiated else Color(0.45, 1.0, 0.52))

func _draw_meter(start: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(start, Vector2(width, 3.0)), Color(0.06, 0.06, 0.07))
	draw_rect(Rect2(start, Vector2(width * ratio, 3.0)), color)

func _draw_wrong_terrain_warning() -> void:
	var danger_t := clampf(wrong_terrain_seconds / WRONG_TERRAIN_GRACE_SEC, 0.0, 1.0)
	var late := wrong_terrain_seconds > WRONG_TERRAIN_GRACE_SEC
	var pulse := sin(Time.get_ticks_msec() * 0.012) * 0.5 + 0.5
	var color := Color(0.24, 0.72, 1.0, 0.26 + danger_t * 0.2)
	if late:
		color = Color(1.0, 0.25, 0.16, 0.46 + pulse * 0.18)
	var ring_radius := body_radius + 7.0 + pulse * (3.0 if late else 1.5)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, color, 2.5)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + pulse * 0.5
		var bubble := Vector2(cos(angle), sin(angle)) * (body_radius * 0.55 + float(i) * 2.0)
		draw_circle(bubble, 1.8 + danger_t * 1.4, color.lightened(0.15))

func _update_render_landing(delta: float) -> void:
	render_landing_timer = maxf(render_landing_timer - delta, 0.0)
	if render_landing_timer <= 0.0:
		render_landing_impact = 0.0
	var profile := _active_movement_profile()
	var thump := clampf(float(profile.get("landing_thump", 0.0)), 0.0, 1.5)
	if thump <= 0.0 or velocity.length() <= 4.0:
		render_last_hop_airborne = false
		return
	var ground_contact := clampf(float(profile.get("ground_contact", 0.6)), 0.1, 0.95)
	var raw_hop := sin(anim_walk_phase * 1.2) * 0.5 + 0.5
	var hop_airborne := raw_hop > ground_contact
	if render_last_hop_airborne and not hop_airborne:
		render_landing_timer = LANDING_TELL_SEC
		render_landing_impact = thump
	render_last_hop_airborne = hop_airborne
