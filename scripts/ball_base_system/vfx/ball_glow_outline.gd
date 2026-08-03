@tool
class_name BallGlowOutline
extends Node2D
## 공을 두르는 상시 발광 테두리입니다 (비주얼 가이드 VFX ①).
##
## 역할은 "예쁘게 빛나기"가 아니라 **공을 잃어버리지 않게 하는 것**입니다.
## 공이 어두운 보드·보스·벽·다른 파티클과 겹쳐도 즉시 찾을 수 있어야 합니다.
##
## 구조: Line2D 두 겹(넓고 흐린 글로우 + 얇고 밝은 코어)을 닫힌 원으로 만들고,
## Gradient의 알파로 갭을 뚫어 "빛이 원을 따라 흐르다 옅어지는" 인상을 만듭니다.
## 노드 전체를 천천히 회전시켜 그 갭이 원을 돌게 합니다.
##
## GL Compatibility 렌더러라 GPUParticles 트레일을 못 쓰므로 Line2D로 갑니다.
## 물리 바디의 위치·회전·크기는 절대 건드리지 않습니다.
## FlipperParryFeedback과 같은 "연출은 물리와 분리" 패턴입니다.


const DEFAULT_OUTLINE_RULES: BallGlowOutlineRules = preload(
	"res://settings/balls/BallGlowOutlineRules.tres"
)

## 비주얼 가이드의 레이어 순서입니다. 꼬리 < 공 본체 < 발광 테두리 < 파동 < 스파크.
const Z_INDEX_OUTLINE: int = 10

## 링을 이루는 점의 개수입니다. 44px에서 64점이면 각진 곳이 보이지 않습니다.
const RING_POINT_COUNT: int = 64

## 갭 중심 각도입니다. 두 개만 둬야 링이 조각난 호로 보이지 않습니다.
## PackedFloat32Array() 생성자는 상수 표현식이 아니므로 배열 리터럴로 둡니다.
const GAP_CENTERS := [0.9, 3.9]

## 공 지름이 이보다 크게 달라지면 링을 다시 만듭니다.
const DIAMETER_EPSILON: float = 0.01

## 부모에서 공 지름을 읽지 못했을 때 쓰는 값입니다. 기획서 기준 22px 반지름.
const FALLBACK_BALL_RADIUS: float = 22.0

## 그라디언트를 다시 만드는 점등량 변화 임계값입니다. 매 프레임 재생성을 막습니다.
const FLASH_REBUILD_EPSILON: float = 0.02

enum State {
	NORMAL,		## 기본. 조작 가능 상태
	COMBO,		## 콤보 상승
	CURSE,		## 저주
	DANGER,		## 위험·피격 직전
}

## 플리퍼가 보내는 패링 등급입니다. FlipperParryFeedback과 값을 맞춥니다.
const PARRY_GRADE_NONE: int = 0
const PARRY_GRADE_NORMAL: int = 1
const PARRY_GRADE_PERFECT: int = 2

const PARRY_SIGNAL: StringName = &"parry_resolved"


var _outline_rules: BallGlowOutlineRules = DEFAULT_OUTLINE_RULES
var _ball: Node2D
var _glow_line: Line2D
var _core_line: Line2D
var _state: State = State.NORMAL
var _flash_amount: float = 0.0
var _flash_hold_remaining: float = 0.0
var _built_diameter: float = -1.0
var _bound_flippers: Array[Node] = []
var _core_gradient: Gradient
var _glow_gradient: Gradient
## 갭 모양을 담아두는 캐시입니다. 점등량이 바뀔 때만 다시 계산합니다.
var _gap_offsets := PackedFloat32Array()
var _gap_ratios := PackedFloat32Array()
var _cached_gap_depth: float = -1.0


## 링 반응 규칙입니다. 씬에 내장하거나 .tres 프리셋으로 교체할 수 있습니다.
@export var outline_rules: BallGlowOutlineRules:
	get:
		return _outline_rules
	set(value):
		_outline_rules = value if value != null else DEFAULT_OUTLINE_RULES
		_built_diameter = -1.0
		_cached_gap_depth = -1.0
		update_configuration_warnings()

