extends SceneTree
## 범퍼 아트 애니메이션 검증.
##
## 확인하는 것:
## - **범퍼 transform 을 건드리지 않는가** (물리 노드 불가침)
## - 눌렸다가 원래 크기로 돌아오는가
## - 북은 북막만 움직이고 북틀은 그대로인가 (기획서 34쪽)
## - 대포는 포획 동안 눌린 채 유지되는가 (5-7)
## - 파괴 상태에서 비활성 투명도가 적용되는가 (프로시저럴 Visual 을 끄며 잃은 것)
## - 규칙 수치가 기획서 의도와 맞는가
##
## 실행:
##   godot --headless --path . --script res://tests/bumper_system/bumper_art_animator_test.gd


const SPRING_SCENE := "res://scenes/bumper_system/vfx/spring_doll_bumper_vfx.tscn"
const DRUM_SCENE := "res://scenes/bumper_system/vfx/toy_drum_bumper_vfx.tscn"
const CANNON_SCENE := "res://scenes/bumper_system/vfx/clockwork_toy_cannon_vfx.tscn"
const COTTON_ANIM := preload("res://settings/bumpers/anim/CottonAnim.tres")
const SPRING_ANIM := preload("res://settings/bumpers/anim/SpringDollAnim.tres")
const DRUM_ANIM := preload("res://settings/bumpers/anim/ToyDrumAnim.tres")
const BUTTON_ANIM := preload("res://settings/bumpers/anim/ButtonAnim.tres")
const EPSILON := 0.001


var _failures: Array[String] = []
var _root: Node2D


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_root = Node2D.new()
	root.add_child(_root)
	await process_frame

	await _test_press_and_recover()
	await _test_drum_head_only()
	await _test_cannon_hold()
	await _test_destroyed_alpha()
	_test_rule_intent()

	_finish()


func _spawn(path: String) -> Bumper:
	var bumper := (load(path) as PackedScene).instantiate() as Bumper
	bumper.global_position = Vector2(400.0, 300.0)
	_root.add_child(bumper)
	await process_frame
	await process_frame
	return bumper


func _test_press_and_recover() -> void:
	var bumper: Bumper = await _spawn(SPRING_SCENE)
	var anim := bumper.get_node_or_null(^"_ArtAnimator") as BumperArtAnimator
	_expect(anim != null, "용수철 인형에 _ArtAnimator 가 있어야 한다")
	if anim == null:
		bumper.queue_free()
		return

	var sprite := anim.get_target_sprite()
	_expect(sprite != null, "애니메이터가 아트 스프라이트를 찾아야 한다")
	if sprite == null:
		bumper.queue_free()
		return

	var base_scale := sprite.scale
	var bumper_position := bumper.global_position
	var bumper_rotation := bumper.global_rotation
	var bumper_scale := bumper.scale

	anim.press(Vector2.DOWN)
	await process_frame
	await process_frame
	_expect(sprite.scale.x < base_scale.x,
		"타격 직후 아트가 눌려 작아져야 한다 (기준=%s, 실제=%s)"
			% [base_scale.x, sprite.scale.x])

	# 물리 노드는 어떤 경우에도 그대로여야 한다.
	_expect(bumper.global_position.is_equal_approx(bumper_position),
		"애니메이션이 범퍼 위치를 건드리면 안 된다")
	_expect(absf(bumper.global_rotation - bumper_rotation) <= EPSILON,
		"애니메이션이 범퍼 회전을 건드리면 안 된다")
	_expect(bumper.scale.is_equal_approx(bumper_scale),
		"애니메이션이 범퍼 크기를 건드리면 안 된다")

	# 눌림 + 복귀 시간을 넘기면 원래대로 돌아와야 한다.
	var total := SPRING_ANIM.press_seconds + SPRING_ANIM.release_seconds
	var waited := 0.0
	while waited < total + 0.1:
		await process_frame
		waited += root.get_process_delta_time()
	_expect(not anim.is_pressing(), "눌림이 끝나면 진행 상태가 꺼져야 한다")
	_expect(sprite.scale.is_equal_approx(base_scale),
		"복귀 후 원래 크기로 돌아와야 한다 (기준=%s, 실제=%s)"
			% [base_scale, sprite.scale])
	_expect(sprite.position.is_equal_approx(Vector2.ZERO),
		"복귀 후 위치 오프셋이 남으면 안 된다 (실제=%s)" % sprite.position)

	bumper.queue_free()
	await process_frame


func _test_drum_head_only() -> void:
	var bumper: Bumper = await _spawn(DRUM_SCENE)
	var anim := bumper.get_node_or_null(^"_ArtAnimator") as BumperArtAnimator
	var head := bumper.get_node_or_null(^"_ArtSpriteHead") as Sprite2D
	var frame := bumper.get_node_or_null(^"_ArtSpriteFrame") as Sprite2D
	_expect(anim != null and head != null and frame != null,
		"북에 애니메이터와 두 레이어가 있어야 한다")
	if anim == null or head == null or frame == null:
		bumper.queue_free()
		return

	_expect(anim.get_target_sprite() == head,
		"북은 북막만 움직여야 한다 (34쪽). 애니메이터 대상이 _ArtSpriteHead 여야 한다")

	var frame_scale := frame.scale
	var frame_position := frame.position
	anim.press(Vector2.DOWN)
	await process_frame
	await process_frame
	_expect(head.scale.x < frame_scale.x, "북막이 눌려야 한다")
	_expect(frame.scale.is_equal_approx(frame_scale),
		"북틀 크기는 그대로여야 한다 (34쪽 외곽 북틀은 크게 움직이지 않는다)")
	_expect(frame.position.is_equal_approx(frame_position),
		"북틀 위치는 그대로여야 한다")

	bumper.queue_free()
	await process_frame


