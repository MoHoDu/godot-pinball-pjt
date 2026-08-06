@tool
class_name ShotBumper
extends Bumper


signal control_started(bumper: ShotBumper, ball: RigidBody2D)
signal selection_changed(bumper: ShotBumper, anchor: ShotLaunchAnchor)
signal control_ended(bumper: ShotBumper, ball: RigidBody2D)


const PREVIOUS_DIRECTION_ACTION: StringName = &"flipper_select_left"
const NEXT_DIRECTION_ACTION: StringName = &"flipper_select_right"


var _controlled_ball: RigidBody2D
var _selected_anchor: ShotLaunchAnchor
var _selection_time_remaining := 0.0
var _destroy_after_release := false
var _is_releasing := false


func _draw() -> void:
	super()
	if not Engine.is_editor_hint() or not show_editor_guides:
		return
	for anchor: ShotLaunchAnchor in get_launch_anchors():
		var target := anchor.release_position
		if target.is_zero_approx():
			target = anchor.get_local_launch_direction() \
				* (get_collision_radius() + 26.0)
		var color := (
			Color(0.3, 1.0, 0.55, 0.95)
			if anchor.is_safe_default
			else Color(0.5, 0.95, 0.8, 0.85)
		)
		_draw_direction_guide(Vector2.ZERO, target, color)


func _ready() -> void:
	super()
	if response_strategy == null or not response_strategy is ShotResponseStrategy:
		response_strategy = ShotResponseStrategy.new()
	set_process_unhandled_input(false)
	if is_inside_tree():
		update_configuration_warnings()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_controlled_ball) \
			or _is_releasing:
		return
	_selection_time_remaining = maxf(_selection_time_remaining - delta, 0.0)
	if _selection_time_remaining <= 0.0:
		release_controlled_ball()


func _physics_process(delta: float) -> void:
	super(delta)
	if not _is_releasing or not is_instance_valid(_controlled_ball):
		return
	var separation := global_position.distance_to(_controlled_ball.global_position)
	if separation > get_safe_respawn_radius():
		_finish_safe_release()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_controlled_ball) or _is_releasing:
		return

	if event.is_action_pressed(PREVIOUS_DIRECTION_ACTION):
		if select_relative_launch_anchor(-1):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(NEXT_DIRECTION_ACTION):
		if select_relative_launch_anchor(1):
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo \
				and key_event.physical_keycode == KEY_SPACE:
			release_controlled_ball()
			get_viewport().set_input_as_handled()


func get_ball_impact(context: BallImpactContext) -> BumperResponse:
	if state != BumperState.ACTIVE:
		return null
	# 실제 접촉만 타격으로 등록하고, 기본 물리 처리 직후 Deferred 캡처합니다.
	register_valid_hit(context.ball, context.ball.get_instance_id())
	return null


func get_launch_anchors() -> Array[ShotLaunchAnchor]:
	var result: Array[ShotLaunchAnchor] = []
	if settings == null:
		return result
	for anchor: ShotLaunchAnchor in settings.shot_launch_directions:
		if anchor != null:
			result.append(anchor)
	return result


func get_selected_launch_direction() -> Vector2:
	var selected_anchor := get_selected_launch_anchor()
	if not is_instance_valid(selected_anchor):
		return Vector2.UP.rotated(global_rotation)
	return (global_transform.basis_xform(
		selected_anchor.get_local_launch_direction()
	)).normalized()


func get_selected_launch_anchor() -> ShotLaunchAnchor:
	if not is_instance_valid(_selected_anchor):
		_selected_anchor = _find_safe_default_anchor()
	return _selected_anchor


func get_selection_time_remaining() -> float:
	return _selection_time_remaining


func select_launch_anchor(anchor: ShotLaunchAnchor) -> bool:
	if anchor == null or anchor not in get_launch_anchors():
		return false
	_selected_anchor = anchor
	selection_changed.emit(self, anchor)
	if visual != null:
		visual.queue_redraw()
	return true


