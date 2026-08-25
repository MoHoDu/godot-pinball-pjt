class_name RewardShopHud
extends Control


## 보상 상점 화면입니다. (기획서 5장)
##
## [[RewardShopController]]의 구매 규칙은 그대로 두고, reward_scene_ui.pen의
## 카툰 토이 박스 그래픽 시스템과 카드 상태를 런타임 Control로 표현합니다.


signal proceed_requested


const CURTAIN_BACKGROUND := preload(
	"res://Resources/Art/backgrounds/cursed_circus_curtain_background.png"
)
const DISPLAY_FONT := preload(
	"res://Resources/ui/themes/web_safe_black_han_font.tres"
)
const BODY_FONT_SOURCE := preload(
	"res://Resources/ui/fonts/noto_sans_kr/NotoSansKR-wght.ttf"
)
const COIN_TEXTURE: Texture2D = preload("res://Resources/Art/coin/coin.png")

const BALL_ROW_TITLE := "공 보상"
const PART_ROW_TITLE := "수리 부품"

const COLOR_INK := Color("17120f")
const COLOR_NAVY_WOOD := Color("103a54")
const COLOR_NAVY_DEEP := Color("081d2b")
const COLOR_CREAM := Color("f7e7bf")
const COLOR_CREAM_LIGHT := Color("fff6dc")
const COLOR_GOLD := Color("e9a83d")
const COLOR_GOLD_DARK := Color("b87523")
const COLOR_TEAL := Color("55bfaf")
const COLOR_TEAL_BRIGHT := Color("76e3d0")
const COLOR_RED := Color("c93b3e")
const COLOR_RED_DARK := Color("81262a")
const COLOR_PURPLE := Color("8066aa")
const COLOR_MUTED := Color("8b8173")
const COLOR_LOCKED := Color("304a59")

const CARD_RADIUS := 16
const PANEL_RADIUS := 28
const ROW_HEADER_HEIGHT := 48
const ROW_TITLE_FONT_SIZE := 21
const ROW_TITLE_PADDING_HORIZONTAL := 18
const ROW_TITLE_PADDING_VERTICAL := 8
const OFFER_ART_WELL_SIZE := 176
const BALL_ICON_SIZE := 148
const PART_ICON_SIZE := 148
const DETAIL_POPUP_WIDTH := 420
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
var _body_font_bold: FontVariation
var _body_font_semibold: FontVariation
var _design_scale := 1.0

var _panel: PanelContainer
var _safe_margin: MarginContainer
var _summary_label: Label
var _wave_badge_label: Label
var _wallet_label: Label
var _owned_ball_label: Label
var _owned_parts_label: Label
var _ball_rule_label: Label
var _part_rule_label: Label
var _ball_row: HBoxContainer
var _part_row: HBoxContainer
var _proceed_button: Button
var _detail_popup: PanelContainer
var _detail_tag_panel: PanelContainer
var _detail_tag_label: Label
var _detail_title_label: Label
var _detail_primary_label: Label
var _detail_secondary_label: Label
var _handoff_overlay: Control
var _handoff_wave_label: Label
var _handoff_ball_label: Label
var _handoff_part_label: Label
var _handoff_coin_label: Label
var _handoff_confirm_button: Button
var _cards: Array[Button] = []
var _card_views: Array[Dictionary] = []

var _selected_index := -1
var _hovered_card_index := -1
var _wave_result_text := ""
var _next_wave_number := 2
var _reward_destination_text := "다음 웨이브"
var _total_wave_count := 0
var _handoff_in_progress := false

var _purchased_ball_id: StringName = &""
var _purchased_part_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design_scale = maxf(0.5, minf(size.x / 1920.0, size.y / 1080.0))
	_body_font_bold = _make_body_font(900)
	_body_font_semibold = _make_body_font(800)
	_build_layout()
	resized.connect(_refresh_safe_margin)
	_refresh_safe_margin()
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
	_board_coin: int,
	_clear_delay_coin: int
) -> void:
	_wave_result_text = "WAVE %02d" % (wave_index + 1)
	_next_wave_number = wave_index + 2


func set_reward_destination(destination_text: String, total_wave_count := 0) -> void:
	_reward_destination_text = destination_text
	_total_wave_count = total_wave_count


