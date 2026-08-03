class_name WaveWorldComboHud
extends Control


const SAFE_MARGIN := 28.0
const SAFE_TOP := 150.0
const DESIGN_SIZE := Vector2(1920.0, 1080.0)

@onready var _combo_value: Label = %ComboValue


func render(snapshot: Dictionary, anchor_design_position: Vector2) -> void:
	var max_combo := maxi(int(snapshot.get(&"max_combo", 0)), 0)
	visible = bool(snapshot.get(&"combo_anchor_visible", false)) and max_combo > 0
	_combo_value.text = "x%d" % max_combo
	var desired := anchor_design_position - Vector2(size.x * 0.5, size.y + 22.0)
	position = Vector2(
		clampf(desired.x, SAFE_MARGIN, DESIGN_SIZE.x - SAFE_MARGIN - size.x),
		clampf(desired.y, SAFE_TOP, DESIGN_SIZE.y - SAFE_MARGIN - size.y)
	)