func _test_cannon_hold() -> void:
	var bumper: Bumper = await _spawn(CANNON_SCENE)
	var anim := bumper.get_node_or_null(^"_ArtAnimator") as BumperArtAnimator
	var shot := bumper as ShotBumper
	_expect(anim != null and shot != null, "대포에 애니메이터가 있어야 한다")
	if anim == null or shot == null:
		bumper.queue_free()
		return

	var sprite := anim.get_target_sprite()
	var base_scale := sprite.scale

	shot.control_started.emit(shot, null)
	await process_frame
	await process_frame
	_expect(anim.is_holding(), "포획 중에는 눌림이 유지돼야 한다")
	_expect(sprite.scale.x < base_scale.x, "포획 중에는 받침대가 눌려 있어야 한다")

	# 유지 상태는 시간이 지나도 풀리지 않아야 한다.
	var waited := 0.0
	while waited < 0.4:
		await process_frame
		waited += root.get_process_delta_time()
	_expect(sprite.scale.x < base_scale.x,
		"포획이 끝나기 전에는 눌림이 저절로 풀리면 안 된다")

	shot.control_ended.emit(shot, null)
	await process_frame
	_expect(not anim.is_holding(), "발사하면 유지가 풀려야 한다")

	bumper.queue_free()
	await process_frame


func _test_destroyed_alpha() -> void:
	var bumper: Bumper = await _spawn(SPRING_SCENE)
	var anim := bumper.get_node_or_null(^"_ArtAnimator") as BumperArtAnimator
	if anim == null:
		bumper.queue_free()
		return
	var sprite := anim.get_target_sprite()

	bumper.state_changed.emit(
		Bumper.BumperState.ACTIVE, Bumper.BumperState.DESTROYED_TIMER
	)
	await process_frame
	await process_frame
	_expect(absf(sprite.modulate.a - SPRING_ANIM.destroyed_alpha) <= 0.01,
		"파괴 상태에서 비활성 투명도가 적용돼야 한다 (기대=%s, 실제=%s)"
			% [SPRING_ANIM.destroyed_alpha, sprite.modulate.a])

	bumper.state_changed.emit(
		Bumper.BumperState.DESTROYED_TIMER, Bumper.BumperState.ACTIVE
	)
	await process_frame
	await process_frame
	_expect(absf(sprite.modulate.a - 1.0) <= 0.01,
		"복귀하면 투명도가 원래대로 돌아와야 한다")

	bumper.queue_free()
	await process_frame


func _test_rule_intent() -> void:
	# 5-3 인형은 "빠르게 튕겨오름", 5-1 단추는 "얕은 눌림".
	_expect(SPRING_ANIM.press_depth > BUTTON_ANIM.press_depth,
		"용수철 인형이 단추보다 깊게 눌려야 한다")
	_expect(SPRING_ANIM.overshoot > BUTTON_ANIM.overshoot,
		"용수철 인형이 단추보다 크게 튕겨올라야 한다")

	# 5-4 북은 "크게 팽창" 이라 오버슛이 가장 커야 한다.
	_expect(DRUM_ANIM.overshoot >= SPRING_ANIM.overshoot,
		"북 팽창이 용수철 인형 오버슛보다 작으면 안 된다 (북=%s, 인형=%s)"
			% [DRUM_ANIM.overshoot, SPRING_ANIM.overshoot])

	# 5-2 솜은 흔들림이 주연출이고 튕기지 않는다(속도를 흡수한다).
	_expect(COTTON_ANIM.shake_amplitude_ratio > 0.0,
		"솜은 흔들림이 있어야 한다")
	_expect(is_equal_approx(COTTON_ANIM.overshoot, 0.0),
		"솜은 튕겨오르면 안 된다 (속도를 흡수하는 완충 오브젝트)")
	_expect(SPRING_ANIM.shake_amplitude_ratio <= 0.0,
		"용수철 인형은 흔들림이 아니라 튕김이 주연출이다")

	# 3-2: 복구 예고는 "아주 약한 떨림" 이다.
	for rules in [BUTTON_ANIM, COTTON_ANIM, SPRING_ANIM, DRUM_ANIM]:
		_expect(rules.telegraph_amplitude_ratio <= 0.03,
			"복구 예고 떨림이 과하면 안 된다 (실제=%s)"
				% rules.telegraph_amplitude_ratio)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_art_animator_test")
		quit(0)
		return
	print("FAIL: bumper_art_animator_test (%d failures)" % _failures.size())
	quit(1)
