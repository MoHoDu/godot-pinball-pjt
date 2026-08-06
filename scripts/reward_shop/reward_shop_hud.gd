class_name RewardShopHud
extends Control


## 보상 상점 화면입니다. (기획서 5장)
##
## 상단 고정 영역(웨이브 결과·획득 코인·보유 코인) + 공 카드 행 + 부품 카드 행 +
## 하단 진행 버튼으로 구성합니다. 카드는 코드로 만듭니다.
##
## 조작
##   ball_select_previous / ball_select_next  카드 이동(6장 순환)
##   ball_select_confirm                      선택 → 한 번 더 누르면 구매 확정(5-4)
##   wave_choose_clear                        다음 단계(구매 없이 진행 포함)
##   마우스: 카드 클릭 = 선택, 선택된 카드 재클릭 = 구매, 버튼 클릭 = 진행


signal proceed_requested


const BALL_ROW_LABEL := "공 선택 — 다음 발사의 물리 방식"
const PART_ROW_LABEL := "수리 부품 — 다음 웨이브의 보드 배치"

const COLOR_BACKGROUND := Color(0.07, 0.08, 0.10, 0.92)
const COLOR_CARD := Color(0.13, 0.15, 0.19)
const COLOR_CARD_SELECTED := Color(0.19, 0.23, 0.29)
## 같은 행 구매 완료로 잠긴 카드는 더 어둡게 눕힙니다(5-4).
const COLOR_CARD_LOCKED := Color(0.09, 0.10, 0.13)
const COLOR_ACCENT := Color(0.35, 0.86, 0.80)
const COLOR_GOLD := Color(0.90, 0.72, 0.25)
const COLOR_DIM := Color(0.55, 0.58, 0.62)


## 카드의 표시 상태입니다. (기획서 5-4)
enum CardState {
	AVAILABLE,      ## 구매 가능
	SELECTED,       ## 선택 중 — 확인 단계
	PURCHASED,      ## 이 카드를 구매 완료
	ROW_LOCKED,     ## 같은 행에서 다른 카드를 구매해 잠김
	INSUFFICIENT,   ## 코인 부족 — 설명은 읽을 수 있음
}


var _shop: RewardShopController
var _wallet: CoinWallet
var _part_inventory: RewardPartInventory

var _panel: PanelContainer
var _summary_label: Label
var _wallet_label: Label
var _owned_label: Label
var _ball_row: HBoxContainer
var _part_row: HBoxContainer
var _proceed_button: Button
var _cards: Array[Button] = []

var _detail_label: Label

var _selected_index := -1
var _wave_result_text := ""
var _earned_text := ""

## 이번 보상 화면에서 구매한 카드 id입니다. 카드 상태 표시에 씁니다(5-4).
var _purchased_ball_id: StringName = &""
var _purchased_part_id: StringName = &""

## 후보 확정 시 "살 수 있는 공+부품 조합"이 있었는지입니다(6-4 안내용).
var _affordable_pair := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	visible = false
	set_process_unhandled_input(false)
	get_viewport().size_changed.connect(_center_panel)


## 앵커에 기대지 않고 뷰포트 크기로 직접 정중앙을 계산합니다.
## 카드가 바뀌어 패널 크기가 달라질 때마다 다시 부릅니다.
func _center_panel() -> void:
	if _panel == null:
		return
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = (get_viewport_rect().size - panel_size) * 0.5


func bind(
	shop: RewardShopController,
	wallet: CoinWallet,
	part_inventory: RewardPartInventory
) -> bool:
	if shop == null or wallet == null:
		return false
	_shop = shop
	_wallet = wallet
	_part_inventory = part_inventory
	_shop.shop_opened.connect(_on_shop_opened)
	_shop.shop_closed.connect(_on_shop_closed)
	_shop.reward_card_purchased.connect(_on_card_purchased)
	_shop.reward_offers_generated.connect(_on_offers_generated)
	_wallet.wallet_changed.connect(_on_wallet_changed)
	return true


func _on_offers_generated(
	_wave_id: int,
	_ball_ids: Array[StringName],
	_part_ids: Array[StringName],
	_wallet_balance: int,
	affordable_pair: bool
) -> void:
	_affordable_pair = affordable_pair


