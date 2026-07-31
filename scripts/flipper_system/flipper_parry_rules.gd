@tool
class_name FlipperParryRules
extends Resource


var _show_contact_zones_in_editor: bool = true
var _zone_a_end_percent: float = 35.0
var _zone_b_end_percent: float = 70.0
var _zone_c_end_percent: float = 90.0
var _zone_a_speed_multiplier: float = 0.94
var _zone_b_speed_multiplier: float = 1.0
var _zone_c_speed_multiplier: float = 1.08
var _zone_d_speed_multiplier: float = 0.84
var _zone_a_angle_correction_enabled: bool = false
var _zone_b_angle_correction_enabled: bool = false
var _zone_c_angle_correction_enabled: bool = false
var _zone_d_angle_correction_enabled: bool = false
var _zone_a_angle_correction_degrees: float = 0.0
var _zone_b_angle_correction_degrees: float = 0.0
var _zone_c_angle_correction_degrees: float = 0.0
var _zone_d_angle_correction_degrees: float = 0.0
var _left_angle_direction_sign: float = -1.0
var _right_angle_direction_sign: float = 1.0
var _normal_parry_window_time: float = 0.08
var _perfect_parry_window_time: float = 0.03
var _normal_parry_speed_multiplier: float = 1.25
var _perfect_parry_speed_multiplier: float = 2.0


@export_category("플리퍼 공용 패링 설정")

@export_group("접촉 구역")

## 에디터에서 각 플리퍼 위에 A/B/C/D 구역 범위 막대를 표시합니다.
@export var show_contact_zones_in_editor: bool:
	get:
		return _show_contact_zones_in_editor
	set(value):
		_show_contact_zones_in_editor = value
		emit_changed()

## A는 0%부터 이 값 미만까지입니다.
@export_range(0.0, 100.0, 0.1, "suffix:%")
var zone_a_end_percent: float:
	get:
		return _zone_a_end_percent
	set(value):
		_zone_a_end_percent = clampf(value, 0.0, _zone_b_end_percent)
		emit_changed()

## B는 A의 끝부터 이 값 미만까지입니다.
@export_range(0.0, 100.0, 0.1, "suffix:%")
var zone_b_end_percent: float:
	get:
		return _zone_b_end_percent
	set(value):
		_zone_b_end_percent = clampf(
			value,
			_zone_a_end_percent,
			_zone_c_end_percent
		)
		emit_changed()

## C는 B의 끝부터 이 값 미만까지이며, D는 이 값부터 100%까지입니다.
@export_range(0.0, 100.0, 0.1, "suffix:%")
var zone_c_end_percent: float:
	get:
		return _zone_c_end_percent
	set(value):
		_zone_c_end_percent = clampf(value, _zone_b_end_percent, 100.0)
		emit_changed()


@export_group("공용 구역 속도 배율")

@export_range(0.0, 5.0, 0.01, "suffix:x")
var zone_a_speed_multiplier: float:
	get:
		return _zone_a_speed_multiplier
	set(value):
		_zone_a_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

@export_range(0.0, 5.0, 0.01, "suffix:x")
var zone_b_speed_multiplier: float:
	get:
		return _zone_b_speed_multiplier
	set(value):
		_zone_b_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

@export_range(0.0, 5.0, 0.01, "suffix:x")
var zone_c_speed_multiplier: float:
	get:
		return _zone_c_speed_multiplier
	set(value):
		_zone_c_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

@export_range(0.0, 5.0, 0.01, "suffix:x")
var zone_d_speed_multiplier: float:
	get:
		return _zone_d_speed_multiplier
	set(value):
		_zone_d_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()


@export_group("구역 각도 보정")

## 다음 TDD 단계에서 A 구역 반사 각도 계산의 적용 여부로 사용합니다.
@export var zone_a_angle_correction_enabled: bool:
	get:
		return _zone_a_angle_correction_enabled
	set(value):
		_zone_a_angle_correction_enabled = value
		emit_changed()

