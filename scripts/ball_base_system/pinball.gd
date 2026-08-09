@tool
class_name Pinball
extends RigidBody2D


const DEFAULT_PHYSICS_RULES: PinballPhysicsRules = preload(
	"res://settings/balls/PinballPhysicsRules.tres"
)

# 크기 상수 정의
const MIN_BALL_DIAMETER: float = 16.0		# 최소 공 지름
const MAX_BALL_DIAMETER: float = 256.0		# 최대 공 지름
const DEFAULT_BALL_DIAMETER: float = 64.0	# 기본 공 지름

# 극도로 작은 원본 크기로 나누는 것을 막기 위한 안전값
const MIN_SOURCE_SIZE: float = 0.001

const STOPPED_SPEED_EPSILON: float = 0.001

const MIN_COLLISION_RADIUS_RATIO: float = 0.25
const MAX_COLLISION_RADIUS_RATIO: float = 1.5
const DEFAULT_COLLISION_RADIUS_RATIO: float = 1.0
const PINBALL_GROUP: StringName = &"pinball_balls"
const DEFAULT_COLLISION_LIMIT_SETTLING_FRAMES := 2

var _minimum_speed_suppressed_by_gravity: bool = false
var _temporary_maximum_speed := INF
var _temporary_speed_limit_until_physics_frame := -1
var _temporary_speed_limit_enforcement_queued := false
var _stats_safety_clamp_in_progress := false
var _stats: PinballStats = PinballStats.new()
var _physics_rules: PinballPhysicsRules = DEFAULT_PHYSICS_RULES

## 모든 공이 기본으로 공유하는 허용 범위 규칙입니다.
## 개별 Stats의 원본은 보존하고 실제 물리에 적용할 때 이 범위로 보정합니다.
var physics_rules: PinballPhysicsRules:
	get:
		return _physics_rules
	set(value):
		_set_physics_rules(value)


@export_category("공 바리에이션")

## 공 개별 물성 및 속도 설정입니다.
## 씬에 내장하거나 .tres 프리셋을 지정해 공 종류별 설정을 저장할 수 있습니다.
@export var stats: PinballStats:
	get:
		return _stats
	set(value):
		_set_stats(value)


@export_category("공 외형 및 충돌")

@export_group("공 크기")

## 게임에서 사용하는 공의 지름입니다.
## 시각 이미지의 원본 해상도와 관계없이 표시 크기에 적용됩니다.
@export_range(16.0, 256.0, 1.0, "suffix:px")
var ball_diameter: float = DEFAULT_BALL_DIAMETER:
	set(value):
		ball_diameter = clampf(value, MIN_BALL_DIAMETER, MAX_BALL_DIAMETER)
		_enforce_stats_size_safety_limit()
		refresh_ball_size()


@export_group("충돌 범위")

## 표시 반지름에 곱할 충돌 반지름 비율입니다.
## 1은 표시 크기와 동일하고, 0.75는 표시 반지름의 75%입니다.
@export_range(0.25, 1.5, 0.05, "suffix:x")
var collision_radius_ratio: float = DEFAULT_COLLISION_RADIUS_RATIO:
	set(value):
		collision_radius_ratio = clampf(
			value,
			MIN_COLLISION_RADIUS_RATIO,
			MAX_COLLISION_RADIUS_RATIO
		)
		_enforce_stats_size_safety_limit()
		refresh_ball_size()

## 공 루트 원점에서 충돌 원 중심을 이동할 거리입니다.
@export var collision_offset: Vector2 = Vector2.ZERO:
	set(value):
		collision_offset = value
		refresh_ball_size()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(PINBALL_GROUP)


func _ready() -> void:
	contact_monitor = true		# 물리 접촉 정보를 수집하도록 활성화. 향후 범퍼/플리퍼 충돌 처리에 필요
	max_contacts_reported = 8	# 한 물리 프레임에 최대 8개의 접촉점 기록
	_set_physics_rules(_physics_rules)
	_set_stats(_stats)
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
		var circle := _get_instance_circle_shape(collision)
		circle.radius = ball_diameter * 0.5 * collision_radius_ratio
		collision.scale = Vector2.ONE
		collision.position = collision_offset

	if is_inside_tree():
		update_configuration_warnings()


## 현재 공 설정이 만드는 실제 원형 충돌 지름입니다.
func get_collision_diameter() -> float:
	return ball_diameter * collision_radius_ratio


## 개별 Stats나 공용 설정으로도 넘을 수 없는 크기별 최종 안전 상한입니다.
func get_safe_maximum_speed() -> float:
	if physics_rules == null:
		return 0.0
	return minf(
		physics_rules.maximum_speed,
		physics_rules.get_safe_maximum_speed(get_collision_diameter())
	)


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

	if (
		stats != null
		and physics_rules != null
		and not physics_rules.is_stats_within_rules(
			stats,
			get_collision_diameter()
		)
	):
		warnings.append(
			"개별 Stats 일부가 공용 물리 규칙 또는 크기별 안전 속도 범위를 벗어났습니다. "
			+ "게임에서는 허용 범위로 보정됩니다."
		)

	if not scale.is_equal_approx(Vector2.ONE):
		warnings.append("PinballBall 루트의 Scale은 (1, 1)로 유지하고 Ball Diameter를 사용하세요.")

	return warnings


