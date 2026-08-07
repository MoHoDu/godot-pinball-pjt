class_name RepairPlacementController
extends Node


## 수리 부품의 예약 → 첫 발사 확정 소비 → 웨이브 종료 소멸을 관리합니다. (기획서 8-2, 9장)
##
## 기존 스크립트는 수정하지 않고 공개 API만 씁니다.
##   - 배치 단계에서는 소켓에 "예약"만 하고 인벤토리를 차감하지 않는다(8-2).
##   - 첫 공 발사가 확정되는 순간 예약 수만큼 차감하고 보드에 장착한다.
##   - 웨이브 종료·실패·재시도 시 장착 개체를 보드에서 제거한다(1회용).
##   - 소켓 표시는 배치 단계에서만 켠다(9-1 표시 시점).


signal placement_started(wave_id: int)
signal placement_finished(wave_id: int)
signal reservation_changed(socket_id: StringName, part_id: StringName)
## 기획서 10-3. layout은 socket_id → part_id, consumed_counts는 part_id → 수량.
signal repair_layout_committed(
	wave_id: int,
	layout: Dictionary,
	consumed_counts: Dictionary
)


## 동시 배치 상한입니다(기획서 9-1).
const MAX_PLACED_PARTS := 6

const MARKER_NAME := "_PlacementMarker"


var _board: RepairBoardController
var _inventory: RewardPartInventory
var _scene_map: RepairPartSceneMap

## socket_id(StringName) → part_id(StringName). 예약 상태라 재고 차감이 없습니다.
var _reservations: Dictionary = {}
var _wave_id := 0
var _is_open := false
var _focused_socket_id: StringName = &""


var is_open: bool:
	get:
		return _is_open

var reservations: Dictionary:
	get:
		return _reservations.duplicate()

var focused_socket_id: StringName:
	get:
		return _focused_socket_id


func bind(
	board: RepairBoardController,
	inventory: RewardPartInventory,
	scene_map: RepairPartSceneMap
) -> bool:
	if board == null or inventory == null or scene_map == null:
		return false
	_board = board
	_inventory = inventory
	_scene_map = scene_map
	return true


## 첫 발사 전 배치 단계를 엽니다. 배치할 재고가 없으면 열지 않습니다.
func begin_placement(wave_id: int) -> bool:
	if _board == null or _is_open or _inventory.total_count <= 0:
		return false
	_wave_id = wave_id
	_is_open = true
	var sockets := _board.get_sockets()
	if not sockets.is_empty():
		_focused_socket_id = sockets[0].get_socket_id()
	_refresh_markers()
	placement_started.emit(wave_id)
	return true


func finish_placement() -> void:
	if not _is_open:
		return
	_is_open = false
	_remove_markers()
	placement_finished.emit(_wave_id)


func get_sockets() -> Array[RepairSocket2D]:
	if _board == null:
		return []
	return _board.get_sockets()


func reserved_part_at(socket_id: StringName) -> StringName:
	return _reservations.get(socket_id, &"")


func reserved_count_of(part_id: StringName) -> int:
	var count := 0
	for reserved: StringName in _reservations.values():
		if reserved == part_id:
			count += 1
	return count


## 예약을 반영한 실질 잔여 재고입니다.
func available_stock_of(part_id: StringName) -> int:
	if _inventory == null:
		return 0
	return _inventory.count_of(part_id) - reserved_count_of(part_id)


## 포커스 소켓을 다음/이전으로 옮깁니다. HUD 조작용입니다.
func move_focus(step: int) -> StringName:
	var sockets := get_sockets()
	if sockets.is_empty():
		return &""
	var index := 0
	for socket_index in sockets.size():
		if sockets[socket_index].get_socket_id() == _focused_socket_id:
			index = socket_index
			break
	index = wrapi(index + step, 0, sockets.size())
	_focused_socket_id = sockets[index].get_socket_id()
	_refresh_markers()
	return _focused_socket_id


## 소켓에 부품을 예약합니다. 같은 부품이 이미 예약돼 있으면 해제(토글)합니다.
func reserve(socket_id: StringName, part_id: StringName) -> bool:
	if not _is_open or part_id == &"" or not _scene_map.has_part(part_id):
		return false
	var socket := _socket_by_id(socket_id)
	if socket == null or not socket.is_socket_active or socket.is_occupied():
		return false
	if reserved_part_at(socket_id) == part_id:
		return cancel_reservation(socket_id)
	var is_replacing := _reservations.has(socket_id)
	if not is_replacing and _reservations.size() >= MAX_PLACED_PARTS:
		return false
	if available_stock_of(part_id) <= 0:
		return false
	_reservations[socket_id] = part_id
	reservation_changed.emit(socket_id, part_id)
	_refresh_markers()
	return true


