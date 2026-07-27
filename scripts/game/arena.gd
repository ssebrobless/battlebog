extends Node2D

const BLUE := 0
const RED := 1
const ARENA_RECT := Rect2(Vector2(-1120.0, -620.0), Vector2(2240.0, 1240.0))
const WAVE_INTERVAL := 20.0
const COVER_RECTS := [
	Rect2(Vector2(-210.0, -265.0), Vector2(130.0, 105.0)),
	Rect2(Vector2(80.0, 160.0), Vector2(130.0, 105.0)),
	Rect2(Vector2(-50.0, -42.0), Vector2(100.0, 84.0))
]
const CoreScript := preload("res://scripts/game/core.gd")
const MinionScript := preload("res://scripts/game/minion.gd")
const CreatureScript := preload("res://scripts/sim/creature.gd")
const ProjectileScript := preload("res://scripts/game/projectile.gd")
const TerrainMapScript := preload("res://scripts/sim/terrain_map.gd")
const LocalInputScript := preload("res://scripts/ui/local_input.gd")
const BotBrainScript := preload("res://scripts/ai/bot_brain.gd")
const MinimapScript := preload("res://scripts/ui/minimap.gd")
const SquadHudScript := preload("res://scripts/ui/squad_hud.gd")
const MatchResultPanelScript := preload("res://scripts/ui/match_result_panel.gd")
const MudHutScript := preload("res://scripts/game/mud_hut.gd")
const InputFrameScript := preload("res://scripts/sim/input_frame.gd")
const TerrainLayerScript := preload("res://scripts/game/terrain_layer.gd")
const WaterLayerScript := preload("res://scripts/game/water_layer.gd")
const DamageEventScript := preload("res://scripts/sim/damage_event.gd")
const SimConstants := preload("res://scripts/sim/sim_constants.gd")
const TargetFilter := preload("res://scripts/sim/combat/target_filter.gd")
const HurtboxScript := preload("res://scripts/sim/combat/hurtbox.gd")
const HitShapeScript := preload("res://scripts/sim/combat/hit_shape.gd")
const PerfOverlayScript := preload("res://scripts/ui/perf_overlay.gd")
const PerfStats := preload("res://scripts/game/perf_stats.gd")
const AbilityBarScript := preload("res://scripts/ui/ability_bar.gd")
const CreatureInfoPanelScript := preload("res://scripts/ui/creature_info_panel.gd")
const StockManagerScript := preload("res://scripts/game/stock_manager.gd")
const FoodSourceScript := preload("res://scripts/game/food_source.gd")
const WildlifeEncounterScript := preload("res://scripts/game/wildlife_encounter.gd")
const BossActorScript := preload("res://scripts/game/bosses/boss_actor.gd")
const ChampsosaurusBossScript := preload("res://scripts/game/bosses/champsosaurus_side_boss.gd")
const TeratornisCenterBossScript := preload("res://scripts/game/bosses/teratornis_center_boss.gd")
const BossCatalog := preload("res://scripts/game/bosses/boss_catalog.gd")
const BreedingActorScript := preload("res://scripts/game/breeding_actor.gd")
const VisualGrammar := preload("res://scripts/visual/visual_grammar.gd")
const TelegraphGeometry := preload("res://scripts/visual/telegraph_geometry.gd")
const MatchRulesScript := preload("res://scripts/game/match_rules.gd")
const MatchSlotRegistryScript := preload("res://scripts/game/match_slot_registry.gd")
const LegalWorldViewScript := preload("res://scripts/ai/legal_world_view.gd")
const TeamDirectorScript := preload("res://scripts/ai/team_director.gd")

const PLAYABLE_CREATURE_POOL := ["snapping_turtle", "chorus_frog", "mink", "beaver", "otter", "leech", "owl", "duck", "bullfrog", "cane_toad", "crayfish", "bog_turtle", "water_shrew", "newt", "great_blue_heron", "kingfisher", "water_snake", "alligator", "wolf_spider", "firefly", "mosquito_swarm"]
const SQUAD_COMMAND_FARM := "farm"
const SQUAD_COMMAND_FOLLOW := "follow"
const SQUAD_COMMAND_AGGRO := "aggro"
const SQUAD_COMMAND_SECONDS := 10.0
const SQUAD_SWITCH_FEEDBACK_SECONDS := 0.85
const SWITCH_RELEASE_BUTTONS := InputFrameScript.BUTTON_PRIMARY \
	| InputFrameScript.BUTTON_ABILITY_Q \
	| InputFrameScript.BUTTON_ABILITY_E \
	| InputFrameScript.BUTTON_HUT_DEFEND \
	| InputFrameScript.BUTTON_HABITAT_DEPOSIT \
	| InputFrameScript.BUTTON_CONTEXT_ACTION \
	| InputFrameScript.BUTTON_FLIGHT_TOGGLE
const SQUAD_FOLLOW_RADIUS := 5.0 * SimConstants.UNIT_PX
const SQUAD_DANGER_HEALTH_RATIO := 0.28
const SQUAD_DANGER_RANGE := 360.0
const DAY_LENGTH_SEC := 120.0
# Team vision (BB-VIS-1). Day-phase sight range (world px); hearing extends past sight but
# is cover-agnostic; ghost fade = how long a last-known position lingers after sight breaks.
const DAY_PHASE_DAWN_END := 0.10   # fraction of the day cycle
const DAY_PHASE_DAY_END := 0.55
const DAY_PHASE_DUSK_END := 0.70
const VISION_RANGE_DAY := 220.0
const VISION_RANGE_DUSK := 170.0
const VISION_RANGE_NIGHT := 120.0
const VISION_RANGE_DAWN := 200.0
const VISION_HEARING_BONUS := 120.0
const VISION_NOISE_GRID := 72.0
const VISION_GHOST_FADE_DAY := 3.0
const VISION_GHOST_FADE_DUSK := 5.0
const VISION_GHOST_FADE_NIGHT := 6.0
const VISION_TICK_SEC := 0.1
const FOOD_MINIMAP_MEMORY_SEC := 45.0
# Six info-states (Decision #35).
const INFO_VISIBLE := "visible"
const INFO_REVEALED := "revealed"
const INFO_HEARD := "heard"
const INFO_LAST_KNOWN := "last_known"
const INFO_SUSPECTED := "suspected"
const INFO_HIDDEN := "hidden"
const FOOD_EAT_RADIUS_PAD := 8.0
const BOSS_BREED_INTERVAL := 5
const SIDE_BOSS_ORDER := ["champsosaurus", "platyhystrix", "american_mastodon", "arthropleura", "teratornis"]
const ANIMAL_ZONE_TICK_SEC := 0.2
const WILDLIFE_HUNGER_REWARD := 24.0
const WILDLIFE_HEAL_FRACTION := 0.05
const BOSS_WILDLIFE_HUNGER_REWARD := 48.0
const BOSS_WILDLIFE_HEAL_FRACTION := 0.12
const BREEDING_STACK_VALUE := 0.03
const BREEDING_TEAM_CAP := 6
const BREEDING_FAMILY_CAP := 3
# Boss-stock buff channel (BB-BOSS-4) -- separate from the capped breeding buffs above.
const BOSS_STOCK_TEAM_CAP := 8
const BOSS_STOCK_EFFECT_KEYS := ["move_speed", "max_health", "damage", "ability_haste", "regen", "swim_duration", "healing_received", "damage_reduction", "size", "hunger_depletion", "vision_range"]
# Contested claim window on a downed side boss (BB-BOSS-4). Ownership via presence, not last-hit.
const BOSS_CLAIM_DURATION := 5.0
const BOSS_CLAIM_DECAY_MULT := 0.5
# Center big bosses (BB-BOSS-5): scheduled neutral map-wide objectives at 10:00 / 20:00 elapsed.
const CENTER_BOSS_TIMES := [600.0, 1200.0]
const CENTER_BOSS_RADIUS := Vector2(150.0, 130.0)
const CENTER_BOSS_REWARD_MAX_STACK := 2
const CENTER_KILL_GROWTH_MAX_STACKS := 8
const CENTER_KILL_GROWTH_DEATH_LOSS := 2
const BREEDING_BUFF_FAMILIES := ["amphibian", "reptile", "bird", "mammal", "crawly"]
const BREEDING_BUFF_EFFECT_BY_FAMILY := {
	"amphibian": "regen",
	"reptile": "max_health",
	"bird": "move_speed",
	"mammal": "damage",
	"crawly": "ability_haste"
}
const BREEDING_BUFF_LABEL_BY_FAMILY := {
	"amphibian": "AMPH",
	"reptile": "REPT",
	"bird": "BIRD",
	"mammal": "MAMM",
	"crawly": "CRAW"
}
const MATCH_SUMMARY_SCHEMA := "battle_bog_match_summary_v1"
const MATCH_LOG_DIR := "user://battle_bog_match_logs"
const ECONOMY_EVENT_LIMIT := 128
const BOSS_LIFECYCLE_EVENT_LIMIT := 512
const DEBUG_HURTBOX_OVERLAY := false

var entities: Array[Node] = []
var minions: Array[Node] = []
var bots: Array[Node] = []
var player_squad: Array[Node] = []
var active_squad_index := 0
var squad_command := SQUAD_COMMAND_FARM
var squad_command_timer := 0.0
var squad_aggro_target: Node = null
var squad_switch_feedback_timer := 0.0
var squad_switch_feedback_state := ""
var squad_switch_feedback_slot_index := -1
var cores: Dictionary = {}
var player: Node
var wave_timer := 2.0
var elapsed := 0.0
var match_over := false
var match_result: Dictionary = {}
var telegraphs: Array[Dictionary] = []
var vfx_events: Array[Dictionary] = []
var dams: Array[Node] = []
var huts: Array[Node] = []
var food_sources: Array[Node] = []
var animal_zone_states: Array[Dictionary] = []
var wildlife_encounters: Array[Node] = []
var breeding_actors: Array[Node] = []
var bred_animal_count := 0
var boss_activation_count := 0
var side_boss_meter := {BLUE: 0, RED: 0}
var side_boss_activations := {BLUE: 0, RED: 0}
var side_boss_index := {BLUE: 0, RED: 0}
var animal_zone_tick_timer := 0.0
var team_breeding_buffs: Dictionary = {}
var team_boss_stock_buffs: Dictionary = {}
var active_terrain_events: Array[Dictionary] = []
var team_vision := {BLUE: {}, RED: {}}    # entity_id -> {last_point, last_seen, ever}
var team_reveals := {BLUE: {}, RED: {}}   # entity_id -> remaining reveal seconds
var team_food_vision := {BLUE: {}, RED: {}} # food_id -> {point, last_seen}
var vision_tick_timer := 0.0
var center_boss_fired := [false, false]   # per CENTER_BOSS_TIMES entry
var center_boss_spawn_count := 0          # unique-id counter (a claimed zone can outlive a new spawn)
var team_combat_rewards: Dictionary = {}  # team -> {family: stack(1..2)}
var team_kill_growth_stacks := {BLUE: 0, RED: 0}
var huts_lost := {0: 0, 1: 0}
var hut_defend_hint_timer := 0.0
var habitat_deposit_feedback_timer := 0.0
var habitat_deposit_prompt_state := ""
var day_index := 1
var day_timer := 0.0
var ui_refresh_accumulator := 0.0
var camera: Camera2D = null
var match_seed := 0
var simulation_tick := 0

const CAMERA_LEAD_DEADZONE := 70.0
const CAMERA_LEAD_FRACTION := 0.32
const CAMERA_LEAD_MAX := 132.0
const WORLD_OVERLAY_REDRAW_INTERVAL := 0.05
var actor_stats: Dictionary = {}
var team_stats := {
	BLUE: {"kills": 0, "deaths": 0, "core_damage": 0.0, "hut_damage": 0.0, "huts_destroyed": 0, "stock_losses": 0, "deposits": 0, "breeds_completed": 0, "breeds_denied": 0, "wildlife_defeats": 0, "boss_claims": 0, "boss_steals": 0, "center_claims": 0},
	RED: {"kills": 0, "deaths": 0, "core_damage": 0.0, "hut_damage": 0.0, "huts_destroyed": 0, "stock_losses": 0, "deposits": 0, "breeds_completed": 0, "breeds_denied": 0, "wildlife_defeats": 0, "boss_claims": 0, "boss_steals": 0, "center_claims": 0}
}
var kill_feed: Array[Dictionary] = []
var match_summary_log_path := ""
var economy_events: Array[Dictionary] = []
var economy_event_sequence := 0
var economy_event_counts: Dictionary = {}
var economy_first_event_sec: Dictionary = {}
var economy_team_event_counts := {"blue": {}, "red": {}}
var economy_team_first_event_sec := {"blue": {}, "red": {}}
var balance_slot_telemetry: Dictionary = {}
var boss_lifecycle_events: Array[Dictionary] = []
var boss_lifecycle_event_sequence := 0
var terrain_map: RefCounted = TerrainMapScript.new()
var arena_rect := ARENA_RECT
var cover_rects: Array = []
var wave_interval := WAVE_INTERVAL
var wave_minion_offsets: Array = []
var blue_core_position := Vector2(-910.0, 0.0)
var red_core_position := Vector2(910.0, 0.0)
var blue_minion_spawn := Vector2(-760.0, 0.0)
var red_minion_spawn := Vector2(760.0, 0.0)
var team_spawns := {}
var bot_spawns := {}
var camera_zoom := Vector2(0.9, 0.9)
var hunger_full_to_empty_sec := CreatureScript.HUNGER_FULL_TO_EMPTY_SEC

var status_label: Label
var core_label: Label
var cooldown_label: Label
var ability_bar: Control
var info_panel: Control
var scoreboard_label: Label
var kill_feed_label: Label
var end_summary_label: Label
var help_label: Label
var squad_hud: Control = null
var match_result_panel: Control = null
var local_input: Node = LocalInputScript.new()
var bot_brain: RefCounted = BotBrainScript.new()
var match_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var stock_manager: RefCounted = StockManagerScript.new()
var slot_registry: RefCounted = MatchSlotRegistryScript.new()
var world_overlay_redraw_accumulator := 0.0
var legacy_mode_snapshot := ""
var match_rules: Dictionary = {}
var control_topology: Dictionary = {}
var last_input_routing_state: Dictionary = {}
var switch_release_mask := 0
var switch_action_neutral_ticks: Dictionary = {}
var team_world_view: RefCounted = LegalWorldViewScript.new()
var team_directors := {
	BLUE: TeamDirectorScript.new(),
	RED: TeamDirectorScript.new()
}
var team_orders := {BLUE: {}, RED: {}}
var team_director_timer := 0.0
var team_director_epoch := 0

func _ready() -> void:
	if not _configure_mode():
		return
	var terrain_layer = TerrainLayerScript.new()
	terrain_layer.name = "TerrainLayer"
	add_child(terrain_layer)
	terrain_layer.setup(terrain_map)
	var water_layer = WaterLayerScript.new()
	water_layer.name = "WaterLayer"
	add_child(water_layer)
	water_layer.setup(terrain_map)
	_build_ui()
	_setup_crosshair_cursor()
	if not _spawn_match():
		set_process(false)
		set_physics_process(false)

func _configure_mode() -> bool:
	legacy_mode_snapshot = String(GameConfig.selected_mode)
	if legacy_mode_snapshot == "Hero Lab":
		match_rules = MatchRulesScript.competitive_3v3()
		control_topology = {}
	else:
		var match_adapter := MatchRulesScript.for_legacy_mode(legacy_mode_snapshot)
		if match_adapter.is_empty():
			push_error("Unknown Battle Bog mode: %s" % legacy_mode_snapshot)
			get_tree().quit(2)
			return false
		match_rules = match_adapter.get("rules", {}).duplicate(true)
		control_topology = match_adapter.get("control_topology", {}).duplicate(true)
	var rule_errors := MatchRulesScript.validate_rules(match_rules)
	if not rule_errors.is_empty():
		push_error("Invalid Battle Bog rules: %s" % ", ".join(rule_errors))
		get_tree().quit(2)
		return false
	if _is_all_bots_mode():
		var simulation_errors: Array[String] = GameConfig.get_simulation_request_errors()
		if not simulation_errors.is_empty():
			push_error("Invalid All Bots simulation request: %s" % "; ".join(simulation_errors))
			get_tree().quit(2)
			return false

	terrain_map.configure(match_rules)
	arena_rect = terrain_map.arena_rect
	cover_rects = terrain_map.get_cover_rects()
	wave_minion_offsets = terrain_map.wave_minion_offsets
	blue_core_position = terrain_map.blue_core_position
	red_core_position = terrain_map.red_core_position
	blue_minion_spawn = terrain_map.blue_minion_spawn
	red_minion_spawn = terrain_map.red_minion_spawn
	team_spawns = terrain_map.team_spawns
	bot_spawns = terrain_map.bot_spawns

	if String(control_topology.get("id", "")) == MatchRulesScript.TOPOLOGY_SOLO_SWAP:
		camera_zoom = Vector2(2.6, 2.6)
	elif legacy_mode_snapshot == "Hero Lab":
		wave_interval = 18.0
		camera_zoom = Vector2(2.8, 2.8)
	else:
		camera_zoom = Vector2(2.2, 2.2)
	if legacy_mode_snapshot != "Hero Lab":
		wave_interval = float(match_rules.get("wave_interval_sec", WAVE_INTERVAL))
	hunger_full_to_empty_sec = float(match_rules.get("hunger_full_to_empty_sec", CreatureScript.HUNGER_FULL_TO_EMPTY_SEC))

	wave_timer = 2.0
	return true

func _physics_process(delta: float) -> void:
	if match_over:
		return
	simulation_tick += 1
	var perf_start := Time.get_ticks_usec() if PerfStats.enabled else 0

	hut_defend_hint_timer = maxf(hut_defend_hint_timer - delta, 0.0)
	habitat_deposit_feedback_timer = maxf(habitat_deposit_feedback_timer - delta, 0.0)
	if habitat_deposit_feedback_timer <= 0.0:
		habitat_deposit_prompt_state = ""
	squad_switch_feedback_timer = maxf(squad_switch_feedback_timer - delta, 0.0)
	if squad_switch_feedback_timer <= 0.0:
		squad_switch_feedback_state = ""
		squad_switch_feedback_slot_index = -1
	_tick_squad_command(delta)
	_tick_day_cycle(delta)
	_tick_breeding(delta)
	if PerfStats.enabled:
		PerfStats.add("arena_maintenance", int(Time.get_ticks_usec() - perf_start))
	var perf_routing_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	if _is_competitive_mode():
		var perf_director_start := Time.get_ticks_usec() if PerfStats.enabled else 0
		_tick_team_directors(delta)
		if PerfStats.enabled:
			PerfStats.add("team_directors", int(Time.get_ticks_usec() - perf_director_start))
		var perf_registered_input_start := Time.get_ticks_usec() if PerfStats.enabled else 0
		_feed_registered_inputs()
		if PerfStats.enabled:
			PerfStats.add("registered_inputs", int(Time.get_ticks_usec() - perf_registered_input_start))
	elif player != null and is_instance_valid(player):
		var player_frame: Resource = local_input.build_frame(player.get_global_mouse_position())
		player.set_input_frame(player_frame)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) and hut_defend_hint_timer <= 0.0 and _player_near_own_hut():
			hut_defend_hint_timer = 2.5
			add_kill_feed("Hut defense assignment needs a reserve habitat upgrade")
	var perf_bots_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	if not _is_competitive_mode():
		for bot in bots:
			if bot != null and is_instance_valid(bot) and bot.is_alive():
				bot.set_input_frame(bot_brain.build_frame(bot))
	if PerfStats.enabled:
		PerfStats.add("bot_frames", int(Time.get_ticks_usec() - perf_bots_start))
		PerfStats.add("arena_routing", int(Time.get_ticks_usec() - perf_routing_start))

	var perf_world_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	elapsed += delta
	_tick_center_boss_schedule()
	_tick_animal_zones(delta)
	_tick_boss_terrain_events(delta)
	_tick_team_vision(delta)
	if not _is_all_bots_mode():
		_apply_world_vision_masking()
	wave_timer -= delta
	_tick_telegraphs(delta)
	if not _is_all_bots_mode():
		_tick_kill_feed(delta)
	if wave_timer <= 0.0:
		spawn_wave()
		wave_timer = wave_interval
	if PerfStats.enabled:
		PerfStats.add("arena_world", int(Time.get_ticks_usec() - perf_world_start))

	if not _is_all_bots_mode():
		ui_refresh_accumulator += delta
		if ui_refresh_accumulator >= 0.2:
			ui_refresh_accumulator = 0.0
			_update_ui()
	var perf_separation_start := Time.get_ticks_usec() if PerfStats.enabled else 0
	resolve_body_separation()
	if PerfStats.enabled:
		PerfStats.add("arena_separation", int(Time.get_ticks_usec() - perf_separation_start))
		PerfStats.add("arena_tick", int(Time.get_ticks_usec() - perf_start))

func _process(delta: float) -> void:
	_update_camera_lead(delta)
	world_overlay_redraw_accumulator += delta
	if world_overlay_redraw_accumulator >= WORLD_OVERLAY_REDRAW_INTERVAL:
		world_overlay_redraw_accumulator = 0.0
		queue_redraw()

func uses_throttled_world_overlay_redraw() -> bool:
	return WORLD_OVERLAY_REDRAW_INTERVAL >= 0.05

func get_world_overlay_redraw_interval() -> float:
	return WORLD_OVERLAY_REDRAW_INTERVAL

func uses_diegetic_habitat_markers() -> bool:
	return true

func uses_diegetic_stock_reserve_tokens() -> bool:
	return true

func _update_camera_lead(delta: float) -> void:
	# Supervive-style cursor-led camera: past a deadzone, the view drifts a
	# fraction of the way toward the cursor so you can see where you aim.
	if camera == null or player == null or not is_instance_valid(player):
		return
	var to_cursor: Vector2 = player.get_global_mouse_position() - player.global_position
	var lead := Vector2.ZERO
	var cursor_distance := to_cursor.length()
	if cursor_distance > CAMERA_LEAD_DEADZONE:
		lead = to_cursor.normalized() * minf((cursor_distance - CAMERA_LEAD_DEADZONE) * CAMERA_LEAD_FRACTION, CAMERA_LEAD_MAX)
	camera.offset = camera.offset.lerp(lead, minf(delta * 7.0, 1.0))

func _draw() -> void:
	# Retired mid-objective holdover: Battle Bog's center belongs to
	# contested water while huts and habitats carry the match contract.
	_draw_animal_zones()
	_draw_terrain_event_overlays()
	_draw_world_info_markers()
	_draw_telegraphs()
	if DEBUG_HURTBOX_OVERLAY:
		_draw_hurtbox_debug_overlays()

	_draw_habitat_stock_visuals()
	_draw_breeding_cues()
	_draw_squad_badges()

func _setup_crosshair_cursor() -> void:
	var size := 25
	var center := size / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(1.0, 1.0, 1.0, 0.95)
	var dark := Color(0.05, 0.05, 0.05, 0.9)
	# Four cross ticks with a gap around the center, dark-edged for contrast.
	for offset in range(4, 11):
		for axis in 2:
			for direction: int in [-1, 1]:
				var x: int = center + (offset * direction if axis == 0 else 0)
				var y: int = center + (offset * direction if axis == 1 else 0)
				img.set_pixel(x, y, white)
				if axis == 0:
					img.set_pixel(x, y - 1, dark)
					img.set_pixel(x, y + 1, dark)
				else:
					img.set_pixel(x - 1, y, dark)
					img.set_pixel(x + 1, y, dark)
	# Center dot.
	img.set_pixel(center, center, white)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(center, center))

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 18.0
	root.offset_top = 14.0
	root.add_theme_constant_override("separation", 6)
	canvas.add_child(root)

	status_label = Label.new()
	core_label = Label.new()
	cooldown_label = Label.new()
	scoreboard_label = Label.new()
	kill_feed_label = Label.new()
	end_summary_label = Label.new()
	help_label = Label.new()
	# Full controls + ability text live in the hold-P panel now (UI pass);
	# the old cooldown text line is superseded by the ability bar but kept
	# updated (hidden) for check-script compatibility.
	help_label.text = "hold P - creature info & controls"
	cooldown_label.visible = false

	root.add_child(status_label)
	root.add_child(core_label)
	root.add_child(cooldown_label)
	root.add_child(scoreboard_label)
	root.add_child(kill_feed_label)
	root.add_child(end_summary_label)
	root.add_child(help_label)

	var minimap := MinimapScript.new()
	minimap.name = "Minimap"
	minimap.arena = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -252.0
	minimap.offset_top = 14.0
	minimap.offset_right = -14.0
	minimap.offset_bottom = 160.0
	canvas.add_child(minimap)

	ability_bar = AbilityBarScript.new()
	ability_bar.arena = self
	ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ability_bar.offset_left = -300.0
	ability_bar.offset_right = 300.0
	ability_bar.offset_top = -78.0
	ability_bar.offset_bottom = -14.0
	canvas.add_child(ability_bar)

	info_panel = CreatureInfoPanelScript.new()
	info_panel.arena = self
	info_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	info_panel.offset_left = 24.0
	info_panel.offset_top = -220.0
	info_panel.offset_right = 560.0
	info_panel.offset_bottom = 220.0
	canvas.add_child(info_panel)

	var perf_overlay := PerfOverlayScript.new()
	perf_overlay.arena = self
	perf_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	perf_overlay.offset_left = -420.0
	perf_overlay.offset_top = -34.0
	perf_overlay.offset_right = -14.0
	perf_overlay.offset_bottom = -14.0
	canvas.add_child(perf_overlay)

	squad_hud = SquadHudScript.new()
	squad_hud.set("arena", self)
	squad_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	squad_hud.offset_left = 18.0
	squad_hud.offset_top = -194.0
	squad_hud.offset_right = 410.0
	squad_hud.offset_bottom = -18.0
	canvas.add_child(squad_hud)

	match_result_panel = MatchResultPanelScript.new()
	match_result_panel.name = "MatchResultPanel"
	match_result_panel.set("arena", self)
	canvas.add_child(match_result_panel)

func _spawn_match() -> bool:
	_seed_match_rng()
	simulation_tick = 0
	_reset_match_telemetry()
	_clear_breeding_actors()
	stock_manager.reset()
	slot_registry.reset(int(match_rules.get("team_size", 3)))
	team_orders = {BLUE: {}, RED: {}}
	team_director_timer = 0.0
	team_director_epoch = 0
	for director in team_directors.values():
		director.reset_team(BLUE)
		director.reset_team(RED)
	if _is_competitive_mode() and not stock_manager.configure_required_slots(
		int(match_rules.get("team_size", 3)),
		int(match_rules.get("initial_stocks_per_slot", StockManagerScript.MAX_STOCKS))
	):
		push_error("Could not configure competitive stock slots: %s" % str(stock_manager.validation_errors()))
		return false
	_reset_breeding_buffs()
	day_index = 1
	day_timer = 0.0
	_setup_animal_zones()
	if GameConfig.wake_boss:
		_debug_wake_all_bosses.call_deferred()
	if GameConfig.center_boss:
		debug_spawn_center_boss.call_deferred()

	var blue_core = CoreScript.new()
	add_child(blue_core)
	blue_core.setup(BLUE, blue_core_position)
	blue_core.destroyed.connect(_on_core_destroyed)
	cores[BLUE] = blue_core

	var red_core = CoreScript.new()
	add_child(red_core)
	red_core.setup(RED, red_core_position)
	red_core.destroyed.connect(_on_core_destroyed)
	cores[RED] = red_core

	for hut_team in terrain_map.hut_positions.keys():
		var lane_list: Array = terrain_map.hut_positions[hut_team]
		for lane_index in lane_list.size():
			var hut = MudHutScript.new()
			add_child(hut)
			hut.setup(self, int(hut_team), lane_index, lane_list[lane_index])
			huts.append(hut)
			register_entity(hut)

	if _is_all_bots_mode():
		if not _spawn_all_bot_squads():
			return false
	elif _is_1v1_trio_mode():
		if not _spawn_player_squad():
			return false
	else:
		player = CreatureScript.new()
		add_child(player)
		player.setup(self, BLUE, get_team_spawn(BLUE), GameConfig.selected_creature_id, terrain_map)
		if _is_competitive_mode() and not _register_competitive_slot(
			BLUE,
			0,
			GameConfig.selected_creature_id,
			player,
			MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN
		):
			return false
		register_entity(player)
	if not _spawn_bots_for_mode():
		return false
	if _is_competitive_mode() and not _seal_competitive_slots():
		return false

	camera = Camera2D.new()
	camera.zoom = camera_zoom
	camera.position_smoothing_enabled = true
	_attach_camera_to_player()

	_refresh_food_sources()
	spawn_wave()
	_update_ui()
	return true

