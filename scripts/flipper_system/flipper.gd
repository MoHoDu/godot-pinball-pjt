@tool
class_name PinballFlipper
extends AnimatableBody2D


signal state_changed(previous_state: int, current_state: int)


const FlipperStateClass := preload("res://scripts/flipper_system/flipper_state.gd")
const FlipperStateMachineClass := preload(
	"res://scripts/flipper_system/flipper_state_machine.gd"
)
const DEFAULT_STATE_RULES: Resource = preload(
	"res://settings/flippers/FlipperStateRules.tres"
)

const MIN_FLIPPER_LENGTH: float = 64.0
const MAX_FLIPPER_LENGTH: float = 4096.0
const DEFAULT_FLIPPER_LENGTH: float = 1552.0
const MIN_SOURCE_SIZE: float = 0.001


var _state_rules: Resource = DEFAULT_STATE_RULES
var _state_machine: RefCounted
var _is_selected: bool = false


## 모든 플리퍼가 공유하는 상태 시간 및 상태별 반사 배율 설정입니다.
## 개별 Inspector에서는 교체하지 않고 settings의 .tres를 편집합니다.
var state_rules: Resource:
	get:
		return _state_rules


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

## 접촉 위치에 따른 반사 배율입니다.
## 위치 판정 방식이 정해질 때까지 값만 보관하며 현재 충돌 계산에는 사용하지 않습니다.
@export_range(0.0, 5.0, 0.05, "suffix:x")
var contact_position_reflection_multiplier: float = 1.0:
	set(value):
		contact_position_reflection_multiplier = clampf(value, 0.0, 5.0)


@export_group("상태")

var is_flipping: bool:
	get:
		return get_current_state_type() != FlipperStateClass.Type.IDLE


@export_group("쉐이더")

@onready var sprite: Sprite2D = $Sprite2D

@export var shader_active_value: String = "outline_enabled"


func _enter_tree() -> void:
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


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_ensure_state_machine()
	_state_machine.physics_update(delta, state_rules)


## 설정된 길이를 시각 이미지와 충돌 폴리곤에 같은 비율로 적용합니다.
## 폴리곤 점 원본은 유지하고 노드의 균일 배율 및 피벗 상대 위치만 갱신합니다.
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
		var orientation := Vector2(
			_sign_or_one(collision.scale.x),
			_sign_or_one(collision.scale.y)
		)
		collision.scale = orientation * size_factor
		collision.position = target_sprite.offset * size_factor

	if is_inside_tree():
		update_configuration_warnings()


func _sign_or_one(value: float) -> float:
	return signf(value) if not is_zero_approx(value) else 1.0


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


func request_activation() -> bool:
	_ensure_state_machine()
	return _state_machine.request_activation()


func get_current_state_type() -> int:
	if _state_machine == null:
		return FlipperStateClass.Type.IDLE

	return _state_machine.get_current_state_type()


## 작동 상태 전체를 패링 가능 구간으로 공개합니다.
## 일반/정확 패링 판정과 배율 적용은 판정 기준이 정해질 때 구현합니다.
func is_parry_window() -> bool:
	return get_current_state_type() == FlipperStateClass.Type.ACTIVE


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
