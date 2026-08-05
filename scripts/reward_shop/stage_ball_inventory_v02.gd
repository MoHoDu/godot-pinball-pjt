class_name StageBallInventoryV02
extends StageBallInventory


## v0.2 공 모델용 스테이지 인벤토리입니다. (기획서 7장)
##
## 기존 StageBallInventory는 수정하지 않고 재고 산출만 오버라이드합니다.
## 해금 공은 생명 슬롯을 차지하지 않으므로, 웨이브 재고는 기본 재고(생명 풀)
## 그대로 두고 해금 목록은 종류로만 관리합니다. 보유 한도가 없습니다(7-1).


## 웨이브 재고는 기본 재고(생명 풀)만 씁니다. 해금 공은 슬롯을 차지하지 않습니다.
func build_stock() -> Array[BallStock]:
	return _base_stock.duplicate()


## 상한이 없으므로 해금한 모든 종류를 선택할 수 있습니다(7-1).
func selectable_unlocked_ids() -> Array[StringName]:
	return unlocked_ids


## 스냅샷 복원용 — 해금 목록을 통째로 바꿉니다(10-1 롤백).
func restore_unlocked(ball_ids: Array[StringName]) -> void:
	_unlocked_ids = ball_ids.duplicate()
	unlocked_balls_changed.emit(unlocked_ids)


## 해금 종류의 BallDefinition 목록입니다. WaveBallInventoryV02에 넘깁니다.
func unlocked_definitions() -> Array[BallDefinition]:
	var definitions: Array[BallDefinition] = []
	if scene_map == null:
		return definitions
	for ball_id in _unlocked_ids:
		var definition := scene_map.make_definition(ball_id)
		if definition != null:
			definitions.append(definition)
	return definitions
