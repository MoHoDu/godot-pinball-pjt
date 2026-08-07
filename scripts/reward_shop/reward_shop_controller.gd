class_name RewardShopController
extends Node


## 보상 상점의 상태와 구매 처리입니다. (기획서 5-4, 6-3, 10-2, 10-3)
##
## UI와 웨이브 연결은 별도 노드가 하고, 여기는 규칙만 다룹니다.
##   - 보상 화면당 공 최대 1장, 수리 부품 최대 1장
##   - 공은 중복 구매 금지(해금 목록 기준), 부품은 중복 구매 가능
##   - 차감과 지급은 같은 호출 안에서 처리하고, 실패하면 거래 전체를 되돌립니다.


signal reward_offers_generated(
	wave_id: int,
	ball_ids: Array[StringName],
	part_ids: Array[StringName],
	wallet: int,
	affordable_pair: bool
)
signal reward_card_purchased(
	category: StringName,
	item_id: StringName,
	price: int,
	bundle_count: int,
	wallet_after: int
)
signal ball_unlocked(ball_id: StringName)
signal shop_opened(wave_id: int)
signal shop_closed(wave_id: int)


const CATEGORY_BALL: StringName = &"ball"
const CATEGORY_PART: StringName = &"part"


@export var catalog: RewardShopCatalog
@export var stage_id: StringName = &"stage_01"

## 0이면 매번 다르게 뽑습니다.
@export var random_seed := 0


var _wallet: CoinWallet
var _part_inventory: RepairPartInventory
var _rng := RandomNumberGenerator.new()

var _is_open := false
var _wave_id := 0
var _reward_index := 0
var _ball_offers: Array[RewardBallOffer] = []
var _part_offers: Array[RepairPartOffer] = []
var _ball_purchase_used := false
var _part_purchase_used := false
var _unlocked_ball_ids: Array[StringName] = []
var _stage_database_applied := false


var is_open: bool:
	get:
		return _is_open

var ball_offers: Array[RewardBallOffer]:
	get:
		return _ball_offers

var part_offers: Array[RepairPartOffer]:
	get:
		return _part_offers

var ball_purchase_used: bool:
	get:
		return _ball_purchase_used

var part_purchase_used: bool:
	get:
		return _part_purchase_used

var unlocked_ball_ids: Array[StringName]:
	get:
		return _unlocked_ball_ids.duplicate()


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()


func bind(wallet: CoinWallet, part_inventory: RepairPartInventory) -> bool:
	if wallet == null or part_inventory == null:
		return false
	_wallet = wallet
	_part_inventory = part_inventory
	return true


## 보상 화면을 엽니다. reward_index는 0부터(보상 1 = 0)입니다.
func open_shop(wave_id: int, reward_index: int) -> bool:
	if _is_open or catalog == null or _wallet == null:
		return false
	_apply_stage_database()
	_is_open = true
	_wave_id = wave_id
	_reward_index = maxi(reward_index, 0)
	_ball_purchase_used = false
	_part_purchase_used = false

	_ball_offers = RewardOfferGenerator.generate_ball_offers(
		catalog, _unlocked_ball_ids, _reward_index, _rng
	)
	_part_offers = RewardOfferGenerator.generate_part_offers(
		catalog, _reward_index, _rng, _owned_part_kinds()
	)
	var affordable := RewardOfferGenerator.ensure_affordable_pair(
		_ball_offers,
		_part_offers,
		catalog,
		_unlocked_ball_ids,
		_wallet.balance,
		_reward_index
	)

	shop_opened.emit(_wave_id)
	reward_offers_generated.emit(
		_wave_id,
		_offer_ball_ids(),
		_offer_part_ids(),
		_wallet.balance,
		affordable
	)
	return true


## 두 카테고리를 모두 구매하지 않아도 언제든 닫을 수 있습니다(5-4 진행 가능).
func close_shop() -> void:
	if not _is_open:
		return
	_is_open = false
	_ball_offers = []
	_part_offers = []
	shop_closed.emit(_wave_id)


## 구매 검사 순서(6-3): 행 사용 여부 → 코인 → 중복 해금 → 차감·지급.
func buy_ball(offer_index: int) -> bool:
	if not _is_open or _ball_purchase_used:
		return false
	if offer_index < 0 or offer_index >= _ball_offers.size():
		return false
	var offer := _ball_offers[offer_index]
	if offer == null or _unlocked_ball_ids.has(offer.ball_id):
		return false
	if not _wallet.try_spend(offer.price):
		return false

	_unlocked_ball_ids.append(offer.ball_id)
	_ball_purchase_used = true
	ball_unlocked.emit(offer.ball_id)
	reward_card_purchased.emit(
		CATEGORY_BALL, offer.ball_id, offer.price, 1, _wallet.balance
	)
	return true


func buy_part(offer_index: int) -> bool:
	if not _is_open or _part_purchase_used:
		return false
	if offer_index < 0 or offer_index >= _part_offers.size():
		return false
	var offer := _part_offers[offer_index]
	if offer == null or _part_inventory == null:
		return false
	if not _wallet.try_spend(offer.price):
		return false

	var count_before := _part_inventory.count_of(offer.part_id)
	var count_after := _part_inventory.add(offer.part_id, offer.bundle_count)
	if count_after != count_before + offer.bundle_count:
		# 지급 실패 시 거래 전체 롤백(6-3 검사 5).
		_wallet.add(offer.price)
		return false
	_part_purchase_used = true
	reward_card_purchased.emit(
		CATEGORY_PART, offer.part_id, offer.price, offer.bundle_count,
		_wallet.balance
	)
	return true


func can_buy_ball(offer_index: int) -> bool:
	if not _is_open or _ball_purchase_used \
			or offer_index < 0 or offer_index >= _ball_offers.size():
		return false
	var offer := _ball_offers[offer_index]
	return offer != null \
		and not _unlocked_ball_ids.has(offer.ball_id) \
		and _wallet.can_afford(offer.price)


func can_buy_part(offer_index: int) -> bool:
	if not _is_open or _part_purchase_used \
			or offer_index < 0 or offer_index >= _part_offers.size():
		return false
	var offer := _part_offers[offer_index]
	return offer != null and _wallet.can_afford(offer.price)


## 스테이지 전환·실패 롤백에서 해금 목록을 통째로 바꿉니다(10-1).
## 인벤토리에 있는 부품 종류 목록입니다. 보스 직전 보상 보장(6-2)에 씁니다.
func _owned_part_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	if _part_inventory == null:
		return kinds
	for part_id: StringName in _part_inventory.snapshot():
		kinds.append(part_id)
	kinds.sort()
	return kinds


func reset_unlocked_balls(next_ids: Array[StringName] = []) -> void:
	_unlocked_ball_ids = next_ids.duplicate()


func _apply_stage_database() -> void:
	if _stage_database_applied:
		return
	var repository := get_node_or_null(
		"/root/StageDataRepository"
	) as StageRewardRepository
	if repository == null:
		return
	_stage_database_applied = repository.apply_to_catalog(stage_id, catalog)


func _offer_ball_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for offer in _ball_offers:
		ids.append(offer.ball_id if offer != null else &"")
	return ids


func _offer_part_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for offer in _part_offers:
		ids.append(offer.part_id if offer != null else &"")
	return ids
