class_name ComboHud
extends Control


signal hit_feedback_requested(combo_count: int, tier: int)
signal tier_feedback_requested(previous_tier: int, current_tier: int, combo_count: int)
signal settlement_feedback_requested(awarded_score: int, reason: int)


@export var combo_label_path: NodePath = ^"Panel/Margin/VBox/ComboLabel"
@export var tier_label_path: NodePath = ^"Panel/Margin/VBox/TierLabel"
@export var timer_bar_path: NodePath = ^"Panel/Margin/VBox/TimerBar"
@export var timer_state_label_path: NodePath = ^"Panel/Margin/VBox/TimerStateLabel"
@export var score_label_path: NodePath = ^"Panel/Margin/VBox/ScoreLabel"
@export var award_label_path: NodePath = ^"Panel/Margin/VBox/AwardLabel"


var _combo_system: Node
var _combo_label: Label
var _tier_label: Label
var _timer_bar: ProgressBar
var _timer_state_label: Label
var _score_label: Label
var _award_label: Label
var _pulse_tween: Tween


func _ready() -> void:
	_resolve_nodes()
	_show_empty_state()


func bind_combo_system(combo_system: Node) -> bool:
	if combo_system == null \
			or not combo_system.has_signal(&"combo_changed") \
			or not combo_system.has_signal(&"combo_tier_changed") \
			or not combo_system.has_signal(&"combo_timer_changed") \
			or not combo_system.has_signal(&"combo_finished") \
			or not combo_system.has_signal(&"score_changed") \
			or not combo_system.has_signal(&"timer_suspension_changed"):
		return false
	if _combo_system == combo_system:
		return true
	unbind_combo_system()
	_combo_system = combo_system
	_connect_signal(&"combo_changed", &"_on_combo_changed")
	_connect_signal(&"combo_tier_changed", &"_on_combo_tier_changed")
	_connect_signal(&"combo_timer_changed", &"_on_combo_timer_changed")
	_connect_signal(&"combo_finished", &"_on_combo_finished")
	_connect_signal(&"score_changed", &"_on_score_changed")
	_connect_signal(&"timer_suspension_changed", &"_on_timer_suspension_changed")
	_refresh_from_combo_system()
	return true


func unbind_combo_system() -> void:
	if _combo_system == null or not is_instance_valid(_combo_system):
		_combo_system = null
		return
	_disconnect_signal(&"combo_changed", &"_on_combo_changed")
	_disconnect_signal(&"combo_tier_changed", &"_on_combo_tier_changed")
	_disconnect_signal(&"combo_timer_changed", &"_on_combo_timer_changed")
	_disconnect_signal(&"combo_finished", &"_on_combo_finished")
	_disconnect_signal(&"score_changed", &"_on_score_changed")
	_disconnect_signal(&"timer_suspension_changed", &"_on_timer_suspension_changed")
	_combo_system = null


func _on_combo_changed(combo_count: int, tier: int, _time_remaining: float) -> void:
	_combo_label.text = "x%d" % combo_count
	_tier_label.text = _get_tier_label(tier)
	if combo_count > 0:
		hit_feedback_requested.emit(combo_count, tier)
		_pulse_combo_label()


func _on_combo_tier_changed(
	previous_tier: int,
	current_tier: int,
	combo_count: int
) -> void:
	tier_feedback_requested.emit(previous_tier, current_tier, combo_count)


func _on_combo_timer_changed(time_remaining: float, hold_time: float) -> void:
	_timer_bar.max_value = maxf(hold_time, 0.1)
	_timer_bar.value = clampf(time_remaining, 0.0, _timer_bar.max_value)
	if _timer_state_label.text != "PAUSED":
		_timer_state_label.text = "%.1fs" % time_remaining \
			if time_remaining > 0.0 else "READY"


func _on_combo_finished(
	_combo_count: int,
	_tier: int,
	awarded_score: int,
	reason: int
) -> void:
	_award_label.text = "+%d" % awarded_score if awarded_score > 0 else ""
	settlement_feedback_requested.emit(awarded_score, reason)


func _on_score_changed(total_score: int, _added_score: int) -> void:
	_score_label.text = "SCORE %d" % total_score
	if total_score <= 0:
		_award_label.text = ""


func _on_timer_suspension_changed(
	is_suspended: bool,
	time_remaining: float
) -> void:
	_timer_state_label.text = "PAUSED" if is_suspended else (
		"%.1fs" % time_remaining if time_remaining > 0.0 else "READY"
	)


func _refresh_from_combo_system() -> void:
	if _combo_system == null:
		_show_empty_state()
		return
	var combo_count := int(_combo_system.get(&"combo_count"))
	var tier := int(_combo_system.get(&"current_tier"))
	var time_remaining := float(_combo_system.get(&"time_remaining"))
	var hold_time := float(_combo_system.get(&"rules").get(&"hold_time"))
	_combo_label.text = "x%d" % combo_count
	_tier_label.text = _get_tier_label(tier)
	_score_label.text = "SCORE %d" % int(_combo_system.get(&"total_score"))
	_award_label.text = ""
	_on_combo_timer_changed(time_remaining, hold_time)
	_on_timer_suspension_changed(
		bool(_combo_system.get(&"is_timer_suspended")),
		time_remaining
	)


func _show_empty_state() -> void:
	if not _nodes_are_ready():
		return
	_combo_label.text = "x0"
	_tier_label.text = "None"
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 3.0
	_timer_bar.value = 0.0
	_timer_state_label.text = "READY"
	_score_label.text = "SCORE 0"
	_award_label.text = ""


func _get_tier_label(tier: int) -> String:
	if _combo_system == null:
		return "None"
	var combo_rules: Resource = _combo_system.get(&"rules")
	return String(combo_rules.call(&"get_tier_label", tier))


func _pulse_combo_label() -> void:
	if not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_combo_label.scale = Vector2(1.12, 1.12)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)


func _resolve_nodes() -> void:
	_combo_label = get_node_or_null(combo_label_path) as Label
	_tier_label = get_node_or_null(tier_label_path) as Label
	_timer_bar = get_node_or_null(timer_bar_path) as ProgressBar
	_timer_state_label = get_node_or_null(timer_state_label_path) as Label
	_score_label = get_node_or_null(score_label_path) as Label
	_award_label = get_node_or_null(award_label_path) as Label
	assert(_nodes_are_ready(), "ComboHud scene node paths must reference valid controls.")


func _nodes_are_ready() -> bool:
	return _combo_label != null \
		and _tier_label != null \
		and _timer_bar != null \
		and _timer_state_label != null \
		and _score_label != null \
		and _award_label != null


func _connect_signal(signal_name: StringName, method_name: StringName) -> void:
	var callback := Callable(self, method_name)
	if not _combo_system.is_connected(signal_name, callback):
		_combo_system.connect(signal_name, callback)


func _disconnect_signal(signal_name: StringName, method_name: StringName) -> void:
	var callback := Callable(self, method_name)
	if _combo_system.is_connected(signal_name, callback):
		_combo_system.disconnect(signal_name, callback)
