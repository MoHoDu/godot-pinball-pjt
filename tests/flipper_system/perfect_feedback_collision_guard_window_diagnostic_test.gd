extends SceneTree


const GUARD_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_collision_guard.gd"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var guard_script := load(GUARD_SCRIPT_PATH) as Script
	_expect(guard_script != null, "CASE_GUARD_WINDOW: 충돌 가드가 필요하다.")
	if guard_script == null:
		_finish()
		return

	var first_flipper_guard := guard_script.new() as RefCounted
	var second_flipper_guard := guard_script.new() as RefCounted
	var ball := RigidBody2D.new()
	var first_frame := 500
	var activation_token := 700

	first_flipper_guard.call(&"mark_resolved", ball, first_frame)
	var blocked_same_frame := bool(second_flipper_guard.call(
		&"was_resolved_this_physics_frame",
		ball,
		first_frame
	))
	var blocked_next_frame := bool(second_flipper_guard.call(
		&"was_resolved_this_physics_frame",
		ball,
		first_frame + 1
	))
	first_flipper_guard.call(
		&"mark_parry_reported",
		ball,
		activation_token
	)
	var blocked_next_frame_for_activation := bool(second_flipper_guard.call(
		&"was_parry_reported_for_activation",
		ball,
		activation_token
	))

	_expect(blocked_same_frame, \
		"CASE_GUARD_WINDOW: 같은 프레임의 두 번째 플리퍼는 차단되어야 한다.")
	_expect(not blocked_next_frame, \
		"CASE_GUARD_WINDOW: 일반 물리 충돌은 다음 프레임에 다시 허용되어야 한다.")
	_expect(blocked_next_frame_for_activation, \
		"CASE_GUARD_WINDOW: 같은 작동 토큰의 패링 보고는 다음 프레임에도 차단되어야 한다.")
	print(("EVIDENCE CASE_GUARD_WINDOW same_frame_blocked=%s " \
		+ "next_frame_blocked=%s activation_next_frame_blocked=%s") % [
		blocked_same_frame,
		blocked_next_frame,
		blocked_next_frame_for_activation,
	])

	ball.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: perfect_feedback_collision_guard_window_diagnostic_test")
		quit(0)
		return
	print("FAIL: perfect_feedback_collision_guard_window_diagnostic_test (%d failures)" \
		% _failures.size())
	quit(1)
