extends SceneTree


## 개발용 즉시 클리어 키(G)가 어느 상태에서 눌려도 정상 클리어 경로를 타는지 확인합니다.


const WAVE_REWARD_SCENE := preload("res://scenes/wave/wave_reward.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_REWARD_SCENE.instantiate() as WaveRewardCoordinator
	scene.reward_random_seed = 20260804
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var flow: WaveBallFlowController = scene.wave_ball_flow
	var controller: RewardChoiceController = scene.reward_controller

	# 1. 공 선택 중(보드에 공이 없음)에 눌렀을 때
	_expect(
		flow.current_state == WaveBallFlowController.State.SELECTING,
		"시작 상태는 공 선택이어야 한다."
	)
	_send_key(scene, KEY_G)
	await process_frame
	await process_frame
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"공 선택 중에 G를 누르면 웨이브가 승리로 끝나야 한다."
	)
	_expect(
		wave_manager.current_score >= 250000,
		"강제 클리어는 목표 점수를 채운 뒤 끝나야 한다."
	)
	_expect(controller.is_choosing, "강제 클리어 뒤 보상 선택창이 떠야 한다.")
	_expect(scene.reward_hud.visible, "보상 HUD가 보여야 한다.")

	# 2. 선택 대기 중에 다시 눌러도 아무 일도 없어야 한다
	_send_key(scene, KEY_G)
	await process_frame
	_expect(
		controller.is_choosing and wave_manager.current_wave_index == 0,
		"선택 대기 중 G는 무시되어야 한다."
	)

	controller.select_index(0)
	_send_action(controller, &"ball_select_confirm")
	await process_frame
	_expect(wave_manager.current_wave_index == 1, "선택 확정 후 웨이브 1로 넘어가야 한다.")
	_expect(
		flow.current_state == WaveBallFlowController.State.SELECTING,
		"다음 웨이브도 공 선택부터 시작해야 한다."
	)

	# 3. 공이 보드에서 굴러가는 중(IN_PLAY)에 눌렀을 때
	_send_action(flow, &"ball_select_confirm")
	_expect(scene.launcher.launch_prepared_ball(), "공이 발사되어야 한다.")
	_expect(
		flow.current_state == WaveBallFlowController.State.IN_PLAY,
		"발사 후에는 진행 상태여야 한다."
	)
	_send_key(scene, KEY_G)
	await process_frame
	await process_frame
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"진행 중에 G를 누르면 웨이브가 승리로 끝나야 한다."
	)
	_expect(
		wave_manager.current_score >= 400000,
		"웨이브 1의 목표 점수도 채워야 한다."
	)
	_expect(controller.is_choosing, "진행 중 강제 클리어 뒤에도 선택창이 떠야 한다.")

	controller.select_index(0)
	_send_action(controller, &"ball_select_confirm")
	await process_frame
	_expect(wave_manager.current_wave_index == 2, "웨이브 2로 넘어가야 한다.")

	# 4. 조준 중(AIMING)에 눌렀을 때
	_send_action(flow, &"ball_select_confirm")
	_expect(
		flow.current_state == WaveBallFlowController.State.AIMING,
		"확정 직후에는 조준 상태여야 한다."
	)
	_send_key(scene, KEY_G)
	await process_frame
	await process_frame
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"조준 중에 G를 누르면 웨이브가 승리로 끝나야 한다."
	)
	_expect(controller.is_choosing, "조준 중 강제 클리어 뒤에도 선택창이 떠야 한다.")

	controller.select_index(0)
	_send_action(controller, &"ball_select_confirm")
	await process_frame
	_expect(wave_manager.current_wave_index == 3, "웨이브 3으로 넘어가야 한다.")

	# 5. 마지막 웨이브를 G로 끝내면 스테이지 클리어
	var finished_reason := {&"value": &""}
	controller.sequence_finished.connect(func(reason: StringName) -> void:
		finished_reason.value = reason
	)
	_send_key(scene, KEY_G)
	await process_frame
	await process_frame
	_expect(
		finished_reason.value == &"stage_cleared",
		"마지막 웨이브를 G로 끝내면 스테이지 클리어여야 한다."
	)
	_expect(not controller.is_choosing, "스테이지 클리어 뒤에는 선택창이 뜨지 않아야 한다.")

	scene.queue_free()
	await process_frame
	_finish()


func _send_key(target: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	target._unhandled_input(event)


func _send_action(target: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_debug_clear_test")
		quit(0)
		return
	print("FAIL: wave_debug_clear_test (%d failures)" % _failures.size())
	quit(1)
