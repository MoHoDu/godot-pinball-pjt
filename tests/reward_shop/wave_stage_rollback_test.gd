extends SceneTree


## 실패 시 스테이지 진입 스냅샷 롤백(기획서 10-1)을 wave_repair.tscn 실씬으로
## 확인합니다. 코인·해금 공·부품이 진입 시점으로 돌아가고 웨이브 1부터
## 재시작해야 합니다.


const WAVE_SCENE := preload("res://scenes/wave/wave_repair.tscn")

const HIT_WEIGHT := 20000.0
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []
var _rollback_log: Array[Array] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveRepairCoordinator
	scene.shop_random_seed = 20260805
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var inventory := scene.wave_ball_inventory as WaveBallInventoryV02
	scene.stage_state_rolled_back.connect(
		func(stage_id: StringName, failure_wave: int, snapshot_id: StringName) -> void:
			_rollback_log.append([stage_id, failure_wave, snapshot_id])
	)

	_expect(
		scene.stage_entry_snapshot != null,
		"스테이지 입장 스냅샷이 캡처되어야 한다."
	)
	_expect(
		scene.stage_entry_snapshot.coin_balance == 0,
		"입장 시점 코인은 0이어야 한다."
	)

	# 웨이브 1을 이기고 공·부품을 산 뒤 웨이브 2로 넘어간다.
	scene.coin_wallet.add(60)
	await _launch_and_drain(scene, true)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	var ball_index := _first_buyable_ball(scene)
	_expect(ball_index >= 0, "살 수 있는 공이 있어야 한다.")
	scene.shop_controller.buy_ball(ball_index)
	var part_index := _first_buyable_part(scene)
	_expect(part_index >= 0, "살 수 있는 부품이 있어야 한다.")
	var bought_part: StringName = \
		scene.shop_controller.part_offers[part_index].part_id
	scene.shop_controller.buy_part(part_index)
	scene.shop_hud.proceed_requested.emit()
	await process_frame
	await process_frame
	_expect(wave_manager.current_wave_index == 1, "웨이브 2에 진입해야 한다.")
	_expect(
		inventory.get_available_definitions().size() == 2,
		"해금 공이 선택지에 있어야 한다."
	)
	_expect(
		scene.part_inventory.total_count > 0,
		"부품 재고가 있어야 한다."
	)

	# 점수 없이 생명 3발을 모두 소진해 실패를 만든다.
	if scene.placement_controller.is_open:
		scene.placement_controller.finish_placement()
	for _launch in 3:
		await _launch_and_drain(scene, false)
	await _wait_until(func() -> bool:
		return wave_manager.current_wave_index == 0 \
			and wave_manager.current_state != WaveManager.State.LOST
	)

	# 롤백 검증: 코인 0, 해금 공 없음, 부품 없음, 웨이브 1부터 재시작.
	_expect(
		scene.coin_wallet.balance == 0,
		"실패 후 코인이 진입 시점(0)으로 복원되어야 한다. (%d)"
		% scene.coin_wallet.balance
	)
	_expect(
		scene.part_inventory.count_of(bought_part) == 0,
		"실패 후 부품 재고가 진입 시점으로 복원되어야 한다."
	)
	_expect(
		scene.stage_ball_inventory.unlocked_ids.is_empty(),
		"실패 후 해금 공 목록이 진입 시점으로 복원되어야 한다."
	)
	_expect(
		wave_manager.current_wave_index == 0,
		"실패 후 웨이브 1부터 재시작해야 한다. (%d)"
		% wave_manager.current_wave_index
	)
	_expect(
		inventory.get_available_definitions().size() == 1,
		"재시작 선택지는 기본 공 1종이어야 한다. (%d)"
		% inventory.get_available_definitions().size()
	)
	_expect(
		inventory.total_remaining == 3,
		"재시작 생명은 3이어야 한다. (%d)" % inventory.total_remaining
	)
	_expect(
		_rollback_log.size() == 1,
		"stage_state_rolled_back가 1회 발화해야 한다. (%d)"
		% _rollback_log.size()
	)
	if _rollback_log.size() == 1:
		_expect(
			int(_rollback_log[0][1]) == 1
				and StringName(_rollback_log[0][2]) == &"stage01_entry",
			"롤백 신호 인자(실패 웨이브·스냅샷 id)가 맞아야 한다."
		)

	# 롤백 후에도 같은 공을 다시 살 수 있어야 한다(해금 목록 복원 검증).
	scene.coin_wallet.add(60)
	await _launch_and_drain(scene, true)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(
		_first_buyable_ball(scene) >= 0,
		"롤백 후 상점에서 공을 다시 살 수 있어야 한다."
	)

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _first_buyable_ball(scene: WaveRepairCoordinator) -> int:
	for offer_index in scene.shop_controller.ball_offers.size():
		if scene.shop_controller.can_buy_ball(offer_index):
			return offer_index
	return -1


func _first_buyable_part(scene: WaveRepairCoordinator) -> int:
	for offer_index in scene.shop_controller.part_offers.size():
		if scene.shop_controller.can_buy_part(offer_index):
			return offer_index
	return -1


func _launch_and_drain(scene: WaveRepairCoordinator, score_hit: bool) -> void:
	var flow: WaveBallFlowController = scene.wave_ball_flow
	if scene.placement_controller.is_open:
		scene.placement_controller.finish_placement()
	_send_action(flow, &"ball_select_confirm")
	var launched_ball := flow.active_ball
	_expect(scene.launcher.launch_prepared_ball(), "공이 발사되어야 한다.")
	if score_hit:
		scene.combo_system.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")
	await process_frame
	await process_frame


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
		print("PASS: wave_stage_rollback_test")
		quit(0)
		return
	print("FAIL: wave_stage_rollback_test (%d failures)" % _failures.size())
	quit(1)