## 예약을 인벤토리로 되돌립니다(차감이 없었으므로 수량 변화 없음).
func cancel_reservation(socket_id: StringName) -> bool:
	if not _reservations.has(socket_id):
		return false
	_reservations.erase(socket_id)
	reservation_changed.emit(socket_id, &"")
	_refresh_markers()
	return true


## 첫 공 발사가 확정되는 순간 부릅니다. 예약 수만큼 차감하고 장착합니다(8-2).
func commit_layout() -> bool:
	if not _is_open:
		return false
	var layout: Dictionary = {}
	var consumed: Dictionary = {}
	for socket_id: StringName in _reservations:
		var part_id: StringName = _reservations[socket_id]
		var socket := _socket_by_id(socket_id)
		if socket == null or not _inventory.try_consume(part_id, 1):
			continue
		var mounted := _board.mount_part_at(socket, _scene_map.scene_of(part_id))
		if mounted == null:
			# 장착 실패 시 차감을 되돌립니다(6-3 검사⑤와 같은 원자성 원칙).
			_inventory.add(part_id, 1)
			continue
		layout[socket_id] = part_id
		consumed[part_id] = int(consumed.get(part_id, 0)) + 1
	_reservations.clear()
	finish_placement()
	repair_layout_committed.emit(_wave_id, layout, consumed)
	return true


## 웨이브 종료·실패·재시도 시 장착 개체를 보드에서 제거합니다(8-2 소멸).
func clear_board() -> void:
	if _board == null:
		return
	for socket: RepairSocket2D in _board.get_sockets():
		if socket.is_occupied():
			_board.unmount_part_at(socket)
	_reservations.clear()


func _socket_by_id(socket_id: StringName) -> RepairSocket2D:
	for socket: RepairSocket2D in get_sockets():
		if socket.get_socket_id() == socket_id:
			return socket
	return null


## 배치 단계 동안만 소켓 위에 자리표시자 마커를 그립니다(9-1 표시 시점).
func _refresh_markers() -> void:
	if not _is_open:
		return
	for socket: RepairSocket2D in get_sockets():
		var marker := socket.get_node_or_null(MARKER_NAME) as SocketMarker
		if marker == null:
			marker = SocketMarker.new()
			marker.name = MARKER_NAME
			socket.add_child(marker)
		var definition := socket.socket_definition
		if definition != null:
			marker.collision_radius = definition.collision_radius
			var v02 := definition as RepairSocketDefinitionV02
			if v02 != null:
				marker.reserve_radius = v02.reserve_radius
		marker.is_reserved = _reservations.has(socket.get_socket_id())
		marker.is_focused = socket.get_socket_id() == _focused_socket_id
		marker.queue_redraw()


func _remove_markers() -> void:
	for socket: RepairSocket2D in get_sockets():
		var marker := socket.get_node_or_null(MARKER_NAME)
		if marker != null:
			marker.queue_free()


## 소켓 자리표시자 마커입니다. 배치 단계에서만 존재합니다.
class SocketMarker:
	extends Node2D

	var collision_radius := 33.0
	var reserve_radius := 72.0
	var is_reserved := false
	var is_focused := false

	func _ready() -> void:
		z_as_relative = false
		z_index = 20

	func _draw() -> void:
		var ring_color := Color(0.55, 0.85, 0.80, 0.55)
		if is_reserved:
			ring_color = Color(0.95, 0.80, 0.30, 0.85)
		draw_arc(
			Vector2.ZERO, reserve_radius, 0.0, TAU, 48, ring_color, 3.0
		)
		draw_circle(
			Vector2.ZERO,
			collision_radius,
			Color(ring_color.r, ring_color.g, ring_color.b, 0.25)
		)
		if is_focused:
			draw_arc(
				Vector2.ZERO,
				reserve_radius + 10.0,
				0.0,
				TAU,
				48,
				Color(0.95, 0.97, 0.90, 0.95),
				4.0
			)
