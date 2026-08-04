@tool
class_name BallGlowOutline
extends Node2D
## 공을 감싸는 상시 발광 테두리입니다 (비주얼 가이드 VFX ①).
##
## 역할은 "예쁘게 빛나기"가 아니라 **공을 잃어버리지 않게 하는 것**입니다.
## 공이 어두운 보드·보스·벽·다른 파티클과 겹쳐도 즉시 찾을 수 있어야 합니다.
##
## 구조(2026-08-03 리디자인): 셰이더를 입힌 Sprite2D 쿼드 한 장입니다.
## 안개는 선이 아니라 면이라 Line2D 2겹으로는 표현할 수 없습니다.
## GL Compatibility 렌더러는 GPUParticles 트레일을 못 쓰지만 셰이더는 제약이 없습니다.
##
## 물리 바디의 위치·회전·크기는 절대 건드리지 않습니다.
## FlipperParryFeedback과 같은 "연출은 물리와 분리" 패턴입니다.


const DEFAULT_OUTLINE_RULES: BallGlowOutlineRules = preload(
	"res://settings/balls/BallGlowOutlineRules.tres"
)

const MIST_SHADER: Shader = preload("res://Resources/shaders/ball_mist_aura.gdshader")

## 비주얼 가이드의 레이어 순서입니다. 꼬리 < 공 본체 < 발광 테두리 < 파동 < 스파크.
const Z_INDEX_OUTLINE: int = 10

## 쿼드가 안개 최대 반경보다 얼마나 여유를 두는지입니다.
## 여유가 없으면 안개가 쿼드 경계에서 잘려 네모난 자국이 남습니다.
const QUAD_PADDING: float = 1.16

## 공 지름이 이보다 크게 달라지면 쿼드 크기를 다시 잡습니다.
const DIAMETER_EPSILON: float = 0.01

## 부모에서 공 지름을 읽지 못했을 때 쓰는 값입니다. 기획서 기준 22px 반지름.
const FALLBACK_BALL_RADIUS: float = 22.0

## 이 속도 미만에서는 진행방향 늘림을 끕니다. 멈춘 공이 한쪽으로 쏠려 보이지 않게 합니다.
const GAZE_MIN_SPEED: float = 40.0

## 코어 링 두께의 최소 px입니다. 작은 공에서 링이 사라지지 않게 합니다.
const MIN_CORE_WIDTH_PX: float = 0.85

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
## 씬에서 규칙을 직접 꽂았는지입니다. 꽂았으면 프로필이 덮어쓰지 못합니다.
var _explicit_rules: bool = false
var _ball: Node2D
var _quad: Sprite2D
var _material: ShaderMaterial
var _state: State = State.NORMAL
var _flash_amount: float = 0.0
var _flash_hold_remaining: float = 0.0
var _built_diameter: float = -1.0
var _drift_phase: float = 0.0
var _gaze_angle: float = 0.0
var _gaze_enabled: float = 0.0
var _bound_flippers: Array[Node] = []


## 링 반응 규칙입니다. 씬에 내장하거나 .tres 프리셋으로 교체할 수 있습니다.
@export var outline_rules: BallGlowOutlineRules:
	get:
		return _outline_rules
	set(value):
		_outline_rules = value if value != null else DEFAULT_OUTLINE_RULES
		_explicit_rules = value != null
		_built_diameter = -1.0
		update_configuration_warnings()

## 켜면 현재 씬에서 parry_resolved 시그널을 가진 노드를 찾아 자동으로 연결합니다.
## 끄면 bind_to_flipper()로 직접 붙입니다.
@export var auto_bind_parry: bool = true

## 켜면 공의 속도 방향으로 안개가 살짝 길어집니다.
@export var gaze_follow_velocity: bool = true


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX_OUTLINE


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ball = get_parent() as Node2D
	_adopt_profile_rules()
	_build_quad()
	_refresh_quad()


	if auto_bind_parry:
		_auto_bind_parry_sources()


## 공에 VFX 프로필이 꽂혀 있으면 그 규칙을 가져옵니다.
##
## 씬에서 규칙을 직접 지정했다면 그쪽이 이깁니다. 프로필은 "기본값 대체"이지
## "씬 설정 덮어쓰기"가 아닙니다. 특정 공 하나만 손보는 길을 막으면 안 됩니다.
func _adopt_profile_rules() -> void:
	if _explicit_rules or not is_instance_valid(_ball):
		return

	var profile_value: Variant = _ball.get(&"vfx_profile")
	if profile_value == null:
		return

	var profile := profile_value as BallVfxProfile
	if profile == null or profile.glow_rules == null:
		return

	_outline_rules = profile.glow_rules
	_built_diameter = -1.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not is_instance_valid(_ball):
		visible = false
		return

	# top_level이라 공의 visible을 물려받지 않으므로 직접 맞춥니다.
	visible = _ball.visible
	global_position = _ball.global_position

	# 노드를 돌리지 않습니다. 안개가 통째로 회전하면 물체가 도는 것처럼 보입니다.
	# 대신 셰이더의 위상만 밀어 안개가 제자리에서 소용돌이치게 합니다.
	# 오래 굴려도 값이 커지지 않도록 한 바퀴로 감쌉니다.
	_drift_phase = fposmod(_drift_phase + _outline_rules.drift_speed * delta, TAU)

	_update_gaze()
	_advance_flash(delta)
	_refresh_quad()


## 링의 기본 상태를 바꿉니다. 점등은 상태와 별개로 겹쳐집니다.
func set_state(new_state: State) -> void:
	if _state == new_state:
		return

	_state = new_state
	_apply_uniforms()


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


## 안개가 도달하는 최대 반지름입니다(px). 공 지름에서 파생됩니다.
func get_ring_radius() -> float:
	return _ball_radius() * _outline_rules.radius_ratio