func _spawn_bots_for_mode() -> bool:
	if _is_all_bots_mode():
		return true
	if legacy_mode_snapshot == "3v3":
		var ally_pool := _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		ally_pool.erase(GameConfig.selected_creature_id)
		var enemy_pool := _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		var blue_guard := _spawn_bot(BLUE, ally_pool[0], get_bot_spawn(BLUE, "Blue Guard"), "Blue Guard")
		var blue_ward := _spawn_bot(BLUE, ally_pool[1], get_bot_spawn(BLUE, "Blue Ward"), "Blue Ward")
		var red_blade := _spawn_bot(RED, enemy_pool[0], get_bot_spawn(RED, "Red Blade"), "Red Blade")
		var red_scope := _spawn_bot(RED, enemy_pool[1], get_bot_spawn(RED, "Red Scope"), "Red Scope")
		var red_chorus := _spawn_bot(RED, enemy_pool[2], get_bot_spawn(RED, "Red Chorus"), "Red Chorus")
		if not _register_competitive_slot(BLUE, 1, ally_pool[0], blue_guard, MatchSlotRegistryScript.CONTROLLER_AI):
			return false
		if not _register_competitive_slot(BLUE, 2, ally_pool[1], blue_ward, MatchSlotRegistryScript.CONTROLLER_AI):
			return false
		if not _register_competitive_slot(RED, 0, enemy_pool[0], red_blade, MatchSlotRegistryScript.CONTROLLER_AI):
			return false
		if not _register_competitive_slot(RED, 1, enemy_pool[1], red_scope, MatchSlotRegistryScript.CONTROLLER_AI):
			return false
		if not _register_competitive_slot(RED, 2, enemy_pool[2], red_chorus, MatchSlotRegistryScript.CONTROLLER_AI):
			return false
	elif _is_1v1_trio_mode():
		var configured_red: Array[String] = (
			GameConfig.get_selected_red_squad_ids()
			if GameConfig.has_method("get_selected_red_squad_ids")
			else []
		)
		var enemy_pool: Array = (
			configured_red
			if configured_red.size() == 3
			else _shuffled_creature_pool(PLAYABLE_CREATURE_POOL)
		)
		var red_spawn := get_team_spawn(RED)
		var red_names := ["Red Claw", "Red Reed", "Red Fang"]
		for i in 3:
			var bot := _spawn_bot(RED, enemy_pool[i], red_spawn + _squad_spawn_offset(i, RED), red_names[i])
			if not _register_competitive_slot(RED, i, enemy_pool[i], bot, MatchSlotRegistryScript.CONTROLLER_AI):
				return false
	else:
		_spawn_bot(RED, PLAYABLE_CREATURE_POOL[match_rng.randi_range(0, PLAYABLE_CREATURE_POOL.size() - 1)], get_bot_spawn(RED, "Red Rival"), "Red Rival")
	return true

func _is_1v1_trio_mode() -> bool:
	return String(control_topology.get("id", "")) == MatchRulesScript.TOPOLOGY_SOLO_SWAP

func _is_all_bots_mode() -> bool:
	return String(control_topology.get("id", "")) == MatchRulesScript.TOPOLOGY_ALL_BOTS

func _is_competitive_mode() -> bool:
	return String(match_rules.get("id", "")) == MatchRulesScript.RULESET_COMPETITIVE_3V3 and not control_topology.is_empty()

func _register_competitive_slot(team: int, slot_index: int, creature_id: String, actor: Node, controller_kind: String) -> bool:
	var controller_id := "local:0" if controller_kind == MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN else "ai:%d:%d" % [team, slot_index]
	if not slot_registry.register_slot(team, slot_index, creature_id, actor):
		push_error("Slot registration failed for %d:%d: %s" % [team, slot_index, str(slot_registry.validation_errors())])
		return false
	var owner_id := "local:0" if team == BLUE and _is_1v1_trio_mode() else "team:%d" % team
	if not slot_registry.assign_owner(team, slot_index, owner_id):
		push_error("Owner registration failed for %d:%d: %s" % [team, slot_index, str(slot_registry.validation_errors())])
		return false
	if not slot_registry.assign_ai_fallback(team, slot_index, "ai:%d:%d" % [team, slot_index]):
		push_error("AI fallback registration failed for %d:%d: %s" % [team, slot_index, str(slot_registry.validation_errors())])
		return false
	if not slot_registry.assign_controller(team, slot_index, controller_kind, controller_id):
		push_error("Controller registration failed for %d:%d: %s" % [team, slot_index, str(slot_registry.validation_errors())])
		return false
	if not stock_manager.register_slot(team, slot_index, creature_id, actor):
		push_error("Stock registration failed for %d:%d: %s" % [team, slot_index, str(stock_manager.validation_errors())])
		return false
	return true

func _seal_competitive_slots() -> bool:
	var slot_errors: Array[String] = slot_registry.seal()
	var stock_errors: Array[String] = stock_manager.seal_registration()
	var topology_errors := _controller_plan_errors()
	if not slot_errors.is_empty() or not stock_errors.is_empty() or not topology_errors.is_empty():
		push_error("Competitive slot seal failed: slots=%s stocks=%s topology=%s" % [str(slot_errors), str(stock_errors), str(topology_errors)])
		return false
	return true

func _controller_plan_errors() -> Array[String]:
	var errors: Array[String] = []
	var plan: Array[Dictionary] = slot_registry.get_controller_plan()
	var expected_total := int(match_rules.get("team_size", 3)) * 2
	var local_count := 0
	var ai_count := 0
	for assignment: Dictionary in plan:
		match String(assignment.get("kind", "")):
			MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN:
				local_count += 1
			MatchSlotRegistryScript.CONTROLLER_AI:
				ai_count += 1
	if plan.size() != expected_total:
		errors.append("expected %d controller assignments, got %d" % [expected_total, plan.size()])
	if local_count != int(control_topology.get("active_human_slots", -1)):
		errors.append("local controller count does not match topology")
	if ai_count != int(control_topology.get("ai_controlled_slots", -1)):
		errors.append("AI controller count does not match topology")
	return errors

func get_match_slot_state() -> Dictionary:
	return {
		"sealed": slot_registry.is_sealed(),
		"stock_sealed": stock_manager.is_registration_sealed(),
		"blue": slot_registry.get_team_slots(BLUE),
		"red": slot_registry.get_team_slots(RED),
		"controllers": slot_registry.get_controller_plan()
	}

func _tick_team_directors(delta: float) -> void:
	if not slot_registry.is_sealed():
		return
	team_director_timer = maxf(team_director_timer - delta, 0.0)
	if team_director_timer > 0.0:
		return
	team_director_timer = TeamDirectorScript.UPDATE_INTERVAL_SEC
	team_director_epoch += 1
	for team in [BLUE, RED]:
		var team_id := int(team)
		var snapshot: Dictionary = team_world_view.team_snapshot(
			self,
			team_id,
			slot_registry,
			team_director_epoch,
			_team_player_override(team_id)
		)
		team_orders[team_id] = team_directors[team_id].update(snapshot)

func _team_player_override(team: int) -> Dictionary:
	if team != BLUE or not _is_1v1_trio_mode() or squad_command == SQUAD_COMMAND_FARM:
		return {"kind": "none"}
	var player_slot: Dictionary = slot_registry.get_slot_for_actor(player)
	var override := {
		"kind": squad_command,
		"follow_slot_id": String(player_slot.get("slot_id", "")),
		"aggro_slot_id": "",
		"destination": player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO,
		"hold_radius": SQUAD_FOLLOW_RADIUS
	}
	if squad_command == SQUAD_COMMAND_AGGRO \
		and squad_aggro_target != null \
		and is_instance_valid(squad_aggro_target):
		var target_slot: Dictionary = slot_registry.get_slot_for_actor(squad_aggro_target)
		override["aggro_slot_id"] = String(target_slot.get("slot_id", ""))
	return override

func get_team_order_state(team := -1) -> Dictionary:
	if team == BLUE or team == RED:
		return team_orders.get(team, {}).duplicate(true)
	return {
		BLUE: team_orders.get(BLUE, {}).duplicate(true),
		RED: team_orders.get(RED, {}).duplicate(true),
		"epoch": team_director_epoch
	}

func get_actor_for_slot_id(slot_id: String) -> Node:
	for team in [BLUE, RED]:
		for slot: Dictionary in slot_registry.get_team_slots(int(team)):
			if String(slot.get("slot_id", "")) == slot_id:
				var actor: Node = slot.get("actor", null)
				return actor if actor != null and is_instance_valid(actor) else null
	return null

func get_live_objective_actor(objective_id: String) -> Node:
	for encounter: Node in wildlife_encounters:
		if encounter == null or not is_instance_valid(encounter):
			continue
		if String(encounter.get("zone_id")) != objective_id:
			continue
		if not encounter.has_method("is_boss_actor") or not encounter.is_boss_actor():
			continue
		if encounter.has_method("is_alive") and not encounter.is_alive():
			continue
		return encounter
	return null

func get_hunger_full_to_empty_sec() -> float:
	return hunger_full_to_empty_sec

func get_team_habitat_rect(team: int) -> Rect2:
	return terrain_map.get_team_habitat_rect(team)

func get_squad_follow_radius() -> float:
	return SQUAD_FOLLOW_RADIUS

