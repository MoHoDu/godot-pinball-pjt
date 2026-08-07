class_name BossArtRig
extends Node2D
## 눈 잃은 테디베어 보스의 아트 리그입니다.
##
## 몸통·왼팔·오른팔·눈구멍 2·하트핵 여섯 장을 걸어 두고,
## 상태별 자세·표정·전환을 전부 여기서 처리합니다.
##
## ## 왜 프레임이 아니라 회전인가
##
## 기획서 8-2 의 팔 충돌체는 **캡슐**이고 공격 회전 범위가 **80~90°** 입니다.
## 충돌체는 어깨에서 도는데 그림이 한 장이면 충돌만 돌고 그림은 안 돕니다.
## 공이 보이지 않는 팔에 맞게 되고, 가이드 20절의 즉시 반려 기준
## "팔 공격 방향을 VFX 만 보고 알 수 없음" 에 걸립니다.
##
## ## 왜 상태가 자세를 통째로 갖는가
##
## 처음에는 팔 각도와 표정만 상태별로 바꿨더니 **기본 대기 빼고 전부 어색**하다는
## 지적을 받았다 (2026-08-07). 원인은 둘이었다.
## - 상태가 **즉시 스냅**됐다. 천 인형이 순간이동하듯 자세를 바꿨다.
## - 몸이 안 움직였다. 예고의 "몸 전체가 아래로 압축", 피격의 "짧게 찌그러지고
##   흔들림", 포효의 "고개를 들어" 가 전부 빠져 있었다.
## 그래서 상태마다 팔·몸 눌림·기울기·오프셋·표정·전환 속도를 전부 정의하고,
## `_process` 에서 지수 보간으로 따라가게 했다.
##
## ## 이 노드가 하지 않는 것
##
## **전투 로직이 없습니다.** 상태 전이·피해·스케줄링은 `boss_system` 런타임 몫이고
## 여기서는 시각 표현만 합니다. 그래서 진행 중인 보스 런타임과 겹치지 않습니다.
##
## 노드 구조:
##   Sway (기본 대기 흔들림)
##     └ Pose (상태별 눌림·기울기)
##         ├ Body / LeftShoulderPivot / RightShoulderPivot
##         ├ LeftEye / RightEye / Face / Heart


## 아트 원본 대비 표시 배율. 1040×1240 을 520×620 으로 줄입니다.
const ART_SCALE: float = 0.5

## 보스 중심 기준 부위 좌표 (인게임 px). 아트에서 실측했다.
const LEFT_SHOULDER := Vector2(-109.2, -116.3)
const RIGHT_SHOULDER := Vector2(110.0, -122.1)
const HEART_CENTRE := Vector2(50.9, -61.4)
const EYE_LEFT := Vector2(-65.5, -193.1)
const EYE_RIGHT := Vector2(88.3, -216.9)
const MOUTH_CENTRE := Vector2(8.0, -150.0)

## 눌림·기울기의 축. 몸통이 바닥에 닿는 자리다.
## 중심에서 변형하면 인형이 아니라 배지처럼 논다.
const DEFORM_ORIGIN := Vector2(0.0, 190.0)

## 팔 각도 규약: **0 이 수직 아래, 양수가 바깥쪽.** 좌우 모두 양수를 쓴다.
## 화면 좌표는 아래가 +y 라 왼팔은 더하고 오른팔은 뺀다.
## 반대로 두면 팔이 안쪽으로 돌아 얼굴을 덮는다.
const ATTACK_ANGLE: float = 115.0
## 예고에서 팔이 눌리는 각도.
const TELEGRAPH_ANGLE: float = 4.0
## 이 각도를 넘으면 팔을 몸 앞으로 옮긴다. 뒤에 두면 머리에 가려 실루엣이 죽는다.
const FRONT_ANGLE: float = 90.0

## z 는 음수를 쓰지 않는다. 배경 노드보다 뒤로 가라앉아 통째로 사라진다.
## UNDER 는 팔보다도 아래다. 팔이 원본에서 몸통을 덮던 자리의 복원면이라
## 대기에서는 팔에 가려 보이지 않아야 한다.
const UNDER_Z: int = 0
const ARM_BACK_Z: int = 1
const BODY_Z: int = 2
const ARM_FRONT_Z: int = 3
const FACE_Z: int = 3
const HEART_Z: int = 4

