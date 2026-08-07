class_name WaveLifeHud
extends Control


const SLOT_SIZE := Vector2(56.0, 56.0)
const SLOT_GAP := 12.0
const LEFT_PADDING := 18.0
const SLOT_Y := 17.0
const OUTLINE_SIZE := Vector2(68.0, 68.0)

const ICON_TEXTURES := {
	&"normal": preload("res://Resources/wave_hud/wave_hud_runtime_dark/life/ball_normal.png"),
	&"cat_eye": preload("res://Resources/wave_hud/wave_hud_runtime_dark/life/ball_cat_eye.png"),
	&"industrial_steel": preload("res://Resources/wave_hud/wave_hud_runtime_dark/life/ball_industrial_steel.png"),
	&"light": preload("res://Resources/wave_hud/wave_hud_runtime_dark/life/ball_cat_eye.png"),
	&"heavy": preload("res://Resources/wave_hud/wave_hud_runtime_dark/life/ball_industrial_steel.png"),
}
const CURRENT_OUTLINE := preload(
	"res://Resources/wave_hud/wave_hud_runtime_dark/life/current_outline.png"
)

@onready var _shadow: NinePatchRect = %PanelShadow
@onready var _fill: NinePatchRect = %PanelFill
@onready var _border: NinePatchRect = %PanelBorder
@onready var _slots: Control = %Slots


func render(snapshot: Dictionary) -> void:
	var life_slots: Array = snapshot.get(&"life_slots", [])
	if life_slots.is_empty():
		visible = false
		return
	visible = true
	var panel_width := 36.0 + life_slots.size() * SLOT_SIZE.x \
		+ maxi(life_slots.size() - 1, 0) * SLOT_GAP
	custom_minimum_size = Vector2(panel_width, 90.0)
	size = custom_minimum_size
	_shadow.size = Vector2(panel_width + 8.0, 98.0)
	_fill.size = Vector2(panel_width, 90.0)
	_border.size = Vector2(panel_width + 3.0, 93.0)
	_rebuild_slots(life_slots)


func _rebuild_slots(life_slots: Array) -> void:
	for child in _slots.get_children():
		child.queue_free()
	for index in life_slots.size():
		var slot: Dictionary = life_slots[index]
		var icon := TextureRect.new()
		icon.name = "BallSlot%d" % index
		icon.texture = ICON_TEXTURES.get(
			StringName(slot.get(&"type", &"normal")),
			ICON_TEXTURES[&"normal"]
		)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var state := int(slot.get(&"state", WaveHudStateSource.LifeState.UPCOMING))
		icon.modulate.a = 0.26 if state == WaveHudStateSource.LifeState.SPENT else 1.0
		_slots.add_child(icon)
		icon.position = Vector2(LEFT_PADDING + index * (SLOT_SIZE.x + SLOT_GAP), SLOT_Y)
		icon.size = SLOT_SIZE
		if state == WaveHudStateSource.LifeState.CURRENT:
			var outline := TextureRect.new()
			outline.name = "CurrentOutline"
			outline.texture = CURRENT_OUTLINE
			outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slots.add_child(outline)
			outline.position = icon.position - Vector2(6.0, 6.0)
			outline.size = OUTLINE_SIZE
