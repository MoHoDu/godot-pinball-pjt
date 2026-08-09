extends SceneTree


const MANAGER_SCENE := preload(
	"res://Resources/Prefabs/stage/flow/stage_flow_manager.tscn"
)
const STAGE_01_SCENE := preload("res://scenes/game/stages/stage_01/stage_01.tscn")
const PLACEHOLDER_REWARD_SCENE := preload(
	"res://scenes/tests/stage/fixtures/stage_reward_placeholder.tscn"
)
const WAVE_SCENE := preload(
	"res://tests/stage_system/fixtures/stage_segment_fixture.tscn"
)
const LEGACY_WAVE_SCENE := preload(
	"res://tests/stage_system/fixtures/legacy_wave_fixture.tscn"
)
const BOSS_SCENE := preload(
	"res://tests/stage_system/fixtures/boss_completion_fixture.tscn"
)
const EXISTING_WAVE_SCENES: Array[PackedScene] = [
	preload("res://scenes/tests/stage/fixtures/legacy_waves/wave_01.tscn"),
	preload("res://scenes/tests/stage/fixtures/legacy_waves/wave_02.tscn"),
	preload("res://scenes/tests/stage/fixtures/legacy_waves/wave_03.tscn"),
]


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_auto_start_from_inspector_configuration()
	await _test_arbitrary_wave_reward_boss_sequence()
	await _test_single_wave_without_boss()
	await _test_nested_legacy_signal_with_arguments()
	await _test_duplicate_completion_is_ignored()
	await _test_restart_cancels_pending_transition()
	await _test_stage_coin_wallet_continuity()
	await _test_stage_reward_purchase_persistence()
	_test_stage_01_scene_configuration()
	_test_existing_wave_scene_contracts()
	_test_configuration_validation()
	_finish()


func _test_auto_start_from_inspector_configuration() -> void:
	var manager := MANAGER_SCENE.instantiate() as StageFlowManager
	var waves: Array[PackedScene] = [WAVE_SCENE]
	manager.wave_scenes = waves
	root.add_child(manager)
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0,
		"인스펙터 설정을 마친 매니저는 씬 진입 시 자동으로 첫 웨이브를 시작해야 한다."
	)
	await _destroy_manager(manager)


func _test_arbitrary_wave_reward_boss_sequence() -> void:
	var waves: Array[PackedScene] = [WAVE_SCENE, WAVE_SCENE, WAVE_SCENE]
	var bosses: Array[PackedScene] = [BOSS_SCENE, BOSS_SCENE]
	var manager := _create_manager(waves, bosses)
	var completed_count := {&"value": 0}
	manager.stage_completed.connect(func() -> void:
		completed_count.value += 1
	)

	_expect(manager.start_stage(), "설정된 스테이지가 첫 웨이브를 시작해야 한다.")
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0,
		"스테이지는 첫 번째 일반 웨이브에서 시작해야 한다."
	)

	for wave_index in waves.size():
		manager.active_scene.call(&"complete")
		await _wait_for_transition()
		_expect(
			manager.current_phase == StageFlowManager.Phase.REWARD,
			"모든 일반 웨이브 뒤에는 보상 페이지가 열려야 한다."
		)
		var reward := manager.active_scene as StageRewardPlaceholder
		_expect(reward != null, "기본 보상 페이지를 인스턴스화해야 한다.")
		if reward != null:
			_expect(reward.continue_stage(), "보상 페이지에서 다음 진행을 선택할 수 있어야 한다.")
		await _wait_for_transition()
		if wave_index + 1 < waves.size():
			_expect(
				manager.current_phase == StageFlowManager.Phase.WAVE
					and manager.current_wave_index == wave_index + 1,
				"보상 뒤에는 배열의 다음 일반 웨이브가 시작되어야 한다."
			)

	_expect(
		manager.current_phase == StageFlowManager.Phase.BOSS
			and manager.current_boss_index == 0,
		"마지막 보상 뒤에는 첫 번째 보스가 시작되어야 한다."
	)

	for boss_index in bosses.size():
		manager.active_scene.call(&"complete")
		await _wait_for_transition()
		if boss_index + 1 < bosses.size():
			_expect(
				manager.current_phase == StageFlowManager.Phase.BOSS
					and manager.current_boss_index == boss_index + 1,
				"보스가 여러 개면 배열 순서대로 연속 진행해야 한다."
			)

	_expect(
		manager.current_phase == StageFlowManager.Phase.COMPLETE,
		"마지막 보스를 클리어하면 스테이지를 완료해야 한다."
	)
	_expect(completed_count.value == 1, "스테이지 완료 시그널은 한 번만 발생해야 한다.")
	_expect(manager.active_scene == null, "완료 뒤에는 진행 씬이 남지 않아야 한다.")
	await _destroy_manager(manager)


