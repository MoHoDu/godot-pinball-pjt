extends SceneTree


## 최신 wave.tscn에 에디터 배치·누적·리셋 수명주기가 연결됐는지 검증합니다.


const WAVE_SCENE := preload("res://scenes/wave/wave.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_SCENE.instantiate() as WaveRuntimeCoordinator
	root.add_child(scene)
	await process_frame
	await process_frame

	var field := scene.get_node(^"CoinSystem") as CoinFieldController
	var session := scene.get_node(^"CoinSystem/CoinSession") as WaveCoinSession
	var wallet := scene.get_node(^"CoinSystem/CoinWallet") as CoinWallet
	var wallet_hud := scene.get_node(
		^"HUD/WaveHud/DesignSpace/CoinWalletHud"
	) as PanelContainer
	var wallet_label := wallet_hud.get_node(
		^"Margin/Row/BalanceLabel"
	) as Label if wallet_hud != null else null
	var wallet_icon := wallet_hud.get_node(
		^"Margin/Row/CoinIcon"
	) as TextureRect if wallet_hud != null else null
	var settings_button := scene.get_node(
		^"HUD/WaveHud/DesignSpace/SettingsButton"
	) as Control
	_expect(field != null and session != null and wallet != null,
		"최신 wave 씬에 코인 필드·세션·지갑이 있어야 한다.")
	_expect(
		wallet_hud != null
			and wallet_label != null
			and wallet_label.text == "× 0"
			and wallet_icon != null
			and wallet_icon.texture != null
			and wallet_icon.texture.resource_path
				== "res://Resources/wave_hud/coin_wallet_icon.png",
		"우측 상단 코인 HUD는 생성 아이콘과 간결한 × 보유량 표기를 사용해야 한다."
	)
	_expect(
		wallet_hud.position.x + wallet_hud.size.x < settings_button.position.x,
		"코인 HUD는 우측 상단 설정 버튼과 겹치지 않아야 한다."
	)
	_expect(field.validate_authored_placement().is_empty(),
		"코인 12개는 보드·범퍼·소켓·금지 영역과 겹치지 않아야 한다: %s"
		% [field.validate_authored_placement()])
	_expect(wallet.balance == 0, "스테이지는 코인 0으로 시작해야 한다.")

	# 첫 배치 단계를 넘기면 웨이브 1의 에디터 배치 12개가 실제 픽업으로 생성된다.
	_expect(scene.wave_manager.advance_stage_phase(), "첫 웨이브에 진입해야 한다.")
	await process_frame
	_expect(field.remaining_pickup_count() == 12,
		"웨이브 1에 코인 12개가 생성되어야 한다.")
	_expect(_count_route(field, CoinSpawnPoint.RouteKind.MAIN) == 10,
		"웨이브 1 기본 경로 코인은 10개여야 한다.")
	_expect(_count_route(field, CoinSpawnPoint.RouteKind.RISK) == 2,
		"웨이브 1 도전 경로 코인은 2개여야 한다.")

	var ball := Node2D.new()
	ball.add_to_group(&"pinball_balls")
	root.add_child(ball)
	var first_pickup := _first_pickup(field)
	_expect(first_pickup != null, "생성된 코인 픽업을 찾을 수 있어야 한다.")
	_expect(first_pickup.definition != null \
		and first_pickup.definition.coin_id == &"basic_coin" \
		and first_pickup.definition.value == 2,
		"실제 픽업은 value 2의 basic_coin 데이터 리소스를 사용해야 한다.")
	first_pickup._on_body_entered(ball)
	await process_frame
	_expect(wallet.balance == 2 and field.board_coin_this_wave == 2,
		"플레이어 공이 코인을 트리거하면 2코인이 지갑과 웨이브 합계에 반영돼야 한다.")
	_expect(wallet_label.text == "× 2",
		"코인을 획득하면 우측 상단 HUD가 같은 프레임에 갱신되어야 한다.")
	# 유예 환산분이 지갑에 더해진 뒤 보상 정산은 보드+유예 획득량을 다시 계산한다.
	wallet.add(3)
	var clear_delay := scene.get_node(
		^"CoinSystem/WaveClearDelayController"
	) as WaveClearDelayController
	clear_delay.wave_clear_delay_finished.emit(&"ball_drained", 37500, 3, 2)
	_expect(session.last_board_coin == 2 \
		and session.last_clear_delay_coin == 3 \
		and session.last_wave_coin_earned == 5 \
		and wallet.balance == 5,
		"보상 정산은 보드 코인과 유예 코인을 합산하고 누적 지갑을 유지해야 한다.")
	# 승리 결과에서 같은 웨이브를 재시도해도 이미 정산된 필드 코인은 부활하지 않는다.
	scene.wave_manager.wave_retried.emit()
	await process_frame
	_expect(wallet.balance == 5 and field.remaining_pickup_count() == 0,
		"승리한 웨이브 재시도는 지갑을 유지하되 코인을 재생성하면 안 된다.")

	# 다음 일반 웨이브에서도 지갑은 누적되고 필드만 새로 계산한다.
	scene.wave_manager.wave_entered.emit(&"test_stage", 1, 400000)
	await process_frame
	_expect(wallet.balance == 5, "일반 웨이브 사이에는 코인이 유지되어야 한다.")
	_expect(field.board_coin_this_wave == 0 and field.remaining_pickup_count() == 12,
		"새 웨이브는 보드 합계 0과 코인 12개로 다시 시작해야 한다.")

	# 게임 오버와 보스 클리어만 지갑을 초기화한다.
	wallet.add(8)
	scene.wave_manager.wave_lost.emit(0, 400000)
	_expect(wallet.balance == 0 and field.remaining_pickup_count() == 0,
		"게임 오버는 코인과 남은 픽업을 초기화해야 한다.")
	scene.wave_manager.wave_retried.emit()
	await process_frame
	_expect(wallet.balance == 0 and field.remaining_pickup_count() == 12,
		"게임 오버 뒤 새 시도에는 코인 필드를 다시 공급해야 한다.")
	wallet.add(10)
	scene.wave_manager.stage_phase_changed.emit(
		WaveManager.StagePhase.REWARD, WaveManager.StagePhase.BOSS
	)
	_expect(wallet.balance == 10,
		"보스 진입 시에는 스테이지 코인을 유지해야 한다.")
	scene.wave_manager.stage_completed.emit(&"test_stage")
	_expect(wallet.balance == 0,
		"보스 클리어(stage_completed)는 코인을 0으로 초기화해야 한다.")

	scene.queue_free()
	ball.queue_free()
	await process_frame
	await process_frame
	_finish()


func _count_route(field: CoinFieldController, route: CoinSpawnPoint.RouteKind) -> int:
	var count := 0
	for point: CoinSpawnPoint in field.get_spawn_points():
		if point.route_kind == route:
			count += 1
	return count


func _first_pickup(field: CoinFieldController) -> CoinPickup:
	for child: Node in field.get_children():
		if child is CoinPickup:
			return child as CoinPickup
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_scene_coin_integration_test")
		quit(0)
		return
	print("FAIL: wave_scene_coin_integration_test (%d failures)" % _failures.size())
	quit(1)