const MOUTH_GAP := Color(0.031, 0.039, 0.055, 1.0)
const MOUTH_STITCH := Color(0.84, 0.80, 0.70, 0.95)
const MOUTH_INK := Color(0.055, 0.070, 0.098, 1.0)

## 상태별 자세. 기획서 9절 상태 표와 1:1 로 맞춘 값이다.
##
## arm: 팔 목표 각도(바깥 양수) / squash: 세로 배율 / widen: 가로 배율
## lean: 기울기(도) / offset: 추가 이동 / speed: 전환 속도(1/초)
const POSES := {
	# 상태 2. 기본 대기. 흔들림은 Sway 가 따로 얹는다.
	&"idle": {
		"arm_l": 0.0, "arm_r": 0.0, "squash": 1.0, "widen": 1.0,
		"lean": 0.0, "offset": Vector2.ZERO, "speed": 6.0,
		"expression": &"idle",
	},
	# 상태 3. 예고. "양팔이 바닥을 누르듯 짧게 압축, 몸 전체가 아래로 압축".
	# 팔은 벌리는 게 아니라 몸과 같이 **아래로 눌린다**.
	&"telegraph": {
		"arm_l": 4.0, "arm_r": 4.0, "squash": 0.90, "widen": 1.05,
		"lean": 0.0, "offset": Vector2(0.0, 10.0), "speed": 11.0,
		"expression": &"telegraph",
	},
	# 상태 4. 공격. 압축을 풀며 위로 뻗는다. 실루엣이 완전히 바뀐다.
	&"attack": {
		"arm_l": ATTACK_ANGLE, "arm_r": ATTACK_ANGLE, "squash": 1.05,
		"widen": 0.97, "lean": 0.0, "offset": Vector2(0.0, -8.0), "speed": 18.0,
		"expression": &"attack",
	},
	# 상태 5. 경직. "양팔이 힘없이 떨어짐". 축 처진 채 천천히 돌아온다.
	&"recovery": {
		"arm_l": -3.0, "arm_r": -2.0, "squash": 0.965, "widen": 1.02,
		"lean": 1.5, "offset": Vector2(0.0, 6.0), "speed": 3.2,
		"expression": &"recovery",
	},
	# 상태 7. 포효. "고개를 들어 포효". 몸을 세우고 위로 뻗는다.
	&"roar": {
		"arm_l": 8.0, "arm_r": 8.0, "squash": 1.06, "widen": 0.98,
		"lean": 0.0, "offset": Vector2(0.0, -10.0), "speed": 9.0,
		"expression": &"roar",
	},
}

## 표정. 가이드 4-2·4-3 이 좁게 못박아 둔 영역이다.
## 눈은 **빈 검은 구멍**만 허용되므로 구멍의 모양·기울기만 바꾼다.
## 눈알·흰자·발광을 넣으면 즉시 반려다.
const EXPRESSIONS := {
	&"idle": {"scale": Vector2(1.0, 1.0), "tilt": 0.0, "lift": 0.0, "mouth": 0.0},
	&"telegraph": {"scale": Vector2(1.06, 0.70), "tilt": 7.0, "lift": 3.0, "mouth": 0.0},
	&"attack": {"scale": Vector2(1.14, 1.16), "tilt": -3.0, "lift": -2.0, "mouth": 0.22},
	&"recovery": {"scale": Vector2(0.90, 0.78), "tilt": -6.0, "lift": 5.0, "mouth": 0.10},
	&"hit": {"scale": Vector2(1.02, 0.60), "tilt": 10.0, "lift": 2.0, "mouth": 0.18},
	&"hit_strong": {"scale": Vector2(1.18, 0.48), "tilt": 15.0, "lift": 4.0, "mouth": 0.45},
	&"roar": {"scale": Vector2(1.22, 1.26), "tilt": -4.0, "lift": -4.0, "mouth": 1.0},
}


@export var body_texture: Texture2D = null
## 팔이 원본에서 몸통을 덮던 자리의 복원면. 팔 뒤에 깔린다.
@export var body_under_texture: Texture2D = null
@export var arm_texture_left: Texture2D = null
@export var arm_texture_right: Texture2D = null
@export var heart_texture: Texture2D = null
@export var eye_texture_left: Texture2D = null
@export var eye_texture_right: Texture2D = null