func _test_single_wave_without_boss() -> void:
	var waves: Array[PackedScene] = [WAVE_SCENE]
	var bosses: Array[PackedScene] = []
	var manager := _create_manager(waves, bosses)

	_expect(manager.start_stage(), "보스가 없어도 한 웨이브 스테이지를 시작해야 한다.")
	manager.active_scene.call(&"complete")
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.REWARD,
		"보스가 없어도 마지막 웨이브 뒤 보상 페이지를 보여야 한다."
	)
	var reward := manager.active_scene as StageRewardPlaceholder
	_expect(reward != null and reward.continue_stage(), "마지막 보상 페이지를 진행할 수 있어야 한다.")
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.COMPLETE,
		"보스가 없으면 마지막 보상 뒤 스테이지를 완료해야 한다."
	)
	await _destroy_manager(manager)


func _test_nested_legacy_signal_with_arguments() -> void:
	var waves: Array[PackedScene] = [LEGACY_WAVE_SCENE]
	var bosses: Array[PackedScene] = []
	var manager := _create_manager(waves, bosses)

	_expect(manager.start_stage(), "자식 노드의 기존 웨이브 완료 시그널을 찾아야 한다.")
	var emitter := manager.active_scene.get_node(^"CompletionEmitter")
	emitter.call(&"complete")
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.REWARD,
		"인자가 있는 wave_won 시그널도 보상 전환으로 연결해야 한다."
	)
	await _destroy_manager(manager)


func _test_duplicate_completion_is_ignored() -> void:
	var waves: Array[PackedScene] = [WAVE_SCENE, WAVE_SCENE]
	var bosses: Array[PackedScene] = []
	var manager := _create_manager(waves, bosses)
	var completed_scenes := {&"value": 0}
	manager.scene_completed.connect(func(
		_phase: StageFlowManager.Phase,
		_index: int
	) -> void:
		completed_scenes.value += 1
	)

	manager.start_stage()
	manager.active_scene.call(&"complete_twice")
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.REWARD,
		"중복 완료 시그널 뒤에도 보상 페이지 하나만 열려야 한다."
	)
	_expect(completed_scenes.value == 1, "중복 완료 시그널은 한 번만 처리해야 한다.")
	await _destroy_manager(manager)


func _test_restart_cancels_pending_transition() -> void:
	var waves: Array[PackedScene] = [WAVE_SCENE, WAVE_SCENE]
	var bosses: Array[PackedScene] = []
	var manager := _create_manager(waves, bosses)

	manager.start_stage()
	manager.active_scene.call(&"complete")
	_expect(
		manager.restart_stage(),
		"완료 전환이 대기 중이어도 스테이지를 다시 시작할 수 있어야 한다."
	)
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0,
		"재시작 전의 지연 전환이 새 스테이지를 보상 단계로 넘기면 안 된다."
	)
	await _destroy_manager(manager)


