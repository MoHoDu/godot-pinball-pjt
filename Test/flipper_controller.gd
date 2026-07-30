class_name FlipperController
extends Node2D

@export_category("컨트롤러 설정")


@export var is_active: bool = true:
	set(value):
		is_active = value
		update_selection_visual()


@export_category("플리퍼 설정")


@export_group("동작 시간")

## 기본 위치에서 목표 각도까지 이동하는 시간입니다.
## 값이 작을수록 빠르게 타격합니다.
@export_range(0.01, 1.0, 0.01, "suffix:s")
var attack_time: float = 0.07

## 목표 각도에 도달한 후 유지하는 시간입니다.
@export_range(0.0, 1.0, 0.01, "suffix:s")
var wait_time: float = 0.04

## 목표 각도에서 기본 위치까지 돌아오는 시간입니다.
@export_range(0.01, 1.0, 0.01, "suffix:s")
var return_time: float = 0.12


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
	if is_any_flipper_running():
		return

	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper):
			flipper.play_flip(attack_time, return_time, wait_time)


func is_any_flipper_running() -> bool:
	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper) and flipper.is_flipping:
			return true

	return false


func update_selection_visual() -> void:
	for flipper: PinballFlipper in flippers:
		if is_instance_valid(flipper):
			flipper.set_selected_visual(is_active)
