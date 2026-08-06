class_name StageBallInventory
extends Node


## 스테이지 동안 해금한 공 목록을 들고, 다음 웨이브의 공 재고를 만듭니다.
## (기획서 7장, 10-2 StageBallInventory)
##
## 공은 매 발사 전에 바꿀 수 있어야 하므로, 기본 공 재고(생명 슬롯)에
## 해금한 보상 공을 선택지로 얹습니다. 웨이브 시스템의 생명 슬롯이 3~5개로
## 제한되므로(WaveRuntimeCoordinator 검사), 총 슬롯은 MAX_LIFE_SLOTS로 막습니다.
##
## ※ 기획서 7-1은 "해금 공 무제한 선택"이지만, 현재 엔진은 공 종류와 생명
##   개수를 한 재고로 묶어 다룹니다. 완전한 무제한 선택은 생명/종류 분리
##   리팩터가 필요하므로, 이 단계에서는 상한 5의 추가 슬롯 모델로 갑니다.


signal unlocked_balls_changed(unlocked_ids: Array[StringName])


const MAX_LIFE_SLOTS := 5


@export var scene_map: RewardBallSceneMap


## 스테이지 시작 시의 기본 공 재고입니다. 여기에 해금 공을 얹습니다.
var _base_stock: Array[BallStock] = []
var _unlocked_ids: Array[StringName] = []


var unlocked_ids: Array[StringName]:
	get:
		return _unlocked_ids.duplicate()


## 스테이지 진입 시 기본 재고를 기억해 둡니다(스냅샷·복원의 기준).
func capture_base_stock(base_stock: Array[BallStock]) -> void:
	_base_stock = base_stock.duplicate()


func base_life_count() -> int:
	var total := 0
	for item in _base_stock:
		if item != null and item.is_valid():
			total += item.count
	return total


## 상점에서 공을 사면 부릅니다. 중복은 무시합니다.
func unlock(ball_id: StringName) -> bool:
	if ball_id == &"" or _unlocked_ids.has(ball_id):
		return false
	if scene_map == null or not scene_map.has_ball(ball_id):
		push_warning("해금할 공의 물리 씬 매핑이 없습니다: %s" % ball_id)
		return false
	_unlocked_ids.append(ball_id)
	unlocked_balls_changed.emit(unlocked_ids)
	return true


## 다음 웨이브에 넣을 재고를 만듭니다. 기본 재고 + 해금 공(각 1개),
## 총 슬롯은 MAX_LIFE_SLOTS까지만 채웁니다.
func build_stock() -> Array[BallStock]:
	var stock: Array[BallStock] = _base_stock.duplicate()
	var slots_used := base_life_count()
	for ball_id in _unlocked_ids:
		if slots_used >= MAX_LIFE_SLOTS:
			break
		var definition := scene_map.make_definition(ball_id)
		if definition == null:
			continue
		var reward_stock := BallStock.new()
		reward_stock.definition = definition
		reward_stock.count = 1
		stock.append(reward_stock)
		slots_used += 1
	return stock


## 이번 재고에 실제로 들어갈 수 있는(상한에 걸리지 않은) 해금 공만 반환합니다.
func selectable_unlocked_ids() -> Array[StringName]:
	var available := MAX_LIFE_SLOTS - base_life_count()
	var ids: Array[StringName] = []
	for ball_id in _unlocked_ids:
		if ids.size() >= available:
			break
		ids.append(ball_id)
	return ids


## 스테이지 클리어·다음 스테이지: 구매 공을 비우고 기본 공만 남깁니다(10-1).
func reset_to_base() -> void:
	if _unlocked_ids.is_empty():
		return
	_unlocked_ids.clear()
	unlocked_balls_changed.emit(unlocked_ids)
