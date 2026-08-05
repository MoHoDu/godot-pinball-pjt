extends SceneTree
## 범퍼 타격 VFX(Normal) 검증.
##
## 확인하는 것:
## - 접촉 지점 유도가 충돌 원 위에 떨어지는가 (시그널이 위치를 안 주므로 유도한다)
## - 시그널이 각각 맞는 연출을 띄우는가
## - 내구도 최초 통지를 감소로 오인하지 않는가
## - **범퍼의 위치·회전·크기를 건드리지 않는가** (FlipperParryFeedback 규칙)
## - z 가 공 아래(타격) / 공 위(파편)로 갈리는가
##
## 실행:
##   godot --headless --path . --script res://tests/bumper_system/bumper_hit_feedback_test.gd


const BUTTON_SCENE := preload("res://scenes/bumper_system/button_bumper.tscn")
const FEEDBACK_SCRIPT := preload("res://scripts/bumper-system/vfx/bumper_hit_feedback.gd")
const BUTTON_VFX := preload("res://settings/bumpers/vfx/ButtonHitVfx.tres")
const COTTON_VFX := preload("res://settings/bumpers/vfx/CottonHitVfx.tres")
const EPSILON := 0.001


var _failures: Array[String] = []
var _root: Node2D
var _bumper: Bumper
var _feedback: BumperHitFeedback


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _build_fixture()

	# 스크립트 파스 에러가 나면 아래 검사가 통째로 건너뛰어져 거짓 PASS 가 난다.
	if _feedback == null or _bumper == null:
		_expect(false, "픽스처 구성 실패 — VFX 스크립트가 컴파일되지 않았다")
		_finish()
		return

	_test_contact_derivation()
	_test_hit_spawns_ticks_and_chips()
	_test_durability_first_notice_is_ignored()
	_test_state_transitions()
	_test_bumper_transform_untouched()
	_test_layer_order()
	_test_rules_are_clamped()

	_finish()


func _build_fixture() -> void:
	_root = Node2D.new()
	root.add_child(_root)

	_bumper = BUTTON_SCENE.instantiate() as Bumper
	_bumper.global_position = Vector2(400.0, 300.0)
	_root.add_child(_bumper)

	_feedback = FEEDBACK_SCRIPT.new() as BumperHitFeedback
	_feedback.rules = BUTTON_VFX
	_bumper.add_child(_feedback)

	await process_frame
	await process_frame


func _test_contact_derivation() -> void:
	var radius := _bumper.get_collision_radius()
	_expect(radius > 0.0, "범퍼 충돌 반지름이 0보다 커야 한다")

	var ball_right := _bumper.global_position + Vector2(500.0, 0.0)
	var contact := _feedback.contact_point_for(ball_right)
	var distance := contact.distance_to(_bumper.global_position)
	_expect(absf(distance - radius) <= EPSILON,
		"접촉 지점이 충돌 원 위에 있어야 한다 (기대=%s, 실제=%s)" % [radius, distance])

	var normal := _feedback.contact_normal_for(ball_right)
	_expect(normal.is_equal_approx(Vector2.RIGHT),
		"공이 오른쪽에 있으면 접촉 법선이 오른쪽이어야 한다 (실제=%s)" % normal)

	# 공이 정확히 중심에 겹쳐도 0 벡터로 나눠 터지면 안 된다.
	var degenerate := _feedback.contact_normal_for(_bumper.global_position)
	_expect(degenerate.length() > 0.0,
		"공이 중심과 겹쳐도 접촉 법선이 0 벡터면 안 된다")


