extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const MovementFeelScript := preload("res://scripts/sim/movement_feel.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const CreatureStateScript := preload("res://scripts/sim/creature_state.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("movement feel check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	var failures: Array[String] = []
	if arena == null or arena.player == null:
		push_error("movement feel check missing arena/player")
		quit(1)
		return

	_check_profile_ramp(arena, failures)
	_check_turn_inertia(arena, failures)
	_check_profile_body_heading(arena, failures)
	_check_directional_scuttle(arena, failures)
	_check_dash_bypass(arena, failures)
	_check_dash_residual_bleed(arena, failures)
	_check_render_profile_keys(arena, failures)
	_check_landing_tell(arena, failures)
	_check_water_profile_overlay(arena, failures)
	_check_terrain_transition_cues(arena, failures)
	_check_wave4_profile_seeds(failures)
	_check_render_state_flags(arena, failures)
	_check_bird_transition_cues(arena, failures)
	_check_predator_latch_cues(arena, failures)
	_check_visual_height_profiles(arena, failures)
	_check_air_attack_readability_contract(arena, failures)
	_check_live_height_hud_read(arena, failures)
	_check_actor_redraw_signatures(arena, failures)

	print("movement_feel failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_profile_ramp(arena: Node, failures: Array[String]) -> void:
	var bullfrog: Node = arena.player
	bullfrog.apply_creature("bullfrog")
	bullfrog.global_position = Vector2(200.0, 200.0)
	bullfrog.velocity = Vector2.ZERO
	var shrew: Node = arena.bots[0]
	shrew.apply_creature("water_shrew")
	shrew.global_position = Vector2(260.0, 200.0)
	shrew.velocity = Vector2.ZERO
	var frame := _move_frame(Vector2.RIGHT)
	bullfrog.set_input_frame(frame)
	shrew.set_input_frame(frame)
	bullfrog.tick_sim(1.0 / 60.0)
	shrew.tick_sim(1.0 / 60.0)
	var bullfrog_ratio: float = bullfrog.velocity.length() / bullfrog.get_speed_px()
	var shrew_ratio: float = shrew.velocity.length() / shrew.get_speed_px()
	if not (bullfrog_ratio > 0.05 and bullfrog_ratio < 0.6 and shrew_ratio > bullfrog_ratio + 0.2):
		failures.append("movement profiles should create distinct first-step acceleration; bullfrog=%.3f shrew=%.3f" % [bullfrog_ratio, shrew_ratio])

func _check_turn_inertia(arena: Node, failures: Array[String]) -> void:
	var turtle: Node = arena.player
	turtle.apply_creature("snapping_turtle")
	turtle.global_position = Vector2(300.0, 300.0)
	turtle.velocity = Vector2.ZERO
	turtle.set_input_frame(_move_frame(Vector2.RIGHT))
	for i in 18:
		turtle.tick_sim(1.0 / 60.0)
	turtle.set_input_frame(_move_frame(Vector2.UP))
	for i in 6:
		turtle.tick_sim(1.0 / 60.0)
	if not (turtle.velocity.x > 8.0 and turtle.velocity.y < -1.0):
		failures.append("heavy turtle profile should keep forward momentum while beginning a turn; velocity=%s" % str(turtle.velocity))

func _check_profile_body_heading(arena: Node, failures: Array[String]) -> void:
	var gator: Node = arena.player
	gator.apply_creature("alligator")
	gator.global_position = Vector2.ZERO
	gator.velocity = Vector2.ZERO
	gator.last_aim_direction = Vector2.RIGHT
	gator.body_heading = Vector2.RIGHT
	gator.set_input_frame(_aim_frame(Vector2.LEFT))
	for i in 6:
		gator.tick_sim(1.0 / 60.0)
	var gator_lagged: bool = gator.last_aim_direction.dot(Vector2.LEFT) > 0.99 and gator.body_heading.dot(Vector2.RIGHT) > 0.75
	var frog: Node = arena.bots[0]
	frog.apply_creature("bullfrog")
	frog.global_position = Vector2.ZERO
	frog.velocity = Vector2.ZERO
	frog.last_aim_direction = Vector2.RIGHT
	frog.body_heading = Vector2.RIGHT
	frog.set_input_frame(_aim_frame(Vector2.LEFT))
	for i in 6:
		frog.tick_sim(1.0 / 60.0)
	var frog_lagged: bool = frog.last_aim_direction.dot(Vector2.LEFT) > 0.99 \
		and frog.body_heading.dot(Vector2.RIGHT) > 0.65 \
		and frog.get_body_axis().dot(frog.body_heading.normalized()) > 0.99 \
		and float(frog.movement_profile.get("body_turn_rate_deg", 0.0)) > 0.0
	var shrew: Node = arena.bots[1]
	shrew.apply_creature("water_shrew")
	shrew.global_position = Vector2.ZERO
	shrew.velocity = Vector2.ZERO
	shrew.last_aim_direction = Vector2.RIGHT
	shrew.body_heading = Vector2.RIGHT
	shrew.set_input_frame(_aim_frame(Vector2.LEFT))
	shrew.tick_sim(1.0 / 60.0)
	var shrew_snapped: bool = shrew.body_heading.dot(Vector2.LEFT) > 0.99 and shrew.get_body_axis().dot(Vector2.LEFT) > 0.99
	if not gator_lagged or not frog_lagged or not shrew_snapped:
		failures.append("profile body heading should lag heavy capsule/round bodies while twitchy bodies snap; gator=%s/%s frog=%s/%s shrew=%s/%s" % [
			str(gator.last_aim_direction),
			str(gator.body_heading),
			str(frog.last_aim_direction),
			str(frog.body_heading),
			str(shrew.last_aim_direction),
			str(shrew.body_heading)
		])

func _check_directional_scuttle(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	var forward_speed := _one_tick_velocity(actor, "crayfish", Vector2.RIGHT)
	var lateral_speed := _one_tick_velocity(actor, "crayfish", Vector2.UP)
	var backward_speed := _one_tick_velocity(actor, "crayfish", Vector2.LEFT)
	var frog_lateral := _one_tick_velocity(actor, "bullfrog", Vector2.UP)
	if not (lateral_speed > forward_speed * 1.3 and backward_speed > lateral_speed * 1.05 and lateral_speed > frog_lateral * 2.0):
		failures.append("crayfish should scuttle laterally and snap backward relative to facing; forward=%.2f lateral=%.2f backward=%.2f frog_lateral=%.2f" % [
			forward_speed,
			lateral_speed,
			backward_speed,
			frog_lateral
		])

func _check_dash_bypass(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2(420.0, 300.0)
	actor.velocity = Vector2.ZERO
	actor.dash_velocity = Vector2.RIGHT * 700.0
	actor.dash_timer = 0.2
	actor.set_input_frame(_move_frame(Vector2.LEFT))
	actor.tick_sim(1.0 / 60.0)
	if actor.velocity.x < 690.0:
		failures.append("dash velocity should bypass movement feel acceleration; velocity=%s" % str(actor.velocity))
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO

func _check_dash_residual_bleed(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2(420.0, 300.0)
	actor.velocity = Vector2.ZERO
	actor.residual_velocity = Vector2.ZERO
	actor.dash_velocity = Vector2.RIGHT * 600.0
	actor.dash_timer = 1.0 / 60.0
	actor.set_input_frame(_move_frame(Vector2.LEFT))
	actor.tick_sim(1.0 / 60.0)
	var captured: bool = actor.dash_timer <= 0.0 and actor.dash_velocity == Vector2.ZERO and actor.residual_velocity.x > 590.0 and actor.velocity.x > 550.0
	var first_residual: float = actor.residual_velocity.length()
	actor.tick_sim(1.0 / 60.0)
	var decayed_once: bool = actor.residual_velocity.length() < first_residual * 0.70 and actor.residual_velocity.length() > first_residual * 0.65
	var moving_after_dash: bool = actor.velocity.x > 250.0
	if not captured or not decayed_once or not moving_after_dash:
		failures.append("dash residual should capture on expiry and decay deterministically; captured=%s decayed=%s moving=%s residual=%.2f velocity=%s" % [
			str(captured),
			str(decayed_once),
			str(moving_after_dash),
			actor.residual_velocity.length(),
			str(actor.velocity)
		])
	actor.residual_velocity = Vector2.ZERO

func _check_render_profile_keys(arena: Node, failures: Array[String]) -> void:
	var frog: Node = arena.player
	frog.apply_creature("bullfrog")
	var toad: Node = arena.bots[0]
	toad.apply_creature("cane_toad")
	if String(frog.movement_profile.get("gait", "")) != "heavy_hop":
		failures.append("bullfrog should expose heavy_hop gait metadata")
	if not float(toad.movement_profile.get("bob_px", 0.0)) < float(frog.movement_profile.get("bob_px", 0.0)):
		failures.append("cane toad should expose a smaller hop bob than bullfrog")
	if not float(toad.movement_profile.get("hop_leg_scale", 0.0)) < float(frog.movement_profile.get("hop_leg_scale", 0.0)):
		failures.append("cane toad should use shorter hop legs than bullfrog")
	if not float(toad.movement_profile.get("ground_contact", 0.0)) > float(frog.movement_profile.get("ground_contact", 0.0)):
		failures.append("cane toad should keep longer ground contact than bullfrog")
	if not float(frog.movement_profile.get("landing_thump", 0.0)) > float(toad.movement_profile.get("landing_thump", 0.0)):
		failures.append("bullfrog should expose heavier landing thump metadata than cane toad")
	if not float(frog.movement_profile.get("body_turn_rate_deg", 0.0)) > 0.0:
		failures.append("bullfrog should expose profile-driven round-body heading lag metadata")
	var crayfish: Node = arena.bots[1]
	crayfish.apply_creature("crayfish")
	if not float(crayfish.movement_profile.get("scuttle_stride", 0.0)) > 1.0:
		failures.append("crayfish should expose a wider scuttle stride")
	var spider: Node = arena.bots[2]
	spider.apply_creature("wolf_spider")
	if not float(spider.movement_profile.get("low_slung", 0.0)) > 0.0:
		failures.append("wolf spider should expose low scuttle posture metadata")
	var firefly: Node = arena.player
	firefly.apply_creature("firefly")
	if not float(firefly.movement_profile.get("glow_breathe", 0.0)) > 0.0:
		failures.append("firefly should expose glow breathing metadata")
	var mosquito: Node = arena.bots[0]
	mosquito.apply_creature("mosquito_swarm")
	if not float(mosquito.movement_profile.get("swarm_jitter", 0.0)) > 0.0:
		failures.append("mosquito swarm should expose swarm jitter metadata")
	var snake: Node = arena.bots[1]
	snake.apply_creature("water_snake")
	if not float(snake.movement_profile.get("slither_amp", 0.0)) > 1.0:
		failures.append("water snake should expose amplified slither metadata")
	var gator: Node = arena.bots[2]
	gator.apply_creature("alligator")
	if not float(gator.movement_profile.get("crawl_weight", 0.0)) > 0.0:
		failures.append("alligator should expose heavy crawl metadata")
	var newt: Node = arena.bots[0]
	newt.apply_creature("newt")
	if not float(newt.movement_profile.get("tail_wave", 0.0)) > 1.0:
		failures.append("newt should expose slick tail-wave metadata")
	var heron: Node = arena.bots[1]
	heron.apply_creature("great_blue_heron")
	if not float(heron.movement_profile.get("bird_stride", 1.0)) < 1.0:
		failures.append("heron should expose patient wading stride metadata")
	var kingfisher: Node = arena.bots[2]
	kingfisher.apply_creature("kingfisher")
	if not float(kingfisher.movement_profile.get("perch_flutter", 1.0)) > 1.0:
		failures.append("kingfisher should expose dart-hover flutter metadata")
	var chorus: Node = arena.bots[0]
	chorus.apply_creature("chorus_frog")
	if not float(chorus.movement_profile.get("gait_rate_mult", 0.0)) > 1.0:
		failures.append("chorus frog should expose light rhythmic hop metadata")
	var duck: Node = arena.bots[1]
	duck.apply_creature("duck")
	if not float(duck.movement_profile.get("waddle_sway", 0.0)) > 0.0:
		failures.append("duck should expose waddle-paddle metadata")
	if not float(duck.movement_profile.get("body_turn_rate_deg", 0.0)) > 0.0:
		failures.append("duck should expose profile-driven body heading lag metadata")
	var beaver: Node = arena.bots[2]
	beaver.apply_creature("beaver")
	if not float(beaver.movement_profile.get("body_wiggle", 1.0)) < 1.0:
		failures.append("beaver should expose builder trundle metadata")
	if not float(beaver.movement_profile.get("body_turn_rate_deg", 0.0)) > 0.0:
		failures.append("beaver should expose heavy body heading lag metadata")
	var mink: Node = arena.bots[0]
	mink.apply_creature("mink")
	if not float(mink.movement_profile.get("body_wiggle", 0.0)) > 1.0:
		failures.append("mink should expose elastic bound metadata")
	var owl: Node = arena.bots[1]
	owl.apply_creature("owl")
	if not float(owl.movement_profile.get("wingbeat_mult", 1.0)) < 1.0:
		failures.append("owl should expose slow silent wingbeat metadata")
	var turtle2: Node = arena.bots[2]
	turtle2.apply_creature("snapping_turtle")
	if not float(turtle2.movement_profile.get("shell_stability", 0.0)) > 0.0:
		failures.append("snapping turtle should expose stable shell metadata")

func _check_landing_tell(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("bullfrog")
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	actor.render_landing_timer = 0.0
	actor.render_landing_impact = 0.0
	actor.render_last_hop_airborne = true
	actor.anim_walk_phase = PI
	actor._process(1.0 / 60.0)
	var landing_state: Dictionary = actor.get_render_motion_state()
	var triggered: bool = float(landing_state.get("landing_t", 0.0)) > 0.85 and absf(float(landing_state.get("landing_impact", 0.0)) - 1.0) < 0.001
	actor._process(0.08)
	var decayed_state: Dictionary = actor.get_render_motion_state()
	var decayed: bool = float(decayed_state.get("landing_t", 1.0)) < float(landing_state.get("landing_t", 0.0))
	actor.apply_creature("water_shrew")
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.render_last_hop_airborne = true
	actor.anim_walk_phase = PI
	actor._process(1.0 / 60.0)
	var shrew_state: Dictionary = actor.get_render_motion_state()
	var gated: bool = float(shrew_state.get("landing_t", 0.0)) <= 0.001 and float(shrew_state.get("landing_impact", 0.0)) <= 0.001
	if not triggered or not decayed or not gated:
		failures.append("hop landing tell should trigger/decay for bullfrog and stay gated for non-hop profiles; triggered=%s decayed=%s gated=%s states=%s/%s/%s" % [
			str(triggered),
			str(decayed),
			str(gated),
			str(landing_state),
			str(decayed_state),
			str(shrew_state)
		])

func _check_water_profile_overlay(arena: Node, failures: Array[String]) -> void:
	var turtle: Node = arena.player
	turtle.apply_creature("snapping_turtle")
	var land_profile: Dictionary = turtle.movement_profile
	var water_profile: Dictionary = MovementFeelScript.profile_for_surface(land_profile, "water")
	if not float(water_profile.get("accel_time", 0.0)) < float(land_profile.get("accel_time", 0.0)):
		failures.append("snapping turtle should accelerate more smoothly in water; land=%s water=%s" % [str(land_profile), str(water_profile)])
	if not float(water_profile.get("turtle_stride", 0.0)) > float(land_profile.get("turtle_stride", 0.0)):
		failures.append("snapping turtle water overlay should paddle more than land creep")
	var beaver_profile: Dictionary = MovementFeelScript.profile_for("beaver")
	var beaver_water: Dictionary = MovementFeelScript.profile_for_surface(beaver_profile, "water")
	if not float(beaver_water.get("tail_wave", 0.0)) > float(beaver_profile.get("tail_wave", 0.0)):
		failures.append("beaver water overlay should emphasize tail-rudder motion")
	turtle.current_environment_profile = {"surface": "water"}
	if not float(turtle._active_movement_profile().get("turn_rate_deg", 0.0)) > float(land_profile.get("turn_rate_deg", 0.0)):
		failures.append("creature active profile should use water movement overlay")

func _check_terrain_transition_cues(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("snapping_turtle")
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var land_point := _movement_zone_point(arena, TerrainMapScript.LAND)
	var water_point := _movement_zone_point(arena, TerrainMapScript.WATER)
	var shallow_point := _movement_zone_point(arena, TerrainMapScript.SHALLOW)
	actor.global_position = land_point
	actor._reset_terrain_profile()
	actor.global_position = water_point
	actor._update_terrain(SimConstants.TICK_DELTA)
	var water_state: Dictionary = actor.get_render_motion_state()
	actor.global_position = shallow_point
	actor._update_terrain(SimConstants.TICK_DELTA)
	var mud_state: Dictionary = actor.get_render_motion_state()
	actor.global_position = land_point
	actor._update_terrain(SimConstants.TICK_DELTA)
	var land_state: Dictionary = actor.get_render_motion_state()
	var water_entry: bool = String(water_state.get("terrain_transition_from_surface", "")) == "solid" \
		and String(water_state.get("terrain_transition_to_surface", "")) == "water" \
		and float(water_state.get("water_entry_t", 0.0)) > 0.9 \
		and float(water_state.get("terrain_splash_t", 0.0)) > 0.9
	var mud_entry: bool = String(mud_state.get("terrain_transition_from_surface", "")) == "water" \
		and String(mud_state.get("terrain_transition_to_surface", "")) == "mud" \
		and float(mud_state.get("water_exit_t", 0.0)) > 0.9 \
		and float(mud_state.get("mud_entry_t", 0.0)) > 0.9 \
		and float(mud_state.get("terrain_scuff_t", 0.0)) > 0.9
	var mud_exit: bool = String(land_state.get("terrain_transition_from_surface", "")) == "mud" \
		and String(land_state.get("terrain_transition_to_surface", "")) == "solid" \
		and float(land_state.get("mud_exit_t", 0.0)) > 0.9 \
		and float(land_state.get("terrain_scuff_t", 0.0)) > 0.9
	if not water_entry or not mud_entry or not mud_exit:
		failures.append("terrain changes should expose splash/scuff transition cues across land, water, and mud; water=%s mud=%s land=%s state=%s/%s/%s points=%s/%s/%s" % [
			str(water_entry),
			str(mud_entry),
			str(mud_exit),
			str(water_state),
			str(mud_state),
			str(land_state),
			str(land_point),
			str(water_point),
			str(shallow_point)
		])

func _check_wave4_profile_seeds(failures: Array[String]) -> void:
	var bog_turtle: Dictionary = MovementFeelScript.profile_for("bog_turtle")
	if String(bog_turtle.get("gait", "")) != "tiny_creep" or not float(bog_turtle.get("shell_stability", 0.0)) > 0.0:
		failures.append("bog turtle should expose tiny stubborn turtle movement metadata")
	var otter: Dictionary = MovementFeelScript.profile_for("otter")
	var otter_water: Dictionary = MovementFeelScript.profile_for_surface(otter, "water")
	if String(otter.get("gait", "")) != "bound_slide" or not float(otter_water.get("tail_wave", 0.0)) > float(otter.get("tail_wave", 0.0)):
		failures.append("otter should expose bound-slide land and stronger water tail metadata")
	var leech: Dictionary = MovementFeelScript.profile_for("leech")
	var leech_water: Dictionary = MovementFeelScript.profile_for_surface(leech, "water")
	if String(leech.get("gait", "")) != "inchworm_cluster" or not float(leech.get("inchworm_pulse", 0.0)) > 0.0 or not float(leech_water.get("tail_wave", 0.0)) > float(leech.get("tail_wave", 0.0)):
		failures.append("leech should expose inchworm land and undulating water metadata")

func _check_render_state_flags(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("cane_toad")
	actor.add_modifier("Thanatosis", {"move_speed_mult": 0.0}, 1.0)
	if not bool(actor.get_render_motion_state().get("rooted_pose", false)):
		failures.append("Thanatosis should expose rooted render pose")
	actor.remove_modifiers_from_source("Thanatosis")
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var cane_non_cane_motion_flags: Array[String] = [
		"chorus_hop_pose", "bullfrog_heavy_hop_pose", "bullfrog_coil_pose", "bullfrog_lunge_pose",
		"shrew_land_skitter_pose", "surface_walk", "submerged_shrew_pose", "slick_crawl_pose", "newt_swim_pose",
		"leech_inchworm_pose", "leech_undulate_pose", "water_snake_land_slither_pose", "water_slither_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"duck_waddle_pose", "duck_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "otter_land_slide_pose", "otter_swim_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "spider_skitter_pose", "high_walk_pose",
		"alligator_water_cruise_pose", "owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose",
		"wading_pose", "heron_stalk_pose", "mosquito_swarm_pose", "firefly_hover_pose"
	]
	var cane_hop_state: Dictionary = actor.get_render_motion_state()
	var cane_hop: bool = bool(cane_hop_state.get("cane_squat_hop_pose", false)) \
		and float(cane_hop_state.get("cane_squat_hop_intensity", 0.0)) > 0.25 \
		and not bool(cane_hop_state.get("rooted_pose", false)) \
		and not bool(cane_hop_state.get("chorus_hop_pose", false)) \
		and not bool(cane_hop_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(cane_hop_state.get("bullfrog_coil_pose", false)) \
		and not bool(cane_hop_state.get("bullfrog_lunge_pose", false)) \
		and not bool(cane_hop_state.get("camouflage_eye_cue", false)) \
		and _none_render_flags(cane_hop_state, cane_non_cane_motion_flags)
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var cane_idle_state: Dictionary = actor.get_render_motion_state()
	var cane_idle_clear: bool = not bool(cane_idle_state.get("cane_squat_hop_pose", false)) \
		and not bool(cane_idle_state.get("rooted_pose", false)) \
		and not bool(cane_idle_state.get("chorus_hop_pose", false)) \
		and not bool(cane_idle_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(cane_idle_state.get("bullfrog_coil_pose", false)) \
		and not bool(cane_idle_state.get("bullfrog_lunge_pose", false)) \
		and not bool(cane_idle_state.get("camouflage_eye_cue", false)) \
		and _none_render_flags(cane_idle_state, cane_non_cane_motion_flags) \
		and float(cane_idle_state.get("cane_squat_hop_intensity", 1.0)) <= 0.001
	actor.add_modifier("Thanatosis", {"move_speed_mult": 0.0}, 1.0)
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var cane_rooted_state: Dictionary = actor.get_render_motion_state()
	var cane_rooted_suppressed: bool = bool(cane_rooted_state.get("rooted_pose", false)) \
		and not bool(cane_rooted_state.get("cane_squat_hop_pose", false)) \
		and not bool(cane_rooted_state.get("chorus_hop_pose", false)) \
		and not bool(cane_rooted_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(cane_rooted_state.get("bullfrog_coil_pose", false)) \
		and not bool(cane_rooted_state.get("bullfrog_lunge_pose", false)) \
		and not bool(cane_rooted_state.get("camouflage_eye_cue", false)) \
		and _none_render_flags(cane_rooted_state, cane_non_cane_motion_flags)
	actor.remove_modifiers_from_source("Thanatosis")
	if not cane_hop or not cane_idle_clear or not cane_rooted_suppressed:
		failures.append("moving cane toad should expose low warty squat-hop without rooted, chorus, bullfrog, crawler, swimmer, snake, turtle, duck, mammal, gator, bird, swarm, hover, crustacean, or spider overlap, clear when idle, and defer to Thanatosis rooted pose; moving=%s idle=%s rooted=%s state=%s/%s/%s" % [
			str(cane_hop),
			str(cane_idle_clear),
			str(cane_rooted_suppressed),
			str(cane_hop_state),
			str(cane_idle_state),
			str(cane_rooted_state)
		])
	actor.apply_creature("crayfish")
	actor.add_modifier("Meral Display", {"forward_back_only": 2.0}, 1.0)
	var stance_state: Dictionary = actor.get_render_motion_state()
	actor.modifiers.clear()
	actor.last_aim_direction = Vector2.RIGHT
	actor.dash_velocity = Vector2.LEFT * 220.0
	actor.dash_timer = 0.2
	var escape_state: Dictionary = actor.get_render_motion_state()
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	if not bool(stance_state.get("display_stance", false)) or not bool(escape_state.get("escape_dash", false)):
		failures.append("crayfish should expose display and escape render states; stance=%s escape=%s" % [str(stance_state), str(escape_state)])
	actor.apply_creature("bullfrog")
	actor.velocity = Vector2.ZERO
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var bullfrog_non_bullfrog_motion_flags: Array[String] = [
		"chorus_hop_pose", "cane_squat_hop_pose", "shrew_land_skitter_pose", "surface_walk", "submerged_shrew_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "duck_waddle_pose", "duck_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose",
		"otter_land_slide_pose", "otter_swim_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "high_walk_pose", "alligator_water_cruise_pose", "owl_glide_pose",
		"owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose", "heron_stalk_pose",
		"mosquito_swarm_pose", "firefly_hover_pose"
	]
	var bullfrog_hop_state: Dictionary = actor.get_render_motion_state()
	var bullfrog_hop: bool = bool(bullfrog_hop_state.get("bullfrog_heavy_hop_pose", false)) \
		and float(bullfrog_hop_state.get("bullfrog_heavy_hop_intensity", 0.0)) > 0.25 \
		and not bool(bullfrog_hop_state.get("rooted_pose", false)) \
		and not bool(bullfrog_hop_state.get("chorus_hop_pose", false)) \
		and not bool(bullfrog_hop_state.get("cane_squat_hop_pose", false)) \
		and not bool(bullfrog_hop_state.get("bullfrog_coil_pose", false)) \
		and not bool(bullfrog_hop_state.get("bullfrog_lunge_pose", false)) \
		and not bool(bullfrog_hop_state.get("camouflage_eye_cue", false)) \
		and _none_render_flags(bullfrog_hop_state, bullfrog_non_bullfrog_motion_flags)
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	actor.begin_stealth(2.0, "Camouflage")
	var bullfrog_camouflage_state: Dictionary = actor.get_render_motion_state()
	var bullfrog_camouflage: bool = bool(bullfrog_camouflage_state.get("bullfrog_coil_pose", false)) \
		and bool(bullfrog_camouflage_state.get("camouflage_eye_cue", false)) \
		and float(bullfrog_camouflage_state.get("bullfrog_coil_intensity", 0.0)) > 0.9 \
		and not bool(bullfrog_camouflage_state.get("rooted_pose", false)) \
		and not bool(bullfrog_camouflage_state.get("chorus_hop_pose", false)) \
		and not bool(bullfrog_camouflage_state.get("cane_squat_hop_pose", false)) \
		and not bool(bullfrog_camouflage_state.get("bullfrog_heavy_hop_pose", false)) \
		and _none_render_flags(bullfrog_camouflage_state, bullfrog_non_bullfrog_motion_flags)
	actor.break_stealth()
	actor.kit.lunge_active = true
	actor.dash_timer = 0.18
	actor.dash_velocity = Vector2.RIGHT * 560.0
	actor.velocity = actor.dash_velocity
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var bullfrog_lunge_state: Dictionary = actor.get_render_motion_state()
	var bullfrog_lunge: bool = bool(bullfrog_lunge_state.get("bullfrog_lunge_pose", false)) \
		and bool(bullfrog_lunge_state.get("bullfrog_coil_pose", false)) \
		and float(bullfrog_lunge_state.get("bullfrog_lunge_intensity", 0.0)) > 0.9 \
		and not bool(bullfrog_lunge_state.get("rooted_pose", false)) \
		and not bool(bullfrog_lunge_state.get("chorus_hop_pose", false)) \
		and not bool(bullfrog_lunge_state.get("cane_squat_hop_pose", false)) \
		and not bool(bullfrog_lunge_state.get("bullfrog_heavy_hop_pose", false)) \
		and _none_render_flags(bullfrog_lunge_state, bullfrog_non_bullfrog_motion_flags)
	actor.kit.lunge_active = false
	actor.dash_timer = 0.0
	actor.dash_velocity = Vector2.ZERO
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var bullfrog_idle_state: Dictionary = actor.get_render_motion_state()
	var bullfrog_idle_clear: bool = not bool(bullfrog_idle_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(bullfrog_idle_state.get("rooted_pose", false)) \
		and not bool(bullfrog_idle_state.get("chorus_hop_pose", false)) \
		and not bool(bullfrog_idle_state.get("cane_squat_hop_pose", false)) \
		and not bool(bullfrog_idle_state.get("bullfrog_coil_pose", false)) \
		and not bool(bullfrog_idle_state.get("bullfrog_lunge_pose", false)) \
		and not bool(bullfrog_idle_state.get("camouflage_eye_cue", false)) \
		and _none_render_flags(bullfrog_idle_state, bullfrog_non_bullfrog_motion_flags) \
		and float(bullfrog_idle_state.get("bullfrog_heavy_hop_intensity", 1.0)) <= 0.001
	if not bullfrog_hop or not bullfrog_camouflage or not bullfrog_lunge or not bullfrog_idle_clear:
		failures.append("bullfrog should expose heavy body-thump hop without rooted, chorus, cane, crawler, swimmer, snake, turtle, duck, mammal, gator, bird, swarm, hover, crustacean, or spider overlap, suppress it during camouflage/lunge, and clear when idle; hop=%s camouflage=%s lunge=%s idle=%s state=%s/%s/%s/%s" % [
			str(bullfrog_hop),
			str(bullfrog_camouflage),
			str(bullfrog_lunge),
			str(bullfrog_idle_clear),
			str(bullfrog_hop_state),
			str(bullfrog_camouflage_state),
			str(bullfrog_lunge_state),
			str(bullfrog_idle_state)
		])
	actor.apply_creature("chorus_frog")
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var chorus_non_chorus_motion_flags: Array[String] = [
		"cane_squat_hop_pose", "bullfrog_heavy_hop_pose", "bullfrog_coil_pose", "bullfrog_lunge_pose",
		"shrew_land_skitter_pose", "surface_walk", "submerged_shrew_pose", "slick_crawl_pose", "newt_swim_pose",
		"leech_inchworm_pose", "leech_undulate_pose", "water_snake_land_slither_pose", "water_slither_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"duck_waddle_pose", "duck_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "otter_land_slide_pose", "otter_swim_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "spider_skitter_pose", "high_walk_pose",
		"alligator_water_cruise_pose", "owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose",
		"wading_pose", "heron_stalk_pose", "mosquito_swarm_pose", "firefly_hover_pose"
	]
	var chorus_hop_state: Dictionary = actor.get_render_motion_state()
	var chorus_hop: bool = bool(chorus_hop_state.get("chorus_hop_pose", false)) \
		and float(chorus_hop_state.get("chorus_hop_intensity", 0.0)) > 0.25 \
		and not bool(chorus_hop_state.get("rooted_pose", false)) \
		and not bool(chorus_hop_state.get("cane_squat_hop_pose", false)) \
		and not bool(chorus_hop_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(chorus_hop_state.get("bullfrog_coil_pose", false)) \
		and not bool(chorus_hop_state.get("bullfrog_lunge_pose", false)) \
		and _none_render_flags(chorus_hop_state, chorus_non_chorus_motion_flags)
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var chorus_idle_state: Dictionary = actor.get_render_motion_state()
	var chorus_idle_clear: bool = not bool(chorus_idle_state.get("chorus_hop_pose", false)) \
		and not bool(chorus_idle_state.get("rooted_pose", false)) \
		and not bool(chorus_idle_state.get("cane_squat_hop_pose", false)) \
		and not bool(chorus_idle_state.get("bullfrog_heavy_hop_pose", false)) \
		and not bool(chorus_idle_state.get("bullfrog_coil_pose", false)) \
		and not bool(chorus_idle_state.get("bullfrog_lunge_pose", false)) \
		and _none_render_flags(chorus_idle_state, chorus_non_chorus_motion_flags) \
		and float(chorus_idle_state.get("chorus_hop_intensity", 1.0)) <= 0.001
	if not chorus_hop or not chorus_idle_clear:
		failures.append("moving chorus frog should expose rhythmic vocal hop without rooted, cane, bullfrog, crawler, swimmer, snake, turtle, duck, mammal, gator, bird, swarm, hover, crustacean, or spider overlap and clear when idle; moving=%s idle=%s state=%s/%s" % [
			str(chorus_hop),
			str(chorus_idle_clear),
			str(chorus_hop_state),
			str(chorus_idle_state)
		])
	actor.apply_creature("water_shrew")
	actor.current_environment_profile = {"surface": "water"}
	actor.add_modifier("Water Walk", {"water_walk": 2.0}, 1.0)
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var shrew_non_shrew_motion_flags: Array[String] = [
		"chorus_hop_pose", "cane_squat_hop_pose", "bullfrog_heavy_hop_pose", "bullfrog_coil_pose", "bullfrog_lunge_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "duck_waddle_pose", "duck_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose",
		"otter_land_slide_pose", "otter_swim_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "high_walk_pose", "alligator_water_cruise_pose", "owl_glide_pose",
		"owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose", "heron_stalk_pose",
		"mosquito_swarm_pose", "firefly_hover_pose"
	]
	var shrew_skim_state: Dictionary = actor.get_render_motion_state()
	var shrew_skim: bool = bool(shrew_skim_state.get("surface_walk", false)) \
		and not bool(shrew_skim_state.get("submerged_shrew_pose", false)) \
		and not bool(shrew_skim_state.get("shrew_land_skitter_pose", false)) \
		and not bool(shrew_skim_state.get("newt_swim_pose", false)) \
		and not bool(shrew_skim_state.get("leech_undulate_pose", false)) \
		and not bool(shrew_skim_state.get("water_slither_pose", false)) \
		and not bool(shrew_skim_state.get("turtle_swim_pose", false)) \
		and not bool(shrew_skim_state.get("duck_paddle_pose", false)) \
		and not bool(shrew_skim_state.get("beaver_swim_pose", false)) \
		and not bool(shrew_skim_state.get("mink_swim_pose", false)) \
		and not bool(shrew_skim_state.get("otter_swim_pose", false)) \
		and not bool(shrew_skim_state.get("crayfish_tail_flick_swim_pose", false)) \
		and _none_render_flags(shrew_skim_state, shrew_non_shrew_motion_flags) \
		and float(shrew_skim_state.get("surface_wake_intensity", 0.0)) > 0.25
	actor.remove_modifiers_from_source("Water Walk")
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var shrew_submerged_state: Dictionary = actor.get_render_motion_state()
	var shrew_submerged: bool = bool(shrew_submerged_state.get("submerged_shrew_pose", false)) \
		and not bool(shrew_submerged_state.get("surface_walk", false)) \
		and not bool(shrew_submerged_state.get("shrew_land_skitter_pose", false)) \
		and not bool(shrew_submerged_state.get("newt_swim_pose", false)) \
		and not bool(shrew_submerged_state.get("leech_undulate_pose", false)) \
		and not bool(shrew_submerged_state.get("water_slither_pose", false)) \
		and not bool(shrew_submerged_state.get("turtle_swim_pose", false)) \
		and not bool(shrew_submerged_state.get("duck_paddle_pose", false)) \
		and not bool(shrew_submerged_state.get("beaver_swim_pose", false)) \
		and not bool(shrew_submerged_state.get("mink_swim_pose", false)) \
		and not bool(shrew_submerged_state.get("otter_swim_pose", false)) \
		and not bool(shrew_submerged_state.get("crayfish_tail_flick_swim_pose", false)) \
		and _none_render_flags(shrew_submerged_state, shrew_non_shrew_motion_flags) \
		and float(shrew_submerged_state.get("submerged_shrew_intensity", 0.0)) > 0.25
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var shrew_land_state: Dictionary = actor.get_render_motion_state()
	var shrew_land_skitter: bool = bool(shrew_land_state.get("shrew_land_skitter_pose", false)) \
		and not bool(shrew_land_state.get("surface_walk", false)) \
		and not bool(shrew_land_state.get("submerged_shrew_pose", false)) \
		and not bool(shrew_land_state.get("slick_crawl_pose", false)) \
		and not bool(shrew_land_state.get("leech_inchworm_pose", false)) \
		and not bool(shrew_land_state.get("water_snake_land_slither_pose", false)) \
		and not bool(shrew_land_state.get("turtle_plod_pose", false)) \
		and not bool(shrew_land_state.get("duck_waddle_pose", false)) \
		and not bool(shrew_land_state.get("beaver_lumber_pose", false)) \
		and not bool(shrew_land_state.get("mink_bound_pose", false)) \
		and not bool(shrew_land_state.get("otter_land_slide_pose", false)) \
		and not bool(shrew_land_state.get("crayfish_scuttle_pose", false)) \
		and _none_render_flags(shrew_land_state, shrew_non_shrew_motion_flags) \
		and float(shrew_land_state.get("shrew_land_skitter_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var shrew_idle_state: Dictionary = actor.get_render_motion_state()
	var shrew_idle_clear: bool = not bool(shrew_idle_state.get("surface_walk", false)) \
		and not bool(shrew_idle_state.get("submerged_shrew_pose", false)) \
		and not bool(shrew_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(shrew_idle_state.get("newt_swim_pose", false)) \
		and not bool(shrew_idle_state.get("slick_crawl_pose", false)) \
		and not bool(shrew_idle_state.get("leech_undulate_pose", false)) \
		and not bool(shrew_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(shrew_idle_state.get("water_slither_pose", false)) \
		and not bool(shrew_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(shrew_idle_state.get("beaver_swim_pose", false)) \
		and not bool(shrew_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(shrew_idle_state.get("mink_swim_pose", false)) \
		and not bool(shrew_idle_state.get("mink_bound_pose", false)) \
		and not bool(shrew_idle_state.get("otter_swim_pose", false)) \
		and not bool(shrew_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(shrew_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(shrew_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and _none_render_flags(shrew_idle_state, shrew_non_shrew_motion_flags) \
		and float(shrew_idle_state.get("shrew_land_skitter_intensity", 1.0)) <= 0.001
	if not shrew_skim or not shrew_submerged or not shrew_land_skitter or not shrew_idle_clear:
		failures.append("water shrew should expose tiny surface skim, submerged swim, and land skitter without frog, low swimmer, crawler, snake, turtle, duck, mammal, gator, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; skim=%s submerged=%s land=%s idle=%s state=%s/%s/%s/%s" % [
			str(shrew_skim),
			str(shrew_submerged),
			str(shrew_land_skitter),
			str(shrew_idle_clear),
			str(shrew_skim_state),
			str(shrew_submerged_state),
			str(shrew_land_state),
			str(shrew_idle_state)
		])
	actor.apply_creature("newt")
	var newt_non_newt_motion_flags: Array[String] = [
		"leech_inchworm_pose",
		"leech_undulate_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"crayfish_scuttle_pose",
		"crayfish_tail_flick_swim_pose",
		"shrew_land_skitter_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"turtle_plod_pose",
		"turtle_swim_pose",
		"duck_waddle_pose",
		"duck_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"high_walk_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"mosquito_swarm_pose",
		"firefly_hover_pose",
		"spider_skitter_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var newt_land_state: Dictionary = actor.get_render_motion_state()
	var newt_crawl: bool = bool(newt_land_state.get("slick_crawl_pose", false)) \
		and not bool(newt_land_state.get("newt_swim_pose", false)) \
		and _none_render_flags(newt_land_state, newt_non_newt_motion_flags) \
		and float(newt_land_state.get("slick_crawl_intensity", 0.0)) > 0.25 \
		and float(newt_land_state.get("newt_swim_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	actor.kit.tail_lost_timer = 1.0
	var newt_water_state: Dictionary = actor.get_render_motion_state()
	var newt_swim: bool = bool(newt_water_state.get("newt_swim_pose", false)) \
		and not bool(newt_water_state.get("slick_crawl_pose", false)) \
		and _none_render_flags(newt_water_state, newt_non_newt_motion_flags) \
		and float(newt_water_state.get("newt_swim_intensity", 0.0)) > 0.25 \
		and float(newt_water_state.get("slick_crawl_intensity", 1.0)) <= 0.001 \
		and bool(newt_water_state.get("tail_lost_pose", false))
	actor.kit.tail_lost_timer = 0.0
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var newt_idle_state: Dictionary = actor.get_render_motion_state()
	var newt_idle_clear: bool = not bool(newt_idle_state.get("slick_crawl_pose", false)) \
		and not bool(newt_idle_state.get("newt_swim_pose", false)) \
		and _none_render_flags(newt_idle_state, newt_non_newt_motion_flags) \
		and float(newt_idle_state.get("slick_crawl_intensity", 1.0)) <= 0.001 \
		and float(newt_idle_state.get("newt_swim_intensity", 1.0)) <= 0.001 \
		and not bool(newt_idle_state.get("tail_lost_pose", false))
	if not newt_crawl or not newt_swim or not newt_idle_clear:
		failures.append("moving newt should expose slick land crawl and tail-led water undulation without frog, leech, snake, crayfish, turtle, duck, mammal, shrew, gator, bird, swarm, hover, or spider overlap, preserve tail-loss read, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(newt_crawl),
			str(newt_swim),
			str(newt_idle_clear),
			str(newt_land_state),
			str(newt_water_state),
			str(newt_idle_state)
		])
	actor.apply_creature("water_snake")
	var snake_non_snake_motion_flags: Array[String] = [
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "duck_waddle_pose", "duck_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose",
		"otter_land_slide_pose", "otter_swim_pose", "surface_walk", "submerged_shrew_pose",
		"shrew_land_skitter_pose", "high_walk_pose", "alligator_water_cruise_pose",
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose",
		"heron_stalk_pose", "mosquito_swarm_pose", "firefly_hover_pose", "spider_skitter_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var snake_land_state: Dictionary = actor.get_render_motion_state()
	var snake_land: bool = bool(snake_land_state.get("water_snake_land_slither_pose", false)) \
		and not bool(snake_land_state.get("water_slither_pose", false)) \
		and not bool(snake_land_state.get("water_snake_mud_slither", false)) \
		and not bool(snake_land_state.get("slick_crawl_pose", false)) \
		and not bool(snake_land_state.get("leech_inchworm_pose", false)) \
		and not bool(snake_land_state.get("crayfish_scuttle_pose", false)) \
		and not bool(snake_land_state.get("bog_turtle_creep_pose", false)) \
		and not bool(snake_land_state.get("turtle_plod_pose", false)) \
		and not bool(snake_land_state.get("duck_waddle_pose", false)) \
		and not bool(snake_land_state.get("beaver_lumber_pose", false)) \
		and not bool(snake_land_state.get("mink_bound_pose", false)) \
		and not bool(snake_land_state.get("otter_land_slide_pose", false)) \
		and _none_render_flags(snake_land_state, snake_non_snake_motion_flags) \
		and float(snake_land_state.get("water_snake_land_slither_intensity", 0.0)) > 0.25 \
		and float(snake_land_state.get("water_slither_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "mud"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var snake_mud_state: Dictionary = actor.get_render_motion_state()
	var snake_mud: bool = bool(snake_mud_state.get("water_snake_land_slither_pose", false)) \
		and bool(snake_mud_state.get("water_snake_mud_slither", false)) \
		and not bool(snake_mud_state.get("water_slither_pose", false)) \
		and not bool(snake_mud_state.get("slick_crawl_pose", false)) \
		and not bool(snake_mud_state.get("leech_inchworm_pose", false)) \
		and not bool(snake_mud_state.get("crayfish_scuttle_pose", false)) \
		and not bool(snake_mud_state.get("bog_turtle_creep_pose", false)) \
		and not bool(snake_mud_state.get("turtle_plod_pose", false)) \
		and not bool(snake_mud_state.get("duck_waddle_pose", false)) \
		and not bool(snake_mud_state.get("beaver_lumber_pose", false)) \
		and not bool(snake_mud_state.get("mink_bound_pose", false)) \
		and not bool(snake_mud_state.get("otter_land_slide_pose", false)) \
		and _none_render_flags(snake_mud_state, snake_non_snake_motion_flags) \
		and float(snake_mud_state.get("water_snake_land_slither_intensity", 0.0)) > 0.25 \
		and float(snake_mud_state.get("water_slither_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var snake_water_state: Dictionary = actor.get_render_motion_state()
	var snake_water: bool = bool(snake_water_state.get("water_slither_pose", false)) \
		and not bool(snake_water_state.get("water_snake_land_slither_pose", false)) \
		and not bool(snake_water_state.get("water_snake_mud_slither", false)) \
		and not bool(snake_water_state.get("newt_swim_pose", false)) \
		and not bool(snake_water_state.get("leech_undulate_pose", false)) \
		and not bool(snake_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(snake_water_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(snake_water_state.get("turtle_swim_pose", false)) \
		and not bool(snake_water_state.get("duck_paddle_pose", false)) \
		and not bool(snake_water_state.get("beaver_swim_pose", false)) \
		and not bool(snake_water_state.get("mink_swim_pose", false)) \
		and not bool(snake_water_state.get("otter_swim_pose", false)) \
		and _none_render_flags(snake_water_state, snake_non_snake_motion_flags) \
		and float(snake_water_state.get("water_slither_intensity", 0.0)) > 0.25 \
		and float(snake_water_state.get("water_snake_land_slither_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var snake_idle_state: Dictionary = actor.get_render_motion_state()
	var snake_idle_clear: bool = not bool(snake_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(snake_idle_state.get("water_slither_pose", false)) \
		and not bool(snake_idle_state.get("water_snake_mud_slither", false)) \
		and not bool(snake_idle_state.get("slick_crawl_pose", false)) \
		and not bool(snake_idle_state.get("newt_swim_pose", false)) \
		and not bool(snake_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(snake_idle_state.get("leech_undulate_pose", false)) \
		and not bool(snake_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(snake_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(snake_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(snake_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(snake_idle_state.get("turtle_plod_pose", false)) \
		and not bool(snake_idle_state.get("turtle_swim_pose", false)) \
		and not bool(snake_idle_state.get("duck_waddle_pose", false)) \
		and not bool(snake_idle_state.get("duck_paddle_pose", false)) \
		and not bool(snake_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(snake_idle_state.get("beaver_swim_pose", false)) \
		and not bool(snake_idle_state.get("mink_bound_pose", false)) \
		and not bool(snake_idle_state.get("mink_swim_pose", false)) \
		and not bool(snake_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(snake_idle_state.get("otter_swim_pose", false)) \
		and _none_render_flags(snake_idle_state, snake_non_snake_motion_flags) \
		and float(snake_idle_state.get("water_snake_land_slither_intensity", 1.0)) <= 0.001 \
		and float(snake_idle_state.get("water_slither_intensity", 1.0)) <= 0.001
	if not snake_land or not snake_mud or not snake_water or not snake_idle_clear:
		failures.append("moving water snake should expose dry belly-track slither, muddy scuff, and S-ripple water wake without frog, crawler, turtle, bird, mammal, shrew, gator, swarm, hover, spider, or crustacean overlap, then clear when idle; land=%s mud=%s water=%s idle=%s state=%s/%s/%s/%s" % [
			str(snake_land),
			str(snake_mud),
			str(snake_water),
			str(snake_idle_clear),
			str(snake_land_state),
			str(snake_mud_state),
			str(snake_water_state),
			str(snake_idle_state)
		])
	actor.apply_creature("snapping_turtle")
	var turtle_non_turtle_motion_flags: Array[String] = [
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"duck_waddle_pose",
		"duck_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"shrew_land_skitter_pose",
		"slick_crawl_pose",
		"newt_swim_pose",
		"leech_inchworm_pose",
		"leech_undulate_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"crayfish_scuttle_pose",
		"crayfish_tail_flick_swim_pose",
		"high_walk_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"mosquito_swarm_pose",
		"firefly_hover_pose",
		"spider_skitter_pose"
	]
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var turtle_water_state: Dictionary = actor.get_render_motion_state()
	var turtle_swim: bool = bool(turtle_water_state.get("turtle_swim_pose", false)) \
		and not bool(turtle_water_state.get("turtle_plod_pose", false)) \
		and _none_render_flags(turtle_water_state, turtle_non_turtle_motion_flags) \
		and float(turtle_water_state.get("turtle_swim_intensity", 0.0)) > 0.25 \
		and float(turtle_water_state.get("turtle_plod_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var turtle_idle_state: Dictionary = actor.get_render_motion_state()
	var turtle_idle_clear: bool = not bool(turtle_idle_state.get("turtle_swim_pose", false)) \
		and not bool(turtle_idle_state.get("turtle_plod_pose", false)) \
		and _none_render_flags(turtle_idle_state, turtle_non_turtle_motion_flags) \
		and float(turtle_idle_state.get("turtle_swim_intensity", 1.0)) <= 0.001 \
		and float(turtle_idle_state.get("turtle_plod_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var turtle_land_state: Dictionary = actor.get_render_motion_state()
	var turtle_plod: bool = bool(turtle_land_state.get("turtle_plod_pose", false)) \
		and not bool(turtle_land_state.get("turtle_swim_pose", false)) \
		and _none_render_flags(turtle_land_state, turtle_non_turtle_motion_flags) \
		and float(turtle_land_state.get("turtle_plod_intensity", 0.0)) > 0.25 \
		and float(turtle_land_state.get("turtle_swim_intensity", 1.0)) <= 0.001
	if not turtle_swim or not turtle_idle_clear or not turtle_plod:
		failures.append("moving snapping turtle should expose heavy-shell water paddle and land plod without tiny turtle, duck, mammal, shrew, newt, leech, snake, gator, frog, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; water=%s idle=%s land=%s state=%s/%s/%s" % [
			str(turtle_swim),
			str(turtle_idle_clear),
			str(turtle_plod),
			str(turtle_water_state),
			str(turtle_idle_state),
			str(turtle_land_state)
		])
	actor.apply_creature("bog_turtle")
	var bog_non_bog_motion_flags: Array[String] = [
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose",
		"turtle_plod_pose", "turtle_swim_pose", "duck_waddle_pose", "duck_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose",
		"otter_land_slide_pose", "otter_swim_pose", "surface_walk", "submerged_shrew_pose",
		"shrew_land_skitter_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "high_walk_pose", "alligator_water_cruise_pose",
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose",
		"heron_stalk_pose", "mosquito_swarm_pose", "firefly_hover_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var bog_creep_state: Dictionary = actor.get_render_motion_state()
	var bog_creep: bool = bool(bog_creep_state.get("bog_turtle_creep_pose", false)) \
		and not bool(bog_creep_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(bog_creep_state.get("turtle_plod_pose", false)) \
		and not bool(bog_creep_state.get("turtle_swim_pose", false)) \
		and not bool(bog_creep_state.get("duck_waddle_pose", false)) \
		and not bool(bog_creep_state.get("beaver_lumber_pose", false)) \
		and not bool(bog_creep_state.get("mink_bound_pose", false)) \
		and not bool(bog_creep_state.get("otter_land_slide_pose", false)) \
		and not bool(bog_creep_state.get("crayfish_scuttle_pose", false)) \
		and not bool(bog_creep_state.get("shrew_land_skitter_pose", false)) \
		and not bool(bog_creep_state.get("leech_inchworm_pose", false)) \
		and not bool(bog_creep_state.get("slick_crawl_pose", false)) \
		and not bool(bog_creep_state.get("water_snake_land_slither_pose", false)) \
		and _none_render_flags(bog_creep_state, bog_non_bog_motion_flags) \
		and float(bog_creep_state.get("bog_turtle_creep_intensity", 0.0)) > 0.25
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var bog_paddle_state: Dictionary = actor.get_render_motion_state()
	var bog_paddle: bool = bool(bog_paddle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(bog_paddle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(bog_paddle_state.get("turtle_plod_pose", false)) \
		and not bool(bog_paddle_state.get("turtle_swim_pose", false)) \
		and not bool(bog_paddle_state.get("duck_paddle_pose", false)) \
		and not bool(bog_paddle_state.get("beaver_swim_pose", false)) \
		and not bool(bog_paddle_state.get("mink_swim_pose", false)) \
		and not bool(bog_paddle_state.get("otter_swim_pose", false)) \
		and not bool(bog_paddle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(bog_paddle_state.get("newt_swim_pose", false)) \
		and not bool(bog_paddle_state.get("leech_undulate_pose", false)) \
		and not bool(bog_paddle_state.get("water_slither_pose", false)) \
		and _none_render_flags(bog_paddle_state, bog_non_bog_motion_flags) \
		and float(bog_paddle_state.get("bog_turtle_paddle_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var bog_idle_state: Dictionary = actor.get_render_motion_state()
	var bog_idle_clear: bool = not bool(bog_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(bog_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(bog_idle_state.get("turtle_plod_pose", false)) \
		and not bool(bog_idle_state.get("turtle_swim_pose", false)) \
		and not bool(bog_idle_state.get("duck_paddle_pose", false)) \
		and not bool(bog_idle_state.get("duck_waddle_pose", false)) \
		and not bool(bog_idle_state.get("beaver_swim_pose", false)) \
		and not bool(bog_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(bog_idle_state.get("mink_swim_pose", false)) \
		and not bool(bog_idle_state.get("mink_bound_pose", false)) \
		and not bool(bog_idle_state.get("otter_swim_pose", false)) \
		and not bool(bog_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(bog_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(bog_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(bog_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(bog_idle_state.get("newt_swim_pose", false)) \
		and not bool(bog_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(bog_idle_state.get("leech_undulate_pose", false)) \
		and not bool(bog_idle_state.get("slick_crawl_pose", false)) \
		and not bool(bog_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(bog_idle_state.get("water_slither_pose", false)) \
		and _none_render_flags(bog_idle_state, bog_non_bog_motion_flags) \
		and float(bog_idle_state.get("bog_turtle_creep_intensity", 1.0)) <= 0.001 \
		and float(bog_idle_state.get("bog_turtle_paddle_intensity", 1.0)) <= 0.001
	if not bog_creep or not bog_paddle or not bog_idle_clear:
		failures.append("moving bog turtle should expose tiny orange-patch creep/paddle without frog, snapping turtle, swimmer, crawler, snake, duck, mammal, shrew, gator, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(bog_creep),
			str(bog_paddle),
			str(bog_idle_clear),
			str(bog_creep_state),
			str(bog_paddle_state),
			str(bog_idle_state)
		])
	actor.apply_creature("mink")
	var mink_non_mink_motion_flags: Array[String] = [
		"mink_choke_pose", "otter_land_slide_pose", "otter_swim_pose", "otter_pack_latch_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "duck_waddle_pose", "duck_paddle_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "spider_skitter_pose",
		"high_walk_pose", "alligator_water_cruise_pose", "hop_pose", "chorus_hop_pose",
		"cane_squat_hop_pose", "rooted_pose", "owl_glide_pose", "owl_silent_flight_pose",
		"kingfisher_dart_pose", "wading_pose", "heron_stalk_pose", "mosquito_swarm_pose",
		"firefly_hover_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var mink_bound_state: Dictionary = actor.get_render_motion_state()
	var mink_bound: bool = bool(mink_bound_state.get("mink_bound_pose", false)) \
		and not bool(mink_bound_state.get("mink_swim_pose", false)) \
		and not bool(mink_bound_state.get("mink_choke_pose", false)) \
		and not bool(mink_bound_state.get("otter_land_slide_pose", false)) \
		and not bool(mink_bound_state.get("otter_swim_pose", false)) \
		and not bool(mink_bound_state.get("beaver_lumber_pose", false)) \
		and not bool(mink_bound_state.get("beaver_swim_pose", false)) \
		and not bool(mink_bound_state.get("duck_waddle_pose", false)) \
		and not bool(mink_bound_state.get("turtle_plod_pose", false)) \
		and not bool(mink_bound_state.get("bog_turtle_creep_pose", false)) \
		and not bool(mink_bound_state.get("water_snake_land_slither_pose", false)) \
		and not bool(mink_bound_state.get("slick_crawl_pose", false)) \
		and not bool(mink_bound_state.get("leech_inchworm_pose", false)) \
		and not bool(mink_bound_state.get("crayfish_scuttle_pose", false)) \
		and not bool(mink_bound_state.get("shrew_land_skitter_pose", false)) \
		and not bool(mink_bound_state.get("high_walk_pose", false)) \
		and _none_render_flags(mink_bound_state, mink_non_mink_motion_flags) \
		and float(mink_bound_state.get("mink_bound_intensity", 0.0)) > 0.25 \
		and float(mink_bound_state.get("mink_swim_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var mink_swim_state: Dictionary = actor.get_render_motion_state()
	var mink_swim: bool = bool(mink_swim_state.get("mink_swim_pose", false)) \
		and not bool(mink_swim_state.get("mink_bound_pose", false)) \
		and not bool(mink_swim_state.get("mink_choke_pose", false)) \
		and not bool(mink_swim_state.get("otter_land_slide_pose", false)) \
		and not bool(mink_swim_state.get("otter_swim_pose", false)) \
		and not bool(mink_swim_state.get("beaver_lumber_pose", false)) \
		and not bool(mink_swim_state.get("beaver_swim_pose", false)) \
		and not bool(mink_swim_state.get("duck_paddle_pose", false)) \
		and not bool(mink_swim_state.get("turtle_swim_pose", false)) \
		and not bool(mink_swim_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(mink_swim_state.get("water_slither_pose", false)) \
		and not bool(mink_swim_state.get("newt_swim_pose", false)) \
		and not bool(mink_swim_state.get("leech_undulate_pose", false)) \
		and not bool(mink_swim_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(mink_swim_state.get("surface_walk", false)) \
		and not bool(mink_swim_state.get("submerged_shrew_pose", false)) \
		and not bool(mink_swim_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(mink_swim_state, mink_non_mink_motion_flags) \
		and float(mink_swim_state.get("mink_swim_intensity", 0.0)) > 0.25 \
		and float(mink_swim_state.get("mink_bound_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var mink_idle_state: Dictionary = actor.get_render_motion_state()
	var mink_idle_clear: bool = not bool(mink_idle_state.get("mink_bound_pose", false)) \
		and not bool(mink_idle_state.get("mink_swim_pose", false)) \
		and not bool(mink_idle_state.get("mink_choke_pose", false)) \
		and not bool(mink_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(mink_idle_state.get("otter_swim_pose", false)) \
		and not bool(mink_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(mink_idle_state.get("beaver_swim_pose", false)) \
		and not bool(mink_idle_state.get("duck_waddle_pose", false)) \
		and not bool(mink_idle_state.get("duck_paddle_pose", false)) \
		and not bool(mink_idle_state.get("turtle_plod_pose", false)) \
		and not bool(mink_idle_state.get("turtle_swim_pose", false)) \
		and not bool(mink_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(mink_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(mink_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(mink_idle_state.get("water_slither_pose", false)) \
		and not bool(mink_idle_state.get("slick_crawl_pose", false)) \
		and not bool(mink_idle_state.get("newt_swim_pose", false)) \
		and not bool(mink_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(mink_idle_state.get("leech_undulate_pose", false)) \
		and not bool(mink_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(mink_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(mink_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(mink_idle_state.get("surface_walk", false)) \
		and not bool(mink_idle_state.get("submerged_shrew_pose", false)) \
		and not bool(mink_idle_state.get("high_walk_pose", false)) \
		and not bool(mink_idle_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(mink_idle_state, mink_non_mink_motion_flags) \
		and float(mink_idle_state.get("mink_bound_intensity", 1.0)) <= 0.001 \
		and float(mink_idle_state.get("mink_swim_intensity", 1.0)) <= 0.001
	if not mink_bound or not mink_swim or not mink_idle_clear:
		failures.append("moving mink should expose small elastic land bound and narrow darting water swim without otter, beaver, duck, crawler, turtle, bird, snake, shrew, gator, frog, swarm, hover, spider, or crustacean overlap, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(mink_bound),
			str(mink_swim),
			str(mink_idle_clear),
			str(mink_bound_state),
			str(mink_swim_state),
			str(mink_idle_state)
		])
	actor.apply_creature("otter")
	var otter_non_otter_motion_flags: Array[String] = [
		"otter_pack_latch_pose", "mink_bound_pose", "mink_swim_pose", "mink_choke_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "duck_waddle_pose", "duck_paddle_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "spider_skitter_pose",
		"high_walk_pose", "alligator_water_cruise_pose", "hop_pose", "chorus_hop_pose",
		"cane_squat_hop_pose", "rooted_pose", "owl_glide_pose", "owl_silent_flight_pose",
		"kingfisher_dart_pose", "wading_pose", "heron_stalk_pose", "mosquito_swarm_pose",
		"firefly_hover_pose"
	]
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var otter_water_state: Dictionary = actor.get_render_motion_state()
	var otter_swim: bool = bool(otter_water_state.get("otter_swim_pose", false)) \
		and not bool(otter_water_state.get("otter_land_slide_pose", false)) \
		and not bool(otter_water_state.get("otter_pack_latch_pose", false)) \
		and not bool(otter_water_state.get("mink_bound_pose", false)) \
		and not bool(otter_water_state.get("mink_swim_pose", false)) \
		and not bool(otter_water_state.get("beaver_lumber_pose", false)) \
		and not bool(otter_water_state.get("beaver_swim_pose", false)) \
		and not bool(otter_water_state.get("duck_paddle_pose", false)) \
		and not bool(otter_water_state.get("turtle_swim_pose", false)) \
		and not bool(otter_water_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(otter_water_state.get("water_slither_pose", false)) \
		and not bool(otter_water_state.get("newt_swim_pose", false)) \
		and not bool(otter_water_state.get("leech_undulate_pose", false)) \
		and not bool(otter_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(otter_water_state.get("surface_walk", false)) \
		and not bool(otter_water_state.get("submerged_shrew_pose", false)) \
		and not bool(otter_water_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(otter_water_state, otter_non_otter_motion_flags) \
		and float(otter_water_state.get("otter_motion_intensity", 0.0)) > 0.25
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var otter_land_state: Dictionary = actor.get_render_motion_state()
	var otter_slide: bool = bool(otter_land_state.get("otter_land_slide_pose", false)) \
		and not bool(otter_land_state.get("otter_swim_pose", false)) \
		and not bool(otter_land_state.get("otter_pack_latch_pose", false)) \
		and not bool(otter_land_state.get("mink_bound_pose", false)) \
		and not bool(otter_land_state.get("mink_swim_pose", false)) \
		and not bool(otter_land_state.get("beaver_lumber_pose", false)) \
		and not bool(otter_land_state.get("beaver_swim_pose", false)) \
		and not bool(otter_land_state.get("duck_waddle_pose", false)) \
		and not bool(otter_land_state.get("turtle_plod_pose", false)) \
		and not bool(otter_land_state.get("bog_turtle_creep_pose", false)) \
		and not bool(otter_land_state.get("water_snake_land_slither_pose", false)) \
		and not bool(otter_land_state.get("slick_crawl_pose", false)) \
		and not bool(otter_land_state.get("leech_inchworm_pose", false)) \
		and not bool(otter_land_state.get("crayfish_scuttle_pose", false)) \
		and not bool(otter_land_state.get("shrew_land_skitter_pose", false)) \
		and not bool(otter_land_state.get("high_walk_pose", false)) \
		and _none_render_flags(otter_land_state, otter_non_otter_motion_flags) \
		and float(otter_land_state.get("otter_motion_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var otter_idle_state: Dictionary = actor.get_render_motion_state()
	var otter_idle_clear: bool = not bool(otter_idle_state.get("otter_swim_pose", false)) \
		and not bool(otter_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(otter_idle_state.get("otter_pack_latch_pose", false)) \
		and not bool(otter_idle_state.get("mink_bound_pose", false)) \
		and not bool(otter_idle_state.get("mink_swim_pose", false)) \
		and not bool(otter_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(otter_idle_state.get("beaver_swim_pose", false)) \
		and not bool(otter_idle_state.get("duck_waddle_pose", false)) \
		and not bool(otter_idle_state.get("duck_paddle_pose", false)) \
		and not bool(otter_idle_state.get("turtle_plod_pose", false)) \
		and not bool(otter_idle_state.get("turtle_swim_pose", false)) \
		and not bool(otter_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(otter_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(otter_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(otter_idle_state.get("water_slither_pose", false)) \
		and not bool(otter_idle_state.get("slick_crawl_pose", false)) \
		and not bool(otter_idle_state.get("newt_swim_pose", false)) \
		and not bool(otter_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(otter_idle_state.get("leech_undulate_pose", false)) \
		and not bool(otter_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(otter_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(otter_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(otter_idle_state.get("surface_walk", false)) \
		and not bool(otter_idle_state.get("submerged_shrew_pose", false)) \
		and not bool(otter_idle_state.get("high_walk_pose", false)) \
		and not bool(otter_idle_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(otter_idle_state, otter_non_otter_motion_flags) \
		and float(otter_idle_state.get("otter_motion_intensity", 1.0)) <= 0.001
	if not otter_swim or not otter_slide or not otter_idle_clear:
		failures.append("moving otter should expose rolling water swim and low belly land slide without mink, beaver, duck, crawler, turtle, bird, snake, shrew, gator, frog, swarm, hover, spider, or crustacean overlap, then clear when idle; swim=%s slide=%s idle=%s state=%s/%s/%s" % [
			str(otter_swim),
			str(otter_slide),
			str(otter_idle_clear),
			str(otter_water_state),
			str(otter_land_state),
			str(otter_idle_state)
		])
	actor.apply_creature("crayfish")
	var crayfish_non_crayfish_motion_flags: Array[String] = [
		"leech_inchworm_pose",
		"leech_undulate_pose",
		"slick_crawl_pose",
		"newt_swim_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"turtle_plod_pose",
		"turtle_swim_pose",
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"duck_waddle_pose",
		"duck_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"shrew_land_skitter_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"mosquito_swarm_pose",
		"firefly_hover_pose",
		"spider_skitter_pose",
		"high_walk_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var crayfish_land_state: Dictionary = actor.get_render_motion_state()
	var crayfish_scuttle: bool = bool(crayfish_land_state.get("crayfish_scuttle_pose", false)) \
		and not bool(crayfish_land_state.get("crayfish_tail_flick_swim_pose", false)) \
		and _none_render_flags(crayfish_land_state, crayfish_non_crayfish_motion_flags) \
		and float(crayfish_land_state.get("crayfish_motion_intensity", 0.0)) > 0.25
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var crayfish_water_state: Dictionary = actor.get_render_motion_state()
	var crayfish_swim: bool = bool(crayfish_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(crayfish_water_state.get("crayfish_scuttle_pose", false)) \
		and _none_render_flags(crayfish_water_state, crayfish_non_crayfish_motion_flags) \
		and float(crayfish_water_state.get("crayfish_motion_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var crayfish_idle_state: Dictionary = actor.get_render_motion_state()
	var crayfish_idle_clear: bool = not bool(crayfish_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(crayfish_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and _none_render_flags(crayfish_idle_state, crayfish_non_crayfish_motion_flags) \
		and float(crayfish_idle_state.get("crayfish_motion_intensity", 1.0)) <= 0.001
	if not crayfish_scuttle or not crayfish_swim or not crayfish_idle_clear:
		failures.append("moving crayfish should expose sideways land scuttle and water tail-flick burst without frog, crawler, swimmer, slider, bird, mammal, shrew, gator, turtle, duck, swarm, hover, spider, or snake overlap, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(crayfish_scuttle),
			str(crayfish_swim),
			str(crayfish_idle_clear),
			str(crayfish_land_state),
			str(crayfish_water_state),
			str(crayfish_idle_state)
		])
	actor.apply_creature("leech")
	var leech_non_leech_motion_flags: Array[String] = [
		"slick_crawl_pose",
		"newt_swim_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"crayfish_scuttle_pose",
		"crayfish_tail_flick_swim_pose",
		"shrew_land_skitter_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"turtle_plod_pose",
		"turtle_swim_pose",
		"duck_waddle_pose",
		"duck_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"high_walk_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"mosquito_swarm_pose",
		"firefly_hover_pose",
		"spider_skitter_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var leech_land_state: Dictionary = actor.get_render_motion_state()
	var leech_inchworm: bool = bool(leech_land_state.get("leech_inchworm_pose", false)) \
		and not bool(leech_land_state.get("leech_undulate_pose", false)) \
		and _none_render_flags(leech_land_state, leech_non_leech_motion_flags) \
		and float(leech_land_state.get("leech_motion_intensity", 0.0)) > 0.25
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var leech_water_state: Dictionary = actor.get_render_motion_state()
	var leech_undulate: bool = bool(leech_water_state.get("leech_undulate_pose", false)) \
		and not bool(leech_water_state.get("leech_inchworm_pose", false)) \
		and _none_render_flags(leech_water_state, leech_non_leech_motion_flags) \
		and float(leech_water_state.get("leech_motion_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var leech_idle_state: Dictionary = actor.get_render_motion_state()
	var leech_idle_clear: bool = not bool(leech_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(leech_idle_state.get("leech_undulate_pose", false)) \
		and _none_render_flags(leech_idle_state, leech_non_leech_motion_flags) \
		and float(leech_idle_state.get("leech_motion_intensity", 1.0)) <= 0.001
	if not leech_inchworm or not leech_undulate or not leech_idle_clear:
		failures.append("moving leech should expose suction inchworm and thin water undulate without frog, crawler, swimmer, turtle, duck, mammal, snake, shrew, gator, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(leech_inchworm),
			str(leech_undulate),
			str(leech_idle_clear),
			str(leech_land_state),
			str(leech_water_state),
			str(leech_idle_state)
		])
	actor.apply_creature("wolf_spider")
	actor.current_environment_profile = {"surface": "land"}
	actor.state = CreatureStateScript.State.NORMAL
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var spider_non_spider_motion_flags: Array[String] = [
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "shrew_land_skitter_pose", "surface_walk",
		"submerged_shrew_pose", "leech_inchworm_pose", "leech_undulate_pose", "slick_crawl_pose", "newt_swim_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "duck_waddle_pose", "duck_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose",
		"otter_land_slide_pose", "otter_swim_pose", "high_walk_pose", "alligator_water_cruise_pose",
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose", "heron_stalk_pose",
		"mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose", "firefly_flash_pose",
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose"
	]
	var spider_skitter_state: Dictionary = actor.get_render_motion_state()
	var spider_skitter: bool = bool(spider_skitter_state.get("spider_skitter_pose", false)) \
		and float(spider_skitter_state.get("spider_skitter_intensity", 0.0)) > 0.25 \
		and not bool(spider_skitter_state.get("spider_lunge_pose", false)) \
		and not bool(spider_skitter_state.get("spider_burrowed_pose", false)) \
		and not bool(spider_skitter_state.get("spider_latch_pose", false)) \
		and not bool(spider_skitter_state.get("crayfish_scuttle_pose", false)) \
		and not bool(spider_skitter_state.get("shrew_land_skitter_pose", false)) \
		and not bool(spider_skitter_state.get("leech_inchworm_pose", false)) \
		and not bool(spider_skitter_state.get("slick_crawl_pose", false)) \
		and not bool(spider_skitter_state.get("water_snake_land_slither_pose", false)) \
		and not bool(spider_skitter_state.get("turtle_plod_pose", false)) \
		and not bool(spider_skitter_state.get("mink_bound_pose", false)) \
		and not bool(spider_skitter_state.get("otter_land_slide_pose", false)) \
		and _none_render_flags(spider_skitter_state, spider_non_spider_motion_flags)
	actor.kit.lunge_active = true
	var spider_lunge_state: Dictionary = actor.get_render_motion_state()
	var spider_lunge_suppresses: bool = bool(spider_lunge_state.get("spider_lunge_pose", false)) \
		and not bool(spider_lunge_state.get("spider_skitter_pose", false)) \
		and not bool(spider_lunge_state.get("crayfish_scuttle_pose", false)) \
		and not bool(spider_lunge_state.get("shrew_land_skitter_pose", false)) \
		and _none_render_flags(spider_lunge_state, spider_non_spider_motion_flags)
	actor.kit.lunge_active = false
	actor.state = CreatureStateScript.State.BURROWED
	var spider_burrow_state: Dictionary = actor.get_render_motion_state()
	var spider_burrow_suppresses: bool = bool(spider_burrow_state.get("spider_burrowed_pose", false)) \
		and not bool(spider_burrow_state.get("spider_skitter_pose", false)) \
		and not bool(spider_burrow_state.get("crayfish_scuttle_pose", false)) \
		and not bool(spider_burrow_state.get("shrew_land_skitter_pose", false)) \
		and _none_render_flags(spider_burrow_state, spider_non_spider_motion_flags)
	actor.state = CreatureStateScript.State.NORMAL
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var spider_idle_state: Dictionary = actor.get_render_motion_state()
	var spider_idle_clear: bool = not bool(spider_idle_state.get("spider_skitter_pose", false)) \
		and not bool(spider_idle_state.get("spider_lunge_pose", false)) \
		and not bool(spider_idle_state.get("spider_burrowed_pose", false)) \
		and not bool(spider_idle_state.get("spider_latch_pose", false)) \
		and not bool(spider_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(spider_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(spider_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(spider_idle_state.get("slick_crawl_pose", false)) \
		and not bool(spider_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(spider_idle_state.get("turtle_plod_pose", false)) \
		and not bool(spider_idle_state.get("mink_bound_pose", false)) \
		and not bool(spider_idle_state.get("otter_land_slide_pose", false)) \
		and _none_render_flags(spider_idle_state, spider_non_spider_motion_flags) \
		and float(spider_idle_state.get("spider_skitter_intensity", 1.0)) <= 0.001
	if not spider_skitter or not spider_lunge_suppresses or not spider_burrow_suppresses or not spider_idle_clear:
		failures.append("wolf spider should expose staccato eight-leg skitter without crayfish, shrew, crawler, swimmer, snake, turtle, duck, mammal, gator, bird, swarm, hover, or frog overlap, suppress it during lunge/burrow, then clear when idle; skitter=%s lunge=%s burrow=%s idle=%s state=%s/%s/%s/%s" % [
			str(spider_skitter),
			str(spider_lunge_suppresses),
			str(spider_burrow_suppresses),
			str(spider_idle_clear),
			str(spider_skitter_state),
			str(spider_lunge_state),
			str(spider_burrow_state),
			str(spider_idle_state)
		])
	actor.apply_creature("alligator")
	actor.add_modifier("Ambush", {"move_speed_mult": 0.7}, 1.0)
	if not bool(actor.get_render_motion_state().get("ambush_pose", false)):
		failures.append("Ambush should expose low ambush render pose")
	actor.remove_modifiers_from_source("Ambush")
	var gator_non_gator_motion_flags: Array[String] = [
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose",
		"leech_inchworm_pose", "leech_undulate_pose", "slick_crawl_pose", "newt_swim_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"duck_waddle_pose", "duck_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "mink_choke_pose", "otter_land_slide_pose", "otter_swim_pose",
		"otter_pack_latch_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose", "spider_skitter_pose",
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose",
		"heron_stalk_pose", "mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose",
		"firefly_flash_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose"
	]
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * 80.0
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var gator_walk_state: Dictionary = actor.get_render_motion_state()
	var gator_walk: bool = bool(gator_walk_state.get("high_walk_pose", false)) \
		and not bool(gator_walk_state.get("ambush_pose", false)) \
		and not bool(gator_walk_state.get("alligator_water_cruise_pose", false)) \
		and not bool(gator_walk_state.get("water_snake_land_slither_pose", false)) \
		and not bool(gator_walk_state.get("water_slither_pose", false)) \
		and not bool(gator_walk_state.get("slick_crawl_pose", false)) \
		and not bool(gator_walk_state.get("bog_turtle_creep_pose", false)) \
		and not bool(gator_walk_state.get("turtle_plod_pose", false)) \
		and not bool(gator_walk_state.get("leech_inchworm_pose", false)) \
		and not bool(gator_walk_state.get("crayfish_scuttle_pose", false)) \
		and not bool(gator_walk_state.get("duck_waddle_pose", false)) \
		and not bool(gator_walk_state.get("beaver_lumber_pose", false)) \
		and not bool(gator_walk_state.get("mink_bound_pose", false)) \
		and not bool(gator_walk_state.get("otter_land_slide_pose", false)) \
		and _none_render_flags(gator_walk_state, gator_non_gator_motion_flags)
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * 80.0
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var gator_water_state: Dictionary = actor.get_render_motion_state()
	var gator_cruise: bool = bool(gator_water_state.get("alligator_water_cruise_pose", false)) \
		and not bool(gator_water_state.get("high_walk_pose", false)) \
		and not bool(gator_water_state.get("ambush_pose", false)) \
		and not bool(gator_water_state.get("water_snake_land_slither_pose", false)) \
		and not bool(gator_water_state.get("water_slither_pose", false)) \
		and not bool(gator_water_state.get("newt_swim_pose", false)) \
		and not bool(gator_water_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(gator_water_state.get("turtle_swim_pose", false)) \
		and not bool(gator_water_state.get("leech_undulate_pose", false)) \
		and not bool(gator_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(gator_water_state.get("duck_paddle_pose", false)) \
		and not bool(gator_water_state.get("beaver_swim_pose", false)) \
		and not bool(gator_water_state.get("mink_swim_pose", false)) \
		and not bool(gator_water_state.get("otter_swim_pose", false)) \
		and _none_render_flags(gator_water_state, gator_non_gator_motion_flags) \
		and float(gator_water_state.get("alligator_water_cruise_intensity", 0.0)) > 0.25
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var gator_idle_state: Dictionary = actor.get_render_motion_state()
	var gator_idle_clear: bool = not bool(gator_idle_state.get("alligator_water_cruise_pose", false)) \
		and not bool(gator_idle_state.get("high_walk_pose", false)) \
		and not bool(gator_idle_state.get("ambush_pose", false)) \
		and not bool(gator_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(gator_idle_state.get("water_slither_pose", false)) \
		and not bool(gator_idle_state.get("slick_crawl_pose", false)) \
		and not bool(gator_idle_state.get("newt_swim_pose", false)) \
		and not bool(gator_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(gator_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(gator_idle_state.get("turtle_plod_pose", false)) \
		and not bool(gator_idle_state.get("turtle_swim_pose", false)) \
		and not bool(gator_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(gator_idle_state.get("leech_undulate_pose", false)) \
		and not bool(gator_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(gator_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(gator_idle_state.get("duck_waddle_pose", false)) \
		and not bool(gator_idle_state.get("duck_paddle_pose", false)) \
		and not bool(gator_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(gator_idle_state.get("beaver_swim_pose", false)) \
		and not bool(gator_idle_state.get("mink_bound_pose", false)) \
		and not bool(gator_idle_state.get("mink_swim_pose", false)) \
		and not bool(gator_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(gator_idle_state.get("otter_swim_pose", false)) \
		and _none_render_flags(gator_idle_state, gator_non_gator_motion_flags) \
		and float(gator_idle_state.get("alligator_water_cruise_intensity", 1.0)) <= 0.001
	if not gator_walk or not gator_cruise or not gator_idle_clear:
		failures.append("moving alligator should expose heavy land high-walk and armored water cruise outside Ambush without frog, crawler, swimmer, snake, turtle, duck, mammal, shrew, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; land=%s water=%s idle=%s state=%s/%s/%s" % [
			str(gator_walk),
			str(gator_cruise),
			str(gator_idle_clear),
			str(gator_walk_state),
			str(gator_water_state),
			str(gator_idle_state)
		])
	actor.apply_creature("owl")
	actor.state = CreatureStateScript.State.PERCHED
	if not bool(actor.get_render_motion_state().get("perched_pose", false)):
		failures.append("perched birds should expose perched render pose")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var owl_non_owl_motion_flags: Array[String] = [
		"kingfisher_dart_pose", "wading_pose", "heron_stalk_pose", "duck_paddle_pose", "duck_waddle_pose",
		"mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose", "firefly_flash_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "mink_choke_pose", "otter_land_slide_pose", "otter_swim_pose",
		"otter_pack_latch_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose",
		"high_walk_pose", "alligator_water_cruise_pose", "hop_pose", "chorus_hop_pose",
		"cane_squat_hop_pose", "rooted_pose"
	]
	var owl_glide_state: Dictionary = actor.get_render_motion_state()
	var owl_glide: bool = bool(owl_glide_state.get("owl_glide_pose", false)) \
		and float(owl_glide_state.get("owl_glide_intensity", 0.0)) > 0.25 \
		and not bool(owl_glide_state.get("owl_silent_flight_pose", false)) \
		and not bool(owl_glide_state.get("kingfisher_dart_pose", false)) \
		and not bool(owl_glide_state.get("wading_pose", false)) \
		and not bool(owl_glide_state.get("heron_stalk_pose", false)) \
		and not bool(owl_glide_state.get("duck_paddle_pose", false)) \
		and not bool(owl_glide_state.get("duck_waddle_pose", false)) \
		and not bool(owl_glide_state.get("mosquito_swarm_pose", false)) \
		and not bool(owl_glide_state.get("firefly_hover_pose", false)) \
		and _none_render_flags(owl_glide_state, owl_non_owl_motion_flags)
	actor.begin_stealth(2.0, "Silent Flight")
	var owl_silent_state: Dictionary = actor.get_render_motion_state()
	var owl_silent: bool = bool(owl_silent_state.get("owl_silent_flight_pose", false)) \
		and bool(owl_silent_state.get("owl_glide_pose", false)) \
		and not bool(owl_silent_state.get("kingfisher_dart_pose", false)) \
		and not bool(owl_silent_state.get("mosquito_swarm_pose", false)) \
		and not bool(owl_silent_state.get("firefly_hover_pose", false)) \
		and _none_render_flags(owl_silent_state, owl_non_owl_motion_flags)
	actor.break_stealth()
	var owl_plain_state: Dictionary = actor.get_render_motion_state()
	var owl_silent_clear: bool = bool(owl_plain_state.get("owl_glide_pose", false)) \
		and not bool(owl_plain_state.get("owl_silent_flight_pose", false)) \
		and not bool(owl_plain_state.get("kingfisher_dart_pose", false)) \
		and not bool(owl_plain_state.get("wading_pose", false)) \
		and not bool(owl_plain_state.get("heron_stalk_pose", false)) \
		and not bool(owl_plain_state.get("duck_paddle_pose", false)) \
		and not bool(owl_plain_state.get("duck_waddle_pose", false)) \
		and not bool(owl_plain_state.get("mosquito_swarm_pose", false)) \
		and not bool(owl_plain_state.get("firefly_hover_pose", false)) \
		and _none_render_flags(owl_plain_state, owl_non_owl_motion_flags) \
		and float(owl_plain_state.get("owl_glide_intensity", 0.0)) > 0.25
	if not owl_glide or not owl_silent or not owl_silent_clear:
		failures.append("airborne owl should expose broad quiet glide and Silent Flight without dart, wade, paddle, swarm, hover, crawler, swimmer, shrew, turtle, mammal, snake, gator, frog, crustacean, or spider overlap, then return to plain glide when stealth breaks; glide=%s silent=%s clear=%s state=%s/%s/%s" % [
			str(owl_glide),
			str(owl_silent),
			str(owl_silent_clear),
			str(owl_glide_state),
			str(owl_silent_state),
			str(owl_plain_state)
		])
	actor.apply_creature("kingfisher")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var kingfisher_non_kingfisher_motion_flags: Array[String] = [
		"owl_glide_pose", "owl_silent_flight_pose", "wading_pose", "heron_stalk_pose", "duck_paddle_pose", "duck_waddle_pose",
		"mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose", "firefly_flash_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "mink_choke_pose", "otter_land_slide_pose", "otter_swim_pose",
		"otter_pack_latch_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose",
		"high_walk_pose", "alligator_water_cruise_pose", "hop_pose", "chorus_hop_pose",
		"cane_squat_hop_pose", "rooted_pose"
	]
	var kingfisher_dart_state: Dictionary = actor.get_render_motion_state()
	var kingfisher_dart: bool = bool(kingfisher_dart_state.get("kingfisher_dart_pose", false)) \
		and float(kingfisher_dart_state.get("kingfisher_dart_intensity", 0.0)) > 0.25 \
		and float(kingfisher_dart_state.get("plunge_t", 1.0)) <= 0.001 \
		and not bool(kingfisher_dart_state.get("owl_glide_pose", false)) \
		and not bool(kingfisher_dart_state.get("owl_silent_flight_pose", false)) \
		and not bool(kingfisher_dart_state.get("wading_pose", false)) \
		and not bool(kingfisher_dart_state.get("heron_stalk_pose", false)) \
		and not bool(kingfisher_dart_state.get("duck_paddle_pose", false)) \
		and not bool(kingfisher_dart_state.get("duck_waddle_pose", false)) \
		and not bool(kingfisher_dart_state.get("mosquito_swarm_pose", false)) \
		and not bool(kingfisher_dart_state.get("mosquito_trail_pose", false)) \
		and not bool(kingfisher_dart_state.get("firefly_hover_pose", false)) \
		and not bool(kingfisher_dart_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(kingfisher_dart_state, kingfisher_non_kingfisher_motion_flags)
	actor.begin_render_plunge()
	var kingfisher_plunge_state: Dictionary = actor.get_render_motion_state()
	var kingfisher_plunge_suppresses_dart: bool = float(kingfisher_plunge_state.get("plunge_t", 0.0)) > 0.5 \
		and not bool(kingfisher_plunge_state.get("kingfisher_dart_pose", false)) \
		and not bool(kingfisher_plunge_state.get("owl_glide_pose", false)) \
		and not bool(kingfisher_plunge_state.get("owl_silent_flight_pose", false)) \
		and not bool(kingfisher_plunge_state.get("mosquito_swarm_pose", false)) \
		and not bool(kingfisher_plunge_state.get("mosquito_trail_pose", false)) \
		and not bool(kingfisher_plunge_state.get("firefly_hover_pose", false)) \
		and not bool(kingfisher_plunge_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(kingfisher_plunge_state, kingfisher_non_kingfisher_motion_flags) \
		and float(kingfisher_plunge_state.get("kingfisher_dart_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	actor.render_plunge_timer = 0.0
	var kingfisher_idle_state: Dictionary = actor.get_render_motion_state()
	var kingfisher_idle_clear: bool = not bool(kingfisher_idle_state.get("kingfisher_dart_pose", false)) \
		and not bool(kingfisher_idle_state.get("owl_glide_pose", false)) \
		and not bool(kingfisher_idle_state.get("owl_silent_flight_pose", false)) \
		and not bool(kingfisher_idle_state.get("wading_pose", false)) \
		and not bool(kingfisher_idle_state.get("heron_stalk_pose", false)) \
		and not bool(kingfisher_idle_state.get("duck_paddle_pose", false)) \
		and not bool(kingfisher_idle_state.get("duck_waddle_pose", false)) \
		and not bool(kingfisher_idle_state.get("mosquito_swarm_pose", false)) \
		and not bool(kingfisher_idle_state.get("mosquito_trail_pose", false)) \
		and not bool(kingfisher_idle_state.get("firefly_hover_pose", false)) \
		and not bool(kingfisher_idle_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(kingfisher_idle_state, kingfisher_non_kingfisher_motion_flags) \
		and float(kingfisher_idle_state.get("kingfisher_dart_intensity", 1.0)) <= 0.001
	if not kingfisher_dart or not kingfisher_plunge_suppresses_dart or not kingfisher_idle_clear:
		failures.append("airborne kingfisher should expose sharp dart flight without owl, wade, paddle, swarm, hover, crawler, swimmer, shrew, turtle, mammal, snake, gator, frog, crustacean, or spider overlap, suppress it during plunge, then clear when idle; dart=%s plunge=%s idle=%s state=%s/%s/%s" % [
			str(kingfisher_dart),
			str(kingfisher_plunge_suppresses_dart),
			str(kingfisher_idle_clear),
			str(kingfisher_dart_state),
			str(kingfisher_plunge_state),
			str(kingfisher_idle_state)
		])
	actor.apply_creature("great_blue_heron")
	actor.state = CreatureStateScript.State.NORMAL
	var heron_non_heron_motion_flags: Array[String] = [
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "duck_paddle_pose", "duck_waddle_pose",
		"mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose", "firefly_flash_pose",
		"surface_walk", "submerged_shrew_pose", "shrew_land_skitter_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "beaver_lumber_pose", "beaver_swim_pose",
		"mink_bound_pose", "mink_swim_pose", "mink_choke_pose", "otter_land_slide_pose", "otter_swim_pose",
		"otter_pack_latch_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose",
		"high_walk_pose", "alligator_water_cruise_pose", "hop_pose", "chorus_hop_pose",
		"cane_squat_hop_pose", "rooted_pose"
	]
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var heron_water_state: Dictionary = actor.get_render_motion_state()
	var heron_wade: bool = bool(heron_water_state.get("wading_pose", false)) \
		and not bool(heron_water_state.get("heron_stalk_pose", false)) \
		and not bool(heron_water_state.get("duck_paddle_pose", false)) \
		and not bool(heron_water_state.get("duck_waddle_pose", false)) \
		and not bool(heron_water_state.get("owl_glide_pose", false)) \
		and not bool(heron_water_state.get("owl_silent_flight_pose", false)) \
		and not bool(heron_water_state.get("kingfisher_dart_pose", false)) \
		and not bool(heron_water_state.get("mosquito_swarm_pose", false)) \
		and not bool(heron_water_state.get("mosquito_trail_pose", false)) \
		and not bool(heron_water_state.get("firefly_hover_pose", false)) \
		and not bool(heron_water_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(heron_water_state, heron_non_heron_motion_flags) \
		and float(heron_water_state.get("wading_stride", 0.0)) > 0.25 \
		and float(heron_water_state.get("heron_stalk_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	var heron_land_state: Dictionary = actor.get_render_motion_state()
	var heron_stalk: bool = bool(heron_land_state.get("heron_stalk_pose", false)) \
		and not bool(heron_land_state.get("wading_pose", false)) \
		and not bool(heron_land_state.get("duck_waddle_pose", false)) \
		and not bool(heron_land_state.get("duck_paddle_pose", false)) \
		and not bool(heron_land_state.get("owl_glide_pose", false)) \
		and not bool(heron_land_state.get("owl_silent_flight_pose", false)) \
		and not bool(heron_land_state.get("kingfisher_dart_pose", false)) \
		and not bool(heron_land_state.get("mosquito_swarm_pose", false)) \
		and not bool(heron_land_state.get("mosquito_trail_pose", false)) \
		and not bool(heron_land_state.get("firefly_hover_pose", false)) \
		and not bool(heron_land_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(heron_land_state, heron_non_heron_motion_flags) \
		and float(heron_land_state.get("heron_stalk_intensity", 0.0)) > 0.25 \
		and float(heron_land_state.get("wading_stride", 1.0)) <= 0.001
	actor.state = CreatureStateScript.State.PERCHED
	var heron_perched_state: Dictionary = actor.get_render_motion_state()
	var heron_perch_suppresses: bool = bool(heron_perched_state.get("perched_pose", false)) \
		and not bool(heron_perched_state.get("heron_stalk_pose", false)) \
		and not bool(heron_perched_state.get("wading_pose", false)) \
		and not bool(heron_perched_state.get("duck_paddle_pose", false)) \
		and not bool(heron_perched_state.get("duck_waddle_pose", false)) \
		and not bool(heron_perched_state.get("owl_glide_pose", false)) \
		and not bool(heron_perched_state.get("kingfisher_dart_pose", false)) \
		and not bool(heron_perched_state.get("mosquito_swarm_pose", false)) \
		and not bool(heron_perched_state.get("mosquito_trail_pose", false)) \
		and not bool(heron_perched_state.get("firefly_hover_pose", false)) \
		and not bool(heron_perched_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(heron_perched_state, heron_non_heron_motion_flags)
	if not heron_wade or not heron_stalk or not heron_perch_suppresses:
		failures.append("great blue heron should expose tall water wading and careful land stalking without duck, owl, kingfisher, swarm, hover, crawler, swimmer, shrew, turtle, mammal, snake, gator, frog, crustacean, or spider overlap, then suppress both when perched; water=%s land=%s perched=%s state=%s/%s/%s" % [
			str(heron_wade),
			str(heron_stalk),
			str(heron_perch_suppresses),
			str(heron_water_state),
			str(heron_land_state),
			str(heron_perched_state)
		])
	actor.apply_creature("mosquito_swarm")
	var mosquito_non_mosquito_motion_flags: Array[String] = [
		"firefly_hover_pose",
		"firefly_flash_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"duck_paddle_pose",
		"duck_waddle_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"shrew_land_skitter_pose",
		"slick_crawl_pose",
		"newt_swim_pose",
		"leech_inchworm_pose",
		"leech_undulate_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"turtle_plod_pose",
		"turtle_swim_pose",
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"crayfish_scuttle_pose",
		"crayfish_tail_flick_swim_pose",
		"spider_skitter_pose",
		"high_walk_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose"
	]
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	actor.secondary_resource = actor.secondary_resource_max * 0.5
	actor.kit.trail_timer = 1.0
	var mosquito_move_state: Dictionary = actor.get_render_motion_state()
	var mosquito_swarm: bool = bool(mosquito_move_state.get("mosquito_swarm_pose", false)) \
		and float(mosquito_move_state.get("mosquito_swarm_intensity", 0.0)) > 0.25 \
		and bool(mosquito_move_state.get("mosquito_trail_pose", false)) \
		and float(mosquito_move_state.get("mosquito_blood_ratio", 0.0)) > 0.45 \
		and _none_render_flags(mosquito_move_state, mosquito_non_mosquito_motion_flags)
	actor.kit.trail_timer = 0.0
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var mosquito_idle_state: Dictionary = actor.get_render_motion_state()
	var mosquito_idle_clear: bool = not bool(mosquito_idle_state.get("mosquito_swarm_pose", false)) \
		and not bool(mosquito_idle_state.get("mosquito_trail_pose", false)) \
		and _none_render_flags(mosquito_idle_state, mosquito_non_mosquito_motion_flags) \
		and float(mosquito_idle_state.get("mosquito_swarm_intensity", 1.0)) <= 0.001
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	var mosquito_attack_frame := InputFrameScript.new()
	mosquito_attack_frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	mosquito_attack_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(mosquito_attack_frame)
	actor.kit.tick(actor, 0.016)
	var mosquito_attack_read: bool = actor.anim_attack_timer > 0.0 and actor.primary_timer > 0.0
	if not mosquito_swarm or not mosquito_idle_clear or not mosquito_attack_read:
		failures.append("moving mosquito swarm should expose directional swarm-cloud drift, trail, blood ratio, and airborne projectile release animation without firefly, bird, heron, duck, crawler, swimmer, shrew, turtle, mammal, snake, gator, frog, crustacean, or spider overlap, then clear when idle; moving=%s idle=%s attack=%s state=%s/%s" % [
			str(mosquito_swarm),
			str(mosquito_idle_clear),
			str(mosquito_attack_read),
			str(mosquito_move_state),
			str(mosquito_idle_state)
		])
	actor.apply_creature("firefly")
	actor.anim_attack_timer = 0.0
	var firefly_non_firefly_motion_flags: Array[String] = [
		"mosquito_swarm_pose",
		"mosquito_trail_pose",
		"owl_glide_pose",
		"owl_silent_flight_pose",
		"kingfisher_dart_pose",
		"wading_pose",
		"heron_stalk_pose",
		"duck_paddle_pose",
		"duck_waddle_pose",
		"surface_walk",
		"submerged_shrew_pose",
		"shrew_land_skitter_pose",
		"slick_crawl_pose",
		"newt_swim_pose",
		"leech_inchworm_pose",
		"leech_undulate_pose",
		"water_snake_land_slither_pose",
		"water_snake_mud_slither",
		"water_slither_pose",
		"turtle_plod_pose",
		"turtle_swim_pose",
		"bog_turtle_creep_pose",
		"bog_turtle_paddle_pose",
		"beaver_lumber_pose",
		"beaver_swim_pose",
		"mink_bound_pose",
		"mink_swim_pose",
		"mink_choke_pose",
		"otter_land_slide_pose",
		"otter_swim_pose",
		"otter_pack_latch_pose",
		"crayfish_scuttle_pose",
		"crayfish_tail_flick_swim_pose",
		"spider_skitter_pose",
		"high_walk_pose",
		"alligator_water_cruise_pose",
		"hop_pose",
		"chorus_hop_pose",
		"cane_squat_hop_pose",
		"rooted_pose"
	]
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	actor.set_input_frame(_move_frame(Vector2.RIGHT))
	actor.kit.flash_timer = 1.0
	var firefly_hover_state: Dictionary = actor.get_render_motion_state()
	var firefly_hover: bool = bool(firefly_hover_state.get("firefly_hover_pose", false)) \
		and float(firefly_hover_state.get("firefly_hover_intensity", 0.0)) > 0.25 \
		and bool(firefly_hover_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(firefly_hover_state, firefly_non_firefly_motion_flags)
	actor.kit.flash_timer = 0.0
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var firefly_idle_state: Dictionary = actor.get_render_motion_state()
	var firefly_idle_clear: bool = not bool(firefly_idle_state.get("firefly_hover_pose", false)) \
		and float(firefly_idle_state.get("firefly_hover_intensity", 1.0)) <= 0.001 \
		and not bool(firefly_idle_state.get("firefly_flash_pose", false)) \
		and _none_render_flags(firefly_idle_state, firefly_non_firefly_motion_flags)
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	var firefly_attack_frame := InputFrameScript.new()
	firefly_attack_frame.aim = actor.global_position + Vector2.RIGHT * 100.0
	firefly_attack_frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	actor.set_input_frame(firefly_attack_frame)
	actor.kit.tick(actor, 0.016)
	var firefly_attack_read: bool = actor.anim_attack_timer > 0.0 and actor.primary_timer > 0.0
	if not firefly_hover or not firefly_idle_clear or not firefly_attack_read:
		failures.append("moving firefly should expose single-hover lantern drift, flash cues, and airborne spark release animation without mosquito, bird, heron, duck, crawler, swimmer, shrew, turtle, mammal, snake, gator, frog, crustacean, or spider overlap, then clear when idle; moving=%s idle=%s attack=%s state=%s/%s" % [
			str(firefly_hover),
			str(firefly_idle_clear),
			str(firefly_attack_read),
			str(firefly_hover_state),
			str(firefly_idle_state)
		])
	actor.apply_creature("duck")
	var duck_non_duck_motion_flags: Array[String] = [
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose",
		"wading_pose", "heron_stalk_pose", "owl_glide_pose", "owl_silent_flight_pose",
		"kingfisher_dart_pose", "mosquito_swarm_pose", "mosquito_trail_pose",
		"firefly_hover_pose", "firefly_flash_pose",
		"slick_crawl_pose", "newt_swim_pose", "leech_inchworm_pose", "leech_undulate_pose",
		"water_snake_land_slither_pose", "water_snake_mud_slither", "water_slither_pose",
		"turtle_plod_pose", "turtle_swim_pose", "bog_turtle_creep_pose", "bog_turtle_paddle_pose",
		"beaver_lumber_pose", "beaver_swim_pose", "mink_bound_pose", "mink_swim_pose", "mink_choke_pose",
		"otter_land_slide_pose", "otter_swim_pose", "otter_pack_latch_pose", "surface_walk", "submerged_shrew_pose",
		"shrew_land_skitter_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose",
		"high_walk_pose", "alligator_water_cruise_pose"
	]
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var duck_water_state: Dictionary = actor.get_render_motion_state()
	var duck_paddle: bool = bool(duck_water_state.get("duck_paddle_pose", false)) \
		and not bool(duck_water_state.get("duck_waddle_pose", false)) \
		and not bool(duck_water_state.get("wading_pose", false)) \
		and not bool(duck_water_state.get("heron_stalk_pose", false)) \
		and not bool(duck_water_state.get("beaver_swim_pose", false)) \
		and not bool(duck_water_state.get("mink_swim_pose", false)) \
		and not bool(duck_water_state.get("otter_swim_pose", false)) \
		and not bool(duck_water_state.get("turtle_swim_pose", false)) \
		and not bool(duck_water_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(duck_water_state.get("water_slither_pose", false)) \
		and not bool(duck_water_state.get("newt_swim_pose", false)) \
		and not bool(duck_water_state.get("leech_undulate_pose", false)) \
		and not bool(duck_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(duck_water_state.get("surface_walk", false)) \
		and not bool(duck_water_state.get("submerged_shrew_pose", false)) \
		and not bool(duck_water_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(duck_water_state, duck_non_duck_motion_flags) \
		and float(duck_water_state.get("duck_paddle_intensity", 0.0)) > 0.25 \
		and float(duck_water_state.get("duck_waddle_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var duck_idle_state: Dictionary = actor.get_render_motion_state()
	var duck_idle_clear: bool = not bool(duck_idle_state.get("duck_paddle_pose", false)) \
		and not bool(duck_idle_state.get("duck_waddle_pose", false)) \
		and not bool(duck_idle_state.get("wading_pose", false)) \
		and not bool(duck_idle_state.get("heron_stalk_pose", false)) \
		and not bool(duck_idle_state.get("beaver_swim_pose", false)) \
		and not bool(duck_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(duck_idle_state.get("mink_swim_pose", false)) \
		and not bool(duck_idle_state.get("mink_bound_pose", false)) \
		and not bool(duck_idle_state.get("otter_swim_pose", false)) \
		and not bool(duck_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(duck_idle_state.get("turtle_swim_pose", false)) \
		and not bool(duck_idle_state.get("turtle_plod_pose", false)) \
		and not bool(duck_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(duck_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(duck_idle_state.get("water_slither_pose", false)) \
		and not bool(duck_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(duck_idle_state.get("slick_crawl_pose", false)) \
		and not bool(duck_idle_state.get("newt_swim_pose", false)) \
		and not bool(duck_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(duck_idle_state.get("leech_undulate_pose", false)) \
		and not bool(duck_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(duck_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(duck_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(duck_idle_state.get("surface_walk", false)) \
		and not bool(duck_idle_state.get("submerged_shrew_pose", false)) \
		and not bool(duck_idle_state.get("high_walk_pose", false)) \
		and not bool(duck_idle_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(duck_idle_state, duck_non_duck_motion_flags) \
		and float(duck_idle_state.get("duck_paddle_intensity", 1.0)) <= 0.001 \
		and float(duck_idle_state.get("duck_waddle_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var duck_land_state: Dictionary = actor.get_render_motion_state()
	var duck_waddle: bool = bool(duck_land_state.get("duck_waddle_pose", false)) \
		and not bool(duck_land_state.get("duck_paddle_pose", false)) \
		and not bool(duck_land_state.get("wading_pose", false)) \
		and not bool(duck_land_state.get("heron_stalk_pose", false)) \
		and not bool(duck_land_state.get("beaver_lumber_pose", false)) \
		and not bool(duck_land_state.get("mink_bound_pose", false)) \
		and not bool(duck_land_state.get("otter_land_slide_pose", false)) \
		and not bool(duck_land_state.get("turtle_plod_pose", false)) \
		and not bool(duck_land_state.get("bog_turtle_creep_pose", false)) \
		and not bool(duck_land_state.get("water_snake_land_slither_pose", false)) \
		and not bool(duck_land_state.get("slick_crawl_pose", false)) \
		and not bool(duck_land_state.get("leech_inchworm_pose", false)) \
		and not bool(duck_land_state.get("crayfish_scuttle_pose", false)) \
		and not bool(duck_land_state.get("shrew_land_skitter_pose", false)) \
		and not bool(duck_land_state.get("high_walk_pose", false)) \
		and _none_render_flags(duck_land_state, duck_non_duck_motion_flags) \
		and float(duck_land_state.get("duck_waddle_intensity", 0.0)) > 0.25 \
		and float(duck_land_state.get("duck_paddle_intensity", 1.0)) <= 0.001
	if not duck_paddle or not duck_idle_clear or not duck_waddle:
		failures.append("moving duck should expose web-foot water paddle and toe-splayed land waddle without frog, heron, bird, mammal, turtle, crawler, snake, shrew, gator, swarm, hover, crustacean, or spider overlap, then clear when idle; water=%s idle=%s land=%s state=%s/%s/%s" % [
			str(duck_paddle),
			str(duck_idle_clear),
			str(duck_waddle),
			str(duck_water_state),
			str(duck_idle_state),
			str(duck_land_state)
		])
	actor.apply_creature("beaver")
	var beaver_non_beaver_motion_flags: Array[String] = [
		"hop_pose", "chorus_hop_pose", "cane_squat_hop_pose", "rooted_pose",
		"duck_waddle_pose", "duck_paddle_pose", "turtle_plod_pose", "turtle_swim_pose",
		"bog_turtle_creep_pose", "bog_turtle_paddle_pose", "mink_bound_pose", "mink_swim_pose", "mink_choke_pose",
		"otter_land_slide_pose", "otter_swim_pose", "otter_pack_latch_pose", "slick_crawl_pose", "newt_swim_pose",
		"leech_inchworm_pose", "leech_undulate_pose", "water_snake_land_slither_pose",
		"water_snake_mud_slither", "water_slither_pose", "surface_walk", "submerged_shrew_pose",
		"shrew_land_skitter_pose", "crayfish_scuttle_pose", "crayfish_tail_flick_swim_pose",
		"spider_skitter_pose", "spider_lunge_pose", "spider_burrowed_pose", "spider_latch_pose",
		"high_walk_pose", "alligator_water_cruise_pose",
		"owl_glide_pose", "owl_silent_flight_pose", "kingfisher_dart_pose", "wading_pose",
		"heron_stalk_pose", "mosquito_swarm_pose", "mosquito_trail_pose", "firefly_hover_pose", "firefly_flash_pose"
	]
	actor.current_environment_profile = {"surface": "water"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var beaver_water_state: Dictionary = actor.get_render_motion_state()
	var beaver_swim: bool = bool(beaver_water_state.get("beaver_swim_pose", false)) \
		and not bool(beaver_water_state.get("beaver_lumber_pose", false)) \
		and not bool(beaver_water_state.get("duck_paddle_pose", false)) \
		and not bool(beaver_water_state.get("turtle_swim_pose", false)) \
		and not bool(beaver_water_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(beaver_water_state.get("mink_swim_pose", false)) \
		and not bool(beaver_water_state.get("otter_swim_pose", false)) \
		and not bool(beaver_water_state.get("otter_land_slide_pose", false)) \
		and not bool(beaver_water_state.get("water_slither_pose", false)) \
		and not bool(beaver_water_state.get("newt_swim_pose", false)) \
		and not bool(beaver_water_state.get("leech_undulate_pose", false)) \
		and not bool(beaver_water_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(beaver_water_state.get("surface_walk", false)) \
		and not bool(beaver_water_state.get("submerged_shrew_pose", false)) \
		and not bool(beaver_water_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(beaver_water_state, beaver_non_beaver_motion_flags) \
		and float(beaver_water_state.get("beaver_swim_intensity", 0.0)) > 0.25 \
		and float(beaver_water_state.get("beaver_lumber_intensity", 1.0)) <= 0.001
	actor.velocity = Vector2.ZERO
	actor.set_input_frame(InputFrameScript.new())
	var beaver_idle_state: Dictionary = actor.get_render_motion_state()
	var beaver_idle_clear: bool = not bool(beaver_idle_state.get("beaver_swim_pose", false)) \
		and not bool(beaver_idle_state.get("beaver_lumber_pose", false)) \
		and not bool(beaver_idle_state.get("duck_paddle_pose", false)) \
		and not bool(beaver_idle_state.get("duck_waddle_pose", false)) \
		and not bool(beaver_idle_state.get("turtle_swim_pose", false)) \
		and not bool(beaver_idle_state.get("turtle_plod_pose", false)) \
		and not bool(beaver_idle_state.get("bog_turtle_paddle_pose", false)) \
		and not bool(beaver_idle_state.get("bog_turtle_creep_pose", false)) \
		and not bool(beaver_idle_state.get("mink_swim_pose", false)) \
		and not bool(beaver_idle_state.get("otter_swim_pose", false)) \
		and not bool(beaver_idle_state.get("mink_bound_pose", false)) \
		and not bool(beaver_idle_state.get("otter_land_slide_pose", false)) \
		and not bool(beaver_idle_state.get("water_slither_pose", false)) \
		and not bool(beaver_idle_state.get("water_snake_land_slither_pose", false)) \
		and not bool(beaver_idle_state.get("slick_crawl_pose", false)) \
		and not bool(beaver_idle_state.get("newt_swim_pose", false)) \
		and not bool(beaver_idle_state.get("leech_inchworm_pose", false)) \
		and not bool(beaver_idle_state.get("leech_undulate_pose", false)) \
		and not bool(beaver_idle_state.get("crayfish_scuttle_pose", false)) \
		and not bool(beaver_idle_state.get("crayfish_tail_flick_swim_pose", false)) \
		and not bool(beaver_idle_state.get("shrew_land_skitter_pose", false)) \
		and not bool(beaver_idle_state.get("surface_walk", false)) \
		and not bool(beaver_idle_state.get("submerged_shrew_pose", false)) \
		and not bool(beaver_idle_state.get("high_walk_pose", false)) \
		and not bool(beaver_idle_state.get("alligator_water_cruise_pose", false)) \
		and _none_render_flags(beaver_idle_state, beaver_non_beaver_motion_flags) \
		and float(beaver_idle_state.get("beaver_swim_intensity", 1.0)) <= 0.001 \
		and float(beaver_idle_state.get("beaver_lumber_intensity", 1.0)) <= 0.001
	actor.current_environment_profile = {"surface": "land"}
	actor.velocity = Vector2.RIGHT * actor.get_speed_px()
	var beaver_land_state: Dictionary = actor.get_render_motion_state()
	var beaver_lumber: bool = bool(beaver_land_state.get("beaver_lumber_pose", false)) \
		and not bool(beaver_land_state.get("beaver_swim_pose", false)) \
		and not bool(beaver_land_state.get("duck_waddle_pose", false)) \
		and not bool(beaver_land_state.get("turtle_plod_pose", false)) \
		and not bool(beaver_land_state.get("bog_turtle_creep_pose", false)) \
		and not bool(beaver_land_state.get("mink_bound_pose", false)) \
		and not bool(beaver_land_state.get("otter_land_slide_pose", false)) \
		and not bool(beaver_land_state.get("water_snake_land_slither_pose", false)) \
		and not bool(beaver_land_state.get("slick_crawl_pose", false)) \
		and not bool(beaver_land_state.get("leech_inchworm_pose", false)) \
		and not bool(beaver_land_state.get("crayfish_scuttle_pose", false)) \
		and not bool(beaver_land_state.get("shrew_land_skitter_pose", false)) \
		and not bool(beaver_land_state.get("high_walk_pose", false)) \
		and _none_render_flags(beaver_land_state, beaver_non_beaver_motion_flags) \
		and float(beaver_land_state.get("beaver_lumber_intensity", 0.0)) > 0.25 \
		and float(beaver_land_state.get("beaver_swim_intensity", 1.0)) <= 0.001
	if not beaver_swim or not beaver_idle_clear or not beaver_lumber:
		failures.append("moving beaver should expose heavy paddle-tail swim and land lumber without frog, duck, turtle, mustelid, crawler, snake, shrew, gator, bird, swarm, hover, crustacean, or spider overlap, then clear when idle; water=%s idle=%s land=%s state=%s/%s/%s" % [
			str(beaver_swim),
			str(beaver_idle_clear),
			str(beaver_lumber),
			str(beaver_water_state),
			str(beaver_idle_state),
			str(beaver_land_state)
		])

func _check_visual_height_profiles(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.anim_attack_timer = 0.0
	actor.apply_creature("great_blue_heron")
	actor.state = CreatureStateScript.State.NORMAL
	actor.anim_attack_timer = 0.0
	var heron_state: Dictionary = actor.get_render_motion_state()
	actor.apply_creature("owl")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.anim_attack_timer = 0.0
	var owl_air_state: Dictionary = actor.get_render_motion_state()
	actor.open_low_window(0.7)
	actor.anim_attack_timer = 0.0
	var owl_low_state: Dictionary = actor.get_render_motion_state()
	actor.state = CreatureStateScript.State.NORMAL
	actor.low_window_timer = 0.0
	actor.anim_attack_timer = 0.0
	var owl_ground_state: Dictionary = actor.get_render_motion_state()
	actor.apply_creature("kingfisher")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.anim_attack_timer = 0.0
	var kingfisher_air_state: Dictionary = actor.get_render_motion_state()
	actor.open_low_window(0.7)
	actor.anim_attack_timer = 0.0
	var kingfisher_low_state: Dictionary = actor.get_render_motion_state()
	actor.apply_creature("bog_turtle")
	actor.anim_attack_timer = 0.0
	var bog_state: Dictionary = actor.get_render_motion_state()
	actor.apply_creature("mosquito_swarm")
	actor.anim_attack_timer = 0.0
	var mosquito_base_state: Dictionary = actor.get_render_motion_state()
	actor.anim_attack_duration = 0.4
	actor.anim_attack_timer = 0.4
	var mosquito_attack_state: Dictionary = actor.get_render_motion_state()
	actor.apply_creature("firefly")
	actor.anim_attack_timer = 0.0
	var firefly_state: Dictionary = actor.get_render_motion_state()
	actor.anim_attack_duration = 0.4
	actor.anim_attack_timer = 0.4
	var firefly_attack_state: Dictionary = actor.get_render_motion_state()
	var tall_heron: bool = float(heron_state.get("model_scale", 1.0)) > 1.15 and float(heron_state.get("height_units", 0.0)) > 1.3 and String(heron_state.get("height_class", "")) == "tall_wader"
	var owl_lift: bool = float(owl_air_state.get("height_units", 0.0)) > float(owl_ground_state.get("height_units", 0.0)) + 0.25
	var owl_low_read: bool = float(owl_low_state.get("height_units", 1.0)) < float(owl_air_state.get("height_units", 0.0)) - 0.55 \
		and bool(owl_low_state.get("air_attack_readable", false)) \
		and bool(owl_low_state.get("air_attack_cue_pose", false)) \
		and float(owl_low_state.get("air_attack_cue_intensity", 0.0)) > 0.9 \
		and float(owl_low_state.get("height_shadow_alpha", 0.0)) > float(owl_air_state.get("height_shadow_alpha", 1.0)) + 0.18 \
		and float(owl_low_state.get("height_shadow_radius_mult", 0.0)) > float(owl_air_state.get("height_shadow_radius_mult", 1.0)) + 0.16 \
		and float(owl_low_state.get("model_scale", 1.0)) > float(owl_air_state.get("model_scale", 1.0)) + 0.08 \
		and float(owl_low_state.get("low_window_model_scale_bonus", 0.0)) > 0.08 \
		and float(owl_low_state.get("low_window_t", 0.0)) > 0.9 \
		and String(owl_low_state.get("height_band", "")) == "body"
	var kingfisher_low_read: bool = float(kingfisher_low_state.get("height_units", 1.0)) < float(kingfisher_air_state.get("height_units", 0.0)) - 0.55 \
		and bool(kingfisher_low_state.get("air_attack_readable", false)) \
		and bool(kingfisher_low_state.get("air_attack_cue_pose", false)) \
		and float(kingfisher_low_state.get("air_attack_cue_intensity", 0.0)) > 0.9 \
		and float(kingfisher_low_state.get("model_scale", 1.0)) > float(kingfisher_air_state.get("model_scale", 1.0)) + 0.08 \
		and float(kingfisher_low_state.get("low_window_model_scale_bonus", 0.0)) > 0.08 \
		and String(kingfisher_low_state.get("height_band", "")) == "body"
	var tiny_low: bool = float(bog_state.get("model_scale", 1.0)) < 0.9 and float(bog_state.get("height_units", 1.0)) < 0.3
	var tiny_hover: bool = float(firefly_state.get("model_scale", 1.0)) < 0.85 \
		and float(firefly_state.get("height_units", 0.0)) >= 0.9 \
		and float(firefly_state.get("height_shadow_alpha", 0.0)) > 0.25 \
		and float(firefly_state.get("height_shadow_radius_mult", 0.0)) > 0.88
	var flying_attack_scale: bool = float(mosquito_attack_state.get("model_scale", 1.0)) > float(mosquito_base_state.get("model_scale", 1.0)) + 0.1 \
		and float(mosquito_attack_state.get("air_attack_model_scale_bonus", 0.0)) > 0.1 \
		and float(mosquito_attack_state.get("air_attack_release_t", 0.0)) > 0.9 \
		and bool(mosquito_attack_state.get("air_attack_readable", false)) \
		and float(mosquito_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(mosquito_attack_state.get("visual_radius_px", 0.0)) * 1.25 \
		and float(firefly_attack_state.get("model_scale", 1.0)) > float(firefly_state.get("model_scale", 1.0)) + 0.16 \
		and float(firefly_attack_state.get("air_attack_model_scale_bonus", 0.0)) > 0.16 \
		and float(firefly_attack_state.get("air_attack_release_t", 0.0)) > 0.9 \
		and bool(firefly_attack_state.get("air_attack_readable", false)) \
		and float(firefly_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(firefly_attack_state.get("visual_radius_px", 0.0)) * 1.25 \
		and float(firefly_attack_state.get("model_scale", 1.0)) < float(mosquito_attack_state.get("model_scale", 1.0))
	var heron_truth_ring: bool = _truth_ring_matches_combat_radius(heron_state) \
		and float(heron_state.get("visual_radius_px", 0.0)) > float(heron_state.get("combat_radius_px", 0.0)) * 1.15
	var bog_truth_ring: bool = _truth_ring_matches_combat_radius(bog_state) \
		and float(bog_state.get("visual_radius_px", 999.0)) < float(bog_state.get("combat_radius_px", 0.0)) * 0.9
	var roster_profiled := _all_roster_creatures_have_height_profile(arena)
	var roster_truth_ring := _all_roster_creatures_have_truth_ring(arena)
	var roster_silhouette_contract := _all_roster_creatures_have_silhouette_contract(arena)
	if not tall_heron or not owl_lift or not owl_low_read or not kingfisher_low_read or not tiny_low or not tiny_hover or not flying_attack_scale or not heron_truth_ring or not bog_truth_ring or not roster_profiled or not roster_truth_ring or not roster_silhouette_contract:
		failures.append("visual height profiles should distinguish tall, airborne, hittable low-window, low, tiny hover, airborne attack readability scales, combat-radius truth rings, and silhouette mass contracts; heron=%s owl=%s/%s/%s kingfisher=%s/%s bog=%s mosquito=%s/%s firefly=%s/%s rings=%s/%s/%s roster_profiled=%s silhouette_contract=%s" % [
			str(heron_state),
			str(owl_air_state),
			str(owl_low_state),
			str(owl_ground_state),
			str(kingfisher_air_state),
			str(kingfisher_low_state),
			str(bog_state),
			str(mosquito_base_state),
			str(mosquito_attack_state),
			str(firefly_state),
			str(firefly_attack_state),
			str(heron_truth_ring),
			str(bog_truth_ring),
			str(roster_truth_ring),
			str(roster_profiled),
			str(roster_silhouette_contract)
		])

func _check_air_attack_readability_contract(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("mosquito_swarm")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.begin_render_air_attack_startup(0.28)
	var startup_only_state: Dictionary = actor.get_render_motion_state()
	var startup_only_ok: bool = bool(startup_only_state.get("air_attack_readable", false)) \
		and float(startup_only_state.get("air_attack_startup_t", 0.0)) > 0.9 \
		and float(startup_only_state.get("air_attack_release_t", 1.0)) <= 0.001 \
		and not bool(startup_only_state.get("low_window_active", true)) \
		and _truth_ring_matches_combat_radius(startup_only_state) \
		and float(startup_only_state.get("air_attack_cue_radius_px", 0.0)) > float(startup_only_state.get("visual_radius_px", 0.0)) * 1.45

	actor.apply_creature("owl")
	actor.global_position = Vector2(400.0, 400.0)
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var owl_attack_state: Dictionary = actor.get_render_motion_state()
	var owl_live_cue: bool = bool(owl_attack_state.get("air_attack_readable", false)) \
		and bool(owl_attack_state.get("low_window_active", false)) \
		and float(owl_attack_state.get("air_attack_startup_t", 0.0)) > 0.9 \
		and float(owl_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(owl_attack_state.get("visual_radius_px", 0.0)) * 1.5 \
		and String(owl_attack_state.get("height_band", "")) == "body"

	actor.apply_creature("kingfisher")
	actor.global_position = Vector2(400.0, 400.0)
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var kingfisher_attack_state: Dictionary = actor.get_render_motion_state()
	var kingfisher_live_cue: bool = bool(kingfisher_attack_state.get("air_attack_readable", false)) \
		and bool(kingfisher_attack_state.get("low_window_active", false)) \
		and float(kingfisher_attack_state.get("air_attack_startup_t", 0.0)) > 0.9 \
		and float(kingfisher_attack_state.get("height_shadow_alpha", 0.0)) > 0.36 \
		and float(kingfisher_attack_state.get("height_shadow_radius_mult", 0.0)) > 1.08 \
		and float(kingfisher_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(kingfisher_attack_state.get("visual_radius_px", 0.0)) * 1.55 \
		and String(kingfisher_attack_state.get("height_band", "")) == "body"

	actor.apply_creature("mosquito_swarm")
	actor.global_position = Vector2(400.0, 400.0)
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var mosquito_attack_state: Dictionary = actor.get_render_motion_state()
	var mosquito_live_cue: bool = bool(mosquito_attack_state.get("air_attack_readable", false)) \
		and float(mosquito_attack_state.get("air_attack_startup_t", 0.0)) > 0.9 \
		and float(mosquito_attack_state.get("air_attack_release_t", 0.0)) > 0.9 \
		and not bool(mosquito_attack_state.get("low_window_active", false)) \
		and float(mosquito_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(mosquito_attack_state.get("visual_radius_px", 0.0)) * 1.55

	actor.apply_creature("firefly")
	actor.global_position = Vector2(400.0, 400.0)
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var firefly_attack_state: Dictionary = actor.get_render_motion_state()
	var firefly_live_cue: bool = bool(firefly_attack_state.get("air_attack_readable", false)) \
		and float(firefly_attack_state.get("air_attack_startup_t", 0.0)) > 0.9 \
		and float(firefly_attack_state.get("air_attack_release_t", 0.0)) > 0.9 \
		and not bool(firefly_attack_state.get("low_window_active", false)) \
		and float(firefly_attack_state.get("air_attack_cue_radius_px", 0.0)) > float(firefly_attack_state.get("visual_radius_px", 0.0)) * 1.55

	actor.apply_creature("great_blue_heron")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var heron_air_primary_state: Dictionary = actor.get_render_motion_state()
	var heron_no_fake_low: bool = not bool(heron_air_primary_state.get("air_attack_readable", false)) \
		and not bool(heron_air_primary_state.get("low_window_active", false)) \
		and float(heron_air_primary_state.get("air_attack_startup_t", 0.0)) <= 0.001 \
		and actor.anim_attack_timer <= 0.001

	actor.apply_creature("duck")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.primary_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.low_window_timer = 0.0
	actor.set_input_frame(_primary_frame(actor, Vector2.RIGHT))
	actor.kit.tick(actor, 0.016)
	var duck_air_primary_state: Dictionary = actor.get_render_motion_state()
	var duck_no_fake_low: bool = not bool(duck_air_primary_state.get("air_attack_readable", false)) \
		and not bool(duck_air_primary_state.get("low_window_active", false)) \
		and float(duck_air_primary_state.get("air_attack_startup_t", 0.0)) <= 0.001 \
		and actor.anim_attack_timer <= 0.001

	if not startup_only_ok or not owl_live_cue or not kingfisher_live_cue or not mosquito_live_cue or not firefly_live_cue or not heron_no_fake_low or not duck_no_fake_low:
		failures.append("flying attack readability should separate render-only startup warning, true LOW punish windows, projectile release cues, and non-attacking airborne heron/duck quiet states; startup=%s owl=%s kingfisher=%s mosquito=%s firefly=%s heron=%s duck=%s" % [
			str(startup_only_state),
			str(owl_attack_state),
			str(kingfisher_attack_state),
			str(mosquito_attack_state),
			str(firefly_attack_state),
			str(heron_air_primary_state),
			str(duck_air_primary_state)
		])

func _check_live_height_hud_read(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("snapping_turtle")
	actor.state = CreatureStateScript.State.NORMAL
	actor.low_window_timer = 0.0
	actor.anim_attack_timer = 0.0
	var grounded_text: String = arena._get_cooldown_text()
	actor.apply_creature("owl")
	actor.state = CreatureStateScript.State.AIRBORNE
	actor.low_window_timer = 0.0
	actor.anim_attack_timer = 0.0
	var airborne_text: String = arena._get_cooldown_text()
	actor.open_low_window(0.7)
	var low_text: String = arena._get_cooldown_text()
	var ok := grounded_text.contains("Height Body") \
		and airborne_text.contains("Height High") \
		and not airborne_text.contains("Height High LOW") \
		and low_text.contains("Height Body LOW")
	if not ok:
		failures.append("live cooldown HUD should expose active creature height band and low airborne attack window; grounded=%s airborne=%s low=%s" % [
			grounded_text,
			airborne_text,
			low_text
		])

func _check_actor_redraw_signatures(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("snapping_turtle")
	actor.global_position = arena.player.global_position
	actor.velocity = Vector2.ZERO
	actor.render_hitstop_frames = 0
	actor.render_flash_timer = 0.0
	actor.render_shake_timer = 0.0
	actor.anim_attack_timer = 0.0
	actor.anim_windup_timer = 0.0
	var idle_signature: String = actor.get_render_signature()
	actor._process(1.0 / 60.0)
	var second_idle_signature: String = actor.get_render_signature()
	actor.begin_render_takeoff_flap()
	var tell_signature: String = actor.get_render_signature()
	var bot: Node = arena.bots[0]
	bot.apply_creature("cane_toad")
	bot.global_position = arena.player.global_position + Vector2(2000.0, 0.0)
	bot._last_render_signature = "offscreen-unchanged"
	bot._request_render_redraw(true)
	var offscreen_kept_signature: bool = String(bot._last_render_signature) == "offscreen-unchanged"
	var minion: Node = arena.minions[0] if arena.minions.size() > 0 else null
	var minion_idle_stable := false
	var minion_attack_changes := false
	if minion != null:
		minion.global_position = arena.player.global_position
		minion.velocity = Vector2.ZERO
		minion.attack_commit_timer = 0.0
		var minion_idle_a: String = minion.get_render_signature()
		minion._request_redraw()
		var minion_idle_b: String = minion.get_render_signature()
		minion.attack_commit_timer = 0.25
		var minion_attack: String = minion.get_render_signature()
		minion_idle_stable = minion_idle_a == minion_idle_b
		minion_attack_changes = minion_attack != minion_idle_a
	if idle_signature != second_idle_signature or idle_signature == tell_signature or not offscreen_kept_signature or not minion_idle_stable or not minion_attack_changes:
		failures.append("actor redraws should be gated by compact render signatures and near-view checks; idle=%s/%s tell=%s offscreen=%s minion_stable=%s minion_attack=%s" % [
			idle_signature,
			second_idle_signature,
			tell_signature,
			str(offscreen_kept_signature),
			str(minion_idle_stable),
			str(minion_attack_changes)
		])

func _check_bird_transition_cues(arena: Node, failures: Array[String]) -> void:
	var actor: Node = arena.player
	actor.apply_creature("owl")
	actor.global_position = Vector2(320.0, 320.0)
	actor.velocity = Vector2.ZERO
	actor.state = CreatureStateScript.State.NORMAL
	actor.flight_grounded_timer = 0.0
	actor.flight_toggle_requires_release = false
	actor.takeoff_distance_px = CreatureScript.TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX * 0.55
	actor.set_input_frame(_flight_frame(Vector2.RIGHT))
	var charge_state: Dictionary = actor.get_render_motion_state()
	var charge_ok: bool = bool(charge_state.get("bird_transition_pose", false)) and float(charge_state.get("takeoff_charge_t", 0.0)) > 0.5
	actor._update_takeoff_charge_from_displacement(CreatureScript.TAKEOFF_DISTANCE_UNITS * SimConstants.UNIT_PX * 0.55)
	var takeoff_state: Dictionary = actor.get_render_motion_state()
	var takeoff_ok: bool = actor.state == CreatureStateScript.State.AIRBORNE \
		and bool(takeoff_state.get("bird_transition_pose", false)) \
		and float(takeoff_state.get("takeoff_flap_t", 0.0)) > 0.9
	actor.render_takeoff_flap_timer = 0.0
	actor.flight_time_remaining = 0.0
	actor.set_input_frame(InputFrameScript.new())
	actor.tick_sim(SimConstants.TICK_DELTA)
	var landing_state: Dictionary = actor.get_render_motion_state()
	var landing_ok: bool = actor.state == CreatureStateScript.State.NORMAL \
		and bool(landing_state.get("bird_transition_pose", false)) \
		and float(landing_state.get("landing_flap_t", 0.0)) > 0.9 \
		and float(landing_state.get("grounded_lockout_t", 0.0)) > 0.9
	if not charge_ok or not takeoff_ok or not landing_ok:
		failures.append("bird flight transitions should expose charge, lift flap, landing flare, and grounded-lockout cues; charge=%s takeoff=%s landing=%s state=%s/%s/%s" % [
			str(charge_ok),
			str(takeoff_ok),
			str(landing_ok),
			str(charge_state),
			str(takeoff_state),
			str(landing_state)
		])

func _check_predator_latch_cues(arena: Node, failures: Array[String]) -> void:
	var snake_state := _latched_render_state(arena, "water_snake", "Bite")
	var gator_hold_state := _latched_render_state(arena, "alligator", "Bite")
	var gator_roll_state := _latched_render_state(arena, "alligator", "Death Roll")
	var mink_choke_state := _latched_render_state(arena, "mink", "Choke")
	var otter_pack_state := _latched_render_state(arena, "otter", "Gang Up")
	var victim_state: Dictionary = arena.bots[0].get_render_motion_state()
	var snake_coil: bool = bool(snake_state.get("water_snake_coil_pose", false)) and bool(snake_state.get("latch_attacker_pose", false))
	var gator_hold: bool = bool(gator_hold_state.get("alligator_jaw_hold_pose", false)) and not bool(gator_hold_state.get("alligator_death_roll_pose", false))
	var gator_roll: bool = bool(gator_roll_state.get("alligator_death_roll_pose", false)) and not bool(gator_roll_state.get("alligator_jaw_hold_pose", false))
	var mink_choke: bool = bool(mink_choke_state.get("mink_choke_pose", false)) and String(mink_choke_state.get("latch_source", "")) == "Choke"
	var otter_pack: bool = bool(otter_pack_state.get("otter_pack_latch_pose", false)) and String(otter_pack_state.get("latch_source", "")) == "Gang Up"
	var victim_read: bool = bool(victim_state.get("latched_victim_pose", false))
	if not snake_coil or not gator_hold or not gator_roll or not mink_choke or not otter_pack or not victim_read:
		failures.append("predator latches should expose source-specific read poses for coil, jaw hold, death roll, choke, pack latch, and held victim; snake=%s gator=%s/%s mink=%s otter=%s victim=%s states=%s/%s/%s/%s/%s/%s" % [
			str(snake_coil),
			str(gator_hold),
			str(gator_roll),
			str(mink_choke),
			str(otter_pack),
			str(victim_read),
			str(snake_state),
			str(gator_hold_state),
			str(gator_roll_state),
			str(mink_choke_state),
			str(otter_pack_state),
			str(victim_state)
		])
	arena.player.release_latch("test_reset")

func _latched_render_state(arena: Node, creature_id: String, source: String) -> Dictionary:
	var actor: Node = arena.player
	var victim: Node = arena.bots[0]
	actor.release_latch("test_reset")
	victim.release_latch("test_reset")
	actor.apply_creature(creature_id)
	victim.apply_creature("cane_toad")
	actor.global_position = Vector2(340.0, 320.0)
	victim.global_position = actor.global_position + Vector2.RIGHT * 28.0
	actor.attach_to_victim(victim, 5.0, source, 10.0 if source == "Choke" else 0.0)
	victim.receive_latch(actor, 5.0, source)
	return actor.get_render_motion_state()

func _all_roster_creatures_have_height_profile(arena: Node) -> bool:
	var actor: Node = arena.player
	var roster := [
		"bullfrog", "chorus_frog", "newt", "cane_toad", "snapping_turtle", "water_snake", "bog_turtle", "alligator", "owl", "great_blue_heron", "kingfisher", "duck", "water_shrew", "beaver", "otter", "mink", "leech", "crayfish", "mosquito_swarm", "wolf_spider", "firefly"
	]
	for creature_id: String in roster:
		actor.apply_creature(creature_id)
		var state: Dictionary = actor.get_render_motion_state()
		if String(state.get("height_class", "mid")) == "mid" or String(state.get("height_band", "")) == "" or float(state.get("height_units", 0.0)) <= 0.0:
			return false
	return true

func _all_roster_creatures_have_truth_ring(arena: Node) -> bool:
	var actor: Node = arena.player
	var roster := [
		"bullfrog", "chorus_frog", "newt", "cane_toad", "snapping_turtle", "water_snake", "bog_turtle", "alligator", "owl", "great_blue_heron", "kingfisher", "duck", "water_shrew", "beaver", "otter", "mink", "leech", "crayfish", "mosquito_swarm", "wolf_spider", "firefly"
	]
	for creature_id: String in roster:
		actor.apply_creature(creature_id)
		var state: Dictionary = actor.get_render_motion_state()
		if not _truth_ring_matches_combat_radius(state):
			return false
	return true

func _all_roster_creatures_have_silhouette_contract(arena: Node) -> bool:
	var actor: Node = arena.player
	var roster := [
		"bullfrog", "chorus_frog", "newt", "cane_toad", "snapping_turtle", "water_snake", "bog_turtle", "alligator", "owl", "great_blue_heron", "kingfisher", "duck", "water_shrew", "beaver", "otter", "mink", "leech", "crayfish", "mosquito_swarm", "wolf_spider", "firefly"
	]
	var expected_archetypes := {
		"bullfrog": "frog",
		"chorus_frog": "frog",
		"newt": "mustelid",
		"cane_toad": "frog",
		"snapping_turtle": "turtle",
		"water_snake": "serpent",
		"bog_turtle": "turtle",
		"alligator": "croc",
		"owl": "bird",
		"great_blue_heron": "bird",
		"kingfisher": "bird",
		"duck": "bird",
		"water_shrew": "mustelid",
		"beaver": "mustelid",
		"otter": "mustelid",
		"mink": "mustelid",
		"leech": "cluster",
		"crayfish": "crustacean",
		"mosquito_swarm": "swarm",
		"wolf_spider": "spider",
		"firefly": "bug"
	}
	for creature_id: String in roster:
		actor.apply_creature(creature_id)
		var state: Dictionary = actor.get_render_motion_state()
		var filled_mult := float(state.get("filled_mass_radius_mult", 99.0))
		var thin_mult := float(state.get("thin_overhang_radius_mult", 0.0))
		var features: Array = state.get("silhouette_features", [])
		var archetype_ok := String(state.get("silhouette_archetype", "")) == String(expected_archetypes.get(creature_id, ""))
		var mass_ok := filled_mult > 0.0 and filled_mult <= float(state.get("wide_filled_overhang_limit_mult", 1.15))
		var overhang_ok := thin_mult >= filled_mult and thin_mult <= 1.65
		var shadow_ok := bool(state.get("contact_shadow_ellipse", false))
		var capsule_half_len := float(state.get("capsule_half_len_px", 0.0))
		var footprint_length := float(state.get("footprint_length_px", 0.0))
		var long_body_length := float(state.get("long_body_visual_length_px", 0.0))
		var long_body_ok := true
		if creature_id == "water_snake" or creature_id == "alligator":
			long_body_ok = capsule_half_len > 0.0 and long_body_length >= footprint_length and footprint_length > float(state.get("combat_radius_px", 0.0)) * 2.0
		elif capsule_half_len > 0.0:
			long_body_ok = false
		if not archetype_ok or not mass_ok or not overhang_ok or not shadow_ok or features.is_empty() or not long_body_ok:
			return false
	return true

func _truth_ring_matches_combat_radius(state: Dictionary) -> bool:
	var combat_radius := float(state.get("combat_radius_px", -1.0))
	var visual_radius := float(state.get("visual_radius_px", -1.0))
	var truth_radius := float(state.get("truth_ring_radius_px", -2.0))
	return combat_radius > 0.0 and visual_radius > 0.0 and absf(truth_radius - combat_radius) < 0.001

func _none_render_flags(state: Dictionary, flags: Array[String]) -> bool:
	for flag: String in flags:
		if bool(state.get(flag, false)):
			return false
	return true

func _move_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = direction
	frame.aim = Vector2.RIGHT * 100.0
	return frame

func _flight_frame(direction: Vector2) -> Resource:
	var frame := _move_frame(direction)
	frame.set_button(InputFrameScript.BUTTON_FLIGHT_TOGGLE, true)
	return frame

func _primary_frame(actor: Node, direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Vector2.ZERO
	frame.aim = actor.global_position + direction.normalized() * 100.0
	frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
	return frame

func _movement_zone_point(arena: Node, zone: String) -> Vector2:
	var rects: Array = arena.terrain_map.get_rects(zone)
	for rect: Rect2 in rects:
		for x_step in 7:
			for y_step in 7:
				var point := Vector2(
					lerpf(rect.position.x + 12.0, rect.end.x - 12.0, float(x_step) / 6.0),
					lerpf(rect.position.y + 12.0, rect.end.y - 12.0, float(y_step) / 6.0)
				)
				if String(arena.terrain_map.get_zone_at(point)) == zone:
					return point
	return Vector2.ZERO

func _aim_frame(direction: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.move = Vector2.ZERO
	frame.aim = direction * 100.0
	return frame

func _one_tick_velocity(actor: Node, creature_id: String, direction: Vector2) -> float:
	actor.apply_creature(creature_id)
	actor.global_position = Vector2.ZERO
	actor.velocity = Vector2.ZERO
	actor.last_aim_direction = Vector2.RIGHT
	actor.set_input_frame(_move_frame(direction))
	actor.tick_sim(1.0 / 60.0)
	return actor.velocity.length()
