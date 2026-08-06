class_name WaveShopBallCoordinator
extends WaveShopCoordinator


## 상점에서 산 공을 다음 웨이브의 공 선택지에 얹는 조립자입니다. (기획서 7장)
##
## WaveShopCoordinator(코인+상점)를 상속합니다. 기존 스크립트 수정은 없습니다.
##   - shop_controller.ball_unlocked → StageBallInventory에 해금 기록
##   - 상점을 닫고 다음 웨이브로 넘어가기 직전에 wave_ball_inventory의
##     starting_stock을 기본 재고 + 해금 공으로 다시 만든다.
##     enter_wave(reset_inventory=true)가 start_wave → reset_stock으로
##     starting_stock을 다시 읽으므로 이 시점 교체가 반영된다.
##   - 스테이지 클리어 시 구매 공을 비운다(10-1).


const DEFAULT_SCENE_MAP := preload(
	"res://settings/reward_shop/RewardBallSceneMap_Stage01.tres"
)


@export_category("Wave Shop Ball")

@export var ball_scene_map: RewardBallSceneMap = DEFAULT_SCENE_MAP


var stage_ball_inventory: StageBallInventory


func _ready() -> void:
	super()
	_build_stage_ball_inventory()


func _build_stage_ball_inventory() -> void:
	stage_ball_inventory = StageBallInventory.new()
	stage_ball_inventory.name = "StageBallInventory"
	stage_ball_inventory.scene_map = ball_scene_map
	add_child(stage_ball_inventory)
	# 씬에 박힌 기본 공 재고를 스테이지 기준으로 기억합니다.
	stage_ball_inventory.capture_base_stock(
		wave_ball_inventory.starting_stock
	)
	stage_ball_inventory.unlocked_balls_changed.connect(_on_unlocked_changed)
	shop_controller.ball_unlocked.connect(_on_ball_unlocked)


func _on_ball_unlocked(ball_id: StringName) -> void:
	stage_ball_inventory.unlock(ball_id)


func _on_unlocked_changed(unlocked_ids: Array[StringName]) -> void:
	_append_event(
		"공 해금 · 보유 %d종 (%s)"
		% [unlocked_ids.size(), ", ".join(_names_of(unlocked_ids))]
	)


## 부모의 진행 처리 직전에 다음 웨이브 재고를 갈아끼웁니다.
func _on_shop_proceed() -> void:
	if not shop_controller.is_open:
		return
	wave_ball_inventory.starting_stock = stage_ball_inventory.build_stock()
	super()


## 스테이지 클리어 시 구매 공을 비웁니다. 부모가 STAGE CLEAR를 알린 뒤 처리합니다.
func _open_shop_after_win() -> void:
	super()
	var next_wave_index := wave_manager.current_wave_index + 1
	if not _has_wave(next_wave_index):
		stage_ball_inventory.reset_to_base()
		wave_ball_inventory.starting_stock = stage_ball_inventory.build_stock()


func _names_of(ball_ids: Array[StringName]) -> Array[String]:
	var names: Array[String] = []
	for ball_id in ball_ids:
		if ball_scene_map != null:
			names.append(ball_scene_map.display_name_of(ball_id))
		else:
			names.append(String(ball_id))
	return names
