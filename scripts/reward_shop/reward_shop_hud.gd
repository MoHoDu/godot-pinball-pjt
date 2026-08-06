class_name RewardShopHud
extends Control


## 보상 상점 화면입니다. (기획서 5장)
##
## [[RewardShopController]]의 구매 규칙은 그대로 두고, reward_scene_ui.pen의
## 다크 토이 시어터 그래픽 시스템과 카드 상태를 런타임 Control로 표현합니다.


signal proceed_requested


const CURTAIN_BACKGROUND := preload(
	"res://Resources/Art/backgrounds/cursed_circus_curtain_background.png"
)
const DISPLAY_FONT := preload(
	"res://Resources/ui/fonts/black_and_white_picture/BlackAndWhitePicture-Regular.ttf"
)

const BALL_ROW_TITLE := "공 선택 — 다음 발사의 물리 방식"
const PART_ROW_TITLE := "수리 부품 — 다음 웨이브의 보드 배치"

const COLOR_VOID := Color(0.039, 0.027, 0.063)
const COLOR_PANEL := Color(0.090, 0.067, 0.122, 0.96)
const COLOR_CARD := Color(0.141, 0.106, 0.176)
const COLOR_CARD_RAISED := Color(0.188, 0.133, 0.235)
const COLOR_LINE := Color(0.349, 0.290, 0.400)
const COLOR_TEXT := Color(1.0, 0.953, 0.871)
const COLOR_TEXT_SECONDARY := Color(0.725, 0.686, 0.765)
const COLOR_MINT := Color(0.369, 0.882, 0.812)
const COLOR_GOLD := Color(0.949, 0.741, 0.298)
const COLOR_MAGENTA := Color(0.902, 0.165, 0.533)
const COLOR_DANGER := Color(0.914, 0.337, 0.373)
const COLOR_LOCKED := Color(0.063, 0.051, 0.082)

const CARD_RADIUS := 14
const PANEL_RADIUS := 20
const BALL_ICON_SIZE := 64
const PART_ICON_SIZE := 64

const PERFORMANCE_NAMES: Array[String] = [
	"안정형",
	"완충형",
	"도전형",
]


enum CardState {
	AVAILABLE,
	SELECTED,
	PURCHASED,
	ROW_LOCKED,
	INSUFFICIENT,
}


var _shop: RewardShopController
var _wallet: CoinWallet
var _part_inventory: RepairPartInventory

var _panel: PanelContainer
var _summary_label: Label
var _earned_label: Label
var _wallet_label: Label
var _owned_label: Label
var _ball_row: HBoxContainer
var _part_row: HBoxContainer
var _proceed_button: Button
var _cards: Array[Button] = []
var _card_views: Array[Dictionary] = []

var _selected_index := -1
var _wave_result_text := ""
var _earned_text := ""

var _purchased_ball_id: StringName = &""
var _purchased_part_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	visible = false
	set_process_unhandled_input(false)


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


