extends SceneTree

const ARENA_SCENE := "res://scenes/Arena.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := get_root().get_node_or_null("GameConfig")
	if config != null:
		config.selected_mode = "1v1"
		config.set_selected_squad_ids(["duck", "snapping_turtle", "mink"])

	var error := change_scene_to_file(ARENA_SCENE)
	if error != OK:
		push_error("boss_meter_freeze check failed to boot Arena: %d" % error)
		quit(1)
		return
	await process_frame
	await process_frame
	var arena := current_scene
	if arena == null:
		push_error("boss_meter_freeze check: Arena scene did not load")
		quit(1)
		return

	var failures: Array[String] = []
	_check_meter_freeze(arena, failures)

	print("boss_meter_freeze failures=%d" % failures.size())
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_meter_freeze(arena: Node, failures: Array[String]) -> void:
	# Fill the blue meter to activate the blue side boss.
	for _i in range(5):
		arena._record_bred_animal(0)
	var activated: Dictionary = arena.get_side_boss_state(0)
	if not bool(activated.get("active", false)) or int(activated.get("meter", -1)) != 0:
		failures.append("blue boss should be active with meter 0 after 5 breeds; state=%s" % str(activated))

	# While the blue boss is active, further blue breeds are frozen out.
	arena._record_bred_animal(0)
	arena._record_bred_animal(0)
	var frozen: Dictionary = arena.get_side_boss_state(0)
	if int(frozen.get("meter", -1)) != 0 or int(frozen.get("activations", -1)) != 1:
		failures.append("blue meter/activations should stay frozen while boss active; state=%s" % str(frozen))

	# Clear the blue boss by defeating its wildlife occupant(s).
	var cleared_any := false
	for enc in arena.wildlife_encounters.duplicate():
		if enc != null and is_instance_valid(enc) and String(enc.get("zone_id")) == "blue:Boss":
			arena.on_wildlife_defeated(enc, arena.player)
			cleared_any = true
	if not cleared_any:
		failures.append("expected a blue:Boss wildlife encounter to defeat")
	if bool(arena.get_side_boss_state(0).get("active", true)):
		failures.append("blue boss should be inactive after its wildlife is defeated; state=%s" % str(arena.get_side_boss_state(0)))

	# Downing does not resolve the objective. Claimable and contesting phases both
	# remain locked so later breeds cannot overwrite an unfinished claim.
	var claimable_state: Dictionary = arena.get_side_boss_state(0)
	arena._record_bred_animal(0)
	arena._record_bred_animal(0)
	var claimable_frozen: Dictionary = arena.get_side_boss_state(0)
	if String(claimable_state.get("objective_state", "")) != "claimable" \
		or not arena.is_side_boss_meter_locked(0) \
		or int(claimable_frozen.get("meter", -1)) != 0 \
		or int(claimable_frozen.get("activations", -1)) != 1:
		failures.append("blue meter should remain frozen through claimable; state=%s" % str(claimable_frozen))

	var zone_index := -1
	for i in arena.animal_zone_states.size():
		if String(arena.animal_zone_states[i].get("id", "")) == "blue:Boss":
			zone_index = i
			break
	if zone_index < 0:
		failures.append("expected blue:Boss zone state for contest lock")
		return
	var zone: Dictionary = arena.animal_zone_states[zone_index]
	zone["objective_state"] = "contesting"
	arena.animal_zone_states[zone_index] = zone
	arena._record_bred_animal(0)
	arena._record_bred_animal(0)
	var contesting_frozen: Dictionary = arena.get_side_boss_state(0)
	if not arena.is_side_boss_meter_locked(0) \
		or int(contesting_frozen.get("meter", -1)) != 0 \
		or int(contesting_frozen.get("activations", -1)) != 1:
		failures.append("blue meter should remain frozen through contesting; state=%s" % str(contesting_frozen))

	# Once the claim resolves, the next breed starts the next cycle.
	zone = arena.animal_zone_states[zone_index]
	zone["objective_state"] = "claimed"
	arena.animal_zone_states[zone_index] = zone
	arena._record_bred_animal(0)
	var resumed := int(arena.get_side_boss_state(0).get("meter", -1))
	if arena.is_side_boss_meter_locked(0) or resumed != 1:
		failures.append("blue meter should resume to 1 only after claim resolution; meter=%d" % resumed)