func get_card_count() -> int:
	return _cards.size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _shop == null or not _shop.is_open:
		return
	if _handoff_in_progress:
		if event.is_action_pressed(&"ball_select_confirm") \
				or event.is_action_pressed(&"wave_choose_clear"):
			_confirm_handoff()
			get_viewport().set_input_as_handled()
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
		_on_proceed_pressed()
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
	shade.color = Color(COLOR_NAVY_DEEP, 0.80)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var backdrop_decoration := RewardBackdropDecoration.new()
	backdrop_decoration.name = "CartoonBackdropDecoration"
	backdrop_decoration.design_scale = _design_scale
	backdrop_decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop_decoration)

	_safe_margin = MarginContainer.new()
	_safe_margin.name = "ShopSafeMargin"
	_safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)

	_panel = PanelContainer.new()
	_panel.name = "ShopPanel"
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_style := _make_style(
		COLOR_NAVY_WOOD,
		COLOR_INK,
		_di(8),
		_di(PANEL_RADIUS),
		0,
		_di(10),
		Vector2(_d(14.0), _d(16.0))
	)
	panel_style.content_margin_left = _d(34.0)
	panel_style.content_margin_right = _d(34.0)
	panel_style.content_margin_top = _d(24.0)
	panel_style.content_margin_bottom = _d(24.0)
	_panel.add_theme_stylebox_override(&"panel", panel_style)
	_safe_margin.add_child(_panel)

	var booth_decoration := RewardBoothDecoration.new()
	booth_decoration.name = "BoothBolts"
	booth_decoration.design_scale = _design_scale
	booth_decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_margin.add_child(booth_decoration)

	var column := VBoxContainer.new()
	column.name = "ShopContent"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", _di(12))
	_panel.add_child(column)

	column.add_child(_build_header())

	var ball_shelf := VBoxContainer.new()
	ball_shelf.name = "BallShelf"
	ball_shelf.custom_minimum_size.y = _d(340.0)
	ball_shelf.add_theme_constant_override(&"separation", _di(10))
	column.add_child(ball_shelf)
	ball_shelf.add_child(_make_row_header(
		BALL_ROW_TITLE,
		"이 화면에서 최대 1개",
		COLOR_TEAL
	))

	_ball_row = HBoxContainer.new()
	_ball_row.name = "BallOfferRow"
	_ball_row.custom_minimum_size.y = _d(282.0)
	_ball_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ball_row.add_theme_constant_override(&"separation", _di(16))
	ball_shelf.add_child(_ball_row)

	var part_shelf := VBoxContainer.new()
	part_shelf.name = "PartShelf"
	part_shelf.custom_minimum_size.y = _d(330.0)
	part_shelf.add_theme_constant_override(&"separation", _di(10))
	column.add_child(part_shelf)
	part_shelf.add_child(_make_row_header(
		PART_ROW_TITLE,
		"이 화면에서 최대 1개",
		COLOR_GOLD
	))

	_part_row = HBoxContainer.new()
	_part_row.name = "PartOfferRow"
	_part_row.custom_minimum_size.y = _d(272.0)
	_part_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_part_row.add_theme_constant_override(&"separation", _di(16))
	part_shelf.add_child(_part_row)

	var footer := HBoxContainer.new()
	footer.name = "ShopFooter"
	footer.custom_minimum_size.y = _d(94.0)
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)

	_proceed_button = Button.new()
	_proceed_button.name = "ProceedButton"
	_proceed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_proceed_button.custom_minimum_size = Vector2(_d(200.0), _d(58.0))
	_proceed_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_proceed_button.add_theme_font_override(&"font", DISPLAY_FONT)
	_proceed_button.add_theme_font_size_override(&"font_size", _di(20))
	_proceed_button.pressed.connect(_on_proceed_pressed)
	footer.add_child(_proceed_button)
	var proceed_arrow := Label.new()
	proceed_arrow.name = "ProceedArrow"
	proceed_arrow.text = "→"
	proceed_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	proceed_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	proceed_arrow.add_theme_font_override(&"font", _body_font_bold)
	proceed_arrow.add_theme_font_size_override(&"font_size", _di(28))
	proceed_arrow.add_theme_color_override(&"font_color", COLOR_RED)
	proceed_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_proceed_button.add_child(proceed_arrow)
	proceed_arrow.set_anchor_and_offset(SIDE_RIGHT, 1.0, -_d(15.0))
	proceed_arrow.set_anchor_and_offset(SIDE_LEFT, 1.0, -_d(45.0))
	proceed_arrow.set_anchor_and_offset(SIDE_BOTTOM, 0.5, _d(16.0))
	proceed_arrow.set_anchor_and_offset(SIDE_TOP, 0.5, -_d(16.0))
	_refresh_proceed_button()
	_build_detail_popup()
	_build_handoff_overlay()


func _refresh_safe_margin() -> void:
	if _safe_margin == null:
		return
	var horizontal := maxi(16, roundi(size.x * 110.0 / 1920.0))
	var vertical := maxi(16, roundi(size.y * 44.0 / 1080.0))
	_safe_margin.add_theme_constant_override(&"margin_left", horizontal)
	_safe_margin.add_theme_constant_override(&"margin_right", horizontal)
	_safe_margin.add_theme_constant_override(&"margin_top", vertical)
	_safe_margin.add_theme_constant_override(&"margin_bottom", vertical)


func _build_detail_popup() -> void:
	_detail_popup = PanelContainer.new()
	_detail_popup.name = "RewardDetailPopup"
	_detail_popup.custom_minimum_size.x = _d(DETAIL_POPUP_WIDTH)
	_detail_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_popup.z_index = 10
	_detail_popup.visible = false
	var popup_style := _make_style(
		COLOR_CREAM,
		COLOR_INK,
		_di(6),
		_di(16),
		_di(18),
		_di(8),
		Vector2(_d(8.0), _d(10.0))
	)
	_detail_popup.add_theme_stylebox_override(&"panel", popup_style)
	add_child(_detail_popup)

	var column := VBoxContainer.new()
	column.name = "RewardDetailContent"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", _di(8))
	_detail_popup.add_child(column)

	_detail_tag_panel = PanelContainer.new()
	_detail_tag_panel.name = "RewardDetailTag"
	_detail_tag_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_detail_tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_detail_tag_panel)
	_detail_tag_label = _make_label("유형", _di(12), COLOR_INK, true)
	_detail_tag_label.name = "RewardDetailTagLabel"
	_detail_tag_panel.add_child(_detail_tag_label)

	_detail_title_label = _make_label("보상 이름", _di(24), COLOR_INK, true)
	_detail_title_label.name = "RewardDetailTitle"
	_detail_title_label.add_theme_font_override(&"font", DISPLAY_FONT)
	column.add_child(_detail_title_label)

	column.add_child(_make_divider())
	_detail_primary_label = _make_detail_line("핵심 효과", COLOR_NAVY_WOOD)
	_detail_primary_label.name = "RewardDetailPrimary"
	column.add_child(_detail_primary_label)
	_detail_secondary_label = _make_detail_line("주의 사항", COLOR_RED_DARK)
	_detail_secondary_label.name = "RewardDetailSecondary"
	column.add_child(_detail_secondary_label)


