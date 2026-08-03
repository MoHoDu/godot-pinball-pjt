extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const RULES_PATH := "res://settings/balls/BallGlowOutlineRules.tres"
const FLOAT_EPSILON := 0.001

## 문서 권장: 공 지름 44px일 때 발광 테두리 외곽 반지름 28~30px
const DOC_BALL_DIAMETER := 44.0
const DOC_OUTER_MIN := 27.5
const DOC_OUTER_MAX := 31.5


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
	_test_scene_wiring()
	await _test_ring_geometry_matches_document()
	await _test_ring_scales_with_ball_diameter()
	await _test_follows_ball_and_ignores_body_rotation()
	await _test_gaps_exist_and_close_on_flash()
	await _test_flash_decays()
	await _test_parry_grades_map_to_flash_strength()
	await _test_state_changes_color()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource() -> void:
	var rules := load(RULES_PATH) as BallGlowOutlineRules
	_expect(rules != null, "BallGlowOutlineRules.tres를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect_float(rules.radius_ratio, 1.24, "기본 반지름 비율은 1.24여야 한다.")
	_expect(rules.gap_half_width <= 0.1,
		"갭 절반 각도가 커지면 링이 조각난 호로 보인다. 0.1rad 이하로 유지해야 한다.")
	_expect(rules.gap_softness > rules.gap_half_width,
		"소프트니스가 갭보다 넓어야 끊김이 아니라 흐름으로 읽힌다.")

	rules.radius_ratio = 99.0
	_expect_float(rules.radius_ratio, BallGlowOutlineRules.MAX_RADIUS_RATIO,
		"반지름 비율은 상한으로 보정되어야 한다.")
	rules.radius_ratio = 1.24

	# 코어는 공의 아이보리 테두리보다 밝지 않아야 한다 (공 본체가 가독성 1순위)
	_expect(rules.normal_core_color.a < 1.0,
		"기본 코어 알파는 1.0 미만이어야 공 본체가 먼저 읽힌다.")
	_expect(rules.normal_glow_color.a < rules.normal_core_color.a,
		"글로우는 코어보다 흐려야 한다.")


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

func _test_ring_geometry_matches_document() -> void:
	var rig: GlowRig = await _make_rig(DOC_BALL_DIAMETER)
	var rules := rig.outline.outline_rules
	var radius := rig.outline.get_ring_radius()
	var core_outer := radius * (1.0 + rules.wobble_amount) \
		+ (DOC_BALL_DIAMETER * 0.5) * rules.core_width_ratio * 0.5
	var glow_outer := radius * (1.0 + rules.wobble_amount) \
		+ (DOC_BALL_DIAMETER * 0.5) * rules.glow_width_ratio * 0.5

	_expect(core_outer >= DOC_OUTER_MIN and core_outer <= DOC_OUTER_MAX,
		"공 44px 기준 코어 외곽 반지름이 문서 권장 28~30px 대역이어야 한다. (%.1f)" % core_outer)
	_expect(glow_outer >= DOC_OUTER_MIN and glow_outer <= DOC_OUTER_MAX,
		"글로우 외곽 반지름도 대역 안이어야 한다. (%.1f)" % glow_outer)
	_expect(radius > DOC_BALL_DIAMETER * 0.5,
		"링은 공 본체 바깥에 있어야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_ring_scales_with_ball_diameter() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var small := rig.outline.get_ring_radius()

	rig.ball.ball_diameter = 128.0
	await physics_frame
	await physics_frame
	var large := rig.outline.get_ring_radius()

	_expect_float(large / small, 128.0 / 44.0,
		"링 반지름은 공 지름에 비례해야 한다. px을 박아두면 안 된다.")

	var glow := rig.outline.get_node("Glow") as Line2D
	_expect(glow.points.size() > 0, "링에 점이 깔려 있어야 한다.")
	# 흔들림 때문에 정확히 일치하지는 않으므로 허용 대역으로 검사한다.
	var wobble := rig.outline.outline_rules.wobble_amount
	var max_r := 0.0
	var min_r := 99999.0
	for p: Vector2 in glow.points:
		max_r = maxf(max_r, p.length())
		min_r = minf(min_r, p.length())
	_expect(max_r <= large * (1.0 + wobble * 1.5) and min_r >= large * (1.0 - wobble * 1.5),
		"실제 점 좌표도 새 반지름을 따라야 한다. (min=%.1f max=%.1f, 기준=%.1f)"
			% [min_r, max_r, large])

	_free_rig(rig)
	await physics_frame


# ── 추종 ────────────────────────────────────────────────────

func _test_follows_ball_and_ignores_body_rotation() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	rig.ball.global_position = Vector2(321.0, -654.0)
	rig.ball.rotation = 1.2
	await physics_frame
	await physics_frame

	_expect(rig.outline.global_position.distance_to(rig.ball.global_position) < 1.0,
		"테두리는 공의 위치를 따라가야 한다.")
	_expect(absf(rig.ball.rotation - 1.2) < 0.2,
		"테두리는 공의 회전을 바꾸면 안 된다.")

	var before := rig.outline.rotation
	for _step in 20:
		await physics_frame
	_expect(absf(angle_difference(before, rig.outline.rotation)) > 0.01,
		"링은 스스로 천천히 돌아 빛이 원을 따라 흐르는 인상을 만들어야 한다.")

	_free_rig(rig)
	await physics_frame


# ── 갭과 점등 ───────────────────────────────────────────────

func _test_gaps_exist_and_close_on_flash() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	var core := rig.outline.get_node("Core") as Line2D

	var idle_min := _min_alpha(core.gradient)
	_expect(idle_min < 0.05,
		"기본 상태에는 알파가 0에 가까운 갭이 있어야 한다. (%.3f)" % idle_min)

	rig.outline.flash(1.0)
	await physics_frame
	var flashed_min := _min_alpha(core.gradient)
	_expect(flashed_min > idle_min + 0.2,
		"전체 점등에서는 갭이 메워져야 한다. (%.3f -> %.3f)" % [idle_min, flashed_min])

	_free_rig(rig)
	await physics_frame


func _test_flash_decays() -> void:
	var rig: GlowRig = await _make_rig(44.0)
	rig.outline.flash(1.0)
	await physics_frame
	_expect(rig.outline.get_flash_amount() > 0.9, "점등 직후에는 최대치여야 한다.")

	var rules := rig.outline.outline_rules
	var frames := int((rules.flash_hold_time + rules.flash_fade_time) * 60.0) + 12
	for _step in frames:
		await physics_frame

	_expect_float(rig.outline.get_flash_amount(), 0.0,
		"점등은 유지 시간 뒤 페이드되어 완전히 사라져야 한다.")

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
	var core := rig.outline.get_node("Core") as Line2D
	var normal_color := _peak_color(core.gradient)

	rig.outline.set_state(BallGlowOutline.State.CURSE)
	await physics_frame
	var curse_color := _peak_color(core.gradient)

	_expect(normal_color != curse_color, "저주 상태는 기본 상태와 색이 달라야 한다.")
	_expect(curse_color.g > curse_color.b,
		"저주 코어는 라임 계열이라 초록이 파랑보다 강해야 한다.")
	_expect(rig.outline.get_state() == BallGlowOutline.State.CURSE,
		"상태가 저장되어야 한다.")

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


func _min_alpha(gradient: Gradient) -> float:
	if gradient == null:
		return -1.0

	var lowest := 999.0
	for i in gradient.get_point_count():
		lowest = minf(lowest, gradient.get_color(i).a)

	return lowest


func _peak_color(gradient: Gradient) -> Color:
	var best := Color(0, 0, 0, -1.0)
	if gradient == null:
		return best

	for i in gradient.get_point_count():
		var c := gradient.get_color(i)
		if c.a > best.a:
			best = c

	return best


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
