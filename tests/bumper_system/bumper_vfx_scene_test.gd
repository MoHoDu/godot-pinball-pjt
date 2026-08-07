extends SceneTree
## VFX 를 얹은 상속 씬 검증.
##
## 원본 씬은 수정하지 않고 상속 씬에서 `_HitFeedback` 자식만 얹는 구조다.
## 확인하는 것:
## - 상속 씬이 열리고 VFX 노드가 붙어 있는가
## - 타입별로 맞는 피드백 스크립트와 규칙이 물려 있는가
## - `_ready()` 의 자동 바인딩으로 범퍼 시그널이 실제로 연결되는가
## - 원본 씬은 VFX 없이 그대로인가 (직접 수정 금지 규칙)
##
## 실행:
##   godot --headless --path . --script res://tests/bumper_system/bumper_vfx_scene_test.gd


const FEEDBACK_NODE := ^"_HitFeedback"

# (상속 씬, 원본 씬, 기대 피드백 클래스, 기대 규칙 클래스)
const CASES := [
	[
		"res://scenes/bumper_system/vfx/button_bumper_vfx.tscn",
		"res://scenes/bumper_system/button_bumper.tscn",
		"BumperHitFeedback", "BumperVfxRules",
	],
	[
		"res://scenes/bumper_system/vfx/cotton_bumper_vfx.tscn",
		"res://scenes/bumper_system/cotton_bumper.tscn",
		"BumperHitFeedback", "BumperVfxRules",
	],
	[
		"res://scenes/bumper_system/vfx/spring_doll_bumper_vfx.tscn",
		"res://scenes/bumper_system/spring_doll_bumper.tscn",
		"BumperBounceFeedback", "BumperBounceVfxRules",
	],
	[
		"res://scenes/bumper_system/vfx/toy_drum_bumper_vfx.tscn",
		"res://scenes/bumper_system/toy_drum_bumper.tscn",
		"BumperBounceFeedback", "BumperBounceVfxRules",
	],
	[
		"res://scenes/bumper_system/vfx/clockwork_toy_cannon_vfx.tscn",
		"res://scenes/bumper_system/clockwork_toy_cannon.tscn",
		"BumperShotFeedback", "BumperShotVfxRules",
	],
]


var _failures: Array[String] = []
var _root: Node2D


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_root = Node2D.new()
	root.add_child(_root)
	await process_frame

	for case: Array in CASES:
		await _check_case(
			String(case[0]), String(case[1]), String(case[2]), String(case[3])
		)
	await _check_combined_lab()

	_finish()


## 범퍼 5종 + 수리 부품 3종을 한 씬에서 보는 통합 검수 씬.
func _check_combined_lab() -> void:
	const LAB := "res://scenes/bumper_system/vfx/all_parts_vfx_test.tscn"
	var packed := load(LAB) as PackedScene
	_expect(packed != null, "%s 를 열 수 있어야 한다" % LAB)
	if packed == null:
		return

	var lab := packed.instantiate()
	_root.add_child(lab)
	await process_frame

	var scenes: Array = lab.get(&"bumper_scenes")
	_expect(scenes.size() == 8,
		"통합 검수 씬에 8종이 등록돼야 한다 (실제=%d)" % scenes.size())
	for entry in scenes:
		_expect(entry != null, "등록된 씬에 빈 항목이 있으면 안 된다")

	lab.queue_free()
	await process_frame


