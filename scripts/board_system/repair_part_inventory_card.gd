class_name RepairPartInventoryCard
extends Button


signal interaction_started(kind_id: StringName, viewport_position: Vector2)


@onready var _type_label: Label = %TypeLabel
@onready var _name_label: Label = %NameLabel
@onready var _feature_label: Label = %FeatureLabel
@onready var _icon_label: Label = %IconLabel
@onready var _stack_back: Control = %StackBack
@onready var _stack_middle: Control = %StackMiddle
@onready var _stack_count: Label = %StackCount


var kind_id: StringName


func _ready() -> void:
	button_down.connect(_on_button_down)


func configure(data: Dictionary, is_compatible: bool) -> void:
	kind_id = StringName(data.get(&"kind_id", &""))
	var available_count := maxi(int(data.get(&"available_count", 0)), 0)
	_type_label.text = "수리 부품"
	_name_label.text = String(data.get(&"display_name", "이름 없음"))
	_feature_label.text = String(data.get(&"feature", ""))
	_icon_label.text = String(data.get(&"placeholder_icon", "?"))
	_stack_count.text = "×%d" % available_count
	_stack_back.visible = available_count >= 2
	_stack_middle.visible = available_count >= 3
	disabled = not is_compatible or available_count <= 0
	tooltip_text = (
		"선택한 소켓에 배치할 수 없습니다"
		if not is_compatible
		else "보유 수량이 없습니다" if available_count <= 0 else ""
	)


func get_stack_text() -> String:
	return _stack_count.text


func has_layered_stack() -> bool:
	return _stack_back.visible or _stack_middle.visible


func _on_button_down() -> void:
	if disabled or kind_id.is_empty():
		return
	interaction_started.emit(kind_id, get_viewport().get_mouse_position())
