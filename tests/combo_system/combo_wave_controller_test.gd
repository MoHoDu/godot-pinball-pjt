extends SceneTree


const COMBO_SYSTEM_PATH := "res://scripts/combo_system/combo_system.gd"
const STAGE_SETTINGS_PATH := "res://scripts/combo_system/combo_stage_settings.gd"
const WAVE_CONTROLLER_PATH := "res://scripts/combo_system/combo_wave_controller.gd"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var combo_script := load(COMBO_SYSTEM_PATH) as Script
	var settings_script := load(STAGE_SETTINGS_PATH) as Script
	var controller_script := load(WAVE_CONTROLLER_PATH) as Script
	_expect(combo_script != null, "콤보 시스템을 불러올 수 있어야 한다.")
	_expect(settings_script != null, "스테이지 설정을 불러올 수 있어야 한다.")
	_expect(controller_script != null, "웨이브 컨트롤러를 불러올 수 있어야 한다.")
	if combo_script == null or settings_script == null or controller_script == null:
		_finish()
		return

	_test_stage_settings(settings_script)
	await _test_clear_choice_flow(combo_script, settings_script, controller_script)
	await _test_continue_until_exhausted(combo_script, settings_script, controller_script)
	await _test_retry_and_missed_target(combo_script, settings_script, controller_script)
	_finish()


func _test_stage_settings(settings_script: Script) -> void:
	var settings := settings_script.new() as Resource
	settings.set(&"stage_base_score", -10)
	settings.set(&"wave_target_scores", PackedInt32Array([-5, 500]))
	_expect(int(settings.get(&"stage_base_score")) == 0, \
		"stage_base_score는 음수가 될 수 없어야 한다.")
	_expect(int(settings.call(&"get_wave_target_score", 0)) == 0, \
		"음수 목표 점수는 0으로 보정해야 한다.")
	_expect(int(settings.call(&"get_wave_target_score", 1)) == 500, \
		"웨이브 인덱스의 목표 점수를 반환해야 한다.")
	_expect(int(settings.call(&"get_wave_target_score", 2)) == 0, \
		"설정되지 않은 웨이브 목표 점수는 0이어야 한다.")


func _test_clear_choice_flow(
	combo_script: Script,
	settings_script: Script,
	controller_script: Script
) -> void:
	var fixture := await _create_fixture(combo_script, settings_script, controller_script, 100)
	var combo: Node = fixture.combo
	var controller: Node = fixture.controller
	var target_signal_count := {&"value": 0}
	var choice_signal_count := {&"value": 0}
	var clear_signal_count := {&"value": 0}
	controller.target_score_reached.connect(func(_score: int, _target: int) -> void:
		target_signal_count.value += 1
	)
	controller.clear_choice_requested.connect(func(
		_score: int, _target: int, _remaining: int
	) -> void:
		choice_signal_count.value += 1
	)
	controller.wave_clear_requested.connect(func(_score: int, _target: int) -> void:
		clear_signal_count.value += 1
	)

	_expect(bool(controller.call(&"on_ball_launched")), \
		"첫 공 발사를 시작할 수 있어야 한다.")
	combo.call(&"register_hit", 1.0)
	combo.call(&"advance_time", 3.0)
	_expect(int(combo.get(&"total_score")) == 100, \
		"시간 초과 시 목표 점수를 정상 정산해야 한다.")
	_expect(int(target_signal_count.value) == 1, \
		"목표 달성은 한 번만 알려야 한다.")
	_expect(int(choice_signal_count.value) == 0, \
		"목표를 달성해도 현재 공이 낙하하기 전에는 선택을 요청하면 안 된다.")

	_expect(int(controller.call(&"on_ball_drained", 2)) == 0, \
		"이미 시간 초과로 정산된 공의 낙하는 다시 점수를 주면 안 된다.")
	_expect(bool(controller.get(&"choice_is_pending")), \
		"남은 공이 있으면 낙하 후 클리어 선택을 기다려야 한다.")
	_expect(int(choice_signal_count.value) == 1, \
		"클리어 선택 신호는 한 번만 보내야 한다.")
	_expect(int(controller.call(&"on_ball_drained", 2)) == 0, \
		"중복 낙하 이벤트는 무시해야 한다.")
	_expect(int(choice_signal_count.value) == 1, \
		"중복 낙하가 선택 신호를 반복하면 안 된다.")
	_expect(not bool(controller.call(&"on_ball_launched")), \
		"선택 대기 중 새 공 발사를 막아야 한다.")
	_expect(bool(controller.call(&"choose_clear")), \
		"클리어 선택을 확정할 수 있어야 한다.")
	_expect(int(clear_signal_count.value) == 1, \
		"클리어 요청은 한 번만 보내야 한다.")
	_expect(not bool(controller.call(&"choose_clear")), \
		"이미 처리한 선택을 다시 처리하면 안 된다.")

	await _destroy_fixture(fixture)


