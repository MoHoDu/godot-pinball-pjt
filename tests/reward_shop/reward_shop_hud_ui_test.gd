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
	_expect(hud.get_node_or_null("CartoonBackdropDecoration") is Control,
		"카툰 별 장식 레이어가 있어야 한다.")
	_expect(hud.get_node_or_null("ShopSafeMargin/ShopPanel") is PanelContainer,
		"안전 여백 안에 보상 패널이 있어야 한다.")
	_expect(hud.find_child("BoothBolts", true, false) is Control,
		"보상 패널에 장난감 부스 볼트 장식이 있어야 한다.")
	_expect(hud.find_child("WaveClearBadge", true, false) is PanelContainer,
		"웨이브 결과가 빨간 간판 배지로 표시되어야 한다.")
	var wallet_coin_icon := hud.find_child(
		"WalletCoinIcon", true, false
	) as TextureRect
	_expect(
		wallet_coin_icon != null
			and wallet_coin_icon.texture != null
			and wallet_coin_icon.texture.resource_path
				== "res://Resources/Art/coin/coin.png",
		"상점 지갑은 pre-main 코인 아트를 사용해야 한다."
	)
	var price_coin_icons := hud.find_children(
		"PriceCoinIcon", "TextureRect", true, false
	)
	_expect(price_coin_icons.size() == 6,
		"모든 상점 가격에 pre-main 코인 아트가 있어야 한다.")
	for price_coin_icon: TextureRect in price_coin_icons:
		_expect(
			price_coin_icon.texture != null
				and price_coin_icon.texture.resource_path
					== "res://Resources/Art/coin/coin.png",
			"상점 가격 아이콘은 pre-main 코인 아트를 사용해야 한다."
		)
	_expect(hud.find_child("EarnedCoinLabel", true, false) == null,
		"설계에 없는 웨이브 획득량 보조 문구는 표시하지 않아야 한다.")
	_expect(not _has_exact_label(hud, "BALL") and not _has_exact_label(hud, "PART"),
		"설계에 없는 영문 카테고리 보조 배지는 없어야 한다.")
	var design_scale := minf(hud.size.x / 1920.0, hud.size.y / 1080.0)
	var shop_panel := hud.find_child("ShopPanel", true, false) as PanelContainer
	_expect(shop_panel != null and is_equal_approx(
		shop_panel.custom_minimum_size.x, 1040.0 * design_scale
	), "보상 3개일 때 상점 패널은 1040px의 밀집 폭을 사용해야 한다.")
	var ball_group := hud.find_child(
		"BallRewardGroup", true, false
	) as PanelContainer
	var part_group := hud.find_child(
		"PartRewardGroup", true, false
	) as PanelContainer
	var ball_group_style := (
		ball_group.get_theme_stylebox(&"panel") as StyleBoxFlat
		if ball_group != null
		else null
	)
	var part_group_style := (
		part_group.get_theme_stylebox(&"panel") as StyleBoxFlat
		if part_group != null
		else null
	)
	_expect(ball_group_style != null
		and ball_group_style.border_color == Color("55bfaf"),
		"공 보상 요소는 청록색 네모 그룹 박스로 묶여야 한다.")
	_expect(part_group_style != null
		and part_group_style.border_color == Color("e9a83d"),
		"수리 부품 요소는 금색 네모 그룹 박스로 묶여야 한다.")
	var ball_shelf := hud.find_child("BallShelf", true, false) as Control
	var ball_shelf_header := hud.find_child(
		"BallShelfHeader", true, false
	) as Control
	var ball_shelf_ribbon := hud.find_child(
		"BallShelfRibbon", true, false
	) as PanelContainer
	var ball_shelf_title := hud.find_child(
		"BallShelfTitle", true, false
	) as Label
	var ball_row := hud.find_child("BallOfferRow", true, false) as Control
	_expect(ball_shelf != null and is_equal_approx(
		ball_shelf.custom_minimum_size.y, 340.0 * design_scale
	), "공 보상 선반 높이가 설계 비율과 같아야 한다.")
	_expect(ball_shelf_header != null and is_equal_approx(
		ball_shelf_header.custom_minimum_size.y, 48.0 * design_scale
	), "공 보상 리본 헤더 높이가 원래 설계 비율과 같아야 한다.")
	_expect(ball_row != null and is_equal_approx(
		ball_row.custom_minimum_size.y, 282.0 * design_scale
	), "공 카드 행 높이가 설계 비율과 같아야 한다.")
	_expect(ball_row != null
		and (ball_row as HBoxContainer).alignment
			== BoxContainer.ALIGNMENT_CENTER
		and ball_row.get_theme_constant(&"separation")
			== roundi(32.0 * design_scale),
		"공 보상은 그룹 중앙에서 32px 간격으로 배치되어야 한다.")
	_expect(ball_shelf_title != null and ball_shelf_title.get_theme_font_size(
		&"font_size"
	) == roundi(21.0 * design_scale),
		"공 보상 리본 글자가 원래 설계 크기와 같아야 한다.")
	var ball_ribbon_style := (
		ball_shelf_ribbon.get_theme_stylebox(&"panel") as StyleBoxFlat
		if ball_shelf_ribbon != null
		else null
	)
	_expect(ball_ribbon_style != null and is_equal_approx(
		ball_ribbon_style.content_margin_left, 18.0 * design_scale
	) and is_equal_approx(
		ball_ribbon_style.content_margin_top, roundi(8.0 * design_scale)
	), "공 보상 리본 내부 여백이 원래 설계 비율과 같아야 한다.")
	var part_shelf_header := hud.find_child(
		"PartShelfHeader", true, false
	) as Control
	var part_shelf_ribbon := hud.find_child(
		"PartShelfRibbon", true, false
	) as PanelContainer
	var part_shelf_title := hud.find_child(
		"PartShelfTitle", true, false
	) as Label
	var part_row := hud.find_child("PartOfferRow", true, false) as Control
	_expect(part_shelf_header != null and is_equal_approx(
		part_shelf_header.custom_minimum_size.y, 48.0 * design_scale
	), "수리 부품 리본 헤더 높이가 원래 설계 비율과 같아야 한다.")
	_expect(part_row != null and is_equal_approx(
		part_row.custom_minimum_size.y, 272.0 * design_scale
	), "수리 부품 카드 행 높이가 설계 비율과 같아야 한다.")
	_expect(part_row != null
		and (part_row as HBoxContainer).alignment
			== BoxContainer.ALIGNMENT_CENTER
		and part_row.get_theme_constant(&"separation")
			== roundi(32.0 * design_scale),
		"수리 부품은 그룹 중앙에서 32px 간격으로 배치되어야 한다.")
	_expect(part_shelf_title != null and part_shelf_title.get_theme_font_size(
		&"font_size"
	) == roundi(21.0 * design_scale),
		"수리 부품 리본 글자가 원래 설계 크기와 같아야 한다.")
	var part_ribbon_style := (
		part_shelf_ribbon.get_theme_stylebox(&"panel") as StyleBoxFlat
		if part_shelf_ribbon != null
		else null
	)
	_expect(part_ribbon_style != null and is_equal_approx(
		part_ribbon_style.content_margin_left, 18.0 * design_scale
	) and is_equal_approx(
		part_ribbon_style.content_margin_top, roundi(8.0 * design_scale)
	), "수리 부품 리본 내부 여백이 원래 설계 비율과 같아야 한다.")
	var shop_title := hud.find_child("ShopTitleLabel", true, false) as Label
	var display_font := (
		shop_title.get_theme_font(&"font") as FontVariation
		if shop_title != null
		else null
	)
	_expect(display_font != null and display_font.base_font.resource_path.ends_with(
		"Resources/ui/fonts/black_han_sans/BlackHanSans-Regular.ttf"
	), "상점 제목은 설계와 같은 Black Han Sans를 기반으로 사용해야 한다.")
	_expect(display_font != null and display_font.has_char("·".unicode_at(0)),
		"상점 장식 폰트는 Web 구매 문구의 구분 기호를 표시해야 한다.")
	var initial_ball_rule := hud.find_child("BallRuleLabel", true, false) as Label
	var body_font := (
		initial_ball_rule.get_theme_font(&"font") as FontVariation
		if initial_ball_rule != null
		else null
	)
	_expect(body_font != null and body_font.base_font.resource_path.ends_with(
		"Resources/ui/fonts/noto_sans_kr/NotoSansKR-wght.ttf"
	), "본문은 설계와 같은 Noto Sans KR을 사용해야 한다.")
	var handoff := hud.find_child("HandoffOverlay", true, false) as Control
	_expect(handoff != null and not handoff.visible,
		"NEXT WAVE 전환 화면은 상점 진행 전까지 숨겨져야 한다.")
	_expect(hud.get_card_count() == 6, "공 3장과 부품 3장이 보여야 한다.")
	_expect(
		hud.find_children("OfferArt", "Control", true, false).size() == 6,
		"모든 카드에 공 또는 부품 아트가 있어야 한다."
	)
	_expect(
		hud.find_children("OfferArtWell", "PanelContainer", true, false).size() == 6,
		"모든 카드 아트가 잉크 외곽선 슬롯에 들어가야 한다."
	)
	var first_art_well := hud.find_child("OfferArtWell", true, false) as Control
	_expect(first_art_well != null and is_equal_approx(
		first_art_well.custom_minimum_size.x, 176.0 * design_scale
	) and is_equal_approx(
		first_art_well.custom_minimum_size.y, 176.0 * design_scale
	), "카드 아트 슬롯이 확대된 정사각형 설계 비율과 같아야 한다.")
	var first_offer_art := hud.find_child("OfferArt", true, false) as Control
	_expect(first_offer_art != null and is_equal_approx(
		first_offer_art.custom_minimum_size.x, roundi(148.0 * design_scale)
	) and is_equal_approx(
		first_offer_art.custom_minimum_size.y, roundi(148.0 * design_scale)
	), "공·수리 부품 아이콘이 확대된 설계 비율과 같아야 한다.")
	_expect(hud.find_child("OfferCopy", true, false) == null
		and hud.find_child("OfferTitle", true, false) == null
		and hud.find_child("OfferKindTag", true, false) == null,
		"기본 카드에는 이름·유형·설명 정보를 노출하지 않아야 한다.")
	var first_card := hud.find_child("OfferCard00", true, false) as Button
	_expect(first_card != null
		and first_card.get_theme_stylebox(&"normal") is StyleBoxEmpty
		and first_card.get_theme_stylebox(&"hover") is StyleBoxEmpty,
		"큰 카드 박스는 투명한 클릭·포커스 영역으로만 남아야 한다.")
	_expect(first_card != null and is_equal_approx(
		first_card.custom_minimum_size.x, 220.0 * design_scale
	) and first_card.size_flags_horizontal == Control.SIZE_SHRINK_CENTER,
		"각 보상 클릭 영역은 220px 고정 폭으로 밀집 배치되어야 한다.")
	var ball_page_controls := hud.find_child(
		"BallPageControls", true, false
	) as HBoxContainer
	_expect(ball_page_controls != null and not ball_page_controls.visible,
		"공 보상이 4개 이하일 때 페이지 컨트롤은 숨겨져야 한다.")

	var original_ball_offers: Array[RewardBallOffer] = []
	for offer: RewardBallOffer in shop.ball_offers:
		original_ball_offers.append(offer)
	var overflow_ball_offers: Array[RewardBallOffer] = []
	for offer: RewardBallOffer in (CATALOG as RewardShopCatalog).ball_offers:
		overflow_ball_offers.append(offer)
	shop._ball_offers = overflow_ball_offers
	hud._rebuild_cards()
	await process_frame
	await create_timer(0.05).timeout

	var ball_page_label := hud.find_child(
		"BallPageLabel", true, false
	) as Label
	var ball_previous_page := hud.find_child(
		"BallPreviousPageButton", true, false
	) as Button
	var ball_next_page := hud.find_child(
		"BallNextPageButton", true, false
	) as Button
	_expect(shop_panel != null and is_equal_approx(
		shop_panel.custom_minimum_size.x, 1136.0 * design_scale
	), "보상 4개 이상에서는 상점 패널이 1136px까지만 확장되어야 한다.")
	_expect(ball_page_controls != null and ball_page_controls.visible,
		"공 보상이 5개이면 페이지 컨트롤이 보여야 한다.")
	_expect(ball_page_label != null and ball_page_label.text == "1 / 2",
		"첫 공 보상 페이지는 전체 페이지 수를 명확하게 표시해야 한다.")
	_expect(ball_previous_page != null and ball_previous_page.disabled,
		"첫 페이지의 이전 버튼은 비활성화되어야 한다.")
	_expect(ball_next_page != null and ball_next_page.text == "→ +1"
		and ball_next_page.tooltip_text == "다음 공 보상 1개",
		"다음 버튼은 숨겨진 공 보상 수를 직접 알려야 한다.")
	_expect(hud._pagination_hint_played,
		"페이지가 생긴 상점은 처음 열릴 때 방향 힌트를 한 번 재생해야 한다.")
	_expect(_visible_offer_count(hud, 0, 5) == 4,
		"첫 페이지에는 공 보상을 최대 4개만 보여야 한다.")

	ball_next_page.pressed.emit()
	await process_frame
	_expect(ball_page_label.text == "2 / 2"
		and ball_next_page.disabled
		and not ball_previous_page.disabled,
		"다음 페이지에서는 2/2 위치와 이동 가능 방향이 갱신되어야 한다.")
	_expect(_visible_offer_count(hud, 0, 5) == 1,
		"두 번째 페이지에는 남은 공 보상 1개만 보여야 한다.")

	ball_previous_page.pressed.emit()
	await process_frame
	hud._on_card_pressed(3)
	hud._move_selection(1)
	await process_frame
	var fifth_ball_card := hud.find_child("OfferCard04", true, false) as Button
	_expect(ball_page_label.text == "2 / 2"
		and fifth_ball_card != null and fifth_ball_card.visible
		and fifth_ball_card.has_focus(),
		"마지막 보상에서 오른쪽으로 이동하면 다음 페이지와 보상에 연결되어야 한다.")

	shop._ball_offers = original_ball_offers
	hud._ball_page = 0
	hud._rebuild_cards()
	await process_frame
	_expect(hud.get_card_count() == 6
		and ball_page_controls != null and not ball_page_controls.visible,
		"검증 후 기본 3개 보상 레이아웃으로 복원되어야 한다.")
	var detail_popup := hud.find_child(
		"RewardDetailPopup", true, false
	) as PanelContainer
	_expect(detail_popup != null and not detail_popup.visible,
		"상세 팝오버는 기본 상태에서 숨겨져야 한다.")
	for badge_node in hud.find_children("StateBadge", "PanelContainer", true, false):
		_expect(not (badge_node as Control).visible,
			"구매 가능한 기본 카드에는 설계에 없는 상태 배지를 표시하지 않아야 한다.")
	_expect(not _has_control_guide(hud), "조작키 가이드 문구는 없어야 한다.")

	var proceed := hud.find_child("ProceedButton", true, false) as Button
	_expect(proceed != null, "다음 단계 버튼이 있어야 한다.")
	if proceed != null:
		_expect(proceed.text == "구매 없이 진행",
			"초기 버튼은 구매 없이 진행이어야 한다.")
		var no_purchase_proceeded := [false]
		hud.proceed_requested.connect(
			func() -> void: no_purchase_proceeded[0] = true,
			CONNECT_ONE_SHOT
		)
		proceed.pressed.emit()
		await process_frame
		var handoff_confirm := hud.find_child(
			"HandoffConfirmButton", true, false
		) as Button
		_expect(handoff != null and handoff.visible,
			"구매 없이 진행해도 NEXT WAVE 확인 화면이 유지되어야 한다.")
		await create_timer(0.65).timeout
		_expect(not no_purchase_proceeded[0],
			"확인 전에는 다음 웨이브 진행 신호가 자동 발생하지 않아야 한다.")
		_expect(handoff_confirm != null and not handoff_confirm.disabled,
			"NEXT WAVE 화면에 다음 웨이브 시작 버튼이 있어야 한다.")
		if handoff_confirm != null:
			handoff_confirm.pressed.emit()
		_expect(no_purchase_proceeded[0],
			"NEXT WAVE 확인 버튼을 누른 뒤 진행 신호가 발생해야 한다.")
		shop.close_shop()
		await process_frame
		_expect(shop.open_shop(0, 0),
			"확인 동작 뒤 구매 상태 검증을 위해 상점을 다시 열 수 있어야 한다.")
		await process_frame

	var cards := hud.find_children("OfferCard*", "Button", true, false)
	_expect(cards.size() == 6, "상호작용 가능한 카드 버튼이 6개여야 한다.")
	if not cards.is_empty():
		var hovered_art_well := (cards[0] as Button).find_child(
			"OfferArtWell", true, false
		) as Control
		(cards[0] as Button).mouse_entered.emit()
		await create_timer(0.12).timeout
		var detail_title := hud.find_child(
			"RewardDetailTitle", true, false
		) as Label
		var detail_primary := hud.find_child(
			"RewardDetailPrimary", true, false
		) as Label
		_expect(detail_popup != null and detail_popup.visible,
			"카드 호버 시 상세 팝오버가 보여야 한다.")
		_expect(detail_title != null and not detail_title.text.is_empty()
			and detail_primary != null and not detail_primary.text.is_empty(),
			"상세 팝오버에 이름과 핵심 설명이 표시되어야 한다.")
		_expect(hovered_art_well != null and hovered_art_well.scale.x > 1.0,
			"카드 호버 시 아이콘 프레임만 확대되어야 한다.")
		(cards[0] as Button).mouse_exited.emit()
		await create_timer(0.12).timeout
		_expect(detail_popup != null and not detail_popup.visible,
			"선택 전 카드에서 마우스가 벗어나면 팝오버가 숨겨져야 한다.")
		_expect(hovered_art_well != null and is_equal_approx(
			hovered_art_well.scale.x, 1.0
		), "호버가 끝나면 아이콘 프레임 크기가 복원되어야 한다.")
		(cards[0] as Button).grab_focus()
		await process_frame
		_expect(detail_popup != null and detail_popup.visible,
			"키보드·패드 포커스 시에도 상세 팝오버가 보여야 한다.")
		(cards[0] as Button).release_focus()
		await process_frame
		_expect(detail_popup != null and not detail_popup.visible,
			"선택 전 카드 포커스가 해제되면 팝오버가 숨겨져야 한다.")
		(cards[0] as Button).pressed.emit()
		_expect(_state_texts(hud).has("선택!"),
			"카드 선택 시 설계와 같은 선택 도장이 보여야 한다.")
		var selected_well_style := (
			hovered_art_well.get_theme_stylebox(&"panel") as StyleBoxFlat
			if hovered_art_well != null
			else null
		)
		_expect(selected_well_style != null
			and selected_well_style.border_color == Color("76e3d0"),
			"선택 상태 외곽선은 큰 카드가 아니라 아이콘 프레임에 표시되어야 한다.")
		if proceed != null:
			_expect(proceed.text.contains("구매 ·"),
				"선택 후 하단 버튼이 해당 카드 구매 확인으로 바뀌어야 한다.")
			proceed.pressed.emit()
		await process_frame
		var states_after_ball := _state_texts(hud)
		_expect(states_after_ball.has("GET!"),
			"공 구매 카드에 GET 도장이 표시되어야 한다.")
		_expect(states_after_ball.count("잠김") >= 2,
			"공 구매 후 같은 행의 다른 두 장이 잠겨야 한다.")
		var ball_rule := hud.find_child("BallRuleLabel", true, false) as Label
		_expect(ball_rule != null and ball_rule.text == "구매 완료 · 같은 줄 잠김",
			"공 구매 후 행 안내가 설계 문구로 바뀌어야 한다.")
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
		_expect(_state_texts(hud).count("GET!") >= 2,
			"부품 구매 카드에도 GET 도장이 표시되어야 한다.")
		if proceed != null:
			_expect(proceed.text == "다음 웨이브 준비",
				"두 카테고리 구매 후 다음 웨이브 준비가 보여야 한다.")
			var proceeded := [false]
			hud.proceed_requested.connect(func() -> void: proceeded[0] = true)
			proceed.pressed.emit()
			await process_frame
			_expect(handoff != null and handoff.visible,
				"진행 버튼을 누르면 NEXT WAVE 전환 화면이 보여야 한다.")
			await create_timer(0.65).timeout
			_expect(not proceeded[0],
				"구매 후에도 확인 전에는 다음 웨이브로 자동 진행하지 않아야 한다.")
			var handoff_confirm := hud.find_child(
				"HandoffConfirmButton", true, false
			) as Button
			if handoff_confirm != null:
				handoff_confirm.pressed.emit()
			_expect(proceeded[0], "확인 버튼 뒤 다음 웨이브 진행 신호가 발생해야 한다.")

	holder.queue_free()
	await process_frame
	_finish()


func _state_texts(hud: RewardShopHud) -> Array[String]:
	var texts: Array[String] = []
	for node in hud.find_children("StateLabel", "Label", true, false):
		texts.append((node as Label).text)
	return texts


func _visible_offer_count(hud: RewardShopHud, first: int, count: int) -> int:
	var visible_count := 0
	for card_index in range(first, first + count):
		var card := hud.find_child(
			"OfferCard%02d" % card_index, true, false
		) as Button
		if card != null and card.visible:
			visible_count += 1
	return visible_count


func _has_control_guide(hud: RewardShopHud) -> bool:
	for node in hud.find_children("*", "Label", true, false):
		var text := (node as Label).text
		if text.contains("카드 이동") or text.contains("A /") \
				or text.contains("B:") or text.contains("←/→"):
			return true
	return false


func _has_exact_label(hud: RewardShopHud, expected: String) -> bool:
	for node in hud.find_children("*", "Label", true, false):
		if (node as Label).text == expected:
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