@export_category("하트핵")
## 기본 상태의 약한 박동 (가이드 8절). 크게 하면 약점으로 오해받아 반려된다.
@export_range(0.2, 4.0, 0.1, "suffix:Hz") var heart_pulse_hz: float = 0.9
@export_range(0.0, 0.2, 0.005) var heart_pulse_amount: float = 0.035

@export_category("기본 대기 흔들림")
## 기획서 상태 2 "몸이 좌우로 불안정하게 흔들림".
## 폭을 키우면 가이드 20절 "과한 흔들림으로 공 경로 가림" 에 걸린다.
@export_range(0.0, 6.0, 0.1, "suffix:°") var sway_degrees: float = 1.6
@export_range(0.05, 1.5, 0.01, "suffix:Hz") var sway_hz: float = 0.34
@export_range(0.0, 20.0, 0.5, "suffix:px") var sway_slide: float = 3.5
@export_range(0.0, 0.06, 0.002) var breathe_amount: float = 0.012
@export_range(0.05, 2.0, 0.01, "suffix:Hz") var breathe_hz: float = 0.46
## 팔이 몸을 늦게 따라오는 정도. 천 인형 느낌의 핵심이다.
@export_range(0.0, 3.0, 0.05) var arm_lag_gain: float = 1.35
@export_range(0.5, 12.0, 0.1) var arm_lag_follow: float = 2.6


var _sway: Node2D = null
var _pose_node: Node2D = null
var _body: Sprite2D = null
var _heart: Sprite2D = null
var _pivot_left: Node2D = null
var _pivot_right: Node2D = null
var _eye_left: Node2D = null
var _eye_right: Node2D = null
var _face: BossFaceLayer = null

var _state: StringName = &"idle"
var _expression: StringName = &"idle"

# 목표 자세와 현재 자세. _process 가 지수 보간으로 따라간다.
var _target := {}
var _angle_left := 0.0
var _angle_right := 0.0
var _squash := 1.0
var _widen := 1.0
var _lean := 0.0
var _offset := Vector2.ZERO
var _speed := 6.0

# 피격 반동. 짧게 튀었다가 잦아드는 감쇠 진동이다.
var _jolt_time := -1.0
var _jolt_amp := 0.0
var _jolt_dir := 1.0

var _time := 0.0
var _wobble := 0.0
var _arm_follow := 0.0


func _ready() -> void:
	_build()


# --------------------------------------------------------------------------
# 구성
# --------------------------------------------------------------------------


func _build() -> void:
	if _body != null:
		return

	# 흔들림(Sway)과 상태 자세(Pose)를 분리한다. 한 노드에 섞으면
	# 대기 흔들림이 상태 전환값을 매 프레임 덮어써 서로 싸운다.
	_sway = Node2D.new()
	_sway.name = "Sway"
	add_child(_sway)

	_pose_node = Node2D.new()
	_pose_node.name = "Pose"
	_sway.add_child(_pose_node)

	if body_under_texture != null:
		var under := Sprite2D.new()
		under.name = "BodyUnder"
		under.texture = body_under_texture
		under.scale = Vector2.ONE * ART_SCALE
		under.z_index = UNDER_Z
		_pose_node.add_child(under)

	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = body_texture
	_body.scale = Vector2.ONE * ART_SCALE
	_body.z_index = BODY_Z
	_pose_node.add_child(_body)

	_pivot_left = Node2D.new()
	_pivot_left.name = "LeftShoulderPivot"
	_pivot_left.position = LEFT_SHOULDER
	_pose_node.add_child(_pivot_left)
	_pivot_left.add_child(
		_make_part_sprite(arm_texture_left, LEFT_SHOULDER, "ArmVisual")
	)

	_pivot_right = Node2D.new()
	_pivot_right.name = "RightShoulderPivot"
	_pivot_right.position = RIGHT_SHOULDER
	_pose_node.add_child(_pivot_right)
	_pivot_right.add_child(
		_make_part_sprite(arm_texture_right, RIGHT_SHOULDER, "ArmVisual")
	)

	_eye_left = _make_part(eye_texture_left, EYE_LEFT, "LeftEye")
	_eye_right = _make_part(eye_texture_right, EYE_RIGHT, "RightEye")
	_pose_node.add_child(_eye_left)
	_pose_node.add_child(_eye_right)

	_face = BossFaceLayer.new()
	_face.name = "Face"
	_face.z_index = FACE_Z
	_pose_node.add_child(_face)

	_heart = Sprite2D.new()
	_heart.name = "Heart"
	_heart.texture = heart_texture
	_heart.scale = Vector2.ONE * ART_SCALE
	_heart.z_index = HEART_Z
	_pose_node.add_child(_heart)

	play_state(&"idle", true)


