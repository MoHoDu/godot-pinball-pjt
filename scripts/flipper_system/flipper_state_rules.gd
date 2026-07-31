@tool
class_name FlipperStateRules
extends Resource


var _return_reflection_multiplier: float = 0.5
var _normal_parry_reflection_multiplier: float = 1.25
var _perfect_parry_reflection_multiplier: float = 2.0
var _activation_time: float = 0.07
var _hold_time: float = 0.04
var _return_time: float = 0.12


@export_category("플리퍼 공용 상태 설정")

@export_group("반사 배율")

## 복귀 중 공을 빗맞혔을 때 물리 반사 속도에 곱하는 배율입니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var return_reflection_multiplier: float:
	get:
		return _return_reflection_multiplier
	set(value):
		_return_reflection_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

## 일반 패링 반사 배율입니다. 패링 판정 규칙이 정해질 때까지 값만 보관합니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var normal_parry_reflection_multiplier: float:
	get:
		return _normal_parry_reflection_multiplier
	set(value):
		_normal_parry_reflection_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

## 정확한 패링 반사 배율입니다. 정확 판정 규칙이 정해질 때까지 값만 보관합니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var perfect_parry_reflection_multiplier: float:
	get:
		return _perfect_parry_reflection_multiplier
	set(value):
		_perfect_parry_reflection_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()


@export_group("상태 시간")

## 초기 각도에서 최대 각도까지 회전하는 시간입니다.
@export_range(0.01, 2.0, 0.01, "suffix:s")
var activation_time: float:
	get:
		return _activation_time
	set(value):
		_activation_time = clampf(value, 0.01, 2.0)
		emit_changed()

## 최대 각도에 도달한 뒤 유지하는 시간입니다.
@export_range(0.0, 2.0, 0.01, "suffix:s")
var hold_time: float:
	get:
		return _hold_time
	set(value):
		_hold_time = clampf(value, 0.0, 2.0)
		emit_changed()

## 최대 각도에서 초기 각도로 돌아오는 시간입니다.
@export_range(0.01, 2.0, 0.01, "suffix:s")
var return_time: float:
	get:
		return _return_time
	set(value):
		_return_time = clampf(value, 0.01, 2.0)
		emit_changed()
