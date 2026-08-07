class_name BossCounterGatedDamageApplier
extends BossGatedDamageApplier


var _counter_multiplier: float = 0.0
var _is_counter_multiplier_configured: bool = false
var _counter_window: BossCounterWindow = null
var _pending_counter_window: BossCounterWindow = null
var _awaiting_counter_resolution: bool = false


func _init() -> void:
	if not boss_hit_resolved.is_connected(_on_boss_hit_resolved):
		boss_hit_resolved.connect(_on_boss_hit_resolved)


func _exit_tree() -> void:
	unbind_counter_window()
	_pending_counter_window = null
	_awaiting_counter_resolution = false


func configure_counter_multiplier(multiplier: float) -> bool:
	if not is_finite(multiplier) or multiplier <= 0.0:
		return false

	_counter_multiplier = multiplier
	_is_counter_multiplier_configured = true
	return true


func bind_counter_window(window: BossCounterWindow) -> bool:
	if window == null or not is_instance_valid(window):
		return false

	_counter_window = window
	return true


func unbind_counter_window() -> void:
	_counter_window = null


func is_counter_window_bound() -> bool:
	return _counter_window != null and is_instance_valid(_counter_window)


func resolve_and_apply_hit(
	target_valid_hit_count: int,
	ball_weight_multiplier: float = 1.0,
	_is_counter: bool = false,
	_counter_multiplier_override: float = 1.0
) -> int:
	var use_window_counter: bool = is_counter_window_bound() \
		and _is_counter_multiplier_configured \
		and _counter_window.is_ready()
	if not use_window_counter:
		return super.resolve_and_apply_hit(
			target_valid_hit_count,
			ball_weight_multiplier,
			false,
			1.0
		)

	_pending_counter_window = _counter_window
	_awaiting_counter_resolution = true
	var applied_damage: int = super.resolve_and_apply_hit(
		target_valid_hit_count,
		ball_weight_multiplier,
		true,
		_counter_multiplier
	)
	_awaiting_counter_resolution = false
	_pending_counter_window = null
	return applied_damage


func _on_boss_hit_resolved(
	_calculated_damage: int,
	_applied_damage: int,
	_previous_health: int,
	_current_health: int,
	_max_health: int,
	was_counter: bool
) -> void:
	if not _awaiting_counter_resolution or not was_counter:
		return

	_awaiting_counter_resolution = false
	var resolved_window: BossCounterWindow = _pending_counter_window
	_pending_counter_window = null
	if is_instance_valid(resolved_window):
		resolved_window.consume()