## 상단 고정 영역에 쓸 웨이브 결과를 상점을 열기 전에 넣어 줍니다.
func set_wave_summary(
	wave_index: int,
	board_coin: int,
	clear_delay_coin: int
) -> void:
	_wave_result_text = "WAVE %02d 성공" % (wave_index + 1)
	_earned_text = "획득 +%d (보드 %d · 유예 %d)" % [
		board_coin + clear_delay_coin, board_coin, clear_delay_coin,
	]


func get_card_count() -> int:
	return _cards.size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _shop == null or not _shop.is_open:
		return
	if event.is_action_pressed(&"ball_select_next"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ball_select_previous"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ball_select_confirm"):
		_confirm_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"wave_choose_clear"):
		proceed_requested.emit()
		get_viewport().set_input_as_handled()


func _build_layout() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ShopPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BACKGROUND
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 5.0
	panel_style.content_margin_bottom = 5.0
	_panel.add_theme_stylebox_override(&"panel", panel_style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	_panel.add_child(column)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override(&"font_size", 16)
	_summary_label.add_theme_color_override(&"font_color", COLOR_ACCENT)
	column.add_child(_summary_label)

	_wallet_label = Label.new()
	_wallet_label.add_theme_font_size_override(&"font_size", 14)
	_wallet_label.add_theme_color_override(&"font_color", COLOR_GOLD)
	column.add_child(_wallet_label)

	# 공 보유 목록 요약과 부품 종류별 재고입니다(5-1 보유 정보).
	_owned_label = Label.new()
	_owned_label.add_theme_font_size_override(&"font_size", 11)
	_owned_label.add_theme_color_override(&"font_color", COLOR_DIM)
	column.add_child(_owned_label)

	column.add_child(_make_row_label(BALL_ROW_LABEL))
	_ball_row = HBoxContainer.new()
	_ball_row.add_theme_constant_override(&"separation", 6)
	column.add_child(_ball_row)

	column.add_child(_make_row_label(PART_ROW_LABEL))
	_part_row = HBoxContainer.new()
	_part_row.add_theme_constant_override(&"separation", 6)
	column.add_child(_part_row)

	# 선택 중 카드의 상세와 구매 확인 안내를 보여 주는 영역입니다(5-4, 6-3).
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override(&"font_size", 11)
	_detail_label.add_theme_color_override(&"font_color", COLOR_ACCENT)
	_detail_label.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(_detail_label)

	_proceed_button = Button.new()
	_proceed_button.text = "다음 단계 (구매 없이 진행 가능)"
	_proceed_button.add_theme_font_size_override(&"font_size", 12)
	_proceed_button.pressed.connect(func() -> void: proceed_requested.emit())
	column.add_child(_proceed_button)


func _make_row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 11)
	label.add_theme_color_override(&"font_color", COLOR_DIM)
	return label


func _on_shop_opened(_wave_id: int) -> void:
	_selected_index = -1
	_purchased_ball_id = &""
	_purchased_part_id = &""
	_rebuild_cards()
	_refresh_header()
	visible = true
	set_process_unhandled_input(true)
	# 카드가 이번 프레임에 추가되어 최소 크기 계산이 늦을 수 있어 지연 호출합니다.
	call_deferred(&"_center_panel")


func _on_shop_closed(_wave_id: int) -> void:
	visible = false
	set_process_unhandled_input(false)
	_clear_cards()


func _on_card_purchased(
	category: StringName,
	item_id: StringName,
	_price: int,
	_bundle_count: int,
	_wallet_after: int
) -> void:
	if category == RewardShopController.CATEGORY_BALL:
		_purchased_ball_id = item_id
	else:
		_purchased_part_id = item_id
	_rebuild_cards()
	_refresh_header()
	call_deferred(&"_center_panel")


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	if visible:
		_refresh_header()
		_refresh_card_states()


func _refresh_header() -> void:
	_summary_label.text = "%s  ·  %s" % [_wave_result_text, _earned_text]
	_wallet_label.text = "보유 코인 %d" % (_wallet.balance if _wallet != null else 0)
	_refresh_owned_label()


