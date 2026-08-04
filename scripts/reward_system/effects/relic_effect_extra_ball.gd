@tool
class_name RelicEffectExtraBall
extends RelicEffect


## 방울 — 다음 웨이브 시작 공을 늘립니다.
##
## WaveBallInventory.starting_stock의 count를 올려두면 다음 enter_wave()의
## reset_stock()에서 반영됩니다. 그래서 효과 적용은 반드시 다음 웨이브 진입 "전"입니다.
##
## 상한이 있습니다. WaveRuntimeCoordinator._configure_lives_from_inventory()가
## 라이프 슬롯 3~5개를 단언하기 때문에 총 공은 5개를 넘을 수 없습니다.


@export_range(1, 3, 1)
var balls_per_stack: int = 1:
	set(value):
		balls_per_stack = maxi(value, 1)
		emit_changed()

## 비워 두면 목록의 첫 번째 공에 더합니다.
@export var target_ball_id: StringName = &""


func apply(runtime: RelicRuntime, stack_count: int) -> bool:
	if runtime == null or runtime.ball_inventory == null:
		return false
	var stocks: Array[BallStock] = runtime.ball_inventory.starting_stock
	if stocks.is_empty():
		return false

	var base_total := 0
	for stock: BallStock in stocks:
		if stock == null:
			continue
		base_total += int(runtime.get_baseline(stock, &"count"))
	if base_total <= 0:
		return false

	# 항상 기준값으로 되돌린 뒤 다시 더합니다. 스택이 늘어도 누적 오차가 없습니다.
	for stock: BallStock in stocks:
		if stock == null:
			continue
		runtime.set_value(stock, &"count", runtime.get_baseline(stock, &"count"))

	var room := maxi(RelicRuntime.MAX_LIFE_SLOTS - base_total, 0)
	var extra := mini(balls_per_stack * maxi(stack_count, 0), room)
	if extra <= 0:
		return false

	var target_index := _find_target_index(stocks)
	if target_index < 0:
		return false
	var target_stock: BallStock = stocks[target_index]
	runtime.set_value(
		target_stock,
		&"count",
		int(runtime.get_baseline(target_stock, &"count")) + extra
	)
	return true


func describe(stack_count: int = 1) -> String:
	return "다음 웨이브 시작 공 +%d (최대 %d개)" % [
		balls_per_stack * maxi(stack_count, 1),
		RelicRuntime.MAX_LIFE_SLOTS,
	]


func _find_target_index(stocks: Array[BallStock]) -> int:
	if not target_ball_id.is_empty():
		for index in stocks.size():
			var stock: BallStock = stocks[index]
			if stock != null \
					and stock.definition != null \
					and stock.definition.ball_id == target_ball_id:
				return index
	for index in stocks.size():
		if stocks[index] != null:
			return index
	return -1
