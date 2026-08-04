@tool
class_name Bumper
extends AnimatableBody2D


signal valid_hit_registered(
	bumper_id: StringName,
	ball: RigidBody2D,
	contact_id: int,
	base_score: int
)
signal durability_changed(current: int, maximum: int)
signal state_changed(previous: BumperState, current: BumperState)
signal response_resolved(bumper: Bumper, ball: RigidBody2D, response: BumperResponse)


enum BumperState {
	ACTIVE,
	DESTROYED_TIMER,
	SAFE_RESPAWN_WAIT,
	RESPAWN_TELEGRAPH,
}


const BUMPER_GROUP: StringName = &"bumper_objects"
const BALL_GROUP: StringName = &"pinball_balls"
const DEFAULT_PREDICTION_SECONDS := 0.3


@export_category("Bumper Configuration")
@export var bumper_id: StringName = &"bumper"
@export var settings: BumperSettings:
	set(value):
		settings = value
		_refresh_configuration()
@export var instance_overrides: BumperInstanceOverrides:
	set(value):
		instance_overrides = value
		_refresh_configuration()
@export var response_strategy: BumperResponseStrategy

@export_category("Safe Respawn")
@export_range(0.05, 2.0, 0.05, "suffix:s")
var prediction_seconds := DEFAULT_PREDICTION_SECONDS


@onready var collision_shape: CollisionShape2D = get_node_or_null(
	^"CollisionShape2D"
) as CollisionShape2D
@onready var hit_area: Area2D = get_node_or_null(^"HitArea") as Area2D
@onready var hit_area_shape: CollisionShape2D = get_node_or_null(
	^"HitArea/CollisionShape2D"
) as CollisionShape2D
@onready var safe_respawn_area: Area2D = get_node_or_null(
	^"SafeRespawnArea"
) as Area2D
@onready var safe_respawn_shape: CollisionShape2D = get_node_or_null(
	^"SafeRespawnArea/CollisionShape2D"
) as CollisionShape2D
@onready var combo_hit_source: ComboHitSource = get_node_or_null(
	^"ComboHitSource"
) as ComboHitSource
@onready var visual: Node2D = get_node_or_null(^"Visual") as Node2D
@onready var respawn_timer: Timer = get_node_or_null(^"RespawnTimer") as Timer
@onready var telegraph_timer: Timer = get_node_or_null(^"TelegraphTimer") as Timer


var current_durability: int = 1
var state: BumperState = BumperState.ACTIVE
var active_contacts: Dictionary = {}


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(BUMPER_GROUP)


func _ready() -> void:
	_refresh_configuration()
	if Engine.is_editor_hint():
		return

	current_durability = get_max_durability()
	if response_strategy == null:
		response_strategy = _create_default_strategy()
	_connect_runtime_nodes()
	_set_collision_enabled(true)
	_set_hit_detection_enabled(true)
	durability_changed.emit(current_durability, get_max_durability())


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	match state:
		BumperState.SAFE_RESPAWN_WAIT:
			if can_reactivate():
				_begin_respawn_telegraph()
		BumperState.RESPAWN_TELEGRAPH:
			if not can_reactivate():
				_cancel_respawn_telegraph()


func _connect_runtime_nodes() -> void:
	if hit_area != null:
		if not hit_area.body_exited.is_connected(_on_hit_area_body_exited):
			hit_area.body_exited.connect(_on_hit_area_body_exited)
	if respawn_timer != null \
			and not respawn_timer.timeout.is_connected(_on_respawn_timer_timeout):
		respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	if telegraph_timer != null \
			and not telegraph_timer.timeout.is_connected(_on_telegraph_timer_timeout):
		telegraph_timer.timeout.connect(_on_telegraph_timer_timeout)


