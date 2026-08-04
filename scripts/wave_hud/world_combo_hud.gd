class_name WaveWorldComboHud
extends Control


const SAFE_MARGIN := 28.0
const SAFE_TOP := 150.0
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const HIT_FADE_DURATION := 0.5
const RESTING_ALPHA := 0.65

@onready var _combo_value: Label = %ComboValue

var _last_active_combo := 0
var _fade_tween: Tween


func render(snapshot: Dictionary, anchor_design_position: Vector2) -> void:
	var active_combo := maxi(int(snapshot.get(&"active_combo", 0)), 0)
	var next_visible := bool(snapshot.get(&"combo_anchor_visible", false)) \
		and bool(snapshot.get(&"combo_visible", false)) \
		and active_combo > 0
	visible = next_visible
	_combo_value.text = "x%d" % active_combo
	var desired := anchor_design_position - Vector2(size.x * 0.5, size.y + 22.0)
	position = Vector2(
		clampf(desired.x, SAFE_MARGIN, DESIGN_SIZE.x - SAFE_MARGIN - size.x),
		clampf(desired.y, SAFE_TOP, DESIGN_SIZE.y - SAFE_MARGIN - size.y)
	)

	if not next_visible:
		_last_active_combo = 0
		_stop_hit_fade()
		modulate.a = 1.0
		return
	if active_combo != _last_active_combo:
		_play_hit_fade()
	_last_active_combo = active_combo


func _play_hit_fade() -> void:
	_stop_hit_fade()
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(
		self,
		^"modulate:a",
		RESTING_ALPHA,
		HIT_FADE_DURATION
	)


func _stop_hit_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
