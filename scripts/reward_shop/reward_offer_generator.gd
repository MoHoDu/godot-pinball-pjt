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
	rng: RandomNumberGenerator,
	current_stage_num: int = 1
) -> Array[RewardBallOffer]:
	var pool: Array[RewardBallOffer] = []
	for offer in catalog.ball_offers:
		if offer == null or not offer.is_valid():
			continue
		if unlocked_ids.has(offer.ball_id):
			continue
		if not _is_available_for_reward(offer, reward_index, current_stage_num):
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


## 스테이지 01 기준으로 이 보상 인덱스부터 "보스 직전 보상"입니다(6-2).
const BOSS_REWARD_INDEX := 2


## 부품 후보 3장을 뽑습니다. 네 종류 중 서로 다른 3종.
##
## - reward_index 0(보상 1): 단독 동작 부품(works_standalone) 최소 1장,
##   연결 필수 부품이 단독 필수처럼 보이지 않게 합니다.
## - 이후: 연결형 부품(needs_partner) 최소 1장.
## - 보스 직전 보상: 보유 부품(owned_part_ids)과 결합해 보스전에서 실제로
##   쓸 수 있는 카드가 최소 1장 있도록 보장합니다(6-2).
static func generate_part_offers(
	catalog: RewardShopCatalog,
	reward_index: int,
	rng: RandomNumberGenerator,
	owned_part_ids: Array[StringName] = [],
	current_stage_num: int = 1
) -> Array[RepairPartOffer]:
	var pool: Array[RepairPartOffer] = []
	for offer in catalog.part_offers:
		if offer != null \
				and offer.is_valid() \
				and _is_available_for_reward(
					offer, reward_index, current_stage_num
				):
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
		if reward_index >= BOSS_REWARD_INDEX \
				and not _has_boss_usable(picked, owned_part_ids):
			continue
		return picked

	# 시도 초과 시에도 보스 직전 보장은 강제합니다(카드 1장 교체).
	var fallback := _pick_random_parts(pool, 3, rng)
	if reward_index >= BOSS_REWARD_INDEX \
			and not _has_boss_usable(fallback, owned_part_ids):
		for offer in pool:
			if _offer_boss_usable(offer, owned_part_ids) \
					and not fallback.has(offer):
				fallback[fallback.size() - 1] = offer
				break
	return fallback


## 보유 부품과 결합했을 때 보스전에서 실제로 발동 가능한 카드인지 봅니다(6-2).
static func _offer_boss_usable(
	offer: RepairPartOffer,
	owned_part_ids: Array[StringName]
) -> bool:
	if offer.works_standalone:
		return true
	var partner_kinds := 0
	for owned_id in owned_part_ids:
		if owned_id != offer.part_id:
			partner_kinds += 1
	return partner_kinds >= maxi(offer.required_partner_kinds, 1)


static func _has_boss_usable(
	offers: Array[RepairPartOffer],
	owned_part_ids: Array[StringName]
) -> bool:
	for offer in offers:
		if _offer_boss_usable(offer, owned_part_ids):
			return true
	return false


