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
var _recovery_overlay: Control
var _recovery_message: Label


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
	if _wallet == null or _stage_ball_inventory == null or _part_inventory == null:
		_show_recovery(
			"보상 데이터를 불러오지 못했습니다.\n계속 버튼을 눌러 다음 단계로 이동해 주세요."
		)
		push_error("Stage reward shop requires all persistent inventories.")
		return
	if shop_catalog == null:
		_show_recovery(
			"보상 설정을 불러오지 못했습니다.\n계속 버튼을 눌러 다음 단계로 이동해 주세요."
		)
		push_error("Stage reward shop requires RewardShopCatalog.")
		return

	shop_controller = RewardShopController.new()
	shop_controller.name = "RewardShopController"
	shop_controller.catalog = shop_catalog.duplicate(true) as RewardShopCatalog
	shop_controller.stage_id = stage_id
	shop_controller.random_seed = random_seed
	add_child(shop_controller)
	var controller_bound := shop_controller.bind(_wallet, _part_inventory)
	if not controller_bound:
		_show_recovery(
			"보상 상점을 준비하지 못했습니다.\n계속 버튼을 눌러 다음 단계로 이동해 주세요."
		)
		push_error("Stage reward controller could not bind persistent inventories.")
		return
	shop_controller.reset_unlocked_balls(_stage_ball_inventory.unlocked_ids)
	shop_controller.ball_unlocked.connect(_on_ball_unlocked)

	shop_hud = RewardShopHud.new()
	shop_hud.name = "RewardShopHud"
	add_child(shop_hud)
	var hud_bound := shop_hud.bind(shop_controller, _wallet, _part_inventory)
	if not hud_bound:
		_show_recovery(
			"보상 화면을 표시하지 못했습니다.\n계속 버튼을 눌러 다음 단계로 이동해 주세요."
		)
		push_error("Stage reward HUD could not bind the reward controller.")
		return
	shop_hud.proceed_requested.connect(_on_proceed_requested)
	_open_shop_if_ready()


## 테스트·자동 진행에서 실제 확인 완료와 같은 경로를 호출합니다.
func continue_stage() -> bool:
	if _completed:
		return false
	if _recovery_overlay != null and _recovery_overlay.visible:
		_complete_reward()
		return true
	if shop_controller == null or not shop_controller.is_open:
		return false
	_complete_reward()
	return true


func _open_shop_if_ready() -> void:
	if not _configured or not is_node_ready() or shop_controller == null \
			or shop_hud == null \
			or shop_controller.is_open:
		return
	shop_hud.set_wave_summary(_wave_index, 0, 0)
	shop_hud.set_reward_destination(_destination_text, _total_wave_count)
	if not shop_controller.open_shop(_wave_index, _wave_index):
		push_error("Stage reward shop could not open for wave %d." % (_wave_index + 1))
		_show_recovery(
			"보상 목록을 열지 못했습니다.\n계속 버튼을 눌러 다음 단계로 이동해 주세요."
		)


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
	_complete_reward()


func _complete_reward() -> void:
	if _completed:
		return
	_completed = true
	if shop_controller != null and shop_controller.is_open:
		shop_controller.close_shop()
	reward_completed.emit()


func _show_recovery(message: String) -> void:
	if _recovery_overlay == null:
		_build_recovery_overlay()
	_recovery_message.text = message
	_recovery_overlay.visible = true
	_recovery_overlay.move_to_front()


func _build_recovery_overlay() -> void:
	_recovery_overlay = ColorRect.new()
	_recovery_overlay.name = "RewardRecoveryOverlay"
	_recovery_overlay.color = Color(0.06, 0.08, 0.12, 0.96)
	_recovery_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_recovery_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_recovery_overlay)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recovery_overlay.add_child(center)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(520.0, 0.0)
	content.add_theme_constant_override(&"separation", 24)
	center.add_child(content)

	var title := Label.new()
	title.text = "보상 화면 오류"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 36)
	content.add_child(title)

	_recovery_message = Label.new()
	_recovery_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recovery_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_message.add_theme_font_size_override(&"font_size", 22)
	content.add_child(_recovery_message)

	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "다음 단계 계속"
	continue_button.custom_minimum_size = Vector2(0.0, 64.0)
	continue_button.add_theme_font_size_override(&"font_size", 24)
	continue_button.pressed.connect(_complete_reward)
	content.add_child(continue_button)
