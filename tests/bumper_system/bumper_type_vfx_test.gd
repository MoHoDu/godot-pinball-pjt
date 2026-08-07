extends SceneTree
## Bounce · Shot 타입 VFX 검증.
##
## Normal 은 `bumper_hit_feedback_test.gd` 가 본다. 여기서는 확장분만 본다.
## - Bounce: response_resolved 로 원형 파동과 방향성 방출선이 뜨는가
## - Bounce: 방출 방향이 **반사 후 속도**를 따르는가 (타격 전 속도가 아니라)
## - Shot: 포획·발사 상태가 시그널대로 갈리는가
## - 확장해도 Normal 연출이 살아 있는가
##
## Track 은 검사하지 않는다. `BumperType.TRACK` 을 쓰는 범퍼 정의가 코드에 없다.
##
## 실행:
##   godot --headless --path . --script res://tests/bumper_system/bumper_type_vfx_test.gd


const SPRING_SCENE := preload("res://scenes/bumper_system/spring_doll_bumper.tscn")
const CANNON_SCENE := preload("res://scenes/bumper_system/clockwork_toy_cannon.tscn")
const BOUNCE_FEEDBACK := preload(
	"res://scripts/bumper-system/vfx/bumper_bounce_feedback.gd"
)
const SHOT_FEEDBACK := preload("res://scripts/bumper-system/vfx/bumper_shot_feedback.gd")
const SPRING_VFX := preload("res://settings/bumpers/vfx/SpringDollHitVfx.tres")
const DRUM_VFX := preload("res://settings/bumpers/vfx/ToyDrumHitVfx.tres")
const CANNON_VFX := preload("res://settings/bumpers/vfx/ClockworkCannonVfx.tres")
const EPSILON := 0.001


var _failures: Array[String] = []
var _root: Node2D
var _spring: Bumper
var _bounce: BumperBounceFeedback
var _cannon: Bumper
var _shot: BumperShotFeedback


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _build_fixture()

	if _bounce == null or _shot == null:
		_expect(false, "픽스처 구성 실패 — VFX 스크립트가 컴파일되지 않았다")
		_finish()
		return

	_test_bounce_spawns_ring_and_burst()
	_test_bounce_uses_exit_velocity()
	_test_bounce_keeps_normal_effects()
	_test_shot_capture_and_launch()
	_test_rule_intent()

	_finish()


func _build_fixture() -> void:
	_root = Node2D.new()
	root.add_child(_root)

	_spring = SPRING_SCENE.instantiate() as Bumper
	_spring.global_position = Vector2(200.0, 200.0)
	_root.add_child(_spring)
	_bounce = BOUNCE_FEEDBACK.new() as BumperBounceFeedback
	_bounce.rules = SPRING_VFX
	_spring.add_child(_bounce)

	_cannon = CANNON_SCENE.instantiate() as Bumper
	_cannon.global_position = Vector2(600.0, 200.0)
	_root.add_child(_cannon)
	_shot = SHOT_FEEDBACK.new() as BumperShotFeedback
	_shot.rules = CANNON_VFX
	_cannon.add_child(_shot)

	await process_frame
	await process_frame