func _test_stage_coin_wallet_continuity() -> void:
	var stage := STAGE_01_SCENE.instantiate()
	root.add_child(stage)
	await _wait_for_transition()
	var manager := stage.get_node(^"StageFlowManager") as StageFlowManager
	manager.clear_destination_scene = null
	_expect(manager.coin_wallet != null, "StageFlowManager는 공용 코인 지갑을 가져야 한다.")
	_expect(manager.current_coin_balance == 0, "새 스테이지의 코인은 0으로 시작해야 한다.")

	var first_session := _get_active_coin_session(manager)
	_expect(
		first_session != null
			and first_session.wallet == manager.coin_wallet
			and not first_session.manages_stage_wallet_lifecycle,
		"첫 웨이브는 스테이지 공용 지갑을 사용해야 한다."
	)
	var first_wave_manager := manager.active_scene.get_node(^"WaveManager") as WaveManager
	var first_coin_field := manager.active_scene.get_node(
		^"CoinSystem"
	) as CoinFieldController
	var first_roster := manager.active_scene.get_node_or_null(
		^"HUD/BumperRosterHud"
	)
	var first_ball_hud := manager.active_scene.get_node(
		^"HUD/BallSelectionHud"
	) as SelectBallSelectionHud
	var first_wallet_label := manager.active_scene.get_node(
		^"HUD/WaveHud/DesignSpace/CoinWalletHud/Margin/Row/BalanceLabel"
	) as Label
	var first_coin_animator := manager.active_scene.get_node_or_null(
		^"HUD/CoinHudFlyAnimator"
	)
	_expect(
		first_roster == null,
		"프로덕션 웨이브는 범퍼 가이드 UI를 표시하지 않아야 한다."
	)
	_expect(
		first_ball_hud != null
			and first_ball_hud.get_node_or_null(^"Center/Panel") != null
			and first_ball_hud.get_node_or_null(^"Panel") == null,
		"Stage 01은 레거시 공 설명 대신 최신 공 선택 UI를 사용해야 한다."
	)
	_expect(first_wave_manager.advance_stage_phase(), "첫 웨이브 플레이 단계에 진입해야 한다.")
	await process_frame
	_expect(
		first_coin_field.remaining_pickup_count() == 12,
		"스테이지 웨이브에도 코인 12개가 생성되어야 한다."
	)
	_expect(
		first_coin_field.layout == null
			and first_coin_field.get_spawn_points().size() == 12,
		"Stage 01 코인은 좌표 배열이 아니라 2D 에디터 마커로 배치되어야 한다."
	)
	_expect(
		first_coin_field.validate_authored_placement().is_empty(),
		"확대된 Stage 01 코인은 벽·범퍼·소켓·금지 영역과 겹치지 않아야 한다: %s"
		% [first_coin_field.validate_authored_placement()]
	)
	var test_ball := Node2D.new()
	test_ball.add_to_group(&"pinball_balls")
	root.add_child(test_ball)
	for child: Node in first_coin_field.get_children():
		if child is CoinPickup:
			(child as CoinPickup)._on_body_entered(test_ball)
			break
	_expect(first_coin_animator != null \
		and int(first_coin_animator.call(&"get_active_fly_count")) == 1,
		"실제 Stage 01 코인 획득은 코인 HUD 이동 연출을 즉시 시작해야 한다.")
	await process_frame
	_expect(
		manager.current_coin_balance == 2
			and first_coin_field.board_coin_this_wave == 2
			and first_wallet_label.text == "× 2",
		"웨이브 코인 획득은 스테이지 공용 지갑에 즉시 반영되어야 한다."
	)
	test_ball.queue_free()
	manager.coin_wallet.add(5)
	_complete_active_wave(manager, 1000)
	await _wait_for_transition()
	var first_reward := manager.active_scene as StageRewardShopScreen
	_expect(
		manager.current_coin_balance == 7
			and first_reward != null
			and first_reward.shop_controller != null
			and first_reward.shop_controller.is_open,
		"웨이브 획득 코인은 실제 보상 상점까지 유지되어야 한다."
	)
	first_reward.continue_stage()
	await _wait_for_transition()

	var second_session := _get_active_coin_session(manager)
	var second_wallet_label := manager.active_scene.get_node(
		^"HUD/WaveHud/DesignSpace/CoinWalletHud/Margin/Row/BalanceLabel"
	) as Label
	_expect(
		second_session != null
			and second_session.wallet == manager.coin_wallet
			and second_session.wallet.balance == 7
			and second_wallet_label.text == "× 7",
		"보상 뒤 다음 웨이브도 같은 누적 지갑을 사용해야 한다."
	)
	manager.coin_wallet.add(5)
	_complete_active_wave(manager, 1500)
	await _wait_for_transition()
	var second_reward := manager.active_scene as StageRewardShopScreen
	_expect(
		manager.current_coin_balance == 12
			and second_reward != null
			and second_reward.shop_controller.is_open,
		"두 번째 웨이브 코인은 실제 보상 상점까지 누적되어야 한다."
	)
	second_reward.continue_stage()
	await _wait_for_transition()

	var third_session := _get_active_coin_session(manager)
	_expect(
		third_session != null and third_session.wallet.balance == 12,
		"마지막 웨이브 진입 전까지 누적 코인을 유지해야 한다."
	)
	_complete_active_wave(manager, 3000)
	await _wait_for_transition()
	var final_reward := manager.active_scene as StageRewardShopScreen
	_expect(
		final_reward != null
			and final_reward.shop_controller.is_open
			and manager.current_coin_balance == 12,
		"마지막 웨이브에서도 현재 코인으로 실제 보상 상점을 열어야 한다."
	)
	final_reward.continue_stage()
	await _wait_frames(6)
	var boss_scene := manager.active_scene as Stage1TeddyBossScene
	_expect(boss_scene != null, "마지막 보상 뒤 실제 보스 씬을 생성해야 한다.")
	if boss_scene == null:
		stage.queue_free()
		await process_frame
		return
	var boss_placement_bridge := boss_scene.get_node(
		^"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	var boss_runtime := boss_scene.get_node(
		^"Stage1TeddyBossRuntime"
	) as Stage1TeddyBossRuntime
	_expect(
		boss_scene is WaveRuntimeCoordinatorFullBleed,
		"보스 웨이브도 일반 웨이브의 전체 화면 카메라를 사용해야 한다."
	)
	boss_scene.call(&"_fit_board_camera", true)
	var boss_viewport_size := boss_scene.get_viewport_rect().size
	if boss_viewport_size.y > 0.0 \
			and boss_viewport_size.x / boss_viewport_size.y \
				>= boss_scene.minimum_full_bleed_aspect:
		var expected_boss_zoom := maxf(
			boss_viewport_size.x
				/ maxf(boss_scene.board_world_bounds.size.x, 1.0),
			boss_viewport_size.y
				/ maxf(boss_scene.board_world_bounds.size.y, 1.0)
		)
		_expect(
			is_equal_approx(boss_scene.board_camera.zoom.x, expected_boss_zoom)
				and boss_scene.board_camera.position.is_equal_approx(
					boss_scene.board_world_bounds.get_center()
				),
			"보스 카메라는 화면 전체를 채우는 확대율과 중앙 위치를 적용해야 한다."
		)
	_expect(
		boss_scene.wave_manager.current_stage_phase
			== WaveManager.StagePhase.REPAIR_PLACEMENT
			and boss_placement_bridge.placement_session.current_state
				== BoardPlacementSession.State.EDITING
			and not boss_runtime.is_battle_active(),
		"보스 전투 전 수리 부품 배치 화면을 먼저 열어야 한다."
	)
	_expect(boss_placement_bridge.commit_placement(),
		"보스 수리 부품 배치를 확정할 수 있어야 한다.")
	await _wait_for_transition()
	_expect(
		boss_scene.wave_manager.current_stage_phase == WaveManager.StagePhase.BOSS
			and boss_runtime.is_battle_active(),
		"수리 부품 배치를 확정한 뒤에만 보스 전투를 시작해야 한다."
	)
	var boss_coin_session := _get_active_coin_session(manager)
	var boss_coin_field := manager.active_scene.get_node(
		^"CoinSystem"
	) as CoinFieldController
	var boss_reward_bridge := manager.active_scene.get_node(
		^"WaveRewardShopBridge"
	) as WaveRewardShopBridge
	_expect(
		manager.current_phase == StageFlowManager.Phase.BOSS
			and boss_scene != null
			and boss_coin_session != null
			and boss_coin_session.wallet == manager.coin_wallet
			and boss_coin_field.remaining_pickup_count() == 0
			and not boss_reward_bridge.embedded_reward_enabled
			and manager.current_coin_balance == 12,
		"마지막 보상 뒤 실제 보스가 공용 코인을 유지한 채 시작되어야 한다."
	)
	await _defeat_active_boss(manager)
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.COMPLETE
			and manager.current_coin_balance == 0,
		"보스 처치로 스테이지가 완료되면 공용 코인 지갑을 초기화해야 한다."
	)

	stage.queue_free()
	await process_frame


