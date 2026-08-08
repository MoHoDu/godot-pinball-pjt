class_name BumperArtAnimator
extends Node
## 범퍼 아트 스프라이트의 타격·상태 애니메이션입니다.
##
## 시그널만 구독하고 **아트 스프라이트만** 움직입니다.
## 물리 노드(`Bumper`)의 위치·회전·크기는 절대 건드리지 않습니다.
## `FlipperParryFeedback` 이 플리퍼 스프라이트의 modulate 를 만지는 것과 같은 선례입니다.
##
## 대상은 자동으로 찾습니다.
## - `_ArtSpriteHead` 가 있으면 그것만 움직입니다 (북: 북막만 변형, 34쪽)
## - 없으면 `_ArtSprite` 를 움직입니다
##
## Tween 대신 `_process` 에서 직접 계산합니다. 재타격이 겹칠 때 상태가 명확하고
## 헤드리스 테스트에서 진행도를 그대로 확인할 수 있습니다.


const HEAD_SPRITE := ^"_ArtSpriteHead"
const SINGLE_SPRITE := ^"_ArtSprite"


@export var rules: BumperAnimRules = null

## 비워 두면 위 두 이름에서 자동으로 찾습니다.
@export var target_path: NodePath = ^""


var _bumper: Bumper = null
var _sprite: Sprite2D = null
var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _base_texture: Texture2D = null

var _press_elapsed := -1.0
var _press_normal := Vector2.UP
var _hold_pressed := false
var _telegraph := false
var _destroyed := false


func _ready() -> void:
	if rules == null:
		rules = BumperAnimRules.new()

	var parent := get_parent()
	if parent is Bumper:
		bind_to_bumper(parent as Bumper)


func bind_to_bumper(bumper: Bumper) -> void:
	if _bumper == bumper:
		return

	if is_instance_valid(_bumper):
		if _bumper.valid_hit_registered.is_connected(_on_valid_hit_registered):
			_bumper.valid_hit_registered.disconnect(_on_valid_hit_registered)
		if _bumper.state_changed.is_connected(_on_state_changed):
			_bumper.state_changed.disconnect(_on_state_changed)

	_bumper = bumper
	if not is_instance_valid(_bumper):
		return

	_bumper.valid_hit_registered.connect(_on_valid_hit_registered)
	_bumper.state_changed.connect(_on_state_changed)

	if _bumper is ShotBumper:
		var shot := _bumper as ShotBumper
		# 5-7: 포획 동안 받침대가 눌린 채 유지되고, 발사 때 짧은 반동이 온다.
		shot.control_started.connect(_on_control_started)
		shot.control_ended.connect(_on_control_ended)

	_resolve_sprite()


func _resolve_sprite() -> void:
	if not is_instance_valid(_bumper):
		return
	if not target_path.is_empty():
		_sprite = _bumper.get_node_or_null(target_path) as Sprite2D
	if _sprite == null:
		_sprite = _bumper.get_node_or_null(HEAD_SPRITE) as Sprite2D
	if _sprite == null:
		_sprite = _bumper.get_node_or_null(SINGLE_SPRITE) as Sprite2D
	if _sprite != null:
		_base_scale = _sprite.scale
		_base_position = _sprite.position
		_base_texture = _sprite.texture


func get_target_sprite() -> Sprite2D:
	return _sprite


# --------------------------------------------------------------------------
# 시그널
# --------------------------------------------------------------------------


func _on_valid_hit_registered(
	_bumper_id: StringName,
	ball: RigidBody2D,
	_contact_id: int,
	_base_score: int
) -> void:
	if not is_instance_valid(ball) or not is_instance_valid(_bumper):
		return
	var offset := ball.global_position - _bumper.global_position
	press(offset.normalized() if offset.length_squared() > 0.0 else Vector2.UP)


func _on_state_changed(
	_previous: Bumper.BumperState,
	current: Bumper.BumperState
) -> void:
	match current:
		Bumper.BumperState.DESTROYED_TIMER:
			_destroyed = true
			_telegraph = false
			_hold_pressed = false
		Bumper.BumperState.RESPAWN_TELEGRAPH:
			_telegraph = true
		Bumper.BumperState.ACTIVE:
			_destroyed = false
			_telegraph = false


func _on_control_started(_source: ShotBumper, _ball: RigidBody2D) -> void:
	_hold_pressed = true


func _on_control_ended(_source: ShotBumper, _ball: RigidBody2D) -> void:
	_hold_pressed = false
	# 발사 반동은 포신 반대쪽으로 밀린다.
	var direction := Vector2.UP
	if _bumper is ShotBumper:
		var launch := (_bumper as ShotBumper).get_selected_launch_direction()
		if launch.length_squared() > 0.0:
			direction = -launch.normalized()
	press(direction)


