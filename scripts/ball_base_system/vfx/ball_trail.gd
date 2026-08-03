@tool
class_name BallTrail
extends Node2D
## 공이 지나온 경로를 보여주는 이동 꼬리입니다 (비주얼 가이드 VFX ②).
##
## 역할은 "예쁘게 빛나기"가 아니라 **공이 어디서 와서 어디로 가는지 읽게 하는 것**입니다.
## 빠르게 움직여도 플레이어가 방향을 읽고 다음 플리퍼를 고를 수 있어야 합니다.
##
## 구조(2026-08-03 형락님 확정, 안 D1): 셰이더를 입힌 Line2D 한 장에 2겹을 그립니다.
##   ① 안쪽 레이저 — 가늘고 흰색, 경계 또렷 (뿌리 9px)
##   ② 바깥 블룸   — 레이저를 감싸는 청록 안개 (뿌리 60px)
## Line2D 를 두 개 쓰면 두 선의 점·폭을 매 프레임 맞춰야 하고 미세하게 어긋납니다.
## 폭 커브를 블룸에 맞춰두면 셰이더가 UV 만으로 두 겹을 다 그릴 수 있습니다.
##
## 물리 바디의 위치·회전·크기는 절대 건드리지 않습니다.
## FlipperParryFeedback / BallGlowOutline 과 같은 "연출은 물리와 분리" 패턴입니다.


const DEFAULT_TRAIL_RULES: BallTrailRules = preload(
	"res://settings/balls/BallTrailRules.tres"
)

const TRAIL_SHADER: Shader = preload("res://Resources/shaders/ball_trail.gdshader")

## 비주얼 가이드의 레이어 순서입니다. 꼬리 < 공 본체 < 발광 테두리 < 파동 < 스파크.
## 공 본체(Visual)는 6, 발광 테두리는 10 입니다.
const Z_INDEX_TRAIL: int = 5

## 부모에서 공 지름을 읽지 못했을 때 쓰는 값입니다. 기획서 기준 22px 반지름.
const FALLBACK_BALL_RADIUS: float = 22.0

## 새 점을 찍는 최소 이동 거리(공 반지름 대비)입니다.
## 너무 촘촘하면 점이 뭉쳐 곡선이 각져 보입니다.
const SAMPLE_STEP_RATIO: float = 0.18

## 폭 커브를 만들 때 쓰는 표본 수입니다.
const WIDTH_CURVE_SAMPLES: int = 12


var _trail_rules: BallTrailRules = DEFAULT_TRAIL_RULES
var _ball: Node2D
var _line: Line2D
var _material: ShaderMaterial
var _width_curve: Curve
## 최신이 앞(0번)입니다. 0번이 공 위치라야 UV.x 0 이 공 쪽이 됩니다.
var _history: PackedVector2Array = PackedVector2Array()
## _history 와 1:1 로 짝지은 각 점의 나이(초)입니다. 항상 같은 길이로 유지합니다.
var _ages: PackedFloat32Array = PackedFloat32Array()
var _fade: float = 0.0
var _built_diameter: float = -1.0


## 꼬리 규칙입니다. 씬에 내장하거나 .tres 프리셋으로 교체할 수 있습니다.
@export var trail_rules: BallTrailRules:
	get:
		return _trail_rules
	set(value):
		_trail_rules = value if value != null else DEFAULT_TRAIL_RULES
		_built_diameter = -1.0
		update_configuration_warnings()


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX_TRAIL


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ball = get_parent() as Node2D
	_build_line()
	_refresh_line()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_instance_valid(_ball):
		visible = false
		return

	# top_level 이라 점 좌표를 월드 좌표 그대로 넣는다.
	# 노드를 원점에 고정해야 공이 움직여도 과거 점을 다시 변환할 필요가 없다.
	global_position = Vector2.ZERO
	global_rotation = 0.0

	var speed := _ball_speed()
	var moving := speed >= _trail_rules.hide_below_speed

	_advance_fade(delta, moving)
	_sample_history(moving, delta)
	_refresh_line()

	# 완전히 사라졌고 기록도 비었으면 그리지 않는다
	visible = _ball.visible and _fade > 0.001 and _history.size() >= 2


## 현재 속도로 정해지는 꼬리 길이입니다(px). 테스트와 디버그용입니다.
func get_trail_length() -> float:
	var rules := _trail_rules
	var base := _ball_radius() * rules.length_ratio
	var scale_v := clampf(
		_ball_speed() / maxf(rules.reference_speed, 1.0),
		rules.min_length_scale,
		rules.max_length_scale
	)
	return base * scale_v


