extends SceneTree

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const RULES_PATH := "res://settings/balls/BallTrailRules.tres"
const SHADER_PATH := "res://Resources/shaders/ball_trail.gdshader"
const FLOAT_EPSILON := 0.001

## 2026-08-03 확정(안 D1): 공 44px 기준 길이 140px, 레이저 뿌리 9px / 블룸 뿌리 60px.
const DOC_BALL_DIAMETER := 44.0
const APPROVED_LENGTH := 140.0
const APPROVED_LASER_WIDTH := 8.8
const APPROVED_BLOOM_WIDTH := 59.4
const WIDTH_TOLERANCE := 0.6

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource()
	_test_shader_resource()
	_test_scene_wiring()
	await _test_confirmed_dimensions()
	await _test_scales_with_ball_diameter()
	await _test_hides_when_stopped()
	await _test_records_path_and_respects_length()
	await _test_layer_order_behind_ball()
	await _test_does_not_touch_ball()
	await _test_slow_ball_keeps_short_trail()
	await _test_trail_retracts_after_slowdown()
	await _test_triangle_silhouette()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource() -> void:
	var rules := load(RULES_PATH) as BallTrailRules
	_expect(rules != null, "BallTrailRules.tres를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect_float(rules.length_ratio, 6.364, "확정된 길이 비율은 6.364(공 44px에서 140px)여야 한다.")
	_expect_float(rules.bloom_root, 1.35, "확정된 블룸 뿌리 반폭 비율은 1.35여야 한다.")
	_expect_float(rules.core_root, 0.20, "확정된 레이저 뿌리 반폭 비율은 0.20이어야 한다.")
	_expect(rules.band_steps == 4, "밝기 계단은 스케치대로 4단이어야 한다.")

	# 2겹으로 읽히려면 블룸이 레이저보다 충분히 넓어야 한다
	_expect(rules.bloom_root >= rules.core_root * 2.5,
		"블룸이 레이저의 2.5배 이상 넓어야 '감싸는 2겹'으로 읽힌다. (%.2f vs %.2f)"
			% [rules.bloom_root, rules.core_root])

	# 끝으로 갈수록 가늘어져야 한다
	_expect(rules.bloom_tip < rules.bloom_root, "블룸은 끝으로 갈수록 가늘어져야 한다.")
	_expect(rules.core_tip < rules.core_root, "레이저는 끝으로 갈수록 가늘어져야 한다.")

	_expect(rules.hide_below_speed > 0.0,
		"정지·발사 대기 중에는 꼬리를 감춰야 하므로 하한 속도가 있어야 한다.")

	rules.length_ratio = 999.0
	_expect_float(rules.length_ratio, BallTrailRules.MAX_LENGTH_RATIO,
		"길이 비율은 상한으로 보정되어야 한다.")
	rules.length_ratio = 6.364


func _test_shader_resource() -> void:
	var shader := load(SHADER_PATH) as Shader
	_expect(shader != null, "꼬리 셰이더를 불러올 수 있어야 한다.")

	if shader == null:
		return

	var code := shader.code
	_expect(code.contains("shader_type canvas_item"),
		"canvas_item 셰이더여야 Line2D에 붙는다.")
	# GLSL 내장 smoothstep은 e0 >= e1이면 정의되지 않는다. 내림차순용을 따로 써야 한다.
	_expect(code.contains("float sstep("),
		"내림차순 falloff용 자체 smoothstep이 있어야 한다.")


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

	var trail := ball.get_node_or_null("_Trail") as BallTrail
	_expect(trail != null, "기본 공 씬에 _Trail(BallTrail)이 붙어 있어야 한다.")
	_expect(ball.get_node_or_null("_GlowOutline") != null,
		"꼬리를 붙여도 발광 테두리가 남아 있어야 한다.")
	_expect(ball.get_node_or_null("Visual/Sprite2D") is Sprite2D,
		"꼬리를 붙여도 Visual/Sprite2D 경로가 유지되어야 한다.")

	if trail != null:
		_expect(trail.top_level, "꼬리는 top_level이라야 공의 회전을 물려받지 않는다.")
		_expect(not trail.z_as_relative, "꼬리 레이어는 절대값이어야 한다.")

	ball.free()


# ── 확정 수치 ───────────────────────────────────────────────

func _test_confirmed_dimensions() -> void:
	var rig: TrailRig = await _make_rig(DOC_BALL_DIAMETER, Vector2(900.0, 0.0))
	var line := rig.trail.get_node("Trail") as Line2D

	_expect(line != null, "꼬리를 그리는 Trail(Line2D)이 있어야 한다.")
	if line == null:
		_free_rig(rig)
		return

	# Line2D.width 는 전체 폭이고 블룸 뿌리에 해당한다
	_expect(absf(line.width - APPROVED_BLOOM_WIDTH) <= WIDTH_TOLERANCE,
		"블룸 뿌리 전체 폭이 확정값 %.1fpx여야 한다. (%.1f)"
			% [APPROVED_BLOOM_WIDTH, line.width])

	var rules := rig.trail.trail_rules
	var laser_w := rules.core_root * (DOC_BALL_DIAMETER * 0.5) * 2.0
	_expect(absf(laser_w - APPROVED_LASER_WIDTH) <= WIDTH_TOLERANCE,
		"레이저 뿌리 전체 폭이 확정값 %.1fpx여야 한다. (%.1f)"
			% [APPROVED_LASER_WIDTH, laser_w])

	# 기준 속도에서는 기준 길이가 나와야 한다
	_expect(absf(rig.trail.get_trail_length() - APPROVED_LENGTH) <= 1.0,
		"기준 속도에서 꼬리 길이는 확정값 140px여야 한다. (%.1f)"
			% rig.trail.get_trail_length())

	# 폭 커브가 끝에서 가늘어져야 한다
	var curve := line.width_curve
	_expect(curve != null and curve.point_count >= 2, "폭 커브가 있어야 한다.")
	if curve != null and curve.point_count >= 2:
		_expect(curve.sample(1.0) < curve.sample(0.0),
			"폭 커브는 끝으로 갈수록 가늘어져야 한다. (%.3f -> %.3f)"
				% [curve.sample(0.0), curve.sample(1.0)])

	_free_rig(rig)
	await physics_frame


func _test_scales_with_ball_diameter() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(900.0, 0.0))
	var small_len := rig.trail.get_trail_length()
	var small_width := (rig.trail.get_node("Trail") as Line2D).width

	rig.ball.ball_diameter = 128.0
	await physics_frame
	await physics_frame

	var large_len := rig.trail.get_trail_length()
	var large_width := (rig.trail.get_node("Trail") as Line2D).width

	_expect_float(large_len / small_len, 128.0 / 44.0,
		"꼬리 길이는 공 지름에 비례해야 한다. px을 박아두면 안 된다.")
	_expect_float(large_width / small_width, 128.0 / 44.0,
		"꼬리 폭도 같은 비율로 따라와야 한다.")

	_free_rig(rig)
	await physics_frame


