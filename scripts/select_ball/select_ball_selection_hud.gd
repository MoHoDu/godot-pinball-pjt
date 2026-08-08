class_name SelectBallSelectionHud
extends BallSelectionHud


const DUMMY_BALL_ICON: Texture2D = preload(
	"res://Resources/Art/balls/glass_eye_ball.png"
)
const SLOT_BUTTON_SCENE: PackedScene = preload(
	"res://Resources/Prefabs/ui/ball_selection/current/select_ball_slot_button.tscn"
)
const COLOR_TEXT_PRIMARY := Color("f1e6cb")
const COLOR_TEXT_SECONDARY := Color("c6bda8")
const COLOR_TEXT_MUTED := Color("829b99")
const COLOR_ACCENT := Color("67d8d0")


@onready var slots_container: HBoxContainer = %SlotsContainer
@onready var mass_label: Label = %MassLabel
@onready var elasticity_label: Label = %ElasticityLabel
@onready var feature_label: Label = %FeatureLabel
@onready var confirm_button: Button = %ConfirmButton


var _slot_buttons: Dictionary[StringName, Button] = {}
var _slot_button_group := ButtonGroup.new()


func _ready() -> void:
	visible = false
	stock_label.visible = false
	confirm_button.pressed.connect(_on_confirm_pressed)


func bind_ball_flow(flow: WaveBallFlowController) -> bool:
	if flow == null or not flow.inventory is SelectBallInventory:
		return false
	_unbind()
	_flow = flow
	_inventory = flow.inventory
	_flow.state_changed.connect(_on_state_changed)
	_flow.selection_lock_changed.connect(_on_selection_lock_changed)
	_inventory.selection_started.connect(_on_selection_updated)
	_inventory.selection_changed.connect(_on_selection_updated)
	_inventory.ball_consumed.connect(_on_ball_used)
	_inventory.stock_reset.connect(_on_inventory_reset)
	_refresh()
	return true


func _unbind() -> void:
	if _flow != null and is_instance_valid(_flow):
		if _flow.state_changed.is_connected(_on_state_changed):
			_flow.state_changed.disconnect(_on_state_changed)
		if _flow.selection_lock_changed.is_connected(_on_selection_lock_changed):
			_flow.selection_lock_changed.disconnect(_on_selection_lock_changed)
	if _inventory != null and is_instance_valid(_inventory):
		if _inventory.selection_started.is_connected(_on_selection_updated):
			_inventory.selection_started.disconnect(_on_selection_updated)
		if _inventory.selection_changed.is_connected(_on_selection_updated):
			_inventory.selection_changed.disconnect(_on_selection_updated)
		if _inventory.ball_consumed.is_connected(_on_ball_used):
			_inventory.ball_consumed.disconnect(_on_ball_used)
		if _inventory.stock_reset.is_connected(_on_inventory_reset):
			_inventory.stock_reset.disconnect(_on_inventory_reset)
	_flow = null
	_inventory = null


func _on_state_changed(
	_previous_state: WaveBallFlowController.State,
	_current_state: WaveBallFlowController.State
) -> void:
	_refresh()


func _on_selection_lock_changed(_is_locked: bool) -> void:
	_refresh()


func _on_selection_updated(
	_definition: BallDefinition,
	_remaining: int
) -> void:
	_refresh()


func _on_ball_used(
	_definition: BallDefinition,
	_remaining_for_type: int,
	_total_remaining: int
) -> void:
	_refresh()


func _on_inventory_reset(_total_remaining: int) -> void:
	_refresh()


func _on_confirm_pressed() -> void:
	if _flow != null:
		_flow.confirm_selection()


func _on_slot_pressed(ball_id: StringName) -> void:
	if _inventory != null:
		_inventory.select_ball(ball_id)