## 현재 페이드 값입니다. 0이면 완전히 숨은 상태입니다.
func get_fade() -> float:
	return _fade


## 기록된 점 개수입니다.
func get_point_count() -> int:
	return _history.size()


## 셰이더에 실제로 들어간 값을 읽습니다. 테스트용입니다.
func get_shader_param(name: StringName) -> Variant:
	if _material == null:
		return null

	return _material.get_shader_parameter(name)


## 공이 순간이동했을 때처럼 기록을 버려야 하는 경우에 씁니다.
func clear_trail() -> void:
	_history = PackedVector2Array()
	_ages = PackedFloat32Array()
	if _line != null:
		_line.points = PackedVector2Array()


# ── 내부 ────────────────────────────────────────────────────

## 공 지름·속도는 Pinball 에만 있는 속성이라 정적 타입 접근이 안 됩니다.
## get() 으로 읽어야 부모가 Pinball 이 아니어도 파스·실행 모두 안전합니다.
func _ball_radius() -> float:
	if is_instance_valid(_ball):
		var diameter: Variant = _ball.get(&"ball_diameter")
		if diameter != null:
			return maxf(float(diameter), 1.0) * 0.5

	return FALLBACK_BALL_RADIUS


func _ball_speed() -> float:
	if is_instance_valid(_ball):
		var velocity: Variant = _ball.get(&"linear_velocity")
		if velocity != null:
			return (velocity as Vector2).length()

	return 0.0


func _build_line() -> void:
	# 셰이더가 UV 전체에 그려지려면 실제로 픽셀이 있는 텍스처가 필요합니다.
	# 흰색 1x1 이면 충분합니다. 셰이더가 COLOR 를 통째로 덮어씁니다.
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	_material = ShaderMaterial.new()
	_material.shader = TRAIL_SHADER

	_width_curve = Curve.new()

	_line = Line2D.new()
	_line.name = "Trail"
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.antialiased = false
	_line.texture = ImageTexture.create_from_image(image)
	_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_line.width_curve = _width_curve
	_line.material = _material
	add_child(_line)


## 공 지름이 바뀌었으면 폭과 커브를 다시 잡습니다.
func _rebuild_width() -> void:
	var rules := _trail_rules
	var ball_r := _ball_radius()

	# Line2D.width 는 전체 폭입니다. 블룸 뿌리 반폭의 두 배가 됩니다.
	_line.width = ball_r * rules.bloom_root * 2.0

	# 폭 커브를 블룸 테이퍼와 똑같이 맞춰야 셰이더의 across 가 곧 "블룸 반폭 대비 거리"가 됩니다.
	_width_curve.clear_points()
	for i in WIDTH_CURVE_SAMPLES:
		var t := float(i) / float(WIDTH_CURVE_SAMPLES - 1)
		var half := rules.bloom_tip + (rules.bloom_root - rules.bloom_tip) \
			* pow(maxf(1.0 - t, 0.0), rules.bloom_power)
		_width_curve.add_point(Vector2(t, half / maxf(rules.bloom_root, 0.0001)))


## 궤적에 점을 찍고, 나이 든 점과 길이를 넘는 꼬리를 잘라냅니다.
func _sample_history(moving: bool, delta: float) -> void:
	var here := _ball.global_position

	# ★ 먼저 나이를 먹인다. 이게 없으면 공이 느려졌을 때 옛 점이 월드 좌표에 그대로
	#   얼어붙어 잔상이 남는다. 거리로만 자르면 공이 멈춘 동안 누적 길이가 줄지 않는다.
	for i in _ages.size():
		_ages[i] += delta

	# 0번은 항상 공에 붙어 있는 "살아있는 머리"입니다. 1번부터가 확정된 궤적입니다.
	if _history.size() < 2:
		if moving:
			_history = PackedVector2Array([here, here])
			_ages = PackedFloat32Array([0.0, 0.0])
		return

	# 머리는 매 프레임 공을 따라갑니다. 끊겨 보이지 않게 하려면 필요합니다.
	_history[0] = here
	_ages[0] = 0.0

	# ★ 간격 검사는 머리가 아니라 **마지막으로 확정된 점**과 비교해야 합니다.
	#   머리와 비교하면 머리를 매 프레임 옮기므로 거리가 항상 한 프레임치라
	#   느린 공에서는 점이 영영 확정되지 않고 꼬리가 점 하나로 붕괴합니다.
	var step := _ball_radius() * SAMPLE_STEP_RATIO
	if here.distance_to(_history[1]) >= step:
		_history.insert(1, here)
		_ages.insert(1, 0.0)

	_drop_expired()
	_trim_to_length()

	var limit := _trail_rules.point_count
	while _history.size() > limit:
		_resize_history(_history.size() - 1)


