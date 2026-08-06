class_name RepairPartPlacementController
extends Node


@export var placement_session: BoardPlacementSession
@export var inventory: RepairPartInventory
@export var placement_hud: RepairPartPlacementHud
@export var wave_bridge: BoardWavePlacementBridge
@export_range(8.0, 128.0, 1.0, "suffix:px") var socket_pick_radius := 58.0
@export_range(8.0, 128.0, 1.0, "suffix:px") var placeable_pick_radius := 54.0


var _selected_socket: BoardPlacementSocket
var _drag_kind_id: StringName


func _ready() -> void:
	_assert_dependencies()
	if placement_session == null \
			or inventory == null \
			or placement_hud == null \
			or wave_bridge == null:
		return
	wave_bridge.placement_requested.connect(_on_placement_requested)
	wave_bridge.placement_ready.connect(_on_placement_ready)
	wave_bridge.placement_blocked.connect(_on_placement_blocked)
	placement_hud.part_activated.connect(_on_part_activated)
	placement_hud.part_drag_started.connect(_on_part_drag_started)
	placement_hud.part_dropped.connect(_on_part_dropped)
	placement_hud.confirm_requested.connect(_on_confirm_requested)
	inventory.inventory_changed.connect(_on_inventory_changed)
	if placement_session.current_state == BoardPlacementSession.State.EDITING:
		_on_placement_requested(placement_session.current_wave_id)


func _unhandled_input(event: InputEvent) -> void:
	if placement_session == null \
			or placement_session.layout == null \
			or placement_session.current_state != BoardPlacementSession.State.EDITING \
			or not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		var right_clicked := _find_placeable(mouse_button.position)
		if right_clicked != null and _remove_placeable(right_clicked):
			get_viewport().set_input_as_handled()
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	var remove_target := _find_remove_button_target(mouse_button.position)
	if remove_target != null and _remove_placeable(remove_target):
		get_viewport().set_input_as_handled()
		return
	var placeable := _find_placeable(mouse_button.position)
	if placeable != null:
		_select_socket(_find_socket_by_id(placeable.socket_id))
		get_viewport().set_input_as_handled()
		return
	var socket := _find_socket(mouse_button.position)
	_select_socket(socket)
	if socket != null:
		get_viewport().set_input_as_handled()


func _on_placement_requested(_wave_id: StringName) -> void:
	if inventory.get_snapshot().is_empty():
		inventory.reset_to_starting_counts()
	if not inventory.begin_reservation(_get_placement_counts()):
		inventory.cancel_reservation()
		inventory.begin_reservation(_get_placement_counts())
	_selected_socket = null
	_drag_kind_id = &""
	_refresh_view()


func _on_placement_ready(
	_wave_id: StringName,
	_consumed_counts: Dictionary
) -> void:
	inventory.commit_reservation()
	_selected_socket = null
	_drag_kind_id = &""
	_refresh_socket_states()


func _on_placement_blocked(result: BoardValidationResult) -> void:
	placement_hud.set_status(result.summary(), true)


func _on_inventory_changed(_snapshot: Array[Dictionary]) -> void:
	_refresh_view()


func _on_confirm_requested() -> void:
	placement_hud.set_confirm_enabled(false)
	if not wave_bridge.commit_placement():
		placement_hud.set_confirm_enabled(true)


func _on_part_activated(kind_id: StringName) -> void:
	if _selected_socket == null:
		placement_hud.set_status("먼저 보드의 소켓을 선택하세요.", true)
		return
	_place_kind_at_socket(kind_id, _selected_socket)


func _on_part_drag_started(kind_id: StringName) -> void:
	_drag_kind_id = kind_id
	_refresh_socket_states()


func _on_part_dropped(
	kind_id: StringName,
	viewport_position: Vector2
) -> void:
	_drag_kind_id = &""
	var socket := _find_socket(viewport_position)
	if socket == null:
		placement_hud.set_status("부품을 격자 안의 활성 소켓에 놓으세요.", true)
		_refresh_socket_states()
		return
	_select_socket(socket)
	_place_kind_at_socket(kind_id, socket)


func select_socket(socket_id: StringName) -> bool:
	var socket := _find_socket_by_id(socket_id)
	_select_socket(socket)
	return socket != null


func place_kind_at_socket(
	kind_id: StringName,
	socket_id: StringName
) -> bool:
	return _place_kind_at_socket(kind_id, _find_socket_by_id(socket_id))


func remove_at_socket(socket_id: StringName) -> bool:
	var placeable := placement_session.find_placeable_at_socket(socket_id)
	return placeable != null and _remove_placeable(placeable)


func _place_kind_at_socket(
	kind_id: StringName,
	socket: BoardPlacementSocket
) -> bool:
	if socket == null or not _is_kind_compatible(kind_id, socket):
		placement_hud.set_status("이 부품은 선택한 영역에 배치할 수 없습니다.", true)
		return false
	var existing := placement_session.find_placeable_at_socket(socket.socket_id)
	if existing != null and existing.get_kind_id() == kind_id:
		placement_hud.set_status("이미 같은 부품이 장착되어 있습니다.")
		return true
	if not inventory.can_reserve(kind_id):
		placement_hud.set_status("인벤토리에 남은 부품이 없습니다.", true)
		return false
	var entry := inventory.get_entry(kind_id)
	if entry == null:
		placement_hud.set_status("부품 프리팹을 찾을 수 없습니다.", true)
		return false
	var placed: BoardPlaceable
	if existing == null:
		placed = placement_session.place_scene_at_socket(
			entry.placeable_scene,
			socket.socket_id
		)
	else:
		placed = placement_session.replace_scene_at_socket(
			entry.placeable_scene,
			socket.socket_id
		)
	if placed == null:
		placement_hud.set_status("배치 규칙을 만족하지 않아 적용하지 못했습니다.", true)
		return false
	_sync_inventory_from_layout()
	placement_hud.set_status("%s 배치를 예약했습니다." % entry.settings.display_name)
	_refresh_view()
	return true


