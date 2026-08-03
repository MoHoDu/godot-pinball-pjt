class_name FlipperController
extends Node2D

@export_category("컨트롤러 설정")


@export var is_active: bool = true:
	set(value):
		is_active = value
		update_selection_visual()


@export_category("플리퍼 설정")

@export_group("입력")

## 모든 플리퍼를 작동시키는 Input Map 액션입니다.
@export var input_action: StringName = &"flipper"


@export_category("플리퍼 목록")

## 이 입력으로 함께 작동할 플리퍼 목록입니다.
@export var flippers: Array[PinballFlipper] = []


func _ready() -> void:
	collect_flippers()
	update_selection_visual()


func collect_flippers() -> void:
	flippers.clear()

	for child: Node in get_children():
		if child is PinballFlipper:
			flippers.append(child as PinballFlipper)
		
	print("찾은 플리퍼 수: ", flippers.size())


func _physics_process(_delta: float) -> void:
	if is_active and Input.is_action_just_pressed(input_action):
		play_all_flippers()


func play_all_flippers() -> void:
	var activation_token := PinballFlipper.issue_activation_token()
	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper):
			flipper.request_activation(activation_token)


func is_any_flipper_running() -> bool:
	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper) and flipper.is_flipping:
			return true

	return false


func update_selection_visual() -> void:
	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper):
			flipper.set_selected_visual(is_active)
