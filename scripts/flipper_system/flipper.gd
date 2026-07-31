@tool
class_name PinballFlipper
extends AnimatableBody2D


signal state_changed(previous_state: int, current_state: int)
signal rotation_sweep_resolved(ball: RigidBody2D)
signal parry_resolved(
	ball: RigidBody2D,
	grade: int,
	contact_point: Vector2,
	contact_zone: int,
	elapsed_time: float,
	speed_multiplier: float
)


enum ContactZone {
	A,
	B,
	C,
	D,
}


const FlipperStateClass := preload("res://scripts/flipper_system/flipper_state.gd")
const FlipperStateMachineClass := preload(
	"res://scripts/flipper_system/flipper_state_machine.gd"
)
const FlipperContactZoneOverlayClass := preload(
	"res://scripts/flipper_system/flipper_contact_zone_overlay.gd"
)
const FlipperParryEvaluatorClass := preload(
	"res://scripts/flipper_system/parrying/flipper_parry_evaluator.gd"
)
const FlipperParryFeedbackClass := preload(
	"res://scripts/flipper_system/parrying/flipper_parry_feedback.gd"
)
const DEFAULT_STATE_RULES: Resource = preload(
	"res://settings/flippers/FlipperStateRules.tres"
)
const DEFAULT_PARRY_RULES: Resource = preload(
	"res://settings/flippers/FlipperParryRules.tres"
)

const MIN_FLIPPER_LENGTH: float = 64.0
const MAX_FLIPPER_LENGTH: float = 4096.0
const DEFAULT_FLIPPER_LENGTH: float = 1552.0
const MIN_SOURCE_SIZE: float = 0.001
const PINBALL_GROUP: StringName = &"pinball_balls"
const MIN_SWEEP_INTERVAL: float = 1.0
const MAX_SWEEP_INTERVAL: float = 64.0
const DEFAULT_SWEEP_INTERVAL: float = 8.0
const MAX_ROTATION_SWEEP_STEPS: int = 128
const CONTACT_ZONE_COLORS: Array[Color] = [
	Color(0.3, 0.75, 1.0, 0.9),
	Color(0.35, 1.0, 0.45, 0.9),
	Color(1.0, 0.8, 0.2, 0.9),
	Color(1.0, 0.3, 0.3, 0.9),
]
const CONTACT_ZONE_OVERLAY_NAME: StringName = &"_ContactZoneOverlay"
const CONTACT_ZONE_OVERLAY_PATH: NodePath = ^"_ContactZoneOverlay"
const PARRY_FEEDBACK_NAME: StringName = &"_ParryFeedback"
const PARRY_FEEDBACK_PATH: NodePath = ^"_ParryFeedback"


var _state_rules: Resource = DEFAULT_STATE_RULES
var _parry_rules: Resource = DEFAULT_PARRY_RULES
var _state_machine: RefCounted
var _parry_evaluator: RefCounted = FlipperParryEvaluatorClass.new()
var _is_selected: bool = false
@export_storage var _source_collision_polygon := PackedVector2Array()
@export_storage var _source_collision_position := Vector2.ZERO
@export_storage var _has_source_collision_position := false
var _last_applied_collision_polygon := PackedVector2Array()
var _last_applied_collision_position := Vector2.ZERO
var _has_last_applied_collision_position := false


## 모든 플리퍼가 공유하는 상태 시간 및 상태별 반사 배율 설정입니다.
## 개별 Inspector에서는 교체하지 않고 settings의 .tres를 편집합니다.
var state_rules: Resource:
	get:
		return _state_rules


## 모든 플리퍼가 공유하는 접촉 구역 및 패링 설정입니다.
## 개별 Inspector에서는 교체하지 않고 settings의 .tres를 편집합니다.
var parry_rules: Resource:
	get:
		return _parry_rules if _parry_rules != null else DEFAULT_PARRY_RULES


@export_category("플리퍼 설정")


@export_group("크기")

## 피벗 방향과 원본 이미지 비율을 유지한 플리퍼의 긴 변 길이입니다.
## Sprite2D와 CollisionPolygon2D의 크기 및 피벗 상대 위치에 함께 적용됩니다.
@export_range(64.0, 4096.0, 1.0, "suffix:px")
var flipper_length: float = DEFAULT_FLIPPER_LENGTH:
	set(value):
		flipper_length = clampf(
			value,
			MIN_FLIPPER_LENGTH,
			MAX_FLIPPER_LENGTH
		)
		refresh_flipper_size()
		# 인스턴스 씬 로딩 중에는 자식 노드보다 export 값이 먼저 복원될 수 있습니다.
		# 자식 구성이 끝난 뒤 한 번 더 적용해 에디터 뷰도 확실히 갱신합니다.
		call_deferred(&"refresh_flipper_size")


@export_group("충돌 안전 검사")