# ── 속도 반응 ───────────────────────────────────────────────

func _test_hides_when_stopped() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(900.0, 0.0))
	for _step in 20:
		await physics_frame

	_expect(rig.trail.get_fade() > 0.9, "움직이는 공은 꼬리가 완전히 켜져 있어야 한다.")

	# 정지 — 문서: "발사 대기·정지 중에는 꼬리를 표시하지 않는다"
	rig.ball.linear_velocity = Vector2.ZERO
	var frames := int(rig.trail.trail_rules.fade_out_time * 60.0) + 20
	for _step in frames:
		await physics_frame

	_expect_float(rig.trail.get_fade(), 0.0, "정지하면 꼬리가 완전히 사라져야 한다.")
	_expect(not rig.trail.visible, "사라진 뒤에는 그리지 않아야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_records_path_and_respects_length() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(900.0, 0.0))
	for _step in 40:
		await physics_frame

	_expect(rig.trail.get_point_count() >= 2, "궤적이 기록되어야 한다.")

	var line := rig.trail.get_node("Trail") as Line2D
	var pts := line.points
	if pts.size() >= 2:
		# 머리는 공에 붙어 있어야 한다
		_expect(pts[0].distance_to(rig.ball.global_position) < 4.0,
			"꼬리 머리는 공에 붙어 있어야 한다. (%.1f)"
				% pts[0].distance_to(rig.ball.global_position))

		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i - 1].distance_to(pts[i])

		var target := rig.trail.get_trail_length()
		_expect(total <= target + 4.0,
			"꼬리 길이가 목표를 넘으면 안 된다. (%.1f > %.1f)" % [total, target])
		_expect(total >= target * 0.6,
			"충분히 달린 뒤에는 목표 길이에 근접해야 한다. (%.1f / %.1f)" % [total, target])

	# 느린 공은 짧아야 한다
	var slow_len := rig.trail.get_trail_length()
	rig.ball.linear_velocity = Vector2(200.0, 0.0)
	await physics_frame
	_expect(rig.trail.get_trail_length() < slow_len,
		"속도가 낮아지면 꼬리가 짧아져야 한다.")

	_free_rig(rig)
	await physics_frame


