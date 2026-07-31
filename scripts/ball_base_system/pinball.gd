@tool
class_name Pinball
extends RigidBody2D


# 크기 상수 정의
const MIN_BALL_DIAMETER: float = 16.0		# 최소 공 지름
const MAX_BALL_DIAMETER: float = 256.0		# 최대 공 지름
const DEFAULT_BALL_DIAMETER: float = 64.0	# 기본 공 지름

# 극도로 작은 원본 크기로 나누는 것을 막기 위한 안전값
const MIN_SOURCE_SIZE: float = 0.001


# 공 기본 물리 상수 정의
const MIN_BALL_MASS: float = 0.1
const MAX_BALL_MASS: float = 100.0
const DEFAULT_BALL_MASS: float = 1.0

const MIN_BALL_ELASTICITY: float = 0.0
const MAX_BALL_ELASTICITY: float = 1.0
const DEFAULT_BALL_ELASTICITY: float = 0.8

const MIN_BALL_SPEED: float = 0.0
const MAX_BALL_SPEED: float = 5000.0
const DEFAULT_INITIAL_SPEED: float = 700.0
const DEFAULT_MINIMUM_SPEED: float = 200.0
const DEFAULT_MAXIMUM_SPEED: float = 2500.0

const MIN_BALL_GRAVITY_SCALE: float = 0.0
const MAX_BALL_GRAVITY_SCALE: float = 5.0
const DEFAULT_BALL_GRAVITY_SCALE: float = 1.0

const STOPPED_SPEED_EPSILON: float = 0.001


var _normalizing_speed_settings: bool = false
var _minimum_speed_suppressed_by_gravity: bool = false


@export_category("공 크기")

## 게임에서 사용하는 공의 지름입니다.
## 시각 이미지의 원본 해상도와 관계없이 표시 및 충돌 크기에 적용됩니다.
@export_range(16.0, 256.0, 1.0, "suffix:px")
var ball_diameter: float = DEFAULT_BALL_DIAMETER:
	set(value):
		ball_diameter = clampf(value, MIN_BALL_DIAMETER, MAX_BALL_DIAMETER)
		refresh_ball_size()


@export_category("공 기본 물리")

@export_group("물성")

## 공의 질량입니다. 충격량과 힘에 의한 가속도에 영향을 줍니다.
@export_range(0.1, 100.0, 0.1, "suffix:kg")
var ball_mass: float = DEFAULT_BALL_MASS:
	set(value):
		ball_mass = clampf(value, MIN_BALL_MASS, MAX_BALL_MASS)
		mass = ball_mass

## 공의 기본 탄성입니다. 0은 튀지 않고 1은 완전 탄성에 가깝습니다.
@export_range(0.0, 1.0, 0.01)
var ball_elasticity: float = DEFAULT_BALL_ELASTICITY:
	set(value):
		ball_elasticity = clampf(
			value,
			MIN_BALL_ELASTICITY,
			MAX_BALL_ELASTICITY
		)
		_apply_ball_elasticity()

## 프로젝트 기본 2D 중력에 곱하는 공 고유 배율입니다.
## 0은 무중력, 1은 프로젝트 기본 중력, 5는 기본 중력의 5배입니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var ball_gravity_scale: float = DEFAULT_BALL_GRAVITY_SCALE:
	set(value):
		ball_gravity_scale = clampf(
			value,
			MIN_BALL_GRAVITY_SCALE,
			MAX_BALL_GRAVITY_SCALE
		)
		gravity_scale = ball_gravity_scale


@export_group("속도")

## launch()로 공을 발사할 때 사용하는 초기 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var initial_speed: float = DEFAULT_INITIAL_SPEED:
	set(value):
		initial_speed = clampf(value, MIN_BALL_SPEED, maximum_speed)

		if initial_speed > STOPPED_SPEED_EPSILON and initial_speed < minimum_speed:
			initial_speed = minimum_speed

