extends SceneTree


## 보상 상점 코어(후보 생성·구매 가능성 보장·구매 처리) 테스트입니다.


const CATALOG := preload("res://settings/reward_shop/RewardShopCatalog_Stage01.tres")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_catalog_data()
	_test_ball_generation()
	_test_part_generation()
	_test_affordability_guard()
	await _test_purchase_flow()
	_finish()


func _test_catalog_data() -> void:
	var catalog := CATALOG as RewardShopCatalog
	_expect(catalog.ball_offers.size() == 5, "공 카드는 5종이어야 한다.")
	_expect(catalog.part_offers.size() == 4, "부품 카드는 4종이어야 한다.")

	# 기획서 4-2·4-3 가격표 검증.
	var ball_prices := {}
	for ball in catalog.ball_offers:
		ball_prices[ball.ball_id] = ball.price
	_expect(ball_prices == {
		&"clockwork": 13, &"rubber": 14, &"gel": 11,
		&"lead": 9, &"hollow_bell": 9,
	}, "공 가격이 기획서 4-2와 같아야 한다. (%s)" % ball_prices)

	var part_data := {}
	for part in catalog.part_offers:
		part_data[part.part_id] = [part.bundle_count, part.price]
	_expect(part_data == {
		&"starlight_brooch": [1, 11], &"golden_gears": [2, 12],
		&"crescent_needle": [2, 10], &"forgotten_star_bell": [3, 9],
	}, "부품 수량·가격이 기획서 4-3과 같아야 한다. (%s)" % part_data)

	_expect(
		catalog.cheapest_ball_price() + catalog.cheapest_part_price() == 18,
		"최저가 조합은 18코인이어야 한다(6-4 기준)."
	)


func _test_ball_generation() -> void:
	var catalog := CATALOG as RewardShopCatalog
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804

	# 보상 1: 좋은·중간·하드코어 각 1장.
	var none_unlocked: Array[StringName] = []
	var first := RewardOfferGenerator.generate_ball_offers(
		catalog, none_unlocked, 0, rng
	)
	_expect(first.size() == 3, "보상 1 공 후보는 3장이어야 한다.")
	var groups: Array[int] = []
	for offer in first:
		if not groups.has(offer.performance_group):
			groups.append(offer.performance_group)
	_expect(groups.size() == 3, "보상 1은 세 성능 계열이 모두 나와야 한다.")
	_expect(_ids_unique(first), "같은 공이 두 번 나오면 안 된다.")

	# 같은 시드는 같은 결과.
	var rng_repeat := RandomNumberGenerator.new()
	rng_repeat.seed = 20260804
	var repeat := RewardOfferGenerator.generate_ball_offers(
		catalog, none_unlocked, 0, rng_repeat
	)
	_expect(
		_ball_ids(first) == _ball_ids(repeat),
		"같은 시드는 같은 후보를 내야 한다."
	)

	# 해금한 공은 후보에서 빠진다.
	var unlocked: Array[StringName] = [&"rubber", &"clockwork"]
	for _attempt in 10:
		var offers := RewardOfferGenerator.generate_ball_offers(
			catalog, unlocked, 1, rng
		)
		for offer in offers:
			_expect(
				not unlocked.has(offer.ball_id),
				"해금한 공 %s이 후보에 나오면 안 된다." % offer.ball_id
			)

	# 미해금이 정확히 3개 남으면 셋 다 보여준다.
	var offers_three := RewardOfferGenerator.generate_ball_offers(
		catalog, unlocked, 2, rng
	)
	_expect(
		offers_three.size() == 3 and _ids_unique(offers_three),
		"미해금 3개가 남으면 세 종류를 모두 표시해야 한다."
	)

	# 보상 2 이후는 가능하면 두 개 이상의 계열을 포함한다.
	var one_unlocked: Array[StringName] = [&"rubber"]
	for _attempt in 6:
		var later := RewardOfferGenerator.generate_ball_offers(
			catalog, one_unlocked, 1, rng
		)
		var later_groups: Array[int] = []
		for offer in later:
			if not later_groups.has(offer.performance_group):
				later_groups.append(offer.performance_group)
		_expect(
			later_groups.size() >= 2,
			"보상 2 이후에는 두 개 이상의 성능 계열이 나와야 한다."
		)


