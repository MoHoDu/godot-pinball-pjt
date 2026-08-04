extends SceneTree

const RULES_PATH := "res://settings/balls/BallParryWaveRules.tres"
const SHADER_PATH := "res://Resources/shaders/ball_parry_wave.gdshader"
const WAVE_SCRIPT_PATH := "res://scripts/ball_base_system/vfx/ball_parry_wave.gd"
const FLOAT_EPSILON := 0.001

## 2026-08-04 확정: 3안 중 **안 A(문서 그대로)** + 같은 날 가시성 개정.
## 안 A = 중심 플래시 꽉 찬 원 / 방사선 균등 / 중심 이동 없음 / 링 대칭.
## 가시성 개정 = 지속 0.16→0.26s, 링 6→9px, 종료 105→95px.
## 여기서 못 박아 두면 나중에 바뀌었을 때 실수가 아니라 결정이었음이 드러납니다.
const APPROVED_START_PX := 27.0
const APPROVED_END_PX := 95.0
const APPROVED_RING_WIDTH_PX := 9.0
const APPROVED_DURATION := 0.26
const APPROVED_SPOKE_COUNT := 10
const APPROVED_FLASH_HOLLOW := false
const APPROVED_CENTER_SHIFT := 0.0

## 60fps에서 "잘 보이는" 구간의 최소 프레임 수입니다.
## 개정 전 5.9프레임이 인게임에서 "잘 안 보인다"로 걸렸습니다.
const MIN_VISIBLE_FRAMES := 10.0

## 기획서 기준 실제 게임 크기입니다. VFX 검수는 이 크기로 해야 의미가 있습니다.
const DOC_BALL_DIAMETER := 44.0
const DOC_BALL_RADIUS := 22.0
const PX_TOLERANCE := 0.5

## 발광 테두리의 z_index 입니다. 파동은 반드시 그 위여야 합니다(가이드 3-2 레이어 순서).
const GLOW_OUTLINE_Z := 10


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

	func emit_parry(ball: RigidBody2D, grade: int, contact_point: Vector2) -> void:
		parry_resolved.emit(ball, grade, contact_point, 0, 0.0, 1.18)


## 파동이 붙을 대상 공입니다. 물리를 끌고 오지 않으려고 최소한만 흉내 냅니다.
class FakeBall:
	extends RigidBody2D

	var ball_diameter: float = 44.0


class WaveRig:
	extends RefCounted

	var holder: Node2D
	var wave: BallParryWave
	var ball: RigidBody2D
	var flipper: Node2D


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource_matches_approved_plan()
	_test_rules_stay_inside_guide_ranges()
	_test_known_deviations_are_deliberate()
	_test_shader_resource()
	_test_expansion_curve_is_monotonic_and_front_loaded()
	_test_sub_ring_trails_main_ring()
	_test_flash_ends_within_its_own_window()
	await _test_only_perfect_grade_fires()
	await _test_uniforms_fit_inside_the_quad()
	await _test_wave_scales_with_ball_diameter()
	await _test_wave_retires_within_duration()
	await _test_concurrent_limit_is_respected()
	await _test_layer_is_above_glow_outline()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource_matches_approved_plan() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules
	_expect(rules != null, "BallParryWaveRules.tres를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect_float(
		rules.start_radius_ratio * DOC_BALL_RADIUS,
		APPROVED_START_PX,
		"확정된 시작 반지름은 44px 공 기준 27px이어야 한다."
	)
	_expect_float(
		rules.end_radius_ratio * DOC_BALL_RADIUS,
		APPROVED_END_PX,
		"확정된 종료 반지름은 44px 공 기준 105px이어야 한다."
	)
	_expect_float(
		rules.ring_width_ratio * DOC_BALL_RADIUS,
		APPROVED_RING_WIDTH_PX,
		"확정된 주요 링 두께는 44px 공 기준 6px이어야 한다."
	)
	_expect(rules.spoke_count == APPROVED_SPOKE_COUNT,
		"가시성 개정본은 방사선 10개 균등이다. (actual=%d)" % rules.spoke_count)
	_expect_float(rules.duration, APPROVED_DURATION,
		"가시성 개정으로 확정된 지속 시간은 0.26초다.")
	_expect(rules.flash_hollow == APPROVED_FLASH_HOLLOW,
		"안 A의 중심 플래시는 꽉 찬 원이다. 속 빈 고리는 안 B·C의 선택지였다.")
	_expect_float(rules.center_shift_ratio, APPROVED_CENTER_SHIFT,
		"안 A는 중심을 타격 방향으로 옮기지 않는다.")

	_expect(rules.band_count <= 8,
		"밴드가 많으면 계단이 사라져 매끈한 네온 링이 된다. 8단 이하로 유지해야 한다.")
	_expect(rules.wobble_amount <= 0.05,
		"흔들림이 크면 44px에서 원이 아니라 톱니바퀴로 읽힌다.")
	_expect(rules.spoke_inner_mul >= 1.0,
		"방사선이 링 안쪽으로 들어가면 파동이 아니라 톱니바퀴가 된다.")
	_expect(rules.expand_exp > 1.0,
		"등속으로 커지면 '빠르게 커지고 사라진다'가 안 된다.")


