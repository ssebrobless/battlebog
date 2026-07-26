extends Control

const ARENA_SCENE := "res://scenes/Arena.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const CreatureReadFormatter := preload("res://scripts/ui/creature_read_formatter.gd")
const SLICE_CREATURE_IDS := [
	"snapping_turtle",
	"chorus_frog",
	"mink",
	"beaver",
	"otter",
	"leech",
	"owl",
	"duck",
	"bullfrog",
	"cane_toad",
	"crayfish",
	"bog_turtle",
	"water_shrew",
	"newt",
	"great_blue_heron",
	"kingfisher",
	"water_snake",
	"alligator",
	"wolf_spider",
	"firefly",
	"mosquito_swarm"
]
const FAMILY_LABELS := {
	"amphibian": "Amphibians",
	"reptile": "Reptiles",
	"bird": "Birds",
	"mammal": "Mammals",
	"crawly": "Crawlies"
}
const FAMILY_ORDER := ["amphibian", "reptile", "bird", "mammal", "crawly"]

var creatures: Array[Dictionary] = []
var selectable_indices: Array[int] = []
var selected_index := 0
var selected_squad_ids: Array[String] = []
var active_squad_slot := 0

@onready var mode_label: Label = $Root/Header/ModeLabel
@onready var squad_panel: VBoxContainer = $Root/Header/SquadPanel
@onready var squad_hint: Label = $Root/Header/SquadPanel/SquadHint
@onready var squad_slots: HBoxContainer = $Root/Header/SquadPanel/SquadSlots
@onready var hero_list: VBoxContainer = $Root/Content/HeroScroll/HeroList
@onready var preview: Control = $Root/Content/Details/HeroPreview
@onready var hero_name: Label = $Root/Content/Details/HeroName
@onready var role_label: Label = $Root/Content/Details/RoleLabel
@onready var identity_label: Label = $Root/Content/Details/IdentityLabel
@onready var stat_label: Label = $Root/Content/Details/StatLabel
@onready var matchup_label: Label = $Root/Content/Details/MatchupLabel
@onready var ability_label: Label = $Root/Content/Details/AbilityLabel
@onready var counterplay_label: Label = $Root/Content/Details/CounterplayLabel
@onready var start_button: Button = $Root/Footer/StartButton
@onready var back_button: Button = $Root/Footer/BackButton

