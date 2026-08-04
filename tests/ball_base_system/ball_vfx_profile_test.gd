extends SceneTree
## BallVfxProfile — 공별 VFX·그림 묶음이 실제로 공에 먹는지 확인합니다.
##
## 이 테스트가 지키려는 것은 하나입니다.
## **프로필을 갈아끼우면 화면이 실제로 달라진다.**
## 프로필 파일만 있고 아무 데도 안 꽂혀 있으면 "만들었다"고 말할 수 없습니다.

const BALL_SCENE_PATH := "res://Resources/balls/base/base_ball.tscn"
const PROFILE_DIR := "res://settings/balls/vfx/"
const BALL_KEYS: Array[String] = ["Clockwork", "Rubber", "Gel", "Lead", "HollowBell"]

## 기획서 기준 실제 게임 크기입니다.
const DOC_BALL_DIAMETER := 44.0
const FLOAT_EPSILON := 0.001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_profiles_load()
	_test_profiles_are_distinct()
	await _test_no_profile_keeps_defaults()
	await _test_profile_overrides_rules()
	await _test_profile_swaps_body_art()
	await _test_pupil_sprite_matches_body_scale()
	await _test_scene_rules_beat_profile()
	await _test_clearing_profile_removes_pupil()
	_finish()


# ── 리소스 ─────────────────────────────────────────────────

func _test_profiles_load() -> void:
	for key in BALL_KEYS:
		var profile := load(PROFILE_DIR + "BallVfxProfile_%s.tres" % key) as BallVfxProfile
		_expect(profile != null, "%s 프로필을 불러올 수 있어야 한다." % key)

		if profile == null:
			continue

		_expect(
			profile.get_missing_slots().is_empty(),
			"%s 프로필에 빈 슬롯이 없어야 한다. 빈 슬롯: %s"
			% [key, ", ".join(profile.get_missing_slots())]
		)
		_expect(profile.has_body_art(), "%s 프로필에 공 껍질 그림이 있어야 한다." % key)
		_expect(profile.has_any_rules(), "%s 프로필에 규칙이 있어야 한다." % key)
		_expect(not String(profile.ball_id).is_empty(), "%s 프로필에 ball_id가 있어야 한다." % key)


## 5종이 서로 달라야 합니다. 같으면 갈아끼워도 플레이어 눈에 아무 차이가 없습니다.
func _test_profiles_are_distinct() -> void:
	var seen_ids: Dictionary = {}
	var seen_bodies: Dictionary = {}
	var seen_colors: Dictionary = {}

	for key in BALL_KEYS:
		var profile := load(PROFILE_DIR + "BallVfxProfile_%s.tres" % key) as BallVfxProfile
		if profile == null:
			continue

		seen_ids[profile.ball_id] = true
		if profile.body_texture != null:
			seen_bodies[profile.body_texture.resource_path] = true
		if profile.trail_rules != null:
			seen_colors[profile.trail_rules.bloom_mid] = true

	_expect(seen_ids.size() == BALL_KEYS.size(), "ball_id가 5종 모두 달라야 한다.")
	_expect(seen_bodies.size() == BALL_KEYS.size(), "공 껍질 그림이 5종 모두 달라야 한다.")
	_expect(seen_colors.size() == BALL_KEYS.size(), "꼬리 색이 5종 모두 달라야 한다.")


# ── 공에 붙였을 때 ──────────────────────────────────────────

func _test_no_profile_keeps_defaults() -> void:
	var ball := await _spawn_ball(null)
	if ball == null:
		return

	var trail := ball.get_node_or_null(^"_Trail") as BallTrail
	var default_trail := load("res://settings/balls/BallTrailRules.tres") as BallTrailRules
	_expect(
		trail != null and trail.trail_rules == default_trail,
		"프로필이 없으면 기본 꼬리 규칙을 써야 한다."
	)

	var sprite := ball.get_node_or_null("Visual/Sprite2D") as Sprite2D
	_expect(
		sprite != null and sprite.get_node_or_null(^"PupilSprite") == null,
		"프로필이 없으면 동공 스프라이트를 만들지 않아야 한다."
	)

	ball.queue_free()


func _test_profile_overrides_rules() -> void:
	for key in BALL_KEYS:
		var profile := load(PROFILE_DIR + "BallVfxProfile_%s.tres" % key) as BallVfxProfile
		var ball := await _spawn_ball(profile)
		if ball == null or profile == null:
			continue

		var trail := ball.get_node_or_null(^"_Trail") as BallTrail
		var glow := ball.get_node_or_null(^"_GlowOutline") as BallGlowOutline
		_expect(
			trail != null and trail.trail_rules == profile.trail_rules,
			"%s: 꼬리 규칙이 프로필 것으로 바뀌어야 한다." % key
		)
		_expect(
			glow != null and glow.outline_rules == profile.glow_rules,
			"%s: 안개 규칙이 프로필 것으로 바뀌어야 한다." % key
		)

		ball.queue_free()