func _make_detail_line(text: String, color: Color) -> Label:
	var label := _make_label(text, _di(14), color, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = _d(DETAIL_POPUP_WIDTH - 48.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_handoff_overlay() -> void:
	_handoff_overlay = Control.new()
	_handoff_overlay.name = "HandoffOverlay"
	_handoff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_handoff_overlay.z_index = 20
	_handoff_overlay.visible = false
	add_child(_handoff_overlay)
	_handoff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.name = "HandoffDim"
	dim.color = Color(COLOR_NAVY_DEEP, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_handoff_overlay.add_child(dim)

	var burst := RewardHandoffBurst.new()
	burst.name = "HandoffBurst"
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handoff_overlay.add_child(burst)
	_set_relative_rect(burst, 0.28, 0.10, 0.72, 0.90)

	var sign := PanelContainer.new()
	sign.name = "NextWaveSign"
	sign.add_theme_stylebox_override(
		&"panel", _make_style(
			COLOR_CREAM,
			COLOR_INK,
			6,
			20,
			24,
			9,
			Vector2(7.0, 9.0)
		)
	)
	_handoff_overlay.add_child(sign)
	_set_relative_rect(sign, 0.25, 0.22, 0.75, 0.78)

	var column := VBoxContainer.new()
	column.name = "HandoffContent"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 10)
	sign.add_child(column)

	var closed := PanelContainer.new()
	closed.name = "ShopClosedRibbon"
	closed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	closed.add_theme_stylebox_override(
		&"panel", _make_style(COLOR_RED, COLOR_INK, 3, 9, 6)
	)
	closed.add_child(_make_label("REWARD SHOP · CLOSED", 10, COLOR_CREAM_LIGHT, true))
	column.add_child(closed)

	var title := _make_label("NEXT WAVE!", 48, COLOR_NAVY_WOOD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", DISPLAY_FONT)
	column.add_child(title)

	_handoff_wave_label = _make_label("웨이브 02 준비 완료", 22, COLOR_RED, true)
	_handoff_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_wave_label.add_theme_font_override(&"font", DISPLAY_FONT)
	column.add_child(_handoff_wave_label)

	var summary := HBoxContainer.new()
	summary.name = "HandoffSummary"
	summary.custom_minimum_size.y = 70.0
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override(&"separation", 9)
	column.add_child(summary)

	_handoff_ball_label = _make_handoff_chip(summary, "공", "선택 없음", COLOR_TEAL)
	_handoff_part_label = _make_handoff_chip(summary, "부품", "선택 없음", COLOR_GOLD)
	_handoff_coin_label = _make_handoff_chip(summary, "잔액", "0 COIN", COLOR_RED)

	var track := HBoxContainer.new()
	track.name = "WaveHandoffTrack"
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	track.add_theme_constant_override(&"separation", 8)
	column.add_child(track)
	var clear_chip := PanelContainer.new()
	clear_chip.add_theme_stylebox_override(
		&"panel", _make_style(COLOR_RED, COLOR_INK, 3, 8, 5)
	)
	clear_chip.add_child(_make_label("WAVE CLEAR", 9, COLOR_CREAM_LIGHT, true))
	track.add_child(clear_chip)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override(&"font_size", 18)
	arrow.add_theme_color_override(&"font_color", COLOR_INK)
	track.add_child(arrow)
	var ready_chip := PanelContainer.new()
	ready_chip.add_theme_stylebox_override(
		&"panel", _make_style(COLOR_TEAL_BRIGHT, COLOR_INK, 3, 8, 5)
	)
	ready_chip.add_child(_make_label("NEXT WAVE · READY", 9, COLOR_INK, true))
	track.add_child(ready_chip)

	_handoff_confirm_button = Button.new()
	_handoff_confirm_button.name = "HandoffConfirmButton"
	_handoff_confirm_button.text = "다음 웨이브 시작"
	_handoff_confirm_button.custom_minimum_size = Vector2(_d(240.0), _d(54.0))
	_handoff_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_handoff_confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_handoff_confirm_button.add_theme_font_override(&"font", DISPLAY_FONT)
	_handoff_confirm_button.add_theme_font_size_override(&"font_size", _di(18))
	_handoff_confirm_button.add_theme_color_override(&"font_color", COLOR_CREAM_LIGHT)
	_handoff_confirm_button.add_theme_color_override(&"font_hover_color", COLOR_CREAM_LIGHT)
	_handoff_confirm_button.add_theme_color_override(&"font_pressed_color", COLOR_CREAM_LIGHT)
	_handoff_confirm_button.add_theme_stylebox_override(
		&"normal", _make_proceed_style(COLOR_NAVY_WOOD, false)
	)
	_handoff_confirm_button.add_theme_stylebox_override(
		&"hover", _make_proceed_style(COLOR_NAVY_WOOD.lightened(0.08), false)
	)
	_handoff_confirm_button.add_theme_stylebox_override(
		&"pressed", _make_proceed_style(COLOR_NAVY_WOOD.darkened(0.08), true)
	)
	_handoff_confirm_button.pressed.connect(_confirm_handoff)
	column.add_child(_handoff_confirm_button)


func _make_handoff_chip(
	parent: HBoxContainer,
	label_text: String,
	value_text: String,
	background: Color
) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		&"panel", _make_style(background, COLOR_INK, 4, 10, 8)
	)
	parent.add_child(panel)
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(copy)
	var label := _make_label(label_text, 8, COLOR_INK, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(label)
	var value := _make_label(value_text, 13, COLOR_INK, true)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_override(&"font", DISPLAY_FONT)
	copy.add_child(value)
	return value


static func _set_relative_rect(
	control: Control,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> void:
	control.set_anchor_and_offset(SIDE_RIGHT, right, 0.0)
	control.set_anchor_and_offset(SIDE_BOTTOM, bottom, 0.0)
	control.set_anchor_and_offset(SIDE_LEFT, left, 0.0)
	control.set_anchor_and_offset(SIDE_TOP, top, 0.0)


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = "ShopHeader"
	header.custom_minimum_size.y = _d(128.0)
	header.add_theme_constant_override(&"separation", _di(12))
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_group := HBoxContainer.new()
	title_group.name = "WaveAndShopTitle"
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.add_theme_constant_override(&"separation", _di(20))
	title_group.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_child(title_group)

	var wave_badge := PanelContainer.new()
	wave_badge.name = "WaveClearBadge"
	wave_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wave_badge.custom_minimum_size = Vector2(_d(160.0), _d(97.0))
	var wave_badge_style := _make_style(
		COLOR_RED, COLOR_INK, _di(5), _di(13), _di(13), _di(4),
		Vector2(_d(5.0), _d(6.0))
	)
	wave_badge_style.content_margin_left = _d(18.0)
	wave_badge_style.content_margin_right = _d(18.0)
	wave_badge.add_theme_stylebox_override(&"panel", wave_badge_style)
	title_group.add_child(wave_badge)

	var result_column := VBoxContainer.new()
	result_column.name = "WaveResult"
	result_column.add_theme_constant_override(&"separation", 0)
	wave_badge.add_child(result_column)

	_wave_badge_label = _make_label("WAVE 01", _di(17), COLOR_GOLD, true)
	_wave_badge_label.name = "WaveBadgeLabel"
	result_column.add_child(_wave_badge_label)
	_summary_label = _make_label("CLEAR!", _di(33), COLOR_CREAM_LIGHT, true)
	_summary_label.name = "WaveResultLabel"
	_summary_label.add_theme_font_override(&"font", DISPLAY_FONT)
	result_column.add_child(_summary_label)

	var shop_title := VBoxContainer.new()
	shop_title.name = "ShopTitle"
	shop_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_title.add_theme_constant_override(&"separation", _di(1))
	title_group.add_child(shop_title)
	shop_title.add_child(_make_label("오늘의 전리품", _di(15), COLOR_GOLD, true))
	var title_label := _make_label("보상 상점", _di(54), COLOR_CREAM_LIGHT, true)
	title_label.name = "ShopTitleLabel"
	title_label.add_theme_font_override(&"font", DISPLAY_FONT)
	shop_title.add_child(title_label)

	var wallet_panel := PanelContainer.new()
	wallet_panel.name = "WalletPanel"
	wallet_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_panel.custom_minimum_size = Vector2(_d(177.0), _d(69.0))
	var wallet_style := _make_style(
		COLOR_GOLD, COLOR_INK, _di(5), _di(14), _di(10), _di(4),
		Vector2(_d(4.0), _d(5.0))
	)
	wallet_style.content_margin_left = _d(17.0)
	wallet_style.content_margin_right = _d(17.0)
	wallet_panel.add_theme_stylebox_override(&"panel", wallet_style)
	header.add_child(wallet_panel)

	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override(&"separation", _di(10))
	wallet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet_panel.add_child(wallet_row)

	var coin_icon := RewardCoinIcon.new()
	coin_icon.name = "WalletCoinIcon"
	coin_icon.custom_minimum_size = Vector2(_d(46.0), _d(46.0))
	wallet_row.add_child(coin_icon)

	_wallet_label = _make_label("0", _di(35), COLOR_INK, true)
	_wallet_label.name = "WalletValueLabel"
	_wallet_label.add_theme_font_override(&"font", DISPLAY_FONT)
	wallet_row.add_child(_wallet_label)
	wallet_row.add_child(_make_label("COIN", _di(13), COLOR_INK, true))

	var owned_panel := PanelContainer.new()
	owned_panel.name = "OwnedSummaryPanel"
	owned_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	owned_panel.custom_minimum_size = Vector2(_d(155.0), _d(61.0))
	var owned_style := _make_style(
		COLOR_CREAM, COLOR_INK, _di(4), _di(12), _di(10)
	)
	owned_style.content_margin_left = _d(15.0)
	owned_style.content_margin_right = _d(15.0)
	owned_panel.add_theme_stylebox_override(&"panel", owned_style)
	header.add_child(owned_panel)

	var owned_copy := VBoxContainer.new()
	owned_copy.name = "OwnedSummaryCopy"
	owned_copy.add_theme_constant_override(&"separation", _di(2))
	owned_panel.add_child(owned_copy)
	_owned_ball_label = _make_label(
		"보유 공 · 기본 유리눈", _di(14), COLOR_INK, true
	)
	_owned_ball_label.name = "OwnedBallLabel"
	_owned_ball_label.clip_text = true
	_owned_ball_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	owned_copy.add_child(_owned_ball_label)
	_owned_parts_label = _make_label(
		"부품 재고 · 없음", _di(13), COLOR_RED_DARK, false
	)
	_owned_parts_label.name = "OwnedPartsLabel"
	_owned_parts_label.clip_text = true
	_owned_parts_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	owned_copy.add_child(_owned_parts_label)
	return header


func _make_row_header(
	title: String,
	note: String,
	accent: Color
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var category_name := "Ball" if title == BALL_ROW_TITLE else "Part"
	row.name = "%sShelfHeader" % category_name
	row.custom_minimum_size.y = _d(ROW_HEADER_HEIGHT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var ribbon := PanelContainer.new()
	ribbon.name = "%sShelfRibbon" % category_name
	ribbon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ribbon_style := _make_style(
		accent,
		COLOR_INK,
		_di(4),
		_di(10),
		_di(ROW_TITLE_PADDING_VERTICAL)
	)
	ribbon_style.content_margin_left = _d(ROW_TITLE_PADDING_HORIZONTAL)
	ribbon_style.content_margin_right = _d(ROW_TITLE_PADDING_HORIZONTAL)
	ribbon.add_theme_stylebox_override(&"panel", ribbon_style)
	var ribbon_text := _make_label(
		title, _di(ROW_TITLE_FONT_SIZE), COLOR_INK, true
	)
	ribbon_text.name = "%sShelfTitle" % category_name
	ribbon_text.add_theme_font_override(&"font", DISPLAY_FONT)
	ribbon.add_child(ribbon_text)
	row.add_child(ribbon)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var note_panel := PanelContainer.new()
	note_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var note_style := _make_style(
		COLOR_CREAM, COLOR_INK, _di(3), _di(9), _di(6)
	)
	note_style.content_margin_left = _d(12.0)
	note_style.content_margin_right = _d(12.0)
	note_panel.add_theme_stylebox_override(&"panel", note_style)
	var note_label := _make_label(note, _di(13), COLOR_INK, true)
	if title == BALL_ROW_TITLE:
		note_label.name = "BallRuleLabel"
		_ball_rule_label = note_label
	else:
		note_label.name = "PartRuleLabel"
		_part_rule_label = note_label
	note_panel.add_child(note_label)
	row.add_child(note_panel)
	return row


func _make_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.color = COLOR_INK
	divider.custom_minimum_size.y = 1.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _on_shop_opened(_wave_id: int) -> void:
	_selected_index = -1
	_hovered_card_index = -1
	_purchased_ball_id = &""
	_purchased_part_id = &""
	_handoff_in_progress = false
	if _handoff_overlay != null:
		_handoff_overlay.visible = false
	_rebuild_cards()
	_refresh_header()
	visible = true
	set_process_unhandled_input(true)


func _on_shop_closed(_wave_id: int) -> void:
	_handoff_in_progress = false
	_hovered_card_index = -1
	_hide_card_detail()
	if _handoff_overlay != null:
		_handoff_overlay.visible = false
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
	_wave_badge_label.text = _wave_result_text if _wave_result_text != "" else "WAVE 01"
	_summary_label.text = "CLEAR!"
	_wallet_label.text = str(_wallet.balance if _wallet != null else 0)
	_refresh_owned_label()


func _refresh_owned_label() -> void:
	if _owned_ball_label == null or _owned_parts_label == null or _shop == null:
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
	_owned_ball_label.text = "보유 공 · %s" % " · ".join(ball_names)
	_owned_parts_label.text = "부품 재고 · %s" % part_text


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
	var art_well := _make_art_well(content)

	var art := TextureRect.new()
	art.name = "OfferArt"
	var ball_icon_size := _di(BALL_ICON_SIZE)
	art.custom_minimum_size = Vector2(ball_icon_size, ball_icon_size)
	art.texture = BallArtLibrary.icon_of(offer.ball_id, ball_icon_size)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_well.add_child(art)

	var group_index := clampi(offer.performance_group, 0, PERFORMANCE_NAMES.size() - 1)
	content.add_child(_make_price_panel(offer.price))
	var badge_data := _make_state_badge(content)
	_card_views.append({
		&"button": card,
		&"badge": badge_data[0],
		&"state_label": badge_data[1],
		&"price": offer.price,
		&"title": offer.display_name,
		&"bundle": 1,
		&"category": RewardShopController.CATEGORY_BALL,
		&"detail_tag": PERFORMANCE_NAMES[group_index],
		&"detail_accent": COLOR_TEAL,
		&"detail_primary": "+ " + offer.merit_text,
		&"detail_secondary": "− " + offer.cost_text,
	})
	return card


func _make_part_card(offer: RepairPartOffer, card_index: int) -> Button:
	var card := _make_card_shell(card_index)
	var content := _make_card_content(card)
	var art_well := _make_art_well(content)

	var art := RewardPartIcon.new()
	art.name = "OfferArt"
	art.custom_minimum_size = Vector2(_d(PART_ICON_SIZE), _d(PART_ICON_SIZE))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.set_part_id(offer.part_id)
	art_well.add_child(art)

	content.add_child(_make_price_panel(offer.price))
	var badge_data := _make_state_badge(content)
	_card_views.append({
		&"button": card,
		&"badge": badge_data[0],
		&"state_label": badge_data[1],
		&"price": offer.price,
		&"title": offer.display_name,
		&"bundle": offer.bundle_count,
		&"category": RewardShopController.CATEGORY_PART,
		&"part_id": offer.part_id,
		&"detail_tag": "x%d · %s" % [offer.bundle_count, offer.verb_text],
		&"detail_accent": COLOR_GOLD,
		&"detail_primary": "조건 · " + offer.condition_text,
		&"detail_secondary": "효과 · " + offer.effect_text,
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
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card_index))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card_index))
	card.focus_entered.connect(_on_card_focus_entered.bind(card_index))
	card.focus_exited.connect(_on_card_focus_exited.bind(card_index))
	return card


func _make_card_content(card: Button) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, _di(14))
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", _di(8))
	margin.add_child(content)
	return content


func _make_art_well(content: VBoxContainer) -> PanelContainer:
	var well := PanelContainer.new()
	well.name = "OfferArtWell"
	well.custom_minimum_size = Vector2(
		_d(OFFER_ART_WELL_SIZE), _d(OFFER_ART_WELL_SIZE)
	)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override(
		&"panel", _make_style(
			COLOR_CREAM_LIGHT, COLOR_INK, _di(4), _di(13)
		)
	)
	content.add_child(well)
	return well


func _make_price_panel(price: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "OfferPrice"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price_style := _make_style(
		COLOR_GOLD, COLOR_INK, _di(3), _di(9), _di(5)
	)
	price_style.content_margin_left = _d(9.0)
	price_style.content_margin_right = _d(9.0)
	panel.add_theme_stylebox_override(&"panel", price_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", _di(5))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var coin := RewardCoinIcon.new()
	coin.name = "PriceCoinIcon"
	coin.custom_minimum_size = Vector2(_d(28.0), _d(28.0))
	row.add_child(coin)
	row.add_child(_make_label(str(price), _di(18), COLOR_INK, true))
	return panel


func _make_state_badge(content: VBoxContainer) -> Array[Control]:
	var state_row := HBoxContainer.new()
	state_row.name = "StateRow"
	state_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_row.alignment = BoxContainer.ALIGNMENT_END
	state_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(state_row)
	var badge := PanelContainer.new()
	badge.name = "StateBadge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_END
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_row.add_child(badge)

	var label := _make_label("구매 가능", _di(13), COLOR_INK, true)
	label.name = "StateLabel"
	badge.add_child(label)
	return [badge, label]


func _make_label(
	text: String,
	font_size: int,
	color: Color,
	bold := false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(
		&"font", _body_font_bold if bold else _body_font_semibold
	)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_body_font(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = BODY_FONT_SOURCE
	var text_server := TextServerManager.get_primary_interface()
	font.variation_opentype = {text_server.name_to_tag("wght"): weight}
	return font


func _d(value: float) -> float:
	return value * _design_scale


func _di(value: float) -> int:
	return maxi(1, roundi(_d(value)))


func _on_card_pressed(card_index: int) -> void:
	if _selected_index == card_index:
		_confirm_selected()
		return
	_selected_index = card_index
	_refresh_card_states()
	_show_card_detail(card_index)


func _on_card_mouse_entered(card_index: int) -> void:
	_hovered_card_index = card_index
	_show_card_detail(card_index)


func _on_card_mouse_exited(card_index: int) -> void:
	if _hovered_card_index == card_index:
		_hovered_card_index = -1
	_restore_active_card_detail()


func _on_card_focus_entered(card_index: int) -> void:
	_show_card_detail(card_index)


func _on_card_focus_exited(_card_index: int) -> void:
	_restore_active_card_detail()


func _restore_active_card_detail() -> void:
	if _hovered_card_index >= 0:
		_show_card_detail(_hovered_card_index)
	elif _selected_index >= 0:
		_show_card_detail(_selected_index)
	else:
		_hide_card_detail()


func _show_card_detail(card_index: int) -> void:
	if _detail_popup == null or card_index < 0 \
			or card_index >= _card_views.size():
		return
	var view := _card_views[card_index]
	_detail_tag_label.text = String(view[&"detail_tag"])
	_detail_title_label.text = String(view[&"title"])
	_detail_primary_label.text = String(view[&"detail_primary"])
	_detail_secondary_label.text = String(view[&"detail_secondary"])
	_detail_tag_panel.add_theme_stylebox_override(
		&"panel",
		_make_style(
			view[&"detail_accent"] as Color,
			COLOR_INK,
			_di(3),
			_di(8),
			_di(6)
		)
	)
	_detail_popup.visible = true
	call_deferred(&"_position_card_detail", card_index)


func _position_card_detail(card_index: int) -> void:
	if _detail_popup == null or not _detail_popup.visible \
			or card_index < 0 or card_index >= _card_views.size():
		return
	var card := _card_views[card_index][&"button"] as Button
	if card == null or not is_instance_valid(card):
		return
	var card_rect := card.get_global_rect()
	var hud_origin := get_global_rect().position
	var local_card_position := card_rect.position - hud_origin
	var popup_size := _detail_popup.size
	var x := local_card_position.x + (card_rect.size.x - popup_size.x) * 0.5
	var card_center_y := local_card_position.y + card_rect.size.y * 0.5
	var y := (
		local_card_position.y + card_rect.size.y + _d(10.0)
		if card_center_y < size.y * 0.55
		else local_card_position.y - popup_size.y - _d(10.0)
	)
	x = clampf(x, _d(20.0), size.x - popup_size.x - _d(20.0))
	y = clampf(y, _d(20.0), size.y - popup_size.y - _d(20.0))
	_detail_popup.position = Vector2(x, y)


func _hide_card_detail() -> void:
	if _detail_popup != null:
		_detail_popup.visible = false


func _on_proceed_pressed() -> void:
	if _selected_index >= 0 \
			and _selected_index < _card_views.size() \
			and _card_state_of(_selected_index) == CardState.SELECTED:
		_confirm_selected()
		return
	if _handoff_in_progress:
		return
	_play_handoff_then_proceed()


func _play_handoff_then_proceed() -> void:
	_handoff_in_progress = true
	_hide_card_detail()
	_refresh_handoff_summary()
	_handoff_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_handoff_overlay.visible = true
	_handoff_confirm_button.disabled = false
	var fade_in := create_tween()
	fade_in.tween_property(_handoff_overlay, ^"modulate:a", 1.0, 0.12)
	_handoff_confirm_button.call_deferred(&"grab_focus")


func _confirm_handoff() -> void:
	if not _handoff_in_progress:
		return
	_handoff_in_progress = false
	_handoff_confirm_button.disabled = true
	proceed_requested.emit()


func _refresh_handoff_summary() -> void:
	match _reward_destination_text:
		"보스 진행":
			_handoff_wave_label.text = "보스전 준비 완료"
		"스테이지 완료":
			_handoff_wave_label.text = "스테이지 보상 정산 완료"
		_:
			var next_wave := mini(_next_wave_number, _total_wave_count) \
				if _total_wave_count > 0 else _next_wave_number
			_handoff_wave_label.text = "웨이브 %02d 준비 완료" % next_wave
	_handoff_ball_label.text = (
		"기본 유리눈"
		if _purchased_ball_id == &""
		else _offer_display_name(RewardShopController.CATEGORY_BALL, _purchased_ball_id)
	)
	if _purchased_part_id == &"":
		_handoff_part_label.text = "선택 없음"
	else:
		_handoff_part_label.text = "%s x%d" % [
			_offer_display_name(RewardShopController.CATEGORY_PART, _purchased_part_id),
			_part_bundle_count(_purchased_part_id),
		]
	_handoff_coin_label.text = "%d COIN" % (_wallet.balance if _wallet != null else 0)


func _offer_display_name(category: StringName, item_id: StringName) -> String:
	if _shop == null or _shop.catalog == null:
		return String(item_id)
	if category == RewardShopController.CATEGORY_BALL:
		for offer in _shop.catalog.ball_offers:
			if offer != null and offer.ball_id == item_id:
				return offer.display_name
	else:
		for offer in _shop.catalog.part_offers:
			if offer != null and offer.part_id == item_id:
				return offer.display_name
	return String(item_id)


func _part_bundle_count(part_id: StringName) -> int:
	if _shop == null or _shop.catalog == null:
		return 0
	for offer in _shop.catalog.part_offers:
		if offer != null and offer.part_id == part_id:
			return offer.bundle_count
	return 0


func _move_selection(step: int) -> void:
	if _cards.is_empty():
		return
	_selected_index = posmod(_selected_index + step, _cards.size())
	_refresh_card_states()
	_cards[_selected_index].grab_focus()
	_show_card_detail(_selected_index)


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
	_refresh_row_rules()
	_refresh_proceed_button()


func _refresh_row_rules() -> void:
	if _shop == null:
		return
	if _ball_rule_label != null:
		_ball_rule_label.text = (
			"구매 완료 · 같은 줄 잠김"
			if _shop.ball_purchase_used
			else "이 화면에서 최대 1개"
		)
	if _part_rule_label != null:
		if _shop.part_purchase_used:
			_part_rule_label.text = "구매 완료 · 같은 줄 잠김"
		elif _selected_index >= _shop.ball_offers.size():
			_part_rule_label.text = "선택한 부품을 다시 확인"
		else:
			_part_rule_label.text = "이 화면에서 최대 1개"


func _apply_card_state(card_index: int, state: CardState) -> void:
	var view := _card_views[card_index]
	var card := view[&"button"] as Button
	var badge := view[&"badge"] as PanelContainer
	var state_label := view[&"state_label"] as Label
	var background := COLOR_CREAM
	var border := COLOR_INK
	var border_width := _di(5)
	var status_color := COLOR_INK
	var badge_background := COLOR_TEAL
	var status_text := "구매 가능"
	var opacity := 1.0

	match state:
		CardState.SELECTED:
			background = COLOR_CREAM_LIGHT
			border = COLOR_TEAL_BRIGHT
			border_width = _di(7)
			badge_background = COLOR_TEAL
			status_text = "선택!"
		CardState.PURCHASED:
			background = COLOR_GOLD
			border = COLOR_INK
			border_width = _di(5)
			badge_background = COLOR_RED
			status_color = COLOR_CREAM_LIGHT
			status_text = "GET!"
		CardState.ROW_LOCKED:
			background = COLOR_LOCKED
			badge_background = COLOR_NAVY_DEEP
			status_color = COLOR_CREAM_LIGHT
			status_text = "잠김"
			opacity = 0.52
		CardState.INSUFFICIENT:
			border = COLOR_RED
			border_width = _di(5)
			badge_background = COLOR_RED
			status_color = COLOR_CREAM_LIGHT
			status_text = "코인 부족"
			opacity = 0.72

	card.disabled = state in [
		CardState.PURCHASED,
		CardState.ROW_LOCKED,
		CardState.INSUFFICIENT,
	]
	card.modulate = Color(1.0, 1.0, 1.0, opacity)
	badge.visible = state != CardState.AVAILABLE
	var card_style := _make_style(
		background,
		border,
		border_width,
		_di(CARD_RADIUS),
		0,
		_di(4),
		Vector2(_d(6.0), _d(7.0))
	)
	for style_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		card.add_theme_stylebox_override(style_name, card_style)
	state_label.text = status_text
	state_label.add_theme_color_override(&"font_color", status_color)
	badge.add_theme_stylebox_override(
		&"panel",
		_make_style(
			badge_background, COLOR_INK, _di(3), _di(9), _di(6)
		)
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
	var has_selection := _selected_index >= 0 \
			and _selected_index < _card_views.size() \
			and _card_state_of(_selected_index) == CardState.SELECTED
	var completed := ball_bought and part_bought
	if has_selection:
		var selected_view := _card_views[_selected_index]
		_proceed_button.text = "%s 구매 · %d" % [
			String(selected_view[&"title"]),
			int(selected_view[&"price"]),
		]
	elif completed:
		_proceed_button.text = "다음 웨이브 준비"
	elif ball_bought or part_bought:
		_proceed_button.text = "다음 단계"
	else:
		_proceed_button.text = "구매 없이 진행"

	var normal_color := COLOR_TEAL_BRIGHT \
			if has_selection or ball_bought or part_bought \
			else COLOR_CREAM
	var text_color := COLOR_INK
	_proceed_button.add_theme_color_override(&"font_color", text_color)
	_proceed_button.add_theme_color_override(&"font_hover_color", text_color)
	_proceed_button.add_theme_color_override(&"font_pressed_color", text_color)
	_proceed_button.add_theme_stylebox_override(
		&"normal", _make_proceed_style(normal_color, false)
	)
	_proceed_button.add_theme_stylebox_override(
		&"hover", _make_proceed_style(normal_color.lightened(0.08), false)
	)
	_proceed_button.add_theme_stylebox_override(
		&"pressed", _make_proceed_style(normal_color.darkened(0.08), true)
	)


func _make_proceed_style(background: Color, pressed: bool) -> StyleBoxFlat:
	var style := _make_style(
		background,
		COLOR_INK,
		_di(6),
		_di(15),
		_di(10),
		_di(1 if pressed else 5),
		Vector2(_d(1.0), _d(1.0)) if pressed else Vector2(_d(7.0), _d(8.0))
	)
	style.content_margin_left = _d(24.0)
	style.content_margin_right = _d(48.0)
	return style


func _clear_cards() -> void:
	_hide_card_detail()
	for card in _cards:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	_card_views.clear()
	_selected_index = -1
	_hovered_card_index = -1


static func _make_style(
	background: Color,
	border: Color,
	border_width: int,
	radius: int,
	content_margin := 0,
	shadow_size := 0,
	shadow_offset := Vector2.ZERO
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
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		style.shadow_size = shadow_size
		style.shadow_offset = shadow_offset
	return style


class RewardBackdropDecoration:
	extends Control
	var design_scale := 1.0

	func _ready() -> void:
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		_draw_star(
			Vector2(96.0, 145.0) * design_scale,
			50.0 * design_scale,
			10,
			COLOR_GOLD,
			9.0
		)
		_draw_star(
			Vector2(1808.0, 863.0) * design_scale,
			43.0 * design_scale,
			8,
			COLOR_RED,
			-7.0
		)

	func _draw_star(
		center: Vector2,
		radius: float,
		count: int,
		color: Color,
		rotation_degrees: float
	) -> void:
		var points := PackedVector2Array()
		for index in count * 2:
			var point_radius := radius if index % 2 == 0 else radius * 0.50
			points.append(
				center + Vector2.from_angle(
					-PI * 0.5 + deg_to_rad(rotation_degrees) + PI * index / count
				) * point_radius
			)
		draw_colored_polygon(points, color)
		var closed_points := points.duplicate()
		closed_points.append(points[0])
		draw_polyline(closed_points, COLOR_INK, 5.0 * design_scale, true)


class RewardBoothDecoration:
	extends Control
	var design_scale := 1.0

	func _ready() -> void:
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var bolt_center := 35.0 * design_scale
		var bolt_radius := 15.0 * design_scale
		for center in [
			Vector2(bolt_center, bolt_center),
			Vector2(size.x - bolt_center, bolt_center),
			Vector2(bolt_center, size.y - bolt_center),
			Vector2(size.x - bolt_center, size.y - bolt_center),
		]:
			draw_circle(center, bolt_radius, COLOR_GOLD)
			draw_arc(
				center, bolt_radius, 0.0, TAU, 24, COLOR_INK, 4.0 * design_scale, true
			)


class RewardHandoffBurst:
	extends Control

	func _ready() -> void:
		resized.connect(queue_redraw)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var center := size * 0.5
		var outer_radius := minf(size.x, size.y) * 0.48
		var points := PackedVector2Array()
		for index in 36:
			var radius := outer_radius if index % 2 == 0 else outer_radius * 0.77
			points.append(
				center + Vector2.from_angle(-PI * 0.5 + TAU * index / 36.0) * radius
			)
		draw_colored_polygon(points, COLOR_GOLD)
		var closed_points := points.duplicate()
		closed_points.append(points[0])
		draw_polyline(closed_points, COLOR_INK, 5.0, true)


class RewardCoinIcon:
	extends TextureRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture = COIN_TEXTURE
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


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
		draw_circle(center + Vector2(0.0, diameter * 0.04), radius, COLOR_INK)
		draw_circle(center, radius, COLOR_NAVY_DEEP)
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
				return COLOR_RED
			&"golden_gears":
				return COLOR_GOLD
			&"crescent_needle":
				return COLOR_PURPLE
			_:
				return COLOR_TEAL

	func _draw_brooch(center: Vector2, radius: float, accent: Color) -> void:
		var points := PackedVector2Array()
		for index in 10:
			var point_radius := radius * (0.62 if index % 2 == 0 else 0.29)
			points.append(Vector2.from_angle(-PI * 0.5 + index * PI / 5.0) * point_radius + center)
		draw_colored_polygon(points, COLOR_CREAM_LIGHT)
		draw_circle(center, radius * 0.15, accent)

	func _draw_gears(center: Vector2, radius: float, accent: Color) -> void:
		for index in 8:
			var angle := TAU * index / 8.0
			draw_circle(center + Vector2.from_angle(angle) * radius * 0.49, radius * 0.16, COLOR_CREAM_LIGHT)
		draw_circle(center, radius * 0.46, COLOR_CREAM_LIGHT)
		draw_circle(center, radius * 0.17, accent)

	func _draw_needle(center: Vector2, radius: float, accent: Color) -> void:
		draw_arc(center, radius * 0.52, -2.2, 1.2, 28, COLOR_CREAM_LIGHT, maxf(3.0, radius * 0.13), true)
		draw_circle(center + Vector2(-0.33, -0.42) * radius, radius * 0.10, accent)

	func _draw_bell(center: Vector2, radius: float, accent: Color) -> void:
		draw_circle(center, radius * 0.46, COLOR_CREAM_LIGHT)
		draw_rect(Rect2(center + Vector2(-0.46, 0.02) * radius, Vector2(0.92, 0.34) * radius), COLOR_CREAM_LIGHT)
		draw_circle(center + Vector2(0.0, 0.48) * radius, radius * 0.11, accent)
