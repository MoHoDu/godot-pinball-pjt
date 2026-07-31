@tool
class_name PinballPhysicsRules
extends Resource


var _minimum_mass: float = PinballStats.MIN_MASS
var _maximum_mass: float = PinballStats.MAX_MASS
var _minimum_elasticity: float = PinballStats.MIN_ELASTICITY
var _maximum_elasticity: float = PinballStats.MAX_ELASTICITY
var _minimum_speed: float = PinballStats.MIN_SPEED
var _maximum_speed: float = PinballStats.MAX_SPEED
var _minimum_gravity_scale: float = PinballStats.MIN_GRAVITY_SCALE
var _maximum_gravity_scale: float = PinballStats.MAX_GRAVITY_SCALE


@export_category("공용 물리 규칙")

@export_group("무게 허용 범위")

@export_range(0.1, 100.0, 0.1, "suffix:kg")
var minimum_mass: float:
	get:
		return _minimum_mass
	set(value):
		_minimum_mass = clampf(value, PinballStats.MIN_MASS, PinballStats.MAX_MASS)

		if _maximum_mass < _minimum_mass:
			_maximum_mass = _minimum_mass

		emit_changed()

@export_range(0.1, 100.0, 0.1, "suffix:kg")
var maximum_mass: float:
	get:
		return _maximum_mass
	set(value):
		_maximum_mass = clampf(value, PinballStats.MIN_MASS, PinballStats.MAX_MASS)

		if _maximum_mass < _minimum_mass:
			_maximum_mass = _minimum_mass

		emit_changed()


@export_group("탄성 허용 범위")

@export_range(0.0, 1.0, 0.01)
var minimum_elasticity: float:
	get:
		return _minimum_elasticity
	set(value):
		_minimum_elasticity = clampf(
			value,
			PinballStats.MIN_ELASTICITY,
			PinballStats.MAX_ELASTICITY
		)

		if _maximum_elasticity < _minimum_elasticity:
			_maximum_elasticity = _minimum_elasticity

		emit_changed()

@export_range(0.0, 1.0, 0.01)
var maximum_elasticity: float:
	get:
		return _maximum_elasticity
	set(value):
		_maximum_elasticity = clampf(
			value,
			PinballStats.MIN_ELASTICITY,
			PinballStats.MAX_ELASTICITY
		)

		if _maximum_elasticity < _minimum_elasticity:
			_maximum_elasticity = _minimum_elasticity

		emit_changed()


@export_group("속력 허용 범위")

## 개별 공의 초기/최소/최대 속력에 공통으로 적용할 최종 허용 범위입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var minimum_speed: float:
	get:
		return _minimum_speed
	set(value):
		_minimum_speed = clampf(value, PinballStats.MIN_SPEED, PinballStats.MAX_SPEED)

		if _maximum_speed < _minimum_speed:
			_maximum_speed = _minimum_speed

		emit_changed()

@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var maximum_speed: float:
	get:
		return _maximum_speed
	set(value):
		_maximum_speed = clampf(value, PinballStats.MIN_SPEED, PinballStats.MAX_SPEED)

		if _maximum_speed < _minimum_speed:
			_maximum_speed = _minimum_speed

		emit_changed()


@export_group("중력 허용 범위")

@export_range(0.0, 5.0, 0.05, "suffix:x")
var minimum_gravity_scale: float:
	get:
		return _minimum_gravity_scale
	set(value):
		_minimum_gravity_scale = clampf(
			value,
			PinballStats.MIN_GRAVITY_SCALE,
			PinballStats.MAX_GRAVITY_SCALE
		)

		if _maximum_gravity_scale < _minimum_gravity_scale:
			_maximum_gravity_scale = _minimum_gravity_scale

		emit_changed()

@export_range(0.0, 5.0, 0.05, "suffix:x")
var maximum_gravity_scale: float:
	get:
		return _maximum_gravity_scale
	set(value):
		_maximum_gravity_scale = clampf(
			value,
			PinballStats.MIN_GRAVITY_SCALE,
			PinballStats.MAX_GRAVITY_SCALE
		)

		if _maximum_gravity_scale < _minimum_gravity_scale:
			_maximum_gravity_scale = _minimum_gravity_scale

		emit_changed()


func get_effective_mass(stats: PinballStats) -> float:
	return clampf(stats.mass, minimum_mass, maximum_mass)


func get_effective_elasticity(stats: PinballStats) -> float:
	return clampf(stats.elasticity, minimum_elasticity, maximum_elasticity)


func get_effective_gravity_scale(stats: PinballStats) -> float:
	return clampf(
		stats.gravity_scale,
		minimum_gravity_scale,
		maximum_gravity_scale
	)


## x에는 개별 최소 속력, y에는 개별 최대 속력의 유효값을 반환합니다.
func get_effective_speed_range(stats: PinballStats) -> Vector2:
	var effective_minimum := clampf(
		stats.minimum_speed,
		minimum_speed,
		maximum_speed
	)
	var effective_maximum := clampf(
		stats.maximum_speed,
		minimum_speed,
		maximum_speed
	)

	if effective_maximum < effective_minimum:
		effective_maximum = effective_minimum

	return Vector2(effective_minimum, effective_maximum)


func get_effective_initial_speed(stats: PinballStats) -> float:
	if stats.initial_speed <= PinballStats.STOPPED_SPEED_EPSILON:
		return 0.0

	var speed_range := get_effective_speed_range(stats)
	return clampf(stats.initial_speed, speed_range.x, speed_range.y)


func is_stats_within_rules(stats: PinballStats) -> bool:
	if not is_equal_approx(stats.mass, get_effective_mass(stats)):
		return false

	if not is_equal_approx(stats.elasticity, get_effective_elasticity(stats)):
		return false

	if not is_equal_approx(
		stats.gravity_scale,
		get_effective_gravity_scale(stats)
	):
		return false

	var speed_range := get_effective_speed_range(stats)
	if not is_equal_approx(stats.minimum_speed, speed_range.x):
		return false

	if not is_equal_approx(stats.maximum_speed, speed_range.y):
		return false

	return is_equal_approx(
		stats.initial_speed,
		get_effective_initial_speed(stats)
	)
