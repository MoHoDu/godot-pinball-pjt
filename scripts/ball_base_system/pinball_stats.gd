@tool
class_name PinballStats
extends Resource


const MIN_MASS: float = 0.1
const MAX_MASS: float = 100.0
const DEFAULT_MASS: float = 1.0

const MIN_ELASTICITY: float = 0.0
const MAX_ELASTICITY: float = 1.0
const DEFAULT_ELASTICITY: float = 0.8

const MIN_SPEED: float = 0.0
const MAX_SPEED: float = 5000.0
const DEFAULT_INITIAL_SPEED: float = 700.0
const DEFAULT_MINIMUM_SPEED: float = 200.0
const DEFAULT_MAXIMUM_SPEED: float = 2500.0

const MIN_GRAVITY_SCALE: float = 0.0
const MAX_GRAVITY_SCALE: float = 5.0
const DEFAULT_GRAVITY_SCALE: float = 1.0

const STOPPED_SPEED_EPSILON: float = 0.001


var _mass: float = DEFAULT_MASS
var _elasticity: float = DEFAULT_ELASTICITY
var _initial_speed: float = DEFAULT_INITIAL_SPEED
var _minimum_speed: float = DEFAULT_MINIMUM_SPEED
var _maximum_speed: float = DEFAULT_MAXIMUM_SPEED
var _gravity_scale: float = DEFAULT_GRAVITY_SCALE


@export_category("공 기본 물리")

@export_group("물성")

## 공의 질량입니다. 충격량과 힘에 의한 가속도에 영향을 줍니다.
@export_range(0.1, 100.0, 0.1, "suffix:kg")
var mass: float:
	get:
		return _mass
	set(value):
		_mass = clampf(value, MIN_MASS, MAX_MASS)
		emit_changed()

## 공의 기본 탄성입니다. 0은 튀지 않고 1은 완전 탄성에 가깝습니다.
@export_range(0.0, 1.0, 0.01)
var elasticity: float:
	get:
		return _elasticity
	set(value):
		_elasticity = clampf(value, MIN_ELASTICITY, MAX_ELASTICITY)
		emit_changed()

## 프로젝트 기본 2D 중력에 곱하는 공 고유 배율입니다.
## 0은 무중력, 1은 프로젝트 기본 중력, 5는 기본 중력의 5배입니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var gravity_scale: float:
	get:
		return _gravity_scale
	set(value):
		_gravity_scale = clampf(value, MIN_GRAVITY_SCALE, MAX_GRAVITY_SCALE)
		emit_changed()


@export_group("속도")

## launch()로 공을 발사할 때 사용하는 초기 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var initial_speed: float:
	get:
		return _initial_speed
	set(value):
		_initial_speed = clampf(value, MIN_SPEED, _maximum_speed)

		if (
			_initial_speed > STOPPED_SPEED_EPSILON
			and _initial_speed < _minimum_speed
		):
			_initial_speed = _minimum_speed

		emit_changed()

## 움직이는 공이 유지해야 하는 최소 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var minimum_speed: float:
	get:
		return _minimum_speed
	set(value):
		_minimum_speed = clampf(value, MIN_SPEED, MAX_SPEED)

		if _maximum_speed < _minimum_speed:
			_maximum_speed = _minimum_speed

		if (
			_initial_speed > STOPPED_SPEED_EPSILON
			and _initial_speed < _minimum_speed
		):
			_initial_speed = _minimum_speed

		emit_changed()

## 공이 가질 수 있는 최대 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var maximum_speed: float:
	get:
		return _maximum_speed
	set(value):
		_maximum_speed = clampf(value, MIN_SPEED, MAX_SPEED)

		if _maximum_speed < _minimum_speed:
			_maximum_speed = _minimum_speed

		if _initial_speed > _maximum_speed:
			_initial_speed = _maximum_speed

		emit_changed()