## 공 보유 목록 요약 + 부품 종류별 재고 수량입니다(5-1).
func _refresh_owned_label() -> void:
	if _owned_label == null or _shop == null:
		return
	var ball_names: PackedStringArray = PackedStringArray(["기본 유리눈"])
	var part_stocks: PackedStringArray = PackedStringArray()
	if _shop.catalog != null:
		for ball_offer in _shop.catalog.ball_offers:
			if ball_offer != null \
					and _shop.unlocked_ball_ids.has(ball_offer.ball_id):
				ball_names.append(ball_offer.display_name)
		if _part_inventory != null:
			for part_offer in _shop.catalog.part_offers:
				if part_offer == null:
					continue
				var count := _part_inventory.count_of(part_offer.part_id)
				if count > 0:
					part_stocks.append(
						"%s %d" % [part_offer.display_name, count]
					)
	var part_text := "없음" if part_stocks.is_empty() \
		else " · ".join(part_stocks)
	_owned_label.text = "보유 공: %s    부품 재고: %s" % [
		", ".join(ball_names), part_text,
	]


func _rebuild_cards() -> void:
	_clear_cards()
	for offer_index in _shop.ball_offers.size():
		var card := _make_card(_ball_card_text(offer_index), _cards.size())
		# 공 카드에는 확정본 아트(본체+동공 합성)를 아이콘으로 함께 보여 줍니다.
		# 원본(1024px)을 그대로 쓰면 카드 최소 크기가 폭주하므로 축소본을 씁니다.
		card.icon = BallArtLibrary.icon_of(
			_shop.ball_offers[offer_index].ball_id
		)
		_ball_row.add_child(card)
		_cards.append(card)
	for offer_index in _shop.part_offers.size():
		var card := _make_card(_part_card_text(offer_index), _cards.size())
		_part_row.add_child(card)
		_cards.append(card)
	_refresh_card_states()


func _ball_card_text(offer_index: int) -> String:
	var offer := _shop.ball_offers[offer_index]
	var lines := [offer.display_name, "%d 코인" % offer.price]
	if offer.merit_text != "":
		lines.append("+ " + offer.merit_text)
	if offer.cost_text != "":
		lines.append("- " + offer.cost_text)
	if _shop.unlocked_ball_ids.has(offer.ball_id):
		lines.append("[보유]")
	return "\n".join(lines)


func _part_card_text(offer_index: int) -> String:
	var offer := _shop.part_offers[offer_index]
	var lines := [
		offer.display_name,
		"x%d · %d 코인" % [offer.bundle_count, offer.price],
	]
	if offer.verb_text != "":
		lines.append("「%s」" % offer.verb_text)
	if offer.effect_text != "":
		lines.append(offer.effect_text)
	var owned := 0
	if _part_inventory != null:
		owned = _part_inventory.count_of(offer.part_id)
	lines.append("재고 %d" % owned)
	return "\n".join(lines)


func _make_card(text: String, card_index: int) -> Button:
	var card := Button.new()
	card.text = text
	card.custom_minimum_size = Vector2(150.0, 84.0)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override(&"font_size", 10)
	card.pressed.connect(_on_card_pressed.bind(card_index))
	return card


func _on_card_pressed(card_index: int) -> void:
	if _selected_index == card_index:
		_confirm_selected()
		return
	_selected_index = card_index
	_refresh_card_states()


func _move_selection(step: int) -> void:
	if _cards.is_empty():
		return
	_selected_index = posmod(_selected_index + step, _cards.size())
	_refresh_card_states()


## 선택 중 카드를 구매 확정합니다(6-3: 카드 선택 → 확인 → 구매).
func _confirm_selected() -> void:
	if _selected_index < 0:
		return
	var ball_count := _shop.ball_offers.size()
	if _selected_index < ball_count:
		_shop.buy_ball(_selected_index)
	else:
		_shop.buy_part(_selected_index - ball_count)


func _refresh_card_states() -> void:
	var ball_count := _shop.ball_offers.size()
	for card_index in _cards.size():
		var card := _cards[card_index]
		var state := _card_state_of(card_index)
		# 코인 부족·행 잠금 카드도 설명은 읽을 수 있게 남깁니다(5-4).
		card.disabled = state in [
			CardState.PURCHASED, CardState.ROW_LOCKED, CardState.INSUFFICIENT,
		]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 5.0
		style.content_margin_bottom = 5.0
		match state:
			CardState.SELECTED:
				style.bg_color = COLOR_CARD_SELECTED
				style.border_color = COLOR_ACCENT
				style.set_border_width_all(2)
			CardState.PURCHASED:
				style.bg_color = COLOR_CARD
				style.border_color = COLOR_GOLD
				style.set_border_width_all(2)
			CardState.ROW_LOCKED:
				style.bg_color = COLOR_CARD_LOCKED
			_:
				# 구매 가능·코인 부족 모두 기본 명도로 설명을 읽게 둡니다.
				style.bg_color = COLOR_CARD
		card.add_theme_stylebox_override(&"normal", style)
		card.add_theme_stylebox_override(&"hover", style)
		card.add_theme_stylebox_override(&"pressed", style)
		card.add_theme_stylebox_override(&"disabled", style)
		card.add_theme_color_override(
			&"font_disabled_color",
			COLOR_GOLD if state == CardState.PURCHASED else COLOR_DIM
		)
	_refresh_detail_label()


