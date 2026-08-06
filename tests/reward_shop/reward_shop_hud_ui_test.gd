extends SceneTree


## reward_scene_ui.pen을 적용한 실제 상점 HUD 구조와 상태 표현 테스트입니다.


const CATALOG := preload("res://settings/reward_shop/RewardShopCatalog_Stage01.tres")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
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

	var layer := CanvasLayer.new()
	holder.add_child(layer)
	var hud := RewardShopHud.new()
	layer.add_child(hud)
	await process_frame

	_expect(shop.bind(wallet, inventory), "상점 컨트롤러가 연결되어야 한다.")
	_expect(hud.bind(shop, wallet, inventory), "상점 HUD가 연결되어야 한다.")
	wallet.add(24)
	hud.set_wave_summary(0, 22, 2)
	_expect(shop.open_shop(0, 0), "상점이 열려야 한다.")
	await process_frame

	_expect(hud.visible, "상점이 열리면 HUD가 보여야 한다.")
	_expect(hud.get_node_or_null("ShopBackdrop") is TextureRect,
		"전체 화면 커튼 배경이 있어야 한다.")
	_expect(hud.get_node_or_null("ShopBackdropShade") is ColorRect,
		"배경 명도 조절 레이어가 있어야 한다.")
	_expect(hud.get_node_or_null("ShopSafeMargin/ShopPanel") is PanelContainer,
		"안전 여백 안에 보상 패널이 있어야 한다.")
	_expect(hud.get_card_count() == 6, "공 3장과 부품 3장이 보여야 한다.")
	_expect(
		hud.find_children("OfferArt", "Control", true, false).size() == 6,
		"모든 카드에 공 또는 부품 아트가 있어야 한다."
	)
	_expect(hud.find_child("*Detail*", true, false) == null,
		"하단 설명 노드는 없어야 한다.")
	_expect(not _has_control_guide(hud), "조작키 가이드 문구는 없어야 한다.")

	var proceed := hud.find_child("ProceedButton", true, false) as Button
	_expect(proceed != null, "다음 단계 버튼이 있어야 한다.")
	if proceed != null:
		_expect(proceed.text == "구매 없이 진행",
			"초기 버튼은 구매 없이 진행이어야 한다.")

	var cards := hud.find_children("OfferCard*", "Button", true, false)
	_expect(cards.size() == 6, "상호작용 가능한 카드 버튼이 6개여야 한다.")
	if not cards.is_empty():
		(cards[0] as Button).pressed.emit()
		_expect(_state_texts(hud).has("선택됨"),
			"카드 선택 시 선택됨 배지가 보여야 한다.")
		(cards[0] as Button).pressed.emit()
		await process_frame
		var states_after_ball := _state_texts(hud)
		_expect(states_after_ball.has("보유 · 구매 완료"),
			"공 구매 카드에 구매 완료가 표시되어야 한다.")
		_expect(states_after_ball.count("행 잠금") >= 2,
			"공 구매 후 같은 행의 다른 두 장이 잠겨야 한다.")
		if proceed != null:
			_expect(proceed.text == "다음 단계",
				"한 카테고리 구매 후 다음 단계 문구가 보여야 한다.")

	var part_index := -1
	for offer_index in shop.part_offers.size():
		if shop.can_buy_part(offer_index):
			part_index = offer_index
			break
	if part_index >= 0:
		_expect(shop.buy_part(part_index), "구매 가능한 부품 구매가 성공해야 한다.")
		await process_frame
		_expect(_state_texts(hud).any(func(text: String) -> bool:
			return text.contains("재고 +") and text.contains("구매 완료")
		), "부품 카드에 재고 증가와 구매 완료가 표시되어야 한다.")
		if proceed != null:
			_expect(proceed.text == "다음 웨이브 준비",
				"두 카테고리 구매 후 다음 웨이브 준비가 보여야 한다.")

	holder.queue_free()
	await process_frame
	_finish()


func _state_texts(hud: RewardShopHud) -> Array[String]:
	var texts: Array[String] = []
	for node in hud.find_children("StateLabel", "Label", true, false):
		texts.append((node as Label).text)
	return texts


func _has_control_guide(hud: RewardShopHud) -> bool:
	for node in hud.find_children("*", "Label", true, false):
		var text := (node as Label).text
		if text.contains("카드 이동") or text.contains("A /") \
				or text.contains("B:") or text.contains("←/→"):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: reward_shop_hud_ui_test")
		quit(0)
		return
	print("FAIL: reward_shop_hud_ui_test (%d failures)" % _failures.size())
	quit(1)
