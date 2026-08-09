@tool
class_name PinballPhysicsRules
extends Resource


## 120Hz 보드에서 실제 검증된 충돌 지름별 절대 속도 상한입니다.
## 개별 Stats와 공용 maximum_speed를 높여도 이 범위를 넘을 수 없습니다.
const COMPACT_COLLISION_DIAMETER := 30.6
const FULL_SPEED_COLLISION_DIAMETER := 57.6
const COMPACT_SAFE_MAXIMUM_SPEED := 3000.0
const FULL_SAFE_MAXIMUM_SPEED := 5000.0


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


## 실제 충돌 지름에 대응하는 최종 안전 속도 상한입니다.
## 소형 기준보다 작으면 충돌 지름에 비례해 더 낮추고, 두 검증 기준 사이는
## 선형 보간합니다. 일반 공 이상은 프로젝트 전체 상한을 사용합니다.
func get_safe_maximum_speed(collision_diameter: float) -> float:
	var safe_diameter := maxf(collision_diameter, 0.0)
	if safe_diameter <= COMPACT_COLLISION_DIAMETER:
		return COMPACT_SAFE_MAXIMUM_SPEED * (
			safe_diameter / COMPACT_COLLISION_DIAMETER
		)
	if safe_diameter >= FULL_SPEED_COLLISION_DIAMETER:
		return FULL_SAFE_MAXIMUM_SPEED
	var diameter_ratio := inverse_lerp(
		COMPACT_COLLISION_DIAMETER,
		FULL_SPEED_COLLISION_DIAMETER,
		safe_diameter
	)
	return lerpf(
		COMPACT_SAFE_MAXIMUM_SPEED,
		FULL_SAFE_MAXIMUM_SPEED,
		diameter_ratio
	)


## x에는 개별 최소 속력, y에는 개별·공용·크기 안전 상한을 모두 적용한
## 최종 속력 범위를 반환합니다.
func get_effective_speed_range(
	stats: PinballStats,
	collision_diameter: float = FULL_SPEED_COLLISION_DIAMETER
) -> Vector2:
	var safety_maximum := minf(
		maximum_speed,
		get_safe_maximum_speed(collision_diameter)
	)
	var effective_common_minimum := minf(minimum_speed, safety_maximum)
	var effective_minimum := clampf(
		stats.minimum_speed,
		effective_common_minimum,
		safety_maximum
	)
	var effective_maximum := clampf(
		stats.maximum_speed,
		effective_common_minimum,
		safety_maximum
	)

	if effective_maximum < effective_minimum:
		effective_maximum = effective_minimum

	return Vector2(effective_minimum, effective_maximum)


func get_effective_initial_speed(
	stats: PinballStats,
	collision_diameter: float = FULL_SPEED_COLLISION_DIAMETER
) -> float:
	if stats.initial_speed <= PinballStats.STOPPED_SPEED_EPSILON:
		return 0.0

	var speed_range := get_effective_speed_range(stats, collision_diameter)
	return clampf(stats.initial_speed, speed_range.x, speed_range.y)


func is_stats_within_rules(
	stats: PinballStats,
	collision_diameter: float = FULL_SPEED_COLLISION_DIAMETER
) -> bool:
	if not is_equal_approx(stats.mass, get_effective_mass(stats)):
		return false

	if not is_equal_approx(stats.elasticity, get_effective_elasticity(stats)):
		return false

	if not is_equal_approx(
		stats.gravity_scale,
		get_effective_gravity_scale(stats)
	):
		return false

	var speed_range := get_effective_speed_range(stats, collision_diameter)
	if not is_equal_approx(stats.minimum_speed, speed_range.x):
		return false

	if not is_equal_approx(stats.maximum_speed, speed_range.y):
		return false

	return is_equal_approx(
		stats.initial_speed,
		get_effective_initial_speed(stats, collision_diameter)
	)