## 구매 가능성 검사(6-4). 지갑이 18코인 이상인데 살 수 있는
## "공 1 + 부품 1" 쌍이 없으면, 카드 한 장을 최저가로 바꿔 조합을 보정합니다.
## 보정 후보가 화면과 겹치면 그대로 둡니다(중복 금지 우선).
static func ensure_affordable_pair(
	ball_offers: Array[RewardBallOffer],
	part_offers: Array[RepairPartOffer],
	catalog: RewardShopCatalog,
	unlocked_ids: Array[StringName],
	wallet_balance: int,
	reward_index: int = 0,
	current_stage_num: int = 1
) -> bool:
	if wallet_balance < AFFORDABLE_GUARD_MIN_WALLET:
		return has_affordable_pair(ball_offers, part_offers, wallet_balance)
	if has_affordable_pair(ball_offers, part_offers, wallet_balance):
		return true

	# 최저가 공으로 교체를 시도합니다.
	var cheapest_ball := _cheapest_ball_not_shown(
		catalog, unlocked_ids, ball_offers, reward_index, current_stage_num
	)
	if cheapest_ball != null and not ball_offers.is_empty():
		var expensive_index := _most_expensive_ball_index(ball_offers)
		if cheapest_ball.price < ball_offers[expensive_index].price:
			ball_offers[expensive_index] = cheapest_ball
	if has_affordable_pair(ball_offers, part_offers, wallet_balance):
		return true

	# 그래도 안 되면 최저가 부품으로 교체를 시도합니다.
	var cheapest_part := _cheapest_part_not_shown(
		catalog, part_offers, reward_index, current_stage_num
	)
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
		var selected := _pick_weighted(candidates, 1, rng)
		if selected.is_empty():
			return []
		picked.append(selected[0])
	return picked


static func _pick_random(
	pool: Array[RewardBallOffer],
	count: int,
	rng: RandomNumberGenerator
) -> Array[RewardBallOffer]:
	var picked: Array[RewardBallOffer] = []
	for offer in _pick_weighted(pool, count, rng):
		picked.append(offer as RewardBallOffer)
	return picked


static func _pick_random_parts(
	pool: Array[RepairPartOffer],
	count: int,
	rng: RandomNumberGenerator
) -> Array[RepairPartOffer]:
	var picked: Array[RepairPartOffer] = []
	for offer in _pick_weighted(pool, count, rng):
		picked.append(offer as RepairPartOffer)
	return picked


## CSV weight를 상대 가중치로 사용하는 비복원 추첨입니다.
static func _pick_weighted(
	pool: Array,
	count: int,
	rng: RandomNumberGenerator
) -> Array:
	var remaining := pool.duplicate()
	var picked: Array = []
	for _pick_index in mini(count, remaining.size()):
		var total_weight := 0.0
		for offer: Variant in remaining:
			total_weight += maxf(float(offer.get(&"weight")), 0.0)
		if total_weight <= 0.0:
			break
		var cursor := rng.randf() * total_weight
		var selected_index := remaining.size() - 1
		for index in remaining.size():
			cursor -= maxf(float(remaining[index].get(&"weight")), 0.0)
			if cursor <= 0.0:
				selected_index = index
				break
		picked.append(remaining[selected_index])
		remaining.remove_at(selected_index)
	return picked


static func _is_available_for_reward(
	offer: Resource,
	reward_index: int,
	current_stage_num: int
) -> bool:
	if not bool(offer.get(&"enabled")) or float(offer.get(&"weight")) <= 0.0:
		return false
	var normalized_index := maxi(reward_index, 0)
	var current_wave_num := mini(normalized_index + 1, 4)
	return StageRewardRepository.is_available_at(
		int(offer.get(&"first_stage_num")),
		int(offer.get(&"first_wave_num")),
		current_stage_num,
		current_wave_num
	)


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
	shown: Array[RewardBallOffer],
	reward_index: int,
	current_stage_num: int
) -> RewardBallOffer:
	var cheapest: RewardBallOffer = null
	for offer in catalog.ball_offers:
		if offer == null \
				or unlocked_ids.has(offer.ball_id) \
				or shown.has(offer) \
				or not _is_available_for_reward(
					offer, reward_index, current_stage_num
				):
			continue
		if cheapest == null or offer.price < cheapest.price:
			cheapest = offer
	return cheapest


static func _cheapest_part_not_shown(
	catalog: RewardShopCatalog,
	shown: Array[RepairPartOffer],
	reward_index: int,
	current_stage_num: int
) -> RepairPartOffer:
	var cheapest: RepairPartOffer = null
	for offer in catalog.part_offers:
		if offer == null \
				or shown.has(offer) \
				or not _is_available_for_reward(
					offer, reward_index, current_stage_num
				):
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
