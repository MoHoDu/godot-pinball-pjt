class_name TeddyArmSweepAttack
extends Node2D


signal attack_hit(target: Node)


const PINBALL_GROUP: StringName = &"pinball_balls"


@export_category("Runtime Nodes")
@export var left_shoulder_pivot: Node2D
@export var right_shoulder_pivot: Node2D
@export var left_hit_area: Area2D
@export var right_hit_area: Area2D
@export var left_arm_visual: CanvasItem
@export var right_arm_visual: CanvasItem

@export_category("Sweep Angles")
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var idle_angle_degrees := 15.0
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var telegraph_angle_degrees := -8.0
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var active_angle_degrees := 125.0


var _detection_active := false
var _hit_target_ids: Dictionary = {}
var _motion_tween: Tween


# Compatibility aliases for the first prototype tests. Runtime behavior uses
# both shoulder pivots and both hit areas.
var arm_pivot: Node2D:
	get:
		return left_shoulder_pivot

var hit_area: Area2D:
	get:
		return left_hit_area


func _ready() -> void:
	assert(is_instance_valid(left_shoulder_pivot),
		"Teddy arm sweep requires a left shoulder pivot.")
	assert(is_instance_valid(right_shoulder_pivot),
		"Teddy arm sweep requires a right shoulder pivot.")
	assert(is_instance_valid(left_hit_area),
		"Teddy arm sweep requires a left hit Area2D.")
	assert(is_instance_valid(right_hit_area),
		"Teddy arm sweep requires a right hit Area2D.")
	for area: Area2D in [left_hit_area, right_hit_area]:
		if not area.body_entered.is_connected(_on_hit_area_body_entered):
			area.body_entered.connect(_on_hit_area_body_entered)
	prepare_attack()


func prepare_attack() -> void:
	_stop_motion()
	_hit_target_ids.clear()
	_set_detection_active(false)
	_set_arm_rotations(idle_angle_degrees)
	_set_visual_state(StateVisual.DEFAULT)


func begin_telegraph(duration: float) -> void:
	_set_detection_active(false)
	_set_visual_state(StateVisual.TELEGRAPH)
	_animate_arms(telegraph_angle_degrees, duration)


func begin_active(duration: float) -> void:
	_set_visual_state(StateVisual.ACTIVE)
	_set_detection_active(true)
	_animate_arms(active_angle_degrees, duration)
	_register_overlapping_targets()


func begin_recovery(duration: float) -> void:
	_set_detection_active(false)
	_set_visual_state(StateVisual.DEFAULT)
	_animate_arms(idle_angle_degrees, duration)


func begin_cooldown() -> void:
	_set_detection_active(false)
	_set_visual_state(StateVisual.DEFAULT)


func finish_attack() -> void:
	_stop_motion()
	_set_detection_active(false)
	_set_arm_rotations(idle_angle_degrees)
	_set_visual_state(StateVisual.DEFAULT)


func cancel_attack() -> void:
	_stop_motion()
	_set_detection_active(false)
	_hit_target_ids.clear()
	_set_arm_rotations(idle_angle_degrees)
	_set_visual_state(StateVisual.DEFAULT)


func is_detection_active() -> bool:
	return _detection_active


func get_registered_target_count() -> int:
	return _hit_target_ids.size()


func _on_hit_area_body_entered(body: Node2D) -> void:
	_register_target(body)


func _register_overlapping_targets() -> void:
	if not _detection_active:
		return
	for area: Area2D in [left_hit_area, right_hit_area]:
		if not is_instance_valid(area):
			continue
		for body: Node2D in area.get_overlapping_bodies():
			_register_target(body)


func _register_target(target: Node) -> bool:
	if not _detection_active \
			or not target is Pinball \
			or not target.is_in_group(PINBALL_GROUP):
		return false
	var target_id := target.get_instance_id()
	if _hit_target_ids.has(target_id):
		return false
	_hit_target_ids[target_id] = true
	attack_hit.emit(target)
	return true


func _set_detection_active(is_active: bool) -> void:
	_detection_active = is_active


func _animate_arms(left_target_degrees: float, duration: float) -> void:
	_stop_motion()
	if duration <= 0.0:
		_set_arm_rotations(left_target_degrees)
		return
	_motion_tween = create_tween()
	_motion_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion_tween.set_trans(Tween.TRANS_SINE)
	_motion_tween.set_ease(Tween.EASE_IN_OUT)
	_motion_tween.set_parallel(true)
	_motion_tween.tween_property(
		left_shoulder_pivot,
		^"rotation",
		deg_to_rad(left_target_degrees),
		duration
	)
	_motion_tween.tween_property(
		right_shoulder_pivot,
		^"rotation",
		deg_to_rad(-left_target_degrees),
		duration
	)


func _stop_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _set_arm_rotations(left_degrees: float) -> void:
	left_shoulder_pivot.rotation = deg_to_rad(left_degrees)
	right_shoulder_pivot.rotation = deg_to_rad(-left_degrees)


enum StateVisual {
	DEFAULT,
	TELEGRAPH,
	ACTIVE,
}


func _set_visual_state(state_visual: StateVisual) -> void:
	var state_modulate := Color.WHITE
	match state_visual:
		StateVisual.TELEGRAPH:
			state_modulate = Color(1.25, 1.05, 0.38, 1.0)
		StateVisual.ACTIVE:
			state_modulate = Color(1.35, 0.35, 0.28, 1.0)
	for visual: CanvasItem in [left_arm_visual, right_arm_visual]:
		if is_instance_valid(visual):
			visual.modulate = state_modulate
