class_name RepairBoardController
extends Node


## 보드의 수리 소켓과 장착된 부품을 관리합니다.
## 기존 WaveRuntimeCoordinator의 Bumpers 서브트리를 건드리지 않고,
## 부품 범퍼의 ComboHitSource 바인딩과 새 공 리셋을 별도로 담당합니다.


const MAX_EQUIPPED_PARTS := 4


@export var sockets_root_path: NodePath = NodePath("../Sockets")
## 비워 두면 combo_systems 그룹에서 찾습니다.
@export var combo_system_path: NodePath = NodePath("")
@export var router_path: NodePath = NodePath("../RepairEffectRouter")


var _sockets_root: Node = null


func _ready() -> void:
	_sockets_root = get_node_or_null(sockets_root_path)
	call_deferred(&"bind_part_hit_sources")


func get_sockets() -> Array[RepairSocket2D]:
	var sockets: Array[RepairSocket2D] = []
	if _sockets_root == null:
		return sockets
	for child: Node in _sockets_root.get_children():
		if child is RepairSocket2D:
			sockets.append(child as RepairSocket2D)
	return sockets


func get_mounted_runtimes() -> Array[RepairPartRuntime]:
	var runtimes: Array[RepairPartRuntime] = []
	for socket: RepairSocket2D in get_sockets():
		var runtime := socket.get_mounted_runtime()
		if runtime != null:
			runtimes.append(runtime)
	return runtimes


func get_equipped_count() -> int:
	return get_mounted_runtimes().size()


func can_mount_more() -> bool:
	return get_equipped_count() < MAX_EQUIPPED_PARTS


## 부품 범퍼의 유효 타격을 기존 콤보 적립에 연결합니다 (공개 API만 사용).
func bind_part_hit_sources() -> void:
	var combo_system := _find_combo_system()
	if combo_system == null:
		return
	for runtime: RepairPartRuntime in get_mounted_runtimes():
		if runtime.bumper != null and runtime.bumper.combo_hit_source != null:
			combo_system.bind_hit_source(runtime.bumper.combo_hit_source)


## 새 발사 준비 시 부품 범퍼의 접촉·내구도 상태를 복구합니다.
func reset_parts_for_new_ball() -> void:
	for runtime: RepairPartRuntime in get_mounted_runtimes():
		if runtime.bumper != null:
			runtime.bumper.reset_for_new_ball()


## 웨이브 사이 부품 장착의 단일 진입점입니다.
## 라우터 등록·콤보 바인딩·재배치 전체 초기화(기획서 9장)를 함께 처리합니다.
func mount_part_at(
	socket: RepairSocket2D,
	part_scene: PackedScene
) -> Bumper:
	if socket == null or not can_mount_more():
		return null
	var part := socket.mount_part(part_scene)
	if part == null:
		return null
	var combo_system := _find_combo_system()
	if combo_system != null and part.combo_hit_source != null:
		combo_system.bind_hit_source(part.combo_hit_source)
	var router := _find_router()
	if router != null:
		router.rescan_parts()
		router.on_full_reset()
	return part


func unmount_part_at(socket: RepairSocket2D) -> void:
	if socket == null:
		return
	socket.unmount_part()
	var router := _find_router()
	if router != null:
		router.on_full_reset()


## 보스 출현 영역과 겹치는 소켓을 잠급니다.
func set_boss_phase(is_boss_active: bool) -> void:
	for socket: RepairSocket2D in get_sockets():
		if (
			socket.socket_definition != null
			and socket.socket_definition.disabled_during_boss
		):
			socket.is_socket_active = not is_boss_active


func _find_router() -> RepairEffectRouter:
	return get_node_or_null(router_path) as RepairEffectRouter


func _find_combo_system() -> ComboSystem:
	if not combo_system_path.is_empty():
		return get_node_or_null(combo_system_path) as ComboSystem
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(
		RepairComboAdapter.COMBO_SYSTEM_GROUP
	) as ComboSystem
