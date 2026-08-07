class_name Stage1TeddyBossWaveBridge
extends Node


@export var boss_runtime: Stage1TeddyBossRuntime = null
@export var wave_manager: WaveManager = null
@export var combo_system: ComboSystem = null
@export var ball_flow: WaveBallFlowController = null
@export var wave_hud: WaveHud = null
@export var hud_state: WaveHudStateSource = null

@export_category("Explicit Production Flippers")
@export var bottom_left_flipper: PinballFlipper = null
@export var bottom_right_flipper: PinballFlipper = null
@export var top_left_flipper: PinballFlipper = null
@export var top_right_flipper: PinballFlipper = null
@export var left_left_flipper: PinballFlipper = null
@export var left_right_flipper: PinballFlipper = null
@export var right_left_flipper: PinballFlipper = null
@export var right_right_flipper: PinballFlipper = null


var _is_setup: bool = false
var _boss_completion_in_progress: bool = false


func _ready() -> void:
	call_deferred(&"_setup_bridge")


func _exit_tree() -> void:
	teardown()


func teardown() -> void:
	if not _is_setup:
		return
	_is_setup = false
	_disconnect_signals()
	_set_placeholder_advance_disabled(false)
	if is_instance_valid(boss_runtime):
		boss_runtime.teardown()


func is_ready() -> bool:
	return _is_setup and is_instance_valid(boss_runtime) \
		and boss_runtime.is_ready() \
		and is_instance_valid(wave_manager) \
		and is_instance_valid(wave_hud)


func _setup_bridge() -> void:
	if _is_setup or not _references_are_valid():
		return
	if not boss_runtime.setup(combo_system, ball_flow, _get_flippers()):
		return
	_connect_signals()
	_is_setup = true
	if wave_manager.current_stage_phase == WaveManager.StagePhase.BOSS:
		_enter_boss_phase()


func _references_are_valid() -> bool:
	for reference: Variant in [
		boss_runtime, wave_manager, combo_system, ball_flow, wave_hud, hud_state,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	var stage_button: Button = wave_hud.get_stage_phase_button()
	if stage_button == null or not is_instance_valid(stage_button):
		return false
	for flipper: PinballFlipper in _get_flippers():
		if flipper == null or not is_instance_valid(flipper) \
				or not flipper.is_inside_tree():
			return false
	return true


func _get_flippers() -> Array[PinballFlipper]:
	var flippers: Array[PinballFlipper] = [
		bottom_left_flipper,
		bottom_right_flipper,
		top_left_flipper,
		top_right_flipper,
		left_left_flipper,
		left_right_flipper,
		right_left_flipper,
		right_right_flipper,
	]
	return flippers


func _connect_signals() -> void:
	if not wave_manager.stage_phase_changed.is_connected(
		_on_stage_phase_changed
	):
		wave_manager.stage_phase_changed.connect(_on_stage_phase_changed)
	if not boss_runtime.battle_completed.is_connected(_on_battle_completed):
		boss_runtime.battle_completed.connect(_on_battle_completed)


func _disconnect_signals() -> void:
	if is_instance_valid(wave_manager) \
			and wave_manager.stage_phase_changed.is_connected(
				_on_stage_phase_changed
			):
		wave_manager.stage_phase_changed.disconnect(_on_stage_phase_changed)
	if is_instance_valid(boss_runtime) \
			and boss_runtime.battle_completed.is_connected(_on_battle_completed):
		boss_runtime.battle_completed.disconnect(_on_battle_completed)


func _on_stage_phase_changed(
	previous_phase: WaveManager.StagePhase,
	current_phase: WaveManager.StagePhase
) -> void:
	if current_phase == WaveManager.StagePhase.BOSS:
		_enter_boss_phase()
		return
	if previous_phase == WaveManager.StagePhase.BOSS:
		_set_placeholder_advance_disabled(false)
		if not _boss_completion_in_progress and boss_runtime.is_battle_active():
			boss_runtime.stop_battle()


func _enter_boss_phase() -> void:
	_set_placeholder_advance_disabled(true)
	hud_state.set_stage_phase(
		wave_manager.get_stage_phase_title(),
		wave_manager.get_stage_phase_button_text(),
		false
	)
	if not boss_runtime.start_battle():
		return
	if not wave_manager.start_boss_ball_cycle():
		boss_runtime.stop_battle()


func _on_battle_completed() -> void:
	if not _is_setup \
			or wave_manager.current_stage_phase != WaveManager.StagePhase.BOSS:
		return
	_boss_completion_in_progress = true
	if wave_manager.finish_boss_ball_cycle():
		wave_manager.advance_stage_phase()
	_boss_completion_in_progress = false
	if wave_manager.current_stage_phase != WaveManager.StagePhase.BOSS:
		_set_placeholder_advance_disabled(false)


func _set_placeholder_advance_disabled(disabled: bool) -> void:
	if not is_instance_valid(wave_hud):
		return
	var stage_button: Button = wave_hud.get_stage_phase_button()
	if is_instance_valid(stage_button):
		stage_button.disabled = disabled
