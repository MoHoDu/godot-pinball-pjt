extends SceneTree


const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/Prefabs/flippers/variants/normal_flipper_left.tscn"
const GRADE_PERFECT := 2


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "CASE_CONNECTION: 왼쪽 플리퍼 씬이 필요하다.")
	if packed_scene == null:
		_finish()
		return

	var flipper := packed_scene.instantiate() as PinballFlipper
	root.add_child(flipper)
	await process_frame

	var feedback := flipper.get_node_or_null("_ParryFeedback") as Node2D
	_expect(feedback != null, "CASE_CONNECTION: 자동 피드백 노드가 필요하다.")
	if feedback == null:
		flipper.queue_free()
		await process_frame
		_finish()
		return

	feedback.call(&"bind_to_flipper", flipper)
	feedback.call(&"bind_to_flipper", flipper)
	flipper.call(&"_ensure_parry_feedback")

	var feedback_connections := 0
	for connection: Dictionary in flipper.get_signal_connection_list(&"parry_resolved"):
		var callable: Callable = connection.get(&"callable", Callable())
		if callable.is_valid() and callable.get_object() == feedback:
			feedback_connections += 1
	_expect(feedback_connections == 1, \
		"CASE_CONNECTION: 반복 bind 뒤 피드백 연결은 정확히 하나여야 한다. " \
		+ "(actual=%d)" % feedback_connections)

	var ball := RigidBody2D.new()
	flipper.parry_resolved.emit(
		ball,
		GRADE_PERFECT,
		Vector2(120.0, 80.0),
		0,
		0.02,
		1.18
	)
	_expect(_count_feedback_labels(feedback) == 1, \
		"CASE_CONNECTION: 신호 한 번은 Label 하나만 생성해야 한다.")

	print("EVIDENCE CASE_CONNECTION connections=%d labels_after_one_signal=%d" % [
		feedback_connections,
		_count_feedback_labels(feedback),
	])
	ball.free()
	flipper.queue_free()
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
		print("PASS: perfect_feedback_signal_connection_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_signal_connection_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
