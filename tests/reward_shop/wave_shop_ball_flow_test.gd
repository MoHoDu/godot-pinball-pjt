extends SceneTree


## 상점 구매 공이 다음 웨이브 선택지에 실제로 실리는지 씬으로 확인합니다.


const WAVE_SCENE := preload("res://scenes/wave/wave_shop_ball.tscn")

const HIT_WEIGHT := 20000.0
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveShopBallCoordinator
	scene.shop_random_seed = 20260804
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var inventory: WaveBallInventory = scene.wave_ball_inventory

	_expect(scene.stage_ball_inventory != null, "스테이지 공 인벤토리가 붙어야 한다.")
	var base_ids := _available_ids(inventory)
	_expect(base_ids == [&"normal"],
		"첫 웨이브 선택지는 기본 보통 공 1종이어야 한다. (%s)" % base_ids)

	# 코인을 채우고 웨이브를 이긴다.
	scene.coin_wallet.add(60)
	await _win_current_wave(scene)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "승리 후 상점이 열려야 한다.")

	# 살 수 있는 공 하나를 산다.
	var ball_index := -1
	for offer_index in scene.shop_controller.ball_offers.size():
		if scene.shop_controller.can_buy_ball(offer_index):
			ball_index = offer_index
			break
	_expect(ball_index >= 0, "살 수 있는 공이 있어야 한다.")
	var bought_ball: StringName = scene.shop_controller.ball_offers[ball_index].ball_id
	_expect(scene.shop_controller.buy_ball(ball_index), "공 구매가 성공해야 한다.")
	_expect(
		scene.stage_ball_inventory.unlocked_ids.has(bought_ball),
		"산 공이 스테이지 인벤토리에 해금되어야 한다."
	)

	# 진행 → 다음 웨이브. 산 공이 선택지에 실려야 한다.
	scene.shop_hud.proceed_requested.emit()
	await process_frame
	await process_frame
	_expect(wave_manager.current_wave_index == 1, "다음 웨이브로 진입해야 한다.")

	var next_ids := _available_ids(inventory)
	_expect(
		next_ids.has(bought_ball),
		"산 공 %s이 다음 웨이브 선택지에 있어야 한다. (%s)" % [bought_ball, next_ids]
	)
	_expect(next_ids.size() == 2, "기본 1종 + 해금 1종 = 2종이어야 한다.")

	# 실제로 그 공을 선택할 수 있어야 한다.
	_expect(
		inventory.select_ball(bought_ball),
		"해금한 공을 선택할 수 있어야 한다."
	)

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _available_ids(inventory: WaveBallInventory) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in inventory.get_available_definitions():
		ids.append(definition.ball_id)
	return ids


func _win_current_wave(scene: WaveShopBallCoordinator) -> void:
	var flow: WaveBallFlowController = scene.wave_ball_flow
	# main 이 도입한 수리 부품 배치 페이즈를 넘겨야 웨이브가 시작된다.
	# 인게임에서는 BoardWavePlacementBridge 가 배치 확정 시 호출하는 자리다.
	var phase := scene.wave_manager.current_stage_phase
	if phase == WaveManager.StagePhase.REPAIR_PLACEMENT:
		var placement_bridge := scene.get_node(
			"BoardWavePlacementBridge"
		) as BoardWavePlacementBridge
		_expect(placement_bridge.commit_placement(),
			"상점 공 데모도 초기 수리 배치 단계를 통과해야 한다.")
		await process_frame
	_send_action(flow, &"ball_select_confirm")
	var launched_ball := flow.active_ball
	_expect(scene.launcher.launch_prepared_ball(), "준비된 공이 발사되어야 한다.")
	scene.combo_system.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")
	await _wait_until(func() -> bool:
		return scene.wave_manager.current_state == WaveManager.State.WON
	)


func _wait_until(condition: Callable) -> void:
	for _frame in MAX_WAIT_FRAMES:
		if condition.call():
			return
		await process_frame


func _send_action(target: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_shop_ball_flow_test")
		quit(0)
		return
	print("FAIL: wave_shop_ball_flow_test (%d failures)" % _failures.size())
	quit(1)