## 한 물리 프레임의 회전 궤적을 나눠 검사할 최대 이동 간격입니다.
## 값이 작을수록 터널링 검사가 촘촘해지지만 검사 횟수가 늘어납니다.
@export_range(1.0, 64.0, 1.0, "suffix:px")
var rotation_sweep_interval: float = DEFAULT_SWEEP_INTERVAL:
	set(value):
		rotation_sweep_interval = clampf(
			value,
			MIN_SWEEP_INTERVAL,
			MAX_SWEEP_INTERVAL
		)


@export_group("개별 상태 설정")

## 플리퍼가 대기 및 쿨다운 상태에서 유지할 로컬 각도입니다.
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var initial_angle_degrees: float = 0.0:
	set(value):
		initial_angle_degrees = clampf(value, -180.0, 180.0)

		if Engine.is_editor_hint() or get_current_state_type() == FlipperStateClass.Type.IDLE:
			rotation = deg_to_rad(initial_angle_degrees)

## 작동 상태가 끝났을 때 도달할 로컬 최대 각도입니다.
@export_range(-180.0, 180.0, 1.0, "suffix:°")
var maximum_angle_degrees: float = -35.0:
	set(value):
		maximum_angle_degrees = clampf(value, -180.0, 180.0)

## 복귀가 끝난 뒤 다시 입력을 받을 때까지 기다리는 개별 시간입니다.
@export_range(0.0, 5.0, 0.01, "suffix:s")
var cooldown_time: float = 0.15:
	set(value):
		cooldown_time = clampf(value, 0.0, 5.0)

## 공용 A 구역 속도 배율에 곱하는 이 플리퍼만의 보정값입니다.
@export_range(0.0, 5.0, 0.01, "suffix:x")
var contact_zone_a_speed_multiplier: float = 1.0:
	set(value):
		contact_zone_a_speed_multiplier = clampf(value, 0.0, 5.0)

## 공용 B 구역 속도 배율에 곱하는 이 플리퍼만의 보정값입니다.
@export_range(0.0, 5.0, 0.01, "suffix:x")
var contact_zone_b_speed_multiplier: float = 1.0:
	set(value):
		contact_zone_b_speed_multiplier = clampf(value, 0.0, 5.0)

## 공용 C 구역 속도 배율에 곱하는 이 플리퍼만의 보정값입니다.
@export_range(0.0, 5.0, 0.01, "suffix:x")
var contact_zone_c_speed_multiplier: float = 1.0:
	set(value):
		contact_zone_c_speed_multiplier = clampf(value, 0.0, 5.0)

## 공용 D 구역 속도 배율에 곱하는 이 플리퍼만의 보정값입니다.
@export_range(0.0, 5.0, 0.01, "suffix:x")
var contact_zone_d_speed_multiplier: float = 1.0:
	set(value):
		contact_zone_d_speed_multiplier = clampf(value, 0.0, 5.0)


@export_group("상태")

var is_flipping: bool:
	get:
		return get_current_state_type() != FlipperStateClass.Type.IDLE


@export_group("쉐이더")

@onready var sprite: Sprite2D = $Sprite2D

@export var shader_active_value: String = "outline_enabled"


func _enter_tree() -> void:
	_connect_parry_rules_changed()
	call_deferred(&"_ensure_contact_zone_overlay")
	# @tool 인스턴스가 에디터 씬 트리에 들어온 뒤 자식 노드까지 구성된 시점에 적용합니다.
	call_deferred(&"refresh_flipper_size")


func _ready() -> void:
	# 다른 플리퍼와 Material 상태를 공유하지 않도록 복제
	if sprite.material:
		sprite.material = sprite.material.duplicate()

	_ensure_state_machine()
	rotation = deg_to_rad(initial_angle_degrees)
	refresh_flipper_size()
	_refresh_selection_visual()
	_ensure_contact_zone_overlay()
	_ensure_parry_feedback()
	_queue_contact_zone_overlay_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_ensure_state_machine()
	# AnimatableBody2D는 물리 동기화 중 rotation getter가 한 틱 전 값을 반환할 수 있습니다.
	# 상태 머신이 보관한 논리 각도를 사용해야 실제 이번 회전 구간을 잃지 않습니다.
	var previous_rotation := float(_state_machine.get_target_rotation())
	var previous_state_type := get_current_state_type()
	var previous_state_elapsed := get_current_state_elapsed_time()
	var target_rotation := float(_state_machine.physics_update(delta, state_rules))

	# 작동 상태에서 이전 각도 이후부터 이번 최종 각도까지 공을 별도 검사합니다.
	# 일반 접촉이 놓칠 수 있는 최종 각도 겹침도 같은 경로에서 해결합니다.
	if previous_state_type == FlipperStateClass.Type.ACTIVE:
		resolve_rotation_sweep(
			previous_rotation,
			target_rotation,
			delta,
			previous_state_elapsed
		)