func get_trio_hud_rows(team: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not _is_1v1_trio_mode() or stock_manager == null or not stock_manager.has_method("get_team_slots"):
		return rows
	for slot: Dictionary in stock_manager.get_team_slots(team):
		rows.append(_build_trio_hud_row(slot))
	return rows

func get_squad_hud_data() -> Dictionary:
	return {
		"enabled": _is_1v1_trio_mode(),
		"own_team": BLUE,
		"enemy_team": RED,
		"command": squad_command,
		"command_timer": squad_command_timer,
		"own": get_trio_hud_rows(BLUE),
		"enemy": get_trio_hud_rows(RED),
		"own_buffs": get_team_breeding_buff_state(BLUE),
		"enemy_buffs": get_team_breeding_buff_state(RED),
		"breeding": get_breeding_queue_state(BLUE),
		"boss_objective": get_boss_objective_brief(BLUE),
		"switch_feedback": get_squad_switch_feedback_state(),
		"deposit_prompt": get_deposit_prompt_state()
	}

func get_squad_switch_feedback_state() -> Dictionary:
	return {
		"state": squad_switch_feedback_state if squad_switch_feedback_timer > 0.0 else "idle",
		"slot_index": squad_switch_feedback_slot_index,
		"timer": squad_switch_feedback_timer
	}

func get_deposit_prompt_state() -> Dictionary:
	var state := "hidden"
	var visible := false
	var in_home := false
	var near_home := false
	if _is_1v1_trio_mode() and player != null and is_instance_valid(player) and player.has_method("is_alive") and player.is_alive():
		in_home = _is_actor_in_home_habitat(player)
		var rect: Rect2 = terrain_map.get_team_habitat_rect(player.team)
		near_home = in_home or (rect.size.x > 0.0 and rect.size.y > 0.0 and rect.grow(96.0).has_point(player.global_position))
		if habitat_deposit_feedback_timer > 0.0 and not habitat_deposit_prompt_state.is_empty():
			state = habitat_deposit_prompt_state
		elif in_home:
			state = "ready" if not player.has_method("is_satiated") or player.is_satiated() else "needs_food"
		elif near_home:
			state = "near"
		visible = state != "hidden"
	return {
		"state": state,
		"visible": visible,
		"timer": habitat_deposit_feedback_timer,
		"in_home_habitat": in_home,
		"near_home_habitat": near_home
	}

func get_breeding_queue_state(team: int) -> Dictionary:
	if stock_manager == null or not stock_manager.has_method("get_breeding_cues"):
		return {"active": false, "count": 0}
	var cues: Array = stock_manager.get_breeding_cues(team)
	var next_cue: Dictionary = {}
	var next_remaining := INF
	for cue_value in cues:
		if typeof(cue_value) != TYPE_DICTIONARY:
			continue
		var cue: Dictionary = cue_value
		var remaining := float(cue.get("remaining", StockManagerScript.BREEDING_DURATION_SEC))
		if remaining < next_remaining:
			next_remaining = remaining
			next_cue = cue
	if next_cue.is_empty():
		return {"active": false, "count": 0}
	var duration := maxf(float(next_cue.get("duration", StockManagerScript.BREEDING_DURATION_SEC)), 0.01)
	var remaining := clampf(float(next_cue.get("remaining", duration)), 0.0, duration)
	return {
		"active": true,
		"count": cues.size(),
		"next_remaining": remaining,
		"next_duration": duration,
		"next_ratio": 1.0 - remaining / duration,
		"next_creature_id": String(next_cue.get("creature_id", "")),
		"next_family": String(next_cue.get("family", "")),
		"next_slot_index": int(next_cue.get("slot_index", -1))
	}

func get_animal_zone_state(side := "") -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	for zone: Dictionary in animal_zone_states:
		if not String(side).is_empty() and String(zone.get("side", "")) != String(side):
			continue
		zones.append(zone.duplicate(true))
	return zones

func get_boss_progress_state() -> Dictionary:
	return {
		"bred_count": bred_animal_count,
		"interval": BOSS_BREED_INTERVAL,
		"toward_next": bred_animal_count % BOSS_BREED_INTERVAL,
		"activations": boss_activation_count,
		"boss_active": _boss_zones_active(),
		"teams": {
			BLUE: get_side_boss_state(BLUE),
			RED: get_side_boss_state(RED)
		}
	}

func get_boss_objective_brief(team: int) -> Dictionary:
	var clean_team := team if team == BLUE or team == RED else BLUE
	return {
		"team": clean_team,
		"side": _side_boss_objective_brief(clean_team),
		"enemy_side": _side_boss_objective_brief(_enemy_team(clean_team)),
		"center": _center_boss_objective_brief(),
		"boss_stock": get_team_boss_stock_summary(clean_team),
		"combat_rewards": get_team_combat_reward_state(clean_team)
	}

func _side_boss_objective_brief(team: int) -> Dictionary:
	var state := get_side_boss_state(team)
	var meter := int(state.get("meter", 0))
	var interval := maxi(int(state.get("interval", BOSS_BREED_INTERVAL)), 1)
	var objective_state := String(state.get("objective_state", "dormant"))
	var active := bool(state.get("active", false))
	var meter_locked := is_side_boss_meter_locked(team)
	var current_family := String(state.get("family", ""))
	var next_family := String(state.get("next_family", ""))
	var family := current_family if not current_family.is_empty() else next_family
	var action := _boss_objective_action(objective_state, active, "breed")
	var route_team := int(state.get("claim_team", -1))
	if route_team < 0:
		route_team = int(state.get("control_team", -1))
	return {
		"team": team,
		"state": objective_state,
		"active": active,
		"family": family,
		"next_family": next_family,
		"meter": meter,
		"interval": interval,
		"meter_ratio": clampf(float(meter) / float(interval), 0.0, 1.0),
		"meter_locked": meter_locked,
		"claim_ratio": float(state.get("claim_ratio", 0.0)),
		"claim_team": int(state.get("claim_team", -1)),
		"control_team": int(state.get("control_team", -1)),
		"contested": bool(state.get("contested", false)),
		"claim_route": _side_boss_claim_route(team, route_team),
		"action": action
	}

func _center_boss_objective_brief() -> Dictionary:
	var state := get_center_boss_state()
	var schedule := _next_center_boss_schedule_brief()
	var active := bool(state.get("active", false))
	var objective_state := String(state.get("objective_state", "active" if active else "dormant"))
	var action := _boss_objective_action(objective_state, active, "wait")
	if action == "wait" and int(schedule.get("index", -1)) < 0:
		action = "complete"
	return {
		"active": active,
		"state": objective_state,
		"family": String(state.get("family", "")),
		"size_mult": float(state.get("size_mult", 0.0)),
		"claim_ratio": float(state.get("claim_ratio", 0.0)),
		"claim_team": int(state.get("claim_team", -1)),
		"control_team": int(state.get("control_team", -1)),
		"contested": bool(state.get("contested", false)),
		"next_spawn_index": int(schedule.get("index", -1)),
		"next_spawn_time": float(schedule.get("time", -1.0)),
		"next_spawn_in": -1.0 if active else float(schedule.get("in", -1.0)),
		"claim_route": "center_combat_reward" if action in ["claim", "contest", "claimed"] else "none",
		"action": action
	}

func _boss_objective_action(objective_state: String, active: bool, dormant_action: String) -> String:
	match objective_state:
		"active":
			return "fight"
		"claimable":
			return "claim"
		"contesting":
			return "contest"
		"claimed", "stolen":
			return "claimed"
	return "fight" if active else dormant_action

func _side_boss_claim_route(owner_team: int, route_team: int) -> String:
	if route_team < 0:
		return "none"
	return "owner_stock_disrupt" if route_team == owner_team else "steal_stock_only"

func _next_center_boss_schedule_brief() -> Dictionary:
	for i in CENTER_BOSS_TIMES.size():
		if not bool(center_boss_fired[i]):
			var spawn_time := float(CENTER_BOSS_TIMES[i])
			return {
				"index": i,
				"time": spawn_time,
				"in": maxf(spawn_time - elapsed, 0.0)
			}
	return {"index": -1, "time": -1.0, "in": -1.0}

func get_side_boss_state(team: int) -> Dictionary:
	var idx := int(side_boss_index.get(team, 0))
	var zone := _team_boss_zone(team)
	return {
		"team": team,
		"meter": int(side_boss_meter.get(team, 0)),
		"interval": BOSS_BREED_INTERVAL,
		"activations": int(side_boss_activations.get(team, 0)),
		"next_family": String(SIDE_BOSS_ORDER[idx % SIDE_BOSS_ORDER.size()]),
		"active": _team_has_active_side_boss(team),
		"objective_state": String(zone.get("objective_state", "dormant")),
		"family": String(zone.get("boss_family", "")),
		"claim_progress": float(zone.get("claim_progress", 0.0)),
		"claim_ratio": clampf(float(zone.get("claim_progress", 0.0)) / BOSS_CLAIM_DURATION, 0.0, 1.0),
		"claim_team": int(zone.get("claim_team", -1)),
		"claimed_team": int(zone.get("claimed_team", -1)),
		"contested": bool(zone.get("contested", false)),
		"control_team": int(zone.get("control_team", -1))
	}

func get_team_breeding_buff_summary(team: int) -> Dictionary:
	var family_counts := _team_breeding_stack_map(team)
	return {
		"team": team,
		"total_stacks": _team_breeding_stack_count(team),
		"family_counts": family_counts.duplicate(true),
		"effects": _team_breeding_effects(team)
	}

func get_team_breeding_buff_state(team := -1) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for team_id in [BLUE, RED]:
		if team >= 0 and team_id != team:
			continue
		var family_counts := _team_breeding_stack_map(team_id)
		for family in BREEDING_BUFF_FAMILIES:
			var count := int(family_counts.get(family, 0))
			if count <= 0:
				continue
			states.append({
				"team": team_id,
				"family": family,
				"label": String(BREEDING_BUFF_LABEL_BY_FAMILY.get(family, family.to_upper())),
				"effect": String(BREEDING_BUFF_EFFECT_BY_FAMILY.get(family, "")),
				"count": count,
				"value": float(count) * BREEDING_STACK_VALUE
			})
	return states

func get_team_breeding_effect(team: int, effect: String) -> float:
	return float(_team_breeding_effects(team).get(effect, 0.0))

func _setup_animal_zones() -> void:
	_clear_wildlife_encounters()
	animal_zone_states.clear()
	bred_animal_count = 0
	boss_activation_count = 0
	side_boss_meter = {BLUE: 0, RED: 0}
	side_boss_activations = {BLUE: 0, RED: 0}
	side_boss_index = {BLUE: 0, RED: 0}
	_reset_boss_stock_buffs()
	active_terrain_events.clear()
	center_boss_fired = [false, false]
	center_boss_spawn_count = 0
	team_combat_rewards = {BLUE: {}, RED: {}}
	team_kill_growth_stacks = {BLUE: 0, RED: 0}
	animal_zone_tick_timer = 0.0
	var terrain_zones: Array = terrain_map.get_animal_zones() if terrain_map.has_method("get_animal_zones") else []
	for source_zone in terrain_zones:
		var zone: Dictionary = source_zone
		var is_boss := bool(zone.get("boss", false))
		var state := zone.duplicate(true)
		state["id"] = "%s:%s" % [String(zone.get("side", "")), String(zone.get("group", ""))]
		state["active"] = not is_boss
		state["objective_state"] = "dormant" if is_boss else "active"
		state["activation_count"] = 0
		state["occupants"] = _spawn_zone_occupants(state)
		state["spawned_count"] = (state["occupants"] as Array).size()
		state["alive_occupants"] = []
		state["alive_count"] = 0
		state["defeated_count"] = 0
		state["blue_defeats"] = 0
		state["red_defeats"] = 0
		state["last_defeat_team"] = -1
		state["cleared_team"] = -1
		state["wildlife_count"] = 0
		state["blue_count"] = 0
		state["red_count"] = 0
		state["contested"] = false
		state["control_team"] = -1
		state["last_control_team"] = -1
		state["claim_progress"] = 0.0
		state["claim_team"] = -1
		state["claimed_team"] = -1
		_spawn_wildlife_for_zone(state)
		animal_zone_states.append(state)
	_tick_animal_zones(ANIMAL_ZONE_TICK_SEC)

func _spawn_zone_occupants(zone: Dictionary) -> Array:
	if bool(zone.get("boss", false)):
		return _boss_zone_occupants(zone) if bool(zone.get("active", false)) else []
	var creatures: Array = zone.get("creatures", [])
	return creatures.duplicate()

func _boss_zone_occupants(zone: Dictionary) -> Array:
	var side := String(zone.get("side", "neutral"))
	var activation := int(zone.get("activation_count", 0))
	return ["%s_boss_%d" % [side, maxi(activation, 1)]]

func _tick_breeding(delta: float) -> void:
	var completed_cues: Array = stock_manager.tick_breeding_cues(delta)
	for cue: Dictionary in completed_cues:
		_clear_breeding_actor_for_cue(String(cue.get("id", "")))
		_complete_breeding_cue(cue)

func _spawn_breeding_actor_for_cue(cue: Dictionary) -> void:
	var cue_id := String(cue.get("id", ""))
	if cue_id.is_empty() or _breeding_actor_for_cue(cue_id) != null:
		return
	var actor = BreedingActorScript.new()
	add_child(actor)
	actor.setup(self, cue, _breeding_cue_position(cue))
	breeding_actors.append(actor)
	register_entity(actor)

func _breeding_actor_for_cue(cue_id: String) -> Node:
	for actor in breeding_actors:
		if actor != null and is_instance_valid(actor) and String(actor.get("cue_id")) == cue_id:
			return actor
	return null

func _clear_breeding_actor_for_cue(cue_id: String) -> void:
	for i in range(breeding_actors.size() - 1, -1, -1):
		var actor: Node = breeding_actors[i]
		if actor == null or not is_instance_valid(actor):
			breeding_actors.remove_at(i)
			continue
		if String(actor.get("cue_id")) != cue_id:
			continue
		unregister_entity(actor)
		breeding_actors.remove_at(i)
		actor.queue_free()

func _clear_breeding_actors() -> void:
	for actor in breeding_actors:
		if actor != null and is_instance_valid(actor):
			unregister_entity(actor)
			actor.queue_free()
	breeding_actors.clear()

func on_breeding_actor_defeated(actor: Node, source_actor: Node = null) -> void:
	if actor == null:
		return
	var cue_id := String(actor.get("cue_id"))
	var cue: Dictionary = stock_manager.remove_breeding_cue(cue_id)
	if source_actor != null and is_instance_valid(source_actor) and source_actor.get("team") != null:
		_record_team_actor_stat(int(source_actor.team), "breeds_denied", 1, source_actor)
	breeding_actors.erase(actor)
	unregister_entity(actor)
	var attacker_name: String = source_actor.get_actor_name() if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("get_actor_name") else "Raiders"
	var defender_team := _team_name(int(actor.get("team")))
	var creature_id := String(cue.get("creature_id", actor.get("creature_id")))
	add_kill_feed("%s denied %s %s breeding" % [attacker_name, defender_team, creature_id.replace("_", " ")])

func is_breeding_actor_targetable(actor: Node) -> bool:
	return actor != null and is_instance_valid(actor) and is_habitat_exposed(int(actor.get("team")))

func can_damage_breeding_actor(actor: Node, source_actor: Node) -> bool:
	if actor == null or source_actor == null or not is_instance_valid(actor) or not is_instance_valid(source_actor):
		return false
	if not ("team" in actor) or not ("team" in source_actor):
		return false
	var defending_team := int(actor.get("team"))
	if int(source_actor.get("team")) == defending_team:
		return false
	if not is_habitat_exposed(defending_team):
		return false
	var habitat: Rect2 = terrain_map.get_team_habitat_rect(defending_team)
	return habitat.size.x > 0.0 and habitat.size.y > 0.0 and habitat.has_point(source_actor.global_position)

func show_breeding_actor_shielded(actor: Node, _source_actor: Node = null) -> void:
	if actor == null or not is_instance_valid(actor) or hut_defend_hint_timer > 0.0:
		return
	hut_defend_hint_timer = 0.8
	var text := "BREEDING SHIELDED" if not is_habitat_exposed(int(actor.get("team"))) else "ENTER HABITAT TO RAID"
	telegraphs.append({
		"type": "float_text",
		"position": actor.global_position + Vector2(-30.0, -36.0),
		"text": text,
		"color": Color(0.85, 0.9, 1.0, 0.92),
		"size": 12,
		"duration": 0.9,
		"remaining": 0.9
	})

func _breeding_cue_position(cue: Dictionary) -> Vector2:
	var team := int(cue.get("team", BLUE))
	var habitat: Rect2 = terrain_map.get_team_habitat_rect(team)
	if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
		return get_team_spawn(team)
	var slot_index := int(cue.get("slot_index", 0))
	return habitat.get_center() + Vector2(0.0, (float(slot_index) - 1.0) * 32.0)

func _complete_breeding_cue(cue: Dictionary) -> void:
	var team := int(cue.get("team", -1))
	var family := String(cue.get("family", ""))
	var creature_id := String(cue.get("creature_id", "animal"))
	var result := _add_breeding_buff_stack(team, family)
	var cue_actor: Node = cue.get("actor", null)
	_record_team_actor_stat(team, "breeds_completed", 1, cue_actor)
	_record_economy_event(cue_actor, "breed_completed", {
		"team": team,
		"creature_id": creature_id,
		"family": family
	})
	_record_bred_animal(team)
	if bool(result.get("accepted", false)):
		add_kill_feed("%s breeding complete: %s +%d%% %s" % [
			_team_name(team),
			String(result.get("label", creature_id)),
			roundi(BREEDING_STACK_VALUE * 100.0),
			String(result.get("effect", "buff")).replace("_", " ")
		])
	else:
		add_kill_feed("%s breeding complete: buff cap held %s" % [_team_name(team), creature_id])

func _add_breeding_buff_stack(team: int, family: String) -> Dictionary:
	var clean_family := family.to_lower()
	if team != BLUE and team != RED:
		return {"accepted": false, "reason": "invalid_team", "team": team, "family": clean_family}
	if not BREEDING_BUFF_FAMILIES.has(clean_family):
		return {"accepted": false, "reason": "unknown_family", "team": team, "family": clean_family}
	var current_total := _team_breeding_stack_count(team)
	var family_counts := _team_breeding_stack_map(team)
	var current_family := int(family_counts.get(clean_family, 0))
	if current_total >= BREEDING_TEAM_CAP:
		return {"accepted": false, "reason": "team_cap", "team": team, "family": clean_family, "total": current_total}
	if current_family >= BREEDING_FAMILY_CAP:
		return {"accepted": false, "reason": "family_cap", "team": team, "family": clean_family, "count": current_family}
	family_counts[clean_family] = current_family + 1
	team_breeding_buffs[team] = family_counts
	_refresh_team_breeding_buffs(team)
	return {
		"accepted": true,
		"team": team,
		"family": clean_family,
		"label": String(BREEDING_BUFF_LABEL_BY_FAMILY.get(clean_family, clean_family.to_upper())),
		"effect": String(BREEDING_BUFF_EFFECT_BY_FAMILY.get(clean_family, "")),
		"count": current_family + 1,
		"total": current_total + 1,
		"value": BREEDING_STACK_VALUE
	}

func _team_side_string(team: int) -> String:
	return "blue" if team == BLUE else "red"

func _team_has_active_side_boss(team: int) -> bool:
	var side := _team_side_string(team)
	for zone: Dictionary in animal_zone_states:
		if bool(zone.get("boss", false)) and String(zone.get("side", "")) == side and bool(zone.get("active", false)):
			return true
	return false

func is_side_boss_meter_locked(team: int) -> bool:
	if team != BLUE and team != RED:
		return false
	var zone := _team_boss_zone(team)
	if zone.is_empty():
		return false
	return bool(zone.get("active", false)) \
		or String(zone.get("objective_state", "dormant")) in ["active", "claimable", "contesting"]

func _team_boss_zone(team: int) -> Dictionary:
	var side := _team_side_string(team)
	for zone: Dictionary in animal_zone_states:
		if bool(zone.get("boss", false)) and String(zone.get("side", "")) == side:
			return zone
	return {}

func debug_wake_boss(team: int) -> void:
	# Dev affordance: instantly wake a team's side boss (forces Champsosaurus so
	# feel-testing is repeatable). Reachable via --bb-wake-boss or the F9 key.
	if not (team == BLUE or team == RED):
		return
	side_boss_index[team] = 0
	_activate_side_boss_for_team(team)
	add_kill_feed("[dev] woke %s side boss" % _team_name(team))

func _debug_wake_all_bosses() -> void:
	debug_wake_boss(BLUE)
	debug_wake_boss(RED)

func debug_spawn_center_boss() -> void:
	# Dev affordance: spawn the center big boss now (skips the 10:00 wait). Reachable via
	# --bb-center-boss or the F10 key. No-op while one is already live.
	if _center_boss_zone_index() >= 0:
		return
	_spawn_center_boss(_roll_center_boss_family())
	add_kill_feed("[dev] summoned center boss")

func _record_bred_animal(team: int, _actor: Node = null) -> void:
	bred_animal_count += 1
	if not (team == BLUE or team == RED):
		return
	if is_side_boss_meter_locked(team):
		return
	side_boss_meter[team] = int(side_boss_meter[team]) + 1
	if int(side_boss_meter[team]) >= BOSS_BREED_INTERVAL:
		_activate_side_boss_for_team(team)

func _reset_breeding_buffs() -> void:
	team_breeding_buffs = {
		BLUE: _empty_breeding_stack_map(),
		RED: _empty_breeding_stack_map()
	}

func _empty_breeding_stack_map() -> Dictionary:
	var stacks := {}
	for family in BREEDING_BUFF_FAMILIES:
		stacks[family] = 0
	return stacks

func _team_breeding_stack_map(team: int) -> Dictionary:
	if not team_breeding_buffs.has(team):
		team_breeding_buffs[team] = _empty_breeding_stack_map()
	return team_breeding_buffs[team]

func _team_breeding_stack_count(team: int) -> int:
	var total := 0
	var family_counts := _team_breeding_stack_map(team)
	for family in BREEDING_BUFF_FAMILIES:
		total += int(family_counts.get(family, 0))
	return total

func _team_breeding_effects(team: int) -> Dictionary:
	var effects := {
		"regen": 0.0,
		"max_health": 0.0,
		"move_speed": 0.0,
		"damage": 0.0,
		"ability_haste": 0.0
	}
	var family_counts := _team_breeding_stack_map(team)
	for family in BREEDING_BUFF_FAMILIES:
		var effect := String(BREEDING_BUFF_EFFECT_BY_FAMILY.get(family, ""))
		if effect.is_empty():
			continue
		effects[effect] = float(effects.get(effect, 0.0)) + float(family_counts.get(family, 0)) * BREEDING_STACK_VALUE
	return effects

func _refresh_team_breeding_buffs(team: int) -> void:
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if not ("team" in entity) or int(entity.get("team")) != team:
			continue
		if entity.has_method("refresh_team_breeding_buffs"):
			entity.refresh_team_breeding_buffs()

func _activate_side_boss_for_team(team: int) -> void:
	if not (team == BLUE or team == RED):
		return
	boss_activation_count += 1
	side_boss_activations[team] = int(side_boss_activations[team]) + 1
	side_boss_meter[team] = 0
	var family := String(SIDE_BOSS_ORDER[int(side_boss_index[team]) % SIDE_BOSS_ORDER.size()])
	side_boss_index[team] = (int(side_boss_index[team]) + 1) % SIDE_BOSS_ORDER.size()
	var side := _team_side_string(team)
	for i in animal_zone_states.size():
		var zone: Dictionary = animal_zone_states[i]
		if not bool(zone.get("boss", false)) or String(zone.get("side", "")) != side:
			continue
		_clear_wildlife_for_zone(String(zone.get("id", "")))
		zone["active"] = true
		zone["activation_count"] = int(zone.get("activation_count", 0)) + 1
		zone["occupants"] = _boss_zone_occupants(zone)
		zone["spawned_count"] = (zone["occupants"] as Array).size()
		zone["alive_occupants"] = []
		zone["alive_count"] = 0
		zone["defeated_count"] = 0
		zone["blue_defeats"] = 0
		zone["red_defeats"] = 0
		zone["last_defeat_team"] = -1
		zone["cleared_team"] = -1
		zone["last_bred_count"] = bred_animal_count
		zone["boss_family"] = family
		zone["objective_state"] = "active"
		zone["claim_progress"] = 0.0
		zone["claim_team"] = -1
		zone["claimed_team"] = -1
		zone["last_claim_notice"] = ""
		_spawn_wildlife_for_zone(zone)
		animal_zone_states[i] = zone
		_record_boss_lifecycle_event(zone, "active", -1, "dormant")
	add_objective_feed(
		"%s boss awakens: %s - fight in %s boss zone" % [_team_name(team), family.capitalize(), side],
		"fight",
		team,
		family,
		"%s:Boss" % side
	)

func _spawn_wildlife_for_zone(zone: Dictionary) -> void:
	if not bool(zone.get("active", false)):
		zone["alive_occupants"] = []
		zone["alive_count"] = 0
		zone["wildlife_count"] = 0
		return
	var occupants: Array = zone.get("occupants", [])
	var alive_occupants: Array = []
	for i in occupants.size():
		var species_id := String(occupants[i])
		var spawn_pos := _animal_zone_spawn_position(zone, i, occupants.size())
		var occupant: Node
		if bool(zone.get("boss", false)):
			occupant = _new_boss_actor(String(zone.get("boss_family", "")))
		else:
			occupant = WildlifeEncounterScript.new()
		add_child(occupant)
		occupant.setup(self, zone, species_id, spawn_pos, i)
		wildlife_encounters.append(occupant)
		register_entity(occupant)
		alive_occupants.append(species_id)
	zone["alive_occupants"] = alive_occupants
	zone["alive_count"] = alive_occupants.size()
	zone["wildlife_count"] = alive_occupants.size()

func _new_boss_actor(family: String) -> Node:
	match family:
		"champsosaurus":
			return ChampsosaurusBossScript.new()
		"teratornis":
			return TeratornisCenterBossScript.new()
		_:
			return BossActorScript.new()

func _animal_zone_spawn_position(zone: Dictionary, index: int, count: int) -> Vector2:
	var center: Vector2 = zone.get("center", Vector2.ZERO)
	if count <= 1:
		return center
	var radius: Vector2 = zone.get("radius", Vector2.ONE)
	var side_bias := 0.34 if String(zone.get("side", "")) == "blue" else -0.34
	var angle := TAU * (float(index) / float(count)) + side_bias
	var ring := 0.36 + float(index % 3) * 0.13
	return center + Vector2(cos(angle) * radius.x * ring, sin(angle) * radius.y * ring)

func _clear_wildlife_encounters() -> void:
	for encounter in wildlife_encounters:
		if encounter != null and is_instance_valid(encounter):
			unregister_entity(encounter)
			encounter.queue_free()
	wildlife_encounters.clear()

func _clear_wildlife_for_zone(target_zone_id: String) -> void:
	for i in range(wildlife_encounters.size() - 1, -1, -1):
		var encounter: Node = wildlife_encounters[i]
		if encounter == null or not is_instance_valid(encounter):
			wildlife_encounters.remove_at(i)
			continue
		if String(encounter.get("zone_id")) != target_zone_id:
			continue
		unregister_entity(encounter)
		wildlife_encounters.remove_at(i)
		encounter.queue_free()

func on_wildlife_defeated(encounter: Node, source_actor: Node = null) -> void:
	wildlife_encounters.erase(encounter)
	unregister_entity(encounter)
	var defeat_team := _wildlife_defeat_team(source_actor)
	_record_team_actor_stat(defeat_team, "wildlife_defeats", 1, source_actor)
	var zone_index := _animal_zone_index(String(encounter.get("zone_id")))
	if zone_index >= 0:
		var zone: Dictionary = animal_zone_states[zone_index]
		var alive_occupants: Array = zone.get("alive_occupants", []).duplicate()
		var species_id := String(encounter.get("species_id"))
		var occupant_index := alive_occupants.find(species_id)
		if occupant_index >= 0:
			alive_occupants.remove_at(occupant_index)
		zone["alive_occupants"] = alive_occupants
		zone["alive_count"] = alive_occupants.size()
		zone["wildlife_count"] = alive_occupants.size()
		zone["defeated_count"] = int(zone.get("defeated_count", 0)) + 1
		if defeat_team == BLUE:
			zone["blue_defeats"] = int(zone.get("blue_defeats", 0)) + 1
		elif defeat_team == RED:
			zone["red_defeats"] = int(zone.get("red_defeats", 0)) + 1
		if defeat_team >= 0:
			zone["last_defeat_team"] = defeat_team
		if alive_occupants.is_empty() and defeat_team >= 0:
			zone["cleared_team"] = defeat_team
		if bool(zone.get("boss", false)) and alive_occupants.is_empty():
			var previous_state := String(zone.get("objective_state", "active"))
			zone["active"] = false
			zone["objective_state"] = "claimable"
			_record_boss_lifecycle_event(zone, "claimable", defeat_team, previous_state)
			add_objective_feed(
				"%s downed - hold the boss zone to claim" % String(zone.get("boss_family", "boss")).capitalize(),
				"claim",
				_zone_owner_team(zone),
				String(zone.get("boss_family", "")),
				String(zone.get("id", ""))
			)
		animal_zone_states[zone_index] = zone
	var reward: Dictionary = _grant_wildlife_reward(encounter, source_actor)
	var source_name: String = source_actor.get_actor_name() if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("get_actor_name") else "A creature"
	var wildlife_name: String = encounter.get_actor_name() if encounter.has_method("get_actor_name") else "wildlife"
	var reward_text := " (+%d hunger)" % int(round(float(reward.get("hunger_gain", 0.0)))) if float(reward.get("hunger_gain", 0.0)) > 0.0 else ""
	add_kill_feed("%s drove off %s%s" % [source_name, wildlife_name, reward_text])

func _wildlife_defeat_team(source_actor: Node) -> int:
	if source_actor == null or not is_instance_valid(source_actor):
		return -1
	if not ("team" in source_actor):
		return -1
	return int(source_actor.get("team"))

func _grant_wildlife_reward(encounter: Node, source_actor: Node) -> Dictionary:
	if source_actor == null or not is_instance_valid(source_actor) or not source_actor.has_method("consume_food"):
		return {"accepted": false, "hunger_gain": 0.0}
	var before_hunger := float(source_actor.get("hunger")) if source_actor.get("hunger") != null else 0.0
	var hunger_reward := BOSS_WILDLIFE_HUNGER_REWARD if bool(encounter.get("boss")) else WILDLIFE_HUNGER_REWARD
	var heal_fraction := BOSS_WILDLIFE_HEAL_FRACTION if bool(encounter.get("boss")) else WILDLIFE_HEAL_FRACTION
	var accepted: bool = source_actor.consume_food(FoodSourceScript.KIND_CRITTER, hunger_reward, heal_fraction)
	var after_hunger := float(source_actor.get("hunger")) if source_actor.get("hunger") != null else before_hunger
	return {
		"accepted": accepted,
		"hunger_gain": maxf(after_hunger - before_hunger, 0.0),
		"hunger_reward": hunger_reward
	}

func _animal_zone_index(target_zone_id: String) -> int:
	for i in animal_zone_states.size():
		if String(animal_zone_states[i].get("id", "")) == target_zone_id:
			return i
	return -1

func _boss_zones_active() -> bool:
	for zone: Dictionary in animal_zone_states:
		if bool(zone.get("boss", false)) and bool(zone.get("active", false)):
			return true
	return false

func _tick_animal_zones(delta: float) -> void:
	animal_zone_tick_timer -= delta
	if animal_zone_tick_timer > 0.0:
		return
	animal_zone_tick_timer = ANIMAL_ZONE_TICK_SEC
	for zone in animal_zone_states:
		var blue_count := 0
		var red_count := 0
		# Count presence for a live zone AND for a downed boss in its claim window, so the
		# contest window (BB-BOSS-4) reuses the same control/contested computation.
		if bool(zone.get("active", false)) or _is_boss_claim_phase(zone):
			for actor in entities:
				if not _actor_counts_for_animal_zone(actor, zone):
					continue
				if int(actor.get("team")) == BLUE:
					blue_count += 1
				elif int(actor.get("team")) == RED:
					red_count += 1
		zone["blue_count"] = blue_count
		zone["red_count"] = red_count
		zone["contested"] = blue_count > 0 and red_count > 0
		var control_team := -1
		if blue_count > 0 and red_count == 0:
			control_team = BLUE
		elif red_count > 0 and blue_count == 0:
			control_team = RED
		zone["control_team"] = control_team
		if control_team >= 0:
			zone["last_control_team"] = control_team
		if _is_boss_claim_phase(zone):
			_advance_boss_claim(zone, ANIMAL_ZONE_TICK_SEC)

func _actor_counts_for_animal_zone(actor: Node, zone: Dictionary) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if not actor.has_method("is_scored_actor") or not actor.is_scored_actor():
		return false
	if actor.has_method("is_alive") and not actor.is_alive():
		return false
	if not ("team" in actor):
		return false
	return _point_in_animal_zone(actor.global_position, zone)

func _point_in_animal_zone(point: Vector2, zone: Dictionary) -> bool:
	var center: Vector2 = zone.get("center", Vector2.ZERO)
	var radius: Vector2 = zone.get("radius", Vector2.ONE)
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var normalized := Vector2((point.x - center.x) / radius.x, (point.y - center.y) / radius.y)
	return normalized.length_squared() <= 1.0

# --- Boss claim / steal contest window (BB-BOSS-4) -------------------------------
func _is_boss_claim_phase(zone: Dictionary) -> bool:
	if not bool(zone.get("boss", false)):
		return false
	var state := String(zone.get("objective_state", ""))
	return state == "claimable" or state == "contesting"

func _zone_owner_team(zone: Dictionary) -> int:
	match String(zone.get("side", "")):
		"blue":
			return BLUE
		"red":
			return RED
	return -1

func _enemy_team(team: int) -> int:
	return RED if team == BLUE else BLUE

func _advance_boss_claim(zone: Dictionary, step: float) -> void:
	# Contested -> nobody makes progress; a single controlling team accrues; an empty
	# point decays back toward claimable. Ownership is by held presence, never last-hit.
	var previous_state := String(zone.get("objective_state", "claimable"))
	var control_team := int(zone.get("control_team", -1))
	var contested := bool(zone.get("contested", false))
	var progress := float(zone.get("claim_progress", 0.0))
	var claim_team := int(zone.get("claim_team", -1))
	if contested:
		zone["objective_state"] = "contesting"
		if previous_state != "contesting":
			_record_boss_lifecycle_event(zone, "contested", -1, previous_state)
		_emit_boss_claim_phase_feed(zone, "contest", -1)
		return
	if control_team < 0:
		if progress > 0.0 or claim_team >= 0:
			_emit_boss_claim_phase_feed(zone, "interrupted", claim_team)
		progress = maxf(progress - step * BOSS_CLAIM_DECAY_MULT, 0.0)
		if progress <= 0.0:
			claim_team = -1
		zone["claim_progress"] = progress
		zone["claim_team"] = claim_team
		zone["objective_state"] = "claimable"
		if previous_state == "contesting":
			_record_boss_lifecycle_event(zone, "claimable", -1, previous_state)
		return
	zone["objective_state"] = "claimable"
	if previous_state == "contesting":
		_record_boss_lifecycle_event(zone, "claimable", control_team, previous_state)
	if claim_team != control_team:
		# A fresh team seized the point: progress restarts under them (no carry-over).
		_emit_boss_claim_phase_feed(zone, "claim", control_team)
		claim_team = control_team
		progress = 0.0
	progress += step
	zone["claim_team"] = claim_team
	if progress >= BOSS_CLAIM_DURATION:
		_resolve_boss_claim(zone, control_team)
	else:
		zone["claim_progress"] = progress

func _emit_boss_claim_phase_feed(zone: Dictionary, action: String, team: int) -> void:
	var notice_key := "%s:%d" % [action, team]
	if String(zone.get("last_claim_notice", "")) == notice_key:
		return
	zone["last_claim_notice"] = notice_key
	var family := String(zone.get("boss_family", "boss"))
	var zone_id := String(zone.get("id", ""))
	match action:
		"claim":
			var route := "stock steal"
			if bool(zone.get("center_boss", false)):
				route = "center reward"
			elif team == _zone_owner_team(zone):
				route = "stock + disruption"
			add_objective_feed(
				"%s claiming %s boss - %s" % [_team_name(team), family.capitalize(), route],
				"claim",
				team,
				family,
				zone_id
			)
		"contest":
			add_objective_feed(
				"%s boss contested - claim paused" % family.capitalize(),
				"contest",
				-1,
				family,
				zone_id
			)
		"interrupted":
			add_objective_feed(
				"%s boss claim interrupted" % family.capitalize(),
				"interrupted",
				team,
				family,
				zone_id
			)

func _resolve_boss_claim(zone: Dictionary, team: int) -> void:
	var family := String(zone.get("boss_family", ""))
	zone["claim_progress"] = BOSS_CLAIM_DURATION
	zone["claim_team"] = team
	zone["claimed_team"] = team
	if bool(zone.get("center_boss", false)):
		# Center bosses have no owner: whoever holds the point claims a combat reward, and
		# they grant NO directed disruption (the map-wide fight already hit both teams).
		var previous_state := String(zone.get("objective_state", "claimable"))
		zone["objective_state"] = "claimed"
		_record_boss_lifecycle_event(zone, "claimed", team, previous_state)
		_record_team_actor_stat(team, "center_claims", 1)
		_grant_center_reward(team, family)
		return
	var is_owner := team == _zone_owner_team(zone)
	var previous_state := String(zone.get("objective_state", "claimable"))
	zone["objective_state"] = "claimed" if is_owner else "stolen"
	_record_boss_lifecycle_event(zone, String(zone["objective_state"]), team, previous_state)
	_record_team_actor_stat(team, "boss_claims" if is_owner else "boss_steals", 1)
	_grant_boss_reward(team, family, is_owner)
	add_objective_feed(
		"%s %s the %s boss - habitat stock gained" % [_team_name(team), "claimed" if is_owner else "stole", family.capitalize()],
		"claimed" if is_owner else "stolen",
		team,
		family,
		String(zone.get("id", ""))
	)

func _grant_boss_reward(team: int, family: String, is_owner: bool) -> void:
	_add_boss_stock_stack(team, family)
	if is_owner:
		_spawn_boss_terrain_event(_enemy_team(team), family)

# --- Center big boss: scheduled neutral map-wide objective (BB-BOSS-5) ------------
func _tick_center_boss_schedule() -> void:
	if _center_boss_zone_index() >= 0:
		return  # a center boss is already live; one at a time
	for i in CENTER_BOSS_TIMES.size():
		if bool(center_boss_fired[i]):
			continue
		if elapsed >= float(CENTER_BOSS_TIMES[i]):
			center_boss_fired[i] = true
			_spawn_center_boss(_roll_center_boss_family())
			return

func _roll_center_boss_family() -> String:
	# Deterministic: the match-seeded RNG picks one of the five families (BUILD_PLAN rule 4).
	var idx := match_rng.randi_range(0, SIDE_BOSS_ORDER.size() - 1)
	return String(SIDE_BOSS_ORDER[idx])

func _spawn_center_boss(family: String) -> void:
	center_boss_spawn_count += 1
	var zone := {
		"id": "center:Boss:%d" % center_boss_spawn_count,
		"side": "center",
		"group": "Boss",
		"boss": true,
		"center_boss": true,
		"boss_family": family,
		"center": Vector2.ZERO,
		"radius": CENTER_BOSS_RADIUS,
		"active": true,
		"objective_state": "active",
		"activation_count": 1,
		"occupants": ["center_boss_1"],
		"spawned_count": 1,
		"alive_occupants": [],
		"alive_count": 0,
		"defeated_count": 0,
		"blue_defeats": 0,
		"red_defeats": 0,
		"last_defeat_team": -1,
		"cleared_team": -1,
		"wildlife_count": 0,
		"blue_count": 0,
		"red_count": 0,
		"contested": false,
		"control_team": -1,
		"last_control_team": -1,
		"claim_progress": 0.0,
		"claim_team": -1,
		"claimed_team": -1,
		"last_claim_notice": ""
	}
	animal_zone_states.append(zone)
	_spawn_wildlife_for_zone(animal_zone_states[animal_zone_states.size() - 1])
	_record_boss_lifecycle_event(zone, "active", -1, "dormant")
	add_objective_feed("Center boss descends: %s - fight mid" % family.capitalize(), "fight", -1, family, String(zone.get("id", "")))

func _center_boss_zone_index() -> int:
	for i in animal_zone_states.size():
		var zone: Dictionary = animal_zone_states[i]
		if bool(zone.get("center_boss", false)) and String(zone.get("objective_state", "")) in ["active", "claimable", "contesting"]:
			return i
	return -1

func _grant_center_reward(team: int, family: String) -> void:
	if not (team == BLUE or team == RED) or BossCatalog.center_reward(family).is_empty():
		return
	var rewards: Dictionary = team_combat_rewards.get(team, {})
	# Same family claimed again upgrades the stack once (1 -> 2), capped.
	rewards[family] = mini(int(rewards.get(family, 0)) + 1, CENTER_BOSS_REWARD_MAX_STACK)
	team_combat_rewards[team] = rewards
	var label := String(BossCatalog.center_reward(family).get("label", family.capitalize()))
	add_objective_feed(
		"%s claims center reward: %s (x%d)" % [_team_name(team), label, int(rewards[family])],
		"reward",
		team,
		family,
		"center"
	)
	if family == "arthropleura":
		_refresh_team_breeding_buffs(team)

func get_center_boss_state() -> Dictionary:
	var idx := _center_boss_zone_index()
	if idx < 0:
		return {"active": false, "family": "", "objective_state": "dormant"}
	var zone: Dictionary = animal_zone_states[idx]
	return {
		"active": true,
		"family": String(zone.get("boss_family", "")),
		"objective_state": String(zone.get("objective_state", "")),
		"size_mult": BossActorScript.CENTER_SIZE_MULT,
		"claim_ratio": clampf(float(zone.get("claim_progress", 0.0)) / BOSS_CLAIM_DURATION, 0.0, 1.0),
		"claim_team": int(zone.get("claim_team", -1)),
		"contested": bool(zone.get("contested", false)),
		"control_team": int(zone.get("control_team", -1))
	}

func get_team_combat_reward_state(team: int) -> Dictionary:
	var rewards: Dictionary = team_combat_rewards.get(team, {})
	var states := {}
	for family in rewards:
		var stack := int(rewards[family])
		states[family] = {
			"family": family,
			"label": String(BossCatalog.center_reward(family).get("label", family.capitalize())),
			"stack": stack,
			"value": BossCatalog.center_reward_value(family, stack)
		}
		if String(family) == "arthropleura":
			states[family]["growth_stacks"] = int(team_kill_growth_stacks.get(team, 0))
			states[family]["growth_bonus"] = get_team_kill_growth_bonus(team)
	return states

func get_team_combat_reward_value(team: int, family: String) -> float:
	var stack := int(team_combat_rewards.get(team, {}).get(family, 0))
	if stack <= 0:
		return 0.0
	return BossCatalog.center_reward_value(family, stack)

func record_center_reward_kill(killer: Node, victim: Node) -> void:
	if killer == null or victim == null or not is_instance_valid(killer):
		return
	if not ("team" in killer) or not ("team" in victim):
		return
	var killer_team := int(killer.get("team"))
	var victim_team := int(victim.get("team"))
	if not (killer_team == BLUE or killer_team == RED) or killer_team == victim_team:
		return
	if killer.has_method("is_scored_actor") and not killer.is_scored_actor():
		return
	if victim.has_method("is_scored_actor") and not victim.is_scored_actor():
		return
	if get_team_combat_reward_value(killer_team, "arthropleura") <= 0.0:
		return
	var before := int(team_kill_growth_stacks.get(killer_team, 0))
	var after := mini(before + 1, CENTER_KILL_GROWTH_MAX_STACKS)
	if after == before:
		return
	team_kill_growth_stacks[killer_team] = after
	_refresh_team_breeding_buffs(killer_team)

func get_team_kill_growth_bonus(team: int) -> float:
	if not (team == BLUE or team == RED):
		return 0.0
	var reward_value := get_team_combat_reward_value(team, "arthropleura")
	if reward_value <= 0.0:
		return 0.0
	return float(team_kill_growth_stacks.get(team, 0)) * reward_value

func _shed_team_kill_growth_on_death(victim: Node) -> void:
	if victim == null or not ("team" in victim):
		return
	var team := int(victim.get("team"))
	if not (team == BLUE or team == RED):
		return
	if get_team_combat_reward_value(team, "arthropleura") <= 0.0:
		return
	var before := int(team_kill_growth_stacks.get(team, 0))
	if before <= 0:
		return
	var after := maxi(before - CENTER_KILL_GROWTH_DEATH_LOSS, 0)
	team_kill_growth_stacks[team] = after
	_refresh_team_breeding_buffs(team)
	add_objective_feed(
		"%s Swarm Growth shed %d stack%s" % [_team_name(team), before - after, "" if before - after == 1 else "s"],
		"reward_decay",
		team,
		"arthropleura",
		"center"
	)

func get_team_vision_range(team: int) -> float:
	# Phase sight range extended by the team's Teratornis habitat-stock vision_range buff.
	return get_vision_range_for_phase() * (1.0 + get_team_boss_stock_effect(team, "vision_range"))

# --- Boss-stock buff channel (separate from the capped breeding buffs) ------------
func _reset_boss_stock_buffs() -> void:
	team_boss_stock_buffs = {
		BLUE: {},
		RED: {}
	}

func _team_boss_stock_map(team: int) -> Dictionary:
	if not team_boss_stock_buffs.has(team):
		team_boss_stock_buffs[team] = {}
	return team_boss_stock_buffs[team]

func _team_boss_stock_count(team: int) -> int:
	var total := 0
	for family in _team_boss_stock_map(team):
		total += int(_team_boss_stock_map(team)[family])
	return total

func _add_boss_stock_stack(team: int, family: String) -> void:
	if not (team == BLUE or team == RED):
		return
	if BossCatalog.family_buff(family).is_empty():
		return
	if _team_boss_stock_count(team) >= BOSS_STOCK_TEAM_CAP:
		return
	var stacks := _team_boss_stock_map(team)
	stacks[family] = int(stacks.get(family, 0)) + 1
	team_boss_stock_buffs[team] = stacks
	_refresh_team_breeding_buffs(team)

func _team_boss_stock_effects(team: int) -> Dictionary:
	var effects := {}
	var stacks := _team_boss_stock_map(team)
	for family in stacks:
		var count := int(stacks[family])
		if count <= 0:
			continue
		for effect in BossCatalog.family_buff(family):
			effects[effect] = float(effects.get(effect, 0.0)) + float(count) * float(BossCatalog.family_buff(family)[effect])
	return effects

func get_team_boss_stock_effect(team: int, effect: String) -> float:
	return float(_team_boss_stock_effects(team).get(effect, 0.0))

func get_team_boss_stock_summary(team: int) -> Dictionary:
	return {
		"team": team,
		"total_stacks": _team_boss_stock_count(team),
		"family_counts": _team_boss_stock_map(team).duplicate(true),
		"effects": _team_boss_stock_effects(team)
	}

# --- Timed enemy-side terrain disruption events (owner-claim only) ----------------
func _spawn_boss_terrain_event(target_team: int, family: String) -> void:
	var spec := BossCatalog.family_terrain_event(family)
	if spec.is_empty() or not (target_team == BLUE or target_team == RED):
		return
	active_terrain_events.append({
		"kind": String(spec.get("kind", "terrain_event")),
		"label": String(spec.get("label", "Terrain Event")),
		"family": family,
		"team": target_team,
		"position": _boss_terrain_event_position(target_team),
		"radius": float(spec.get("radius", 120.0)),
		"duration": float(spec.get("duration", 12.0)),
		"remaining": float(spec.get("duration", 12.0))
	})
	add_kill_feed("%s hits %s side" % [String(spec.get("label", "Terrain event")), _team_name(target_team)])

func _boss_terrain_event_position(target_team: int) -> Vector2:
	var zone := _team_boss_zone(target_team)
	if not zone.is_empty():
		return zone.get("center", Vector2.ZERO)
	if cores.has(target_team) and is_instance_valid(cores[target_team]):
		return cores[target_team].global_position
	return Vector2.ZERO

func _tick_boss_terrain_events(delta: float) -> void:
	if active_terrain_events.is_empty():
		return
	for i in range(active_terrain_events.size() - 1, -1, -1):
		var event: Dictionary = active_terrain_events[i]
		event["remaining"] = float(event.get("remaining", 0.0)) - delta
		if float(event["remaining"]) <= 0.0:
			active_terrain_events.remove_at(i)
		else:
			active_terrain_events[i] = event

func get_active_terrain_events() -> Array[Dictionary]:
	return active_terrain_events.duplicate(true)

func get_terrain_event_visuals() -> Array[Dictionary]:
	var visuals: Array[Dictionary] = []
	for event: Dictionary in active_terrain_events:
		var duration := maxf(float(event.get("duration", 0.01)), 0.01)
		var remaining := clampf(float(event.get("remaining", 0.0)), 0.0, duration)
		var kind := String(event.get("kind", "terrain_event"))
		visuals.append({
			"kind": kind,
			"label": String(event.get("label", "Terrain Event")),
			"family": String(event.get("family", "")),
			"team": int(event.get("team", -1)),
			"position": event.get("position", Vector2.ZERO),
			"radius": float(event.get("radius", 120.0)),
			"duration": duration,
			"remaining": remaining,
			"ratio": remaining / duration
		})
	return visuals

func _build_trio_hud_row(slot: Dictionary) -> Dictionary:
	var actor: Node = slot.get("actor", null)
	var team := int(slot.get("team", -1))
	var creature_id := String(slot.get("creature_id", ""))
	var name := creature_id
	var hp_ratio := 0.0
	var hunger_ratio := 0.0
	var satiated := false
	var hp_known := team == BLUE
	if actor != null and is_instance_valid(actor):
		var data_value = actor.get("creature_data")
		if typeof(data_value) == TYPE_DICTIONARY:
			var creature_data: Dictionary = data_value
			name = String(creature_data.get("name", creature_id))
		elif actor.has_method("get_actor_name"):
			name = actor.get_actor_name()
		if actor.has_method("is_alive") and actor.is_alive():
			hp_ratio = _health_ratio(actor)
			hp_known = team == BLUE or is_entity_visible_to_team(actor, BLUE)
			if team == BLUE:
				hunger_ratio = clampf(float(actor.get("hunger")) / 100.0, 0.0, 1.0) if actor.get("hunger") != null else 0.0
				satiated = actor.has_method("is_satiated") and actor.is_satiated()
	var state := String(slot.get("state", StockManagerScript.STATE_FIELD))
	if state == StockManagerScript.STATE_FIELD and actor != null and is_instance_valid(actor) and actor.has_method("is_alive") and not actor.is_alive():
		state = StockManagerScript.STATE_RESPAWNING
	return {
		"team": team,
		"slot_index": int(slot.get("slot_index", -1)),
		"creature_id": creature_id,
		"name": name,
		"active": team == BLUE and actor != null and actor == player,
		"hp_ratio": hp_ratio,
		"hp_known": hp_known,
		"hunger_ratio": hunger_ratio,
		"satiated": satiated,
		"deposit_ready": team == BLUE and satiated and state == StockManagerScript.STATE_FIELD,
		"stocks": int(slot.get("stocks_remaining", StockManagerScript.MAX_STOCKS)),
		"max_stocks": int(slot.get("max_stocks", StockManagerScript.MAX_STOCKS)),
		"state": state
	}

func _spawn_player_squad() -> bool:
	player_squad.clear()
	active_squad_index = 0
	squad_command = SQUAD_COMMAND_FARM
	squad_command_timer = 0.0
	squad_aggro_target = null
	squad_switch_feedback_timer = 0.0
	squad_switch_feedback_state = ""
	squad_switch_feedback_slot_index = -1

	var squad_ids: Array[String] = GameConfig.get_selected_squad_ids() if GameConfig.has_method("get_selected_squad_ids") else [GameConfig.selected_creature_id, "chorus_frog", "mink"]
	var blue_spawn := get_team_spawn(BLUE)
	for i in 3:
		var member = CreatureScript.new()
		add_child(member)
		member.setup(self, BLUE, blue_spawn + _squad_spawn_offset(i, BLUE), squad_ids[i], terrain_map)
		member.actor_name = "Blue %d %s" % [i + 1, member.creature_data.get("name", member.creature_id)]
		player_squad.append(member)
		var controller_kind := MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN if i == active_squad_index else MatchSlotRegistryScript.CONTROLLER_AI
		if not _register_competitive_slot(BLUE, i, squad_ids[i], member, controller_kind):
			return false
		register_entity(member)
	player = player_squad[active_squad_index]
	return true

func _spawn_all_bot_squads() -> bool:
	player_squad.clear()
	player = null
	var blue_ids: Array[String] = GameConfig.get_selected_squad_ids()
	var configured_red: Array[String] = GameConfig.get_selected_red_squad_ids()
	if blue_ids.size() != 3 or configured_red.size() != 3:
		push_error("All Bots requires exact three-creature rosters for both teams")
		return false
	var red_ids: Array = configured_red
	var team_rosters := {BLUE: blue_ids, RED: red_ids}
	var team_names := {
		BLUE: ["Blue Root", "Blue Reed", "Blue Tide"],
		RED: ["Red Claw", "Red Reed", "Red Fang"]
	}
	for team_value in [BLUE, RED]:
		var team := int(team_value)
		var spawn := get_team_spawn(team)
		var roster: Array = team_rosters[team]
		for index in 3:
			var bot := _spawn_bot(
				team,
				String(roster[index]),
				spawn + _squad_spawn_offset(index, team),
				String(team_names[team][index])
			)
			if not _register_competitive_slot(
				team,
				index,
				String(roster[index]),
				bot,
				MatchSlotRegistryScript.CONTROLLER_AI
			):
				return false
	return true

func _squad_spawn_offset(index: int, team: int) -> Vector2:
	var y_offsets := [-42.0, 0.0, 42.0]
	var x := -28.0 if team == BLUE else 28.0
	return Vector2(x, y_offsets[index])

func _attach_camera_to_player() -> void:
	if camera == null or player == null or not is_instance_valid(player):
		return
	var parent := camera.get_parent()
	if parent != null:
		parent.remove_child(camera)
	player.add_child(camera)
	camera.position = Vector2.ZERO
	camera.make_current()

func _seed_match_rng() -> void:
	var ruleset_id := String(match_rules.get("id", MatchRulesScript.RULESET_COMPETITIVE_3V3))
	match_seed = (
		int(GameConfig.simulation_seed)
		if int(GameConfig.simulation_seed) >= 0
		else int(("%s:%s" % [ruleset_id, GameConfig.selected_creature_id]).hash())
	)
	match_rng.seed = match_seed

func get_simulation_tick() -> int:
	return simulation_tick

func _shuffled_creature_pool(source_pool: Array) -> Array:
	var shuffled := source_pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := match_rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled

func _spawn_bot(team: int, creature_id: String, spawn_position: Vector2, bot_name: String) -> Node:
	var bot = CreatureScript.new()
	add_child(bot)
	bot.setup(self, team, spawn_position, creature_id, terrain_map)
	bot.actor_name = bot_name
	bots.append(bot)
	register_entity(bot)
	return bot

func _feed_registered_inputs() -> void:
	if not slot_registry.is_sealed():
		last_input_routing_state = {"sealed": false, "assignments": 0, "routed": 0, "duplicates": 0}
		return
	if _is_1v1_trio_mode():
		_select_live_active_if_needed()
	var routed_frames: Dictionary = {}
	var routed_actors: Dictionary = {}
	var routed_controller_kinds: Dictionary = {}
	var routed_slots: Dictionary = {}
	var duplicate_count := 0
	var unsupported_count := 0
	var local_count := 0
	var ai_count := 0
	for assignment: Dictionary in slot_registry.get_controller_plan():
		var team := int(assignment.get("team", -1))
		var slot_index := int(assignment.get("slot_index", -1))
		var slot: Dictionary = slot_registry.get_slot(team, slot_index)
		var actor: Node = slot.get("actor", null)
		if actor == null or not is_instance_valid(actor):
			continue
		var frame: Resource = InputFrameScript.new()
		var controller_kind := String(assignment.get("kind", ""))
		if actor.has_method("is_alive") and actor.is_alive():
			match controller_kind:
				MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN:
					local_count += 1
					frame = local_input.build_frame(actor.get_global_mouse_position())
					_apply_switch_release_gate(frame)
				MatchSlotRegistryScript.CONTROLLER_AI:
					ai_count += 1
					var slot_id := String(slot.get("slot_id", ""))
					var order: Dictionary = team_orders.get(team, {}).get(slot_id, {})
					frame = bot_brain.build_frame(actor, true, order)
				_:
					unsupported_count += 1
					push_error("Unsupported live controller kind: %s" % controller_kind)
		_apply_switch_action_neutral_gate(actor, frame)
		var actor_key := str(actor.get_instance_id())
		if routed_frames.has(actor_key):
			duplicate_count += 1
			push_error("Actor received more than one input provider: %s" % actor_key)
			continue
		routed_frames[actor_key] = frame
		routed_actors[actor_key] = actor
		routed_controller_kinds[actor_key] = controller_kind
		routed_slots[actor_key] = slot
	var routing_valid := duplicate_count == 0 and unsupported_count == 0
	var transition_consumed: Array = []
	var committed_action_count := 0
	for actor_key in routed_frames:
		var actor: Node = routed_actors.get(actor_key, null)
		if actor != null and is_instance_valid(actor):
			var frame: Resource = routed_frames[actor_key] if routing_valid else InputFrameScript.new()
			var controller_kind := String(routed_controller_kinds.get(actor_key, ""))
			var actor_alive: bool = actor.has_method("is_alive") and actor.is_alive()
			if routing_valid and actor_alive:
				if frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT):
					if controller_kind == MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN:
						if _try_manual_habitat_deposit(actor):
							committed_action_count += 1
					elif controller_kind == MatchSlotRegistryScript.CONTROLLER_AI:
						if _try_autonomous_habitat_deposit(actor):
							committed_action_count += 1
				if controller_kind == MatchSlotRegistryScript.CONTROLLER_LOCAL_HUMAN \
					and frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) \
					and hut_defend_hint_timer <= 0.0 \
					and _player_near_own_hut():
					hut_defend_hint_timer = 2.5
					add_kill_feed("Hut defense assignment needs a reserve habitat upgrade")
					committed_action_count += 1
			actor.set_input_frame(frame)
			_record_balance_slot_tick(actor, frame, actor_alive, routed_slots.get(actor_key, {}))
			if routing_valid and actor_alive and switch_action_neutral_ticks.has(actor.get_instance_id()):
				transition_consumed.append(actor.get_instance_id())
	_advance_switch_action_neutral_ticks(transition_consumed)
	last_input_routing_state = {
		"sealed": true,
		"assignments": slot_registry.get_controller_plan().size(),
		"routed": routed_frames.size(),
		"duplicates": duplicate_count,
		"unsupported": unsupported_count,
		"routing_valid": routing_valid,
		"committed_actions": committed_action_count,
		"local": local_count,
		"ai": ai_count,
		"actor_ids": routed_frames.keys()
	}

