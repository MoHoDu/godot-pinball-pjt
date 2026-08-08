extends SceneTree


const COMBO_SYSTEM_PATH := "res://scripts/combo_system/combo_system.gd"
const COMBO_HUD_SCENE_PATH := "res://Resources/Prefabs/ui/combo/combo_hud.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var combo_script := load(COMBO_SYSTEM_PATH) as Script
	var hud_scene := load(COMBO_HUD_SCENE_PATH) as PackedScene
	_expect(combo_script != null and combo_script.can_instantiate(), \
		"콤보 시스템을 인스턴스화할 수 있어야 한다.")
	_expect(hud_scene != null and hud_scene.can_instantiate(), \
		"콤보 HUD 씬을 인스턴스화할 수 있어야 한다.")
	if combo_script == null or not combo_script.can_instantiate() \
			or hud_scene == null or not hud_scene.can_instantiate():
		_finish()
		return

	var combo := combo_script.new() as Node
	var hud := hud_scene.instantiate() as Control
	root.add_child(combo)
	root.add_child(hud)
	await process_frame
	_test_initial_and_binding(combo, hud)
	_test_hit_tier_and_timer(combo, hud)
	_test_suspension(combo, hud)
	_test_settlement_and_retry(combo, hud)
	_test_unbind(combo, hud)

	hud.queue_free()
	combo.queue_free()
	await process_frame
	_finish()


func _test_initial_and_binding(combo: Node, hud: Control) -> void:
	var unsupported := Node.new()
	_expect(not bool(hud.call(&"bind_combo_system", unsupported)), \
		"필수 신호가 없는 노드는 HUD 연결을 거절해야 한다.")
	unsupported.free()
	_expect(bool(hud.call(&"bind_combo_system", combo)), \
		"HUD를 콤보 시스템에 연결할 수 있어야 한다.")
	_expect(_label_text(hud, "ComboLabel") == "x0", \
		"초기 콤보 표시는 x0이어야 한다.")
	_expect(_label_text(hud, "TierLabel") == "None", \
		"초기 단계 표시는 None이어야 한다.")
	_expect(_label_text(hud, "ScoreLabel") == "SCORE 0", \
		"초기 점수 표시는 0이어야 한다.")


func _test_hit_tier_and_timer(combo: Node, hud: Control) -> void:
	var hit_feedback_count := {&"value": 0}
	var tier_feedback_count := {&"value": 0}
	hud.hit_feedback_requested.connect(func(_count: int, _tier: int) -> void:
		hit_feedback_count.value += 1
	)
	hud.tier_feedback_requested.connect(func(
		_previous: int, _current: int, _count: int
	) -> void:
		tier_feedback_count.value += 1
	)

	combo.call(&"register_hit", 1.0)
	_expect(_label_text(hud, "ComboLabel") == "x1", \
		"유효 타격 직후 콤보 수를 표시해야 한다.")
	_expect(_label_text(hud, "TierLabel") == "Normal", \
		"첫 유효 타격은 Normal 단계를 표시해야 한다.")
	_expect_float(_timer(hud).value, 3.0, \
		"유효 타격 직후 타이머 게이지를 3초로 채워야 한다.")
	for _index in range(10):
		combo.call(&"register_hit", 1.0)
	_expect(_label_text(hud, "ComboLabel") == "x11", \
		"누적 콤보 수를 HUD에 반영해야 한다.")
	_expect(_label_text(hud, "TierLabel") == "Super", \
		"11콤보에서 Super 단계를 표시해야 한다.")
	_expect(int(hit_feedback_count.value) == 11, \
		"유효 타격마다 외부 피드백 신호를 한 번 보내야 한다.")
	_expect(int(tier_feedback_count.value) == 2, \
		"None→Normal과 Normal→Super 단계 변화 피드백을 보내야 한다.")


func _test_suspension(combo: Node, hud: Control) -> void:
	combo.call(&"advance_time", 1.0)
	combo.call(&"suspend_combo_timer")
	_expect(_label_text(hud, "TimerStateLabel") == "PAUSED", \
		"강제 이동 중 타이머 일시정지를 표시해야 한다.")
	_expect_float(_timer(hud).value, 3.0, \
		"강제 이동 시작 시 타이머 게이지를 다시 채워야 한다.")
	combo.call(&"advance_time", 2.0)
	_expect_float(_timer(hud).value, 3.0, \
		"일시정지 중 타이머 게이지가 감소하면 안 된다.")
	combo.call(&"resume_combo_timer")
	_expect(_label_text(hud, "TimerStateLabel") == "3.0s", \
		"강제 이동 종료 뒤 남은 시간을 다시 표시해야 한다.")


func _test_settlement_and_retry(combo: Node, hud: Control) -> void:
	var settlement_count := {&"value": 0}
	hud.settlement_feedback_requested.connect(func(_score: int, _reason: int) -> void:
		settlement_count.value += 1
	)
	_expect(int(combo.call(&"on_ball_drained")) == 5500, \
		"11콤보 낙하는 Super 배율로 정산되어야 한다.")
	_expect(_label_text(hud, "ComboLabel") == "x0", \
		"정산 뒤 콤보 표시를 0으로 초기화해야 한다.")
	_expect(_label_text(hud, "TierLabel") == "None", \
		"정산 뒤 단계 표시를 None으로 초기화해야 한다.")
	_expect(_label_text(hud, "ScoreLabel") == "SCORE 5500", \
		"정산된 누적 점수를 표시해야 한다.")
	_expect(_label_text(hud, "AwardLabel") == "+5500", \
		"마지막 정산 점수를 별도로 표시해야 한다.")
	_expect(int(settlement_count.value) == 1, \
		"정산 피드백 신호는 한 번만 보내야 한다.")
	combo.call(&"on_wave_retried")
	_expect(_label_text(hud, "ScoreLabel") == "SCORE 0", \
		"웨이브 재시도 점수 초기화를 HUD에 반영해야 한다.")
	_expect(_label_text(hud, "AwardLabel") == "", \
		"웨이브 재시도는 이전 정산 표시를 지워야 한다.")


func _test_unbind(combo: Node, hud: Control) -> void:
	hud.call(&"unbind_combo_system")
	combo.call(&"register_hit", 1.0)
	_expect(_label_text(hud, "ComboLabel") == "x0", \
		"연결 해제 뒤 콤보 변경이 HUD에 전달되면 안 된다.")


func _label_text(hud: Control, node_name: String) -> String:
	var label := hud.find_child(node_name, true, false) as Label
	return label.text if label != null else "<missing>"


func _timer(hud: Control) -> ProgressBar:
	return hud.find_child("TimerBar", true, false) as ProgressBar


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
		print("PASS: combo_hud_test")
		quit(0)
		return
	print("FAIL: combo_hud_test (%d failures)" % _failures.size())
	quit(1)