func set_wave_summary(
	wave_index: int,
	board_coin: int,
	clear_delay_coin: int
) -> void:
	_wave_result_text = "WAVE %02d CLEAR" % (wave_index + 1)
	_earned_text = "획득 +%d  ·  보드 %d  ·  종료 유예 +%d" % [
		board_coin + clear_delay_coin,
		board_coin,
		clear_delay_coin,
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
	var backdrop := TextureRect.new()
	backdrop.name = "ShopBackdrop"
	backdrop.texture = CURTAIN_BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var shade := ColorRect.new()
	shade.name = "ShopBackdropShade"
	shade.color = Color(COLOR_VOID, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var safe_margin := MarginContainer.new()
	safe_margin.name = "ShopSafeMargin"
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		safe_margin.add_theme_constant_override("margin_%s" % side, 18)
	add_child(safe_margin)

	_panel = PanelContainer.new()
	_panel.name = "ShopPanel"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_theme_stylebox_override(
		&"panel",
		_make_style(COLOR_PANEL, Color(COLOR_LINE, 0.72), 2, PANEL_RADIUS, 20)
	)
	safe_margin.add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "ShopContent"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 7)
	_panel.add_child(column)

	column.add_child(_build_header())
	column.add_child(_make_divider())
	column.add_child(_make_row_header(
		"BALL OFFER",
		BALL_ROW_TITLE,
		"이번 화면에서 최대 1장 · 중복 해금 없음"
	))

	_ball_row = HBoxContainer.new()
	_ball_row.name = "BallOfferRow"
	_ball_row.custom_minimum_size.y = 166.0
	_ball_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ball_row.add_theme_constant_override(&"separation", 10)
	column.add_child(_ball_row)

	column.add_child(_make_row_header(
		"REPAIR PART",
		PART_ROW_TITLE,
		"이번 화면에서 최대 1장 · 반복 구매 가능"
	))

	_part_row = HBoxContainer.new()
	_part_row.name = "PartOfferRow"
	_part_row.custom_minimum_size.y = 166.0
	_part_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_part_row.add_theme_constant_override(&"separation", 10)
	column.add_child(_part_row)

	var footer := HBoxContainer.new()
	footer.name = "ShopFooter"
	footer.custom_minimum_size.y = 44.0
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)

	_proceed_button = Button.new()
	_proceed_button.name = "ProceedButton"
	_proceed_button.custom_minimum_size = Vector2(190.0, 42.0)
	_proceed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_proceed_button.add_theme_font_size_override(&"font_size", 14)
	_proceed_button.pressed.connect(func() -> void: proceed_requested.emit())
	footer.add_child(_proceed_button)
	_refresh_proceed_button()


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = "ShopHeader"
	header.custom_minimum_size.y = 78.0
	header.add_theme_constant_override(&"separation", 16)
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	var result_column := VBoxContainer.new()
	result_column.name = "WaveResult"
	result_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_column.size_flags_stretch_ratio = 1.6
	result_column.add_theme_constant_override(&"separation", 2)
	header.add_child(result_column)

	var kicker := _make_label("REWARD SHOP", 9, COLOR_MAGENTA, true)
	kicker.add_theme_constant_override(&"outline_size", 2)
	result_column.add_child(kicker)

	_summary_label = _make_label("WAVE CLEAR", 28, COLOR_TEXT, true)
	_summary_label.name = "WaveResultLabel"
	_summary_label.add_theme_font_override(&"font", DISPLAY_FONT)
	result_column.add_child(_summary_label)

	_earned_label = _make_label("", 12, COLOR_MINT, true)
	_earned_label.name = "EarnedCoinLabel"
	result_column.add_child(_earned_label)

	var wallet_panel := PanelContainer.new()
	wallet_panel.name = "WalletPanel"
	wallet_panel.custom_minimum_size = Vector2(168.0, 58.0)
	wallet_panel.add_theme_stylebox_override(
		&"panel",
		_make_style(COLOR_CARD, COLOR_GOLD, 2, 14, 12)
	)
	header.add_child(wallet_panel)

	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override(&"separation", 8)
	wallet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_panel.add_child(wallet_row)

	var coin_icon := RewardCoinIcon.new()
	coin_icon.name = "WalletCoinIcon"
	coin_icon.custom_minimum_size = Vector2(34.0, 34.0)
	wallet_row.add_child(coin_icon)

	_wallet_label = _make_label("0", 25, COLOR_GOLD, true)
	_wallet_label.name = "WalletValueLabel"
	wallet_row.add_child(_wallet_label)
	wallet_row.add_child(_make_label("보유 코인", 11, COLOR_TEXT_SECONDARY, true))

	var owned_panel := PanelContainer.new()
	owned_panel.name = "OwnedSummaryPanel"
	owned_panel.custom_minimum_size = Vector2(330.0, 58.0)
	owned_panel.size_flags_stretch_ratio = 1.0
	owned_panel.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(COLOR_LOCKED, 0.88), COLOR_LINE, 1, 12, 12)
	)
	header.add_child(owned_panel)

	_owned_label = _make_label("보유 공 · 기본 유리눈\n부품 재고 · 없음", 11, COLOR_TEXT_SECONDARY)
	_owned_label.name = "OwnedSummaryLabel"
	_owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owned_panel.add_child(_owned_label)
	return header


