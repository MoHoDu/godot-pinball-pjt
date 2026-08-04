@tool
class_name RepairSocket2D
extends Marker2D


## 기획자가 충돌 안전성을 검증한 수리 소켓입니다.
## 부품은 자유 좌표에 놓지 않고 이 소켓의 자식으로만 장착합니다.
## 소켓은 부품의 시각 중심·충돌 반경·발동 VFX 기준점을 함께 제공합니다.


@export var socket_definition: RepairSocketDefinition

## 보스전 등에서 소켓을 잠급니다. 비활성 소켓의 부품은 발동하지 않습니다.
@export var is_socket_active: bool = true:
	set(value):
		is_socket_active = value
		_apply_active_state()


func get_socket_id() -> StringName:
	return (
		socket_definition.socket_id
		if socket_definition != null
		else &""
	)


func get_mounted_runtime() -> RepairPartRuntime:
	for child: Node in get_children():
		if child is Bumper:
			var runtime := child.get_node_or_null(^"RepairPartRuntime")
			if runtime is RepairPartRuntime:
				return runtime as RepairPartRuntime
	return null


func is_occupied() -> bool:
	return get_mounted_runtime() != null


## 부품 프리팹 씬을 이 소켓에 장착합니다. 이미 차 있으면 실패합니다.
func mount_part(part_scene: PackedScene) -> Bumper:
	if part_scene == null or is_occupied():
		return null
	var part := part_scene.instantiate() as Bumper
	if part == null:
		return null
	add_child(part)
	part.position = Vector2.ZERO
	_apply_active_state()
	return part


func unmount_part() -> void:
	for child: Node in get_children():
		if child is Bumper:
			child.queue_free()


func _apply_active_state() -> void:
	var runtime := get_mounted_runtime()
	if runtime != null:
		runtime.is_equipped = is_socket_active
