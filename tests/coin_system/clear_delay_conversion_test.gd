extends SceneTree


## 종료 유예 추가 점수 → 코인 환산식(기획서 3-3) 경계값 테스트입니다.
##
##   clear_delay_coin = floor(clear_delay_score / (target_score × 0.05))
##   clear_delay_coin = min(clear_delay_coin, 5)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	# 목표 250000 기준 5% 단위는 12500이다.
	_check(0, 250000, 0, "추가 점수 0은 코인 0이어야 한다.")
	_check(12499, 250000, 0, "단위 바로 아래는 코인 0이어야 한다.")
	_check(12500, 250000, 1, "정확히 5%면 코인 1이어야 한다.")
	_check(24999, 250000, 1, "두 단위 바로 아래는 코인 1이어야 한다.")
	_check(25000, 250000, 2, "정확히 10%면 코인 2여야 한다.")
	_check(62500, 250000, 5, "정확히 25%면 상한과 같은 5여야 한다.")
	_check(62499, 250000, 4, "상한 바로 아래 값이 정확해야 한다.")
	_check(999999, 250000, 5, "상한을 넘으면 5로 잘려야 한다.")

	# 웨이브별 목표 차이가 자동 보정되는지 다른 목표로도 확인한다.
	_check(20000, 400000, 1, "목표 400000의 5%는 20000이어야 한다.")
	_check(19999, 400000, 0, "목표 400000에서 단위 미만은 0이어야 한다.")

	# 방어 조건.
	_check(-100, 250000, 0, "음수 추가 점수는 0이어야 한다.")
	_check(10000, 0, 0, "목표 0이면 환산하지 않아야 한다.")
	_expect(
		WaveClearDelayController.convert_delay_score(99999, 250000, 0.05, 0) == 0,
		"상한 0이면 코인 0이어야 한다."
	)
	_expect(
		WaveClearDelayController.convert_delay_score(12500, 250000, 0.0, 5) == 0,
		"비율 0이면 환산하지 않아야 한다."
	)
	_expect(
		WaveClearDelayController.convert_delay_score(25000, 250000, 0.10, 5) == 1,
		"비율을 바꾸면 단위도 따라 바뀌어야 한다."
	)

	_finish()


func _check(delay_score: int, target: int, expected: int, message: String) -> void:
	var actual := WaveClearDelayController.convert_delay_score(delay_score, target)
	_expect(actual == expected, "%s (기대 %d, 실제 %d)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: clear_delay_conversion_test")
		quit(0)
		return
	print("FAIL: clear_delay_conversion_test (%d failures)" % _failures.size())
	quit(1)