## 설정된 길이를 시각 이미지와 충돌 폴리곤에 같은 비율로 적용합니다.
## 물리 충돌 노드에는 Scale을 사용하지 않고 폴리곤 점 좌표에 크기를 반영합니다.
func refresh_flipper_size() -> void:
	var target_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D

	if target_sprite == null or target_sprite.texture == null:
		if is_inside_tree():
			update_configuration_warnings()
		return

	var texture_size := target_sprite.texture.get_size()
	var source_length := maxf(absf(texture_size.x), absf(texture_size.y))

	if source_length <= MIN_SOURCE_SIZE:
		return

	var size_factor := flipper_length / source_length
	target_sprite.scale = Vector2.ONE * size_factor

	if collision != null:
		_capture_collision_source_if_needed(collision, size_factor)
		_capture_collision_position_if_needed(collision, size_factor)
		collision.polygon = _build_scaled_collision_polygon(size_factor)
		_last_applied_collision_polygon = collision.polygon.duplicate()
		collision.scale = Vector2.ONE
		collision.position = _source_collision_position * size_factor
		_last_applied_collision_position = collision.position
		_has_last_applied_collision_position = true

	if is_inside_tree():
		update_configuration_warnings()
		_queue_contact_zone_overlay_redraw()


## 현재 폴리곤과 Scale이 만드는 실제 모양을 원본 길이 기준 점으로 환산합니다.
## 최초 씬의 음수 Scale(오른쪽 플리퍼 반전)도 이때 점 좌표에 흡수됩니다.
func _capture_collision_source_if_needed(
	collision: CollisionPolygon2D,
	current_size_factor: float
) -> void:
	var polygon_was_edited := (
		not _last_applied_collision_polygon.is_empty()
		and collision.polygon != _last_applied_collision_polygon
	)
	var transform_was_edited := not collision.scale.is_equal_approx(Vector2.ONE)

	if (
		not _source_collision_polygon.is_empty()
		and not polygon_was_edited
		and not transform_was_edited
	):
		return

	_source_collision_polygon.clear()
	if collision.polygon.is_empty() or current_size_factor <= MIN_SOURCE_SIZE:
		return

	var source_divisor := current_size_factor
	if _last_applied_collision_polygon.is_empty() \
			and collision.scale.is_equal_approx(Vector2.ONE):
		# 자식 노드가 export 값보다 늦게 복원되면 폴리곤은 아직 원본 크기입니다.
		source_divisor = 1.0

	for point: Vector2 in collision.polygon:
		var effective_point := point * collision.scale
		_source_collision_polygon.append(effective_point / source_divisor)


func _build_scaled_collision_polygon(size_factor: float) -> PackedVector2Array:
	var scaled_polygon := PackedVector2Array()
	scaled_polygon.resize(_source_collision_polygon.size())

	for index in _source_collision_polygon.size():
		scaled_polygon[index] = _source_collision_polygon[index] * size_factor

	return scaled_polygon


## 스프라이트 중심과 별개로 조정된 충돌체 위치를 원본 길이 기준으로 보관합니다.
## 에디터에서 CollisionPolygon2D를 직접 옮긴 경우에도 새 위치를 다시 기억합니다.
func _capture_collision_position_if_needed(
	collision: CollisionPolygon2D,
	current_size_factor: float
) -> void:
	if current_size_factor <= MIN_SOURCE_SIZE:
		return

	var position_was_edited := false
	if _has_last_applied_collision_position:
		position_was_edited = not collision.position.is_equal_approx(
			_last_applied_collision_position
		)
	elif _has_source_collision_position:
		var expected_position := _source_collision_position * current_size_factor
		position_was_edited = not collision.position.is_equal_approx(expected_position)

	if _has_source_collision_position and not position_was_edited:
		return

	var source_divisor := current_size_factor
	if not _has_source_collision_position \
			and collision.scale.is_equal_approx(Vector2.ONE):
		# 자식 노드가 export 값보다 늦게 복원되면 위치도 아직 원본 기준입니다.
		source_divisor = 1.0

	_source_collision_position = collision.position / source_divisor
	_has_source_collision_position = true


## 플리퍼 끝점의 호 이동 거리가 안전 간격 이하가 되도록 검사 횟수를 계산합니다.
func get_rotation_sweep_step_count(
	previous_rotation: float,
	target_rotation: float
) -> int:
	var angle_delta := absf(_get_short_rotation_delta(
		previous_rotation,
		target_rotation
	))
	var arc_distance := angle_delta * _get_collision_sweep_radius()
	return clampi(
		int(ceil(arc_distance / rotation_sweep_interval)),
		1,
		MAX_ROTATION_SWEEP_STEPS
	)


