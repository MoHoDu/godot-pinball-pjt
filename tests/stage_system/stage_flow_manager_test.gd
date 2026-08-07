extends SceneTree


const MANAGER_SCENE := preload(
	"res://scenes/stage_system/stage_flow_manager.tscn"
)
const STAGE_01_SCENE := preload("res://scenes/stage_01.tscn")
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
	preload("res://scenes/wave/levels/wave_01.tscn"),
	preload("res://scenes/wave/levels/wave_02.tscn"),
	preload("res://scenes/wave/levels/wave_03.tscn"),
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
	var first_roster := manager.active_scene.get_node(
		^"HUD/BumperRosterHud"
	) as BumperRosterHud
	var first_ball_hud := manager.active_scene.get_node(
		^"HUD/BallSelectionHud"
	) as SelectBallSelectionHud
	var first_wallet_label := manager.active_scene.get_node(
		^"HUD/WaveHud/DesignSpace/CoinWalletHud/Margin/Row/BalanceLabel"
	) as Label
	_expect(
		first_roster.visible and first_roster.position.y <= 20.0,
		"범퍼 가이드는 배치 단계에만 보드 위쪽 안전 영역에 표시되어야 한다."
	)
	_expect(
		first_ball_hud != null
			and first_ball_hud.get_node_or_null(^"Center/Panel") != null
			and first_ball_hud.get_node_or_null(^"Panel") == null,
		"Stage 01은 레거시 공 설명 대신 최신 공 선택 UI를 사용해야 한다."
	)
	_expect(first_wave_manager.advance_stage_phase(), "첫 웨이브 플레이 단계에 진입해야 한다.")
	await process_frame
	_expect(not first_roster.visible, "배치가 끝나면 범퍼 가이드를 숨겨야 한다.")
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
	await process_frame
	_expect(
		manager.current_coin_balance == 2
			and first_coin_field.board_coin_this_wave == 2
			and first_wallet_label.text == "× 2",
		"웨이브 코인 획득은 스테이지 공용 지갑에 즉시 반영되어야 한다."
	)
	test_ball.queue_free()
	manager.coin_wallet.add(5)
	_complete_active_wave(manager, 300)
	await _wait_for_transition()
	var first_reward := manager.active_scene as StageRewardPlaceholder
	_expect(
		manager.current_coin_balance == 7
			and first_reward != null
			and first_reward.description_label.text.contains("보유 코인: 7"),
		"웨이브 획득 코인은 보상 페이지까지 유지되고 표시되어야 한다."
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
	_complete_active_wave(manager, 500)
	await _wait_for_transition()
	var second_reward := manager.active_scene as StageRewardPlaceholder
	_expect(
		manager.current_coin_balance == 12
			and second_reward.description_label.text.contains("보유 코인: 12"),
		"두 번째 웨이브 코인은 기존 잔액에 누적되어야 한다."
	)
	second_reward.continue_stage()
	await _wait_for_transition()

	var third_session := _get_active_coin_session(manager)
	_expect(
		third_session != null and third_session.wallet.balance == 12,
		"마지막 웨이브 진입 전까지 누적 코인을 유지해야 한다."
	)
	var third_wave_manager := manager.active_scene.get_node(^"WaveManager") as WaveManager
	third_wave_manager.wave_lost.emit(0, 1000)
	_expect(manager.current_coin_balance == 0, "게임 오버는 스테이지 공용 지갑도 초기화해야 한다.")
	manager.coin_wallet.add(9)
	_complete_active_wave(manager, 1000)
	await _wait_for_transition()
	var final_reward := manager.active_scene as StageRewardPlaceholder
	_expect(
		final_reward != null
			and final_reward.description_label.text.contains("보유 코인: 9"),
		"마지막 웨이브 보상에서도 현재 코인을 확인할 수 있어야 한다."
	)
	final_reward.continue_stage()
	await _wait_for_transition()
	_expect(
		manager.current_phase == StageFlowManager.Phase.COMPLETE
			and manager.current_coin_balance == 0,
		"스테이지 완료 시 공용 코인 지갑을 초기화해야 한다."
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
	var stage := STAGE_01_SCENE.instantiate()
	var manager := stage.get_node(^"StageFlowManager") as StageFlowManager
	var expected_scores := PackedInt32Array([300, 500, 1000])
	_expect(manager != null, "Stage 01에 스테이지 진행 매니저가 있어야 한다.")
	if manager == null:
		stage.free()
		return
	_expect(manager.wave_scenes.size() == 3, "Stage 01은 일반 웨이브 3개를 연결해야 한다.")
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
		_expect_stage_wave_uses_latest_runtime(wave, index)
		wave.free()
	stage.free()


func _expect_stage_wave_uses_latest_runtime(wave: Node, wave_index: int) -> void:
	var display_index := wave_index + 1
	var bumpers := wave.get_node_or_null(^"Bumpers")
	var all_bumpers_have_art := bumpers != null and bumpers.get_child_count() >= 6
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
				== "res://Resources/wave_hud/coin_wallet_icon.png",
		"Stage 01 웨이브 %d는 최신 코인 필드와 HUD 리소스를 사용해야 한다."
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
	root.add_child(manager)
	return manager


func _destroy_manager(manager: StageFlowManager) -> void:
	manager.queue_free()
	await process_frame


func _wait_for_transition() -> void:
	await process_frame
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
