class_name RewardChoiceHud
extends Control


## 웨이브 사이 유물 선택창입니다.
## 아트 확정 전까지 쓰는 임시 카드입니다. 도형과 텍스트만 씁니다.


const CARD_SIZE := Vector2(360.0, 260.0)
const CARD_NORMAL_COLOR := Color(0.09, 0.11, 0.15, 0.96)
const CARD_SELECTED_COLOR := Color(0.16, 0.22, 0.26, 1.0)
const CARD_BORDER_COLOR := Color(0.26, 0.30, 0.36, 1.0)
const CARD_SELECTED_BORDER_COLOR := Color(0.98, 0.82, 0.35, 1.0)


@onready var _dim: ColorRect = %Dim
@onready var _title_label: Label = %TitleLabel
@onready var _card_row: HBoxContainer = %CardRow
@onready var _guide_label: Label = %GuideLabel
@onready var _owned_label: Label = %OwnedLabel


var _controller: RewardChoiceController
var _relic_inventory: RelicInventory
var _cards: Array[Button] = []


func _ready() -> void:
	visible = false


func bind_controller(
	controller: RewardChoiceController,
	relic_inventory: RelicInventory = null
) -> bool:
	if controller == null:
		return false
	unbind_controller()
	_controller = controller
	_relic_inventory = relic_inventory
	_controller.choices_presented.connect(_on_choices_presented)
	_controller.selection_changed.connect(_on_selection_changed)
	_controller.choice_confirmed.connect(_on_choice_confirmed)
	_controller.sequence_finished.connect(_on_sequence_finished)
	return true


func unbind_controller() -> void:
	if _controller != null and is_instance_valid(_controller):
		if _controller.choices_presented.is_connected(_on_choices_presented):
			_controller.choices_presented.disconnect(_on_choices_presented)
		if _controller.selection_changed.is_connected(_on_selection_changed):
			_controller.selection_changed.disconnect(_on_selection_changed)
		if _controller.choice_confirmed.is_connected(_on_choice_confirmed):
			_controller.choice_confirmed.disconnect(_on_choice_confirmed)
		if _controller.sequence_finished.is_connected(_on_sequence_finished):
			_controller.sequence_finished.disconnect(_on_sequence_finished)
	_controller = null


func get_card_count() -> int:
	return _cards.size()


func _on_choices_presented(
	choices: Array[RelicDefinition],
	wave_index: int
) -> void:
	_title_label.text = "WAVE %02d 수리 완료 · 부품을 하나 고르세요" % (wave_index + 1)
	_guide_label.text = "←/→ 또는 A/D: 이동    Space: 확정    (카드를 눌러도 됩니다)"
	_rebuild_cards(choices)
	_refresh_owned_label()
	_apply_selection(_controller.selected_index)
	visible = true


func _on_selection_changed(selected_index: int) -> void:
	_apply_selection(selected_index)


func _on_choice_confirmed(
	_definition: RelicDefinition,
	_stack_count: int
) -> void:
	visible = false
	_clear_cards()


func _on_sequence_finished(reason: StringName) -> void:
	_clear_cards()
	if reason != &"stage_cleared":
		visible = false
		return
	_title_label.text = "수리 완료"
	_guide_label.text = ""
	_refresh_owned_label()
	visible = true


func _rebuild_cards(choices: Array[RelicDefinition]) -> void:
	_clear_cards()
	for index in choices.size():
		var definition: RelicDefinition = choices[index]
		var card := _create_card(definition, index)
		_card_row.add_child(card)
		_cards.append(card)


func _create_card(definition: RelicDefinition, index: int) -> Button:
	var card := Button.new()
	card.name = "RelicCard%d" % index
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.clip_text = false
	var owned_suffix := ""
	if _relic_inventory != null:
		var owned := _relic_inventory.get_stack_count(definition.relic_id)
		if owned > 0:
			owned_suffix = "\n(보유 %d / %d)" % [owned, definition.max_stack]
	card.text = "%d. %s\n\n%s\n\n%s%s" % [
		index + 1,
		definition.display_name,
		definition.describe(_next_stack_count(definition)),
		definition.flavor_text,
		owned_suffix,
	]
	card.pressed.connect(_on_card_pressed.bind(index))
	card.mouse_entered.connect(_on_card_hovered.bind(index))
	return card


## 카드에는 "지금 고르면 얼마가 되는지"를 적습니다. 보유 중이면 다음 스택 기준입니다.
func _next_stack_count(definition: RelicDefinition) -> int:
	if _relic_inventory == null:
		return 1
	return _relic_inventory.get_stack_count(definition.relic_id) + 1


func _on_card_pressed(index: int) -> void:
	if _controller == null:
		return
	_controller.confirm_selection(index)


func _on_card_hovered(index: int) -> void:
	if _controller == null:
		return
	_controller.select_index(index)


func _apply_selection(selected_index: int) -> void:
	for index in _cards.size():
		var card := _cards[index]
		var is_selected := index == selected_index
		card.add_theme_stylebox_override(
			&"normal",
			_make_card_style(is_selected)
		)
		card.add_theme_stylebox_override(
			&"hover",
			_make_card_style(is_selected)
		)
		card.add_theme_stylebox_override(
			&"pressed",
			_make_card_style(true)
		)


func _make_card_style(is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_SELECTED_COLOR if is_selected else CARD_NORMAL_COLOR
	style.border_color = CARD_SELECTED_BORDER_COLOR \
		if is_selected else CARD_BORDER_COLOR
	var border_width := 5 if is_selected else 2
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	return style


func _refresh_owned_label() -> void:
	if _relic_inventory == null:
		_owned_label.text = ""
		return
	_owned_label.text = "수리함: %s" % _relic_inventory.describe_all()


func _clear_cards() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()


func _exit_tree() -> void:
	unbind_controller()