## 지정한 각도의 플리퍼 폴리곤과 원형 공이 겹치는지 확인합니다.
func is_circle_overlapping_at_rotation(
	circle_center: Vector2,
	circle_radius: float,
	test_rotation: float
) -> bool:
	var polygon := _get_world_collision_polygon(test_rotation)
	return _is_circle_overlapping_polygon(circle_center, circle_radius, polygon)


## 시작 각도 이후부터 최종 각도까지 최초로 공과 겹친 각도를 찾습니다.
## 빠른 회전은 최종 각도 겹침도 일반 물리가 놓칠 수 있으므로 검사에 포함합니다.
func find_rotation_sweep_hit(
	circle_center: Vector2,
	circle_radius: float,
	previous_rotation: float,
	target_rotation: float
) -> Dictionary:
	if is_circle_overlapping_at_rotation(
		circle_center,
		circle_radius,
		previous_rotation
	):
		return {}

	var step_count := get_rotation_sweep_step_count(
		previous_rotation,
		target_rotation
	)
	var angle_delta := _get_short_rotation_delta(
		previous_rotation,
		target_rotation
	)

	for step_index in range(1, step_count + 1):
		var progress := float(step_index) / float(step_count)
		var sample_rotation := previous_rotation + angle_delta * progress

		if is_circle_overlapping_at_rotation(
			circle_center,
			circle_radius,
			sample_rotation
		):
			var polygon := _get_world_collision_polygon(sample_rotation)
			var contact := _get_circle_polygon_contact(circle_center, polygon)
			var hit := {
				&"rotation": sample_rotation,
				&"progress": progress,
			}
			if not contact.is_empty():
				var contact_point: Vector2 = contact.get(&"point")
				var contact_percent := calculate_contact_position_percent(
					contact_point,
					sample_rotation
				)
				hit[&"point"] = contact_point
				hit[&"normal"] = contact.get(&"normal")
				hit[&"contact_percent"] = contact_percent
				hit[&"contact_zone"] = get_contact_zone(contact_percent)
			return hit

	return {}


## 회전축을 0%, 중앙 갭을 향하는 플리퍼 끝을 100%로 접촉 위치를 환산합니다.
## 전역 X축 대신 실제 충돌 폴리곤의 길이축을 사용해 좌우 반전과 회전을 함께 처리합니다.
func calculate_contact_position_percent(
	contact_point: Vector2,
	test_rotation: float = rotation
) -> float:
	var polygon := _get_world_collision_polygon(test_rotation)
	if polygon.size() < 2:
		return 0.0

	var pivot := global_position
	var polygon_center := Vector2.ZERO
	for point: Vector2 in polygon:
		polygon_center += point
	polygon_center /= float(polygon.size())

	var length_axis := polygon_center - pivot
	if length_axis.is_zero_approx():
		for point: Vector2 in polygon:
			var radial_vector := point - pivot
			if radial_vector.length_squared() > length_axis.length_squared():
				length_axis = radial_vector

	if length_axis.is_zero_approx():
		return 0.0

	length_axis = length_axis.normalized()
	var tip_distance := 0.0
	for point: Vector2 in polygon:
		tip_distance = maxf(
			tip_distance,
			(point - pivot).dot(length_axis)
		)

	if tip_distance <= MIN_SOURCE_SIZE:
		return 0.0

	var contact_distance := (contact_point - pivot).dot(length_axis)
	return clampf(contact_distance / tip_distance * 100.0, 0.0, 100.0)


## 공용 패링 설정의 접촉 위치 경계로 A/B/C/D 구역을 판정합니다.
func get_contact_zone(contact_percent: float) -> ContactZone:
	var clamped_percent := clampf(contact_percent, 0.0, 100.0)
	if clamped_percent < float(parry_rules.get(&"zone_a_end_percent")):
		return ContactZone.A
	if clamped_percent < float(parry_rules.get(&"zone_b_end_percent")):
		return ContactZone.B
	if clamped_percent < float(parry_rules.get(&"zone_c_end_percent")):
		return ContactZone.C
	return ContactZone.D


## 개별 플리퍼에 설정된 접촉 구역의 속도 배율을 반환합니다.
func get_contact_zone_speed_multiplier(contact_zone: ContactZone) -> float:
	match contact_zone:
		ContactZone.A:
			return (
				float(parry_rules.get(&"zone_a_speed_multiplier"))
				* contact_zone_a_speed_multiplier
			)
		ContactZone.B:
			return (
				float(parry_rules.get(&"zone_b_speed_multiplier"))
				* contact_zone_b_speed_multiplier
			)
		ContactZone.C:
			return (
				float(parry_rules.get(&"zone_c_speed_multiplier"))
				* contact_zone_c_speed_multiplier
			)
		ContactZone.D:
			return (
				float(parry_rules.get(&"zone_d_speed_multiplier"))
				* contact_zone_d_speed_multiplier
			)

	return 1.0