## 움직이는 공이 유지해야 하는 최소 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var minimum_speed: float = DEFAULT_MINIMUM_SPEED:
	set(value):
		minimum_speed = clampf(value, MIN_BALL_SPEED, MAX_BALL_SPEED)

		if _normalizing_speed_settings:
			return

		_normalizing_speed_settings = true

		if maximum_speed < minimum_speed:
			maximum_speed = minimum_speed

		if initial_speed > STOPPED_SPEED_EPSILON and initial_speed < minimum_speed:
			initial_speed = minimum_speed

		_normalizing_speed_settings = false

## 공이 가질 수 있는 최대 속력입니다.
@export_range(0.0, 5000.0, 10.0, "suffix:px/s")
var maximum_speed: float = DEFAULT_MAXIMUM_SPEED:
	set(value):
		maximum_speed = clampf(value, MIN_BALL_SPEED, MAX_BALL_SPEED)

		if _normalizing_speed_settings:
			return

		_normalizing_speed_settings = true

		if maximum_speed < minimum_speed:
			maximum_speed = minimum_speed

		if initial_speed > maximum_speed:
			initial_speed = maximum_speed

		_normalizing_speed_settings = false


func _ready() -> void:
	contact_monitor = true		# 물리 접촉 정보를 수집하도록 활성화. 향후 범퍼/플리퍼 충돌 처리에 필요
	max_contacts_reported = 8	# 한 물리 프레임에 최대 8개의 접촉점 기록
	refresh_ball_size()
	refresh_physics_properties()