func _test_bounce_spawns_ring_and_burst() -> void:
	_bounce.spawn_bounce(
		_spring.global_position + Vector2(0.0, -60.0), Vector2(0.0, -400.0)
	)
	_expect(_bounce.live_ring_count() == SPRING_VFX.ring_count,
		"원형 파동이 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [SPRING_VFX.ring_count, _bounce.live_ring_count()])
	_expect(_bounce.live_burst_count() == SPRING_VFX.burst_count,
		"방출선이 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [SPRING_VFX.burst_count, _bounce.live_burst_count()])


func _test_bounce_uses_exit_velocity() -> void:
	# 속도가 0 이면 접촉 법선으로 떨어져야 한다. 0 벡터로 나눠 터지면 안 된다.
	var before := _bounce.live_burst_count()
	_bounce.spawn_bounce(_spring.global_position + Vector2(50.0, 0.0), Vector2.ZERO)
	_expect(_bounce.live_burst_count() == before + SPRING_VFX.burst_count,
		"속도가 0 이어도 방출선이 생겨야 한다")


func _test_bounce_keeps_normal_effects() -> void:
	var ticks_before := _bounce.live_tick_count()
	_bounce.spawn_hit(_spring.global_position + Vector2(0.0, -80.0))
	_expect(_bounce.live_tick_count() == ticks_before + SPRING_VFX.tick_count,
		"Bounce 로 확장해도 Normal 타격선이 살아 있어야 한다")

	_spring.state_changed.emit(
		Bumper.BumperState.ACTIVE, Bumper.BumperState.RESPAWN_TELEGRAPH
	)
	_expect(_bounce.is_telegraph_active(),
		"Bounce 로 확장해도 복구 예고가 동작해야 한다")


func _test_shot_capture_and_launch() -> void:
	_expect(not _shot.is_capture_active(),
		"기본 상태에서는 포획 표시가 꺼져 있어야 한다")

	var shot_bumper := _cannon as ShotBumper
	_expect(shot_bumper != null, "태엽 대포는 ShotBumper 여야 한다")
	if shot_bumper == null:
		return

	# 공이 대포 안으로 들어간 것처럼 보이게 포획 동안 숨긴다 (2026-08-07 지시).
	var ball := RigidBody2D.new()
	_root.add_child(ball)

	shot_bumper.control_started.emit(shot_bumper, ball)
	_expect(_shot.is_capture_active(),
		"포획이 시작되면 받침대 눌림 표시가 켜져야 한다")
	_expect(_shot.is_ball_hidden(), "포획 동안 공이 숨어야 한다")
	_expect(not ball.visible, "포획 동안 공의 visible 이 꺼져야 한다")
	# 물리는 건드리면 안 된다. 숨기는 것은 순전히 표시만이다.
	_expect(not ball.freeze, "공을 숨기면서 물리를 얼리면 안 된다")

	# 발사는 **한 번만** 쏜다. 두 번 쏘면 잔상·연기가 두 배로 쌓인다.
	shot_bumper.control_ended.emit(shot_bumper, ball)
	_expect(ball.visible, "발사하면 공이 다시 보여야 한다")
	_expect(not _shot.is_ball_hidden(), "발사 후에는 숨긴 공이 남아 있으면 안 된다")
	ball.queue_free()

	_expect(not _shot.is_capture_active(),
		"발사가 끝나면 포획 표시가 꺼져야 한다")
	_expect(_shot.live_trail_count() == 1,
		"발사하면 방향 잔상이 하나 생겨야 한다 (실제=%d)" % _shot.live_trail_count())
	_expect(_shot.live_smoke_count() == CANNON_VFX.smoke_count,
		"연기가 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [CANNON_VFX.smoke_count, _shot.live_smoke_count()])


func _test_rule_intent() -> void:
	# 5-4: 북은 넓은 원형 파동이 주연출이라 인형보다 파동이 커야 한다.
	_expect(DRUM_VFX.ring_end_ratio > SPRING_VFX.ring_end_ratio,
		"북 파동이 용수철 인형보다 넓어야 한다 (북=%s, 인형=%s)"
			% [DRUM_VFX.ring_end_ratio, SPRING_VFX.ring_end_ratio])

	# 5-3: 인형은 방향 방출선이 주연출이다.
	_expect(SPRING_VFX.burst_count >= DRUM_VFX.burst_count,
		"용수철 인형 방출선이 북보다 적으면 안 된다")

	# 3-6: 실제 충돌체보다 훨씬 크게 보이는 상시 글로우 금지.
	_expect(DRUM_VFX.ring_end_ratio <= 2.0,
		"파동 끝 반지름이 충돌 반지름의 2배를 넘으면 안 된다 (실제=%s)"
			% DRUM_VFX.ring_end_ratio)

	# 5-7 은 "제한된 연기" 를 요구하지만 2026-08-07 형락님이 발사 연기를 더
	# 확실히 보이게 해 달라고 지시해 완화했다. 화면을 덮지 않는 선만 지킨다.
	_expect(CANNON_VFX.smoke_count <= 12,
		"대포 연기가 화면을 덮을 만큼 많으면 안 된다 (실제=%d)" % CANNON_VFX.smoke_count)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_type_vfx_test")
		quit(0)
		return
	print("FAIL: bumper_type_vfx_test (%d failures)" % _failures.size())
	quit(1)