## 물리 반사 방향은 유지하고 접촉 구역에 따라 속력만 조절합니다.
func apply_contact_zone_speed_multiplier(
	physical_reflection_velocity: Vector2,
	contact_zone: ContactZone
) -> Vector2:
	return physical_reflection_velocity * get_contact_zone_speed_multiplier(
		contact_zone
	)


## 구역 설정이 켜진 경우 좌우 플리퍼 부호를 반영해 반사 방향만 회전시킵니다.
func apply_contact_zone_angle_correction(
	reflected_velocity: Vector2,
	contact_zone: ContactZone
) -> Vector2:
	if reflected_velocity.is_zero_approx() \
		or not is_contact_zone_angle_correction_enabled(contact_zone):
		return reflected_velocity

	var correction_degrees := get_contact_zone_angle_correction_degrees(
		contact_zone
	)
	var signed_correction := correction_degrees * get_flipper_angle_direction_sign()
	return reflected_velocity.rotated(deg_to_rad(signed_correction))


func is_contact_zone_angle_correction_enabled(
	contact_zone: ContactZone
) -> bool:
	var property_name: StringName
	match contact_zone:
		ContactZone.A:
			property_name = &"zone_a_angle_correction_enabled"
		ContactZone.B:
			property_name = &"zone_b_angle_correction_enabled"
		ContactZone.C:
			property_name = &"zone_c_angle_correction_enabled"
		ContactZone.D:
			property_name = &"zone_d_angle_correction_enabled"
		_:
			return false

	return bool(parry_rules.get(property_name))


func get_contact_zone_angle_correction_degrees(
	contact_zone: ContactZone
) -> float:
	var property_name: StringName
	match contact_zone:
		ContactZone.A:
			property_name = &"zone_a_angle_correction_degrees"
		ContactZone.B:
			property_name = &"zone_b_angle_correction_degrees"
		ContactZone.C:
			property_name = &"zone_c_angle_correction_degrees"
		ContactZone.D:
			property_name = &"zone_d_angle_correction_degrees"
		_:
			return 0.0

	return float(parry_rules.get(property_name))


## 피벗에서 충돌체가 뻗는 방향으로 좌우 플리퍼를 판별합니다.
func get_flipper_angle_direction_sign() -> float:
	var axis_data := _get_local_contact_zone_axis_data()
	if axis_data.is_empty():
		return 1.0

	var axis: Vector2 = axis_data.get(&"axis")
	if axis.x >= 0.0:
		return float(parry_rules.get(&"left_angle_direction_sign"))
	return float(parry_rules.get(&"right_angle_direction_sign"))


func is_contact_zone_visualization_enabled() -> bool:
	return bool(parry_rules.get(&"show_contact_zones_in_editor"))


## 전면 오버레이가 그릴 A/B/C/D 구역 선분 정보를 반환합니다.
func get_contact_zone_visualization_segments() -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if not is_contact_zone_visualization_enabled():
		return segments
	var axis_data := _get_local_contact_zone_axis_data()
	if axis_data.is_empty():
		return segments

	var axis: Vector2 = axis_data.get(&"axis")
	var tip_distance := float(axis_data.get(&"tip_distance"))
	var normal := axis.orthogonal()
	var offset := normal * flipper_length * -0.1
	var line_width := maxf(8.0, flipper_length * 0.025)
	var boundaries := PackedFloat32Array([
		0.0,
		float(parry_rules.get(&"zone_a_end_percent")),
		float(parry_rules.get(&"zone_b_end_percent")),
		float(parry_rules.get(&"zone_c_end_percent")),
		100.0,
	])

	for zone_index in ContactZone.size():
		var start_distance := tip_distance * boundaries[zone_index] / 100.0
		var end_distance := tip_distance * boundaries[zone_index + 1] / 100.0
		segments.append({
			&"start": offset + axis * start_distance,
			&"end": offset + axis * end_distance,
			&"color": CONTACT_ZONE_COLORS[zone_index],
			&"width": line_width,
		})

	return segments


func _ensure_contact_zone_overlay() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return

	var overlay := get_node_or_null(CONTACT_ZONE_OVERLAY_PATH) as Node2D
	if overlay == null:
		overlay = FlipperContactZoneOverlayClass.new() as Node2D
		overlay.name = CONTACT_ZONE_OVERLAY_NAME
		add_child(overlay, false, Node.INTERNAL_MODE_FRONT)

	overlay.queue_redraw()


func _queue_contact_zone_overlay_redraw() -> void:
	if not Engine.is_editor_hint():
		return

	var overlay := get_node_or_null(CONTACT_ZONE_OVERLAY_PATH) as Node2D
	if overlay != null:
		overlay.queue_redraw()


func _ensure_parry_feedback() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return

	var feedback := get_node_or_null(PARRY_FEEDBACK_PATH) as Node2D
	if feedback == null:
		feedback = FlipperParryFeedbackClass.new() as Node2D
		feedback.name = PARRY_FEEDBACK_NAME
		add_child(feedback, false, Node.INTERNAL_MODE_FRONT)

	feedback.call(&"bind_to_flipper", self)