func _test_stage_reward_purchase_persistence() -> void:
	var stage := STAGE_01_SCENE.instantiate()
	root.add_child(stage)
	await _wait_for_transition()
	var manager := stage.get_node(^"StageFlowManager") as StageFlowManager
	manager.defeat_destination_scene = null
	manager.failure_overlay_scene = null
	manager.coin_wallet.add(999)
	_complete_active_wave(manager, 1000)
	await _wait_for_transition()

	var reward := manager.active_scene as StageRewardShopScreen
	_expect(
		reward != null and reward.shop_controller != null
			and reward.shop_controller.is_open,
		"웨이브 완료 뒤 실제 보상 상점이 자동으로 열려야 한다."
	)
	if reward == null or reward.shop_controller == null:
		stage.queue_free()
		await process_frame
		return

	var ball_offer := reward.shop_controller.ball_offers[0]
	var part_offer := reward.shop_controller.part_offers[0]
	var initial_part_count := manager.reward_part_inventory.count_of(
		part_offer.part_id
	)
	_expect(reward.shop_controller.buy_ball(0),
		"보상 상점에서 공을 구매할 수 있어야 한다.")
	_expect(reward.shop_controller.buy_part(0),
		"보상 상점에서 수리 부품을 구매할 수 있어야 한다.")
	var expected_part_count := initial_part_count + part_offer.bundle_count
	_expect(reward.continue_stage(),
		"보상 확인 뒤 다음 스테이지 웨이브로 진행해야 한다.")
	await _wait_for_transition()

	var next_ball_inventory := manager.active_scene.get_node(
		^"WaveBallInventory"
	) as SelectBallInventory
	var next_part_inventory := manager.active_scene.get_node(
		^"RepairPartInventory"
	) as RepairPartInventory
	var owned_ball_ids: Array[StringName] = []
	for definition: BallDefinition in next_ball_inventory.get_owned_definitions():
		owned_ball_ids.append(definition.ball_id)
	_expect(
		owned_ball_ids.has(ball_offer.ball_id),
		"구매한 공은 다음 웨이브 공 선택 인벤토리에 유지되어야 한다."
	)
	_expect(
		next_part_inventory.count_of(part_offer.part_id) == expected_part_count,
		"구매한 수리 부품 수량은 다음 웨이브 배치 인벤토리에 유지되어야 한다."
	)
	var embedded_bridge := manager.active_scene.get_node(
		^"WaveRewardShopBridge"
	) as WaveRewardShopBridge
	_expect(
		embedded_bridge != null and not embedded_bridge.embedded_reward_enabled,
		"StageFlowManager 웨이브에서는 내부 보상 브리지를 비활성화해야 한다."
	)
	_complete_active_wave(manager, 1500)
	await _wait_for_transition()
	(manager.active_scene as StageRewardShopScreen).continue_stage()
	await _wait_for_transition()
	_complete_active_wave(manager, 3000)
	await _wait_for_transition()
	(manager.active_scene as StageRewardShopScreen).continue_stage()
	await _wait_frames(6)
	var boss_scene := manager.active_scene as Stage1TeddyBossScene
	_expect(boss_scene != null, "구매 상태를 이어받을 보스 씬을 생성해야 한다.")
	if boss_scene == null:
		stage.queue_free()
		await process_frame
		return
	var boss_placement_bridge := boss_scene.get_node(
		^"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	_expect(
		boss_scene.wave_manager.current_stage_phase
			== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"보상 구매 상태를 유지한 채 보스 수리 부품 배치로 진입해야 한다."
	)
	_expect(boss_placement_bridge.commit_placement(),
		"보스 전투 전에 구매한 수리 부품 배치를 확정할 수 있어야 한다.")
	await _wait_for_transition()

	var boss_inventory := manager.active_scene.get_node(
		^"WaveBallInventory"
	) as SelectBallInventory
	var boss_part_inventory := manager.active_scene.get_node(
		^"RepairPartInventory"
	) as RepairPartInventory
	var boss_owned_ball_ids: Array[StringName] = []
	for definition: BallDefinition in boss_inventory.get_owned_definitions():
		boss_owned_ball_ids.append(definition.ball_id)
	_expect(
		manager.current_phase == StageFlowManager.Phase.BOSS
			and manager.active_scene is Stage1TeddyBossScene
			and boss_owned_ball_ids.has(ball_offer.ball_id)
			and boss_part_inventory.count_of(part_offer.part_id)
				== expected_part_count,
		"보스 씬은 일반 웨이브 보상으로 얻은 공과 부품 상태를 이어받아야 한다."
	)
	await _exhaust_active_boss_balls(manager)
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0
			and manager.current_coin_balance == 0,
		"보스 공 라이프 소진 시 코인을 초기화하고 스테이지 첫 웨이브로 롤백해야 한다."
	)
	_expect(
		manager.stage_ball_inventory.unlocked_ids.is_empty()
			and manager.reward_part_inventory.count_of(part_offer.part_id)
				== initial_part_count,
		"스테이지 롤백은 보상으로 구매한 공과 수리 부품도 시작 상태로 복원해야 한다."
	)

	stage.queue_free()
	await process_frame


