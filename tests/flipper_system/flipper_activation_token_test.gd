extends SceneTree


const CONTROLLER_SCENE_PATH := \
	"res://Resources/flippers/flipper/flipper_controller_sample.tscn"
const LEFT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_left.tscn"
const RIGHT_FLIPPER_SCENE_PATH := \
	"res://Resources/flippers/sub_flipper/normal_flipper_right.tscn"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_controller_shares_one_activation_token()
	await _test_direct_activation_issues_independent_tokens()
	_finish()


func _test_controller_shares_one_activation_token() -> void:
	var packed_scene := load(CONTROLLER_SCENE_PATH) as PackedScene
	_expect(packed_scene != null, "공유 작동 토큰을 검증할 컨트롤러 씬이 필요하다.")
	if packed_scene == null:
		return

	var controller := packed_scene.instantiate() as FlipperController
	root.add_child(controller)
	await process_frame
	_expect(controller.flippers.size() == 2, \
		"공유 토큰 테스트에는 한 컨트롤러의 플리퍼 두 개가 필요하다.")
	if controller.flippers.size() == 2:
		controller.play_all_flippers()
		var first_token := controller.flippers[0].get_current_activation_token()
		var second_token := controller.flippers[1].get_current_activation_token()
		_expect(first_token > 0, "컨트롤러 작동은 유효한 토큰을 발급해야 한다.")
		_expect(first_token == second_token, \
			"같이 작동한 두 플리퍼는 동일한 작동 토큰을 공유해야 한다.")

	controller.queue_free()
	await process_frame


func _test_direct_activation_issues_independent_tokens() -> void:
	var left_scene := load(LEFT_FLIPPER_SCENE_PATH) as PackedScene
	var right_scene := load(RIGHT_FLIPPER_SCENE_PATH) as PackedScene
	_expect(left_scene != null and right_scene != null, \
		"독립 작동 토큰을 검증할 플리퍼 씬이 필요하다.")
	if left_scene == null or right_scene == null:
		return

	var left := left_scene.instantiate() as PinballFlipper
	var right := right_scene.instantiate() as PinballFlipper
	root.add_child(left)
	root.add_child(right)
	await process_frame
	_expect(left.request_activation(), "왼쪽 플리퍼를 직접 작동할 수 있어야 한다.")
	_expect(right.request_activation(), "오른쪽 플리퍼를 직접 작동할 수 있어야 한다.")
	var left_token := left.get_current_activation_token()
	var right_token := right.get_current_activation_token()
	_expect(left_token > 0 and right_token > 0, \
		"직접 작동도 각각 유효한 토큰을 받아야 한다.")
	_expect(left_token != right_token, \
		"서로 독립적으로 작동한 플리퍼는 토큰을 공유하면 안 된다.")
	var token_before_rejected_request := left.get_current_activation_token()
	_expect(not left.request_activation(), \
		"이미 작동 중인 플리퍼의 중복 작동 요청은 거절되어야 한다.")
	_expect(left.get_current_activation_token() == token_before_rejected_request, \
		"거절된 작동 요청은 현재 토큰을 바꾸면 안 된다.")

	left.queue_free()
	right.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flipper_activation_token_test")
		quit(0)
		return
	print("FAIL: flipper_activation_token_test (%d failures)" % _failures.size())
	quit(1)