func _get_local_contact_zone_axis_data() -> Dictionary:
	var collision := get_node_or_null(
		"CollisionPolygon2D"
	) as CollisionPolygon2D
	if collision == null or collision.polygon.size() < 2:
		return {}

	var local_polygon := collision.transform * collision.polygon
	var polygon_center := Vector2.ZERO
	for point: Vector2 in local_polygon:
		polygon_center += point
	polygon_center /= float(local_polygon.size())
	if polygon_center.is_zero_approx():
		return {}

	var axis := polygon_center.normalized()
	var tip_distance := 0.0
	for point: Vector2 in local_polygon:
		tip_distance = maxf(tip_distance, point.dot(axis))
	if tip_distance <= MIN_SOURCE_SIZE:
		return {}

	return {
		&"axis": axis,
		&"tip_distance": tip_distance,
	}


## 움직이는 플리퍼 표면을 기준으로 공의 상대속도를 물리 반사합니다.
## 접선 성분은 보존하고 법선 성분에만 탄성을 적용한 뒤 표면 속도를 다시 더합니다.
func calculate_physical_sweep_velocity(
	incoming_velocity: Vector2,
	surface_velocity: Vector2,
	collision_normal: Vector2,
	elasticity: float = 1.0
) -> Vector2:
	var normal := collision_normal.normalized()
	if normal.is_zero_approx():
		return incoming_velocity

	var relative_velocity := incoming_velocity - surface_velocity
	var incoming_normal_speed := relative_velocity.dot(normal)
	if incoming_normal_speed >= 0.0:
		return incoming_velocity

	var clamped_elasticity := clampf(elasticity, 0.0, 1.0)
	var reflected_relative_velocity := relative_velocity - normal * (
		(1.0 + clamped_elasticity) * incoming_normal_speed
	)
	return surface_velocity + reflected_relative_velocity


## 시작 자세 밖에 있지만 회전 중간 또는 끝 자세에서 건너뛴 공을 찾아 임펄스를 줍니다.
## Transform 보정 없이 속도 변화만 물리 서버에 전달합니다.
## 반환값은 이 물리 프레임에서 별도 임펄스를 적용한 공의 개수입니다.
func resolve_rotation_sweep(
	previous_rotation: float,
	target_rotation: float,
	delta: float,
	active_elapsed_before_sweep: float = -1.0
) -> int:
	if (
		not is_inside_tree()
		or delta <= 0.0
		or is_equal_approx(previous_rotation, target_rotation)
	):
		return 0

	var resolved_count := 0
	for candidate: Node in get_tree().get_nodes_in_group(PINBALL_GROUP):
		if not candidate is RigidBody2D:
			continue

		var ball := candidate as RigidBody2D
		var ball_collision := ball.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D
		if ball_collision == null or not ball_collision.shape is CircleShape2D:
			continue

		var circle := ball_collision.shape as CircleShape2D
		var collision_scale := ball_collision.global_scale.abs()
		var circle_radius := circle.radius * maxf(
			collision_scale.x,
			collision_scale.y
		)
		var hit := find_rotation_sweep_hit(
			ball_collision.global_position,
			circle_radius,
			previous_rotation,
			target_rotation
		)

		if hit.is_empty():
			continue

		var hit_point: Vector2 = hit.get(&"point", ball_collision.global_position)
		var hit_normal: Vector2 = hit.get(&"normal", Vector2.UP)
		var contact_zone: ContactZone = int(hit.get(
			&"contact_zone",
			ContactZone.B
		))
		var impact_elapsed_time := -1.0
		if active_elapsed_before_sweep >= 0.0:
			impact_elapsed_time = active_elapsed_before_sweep + delta * clampf(
				float(hit.get(&"progress", 1.0)),
				0.0,
				1.0
			)
		var parry_grade := get_parry_grade(impact_elapsed_time)
		var impulse_applied := _resolve_swept_ball(
			ball,
			hit_point,
			hit_normal,
			contact_zone,
			previous_rotation,
			target_rotation,
			delta,
			parry_grade
		)
		if impulse_applied and parry_grade != FlipperParryEvaluatorClass.Grade.NONE:
			parry_resolved.emit(
				ball,
				parry_grade,
				hit_point,
				contact_zone,
				impact_elapsed_time,
				get_parry_speed_multiplier(parry_grade)
			)
		rotation_sweep_resolved.emit(ball)
		resolved_count += 1

	return resolved_count


