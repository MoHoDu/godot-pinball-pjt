extends SceneTree
## 특수 공 검수 씬(test_special_ball_visual.tscn) 스모크 테스트.
##
## 검수 씬이 보여주는 것이 프로덕션 상태 그대로인지 확인합니다.
## 1) 비교 그룹 6종(기본+특수 5종)이 오버라이드 없이 전부 64px인지
## 2) 특수 공 5종에 공별 발광 프리셋이 연결돼 있는지
## 3) 숫자키 로스터가 특수 공 씬을 띄우는지


const SCENE_PATH := "res://scenes/tests/balls/test_special_ball_visual.tscn"
const EXPECTED_DIAMETER := 64.0
const EPSILON := 0.001

const ROSTER_SCENE_PATHS: Array[String] = [
	"res://Resources/Prefabs/balls/base/base_ball.tscn",
	"res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn",
	"res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn",
	"res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn",
	"res://Resources/Prefabs/balls/variants/reward/lead_ball.tscn",
	"res://Resources/Prefabs/balls/variants/reward/hollow_bell_ball.tscn",
]

const COMPARISON_GLOW_PATHS: Dictionary = {
	&"BaseBall": "res://settings/balls/BallGlowOutlineRules.tres",
	&"ClockworkBall": "res://settings/balls/glow/BallGlowOutlineRules_Clockwork.tres",
	&"RubberBall": "res://settings/balls/glow/BallGlowOutlineRules_Rubber.tres",
	&"GelBall": "res://settings/balls/glow/BallGlowOutlineRules_Gel.tres",
	&"LeadBall": "res://settings/balls/glow/BallGlowOutlineRules_Lead.tres",
	&"HollowBellBall": "res://settings/balls/glow/BallGlowOutlineRules_HollowBell.tres",
}


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_scene_wiring_and_comparison_group()
	await _test_roster_switches_special_balls()
	_finish()


func _test_scene_wiring_and_comparison_group() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	_expect(root_node.get_node_or_null("BallSwitchGuide/Panel/GuideLabel") is Label,
		"조작 안내 라벨이 있어야 한다.")
	_expect(root_node.get_node_or_null("FocusBall") != null,
		"집중 모드 공을 담을 FocusBall 홀더가 만들어져야 한다.")

	var group := root_node.get_node_or_null("Balls") as Node2D
	_expect(group != null, "비교용 공 그룹(Balls)이 있어야 한다.")
	if group == null:
		_free_scene(root_node)
		return

	_expect(group.get_child_count() == COMPARISON_GLOW_PATHS.size(),
		"비교 그룹에는 기본 공 + 특수 공 5종이 있어야 한다.")

	for child in group.get_children():
		var ball := child as Pinball
		_expect(ball != null, "%s는 Pinball이어야 한다." % child.name)
		if ball == null:
			continue

		_expect(absf(ball.ball_diameter - EXPECTED_DIAMETER) <= EPSILON,
			"%s 비교 공은 오버라이드 없이 프로덕션 크기 64px여야 한다. (actual=%s)"
			% [ball.name, ball.ball_diameter])

		var expected_glow: String = COMPARISON_GLOW_PATHS.get(child.name, "")
		_expect(not expected_glow.is_empty(),
			"%s는 검수 대상 목록에 있는 이름이어야 한다." % child.name)

		var glow := ball.get_node_or_null("_GlowOutline") as BallGlowOutline
		_expect(glow != null and glow.outline_rules != null \
			and glow.outline_rules.resource_path == expected_glow,
			"%s 발광 프리셋은 %s여야 한다. (actual=%s)" % [
				child.name,
				expected_glow,
				glow.outline_rules.resource_path if (
					glow != null and glow.outline_rules != null
				) else "null",
			])

	_free_scene(root_node)


func _test_roster_switches_special_balls() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	_expect(root_node.get_selected_index() == 0, "시작 시 1번(기본 공)이 선택되어야 한다.")

	for index in ROSTER_SCENE_PATHS.size():
		root_node.select_ball_type(index)
		await physics_frame
		await physics_frame

		var focus: Pinball = root_node.get_focus_ball()
		_expect(focus != null, "%d번 선택 시 집중 공이 떠야 한다." % (index + 1))
		if focus == null:
			continue

		_expect(focus.scene_file_path == ROSTER_SCENE_PATHS[index],
			"%d번 키는 %s를 띄워야 한다. (actual=%s)" % [
				index + 1,
				ROSTER_SCENE_PATHS[index],
				focus.scene_file_path,
			])
		_expect(absf(focus.ball_diameter - EXPECTED_DIAMETER) <= EPSILON,
			"%d번 집중 공은 64px로 떠야 한다. (actual=%s)"
			% [index + 1, focus.ball_diameter])

	# 로스터 밖 인덱스는 무시해야 한다
	var last_index := ROSTER_SCENE_PATHS.size() - 1
	root_node.select_ball_type(ROSTER_SCENE_PATHS.size())
	await physics_frame
	_expect(root_node.get_selected_index() == last_index,
		"없는 번호를 누르면 선택이 바뀌지 않아야 한다.")

	root_node.show_comparison()
	await physics_frame
	_expect(root_node.get_selected_index() == -1, "0번은 비교 모드로 돌아가야 한다.")
	_expect(root_node.get_focus_ball() == null, "비교 모드에서는 집중 공이 없어야 한다.")

	_free_scene(root_node)


func _make_scene() -> Node2D:
	var packed_scene := load(SCENE_PATH) as PackedScene
	_expect(packed_scene != null and packed_scene.can_instantiate(),
		"특수 공 검수 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		return null

	var root_node := packed_scene.instantiate() as Node2D
	_expect(root_node != null, "검수 씬 루트는 Node2D여야 한다.")
	if root_node == null:
		return null

	root.add_child(root_node)
	await physics_frame
	await physics_frame
	return root_node


func _free_scene(root_node: Node2D) -> void:
	root_node.queue_free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	await process_frame
	if _failures.is_empty():
		print("PASS: test_special_ball_visual_scene_test")
		quit(0)
		return

	print("FAIL: test_special_ball_visual_scene_test (%d failures)" % _failures.size())
	quit(1)
