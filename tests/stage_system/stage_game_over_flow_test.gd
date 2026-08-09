extends SceneTree


const MANAGER_SCENE := preload(
	"res://Resources/Prefabs/stage/flow/stage_flow_manager.tscn"
)
const FAILURE_SCENE := preload(
	"res://tests/stage_system/fixtures/stage_failure_fixture.tscn"
)
const REWARD_SCENE := preload(
	"res://scenes/tests/stage/fixtures/stage_reward_placeholder.tscn"
)
const GAME_OVER_SCENE := preload(
	"res://scenes/ending/stage1_game_over.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_wave_failure_restarts_once()
	await _test_boss_failure_restarts_once()
	if _failures.is_empty():
		print("PASS: stage_game_over_flow_test")
		quit(0)
		return
	print("FAIL: stage_game_over_flow_test (%d failures)" % _failures.size())
	quit(1)


func _test_wave_failure_restarts_once() -> void:
	var manager := _create_manager([])
	var failure_count := {&"value": 0}
	manager.stage_failed.connect(func(_index: int) -> void:
		failure_count.value += 1
	)
	manager.start_stage()
	manager.active_scene.call(&"fail")
	manager.active_scene.call(&"fail")
	await _wait_for_restart(manager)
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0,
		"Wave failure must restart at Wave 1."
	)
	_expect(failure_count.value == 1, "Duplicate wave failure must restart once.")
	manager.queue_free()
	await process_frame


func _test_boss_failure_restarts_once() -> void:
	var bosses: Array[PackedScene] = [FAILURE_SCENE]
	var manager := _create_manager(bosses)
	var failure_count := {&"value": 0}
	manager.stage_failed.connect(func(_index: int) -> void:
		failure_count.value += 1
	)
	manager.start_stage()
	manager.active_scene.call(&"complete")
	await _wait_frames(2)
	(manager.active_scene as StageRewardPlaceholder).continue_stage()
	await _wait_frames(2)
	manager.active_scene.call(&"fail")
	manager.active_scene.call(&"fail")
	await _wait_for_restart(manager)
	_expect(
		manager.current_phase == StageFlowManager.Phase.WAVE
			and manager.current_wave_index == 0,
		"Boss failure must restart at Wave 1."
	)
	_expect(failure_count.value == 1, "Duplicate boss failure must restart once.")
	manager.queue_free()
	await process_frame


func _create_manager(bosses: Array[PackedScene]) -> StageFlowManager:
	var manager := MANAGER_SCENE.instantiate() as StageFlowManager
	manager.auto_start = false
	var waves: Array[PackedScene] = [FAILURE_SCENE]
	manager.wave_scenes = waves
	manager.boss_scenes = bosses
	manager.reward_scene = REWARD_SCENE
	manager.failure_overlay_scene = _fast_overlay_scene()
	root.add_child(manager)
	return manager


func _fast_overlay_scene() -> PackedScene:
	var overlay: Node = GAME_OVER_SCENE.instantiate()
	overlay.set(&"screen_fade_duration", 0.01)
	overlay.set(&"logo_fade_in_duration", 0.01)
	overlay.set(&"logo_hold_duration", 0.01)
	overlay.set(&"logo_fade_out_duration", 0.01)
	overlay.set(&"screen_fade_out_duration", 0.01)
	var packed := PackedScene.new()
	packed.pack(overlay)
	overlay.free()
	return packed


func _wait_for_restart(manager: StageFlowManager) -> void:
	for _frame in 30:
		await process_frame
		if manager.current_phase == StageFlowManager.Phase.WAVE \
				and manager.current_wave_index == 0 \
				and manager.get_node_or_null(^"Stage1GameOver") == null:
			return


func _wait_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)
