extends SceneTree


## 상점 씬 통합 테스트입니다.
##
## 웨이브 승리 → 상점 열림(유물 3택1 대체 확인) → 공·부품 구매 →
## 다음 단계 → 다음 웨이브 진입·코인 재스폰을 확인하고,
## 마지막 웨이브까지 진행해 상점 없이 스테이지 클리어로 끝나는지 봅니다.


const WAVE_SHOP_SCENE := preload("res://scenes/wave/wave_shop.tscn")

const HIT_WEIGHT := 20000.0
const WAVE_COUNT := 4
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SHOP_SCENE.instantiate() as WaveShopCoordinator
	scene.shop_random_seed = 20260804
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager

	_expect(scene.shop_controller != null, "상점 컨트롤러가 붙어야 한다.")
	_expect(scene.shop_controller.stage_id == scene.shop_stage_id \
		and StageRewardRepository.stage_num_from_id(
			scene.shop_controller.stage_id
		) == 1,
		"상점 컨트롤러는 현재 스테이지 DB ID와 번호를 사용해야 한다.")
	_expect(scene.shop_hud != null, "상점 HUD가 붙어야 한다.")
	_expect(
		scene.reward_controller == null,
		"유물 3택1 컨트롤러는 만들어지지 않아야 한다(대체 확인)."
	)
	_expect(not scene.shop_hud.visible, "웨이브 중에는 상점이 보이면 안 된다.")

	# 구매를 확인할 수 있게 코인을 넉넉히 넣어 둔다.
	scene.coin_wallet.add(24)

	# ── 웨이브 0: 승리 → 상점 → 구매 → 진행 ──
	await _win_current_wave(scene)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "승리 후 상점이 열려야 한다.")
	_expect(scene.shop_hud.visible, "상점이 열리면 HUD가 보여야 한다.")
	_expect(scene.shop_hud.get_card_count() == 6, "카드는 6장이어야 한다.")
	_expect(
		scene.shop_controller.ball_offers.size() == 3
			and scene.shop_controller.part_offers.size() == 3,
		"공 3장 + 부품 3장이어야 한다."
	)

	var ball_index := -1
	for offer_index in scene.shop_controller.ball_offers.size():
		if scene.shop_controller.can_buy_ball(offer_index):
			ball_index = offer_index
			break
	_expect(ball_index >= 0, "살 수 있는 공이 있어야 한다(구매 가능성 보장).")
	var bought_ball: StringName = &""
	if ball_index >= 0:
		bought_ball = scene.shop_controller.ball_offers[ball_index].ball_id
		_expect(scene.shop_controller.buy_ball(ball_index), "공 구매가 성공해야 한다.")

	var part_index := -1
	for offer_index in scene.shop_controller.part_offers.size():
		if scene.shop_controller.can_buy_part(offer_index):
			part_index = offer_index
			break
	if part_index >= 0:
		var part_id: StringName = scene.shop_controller.part_offers[part_index].part_id
		var bundle: int = scene.shop_controller.part_offers[part_index].bundle_count
		var count_before := scene.part_inventory.count_of(part_id)
		_expect(scene.shop_controller.buy_part(part_index), "부품 구매가 성공해야 한다.")
		_expect(
			scene.part_inventory.count_of(part_id) == count_before + bundle,
			"메인 수리 배치 인벤토리에 묶음 수량만큼 늘어야 한다."
		)

	scene.shop_hud.proceed_requested.emit()
	await process_frame
	_expect(not scene.shop_controller.is_open, "진행하면 상점이 닫혀야 한다.")
	_expect(not scene.shop_hud.visible, "상점이 닫히면 HUD가 숨어야 한다.")
	_expect(
		wave_manager.current_wave_index == 1,
		"다음 웨이브로 진입해야 한다. (%d)" % wave_manager.current_wave_index
	)
	_expect(
		scene.coin_field.remaining_pickup_count() == 12,
		"다음 웨이브에 코인이 다시 깔려야 한다."
	)

	# ── 웨이브 1: 해금한 공이 후보에서 빠지는지 확인하고 구매 없이 진행 ──
	await _win_current_wave(scene)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	_expect(scene.shop_controller.is_open, "두 번째 보상 상점이 열려야 한다.")
	if bought_ball != &"":
		for offer in scene.shop_controller.ball_offers:
			_expect(
				offer.ball_id != bought_ball,
				"해금한 공 %s은 후보에서 빠져야 한다." % bought_ball
			)
	scene.shop_hud.proceed_requested.emit()
	await process_frame
	_expect(wave_manager.current_wave_index == 2, "웨이브 2로 진입해야 한다.")

	# ── 남은 웨이브를 끝까지: 마지막 승리 뒤에는 상점 없이 스테이지 클리어 ──
	await _win_current_wave(scene)
	await _wait_until(func() -> bool: return scene.shop_controller.is_open)
	scene.shop_hud.proceed_requested.emit()
	await process_frame
	_expect(wave_manager.current_wave_index == 3, "웨이브 3(마지막)으로 진입해야 한다.")

	await _win_current_wave(scene)
	await process_frame
	await process_frame
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"마지막 웨이브는 승리로 끝나야 한다."
	)
	_expect(
		not scene.shop_controller.is_open,
		"마지막 웨이브 뒤에는 상점이 열리지 않아야 한다."
	)

	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _win_current_wave(scene: WaveShopCoordinator) -> void:
	var flow: WaveBallFlowController = scene.wave_ball_flow
	if scene.wave_manager.current_stage_phase \
			== WaveManager.StagePhase.REPAIR_PLACEMENT:
		var placement_bridge := scene.get_node_or_null(
			^"BoardWavePlacementBridge"
		) as BoardWavePlacementBridge
		_expect(placement_bridge != null and placement_bridge.commit_placement(),
			"첫 웨이브는 수리 배치를 확정한 뒤 공 선택으로 넘어가야 한다.")
		await process_frame
	_send_action(flow, &"ball_select_confirm")
	_expect(
		flow.current_state == WaveBallFlowController.State.AIMING,
		"공 선택 확정은 조준으로 넘어가야 한다."
	)
	var launched_ball := flow.active_ball
	_expect(scene.launcher.launch_prepared_ball(), "준비된 공이 발사되어야 한다.")
	scene.combo_system.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")
	await _wait_until(func() -> bool:
		return scene.wave_manager.current_state == WaveManager.State.WON
	)
	_expect(
		scene.wave_manager.current_state == WaveManager.State.WON,
		"클리어 선택 없이 자동으로 승리해야 한다. (%s)"
		% scene.wave_manager.get_state_name()
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
		print("PASS: wave_shop_flow_test")
		quit(0)
		return
	print("FAIL: wave_shop_flow_test (%d failures)" % _failures.size())
	quit(1)