func register_valid_hit(ball: RigidBody2D, contact_id: int) -> bool:
	if (
		state != BumperState.ACTIVE
		or current_durability <= 0
		or active_contacts.has(contact_id)
	):
		return false

	active_contacts[contact_id] = weakref(ball)
	if combo_hit_source != null:
		combo_hit_source.register_contact(contact_id)
	valid_hit_registered.emit(
		bumper_id,
		ball,
		contact_id,
		get_base_score()
	)
	decrease_durability(get_durability_damage_per_hit())
	_after_valid_hit(ball, contact_id)
	return true


func release_contact(contact_id: int) -> bool:
	if not active_contacts.erase(contact_id):
		return false
	if combo_hit_source != null:
		combo_hit_source.release_contact(contact_id)
	return true


func get_ball_impact(context: BallImpactContext) -> BumperResponse:
	if state != BumperState.ACTIVE or response_strategy == null:
		return null
	# Pinball이 실제 물리 접촉에서 호출하는 지점을 유효 타격의 단일 입력으로 사용합니다.
	# 주변 감지 Area는 분리 판정만 담당하므로 근접 통과가 타격으로 오인되지 않습니다.
	var is_new_hit := register_valid_hit(
		context.ball,
		context.ball.get_instance_id()
	)
	var response := response_strategy.build_response(context, self)
	if is_new_hit and response != null:
		# Godot의 기본 접촉 해소가 최종 반사 방향을 확정한 뒤 속력만 합성합니다.
		# Pinball에 결과를 반환해 기본 반사를 다시 뒤집지 않도록 null을 반환합니다.
		call_deferred(&"_apply_deferred_physical_response", context.ball, response)
	return null


func apply_response_to_ball(
	ball: RigidBody2D,
	response: BumperResponse
) -> bool:
	if not is_instance_valid(ball) or response == null:
		return false

	var direction := ball.linear_velocity.normalized()
	match response.direction_mode:
		BallImpactResult.DirectionMode.FIXED_WORLD, \
		BallImpactResult.DirectionMode.FIXED_LOCAL:
			direction = response.direction.normalized()
		BallImpactResult.DirectionMode.PHYSICAL_REFLECTION:
			# 기본 물리가 확정한 방향을 보존합니다.
			pass
		BallImpactResult.DirectionMode.KEEP_CURRENT:
			pass

	if direction.is_zero_approx():
		return false
	var source_speed := (
		response.source_speed
		if response.source_speed >= 0.0
		else ball.linear_velocity.length()
	)
	var speed := clampf(
		source_speed * response.speed_multiplier
			+ response.speed_addition,
		response.minimum_speed,
		response.maximum_speed
	)
	ball.linear_velocity = direction * speed
	response_resolved.emit(self, ball, response)
	return true


func _apply_deferred_physical_response(
	ball: RigidBody2D,
	response: BumperResponse
) -> void:
	if not is_instance_valid(ball):
		return
	apply_response_to_ball(ball, response)


func decrease_durability(amount: int = 1) -> void:
	if state != BumperState.ACTIVE or amount <= 0:
		return
	current_durability = maxi(current_durability - amount, 0)
	durability_changed.emit(current_durability, get_max_durability())
	if current_durability == 0 and not _should_defer_destruction_after_hit():
		enter_destroyed_state()


func enter_destroyed_state() -> void:
	if state != BumperState.ACTIVE:
		return
	_set_state(BumperState.DESTROYED_TIMER)
	_reset_contacts()
	_set_collision_enabled(false)
	_set_hit_detection_enabled(false)
	if respawn_timer == null or get_respawn_delay() <= 0.0:
		begin_safe_respawn_wait()
		return
	respawn_timer.start(get_respawn_delay())


func begin_safe_respawn_wait() -> void:
	if state not in [
		BumperState.DESTROYED_TIMER,
		BumperState.RESPAWN_TELEGRAPH,
	]:
		return
	if telegraph_timer != null:
		telegraph_timer.stop()
	_set_state(BumperState.SAFE_RESPAWN_WAIT)