## 다음 TDD 단계에서 B 구역 반사 각도 계산의 적용 여부로 사용합니다.
@export var zone_b_angle_correction_enabled: bool:
	get:
		return _zone_b_angle_correction_enabled
	set(value):
		_zone_b_angle_correction_enabled = value
		emit_changed()

## 다음 TDD 단계에서 C 구역 반사 각도 계산의 적용 여부로 사용합니다.
@export var zone_c_angle_correction_enabled: bool:
	get:
		return _zone_c_angle_correction_enabled
	set(value):
		_zone_c_angle_correction_enabled = value
		emit_changed()

## 다음 TDD 단계에서 D 구역 반사 각도 계산의 적용 여부로 사용합니다.
@export var zone_d_angle_correction_enabled: bool:
	get:
		return _zone_d_angle_correction_enabled
	set(value):
		_zone_d_angle_correction_enabled = value
		emit_changed()

@export_range(-180.0, 180.0, 0.1, "suffix:°")
var zone_a_angle_correction_degrees: float:
	get:
		return _zone_a_angle_correction_degrees
	set(value):
		_zone_a_angle_correction_degrees = clampf(value, -180.0, 180.0)
		emit_changed()

@export_range(-180.0, 180.0, 0.1, "suffix:°")
var zone_b_angle_correction_degrees: float:
	get:
		return _zone_b_angle_correction_degrees
	set(value):
		_zone_b_angle_correction_degrees = clampf(value, -180.0, 180.0)
		emit_changed()

@export_range(-180.0, 180.0, 0.1, "suffix:°")
var zone_c_angle_correction_degrees: float:
	get:
		return _zone_c_angle_correction_degrees
	set(value):
		_zone_c_angle_correction_degrees = clampf(value, -180.0, 180.0)
		emit_changed()

@export_range(-180.0, 180.0, 0.1, "suffix:°")
var zone_d_angle_correction_degrees: float:
	get:
		return _zone_d_angle_correction_degrees
	set(value):
		_zone_d_angle_correction_degrees = clampf(value, -180.0, 180.0)
		emit_changed()

## 왼쪽 플리퍼의 각도 보정 방향입니다. -1 또는 1로 정규화됩니다.
@export_range(-1.0, 1.0, 2.0)
var left_angle_direction_sign: float:
	get:
		return _left_angle_direction_sign
	set(value):
		_left_angle_direction_sign = -1.0 if value < 0.0 else 1.0
		emit_changed()

## 오른쪽 플리퍼의 각도 보정 방향입니다. -1 또는 1로 정규화됩니다.
@export_range(-1.0, 1.0, 2.0)
var right_angle_direction_sign: float:
	get:
		return _right_angle_direction_sign
	set(value):
		_right_angle_direction_sign = -1.0 if value < 0.0 else 1.0
		emit_changed()


@export_group("패링 타이밍")

## 작동 상태 진입 후 일반 패링으로 인정할 최대 시간입니다.
@export_range(0.0, 2.0, 0.001, "suffix:s")
var normal_parry_window_time: float:
	get:
		return _normal_parry_window_time
	set(value):
		_normal_parry_window_time = clampf(value, 0.0, 2.0)
		_perfect_parry_window_time = minf(
			_perfect_parry_window_time,
			_normal_parry_window_time
		)
		emit_changed()

## 일반 패링 구간 안에서 정확 패링으로 인정할 최대 시간입니다.
@export_range(0.0, 2.0, 0.001, "suffix:s")
var perfect_parry_window_time: float:
	get:
		return _perfect_parry_window_time
	set(value):
		_perfect_parry_window_time = clampf(
			value,
			0.0,
			_normal_parry_window_time
		)
		emit_changed()


@export_group("패링 속도 배율")

@export_range(0.0, 5.0, 0.01, "suffix:x")
var normal_parry_speed_multiplier: float:
	get:
		return _normal_parry_speed_multiplier
	set(value):
		_normal_parry_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()

@export_range(0.0, 5.0, 0.01, "suffix:x")
var perfect_parry_speed_multiplier: float:
	get:
		return _perfect_parry_speed_multiplier
	set(value):
		_perfect_parry_speed_multiplier = clampf(value, 0.0, 5.0)
		emit_changed()
