@tool
class_name PinballFlipper
extends AnimatableBody2D


const MIN_FLIPPER_LENGTH: float = 64.0
const MAX_FLIPPER_LENGTH: float = 4096.0
const DEFAULT_FLIPPER_LENGTH: float = 1552.0
const MIN_SOURCE_SIZE: float = 0.001


@export_category("플리퍼 설정")


@export_group("크기")

## 피벗 방향과 원본 이미지 비율을 유지한 플리퍼의 긴 변 길이입니다.
## Sprite2D와 CollisionPolygon2D의 크기 및 피벗 상대 위치에 함께 적용됩니다.
@export_range(64.0, 4096.0, 1.0, "suffix:px")
var flipper_length: float = DEFAULT_FLIPPER_LENGTH:
	set(value):
		flipper_length = clampf(
			value,
			MIN_FLIPPER_LENGTH,
			MAX_FLIPPER_LENGTH
		)
		refresh_flipper_size()
		# 인스턴스 씬 로딩 중에는 자식 노드보다 export 값이 먼저 복원될 수 있습니다.
		# 자식 구성이 끝난 뒤 한 번 더 적용해 에디터 뷰도 확실히 갱신합니다.
		call_deferred(&"refresh_flipper_size")


@export_group("회전")

## 플리퍼가 작동할 때 회전하는 각도입니다.
## 음수는 반시계 방향, 양수는 시계 방향입니다.
@export_range(-90.0, 90.0, 1.0, "suffix:°")
var flip_angle_degrees: float = -35.0


@export_group("상태")

var rest_rotation: float
var is_flipping: bool = false


@export_group("쉐이더")

@onready var sprite: Sprite2D = $Sprite2D

@export var shader_active_value: String = "outline_enabled"


func _enter_tree() -> void:
	# @tool 인스턴스가 에디터 씬 트리에 들어온 뒤 자식 노드까지 구성된 시점에 적용합니다.
	call_deferred(&"refresh_flipper_size")


func _ready() -> void:
	rest_rotation = rotation

	# 다른 플리퍼와 Material 상태를 공유하지 않도록 복제
	if sprite.material:
		sprite.material = sprite.material.duplicate()

	refresh_flipper_size()


## 설정된 길이를 시각 이미지와 충돌 폴리곤에 같은 비율로 적용합니다.
## 폴리곤 점 원본은 유지하고 노드의 균일 배율 및 피벗 상대 위치만 갱신합니다.
func refresh_flipper_size() -> void:
	var target_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D

	if target_sprite == null or target_sprite.texture == null:
		if is_inside_tree():
			update_configuration_warnings()
		return

	var texture_size := target_sprite.texture.get_size()
	var source_length := maxf(absf(texture_size.x), absf(texture_size.y))

	if source_length <= MIN_SOURCE_SIZE:
		return

	var size_factor := flipper_length / source_length
	target_sprite.scale = Vector2.ONE * size_factor

	if collision != null:
		var orientation := Vector2(
			_sign_or_one(collision.scale.x),
			_sign_or_one(collision.scale.y)
		)
		collision.scale = orientation * size_factor
		collision.position = target_sprite.offset * size_factor

	if is_inside_tree():
		update_configuration_warnings()


func _sign_or_one(value: float) -> float:
	return signf(value) if not is_zero_approx(value) else 1.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var target_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D

	if target_sprite == null:
		warnings.append("Sprite2D 자식 노드가 필요합니다.")
	elif target_sprite.texture == null:
		warnings.append("Sprite2D에 Texture2D를 지정해야 합니다.")

	if collision == null:
		warnings.append("CollisionPolygon2D 자식 노드가 필요합니다.")
	elif collision.polygon.is_empty():
		warnings.append("CollisionPolygon2D에 Polygon 점을 지정해야 합니다.")

	if not scale.is_equal_approx(Vector2.ONE):
		warnings.append("플리퍼 루트의 Scale은 (1, 1)로 유지하고 Flipper Length를 사용하세요.")

	return warnings


func set_selected_visual(is_selected: bool) -> void:
	var shader_material := sprite.material as ShaderMaterial

	if shader_material == null:
		return 

	shader_material.set_shader_parameter(
		shader_active_value,
		is_selected
	)


func play_flip(attack_time: float, return_time: float, wait_time: float) -> void:
	is_flipping = true

	var target_rotation: float = (
		rest_rotation
		+ deg_to_rad(flip_angle_degrees)
	)

	# 트윈 애니메이션 생성
	var tween: Tween = create_tween()

	# 트윈을 물리 프레임에서 처리
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	# 플리퍼의 rotation을 attack_time동안 target_rotation까지 변경
	# 시작할 때 빠르게 움직이고 목표에 가까워지면서 감속하는 효과 추가
	tween.tween_property(
		self,
		"rotation",
		target_rotation,
		attack_time
	).set_trans(
		Tween.TRANS_QUART
	).set_ease(
		Tween.EASE_OUT
	)

	# 현재 각도에서 wait_time만큼 기다림
	tween.tween_interval(wait_time)

	# 플리퍼의 rotation을 return_time동안 rest_rotation으로 복구
	tween.tween_property(
		self,
		"rotation",
		rest_rotation,
		return_time
	).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(
		Tween.EASE_IN_OUT
	)

	# 트윈 종료까지 대기 
	await tween.finished

	# 현재 각도를 초기 각도로 복구 
	rotation = rest_rotation
	is_flipping = false
