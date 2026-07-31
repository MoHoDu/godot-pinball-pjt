class_name FlipperSelector
extends Node2D


@export_category("컨트롤러 선택 관리자")

@export_category("컨트롤러")

## 이 입력으로 함께 작동할 플리퍼 목록입니다.
@export var controllers: Array[FlipperController] = []

@export var selected: FlipperController = null

@export_group("입력")

## 위쪽에 배치된 컨트롤러를 선택하는 Input Map 액션입니다.
@export var select_up_action: StringName = &"flipper_select_up"

## 왼쪽에 배치된 컨트롤러를 선택하는 Input Map 액션입니다.
@export var select_left_action: StringName = &"flipper_select_left"

## 아래쪽에 배치된 컨트롤러를 선택하는 Input Map 액션입니다.
@export var select_down_action: StringName = &"flipper_select_down"

## 오른쪽에 배치된 컨트롤러를 선택하는 Input Map 액션입니다.
@export var select_right_action: StringName = &"flipper_select_right"

## 실제 컨트롤러 배치를 기준으로 Input Map 액션과 컨트롤러를 연결합니다.
var controller_by_action: Dictionary = {}


func _ready() -> void:
	collect_flipper_controllers()
	map_direction_actions()

	if not controllers.is_empty():
		select_controller(controllers[0])


## 플리퍼 컨트롤러를 수집합니다.
func collect_flipper_controllers() -> void:
	controllers.clear()

	for child: Node in get_children():
		if child is FlipperController:
			controllers.append(child as FlipperController)

	print("찾은 컨트롤러 수: ", controllers.size())


## 방향 기준으로 입력 버튼과 컨트롤러를 매핑합니다.
func map_direction_actions() -> void:
	controller_by_action.clear()

	if controllers.is_empty():
		return

	var layout_center := get_layout_center()

	controller_by_action[select_up_action] = find_controller_in_direction(
		Vector2.UP,
		layout_center
	)
	controller_by_action[select_left_action] = find_controller_in_direction(
		Vector2.LEFT,
		layout_center
	)
	controller_by_action[select_down_action] = find_controller_in_direction(
		Vector2.DOWN,
		layout_center
	)
	controller_by_action[select_right_action] = find_controller_in_direction(
		Vector2.RIGHT,
		layout_center
	)


## 모든 컨트롤러 위치의 중심을 찾습니다.
func get_layout_center() -> Vector2:
	var layout_center := Vector2.ZERO

	for controller: FlipperController in controllers:
		layout_center += controller.position

	return layout_center / controllers.size()


## 정해진 방향의 컨트롤러를 찾습니다.
func find_controller_in_direction(
	direction: Vector2,
	layout_center: Vector2
) -> FlipperController:
	var closest_controller: FlipperController = controllers[0]
	var highest_direction_score := -INF

	for controller: FlipperController in controllers:
		var offset_from_center := controller.position - layout_center
		var direction_score := offset_from_center.dot(direction)

		if direction_score > highest_direction_score:
			highest_direction_score = direction_score
			closest_controller = controller

	return closest_controller


func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in controller_by_action:
		if event.is_action_pressed(action):
			select_controller(
				controller_by_action[action] as FlipperController
			)
			get_viewport().set_input_as_handled()
			return


func select_controller(controller: FlipperController) -> void:
	if not is_instance_valid(controller):
		return

	selected = controller

	for current_controller: FlipperController in controllers:
		current_controller.is_active = current_controller == selected
