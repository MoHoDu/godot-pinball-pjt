extends SceneTree


## 종료 유예의 타임아웃 경로(기획서 3-2 — "3초 경과" 조건)를 실씬으로
## 확인합니다. 공이 유예 시간을 버티면 강제 낙하로 웨이브가 확정되어야 합니다.
## 테스트 시간을 줄이려고 유예를 0.6초로 줄여 실행합니다.


const WAVE_SCENE := preload("res://Resources/Prefabs/wave/base/wave.tscn")

const HIT_WEIGHT := 20000.0
const MAX_TIMEOUT_FRAMES := 300


var _failures: Array[String] = []
var _finish_reasons: Array[StringName] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveRuntimeCoordinator
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var clear_delay := scene.get_node(
		^"CoinSystem/WaveClearDelayController"
	) as WaveClearDelayController
	clear_delay.duration = 0.6
	clear_delay.wave_clear_delay_finished.connect(
		func(
			reason: StringName,
			_delay_score: int,
			_delay_coin: int,
			_board_coin: int
		) -> void:
			_finish_reasons.append(reason)
	)
	var placement_bridge := scene.get_node(
		^"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(
		placement_bridge.commit_placement(),
		"수리 부품 배치를 확정하고 웨이브에 진입해야 한다."
	)

	# 공을 발사한 채 목표 점수를 채우고, 낙하시키지 않고 유예 만료를 기다린다.
	var flow: WaveBallFlowController = scene.wave_ball_flow
	var event := InputEventAction.new()
	event.action = &"ball_select_confirm"
	event.pressed = true
	flow._unhandled_input(event)
	_expect(scene.launcher.launch_prepared_ball(), "공이 발사되어야 한다.")
	# 물리 궤적으로 먼저 낙하하면 타임아웃 경로를 검증할 수 없으므로 고정한다.
	if is_instance_valid(flow.active_ball):
		flow.active_ball.freeze = true
	# 점수는 콤보 정산 시점에 반영되므로 수동으로 정산해 목표를 달성시킨다.
	scene.combo_system.register_hit(HIT_WEIGHT)
	scene.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_expect(
		clear_delay.is_delay_active,
		"목표 달성 시 종료 유예가 시작되어야 한다."
	)

	for _frame in MAX_TIMEOUT_FRAMES:
		if not _finish_reasons.is_empty():
			break
		await process_frame
	_expect(
		not _finish_reasons.is_empty(),
		"유예 만료 시 wave_clear_delay_finished가 발화해야 한다."
	)
	if not _finish_reasons.is_empty():
		_expect(
			_finish_reasons[0] == WaveClearDelayController.REASON_TIMEOUT,
			"만료 사유가 timeout이어야 한다. (%s)" % _finish_reasons[0]
		)
	for _frame in 12:
		if wave_manager.current_state == WaveManager.State.WON:
			break
		await process_frame
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"강제 낙하 후 웨이브가 승리로 확정되어야 한다. (%s)"
		% wave_manager.get_state_name()
	)

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: clear_delay_timeout_test")
		quit(0)
		return
	print("FAIL: clear_delay_timeout_test (%d failures)" % _failures.size())
	quit(1)
