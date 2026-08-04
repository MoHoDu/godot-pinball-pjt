extends "res://tests/flipper_system/test_flipper_board.gd"
## test_flipper_board 복제 씬의 컨트롤러입니다 (VFX ③ 패링 파동 검수용).
##
## 기존 컨트롤러는 **고치지 않고 상속만** 합니다. 원본 보드 테스트는 그대로 남습니다.
##
## ── 조작키 (원본에 더한 것) ──────────────────────────
##
##   P   현재 공 위치에서 파동을 수동으로 한 번 재생
##   O   "칠 때마다" 모드 켜기/끄기
##
## ── ★ 이 씬은 칠 때마다 파동이 나옵니다 ─────────────
##
## 실제 게임 규칙은 **정확한 패링(PERFECT)에만** 입니다. 그건 BallParryWave 안에 있고
## 안 건드립니다. 다만 검수할 때 PERFECT 를 매번 성공시키기 어려워서
## **이 테스트 씬에서만** 플리퍼로 칠 때마다 띄웁니다.
##
## 그래서 씬의 _ParryWave 는 auto_bind_parry 가 꺼져 있고, 대신 이 컨트롤러가
## 플리퍼의 rotation_sweep_resolved(등급과 무관하게 모든 타격에 발생)를 받습니다.
##
## play_on_every_hit 을 끄면 원래 규칙(PERFECT 에만)으로 돌아갑니다.


const PARRY_WAVE_PATH: NodePath = ^"_ParryWave"

## 모든 타격에 발생하는 시그널입니다. parry_resolved 는 등급이 NONE 이면 안 옵니다.
const ANY_HIT_SIGNAL: StringName = &"rotation_sweep_resolved"
const PARRY_SIGNAL: StringName = &"parry_resolved"

## 정지한 공에서 P를 눌렀을 때 쓸 기본 방향입니다. 위쪽으로 날아간 것처럼 봅니다.
const IDLE_HIT_ANGLE: float = -PI * 0.5


## 켜면 플리퍼로 칠 때마다 파동이 납니다(검수용).
## 끄면 실제 게임 규칙대로 정확한 패링에만 납니다.
@export var play_on_every_hit: bool = true


@onready var parry_wave: BallParryWave = get_node_or_null(
	PARRY_WAVE_PATH
) as BallParryWave


var _bound: Array[Node] = []
## 한 물리 프레임에 플리퍼 여러 개가 같은 공을 처리해도 파동은 한 번만 띄웁니다.
var _last_played_frame: int = -1


func _ready() -> void:
	super()

	if not is_instance_valid(parry_wave):
		push_warning("_ParryWave 노드를 찾지 못했습니다. 파동 검수를 할 수 없습니다.")
		return

	_bind_all(get_tree().current_scene)
	_report_mode()


func _unhandled_input(event: InputEvent) -> void:
	super(event)

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode == KEY_P:
		play_parry_wave()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_O:
		toggle_every_hit()
		get_viewport().set_input_as_handled()


## 공 위치에서 파동을 한 번 터뜨립니다. 슬롯 인덱스를 돌려주고, 못 만들면 -1입니다.
func play_parry_wave() -> int:
	if not is_instance_valid(parry_wave) or not is_instance_valid(ball):
		return -1

	var angle := IDLE_HIT_ANGLE

	if ball.linear_velocity.length() > 1.0:
		angle = ball.linear_velocity.angle()

	return parry_wave.play_at(ball.global_position, ball.ball_diameter * 0.5, angle)


## "칠 때마다" 모드를 켜고 끕니다. 연결을 다시 잡습니다.
func toggle_every_hit() -> bool:
	play_on_every_hit = not play_on_every_hit
	_rebind()
	_report_mode()
	return play_on_every_hit


func _rebind() -> void:
	for node in _bound:
		if not is_instance_valid(node):
			continue

		if node.is_connected(ANY_HIT_SIGNAL, _on_any_hit):
			node.disconnect(ANY_HIT_SIGNAL, _on_any_hit)

	_bound.clear()
	_bind_all(get_tree().current_scene)


func _bind_all(node: Node) -> void:
	if node == null:
		return

	if play_on_every_hit:
		# 검수 모드: 등급과 무관하게 모든 타격
		if node.has_signal(ANY_HIT_SIGNAL) and not node.is_connected(
			ANY_HIT_SIGNAL, _on_any_hit
		):
			node.connect(ANY_HIT_SIGNAL, _on_any_hit)
			_bound.append(node)
	else:
		# 실제 게임 규칙: 정확한 패링에만. 파동 노드가 직접 거른다
		if node.has_signal(PARRY_SIGNAL):
			parry_wave.bind_to_flipper(node)

	for child in node.get_children():
		_bind_all(child)


func _on_any_hit(hit_ball: RigidBody2D) -> void:
	if not is_instance_valid(parry_wave) or not is_instance_valid(hit_ball):
		return

	var frame := Engine.get_physics_frames()

	if frame == _last_played_frame:
		return

	_last_played_frame = frame

	var radius := 22.0
	var diameter: Variant = hit_ball.get(&"ball_diameter")

	if diameter != null:
		radius = maxf(float(diameter), 1.0) * 0.5

	var angle := IDLE_HIT_ANGLE

	if hit_ball.linear_velocity.length() > 1.0:
		angle = hit_ball.linear_velocity.angle()

	parry_wave.play_at(hit_ball.global_position, radius, angle)


func _report_mode() -> void:
	var mode := "칠 때마다" if play_on_every_hit else "정확한 패링에만"
	print("[파동 검수] 모드: %s / 연결 %d개" % [mode, _bound.size()])


func _refresh_hud() -> void:
	super()

	if not is_instance_valid(guide_label):
		return

	var mode := "칠 때마다" if play_on_every_hit else "정확한 패링에만"
	guide_label.text += "\nP: 파동 수동 재생   O: 발생 조건 전환 (현재 %s)" % mode