func _get_active_coin_session(manager: StageFlowManager) -> WaveCoinSession:
	if manager.active_scene == null:
		return null
	return manager.active_scene.get_node_or_null(
		^"CoinSystem/CoinSession"
	) as WaveCoinSession


func _complete_active_wave(manager: StageFlowManager, target_score: int) -> void:
	var wave_manager := manager.active_scene.get_node(^"WaveManager") as WaveManager
	wave_manager.wave_won.emit(target_score, target_score)


func _test_configuration_validation() -> void:
	var manager := StageFlowManager.new()
	_expect(
		manager.get_configuration_error().contains("at least one wave"),
		"일반 웨이브가 비어 있으면 설정 오류를 알려야 한다."
	)
	var waves: Array[PackedScene] = [WAVE_SCENE, null]
	manager.wave_scenes = waves
	_expect(
		manager.get_configuration_error().contains("Wave scene 2"),
		"웨이브 배열의 빈 항목 위치를 알려야 한다."
	)
	manager.free()


func _test_existing_wave_scene_contracts() -> void:
	var manager := StageFlowManager.new()
	for index in EXISTING_WAVE_SCENES.size():
		var instance := EXISTING_WAVE_SCENES[index].instantiate()
		var binding: Dictionary = manager.call(
			&"_find_completion_binding",
			instance,
			manager.wave_completion_signals
		)
		_expect(
			not binding.is_empty()
				and binding.signal_name == &"wave_won"
				and (binding.source as Node).name == &"WaveManager",
			"기존 웨이브 %d의 WaveManager.wave_won을 자동 탐색해야 한다."
				% (index + 1)
		)
		instance.free()
	manager.free()