func get_input_routing_state() -> Dictionary:
	return last_input_routing_state.duplicate(true)

func _record_balance_slot_tick(
	actor: Node,
	frame: Resource,
	actor_alive: bool,
	known_slot: Dictionary = {}
) -> void:
	if actor == null or not is_instance_valid(actor) or frame == null:
		return
	var slot: Dictionary = known_slot if not known_slot.is_empty() else slot_registry.get_slot_for_actor(actor)
	var slot_id := String(slot.get("slot_id", ""))
	if slot_id.is_empty():
		return
	var state := _ensure_balance_slot_telemetry(actor, slot)
	if int(state.get("last_sample_tick", -1)) == simulation_tick:
		return
	var position: Vector2 = actor.global_position
	if bool(state.get("was_alive", false)) and actor_alive:
		state["distance_traveled_px"] = float(state.get("distance_traveled_px", 0.0)) \
			+ position.distance_to(state.get("last_position", position))
	state["last_position"] = position
	state["last_sample_tick"] = simulation_tick
	state["sample_ticks"] = int(state.get("sample_ticks", 0)) + 1

	var buttons := int(frame.get("buttons"))
	var previous_buttons := int(state.get("previous_buttons", 0))
	if not actor_alive:
		state["was_alive"] = false
		state["previous_buttons"] = 0
		state["current_idle_ticks"] = 0
		balance_slot_telemetry[slot_id] = state
		return

	state["was_alive"] = true
	state["alive_ticks"] = int(state.get("alive_ticks", 0)) + 1
	var move_input: Vector2 = frame.get("move")
	var has_move_input := move_input.length_squared() > 0.0001
	var has_action_input := buttons != 0
	if has_move_input:
		state["move_input_ticks"] = int(state.get("move_input_ticks", 0)) + 1
	if has_move_input or has_action_input:
		state["active_ticks"] = int(state.get("active_ticks", 0)) + 1
		state["current_idle_ticks"] = 0
	else:
		state["idle_ticks"] = int(state.get("idle_ticks", 0)) + 1
		state["current_idle_ticks"] = int(state.get("current_idle_ticks", 0)) + 1
		state["max_idle_ticks"] = maxi(
			int(state.get("max_idle_ticks", 0)),
			int(state.get("current_idle_ticks", 0))
		)

	var pressed_buttons := buttons & ~previous_buttons
	if (pressed_buttons & InputFrameScript.BUTTON_PRIMARY) != 0:
		state["primary_press_count"] = int(state.get("primary_press_count", 0)) + 1
	var ability_presses := 0
	if (pressed_buttons & InputFrameScript.BUTTON_ABILITY_Q) != 0:
		state["ability_q_press_count"] = int(state.get("ability_q_press_count", 0)) + 1
		ability_presses += 1
	if (pressed_buttons & InputFrameScript.BUTTON_ABILITY_E) != 0:
		state["ability_e_press_count"] = int(state.get("ability_e_press_count", 0)) + 1
		ability_presses += 1
	state["ability_press_count"] = int(state.get("ability_press_count", 0)) + ability_presses
	state["previous_buttons"] = buttons
	balance_slot_telemetry[slot_id] = state

func _ensure_balance_slot_telemetry(actor: Node, known_slot: Dictionary = {}) -> Dictionary:
	var slot := known_slot
	if slot.is_empty() and actor != null and is_instance_valid(actor):
		slot = slot_registry.get_slot_for_actor(actor)
	var slot_id := String(slot.get("slot_id", ""))
	if slot_id.is_empty():
		return {}
	if balance_slot_telemetry.has(slot_id):
		return balance_slot_telemetry[slot_id]
	var position: Vector2 = actor.global_position if actor != null and is_instance_valid(actor) else Vector2.ZERO
	var state := {
		"slot_id": slot_id,
		"slot_index": int(slot.get("slot_index", -1)),
		"team": int(slot.get("team", -1)),
		"creature_id": String(slot.get("creature_id", "")),
		"sample_ticks": 0,
		"alive_ticks": 0,
		"active_ticks": 0,
		"idle_ticks": 0,
		"current_idle_ticks": 0,
		"max_idle_ticks": 0,
		"distance_traveled_px": 0.0,
		"move_input_ticks": 0,
		"primary_press_count": 0,
		"ability_press_count": 0,
		"ability_q_press_count": 0,
		"ability_e_press_count": 0,
		"landed_hit_count": 0,
		"last_position": position,
		"last_sample_tick": -1,
		"previous_buttons": 0,
		"was_alive": false
	}
	balance_slot_telemetry[slot_id] = state
	return state

func _record_landed_hit_telemetry(event: Dictionary) -> void:
	if String(event.get("type", "")) != "hit_landed" or float(event.get("amount", 0.0)) <= 0.0:
		return
	var source: Node = event.get("source", null)
	var target: Node = event.get("target", null)
	if source == null or not is_instance_valid(source) or source == target:
		return
	if not source.has_method("is_scored_actor") or not source.is_scored_actor():
		return
	var slot: Dictionary = slot_registry.get_slot_for_actor(source)
	var slot_id := String(slot.get("slot_id", ""))
	if slot_id.is_empty():
		return
	var state := _ensure_balance_slot_telemetry(source, slot)
	state["landed_hit_count"] = int(state.get("landed_hit_count", 0)) + 1
	balance_slot_telemetry[slot_id] = state

func _record_boss_lifecycle_event(
	zone: Dictionary,
	event_name: String,
	acting_team := -1,
	from_state := ""
) -> void:
	if not bool(zone.get("boss", false)):
		return
	boss_lifecycle_event_sequence += 1
	var center := bool(zone.get("center_boss", false))
	boss_lifecycle_events.append({
		"sequence": boss_lifecycle_event_sequence,
		"event": event_name,
		"elapsed_sec": elapsed,
		"simulation_tick": simulation_tick,
		"zone_id": String(zone.get("id", "")),
		"family": String(zone.get("boss_family", "")),
		"center": center,
		"side": String(zone.get("side", "center" if center else "")),
		"owner_team": _zone_owner_team(zone),
		"acting_team": int(acting_team),
		"from_state": from_state,
		"objective_state": String(zone.get("objective_state", event_name)),
		"trigger": "center_spawn" if center and event_name == "active" else "side_wake" if event_name == "active" else ""
	})
	while boss_lifecycle_events.size() > BOSS_LIFECYCLE_EVENT_LIMIT:
		boss_lifecycle_events.pop_front()

func get_balance_telemetry_state() -> Dictionary:
	return {
		"slot_activity": _balance_slot_telemetry_rows(),
		"boss_lifecycle_events": boss_lifecycle_events.duplicate(true),
		"boss_lifecycle_total_events": boss_lifecycle_event_sequence,
		"boss_lifecycle_retained_events": boss_lifecycle_events.size(),
		"boss_lifecycle_truncated_events": maxi(
			boss_lifecycle_event_sequence - boss_lifecycle_events.size(),
			0
		)
	}

func _balance_slot_telemetry_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not slot_registry.is_sealed():
		return rows
	for team_value in [BLUE, RED]:
		for slot: Dictionary in slot_registry.get_team_slots(int(team_value)):
			var actor: Node = slot.get("actor", null)
			var state := _ensure_balance_slot_telemetry(actor, slot)
			var row := state.duplicate(true)
			row.erase("last_position")
			row.erase("last_sample_tick")
			row.erase("previous_buttons")
			row.erase("was_alive")
			row["distance_traveled_px"] = snappedf(float(row.get("distance_traveled_px", 0.0)), 0.001)
			rows.append(row)
	return rows

func _apply_switch_release_gate(frame: Resource) -> void:
	if frame == null or switch_release_mask == 0:
		return
	switch_release_mask &= int(frame.buttons)
	frame.buttons &= ~switch_release_mask

func _apply_switch_action_neutral_gate(actor: Node, frame: Resource) -> void:
	if actor == null or frame == null:
		return
	if int(switch_action_neutral_ticks.get(actor.get_instance_id(), 0)) > 0:
		frame.buttons = 0

func _advance_switch_action_neutral_ticks(consumed_actor_ids: Array) -> void:
	for actor_id in consumed_actor_ids:
		var remaining := int(switch_action_neutral_ticks.get(actor_id, 0)) - 1
		if remaining <= 0:
			switch_action_neutral_ticks.erase(actor_id)
		else:
			switch_action_neutral_ticks[actor_id] = remaining

func _feed_player_squad_inputs() -> void:
	_select_live_active_if_needed()
	if player != null and is_instance_valid(player) and player.is_alive():
		var player_frame: Resource = local_input.build_frame(player.get_global_mouse_position())
		player.set_input_frame(player_frame)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HABITAT_DEPOSIT):
			_try_manual_habitat_deposit(player)
		if player_frame.is_pressed(InputFrameScript.BUTTON_HUT_DEFEND) and hut_defend_hint_timer <= 0.0 and _player_near_own_hut():
			hut_defend_hint_timer = 2.5
			add_kill_feed("Hut defense assignment needs a reserve habitat upgrade")
	for member in player_squad:
		if member == null or not is_instance_valid(member) or member == player:
			continue
		if member.is_alive():
			member.set_input_frame(_build_squad_ai_frame(member))

func _select_live_active_if_needed() -> void:
	if player != null and is_instance_valid(player) and player.is_alive():
		return
	var best_index := -1
	var best_health_ratio := -1.0
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member) or not member.is_alive():
			continue
		var ratio := _health_ratio(member)
		if ratio > best_health_ratio:
			best_health_ratio = ratio
			best_index = i
	if best_index >= 0:
		_set_active_squad_index(best_index, false)

func _build_squad_ai_frame(actor: Node) -> Resource:
	if _is_severe_danger(actor):
		return _retreat_frame(actor)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return _follow_active_frame(actor)
		SQUAD_COMMAND_AGGRO:
			var target := squad_aggro_target if _autonomous_can_perceive(actor, squad_aggro_target) else _closest_enemy_creature(actor, SQUAD_DANGER_RANGE * 1.8)
			if target != null:
				return _direct_target_frame(actor, target, true)
			return _follow_active_frame(actor)
		_:
			return bot_brain.build_frame(actor)

func _follow_active_frame(actor: Node) -> Resource:
	if player == null or not is_instance_valid(player):
		return bot_brain.build_frame(actor, false)
	var distance: float = actor.global_position.distance_to(player.global_position)
	if distance <= SQUAD_FOLLOW_RADIUS:
		var frame := InputFrameScript.new()
		frame.aim = player.global_position
		return frame
	return _move_to_frame(actor, player.global_position, SQUAD_FOLLOW_RADIUS, player.global_position)

func _safe_farm_frame(actor: Node) -> Resource:
	# Proactive when uncontrolled (2026-07-05 playtest: 'in gather they just
	# stand still in spawn'): push out and clear the nearest wave, but never
	# contest a point an enemy creature is holding — the frontline hut line
	# is the risk ceiling, and _is_severe_danger retreat still overrides all.
	var minion_target := _closest_enemy_minion(actor, 900.0)
	if minion_target != null and not _farm_point_contested(actor, minion_target.global_position):
		return _direct_target_frame(actor, minion_target, false)
	var frontline := _squad_frontline_point(actor)
	return _move_to_frame(actor, frontline, 70.0, frontline)

# Hold just behind an alive friendly hut (lane split by squad slot) —
# forward enough to meet waves, safe enough to disengage.
func _squad_frontline_point(actor: Node) -> Vector2:
	var own_huts: Array[Node] = []
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.is_alive() and hut.team == actor.team:
			own_huts.append(hut)
	if own_huts.is_empty():
		return _safe_patrol_point(actor)
	var slot: int = maxi(player_squad.find(actor), 0)
	var hut: Node = own_huts[slot % own_huts.size()]
	return hut.global_position + Vector2(-90.0 if actor.team == BLUE else 90.0, 0.0)

func _farm_point_contested(actor: Node, point: Vector2) -> bool:
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		var creature_id_value: Variant = entity.get("creature_id")
		if creature_id_value == null or String(creature_id_value) == "":
			continue
		if int(entity.get("team")) == actor.team:
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if not _autonomous_can_perceive(actor, entity):
			continue
		if entity.global_position.distance_to(point) < SQUAD_DANGER_RANGE:
			return true
	return false

func _retreat_frame(actor: Node) -> Resource:
	var point := _retreat_point(actor)
	var threat := _closest_enemy_creature(actor, SQUAD_DANGER_RANGE)
	return _move_to_frame(actor, point, 36.0, threat.global_position if threat != null else point)

func _direct_target_frame(actor: Node, target: Node, allow_abilities: bool) -> Resource:
	var frame := _move_to_frame(actor, target.global_position, bot_brain._preferred_range(actor) + _target_radius(target), target.global_position)
	var distance: float = actor.global_position.distance_to(target.global_position)
	if distance <= bot_brain._primary_range(actor, target):
		frame.set_button(InputFrameScript.BUTTON_PRIMARY, true)
		if allow_abilities:
			bot_brain._hook(actor).apply(actor, target, frame, distance)
	return frame

func _move_to_frame(actor: Node, point: Vector2, hold_radius: float, aim_point: Vector2) -> Resource:
	var frame := InputFrameScript.new()
	frame.aim = aim_point
	var offset: Vector2 = point - actor.global_position
	var distance := offset.length()
	if distance > hold_radius:
		var direction := offset.normalized()
		frame.move = get_steering_direction(actor.global_position, point, actor.body_radius, actor.team)
		if frame.move == Vector2.ZERO:
			frame.move = direction
	return frame

func _is_severe_danger(actor: Node) -> bool:
	return _health_ratio(actor) <= SQUAD_DANGER_HEALTH_RATIO and _closest_enemy_creature(actor, SQUAD_DANGER_RANGE) != null

func _health_ratio(target: Node) -> float:
	var max_health := float(target.get("max_health") if target.get("max_health") != null else 0.0)
	if max_health <= 0.0:
		return 1.0
	return clampf(float(target.health) / max_health, 0.0, 1.0)

