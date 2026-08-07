class_name BossParryCounterResolver
extends Node


signal counter_earned(ball: Pinball)


var _tracker: BossArmHitBallTracker = null
var _flippers: Array[PinballFlipper] = []


func _exit_tree() -> void:
	unbind_flippers()
	_tracker = null


func bind_tracker(tracker: BossArmHitBallTracker) -> bool:
	if tracker == null or not is_instance_valid(tracker):
		return false

	_tracker = tracker
	return true


func bind_flippers(flippers: Array[PinballFlipper]) -> bool:
	var validated_flippers: Array[PinballFlipper] = []
	var validated_ids: Dictionary[int, bool] = {}
	for flipper: PinballFlipper in flippers:
		if flipper == null or not is_instance_valid(flipper):
			return false

		var flipper_id: int = flipper.get_instance_id()
		if validated_ids.has(flipper_id):
			continue
		validated_ids[flipper_id] = true
		validated_flippers.append(flipper)

	_disconnect_flippers()
	_flippers = validated_flippers
	for flipper: PinballFlipper in _flippers:
		if not flipper.parry_resolved.is_connected(_on_parry_resolved):
			flipper.parry_resolved.connect(_on_parry_resolved)
	return true


func unbind_flippers() -> void:
	_disconnect_flippers()
	_flippers.clear()


func _on_parry_resolved(
	ball: RigidBody2D,
	grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_speed_multiplier: float
) -> void:
	if ball == null or not is_instance_valid(ball) or not ball is Pinball:
		return
	if _tracker == null \
			or not is_instance_valid(_tracker) \
			or not _tracker.is_bound():
		return

	var pinball := ball as Pinball
	if not _tracker.is_ball_tracked(pinball):
		return
	if grade != FlipperParryEvaluator.Grade.PERFECT:
		return
	if not _tracker.consume_ball(pinball):
		return

	counter_earned.emit(pinball)


func _disconnect_flippers() -> void:
	for flipper: PinballFlipper in _flippers:
		if is_instance_valid(flipper) \
				and flipper.parry_resolved.is_connected(_on_parry_resolved):
			flipper.parry_resolved.disconnect(_on_parry_resolved)