## 가이드 3-5 권장 범위를 벗어나면 알려줍니다.
## 벗어난 것 자체가 결함은 아니지만, 모르고 벗어나는 일은 없어야 합니다.
func _test_rules_stay_inside_guide_ranges() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules

	if rules == null:
		return

	_expect_in_range(
		rules.start_radius_ratio * DOC_BALL_RADIUS,
		BallParryWaveRules.DOC_START_RADIUS_PX,
		"시작 반지름"
	)
	_expect_in_range(
		rules.end_radius_ratio * DOC_BALL_RADIUS,
		BallParryWaveRules.DOC_END_RADIUS_PX,
		"종료 반지름"
	)
	_expect_in_range(rules.flash_time, BallParryWaveRules.DOC_FLASH_TIME, "중심 플래시")

	# 링은 커지면서 얇아진다. 개정 후에는 끝 두께도 권장 하한 위에 남는다.
	var end_width := rules.get_ring_width_ratio(1.0) * DOC_BALL_RADIUS
	_expect(end_width >= BallParryWaveRules.DOC_RING_WIDTH_PX.x,
		"끝 두께도 권장 하한 4px 위에 있어야 한다. (actual=%.2f)" % end_width)


## ★ 가이드 권장을 의도적으로 넘긴 항목입니다.
##
## 벗어난 것 자체는 결함이 아닙니다. 안개 오라 40px(문서 28~30),
## 이동 꼬리 140px(문서 60~100)과 같은 종류의 결정입니다.
## 다만 **모르고 벗어나는 일은 없어야 하므로** 여기서 값을 못 박습니다.
func _test_known_deviations_are_deliberate() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules

	if rules == null:
		return

	_expect(rules.duration > BallParryWaveRules.DOC_DURATION.y,
		"지속 시간은 가이드 상한을 넘긴 값이 맞다. "
		+ "범위 안으로 돌아왔다면 의도한 것인지 확인해야 한다.")
	_expect(
		rules.ring_width_ratio * DOC_BALL_RADIUS > BallParryWaveRules.DOC_RING_WIDTH_PX.y,
		"링 두께는 가이드 상한을 넘긴 값이 맞다."
	)

	# 인게임에서 "잘 안 보인다"로 걸린 원인이 이 수치였다
	var span := maxf(1.0 - rules.fade_start, 0.001)
	var x := pow(0.2, 1.0 / rules.fade_exp)
	var visible := minf(rules.fade_start + span * x, 1.0) * rules.duration * 60.0
	_expect(visible >= MIN_VISIBLE_FRAMES,
		"60fps에서 잘 보이는 구간이 %.1f프레임 이상이어야 한다. (actual=%.1f)"
			% [MIN_VISIBLE_FRAMES, visible])

	# ★ 종료 반지름은 오히려 줄였다. 같은 잉크를 좁은 둘레에 모아야 선이 굵게 읽힌다.
	_expect(rules.end_radius_ratio * DOC_BALL_RADIUS < 105.0,
		"종료 반지름을 다시 키우면 링이 얇아 보여 개정 전으로 돌아간다.")