func _test_part_generation() -> void:
	var catalog := CATALOG as RewardShopCatalog
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804

	for _attempt in 10:
		var first := RewardOfferGenerator.generate_part_offers(catalog, 0, rng)
		_expect(first.size() == 3, "부품 후보는 3장이어야 한다.")
		_expect(_part_ids_unique(first), "같은 부품이 두 번 나오면 안 된다.")
		var has_standalone := false
		for offer in first:
			if offer.works_standalone:
				has_standalone = true
		_expect(has_standalone, "보상 1에는 단독 동작 부품이 최소 1장 있어야 한다.")

	for _attempt in 10:
		var later := RewardOfferGenerator.generate_part_offers(catalog, 1, rng)
		var has_partner := false
		for offer in later:
			if offer.needs_partner:
				has_partner = true
		_expect(has_partner, "보상 2 이후에는 연결형 부품이 최소 1장 있어야 한다.")


func _test_affordability_guard() -> void:
	var catalog := CATALOG as RewardShopCatalog
	var no_unlocked: Array[StringName] = []

	# 비싼 조합만 나온 화면을 인위로 만든다: 공 13·14, 부품 11·12.
	var expensive_balls: Array[RewardBallOffer] = [
		_find_ball(catalog, &"clockwork"), _find_ball(catalog, &"rubber"),
	]
	var expensive_parts: Array[RepairPartOffer] = [
		_find_part(catalog, &"starlight_brooch"), _find_part(catalog, &"golden_gears"),
	]

	# 지갑 18: 보정 후 살 수 있는 쌍이 반드시 생겨야 한다.
	var balls := expensive_balls.duplicate()
	var parts := expensive_parts.duplicate()
	var guaranteed := RewardOfferGenerator.ensure_affordable_pair(
		balls, parts, catalog, no_unlocked, 18
	)
	_expect(guaranteed, "지갑 18이면 보정 후 구매 가능한 쌍이 있어야 한다.")
	_expect(
		RewardOfferGenerator.has_affordable_pair(balls, parts, 18),
		"보정 결과가 실제로 18코인 안에 있어야 한다."
	)

	# 지갑 17: 기준 미만이면 보정을 강제하지 않는다.
	var balls_17 := expensive_balls.duplicate()
	var parts_17 := expensive_parts.duplicate()
	RewardOfferGenerator.ensure_affordable_pair(
		balls_17, parts_17, catalog, no_unlocked, 17
	)
	_expect(
		_ball_ids(balls_17) == _ball_ids(expensive_balls),
		"지갑이 18 미만이면 후보를 바꾸지 않아야 한다."
	)

	# 이미 살 수 있으면 후보를 건드리지 않는다.
	var cheap_balls: Array[RewardBallOffer] = [_find_ball(catalog, &"lead")]
	var cheap_parts: Array[RepairPartOffer] = [
		_find_part(catalog, &"forgotten_star_bell")
	]
	RewardOfferGenerator.ensure_affordable_pair(
		cheap_balls, cheap_parts, catalog, no_unlocked, 20
	)
	_expect(
		cheap_balls[0].ball_id == &"lead"
			and cheap_parts[0].part_id == &"forgotten_star_bell",
		"이미 구매 가능한 화면은 보정하지 않아야 한다."
	)


