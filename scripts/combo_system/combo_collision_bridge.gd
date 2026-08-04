class_name ComboCollisionBridge
extends Node


signal flipper_contact_registered(flipper: Node, ball: RigidBody2D)
signal wall_contact_registered(wall: Node, ball: RigidBody2D)


const FLIPPER_GROUP: StringName = &"combo_flippers"
const WALL_GROUP: StringName = &"combo_walls"
const FLIPPER_IDLE_STATE := 0


@export var combo_system_path: NodePath
@export var ball_path: NodePath
var _combo_system: Node
var _ball: RigidBody2D
var _flipper_contacts: Dictionary = {}
var _wall_contacts: Dictionary = {}
var _bound_flipper_ids: Dictionary = {}


func _ready() -> void:
	# 플리퍼가 새 물리 프레임의 회전 스윕을 처리하기 전에 지난 프레임의
	# 합성 접촉이 실제로 분리됐는지 먼저 판정합니다.
	process_physics_priority = -100
	if not combo_system_path.is_empty():
		bind_combo_system(get_node_or_null(combo_system_path))
	if not ball_path.is_empty():
		bind_ball(get_node_or_null(ball_path) as RigidBody2D)
	_bind_registered_flippers()


func bind_combo_system(combo_system: Node) -> bool:
	if combo_system == null \
			or not combo_system.has_method(&"refresh_combo_timer_from_flipper"):
		return false
	_combo_system = combo_system
	return true


func bind_ball(ball: RigidBody2D) -> bool:
	if _ball == ball:
		return is_instance_valid(_ball)
	_disconnect_ball()
	_ball = ball
	_flipper_contacts.clear()
	_wall_contacts.clear()
	if not is_instance_valid(_ball):
		return false
	_ball.body_entered.connect(_on_ball_body_entered)
	_ball.body_exited.connect(_on_ball_body_exited)
	return true


func bind_flipper(flipper: Node) -> bool:
	if flipper == null or not flipper.has_signal(&"rotation_sweep_resolved"):
		return false
	var flipper_id := flipper.get_instance_id()
	if _bound_flipper_ids.has(flipper_id):
		return true

	var sweep_callback := Callable(
		self,
		&"_on_flipper_rotation_sweep_resolved"
	).bind(flipper)
	flipper.connect(&"rotation_sweep_resolved", sweep_callback)
	if flipper.has_signal(&"state_changed"):
		var state_callback := Callable(
			self,
			&"_on_flipper_state_changed"
		).bind(flipper)
		flipper.connect(&"state_changed", state_callback)
	_bound_flipper_ids[flipper_id] = weakref(flipper)
	return true


func _physics_process(_delta: float) -> void:
	_reconcile_swept_flipper_contacts()


func _exit_tree() -> void:
	_disconnect_ball()
	_flipper_contacts.clear()
	_wall_contacts.clear()


func _bind_registered_flippers() -> void:
	if not is_inside_tree():
		return
	for flipper: Node in get_tree().get_nodes_in_group(FLIPPER_GROUP):
		bind_flipper(flipper)


func _disconnect_ball() -> void:
	if not is_instance_valid(_ball):
		_ball = null
		return
	if _ball.body_entered.is_connected(_on_ball_body_entered):
		_ball.body_entered.disconnect(_on_ball_body_entered)
	if _ball.body_exited.is_connected(_on_ball_body_exited):
		_ball.body_exited.disconnect(_on_ball_body_exited)
	_ball = null


func _on_ball_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group(FLIPPER_GROUP):
		_register_flipper_contact(body, true)
	if body.is_in_group(WALL_GROUP):
		_register_wall_contact(body)