func _closest_enemy_creature(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for entity in entities:
		if not _valid_target(entity) or entity.team == actor.team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if not _autonomous_can_perceive(actor, entity):
			continue
		var distance: float = actor.global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _closest_enemy_minion(actor: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance := max_distance
	for minion in minions:
		if not _valid_target(minion) or minion.team == actor.team:
			continue
		if not _autonomous_can_perceive(actor, minion):
			continue
		var distance: float = actor.global_position.distance_to(minion.global_position)
		if distance < closest_distance:
			closest = minion
			closest_distance = distance
	return closest

func _autonomous_can_perceive(actor: Node, target: Variant) -> bool:
	if not _valid_target(target):
		return false
	if target.get("team") == null or int(target.get("team")) == int(actor.team):
		return true
	if has_method("is_entity_visible_to_team"):
		return is_entity_visible_to_team(target, int(actor.team))
	return not (target.has_method("is_stealthed") and target.is_stealthed())

func _valid_target(target: Variant) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	if target.get("health") != null and float(target.health) <= 0.0:
		return false
	return true

func _target_radius(target: Node) -> float:
	if target.get("body_radius") != null:
		return float(target.body_radius)
	if target.get("radius") != null:
		return float(target.radius)
	return 0.0

func _retreat_point(actor: Node) -> Vector2:
	var best_point: Vector2 = get_team_spawn(actor.team)
	var best_distance: float = actor.global_position.distance_to(best_point)
	for hut in huts:
		if not _valid_target(hut) or hut.team != actor.team:
			continue
		var distance: float = actor.global_position.distance_to(hut.global_position)
		if distance < best_distance:
			best_point = hut.global_position
			best_distance = distance
	return best_point

func _safe_patrol_point(actor: Node) -> Vector2:
	var spawn := get_team_spawn(actor.team)
	var lane_y := 56.0 * (1.0 if active_squad_index % 2 == 0 else -1.0)
	return spawn + Vector2(150.0 if actor.team == BLUE else -150.0, lane_y)

func _tick_squad_command(delta: float) -> void:
	if not _is_1v1_trio_mode():
		return
	if squad_command == SQUAD_COMMAND_FOLLOW or squad_command == SQUAD_COMMAND_AGGRO:
		squad_command_timer = maxf(squad_command_timer - delta, 0.0)
		if squad_command_timer <= 0.0:
			_issue_squad_farm(false)

func _set_squad_switch_feedback(state: String, slot_index: int) -> void:
	squad_switch_feedback_state = state
	squad_switch_feedback_slot_index = slot_index
	squad_switch_feedback_timer = SQUAD_SWITCH_FEEDBACK_SECONDS

func _set_active_squad_index(index: int, announce := true) -> void:
	if index < 0 or index >= player_squad.size():
		_set_squad_switch_feedback("invalid", index)
		return
	var next_player: Node = player_squad[index]
	if next_player == null or not is_instance_valid(next_player) or not next_player.is_alive():
		var unavailable_state := "respawning"
		if next_player != null and is_instance_valid(next_player) and stock_manager.has_actor(next_player):
			var stock_slot: Dictionary = stock_manager.get_slot_for_actor(next_player)
			if String(stock_slot.get("state", "")) == StockManagerScript.STATE_EXHAUSTED:
				unavailable_state = "exhausted"
		_set_squad_switch_feedback(unavailable_state, index)
		if announce:
			add_kill_feed(
				"Squad slot %d is out of stocks" % (index + 1)
				if unavailable_state == "exhausted"
				else "Squad slot %d is respawning" % (index + 1)
			)
		return
	var previous_index := active_squad_index
	if slot_registry.is_sealed() and previous_index != index:
		var held_frame: Resource = local_input.build_frame(next_player.get_global_mouse_position())
		if not slot_registry.transfer_controller(BLUE, previous_index, index):
			_set_squad_switch_feedback("invalid", index)
			push_error("Could not transfer local controller: %s" % str(slot_registry.validation_errors()))
			return
		switch_release_mask = int(held_frame.buttons) & SWITCH_RELEASE_BUTTONS
		var previous_player: Node = player_squad[previous_index]
		if previous_player != null and is_instance_valid(previous_player):
			switch_action_neutral_ticks[previous_player.get_instance_id()] = 1
			bot_brain.reset_actor(previous_player)
		switch_action_neutral_ticks[next_player.get_instance_id()] = 1
		bot_brain.reset_actor(next_player)
		team_director_timer = 0.0
	active_squad_index = index
	player = next_player
	_set_squad_switch_feedback("active", index)
	_attach_camera_to_player()
	if announce:
		add_kill_feed("Controlling %d: %s" % [index + 1, player.get_actor_name()])
	_update_ui()

func _issue_squad_follow(announce := true) -> void:
	if not _is_1v1_trio_mode():
		return
	squad_command = SQUAD_COMMAND_FOLLOW
	squad_command_timer = SQUAD_COMMAND_SECONDS
	squad_aggro_target = null
	team_director_timer = 0.0
	if announce:
		add_kill_feed("Squad regrouping on active creature")
		if player != null and is_instance_valid(player):
			add_circle_telegraph(player.global_position, SQUAD_FOLLOW_RADIUS, Color(0.45, 0.75, 1.0, 0.75), 0.35, 3.0, false)

func _issue_squad_farm(announce := true) -> void:
	if not _is_1v1_trio_mode():
		return
	squad_command = SQUAD_COMMAND_FARM
	squad_command_timer = 0.0
	squad_aggro_target = null
	team_director_timer = 0.0
	if announce:
		add_kill_feed("Squad farming safely")

func _issue_squad_aggro(target: Node) -> void:
	if not _is_1v1_trio_mode() or squad_command != SQUAD_COMMAND_FOLLOW or squad_command_timer <= 0.0:
		return
	if not _valid_target(target) or (player != null and target.team == player.team):
		return
	if not target.has_method("is_scored_actor") or not target.is_scored_actor():
		return
	squad_command = SQUAD_COMMAND_AGGRO
	squad_aggro_target = target
	team_director_timer = 0.0
	add_kill_feed("Squad assisting on %s" % (target.get_actor_name() if target.has_method("get_actor_name") else "target"))

func spawn_wave() -> void:
	# Each surviving hut fields a wave that marches down its lane.
	for hut in huts:
		if hut == null or not is_instance_valid(hut) or not hut.is_alive():
			continue
		var toward_mid := Vector2(1.0 if hut.team == BLUE else -1.0, 0.0)
		var lane_anchor := Vector2(-hut.global_position.x, hut.global_position.y)
		for i in wave_minion_offsets.size():
			var minion = MinionScript.new()
			add_child(minion)
			minion.setup(self, hut.team, hut.global_position + toward_mid * (52.0 + float(i) * 22.0) + wave_minion_offsets[i] * 0.4, "lane", lane_anchor)
			minions.append(minion)
			register_entity(minion)

func track_minion(minion: Node) -> void:
	if not minions.has(minion):
		minions.append(minion)

func _tick_day_cycle(delta: float) -> void:
	day_timer += delta
	if day_timer < DAY_LENGTH_SEC:
		return
	day_timer = fmod(day_timer, DAY_LENGTH_SEC)
	day_index += 1
	_refresh_food_sources()
	add_kill_feed("Dawn %d: wild food refreshed" % day_index)

func _refresh_food_sources() -> void:
	for food in food_sources:
		if food != null and is_instance_valid(food):
			food.queue_free()
	food_sources.clear()
	team_food_vision = {BLUE: {}, RED: {}}
	var spawn_points: Array = terrain_map.get_food_spawn_points() if terrain_map.has_method("get_food_spawn_points") else []
	for entry: Dictionary in spawn_points:
		var food = FoodSourceScript.new()
		add_child(food)
		food.setup_from_entry(entry)
		food_sources.append(food)

func try_eat_nearby_food(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("consume_food"):
		return false
	for i in range(food_sources.size() - 1, -1, -1):
		var food: Node = food_sources[i]
		if food == null or not is_instance_valid(food):
			food_sources.remove_at(i)
			continue
		if food.has_method("requires_attack_harvest") and food.requires_attack_harvest():
			continue
		var reach := float(actor.get("body_radius") if actor.get("body_radius") != null else 10.0) + float(food.get("body_radius")) + FOOD_EAT_RADIUS_PAD
		if actor.global_position.distance_to(food.global_position) > reach:
			continue
		if actor.consume_food(String(food.get("kind")), float(food.get("food_value")), float(food.get("heal_fraction"))):
			food.consume()
			food_sources.remove_at(i)
			_forget_food_source(food)
			return true
	return false

func try_harvest_food_with_hit_shape(actor: Node, shape: Dictionary, source_ability := "") -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("consume_food"):
		return false
	var best_food: Node = null
	var best_distance := INF
	for i in range(food_sources.size() - 1, -1, -1):
		var food: Node = food_sources[i]
		if food == null or not is_instance_valid(food):
			food_sources.remove_at(i)
			continue
		if String(food.get("kind")) != FoodSourceScript.KIND_PLANT:
			continue
		if actor.has_method("can_eat_food_kind") and not actor.can_eat_food_kind(String(food.get("kind"))):
			continue
		if not _food_hit_shape_hit(shape, food):
			continue
		var distance: float = actor.global_position.distance_to(food.global_position)
		if distance < best_distance:
			best_distance = distance
			best_food = food
	if best_food == null:
		return false
	var completed := true
	if best_food.has_method("harvest_hit"):
		completed = best_food.harvest_hit(actor)
	if actor.has_method("emit_vfx_event"):
		actor.emit_vfx_event("harvest_hit", {
			"actor": actor,
			"food": best_food,
			"position": best_food.global_position,
			"source_ability": source_ability,
			"remaining": int(best_food.get("harvest_hits_remaining") if best_food.get("harvest_hits_remaining") != null else 0)
		})
	if not completed:
		return true
	if actor.consume_food(String(best_food.get("kind")), float(best_food.get("food_value")), float(best_food.get("heal_fraction"))):
		best_food.consume()
		food_sources.erase(best_food)
		_forget_food_source(best_food)
		return true
	return false

func _food_hit_shape_hit(shape: Dictionary, food: Node) -> bool:
	match String(shape.get("kind", "")):
		"melee_arc":
			return bool(HitShapeScript.melee_arc_hit(shape, food).get("hit", false))
		"line":
			return bool(HitShapeScript.line_hit(shape, food).get("hit", false))
		_:
			if shape.has("center") and shape.has("radius"):
				return bool(HitShapeScript.circle_hit(shape.get("center", Vector2.ZERO), float(shape.get("radius", 0.0)), food).get("hit", false))
	return false

func record_food_consumed(actor: Node, food_kind: String, hunger_gain: float) -> void:
	var food_label := "plant" if food_kind == FoodSourceScript.KIND_PLANT else "critter"
	var actor_name: String = actor.get_actor_name() if actor != null and actor.has_method("get_actor_name") else "Creature"
	var hunger_after := float(actor.get("hunger")) if actor != null and actor.get("hunger") != null else 0.0
	var satiated: bool = actor != null and actor.has_method("is_satiated") and actor.is_satiated()
	_record_economy_event(actor, "food_consumed", {
		"food_kind": food_kind,
		"hunger_gain": hunger_gain,
		"hunger_after": hunger_after,
		"satiated": satiated
	})
	if hunger_gain > 0.0:
		add_kill_feed("%s ate %s (+%d hunger)" % [actor_name, food_label, int(round(hunger_gain))])
	else:
		add_kill_feed("%s topped off on %s" % [actor_name, food_label])

func get_economy_event_state() -> Array[Dictionary]:
	return economy_events.duplicate(true)

func get_economy_summary_state() -> Dictionary:
	return {
		"total_events": economy_event_sequence,
		"retained_events": economy_events.size(),
		"truncated_events": maxi(economy_event_sequence - economy_events.size(), 0),
		"counts": economy_event_counts.duplicate(true),
		"first_elapsed_sec": economy_first_event_sec.duplicate(true),
		"by_team": {
			"blue": {
				"counts": economy_team_event_counts.get("blue", {}).duplicate(true),
				"first_elapsed_sec": economy_team_first_event_sec.get("blue", {}).duplicate(true)
			},
			"red": {
				"counts": economy_team_event_counts.get("red", {}).duplicate(true),
				"first_elapsed_sec": economy_team_first_event_sec.get("red", {}).duplicate(true)
			}
		}
	}

func _record_economy_event(actor: Node, event_name: String, payload: Dictionary = {}) -> void:
	economy_event_sequence += 1
	var event := {
		"sequence": economy_event_sequence,
		"elapsed_sec": elapsed,
		"slot_id": _economy_slot_id(actor),
		"event": event_name
	}
	for key in payload:
		event[key] = payload[key]
	economy_event_counts[event_name] = int(economy_event_counts.get(event_name, 0)) + 1
	if not economy_first_event_sec.has(event_name):
		economy_first_event_sec[event_name] = elapsed
	var event_team := int(payload.get("team", actor.get("team") if actor != null and is_instance_valid(actor) and actor.get("team") != null else -1))
	if event_team == BLUE or event_team == RED:
		var team_key := "blue" if event_team == BLUE else "red"
		var team_counts: Dictionary = economy_team_event_counts[team_key]
		team_counts[event_name] = int(team_counts.get(event_name, 0)) + 1
		var first_events: Dictionary = economy_team_first_event_sec[team_key]
		if not first_events.has(event_name):
			first_events[event_name] = elapsed
	economy_events.append(event)
	while economy_events.size() > ECONOMY_EVENT_LIMIT:
		economy_events.pop_front()

func _economy_slot_id(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	var slot: Dictionary = slot_registry.get_slot_for_actor(actor)
	if not slot.is_empty():
		return String(slot.get("slot_id", ""))
	var actor_team := int(actor.get("team")) if actor.get("team") != null else -1
	var team_label := "blue" if actor_team == BLUE else ("red" if actor_team == RED else "neutral")
	return "%s:unregistered" % team_label

func get_day_state() -> Dictionary:
	var phase := get_day_phase()
	var vision_range := get_vision_range_for_phase(phase)
	return {
		"day": day_index,
		"elapsed": day_timer,
		"remaining": maxf(DAY_LENGTH_SEC - day_timer, 0.0),
		"length": DAY_LENGTH_SEC,
		"food_sources": food_sources.size(),
		"phase": phase,
		"vision_range": vision_range,
		"vision_multiplier": vision_range / VISION_RANGE_DAY
	}

func get_day_phase() -> String:
	var f := day_timer / DAY_LENGTH_SEC
	if f < DAY_PHASE_DAWN_END:
		return "dawn"
	if f < DAY_PHASE_DAY_END:
		return "day"
	if f < DAY_PHASE_DUSK_END:
		return "dusk"
	return "night"

func get_vision_range_for_phase(phase := "") -> float:
	match (phase if not phase.is_empty() else get_day_phase()):
		"day":
			return VISION_RANGE_DAY
		"dusk":
			return VISION_RANGE_DUSK
		"night":
			return VISION_RANGE_NIGHT
		"dawn":
			return VISION_RANGE_DAWN
	return VISION_RANGE_DAY

func _vision_ghost_fade() -> float:
	match get_day_phase():
		"dusk":
			return VISION_GHOST_FADE_DUSK
		"night":
			return VISION_GHOST_FADE_NIGHT
	return VISION_GHOST_FADE_DAY

# --- Team vision API (BB-VIS-1) --------------------------------------------------
# Shared per-team information layer. Six info-states per Decision #35. Fog gates POSITION
# and IDENTITY only -- never combat telegraphs (those are drawn unconditionally).
func is_entity_visible_to_team(entity: Node, team: int) -> bool:
	var state := get_entity_info_state(entity, team)
	return state == INFO_VISIBLE or state == INFO_REVEALED

func get_entity_info_state(entity: Node, team: int) -> String:
	if entity == null or not is_instance_valid(entity):
		return INFO_HIDDEN
	if entity.has_method("is_alive") and not entity.is_alive():
		return INFO_HIDDEN
	if ("team" in entity) and int(entity.get("team")) == team:
		return INFO_VISIBLE  # a team always sees its own members
	var id := entity.get_instance_id()
	var sensed := _sensory_state_for(entity, team)
	if sensed == INFO_VISIBLE:
		return INFO_VISIBLE
	if _is_revealed(team, id):
		return INFO_REVEALED  # forced reveal (Teratornis / Sky Scare) gives exact position
	if sensed == INFO_HEARD:
		return INFO_HEARD
	var record: Dictionary = team_vision.get(team, {}).get(id, {})
	if not record.is_empty() and (elapsed - float(record.get("last_seen", -9999.0))) <= _vision_ghost_fade():
		return INFO_LAST_KNOWN
	if _point_in_team_territory(entity.global_position, team):
		return INFO_SUSPECTED  # an unseen intruder on our own turf
	return INFO_HIDDEN

func reveal_entity_to_team(entity: Node, team: int, duration: float) -> void:
	if entity == null or not is_instance_valid(entity) or not (team == BLUE or team == RED):
		return
	var reveals: Dictionary = team_reveals[team]
	var id := entity.get_instance_id()
	reveals[id] = maxf(float(reveals.get(id, 0.0)), duration)

func get_visible_enemy_targets(actor: Node) -> Array[Node]:
	var out: Array[Node] = []
	if actor == null or not is_instance_valid(actor) or not ("team" in actor):
		return out
	var team := int(actor.get("team"))
	for entity: Node in entities:
		if entity == null or not is_instance_valid(entity) or not ("team" in entity):
			continue
		if int(entity.get("team")) == team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		if is_entity_visible_to_team(entity, team):
			out.append(entity)
	return out

func get_world_view_team() -> int:
	if player != null and is_instance_valid(player) and ("team" in player):
		return int(player.get("team"))
	return BLUE

func get_world_entity_info_state(entity: Node) -> String:
	if not _is_world_fog_gated_enemy(entity):
		return INFO_VISIBLE
	return get_entity_info_state(entity, get_world_view_team())

func is_world_entity_rendered(entity: Node) -> bool:
	var state := get_world_entity_info_state(entity)
	return state == INFO_VISIBLE or state == INFO_REVEALED

func get_world_info_markers(team := -1) -> Array[Dictionary]:
	var view_team := int(team)
	if view_team < 0:
		view_team = get_world_view_team()
	var markers: Array[Dictionary] = []
	for entity: Node in entities:
		if not _is_info_marker_candidate(entity, view_team):
			continue
		var state := get_entity_info_state(entity, view_team)
		if state == INFO_VISIBLE or state == INFO_HIDDEN:
			continue
		var point := get_info_marker_point(view_team, entity)
		if point == Vector2.INF:
			continue
		markers.append({
			"state": state,
			"point": point,
			"team": int(entity.get("team")),
			"entity_id": entity.get_instance_id(),
			"exact": state == INFO_REVEALED or state == INFO_LAST_KNOWN
		})
	return markers

func get_information_debug_state(team := -1) -> Dictionary:
	var view_team := int(team)
	if view_team < 0:
		view_team = get_world_view_team()
	var enemy_info := _blank_info_counts()
	for entity: Node in entities:
		if not _is_info_marker_candidate(entity, view_team):
			continue
		var state := get_entity_info_state(entity, view_team)
		enemy_info[state] = int(enemy_info.get(state, 0)) + 1
	var food_info := _blank_info_counts()
	for food in food_sources:
		var food_state := get_food_minimap_state(food, view_team)
		var state := String(food_state.get("state", INFO_HIDDEN))
		food_info[state] = int(food_info.get(state, 0)) + 1
	return {
		"team": view_team,
		"phase": get_day_phase(),
		"vision_range": get_team_vision_range(view_team),
		"enemy_info": enemy_info,
		"food_info": food_info,
		"reveal_count": team_reveals.get(view_team, {}).size(),
		"objective_event_count": _objective_feed_count(),
		"live_objective_count": _live_objective_count()
	}

func _blank_info_counts() -> Dictionary:
	return {
		INFO_VISIBLE: 0,
		INFO_REVEALED: 0,
		INFO_HEARD: 0,
		INFO_LAST_KNOWN: 0,
		INFO_SUSPECTED: 0,
		INFO_HIDDEN: 0
	}

func _objective_feed_count() -> int:
	var count := 0
	for entry: Dictionary in kill_feed:
		if String(entry.get("kind", "")) == "objective":
			count += 1
	return count

func _live_objective_count() -> int:
	var count := 0
	for zone: Dictionary in animal_zone_states:
		var state := String(zone.get("objective_state", ""))
		if state in ["active", "claimable", "contesting"]:
			count += 1
	return count

func get_food_minimap_state(food: Node, team: int) -> Dictionary:
	if not _is_food_source_valid(food) or not (team == BLUE or team == RED):
		return {"visible": false, "state": INFO_HIDDEN, "point": Vector2.INF}
	if _is_food_visible_to_team(food, team):
		return {
			"visible": true,
			"state": INFO_VISIBLE,
			"point": food.global_position,
			"stale": false
		}
	var record: Dictionary = team_food_vision.get(team, {}).get(food.get_instance_id(), {})
	if record.is_empty():
		return {"visible": false, "state": INFO_HIDDEN, "point": Vector2.INF}
	if elapsed - float(record.get("last_seen", -9999.0)) > FOOD_MINIMAP_MEMORY_SEC:
		return {"visible": false, "state": INFO_HIDDEN, "point": Vector2.INF}
	return {
		"visible": true,
		"state": INFO_LAST_KNOWN,
		"point": record.get("point", Vector2.INF),
		"stale": true,
		"age": elapsed - float(record.get("last_seen", elapsed))
	}

func _is_food_source_valid(food: Node) -> bool:
	if food == null or not is_instance_valid(food):
		return false
	if food.has_method("is_alive") and not food.is_alive():
		return false
	return true

func _is_food_visible_to_team(food: Node, team: int) -> bool:
	if not _is_food_source_valid(food):
		return false
	if _point_in_team_habitat(food.global_position, team):
		return true
	var vision_range := get_team_vision_range(team)
	for member in _team_vision_members(team):
		if member.global_position.distance_to(food.global_position) <= vision_range and has_line_of_sight(member.global_position, food.global_position, 3.0):
			return true
	return false

func _record_food_sighting(food: Node, team: int) -> void:
	if not _is_food_source_valid(food) or not (team == BLUE or team == RED):
		return
	team_food_vision[team][food.get_instance_id()] = {
		"point": food.global_position,
		"last_seen": elapsed
	}

func _forget_food_source(food: Node) -> void:
	if food == null:
		return
	var id := food.get_instance_id()
	for team in [BLUE, RED]:
		team_food_vision[team].erase(id)

func _point_in_team_habitat(point: Vector2, team: int) -> bool:
	if terrain_map == null or not terrain_map.has_method("get_team_habitat_rect"):
		return false
	return terrain_map.get_team_habitat_rect(team).has_point(point)

func _is_info_marker_candidate(entity: Node, view_team: int) -> bool:
	if entity == null or not is_instance_valid(entity) or not ("team" in entity):
		return false
	var team := int(entity.get("team"))
	if team < 0 or team == view_team:
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		return true
	var script: Script = entity.get_script()
	return script != null and String(script.resource_path).ends_with("/minion.gd")

func _apply_world_vision_masking() -> void:
	# BB-VIS-4: the local world view should not draw exact enemy mobile positions
	# that are only heard/remembered/suspected. Combat, collision, and telegraphs
	# still run on the real entities; this is a render-only truth downgrade.
	for entity: Node in entities:
		if not _is_world_fog_gated_enemy(entity):
			continue
		if not (entity is CanvasItem):
			continue
		var should_render := is_world_entity_rendered(entity)
		if bool(entity.get("visible")) != should_render:
			entity.set("visible", should_render)
			if should_render and entity.has_method("queue_redraw"):
				entity.queue_redraw()

func _is_world_fog_gated_enemy(entity: Node) -> bool:
	if entity == null or not is_instance_valid(entity) or not ("team" in entity):
		return false
	var team := int(entity.get("team"))
	var view_team := get_world_view_team()
	if team < 0 or team == view_team:
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		return true
	var script: Script = entity.get_script()
	return script != null and String(script.resource_path).ends_with("/minion.gd")

func get_last_known_point(team: int, entity: Node) -> Vector2:
	# The stored last-seen position for a fog-gated enemy, or Vector2.INF if never seen.
	if entity == null or not is_instance_valid(entity):
		return Vector2.INF
	var record: Dictionary = team_vision.get(team, {}).get(entity.get_instance_id(), {})
	if record.is_empty():
		return Vector2.INF
	return record.get("last_point", Vector2.INF)

func get_info_marker_point(team: int, entity: Node) -> Vector2:
	# Public marker point for degraded information: exact for visible/revealed,
	# stored for last-known, coarse for heard/suspected, never for fully hidden.
	if entity == null or not is_instance_valid(entity):
		return Vector2.INF
	var state := get_entity_info_state(entity, team)
	match state:
		INFO_VISIBLE, INFO_REVEALED:
			return entity.global_position
		INFO_LAST_KNOWN:
			return get_last_known_point(team, entity)
		INFO_HEARD, INFO_SUSPECTED:
			return _coarse_info_marker_point(entity.global_position, entity.get_instance_id() + team * 31)
	return Vector2.INF

func _coarse_info_marker_point(point: Vector2, salt: int) -> Vector2:
	var grid := VISION_NOISE_GRID
	var snapped := Vector2(roundf(point.x / grid) * grid, roundf(point.y / grid) * grid)
	var sx := float(posmod(salt, 5) - 2) * 5.0
	var sy := float(posmod(floori(float(salt) / 5.0), 5) - 2) * 5.0
	return snapped + Vector2(sx, sy)

func _is_revealed(team: int, id: int) -> bool:
	return float(team_reveals.get(team, {}).get(id, 0.0)) > 0.0

func _point_in_team_territory(point: Vector2, team: int) -> bool:
	# The arena is symmetric about x = 0: blue owns the left half, red the right.
	if team == BLUE:
		return point.x < 0.0
	if team == RED:
		return point.x > 0.0
	return false

func _team_vision_members(team: int) -> Array[Node]:
	var out: Array[Node] = []
	for entity: Node in entities:
		if entity == null or not is_instance_valid(entity) or not ("team" in entity):
			continue
		if int(entity.get("team")) != team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		out.append(entity)
	return out

func _sensory_state_for(entity: Node, team: int) -> String:
	# Live sight/hearing only (no memory): INFO_VISIBLE | INFO_HEARD | INFO_HIDDEN.
	var vision_range := get_team_vision_range(team)
	var hearing_range := vision_range + VISION_HEARING_BONUS
	var stealthed: bool = entity.has_method("is_stealthed") and entity.is_stealthed()
	var pos: Vector2 = entity.global_position
	var best := INFO_HIDDEN
	for member in _team_vision_members(team):
		var d: float = member.global_position.distance_to(pos)
		if d <= vision_range and not stealthed and has_line_of_sight(member.global_position, pos, 4.0):
			return INFO_VISIBLE
		if d <= hearing_range:
			best = INFO_HEARD
	return best

func _tick_team_vision(delta: float) -> void:
	# Reveal timers decay every frame (cheap); last-known records refresh on a throttle.
	for team in [BLUE, RED]:
		var reveals: Dictionary = team_reveals[team]
		for id in reveals.keys():
			var remaining := float(reveals[id]) - delta
			if remaining <= 0.0:
				reveals.erase(id)
			else:
				reveals[id] = remaining
	vision_tick_timer -= delta
	if vision_tick_timer > 0.0:
		return
	vision_tick_timer = VISION_TICK_SEC
	for team in [BLUE, RED]:
		var enemy := RED if team == BLUE else BLUE
		for entity in _team_vision_members(enemy):
			if _sensory_state_for(entity, team) == INFO_VISIBLE:
				team_vision[team][entity.get_instance_id()] = {
					"last_point": entity.global_position,
					"last_seen": elapsed,
					"ever": true
				}
		for food in food_sources:
			if _is_food_visible_to_team(food, team):
				_record_food_sighting(food, team)

func _reset_team_vision() -> void:
	team_vision = {BLUE: {}, RED: {}}
	team_reveals = {BLUE: {}, RED: {}}
	team_food_vision = {BLUE: {}, RED: {}}
	vision_tick_timer = 0.0

func get_lane_destination(attacking_team: int, lane_anchor: Vector2) -> Vector2:
	# March to the nearest surviving enemy hut on this lane; if none remain,
	# push into the habitat toward the core.
	var enemy_team := RED if attacking_team == BLUE else BLUE
	var best_position := Vector2.ZERO
	var best_distance := INF
	for hut in huts:
		if hut == null or not is_instance_valid(hut) or not hut.is_alive() or hut.team != enemy_team:
			continue
		var distance: float = hut.global_position.distance_to(lane_anchor)
		if distance < best_distance:
			best_distance = distance
			best_position = hut.global_position
	if best_distance < INF:
		return best_position
	var core = cores.get(enemy_team)
	return core.global_position if core != null else lane_anchor

func can_damage_core(defending_team: int) -> bool:
	if _is_competitive_mode() and not bool(match_rules.get("core_targetable", true)):
		return false
	return is_habitat_exposed(defending_team)

func is_habitat_exposed(defending_team: int) -> bool:
	return int(huts_lost.get(defending_team, 0)) > 0 or not _team_has_huts(defending_team)

func _team_has_huts(defending_team: int) -> bool:
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.team == defending_team:
			return true
	return int(huts_lost.get(defending_team, 0)) > 0

func on_hut_destroyed(hut: Node) -> void:
	huts.erase(hut)
	huts_lost[hut.team] = int(huts_lost.get(hut.team, 0)) + 1
	var attacking_team := int(hut.get("last_damage_source_team")) if hut.get("last_damage_source_team") != null else -1
	if attacking_team == BLUE or attacking_team == RED:
		team_stats[attacking_team]["huts_destroyed"] += 1
	var team_name := _team_name(hut.team)
	add_kill_feed("%s mud hut destroyed — %s habitat exposed!" % [team_name, team_name])
	add_circle_telegraph(cores[hut.team].global_position, 90.0, Color(1.0, 0.6, 0.2, 0.8), 1.0, 5.0, true)
	for actor in breeding_actors:
		if actor != null and is_instance_valid(actor) and int(actor.get("team")) == int(hut.team):
			actor.queue_redraw()

func register_dam(dam: Node) -> void:
	if not dams.has(dam):
		dams.append(dam)
	register_entity(dam)

func unregister_dam(dam: Node) -> void:
	dams.erase(dam)

func get_dam_rects() -> Array:
	var rects: Array = []
	for dam in dams:
		if dam != null and is_instance_valid(dam):
			rects.append(dam.rect)
	return rects

func register_entity(entity: Node) -> void:
	if not entities.has(entity):
		entities.append(entity)
	if entity.has_method("is_scored_actor") and entity.is_scored_actor():
		_ensure_actor_stats(entity)
	if entity.has_method("refresh_team_breeding_buffs"):
		entity.refresh_team_breeding_buffs()

func unregister_entity(entity: Node) -> void:
	entities.erase(entity)
	minions.erase(entity)

func has_debug_hurtbox_overlay_contract() -> bool:
	return true

func get_hurtbox_debug_overlays() -> Array[Dictionary]:
	var overlays: Array[Dictionary] = []
	for entity: Node in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		var radius_value: Variant = entity.get("body_radius")
		if typeof(radius_value) != TYPE_FLOAT and typeof(radius_value) != TYPE_INT:
			continue
		var hull: Dictionary = HurtboxScript.hull_of(entity)
		overlays.append({
			"type": "hull",
			"actor": entity,
			"shape": String(hull.get("kind", "circle")),
			"center": hull.get("center", Vector2.ZERO),
			"radius": float(hull.get("radius", 0.0)),
			"half_len": float(hull.get("half_len", 0.0)),
			"axis": hull.get("axis", Vector2.RIGHT)
		})
		for region: Dictionary in HurtboxScript.open_regions(entity):
			overlays.append({
				"type": "region",
				"actor": entity,
				"region": String(region.get("region", "hull")),
				"center": region.get("center", Vector2.ZERO),
				"radius": float(region.get("radius", 0.0)),
				"region_mult": float(region.get("region_mult", 1.0))
			})
	return overlays

func spawn_projectile(projectile_team: int, start_position: Vector2, direction: Vector2, damage: float, speed: float, color: Color, pierce := false, radius := 7.0, lifetime := 1.6, source_actor: Node = null) -> void:
	var projectile: Node = ProjectileScript.new()
	add_child(projectile)
	projectile.setup(self, projectile_team, start_position, direction, _outgoing_damage(source_actor, damage), speed, color, pierce, radius, lifetime, source_actor)

func add_line_telegraph(from: Vector2, to: Vector2, color: Color, duration := 0.16, width := 4.0) -> void:
	telegraphs.append({
		"type": "line",
		"from": from,
		"to": to,
		"color": color,
		"duration": duration,
		"remaining": duration,
		"width": width
	})

func add_circle_telegraph(center: Vector2, radius: float, color: Color, duration := 0.22, width := 3.0, filled := false) -> void:
	telegraphs.append({
		"type": "circle",
		"center": center,
		"radius": radius,
		"color": color,
		"duration": duration,
		"remaining": duration,
		"width": width,
		"filled": filled
	})

func record_vfx_event(event: Dictionary) -> void:
	vfx_events.append(event.duplicate())
	if vfx_events.size() > 240:
		vfx_events.pop_front()
	_record_landed_hit_telemetry(event)
	_maybe_trigger_squad_aggro(event)
	_spawn_vfx_for_event(event)
	queue_redraw()

func _maybe_trigger_squad_aggro(event: Dictionary) -> void:
	if not _is_1v1_trio_mode() or squad_command != SQUAD_COMMAND_FOLLOW or squad_command_timer <= 0.0:
		return
	if String(event.get("type", "")) != "hit_landed":
		return
	var source: Node = event.get("source", null)
	var target: Node = event.get("target", null)
	if source == player:
		_issue_squad_aggro(target)

func resolve_projectile_hits(projectile: Node) -> void:
	if projectile_crosses_cover(projectile.previous_position, projectile.global_position, projectile.radius):
		projectile.queue_free()
		return

	for entity: Node in entities:
		if projectile.hit_entities.has(entity):
			continue
		if not TargetFilter.is_live_damage_target(projectile, entity, {"require_damage_api": false, "allow_wildlife": _projectile_allows_wildlife(projectile)}):
			continue
		# Hull test (decision #21): capsule bodies are hittable along their length.
		var hit_info: Dictionary = HitShapeScript.circle_hit(projectile.global_position, projectile.radius, entity)
		if bool(hit_info.hit):
			# Projectiles are RANGED (decision #1) — flying targets are hit
			# normally and heavy shots can spike birds (decision #20).
			if entity.has_method("take_damage_event"):
				var event := DamageEventScript.new()
				event.setup(projectile.damage, DamageEventScript.DELIVERY_RANGED, DamageEventScript.PLANE_GROUND, projectile.source_actor, "projectile")
				event.set_hit(hit_info.point, hit_info.normal, String(hit_info.get("region", "hull")), float(hit_info.get("region_mult", 1.0)))
				entity.take_damage_event(event)
			else:
				entity.take_damage(projectile.damage, projectile.team, projectile.source_actor)
			projectile.hit_entities.append(entity)
			if not projectile.pierce:
				projectile.queue_free()
				return

	for core_team: int in cores.keys():
		var core: Node = cores[core_team]
		if core.team == projectile.team:
			continue
		if core.global_position.distance_to(projectile.global_position) <= projectile.radius + core.radius:
			if not can_damage_core(core.team):
				_show_core_shielded(core)
				projectile.queue_free()
				return
			var core_damage: float = projectile.damage * get_core_damage_multiplier(projectile.team)
			core.take_damage(core_damage, projectile.team, projectile.source_actor)
			record_core_damage(projectile.team, core_damage, projectile.source_actor)
			projectile.queue_free()
			return

func get_closest_enemy(source: Node, max_distance: float) -> Node:
	var closest: Node = null
	var closest_distance: float = max_distance
	for entity: Node in entities:
		if not TargetFilter.is_live_damage_target(source, entity, {"require_damage_api": false}):
			continue
		if not has_line_of_sight(source.global_position, entity.global_position, source.body_radius):
			continue
		var distance: float = source.global_position.distance_to(entity.global_position)
		if distance < closest_distance:
			closest = entity
			closest_distance = distance
	return closest

func _projectile_allows_wildlife(projectile: Node) -> bool:
	var source_actor: Node = projectile.get("source_actor") if projectile != null and projectile.get("source_actor") != null else null
	return source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("is_scored_actor") and source_actor.is_scored_actor()

func damage_enemies_in_radius(source_team: int, center: Vector2, radius: float, damage: float, source_actor: Node = null, source_ability := "Area") -> void:
	var final_damage: float = _outgoing_damage(source_actor, damage)
	for entity: Node in entities:
		if not _valid_target(entity) or entity.team == source_team:
			continue
		if cover_blocks_point(center, entity.global_position, minf(radius, 18.0)):
			continue
		var hit_info: Dictionary = HitShapeScript.circle_hit(center, radius, entity)
		if bool(hit_info.hit):
			if entity.has_method("take_damage_event"):
				var event := DamageEventScript.new()
				event.setup(final_damage, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
				event.set_hit(hit_info.point, hit_info.normal, String(hit_info.get("region", "hull")), float(hit_info.get("region_mult", 1.0)))
				entity.take_damage_event(event)
			else:
				entity.take_damage(final_damage, source_team, source_actor)

	for core_team: int in cores.keys():
		var core: Node = cores[core_team]
		if core.team != source_team and core.global_position.distance_to(center) <= radius + core.radius:
			if not can_damage_core(core.team):
				_show_core_shielded(core)
				continue
			var core_damage: float = final_damage * get_core_damage_multiplier(source_team)
			core.take_damage(core_damage, source_team, source_actor)
			record_core_damage(source_team, core_damage, source_actor)

## Creature-only area damage: hits scored creatures of other teams but never cores,
## huts, dams, or breeding actors. Used by the neutral side boss (team -1) so its bite
## threatens fighters without collaterally damaging structures/cores (BB-BOSS-4, review #2).
func damage_creatures_in_radius(source_team: int, center: Vector2, radius: float, damage: float, source_actor: Node = null, source_ability := "Area") -> void:
	var final_damage: float = _outgoing_damage(source_actor, damage)
	for entity: Node in entities:
		if not _valid_target(entity) or entity.team == source_team:
			continue
		if not entity.has_method("is_scored_actor") or not entity.is_scored_actor():
			continue
		if cover_blocks_point(center, entity.global_position, minf(radius, 18.0)):
			continue
		var hit_info: Dictionary = HitShapeScript.circle_hit(center, radius, entity)
		if bool(hit_info.hit):
			if entity.has_method("take_damage_event"):
				var event := DamageEventScript.new()
				event.setup(final_damage, DamageEventScript.DELIVERY_AREA, DamageEventScript.PLANE_GROUND, source_actor, source_ability)
				event.set_hit(hit_info.point, hit_info.normal, String(hit_info.get("region", "hull")), float(hit_info.get("region_mult", 1.0)))
				entity.take_damage_event(event)
			else:
				entity.take_damage(final_damage, source_team, source_actor)

func _outgoing_damage(source_actor: Node, amount: float) -> float:
	if source_actor != null and is_instance_valid(source_actor) and source_actor.has_method("modify_outgoing_damage"):
		return source_actor.modify_outgoing_damage(amount)
	return amount

func heal_allies_in_radius(source_team: int, center: Vector2, radius: float, amount: float) -> void:
	for entity: Node in entities:
		if not _valid_target(entity) or entity.team != source_team:
			continue
		if entity.has_method("heal") and entity.global_position.distance_to(center) <= radius + entity.body_radius:
			entity.heal(amount)

func record_death(victim: Node, killer: Node = null) -> void:
	if victim == null or not victim.has_method("is_scored_actor") or not victim.is_scored_actor():
		return
	if bot_brain != null and bot_brain.has_method("reset_actor"):
		bot_brain.reset_actor(victim)
	team_director_timer = 0.0

	var victim_key := _get_actor_key(victim)
	_ensure_actor_stats(victim)
	actor_stats[victim_key]["deaths"] += 1
	team_stats[victim.team]["deaths"] += 1

	if killer != null and is_instance_valid(killer) and killer.has_method("is_scored_actor") and killer.is_scored_actor() and killer.team != victim.team:
		var killer_key := _get_actor_key(killer)
		_ensure_actor_stats(killer)
		actor_stats[killer_key]["kills"] += 1
		team_stats[killer.team]["kills"] += 1
		add_kill_feed("%s eliminated %s" % [killer.get_actor_name(), victim.get_actor_name()])
	else:
		add_kill_feed("%s was eliminated" % victim.get_actor_name())
	_shed_team_kill_growth_on_death(victim)
	_consume_stock_for_death(victim)

func _consume_stock_for_death(victim: Node) -> void:
	if not uses_stock_respawn(victim):
		return
	var respawn_duration := float(victim.get("respawn_duration") if victim.get("respawn_duration") != null else 5.0)
	var slot: Dictionary = stock_manager.record_ko(victim, respawn_duration)
	if bool(slot.get("consumed", false)):
		_record_team_actor_stat(victim.team, "stock_losses", 1, victim)
	else:
		return
	var remaining := int(slot.get("stocks_remaining", 0))
	var max_stocks := int(slot.get("max_stocks", StockManagerScript.MAX_STOCKS))
	switch_action_neutral_ticks.erase(victim.get_instance_id())
	if String(slot.get("state", "")) == StockManagerScript.STATE_EXHAUSTED:
		add_kill_feed("%s is out of stocks" % victim.get_actor_name())
	else:
		add_kill_feed("%s stocks %d/%d" % [victim.get_actor_name(), remaining, max_stocks])
	_check_stock_victory(victim.team)

func uses_stock_respawn(actor: Node) -> bool:
	return bool(match_rules.get("stock_respawns", false)) \
		and slot_registry.is_sealed() \
		and actor != null \
		and stock_manager.has_actor(actor)

func tick_stock_respawn(actor: Node, delta: float) -> bool:
	if not uses_stock_respawn(actor):
		return false
	var slot: Dictionary = stock_manager.tick_actor_respawn(actor, delta)
	if slot.is_empty():
		return false
	actor.respawn_timer = float(slot.get("respawn_timer", actor.respawn_timer))
	return stock_manager.can_respawn(actor)

func get_actor_respawn_position(actor: Node) -> Vector2:
	if uses_stock_respawn(actor):
		var rect: Rect2 = terrain_map.get_team_habitat_rect(actor.team)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			var slot: Dictionary = stock_manager.get_slot_for_actor(actor)
			var slot_index := int(slot.get("slot_index", 1))
			return rect.position + rect.size * 0.5 + Vector2(0.0, float(slot_index - 1) * 34.0)
	return get_team_spawn(actor.team)

func on_actor_respawned(actor: Node) -> void:
	if bot_brain != null and bot_brain.has_method("reset_actor"):
		bot_brain.reset_actor(actor)
	team_director_timer = 0.0
	if uses_stock_respawn(actor):
		switch_action_neutral_ticks[actor.get_instance_id()] = 1
		stock_manager.mark_respawned(actor)

func _check_stock_victory(losing_team: int) -> void:
	if match_over or not stock_manager.team_exhausted(losing_team):
		return
	var winner := "Red" if losing_team == BLUE else "Blue"
	_finish_match(winner, "stock_elimination", "%s wins by stock elimination! Press Enter to restart or Esc for menu." % winner)
	add_kill_feed("%s squad is out of stocks" % _team_name(losing_team))

func _show_core_shielded(core: Node) -> void:
	if hut_defend_hint_timer > 0.0:
		return
	hut_defend_hint_timer = 1.2
	var shield_text := "HABITAT ANCHOR - eliminate enemy stocks" if _is_competitive_mode() else "SHIELDED - destroy a mud hut first"
	telegraphs.append({
		"type": "float_text",
		"position": core.global_position + Vector2(-20.0, -70.0),
		"text": shield_text,
		"color": Color(0.7, 0.85, 1.0, 0.95),
		"size": 13,
		"duration": 1.1,
		"remaining": 1.1
	})

func record_core_damage(source_team: int, amount: float, source_actor: Node = null) -> void:
	_record_team_actor_stat(source_team, "core_damage", amount, source_actor)

func record_hut_damage(source_team: int, amount: float, source_actor: Node = null) -> void:
	_record_team_actor_stat(source_team, "hut_damage", amount, source_actor)

func get_core_damage_multiplier(_team: int) -> float:
	return 1.0

func add_kill_feed(message: String, kind: String = "feed", duration: float = 4.5, metadata: Dictionary = {}) -> void:
	var entry := metadata.duplicate(true)
	entry["message"] = message
	entry["remaining"] = duration
	entry["kind"] = kind
	kill_feed.push_front(entry)
	while kill_feed.size() > 5:
		kill_feed.pop_back()

func add_objective_feed(message: String, action: String, team: int = -1, family: String = "", zone_id: String = "") -> void:
	add_kill_feed(message, "objective", 6.0, {
		"action": action,
		"team": team,
		"family": family,
		"zone_id": zone_id
	})

func get_enemy_core(team: int):
	return cores.get(RED if team == BLUE else BLUE)

func get_team_spawn(team: int) -> Vector2:
	return team_spawns.get(team, Vector2.ZERO)

func get_bot_spawn(team: int, bot_name: String) -> Vector2:
	return bot_spawns.get(bot_name, get_team_spawn(team))

func get_terrain_zone(point: Vector2) -> String:
	return terrain_map.get_zone_at(point)

func is_near_view(point: Vector2) -> bool:
	# True when a point is close enough to the player's camera view that its
	# node should bother redrawing. Generous margin for the cursor-led camera.
	if player == null or not is_instance_valid(player):
		return true
	return point.distance_squared_to(player.global_position) < 810000.0  # 900px

func is_inside_arena(point: Vector2) -> bool:
	return arena_rect.has_point(point)

func clamp_to_arena(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, arena_rect.position.x + 24.0, arena_rect.end.x - 24.0), clampf(point.y, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0))

# Soft body collision (decision #27): grounded live movers push apart with a
# capped per-tick correction so bodies read as solid without hard physics.
# Airborne creatures pass over, dashers ghost through, latch pairs stay
# attached. Deterministic: entities iterated in registration order.
const SEPARATION_MAX_PUSH_PX := 2.0

func resolve_body_separation() -> void:
	var bodies: Array[Node] = []
	for entity: Node in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_alive") and not entity.is_alive():
			continue
		# Movers only (creatures + minions); huts/cores are terrain-like.
		if not _is_separation_body(entity):
			continue
		bodies.append(entity)
	# PERF: hulls computed once per body, and a squared-distance broad phase
	# rejects far pairs before any hull math (this pass regressed to
	# 80 ms/frame without it — see perf_harness before committing changes).
	var hulls: Array[Dictionary] = []
	var reaches := PackedFloat32Array()
	for body in bodies:
		var hull: Dictionary = HurtboxScript.hull_of(body)
		hulls.append(hull)
		reaches.append(float(hull.radius) + float(hull.half_len))
	for i: int in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Node = bodies[i]
			var b: Node = bodies[j]
			var max_gap: float = reaches[i] + reaches[j]
			if a.global_position.distance_squared_to(b.global_position) > max_gap * max_gap:
				continue
			if _separation_exempt(a, b):
				continue
			var push: Vector2 = HurtboxScript.separation_push_hulls(hulls[i], hulls[j])
			if push == Vector2.ZERO:
				continue
			var half: Vector2 = push * 0.5
			if half.length() > SEPARATION_MAX_PUSH_PX:
				half = half.normalized() * SEPARATION_MAX_PUSH_PX
			a.global_position = resolve_body_position(a.global_position + half, a.body_radius)
			b.global_position = resolve_body_position(b.global_position - half, b.body_radius)

func _is_separation_body(entity: Node) -> bool:
	if entity is CharacterBody2D:
		return true
	return entity.has_method("uses_manual_movement_body") and bool(entity.call("uses_manual_movement_body"))

func _separation_exempt(a: Node, b: Node) -> bool:
	if _passes_over_bodies(a) or _passes_over_bodies(b):
		return true
	if a.get("latch_victim") == b or b.get("latch_victim") == a:
		return true
	return false

func _passes_over_bodies(body: Node) -> bool:
	if body.has_method("is_airborne") and body.is_airborne():
		return true
	var dash_value: Variant = body.get("dash_timer")
	if typeof(dash_value) == TYPE_FLOAT and float(dash_value) > 0.0:
		return true
	var knockback_value: Variant = body.get("knockback_timer")
	if typeof(knockback_value) == TYPE_FLOAT and float(knockback_value) > 0.0:
		return true
	var pass_obstacles_value: Variant = body.get("pass_obstacles_timer")
	if typeof(pass_obstacles_value) == TYPE_FLOAT and float(pass_obstacles_value) > 0.0:
		return true
	return false

func resolve_body_position(point: Vector2, radius: float) -> Vector2:
	var resolved := Vector2(clampf(point.x, arena_rect.position.x + radius, arena_rect.end.x - radius), clampf(point.y, arena_rect.position.y + radius, arena_rect.end.y - radius))
	for cover in cover_rects + get_dam_rects():
		var expanded: Rect2 = cover.grow(radius)
		if not expanded.has_point(resolved):
			continue

		var left_distance := absf(resolved.x - expanded.position.x)
		var right_distance := absf(expanded.end.x - resolved.x)
		var top_distance := absf(resolved.y - expanded.position.y)
		var bottom_distance := absf(expanded.end.y - resolved.y)
		var smallest := minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))

		if smallest == left_distance:
			resolved.x = expanded.position.x
		elif smallest == right_distance:
			resolved.x = expanded.end.x
		elif smallest == top_distance:
			resolved.y = expanded.position.y
		else:
			resolved.y = expanded.end.y

	return resolved

func get_steering_direction(from: Vector2, to: Vector2, radius: float, team: int) -> Vector2:
	var direct := (to - from).normalized()
	if direct == Vector2.ZERO:
		return Vector2.ZERO

	if not _body_step_hits_cover(from, direct, radius):
		return direct

	var options := [
		direct.rotated(PI * 0.5),
		direct.rotated(-PI * 0.5),
		(direct + Vector2(0.0, 1.0 if team == BLUE else -1.0) * 0.75).normalized(),
		(direct + Vector2(0.0, -1.0 if team == BLUE else 1.0) * 0.75).normalized(),
		-direct
	]
	var best_direction := Vector2.ZERO
	var best_score := -2.0
	for option in options:
		if option == Vector2.ZERO or _body_step_hits_cover(from, option, radius):
			continue
		var score: float = option.dot(direct)
		if score > best_score:
			best_score = score
			best_direction = option
	return best_direction

func has_line_of_sight(from: Vector2, to: Vector2, radius := 4.0) -> bool:
	return not cover_blocks_point(from, to, radius)

func cover_blocks_point(from: Vector2, to: Vector2, radius := 4.0) -> bool:
	for cover: Rect2 in cover_rects:
		if _segment_intersects_rect(from, to, cover.grow(radius)):
			return true
	return false

# Exact segment-vs-AABB slab test — replaces the old 20px point-stepping walk.
static func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		var delta := d.x if axis == 0 else d.y
		var origin := a.x if axis == 0 else a.y
		var low := rect.position.x if axis == 0 else rect.position.y
		var high := rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0001:
			if origin < low or origin > high:
				return false
		else:
			var t1 := (low - origin) / delta
			var t2 := (high - origin) / delta
			if t1 > t2:
				var swap := t1
				t1 = t2
				t2 = swap
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return false
	return true

func projectile_crosses_cover(from: Vector2, to: Vector2, radius: float) -> bool:
	return cover_blocks_point(from, to, radius)

func _body_step_hits_cover(from: Vector2, direction: Vector2, radius: float) -> bool:
	var next_position := from + direction.normalized() * 34.0
	if not arena_rect.grow(-radius).has_point(next_position):
		return true
	for cover in cover_rects + get_dam_rects():
		if cover.grow(radius).has_point(next_position):
			return true
	return false

func _tick_telegraphs(delta: float) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var telegraph := telegraphs[i]
		if _telegraph_lost_anchor(telegraph):
			telegraphs.remove_at(i)
			continue
		telegraphs[i]["remaining"] = float(telegraphs[i]["remaining"]) - delta
		if float(telegraphs[i]["remaining"]) <= 0.0:
			telegraphs.remove_at(i)

func _draw_telegraphs() -> void:
	for telegraph in telegraphs:
		var remaining: float = telegraph.get("remaining", 0.0)
		var duration: float = maxf(telegraph.get("duration", 0.01), 0.01)
		var fade := clampf(remaining / duration, 0.0, 1.0)
		var color: Color = telegraph.get("color", Color.WHITE)
		color.a *= fade

		match String(telegraph.get("type", "")):
			"line":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 4.0)))
			"windup":
				_draw_windup_telegraph(telegraph, color)
			"swing":
				_draw_swing_telegraph(telegraph, color)
			"dash_trail":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 7.0)))
			"tracer":
				draw_line(telegraph["from"], telegraph["to"], color, float(telegraph.get("width", 3.0)))
			"aura_follow":
				var target = telegraph.get("target", null)
				if target != null and is_instance_valid(target):
					var ring_radius: float = float(telegraph.get("ring_radius", 22.0))
					draw_arc(target.global_position, ring_radius, 0.0, TAU, 32, color, float(telegraph.get("width", 3.0)))
			"tether":
				var attacker = telegraph.get("attacker", null)
				var victim = telegraph.get("victim", null)
				if attacker != null and victim != null and is_instance_valid(attacker) and is_instance_valid(victim):
					draw_line(attacker.global_position, victim.global_position, color, float(telegraph.get("width", 4.0)))
					_draw_latch_countdown(telegraph, attacker.global_position.lerp(victim.global_position, 0.5), color)
			"float_text":
				_draw_float_text(telegraph, color, fade)
			"circle":
				var center: Vector2 = telegraph["center"]
				var radius: float = telegraph["radius"]
				var width: float = telegraph.get("width", 3.0)
				if bool(telegraph.get("filled", false)):
					var fill_color := color
					fill_color.a *= 0.18
					draw_circle(center, radius, fill_color)
				draw_arc(center, radius, 0.0, TAU, 48, color, width)