func _ready() -> void:
	_load_creatures()
	_build_creature_buttons()
	start_button.pressed.connect(_start_match)
	back_button.pressed.connect(_go_back)
	for slot_index in squad_slots.get_child_count():
		var slot_button := squad_slots.get_child(slot_index) as Button
		if slot_button != null:
			slot_button.pressed.connect(_set_active_squad_slot.bind(slot_index))
	_setup_mode_ui()

	var selected_id := GameConfig.selected_creature_id
	if _is_trio_mode():
		selected_squad_ids = GameConfig.get_selected_squad_ids()
		active_squad_slot = clampi(active_squad_slot, 0, selected_squad_ids.size() - 1)
		selected_id = selected_squad_ids[active_squad_slot]

	for i in creatures.size():
		if creatures[i].get("id", "") == selected_id and _is_selectable(creatures[i]):
			selected_index = i
			break
	_select_creature(selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_accept"):
		_start_match()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var slot: int = event.keycode - KEY_1
			if slot < selectable_indices.size():
				_select_creature(selectable_indices[slot])

func _load_creatures() -> void:
	creatures = CreatureCatalog.get_all()

func _build_creature_buttons() -> void:
	for child in hero_list.get_children():
		child.queue_free()

	selectable_indices.clear()
	var grouped := _group_by_family()
	for family in FAMILY_ORDER:
		if not grouped.has(family):
			continue

		var header := Label.new()
		header.text = FAMILY_LABELS.get(family, family.capitalize())
		header.add_theme_color_override("font_color", Color(0.76, 0.84, 0.86))
		hero_list.add_child(header)

		for creature in grouped[family]:
			var index: int = creatures.find(creature)
			var selectable := _is_selectable(creature)
			var banned := _is_banned(creature)
			var selectable_number := selectable_indices.size() + 1
			if selectable and not banned:
				selectable_indices.append(index)

			var button := Button.new()
			if banned:
				button.text = "%s  banned" % creature.get("name", "Unknown")
			else:
				button.text = "%d  %s" % [selectable_number, creature.get("name", "Unknown")] if selectable else "%s  coming soon" % creature.get("name", "Unknown")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(260.0, 34.0)
			button.set_meta("creature_index", index)
			button.set_meta("selectable", selectable)
			button.set_meta("banned", banned)
			button.disabled = not selectable or banned
			button.modulate = Color(0.55, 0.42, 0.4, 0.78) if banned else (Color(1.0, 1.0, 1.0, 1.0) if selectable else Color(0.48, 0.52, 0.54, 0.78))
			button.pressed.connect(_select_creature.bind(index))
			hero_list.add_child(button)

func _select_creature(index: int) -> void:
	if creatures.is_empty():
		return

	selected_index = clampi(index, 0, creatures.size() - 1)
	var creature: Dictionary = creatures[selected_index]
	if not _is_selectable(creature) or _is_banned(creature):
		return

	var creature_id := String(creature.get("id", "snapping_turtle"))
	if _is_trio_mode():
		_assign_trio_slot(creature_id)
	else:
		GameConfig.set_selected_creature(creature_id)
	preview.set_creature(creature_id, 0)

	hero_name.text = creature.get("name", "Unknown")
	role_label.text = "%s | %s" % [
		String(creature.get("family", "family")).to_upper(),
		", ".join(PackedStringArray(creature.get("role", []))).to_upper()
	]
	identity_label.text = String(creature.get("identity_blurb", "Playable Wave 1 creature."))
	var stats: Dictionary = creature.get("stats", {})
	var footprint: Dictionary = creature.get("footprint", {})
	stat_label.text = "HP %s    Speed %s    Diet %s\nFootprint %s    Height %s" % [
		str(stats.get("health", "?")),
		CreatureReadFormatter.speed_text(stats),
		String(creature.get("diet", "?")).capitalize(),
		CreatureReadFormatter.footprint_text(footprint),
		CreatureReadFormatter.height_read_text(creature_id)
	]
	matchup_label.text = "Wins: %s\nFears: %s" % [
		_format_short_list(creature.get("wins", [])),
		_format_short_list(creature.get("fears", []))
	]

	var ability_lines := ["Primary: %s" % creature.get("primary", "")]
	for ability: Dictionary in creature.get("abilities", []):
		ability_lines.append("%s: %s - %s" % [
			ability.get("slot", "?"),
			ability.get("name", "Ability"),
			ability.get("summary", "")
		])
	ability_label.text = "\n".join(ability_lines)

	var passive_lines: Array[String] = []
	for passive: Dictionary in creature.get("passives", []):
		passive_lines.append("%s: %s" % [passive.get("name", "Passive"), passive.get("summary", "")])
	counterplay_label.text = "Passives: %s" % ("None" if passive_lines.is_empty() else " / ".join(passive_lines))

	_refresh_button_states()
	_refresh_squad_display()

func _setup_mode_ui() -> void:
	var mode_text := "Play vs AI" if _is_trio_mode() else GameConfig.selected_mode
	mode_label.text = "Mode: %s" % mode_text
	squad_panel.visible = _is_trio_mode()
	start_button.text = "Start Trio Match" if _is_trio_mode() else "Start Match"
	if _is_trio_mode():
		selected_squad_ids = GameConfig.get_selected_squad_ids()
		var draft_state: Dictionary = GameConfig.get_draft_stub_state()
		var ban_text := _format_ban_text(draft_state)
		squad_hint.text = "Pick a slot, then pick a playable creature. Slot 1 starts active; 1/2/3 swap during the match.%s" % ban_text
	else:
		selected_squad_ids.clear()

func _is_trio_mode() -> bool:
	return GameConfig.selected_mode == "1v1"

func _set_active_squad_slot(slot_index: int) -> void:
	if not _is_trio_mode():
		return
	active_squad_slot = clampi(slot_index, 0, 2)
	if active_squad_slot < selected_squad_ids.size():
		var creature_id := selected_squad_ids[active_squad_slot]
		var index := _find_creature_index(creature_id)
		if index >= 0:
			_select_creature(index)
			return
	_refresh_squad_display()
	_refresh_button_states()

func _assign_trio_slot(creature_id: String) -> void:
	if not SLICE_CREATURE_IDS.has(creature_id):
		return
	selected_squad_ids = GameConfig.get_selected_squad_ids()
	active_squad_slot = clampi(active_squad_slot, 0, 2)
	while selected_squad_ids.size() < 3:
		selected_squad_ids.append(SLICE_CREATURE_IDS[selected_squad_ids.size()])

	var existing_slot := selected_squad_ids.find(creature_id)
	if existing_slot >= 0 and existing_slot != active_squad_slot:
		selected_squad_ids[existing_slot] = selected_squad_ids[active_squad_slot]
	selected_squad_ids[active_squad_slot] = creature_id
	GameConfig.set_selected_squad_ids(selected_squad_ids)
	selected_squad_ids = GameConfig.get_selected_squad_ids()

func _refresh_squad_display() -> void:
	if not _is_trio_mode():
		return
	selected_squad_ids = GameConfig.get_selected_squad_ids()
	for slot_index in squad_slots.get_child_count():
		var button := squad_slots.get_child(slot_index) as Button
		if button == null:
			continue
		var creature_id := selected_squad_ids[slot_index] if slot_index < selected_squad_ids.size() else ""
		var prefix := "Slot %d" % (slot_index + 1)
		if slot_index == 0:
			prefix = "Slot 1 start"
		if slot_index == active_squad_slot:
			prefix = "> %s" % prefix
		button.text = "%s\n%s" % [prefix, _get_creature_name(creature_id)]
		button.modulate = Color(1.0, 0.95, 0.64, 1.0) if slot_index == active_squad_slot else Color(1.0, 1.0, 1.0, 1.0)

func _find_creature_index(creature_id: String) -> int:
	for i in creatures.size():
		if String(creatures[i].get("id", "")) == creature_id:
			return i
	return -1

func _get_creature_name(creature_id: String) -> String:
	var index := _find_creature_index(creature_id)
	if index >= 0:
		return String(creatures[index].get("name", creature_id))
	return creature_id.capitalize()

func _group_by_family() -> Dictionary:
	var grouped := {}
	for creature in creatures:
		var family := String(creature.get("family", "unknown"))
		if not grouped.has(family):
			grouped[family] = []
		grouped[family].append(creature)
	return grouped

func _is_selectable(creature: Dictionary) -> bool:
	return SLICE_CREATURE_IDS.has(creature.get("id", ""))

func _is_banned(creature: Dictionary) -> bool:
	return GameConfig.is_creature_banned(String(creature.get("id", "")))

func _refresh_button_states() -> void:
	for child in hero_list.get_children():
		var button := child as Button
		if button == null or not bool(button.get_meta("selectable", false)):
			continue
		if bool(button.get_meta("banned", false)):
			button.disabled = true
			button.modulate = Color(0.55, 0.42, 0.4, 0.78)
			continue
		if _is_trio_mode():
			button.disabled = false
			var creature_id := String(creatures[int(button.get_meta("creature_index", -1))].get("id", ""))
			button.modulate = Color(0.88, 1.0, 0.84, 1.0) if selected_squad_ids.has(creature_id) else Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.disabled = int(button.get_meta("creature_index", -1)) == selected_index

func _format_short_list(value: Variant) -> String:
	if value is Array:
		var parts := PackedStringArray()
		for item in value:
			var text := String(item)
			if not text.is_empty():
				parts.append(text)
		return ", ".join(parts) if not parts.is_empty() else "TBD"
	var text := String(value)
	return text if not text.is_empty() else "TBD"

func _format_ban_text(draft_state: Dictionary) -> String:
	if not bool(draft_state.get("enabled", false)):
		return ""
	var blue_bans: Array = draft_state.get("blue_bans", [])
	var red_bans: Array = draft_state.get("red_bans", [])
	if blue_bans.is_empty() and red_bans.is_empty():
		return " Draft bans: open."
	return " Draft bans: Blue %s / Red %s." % [
		_format_ban_names(blue_bans),
		_format_ban_names(red_bans)
	]

func _format_ban_names(bans: Array) -> String:
	if bans.is_empty():
		return "none"
	var names := PackedStringArray()
	for creature_id in bans:
		names.append(_get_creature_name(String(creature_id)))
	return ", ".join(names)

func _start_match() -> void:
	get_tree().change_scene_to_file(ARENA_SCENE)

func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