func _refresh() -> void:
	if _flow == null or _inventory == null:
		visible = false
		return
	visible = _flow.current_state == WaveBallFlowController.State.SELECTING
	if not visible:
		return

	_sync_slots()
	var definition := _inventory.selected_definition
	if definition == null:
		title_label.text = "선택 가능한 공 없음"
		ball_name_label.text = "-"
		mass_label.text = "무게 -"
		elasticity_label.text = "탄성 -"
		feature_label.text = "이번 웨이브에서 모든 보유 공을 사용했습니다."
		confirm_button.disabled = true
		return

	title_label.text = "다음 공 선택"
	ball_name_label.text = definition.display_name
	var physics := _get_effective_physics(definition)
	mass_label.text = "무게 %.1f kg" % float(physics.mass)
	elasticity_label.text = "탄성 %d%%" % roundi(float(physics.elasticity) * 100.0)
	feature_label.text = _get_feature_summary(definition)
	confirm_button.disabled = _flow.selection_locked
	guide_label.text = (
		"B: 웨이브 클리어    V: 남은 공 계속 사용"
		if _flow.selection_locked
		else "A/D 또는 방향키: 공 선택    Space: 선택 확정\n"
			+ "확정 후 조준과 발사는 기존 입력을 사용합니다."
	)


func _sync_slots() -> void:
	var select_inventory := _inventory as SelectBallInventory
	var owned_definitions := select_inventory.get_owned_definitions()
	var needs_rebuild := slots_container.get_child_count() != owned_definitions.size()
	if not needs_rebuild:
		for definition: BallDefinition in owned_definitions:
			if not _slot_buttons.has(definition.ball_id):
				needs_rebuild = true
				break
	if needs_rebuild:
		_rebuild_slots(owned_definitions)

	for definition: BallDefinition in owned_definitions:
		var button := _slot_buttons.get(definition.ball_id) as Button
		if button == null:
			continue
		var used := select_inventory.is_ball_used(definition.ball_id)
		var selected := definition == _inventory.selected_definition
		button.disabled = used
		button.button_pressed = selected
		button.modulate = Color(1.0, 1.0, 1.0, 0.55 if used else 1.0)
		(button.get_node("%BallIcon") as TextureRect).texture = DUMMY_BALL_ICON
		(button.get_node("%FocusRing") as TextureRect).visible = selected
		(button.get_node("%UsedSlash") as ColorRect).visible = used
		var name_label := button.get_node("%BallName") as Label
		name_label.text = definition.display_name
		name_label.add_theme_color_override(
			"font_color",
			COLOR_TEXT_MUTED if used else COLOR_TEXT_PRIMARY
		)
		var status_text := button.get_node("%StatusText") as Label
		status_text.text = (
			"이번 웨이브 사용됨"
			if used
			else ("현재 선택" if selected else "사용 가능")
		)
		status_text.add_theme_color_override(
			"font_color",
			COLOR_TEXT_MUTED
			if used
			else (COLOR_ACCENT if selected else COLOR_TEXT_SECONDARY)
		)
		button.tooltip_text = "%s · %s" % [definition.display_name, status_text.text]


func _rebuild_slots(owned_definitions: Array[BallDefinition]) -> void:
	for child: Node in slots_container.get_children():
		slots_container.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()

	for definition: BallDefinition in owned_definitions:
		var button := SLOT_BUTTON_SCENE.instantiate() as Button
		button.name = "BallSlot_%s" % definition.ball_id
		button.button_group = _slot_button_group
		button.set_meta(&"ball_id", definition.ball_id)
		button.pressed.connect(_on_slot_pressed.bind(definition.ball_id))
		slots_container.add_child(button)
		_slot_buttons[definition.ball_id] = button


func _get_effective_physics(definition: BallDefinition) -> Dictionary:
	var values := {&"mass": 0.0, &"elasticity": 0.0}
	if definition == null or definition.ball_scene == null:
		return values
	var instance := definition.ball_scene.instantiate()
	if instance is Pinball:
		var preview_ball := instance as Pinball
		values.mass = preview_ball.physics_rules.get_effective_mass(
			preview_ball.stats
		)
		values.elasticity = preview_ball.physics_rules.get_effective_elasticity(
			preview_ball.stats
		)
	instance.free()
	return values


func _get_feature_summary(definition: BallDefinition) -> String:
	if definition is SelectBallDefinition:
		var summary := (definition as SelectBallDefinition).feature_summary.strip_edges()
		if not summary.is_empty():
			return summary
	return "핵심 특징 설명이 아직 등록되지 않았습니다."