func _make_part_sprite(texture: Texture2D, anchor: Vector2, name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = name
	sprite.texture = texture
	sprite.scale = Vector2.ONE * ART_SCALE
	# 여섯 장이 같은 캔버스라, 앵커만큼 되밀면 원래 자리에 겹친다.
	sprite.position = -anchor
	return sprite


func _make_part(texture: Texture2D, centre: Vector2, name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	holder.position = centre
	holder.z_index = FACE_Z
	holder.add_child(_make_part_sprite(texture, centre, "Sprite"))
	return holder


# --------------------------------------------------------------------------
# 상태
# --------------------------------------------------------------------------


## 상태 자세로 전환합니다. `instant` 면 보간 없이 바로 그 자세가 됩니다.
func play_state(name: StringName, instant: bool = false) -> void:
	_build()
	if not POSES.has(name):
		push_warning("모르는 상태: %s" % name)
		return
	_state = name
	_target = POSES[name]
	_speed = float(_target["speed"])
	set_expression(_target["expression"])
	if instant:
		_angle_left = float(_target["arm_l"])
		_angle_right = float(_target["arm_r"])
		_squash = float(_target["squash"])
		_widen = float(_target["widen"])
		_lean = float(_target["lean"])
		_offset = _target["offset"]
		_apply()


func play_idle(instant: bool = false) -> void:
	play_state(&"idle", instant)


func play_telegraph(instant: bool = false) -> void:
	play_state(&"telegraph", instant)


func play_attack(instant: bool = false) -> void:
	play_state(&"attack", instant)


func play_recovery(instant: bool = false) -> void:
	play_state(&"recovery", instant)


func play_roar(instant: bool = false) -> void:
	play_state(&"roar", instant)


## 상태 6. 일반 피격. 자세는 유지하고 몸이 짧게 찌그러졌다 돌아옵니다.
## `direction` 은 공이 온 쪽(-1 왼쪽, +1 오른쪽).
func play_hit(direction: float = 1.0) -> void:
	_build()
	_jolt_time = 0.0
	_jolt_amp = 0.055
	_jolt_dir = signf(direction) if direction != 0.0 else 1.0
	set_expression(&"hit")


## 상태 9. 강한 피격(정확한 반격). 일반보다 크게 비틀립니다.
func play_hit_strong(direction: float = 1.0) -> void:
	_build()
	_jolt_time = 0.0
	_jolt_amp = 0.11
	_jolt_dir = signf(direction) if direction != 0.0 else 1.0
	set_expression(&"hit_strong")


func get_state() -> StringName:
	return _state


func is_jolting() -> bool:
	return _jolt_time >= 0.0


## 0~1 진행도로 예고에서 공격까지 직접 몰 수 있습니다.
## 런타임이 `arm_active_sec` 0.22 초에 맞춰 밀면 됩니다. 보간을 건너뜁니다.
func set_attack_progress(t: float) -> void:
	_build()
	var k := clampf(t, 0.0, 1.0)
	# 가감속(smoothstep). 오버슛 곡선은 중간에서 이미 목표를 넘어 버려서
	# "진행도 0.5 = 예고와 공격 사이" 라는 계약이 깨진다 (2026-08-07).
	# 관성으로 딸려 가는 느낌은 대기 팔 지연(trail)이 이미 만든다.
	var eased := k * k * (3.0 - 2.0 * k)
	var telegraph: Dictionary = POSES[&"telegraph"]
	var attack: Dictionary = POSES[&"attack"]
	_angle_left = lerpf(float(telegraph["arm_l"]), float(attack["arm_l"]), eased)
	_angle_right = lerpf(float(telegraph["arm_r"]), float(attack["arm_r"]), eased)
	_squash = lerpf(float(telegraph["squash"]), float(attack["squash"]), k)
	_offset = (telegraph["offset"] as Vector2).lerp(attack["offset"], k)
	_state = &"attack" if k >= 1.0 else &"telegraph"
	_target = POSES[_state]
	_speed = float(_target["speed"])
	_apply()


func set_arm_angles(left_deg: float, right_deg: float) -> void:
	_build()
	_angle_left = left_deg
	_angle_right = right_deg
	_apply()


func get_arm_angles() -> Vector2:
	return Vector2(_angle_left, _angle_right)


func is_arm_raised() -> bool:
	return maxf(absf(_angle_left), absf(_angle_right)) >= FRONT_ANGLE


# --------------------------------------------------------------------------
# 표정
# --------------------------------------------------------------------------


func set_expression(name: StringName) -> void:
	_build()
	if not EXPRESSIONS.has(name):
		push_warning("모르는 표정: %s" % name)
		return
	_expression = name
	var e: Dictionary = EXPRESSIONS[name]
	var eye_scale: Vector2 = e["scale"]
	var tilt: float = e["tilt"]
	var lift: float = e["lift"]

	# 두 눈은 **서로 반대로** 기운다. 같은 방향이면 얼굴이 통째로 돌아간 것처럼
	# 보이고 표정이 안 읽힌다.
	_eye_left.scale = eye_scale
	_eye_left.rotation = deg_to_rad(-tilt)
	_eye_left.position = EYE_LEFT + Vector2(0.0, lift)
	_eye_right.scale = eye_scale
	_eye_right.rotation = deg_to_rad(tilt)
	_eye_right.position = EYE_RIGHT + Vector2(0.0, lift)

	_face.mouth_open = float(e["mouth"])
	_face.queue_redraw()


func get_expression() -> StringName:
	return _expression


func is_mouth_open() -> bool:
	return _face != null and _face.mouth_open > 0.0


# --------------------------------------------------------------------------
# 갱신
# --------------------------------------------------------------------------


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta

	_follow_target(delta)
	_update_jolt(delta)
	_update_idle_sway(delta)

	var pulse := 1.0 + heart_pulse_amount * sin(_time * TAU * heart_pulse_hz)
	_heart.scale = Vector2.ONE * ART_SCALE * pulse

	_apply()


## 목표 자세를 지수 보간으로 따라갑니다. 스냅이 "어색함" 의 첫 번째 원인이었다.
func _follow_target(delta: float) -> void:
	if _target.is_empty():
		return
	var k := clampf(delta * _speed, 0.0, 1.0)
	_angle_left = lerpf(_angle_left, float(_target["arm_l"]), k)
	_angle_right = lerpf(_angle_right, float(_target["arm_r"]), k)
	_squash = lerpf(_squash, float(_target["squash"]), k)
	_widen = lerpf(_widen, float(_target["widen"]), k)
	_lean = lerpf(_lean, float(_target["lean"]), k)
	_offset = _offset.lerp(_target["offset"], k)


## 피격 반동. 감쇠 진동으로 찌그러졌다 돌아옵니다 (기획서 상태 6·9).
func _update_jolt(delta: float) -> void:
	if _jolt_time < 0.0:
		return
	_jolt_time += delta
	if _jolt_time > 0.45:
		_jolt_time = -1.0
		if _target.has("expression"):
			set_expression(_target["expression"])


func _jolt_squash() -> float:
	if _jolt_time < 0.0:
		return 0.0
	# 눌렸다가 -> 살짝 부풀며 -> 잦아든다.
	return -_jolt_amp * exp(-_jolt_time * 9.0) * cos(_jolt_time * TAU * 3.2)


func _jolt_lean() -> float:
	if _jolt_time < 0.0:
		return 0.0
	return (
		_jolt_dir * _jolt_amp * 55.0 * exp(-_jolt_time * 7.0)
		* sin(_jolt_time * TAU * 2.6)
	)


## 기본 대기 흔들림 (기획서 상태 2). 상태 자세 위에 얹힌다.
func _update_idle_sway(delta: float) -> void:
	var t := _time * TAU
	# 주기가 안 맞는 사인 둘 = "불안정하게". 하나면 태엽처럼 규칙적이다.
	_wobble = sin(t * sway_hz) * 0.72 + sin(t * sway_hz * 1.63 + 1.1) * 0.28

	# 팔을 들었을 때는 흔들림을 죽인다. 공격 자세가 흔들리면 예고가 흐려진다.
	var damp := 0.25 if is_arm_raised() else 1.0
	var body_deg := sway_degrees * _wobble * damp

	_sway.rotation = deg_to_rad(body_deg)
	var pivot := DEFORM_ORIGIN
	_sway.position = (
		pivot - pivot.rotated(_sway.rotation)
		+ Vector2(sway_slide * _wobble * damp, 0.0)
	)

	var breathe := 1.0 + breathe_amount * sin(t * breathe_hz + 0.6)
	_body.scale = Vector2(ART_SCALE, ART_SCALE * breathe)

	# 팔은 몸을 **뒤늦게** 따라온다. 천 주머니가 매달린 느낌의 핵심.
	_arm_follow = lerpf(
		_arm_follow, body_deg, clampf(delta * arm_lag_follow, 0.0, 1.0)
	)


func get_arm_trail() -> float:
	return _arm_follow


## 현재 자세를 노드에 반영합니다.
func _apply() -> void:
	if _body == null:
		return

	var damp := 0.25 if is_arm_raised() else 1.0
	var body_deg := sway_degrees * _wobble * damp
	var trail := (body_deg - _arm_follow) * arm_lag_gain
	_pivot_left.rotation = deg_to_rad(_angle_left - trail)
	_pivot_right.rotation = deg_to_rad(-_angle_right - trail)

	var z := ARM_FRONT_Z if is_arm_raised() else ARM_BACK_Z
	_pivot_left.z_index = z
	_pivot_right.z_index = z

	# 몸 자세. 바닥을 축으로 눌리고 기운다.
	var squash := _squash + _jolt_squash()
	var widen := _widen - _jolt_squash() * 0.7
	var lean := deg_to_rad(_lean + _jolt_lean())
	var pivot := DEFORM_ORIGIN
	var c := cos(lean)
	var sn := sin(lean)
	var x_basis := Vector2(c, sn) * widen
	var y_basis := Vector2(-sn, c) * squash
	_pose_node.transform = Transform2D(
		x_basis, y_basis,
		pivot - x_basis * pivot.x - y_basis * pivot.y + _offset
	)


## 봉제된 입. 다물린 입은 아트에 있으므로 벌어질 때만 틈을 얹는다 (가이드 4-3).
class BossFaceLayer:
	extends Node2D

	var mouth_open := 0.0

	func _draw() -> void:
		if mouth_open <= 0.0:
			return
		var c := MOUTH_CENTRE
		# 얼굴 안에서 끝나야 한다. 크면 턱 아래 검은 삼각형이 된다.
		var half := 24.0 + 14.0 * mouth_open
		var drop := 8.0 + 40.0 * mouth_open
		var points := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var t := float(i) / float(steps)
			points.append(Vector2(
				c.x - half + half * 2.0 * t, c.y - 3.0 + sin(t * PI) * 2.0
			))
		# 아래는 둥근 렌즈꼴. 뾰족하면 이빨 입처럼 보인다.
		for i in steps + 1:
			var t := 1.0 - float(i) / float(steps)
			points.append(Vector2(
				c.x - half + half * 2.0 * t,
				c.y + pow(sin(t * PI), 0.72) * drop
			))
		draw_colored_polygon(points, MOUTH_GAP)
		draw_polyline(
			points + PackedVector2Array([points[0]]), MOUTH_INK, 3.0, true
		)

		var count := 5
		for i in count:
			var t := (float(i) + 0.5) / float(count)
			var x := c.x - half + half * 2.0 * t
			var y := c.y + pow(sin(t * PI), 0.72) * drop
			draw_line(
				Vector2(x - 4.0, y - 2.0), Vector2(x + 4.0, y + 6.0),
				MOUTH_STITCH, 2.2, true
			)
			draw_line(
				Vector2(x - 4.0, c.y - 8.0), Vector2(x + 4.0, c.y - 1.0),
				MOUTH_STITCH, 2.2, true
			)