func _test_layer_order_behind_ball() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(900.0, 0.0))
	var visual := rig.ball.get_node("Visual") as Node2D
	var glow := rig.ball.get_node("_GlowOutline") as Node2D

	_expect(rig.trail.z_index < visual.z_index,
		"꼬리는 공 본체보다 뒤 레이어여야 한다. (%d < %d)"
			% [rig.trail.z_index, visual.z_index])
	_expect(visual.z_index < glow.z_index,
		"공 본체는 발광 테두리보다 뒤 레이어여야 한다. (%d < %d)"
			% [visual.z_index, glow.z_index])
	_expect(rig.trail.z_index > 0,
		"꼬리가 보드 아래로 내려가면 안 된다.")

	_free_rig(rig)
	await physics_frame


func _test_does_not_touch_ball() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(700.0, 300.0))
	rig.ball.global_position = Vector2(123.0, -456.0)
	rig.ball.rotation = 0.8
	var before_pos := rig.ball.global_position
	var before_rot := rig.ball.rotation

	for _step in 15:
		await physics_frame

	_expect(rig.ball.global_position.distance_to(before_pos) < 0.01,
		"꼬리는 공의 위치를 바꾸면 안 된다.")
	_expect(absf(rig.ball.rotation - before_rot) < 0.01,
		"꼬리는 공의 회전을 바꾸면 안 된다.")
	# top_level 노드는 원점에 고정하고 점만 월드 좌표로 넣는다
	_expect(rig.trail.global_position.length() < 0.01,
		"꼬리 노드는 원점에 있어야 과거 점을 다시 변환하지 않는다.")

	_free_rig(rig)
	await physics_frame


## 느린 공에서 꼬리가 점 하나로 붕괴하면 안 됩니다.
## 간격 검사를 "살아있는 머리"와 하면 거리가 늘 한 프레임치라 점이 확정되지 않습니다.
func _test_slow_ball_keeps_short_trail() -> void:
	# hide_below_speed(60)보다는 빠르지만 아주 느린 속도
	var rig: TrailRig = await _make_rig(44.0, Vector2(80.0, 0.0))
	for _step in 90:
		await physics_frame

	_expect(rig.trail.get_point_count() >= 3,
		"느린 공도 꼬리가 점 하나로 붕괴하면 안 된다. (%d개)"
			% rig.trail.get_point_count())

	var pts := (rig.trail.get_node("Trail") as Line2D).points
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	_expect(total > 4.0, "느린 공도 꼬리가 눈에 보일 길이는 있어야 한다. (%.1fpx)" % total)

	_free_rig(rig)
	await physics_frame


