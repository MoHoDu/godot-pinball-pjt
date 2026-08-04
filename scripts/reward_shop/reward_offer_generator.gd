class_name RewardOfferGenerator
extends RefCounted


## 보상 후보 생성 규칙(기획서 6-1, 6-2)과 구매 가능성 보장(6-4)입니다.
##
## 가격은 절대 바꾸지 않습니다. 살 수 있는 "공 1 + 부품 1" 쌍이 없으면
## 후보 조합만 바꿉니다.


## 구매 가능성 보장을 강제하는 최소 지갑 기준(6-4). 저가 공 9 + 저가 부품 9.
const AFFORDABLE_GUARD_MIN_WALLET := 18


## 공 후보 3장을 뽑습니다.
##
## - 기본 공은 카탈로그에 없으므로 자연히 제외됩니다.
## - 해금한 공은 제외하고, 한 화면에 같은 공이 두 번 나오지 않습니다.
## - reward_index 0(보상 1): 좋은·중간·하드코어 각 1장.
## - 이후: 미해금 중 3장, 가능하면 두 개 이상의 성능 계열 포함.
## - 미해금이 3장 이하로 남으면 남은 전부를 그대로 보여줍니다.
static func generate_ball_offers(
	catalog: RewardShopCatalog,
	unlocked_ids: Array[StringName],
	reward_index: int,
	rng: RandomNumberGenerator
) -> Array[RewardBallOffer]:
	var pool: Array[RewardBallOffer] = []
	for offer in catalog.ball_offers:
		if offer == null or not offer.is_valid():
			continue
		if unlocked_ids.has(offer.ball_id):
			continue
		pool.append(offer)

	if pool.size() <= 3:
		return pool

	if reward_index <= 0:
		var by_group := _pick_one_per_group(pool, rng)
		if by_group.size() == 3:
			return by_group

	# 두 개 이상의 성능 계열이 섞이도록 뽑습니다. 못 채우면 있는 대로 갑니다.
	for _attempt in 8:
		var picked := _pick_random(pool, 3, rng)
		if _distinct_group_count(picked) >= 2:
			return picked
	return _pick_random(pool, 3, rng)


## 부품 후보 3장을 뽑습니다. 네 종류 중 서로 다른 3종.
##
## - reward_index 0(보상 1): 단독 동작 부품(works_standalone) 최소 1장,
##   연결 필수 부품이 단독 필수처럼 보이지 않게 합니다.
## - 이후: 연결형 부품(needs_partner) 최소 1장.
static func generate_part_offers(
	catalog: RewardShopCatalog,
	reward_index: int,
	rng: RandomNumberGenerator
) -> Array[RepairPartOffer]:
	var pool: Array[RepairPartOffer] = []
	for offer in catalog.part_offers:
		if offer != null and offer.is_valid():
			pool.append(offer)
	if pool.size() <= 3:
		return pool

	for _attempt in 8:
		var picked: Array[RepairPartOffer] = []
		for offer in _pick_random_parts(pool, 3, rng):
			picked.append(offer)
		if reward_index <= 0 and not _has_standalone(picked):
			continue
		if reward_index > 0 and not _has_partner_type(picked):
			continue
		return picked
	return _pick_random_parts(pool, 3, rng)


## 구매 가능성 검사(6-4). 지갑이 18코인 이상인데 살 수 있는
## "공 1 + 부품 1" 쌍이 없으면, 카드 한 장을 최저가로 바꿔 조합을 보정합니다.
## 보정 후보가 화면과 겹치면 그대로 둡니다(중복 금지 우선).
static func ensure_affordable_pair(
	ball_offers: Array[RewardBallOffer],
	part_offers: Array[RepairPartOffer],
	catalog: RewardShopCatalog,
	unlocked_ids: Array[StringName],
	wallet_balance: int
) -> bool:
	if wallet_balance < AFFORDABLE_GUARD_MIN_WALLET:
		return has_affordable_pair(ball_offers, part_offers, wallet_balance)
	if has_affordable_pair(ball_offers, part_offers, wallet_balance):
		return true

	# 최저가 공으로 교체를 시도합니다.
	var cheapest_ball := _cheapest_ball_not_shown(
		catalog, unlocked_ids, ball_offers
	)
	if cheapest_ball != null and not ball_offers.is_empty():
		var expensive_index := _most_expensive_ball_index(ball_offers)
		if cheapest_ball.price < ball_offers[expensive_index].price:
			ball_offers[expensive_index] = cheapest_ball
	if has_affordable_pair(ball_offers, part_offers, wallet_balance):
		return true

	# 그래도 안 되면 최저가 부품으로 교체를 시도합니다.
	var cheapest_part := _cheapest_part_not_shown(catalog, part_offers)
	if cheapest_part != null and not part_offers.is_empty():
		var expensive_part_index := _most_expensive_part_index(part_offers)
		if cheapest_part.price < part_offers[expensive_part_index].price:
			part_offers[expensive_part_index] = cheapest_part
	return has_affordable_pair(ball_offers, part_offers, wallet_balance)


