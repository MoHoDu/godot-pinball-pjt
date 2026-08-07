class_name WaveShopCoordinator
extends WaveCoinCoordinator


## 유물 3택1을 v0.2 보상 상점으로 교체한 조립자입니다.
##
## WaveCoinCoordinator(코인 경제)를 상속하고, 부모의 유물 구축만
## _build_reward_system() 오버라이드로 비웁니다. 기존 스크립트 수정은 없습니다.
##
## 흐름: wave_won → (유예 정산이 코인을 지갑에 반영) → 상점 열림 →
##       다음 단계 → 다음 웨이브 진입. 마지막 웨이브 뒤에는 상점 없이 스테이지 클리어.


const DEFAULT_SHOP_CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)


@export_category("Wave Shop")

@export var shop_catalog: RewardShopCatalog = DEFAULT_SHOP_CATALOG
@export var shop_stage_id: StringName = &"stage_01"

## 0이면 매번 다르게 뽑습니다.
@export var shop_random_seed := 0


@export_group("디버그")

## 개발용 코인 채우기 키입니다. 빼려면 KEY_NONE으로 두면 됩니다.
@export var debug_fill_coin_key: Key = KEY_C
@export var debug_fill_coin_amount := 999


var part_inventory: RepairPartInventory
var shop_controller: RewardShopController
var shop_hud: RewardShopHud

var _reward_count := 0
var _last_delay_coin := 0


func _ready() -> void:
	super()
	_build_shop_system()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if get_tree().paused or debug_fill_coin_key == KEY_NONE:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != debug_fill_coin_key:
		return
	coin_wallet.reset(debug_fill_coin_amount)
	_append_event("디버그 · 코인 %d 채움" % debug_fill_coin_amount)
	get_viewport().set_input_as_handled()


## 부모(WaveRewardCoordinator)의 유물 보상 구축을 대체합니다. 상점이 그 역할을 맡습니다.
func _build_reward_system() -> void:
	pass


func _build_shop_system() -> void:
	part_inventory = get_node_or_null(^"RepairPartInventory") as RepairPartInventory
	if part_inventory == null:
		part_inventory = RewardShopPartInventory.new()
		part_inventory.name = "RepairPartInventory"
		add_child(part_inventory)

	shop_controller = RewardShopController.new()
	shop_controller.name = "RewardShopController"
	shop_controller.catalog = shop_catalog
	shop_controller.stage_id = shop_stage_id
	shop_controller.random_seed = shop_random_seed
	add_child(shop_controller)
	var bound := shop_controller.bind(coin_wallet, part_inventory)
	assert(bound, "상점 컨트롤러가 지갑·인벤토리에 연결되지 못했습니다.")

	# 기존 HUD 레이어의 변환·배치와 섞이지 않게 전용 레이어에 올립니다.
	var shop_layer := CanvasLayer.new()
	shop_layer.name = "RewardShopLayer"
	shop_layer.layer = 25
	add_child(shop_layer)
	shop_hud = RewardShopHud.new()
	shop_hud.name = "RewardShopHud"
	shop_layer.add_child(shop_hud)
	var hud_bound := shop_hud.bind(shop_controller, coin_wallet, part_inventory)
	assert(hud_bound, "상점 HUD가 컨트롤러에 연결되지 못했습니다.")

	shop_hud.proceed_requested.connect(_on_shop_proceed)
	shop_controller.reward_card_purchased.connect(_on_shop_purchase)
	clear_delay.wave_clear_delay_finished.connect(_on_shop_delay_finished)
	wave_manager.wave_won.connect(_on_shop_wave_won)


## 유예 정산 코인을 상점 헤더에 보여 주려고 기억해 둡니다.
func _on_shop_delay_finished(
	_reason: StringName,
	_clear_delay_score: int,
	clear_delay_coin: int,
	_board_coin: int
) -> void:
	_last_delay_coin = clear_delay_coin


func _on_shop_wave_won(_current_score: int, _target_score: int) -> void:
	# 유예 정산(같은 시그널의 앞 핸들러)이 끝난 뒤에 열도록 지연 호출합니다.
	call_deferred(&"_open_shop_after_win")


func _open_shop_after_win() -> void:
	if wave_manager.current_state != WaveManager.State.WON:
		return
	var next_wave_index := wave_manager.current_wave_index + 1
	if not _has_wave(next_wave_index):
		_append_event("STAGE CLEAR · 수리 완료")
		return
	shop_hud.set_wave_summary(
		wave_manager.current_wave_index,
		coin_field.board_coin_this_wave,
		_last_delay_coin
	)
	if shop_controller.open_shop(wave_manager.current_wave_index, _reward_count):
		_reward_count += 1
		_append_event("REWARD · 코인 %d · 공/부품을 고르세요" % coin_wallet.balance)


func _on_shop_proceed() -> void:
	if not shop_controller.is_open:
		return
	shop_controller.close_shop()
	_last_delay_coin = 0
	# 이전 웨이브 점수가 남은 채 다음 웨이브를 구성하면 목표 재달성 판정으로
	# 진입 즉시 클리어되어 버린다. 새 웨이브 점수는 0에서 시작한다.
	combo_system.reset_wave()
	var next_wave_index := wave_manager.current_wave_index + 1
	if wave_manager.enter_wave(_wave_settings, next_wave_index, true):
		_append_event("WAVE %02d 시작 · 다음 공을 선택하세요" % (next_wave_index + 1))
	else:
		_append_event("REWARD · 다음 웨이브 진입 실패")


func _on_shop_purchase(
	category: StringName,
	item_id: StringName,
	price: int,
	bundle_count: int,
	wallet_after: int
) -> void:
	if category == RewardShopController.CATEGORY_BALL:
		_append_event("구매 · 공 %s · -%d코인 · 잔액 %d" % [item_id, price, wallet_after])
	else:
		_append_event(
			"구매 · 부품 %s x%d · -%d코인 · 잔액 %d"
			% [item_id, bundle_count, price, wallet_after]
		)


func _has_wave(wave_index: int) -> bool:
	if _wave_settings == null:
		return false
	return int(_wave_settings.call(&"get_wave_target_score", wave_index)) > 0