func _test_stage_01_scene_configuration() -> void:
	_expect(
		ProjectSettings.get_setting(
			"display/window/stretch/aspect", ""
		) == "keep",
		"웹 화면 크기가 달라도 16:9 UI 프레임의 종횡비를 유지해야 한다."
	)
	var stage := STAGE_01_SCENE.instantiate()
	var manager := stage.get_node(^"StageFlowManager") as StageFlowManager
	var expected_scores := PackedInt32Array([1000, 1500, 3000])
	_expect(manager != null, "Stage 01에 스테이지 진행 매니저가 있어야 한다.")
	if manager == null:
		stage.free()
		return
	_expect(manager.wave_scenes.size() == 3, "Stage 01은 일반 웨이브 3개를 연결해야 한다.")
	_expect(
		manager.boss_scenes.size() == 1
			and manager.boss_scenes[0].resource_path
				== "res://scenes/game/stages/stage_01/boss/stage1_teddy_boss_scene.tscn",
		"Stage 01은 실제 테디 보스 씬 하나를 보스 배열에 직접 연결해야 한다."
	)
	_expect(
		manager.clear_destination_scene != null
			and manager.clear_destination_scene.resource_path
				== "res://scenes/ending/stage1_ending.tscn",
		"Stage 01 클리어는 Stage 1 엔딩 씬으로 이동해야 한다."
	)
	_expect(
		manager.defeat_destination_scene == null
			and manager.failure_overlay_scene != null
			and manager.failure_overlay_scene.resource_path
				== "res://scenes/ending/stage1_game_over.tscn",
		"Stage 01 패배는 엔딩 대신 GAME OVER Overlay를 사용해야 한다."
	)
	for index in mini(manager.wave_scenes.size(), expected_scores.size()):
		var wave := manager.wave_scenes[index].instantiate()
		var settings := wave.get(&"wave_stage_settings") as ComboStageSettings
		var selection_hud := wave.get_node(
			^"HUD/BallSelectionHud"
		) as SelectBallSelectionHud
		_expect(
			settings != null
				and settings.wave_target_scores.size() == 1
				and settings.get_wave_target_score(0) == expected_scores[index],
			"Stage 01 웨이브 %d는 목표 점수 하나(%d)를 가져야 한다."
				% [index + 1, expected_scores[index]]
		)
		_expect(
			selection_hud != null,
			"Stage 01 웨이브 %d는 최신 공 선택 UI를 사용해야 한다."
				% (index + 1)
		)
		_expect(
			wave.get_node_or_null(^"HUD/BumperRosterHud") == null,
			"Stage 01 웨이브 %d는 범퍼 가이드 UI를 제거해야 한다."
				% (index + 1)
		)
		_expect_stage_wave_uses_latest_runtime(wave, index)
		wave.free()
	stage.free()


