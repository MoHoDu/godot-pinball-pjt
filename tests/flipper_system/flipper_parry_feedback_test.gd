extends SceneTree


const FEEDBACK_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_parry_feedback.gd"
const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_left.tscn"
const GRADE_NORMAL := 1
const GRADE_PERFECT := 2


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var feedback_script := load(FEEDBACK_SCRIPT_PATH) as Script
	_expect(feedback_script != null, "패링 결과를 보여줄 전용 피드백 스크립트가 필요하다.")
	if feedback_script == null:
		_finish()
		return

	var feedback := feedback_script.new() as Node2D
	_expect(feedback != null, "패링 피드백 노드를 생성할 수 있어야 한다.")
	if feedback != null:
		_test_feedback_levels(feedback)
		feedback.free()

	var packed_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "피드백 자동 연결을 확인할 플리퍼 씬이 필요하다.")
	if packed_scene != null:
		var flipper := packed_scene.instantiate() as PinballFlipper
		root.add_child(flipper)
		await process_frame
		var feedback_node := flipper.get_node_or_null("_ParryFeedback") as Node2D
		_expect(feedback_node != null, \
			"실행 중 플리퍼에는 패링 신호를 표시할 피드백 노드가 자동으로 연결되어야 한다.")
		if feedback_node != null:
			_expect(feedback_node.top_level, \
				"패링 문구는 회전하는 플리퍼의 자식 Transform을 따라 돌면 안 된다.")
		flipper.queue_free()
		await process_frame

	_finish()


func _test_feedback_levels(feedback: Node2D) -> void:
	var normal_text := String(feedback.call(&"get_feedback_text", GRADE_NORMAL))
	var perfect_text := String(feedback.call(&"get_feedback_text", GRADE_PERFECT))
	_expect(normal_text == "PARRY!", "일반 패링은 PARRY! 문구로 구분해야 한다.")
	_expect(perfect_text == "PERFECT!", "정확 패링은 PERFECT! 문구로 구분해야 한다.")

	var normal_color: Color = feedback.call(&"get_feedback_color", GRADE_NORMAL)
	var perfect_color: Color = feedback.call(&"get_feedback_color", GRADE_PERFECT)
	_expect(not normal_color.is_equal_approx(perfect_color), \
		"일반·정확 패링은 서로 다른 섬광 색으로 구분되어야 한다.")
	_expect(int(feedback.call(&"get_feedback_font_size", GRADE_PERFECT)) \
		> int(feedback.call(&"get_feedback_font_size", GRADE_NORMAL)), \
		"정확 패링 문구는 일반 패링보다 크게 보여야 한다.")
	_expect(float(feedback.call(&"get_feedback_duration", GRADE_PERFECT)) \
		> float(feedback.call(&"get_feedback_duration", GRADE_NORMAL)), \
		"정확 패링 섬광은 일반 패링보다 조금 더 오래 보여야 한다.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_parry_feedback_test")
		quit(0)
		return
	print("FAIL: flipper_parry_feedback_test (%d failures)" % _failures.size())
	quit(1)