func _resolve_swept_ball(
	ball: RigidBody2D,
	hit_point: Vector2,
	hit_normal: Vector2,
	contact_zone: ContactZone,
	previous_rotation: float,
	target_rotation: float,
	delta: float,
	parry_grade: int = FlipperParryEvaluatorClass.Grade.NONE
) -> bool:
	var pivot := global_position
	var total_rotation := _get_short_rotation_delta(
		previous_rotation,
		target_rotation
	)
	var angular_velocity := total_rotation / delta
	var radial_vector := hit_point - pivot
	var surface_velocity := Vector2(
		-radial_vector.y,
		radial_vector.x
	) * angular_velocity
	var resolved_velocity := calculate_physical_sweep_velocity(
		ball.linear_velocity,
		surface_velocity,
		hit_normal,
		_get_ball_elasticity(ball)
	)
	resolved_velocity = apply_contact_zone_speed_multiplier(
		resolved_velocity,
		contact_zone
	)
	resolved_velocity = apply_contact_zone_angle_correction(
		resolved_velocity,
		contact_zone
	)
	resolved_velocity = apply_parry_speed_multiplier(
		resolved_velocity,
		parry_grade
	)
	var velocity_change := resolved_velocity - ball.linear_velocity
	if velocity_change.is_zero_approx():
		return false

	# RigidBody2D의 Transform이나 속도를 직접 덮어쓰지 않습니다.
	# 목표 속도 변화량을 질량에 맞는 순간 임펄스로 변환해 물리 서버에 전달합니다.
	ball.sleeping = false
	ball.apply_central_impulse(velocity_change * ball.mass)
	return true


func _get_ball_elasticity(ball: RigidBody2D) -> float:
	var physics_material := ball.physics_material_override
	if physics_material == null:
		return 0.0

	return clampf(physics_material.bounce, 0.0, 1.0)


func _get_collision_sweep_radius() -> float:
	var collision := get_node_or_null(
		"CollisionPolygon2D"
	) as CollisionPolygon2D
	if collision == null:
		return 0.0

	var maximum_radius := collision.position.length()
	for point: Vector2 in collision.polygon:
		maximum_radius = maxf(
			maximum_radius,
			(collision.position + point).length()
		)

	return maximum_radius


func _get_world_collision_polygon(test_rotation: float) -> PackedVector2Array:
	var collision := get_node_or_null(
		"CollisionPolygon2D"
	) as CollisionPolygon2D
	if collision == null or collision.polygon.is_empty():
		return PackedVector2Array()

	var parent_global_transform := Transform2D.IDENTITY
	if get_parent() is Node2D:
		parent_global_transform = (get_parent() as Node2D).global_transform

	var flipper_transform := Transform2D(test_rotation, position)
	var world_transform := (
		parent_global_transform
		* flipper_transform
		* collision.transform
	)
	return world_transform * collision.polygon


func _is_circle_overlapping_polygon(
	circle_center: Vector2,
	circle_radius: float,
	polygon: PackedVector2Array
) -> bool:
	if polygon.size() < 3:
		return false

	if Geometry2D.is_point_in_polygon(circle_center, polygon):
		return true

	var radius_squared := circle_radius * circle_radius
	for point_index in polygon.size():
		var next_index := (point_index + 1) % polygon.size()
		var closest_point := Geometry2D.get_closest_point_to_segment(
			circle_center,
			polygon[point_index],
			polygon[next_index]
		)
		if circle_center.distance_squared_to(closest_point) <= radius_squared:
			return true

	return false


func _get_circle_polygon_contact(
	circle_center: Vector2,
	polygon: PackedVector2Array
) -> Dictionary:
	if polygon.size() < 2:
		return {}

	var closest_point := polygon[0]
	var closest_edge_start := polygon[0]
	var closest_edge_end := polygon[1]
	var closest_distance_squared := INF

	for point_index in polygon.size():
		var next_index := (point_index + 1) % polygon.size()
		var edge_point := Geometry2D.get_closest_point_to_segment(
			circle_center,
			polygon[point_index],
			polygon[next_index]
		)
		var distance_squared := circle_center.distance_squared_to(edge_point)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_point = edge_point
			closest_edge_start = polygon[point_index]
			closest_edge_end = polygon[next_index]

	var center_is_inside := Geometry2D.is_point_in_polygon(circle_center, polygon)
	var normal := (
		closest_point - circle_center
		if center_is_inside
		else circle_center - closest_point
	)

	if normal.is_zero_approx():
		var polygon_center := Vector2.ZERO
		for point: Vector2 in polygon:
			polygon_center += point
		polygon_center /= float(polygon.size())

		normal = (closest_edge_end - closest_edge_start).orthogonal().normalized()
		if normal.dot(closest_point - polygon_center) < 0.0:
			normal = -normal
	else:
		normal = normal.normalized()

	return {
		&"point": closest_point,
		&"normal": normal,
	}