func can_reactivate() -> bool:
	if safe_respawn_area != null and safe_respawn_area.has_overlapping_bodies():
		return false
	if not is_inside_tree():
		return false

	var safe_radius := get_safe_respawn_radius()
	for candidate: Node in get_tree().get_nodes_in_group(BALL_GROUP):
		if not candidate is RigidBody2D:
			continue
		var ball := candidate as RigidBody2D
		if not is_instance_valid(ball) or ball.freeze:
			continue
		var radius := _get_ball_collision_radius(ball)
		var from := ball.global_position
		var to := from + ball.linear_velocity * prediction_seconds
		var closest := Geometry2D.get_closest_point_to_segment(
			global_position,
			from,
			to
		)
		if global_position.distance_to(closest) <= safe_radius + radius:
			return false
	return true


func reactivate() -> void:
	if respawn_timer != null:
		respawn_timer.stop()
	if telegraph_timer != null:
		telegraph_timer.stop()
	_reset_contacts()
	current_durability = get_max_durability()
	_set_collision_enabled(true)
	_set_hit_detection_enabled(true)
	_set_state(BumperState.ACTIVE)
	durability_changed.emit(current_durability, get_max_durability())


## 새 발사를 준비할 때 모든 범퍼를 즉시 최대 내구도로 복구합니다.
func reset_for_new_ball() -> void:
	if state == BumperState.ACTIVE and current_durability == get_max_durability():
		_reset_contacts()
		return
	reactivate()


func get_base_score() -> int:
	if instance_overrides != null and instance_overrides.base_score >= 0:
		return instance_overrides.base_score
	return settings.base_score if settings != null else 0


## 수리 부품은 별도 런타임 타입이 아니라 범퍼 정의의 보상·보유·배치 자격입니다.
func is_repair_part() -> bool:
	return settings != null and settings.is_repair_part


func get_score_weight() -> float:
	if instance_overrides != null and instance_overrides.score_weight >= 0.0:
		return instance_overrides.score_weight
	return settings.score_weight if settings != null else 1.0


func get_max_durability() -> int:
	if instance_overrides != null and instance_overrides.max_durability >= 1:
		return instance_overrides.max_durability
	return settings.max_durability if settings != null else 1


func get_durability_damage_per_hit() -> int:
	return settings.durability_damage_per_hit if settings != null else 1


func get_respawn_delay() -> float:
	if instance_overrides != null and instance_overrides.respawn_delay >= 0.0:
		return instance_overrides.respawn_delay
	return settings.respawn_delay if settings != null else 0.0


func get_speed_multiplier() -> float:
	if instance_overrides != null and instance_overrides.speed_multiplier >= 0.0:
		return instance_overrides.speed_multiplier
	return settings.speed_multiplier if settings != null else 1.0


func get_minimum_release_speed() -> float:
	if instance_overrides != null \
			and instance_overrides.minimum_release_speed >= 0.0:
		return instance_overrides.minimum_release_speed
	return settings.minimum_release_speed if settings != null else 0.0


func get_maximum_response_speed() -> float:
	if instance_overrides != null \
			and instance_overrides.maximum_response_speed >= 0.0:
		return instance_overrides.maximum_response_speed
	return settings.maximum_response_speed if settings != null else 1540.0


func get_selection_duration() -> float:
	if instance_overrides != null and instance_overrides.selection_duration >= 0.0:
		return instance_overrides.selection_duration
	return settings.selection_duration if settings != null else 0.8


func get_launch_speed() -> float:
	if instance_overrides != null and instance_overrides.launch_speed >= 0.0:
		return instance_overrides.launch_speed
	return settings.launch_speed if settings != null else 1300.0


func get_collision_radius() -> float:
	return settings.collision_diameter * 0.5 if settings != null else 44.0


func get_safe_respawn_radius() -> float:
	if settings == null:
		return 84.0
	return get_collision_radius() + settings.respawn_safe_margin


func _after_valid_hit(_ball: RigidBody2D, _contact_id: int) -> void:
	pass


