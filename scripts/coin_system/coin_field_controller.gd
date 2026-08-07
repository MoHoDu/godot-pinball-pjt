class_name CoinFieldController
extends Node2D


## 웨이브마다 코인을 스폰하고, 획득을 지갑에 반영하는 관리자입니다.
##
## 기획서 10-3의 coin_pickup_collected 시그널을 여기서 발화합니다.
## 웨이브가 바뀌면 이전 코인을 전부 지우고 새로 깝니다.


signal coin_pickup_collected(
	wave_id: int,
	pickup_id: StringName,
	value: int,
	wallet_after: int
)
signal board_coin_changed(board_coin: int)


const DEFAULT_PICKUP_SCENE := preload("res://scenes/coin_system/coin_pickup.tscn")


@export var layout: CoinSpawnLayout
@export var pickup_scene: PackedScene = DEFAULT_PICKUP_SCENE
@export var coin_definition: CoinDefinition
@export var spawn_points_root: Node2D
@export var board_layout: BoardLayout
@export var bumpers_root: Node2D


var _wallet: CoinWallet
var _wave_id := 0
var _board_coin_this_wave := 0


## 이번 웨이브에서 보드 코인으로 얻은 합계입니다. 유예 환산 코인은 포함하지 않습니다.
var board_coin_this_wave: int:
	get:
		return _board_coin_this_wave


func bind_wallet(wallet: CoinWallet) -> bool:
	if wallet == null:
		return false
	_wallet = wallet
	return true


## 웨이브 시작에 호출합니다. 남은 코인을 지우고 배치를 새로 깝니다.
func spawn_for_wave(wave_id: int) -> int:
	clear_pickups()
	_wave_id = wave_id
	_board_coin_this_wave = 0
	board_coin_changed.emit(0)
	if pickup_scene == null or (spawn_points_root == null and layout == null):
		push_warning("코인 배치 데이터가 없어 코인을 스폰하지 않습니다.")
		return 0

	var spawn_points := get_spawn_points()
	var positions := _spawn_positions(spawn_points)
	if positions.is_empty() and layout != null:
		positions = layout.all_positions()
	var spawned := 0
	for position_index in positions.size():
		var pickup := pickup_scene.instantiate() as CoinPickup
		if pickup == null:
			push_warning("코인 픽업 씬의 루트가 CoinPickup이 아닙니다.")
			continue
		pickup.pickup_id = (
			spawn_points[position_index].pickup_id_for_wave(wave_id)
			if position_index < spawn_points.size()
			else StringName("coin_w%d_%02d" % [wave_id, position_index])
		)
		pickup.definition = coin_definition
		pickup.value = (
			0 if coin_definition != null
			else layout.coin_value if layout != null
			else 2
		)
		pickup.position = positions[position_index]
		pickup.collected.connect(_on_pickup_collected)
		add_child(pickup)
		spawned += 1
	return spawned


func clear_pickups() -> void:
	for child in get_children():
		if child is CoinPickup:
			child.queue_free()


func reset_wave() -> void:
	clear_pickups()
	_board_coin_this_wave = 0
	board_coin_changed.emit(0)


func get_spawn_points() -> Array[CoinSpawnPoint]:
	var points: Array[CoinSpawnPoint] = []
	if spawn_points_root == null:
		return points
	for child: Node in spawn_points_root.get_children():
		if child is CoinSpawnPoint:
			points.append(child as CoinSpawnPoint)
	return points


func validate_authored_placement() -> PackedStringArray:
	var errors := PackedStringArray()
	var points := get_spawn_points()
	if points.size() != 12:
		errors.append("Coin board requires exactly 12 authored spawn points; found %d." % points.size())
		return errors
	var main_count := 0
	var risk_count := 0
	var ids: Dictionary = {}
	var radius := coin_definition.visual_radius if coin_definition != null else 14.0
	var boundary_polygon := PackedVector2Array()
	if board_layout != null and board_layout.get_boundary() != null:
		boundary_polygon = board_layout.get_boundary().get_polygon_in(board_layout)
	for point: CoinSpawnPoint in points:
		if ids.has(point.point_id):
			errors.append("Coin point id '%s' is duplicated." % point.point_id)
		ids[point.point_id] = true
		if point.route_kind == CoinSpawnPoint.RouteKind.MAIN:
			main_count += 1
		else:
			risk_count += 1
		if board_layout != null and not boundary_polygon.is_empty():
			var board_position := board_layout.to_local(point.global_position)
			if not BoardGeometry.contains_circle(boundary_polygon, board_position, radius):
				errors.append("Coin '%s' is outside the playable board." % point.point_id)
			for socket: BoardPlacementSocket in board_layout.get_sockets():
				var minimum := radius + socket.reserve_radius
				if point.global_position.distance_to(socket.global_position) < minimum:
					errors.append("Coin '%s' overlaps socket reserve '%s'." % [point.point_id, socket.socket_id])
			for area: BoardForbiddenArea in board_layout.get_forbidden_areas():
				var polygon := area.get_polygon_in(board_layout)
				var area_position := board_layout.to_local(point.global_position)
				if BoardGeometry.contains_point(polygon, area_position) \
						or BoardGeometry.distance_to_edges(polygon, area_position) < radius:
					errors.append("Coin '%s' overlaps forbidden area '%s'." % [point.point_id, area.area_id])
		if bumpers_root != null:
			for child: Node in bumpers_root.get_children():
				var bumper := child as Bumper
				if bumper == null:
					continue
				if point.global_position.distance_to(bumper.global_position) \
						< radius + bumper.get_collision_radius():
					errors.append("Coin '%s' overlaps bumper '%s'." % [point.point_id, bumper.name])
	for first_index in points.size():
		for second_index in range(first_index + 1, points.size()):
			if points[first_index].global_position.distance_to(points[second_index].global_position) \
					< radius * 2.0:
				errors.append("Coin points '%s' and '%s' overlap." % [points[first_index].point_id, points[second_index].point_id])
	if main_count != 10 or risk_count != 2:
		errors.append("Wave 1 requires 10 main-route and 2 risk-route coins; found %d/%d." % [main_count, risk_count])
	return errors


func _spawn_positions(points: Array[CoinSpawnPoint]) -> PackedVector2Array:
	var positions := PackedVector2Array()
	for point: CoinSpawnPoint in points:
		positions.append(to_local(point.global_position))
	return positions


func remaining_pickup_count() -> int:
	var count := 0
	for child in get_children():
		if child is CoinPickup and not child.is_queued_for_deletion():
			count += 1
	return count


func _on_pickup_collected(pickup_id: StringName, value: int) -> void:
	_board_coin_this_wave += value
	var wallet_after := _board_coin_this_wave
	if _wallet != null:
		wallet_after = _wallet.add(value)
	board_coin_changed.emit(_board_coin_this_wave)
	coin_pickup_collected.emit(_wave_id, pickup_id, value, wallet_after)
