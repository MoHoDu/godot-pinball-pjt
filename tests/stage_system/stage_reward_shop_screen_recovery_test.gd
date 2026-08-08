extends SceneTree


## 보상 상점 초기화가 실패해도 빈 회색 화면에 갇히지 않고 다음 단계로
## 진행할 수 있는 복구 화면을 제공하는지 검증합니다.


var _failures: Array[String] = []
var _completed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var screen := StageRewardShopScreen.new()
	screen.stage_id = &"invalid_stage_id"
	var wallet := CoinWallet.new()
	var ball_inventory := StageBallInventory.new()
	var part_inventory := RepairPartInventory.new()
	_expect(
		screen.bind_stage_reward_runtime(
			wallet, ball_inventory, part_inventory
		),
		"복구 테스트용 스테이지 런타임을 트리 진입 전에 연결해야 한다."
	)
	screen.configure_reward(0, 3, "다음 웨이브")
	screen.reward_completed.connect(func() -> void: _completed = true)
	root.add_child(screen)
	await process_frame

	var recovery := screen.get_node_or_null(
		^"RewardRecoveryOverlay"
	) as Control
	var continue_button := screen.get_node_or_null(
		^"RewardRecoveryOverlay/Center/Content/ContinueButton"
	) as Button
	_expect(
		recovery != null and recovery.visible,
		"보상 목록을 열지 못하면 사용자에게 복구 화면을 보여야 한다."
	)
	_expect(
		continue_button != null,
		"복구 화면에는 다음 단계로 진행하는 버튼이 있어야 한다."
	)
	_expect(
		screen.continue_stage() and _completed,
		"복구 화면에서도 보상 완료 시그널을 통해 다음 단계로 진행해야 한다."
	)
	_expect(
		not screen.continue_stage(),
		"복구 진행은 중복 완료 시그널을 발생시키면 안 된다."
	)

	screen.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_reward_shop_screen_recovery_test")
		quit(0)
		return
	print(
		"FAIL: stage_reward_shop_screen_recovery_test (%d failures)"
		% _failures.size()
	)
	quit(1)