func _expect_stage_wave_uses_latest_runtime(wave: Node, wave_index: int) -> void:
	var display_index := wave_index + 1
	var bumpers := wave.get_node_or_null(^"Bumpers")
	var all_bumpers_have_art := bumpers != null and bumpers.get_child_count() > 0
	if bumpers != null:
		for bumper: Node in bumpers.get_children():
			var has_art_sprite := false
			for bumper_child: Node in bumper.get_children():
				if bumper_child is Sprite2D \
						and String(bumper_child.name).begins_with("_ArtSprite"):
					has_art_sprite = true
					break
			if not has_art_sprite:
				all_bumpers_have_art = false
				break
	_expect(
		wave is WaveRuntimeCoordinator
			and wave.get_node_or_null(^"WaveBallInventory") is SelectBallInventory
			and wave.get_node_or_null(^"HUD/BallSelectionHud") is SelectBallSelectionHud,
		"Stage 01 웨이브 %d는 최신 웨이브 런타임과 공 선택 시스템을 사용해야 한다."
			% display_index
	)
	_expect(
		all_bumpers_have_art,
		"Stage 01 웨이브 %d의 모든 고정 범퍼에 최신 그래픽 리소스가 있어야 한다."
			% display_index
	)
	_expect(
		wave.get_node_or_null(^"SfxDirector") is SfxDirector
			and wave.get_node_or_null(^"_WaveSfxBinder") is WaveSfxBinderStrict,
		"Stage 01 웨이브 %d는 최신 SFX 디렉터와 엄격 바인더를 사용해야 한다."
			% display_index
	)
	_expect(
		wave.get_node_or_null(^"WaveRepairEffects/RepairEffectRouter")
			is RepairEffectRouter,
		"Stage 01 웨이브 %d는 최신 수리 부품 효과 라우터를 사용해야 한다."
			% display_index
	)
	var coin_icon := wave.get_node_or_null(
		^"HUD/WaveHud/DesignSpace/CoinWalletHud/Margin/Row/CoinIcon"
	) as TextureRect
	_expect(
		wave.get_node_or_null(^"CoinSystem") is CoinFieldController
			and coin_icon != null
			and coin_icon.texture != null
			and coin_icon.texture.resource_path
				== "res://Resources/Art/coin/coin.png",
		"Stage 01 웨이브 %d는 pre-main 코인 아트를 필드와 HUD에 함께 사용해야 한다."
			% display_index
	)


func _create_manager(
	waves: Array[PackedScene],
	bosses: Array[PackedScene]
) -> StageFlowManager:
	var manager := MANAGER_SCENE.instantiate() as StageFlowManager
	manager.auto_start = false
	manager.wave_scenes = waves
	manager.boss_scenes = bosses
	manager.reward_scene = PLACEHOLDER_REWARD_SCENE
	root.add_child(manager)
	return manager


func _destroy_manager(manager: StageFlowManager) -> void:
	manager.queue_free()
	await process_frame


func _wait_for_transition() -> void:
	await process_frame
	await process_frame


func _wait_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame


func _defeat_active_boss(manager: StageFlowManager) -> void:
	var runtime := manager.active_scene.get_node(
		^"Stage1TeddyBossRuntime"
	) as Stage1TeddyBossRuntime
	var health := runtime.get_node(
		^"Components/BossHealthComponent"
	) as BossHealthComponent
	health.apply_damage(health.get_current_health())
	await runtime.battle_completed


func _exhaust_active_boss_balls(manager: StageFlowManager) -> void:
	var flow := manager.active_scene.get_node(
		^"WaveBallFlowController"
	) as WaveBallFlowController
	var launcher := manager.active_scene.get_node(
		^"PinballLauncher"
	) as PinballLauncher
	for _launch_index in WaveManager.BALLS_PER_WAVE:
		_expect(flow.confirm_selection(), "보스 공을 선택할 수 있어야 한다.")
		var active_ball := flow.active_ball
		_expect(launcher.launch_prepared_ball(), "보스 공을 발사할 수 있어야 한다.")
		_expect(flow.on_ball_drained(active_ball), "보스 공 낙하를 처리할 수 있어야 한다.")
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_flow_manager_test")
		quit(0)
		return
	print("FAIL: stage_flow_manager_test (%d failures)" % _failures.size())
	for failure in _failures:
		print(" - %s" % failure)
	quit(1)
