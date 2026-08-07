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
		_expect(
			settings != null
				and settings.wave_target_scores.size() == 1
				and settings.get_wave_target_score(0) == expected_scores[index],
			"Stage 01 웨이브 %d는 목표 점수 하나(%d)를 가져야 한다."
				% [index + 1, expected_scores[index]]
		)
		wave.free()
	stage.free()


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