func _test_shader_resource() -> void:
	var shader := load(SHADER_PATH) as Shader
	_expect(shader != null, "ball_parry_wave.gdshader를 불러올 수 있어야 한다.")


# ── 순수 계산 (엔진 없이도 성립해야 하는 것) ──────────────────

func _test_expansion_curve_is_monotonic_and_front_loaded() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules

	if rules == null:
		return

	var previous := -1.0
	var monotonic := true

	for step in 21:
		var t := float(step) / 20.0
		var radius := rules.get_main_radius_ratio(t)

		if radius < previous - FLOAT_EPSILON:
			monotonic = false

		previous = radius

	_expect(monotonic, "파동 반경은 줄어들지 않고 계속 커져야 한다.")

	_expect_float(
		rules.get_main_radius_ratio(0.0) * DOC_BALL_RADIUS,
		APPROVED_START_PX,
		"t=0에서는 시작 반지름이어야 한다."
	)
	_expect_float(
		rules.get_main_radius_ratio(1.0) * DOC_BALL_RADIUS,
		APPROVED_END_PX,
		"t=1에서는 종료 반지름이어야 한다."
	)

	# 앞쪽에 몰려 있어야 "빠르게 커지고 사라진다"로 읽힌다
	var half := rules.get_expand_curve(0.5)
	_expect(half > 0.60,
		"절반 시점에 이미 60%% 이상 커져 있어야 한다. (actual=%.3f)" % half)

	_expect_float(rules.get_fade(0.0), 1.0, "시작 시점에는 소멸이 없어야 한다.")
	_expect_float(rules.get_fade(1.0), 0.0, "끝나는 시점에는 완전히 사라져야 한다.")


func _test_sub_ring_trails_main_ring() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules

	if rules == null:
		return

	var trails := true

	for step in 19:
		var t := float(step + 1) / 20.0

		if rules.get_sub_radius_ratio(t) > rules.get_main_radius_ratio(t) + FLOAT_EPSILON:
			trails = false

	_expect(trails,
		"금색 보조 링은 주요 링을 앞지르면 안 된다. 가이드는 '뒤따름'이라고 못 박는다.")


func _test_flash_ends_within_its_own_window() -> void:
	var rules := load(RULES_PATH) as BallParryWaveRules

	if rules == null:
		return

	_expect(rules.get_flash_amount(0.0) > 0.9,
		"중심 플래시는 시작 순간 가장 밝아야 한다.")
	_expect_float(rules.get_flash_amount(rules.flash_time), 0.0,
		"플래시 시간이 지나면 완전히 꺼져야 한다.")
	_expect_float(rules.get_flash_amount(rules.duration), 0.0,
		"파동이 끝날 때까지 플래시가 켜져 있으면 동공을 계속 가린다.")
	_expect(rules.flash_time < rules.duration,
		"플래시는 파동 전체보다 짧아야 한다.")


# ── 엔진 (씬 트리 · 시그널) ──────────────────────────────────

func _test_only_perfect_grade_fires() -> void:
	var rig: WaveRig = await _make_rig(DOC_BALL_DIAMETER)

	rig.flipper.emit_parry(rig.ball, BallParryWave.PARRY_GRADE_NONE, Vector2.ZERO)
	_expect(rig.wave.get_active_count() == 0,
		"패링이 아닌 충돌에는 파동이 나오면 안 된다.")

	rig.flipper.emit_parry(rig.ball, BallParryWave.PARRY_GRADE_NORMAL, Vector2.ZERO)
	_expect(rig.wave.get_active_count() == 0,
		"일반 패링에는 파동이 나오면 안 된다. 가이드가 '정확한 패링에만'이라고 못 박는다.")

	rig.flipper.emit_parry(rig.ball, BallParryWave.PARRY_GRADE_PERFECT, Vector2.ZERO)
	_expect(rig.wave.get_active_count() == 1,
		"정확한 패링에는 파동이 정확히 하나 나와야 한다.")

	_expect(rig.wave.get_bound_flipper_count() == 1,
		"bind_to_flipper로 붙인 플리퍼가 하나 잡혀 있어야 한다.")

	_free_rig(rig)


