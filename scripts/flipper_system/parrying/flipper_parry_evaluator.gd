class_name FlipperParryEvaluator
extends RefCounted


## 작동 입력부터 실제 충돌까지 걸린 시간으로 패링 등급을 구분합니다.
## 숫자 순서는 피드백 강도 비교에도 사용할 수 있도록 NONE < NORMAL < PERFECT입니다.
enum Grade {
	NONE,
	NORMAL,
	PERFECT,
}


## 정확 판정 구간을 먼저 확인하고, 그 이후 일반 판정 구간을 확인합니다.
## 경계 시각의 충돌은 플레이어에게 유리하도록 해당 판정에 포함합니다.
func evaluate(elapsed_time: float, rules: Resource) -> Grade:
	if rules == null or elapsed_time < 0.0:
		return Grade.NONE

	var perfect_window := maxf(
		float(rules.get(&"perfect_parry_window_time")),
		0.0
	)
	var normal_window := maxf(
		float(rules.get(&"normal_parry_window_time")),
		perfect_window
	)

	if elapsed_time <= perfect_window:
		return Grade.PERFECT
	if elapsed_time <= normal_window:
		return Grade.NORMAL
	return Grade.NONE


## 판정 등급에 해당하는 공용 속도 배율을 반환합니다.
func get_speed_multiplier(grade: Grade, rules: Resource) -> float:
	if rules == null:
		return 1.0

	match grade:
		Grade.NORMAL:
			return maxf(
				float(rules.get(&"normal_parry_speed_multiplier")),
				0.0
			)
		Grade.PERFECT:
			return maxf(
				float(rules.get(&"perfect_parry_speed_multiplier")),
				0.0
			)
		_:
			return 1.0


## 이미 계산된 물리 반사 방향은 유지하고 속력에만 패링 배율을 적용합니다.
func apply_speed_multiplier(
	reflected_velocity: Vector2,
	grade: Grade,
	rules: Resource
) -> Vector2:
	return reflected_velocity * get_speed_multiplier(grade, rules)


func get_grade_label(grade: Grade) -> String:
	match grade:
		Grade.NORMAL:
			return "PARRY!"
		Grade.PERFECT:
			return "PERFECT!"
		_:
			return ""
