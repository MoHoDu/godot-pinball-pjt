extends SceneTree


## 부품 구매 → 배치 예약 → 첫 발사 확정 소비 → 웨이브 종료 소멸을
## wave_repair.tscn 실씬으로 확인합니다. (기획서 8-2, 9장)


const WAVE_SCENE := preload("res://scenes/wave/wave_repair.tscn")

const HIT_WEIGHT := 20000.0
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveRepairCoordinator
	scene.shop_random_seed = 20260805
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var inventory: RewardPartInventory = scene.part_inventory
	var placement: RepairPlacementController = scene.placement_controller

	_expect(scene.repair_board != null, "수리 보드 컨트롤러가 붙어야 한다.")
	_expect(
		scene.repair_board.get_sockets().size() == 12,
		"소켓은 12개여야 한다(9-1). (%d)"
		% scene.repair_board.get_sockets().size()
	)
	_expect(
		not placement.is_open,
		"재고가 없으면 첫 웨이브에서 배치 단계가 열리지 않아야 한다."
	)

	# 웨이브 1을 이기고 상점에서 부품 한 장을 산다.
	scene.coin_wallet.add(60)
	await _win_current_wave(scene)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "승리 후 상점이 열려야 한다.")

	var part_index := -1
	for offer_index in scene.shop_controller.part_offers.size():
		if scene.shop_controller.can_buy_part(offer_index):
			part_index = offer_index
			break
	_expect(part_index >= 0, "살 수 있는 부품이 있어야 한다.")
	var bought_part: StringName = \
		scene.shop_controller.part_offers[part_index].part_id
	var bought_bundle: int = \
		scene.shop_controller.part_offers[part_index].bundle_count
	_expect(scene.shop_controller.buy_part(part_index), "부품 구매가 성공해야 한다.")
	_expect(
		inventory.count_of(bought_part) == bought_bundle,
		"구매 수량만큼 재고가 늘어야 한다."
	)

	# 다음 웨이브로 진입하면 배치 단계가 열린다.
	scene.shop_hud.proceed_requested.emit()
	await process_frame
	await process_frame
	_expect(wave_manager.current_wave_index == 1, "다음 웨이브로 진입해야 한다.")
	_expect(placement.is_open, "재고가 있으면 배치 단계가 열려야 한다.")

	# 예약은 재고를 차감하지 않는다(8-2).
	var first_socket: StringName = \
		scene.repair_board.get_sockets()[0].get_socket_id()
	_expect(
		placement.reserve(first_socket, bought_part),
		"소켓에 부품을 예약할 수 있어야 한다."
	)
	_expect(
		inventory.count_of(bought_part) == bought_bundle,
		"예약만으로는 재고가 줄지 않아야 한다."
	)
	_expect(
		placement.available_stock_of(bought_part) == bought_bundle - 1,
		"예약분은 실질 잔여 재고에서 빠져야 한다."
	)

	# 첫 발사가 배치를 확정하고 재고를 차감한다.
	var flow: WaveBallFlowController = scene.wave_ball_flow
	_send_action(flow, &"ball_select_confirm")
	_expect(scene.launcher.launch_prepared_ball(), "공이 발사되어야 한다.")
	await process_frame
	_expect(not placement.is_open, "첫 발사 후 배치 단계가 닫혀야 한다.")
	_expect(
		inventory.count_of(bought_part) == bought_bundle - 1,
		"발사 확정 시 배치 수량만큼 재고가 줄어야 한다."
	)
	_expect(
		scene.repair_board.get_equipped_count() == 1,
		"확정된 부품이 보드에 장착되어야 한다."
	)

	# 웨이브를 끝내면 장착 개체는 보드에서 사라진다(1회용).
	scene.combo_system.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(flow.active_ball), "공이 낙하 처리되어야 한다.")
	await _wait_until(func() -> bool:
		return wave_manager.current_state == WaveManager.State.WON
	)
	_expect(
		scene.repair_board.get_equipped_count() == 0,
		"웨이브 종료 후 장착 부품이 제거되어야 한다."
	)
	_expect(
		inventory.count_of(bought_part) == bought_bundle - 1,
		"미배치 재고는 소비되지 않고 남아야 한다(8-1)."
	)

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _win_current_wave(scene: WaveRepairCoordinator) -> void:
	var flow: WaveBallFlowController = scene.wave_ball_flow
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
		print("PASS: wave_repair_flow_test")
		quit(0)
		return
	print("FAIL: wave_repair_flow_test (%d failures)" % _failures.size())
	quit(1)