## 에디터에 설정된 공 물성을 RigidBody2D와 PhysicsMaterial에 반영합니다.
func refresh_physics_properties() -> void:
	if stats == null or physics_rules == null:
		return

	mass = physics_rules.get_effective_mass(stats)
	gravity_scale = physics_rules.get_effective_gravity_scale(stats)
	_apply_ball_elasticity()


func _set_stats(value: PinballStats) -> void:
	if _stats != null and _stats.changed.is_connected(_on_stats_changed):
		_stats.changed.disconnect(_on_stats_changed)

	_stats = value

	if _stats == null:
		_stats = PinballStats.new()
		_stats.resource_local_to_scene = true

	if not _stats.changed.is_connected(_on_stats_changed):
		_stats.changed.connect(_on_stats_changed)

	_enforce_stats_size_safety_limit()
	refresh_physics_properties()


func _on_stats_changed() -> void:
	if _stats_safety_clamp_in_progress:
		return
	_enforce_stats_size_safety_limit()
	refresh_physics_properties()

	if is_inside_tree():
		update_configuration_warnings()


func _set_physics_rules(value: PinballPhysicsRules) -> void:
	if (
		_physics_rules != null
		and _physics_rules.changed.is_connected(_on_physics_rules_changed)
	):
		_physics_rules.changed.disconnect(_on_physics_rules_changed)

	_physics_rules = value if value != null else DEFAULT_PHYSICS_RULES

	if not _physics_rules.changed.is_connected(_on_physics_rules_changed):
		_physics_rules.changed.connect(_on_physics_rules_changed)

	_enforce_stats_size_safety_limit()
	refresh_physics_properties()

	if is_inside_tree():
		update_configuration_warnings()


func _on_physics_rules_changed() -> void:
	_enforce_stats_size_safety_limit()
	refresh_physics_properties()

	if is_inside_tree():
		update_configuration_warnings()


## 개별 Stats가 충돌 크기별 절대 안전 상한을 넘으면 입력 즉시 보정합니다.
## 공용 maximum_speed가 더 낮은 경우에는 기존 계약대로 Stats 원본을 보존합니다.
func _enforce_stats_size_safety_limit() -> void:
	if (
		_stats_safety_clamp_in_progress
		or _stats == null
		or _physics_rules == null
	):
		return
	var size_safety_maximum := _physics_rules.get_safe_maximum_speed(
		get_collision_diameter()
	)
	var clamped_maximum := minf(_stats.maximum_speed, size_safety_maximum)
	var clamped_minimum := minf(_stats.minimum_speed, clamped_maximum)
	if (
		is_equal_approx(_stats.maximum_speed, clamped_maximum)
		and is_equal_approx(_stats.minimum_speed, clamped_minimum)
	):
		return

	_stats_safety_clamp_in_progress = true
	_stats.minimum_speed = clamped_minimum
	_stats.maximum_speed = clamped_maximum
	_stats_safety_clamp_in_progress = false


func _get_instance_circle_shape(collision: CollisionShape2D) -> CircleShape2D:
	var circle := collision.shape as CircleShape2D

	if not circle.resource_local_to_scene:
		circle = circle.duplicate() as CircleShape2D
		circle.resource_local_to_scene = true
		collision.shape = circle

	return circle


## 입력 방향을 정규화하고 설정된 초기 속력 또는 요청 속력으로 공을 발사합니다.
## 요청 속력이 -1이면 공 Stats의 초기 속력을 사용합니다.
## 방향이나 요청 속력이 잘못되면 기존 속도를 보존하고 false를 반환합니다.
func launch(direction: Vector2, requested_speed: float = -1.0) -> bool:
	if (
		direction.is_zero_approx()
		or is_nan(requested_speed)
		or is_inf(requested_speed)
		or (
			requested_speed < 0.0
			and not is_equal_approx(requested_speed, -1.0)
		)
	):
		return false

	var launch_speed := physics_rules.get_effective_initial_speed(
		stats,
		get_collision_diameter()
	)
	if requested_speed >= 0.0:
		launch_speed = requested_speed

	_minimum_speed_suppressed_by_gravity = false
	sleeping = false
	linear_velocity = get_limited_velocity(
		direction.normalized()
		* launch_speed
	)
	return true


## 방향은 유지하면서 정지, 최소 속력, 최대 속력 규칙을 적용한 속도를 반환합니다.
func get_limited_velocity(
	velocity: Vector2,
	maximum_speed_override: float = INF
) -> Vector2:
	var speed := velocity.length()

	if speed <= STOPPED_SPEED_EPSILON:
		return Vector2.ZERO

	var speed_range := physics_rules.get_effective_speed_range(
		stats,
		get_collision_diameter()
	)
	var effective_maximum := minf(speed_range.y, maximum_speed_override)
	var effective_minimum := minf(speed_range.x, effective_maximum)
	var limited_speed := clampf(speed, effective_minimum, effective_maximum)
	return velocity.normalized() * limited_speed