func _should_defer_destruction_after_hit() -> bool:
	return false


func _create_default_strategy() -> BumperResponseStrategy:
	if settings == null:
		return NormalResponseStrategy.new()
	match settings.bumper_type:
		BumperSettings.BumperType.BOUNCE:
			return BounceResponseStrategy.new()
		BumperSettings.BumperType.SHOT:
			return ShotResponseStrategy.new()
		_:
			return NormalResponseStrategy.new()


func _on_hit_area_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		release_contact(body.get_instance_id())


func _on_respawn_timer_timeout() -> void:
	begin_safe_respawn_wait()


func _begin_respawn_telegraph() -> void:
	_set_state(BumperState.RESPAWN_TELEGRAPH)
	var duration := (
		settings.respawn_telegraph_duration
		if settings != null
		else 0.0
	)
	if telegraph_timer == null or duration <= 0.0:
		reactivate()
		return
	telegraph_timer.start(duration)


func _cancel_respawn_telegraph() -> void:
	if telegraph_timer != null:
		telegraph_timer.stop()
	_set_state(BumperState.SAFE_RESPAWN_WAIT)


func _on_telegraph_timer_timeout() -> void:
	if can_reactivate():
		reactivate()
	else:
		_cancel_respawn_telegraph()


func _set_state(next_state: BumperState) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(previous, state)
	if visual != null:
		visual.queue_redraw()


func _reset_contacts() -> void:
	active_contacts.clear()
	if combo_hit_source != null:
		combo_hit_source.reset_contacts()


func _set_collision_enabled(enabled: bool) -> void:
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", not enabled)


func _set_hit_detection_enabled(enabled: bool) -> void:
	if hit_area != null:
		hit_area.set_deferred(&"monitoring", enabled)
	if combo_hit_source != null:
		combo_hit_source.is_active = enabled


func _refresh_configuration() -> void:
	if not is_node_ready():
		return
	_sync_circle_shape(collision_shape, get_collision_radius())
	_sync_circle_shape(hit_area_shape, get_collision_radius() + 4.0)
	_sync_circle_shape(safe_respawn_shape, get_safe_respawn_radius())
	if combo_hit_source != null:
		combo_hit_source.source_id = bumper_id
		combo_hit_source.score_weight = get_score_weight()
	if visual != null and visual.has_method(&"refresh_from_bumper"):
		visual.call(&"refresh_from_bumper")
	update_configuration_warnings()


func _sync_circle_shape(shape_node: CollisionShape2D, radius: float) -> void:
	if shape_node == null or not shape_node.shape is CircleShape2D:
		return
	var circle := shape_node.shape as CircleShape2D
	if not circle.resource_local_to_scene:
		circle = circle.duplicate() as CircleShape2D
		circle.resource_local_to_scene = true
		shape_node.shape = circle
	circle.radius = maxf(radius, 1.0)


func _get_ball_collision_radius(ball: RigidBody2D) -> float:
	var shape_node := ball.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is CircleShape2D:
		return 0.0
	var circle := shape_node.shape as CircleShape2D
	var shape_scale := shape_node.global_scale.abs()
	return circle.radius * maxf(shape_scale.x, shape_scale.y)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if settings == null:
		warnings.append("BumperSettings Resource가 필요합니다.")
	elif not settings.is_valid():
		warnings.append("BumperSettings 값이 유효하지 않습니다.")
	if collision_shape == null:
		warnings.append("CollisionShape2D 자식 노드가 필요합니다.")
	if hit_area == null or hit_area_shape == null:
		warnings.append("HitArea/CollisionShape2D 자식 노드가 필요합니다.")
	if safe_respawn_area == null or safe_respawn_shape == null:
		warnings.append("SafeRespawnArea/CollisionShape2D 자식 노드가 필요합니다.")
	if combo_hit_source == null:
		warnings.append("ComboHitSource 자식 노드가 필요합니다.")
	return warnings