## 셰이더는 쿼드 반지름 1.0 기준으로 정규화돼 있다.
## 어떤 반경 유니폼이든 1.0을 넘으면 그만큼 쿼드 밖에서 잘린다.
func _test_uniforms_fit_inside_the_quad() -> void:
	var rig: WaveRig = await _make_rig(DOC_BALL_DIAMETER)
	var index := rig.wave.play_at(Vector2(120.0, -40.0), DOC_BALL_RADIUS, 0.0)

	_expect(index >= 0, "play_at은 유효한 슬롯 인덱스를 돌려줘야 한다.")

	if index < 0:
		_free_rig(rig)
		return

	var checked := ["main_r", "sub_r", "spoke_out", "spark_r", "flash_r", "ball_r"]

	for param_name in checked:
		var value: Variant = rig.wave.get_shader_param(index, StringName(param_name))
		_expect(value != null, "유니폼 %s가 셰이더에 들어가 있어야 한다." % param_name)

		if value == null:
			continue

		_expect(float(value) <= 1.0,
			"유니폼 %s가 1.0을 넘으면 쿼드 경계에서 잘린다. (actual=%.4f)"
				% [param_name, float(value)])

	var hollow: Variant = rig.wave.get_shader_param(index, &"flash_hollow")
	_expect(hollow != null and is_equal_approx(float(hollow), 0.0),
		"안 A는 꽉 찬 중심 플래시이므로 flash_hollow가 0이어야 한다.")
	_expect(
		rig.wave.get_wave_position(index).is_equal_approx(Vector2(120.0, -40.0)),
		"중심 이동이 0인 안 A에서는 파동이 준 좌표 그대로 떠야 한다."
	)

	var radius := rig.wave.get_wave_radius_px(index)
	_expect(absf(radius - APPROVED_START_PX) <= 1.0,
		"막 태어난 파동의 반경은 27px 부근이어야 한다. (actual=%.2f)" % radius)

	_free_rig(rig)


## 공 크기가 달라져도 파동이 공에 대해 같은 비율을 유지해야 합니다.
## 씬마다 ball_diameter가 다르므로(44 / 64 / 128) px을 박으면 여기서 깨집니다.
func _test_wave_scales_with_ball_diameter() -> void:
	var rig: WaveRig = await _make_rig(128.0)
	var index := rig.wave.play_at(Vector2.ZERO, 64.0, 0.0)

	if index < 0:
		_free_rig(rig)
		return

	var radius := rig.wave.get_wave_radius_px(index)
	var expected := APPROVED_START_PX * (64.0 / DOC_BALL_RADIUS)

	_expect(absf(radius - expected) <= 1.0,
		"공이 커지면 파동도 같은 비율로 커져야 한다. (expected=%.2f, actual=%.2f)"
			% [expected, radius])

	_free_rig(rig)


func _test_wave_retires_within_duration() -> void:
	var rig: WaveRig = await _make_rig(DOC_BALL_DIAMETER)
	rig.wave.play_at(Vector2.ZERO, DOC_BALL_RADIUS, 0.0)

	_expect(rig.wave.get_active_count() == 1, "파동이 하나 살아 있어야 한다.")

	# 0.16초는 60fps에서 약 10프레임이다. 넉넉히 돌려 확실히 끝나게 한다.
	var elapsed := 0.0

	while elapsed < 1.0 and rig.wave.get_active_count() > 0:
		var frame_delta: float = await _wait_process_frame()
		elapsed += frame_delta

	_expect(rig.wave.get_active_count() == 0,
		"파동은 지속 시간이 지나면 반드시 사라져야 한다. "
		+ "다음 공의 방향을 판단할 시점까지 화면에 남으면 안 된다.")
	_expect(elapsed < 0.9,
		"파동이 0.9초 넘게 남아 있으면 안 된다. (actual=%.3fs)" % elapsed)

	_free_rig(rig)


