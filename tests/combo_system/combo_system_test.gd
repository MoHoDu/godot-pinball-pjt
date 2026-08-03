extends SceneTree


const COMBO_SYSTEM_SCRIPT_PATH := "res://scripts/combo_system/combo_system.gd"
const EPSILON := 0.001

const TIER_NORMAL := 1
const TIER_SUPER := 2
const END_REASON_TIMEOUT := 0
const END_REASON_BALL_DRAINED := 1


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var combo_system_script := load(COMBO_SYSTEM_SCRIPT_PATH) as Script
	_expect(combo_system_script != null, "콤보 상태 관리 스크립트가 필요하다.")
	if combo_system_script == null:
		_finish()
		return

	var combo_system := combo_system_script.new() as Node
	root.add_child(combo_system)
	await process_frame

	_test_hit_accumulation(combo_system)
	_test_zero_combo_state(combo_system)
	_test_timer_timeout(combo_system)
	_test_timer_suspension(combo_system)
	_test_lifecycle_and_score_signals(combo_system)
	_test_boss_hit_integration(combo_system)

	combo_system.queue_free()
	await process_frame
	_finish()


func _test_hit_accumulation(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	for hit_index in 10:
		combo_system.call(&"register_hit")

	_expect(int(combo_system.get(&"combo_count")) == 10, \
		"유효 충돌마다 콤보가 정확히 1씩 증가해야 한다.")
	_expect(int(combo_system.get(&"current_tier")) == TIER_NORMAL, \
		"10콤보까지 Normal 단계여야 한다.")
	_expect_float(float(combo_system.get(&"total_score_weight")), 10.0, \
		"기본 유효 타격은 점수 가중치 1을 적립해야 한다.")
	combo_system.call(&"register_hit", 2.5)
	_expect(int(combo_system.get(&"current_tier")) == TIER_SUPER, \
		"11번째 충돌에서 Super 단계로 전환되어야 한다.")
	_expect_float(float(combo_system.get(&"total_score_weight")), 12.5, \
		"오브젝트별 상대 점수 가중치를 합산해야 한다.")
	_expect_float(float(combo_system.get(&"time_remaining")), 3.0, \
		"각 유효 충돌은 유지 시간을 3초로 갱신해야 한다.")
	_expect(int(combo_system.call(&"finish_combo")) == 6250, \
		"종료 점수는 스테이지 기준 점수·가중치 합·Super 배율을 적용해야 한다.")


func _test_zero_combo_state(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	_expect(not combo_system.is_processing(), \
		"0콤보에서는 타이머 프로세스를 실행하면 안 된다.")
	combo_system.call(&"advance_time", 10.0)
	_expect_float(float(combo_system.get(&"time_remaining")), 0.0, \
		"0콤보에서는 시간이 지나도 타이머가 0이어야 한다.")
	_expect(int(combo_system.call(&"on_ball_drained")) == 0, \
		"0콤보 공 낙하는 점수를 획득하면 안 된다.")


func _test_timer_timeout(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	var finished := {}
	combo_system.combo_finished.connect(func(
		count: int,
		tier: int,
		score: int,
		reason: int
	) -> void:
		finished[&"count"] = count
		finished[&"tier"] = tier
		finished[&"score"] = score
		finished[&"reason"] = reason
	, CONNECT_ONE_SHOT)

	combo_system.call(&"register_hit")
	combo_system.call(&"advance_time", 2.9)
	_expect(int(combo_system.get(&"combo_count")) == 1, \
		"유지 시간이 남아 있으면 콤보를 유지해야 한다.")
	combo_system.call(&"advance_time", 0.1)
	_expect(int(combo_system.get(&"combo_count")) == 0, \
		"3초가 지나면 콤보를 종료하고 초기화해야 한다.")
	_expect(int(finished.get(&"reason", -1)) == END_REASON_TIMEOUT, \
		"시간 초과 종료 이유를 외부 시스템에 전달해야 한다.")
	_expect(int(finished.get(&"score", 0)) == 100, \
		"시간 초과로 종료된 콤보도 즉시 점수를 정산해야 한다.")


func _test_timer_suspension(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	combo_system.call(&"register_hit")
	combo_system.call(&"advance_time", 2.0)
	combo_system.call(&"suspend_combo_timer")
	_expect_float(float(combo_system.get(&"time_remaining")), 3.0, \
		"이동 연출 시작 시 유지 시간을 초기값으로 되돌려야 한다.")
	_expect(bool(combo_system.get(&"is_timer_suspended")), \
		"이동 연출 중 콤보 타이머가 멈춰야 한다.")
	combo_system.call(&"advance_time", 10.0)
	_expect_float(float(combo_system.get(&"time_remaining")), 3.0, \
		"일시정지 중에는 시간이 지나도 유지 시간을 차감하면 안 된다.")

	combo_system.call(&"suspend_combo_timer")
	combo_system.call(&"resume_combo_timer")
	_expect(bool(combo_system.get(&"is_timer_suspended")), \
		"중첩된 연출이 하나 남으면 타이머를 계속 멈춰야 한다.")
	combo_system.call(&"resume_combo_timer")
	combo_system.call(&"advance_time", 1.0)
	_expect_float(float(combo_system.get(&"time_remaining")), 2.0, \
		"마지막 연출이 끝나면 초기화된 유지 시간부터 다시 진행해야 한다.")


func _test_lifecycle_and_score_signals(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	var latest_score := {}
	var score_signal_count := {&"value": 0}
	combo_system.score_changed.connect(func(total: int, added: int) -> void:
		latest_score[&"total"] = total
		latest_score[&"added"] = added
		score_signal_count[&"value"] = int(score_signal_count[&"value"]) + 1
	)

	for hit_index in 11:
		combo_system.call(&"register_hit")
	var drain_score := int(combo_system.call(&"on_ball_drained"))
	_expect(drain_score == 5500, \
		"공 낙하 시 11콤보 Super 점수를 정산해야 한다.")
	_expect(int(latest_score.get(&"total", 0)) == 5500, \
		"점수 신호는 정산 후 누적 점수를 전달해야 한다.")

	combo_system.call(&"register_hit")
	combo_system.call(&"register_hit")
	var launch_score := int(combo_system.call(&"on_ball_launched"))
	_expect(launch_score == 0, \
		"새 공 발사는 남은 콤보를 다시 정산하면 안 된다.")
	_expect(int(combo_system.get(&"combo_count")) == 0, \
		"새 공은 콤보 0에서 시작해야 한다.")
	_expect(int(combo_system.get(&"total_score")) == 5500, \
		"새 공 발사는 이미 정산된 누적 점수를 바꾸면 안 된다.")
	_expect(int(score_signal_count[&"value"]) == 1, \
		"낙하와 새 발사 수명주기에서 점수 정산은 한 번만 발생해야 한다.")
	_expect(int(combo_system.call(&"on_ball_drained")) == 0, \
		"0콤보 낙하는 추가 정산을 발생시키면 안 된다.")
	_expect(int(score_signal_count[&"value"]) == 1, \
		"0콤보 낙하는 점수 신호를 발생시키면 안 된다.")

	combo_system.call(&"on_wave_retried")
	_expect(int(combo_system.get(&"total_score")) == 0, \
		"웨이브 재시도는 누적 웨이브 스코어를 0으로 지워야 한다.")


func _test_boss_hit_integration(combo_system: Node) -> void:
	combo_system.call(&"reset_run")
	var damage := 0
	for hit_index in 10:
		damage = int(combo_system.call(&"register_boss_hit", 100.0))
	_expect(damage == 123, \
		"10번째 보스 타격은 증가된 10콤보 피해를 계산해야 한다.")
	_expect_float(float(combo_system.get(&"total_score_weight")), 0.0, \
		"보스 타격은 일반 웨이브용 점수 가중치를 추가하면 안 된다.")

	damage = int(combo_system.call(&"register_boss_hit", 100.0))
	_expect(int(combo_system.get(&"combo_count")) == 11, \
		"보스 유효 타격도 콤보를 증가시켜야 한다.")
	_expect(damage == 156, \
		"11번째 보스 타격은 Super 단계 진입 후 피해를 계산해야 한다.")
	_expect(int(combo_system.call(&"on_ball_drained")) == 0, \
		"보스 타격만 포함된 콤보는 일반 웨이브 점수를 정산하면 안 된다.")
	_expect(int(combo_system.get(&"total_score")) == 0, \
		"보스 피해와 일반 웨이브 스코어는 분리되어야 한다.")
	_expect(not combo_system.has_method(&"watch_flipper"), \
		"플리퍼 접촉을 자동으로 콤보에 연결하는 API를 제공하면 안 된다.")


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
		print("PASS: combo_system_test")
		quit(0)
		return
	print("FAIL: combo_system_test (%d failures)" % _failures.size())
	quit(1)