func _on_ball_body_exited(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group(FLIPPER_GROUP):
		_release_flipper_contact(body, true)
	if body.is_in_group(WALL_GROUP):
		_release_wall_contact(body)


func _on_flipper_rotation_sweep_resolved(
	resolved_ball: RigidBody2D,
	flipper: Node
) -> void:
	if resolved_ball != _ball:
		return
	_register_flipper_contact(flipper, false)


func _on_flipper_state_changed(
	_previous_state: int,
	current_state: int,
	flipper: Node
) -> void:
	if current_state != FLIPPER_IDLE_STATE:
		return
	_release_flipper_contact(flipper, false)


func _register_flipper_contact(flipper: Node, is_physical: bool) -> bool:
	if not is_instance_valid(_combo_system) \
			or not is_instance_valid(_ball) \
			or not is_instance_valid(flipper):
		return false

	var ball_id := _ball.get_instance_id()
	var flipper_id := flipper.get_instance_id()
	var contact: Dictionary = _flipper_contacts.get(ball_id, {})
	var physical_ids: Dictionary = contact.get(&"physical", {})
	var swept_ids: Dictionary = contact.get(&"swept", {})
	var had_swept_contact := not swept_ids.is_empty()

	if is_physical:
		physical_ids[flipper_id] = true
	else:
		swept_ids[flipper_id] = true
	contact[&"physical"] = physical_ids
	contact[&"swept"] = swept_ids
	_flipper_contacts[ball_id] = contact

	# 일반 물리 접촉은 대기·복귀 플리퍼에서도 발생하므로 콤보 상태를 바꾸지 않습니다.
	# ACTIVE 회전 스윕이 실제 임펄스를 적용했을 때만 조건부 타이머 갱신을 요청합니다.
	if is_physical or had_swept_contact:
		return false
	_combo_system.call(&"refresh_combo_timer_from_flipper")
	flipper_contact_registered.emit(flipper, _ball)
	return true


func _release_flipper_contact(flipper: Node, is_physical: bool) -> bool:
	if not is_instance_valid(_ball) or not is_instance_valid(flipper):
		return false
	var ball_id := _ball.get_instance_id()
	if not _flipper_contacts.has(ball_id):
		return false

	var flipper_id := flipper.get_instance_id()
	var contact: Dictionary = _flipper_contacts[ball_id]
	var key: StringName = &"physical" if is_physical else &"swept"
	var contact_ids: Dictionary = contact.get(key, {})
	if not contact_ids.erase(flipper_id):
		return false
	contact[key] = contact_ids
	# 스윕으로 먼저 잡은 타격이 실제 물리 접촉으로 이어졌다면, 모든 플리퍼에서
	# 분리되는 순간 합성 표식도 끝내야 같은 작동 중의 실제 재타격을 인정할 수 있습니다.
	if is_physical and contact_ids.is_empty():
		contact[&"swept"] = {}

	var physical_ids: Dictionary = contact.get(&"physical", {})
	var swept_ids: Dictionary = contact.get(&"swept", {})
	if physical_ids.is_empty() and swept_ids.is_empty():
		_flipper_contacts.erase(ball_id)
	else:
		_flipper_contacts[ball_id] = contact
	return true


func _reconcile_swept_flipper_contacts() -> void:
	if not is_instance_valid(_ball):
		return
	var ball_id := _ball.get_instance_id()
	if not _flipper_contacts.has(ball_id):
		return

	var contact: Dictionary = _flipper_contacts[ball_id]
	var physical_ids: Dictionary = contact.get(&"physical", {})
	var swept_ids: Dictionary = contact.get(&"swept", {})
	if not physical_ids.is_empty() or swept_ids.is_empty():
		return

	var has_overlap := false
	for flipper_id: int in swept_ids.keys():
		var flipper_ref: WeakRef = _bound_flipper_ids.get(flipper_id)
		var flipper: Node = flipper_ref.get_ref() if flipper_ref != null else null
		if not is_instance_valid(flipper):
			swept_ids.erase(flipper_id)
			continue
		if _is_ball_overlapping_flipper(flipper):
			has_overlap = true
			break

	if has_overlap:
		contact[&"swept"] = swept_ids
		_flipper_contacts[ball_id] = contact
		return
	_flipper_contacts.erase(ball_id)


func _is_ball_overlapping_flipper(flipper: Node) -> bool:
	# 겹침을 판정할 수 없는 사용자 정의 플리퍼는 IDLE 신호까지 보수적으로 유지합니다.
	if not flipper.has_method(&"is_circle_overlapping_at_rotation"):
		return true
	var ball_collision := _ball.get_node_or_null(
		^"CollisionShape2D"
	) as CollisionShape2D
	if ball_collision == null or not ball_collision.shape is CircleShape2D:
		return true
	var circle := ball_collision.shape as CircleShape2D
	var collision_scale := ball_collision.global_scale.abs()
	var circle_radius := circle.radius * maxf(
		collision_scale.x,
		collision_scale.y
	)
	var flipper_rotation := 0.0
	if flipper is Node2D:
		flipper_rotation = (flipper as Node2D).rotation
	return bool(flipper.call(
		&"is_circle_overlapping_at_rotation",
		ball_collision.global_position,
		circle_radius,
		flipper_rotation
	))


func _register_wall_contact(wall: Node) -> bool:
	if not is_instance_valid(_ball) \
			or not is_instance_valid(wall):
		return false
	var wall_id := wall.get_instance_id()
	if _wall_contacts.has(wall_id):
		return false

	# 벽은 물리 반사만 담당합니다. 접촉 신호는 관찰용으로 유지하되 콤보 상태에는
	# 어떤 변경도 요청하지 않습니다.
	_wall_contacts[wall_id] = true
	wall_contact_registered.emit(wall, _ball)
	return true


func _release_wall_contact(wall: Node) -> bool:
	if not is_instance_valid(wall):
		return false
	return _wall_contacts.erase(wall.get_instance_id())
