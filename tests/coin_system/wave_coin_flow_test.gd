extends SceneTree


## 코인 씬 통합 테스트입니다.
##
## 웨이브 승리 → 종료 유예 시작·종료 → 클리어 자동 확정 → 다음 웨이브 코인 재스폰을
## wave_coin.tscn을 실제로 띄워 확인합니다.
##
## 유예 타이머 만료(공이 3초를 버티는 경우)는 실제 물리 진행이 필요해
## 헤드리스로 재현하지 않습니다. 엔진 씬에서 수동으로 확인합니다.


const WAVE_COIN_SCENE := preload("res://scenes/wave/wave_coin.tscn")

const HIT_WEIGHT := 20000.0
const MAX_WAIT_FRAMES := 12


var _failures: Array[String] = []
var _delay_started_log: Array = []
var _delay_finished_log: Array = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_COIN_SCENE.instantiate() as WaveCoinCoordinator
	scene.reward_random_seed = 20260804
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var flow: WaveBallFlowController = scene.wave_ball_flow
	var combo: ComboSystem = scene.combo_system
	var launcher: PinballLauncher = scene.launcher
	# 최신 wave 베이스는 실제 수리 배치를 확정한 뒤 일반 웨이브에 진입한다.
	var placement_bridge := scene.get_node(
		^"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(
		placement_bridge.commit_placement(),
		"첫 수리 배치 단계에서 웨이브 1로 진입해야 한다."
	)
	await process_frame

	_expect(scene.coin_wallet != null, "코인 지갑이 씬에 붙어야 한다.")
	_expect(scene.coin_field != null, "코인 필드가 씬에 붙어야 한다.")
	_expect(scene.clear_delay != null, "종료 유예 컨트롤러가 씬에 붙어야 한다.")
	_expect(
		scene.coin_field.remaining_pickup_count() == 12,
		"첫 웨이브에 코인 12개가 깔려야 한다. (%d)"
		% scene.coin_field.remaining_pickup_count()
	)
	_expect(scene.coin_wallet.balance == 0, "지갑은 0으로 시작해야 한다.")

	scene.clear_delay.wave_clear_delay_started.connect(
		func(wave_id: int, target: int, at_start: int, duration: float) -> void:
			_delay_started_log.append([wave_id, target, at_start, duration])
	)
	scene.clear_delay.wave_clear_delay_finished.connect(
		func(reason: StringName, score: int, coin: int, board: int) -> void:
			_delay_finished_log.append([reason, score, coin, board])
	)

	# 보드 코인 하나를 먹는다.
	var ball_dummy := Node2D.new()
	ball_dummy.add_to_group(&"pinball_balls")
	root.add_child(ball_dummy)
	var first_pickup: CoinPickup = null
	for child in scene.coin_field.get_children():
		if child is CoinPickup:
			first_pickup = child
			break
	_expect(first_pickup != null, "스폰된 코인을 찾을 수 있어야 한다.")
	first_pickup._on_body_entered(ball_dummy)
	await process_frame
	_expect(scene.coin_wallet.balance == 2, "코인 획득이 지갑에 반영돼야 한다.")
	_expect(
		scene.coin_field.board_coin_this_wave == 2,
		"보드 코인 합계가 2여야 한다."
	)

	# 웨이브를 이긴다. 클리어 선택지는 자동 확정되므로 입력을 보내지 않는다.
	_send_action(flow, &"ball_select_confirm")
	_expect(
		flow.current_state == WaveBallFlowController.State.AIMING,
		"공 선택 확정은 조준으로 넘어가야 한다."
	)
	var launched_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "준비된 공이 발사되어야 한다.")
	combo.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")

	await _wait_until(func() -> bool:
		return wave_manager.current_state == WaveManager.State.WON
	)
	_expect(
		wave_manager.current_state == WaveManager.State.WON,
		"클리어 선택 없이 자동으로 승리가 확정돼야 한다. (현재: %s)"
		% wave_manager.get_state_name()
	)

	_expect(
		_delay_started_log.size() == 1,
		"종료 유예 시작 시그널이 한 번 나가야 한다. (%d)" % _delay_started_log.size()
	)
	if _delay_started_log.size() == 1:
		_expect(_delay_started_log[0][0] == 0, "유예 시작 웨이브는 0이어야 한다.")
		_expect(
			_delay_started_log[0][1] == wave_manager.target_score,
			"유예 시작 시그널의 목표 점수가 맞아야 한다."
		)
	_expect(
		_delay_finished_log.size() == 1,
		"종료 유예 종료 시그널이 한 번 나가야 한다. (%d)" % _delay_finished_log.size()
	)
	if _delay_finished_log.size() == 1:
		_expect(
			_delay_finished_log[0][0] == WaveClearDelayController.REASON_BALL_DRAINED,
			"헤드리스 낙하 경로의 종료 사유는 ball_drained여야 한다."
		)
		_expect(_delay_finished_log[0][3] == 2, "종료 시그널의 보드 코인은 2여야 한다.")
		var delay_coin: int = _delay_finished_log[0][2]
		_expect(
			scene.coin_wallet.balance == 2 + delay_coin,
			"지갑 = 보드 코인 + 유예 환산 코인이어야 한다. (잔액 %d, 환산 %d)"
			% [scene.coin_wallet.balance, delay_coin]
		)

	# 유물 선택(기존 흐름)을 확정하면 다음 웨이브로 넘어가고 코인이 다시 깔린다.
	_expect(
		scene.reward_controller.is_choosing,
		"승리 후에는 기존 보상 선택이 떠야 한다."
	)
	var wallet_before_next := scene.coin_wallet.balance
	scene.reward_controller.select_index(0)
	_send_action(scene.reward_controller, &"ball_select_confirm")
	await process_frame
	await process_frame

	_expect(
		wave_manager.current_wave_index == 1,
		"확정 후 웨이브 1로 진입해야 한다. (%d)" % wave_manager.current_wave_index
	)
	_expect(
		scene.coin_field.remaining_pickup_count() == 12,
		"다음 웨이브에 코인 12개가 다시 깔려야 한다. (%d)"
		% scene.coin_field.remaining_pickup_count()
	)
	_expect(
		scene.coin_field.board_coin_this_wave == 0,
		"웨이브 보드 코인 합계는 초기화돼야 한다."
	)
	_expect(
		scene.coin_wallet.balance == wallet_before_next,
		"지갑 잔액은 웨이브가 바뀌어도 유지돼야 한다."
	)
	_expect(
		not scene.clear_delay.is_delay_active,
		"새 웨이브에서 유예 상태는 꺼져 있어야 한다."
	)

	scene.queue_free()
	ball_dummy.queue_free()
	await process_frame
	await process_frame
	_finish()


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
		print("PASS: wave_coin_flow_test")
		quit(0)
		return
	print("FAIL: wave_coin_flow_test (%d failures)" % _failures.size())
	quit(1)