func _get_short_rotation_delta(from_rotation: float, to_rotation: float) -> float:
	return wrapf(to_rotation - from_rotation, -PI, PI)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var target_sprite := get_node_or_null("Sprite2D") as Sprite2D
	var collision := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D

	if target_sprite == null:
		warnings.append("Sprite2D 자식 노드가 필요합니다.")
	elif target_sprite.texture == null:
		warnings.append("Sprite2D에 Texture2D를 지정해야 합니다.")

	if collision == null:
		warnings.append("CollisionPolygon2D 자식 노드가 필요합니다.")
	elif collision.polygon.is_empty():
		warnings.append("CollisionPolygon2D에 Polygon 점을 지정해야 합니다.")

	if not scale.is_equal_approx(Vector2.ONE):
		warnings.append("플리퍼 루트의 Scale은 (1, 1)로 유지하고 Flipper Length를 사용하세요.")

	return warnings


func set_selected_visual(is_selected: bool) -> void:
	_is_selected = is_selected
	_refresh_selection_visual()


func _refresh_selection_visual() -> void:
	var target_sprite := get_node_or_null("Sprite2D") as Sprite2D

	if target_sprite == null:
		return

	var shader_material := target_sprite.material as ShaderMaterial

	if shader_material == null:
		return

	shader_material.set_shader_parameter(
		shader_active_value,
		_is_selected and get_current_state_type() == FlipperStateClass.Type.IDLE
	)


func set_state_rules(value: Resource) -> void:
	_state_rules = value if value != null else DEFAULT_STATE_RULES


func set_parry_rules(value: Resource) -> void:
	if _parry_rules == value and _parry_rules != null:
		return

	if (
		_parry_rules != null
		and _parry_rules.changed.is_connected(_on_parry_rules_changed)
	):
		_parry_rules.changed.disconnect(_on_parry_rules_changed)

	_parry_rules = value if value != null else DEFAULT_PARRY_RULES
	_connect_parry_rules_changed()
	_on_parry_rules_changed()


func _connect_parry_rules_changed() -> void:
	if _parry_rules == null:
		_parry_rules = DEFAULT_PARRY_RULES

	if (
		_parry_rules != null
		and not _parry_rules.changed.is_connected(_on_parry_rules_changed)
	):
		_parry_rules.changed.connect(_on_parry_rules_changed)


func _on_parry_rules_changed() -> void:
	_ensure_contact_zone_overlay()
	_queue_contact_zone_overlay_redraw()
	if is_inside_tree():
		update_configuration_warnings()


func request_activation() -> bool:
	_ensure_state_machine()
	return _state_machine.request_activation()


func get_current_state_type() -> int:
	if _state_machine == null:
		return FlipperStateClass.Type.IDLE

	return _state_machine.get_current_state_type()


func get_current_state_elapsed_time() -> float:
	if _state_machine == null:
		return 0.0
	return float(_state_machine.get_current_state_elapsed_time())


## 작동 입력부터 충돌까지의 시간으로 NONE/NORMAL/PERFECT 등급을 반환합니다.
func get_parry_grade(elapsed_time: float) -> int:
	return int(_parry_evaluator.call(&"evaluate", elapsed_time, parry_rules))


func get_parry_speed_multiplier(parry_grade: int) -> float:
	return float(_parry_evaluator.call(
		&"get_speed_multiplier",
		parry_grade,
		parry_rules
	))


## 물리 반사와 접촉 구역 계산이 끝난 속력에 패링 배율만 추가합니다.
func apply_parry_speed_multiplier(
	reflected_velocity: Vector2,
	parry_grade: int
) -> Vector2:
	return _parry_evaluator.call(
		&"apply_speed_multiplier",
		reflected_velocity,
		parry_grade,
		parry_rules
	) as Vector2


## 현재 작동 상태의 경과 시간이 일반 패링 판정 안에 있는지 공개합니다.
func is_parry_window() -> bool:
	if get_current_state_type() != FlipperStateClass.Type.ACTIVE:
		return false
	return get_parry_grade(get_current_state_elapsed_time()) \
		!= FlipperParryEvaluatorClass.Grade.NONE


## 복귀 중 충돌에만 빗맞음 반사 배율을 적용합니다.
## 다른 상태의 특수 충돌 결과는 패링 판정이 정해질 때 추가합니다.
func get_ball_impact(_context: BallImpactContext) -> Variant:
	if get_current_state_type() != FlipperStateClass.Type.RETURNING:
		return null

	var result := BallImpactResult.new()
	result.direction_mode = BallImpactResult.DirectionMode.PHYSICAL_REFLECTION
	result.speed_multiplier = float(state_rules.get(&"return_reflection_multiplier"))
	result.maximum_speed = INF
	return result


func _ensure_state_machine() -> void:
	if _state_machine != null:
		return

	_state_machine = FlipperStateMachineClass.new(self)
	_state_machine.state_changed.connect(_on_state_machine_state_changed)


func _on_state_machine_state_changed(
	previous_state: int,
	current_state: int
) -> void:
	_refresh_selection_visual()
	state_changed.emit(previous_state, current_state)
