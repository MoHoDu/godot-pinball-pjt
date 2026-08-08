class_name WaveScoreRepairHud
extends Control


const GAUGE_WIDTH := 342.0
const WAVE_CURRENT_FONT_SIZE := 40
const BOSS_CURRENT_FONT_SIZE := 30

@onready var _current_label: Label = $CurrentLabel
@onready var _current_score: Label = %CurrentScore
@onready var _target_label: Label = $TargetLabel
@onready var _target_score: Label = %TargetScore
@onready var _repair_label: Label = %RepairLabel
@onready var _gauge_clip: Control = %GaugeClip


func render(snapshot: Dictionary) -> void:
	if StringName(snapshot.get(
		&"score_display_mode",
		WaveHudStateSource.SCORE_MODE_WAVE
	)) == WaveHudStateSource.SCORE_MODE_BOSS:
		_render_boss(snapshot)
		return
	_render_wave(snapshot)


func _render_wave(snapshot: Dictionary) -> void:
	var current := maxi(int(snapshot.get(&"current_score", 0)), 0)
	var target := maxi(int(snapshot.get(&"target_score", 0)), 0)
	var ratio := clampf(float(current) / float(target), 0.0, 1.0) \
		if target > 0 else 0.0
	_current_label.text = "CURRENT SCORE"
	_current_score.add_theme_font_size_override("font_size", WAVE_CURRENT_FONT_SIZE)
	_current_score.text = _format_number(current)
	_target_label.text = "TARGET SCORE"
	_target_score.text = _format_number(target)
	_repair_label.text = "REPAIR %.1f%%" % (ratio * 100.0)
	_gauge_clip.size.x = GAUGE_WIDTH * ratio


func _render_boss(snapshot: Dictionary) -> void:
	var max_health := maxi(int(snapshot.get(&"boss_max_health", 0)), 0)
	var current_health := clampi(
		int(snapshot.get(&"boss_current_health", 0)),
		0,
		max_health
	) if max_health > 0 else 0
	var last_damage := maxi(int(snapshot.get(&"boss_last_damage", 0)), 0)
	var defeat_ratio := clampf(
		1.0 - float(current_health) / float(max_health),
		0.0,
		1.0
	) if max_health > 0 else 0.0
	_current_label.text = "BOSS HP"
	_current_score.add_theme_font_size_override("font_size", BOSS_CURRENT_FONT_SIZE)
	_current_score.text = "%s / %s" % [
		_format_number(current_health),
		_format_number(max_health),
	]
	_target_label.text = "LAST HIT"
	_target_score.text = "-%s" % _format_number(last_damage) \
		if last_damage > 0 else "—"
	_repair_label.text = "DEFEAT %.1f%%" % (defeat_ratio * 100.0)
	_gauge_clip.size.x = GAUGE_WIDTH * defeat_ratio


func get_repair_ratio() -> float:
	return _gauge_clip.size.x / GAUGE_WIDTH


func _format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