## 현재 공 지름을 시각 이미지와 원형 충돌 범위에 즉시 반영합니다.
## 필수 노드나 리소스가 빠져 있어도 오류 없이 적용 가능한 항목만 갱신합니다.
func refresh_ball_size() -> void:
	var sprite := get_node_or_null("Visual/Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		var source_diameter := maxf(absf(texture_size.x), absf(texture_size.y))

		if source_diameter > MIN_SOURCE_SIZE:
			var visual_scale := ball_diameter / source_diameter
			sprite.scale = Vector2.ONE * visual_scale

	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		var source_diameter := circle.radius * 2.0

		if source_diameter > MIN_SOURCE_SIZE:
			var collision_scale := ball_diameter / source_diameter
			collision.scale = Vector2.ONE * collision_scale

	if is_inside_tree():
		update_configuration_warnings()


# 에디터 속성 값 설정 시 에러 표시
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var visual := get_node_or_null("Visual")
	var sprite := get_node_or_null("Visual/Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D

	if visual == null:
		warnings.append("Visual Node2D 자식 노드가 필요합니다.")
	elif sprite == null:
		warnings.append("Visual/Sprite2D 자식 노드가 필요합니다.")
	elif sprite.texture == null:
		warnings.append("Visual/Sprite2D에 Texture2D를 지정해야 합니다.")

	if collision == null:
		warnings.append("CollisionShape2D 자식 노드가 필요합니다.")
	elif not collision.shape is CircleShape2D:
		warnings.append("CollisionShape2D에는 CircleShape2D를 지정해야 합니다.")

	if not scale.is_equal_approx(Vector2.ONE):
		warnings.append("PinballBall 루트의 Scale은 (1, 1)로 유지하고 Ball Diameter를 사용하세요.")

	return warnings


## 에디터에 설정된 공 물성을 RigidBody2D와 PhysicsMaterial에 반영합니다.
func refresh_physics_properties() -> void:
	mass = ball_mass
	gravity_scale = ball_gravity_scale
	_apply_ball_elasticity()


## 입력 방향을 정규화하고 설정된 초기 속력으로 공을 발사합니다.
## 방향이 Vector2.ZERO이면 기존 속도를 보존하고 false를 반환합니다.
func launch(direction: Vector2) -> bool:
	if direction.is_zero_approx():
		return false

	_minimum_speed_suppressed_by_gravity = false
	sleeping = false
	linear_velocity = get_limited_velocity(
		direction.normalized() * initial_speed
	)
	return true


## 방향은 유지하면서 정지, 최소 속력, 최대 속력 규칙을 적용한 속도를 반환합니다.
func get_limited_velocity(velocity: Vector2) -> Vector2:
	var speed := velocity.length()

	if speed <= STOPPED_SPEED_EPSILON:
		return Vector2.ZERO

	var limited_speed := clampf(speed, minimum_speed, maximum_speed)
	return velocity.normalized() * limited_speed


## 중력을 거슬러 상승하는 동안에는 최소 속력 보정을 억제합니다.
## 공이 정점을 지나 중력으로 최소 속력을 회복하면 일반 제한으로 복귀합니다.
func _get_physics_limited_velocity(
	velocity: Vector2,
	gravity: Vector2
) -> Vector2:
	var speed := velocity.length()

	if gravity.is_zero_approx():
		_minimum_speed_suppressed_by_gravity = false
		return get_limited_velocity(velocity)

	if velocity.dot(gravity) < 0.0:
		_minimum_speed_suppressed_by_gravity = true

	if _minimum_speed_suppressed_by_gravity:
		var recovered_minimum_speed := (
			velocity.dot(gravity) >= 0.0
			and speed >= minimum_speed
		)

		if recovered_minimum_speed:
			_minimum_speed_suppressed_by_gravity = false
		else:
			return _get_maximum_limited_velocity(velocity)

	return get_limited_velocity(velocity)


func _get_maximum_limited_velocity(velocity: Vector2) -> Vector2:
	var speed := velocity.length()

	if speed <= STOPPED_SPEED_EPSILON:
		return Vector2.ZERO

	if speed <= maximum_speed:
		return velocity

	return velocity.normalized() * maximum_speed


func _apply_ball_elasticity() -> void:
	var physics_material := _get_instance_physics_material()
	physics_material.bounce = ball_elasticity


func _get_instance_physics_material() -> PhysicsMaterial:
	var physics_material := physics_material_override

	if physics_material == null:
		physics_material = PhysicsMaterial.new()
		physics_material.resource_local_to_scene = true
		physics_material_override = physics_material
	elif not physics_material.resource_local_to_scene:
		physics_material = physics_material.duplicate() as PhysicsMaterial
		physics_material.resource_local_to_scene = true
		physics_material_override = physics_material

	return physics_material


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var best_result: BallImpactResult = null
	var best_context: BallImpactContext = null
	var visited_colliders: Dictionary = {}

	for contact_index: int in state.get_contact_count():
		var collider := state.get_contact_collider_object(contact_index)

		if not collider is Node:
			continue

		var collider_id := collider.get_instance_id()

		# 같은 충돌체에서 접촉점이 여러 개 검출되는 경우 방지
		if visited_colliders.has(collider_id):
			continue

		visited_colliders[collider_id] = true

		if not collider.has_method(&"get_ball_impact"):
			continue

		var context := BallImpactContext.new(
			self,
			state.linear_velocity,
			state.get_contact_collider_velocity_at_position(contact_index),
			state.get_contact_local_normal(contact_index),
			state.get_contact_local_position(contact_index)
		)

		var result: Variant = collider.call(&"get_ball_impact", context)

		if result is BallImpactResult:
			if best_result == null or result.priority > best_result.priority:
				best_result = result
				best_context = context

	if best_result != null:
		_apply_impact(state, best_context, best_result)

	state.linear_velocity = _get_physics_limited_velocity(
		state.linear_velocity,
		state.total_gravity
	)


func _apply_impact(
    state: PhysicsDirectBodyState2D,
    context: BallImpactContext,
    result: BallImpactResult
) -> void:
	var relative_velocity := (
		context.velocity
		- context.collider_velocity
	)

	var direction: Vector2

	match result.direction_mode:
		BallImpactResult.DirectionMode.PHYSICAL_REFLECTION:
			direction = relative_velocity.bounce(context.normal).normalized()

		BallImpactResult.DirectionMode.FIXED_WORLD:
			direction = result.direction.normalized()

		BallImpactResult.DirectionMode.FIXED_LOCAL:
			var collider := context.ball # 실제로는 context에 collider도 보관 권장
			direction = result.direction.normalized()

		BallImpactResult.DirectionMode.KEEP_CURRENT:
			direction = relative_velocity.normalized()

	var speed := (
		relative_velocity.length()
		* result.speed_multiplier
		+ result.speed_addition
	)

	speed = clampf(
		speed,
		result.minimum_speed,
		result.maximum_speed
	)

	state.linear_velocity = (
		context.collider_velocity
		+ direction * speed
	)
