class_name WaveScoreRepairHud
extends Control


const GAUGE_WIDTH := 342.0

@onready var _current_score: Label = %CurrentScore
@onready var _target_score: Label = %TargetScore
@onready var _repair_label: Label = %RepairLabel
@onready var _gauge_clip: Control = %GaugeClip


func render(snapshot: Dictionary) -> void:
	var current := maxi(int(snapshot.get(&"current_score", 0)), 0)
	var target := maxi(int(snapshot.get(&"target_score", 0)), 0)
	var ratio := clampf(float(current) / float(target), 0.0, 1.0) \
		if target > 0 else 0.0
	_current_score.text = _format_number(current)
	_target_score.text = _format_number(target)
	_repair_label.text = "REPAIR %.1f%%" % (ratio * 100.0)
	_gauge_clip.size.x = GAUGE_WIDTH * ratio


func get_repair_ratio() -> float:
	return _gauge_clip.size.x / GAUGE_WIDTH


func _format_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
