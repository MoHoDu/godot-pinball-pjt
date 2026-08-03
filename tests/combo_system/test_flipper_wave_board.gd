extends "res://tests/combo_system/test_flipper_combo_board.gd"


@onready var wave_ball_inventory: WaveBallInventory = get_node(
	"WaveBallInventory"
) as WaveBallInventory
@onready var wave_ball_flow: WaveBallFlowController = get_node(
	"WaveBallFlowController"
) as WaveBallFlowController
@onready var ball_selection_hud: BallSelectionHud = get_node(
	"HUD/BallSelectionHud"
) as BallSelectionHud


var _wave_settings := ComboStageSettings.new()


func _ready() -> void:
	super()
	var authored_ball := ball
	if is_instance_valid(launcher):
		launcher.cancel_prepared_ball(false)
	if is_instance_valid(authored_ball):
		authored_ball.queue_free()
	ball = null

	wave_ball_flow.bind_inventory(wave_ball_inventory)
	wave_ball_flow.bind_launcher(launcher)
	wave_ball_flow.active_ball_changed.connect(_on_active_ball_changed)
	combo_wave_controller.bind_combo_system(combo_system)
	combo_wave_controller.bind_ball_flow(wave_ball_flow)
	_wave_settings.stage_id = &"main_demo_stage"
	_wave_settings.stage_base_score = 100
	_wave_settings.wave_target_scores = PackedInt32Array([500])
	combo_wave_controller.configure_wave(_wave_settings, 0)
	ball_selection_hud.bind_ball_flow(wave_ball_flow)
	wave_ball_flow.start_wave()
	_append_event("WAVE · 다음 공을 선택하세요")


func reset_ball() -> void:
	if not is_instance_valid(wave_ball_flow):
		return
	if wave_ball_flow.current_state == WaveBallFlowController.State.IN_PLAY:
		_handle_ball_drained("R 수동 낙하")
		return
	if wave_ball_flow.current_state in [
		WaveBallFlowController.State.SELECTING,
		WaveBallFlowController.State.EXHAUSTED,
	]:
		combo_wave_controller.on_wave_retried()


func _handle_ball_drained(source_name: String) -> void:
	if not is_instance_valid(ball) or not is_instance_valid(wave_ball_flow):
		_drain_pending = false
		return
	var drained_ball := ball
	if wave_ball_flow.on_ball_drained(drained_ball):
		_append_event("DRAIN · %s · 공 선택으로 이동" % source_name)
	_drain_pending = false


func _on_active_ball_changed(next_ball: Pinball) -> void:
	ball = next_ball