func _make_row_header(kicker_text: String, title: String, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 24.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)

	row.add_child(_make_label(kicker_text, 8, COLOR_MAGENTA, true))
	var title_label := _make_label(title, 14, COLOR_TEXT, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	row.add_child(_make_label(note, 9, COLOR_TEXT_SECONDARY, true))
	return row


func _make_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.color = Color(COLOR_LINE, 0.72)
	divider.custom_minimum_size.y = 1.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _on_shop_opened(_wave_id: int) -> void:
	_selected_index = -1
	_purchased_ball_id = &""
	_purchased_part_id = &""
	_rebuild_cards()
	_refresh_header()
	visible = true
	set_process_unhandled_input(true)


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


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	if visible:
		_refresh_header()
		_refresh_card_states()


func _refresh_header() -> void:
	_summary_label.text = _wave_result_text if _wave_result_text != "" else "WAVE CLEAR"
	_earned_label.text = _earned_text
	_wallet_label.text = str(_wallet.balance if _wallet != null else 0)
	_refresh_owned_label()


func _refresh_owned_label() -> void:
	if _owned_label == null or _shop == null:
		return
	var ball_names := PackedStringArray(["기본 유리눈"])
	var part_stocks := PackedStringArray()
	if _shop.catalog != null:
		for ball_offer in _shop.catalog.ball_offers:
			if ball_offer != null and _shop.unlocked_ball_ids.has(ball_offer.ball_id):
				ball_names.append(ball_offer.display_name)
		if _part_inventory != null:
			for part_offer in _shop.catalog.part_offers:
				if part_offer == null:
					continue
				var count := _part_inventory.count_of(part_offer.part_id)
				if count > 0:
					part_stocks.append("%s %d" % [part_offer.display_name, count])
	var part_text := "없음" if part_stocks.is_empty() else " · ".join(part_stocks)
	_owned_label.text = "보유 공 · %s\n부품 재고 · %s" % [
		" · ".join(ball_names),
		part_text,
	]


func _rebuild_cards() -> void:
	_clear_cards()
	for offer_index in _shop.ball_offers.size():
		var card := _make_ball_card(_shop.ball_offers[offer_index], _cards.size())
		_ball_row.add_child(card)
		_cards.append(card)
	for offer_index in _shop.part_offers.size():
		var card := _make_part_card(_shop.part_offers[offer_index], _cards.size())
		_part_row.add_child(card)
		_cards.append(card)
	_refresh_card_states()


func _make_ball_card(offer: RewardBallOffer, card_index: int) -> Button:
	var card := _make_card_shell(card_index)
	var content := _make_card_content(card)
	var header := _make_card_header(content)

	var art := TextureRect.new()
	art.name = "OfferArt"
	art.custom_minimum_size = Vector2(BALL_ICON_SIZE, BALL_ICON_SIZE)
	art.texture = BallArtLibrary.icon_of(offer.ball_id, BALL_ICON_SIZE)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(art)

	var meta := _make_meta_column(header)
	var group_index := clampi(offer.performance_group, 0, PERFORMANCE_NAMES.size() - 1)
	meta.add_child(_make_label(PERFORMANCE_NAMES[group_index], 9, COLOR_TEXT_SECONDARY, true))
	var title := _make_label(offer.display_name, 16, COLOR_TEXT, true)
	title.name = "OfferTitle"
	meta.add_child(title)
	meta.add_child(_make_price_row(offer.price))

	var badge_data := _make_state_badge(content)
	content.add_child(_make_body_label("+ " + offer.merit_text, COLOR_TEXT))
	content.add_child(_make_body_label("− " + offer.cost_text, COLOR_TEXT_SECONDARY))
	_card_views.append({
		&"button": card,
		&"badge": badge_data[0],
		&"state_label": badge_data[1],
		&"price": offer.price,
		&"bundle": 1,
		&"category": RewardShopController.CATEGORY_BALL,
	})
	return card


func _make_part_card(offer: RepairPartOffer, card_index: int) -> Button:
	var card := _make_card_shell(card_index)
	var content := _make_card_content(card)
	var header := _make_card_header(content)

	var art := RewardPartIcon.new()
	art.name = "OfferArt"
	art.custom_minimum_size = Vector2(PART_ICON_SIZE, PART_ICON_SIZE)
	art.set_part_id(offer.part_id)
	header.add_child(art)

	var meta := _make_meta_column(header)
	meta.add_child(_make_label("x%d · %s" % [offer.bundle_count, offer.verb_text], 9, COLOR_TEXT_SECONDARY, true))
	var title := _make_label(offer.display_name, 16, COLOR_TEXT, true)
	title.name = "OfferTitle"
	meta.add_child(title)
	meta.add_child(_make_price_row(offer.price))

	var badge_data := _make_state_badge(content)
	content.add_child(_make_body_label(offer.condition_text, COLOR_TEXT))
	content.add_child(_make_body_label(offer.effect_text, COLOR_TEXT_SECONDARY))
	_card_views.append({
		&"button": card,
		&"badge": badge_data[0],
		&"state_label": badge_data[1],
		&"price": offer.price,
		&"bundle": offer.bundle_count,
		&"category": RewardShopController.CATEGORY_PART,
		&"part_id": offer.part_id,
	})
	return card


func _make_card_shell(card_index: int) -> Button:
	var card := Button.new()
	card.name = "OfferCard%02d" % card_index
	card.text = ""
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_ALL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pressed.connect(_on_card_pressed.bind(card_index))
	return card


func _make_card_content(card: Button) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 4)
	margin.add_child(content)
	return content


