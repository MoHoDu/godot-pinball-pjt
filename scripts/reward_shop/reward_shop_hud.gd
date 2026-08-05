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
const COLOR_ACCENT := Color(0.35, 0.86, 0.80)
const COLOR_GOLD := Color(0.90, 0.72, 0.25)
const COLOR_DIM := Color(0.55, 0.58, 0.62)


var _shop: RewardShopController
var _wallet: CoinWallet
var _part_inventory: RepairPartInventory

var _panel: PanelContainer
var _summary_label: Label
var _wallet_label: Label
var _ball_row: HBoxContainer
var _part_row: HBoxContainer
var _proceed_button: Button
var _cards: Array[Button] = []

var _selected_index := -1
var _wave_result_text := ""
var _earned_text := ""


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
	part_inventory: RepairPartInventory
) -> bool:
	if shop == null or wallet == null:
		return false
	_shop = shop
	_wallet = wallet
	_part_inventory = part_inventory
	_shop.shop_opened.connect(_on_shop_opened)
	_shop.shop_closed.connect(_on_shop_closed)
	_shop.reward_card_purchased.connect(_on_card_purchased)
	_wallet.wallet_changed.connect(_on_wallet_changed)
	return true


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

	column.add_child(_make_row_label(BALL_ROW_LABEL))
	_ball_row = HBoxContainer.new()
	_ball_row.add_theme_constant_override(&"separation", 6)
	column.add_child(_ball_row)

	column.add_child(_make_row_label(PART_ROW_LABEL))
	_part_row = HBoxContainer.new()
	_part_row.add_theme_constant_override(&"separation", 6)
	column.add_child(_part_row)

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
	_category: StringName,
	_item_id: StringName,
	_price: int,
	_bundle_count: int,
	_wallet_after: int
) -> void:
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
		var purchasable := false
		if card_index < ball_count:
			purchasable = _shop.can_buy_ball(card_index)
		else:
			purchasable = _shop.can_buy_part(card_index - ball_count)
		# 코인 부족·행 잠금 카드도 설명은 읽을 수 있게 남깁니다(5-4).
		card.disabled = not purchasable
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CARD_SELECTED \
			if card_index == _selected_index else COLOR_CARD
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 6.0
		style.content_margin_right = 6.0
		style.content_margin_top = 5.0
		style.content_margin_bottom = 5.0
		if card_index == _selected_index:
			style.border_color = COLOR_ACCENT
			style.set_border_width_all(2)
		card.add_theme_stylebox_override(&"normal", style)
		card.add_theme_stylebox_override(&"hover", style)
		card.add_theme_stylebox_override(&"pressed", style)
		card.add_theme_stylebox_override(&"disabled", style)
		card.add_theme_color_override(
			&"font_disabled_color", COLOR_DIM
		)


func _clear_cards() -> void:
	for card in _cards:
		# queue_free만 하면 다음 프레임까지 자식으로 남아, 재구성 직후의
		# 패널 최소 크기 계산에 유령 카드가 섞인다. 먼저 트리에서 떼어낸다.
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	_selected_index = -1