func _remove_placeable(placeable: BoardPlaceable) -> bool:
	if not placement_session.remove_placeable(placeable):
		return false
	_sync_inventory_from_layout()
	placement_hud.set_status("부품을 해제해 인벤토리로 돌려보냈습니다.")
	_refresh_view()
	return true


func _select_socket(socket: BoardPlacementSocket) -> void:
	_selected_socket = socket
	if socket != null and not placement_hud.is_drawer_open():
		placement_hud.toggle_drawer()
	_refresh_view()


func _refresh_view() -> void:
	if placement_session == null \
			or placement_session.layout == null \
			or inventory == null \
			or placement_hud == null:
		return
	var compatibility: Dictionary = {}
	for entry: RepairPartInventoryEntry in inventory.entries:
		if entry == null or not entry.is_valid():
			continue
		compatibility[entry.get_kind_id()] = (
			_selected_socket != null
			and _is_kind_compatible(entry.get_kind_id(), _selected_socket)
		)
	placement_hud.render_inventory(
		inventory.get_snapshot(),
		_selected_socket.socket_id if _selected_socket != null else &"",
		compatibility
	)
	_refresh_socket_states()


func _refresh_socket_states() -> void:
	if placement_session == null or placement_session.layout == null:
		return
	for socket: BoardPlacementSocket in placement_session.layout.get_sockets():
		var occupied := placement_session.find_placeable_at_socket(
			socket.socket_id
		) != null
		var state := BoardPlacementSocket.VisualState.OCCUPIED \
			if occupied else BoardPlacementSocket.VisualState.IDLE
		if socket == _selected_socket:
			state = BoardPlacementSocket.VisualState.SELECTED
		elif not _drag_kind_id.is_empty():
			state = (
				BoardPlacementSocket.VisualState.COMPATIBLE
				if _is_kind_compatible(_drag_kind_id, socket)
				else BoardPlacementSocket.VisualState.DISABLED
			)
		socket.set_visual_state(state)


func _is_kind_compatible(
	kind_id: StringName,
	socket: BoardPlacementSocket
) -> bool:
	if socket == null or not socket.enabled:
		return false
	var entry := inventory.get_entry(kind_id)
	if entry == null or entry.settings == null:
		return false
	for zone: BoardPlacementZone in placement_session.layout.get_zones():
		if zone.zone_id == socket.zone_id:
			return zone.accepts_kind(kind_id, entry.settings.is_repair_part)
	return false


func _sync_inventory_from_layout() -> void:
	if not inventory.sync_reservations(_get_placement_counts()):
		push_error("Board placement counts diverged from repair-part inventory.")


func _get_placement_counts() -> Dictionary:
	var counts: Dictionary = {}
	if placement_session == null or placement_session.layout == null:
		return counts
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var kind_id := placeable.get_kind_id()
		counts[kind_id] = int(counts.get(kind_id, 0)) + 1
	return counts


func _find_socket(viewport_position: Vector2) -> BoardPlacementSocket:
	var local_position := _to_layout_position(viewport_position)
	var closest: BoardPlacementSocket
	var closest_distance := socket_pick_radius
	for socket: BoardPlacementSocket in placement_session.layout.get_sockets():
		if not socket.enabled:
			continue
		var distance := local_position.distance_to(
			placement_session.layout.to_local(socket.global_position)
		)
		if distance <= closest_distance:
			closest = socket
			closest_distance = distance
	return closest


func _find_socket_by_id(socket_id: StringName) -> BoardPlacementSocket:
	for socket: BoardPlacementSocket in placement_session.layout.get_sockets():
		if socket.socket_id == socket_id:
			return socket
	return null


func _find_placeable(viewport_position: Vector2) -> BoardPlaceable:
	var local_position := _to_layout_position(viewport_position)
	var closest: BoardPlaceable
	var closest_distance := placeable_pick_radius
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var distance := local_position.distance_to(
			placement_session.layout.to_local(placeable.global_position)
		)
		if distance <= closest_distance:
			closest = placeable
			closest_distance = distance
	return closest


func _find_remove_button_target(viewport_position: Vector2) -> BoardPlaceable:
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var local_position := placeable.get_global_transform_with_canvas() \
			.affine_inverse() * viewport_position
		if placeable.is_remove_button_hit(local_position):
			return placeable
	return null


func _to_layout_position(viewport_position: Vector2) -> Vector2:
	return placement_session.layout.get_global_transform_with_canvas() \
		.affine_inverse() * viewport_position


func _assert_dependencies() -> void:
	assert(placement_session != null,
		"Repair placement controller requires BoardPlacementSession.")
	assert(inventory != null,
		"Repair placement controller requires RepairPartInventory.")
	assert(placement_hud != null,
		"Repair placement controller requires RepairPartPlacementHud.")
	assert(wave_bridge != null,
		"Repair placement controller requires BoardWavePlacementBridge.")