## 카드 하나의 표시 상태를 판정합니다(5-4).
func _card_state_of(card_index: int) -> CardState:
	var ball_count := _shop.ball_offers.size()
	var is_ball := card_index < ball_count
	if is_ball:
		var ball_offer := _shop.ball_offers[card_index]
		if ball_offer.ball_id == _purchased_ball_id:
			return CardState.PURCHASED
		if _shop.ball_purchase_used:
			return CardState.ROW_LOCKED
		if _shop.unlocked_ball_ids.has(ball_offer.ball_id):
			return CardState.ROW_LOCKED
		if not _shop.can_buy_ball(card_index):
			return CardState.INSUFFICIENT
	else:
		var part_offer := _shop.part_offers[card_index - ball_count]
		if part_offer.part_id == _purchased_part_id:
			return CardState.PURCHASED
		if _shop.part_purchase_used:
			return CardState.ROW_LOCKED
		if not _shop.can_buy_part(card_index - ball_count):
			return CardState.INSUFFICIENT
	if card_index == _selected_index:
		return CardState.SELECTED
	return CardState.AVAILABLE


## 선택 중 카드의 상세와 다음 행동 안내를 갱신합니다(5-4 확인 단계, 6-3).
func _refresh_detail_label() -> void:
	if _detail_label == null:
		return
	if _selected_index < 0 or _selected_index >= _cards.size():
		if _affordable_pair:
			_detail_label.text = "카드를 선택하면 상세가 표시됩니다 · B: 다음 단계"
		else:
			# 6-4 가드가 조합을 만들지 못한 화면입니다(코인 18 미만 등).
			_detail_label.text = (
				"공+부품을 모두 살 코인이 부족합니다 · 저축 후 다음 보상도 가능 (B)"
			)
		_detail_label.add_theme_color_override(&"font_color", COLOR_DIM)
		return
	var ball_count := _shop.ball_offers.size()
	var display_name := ""
	var price := 0
	if _selected_index < ball_count:
		var ball_offer := _shop.ball_offers[_selected_index]
		display_name = ball_offer.display_name
		price = ball_offer.price
	else:
		var part_offer := _shop.part_offers[_selected_index - ball_count]
		display_name = part_offer.display_name
		price = part_offer.price
	var wallet_balance := _wallet.balance if _wallet != null else 0
	match _card_state_of(_selected_index):
		CardState.SELECTED, CardState.AVAILABLE:
			_detail_label.text = "%s · %d코인 — 한 번 더 누르면 구매 확정" % [
				display_name, price,
			]
			_detail_label.add_theme_color_override(&"font_color", COLOR_ACCENT)
		CardState.PURCHASED:
			_detail_label.text = "%s — 구매 완료" % display_name
			_detail_label.add_theme_color_override(&"font_color", COLOR_GOLD)
		CardState.ROW_LOCKED:
			_detail_label.text = (
				"%s — 이 줄은 이번 보상에서 이미 구매했습니다" % display_name
			)
			_detail_label.add_theme_color_override(&"font_color", COLOR_DIM)
		CardState.INSUFFICIENT:
			_detail_label.text = "%s — 코인 부족 (가격 %d · 보유 %d)" % [
				display_name, price, wallet_balance,
			]
			_detail_label.add_theme_color_override(&"font_color", COLOR_DIM)


func _clear_cards() -> void:
	for card in _cards:
		# queue_free만 하면 다음 프레임까지 자식으로 남아, 재구성 직후의
		# 패널 최소 크기 계산에 유령 카드가 섞인다. 먼저 트리에서 떼어낸다.
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	_selected_index = -1
