extends SceneTree


const FEEDBACK_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_parry_feedback.gd"
const GRADE_PERFECT := 2


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var feedback_script := load(FEEDBACK_SCRIPT_PATH) as Script
	_expect(feedback_script != null, "CASE_STACK: 피드백 스크립트가 필요하다.")
	if feedback_script == null:
		_finish()
		return

	var feedback := feedback_script.new() as Node2D
	root.add_child(feedback)
	feedback.call(&"play_feedback", GRADE_PERFECT, Vector2(200.0, 180.0))
	await process_frame
	feedback.call(&"play_feedback", GRADE_PERFECT, Vector2(204.0, 180.0))

	var label_count := _count_feedback_labels(feedback)
	_expect(label_count == 2, \
		"CASE_STACK: 짧은 간격의 유효 신호 두 번은 Label 두 개를 겹쳐 둔다. " \
		+ "(actual=%d)" % label_count)
	print("EVIDENCE CASE_STACK labels_after_two_calls=%d" % label_count)

	feedback.queue_free()
	await process_frame
	_finish()


func _count_feedback_labels(feedback: Node2D) -> int:
	var count := 0
	for child: Node in feedback.get_children():
		if child is Label:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: perfect_feedback_stack_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_stack_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
