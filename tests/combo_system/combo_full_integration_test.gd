extends SceneTree


const COMBO_SYSTEM_PATH := "res://scripts/combo_system/combo_system.gd"
const BALL_STATS_PATH := "res://scripts/ball_base_system/pinball_stats.gd"
const HIT_SOURCE_PATH := "res://scripts/combo_system/combo_hit_source.gd"
const STAGE_SETTINGS_PATH := "res://scripts/combo_system/combo_stage_settings.gd"
const WAVE_CONTROLLER_PATH := "res://scripts/combo_system/combo_wave_controller.gd"
const BOSS_SETTINGS_PATH := "res://scripts/combo_system/combo_boss_settings.gd"
const BOSS_TARGET_PATH := "res://scripts/combo_system/combo_boss_target.gd"
const HUD_SCENE_PATH := "res://Resources/Prefabs/ui/combo/combo_hud.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scripts := {
		&"combo": load(COMBO_SYSTEM_PATH) as Script,
		&"ball_stats": load(BALL_STATS_PATH) as Script,
		&"source": load(HIT_SOURCE_PATH) as Script,
		&"stage": load(STAGE_SETTINGS_PATH) as Script,
		&"wave": load(WAVE_CONTROLLER_PATH) as Script,
		&"boss_settings": load(BOSS_SETTINGS_PATH) as Script,
		&"boss": load(BOSS_TARGET_PATH) as Script,
	}
	var hud_scene := load(HUD_SCENE_PATH) as PackedScene
	for key in scripts:
		var script: Script = scripts[key]
		_expect(script != null and script.can_instantiate(), \
			"%s 스크립트를 인스턴스화할 수 있어야 한다." % key)
	_expect(hud_scene != null and hud_scene.can_instantiate(), \
		"콤보 HUD 씬을 인스턴스화할 수 있어야 한다.")
	if not _failures.is_empty():
		_finish()
		return

	var combo := (scripts.combo as Script).new() as Node
	var source := (scripts.source as Script).new() as Node
	var wave := (scripts.wave as Script).new() as Node
	var boss := (scripts.boss as Script).new() as Node
	var hud := hud_scene.instantiate() as Control
	var stage_settings := (scripts.stage as Script).new() as Resource
	var boss_settings := (scripts.boss_settings as Script).new() as Resource
	var ball_stats := (scripts.ball_stats as Script).new() as Resource
	stage_settings.set(&"stage_id", &"integration_stage")
	stage_settings.set(&"stage_base_score", 125)
	stage_settings.set(&"wave_target_scores", PackedInt32Array([375]))
	boss_settings.set(&"boss_id", &"integration_boss")
	boss_settings.set(&"max_health", 100)
	boss_settings.set(&"target_hit_count", 1)
	ball_stats.set(&"mass", 1.0)

	root.add_child(combo)
	root.add_child(source)
	root.add_child(wave)
	root.add_child(boss)
	root.add_child(hud)
	await process_frame

	_expect(bool(combo.call(&"bind_hit_source", source)), \
		"일반 타격 소스를 콤보 시스템에 연결해야 한다.")
	_expect(bool(wave.call(&"bind_combo_system", combo)), \
		"웨이브 컨트롤러를 콤보 시스템에 연결해야 한다.")
	_expect(bool(wave.call(&"configure_wave", stage_settings, 0)), \
		"스테이지 점수 설정을 웨이브에 적용해야 한다.")
	_expect(bool(boss.call(&"bind_combo_system", combo)), \
		"보스 타격 수신기를 콤보 시스템에 연결해야 한다.")
	_expect(bool(boss.call(&"configure_boss", boss_settings)), \
		"보스 설정을 적용해야 한다.")
	_expect(bool(hud.call(&"bind_combo_system", combo)), \
		"HUD를 콤보 시스템에 연결해야 한다.")

	var target_reached_count := {&"value": 0}
	var choice_count := {&"value": 0}
	var clear_count := {&"value": 0}
	var boss_defeated_count := {&"value": 0}
	wave.target_score_reached.connect(func(_score: int, _target: int) -> void:
		target_reached_count.value += 1
	)
	wave.clear_choice_requested.connect(func(
		_score: int, _target: int, _remaining: int
	) -> void:
		choice_count.value += 1
	)
	wave.wave_clear_requested.connect(func(_score: int, _target: int) -> void:
		clear_count.value += 1
	)
	boss.defeated.connect(func() -> void:
		boss_defeated_count.value += 1
	)

	_expect(bool(wave.call(&"on_ball_launched")), \
		"첫 공을 발사해야 한다.")
	for contact_id in range(1, 4):
		_expect(bool(source.call(&"register_contact", contact_id)), \
			"각 일반 오브젝트 접촉을 유효 타격으로 받아야 한다.")
	_expect(int(combo.get(&"combo_count")) == 3, \
		"세 타격이 3콤보로 누적되어야 한다.")
	_expect(_label_text(hud, "ComboLabel") == "x3", \
		"HUD가 일반 타격 콤보를 표시해야 한다.")

	combo.call(&"suspend_combo_timer")
	combo.call(&"advance_time", 10.0)
	_expect(int(combo.get(&"combo_count")) == 3, \
		"강제 이동 중에는 콤보 시간이 진행되면 안 된다.")
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"강제 이동 시작 시 콤보 시간을 3초로 다시 채워야 한다.")
	combo.call(&"resume_combo_timer")
	combo.call(&"advance_time", 3.0)
	_expect(int(combo.get(&"total_score")) == 375, \
		"시간 초과 시 세 타격 점수를 한 번 정산해야 한다.")
	_expect(int(target_reached_count.value) == 1, \
		"현재 공 진행 중 목표 달성을 한 번 감지해야 한다.")
	_expect(int(choice_count.value) == 0, \
		"공 낙하 전에는 클리어 선택을 요청하면 안 된다.")

	_expect(int(wave.call(&"on_ball_drained", 1)) == 0, \
		"시간 초과 뒤 낙하가 점수를 중복 정산하면 안 된다.")
	_expect(int(choice_count.value) == 1, \
		"낙하 뒤 남은 공 사용 여부를 한 번 요청해야 한다.")
	_expect(bool(wave.call(&"choose_remaining_balls")), \
		"남은 공 사용 선택을 적용해야 한다.")
	_expect(bool(wave.call(&"on_ball_launched")), \
		"선택 후 마지막 공을 발사해야 한다.")

	_expect(int(boss.call(&"register_ball_contact", 77, ball_stats)) == 100, \
		"마지막 공의 첫 보스 타격이 보스를 처치해야 한다.")
	_expect(int(combo.get(&"combo_count")) == 1, \
		"보스 타격도 콤보를 먼저 1로 증가시켜야 한다.")
	_expect(float(combo.get(&"total_score_weight")) == 0.0, \
		"보스 타격은 일반 웨이브 점수 가중치를 더하면 안 된다.")
	_expect(int(boss_defeated_count.value) == 1, \
		"보스 처치 신호는 한 번만 발생해야 한다.")
	_expect(int(wave.call(&"on_ball_drained", 0)) == 0, \
		"보스 전용 콤보 정산은 일반 점수를 주면 안 된다.")
	_expect(int(combo.get(&"total_score")) == 375, \
		"보스 타격 뒤에도 일반 웨이브 점수는 유지되어야 한다.")
	_expect(int(clear_count.value) == 1, \
		"남은 공 소진 뒤 웨이브 클리어를 한 번 요청해야 한다.")
	_expect(int(wave.call(&"on_ball_drained", 0)) == 0, \
		"중복 마지막 낙하를 무시해야 한다.")
	_expect(int(clear_count.value) == 1, \
		"중복 마지막 낙하가 클리어 요청을 반복하면 안 된다.")
	_expect(_label_text(hud, "ScoreLabel") == "SCORE 375", \
		"HUD가 최종 일반 웨이브 점수를 유지해야 한다.")

	wave.call(&"on_wave_retried")
	boss.call(&"reset_encounter")
	source.call(&"reset_contacts")
	_expect(int(combo.get(&"combo_count")) == 0 \
			and int(combo.get(&"total_score")) == 0, \
		"웨이브 재시도는 콤보와 점수를 함께 초기화해야 한다.")
	_expect(not bool(wave.get(&"target_reached")) \
			and not bool(wave.get(&"clear_was_requested")), \
		"웨이브 재시도는 목표·클리어 진행 상태를 초기화해야 한다.")
	_expect(int(boss.get(&"current_health")) == 100 \
			and not bool(boss.get(&"is_defeated")), \
		"보스 재시도는 체력과 처치 상태를 복원해야 한다.")
	_expect(_label_text(hud, "ScoreLabel") == "SCORE 0", \
		"HUD가 재시도 점수 초기화를 표시해야 한다.")

	hud.queue_free()
	boss.queue_free()
	wave.queue_free()
	source.queue_free()
	combo.queue_free()
	await process_frame
	_finish()


func _label_text(hud: Control, node_name: String) -> String:
	var label := hud.find_child(node_name, true, false) as Label
	return label.text if label != null else "<missing>"


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_full_integration_test")
		quit(0)
		return
	print("FAIL: combo_full_integration_test (%d failures)" % _failures.size())
	quit(1)