func select_relative_launch_anchor(offset: int) -> bool:
	var anchors := get_launch_anchors()
	if anchors.is_empty():
		return false
	var current_index := anchors.find(get_selected_launch_anchor())
	if current_index < 0:
		return select_launch_anchor(anchors[0])
	var target_index := wrapi(current_index + offset, 0, anchors.size())
	return select_launch_anchor(anchors[target_index])


func release_controlled_ball() -> bool:
	if not is_instance_valid(_controlled_ball) or _is_releasing:
		return false
	if not is_instance_valid(_selected_anchor):
		_selected_anchor = _find_safe_default_anchor()
	if not is_instance_valid(_selected_anchor):
		return false

	var direction := get_selected_launch_direction()
	var ball_radius := _get_ball_collision_radius(_controlled_ball)
	var minimum_release_distance := get_collision_radius() + ball_radius + 4.0
	var local_release_position := _selected_anchor.get_local_release_position(
		minimum_release_distance
	)
	if local_release_position.length() < minimum_release_distance:
		local_release_position = local_release_position.normalized() \
			* minimum_release_distance
	_controlled_ball.global_position = global_transform * local_release_position
	_controlled_ball.freeze = false
	_controlled_ball.sleeping = false
	_controlled_ball.linear_velocity = Vector2.ZERO

	var context := BallImpactContext.new(
		_controlled_ball,
		Vector2.ZERO,
		Vector2.ZERO,
		-direction,
		_controlled_ball.global_position
	)
	var response := response_strategy.build_response(context, self)
	apply_response_to_ball(_controlled_ball, response)
	_is_releasing = true
	set_process_unhandled_input(false)
	return true


func reset_for_new_ball() -> void:
	_abort_control_for_reset()
	super()


func _after_valid_hit(ball: RigidBody2D, _contact_id: int) -> void:
	if current_durability <= 0:
		_destroy_after_release = true
	call_deferred(&"_begin_selection", ball)


func _should_defer_destruction_after_hit() -> bool:
	return true


func _begin_selection(ball: RigidBody2D) -> void:
	if (
		not is_instance_valid(ball)
		or is_instance_valid(_controlled_ball)
		or state != BumperState.ACTIVE
	):
		return

	_controlled_ball = ball
	_is_releasing = false
	_selected_anchor = _find_safe_default_anchor()
	if not is_instance_valid(_selected_anchor):
		push_warning("ShotBumper 설정에는 안전 기본 발사 방향이 정확히 하나 필요합니다.")
		return
	ball.add_collision_exception_with(self)
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.global_position = global_position
	_selection_time_remaining = get_selection_duration()
	set_process_unhandled_input(true)
	control_started.emit(self, ball)
	selection_changed.emit(self, _selected_anchor)


func _finish_safe_release() -> void:
	if not is_instance_valid(_controlled_ball):
		return
	var released_ball := _controlled_ball
	released_ball.remove_collision_exception_with(self)
	_controlled_ball = null
	_is_releasing = false
	control_ended.emit(self, released_ball)
	if _destroy_after_release:
		_destroy_after_release = false
		enter_destroyed_state()


func _abort_control_for_reset() -> void:
	if not is_instance_valid(_controlled_ball):
		_controlled_ball = null
		_is_releasing = false
		_destroy_after_release = false
		set_process_unhandled_input(false)
		return
	var cancelled_ball := _controlled_ball
	cancelled_ball.remove_collision_exception_with(self)
	cancelled_ball.freeze = false
	_controlled_ball = null
	_is_releasing = false
	_destroy_after_release = false
	set_process_unhandled_input(false)
	control_ended.emit(self, cancelled_ball)


func _find_safe_default_anchor() -> ShotLaunchAnchor:
	for anchor: ShotLaunchAnchor in get_launch_anchors():
		if anchor.is_safe_default:
			return anchor
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	var anchors := get_launch_anchors()
	if anchors.is_empty():
		warnings.append("ShotBumper 설정에는 발사 방향이 하나 이상 필요합니다.")
	var safe_count := 0
	for anchor: ShotLaunchAnchor in anchors:
		if anchor.is_safe_default:
			safe_count += 1
	if safe_count != 1:
		warnings.append("안전 기본 발사 방향이 정확히 하나여야 합니다.")
	return warnings