## 안개가 흐른 누적 위상입니다. 테스트용입니다.
func get_drift_phase() -> float:
	return _drift_phase


## 셰이더에 실제로 들어간 값을 읽습니다. 테스트용입니다.
func get_shader_param(name: StringName) -> Variant:
	if _material == null:
		return null

	return _material.get_shader_parameter(name)


# ── 내부 ────────────────────────────────────────────────────

## 공 지름은 Pinball에만 있는 속성이라 정적 타입 접근이 안 됩니다.
## get()으로 읽어야 부모가 Pinball이 아니어도 파스·실행 모두 안전합니다.
func _ball_radius() -> float:
	if is_instance_valid(_ball):
		var diameter: Variant = _ball.get(&"ball_diameter")
		if diameter != null:
			return maxf(float(diameter), 1.0) * 0.5

	return FALLBACK_BALL_RADIUS


func _build_quad() -> void:
	# 셰이더가 UV 전체에 그려지려면 실제로 픽셀이 있는 텍스처가 필요합니다.
	# 흰색 1x1이면 충분합니다. 셰이더가 COLOR를 통째로 덮어쓰므로 내용은 안 씁니다.
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	_material = ShaderMaterial.new()
	_material.shader = MIST_SHADER

	_quad = Sprite2D.new()
	_quad.name = "Mist"
	_quad.centered = true
	_quad.texture = ImageTexture.create_from_image(image)
	_quad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_quad.material = _material
	add_child(_quad)


## 공 지름이 바뀌었으면 쿼드를 다시 재고, 매 프레임 유니폼을 갱신합니다.
func _refresh_quad() -> void:
	if _quad == null or _material == null:
		return

	var diameter := _ball_radius() * 2.0
	if absf(diameter - _built_diameter) > DIAMETER_EPSILON:
		_built_diameter = diameter
		# 1x1 텍스처라 scale이 곧 px 크기입니다.
		var quad_size := get_ring_radius() * 2.0 * QUAD_PADDING
		_quad.scale = Vector2(quad_size, quad_size)

	_apply_uniforms()


func _update_gaze() -> void:
	if not gaze_follow_velocity or not is_instance_valid(_ball):
		_gaze_enabled = 0.0
		return

	var velocity: Variant = _ball.get(&"linear_velocity")
	if velocity == null:
		_gaze_enabled = 0.0
		return

	var v: Vector2 = velocity
	if v.length() < GAZE_MIN_SPEED:
		_gaze_enabled = 0.0
		return

	_gaze_angle = v.angle()
	_gaze_enabled = 1.0


func _apply_uniforms() -> void:
	if _material == null:
		return

	var rules := _outline_rules
	var ball_r := _ball_radius()
	var outer_r := get_ring_radius()
	# 쿼드 반지름을 1.0으로 보는 정규화 좌표로 넘깁니다. 셰이더에 px을 넘기지 않습니다.
	var half_quad := maxf(outer_r * QUAD_PADDING, 0.001)

	var core_color := _state_core_color()
	var mist_color := _state_mist_color()
	core_color = core_color.lerp(rules.flash_core_color, _flash_amount)
	mist_color = mist_color.lerp(rules.flash_mist_color, _flash_amount)

	var darken := rules.outer_darken
	var outer_color := Color(
		mist_color.r * darken,
		mist_color.g * darken,
		mist_color.b * darken,
		mist_color.a
	)

	var gain := lerpf(1.0, rules.flash_alpha_scale, _flash_amount)
	var core_width := maxf(ball_r * rules.core_width_ratio, MIN_CORE_WIDTH_PX)

	_material.set_shader_parameter(&"ball_ratio", ball_r / half_quad)
	_material.set_shader_parameter(&"outer_ratio", outer_r / half_quad)
	_material.set_shader_parameter(&"peak", rules.peak_alpha)
	_material.set_shader_parameter(&"bands", float(rules.band_count))
	_material.set_shader_parameter(&"falloff_exp", rules.falloff_exp)
	_material.set_shader_parameter(&"plume", rules.plume_amount)
	_material.set_shader_parameter(&"plume_lobes", float(rules.plume_lobes))
	_material.set_shader_parameter(&"wisp", rules.wisp_amount)
	_material.set_shader_parameter(&"wisp_lobes", float(rules.wisp_lobes))
	_material.set_shader_parameter(&"wisp_radial", float(rules.wisp_radial))
	_material.set_shader_parameter(&"inner_bloom", rules.inner_bloom)
	_material.set_shader_parameter(&"gaze_stretch", rules.gaze_stretch)
	_material.set_shader_parameter(&"gaze_angle", _gaze_angle)
	_material.set_shader_parameter(&"gaze_enabled", _gaze_enabled)
	_material.set_shader_parameter(&"core_alpha", rules.core_alpha)
	_material.set_shader_parameter(&"core_w_norm", core_width / half_quad)
	_material.set_shader_parameter(&"core_gain", gain)
	_material.set_shader_parameter(&"alpha_gain", gain)
	_material.set_shader_parameter(&"wobble", rules.wobble_amount)
	_material.set_shader_parameter(&"drift_phase", _drift_phase)
	_material.set_shader_parameter(&"seed", 7.0)
	_material.set_shader_parameter(&"col_core", core_color)
	_material.set_shader_parameter(&"col_mist", mist_color)
	_material.set_shader_parameter(&"col_outer", outer_color)


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


func _state_mist_color() -> Color:
	match _state:
		State.COMBO:
			return _outline_rules.combo_mist_color
		State.CURSE:
			return _outline_rules.curse_mist_color
		State.DANGER:
			return _outline_rules.danger_mist_color
		_:
			return _outline_rules.normal_mist_color


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
