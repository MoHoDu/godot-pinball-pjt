class_name StageRewardShopScreen
extends Control


## StageFlowManager가 웨이브 사이에 교체해 표시하는 실제 보상 상점 화면입니다.
## 보상 브랜치의 컨트롤러와 HUD를 그대로 사용하고, 코인·공·부품 상태만
## 스테이지 매니저가 소유한 런타임에 연결합니다.


signal reward_completed


const DEFAULT_CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)
const DEFAULT_BALL_SCENE_MAP := preload(
	"res://settings/reward_shop/RewardBallSceneMap_Stage01.tres"
)


@export var stage_id: StringName = &"stage_01"
@export var shop_catalog: RewardShopCatalog = DEFAULT_CATALOG
@export var ball_scene_map: RewardBallSceneMap = DEFAULT_BALL_SCENE_MAP
@export var random_seed := 0


var shop_controller: RewardShopController
var shop_hud: RewardShopHud

var _wallet: CoinWallet
var _stage_ball_inventory: StageBallInventory
var _part_inventory: RepairPartInventory
var _wave_index := -1
var _total_wave_count := 0
var _destination_text := ""
var _configured := false
var _completed := false


func bind_coin_wallet(wallet: CoinWallet) -> bool:
	if wallet == null or is_inside_tree():
		return false
	_wallet = wallet
	return true


func bind_stage_reward_runtime(
	wallet: CoinWallet,
	stage_ball_inventory: StageBallInventory,
	part_inventory: RepairPartInventory
) -> bool:
	if wallet == null or stage_ball_inventory == null \
			or part_inventory == null or is_inside_tree():
		return false
	_wallet = wallet
	_stage_ball_inventory = stage_ball_inventory
	_part_inventory = part_inventory
	return true


func configure_reward(
	wave_index: int,
	total_wave_count: int,
	destination_text: String
) -> void:
	_wave_index = wave_index
	_total_wave_count = total_wave_count
	_destination_text = destination_text
	_configured = true
	_open_shop_if_ready()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assert(_wallet != null, "Stage reward shop requires the stage CoinWallet.")
	assert(_stage_ball_inventory != null,
		"Stage reward shop requires StageBallInventory.")
	assert(_part_inventory != null,
		"Stage reward shop requires RepairPartInventory.")
	if _wallet == null or _stage_ball_inventory == null or _part_inventory == null:
		return

	shop_controller = RewardShopController.new()
	shop_controller.name = "RewardShopController"
	shop_controller.catalog = shop_catalog.duplicate(true) as RewardShopCatalog
	shop_controller.stage_id = stage_id
	shop_controller.random_seed = random_seed
	add_child(shop_controller)
	assert(shop_controller.bind(_wallet, _part_inventory),
		"Stage reward controller could not bind persistent inventories.")
	shop_controller.reset_unlocked_balls(_stage_ball_inventory.unlocked_ids)
	shop_controller.ball_unlocked.connect(_on_ball_unlocked)

	shop_hud = RewardShopHud.new()
	shop_hud.name = "RewardShopHud"
	add_child(shop_hud)
	assert(shop_hud.bind(shop_controller, _wallet, _part_inventory),
		"Stage reward HUD could not bind the reward controller.")
	shop_hud.proceed_requested.connect(_on_proceed_requested)
	_open_shop_if_ready()


## 테스트·자동 진행에서 실제 확인 완료와 같은 경로를 호출합니다.
func continue_stage() -> bool:
	if shop_controller == null or not shop_controller.is_open or _completed:
		return false
	_on_proceed_requested()
	return true


func _open_shop_if_ready() -> void:
	if not _configured or not is_node_ready() or shop_controller == null \
			or shop_controller.is_open:
		return
	shop_hud.set_wave_summary(_wave_index, 0, 0)
	shop_hud.set_reward_destination(_destination_text, _total_wave_count)
	if not shop_controller.open_shop(_wave_index, _wave_index):
		push_error("Stage reward shop could not open for wave %d." % (_wave_index + 1))


func _on_ball_unlocked(ball_id: StringName) -> void:
	if _stage_ball_inventory.unlock(ball_id):
		return
	var refund := 0
	for offer: RewardBallOffer in shop_controller.catalog.ball_offers:
		if offer != null and offer.ball_id == ball_id:
			refund = offer.price
			break
	if refund > 0:
		_wallet.add(refund)
	var unlocked_ids := shop_controller.unlocked_ball_ids
	unlocked_ids.erase(ball_id)
	shop_controller.reset_unlocked_balls(unlocked_ids)
	push_error("Stage reward ball unlock failed and was refunded: %s" % ball_id)


func _on_proceed_requested() -> void:
	if shop_controller == null or not shop_controller.is_open or _completed:
		return
	_completed = true
	shop_controller.close_shop()
	reward_completed.emit()