## 켜면 현재 씬에서 parry_resolved 시그널을 가진 노드를 찾아 자동으로 연결합니다.
## 끄면 bind_to_flipper()로 직접 붙입니다.
@export var auto_bind_parry: bool = true


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX_OUTLINE


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ball = get_parent() as Node2D
	_build_lines()
	_refresh_ring()

	if auto_bind_parry:
		_auto_bind_parry_sources()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_instance_valid(_ball):
		visible = false
		return

	# top_level이라 공의 visible을 물려받지 않으므로 직접 맞춥니다.
	visible = _ball.visible
	global_position = _ball.global_position
	# 오래 굴려도 각도가 커지지 않도록 한 바퀴로 감쌉니다.
	rotation = fposmod(rotation + _outline_rules.drift_speed * delta, TAU)

	_advance_flash(delta)
	_refresh_ring()


## 링의 기본 상태를 바꿉니다. 점등은 상태와 별개로 겹쳐집니다.
func set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_apply_colors()


func get_state() -> State:
	return _state


## 링을 강하게 점등시킵니다. strength 1.0이 정확한 패링의 전체 점등입니다.
func flash(strength: float = 1.0) -> void:
	var clamped := clampf(strength, 0.0, 1.0)
	if clamped <= 0.0:
		return

	_flash_amount = maxf(_flash_amount, clamped)
	_flash_hold_remaining = _outline_rules.flash_hold_time


## 패링 시그널을 가진 노드에 연결합니다. 같은 공의 패링만 반응합니다.
func bind_to_flipper(flipper: Node) -> void:
	if flipper == null or _bound_flippers.has(flipper):
		return

	if not flipper.has_signal(PARRY_SIGNAL):
		return

	flipper.connect(PARRY_SIGNAL, _on_parry_resolved)
	_bound_flippers.append(flipper)


## 현재 점등량입니다. 테스트와 디버그용입니다.
func get_flash_amount() -> float:
	return _flash_amount


## 현재 링 중심 반지름입니다(px). 공 지름에서 파생됩니다.
func get_ring_radius() -> float:
	return _ball_radius() * _outline_rules.radius_ratio


# ── 내부 ────────────────────────────────────────────────────

## 공 지름은 Pinball에만 있는 속성이라 정적 타입 접근이 안 됩니다.
## get()으로 읽어야 부모가 Pinball이 아니어도 파스·실행 모두 안전합니다.
func _ball_radius() -> float:
	if is_instance_valid(_ball):
		var diameter: Variant = _ball.get(&"ball_diameter")
		if diameter != null:
			return maxf(float(diameter), 1.0) * 0.5

	return FALLBACK_BALL_RADIUS


func _build_lines() -> void:
	_glow_line = Line2D.new()
	_glow_line.name = "Glow"
	_glow_line.closed = true
	_glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow_line.antialiased = true
	add_child(_glow_line)

	_core_line = Line2D.new()
	_core_line.name = "Core"
	_core_line.closed = true
	_core_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_core_line.antialiased = true
	add_child(_core_line)

	_glow_gradient = Gradient.new()
	_core_gradient = Gradient.new()
	_glow_line.gradient = _glow_gradient
	_core_line.gradient = _core_gradient


## 공 지름이 바뀌었으면 점을 다시 깔고, 점등량이 바뀌었으면 색·두께를 갱신합니다.
func _refresh_ring() -> void:
	if _glow_line == null or _core_line == null:
		return

	var diameter := _ball_radius() * 2.0
	if absf(diameter - _built_diameter) > DIAMETER_EPSILON:
		_built_diameter = diameter
		_rebuild_points()

	_apply_colors()


func _rebuild_points() -> void:
	var radius := get_ring_radius()
	var points := PackedVector2Array()
	points.resize(RING_POINT_COUNT)

	for i in RING_POINT_COUNT:
		var angle := TAU * float(i) / float(RING_POINT_COUNT)
		var r := radius * _radius_at(angle)
		points[i] = Vector2(cos(angle) * r, sin(angle) * r)

	_glow_line.points = points
	_core_line.points = points


## 손그림 느낌의 반지름 배율입니다. 저주파만 섞어 원으로 읽히게 유지합니다.
func _radius_at(angle: float) -> float:
	var wobble := _outline_rules.wobble_amount
	return 1.0 + wobble * sin(3.0 * angle) + wobble * 0.45 * sin(7.0 * angle + 1.7)