func _draw_world_info_markers() -> void:
	for marker: Dictionary in get_world_info_markers():
		var state := String(marker.get("state", ""))
		var point: Vector2 = marker.get("point", Vector2.ZERO)
		var color := _world_info_marker_color(state)
		var radius := _world_info_marker_radius(state)
		draw_arc(point, radius, 0.0, TAU, 40, color, 2.0)
		if state == INFO_HEARD or state == INFO_SUSPECTED:
			draw_arc(point, radius + 8.0, PI * 0.12, PI * 1.88, 36, Color(color.r, color.g, color.b, color.a * 0.52), 1.2)
		elif state == INFO_REVEALED:
			draw_arc(point, radius + 5.0, 0.0, TAU, 36, Color(color.r, color.g, color.b, color.a * 0.7), 1.5)
		var label := _world_info_marker_label(state)
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, point + Vector2(-18.0, -radius - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 9, color)

func _draw_terrain_event_overlays() -> void:
	for event: Dictionary in get_terrain_event_visuals():
		var point: Vector2 = event.get("position", Vector2.ZERO)
		var radius := float(event.get("radius", 0.0))
		var ratio := clampf(float(event.get("ratio", 0.0)), 0.0, 1.0)
		if radius <= 0.0 or ratio <= 0.0:
			continue
		var kind := String(event.get("kind", "terrain_event"))
		var color := VisualGrammar.terrain_event_color(kind, 0.26 * ratio)
		var edge := VisualGrammar.terrain_event_color(kind, 0.56 * ratio)
		draw_circle(point, radius, color)
		draw_arc(point, radius, 0.0, TAU, 56, edge, 2.2)
		draw_arc(point, radius * 0.68, PI * 0.12, PI * 1.88, 42, Color(edge.r, edge.g, edge.b, edge.a * 0.72), 1.2)
		var label := _terrain_event_label(kind)
		if not label.is_empty():
			draw_string(ThemeDB.fallback_font, point + Vector2(-30.0, -radius - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 9, edge)

func _terrain_event_label(kind: String) -> String:
	match kind:
		"flood_scar":
			return "FLOOD"
		"toxic_bloom":
			return "TOXIN"
		"trampled_ground":
			return "TRAMPLE"
		"leaf_litter":
			return "LITTER"
		"wind_shear":
			return "WIND"
	return ""

func _world_info_marker_color(state: String) -> Color:
	match state:
		INFO_REVEALED:
			return VisualGrammar.telegraph_color("aura", 0.52, false)
		INFO_LAST_KNOWN:
			return Color(0.78, 0.84, 0.78, 0.34)
		INFO_HEARD:
			return VisualGrammar.ecology_zone_color("water_outline", 0.34)
		INFO_SUSPECTED:
			return VisualGrammar.ecology_zone_color("contested", 0.32)
	return Color(1.0, 1.0, 1.0, 0.0)

func _world_info_marker_radius(state: String) -> float:
	match state:
		INFO_REVEALED:
			return 24.0
		INFO_LAST_KNOWN:
			return 18.0
		INFO_HEARD:
			return 30.0
		INFO_SUSPECTED:
			return 34.0
	return 0.0

func _world_info_marker_label(state: String) -> String:
	match state:
		INFO_REVEALED:
			return "REVEAL"
		INFO_LAST_KNOWN:
			return "LAST"
		INFO_HEARD:
			return "SOUND"
		INFO_SUSPECTED:
			return "RUSTLE"
	return ""

func _draw_hurtbox_debug_overlays() -> void:
	for overlay: Dictionary in get_hurtbox_debug_overlays():
		match String(overlay.get("type", "")):
			"hull":
				var center: Vector2 = overlay.get("center", Vector2.ZERO)
				var radius := float(overlay.get("radius", 0.0))
				var axis: Vector2 = overlay.get("axis", Vector2.RIGHT)
				var half_len := float(overlay.get("half_len", 0.0))
				var color := Color(0.52, 0.82, 1.0, 0.28)
				if half_len > 0.0:
					var cap_a := center - axis.normalized() * half_len
					var cap_b := center + axis.normalized() * half_len
					draw_line(cap_a, cap_b, color, 1.6)
					draw_arc(cap_a, radius, 0.0, TAU, 32, color, 1.2)
					draw_arc(cap_b, radius, 0.0, TAU, 32, color, 1.2)
				else:
					draw_arc(center, radius, 0.0, TAU, 32, color, 1.2)
			"region":
				var center: Vector2 = overlay.get("center", Vector2.ZERO)
				var radius := float(overlay.get("radius", 0.0))
				var mult := clampf(float(overlay.get("region_mult", 1.0)), 0.75, 1.35)
				var color := Color(1.0, 0.66, 0.24, 0.34) if mult > 1.0 else Color(0.62, 0.82, 1.0, 0.3)
				draw_arc(center, radius, 0.0, TAU, 28, color, 1.6)

func _spawn_vfx_for_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"windup_started":
			var actor = event.get("actor", null)
			var duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "windup",
				"actor": actor,
				"aim": event.get("aim", Vector2.RIGHT),
				"reach_px": event.get("reach_px", 24.0),
				"color": Color(1.0, 0.78, 0.22, 0.95),
				"duration": duration,
				"remaining": duration
			})
		"attack_swung":
			telegraphs.append({
				"type": "swing",
				"actor": event.get("actor", null),
				"position": event.get("position", event.get("center", Vector2.ZERO)),
				"aim": event.get("aim", Vector2.RIGHT),
				"reach_px": event.get("reach_px", 24.0),
				"color": Color(1.0, 0.93, 0.55, 0.95),
				"duration": 0.3,
				"remaining": 0.3
			})
		"hit_landed":
			var target = event.get("target", null)
			var amount: float = float(event.get("amount", 0.0))
			var region_mult: float = clampf(float(event.get("region_mult", 1.0)), 0.75, 1.35)
			if target != null and is_instance_valid(target) and target.has_method("apply_render_hit_feedback"):
				target.apply_render_hit_feedback(amount, region_mult)
			var heavy := bool(event.get("heavy", false))
			var hit_position: Vector2 = event.get("hit_position", Vector2.ZERO)
			var spark_center: Vector2 = hit_position if hit_position != Vector2.ZERO else event.get("position", Vector2.ZERO)
			var spark_color := Color(1.0, 0.9, 0.7, 0.85)
			spark_color.a *= lerpf(0.85, 1.15, inverse_lerp(0.75, 1.35, region_mult))
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": str(int(round(amount))),
				"color": Color(1.0, 0.62, 0.28, 1.0) if heavy else Color(1.0, 0.96, 0.82, 1.0),
				"size": 19 if heavy else 15,
				"duration": 0.7 if heavy else 0.55,
				"remaining": 0.7 if heavy else 0.55
			})
			telegraphs.append({
				"type": "circle",
				"center": spark_center,
				"radius": (16.0 if heavy else 10.0) * region_mult,
				"color": spark_color,
				"width": 3.0,
				"filled": true,
				"duration": 0.16,
				"remaining": 0.16
			})
		"counter_hit":
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "COUNTER",
				"color": Color(1.0, 0.25, 0.18, 1.0),
				"size": 17,
				"duration": 0.55,
				"remaining": 0.55
			})
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 18.0,
				"color": Color(1.0, 0.25, 0.18, 0.8),
				"width": 3.0,
				"filled": false,
				"duration": 0.18,
				"remaining": 0.18
			})
		"heal_tick":
			var heal_amount: float = float(event.get("amount", 0.0))
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "+%d" % int(ceil(heal_amount)),
				"color": Color(0.32, 1.0, 0.48, 1.0),
				"duration": 0.5,
				"remaining": 0.5
			})
		"shield_refreshed":
			var shield_amount: float = float(event.get("amount", 0.0))
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 24.0,
				"color": Color(0.58, 1.0, 0.72, 0.55),
				"width": 2.5,
				"filled": false,
				"duration": 0.45,
				"remaining": 0.45
			})
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "+%d SHIELD" % int(ceil(shield_amount)),
				"color": Color(0.58, 1.0, 0.72, 1.0),
				"size": 13,
				"duration": 0.55,
				"remaining": 0.55
			})
		"shield_absorbed":
			var absorbed: float = float(event.get("amount", 0.0))
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "-%d" % int(ceil(absorbed)),
				"color": Color(0.68, 1.0, 0.8, 0.95),
				"size": 12,
				"duration": 0.42,
				"remaining": 0.42
			})
		"shield_broken":
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 30.0,
				"color": Color(0.82, 1.0, 0.48, 0.7),
				"width": 4.0,
				"filled": false,
				"duration": 0.28,
				"remaining": 0.28
			})
		"dash_started":
			var dash_duration: float = float(event.get("duration", 0.12))
			telegraphs.append({
				"type": "dash_trail",
				"from": event.get("from", Vector2.ZERO),
				"to": event.get("to", Vector2.ZERO),
				"color": Color(0.65, 0.95, 1.0, 0.65),
				"duration": maxf(dash_duration, 0.12),
				"remaining": maxf(dash_duration, 0.12),
				"width": 7.0
			})
		"projectile_tracer":
			telegraphs.append({
				"type": "tracer",
				"from": event.get("from", Vector2.ZERO),
				"to": event.get("to", Vector2.ZERO),
				"color": Color(0.92, 0.88, 0.5, 0.85),
				"duration": float(event.get("duration", 0.18)),
				"remaining": float(event.get("duration", 0.18)),
				"width": 3.0
			})
		"aura_applied":
			var target = event.get("target", null)
			var aura_duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "aura_follow",
				"target": target,
				"ring_radius": _aura_ring_radius(target),
				"color": _aura_color(String(event.get("source_ability", "")), bool(event.get("friendly", true))),
				"duration": aura_duration,
				"remaining": aura_duration,
				"width": 3.0
			})
		"latch_started":
			var duration: float = float(event.get("duration", 0.1))
			telegraphs.append({
				"type": "tether",
				"attacker": event.get("attacker", null),
				"victim": event.get("victim", null),
				"source_ability": event.get("source_ability", ""),
				"duration": duration,
				"remaining": duration,
				"execute_after": event.get("execute_after", 0.0),
				"color": Color(1.0, 0.28, 0.2, 0.9),
				"width": 4.0
			})
		"spiked":
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "SPIKED!",
				"color": Color(1.0, 0.45, 0.2, 1.0),
				"size": 18,
				"duration": 0.8,
				"remaining": 0.8
			})
			telegraphs.append({
				"type": "circle",
				"center": event.get("position", Vector2.ZERO),
				"radius": 22.0,
				"color": Color(1.0, 0.5, 0.2, 0.9),
				"width": 4.0,
				"filled": true,
				"duration": 0.3,
				"remaining": 0.3
			})
		"attack_dodged":
			telegraphs.append({
				"type": "float_text",
				"position": event.get("position", Vector2.ZERO),
				"text": "MISS",
				"color": Color(0.75, 0.8, 0.9, 0.9),
				"size": 13,
				"duration": 0.5,
				"remaining": 0.5
			})
		"latch_ended":
			_remove_tether(event.get("attacker", null), event.get("victim", null))

