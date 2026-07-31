@tool
class_name Pinball
extends RigidBody2D


# 크기 상수 정의 
const MIN_BALL_DIAMETER: float = 16.0		# 최소 공 지름
const MAX_BALL_DIAMETER: float = 256.0		# 최대 공 지름
const DEFAULT_BALL_DIAMETER: float = 64.0	# 기본 공 지름

# 극도로 작은 원본 크기로 나누는 것을 막기 위한 안전값
const MIN_SOURCE_SIZE: float = 0.001		


@export_category("공 크기")

## 게임에서 사용하는 공의 지름입니다.
## 시각 이미지의 원본 해상도와 관계없이 표시 및 충돌 크기에 적용됩니다.
@export_range(16.0, 256.0, 1.0, "suffix:px")
var ball_diameter: float = DEFAULT_BALL_DIAMETER:
	set(value):
		ball_diameter = clampf(value, MIN_BALL_DIAMETER, MAX_BALL_DIAMETER)
		refresh_ball_size()


func _ready() -> void:
	contact_monitor = true		# 물리 접촉 정보를 수집하도록 활성화. 향후 범퍼/플리퍼 충돌 처리에 필요 
	max_contacts_reported = 8	# 한 물리 프레임에 최대 8개의 접촉점 기록
	refresh_ball_size()


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