func _test_purchase_flow() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var wallet := CoinWallet.new()
	holder.add_child(wallet)
	var inventory := RepairPartInventory.new()
	holder.add_child(inventory)
	var shop := RewardShopController.new()
	shop.catalog = CATALOG
	shop.random_seed = 20260804
	holder.add_child(shop)
	await process_frame

	_expect(shop.bind(wallet, inventory), "지갑·인벤토리 연결은 성공해야 한다.")
	wallet.add(24)

	var purchases: Array = []
	shop.reward_card_purchased.connect(
		func(category: StringName, item_id: StringName, price: int,
				bundle: int, after: int) -> void:
			purchases.append([category, item_id, price, bundle, after])
	)

	_expect(shop.open_shop(0, 0), "상점은 열려야 한다.")
	_expect(not shop.open_shop(0, 0), "이미 열린 상점은 다시 열 수 없다.")
	_expect(shop.ball_offers.size() == 3, "공 카드 3장이 나와야 한다.")
	_expect(shop.part_offers.size() == 3, "부품 카드 3장이 나와야 한다.")

	# 살 수 있는 공을 찾아 산다.
	var ball_index := -1
	for offer_index in shop.ball_offers.size():
		if shop.can_buy_ball(offer_index):
			ball_index = offer_index
			break
	_expect(ball_index >= 0, "지갑 24로 살 수 있는 공이 있어야 한다.")
	var ball_price := shop.ball_offers[ball_index].price
	var bought_ball_id := shop.ball_offers[ball_index].ball_id
	_expect(shop.buy_ball(ball_index), "공 구매는 성공해야 한다.")
	_expect(wallet.balance == 24 - ball_price, "공 가격만큼 차감돼야 한다.")
	_expect(
		shop.unlocked_ball_ids.has(bought_ball_id),
		"구매한 공은 해금 목록에 들어가야 한다."
	)
	_expect(not shop.buy_ball(ball_index), "공 행은 화면당 한 번만 살 수 있다.")
	_expect(not shop.can_buy_ball(ball_index), "구매 후 공 행은 비활성이어야 한다.")

	# 부품 구매.
	var part_index := -1
	for offer_index in shop.part_offers.size():
		if shop.can_buy_part(offer_index):
			part_index = offer_index
			break
	if part_index >= 0:
		var part_offer := shop.part_offers[part_index]
		var wallet_before := wallet.balance
		_expect(shop.buy_part(part_index), "부품 구매는 성공해야 한다.")
		_expect(
			wallet.balance == wallet_before - part_offer.price,
			"부품 가격만큼 차감돼야 한다."
		)
		_expect(
			inventory.count_of(part_offer.part_id) == part_offer.bundle_count,
			"묶음 수량만큼 재고가 늘어야 한다."
		)
		_expect(not shop.buy_part(part_index), "부품 행도 화면당 한 번만 산다.")
	_expect(purchases.size() == (2 if part_index >= 0 else 1),
		"구매 이벤트 수가 맞아야 한다.")

	shop.close_shop()
	_expect(not shop.is_open, "닫힌 상점은 is_open이 꺼져야 한다.")
	_expect(not shop.buy_ball(0), "닫힌 상점에서는 살 수 없다.")

	# 다음 보상: 해금한 공은 후보에서 빠지고, 부품은 다시 살 수 있다.
	wallet.reset(24)
	_expect(shop.open_shop(1, 1), "다음 보상 화면이 열려야 한다.")
	for offer in shop.ball_offers:
		_expect(
			offer.ball_id != bought_ball_id,
			"해금한 공 %s은 다음 후보에서 빠져야 한다." % bought_ball_id
		)
	var repurchase_index := -1
	for offer_index in shop.part_offers.size():
		if shop.can_buy_part(offer_index):
			repurchase_index = offer_index
			break
	_expect(repurchase_index >= 0, "부품은 다음 화면에서 다시 살 수 있어야 한다.")

	# 잔액 부족 검사: 지갑을 비우면 아무것도 못 산다.
	wallet.reset(0)
	_expect(not shop.can_buy_part(repurchase_index), "코인이 없으면 비활성이어야 한다.")
	_expect(not shop.buy_part(repurchase_index), "코인이 없으면 구매가 실패해야 한다.")
	_expect(inventory.total_count > 0, "실패한 구매는 재고를 바꾸지 않아야 한다.")

	holder.queue_free()
	await process_frame


func _find_ball(catalog: RewardShopCatalog, ball_id: StringName) -> RewardBallOffer:
	for offer in catalog.ball_offers:
		if offer.ball_id == ball_id:
			return offer
	return null


func _find_part(catalog: RewardShopCatalog, part_id: StringName) -> RepairPartOffer:
	for offer in catalog.part_offers:
		if offer.part_id == part_id:
			return offer
	return null


func _ball_ids(offers: Array[RewardBallOffer]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for offer in offers:
		ids.append(offer.ball_id)
	return ids


func _ids_unique(offers: Array[RewardBallOffer]) -> bool:
	var seen: Array[StringName] = []
	for offer in offers:
		if seen.has(offer.ball_id):
			return false
		seen.append(offer.ball_id)
	return true


func _part_ids_unique(offers: Array[RepairPartOffer]) -> bool:
	var seen: Array[StringName] = []
	for offer in offers:
		if seen.has(offer.part_id):
			return false
		seen.append(offer.part_id)
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: reward_shop_core_test")
		quit(0)
		return
	print("FAIL: reward_shop_core_test (%d failures)" % _failures.size())
	quit(1)