func _make_card_header(content: VBoxContainer) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = "CardHeader"
	header.custom_minimum_size.y = 64.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override(&"separation", 9)
	content.add_child(header)
	return header


func _make_meta_column(header: HBoxContainer) -> VBoxContainer:
	var meta := VBoxContainer.new()
	meta.name = "OfferMeta"
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_constant_override(&"separation", 1)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(meta)
	return meta


func _make_price_row(price: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "OfferPrice"
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var coin := RewardCoinIcon.new()
	coin.custom_minimum_size = Vector2(15.0, 15.0)
	row.add_child(coin)
	row.add_child(_make_label("%d 코인" % price, 12, COLOR_GOLD, true))
	return row


func _make_state_badge(content: VBoxContainer) -> Array[Control]:
	var badge := PanelContainer.new()
	badge.name = "StateBadge"
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(badge)

	var label := _make_label("구매 가능", 9, COLOR_MINT, true)
	label.name = "StateLabel"
	badge.add_child(label)
	return [badge, label]


func _make_body_label(text: String, color: Color) -> Label:
	var label := _make_label(text, 10, color)
	label.custom_minimum_size.y = 15.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_label(
	text: String,
	font_size: int,
	color: Color,
	bold := false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	if bold:
		label.add_theme_constant_override(&"outline_size", 1)
		label.add_theme_color_override(&"font_outline_color", Color(COLOR_VOID, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


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


func _confirm_selected() -> void:
	if _selected_index < 0:
		return
	var ball_count := _shop.ball_offers.size()
	if _selected_index < ball_count:
		_shop.buy_ball(_selected_index)
	else:
		_shop.buy_part(_selected_index - ball_count)


func _refresh_card_states() -> void:
	for card_index in _cards.size():
		var state := _card_state_of(card_index)
		_apply_card_state(card_index, state)
	_refresh_proceed_button()


func _apply_card_state(card_index: int, state: CardState) -> void:
	var view := _card_views[card_index]
	var card := view[&"button"] as Button
	var badge := view[&"badge"] as PanelContainer
	var state_label := view[&"state_label"] as Label
	var background := COLOR_CARD
	var border := COLOR_LINE
	var border_width := 2
	var status_color := COLOR_MINT
	var status_text := "구매 가능"
	var opacity := 1.0

	match state:
		CardState.SELECTED:
			background = COLOR_CARD_RAISED
			border = COLOR_MINT
			border_width = 3
			status_text = "선택됨"
		CardState.PURCHASED:
			border = COLOR_GOLD
			border_width = 3
			status_color = COLOR_GOLD
			if view[&"category"] == RewardShopController.CATEGORY_BALL:
				status_text = "보유 · 구매 완료"
			else:
				status_text = "재고 +%d · 구매 완료" % int(view[&"bundle"])
		CardState.ROW_LOCKED:
			background = COLOR_LOCKED
			status_color = COLOR_TEXT_SECONDARY
			status_text = "행 잠금"
			opacity = 0.50
		CardState.INSUFFICIENT:
			border = COLOR_DANGER
			status_color = COLOR_DANGER
			status_text = "코인 부족 · %d / %d" % [
				int(view[&"price"]),
				_wallet.balance if _wallet != null else 0,
			]
			opacity = 0.72

	card.disabled = state in [
		CardState.PURCHASED,
		CardState.ROW_LOCKED,
		CardState.INSUFFICIENT,
	]
	card.modulate = Color(1.0, 1.0, 1.0, opacity)
	var card_style := _make_style(background, border, border_width, CARD_RADIUS)
	for style_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		card.add_theme_stylebox_override(style_name, card_style)
	state_label.text = status_text
	state_label.add_theme_color_override(&"font_color", status_color)
	badge.add_theme_stylebox_override(
		&"panel",
		_make_style(Color(status_color, 0.10), status_color, 1, 8, 6)
	)


func _card_state_of(card_index: int) -> CardState:
	var ball_count := _shop.ball_offers.size()
	var is_ball := card_index < ball_count
	if is_ball:
		var ball_offer := _shop.ball_offers[card_index]
		if ball_offer.ball_id == _purchased_ball_id:
			return CardState.PURCHASED
		if _shop.ball_purchase_used or _shop.unlocked_ball_ids.has(ball_offer.ball_id):
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


func _refresh_proceed_button() -> void:
	if _proceed_button == null:
		return
	var ball_bought := _shop != null and _shop.ball_purchase_used
	var part_bought := _shop != null and _shop.part_purchase_used
	var primary := ball_bought and part_bought
	if primary:
		_proceed_button.text = "다음 웨이브 준비"
	elif ball_bought or part_bought:
		_proceed_button.text = "다음 단계"
	else:
		_proceed_button.text = "구매 없이 진행"

	var normal_color := COLOR_MINT if primary else COLOR_CARD_RAISED
	var text_color := COLOR_VOID if primary else COLOR_TEXT
	_proceed_button.add_theme_color_override(&"font_color", text_color)
	_proceed_button.add_theme_color_override(&"font_hover_color", text_color)
	_proceed_button.add_theme_color_override(&"font_pressed_color", text_color)
	_proceed_button.add_theme_stylebox_override(
		&"normal", _make_style(normal_color, COLOR_MINT, 2, 11, 10)
	)
	_proceed_button.add_theme_stylebox_override(
		&"hover", _make_style(normal_color.lightened(0.08), COLOR_MINT, 2, 11, 10)
	)
	_proceed_button.add_theme_stylebox_override(
		&"pressed", _make_style(normal_color.darkened(0.08), COLOR_MINT, 2, 11, 10)
	)


func _clear_cards() -> void:
	for card in _cards:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	_card_views.clear()
	_selected_index = -1


static func _make_style(
	background: Color,
	border: Color,
	border_width: int,
	radius: int,
	content_margin := 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if content_margin > 0:
		style.content_margin_left = content_margin
		style.content_margin_top = content_margin
		style.content_margin_right = content_margin
		style.content_margin_bottom = content_margin
	return style


class RewardCoinIcon:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		var diameter := minf(size.x, size.y)
		if diameter <= 0.0:
			return
		var center := size * 0.5
		var radius := diameter * 0.44
		draw_circle(center + Vector2(0.0, diameter * 0.035), radius, Color(0.42, 0.23, 0.07))
		draw_circle(center, radius, COLOR_GOLD)
		draw_arc(center, radius, 0.0, TAU, 32, Color(1.0, 0.90, 0.54), maxf(1.0, diameter * 0.07), true)
		var star := PackedVector2Array()
		for index in 10:
			var point_radius := radius * (0.48 if index % 2 == 0 else 0.22)
			star.append(Vector2.from_angle(-PI * 0.5 + index * PI / 5.0) * point_radius + center)
		draw_colored_polygon(star, Color(0.35, 0.18, 0.05))


class RewardPartIcon:
	extends Control

	var _part_id: StringName = &""

	func set_part_id(value: StringName) -> void:
		_part_id = value
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		var diameter := minf(size.x, size.y)
		if diameter <= 0.0:
			return
		var center := size * 0.5
		var radius := diameter * 0.43
		var accent := _accent_color()
		draw_circle(center + Vector2(0.0, diameter * 0.04), radius, Color(0.02, 0.01, 0.03, 0.72))
		draw_circle(center, radius, Color(0.086, 0.055, 0.122))
		draw_arc(center, radius, 0.0, TAU, 36, accent, maxf(2.0, diameter * 0.055), true)
		draw_circle(center, radius * 0.73, Color(accent, 0.18))
		match _part_id:
			&"starlight_brooch":
				_draw_brooch(center, radius, accent)
			&"golden_gears":
				_draw_gears(center, radius, accent)
			&"crescent_needle":
				_draw_needle(center, radius, accent)
			_:
				_draw_bell(center, radius, accent)

	func _accent_color() -> Color:
		match _part_id:
			&"starlight_brooch":
				return COLOR_MAGENTA
			&"golden_gears":
				return COLOR_GOLD
			&"crescent_needle":
				return Color(0.74, 0.68, 0.96)
			_:
				return COLOR_MINT

	func _draw_brooch(center: Vector2, radius: float, accent: Color) -> void:
		var points := PackedVector2Array()
		for index in 10:
			var point_radius := radius * (0.62 if index % 2 == 0 else 0.29)
			points.append(Vector2.from_angle(-PI * 0.5 + index * PI / 5.0) * point_radius + center)
		draw_colored_polygon(points, COLOR_TEXT)
		draw_circle(center, radius * 0.15, accent)

	func _draw_gears(center: Vector2, radius: float, accent: Color) -> void:
		for index in 8:
			var angle := TAU * index / 8.0
			draw_circle(center + Vector2.from_angle(angle) * radius * 0.49, radius * 0.16, COLOR_TEXT)
		draw_circle(center, radius * 0.46, COLOR_TEXT)
		draw_circle(center, radius * 0.17, accent)

	func _draw_needle(center: Vector2, radius: float, accent: Color) -> void:
		draw_arc(center, radius * 0.52, -2.2, 1.2, 28, COLOR_TEXT, maxf(3.0, radius * 0.13), true)
		draw_circle(center + Vector2(-0.33, -0.42) * radius, radius * 0.10, accent)

	func _draw_bell(center: Vector2, radius: float, accent: Color) -> void:
		draw_circle(center, radius * 0.46, COLOR_TEXT)
		draw_rect(Rect2(center + Vector2(-0.46, 0.02) * radius, Vector2(0.92, 0.34) * radius), COLOR_TEXT)
		draw_circle(center + Vector2(0.0, 0.48) * radius, radius * 0.11, accent)
