class_name DebugTeddyBossWave
extends WaveRuntimeCoordinator


@export_category("Boss Debug Dependencies")
@export var debug_boss_runtime: Stage1TeddyBossRuntime = null
@export var damage_1000_button: Button = null
@export var phase_2_button: Button = null
@export var defeat_button: Button = null
@export var debug_status_label: Label = null


var _debug_entry_started: bool = false
var _debug_entry_completed: bool = false


func _ready() -> void:
	super._ready()
	_connect_debug_buttons()
	call_deferred(&"_enter_boss_for_debug")


func _process(delta: float) -> void:
	super._process(delta)
	_update_debug_status()


func _enter_boss_for_debug() -> void:
	if _debug_entry_started:
		return
	_debug_entry_started = true
	await get_tree().process_frame
	await get_tree().process_frame

	for wave_index: int in WaveManager.NORMAL_WAVE_COUNT:
		if not _complete_normal_wave_with_public_api(wave_index):
			_update_debug_status("Boss debug entry failed at Wave %d." % (wave_index + 1))
			return
		await get_tree().process_frame
		await get_tree().process_frame
		if wave_manager.current_stage_phase != WaveManager.StagePhase.WAVE_RESULT:
			_update_debug_status("Wave result transition did not complete.")
			return
		if not wave_manager.advance_stage_phase():
			_update_debug_status("Wave result could not advance to reward.")
			return
		if not wave_manager.advance_stage_phase():
			_update_debug_status("Reward could not advance.")
			return

	await get_tree().process_frame
	_debug_entry_completed = (
		wave_manager.current_stage_phase == WaveManager.StagePhase.BOSS
		and wave_manager.is_boss_ball_cycle_active()
		and is_instance_valid(debug_boss_runtime)
		and debug_boss_runtime.is_battle_active()
	)
	if not _debug_entry_completed:
		_update_debug_status("Production Boss startup did not complete.")


func _complete_normal_wave_with_public_api(expected_wave_index: int) -> bool:
	if not _debug_dependencies_are_valid() \
			or wave_manager.current_stage_phase \
				!= WaveManager.StagePhase.REPAIR_PLACEMENT \
			or wave_manager.current_wave_index != expected_wave_index:
		return false
	if not wave_manager.advance_stage_phase():
		return false
	if not wave_ball_flow.confirm_selection():
		return false
	if not launcher.launch_prepared_ball():
		return false

	combo_system.stage_base_score = maxi(wave_manager.target_score, 1)
	combo_system.register_hit(1.0)
	combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	return true


func _debug_dependencies_are_valid() -> bool:
	return is_instance_valid(wave_manager) \
		and is_instance_valid(wave_ball_flow) \
		and is_instance_valid(launcher) \
		and is_instance_valid(combo_system) \
		and is_instance_valid(debug_boss_runtime)


func _connect_debug_buttons() -> void:
	if is_instance_valid(damage_1000_button) \
			and not damage_1000_button.pressed.is_connected(_on_damage_1000_pressed):
		damage_1000_button.pressed.connect(_on_damage_1000_pressed)
	if is_instance_valid(phase_2_button) \
			and not phase_2_button.pressed.is_connected(_on_phase_2_pressed):
		phase_2_button.pressed.connect(_on_phase_2_pressed)
	if is_instance_valid(defeat_button) \
			and not defeat_button.pressed.is_connected(_on_defeat_pressed):
		defeat_button.pressed.connect(_on_defeat_pressed)


func _on_damage_1000_pressed() -> void:
	var health: BossHealthComponent = _get_debug_health()
	if health != null and not health.is_defeated():
		health.apply_damage(1000)


func _on_phase_2_pressed() -> void:
	var health: BossHealthComponent = _get_debug_health()
	if health == null or health.is_defeated():
		return
	var threshold_hp: int = int(
		float(health.get_max_health()) * debug_boss_runtime.phase1_rules.phase2_hp_ratio
	)
	var damage_needed: int = health.get_current_health() - threshold_hp
	if damage_needed > 0:
		health.apply_damage(damage_needed)


func _on_defeat_pressed() -> void:
	var health: BossHealthComponent = _get_debug_health()
	if health != null and not health.is_defeated():
		health.apply_damage(health.get_current_health())


func _get_debug_health() -> BossHealthComponent:
	if not _debug_entry_completed \
			or not is_instance_valid(debug_boss_runtime) \
			or not is_instance_valid(debug_boss_runtime.health):
		return null
	return debug_boss_runtime.health


func _update_debug_status(override_text: String = "") -> void:
	if not is_instance_valid(debug_status_label):
		return
	if not override_text.is_empty():
		debug_status_label.text = override_text
		return
	var phase_name: String = "UNAVAILABLE"
	if is_instance_valid(wave_manager):
		phase_name = String(
			WaveManager.StagePhase.keys()[wave_manager.current_stage_phase]
		)
	var health: BossHealthComponent = _get_debug_health()
	var hp_text: String = "not ready"
	if health != null:
		hp_text = "%d / %d" % [
			health.get_current_health(),
			health.get_max_health(),
		]
	debug_status_label.text = "Stage: %s\nBoss HP: %s" % [phase_name, hp_text]
