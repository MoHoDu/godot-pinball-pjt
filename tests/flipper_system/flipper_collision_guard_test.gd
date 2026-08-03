extends SceneTree


const GUARD_SCRIPT_PATH := \
	"res://scripts/flipper_system/parrying/flipper_collision_guard.gd"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var guard_script := load(GUARD_SCRIPT_PATH) as Script
	_expect(guard_script != null, "동일 충돌 중복 적용 방지 스크립트가 필요하다.")
	if guard_script == null:
		_finish()
		return

	var left_guard := guard_script.new() as RefCounted
	var right_guard := guard_script.new() as RefCounted
	var first_ball := RigidBody2D.new()
	var second_ball := RigidBody2D.new()
	var test_frame := 120
	var first_activation_token := 41
	var second_activation_token := 42

	_expect(not bool(left_guard.call(
		&"was_resolved_this_physics_frame",
		first_ball,
		test_frame
	)), "처리 전 공은 현재 프레임 충돌 잠금 상태가 아니어야 한다.")
	left_guard.call(&"mark_resolved", first_ball, test_frame)
	_expect(bool(right_guard.call(
		&"was_resolved_this_physics_frame",
		first_ball,
		test_frame
	)), "왼쪽 플리퍼가 기록한 공 잠금을 오른쪽 플리퍼도 공유해야 한다.")
	_expect(not bool(right_guard.call(
		&"was_resolved_this_physics_frame",
		first_ball,
		test_frame + 1
	)), "다음 물리 프레임에는 같은 공을 다시 충돌 처리할 수 있어야 한다.")
	_expect(not bool(right_guard.call(
		&"was_resolved_this_physics_frame",
		second_ball,
		test_frame
	)), "한 공의 충돌 잠금이 다른 공의 충돌까지 막으면 안 된다.")

	left_guard.call(
		&"mark_parry_reported",
		first_ball,
		first_activation_token
	)
	_expect(bool(right_guard.call(
		&"was_parry_reported_for_activation",
		first_ball,
		first_activation_token
	)), "한 플리퍼가 처리한 작동 토큰을 다른 플리퍼도 공유해야 한다.")
	_expect(not bool(right_guard.call(
		&"was_parry_reported_for_activation",
		first_ball,
		second_activation_token
	)), "새로운 작동 토큰은 같은 공을 다시 처리할 수 있어야 한다.")
	_expect(not bool(right_guard.call(
		&"was_parry_reported_for_activation",
		second_ball,
		first_activation_token
	)), "한 공의 작동 잠금이 다른 공까지 막으면 안 된다.")

	first_ball.free()
	second_ball.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_collision_guard_test")
		quit(0)
		return
	print("FAIL: flipper_collision_guard_test (%d failures)" % _failures.size())
	quit(1)
