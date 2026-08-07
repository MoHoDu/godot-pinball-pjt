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
	if layout == null or pickup_scene == null:
		push_warning("코인 배치 데이터가 없어 코인을 스폰하지 않습니다.")
		return 0

	var positions := layout.all_positions()
	var spawned := 0
	for position_index in positions.size():
		var pickup := pickup_scene.instantiate() as CoinPickup
		if pickup == null:
			push_warning("코인 픽업 씬의 루트가 CoinPickup이 아닙니다.")
			continue
		pickup.pickup_id = StringName("coin_w%d_%02d" % [wave_id, position_index])
		pickup.value = layout.coin_value
		pickup.position = positions[position_index]
		pickup.collected.connect(_on_pickup_collected)
		add_child(pickup)
		spawned += 1
	return spawned


func clear_pickups() -> void:
	for child in get_children():
		if child is CoinPickup:
			child.queue_free()


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