func _test_continue_until_exhausted(
	combo_script: Script,
	settings_script: Script,
	controller_script: Script
) -> void:
	var fixture := await _create_fixture(combo_script, settings_script, controller_script, 100)
	var combo: Node = fixture.combo
	var controller: Node = fixture.controller
	var clear_signal_count := {&"value": 0}
	controller.wave_clear_requested.connect(func(_score: int, _target: int) -> void:
		clear_signal_count.value += 1
	)

	controller.call(&"on_ball_launched")
	combo.call(&"register_hit", 1.0)
	_expect(int(controller.call(&"on_ball_drained", 1)) == 100, \
		"낙하 시 활성 콤보를 한 번 정산해야 한다.")
	_expect(bool(controller.call(&"choose_remaining_balls")), \
		"남은 공 사용을 선택할 수 있어야 한다.")
	_expect(bool(controller.get(&"is_waiting_for_remaining_balls")), \
		"남은 공을 모두 사용할 때까지 계속 상태를 유지해야 한다.")
	_expect(bool(controller.call(&"on_ball_launched")), \
		"계속 선택 후 다음 공을 발사할 수 있어야 한다.")
	_expect(int(controller.call(&"on_ball_drained", 0)) == 0, \
		"0콤보 공 낙하는 점수를 주면 안 된다.")
	_expect(int(combo.get(&"total_score")) == 100, \
		"0콤보 낙하가 누적 점수를 바꾸면 안 된다.")
	_expect(int(clear_signal_count.value) == 1, \
		"남은 공이 소진되면 자동으로 클리어를 요청해야 한다.")

	await _destroy_fixture(fixture)


func _test_retry_and_missed_target(
	combo_script: Script,
	settings_script: Script,
	controller_script: Script
) -> void:
	var fixture := await _create_fixture(combo_script, settings_script, controller_script, 300)
	var combo: Node = fixture.combo
	var controller: Node = fixture.controller
	controller.call(&"on_ball_launched")
	combo.call(&"register_hit", 1.0)
	_expect(int(controller.call(&"on_ball_drained", 1)) == 100, \
		"목표 미달이어도 콤보 점수는 정산해야 한다.")
	_expect(not bool(controller.get(&"choice_is_pending")), \
		"목표 미달 낙하는 클리어 선택을 요청하면 안 된다.")
	_expect(bool(controller.call(&"on_ball_launched")), \
		"목표 미달이면 다음 공을 바로 발사할 수 있어야 한다.")
	combo.call(&"register_hit", 1.0)
	controller.call(&"on_wave_retried")
	_expect(int(combo.get(&"combo_count")) == 0, \
		"웨이브 재시도는 현재 콤보를 0으로 초기화해야 한다.")
	_expect(int(combo.get(&"total_score")) == 0, \
		"웨이브 재시도는 누적 점수를 0으로 초기화해야 한다.")
	_expect(not bool(controller.get(&"ball_is_active")), \
		"웨이브 재시도는 공 진행 상태도 초기화해야 한다.")

	await _destroy_fixture(fixture)


func _create_fixture(
	combo_script: Script,
	settings_script: Script,
	controller_script: Script,
	target_score: int
) -> Dictionary:
	var combo := combo_script.new() as Node
	var controller := controller_script.new() as Node
	var settings := settings_script.new() as Resource
	settings.set(&"stage_id", &"validation_stage")
	settings.set(&"stage_base_score", 100)
	settings.set(&"wave_target_scores", PackedInt32Array([target_score]))
	root.add_child(combo)
	root.add_child(controller)
	await process_frame
	_expect(bool(controller.call(&"bind_combo_system", combo)), \
		"웨이브 컨트롤러가 콤보 시스템에 연결되어야 한다.")
	_expect(bool(controller.call(&"configure_wave", settings, 0)), \
		"웨이브 설정을 적용할 수 있어야 한다.")
	return {&"combo": combo, &"controller": controller, &"settings": settings}


func _destroy_fixture(fixture: Dictionary) -> void:
	(fixture.controller as Node).queue_free()
	(fixture.combo as Node).queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_wave_controller_test")
		quit(0)
		return
	print("FAIL: combo_wave_controller_test (%d failures)" % _failures.size())
	quit(1)
