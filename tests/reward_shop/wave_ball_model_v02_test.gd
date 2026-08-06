extends SceneTree


## v0.2 공 보유 모델(기획서 7장)을 wave_repair.tscn 실씬으로 확인합니다.
##   - 기본 공 1종 × 생명 3으로 시작
##   - 해금 공은 생명 풀을 공유하며 무제한 재선택 가능
##   - ball_selected(wave_id, launch_index, ball_id) 신호
##   - 해금 실패 시 코인 롤백(6-3 검사⑤)


const WAVE_SCENE := preload("res://scenes/wave/wave_repair.tscn")

const HIT_WEIGHT := 20000.0
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []
var _selected_log: Array[Array] = []


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveRepairCoordinator
	scene.shop_random_seed = 20260805
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var inventory := scene.wave_ball_inventory as WaveBallInventoryV02
	var flow: WaveBallFlowController = scene.wave_ball_flow
	scene.ball_selected.connect(
		func(wave_id: int, launch_index: int, ball_id: StringName) -> void:
			_selected_log.append([wave_id, launch_index, ball_id])
	)

	_expect(inventory != null, "웨이브 인벤토리가 v0.2 모델이어야 한다.")
	_expect(
		inventory.get_available_definitions().size() == 1,
		"시작 보유는 기본 공 1종이어야 한다(7-1). (%d)"
		% inventory.get_available_definitions().size()
	)
	_expect(
		inventory.total_remaining == 3,
		"시작 생명(발사 기회)은 3이어야 한다. (%d)" % inventory.total_remaining
	)

	# 웨이브 1을 이기고 상점에서 공을 산다.
	scene.coin_wallet.add(60)
	await _launch_and_drain(scene, true)
	await _wait_until(func() -> bool:
		return wave_manager.current_state == WaveManager.State.WON
	)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "승리 후 상점이 열려야 한다.")

	var ball_index := -1
	for offer_index in scene.shop_controller.ball_offers.size():
		if scene.shop_controller.can_buy_ball(offer_index):
			ball_index = offer_index
			break
	_expect(ball_index >= 0, "살 수 있는 공이 있어야 한다.")
	var bought_ball: StringName = \
		scene.shop_controller.ball_offers[ball_index].ball_id
	_expect(scene.shop_controller.buy_ball(ball_index), "공 구매가 성공해야 한다.")

	scene.shop_hud.proceed_requested.emit()
	await process_frame
	await process_frame
	_expect(wave_manager.current_wave_index == 1, "다음 웨이브로 진입해야 한다.")

	# 해금 공은 슬롯을 차지하지 않고 종류로만 추가된다. 생명은 그대로 3.
	_expect(
		inventory.get_available_definitions().size() == 2,
		"기본 1종 + 해금 1종 = 2종이어야 한다. (%d)"
		% inventory.get_available_definitions().size()
	)
	_expect(
		inventory.total_remaining == 3,
		"해금 후에도 생명은 3이어야 한다. (%d)" % inventory.total_remaining
	)

	# 해금 공으로 두 번 연속 발사(무제한 재선택), 마지막은 기본 공으로 클리어.
	_expect(inventory.select_ball(bought_ball), "해금 공을 선택할 수 있어야 한다.")
	await _launch_and_drain(scene, false)
	_expect(
		inventory.total_remaining == 2,
		"발사마다 생명이 1씩 줄어야 한다. (%d)" % inventory.total_remaining
	)
	_expect(
		inventory.select_ball(bought_ball),
		"같은 해금 공을 다시 선택할 수 있어야 한다(발사 횟수 제한 없음)."
	)
	await _launch_and_drain(scene, false)
	_expect(
		inventory.total_remaining == 1,
		"두 번째 발사 후 생명은 1이어야 한다. (%d)" % inventory.total_remaining
	)
	_expect(inventory.select_ball(&"normal"), "기본 공으로 되돌릴 수 있어야 한다.")
	await _launch_and_drain(scene, true)
	await _wait_until(func() -> bool:
		return wave_manager.current_state == WaveManager.State.WON
	)
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"마지막 발사로 웨이브를 이겨야 한다."
	)

	# ball_selected 신호: 웨이브0 1회 + 웨이브1 3회(발사 순번 0·1·2).
	var wave1_entries: Array[Array] = []
	for entry in _selected_log:
		if int(entry[0]) == 1:
			wave1_entries.append(entry)
	_expect(
		wave1_entries.size() == 3,
		"웨이브1에서 ball_selected가 3회 발화해야 한다. (%d)"
		% wave1_entries.size()
	)
	if wave1_entries.size() == 3:
		_expect(
			int(wave1_entries[0][1]) == 0 and int(wave1_entries[2][1]) == 2,
			"launch_index가 0부터 차례로 증가해야 한다."
		)
		_expect(
			StringName(wave1_entries[0][2]) == bought_ball
				and StringName(wave1_entries[2][2]) == &"normal",
			"ball_selected가 실제 선택한 공 id를 실어야 한다."
		)

	# 해금 실패 시 코인 롤백(6-3 검사⑤): 씬맵을 비워 실패를 유도한다.
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "웨이브1 승리 후 상점이 열려야 한다.")
	var stage_v02 := scene.stage_ball_inventory as StageBallInventoryV02
	var saved_map: RewardBallSceneMap = stage_v02.scene_map
	stage_v02.scene_map = null
	var wallet_before := scene.coin_wallet.balance
	var retry_index := -1
	for offer_index in scene.shop_controller.ball_offers.size():
		if scene.shop_controller.can_buy_ball(offer_index):
			retry_index = offer_index
			break
	_expect(retry_index >= 0, "롤백 검증용으로 살 수 있는 공이 있어야 한다.")
	var failed_ball: StringName = \
		scene.shop_controller.ball_offers[retry_index].ball_id
	scene.shop_controller.buy_ball(retry_index)
	_expect(
		scene.coin_wallet.balance == wallet_before,
		"해금 실패 시 코인이 전액 반환되어야 한다. (%d → %d)"
		% [wallet_before, scene.coin_wallet.balance]
	)
	_expect(
		not scene.shop_controller.unlocked_ball_ids.has(failed_ball),
		"해금 실패한 공은 상점 해금 목록에도 남지 않아야 한다."
	)
	stage_v02.scene_map = saved_map

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _init() -> void:
	call_deferred(&"_run")


## 현재 선택된 공을 발사하고 낙하시킵니다. score_hit이면 목표 점수를 채웁니다.
func _launch_and_drain(scene: WaveRepairCoordinator, score_hit: bool) -> void:
	var flow: WaveBallFlowController = scene.wave_ball_flow
	if scene.placement_controller.is_open:
		scene.placement_controller.finish_placement()
	# main 이 도입한 수리 부품 배치 페이즈를 넘겨야 웨이브가 시작된다.
	# 인게임에서는 BoardWavePlacementBridge 가 배치 확정 시 호출하는 자리다.
	var phase := scene.wave_manager.current_stage_phase
	if phase == WaveManager.StagePhase.REPAIR_PLACEMENT:
		scene.wave_manager.advance_stage_phase()
		await process_frame
	_send_action(flow, &"ball_select_confirm")
	var launched_ball := flow.active_ball
	_expect(scene.launcher.launch_prepared_ball(), "공이 발사되어야 한다.")
	if score_hit:
		scene.combo_system.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")
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
		print("PASS: wave_ball_model_v02_test")
		quit(0)
		return
	print("FAIL: wave_ball_model_v02_test (%d failures)" % _failures.size())
	quit(1)
