extends SceneTree
## 특수 공(보상 공 5종) 가시성·크기 통일 검증.
##
## 1) 크기 — 5종 전부 기본 공과 같은 지름 64px, 충돌 지름 57.6px이어야 한다.
##    (완충 젤이 dead_ball의 34px를 상속해 절반 크기로 나오던 문제 회귀 방지)
## 2) 가시성 — 5종 전부 공별 발광 테두리·이동 꼬리 프리셋이 연결되어
##    기본 청록이 아닌 공별 색 정체성으로 그려져야 한다.


const EXPECTED_DIAMETER := 64.0
const EXPECTED_COLLISION_DIAMETER := 57.6
const EPSILON := 0.001

const BASE_GLOW_RULES_PATH := "res://settings/balls/BallGlowOutlineRules.tres"
const BASE_TRAIL_RULES_PATH := "res://settings/balls/BallTrailRules.tres"

const BALL_CASES: Array[Dictionary] = [
	{
		&"name": &"clockwork_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn",
		&"glow_rules_path": "res://settings/balls/glow/BallGlowOutlineRules_Clockwork.tres",
		&"trail_rules_path": "res://settings/balls/trail/BallTrailRules_Clockwork.tres",
	},
	{
		&"name": &"rubber_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn",
		&"glow_rules_path": "res://settings/balls/glow/BallGlowOutlineRules_Rubber.tres",
		&"trail_rules_path": "res://settings/balls/trail/BallTrailRules_Rubber.tres",
	},
	{
		&"name": &"gel_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn",
		&"glow_rules_path": "res://settings/balls/glow/BallGlowOutlineRules_Gel.tres",
		&"trail_rules_path": "res://settings/balls/trail/BallTrailRules_Gel.tres",
	},
	{
		&"name": &"lead_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/lead_ball.tscn",
		&"glow_rules_path": "res://settings/balls/glow/BallGlowOutlineRules_Lead.tres",
		&"trail_rules_path": "res://settings/balls/trail/BallTrailRules_Lead.tres",
	},
	{
		&"name": &"hollow_bell_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/hollow_bell_ball.tscn",
		&"glow_rules_path": "res://settings/balls/glow/BallGlowOutlineRules_HollowBell.tres",
		&"trail_rules_path": "res://settings/balls/trail/BallTrailRules_HollowBell.tres",
	},
]


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for ball_case: Dictionary in BALL_CASES:
		await _test_ball_case(ball_case)
	_finish()


func _test_ball_case(ball_case: Dictionary) -> void:
	var ball_name := StringName(ball_case[&"name"])
	var packed_scene := load(String(ball_case[&"scene_path"])) as PackedScene
	_expect(packed_scene != null and packed_scene.can_instantiate(), \
		"%s 씬을 불러올 수 있어야 한다." % ball_name)
	if packed_scene == null:
		return

	var ball := packed_scene.instantiate() as Pinball
	_expect(ball != null, "%s 씬의 루트는 Pinball이어야 한다." % ball_name)
	if ball == null:
		return

	root.add_child(ball)
	await process_frame

	_test_unified_size(ball, ball_name)
	_test_identity_vfx_presets(ball, ball_case, ball_name)
	_test_pupil_sprite_contract(ball, ball_name)

	ball.queue_free()
	await process_frame


func _test_unified_size(ball: Pinball, ball_name: StringName) -> void:
	_expect_float(ball.ball_diameter, EXPECTED_DIAMETER, \
		"%s 지름은 기본 공과 같은 64px로 통일되어야 한다." % ball_name)
	_expect_float(ball.get_collision_diameter(), EXPECTED_COLLISION_DIAMETER, \
		"%s 충돌 지름은 57.6px로 통일되어야 한다." % ball_name)

	var sprite := ball.get_node_or_null("Visual/Sprite2D") as Sprite2D
	_expect(sprite != null and sprite.texture != null, \
		"%s는 Visual/Sprite2D에 본체 텍스처가 있어야 한다." % ball_name)
	if sprite != null and sprite.texture != null:
		var rendered_size := sprite.texture.get_size() * sprite.scale.abs()
		_expect_float(maxf(rendered_size.x, rendered_size.y), EXPECTED_DIAMETER, \
			"%s 표시 크기는 지름 64px와 일치해야 한다." % ball_name)

	var collision := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_expect(collision != null and collision.shape is CircleShape2D, \
		"%s는 CircleShape2D 충돌 노드가 있어야 한다." % ball_name)
	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		var effective_diameter := (
			circle.radius
			* 2.0
			* maxf(absf(collision.scale.x), absf(collision.scale.y))
		)
		_expect_float(effective_diameter, EXPECTED_COLLISION_DIAMETER, \
			"%s 실제 충돌 셰이프 지름도 57.6px여야 한다." % ball_name)


func _test_identity_vfx_presets(
	ball: Pinball,
	ball_case: Dictionary,
	ball_name: StringName
) -> void:
	var glow := ball.get_node_or_null("_GlowOutline") as BallGlowOutline
	_expect(glow != null, "%s는 _GlowOutline 노드가 있어야 한다." % ball_name)
	if glow != null:
		var glow_rules := glow.outline_rules
		var expected_glow_path := String(ball_case[&"glow_rules_path"])
		_expect(glow_rules != null \
			and glow_rules.resource_path == expected_glow_path, \
			"%s 발광 테두리는 공별 프리셋(%s)을 써야 한다. (actual=%s)" % [
				ball_name,
				expected_glow_path,
				glow_rules.resource_path if glow_rules != null else "null",
			])
		_expect(glow_rules == null \
			or glow_rules.resource_path != BASE_GLOW_RULES_PATH, \
			"%s 발광 테두리가 기본 공용 프리셋에 남아 있으면 안 된다." % ball_name)

	var trail := ball.get_node_or_null("_Trail") as BallTrail
	_expect(trail != null, "%s는 _Trail 노드가 있어야 한다." % ball_name)
	if trail != null:
		var trail_rules := trail.trail_rules
		var expected_trail_path := String(ball_case[&"trail_rules_path"])
		_expect(trail_rules != null \
			and trail_rules.resource_path == expected_trail_path, \
			"%s 이동 꼬리는 공별 프리셋(%s)을 써야 한다. (actual=%s)" % [
				ball_name,
				expected_trail_path,
				trail_rules.resource_path if trail_rules != null else "null",
			])
		_expect(trail_rules == null \
			or trail_rules.resource_path != BASE_TRAIL_RULES_PATH, \
			"%s 이동 꼬리가 기본 공용 프리셋에 남아 있으면 안 된다." % ball_name)


func _test_pupil_sprite_contract(ball: Pinball, ball_name: StringName) -> void:
	var pupil := ball.get_node_or_null("Visual/Sprite2D/PupilSprite") as Sprite2D
	_expect(pupil != null and pupil.texture != null, \
		"%s는 본체 위에 동공 스프라이트가 있어야 한다." % ball_name)
	if pupil != null:
		_expect(pupil.scale.is_equal_approx(Vector2.ONE), \
			"%s 동공은 본체 스케일을 그대로 상속해야 한다. (actual=%s)" % [
				ball_name,
				pupil.scale,
			])


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: reward_ball_visual_unify_test")
		quit(0)
		return

	print("FAIL: reward_ball_visual_unify_test (%d failures)" % _failures.size())
	quit(1)