func _telegraph_lost_anchor(telegraph: Dictionary) -> bool:
	match String(telegraph.get("type", "")):
		"windup":
			var actor = telegraph.get("actor", null)
			return actor == null or not is_instance_valid(actor)
		"aura_follow":
			var target = telegraph.get("target", null)
			return target == null or not is_instance_valid(target)
		"tether":
			var attacker = telegraph.get("attacker", null)
			var victim = telegraph.get("victim", null)
			return attacker == null or victim == null or not is_instance_valid(attacker) or not is_instance_valid(victim)
	return false

func _remove_tether(attacker: Variant, victim: Variant) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var telegraph := telegraphs[i]
		if String(telegraph.get("type", "")) != "tether":
			continue
		if telegraph.get("attacker", null) == attacker and telegraph.get("victim", null) == victim:
			telegraphs.remove_at(i)

func _draw_windup_telegraph(telegraph: Dictionary, color: Color) -> void:
	var actor = telegraph.get("actor", null)
	if actor == null or not is_instance_valid(actor):
		return
	var aim: Vector2 = telegraph.get("aim", Vector2.RIGHT)
	var actor_aim_value: Variant = actor.get("last_aim_direction")
	if typeof(actor_aim_value) == TYPE_VECTOR2 \
		and (actor_aim_value as Vector2).is_finite() \
		and not (actor_aim_value as Vector2).is_zero_approx():
		aim = actor_aim_value
	if not aim.is_finite() or aim.is_zero_approx():
		return
	var duration: float = maxf(float(telegraph.get("duration", 0.01)), 0.01)
	var remaining: float = float(telegraph.get("remaining", 0.0))
	var progress := 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var reach: float = float(telegraph.get("reach_px", 24.0))
	var danger := Color(1.0, 0.42, 0.2, 0.35 + progress * 0.55)
	_draw_cone(actor.global_position, aim.normalized(), reach, PI * 0.52, Color(1.0, 0.75, 0.3, 0.3))
	_draw_cone(actor.global_position, aim.normalized(), reach * progress, PI * 0.52, danger)

func _draw_swing_telegraph(telegraph: Dictionary, color: Color) -> void:
	var actor = telegraph.get("actor", null)
	var origin: Vector2 = actor.global_position if actor != null and is_instance_valid(actor) else telegraph.get("position", Vector2.ZERO)
	var aim: Vector2 = telegraph.get("aim", Vector2.RIGHT)
	if not aim.is_finite() or aim.is_zero_approx():
		return
	var reach: float = float(telegraph.get("reach_px", 24.0))
	_draw_cone(origin, aim.normalized(), reach, PI * 0.7, color)

func _draw_cone(origin: Vector2, aim: Vector2, reach: float, spread: float, color: Color) -> void:
	var points := TelegraphGeometry.cone_polygon_points(origin, aim, reach, spread)
	if points.is_empty():
		return
	var fill := color
	fill.a *= 0.34
	draw_colored_polygon(points, fill)
	var safe_spread := TelegraphGeometry.safe_cone_spread(spread)
	draw_arc(
		origin,
		reach,
		aim.angle() - safe_spread * 0.5,
		aim.angle() + safe_spread * 0.5,
		18,
		color,
		5.0
	)

func _draw_latch_countdown(telegraph: Dictionary, center: Vector2, color: Color) -> void:
	var duration: float = maxf(float(telegraph.get("duration", 0.1)), 0.1)
	var remaining: float = clampf(float(telegraph.get("remaining", 0.0)), 0.0, duration)
	var radius := 7.0
	draw_circle(center, radius + 2.0, Color(0.04, 0.02, 0.02, color.a))
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * (remaining / duration), 20, color, 3.0)

func _draw_squad_badges() -> void:
	if not _is_1v1_trio_mode():
		return
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member) or not member.is_alive():
			continue
		var text := _squad_badge_text(member, i)
		var color := _squad_badge_color(member, i)
		var position: Vector2 = member.global_position + Vector2(-28.0, -member.body_radius - 25.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.02, 0.02, 0.02, 0.85))
		draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, color)

func _draw_animal_zones() -> void:
	for zone: Dictionary in animal_zone_states:
		var center: Vector2 = zone.get("center", Vector2.ZERO)
		var radius: Vector2 = zone.get("radius", Vector2.ZERO)
		if radius.x <= 0.0 or radius.y <= 0.0:
			continue
		var active := bool(zone.get("active", false))
		var boss := bool(zone.get("boss", false))
		var contested := bool(zone.get("contested", false))
		var control_team := int(zone.get("control_team", -1))
		var base_color := _animal_zone_color(zone, active, boss, control_team)
		var fill := Color(base_color.r, base_color.g, base_color.b, 0.035 if active else 0.014)
		var outline := Color(base_color.r, base_color.g, base_color.b, 0.3 if active else 0.12)
		_draw_ellipse(center, radius, fill, outline, 2.0 if active else 1.0)
		_draw_animal_zone_water_source(zone, active)
		if contested:
			var contested_color := VisualGrammar.ecology_zone_color("contested")
			_draw_ellipse(center, radius * 0.92, Color(contested_color.r, contested_color.g, contested_color.b, 0.025), VisualGrammar.ecology_zone_color("contested", 0.46), 3.0)
		elif control_team >= 0:
			var control_key := "blue_control" if control_team == BLUE else "red_control"
			var team_tint := VisualGrammar.ecology_zone_color(control_key, 0.34)
			_draw_ellipse(center, radius * 0.86, Color(team_tint.r, team_tint.g, team_tint.b, 0.018), team_tint, 2.0)
		_draw_animal_zone_occupant_marks(zone, center, radius, base_color)

func _draw_animal_zone_water_source(zone: Dictionary, active: bool) -> void:
	var water_center: Vector2 = zone.get("water_center", zone.get("center", Vector2.ZERO))
	var water_radius: Vector2 = zone.get("water_radius", Vector2.ZERO)
	if water_radius.x <= 0.0 or water_radius.y <= 0.0:
		return
	var alpha := 0.24 if active else 0.09
	var water_fill := VisualGrammar.ecology_zone_color("water_fill")
	_draw_ellipse(water_center, water_radius, Color(water_fill.r, water_fill.g, water_fill.b, alpha * 0.34), VisualGrammar.ecology_zone_color("water_outline", alpha), 1.3 if active else 0.8)
	_draw_ellipse(water_center, water_radius * 0.58, Color(0.0, 0.0, 0.0, 0.0), VisualGrammar.ecology_zone_color("water_outline", alpha * 0.72), 0.9)

func _animal_zone_color(zone: Dictionary, active: bool, boss: bool, control_team: int) -> Color:
	if boss:
		return VisualGrammar.ecology_zone_color("boss_active" if active else "boss_dormant")
	if control_team == BLUE:
		return VisualGrammar.ecology_zone_color("blue_control")
	if control_team == RED:
		return VisualGrammar.ecology_zone_color("red_control")
	return VisualGrammar.ecology_zone_color("blue_side" if String(zone.get("side", "")) == "blue" else "red_side")

func _draw_animal_zone_occupant_marks(zone: Dictionary, center: Vector2, radius: Vector2, color: Color) -> void:
	var occupants: Array = zone.get("alive_occupants", zone.get("occupants", []))
	if occupants.is_empty():
		return
	var active := bool(zone.get("active", false))
	var alpha := 0.42 if active else 0.12
	var count := mini(occupants.size(), 8)
	for i in count:
		var angle := -PI * 0.84 + (PI * 1.68 * float(i) / maxf(float(count - 1), 1.0))
		var point := center + Vector2(cos(angle) * radius.x * 0.72, sin(angle) * radius.y * 0.72)
		draw_circle(point, 4.0 if bool(zone.get("boss", false)) else 3.0, Color(color.r, color.g, color.b, alpha))

func _draw_ellipse(center: Vector2, radius: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 44
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	for i in steps:
		draw_line(points[i], points[(i + 1) % steps], outline, width)

func get_habitat_stock_visuals(team := -1) -> Array[Dictionary]:
	var visuals: Array[Dictionary] = []
	if stock_manager == null or not stock_manager.has_method("get_team_slots"):
		return visuals
	var teams := [BLUE, RED] if team < 0 else [team]
	for draw_team in teams:
		var habitat: Rect2 = terrain_map.get_team_habitat_rect(draw_team)
		if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
			continue
		var slots: Array[Dictionary] = stock_manager.get_team_slots(draw_team)
		for slot: Dictionary in slots:
			var slot_index := int(slot.get("slot_index", 0))
			var stocks := int(slot.get("stocks_remaining", StockManagerScript.MAX_STOCKS))
			var state := String(slot.get("state", StockManagerScript.STATE_FIELD))
			var reserves := maxi(0, stocks - (0 if state == StockManagerScript.STATE_RESPAWNING else 1))
			for reserve_index in mini(reserves, StockManagerScript.MAX_STOCKS - 1):
				visuals.append({
					"team": draw_team,
					"slot_index": slot_index,
					"reserve_index": reserve_index,
					"creature_id": String(slot.get("creature_id", "")),
					"state": state,
					"position": _habitat_reserve_position(habitat, draw_team, slot_index, reserve_index)
				})
	return visuals

func _habitat_reserve_position(habitat: Rect2, team: int, slot_index: int, reserve_index: int) -> Vector2:
	var x_side := -1.0 if team == BLUE else 1.0
	var center := habitat.get_center()
	var row_y := (float(slot_index) - 1.0) * 32.0
	var col_x := x_side * (34.0 + float(reserve_index) * 26.0)
	return center + Vector2(col_x, row_y)

func _draw_habitat_stock_visuals() -> void:
	for visual: Dictionary in get_habitat_stock_visuals():
		var position: Vector2 = visual.get("position", Vector2.ZERO)
		var team := int(visual.get("team", BLUE))
		var slot_index := int(visual.get("slot_index", 0))
		var team_color := _habitat_stock_color(team)
		draw_circle(position + Vector2(1.5, 2.5), 10.0, VisualGrammar.shadow_color(0.72))
		draw_arc(position, 10.5, PI * 0.08, PI * 0.92, 18, VisualGrammar.BOG_REED.darkened(0.08), 2.6)
		draw_arc(position + Vector2(0.0, 1.0), 7.4, PI * 0.12, PI * 0.88, 16, VisualGrammar.BOG_MUD.lightened(0.08), 2.0)
		draw_circle(position + Vector2(0.0, -1.0), 4.5, team_color)
		draw_arc(position + Vector2(0.0, -1.0), 5.8, 0.0, TAU, 16, Color(0.88, 0.92, 0.82, 0.38), 1.2)
		for mark in slot_index + 1:
			var x_offset := (float(mark) - float(slot_index) * 0.5) * 3.2
			draw_line(position + Vector2(x_offset, 7.0), position + Vector2(x_offset, 10.0), team_color.darkened(0.18), 1.2)

func _habitat_stock_color(team: int) -> Color:
	return VisualGrammar.team_color(team, 0.84).lightened(0.08)

func _draw_breeding_cues() -> void:
	for cue: Dictionary in stock_manager.get_breeding_cues():
		var team := int(cue.get("team", BLUE))
		var habitat: Rect2 = terrain_map.get_team_habitat_rect(team)
		if habitat.size.x <= 0.0 or habitat.size.y <= 0.0:
			continue
		var center := _breeding_cue_position(cue)
		var duration := maxf(float(cue.get("duration", StockManagerScript.BREEDING_DURATION_SEC)), 0.01)
		var remaining := clampf(float(cue.get("remaining", 0.0)), 0.0, duration)
		var progress := 1.0 - remaining / duration
		var color := Color(0.9, 0.75, 0.28, 0.85)
		draw_arc(center, 24.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 36, color, 4.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-16.0, -28.0), "%ds" % ceili(remaining), HORIZONTAL_ALIGNMENT_LEFT, 36.0, 10, color)

func _squad_badge_text(member: Node, index: int) -> String:
	if member == player:
		return "%d ACTIVE" % (index + 1)
	if _is_severe_danger(member):
		return "%d DANGER" % (index + 1)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return "%d FOLLOW %.0f" % [index + 1, ceili(squad_command_timer)]
		SQUAD_COMMAND_AGGRO:
			return "%d AGGRO" % (index + 1)
		_:
			return "%d FARM" % (index + 1)

func _squad_badge_color(member: Node, _index: int) -> Color:
	if member == player:
		return Color(1.0, 1.0, 1.0, 0.95)
	if _is_severe_danger(member):
		return Color(1.0, 0.34, 0.24, 0.95)
	match squad_command:
		SQUAD_COMMAND_FOLLOW:
			return Color(0.45, 0.75, 1.0, 0.95)
		SQUAD_COMMAND_AGGRO:
			return Color(1.0, 0.54, 0.26, 0.95)
		_:
			return Color(0.58, 1.0, 0.48, 0.95)

