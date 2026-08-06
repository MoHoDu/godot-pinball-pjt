class_name RewardPartInventory
extends Node


## 수량형 수리 부품 인벤토리입니다. (기획서 8-1, 10-2)
##
## 랭크가 없으므로 부품 종류별 정수 수량만 저장합니다.
## 배치·소비는 배치 단계에서 다루고, 여기는 보관과 가감만 합니다.
##
## main 의 board_system/RepairPartInventory(예약·용량 기반)와는 별개 구현입니다.
## class_name 충돌만 피하려고 이름을 분리해 두었고, 두 시스템 통합은 별도 과제입니다.


signal part_count_changed(part_id: StringName, count: int)


var _counts: Dictionary = {}


var total_count: int:
	get:
		var sum := 0
		for part_id: StringName in _counts:
			sum += _counts[part_id]
		return sum


func count_of(part_id: StringName) -> int:
	return int(_counts.get(part_id, 0))


## 구매·이월로 수량을 더합니다. 초기 버전은 수량 상한이 없습니다(8-1).
func add(part_id: StringName, amount: int) -> int:
	if part_id == &"" or amount <= 0:
		return count_of(part_id)
	_counts[part_id] = count_of(part_id) + amount
	part_count_changed.emit(part_id, _counts[part_id])
	return _counts[part_id]


## 배치 확정 소비에 씁니다. 재고가 모자라면 실패합니다.
func try_consume(part_id: StringName, amount: int) -> bool:
	if amount <= 0 or count_of(part_id) < amount:
		return false
	_counts[part_id] -= amount
	if _counts[part_id] <= 0:
		_counts.erase(part_id)
	part_count_changed.emit(part_id, count_of(part_id))
	return true


## 스테이지 진입 스냅샷용 복사본입니다(10-1).
func snapshot() -> Dictionary:
	return _counts.duplicate()


func restore(counts: Dictionary) -> void:
	_counts = counts.duplicate()
	for part_id: StringName in _counts:
		part_count_changed.emit(part_id, _counts[part_id])