## 수명이 다한 점을 꼬리 끝에서부터 버립니다.
## 나이는 뒤로 갈수록 크므로 끝에서부터 검사하면 됩니다.
func _drop_expired() -> void:
	var lifetime := _trail_rules.point_lifetime
	while _history.size() > 0 and _ages[_ages.size() - 1] > lifetime:
		_resize_history(_history.size() - 1)


## 두 배열의 길이를 항상 함께 맞춥니다. 하나만 줄이면 나이와 좌표가 어긋납니다.
func _resize_history(new_size: int) -> void:
	_history.resize(new_size)
	_ages.resize(new_size)


## 누적 길이가 목표를 넘는 지점에서 꼬리를 잘라냅니다.
## 마지막 한 칸은 정확히 목표 길이가 되도록 보간해 길이가 톱니처럼 튀지 않게 합니다.
func _trim_to_length() -> void:
	var target := get_trail_length()
	var total := 0.0

	for i in range(1, _history.size()):
		var seg := _history[i - 1].distance_to(_history[i])
		if total + seg >= target:
			var remain := maxf(target - total, 0.0)
			var ratio := remain / maxf(seg, 0.0001)
			var cut := _history[i - 1].lerp(_history[i], ratio)
			_resize_history(i + 1)
			_history[i] = cut
			return

		total += seg


func _advance_fade(delta: float, moving: bool) -> void:
	var rules := _trail_rules
	if moving:
		_fade = minf(_fade + delta / maxf(rules.fade_in_time, 0.001), 1.0)
		return

	_fade = maxf(_fade - delta / maxf(rules.fade_out_time, 0.001), 0.0)
	if _fade <= 0.0:
		# 완전히 사라진 뒤에야 기록을 버린다. 사라지는 중에 끊기면 툭 잘려 보인다
		_history = PackedVector2Array()
		_ages = PackedFloat32Array()


func _refresh_line() -> void:
	if _line == null or _material == null:
		return

	var diameter := _ball_radius() * 2.0
	if absf(diameter - _built_diameter) > 0.01:
		_built_diameter = diameter
		_rebuild_width()

	_line.points = _history
	_apply_uniforms()


func _apply_uniforms() -> void:
	var rules := _trail_rules
	_material.set_shader_parameter(&"ball_radius_px", _ball_radius())
	_material.set_shader_parameter(&"bloom_root", rules.bloom_root)
	_material.set_shader_parameter(&"bloom_tip", rules.bloom_tip)
	_material.set_shader_parameter(&"bloom_power", rules.bloom_power)
	_material.set_shader_parameter(&"core_root", rules.core_root)
	_material.set_shader_parameter(&"core_tip", rules.core_tip)
	_material.set_shader_parameter(&"core_power", rules.core_power)
	_material.set_shader_parameter(&"steps", float(rules.band_steps))
	_material.set_shader_parameter(&"step_gamma", rules.step_gamma)
	_material.set_shader_parameter(&"core_step_drop", float(rules.core_step_drop))
	_material.set_shader_parameter(&"bloom_alpha", rules.bloom_alpha)
	_material.set_shader_parameter(&"core_alpha", rules.core_alpha)
	_material.set_shader_parameter(&"fade", _fade)
	_material.set_shader_parameter(&"laser_hot", rules.laser_hot)
	_material.set_shader_parameter(&"laser_tip", rules.laser_tip)
	_material.set_shader_parameter(&"bloom_in", rules.bloom_in)
	_material.set_shader_parameter(&"bloom_mid", rules.bloom_mid)
	_material.set_shader_parameter(&"bloom_out", rules.bloom_out)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is Node2D):
		warnings.append("BallTrail의 부모는 공(Node2D)이어야 합니다.")

	if _trail_rules == null:
		warnings.append("Trail Rules 리소스를 지정해야 합니다.")

	return warnings