func _test_hit_spawns_ticks_and_chips() -> void:
	_feedback.spawn_hit(_bumper.global_position + Vector2(0.0, -500.0))
	_expect(_feedback.live_tick_count() == BUTTON_VFX.tick_count,
		"타격선이 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [BUTTON_VFX.tick_count, _feedback.live_tick_count()])
	_expect(_feedback.live_chip_count() == BUTTON_VFX.chip_count,
		"재질 조각이 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [BUTTON_VFX.chip_count, _feedback.live_chip_count()])

	# 솜은 조각이 3~5 개여야 한다 (기획서 5-2). 큰 먼지 구름 금지.
	_expect(COTTON_VFX.chip_count >= 3 and COTTON_VFX.chip_count <= 5,
		"솜 조각 수가 3~5 개여야 한다 (실제=%d)" % COTTON_VFX.chip_count)


func _test_durability_first_notice_is_ignored() -> void:
	var before := _feedback.live_thread_count()
	_bumper.durability_changed.emit(3, 3)
	_expect(_feedback.live_thread_count() == before,
		"내구도 최초 통지(현재==최대)는 실밥 연출을 띄우면 안 된다")

	_bumper.durability_changed.emit(2, 3)
	_expect(_feedback.live_thread_count() == before + 1,
		"내구도가 깎이면 실밥 한 가닥이 끊어져야 한다")


func _test_state_transitions() -> void:
	_bumper.state_changed.emit(
		Bumper.BumperState.ACTIVE, Bumper.BumperState.DESTROYED_TIMER
	)
	_expect(_feedback.live_debris_count() == BUTTON_VFX.debris_count,
		"파괴 시 파편이 규칙 수만큼 생겨야 한다 (기대=%d, 실제=%d)"
			% [BUTTON_VFX.debris_count, _feedback.live_debris_count()])
	_expect(not _feedback.is_telegraph_active(),
		"파괴 상태에서는 복구 예고가 꺼져 있어야 한다")

	_bumper.state_changed.emit(
		Bumper.BumperState.SAFE_RESPAWN_WAIT, Bumper.BumperState.RESPAWN_TELEGRAPH
	)
	_expect(_feedback.is_telegraph_active(),
		"복구 예고 상태에서는 떨림이 켜져야 한다")

	_bumper.state_changed.emit(
		Bumper.BumperState.RESPAWN_TELEGRAPH, Bumper.BumperState.ACTIVE
	)
	_expect(not _feedback.is_telegraph_active(),
		"복귀하면 복구 예고가 꺼져야 한다")


func _test_bumper_transform_untouched() -> void:
	var position_before := _bumper.global_position
	var rotation_before := _bumper.global_rotation
	var scale_before := _bumper.scale

	_feedback.spawn_hit(_bumper.global_position + Vector2(300.0, 120.0))
	_feedback.spawn_thread_snap()
	_feedback.spawn_debris()

	_expect(_bumper.global_position.is_equal_approx(position_before),
		"VFX 가 범퍼 위치를 건드리면 안 된다")
	_expect(absf(_bumper.global_rotation - rotation_before) <= EPSILON,
		"VFX 가 범퍼 회전을 건드리면 안 된다")
	_expect(_bumper.scale.is_equal_approx(scale_before),
		"VFX 가 범퍼 크기를 건드리면 안 된다")


func _test_layer_order() -> void:
	_expect(_feedback.top_level and not _feedback.z_as_relative,
		"VFX 노드는 top_level 이고 z_as_relative 가 꺼져 있어야 한다")
	_expect(_feedback.z_index == BumperHitFeedback.HIT_Z_INDEX,
		"타격 VFX z 가 규정값이어야 한다 (기대=%d, 실제=%d)"
			% [BumperHitFeedback.HIT_Z_INDEX, _feedback.z_index])

	var debris := _feedback.get_node_or_null(^"_Debris")
	_expect(debris != null, "파편 레이어 노드가 있어야 한다")
	if debris != null:
		_expect(debris.z_index == BumperHitFeedback.DEBRIS_Z_INDEX,
			"파편 z 가 규정값이어야 한다 (기대=%d, 실제=%d)"
				% [BumperHitFeedback.DEBRIS_Z_INDEX, debris.z_index])
		_expect(debris.z_index > _feedback.z_index,
			"파편은 타격 VFX 보다 위에 그려져야 한다")


func _test_rules_are_clamped() -> void:
	var rules := BumperVfxRules.new()
	rules.tick_count = 999
	_expect(rules.tick_count == BumperVfxRules.MAX_TICK_COUNT,
		"타격선 수가 상한으로 보정돼야 한다 (실제=%d)" % rules.tick_count)

	rules.chip_radius_ratio = -5.0
	_expect(absf(rules.chip_radius_ratio - BumperVfxRules.MIN_CHIP_RADIUS_RATIO) <= EPSILON,
		"조각 반지름 비율이 하한으로 보정돼야 한다 (실제=%s)" % rules.chip_radius_ratio)

	rules.telegraph_amplitude_ratio = 99.0
	_expect(
		absf(rules.telegraph_amplitude_ratio - BumperVfxRules.MAX_TELEGRAPH_AMPLITUDE)
			<= EPSILON,
		"복구 예고 떨림 폭이 상한으로 보정돼야 한다 (실제=%s)"
			% rules.telegraph_amplitude_ratio
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_hit_feedback_test")
		quit(0)
		return
	print("FAIL: bumper_hit_feedback_test (%d failures)" % _failures.size())
	quit(1)