func _test_profile_swaps_body_art() -> void:
	for key in BALL_KEYS:
		var profile := load(PROFILE_DIR + "BallVfxProfile_%s.tres" % key) as BallVfxProfile
		var ball := await _spawn_ball(profile)
		if ball == null or profile == null:
			continue

		var sprite := ball.get_node_or_null("Visual/Sprite2D") as Sprite2D
		_expect(
			sprite != null and sprite.texture == profile.body_texture,
			"%s: 공 껍질 그림이 프로필 것으로 바뀌어야 한다." % key
		)

		var pupil: Sprite2D = null
		if sprite != null:
			pupil = sprite.get_node_or_null(^"PupilSprite") as Sprite2D
		_expect(
			pupil != null and pupil.texture == profile.pupil_texture,
			"%s: 동공 그림이 껍질 위에 얹혀야 한다." % key
		)

		ball.queue_free()


## 동공은 껍질의 자식이라 배율을 물려받아야 합니다.
## 따로 스케일하면 공 크기를 바꿀 때마다 눈만 어긋납니다.
func _test_pupil_sprite_matches_body_scale() -> void:
	var profile := load(PROFILE_DIR + "BallVfxProfile_Clockwork.tres") as BallVfxProfile
	var ball := await _spawn_ball(profile)
	if ball == null:
		return

	var sprite := ball.get_node_or_null("Visual/Sprite2D") as Sprite2D
	var pupil: Sprite2D = null
	if sprite != null:
		pupil = sprite.get_node_or_null(^"PupilSprite") as Sprite2D

	if pupil != null:
		_expect(
			pupil.scale.is_equal_approx(Vector2.ONE),
			"동공은 자체 배율 1이어야 한다 (껍질 배율을 물려받는다)."
		)
		_expect(
			pupil.position.is_equal_approx(Vector2.ZERO),
			"동공은 껍질과 같은 캔버스라 위치 보정이 필요 없어야 한다."
		)

	# 공 크기를 바꿔도 눈이 껍질을 따라가야 한다
	ball.ball_diameter = 88.0
	await process_frame
	var expected := 88.0 / maxf(sprite.texture.get_size().x, sprite.texture.get_size().y)
	_expect(
		absf(sprite.scale.x - expected) < FLOAT_EPSILON,
		"공 지름을 바꾸면 껍질 배율이 따라가야 한다."
	)

	ball.queue_free()


## 프로필은 "기본값 대체"입니다. 씬에서 직접 꽂은 값을 덮어쓰면
## 공 하나만 따로 손보는 길이 막힙니다.
func _test_scene_rules_beat_profile() -> void:
	var profile := load(PROFILE_DIR + "BallVfxProfile_Clockwork.tres") as BallVfxProfile
	var scene := load(BALL_SCENE_PATH) as PackedScene
	if profile == null or scene == null:
		return

	var ball := scene.instantiate() as Pinball
	var explicit := load("res://settings/balls/trail/BallTrailRules_Lead.tres") as BallTrailRules
	ball.vfx_profile = profile
	(ball.get_node(^"_Trail") as BallTrail).trail_rules = explicit

	root.add_child(ball)
	await process_frame

	_expect(
		(ball.get_node(^"_Trail") as BallTrail).trail_rules == explicit,
		"씬에서 직접 꽂은 규칙이 프로필보다 우선해야 한다."
	)

	ball.queue_free()


## 프로필을 비운 공으로 되돌렸을 때 앞 공의 동공이 남으면 안 됩니다.
func _test_clearing_profile_removes_pupil() -> void:
	var profile := load(PROFILE_DIR + "BallVfxProfile_Gel.tres") as BallVfxProfile
	var ball := await _spawn_ball(profile)
	if ball == null:
		return

	var sprite := ball.get_node_or_null("Visual/Sprite2D") as Sprite2D
	ball.vfx_profile = null
	ball.refresh_profile_art()
	await process_frame

	_expect(
		sprite != null and sprite.get_node_or_null(^"PupilSprite") == null,
		"프로필을 비우면 동공 스프라이트가 사라져야 한다."
	)

	ball.queue_free()


# ── 도구 ───────────────────────────────────────────────────

## 프로필은 add_child() **전에** 넣습니다. 연출 노드가 _ready()에서 한 번만 읽습니다.
func _spawn_ball(profile: BallVfxProfile) -> Pinball:
	var scene := load(BALL_SCENE_PATH) as PackedScene
	if scene == null:
		_expect(false, "공 씬을 불러올 수 있어야 한다.")
		return null

	var ball := scene.instantiate() as Pinball
	if ball == null:
		_expect(false, "공 씬의 루트가 Pinball이어야 한다.")
		return null

	ball.vfx_profile = profile
	ball.ball_diameter = DOC_BALL_DIAMETER
	root.add_child(ball)
	await process_frame

	return ball


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BallVfxProfile 테스트 통과")
		quit(0)
		return

	for failure in _failures:
		print("FAIL: %s" % failure)

	quit(1)