func _apply_colors() -> void:
	var base_core := _state_core_color()
	var base_glow := _state_glow_color()
	var core_color := base_core.lerp(_outline_rules.flash_core_color, _flash_amount)
	var glow_color := base_glow.lerp(_outline_rules.flash_glow_color, _flash_amount)

	var width_scale := lerpf(1.0, _outline_rules.flash_width_scale, _flash_amount)
	var radius := _ball_radius()
	_core_line.width = radius * _outline_rules.core_width_ratio * width_scale
	_glow_line.width = radius * _outline_rules.glow_width_ratio * width_scale

	_refresh_gap_shape()
	_paint_gradient(_core_gradient, core_color)
	_paint_gradient(_glow_gradient, glow_color)


## 갭 모양(오프셋과 알파 배율)을 다시 계산합니다.
## 점등이 강해질수록 갭이 메워져 "전체 점등"이 됩니다.
func _refresh_gap_shape() -> void:
	var gap_depth := 1.0 - _flash_amount
	if (
		absf(gap_depth - _cached_gap_depth) <= FLASH_REBUILD_EPSILON
		and not _gap_offsets.is_empty()
	):
		return

	_cached_gap_depth = gap_depth

	var half := _outline_rules.gap_half_width
	var soft := _outline_rules.gap_softness
	# GAP_CENTERS가 오름차순이고 갭이 겹치지 않으므로 이미 정렬된 상태로 쌓입니다.
	var stops: Array[Vector2] = [Vector2(0.0, 1.0)]

	for center: float in GAP_CENTERS:
		stops.append(Vector2((center - half - soft) / TAU, 1.0))
		stops.append(Vector2((center - half) / TAU, 1.0 - gap_depth))
		stops.append(Vector2((center + half) / TAU, 1.0 - gap_depth))
		stops.append(Vector2((center + half + soft) / TAU, 1.0))

	stops.append(Vector2(1.0, 1.0))

	_gap_offsets = PackedFloat32Array()
	_gap_ratios = PackedFloat32Array()

	var previous := -1.0
	for stop: Vector2 in stops:
		var offset := clampf(stop.x, 0.0, 1.0)
		# Gradient의 오프셋은 증가해야 하므로 겹치면 아주 조금 밀어냅니다.
		if offset <= previous:
			offset = minf(previous + 0.0005, 1.0)

		previous = offset
		_gap_offsets.append(offset)
		_gap_ratios.append(stop.y)


## 캐시된 갭 모양에 색만 입혀 그라디언트를 갱신합니다. 새 객체를 만들지 않습니다.
func _paint_gradient(gradient: Gradient, color: Color) -> void:
	if gradient == null or _gap_offsets.is_empty():
		return

	var colors := PackedColorArray()
	colors.resize(_gap_ratios.size())
	for i in _gap_ratios.size():
		colors[i] = Color(color.r, color.g, color.b, color.a * _gap_ratios[i])

	gradient.offsets = _gap_offsets
	gradient.colors = colors


func _state_core_color() -> Color:
	match _state:
		State.COMBO:
			return _outline_rules.combo_core_color
		State.CURSE:
			return _outline_rules.curse_core_color
		State.DANGER:
			return _outline_rules.danger_core_color
		_:
			return _outline_rules.normal_core_color


func _state_glow_color() -> Color:
	match _state:
		State.COMBO:
			return _outline_rules.combo_glow_color
		State.CURSE:
			return _outline_rules.curse_glow_color
		State.DANGER:
			return _outline_rules.danger_glow_color
		_:
			return _outline_rules.normal_glow_color


func _advance_flash(delta: float) -> void:
	if _flash_amount <= 0.0:
		return

	if _flash_hold_remaining > 0.0:
		_flash_hold_remaining = maxf(_flash_hold_remaining - delta, 0.0)
		return

	var fade_step := delta / maxf(_outline_rules.flash_fade_time, 0.001)
	_flash_amount = maxf(_flash_amount - fade_step, 0.0)


func _auto_bind_parry_sources() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	_bind_recursive(scene_root)


func _bind_recursive(node: Node) -> void:
	if node.has_signal(PARRY_SIGNAL):
		bind_to_flipper(node)

	for child in node.get_children():
		_bind_recursive(child)


func _on_parry_resolved(
	ball: RigidBody2D,
	grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_speed_multiplier: float
) -> void:
	if ball != _ball or grade == PARRY_GRADE_NONE:
		return

	if grade == PARRY_GRADE_PERFECT:
		flash(1.0)
	else:
		flash(_outline_rules.normal_grade_strength)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is Node2D):
		warnings.append("BallGlowOutline의 부모는 공(Node2D)이어야 합니다.")

	if _outline_rules == null:
		warnings.append("Outline Rules 리소스를 지정해야 합니다.")

	return warnings