## 플리퍼 등 외부 충돌이 요청한 순간 속도 상한을 짧은 물리 정리 구간 동안 보관합니다.
## 공 자체 Maximum Speed가 더 낮으면 기존 공 설정이 항상 우선합니다.
func request_temporary_maximum_speed(
	maximum_speed: float,
	settling_physics_frames: int = DEFAULT_COLLISION_LIMIT_SETTLING_FRAMES
) -> void:
	if is_nan(maximum_speed) or maximum_speed < 0.0:
		return

	var current_physics_frame := Engine.get_physics_frames()
	var active_maximum := get_active_temporary_maximum_speed(
		current_physics_frame
	)
	_temporary_maximum_speed = (
		minf(active_maximum, maximum_speed)
		if not is_inf(active_maximum)
		else maximum_speed
	)
	_temporary_speed_limit_until_physics_frame = maxi(
		_temporary_speed_limit_until_physics_frame,
		current_physics_frame + maxi(settling_physics_frames, 0)
	)


func get_active_temporary_maximum_speed(
	physics_frame: int = Engine.get_physics_frames()
) -> float:
	if physics_frame <= _temporary_speed_limit_until_physics_frame:
		return _temporary_maximum_speed

	clear_temporary_maximum_speed()
	return INF


func clear_temporary_maximum_speed() -> void:
	_temporary_maximum_speed = INF
	_temporary_speed_limit_until_physics_frame = -1


## 물리 프레임 사이에 외부 코드가 관찰하는 linear_velocity에도 현재 상한을 적용합니다.
func enforce_active_temporary_speed_limit() -> void:
	var active_maximum := get_active_temporary_maximum_speed()
	if is_inf(active_maximum):
		return
	linear_velocity = _get_maximum_limited_velocity(
		linear_velocity,
		active_maximum
	)


## 플리퍼 임펄스 뒤 기본 충돌 해석이 속도를 다시 더할 수 있으므로,
## 물리 스텝이 끝난 시점에 같은 상한을 한 번 더 적용합니다.
func _queue_active_temporary_speed_limit_enforcement() -> void:
	if _temporary_speed_limit_enforcement_queued:
		return
	_temporary_speed_limit_enforcement_queued = true
	call_deferred(&"_enforce_active_temporary_speed_limit_deferred")


func _enforce_active_temporary_speed_limit_deferred() -> void:
	_temporary_speed_limit_enforcement_queued = false
	enforce_active_temporary_speed_limit()


## 중력을 거슬러 상승하는 동안에는 최소 속력 보정을 억제합니다.
## 공이 정점을 지나 중력으로 최소 속력을 회복하면 일반 제한으로 복귀합니다.
func _get_physics_limited_velocity(
	velocity: Vector2,
	gravity: Vector2,
	maximum_speed_override: float = INF
) -> Vector2:
	var speed := velocity.length()

	if gravity.is_zero_approx():
		_minimum_speed_suppressed_by_gravity = false
		return get_limited_velocity(velocity, maximum_speed_override)

	if velocity.dot(gravity) < 0.0:
		_minimum_speed_suppressed_by_gravity = true

	if _minimum_speed_suppressed_by_gravity:
		var speed_range := physics_rules.get_effective_speed_range(
			stats,
			get_collision_diameter()
		)
		var recovered_minimum_speed := (
			velocity.dot(gravity) >= 0.0
			and speed >= speed_range.x
		)

		if recovered_minimum_speed:
			_minimum_speed_suppressed_by_gravity = false
		else:
			return _get_maximum_limited_velocity(
				velocity,
				maximum_speed_override
			)

	return get_limited_velocity(velocity, maximum_speed_override)


func _get_maximum_limited_velocity(
	velocity: Vector2,
	maximum_speed_override: float = INF
) -> Vector2:
	var speed := velocity.length()
	var maximum_speed := minf(
		physics_rules.get_effective_speed_range(
			stats,
			get_collision_diameter()
		).y,
		maximum_speed_override
	)

	if speed <= STOPPED_SPEED_EPSILON:
		return Vector2.ZERO

	if speed <= maximum_speed:
		return velocity

	return velocity.normalized() * maximum_speed


func _apply_ball_elasticity() -> void:
	var physics_material := _get_instance_physics_material()
	physics_material.bounce = physics_rules.get_effective_elasticity(stats)


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

	var temporary_maximum := get_active_temporary_maximum_speed()
	state.linear_velocity = _get_physics_limited_velocity(
		state.linear_velocity,
		state.total_gravity,
		temporary_maximum
	)
	if not is_inf(temporary_maximum):
		_queue_active_temporary_speed_limit_enforcement()

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