func _check_case(
	vfx_path: String,
	origin_path: String,
	feedback_class: String,
	rules_class: String
) -> void:
	var packed := load(vfx_path) as PackedScene
	_expect(packed != null, "%s 를 열 수 있어야 한다" % vfx_path)
	if packed == null:
		return

	var bumper := packed.instantiate() as Bumper
	_expect(bumper != null, "%s 의 루트가 Bumper 여야 한다" % vfx_path)
	if bumper == null:
		return

	bumper.global_position = Vector2(300.0, 300.0)
	_root.add_child(bumper)
	await process_frame
	await process_frame

	var feedback := bumper.get_node_or_null(FEEDBACK_NODE)
	_expect(feedback != null, "%s 에 %s 노드가 있어야 한다" % [vfx_path, FEEDBACK_NODE])
	if feedback == null:
		bumper.queue_free()
		return

	_expect(feedback.is_class("Node2D"), "VFX 노드는 Node2D 여야 한다")
	_expect(feedback.get_script() != null, "VFX 노드에 스크립트가 물려 있어야 한다")

	var script_path := String((feedback.get_script() as Script).resource_path)
	_expect(script_path.contains(_expected_script_file(feedback_class)),
		"%s 는 %s 를 써야 한다 (실제=%s)" % [vfx_path, feedback_class, script_path])

	var rules: Resource = feedback.get(&"rules")
	_expect(rules != null, "%s 에 VFX 규칙이 물려 있어야 한다" % vfx_path)
	if rules != null:
		var rules_path := String((rules.get_script() as Script).resource_path)
		_expect(rules_path.contains(_expected_rules_file(rules_class)),
			"%s 규칙이 %s 여야 한다 (실제=%s)" % [vfx_path, rules_class, rules_path])

	# 아트 스프라이트. 범퍼에 텍스처 슬롯이 없어 상속 씬에서 Sprite2D 로 얹는다.
	# 북만 북막/북틀 2레이어다 (기획서 34쪽). 나머지는 한 장이다.
	var sprites: Array[Sprite2D] = []
	for sprite_name in [^"_ArtSprite", ^"_ArtSpriteHead", ^"_ArtSpriteFrame"]:
		var found := bumper.get_node_or_null(sprite_name) as Sprite2D
		if found != null:
			sprites.append(found)
	_expect(not sprites.is_empty(), "%s 에 아트 스프라이트가 있어야 한다" % vfx_path)

	var expected: float = bumper.settings.visual_diameter
	for sprite in sprites:
		_expect(sprite.texture != null, "아트 스프라이트에 텍스처가 물려 있어야 한다")
		if sprite.texture == null:
			continue
		# 표시 지름 = 텍스처 긴 변 * scale. 설정값과 어긋나면 충돌 크기와 안 맞는다.
		var long_side := float(maxi(
			sprite.texture.get_width(), sprite.texture.get_height()
		))
		_expect(absf(long_side * sprite.scale.x - expected) <= 1.0,
			"%s / %s 표시 지름이 설정과 맞아야 한다 (기대=%s, 실제=%s)"
				% [vfx_path, sprite.name, expected, long_side * sprite.scale.x])

	# 2레이어면 북막이 북틀 아래에 그려져야 이음매가 안 드러난다.
	var head := bumper.get_node_or_null(^"_ArtSpriteHead") as Sprite2D
	var frame := bumper.get_node_or_null(^"_ArtSpriteFrame") as Sprite2D
	if head != null or frame != null:
		_expect(head != null and frame != null,
			"%s 는 북막과 북틀이 둘 다 있어야 한다" % vfx_path)
		if head != null and frame != null:
			_expect(frame.z_index > head.z_index,
				"북틀이 북막보다 위에 그려져야 한다 (북막 z=%d, 북틀 z=%d)"
					% [head.z_index, frame.z_index])
			_expect(head.scale.is_equal_approx(frame.scale),
				"두 레이어는 같은 캔버스 정렬이라 scale 이 같아야 한다")

	# 프로시저럴 도형은 꺼야 아트와 겹치지 않는다.
	var visual := bumper.get_node_or_null(^"Visual") as Node2D
	_expect(visual != null and not visual.visible,
		"%s 의 프로시저럴 Visual 은 꺼져 있어야 한다" % vfx_path)

	# `_ready()` 의 자동 바인딩이 실제로 걸렸는지 본다.
	_expect(bumper.valid_hit_registered.get_connections().size() > 0,
		"%s 의 타격 시그널이 VFX 에 연결돼야 한다" % vfx_path)
	_expect(bumper.state_changed.get_connections().size() > 0,
		"%s 의 상태 시그널이 VFX 에 연결돼야 한다" % vfx_path)

	# 원본 씬은 VFX 없이 그대로여야 한다.
	var origin_packed := load(origin_path) as PackedScene
	_expect(origin_packed != null, "%s 를 열 수 있어야 한다" % origin_path)
	if origin_packed != null:
		var origin := origin_packed.instantiate() as Bumper
		_root.add_child(origin)
		await process_frame
		_expect(origin.get_node_or_null(FEEDBACK_NODE) == null,
			"원본 씬 %s 에는 VFX 노드가 없어야 한다 (직접 수정 금지)" % origin_path)
		origin.queue_free()

	bumper.queue_free()
	await process_frame


func _expected_script_file(feedback_class: String) -> String:
	match feedback_class:
		"BumperBounceFeedback":
			return "bumper_bounce_feedback.gd"
		"BumperShotFeedback":
			return "bumper_shot_feedback.gd"
		_:
			return "bumper_hit_feedback.gd"


func _expected_rules_file(rules_class: String) -> String:
	match rules_class:
		"BumperBounceVfxRules":
			return "bumper_bounce_vfx_rules.gd"
		"BumperShotVfxRules":
			return "bumper_shot_vfx_rules.gd"
		_:
			return "bumper_vfx_rules.gd"


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_vfx_scene_test")
		quit(0)
		return
	print("FAIL: bumper_vfx_scene_test (%d failures)" % _failures.size())
	quit(1)