static func has_affordable_pair(
	ball_offers: Array[RewardBallOffer],
	part_offers: Array[RepairPartOffer],
	wallet_balance: int
) -> bool:
	for ball in ball_offers:
		for part in part_offers:
			if ball != null and part != null \
					and ball.price + part.price <= wallet_balance:
				return true
	return false


static func _pick_one_per_group(
	pool: Array[RewardBallOffer],
	rng: RandomNumberGenerator
) -> Array[RewardBallOffer]:
	var picked: Array[RewardBallOffer] = []
	for group in [
		RewardBallOffer.PerformanceGroup.GOOD,
		RewardBallOffer.PerformanceGroup.MID,
		RewardBallOffer.PerformanceGroup.HARDCORE,
	]:
		var candidates: Array[RewardBallOffer] = []
		for offer in pool:
			if offer.performance_group == group and not picked.has(offer):
				candidates.append(offer)
		if candidates.is_empty():
			return []
		picked.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return picked


static func _pick_random(
	pool: Array[RewardBallOffer],
	count: int,
	rng: RandomNumberGenerator
) -> Array[RewardBallOffer]:
	var shuffled := pool.duplicate()
	_shuffle_with_rng(shuffled, rng)
	var picked: Array[RewardBallOffer] = []
	for offer_index in mini(count, shuffled.size()):
		picked.append(shuffled[offer_index])
	return picked


static func _pick_random_parts(
	pool: Array[RepairPartOffer],
	count: int,
	rng: RandomNumberGenerator
) -> Array[RepairPartOffer]:
	var shuffled := pool.duplicate()
	_shuffle_with_rng(shuffled, rng)
	var picked: Array[RepairPartOffer] = []
	for offer_index in mini(count, shuffled.size()):
		picked.append(shuffled[offer_index])
	return picked


## Array.shuffle()은 전역 시드를 쓰므로 재현 가능한 rng로 직접 섞습니다.
static func _shuffle_with_rng(items: Array, rng: RandomNumberGenerator) -> void:
	for item_index in range(items.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, item_index)
		var swapped: Variant = items[item_index]
		items[item_index] = items[swap_index]
		items[swap_index] = swapped


static func _distinct_group_count(offers: Array[RewardBallOffer]) -> int:
	var groups: Array[int] = []
	for offer in offers:
		if not groups.has(offer.performance_group):
			groups.append(offer.performance_group)
	return groups.size()


static func _has_standalone(offers: Array[RepairPartOffer]) -> bool:
	for offer in offers:
		if offer.works_standalone:
			return true
	return false


static func _has_partner_type(offers: Array[RepairPartOffer]) -> bool:
	for offer in offers:
		if offer.needs_partner:
			return true
	return false


static func _cheapest_ball_not_shown(
	catalog: RewardShopCatalog,
	unlocked_ids: Array[StringName],
	shown: Array[RewardBallOffer]
) -> RewardBallOffer:
	var cheapest: RewardBallOffer = null
	for offer in catalog.ball_offers:
		if offer == null or unlocked_ids.has(offer.ball_id) or shown.has(offer):
			continue
		if cheapest == null or offer.price < cheapest.price:
			cheapest = offer
	return cheapest


static func _cheapest_part_not_shown(
	catalog: RewardShopCatalog,
	shown: Array[RepairPartOffer]
) -> RepairPartOffer:
	var cheapest: RepairPartOffer = null
	for offer in catalog.part_offers:
		if offer == null or shown.has(offer):
			continue
		if cheapest == null or offer.price < cheapest.price:
			cheapest = offer
	return cheapest


static func _most_expensive_ball_index(offers: Array[RewardBallOffer]) -> int:
	var expensive_index := 0
	for offer_index in offers.size():
		if offers[offer_index].price > offers[expensive_index].price:
			expensive_index = offer_index
	return expensive_index


static func _most_expensive_part_index(offers: Array[RepairPartOffer]) -> int:
	var expensive_index := 0
	for offer_index in offers.size():
		if offers[offer_index].price > offers[expensive_index].price:
			expensive_index = offer_index
	return expensive_index
