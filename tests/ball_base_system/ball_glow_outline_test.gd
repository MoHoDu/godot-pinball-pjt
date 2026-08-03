extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const RULES_PATH := "res://settings/balls/BallGlowOutlineRules.tres"
const SHADER_PATH := "res://Resources/shaders/ball_mist_aura.gdshader"
const FLOAT_EPSILON := 0.001

## 2026-08-03 확정: 공 44px 기준 안개 외곽 40px (3안 중 안 B).
## 비주얼 가이드의 28~30px을 의도적으로 넘긴 값이라 여기서 못 박아 둡니다.
const DOC_BALL_DIAMETER := 44.0
const APPROVED_OUTER_RADIUS := 40.0
const OUTER_TOLERANCE := 0.5


## 패링 시그널을 흉내 내는 가짜 플리퍼입니다.
class FakeFlipper:
	extends Node2D

	signal parry_resolved(
		ball: RigidBody2D,
		grade: int,
		contact_point: Vector2,
		contact_zone: int,
		elapsed_time: float,
		speed_multiplier: float
	)

	func emit_parry(ball: RigidBody2D, grade: int) -> void:
		parry_resolved.emit(ball, grade, Vector2.ZERO, 0, 0.0, 1.0)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource()
	_test_shader_resource()
	_test_scene_wiring()
	await _test_outer_radius_matches_approved_value()
	await _test_scales_with_ball_diameter()
	await _test_uniforms_are_normalised()
	await _test_follows_ball_without_rotating()
	await _test_flash_raises_gain_and_decays()
	await _test_parry_grades_map_to_flash_strength()
	await _test_state_changes_color()
	await _test_gaze_only_when_moving()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource() -> void:
	var rules := load(RULES_PATH) as BallGlowOutlineRules
	_expect(rules != null, "BallGlowOutlineRules.tres를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect_float(rules.radius_ratio, 1.818, "확정된 반지름 비율은 1.818(외곽 40px)이어야 한다.")

	_expect(rules.band_count <= 6,
		"밴드가 많으면 계단이 사라져 매끈한 네온 글로우가 된다. 6단 이하로 유지해야 한다.")
	_expect(rules.plume_amount <= 0.25,
		"혓바닥이 커지면 실루엣이 울퉁불퉁해져 '반드시 원으로 읽힐 것' 기준에 걸린다.")
	_expect(rules.wisp_amount > 0.0,
		"결이 0이면 안개가 아니라 매끈한 글로우가 된다.")
	_expect(rules.core_alpha > 0.0,
		"코어 링이 없으면 안개만 남아 전체 형태가 원으로 안 읽힌다.")

	rules.radius_ratio = 99.0
	_expect_float(rules.radius_ratio, BallGlowOutlineRules.MAX_RADIUS_RATIO,
		"반지름 비율은 상한으로 보정되어야 한다.")
	rules.radius_ratio = 1.818

	rules.band_count = 999
	_expect(rules.band_count == BallGlowOutlineRules.MAX_BAND_COUNT,
		"밴드 수도 상한으로 보정되어야 한다.")
	rules.band_count = 5

	# 코어는 공의 아이보리 테두리보다 밝지 않아야 한다 (공 본체가 가독성 1순위)
	_expect(rules.normal_core_color.a < 1.0,
		"기본 코어 알파는 1.0 미만이어야 공 본체가 먼저 읽힌다.")
	_expect(rules.outer_darken < 1.0,
		"바깥 색은 안개 색보다 어두워야 바깥으로 갈수록 옅어 보인다.")


func _test_shader_resource() -> void:
	var shader := load(SHADER_PATH) as Shader
	_expect(shader != null, "안개 셰이더를 불러올 수 있어야 한다.")

	if shader == null:
		return

	var code := shader.code
	_expect(code.contains("shader_type canvas_item"),
		"canvas_item 셰이더여야 2D 스프라이트에 붙는다.")
	# GLSL의 pow(음수, 2.0)은 정의되지 않는다. 코어 링 감쇠는 곱셈이어야 한다.
	_expect(not code.contains("pow(rd"),
		"pow로 제곱하면 음수 밑에서 정의되지 않는다. rd * rd 로 써야 한다.")


# ── 씬 연결 ─────────────────────────────────────────────────

func _test_scene_wiring() -> void:
	var packed_scene := load(BALL_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "기본 공 씬을 불러올 수 있어야 한다.")

	if packed_scene == null:
		return

	var ball := packed_scene.instantiate() as Pinball
	_expect(ball != null, "기본 공 씬의 루트는 Pinball이어야 한다.")

	if ball == null:
		return

	var outline := ball.get_node_or_null("_GlowOutline") as BallGlowOutline
	_expect(outline != null,
		"기본 공 씬에 _GlowOutline(BallGlowOutline)이 붙어 있어야 한다.")
	_expect(ball.get_node_or_null("Visual/Sprite2D") is Sprite2D,
		"발광 테두리를 붙여도 Visual/Sprite2D 경로가 유지되어야 한다.")

	if outline != null:
		_expect(outline.top_level,
			"테두리는 top_level이라야 공의 회전을 물려받지 않는다.")
		_expect(not outline.z_as_relative and outline.z_index > 0,
			"테두리는 공 본체보다 위 레이어에 있어야 한다.")

	ball.free()


# ── 기하 ────────────────────────────────────────────────────

func _test_outer_radius_matches_approved_value() -> void:
	var rig: GlowRig = await _make_rig(DOC_BALL_DIAMETER)
	var outer := rig.outline.get_ring_radius()

	_expect(absf(outer - APPROVED_OUTER_RADIUS) <= OUTER_TOLERANCE,
		"공 44px 기준 안개 외곽은 확정값 40px이어야 한다. (%.1f)" % outer)
	_expect(outer > DOC_BALL_DIAMETER * 0.5,
		"안개는 공 본체 바깥에 있어야 한다.")

	# 쿼드가 안개보다 넓어야 경계에서 잘린 네모 자국이 안 남는다
	var quad := rig.outline.get_node("Mist") as Sprite2D
	_expect(quad != null, "안개를 그리는 Mist 쿼드가 있어야 한다.")
	if quad != null:
		_expect(quad.scale.x >= outer * 2.0,
			"쿼드는 안개 지름보다 커야 한다. (쿼드 %.1f, 안개 지름 %.1f)"
				% [quad.scale.x, outer * 2.0])

	_free_rig(rig)
	await physics_frame


func _test_scales_with_ball_diameter() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var small := rig.outline.get_ring_radius()
	var small_quad := (rig.outline.get_node("Mist") as Sprite2D).scale.x

	rig.ball.ball_diameter = 128.0
	await physics_frame
	await physics_frame

	var large := rig.outline.get_ring_radius()
	var large_quad := (rig.outline.get_node("Mist") as Sprite2D).scale.x

	_expect_float(large / small, 128.0 / 44.0,
		"안개 반지름은 공 지름에 비례해야 한다. px을 박아두면 안 된다.")
	_expect_float(large_quad / small_quad, 128.0 / 44.0,
		"쿼드 크기도 같은 비율로 따라와야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_uniforms_are_normalised() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var ball_ratio: float = rig.outline.get_shader_param(&"ball_ratio")
	var outer_ratio: float = rig.outline.get_shader_param(&"outer_ratio")

	_expect(ball_ratio > 0.0 and ball_ratio < outer_ratio,
		"공 반지름 비율은 안개 반지름 비율보다 작아야 한다. (%.3f < %.3f)"
			% [ball_ratio, outer_ratio])
	_expect(outer_ratio < 1.0,
		"안개 외곽은 쿼드 안에 들어와야 한다. 1.0을 넘으면 잘린다. (%.3f)" % outer_ratio)

	# 공 지름이 바뀌어도 정규화 비율은 그대로여야 px 하드코딩이 없다는 뜻이다
	rig.ball.ball_diameter = 128.0
	await physics_frame
	await physics_frame
	var ball_ratio_large: float = rig.outline.get_shader_param(&"ball_ratio")
	_expect_float(ball_ratio_large, ball_ratio,
		"정규화 비율은 공 크기와 무관해야 한다.")

	_free_rig(rig)
	await physics_frame


# ── 추종 ────────────────────────────────────────────────────

func _test_follows_ball_without_rotating() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	rig.ball.global_position = Vector2(321.0, -654.0)
	rig.ball.rotation = 1.2
	await physics_frame
	await physics_frame

	_expect(rig.outline.global_position.distance_to(rig.ball.global_position) < 1.0,
		"테두리는 공의 위치를 따라가야 한다.")
	_expect(absf(rig.ball.rotation - 1.2) < 0.2,
		"테두리는 공의 회전을 바꾸면 안 된다.")

	var before := rig.outline.get_drift_phase()
	for _step in 20:
		await physics_frame

	_expect(rig.outline.get_drift_phase() != before,
		"안개는 위상이 흘러 제자리에서 소용돌이쳐야 한다.")
	_expect_float(rig.outline.rotation, 0.0,
		"노드 자체는 돌면 안 된다. 안개가 통째로 회전하면 물체가 도는 것처럼 보인다.")

	_free_rig(rig)
	await physics_frame


# ── 점등 ────────────────────────────────────────────────────

func _test_flash_raises_gain_and_decays() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var idle_gain: float = rig.outline.get_shader_param(&"alpha_gain")

	rig.outline.flash(1.0)
	await physics_frame
	_expect(rig.outline.get_flash_amount() > 0.9, "점등 직후에는 최대치여야 한다.")

	var flashed_gain: float = rig.outline.get_shader_param(&"alpha_gain")
	_expect(flashed_gain > idle_gain + 0.1,
		"전체 점등에서는 안개가 밝아져야 한다. (%.2f -> %.2f)" % [idle_gain, flashed_gain])

	var rules := rig.outline.outline_rules
	var frames := int((rules.flash_hold_time + rules.flash_fade_time) * 60.0) + 12
	for _step in frames:
		await physics_frame

	_expect_float(rig.outline.get_flash_amount(), 0.0,
		"점등은 유지 시간 뒤 페이드되어 완전히 사라져야 한다.")
	_expect_float(rig.outline.get_shader_param(&"alpha_gain"), idle_gain,
		"점등이 끝나면 밝기도 원래대로 돌아와야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_parry_grades_map_to_flash_strength() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var flipper := FakeFlipper.new()
	root.add_child(flipper)
	rig.outline.bind_to_flipper(flipper)
	await physics_frame

	flipper.emit_parry(rig.ball, BallGlowOutline.PARRY_GRADE_NORMAL)
	await physics_frame
	var normal_flash := rig.outline.get_flash_amount()
	_expect(normal_flash > 0.0 and normal_flash < 0.9,
		"일반 패링은 약한 순간 점등이어야 한다. (%.2f)" % normal_flash)

	flipper.emit_parry(rig.ball, BallGlowOutline.PARRY_GRADE_PERFECT)
	await physics_frame
	_expect(rig.outline.get_flash_amount() > 0.9,
		"정확한 패링은 강한 전체 점등이어야 한다.")

	# 다른 공의 패링에는 반응하지 않아야 한다
	var other := RigidBody2D.new()
	root.add_child(other)
	for _step in 30:
		await physics_frame
	flipper.emit_parry(other, BallGlowOutline.PARRY_GRADE_PERFECT)
	await physics_frame
	_expect_float(rig.outline.get_flash_amount(), 0.0,
		"다른 공의 패링에는 점등하지 않아야 한다.")

	other.queue_free()
	flipper.queue_free()
	_free_rig(rig)
	await physics_frame


func _test_state_changes_color() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var normal_core: Color = rig.outline.get_shader_param(&"col_core")
	var normal_mist: Color = rig.outline.get_shader_param(&"col_mist")

	rig.outline.set_state(BallGlowOutline.State.CURSE)
	await physics_frame
	var curse_core: Color = rig.outline.get_shader_param(&"col_core")
	var curse_mist: Color = rig.outline.get_shader_param(&"col_mist")

	_expect(normal_core != curse_core, "저주 상태는 기본 상태와 색이 달라야 한다.")
	_expect(curse_core.g > curse_core.b,
		"저주 코어는 라임 계열이라 초록이 파랑보다 강해야 한다.")
	_expect(curse_mist.b > curse_mist.g,
		"저주 안개는 보라 계열이라 파랑이 초록보다 강해야 한다.")
	_expect(normal_mist.g > normal_mist.r,
		"기본 안개는 청록이라 초록이 빨강보다 강해야 한다.")
	_expect(rig.outline.get_state() == BallGlowOutline.State.CURSE,
		"상태가 저장되어야 한다.")

	# 바깥 색은 안개 색을 어둡게 한 것이어야 한다
	var outer: Color = rig.outline.get_shader_param(&"col_outer")
	_expect(outer.r <= curse_mist.r and outer.g <= curse_mist.g and outer.b <= curse_mist.b,
		"바깥 색은 안개 색보다 어두워야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_gaze_only_when_moving() -> void:
	var rig: GlowRig = await _make_rig(44.0)

	# freeze 상태라 속도가 0이다
	_expect_float(rig.outline.get_shader_param(&"gaze_enabled"), 0.0,
		"멈춘 공은 한쪽으로 쏠려 보이면 안 되므로 진행방향 늘림을 꺼야 한다.")

	rig.ball.freeze = false
	rig.ball.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	await physics_frame

	_expect_float(rig.outline.get_shader_param(&"gaze_enabled"), 1.0,
		"빠르게 움직이는 공은 진행방향으로 안개가 늘어나야 한다.")
	_expect(absf(rig.outline.get_shader_param(&"gaze_angle")) < 0.35,
		"오른쪽으로 가는 공의 응시 각도는 0에 가까워야 한다.")

	_free_rig(rig)
	await physics_frame


# ── 헬퍼 ────────────────────────────────────────────────────

class GlowRig:
	var ball: Pinball
	var outline: BallGlowOutline


func _make_rig(diameter: float) -> GlowRig:
	var rig := GlowRig.new()
	rig.ball = (load(BALL_SCENE_PATH) as PackedScene).instantiate() as Pinball
	root.add_child(rig.ball)
	# _ready의 refresh_physics_properties()가 stats를 다시 적용하므로 그 뒤에 끕니다.
	rig.ball.gravity_scale = 0.0
	rig.ball.freeze = true
	rig.ball.ball_diameter = diameter
	rig.outline = rig.ball.get_node("_GlowOutline") as BallGlowOutline
	await physics_frame
	await physics_frame
	return rig


func _free_rig(rig: GlowRig) -> void:
	rig.ball.queue_free()


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= FLOAT_EPSILON,
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ball_glow_outline_test")
		quit(0)
		return

	print("FAIL: ball_glow_outline_test (%d failures)" % _failures.size())
	quit(1)