## 튕긴 뒤 속도가 줄면 꼬리가 공 쪽으로 걷혀야 합니다.
## 점에 수명이 없으면 옛 점이 월드 좌표에 얼어붙어 잔상으로 남습니다.
func _test_trail_retracts_after_slowdown() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(1100.0, 0.0))
	for _step in 40:
		await physics_frame

	var fast_span := _head_to_tail(rig)
	_expect(fast_span > 60.0, "빠른 공은 꼬리가 길어야 한다. (%.1fpx)" % fast_span)

	# 급감속 — 여전히 hide_below_speed 위라 꼬리는 켜져 있다
	rig.ball.linear_velocity = Vector2(80.0, 0.0)
	var frames := int(rig.trail.trail_rules.point_lifetime * 60.0) + 25
	for _step in frames:
		await physics_frame

	var slow_span := _head_to_tail(rig)
	_expect(slow_span < fast_span * 0.5,
		"감속하면 꼬리가 걷혀야 한다. 안 걷히면 옛 점이 제자리에 남는 잔상이다. (%.1f -> %.1f)"
			% [fast_span, slow_span])
	_expect(rig.trail.get_fade() > 0.5,
		"hide_below_speed 위라면 꼬리는 여전히 켜져 있어야 한다.")

	_free_rig(rig)
	await physics_frame


## 올챙이 꼬리 = 삼각형. 폭 커브가 직선이고 끝이 점으로 수렴해야 합니다.
func _test_triangle_silhouette() -> void:
	var rig: TrailRig = await _make_rig(44.0, Vector2(900.0, 0.0))
	var curve := (rig.trail.get_node("Trail") as Line2D).width_curve

	if curve != null:
		var a := curve.sample(0.0)
		var mid := curve.sample(0.5)
		var b := curve.sample(1.0)
		_expect(absf(mid - (a + b) * 0.5) < a * 0.06,
			"폭이 길이에 대해 직선이라야 삼각형으로 보인다. (중간 %.3f, 직선값 %.3f)"
				% [mid, (a + b) * 0.5])
		# 절대 px 로 재면 두께를 바꿀 때마다 깨진다. 뿌리 대비 비율로 본다.
		_expect(b / maxf(a, 0.0001) < 0.03,
			"꼬리 끝은 뿌리의 3%% 미만으로 수렴해야 한다. (%.1f%%)" % (b / maxf(a, 0.0001) * 100.0))

	_free_rig(rig)
	await physics_frame


# ── 헬퍼 ────────────────────────────────────────────────────

func _head_to_tail(rig: TrailRig) -> float:
	var pts := (rig.trail.get_node("Trail") as Line2D).points
	if pts.size() < 2:
		return 0.0

	return pts[0].distance_to(pts[pts.size() - 1])

class TrailRig:
	var ball: Pinball
	var trail: BallTrail


func _make_rig(diameter: float, velocity: Vector2) -> TrailRig:
	var rig := TrailRig.new()
	rig.ball = (load(BALL_SCENE_PATH) as PackedScene).instantiate() as Pinball
	root.add_child(rig.ball)
	# _ready의 refresh_physics_properties()가 stats를 다시 적용하므로 그 뒤에 끕니다.
	rig.ball.gravity_scale = 0.0
	rig.ball.ball_diameter = diameter
	rig.ball.linear_velocity = velocity
	rig.trail = rig.ball.get_node("_Trail") as BallTrail
	await physics_frame
	await physics_frame
	return rig


func _free_rig(rig: TrailRig) -> void:
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
		print("PASS: ball_trail_test")
		quit(0)
		return

	print("FAIL: ball_trail_test (%d failures)" % _failures.size())
	quit(1)