## 접촉 법선 방향으로 눌렀다가 복귀합니다.
func press(normal: Vector2) -> void:
	if normal.length_squared() > 0.0:
		_press_normal = normal.normalized()
	_press_elapsed = 0.0


func is_pressing() -> bool:
	return _press_elapsed >= 0.0


func is_holding() -> bool:
	return _hold_pressed


func is_telegraphing() -> bool:
	return _telegraph


func is_destroyed_state() -> bool:
	return _destroyed


# --------------------------------------------------------------------------
# 갱신
# --------------------------------------------------------------------------


func _process(delta: float) -> void:
	if _sprite == null:
		_resolve_sprite()
		if _sprite == null:
			return
	if rules == null:
		return

	var radius := _visual_radius()
	var scale_factor := 1.0
	var offset := Vector2.ZERO

	if _press_elapsed >= 0.0:
		_press_elapsed += delta
		var total := rules.press_seconds + rules.release_seconds
		if _press_elapsed >= total:
			_press_elapsed = -1.0
		else:
			var amount := _press_curve(_press_elapsed)
			scale_factor += amount
			# amount 가 음수(눌림)일 때만 법선 방향으로 밀려 들어간다.
			if amount < 0.0:
				var press_ratio := -amount / maxf(rules.press_depth, 0.0001)
				offset += (
					_press_normal * radius * rules.press_offset_ratio * press_ratio
				)

	if _hold_pressed:
		scale_factor -= rules.press_depth
		offset += _press_normal * radius * rules.press_offset_ratio

	if rules.shake_amplitude_ratio > 0.0 and _press_elapsed >= 0.0:
		var decay := 1.0 - clampf(
			_press_elapsed / (rules.press_seconds + rules.release_seconds), 0.0, 1.0
		)
		var wave := sin(_press_elapsed * TAU * rules.shake_hz)
		# 흔들림은 접촉 법선의 수직 방향으로. 눌림과 축이 겹치지 않게 한다.
		offset += (
			_press_normal.orthogonal() * radius
			* rules.shake_amplitude_ratio * wave * decay
		)

	if _telegraph:
		var shiver := sin(
			float(Time.get_ticks_msec()) * 0.001 * TAU * rules.telegraph_hz
		)
		scale_factor += rules.telegraph_amplitude_ratio * shiver

	_sprite.scale = _base_scale * maxf(scale_factor, 0.05)
	_sprite.position = _base_position + offset

	_apply_frame()

	var alpha := rules.destroyed_alpha if _destroyed else 1.0
	var color := _sprite.modulate
	if not is_equal_approx(color.a, alpha):
		color.a = alpha
		_sprite.modulate = color


## 눌림 구간 초반에만 타격 프레임을 보여 줍니다 (33쪽 형태 변화로 Bounce 전달).
func _apply_frame() -> void:
	if rules.hit_texture == null or _base_texture == null:
		return
	var want_hit := false
	if _hold_pressed:
		want_hit = true
	elif _press_elapsed >= 0.0:
		var total := rules.press_seconds + rules.release_seconds
		# 비율과 최소 노출 시간 중 **긴 쪽**을 쓴다. 눌림이 짧아도 프레임이 보인다.
		var window: float = maxf(
			total * rules.hit_frame_window, rules.hit_frame_min_seconds
		)
		want_hit = _press_elapsed <= window
	var wanted: Texture2D = rules.hit_texture if want_hit else _base_texture
	if _sprite.texture != wanted:
		_sprite.texture = wanted


func is_showing_hit_frame() -> bool:
	return (
		rules != null
		and rules.hit_texture != null
		and _sprite != null
		and _sprite.texture == rules.hit_texture
	)


## 눌림 -> 복귀 곡선. 음수가 눌림, 양수가 오버슛입니다.
func _press_curve(elapsed: float) -> float:
	if elapsed < rules.press_seconds:
		var t := elapsed / rules.press_seconds
		return -rules.press_depth * t
	var t2 := (elapsed - rules.press_seconds) / rules.release_seconds
	t2 = clampf(t2, 0.0, 1.0)
	# 눌린 깊이에서 출발해 오버슛을 지나 0 으로 잦아든다.
	var swing := lerpf(-rules.press_depth, rules.overshoot, minf(t2 * 2.0, 1.0))
	return swing * (1.0 - t2)


func _visual_radius() -> float:
	if is_instance_valid(_bumper) and _bumper.settings != null:
		return _bumper.settings.visual_diameter * 0.5
	return 46.0