func _draw_float_text(telegraph: Dictionary, color: Color, fade: float) -> void:
	var duration: float = maxf(float(telegraph.get("duration", 0.5)), 0.01)
	var remaining: float = float(telegraph.get("remaining", 0.0))
	var progress := 1.0 - clampf(remaining / duration, 0.0, 1.0)
	var position: Vector2 = telegraph.get("position", Vector2.ZERO) + Vector2(-8.0, -18.0 - progress * 24.0)
	var size: int = int(telegraph.get("size", 15))
	color.a *= fade
	draw_string(ThemeDB.fallback_font, position + Vector2(1.5, 1.5), String(telegraph.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(0.02, 0.02, 0.02, color.a))
	draw_string(ThemeDB.fallback_font, position, String(telegraph.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _aura_ring_radius(target: Variant) -> float:
	if target != null and is_instance_valid(target) and target.get("body_radius") != null:
		return float(target.body_radius) + 9.0
	return 22.0

func _aura_color(source_ability: String, friendly: bool) -> Color:
	if source_ability == "Scent Marking":
		return VisualGrammar.telegraph_color("windup", 0.82)
	if friendly:
		return VisualGrammar.telegraph_color("aura", 0.82, true)
	return VisualGrammar.telegraph_color("aura", 0.82, false)

func _on_core_destroyed(core) -> void:
	if _is_competitive_mode() and not bool(match_rules.get("core_targetable", true)):
		return
	var winner := "Red" if core.team == BLUE else "Blue"
	_finish_match(winner, "core_destroyed", "%s wins! Press Enter to restart or Esc for menu." % winner)

func _finish_match(winner: String, reason: String, status_text: String) -> void:
	if match_over:
		return
	match_over = true
	match_result = get_match_summary_data(winner, reason)
	match_result["status_text"] = status_text
	if match_result_panel != null and match_result_panel.has_method("get_display_state"):
		match_result_panel.get_display_state()
	_freeze_match_world()
	_set_label_text_if_changed(status_label, status_text)
	_set_label_text_if_changed(end_summary_label, _get_match_summary(winner))
	_write_match_summary_log(winner, reason, match_result)

func get_match_result_state() -> Dictionary:
	return match_result.duplicate(true)

func _freeze_match_world() -> void:
	var neutralized: Dictionary = {}
	for entity: Node in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		var entity_id := entity.get_instance_id()
		if neutralized.has(entity_id):
			continue
		neutralized[entity_id] = true
		if entity.has_method("set_input_frame"):
			entity.set_input_frame(InputFrameScript.new())
	switch_action_neutral_ticks.clear()
	switch_release_mask = 0
	for child: Node in get_children():
		child.set_process(false)
		child.set_physics_process(false)
	set_physics_process(false)
	call_deferred("_disable_match_world_children")

func _disable_match_world_children() -> void:
	if not match_over:
		return
	for child: Node in get_children():
		if child != null and is_instance_valid(child):
			child.process_mode = Node.PROCESS_MODE_DISABLED

func _update_ui() -> void:
	var blue_core = cores[BLUE]
	var red_core = cores[RED]
	var creature_name: String = player.creature_data.get("name", "Unknown") if player != null else "Unknown"
	if not match_over:
		_set_label_text_if_changed(status_label, get_status_hud_text(creature_name))
	if _is_competitive_mode():
		var blue_stock := _team_stock_total(BLUE)
		var red_stock := _team_stock_total(RED)
		_set_label_text_if_changed(
			core_label,
			"Blue Stocks %d / %d    Red Stocks %d / %d"
			% [blue_stock.x, blue_stock.y, red_stock.x, red_stock.y]
		)
	else:
		_set_label_text_if_changed(core_label, "Blue Core %d / %d    Red Core %d / %d" % [blue_core.health, blue_core.max_health, red_core.health, red_core.max_health])
	_set_label_text_if_changed(cooldown_label, _get_cooldown_text())
	_set_label_text_if_changed(scoreboard_label, _get_scoreboard_text())
	_set_label_text_if_changed(kill_feed_label, _get_kill_feed_text())

func _team_stock_total(team: int) -> Vector2i:
	var remaining := 0
	var maximum := 0
	for slot: Dictionary in stock_manager.get_team_slots(team):
		remaining += int(slot.get("stocks_remaining", 0))
		maximum += int(slot.get("max_stocks", 0))
	return Vector2i(remaining, maximum)

func _set_label_text_if_changed(label: Label, next_text: String) -> void:
	if label != null and label.text != next_text:
		label.text = next_text

func get_status_hud_text(creature_name := "") -> String:
	var mode_text: String = "Play vs AI" if _is_1v1_trio_mode() else GameConfig.selected_mode
	var display_name: String = creature_name
	if display_name.is_empty():
		display_name = String(player.creature_data.get("name", "Unknown")) if player != null else "Unknown"
	var active_text: String = "S%d %s" % [active_squad_index + 1, display_name] if _is_1v1_trio_mode() else display_name
	var hunger_text: String = "Hunger %d%%" % int(round(float(player.get("hunger")))) if player != null and player.get("hunger") != null else "Hunger --"
	return "%s  %s  %s\n%s  %s  Bots %d  Wave %ds" % [
		mode_text,
		_format_match_time(elapsed),
		get_day_hud_label(),
		active_text,
		hunger_text,
		bots.size(),
		ceili(wave_timer)
	]

func get_day_hud_label() -> String:
	var phase := get_day_phase()
	var phase_label := phase.capitalize()
	var vision_pct := int(round(get_vision_range_for_phase(phase) / VISION_RANGE_DAY * 100.0))
	return "Day %d %s V%d%%" % [day_index, phase_label, vision_pct]

func _get_cooldown_text() -> String:
	if player == null:
		return ""
	if player.has_method("is_alive") and not player.is_alive():
		return "RESPAWNING IN %.1fs" % maxf(player.respawn_timer, 0.0)
	var active_line := "Primary %s | Q %s | E %s | Swim %d%% | Flight %d%% | Height %s | %s" % [
		_format_cooldown(player.primary_timer),
		_format_cooldown(player.q_timer),
		_format_cooldown(player.e_timer),
		int(player.get_swim_ratio() * 100.0),
		int(player.get_flight_ratio() * 100.0),
		_format_player_height_read(player),
		"LATCH" if player.has_latch() else "free"
	]
	return active_line

func _format_player_height_read(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor) or not actor.has_method("get_render_motion_state"):
		return "--"
	var state: Dictionary = actor.get_render_motion_state()
	var band := String(state.get("height_band", "--")).capitalize()
	if band.is_empty():
		band = "--"
	if bool(state.get("air_attack_readable", false)) or bool(state.get("low_window_active", false)):
		return "%s LOW" % band
	return band

func _get_squad_rail_text() -> String:
	var command_text := "FARM/SAFE"
	if squad_command == SQUAD_COMMAND_FOLLOW:
		command_text = "FOLLOW %.0fs" % ceili(squad_command_timer)
	elif squad_command == SQUAD_COMMAND_AGGRO:
		command_text = "AGGRO %.0fs" % ceili(squad_command_timer)
	var chunks: Array[String] = ["Squad %s" % command_text]
	for i in player_squad.size():
		var member: Node = player_squad[i]
		if member == null or not is_instance_valid(member):
			continue
		var marker := "*" if member == player else " "
		var hp_ratio := _health_ratio(member)
		var state := "KO %.1fs" % member.respawn_timer if member.has_method("is_alive") and not member.is_alive() else "%d%%" % int(hp_ratio * 100.0)
		var stocks_text := "stocks 3/3"
		if stock_manager.has_actor(member):
			var slot: Dictionary = stock_manager.get_slot_for_actor(member)
			stocks_text = "stocks %d/%d" % [int(slot.get("stocks_remaining", 3)), int(slot.get("max_stocks", 3))]
			if String(slot.get("state", "")) == StockManagerScript.STATE_EXHAUSTED:
				state = "OUT"
		chunks.append("%s%d %s %s %s" % [marker, i + 1, member.creature_data.get("name", member.creature_id), stocks_text, state])
	return " | ".join(chunks)

func _format_cooldown(timer: float) -> String:
	if timer <= 0.05:
		return "READY"
	return "%.1fs" % timer

func _get_kill_feed_text() -> String:
	if kill_feed.is_empty():
		return ""

	var lines := ["Feed"]
	for entry in kill_feed:
		lines.append(entry["message"])
	return "\n".join(lines)

func _ensure_actor_stats(actor: Node) -> void:
	var key := _get_actor_key(actor)
	var slot: Dictionary = slot_registry.get_slot_for_actor(actor)
	if actor_stats.has(key):
		if not slot.is_empty():
			actor_stats[key]["slot_id"] = String(slot.get("slot_id", ""))
			actor_stats[key]["slot_index"] = int(slot.get("slot_index", -1))
			actor_stats[key]["creature_id"] = String(slot.get("creature_id", actor_stats[key].get("creature_id", "")))
		return

	actor_stats[key] = {
		"name": actor.get_actor_name() if actor.has_method("get_actor_name") else "Actor",
		"team": actor.team,
		"slot_id": String(slot.get("slot_id", "")),
		"slot_index": int(slot.get("slot_index", -1)),
		"creature_id": String(slot.get("creature_id", actor.get("creature_id") if actor.get("creature_id") != null else "")),
		"kills": 0,
		"deaths": 0,
		"core_damage": 0.0,
		"hut_damage": 0.0,
		"stock_losses": 0,
		"deposits": 0,
		"breeds_completed": 0,
		"breeds_denied": 0,
		"wildlife_defeats": 0,
		"boss_claims": 0,
		"boss_steals": 0,
		"center_claims": 0
	}

func _get_actor_key(actor: Node) -> String:
	return str(actor.get_instance_id())

func _reset_match_telemetry() -> void:
	actor_stats.clear()
	match_summary_log_path = ""
	match_result.clear()
	economy_events.clear()
	economy_event_sequence = 0
	economy_event_counts.clear()
	economy_first_event_sec.clear()
	economy_team_event_counts = {"blue": {}, "red": {}}
	economy_team_first_event_sec = {"blue": {}, "red": {}}
	balance_slot_telemetry.clear()
	boss_lifecycle_events.clear()
	boss_lifecycle_event_sequence = 0
	_reset_team_vision()
	team_stats = {
		BLUE: _new_team_stats(),
		RED: _new_team_stats()
	}

func _new_team_stats() -> Dictionary:
	return {
		"kills": 0,
		"deaths": 0,
		"core_damage": 0.0,
		"hut_damage": 0.0,
		"huts_destroyed": 0,
		"stock_losses": 0,
		"deposits": 0,
		"breeds_completed": 0,
		"breeds_denied": 0,
		"wildlife_defeats": 0
	}

func _record_team_actor_stat(team: int, stat: String, amount: Variant, actor: Node = null) -> void:
	if team != BLUE and team != RED:
		return
	if not team_stats[team].has(stat):
		team_stats[team][stat] = 0
	team_stats[team][stat] += amount
	if actor != null and is_instance_valid(actor) and actor.has_method("is_scored_actor") and actor.is_scored_actor():
		_ensure_actor_stats(actor)
		var key := _get_actor_key(actor)
		if not actor_stats[key].has(stat):
			actor_stats[key][stat] = 0
		actor_stats[key][stat] += amount

func _get_scoreboard_text() -> String:
	var blue: Dictionary = team_stats[BLUE]
	var red: Dictionary = team_stats[RED]
	var lines := [
		"Score  Blue %dK/%dD/%dDmg    Red %dK/%dD/%dDmg" % [
			blue["kills"], blue["deaths"], int(blue["core_damage"]),
			red["kills"], red["deaths"], int(red["core_damage"]),
		],
		"Flow   Blue %s    Red %s" % [_format_live_team_telemetry(BLUE), _format_live_team_telemetry(RED)],
		"Review %s" % _match_balance_review_summary(),
		"Breed  Blue %s    Red %s" % [_format_breeding_buff_line(BLUE), _format_breeding_buff_line(RED)],
		"Players"
	]

	for key in actor_stats.keys():
		var stats: Dictionary = actor_stats[key]
		var team_name := "Blue" if int(stats["team"]) == BLUE else "Red"
		lines.append("%s %-11s  %d/%d  %dHut %dCore Dep%d" % [
			team_name,
			stats["name"],
			stats["kills"],
			stats["deaths"],
			int(stats.get("hut_damage", 0.0)),
			int(stats.get("core_damage", 0.0)),
			int(stats.get("deposits", 0))
		])

	return "\n".join(lines)

func _format_live_team_telemetry(team: int) -> String:
	var stats: Dictionary = team_stats[team]
	var stocks := _team_stock_totals(team)
	return "Stocks %d/%d Lost%d Dep%d Hut%d Wild%d" % [
		int(stocks.get("remaining", 0)),
		int(stocks.get("max", 0)),
		int(stats.get("stock_losses", 0)),
		int(stats.get("deposits", 0)),
		int(stats.get("hut_damage", 0.0)),
		int(stats.get("wildlife_defeats", 0))
	]

func _format_breeding_buff_line(team: int) -> String:
	var chunks: Array[String] = []
	var family_counts := _team_breeding_stack_map(team)
	for family in BREEDING_BUFF_FAMILIES:
		var count := int(family_counts.get(family, 0))
		if count <= 0:
			continue
		chunks.append("%s%d" % [String(BREEDING_BUFF_LABEL_BY_FAMILY.get(family, family.to_upper())).substr(0, 1), count])
	if chunks.is_empty():
		return "none"
	return " ".join(chunks)

func _get_match_summary(winner: String) -> String:
	var lines := [
		"Match Summary: %s victory at %s" % [winner, _format_match_time(elapsed)],
		_format_team_match_summary_line(BLUE),
		_format_team_match_summary_line(RED)
	]
	lines.append(_format_match_context_line())
	lines.append(_format_balance_flags_line())
	lines.append(_format_balance_focus_line())
	var blue_top := _format_top_player_summary_line(BLUE)
	if not blue_top.is_empty():
		lines.append(blue_top)
	var red_top := _format_top_player_summary_line(RED)
	if not red_top.is_empty():
		lines.append(red_top)
	return "\n".join(lines)

func get_match_summary_data(winner := "", reason := "") -> Dictionary:
	var competitive := _is_competitive_mode()
	return {
		"schema": MATCH_SUMMARY_SCHEMA,
		"winner": winner,
		"reason": reason,
		"time": _format_match_time(elapsed),
		"elapsed_sec": elapsed,
		"mode": legacy_mode_snapshot,
		"ruleset_id": String(match_rules.get("id", "")) if competitive else "",
		"rules_schema_version": int(match_rules.get("schema_version", 0)) if competitive else 0,
		"rules_fingerprint": _rules_fingerprint() if competitive else "",
		"control_topology_id": String(control_topology.get("id", "")),
		"simulation_seed": match_seed,
		"mode_tuning": _match_mode_tuning_data(),
		"selected_creature_id": GameConfig.selected_creature_id,
		"selected_squad_ids": GameConfig.get_selected_squad_ids() if GameConfig.has_method("get_selected_squad_ids") else [GameConfig.selected_creature_id],
		"selected_red_squad_ids": GameConfig.get_selected_red_squad_ids() if GameConfig.has_method("get_selected_red_squad_ids") else [],
		"resolved_rosters": {
			"blue": _resolved_team_roster(BLUE),
			"red": _resolved_team_roster(RED)
		},
		"draft": GameConfig.get_draft_stub_state() if GameConfig.has_method("get_draft_stub_state") else {},
		"teams": {
			"blue": _team_match_summary_data(BLUE),
			"red": _team_match_summary_data(RED)
		},
		"balance_deltas": _match_balance_deltas(),
		"balance_flags": _match_balance_flags(),
		"balance_review_priority": _match_balance_review_priority(),
		"balance_review_focus": _match_balance_review_focus(),
		"balance_review_summary": _match_balance_review_summary(),
		"top_players": _top_match_summary_rows(),
		"players": _player_match_summary_rows(),
		"economy_events": get_economy_event_state(),
		"economy_summary": get_economy_summary_state(),
		"balance_telemetry": get_balance_telemetry_state()
	}

func get_last_match_summary_log_path() -> String:
	return match_summary_log_path

func _write_match_summary_log(winner: String, reason: String, frozen_result: Dictionary = {}) -> void:
	var dir_path := ProjectSettings.globalize_path(MATCH_LOG_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_error != OK:
		push_warning("Could not create match log directory: %s error=%d" % [MATCH_LOG_DIR, dir_error])
		return
	var data := frozen_result.duplicate(true) if not frozen_result.is_empty() else get_match_summary_data(winner, reason)
	var filename := "match_%d_%s_p%d_%s.json" % [
		Time.get_unix_time_from_system(),
		legacy_mode_snapshot.replace(" ", "_").to_lower(),
		int(data.get("balance_review_priority", 0)),
		reason
	]
	var path := "%s/%s" % [MATCH_LOG_DIR, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write match summary log: %s error=%d" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()
	match_summary_log_path = path

func _format_team_match_summary_line(team: int) -> String:
	var data := _team_match_summary_data(team)
	return "%s: %dK/%dD | Stocks lost %d/%d | Deposits %d | Breeds %d/%d denied | HutDmg %d | CoreDmg %d | Wildlife %d | Buffs %s" % [
		String(data.get("name", "")),
		int(data.get("kills", 0)),
		int(data.get("deaths", 0)),
		int(data.get("stock_losses", 0)),
		int(data.get("max_stocks", 0)),
		int(data.get("deposits", 0)),
		int(data.get("breeds_completed", 0)),
		int(data.get("breeds_denied", 0)),
		int(data.get("hut_damage", 0)),
		int(data.get("core_damage", 0)),
		int(data.get("wildlife_defeats", 0)),
		String(data.get("buffs", "none"))
	]

func _format_match_context_line() -> String:
	var squad_labels: Array[String] = []
	var squad_ids: Array = GameConfig.get_selected_squad_ids() if GameConfig.has_method("get_selected_squad_ids") else [GameConfig.selected_creature_id]
	for creature_id in squad_ids:
		squad_labels.append(_creature_label(String(creature_id)))
	var squad_text := " / ".join(squad_labels) if not squad_labels.is_empty() else _creature_label(GameConfig.selected_creature_id)
	var draft_state: Dictionary = GameConfig.get_draft_stub_state() if GameConfig.has_method("get_draft_stub_state") else {}
	var draft_text := "Draft: off"
	if bool(draft_state.get("enabled", false)):
		draft_text = "Draft: pick %d, ban %d/team" % [
			int(draft_state.get("pick_slots_per_team", 0)),
			int(draft_state.get("ban_slots_per_team", 0))
		]
		var ban_text := _format_draft_bans(draft_state)
		if not ban_text.is_empty():
			draft_text += " (%s)" % ban_text
	return "Mode: %s | Squad: %s | %s | %s" % [legacy_mode_snapshot, squad_text, draft_text, _format_mode_tuning_line()]

func _rules_fingerprint() -> String:
	if match_rules.is_empty():
		return ""
	return str(JSON.stringify(match_rules).hash())

func _format_mode_tuning_line() -> String:
	var tuning := _match_mode_tuning_data()
	var huts: Dictionary = tuning.get("huts_per_side", {})
	var hut_text := "%d/%d huts" % [int(huts.get("blue", 0)), int(huts.get("red", 0))]
	return "Pace: hunger %ds, wave %ds, %s, %d minions/hut" % [
		int(tuning.get("hunger_full_to_empty_sec", 0)),
		int(tuning.get("wave_interval_sec", 0)),
		hut_text,
		int(tuning.get("lane_minions_per_hut", 0))
	]

func _match_mode_tuning_data() -> Dictionary:
	return {
		"hunger_full_to_empty_sec": hunger_full_to_empty_sec,
		"wave_interval_sec": wave_interval,
		"lane_minions_per_hut": wave_minion_offsets.size(),
		"huts_per_side": {
			"blue": _configured_hut_count_for_team(BLUE),
			"red": _configured_hut_count_for_team(RED)
		}
	}

func _configured_hut_count_for_team(team: int) -> int:
	if terrain_map != null and terrain_map.get("hut_positions") != null:
		var positions: Dictionary = terrain_map.get("hut_positions")
		return (positions.get(team, []) as Array).size()
	return 0

func _format_draft_bans(draft_state: Dictionary) -> String:
	var chunks: Array[String] = []
	var blue_bans: Array = draft_state.get("blue_bans", [])
	var red_bans: Array = draft_state.get("red_bans", [])
	if not blue_bans.is_empty():
		chunks.append("Blue bans %s" % _creature_label(String(blue_bans[0])))
	if not red_bans.is_empty():
		chunks.append("Red bans %s" % _creature_label(String(red_bans[0])))
	return ", ".join(chunks)

func _creature_label(creature_id: String) -> String:
	var catalog := get_node_or_null("/root/CreatureCatalog")
	if catalog != null and catalog.has_method("get_creature"):
		var creature_data: Dictionary = catalog.get_creature(creature_id)
		if not creature_data.is_empty():
			return String(creature_data.get("name", creature_id))
	return creature_id.replace("_", " ").capitalize()

func _format_balance_flags_line() -> String:
	var labels: Array[String] = []
	for flag in _match_balance_flags():
		labels.append(_balance_flag_label(flag))
	return "Review flags: %s | Priority %d/5" % [", ".join(labels), _match_balance_review_priority()]

func _format_balance_focus_line() -> String:
	var labels: Array[String] = []
	for entry: Dictionary in _match_balance_review_focus():
		labels.append(String(entry.get("label", "")))
	return "Review focus: %s" % ", ".join(labels)

func _match_balance_review_summary() -> String:
	var labels: Array[String] = []
	for entry: Dictionary in _match_balance_review_focus():
		labels.append(String(entry.get("label", "")))
	return "P%d: %s" % [_match_balance_review_priority(), ", ".join(labels)]

func _balance_flag_label(flag: String) -> String:
	match flag:
		"blue_stock_advantage":
			return "Blue stock advantage"
		"red_stock_advantage":
			return "Red stock advantage"
		"blue_objective_pressure":
			return "Blue objective pressure"
		"red_objective_pressure":
			return "Red objective pressure"
		"blue_breeding_tempo":
			return "Blue breeding tempo"
		"red_breeding_tempo":
			return "Red breeding tempo"
		"blue_raid_pressure":
			return "Blue raid pressure"
		"red_raid_pressure":
			return "Red raid pressure"
		"blue_buff_lead":
			return "Blue buff lead"
		"red_buff_lead":
			return "Red buff lead"
		_:
			return "Balanced flow"

func _team_match_summary_data(team: int) -> Dictionary:
	var stats: Dictionary = team_stats[team]
	var stocks := _team_stock_totals(team)
	return {
		"name": _team_name(team),
		"kills": int(stats.get("kills", 0)),
		"deaths": int(stats.get("deaths", 0)),
		"core_damage": float(stats.get("core_damage", 0.0)),
		"hut_damage": float(stats.get("hut_damage", 0.0)),
		"huts_destroyed": int(stats.get("huts_destroyed", 0)),
		"stock_losses": int(stats.get("stock_losses", 0)),
		"stocks_remaining": int(stocks.get("remaining", 0)),
		"max_stocks": int(stocks.get("max", 0)),
		"deposits": int(stats.get("deposits", 0)),
		"breeds_completed": int(stats.get("breeds_completed", 0)),
		"breeds_denied": int(stats.get("breeds_denied", 0)),
		"wildlife_defeats": int(stats.get("wildlife_defeats", 0)),
		"boss_claims": int(stats.get("boss_claims", 0)),
		"boss_steals": int(stats.get("boss_steals", 0)),
		"center_claims": int(stats.get("center_claims", 0)),
		"buffs": _format_breeding_buff_line(team),
		"buff_summary": get_team_breeding_buff_summary(team)
	}

func _resolved_team_roster(team: int) -> Array[String]:
	var roster: Array[String] = []
	if not slot_registry.is_sealed():
		return roster
	for slot: Dictionary in slot_registry.get_team_slots(team):
		roster.append(String(slot.get("creature_id", "")))
	return roster

func _match_balance_deltas() -> Dictionary:
	var blue := _team_match_summary_data(BLUE)
	var red := _team_match_summary_data(RED)
	var blue_buffs: Dictionary = blue.get("buff_summary", {})
	var red_buffs: Dictionary = red.get("buff_summary", {})
	return {
		"stock_remaining_delta": int(blue.get("stocks_remaining", 0)) - int(red.get("stocks_remaining", 0)),
		"stock_loss_delta": int(blue.get("stock_losses", 0)) - int(red.get("stock_losses", 0)),
		"deposit_delta": int(blue.get("deposits", 0)) - int(red.get("deposits", 0)),
		"breed_complete_delta": int(blue.get("breeds_completed", 0)) - int(red.get("breeds_completed", 0)),
		"breed_deny_delta": int(blue.get("breeds_denied", 0)) - int(red.get("breeds_denied", 0)),
		"hut_damage_delta": float(blue.get("hut_damage", 0.0)) - float(red.get("hut_damage", 0.0)),
		"core_damage_delta": float(blue.get("core_damage", 0.0)) - float(red.get("core_damage", 0.0)),
		"wildlife_delta": int(blue.get("wildlife_defeats", 0)) - int(red.get("wildlife_defeats", 0)),
		"buff_stack_delta": int(blue_buffs.get("total_stacks", 0)) - int(red_buffs.get("total_stacks", 0))
	}

func _match_balance_flags() -> Array[String]:
	var deltas := _match_balance_deltas()
	var flags: Array[String] = []
	var stock_delta := int(deltas.get("stock_remaining_delta", 0))
	var deposit_delta := int(deltas.get("deposit_delta", 0))
	var breed_complete_delta := int(deltas.get("breed_complete_delta", 0))
	var breed_deny_delta := int(deltas.get("breed_deny_delta", 0))
	var hut_damage_delta := float(deltas.get("hut_damage_delta", 0.0))
	var core_damage_delta := float(deltas.get("core_damage_delta", 0.0))
	var buff_stack_delta := int(deltas.get("buff_stack_delta", 0))

	if stock_delta >= 2:
		flags.append("blue_stock_advantage")
	elif stock_delta <= -2:
		flags.append("red_stock_advantage")
	if hut_damage_delta >= 250.0 or core_damage_delta >= 250.0:
		flags.append("blue_objective_pressure")
	elif hut_damage_delta <= -250.0 or core_damage_delta <= -250.0:
		flags.append("red_objective_pressure")
	if deposit_delta >= 2 or breed_complete_delta >= 2:
		flags.append("blue_breeding_tempo")
	elif deposit_delta <= -2 or breed_complete_delta <= -2:
		flags.append("red_breeding_tempo")
	if breed_deny_delta >= 1:
		flags.append("blue_raid_pressure")
	elif breed_deny_delta <= -1:
		flags.append("red_raid_pressure")
	if buff_stack_delta >= 2:
		flags.append("blue_buff_lead")
	elif buff_stack_delta <= -2:
		flags.append("red_buff_lead")
	if flags.is_empty():
		flags.append("balanced_flow")
	return flags

func _match_balance_review_priority() -> int:
	var deltas := _match_balance_deltas()
	var score := 0
	var stock_delta := absi(int(deltas.get("stock_remaining_delta", 0)))
	var deposit_delta := absi(int(deltas.get("deposit_delta", 0)))
	var breed_complete_delta := absi(int(deltas.get("breed_complete_delta", 0)))
	var breed_deny_delta := absi(int(deltas.get("breed_deny_delta", 0)))
	var hut_damage_delta := absf(float(deltas.get("hut_damage_delta", 0.0)))
	var core_damage_delta := absf(float(deltas.get("core_damage_delta", 0.0)))
	var buff_stack_delta := absi(int(deltas.get("buff_stack_delta", 0)))

	if stock_delta >= 4:
		score += 3
	elif stock_delta >= 2:
		score += 2
	if hut_damage_delta >= 600.0 or core_damage_delta >= 600.0:
		score += 3
	elif hut_damage_delta >= 250.0 or core_damage_delta >= 250.0:
		score += 2
	if deposit_delta >= 4 or breed_complete_delta >= 4:
		score += 2
	elif deposit_delta >= 2 or breed_complete_delta >= 2:
		score += 1
	if breed_deny_delta >= 1:
		score += 1
	if buff_stack_delta >= 2:
		score += 1
	return mini(score, 5)

func _match_balance_review_focus() -> Array[Dictionary]:
	var deltas := _match_balance_deltas()
	var focus: Array[Dictionary] = []
	_append_delta_focus(focus, "hut_damage_delta", float(deltas.get("hut_damage_delta", 0.0)), 250.0, "hut damage", true)
	_append_delta_focus(focus, "core_damage_delta", float(deltas.get("core_damage_delta", 0.0)), 250.0, "core damage", true)
	_append_delta_focus(focus, "stock_remaining_delta", float(deltas.get("stock_remaining_delta", 0)), 2.0, "stocks remaining")
	_append_delta_focus(focus, "deposit_delta", float(deltas.get("deposit_delta", 0)), 2.0, "deposits")
	_append_delta_focus(focus, "breed_complete_delta", float(deltas.get("breed_complete_delta", 0)), 2.0, "breeds completed")
	_append_delta_focus(focus, "breed_deny_delta", float(deltas.get("breed_deny_delta", 0)), 1.0, "denials")
	_append_delta_focus(focus, "buff_stack_delta", float(deltas.get("buff_stack_delta", 0)), 2.0, "buff stacks")
	if focus.is_empty():
		focus.append({
			"key": "balanced_flow",
			"side": "Even",
			"value": 0,
			"label": "Balanced flow"
		})
	return focus

func _append_delta_focus(focus: Array[Dictionary], key: String, delta: float, threshold: float, label: String, whole_value := false) -> void:
	if absf(delta) < threshold:
		return
	var side := "Blue" if delta > 0.0 else "Red"
	var value := absf(delta)
	var display_value := int(round(value)) if whole_value else int(value)
	focus.append({
		"key": key,
		"side": side,
		"value": display_value,
		"label": "%s %s +%d" % [side, label, display_value]
	})

func _team_stock_totals(team: int) -> Dictionary:
	var totals := {"remaining": 0, "max": 0}
	if stock_manager == null or not stock_manager.has_method("get_team_slots"):
		return totals
	for slot: Dictionary in stock_manager.get_team_slots(team):
		totals["remaining"] = int(totals["remaining"]) + int(slot.get("stocks_remaining", 0))
		totals["max"] = int(totals["max"]) + int(slot.get("max_stocks", 0))
	return totals

func _player_match_summary_rows() -> Array[Dictionary]:
	_ensure_registered_actor_stats()
	var rows: Array[Dictionary] = []
	for key in actor_stats.keys():
		var stats: Dictionary = actor_stats[key]
		rows.append(_player_match_summary_entry(stats))
	_rank_player_summary_rows(rows)
	rows.sort_custom(Callable(self, "_sort_player_summary_rows"))
	return rows

func _ensure_registered_actor_stats() -> void:
	if not slot_registry.is_sealed():
		return
	for team_value in [BLUE, RED]:
		for slot: Dictionary in slot_registry.get_team_slots(int(team_value)):
			var actor: Node = slot.get("actor", null)
			if actor != null and is_instance_valid(actor):
				_ensure_actor_stats(actor)

func _player_match_summary_entry(stats: Dictionary) -> Dictionary:
	var entry := stats.duplicate(true)
	entry["summary_score"] = snappedf(_player_summary_score(entry), 0.1)
	entry["summary_score_breakdown"] = _player_summary_score_breakdown(entry)
	return entry

func _rank_player_summary_rows(rows: Array[Dictionary]) -> void:
	var ranked := rows.duplicate()
	ranked.sort_custom(Callable(self, "_sort_player_summary_rank_rows"))
	var team_ranks := {}
	var match_rank := 1
	for row: Dictionary in ranked:
		var team := int(row.get("team", -1))
		var team_rank := int(team_ranks.get(team, 0)) + 1
		team_ranks[team] = team_rank
		row["summary_rank"] = match_rank
		row["team_summary_rank"] = team_rank
		match_rank += 1

func _sort_player_summary_rank_rows(a: Dictionary, b: Dictionary) -> bool:
	var score_a := float(a.get("summary_score", 0.0))
	var score_b := float(b.get("summary_score", 0.0))
	if absf(score_a - score_b) > 0.001:
		return score_a > score_b
	var team_a := int(a.get("team", 0))
	var team_b := int(b.get("team", 0))
	if team_a != team_b:
		return team_a < team_b
	return String(a.get("name", "")) < String(b.get("name", ""))

func _sort_player_summary_rows(a: Dictionary, b: Dictionary) -> bool:
	var team_a := int(a.get("team", 0))
	var team_b := int(b.get("team", 0))
	if team_a != team_b:
		return team_a < team_b
	return String(a.get("name", "")) < String(b.get("name", ""))

func _format_top_player_summary_line(team: int) -> String:
	var top := _top_player_summary_row(team)
	if top.is_empty():
		return ""
	return "Top %s: %s %dK/%dD | StockLost %d | Dep %d | Breed %d/%d deny | HutDmg %d | CoreDmg %d" % [
		_team_name(team),
		String(top.get("name", "Actor")),
		int(top.get("kills", 0)),
		int(top.get("deaths", 0)),
		int(top.get("stock_losses", 0)),
		int(top.get("deposits", 0)),
		int(top.get("breeds_completed", 0)),
		int(top.get("breeds_denied", 0)),
		int(top.get("hut_damage", 0)),
		int(top.get("core_damage", 0))
	]

func _top_player_summary_row(team: int) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for row: Dictionary in _player_match_summary_rows():
		if int(row.get("team", -1)) != team:
			continue
		var score := _player_summary_score(row)
		if score > best_score:
			best_score = score
			best = row
	return best

func _top_match_summary_rows() -> Dictionary:
	return {
		"blue": _top_player_summary_entry(BLUE),
		"red": _top_player_summary_entry(RED)
	}

func _top_player_summary_entry(team: int) -> Dictionary:
	var top := _top_player_summary_row(team)
	if top.is_empty():
		return {}
	var entry := top.duplicate(true)
	entry["summary_score"] = snappedf(_player_summary_score(top), 0.1)
	entry["summary_score_breakdown"] = _player_summary_score_breakdown(top)
	return entry

func _player_summary_score_breakdown(row: Dictionary) -> Array[Dictionary]:
	var breakdown: Array[Dictionary] = []
	_append_summary_score_component(breakdown, "kills", "Kills", float(row.get("kills", 0)), 120.0)
	_append_summary_score_component(breakdown, "breeds_completed", "Breeds completed", float(row.get("breeds_completed", 0)), 90.0)
	_append_summary_score_component(breakdown, "breeds_denied", "Breeds denied", float(row.get("breeds_denied", 0)), 80.0)
	_append_summary_score_component(breakdown, "deposits", "Deposits", float(row.get("deposits", 0)), 50.0)
	_append_summary_score_component(breakdown, "wildlife_defeats", "Wildlife defeats", float(row.get("wildlife_defeats", 0)), 30.0)
	_append_summary_score_component(breakdown, "stock_losses", "Stock losses", float(row.get("stock_losses", 0)), 20.0)
	_append_summary_score_component(breakdown, "hut_damage", "Hut damage", float(row.get("hut_damage", 0.0)), 0.1)
	_append_summary_score_component(breakdown, "core_damage", "Core damage", float(row.get("core_damage", 0.0)), 0.1)
	_append_summary_score_component(breakdown, "deaths", "Deaths", float(row.get("deaths", 0)), -5.0)
	return breakdown

func _append_summary_score_component(breakdown: Array[Dictionary], key: String, label: String, value: float, weight: float) -> void:
	if absf(value) < 0.001:
		return
	breakdown.append({
		"key": key,
		"label": label,
		"value": snappedf(value, 0.1),
		"weight": weight,
		"score": snappedf(value * weight, 0.1)
	})

func _player_summary_score(row: Dictionary) -> float:
	return float(row.get("kills", 0)) * 120.0 \
		+ float(row.get("breeds_completed", 0)) * 90.0 \
		+ float(row.get("breeds_denied", 0)) * 80.0 \
		+ float(row.get("deposits", 0)) * 50.0 \
		+ float(row.get("wildlife_defeats", 0)) * 30.0 \
		+ float(row.get("stock_losses", 0)) * 20.0 \
		+ float(row.get("hut_damage", 0.0)) * 0.1 \
		+ float(row.get("core_damage", 0.0)) * 0.1 \
		- float(row.get("deaths", 0)) * 5.0

func _format_match_time(seconds: float) -> String:
	var total_seconds := int(floor(seconds))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _tick_kill_feed(delta: float) -> void:
	for i in range(kill_feed.size() - 1, -1, -1):
		kill_feed[i]["remaining"] = float(kill_feed[i]["remaining"]) - delta
		if float(kill_feed[i]["remaining"]) <= 0.0:
			kill_feed.remove_at(i)

func _player_near_own_hut() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	for hut in huts:
		if hut != null and is_instance_valid(hut) and hut.team == player.team and hut.global_position.distance_to(player.global_position) < 110.0:
			return true
	return false

func _try_manual_habitat_deposit(actor: Node) -> bool:
	return _try_habitat_deposit(actor, true)

func _try_autonomous_habitat_deposit(actor: Node) -> bool:
	return _try_habitat_deposit(actor, false)

func _try_habitat_deposit(actor: Node, show_player_feedback: bool) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if show_player_feedback and habitat_deposit_feedback_timer > 0.0:
		return false
	if show_player_feedback:
		habitat_deposit_feedback_timer = 1.0
	if not _is_actor_in_home_habitat(actor):
		if show_player_feedback:
			habitat_deposit_prompt_state = "needs_habitat"
			add_kill_feed("U: enter home habitat to deposit")
		return false
	if actor.has_method("is_satiated") and not actor.is_satiated():
		if show_player_feedback:
			habitat_deposit_prompt_state = "needs_food"
			add_kill_feed("U: eat wild food until satiated first")
		return false
	var cue: Dictionary = {}
	if uses_stock_respawn(actor):
		cue = stock_manager.record_habitat_visit(actor)
		if not bool(cue.get("accepted", true)):
			if show_player_feedback:
				habitat_deposit_prompt_state = "duplicate"
				add_kill_feed("U: %s is already breeding" % actor.get_actor_name())
			return false
		_spawn_breeding_actor_for_cue(cue)
	if actor.has_method("reset_hunger_after_deposit") and actor.has_method("is_satiated") and actor.is_satiated():
		actor.reset_hunger_after_deposit()
	if show_player_feedback:
		habitat_deposit_prompt_state = "accepted"
	_record_team_actor_stat(actor.team, "deposits", 1, actor)
	var duration := float(cue.get("duration", StockManagerScript.BREEDING_DURATION_SEC)) if not cue.is_empty() else StockManagerScript.BREEDING_DURATION_SEC
	_record_economy_event(actor, "deposit_committed", {
		"team": int(actor.team),
		"breeding_duration_sec": duration
	})
	add_kill_feed("%s deposited at habitat; breeding %.0fs" % [actor.get_actor_name(), duration])
	return true

func _is_actor_in_home_habitat(actor: Node) -> bool:
	var rect: Rect2 = terrain_map.get_team_habitat_rect(actor.team)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.grow(16.0).has_point(actor.global_position)

func _team_name(team: int) -> String:
	return "Blue" if team == BLUE else "Red"

var quit_confirm_timer := 0.0

func _input(event: InputEvent) -> void:
	if not _is_all_bots_mode() and event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F9:
		debug_wake_boss(BLUE)
		return
	if not _is_all_bots_mode() and event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F10:
		debug_spawn_center_boss()
		return
	if match_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		# No accidental mid-match exits: Esc must be pressed twice within 2s.
		if match_over or quit_confirm_timer > 0.0:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		else:
			quit_confirm_timer = 2.0
			add_kill_feed("Press Esc again to leave the match")
			var confirm_timer := get_tree().create_timer(2.0)
			confirm_timer.timeout.connect(func() -> void: quit_confirm_timer = 0.0)
	elif _is_1v1_trio_mode() and _is_pressed_non_echo_event(event):
		if event.is_action_pressed("squad_slot_1"):
			_set_active_squad_index(0)
		elif event.is_action_pressed("squad_slot_2"):
			_set_active_squad_index(1)
		elif event.is_action_pressed("squad_slot_3"):
			_set_active_squad_index(2)
		elif event.is_action_pressed("squad_regroup"):
			_issue_squad_follow()
		elif event.is_action_pressed("squad_farm"):
			_issue_squad_farm()

func _is_pressed_non_echo_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventAction:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false