func _test_concurrent_limit_is_respected() -> void:
	var rig: WaveRig = await _make_rig(DOC_BALL_DIAMETER)
	var rules := rig.wave.wave_rules
	var limit := rules.max_concurrent if rules != null else 6

	for i in limit + 4:
		rig.wave.play_at(Vector2(float(i) * 30.0, 0.0), DOC_BALL_RADIUS, 0.0)

	_expect(rig.wave.get_active_count() <= limit,
		"동시 파동 수가 상한을 넘으면 안 된다. (limit=%d, actual=%d)"
			% [limit, rig.wave.get_active_count()])
	_expect(rig.wave.get_total_played() == limit + 4,
		"상한을 넘긴 요청도 가장 오래된 것을 밀어내고 재생돼야 한다.")

	_free_rig(rig)


func _test_layer_is_above_glow_outline() -> void:
	var rig: WaveRig = await _make_rig(DOC_BALL_DIAMETER)
	var index := rig.wave.play_at(Vector2.ZERO, DOC_BALL_RADIUS, 0.0)

	if index < 0:
		_free_rig(rig)
		return

	_expect(BallParryWave.Z_INDEX_WAVE > GLOW_OUTLINE_Z,
		"가이드 레이어 순서상 파동은 발광 테두리보다 위여야 한다.")

	var sprite := rig.wave.get_child(0) as Sprite2D
	_expect(sprite != null, "파동 스프라이트가 만들어져 있어야 한다.")

	if sprite == null:
		_free_rig(rig)
		return

	_expect(sprite.top_level,
		"파동은 월드 고정이어야 한다. top_level이 꺼져 있으면 관리 노드를 따라 움직인다.")
	_expect(not sprite.z_as_relative,
		"z_as_relative가 켜져 있으면 부모 z에 묻혀 레이어 순서가 깨진다.")
	_expect(sprite.z_index == BallParryWave.Z_INDEX_WAVE,
		"스프라이트 z_index가 상수와 어긋난다.")

	_free_rig(rig)


# ── 도구 ────────────────────────────────────────────────────

func _make_rig(diameter: float) -> WaveRig:
	var rig := WaveRig.new()

	rig.holder = Node2D.new()
	root.add_child(rig.holder)

	# current_scene이 없는 헤드리스 테스트라 자동 연결 대신 직접 붙입니다.
	rig.wave = BallParryWave.new()
	rig.wave.auto_bind_parry = false
	rig.holder.add_child(rig.wave)

	rig.ball = FakeBall.new()
	rig.ball.set(&"ball_diameter", diameter)
	rig.ball.freeze = true
	rig.holder.add_child(rig.ball)

	rig.flipper = FakeFlipper.new()
	rig.holder.add_child(rig.flipper)
	rig.wave.bind_to_flipper(rig.flipper)

	await process_frame
	return rig


func _free_rig(rig: WaveRig) -> void:
	rig.holder.queue_free()


func _wait_process_frame() -> float:
	await process_frame
	return root.get_process_delta_time()


func _expect_in_range(value: float, range_pair: Vector2, label: String) -> void:
	_expect(
		value >= range_pair.x - FLOAT_EPSILON and value <= range_pair.y + FLOAT_EPSILON,
		"%s가 가이드 권장 범위를 벗어났다. (range=%.3f~%.3f, actual=%.3f)"
			% [label, range_pair.x, range_pair.y, value]
	)


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= PX_TOLERANCE,
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ball_parry_wave_test")
		quit(0)
		return

	print("FAIL: ball_parry_wave_test (%d failures)" % _failures.size())
	quit(1)
