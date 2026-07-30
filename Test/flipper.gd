class_name PinballFlipper
extends AnimatableBody2D

@export_category("플리퍼 설정")


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


func _ready() -> void:
	rest_rotation = rotation

	# 다른 플리퍼와 Material 상태를 공유하지 않도록 복제
	if sprite.material:
		sprite.material = sprite.material.duplicate()


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
