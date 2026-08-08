extends SceneTree


const DebugWaveScene: PackedScene = preload(
	"res://scenes/tests/boss/debug_teddy_boss_wave.tscn"
)
const ProductionWaveScene: PackedScene = preload(
	"res://scenes/game/stages/stage_01/boss/stage1_teddy_boss_wave.tscn"
)
const ComboSystemScript: Script = preload(
	"res://scripts/combo_system/combo_system.gd"
)
const FlipperScript: Script = preload(
	"res://scripts/flipper_system/flipper.gd"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(DebugWaveScene != null and DebugWaveScene.can_instantiate(),
		"Debug Teddy Boss Wave scene must load.")
	if DebugWaveScene == null or not DebugWaveScene.can_instantiate():
		_finish()
		return

	var wave: DebugTeddyBossWave = DebugWaveScene.instantiate() \
		as DebugTeddyBossWave
	root.add_child(wave)
	for _frame: int in 12:
		await process_frame

	var manager: WaveManager = wave.wave_manager
	var flow: WaveBallFlowController = wave.wave_ball_flow
	var launcher: PinballLauncher = wave.launcher
	var boss := wave.get_node("Stage1TeddyBossRuntime") \
		as Stage1TeddyBossRuntime
	_expect(_count_wave_managers(wave) == 1,
		"Debug inheritance must keep one production WaveManager.")
	_expect(_count_script(wave, ComboSystemScript) == 1,
		"Debug inheritance must keep one production ComboSystem.")
	_expect(_count_ball_flows(wave) == 1,
		"Debug inheritance must keep one production BallFlow.")
	_expect(_count_script(wave, FlipperScript) == 8,
		"Debug inheritance must keep the eight production Flippers.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Debug entry must reach BOSS through public stage transitions.")
	_expect(boss.is_battle_active(),
		"Production Teddy Boss Runtime must be active.")
	_expect(manager.is_boss_ball_cycle_active(),
		"Production Boss Ball cycle must be active.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Boss Ball cycle must expose existing Ball selection.")
	_expect(flow.confirm_selection(),
		"Debug Boss cycle must prepare a production inventory Ball.")
	_expect(launcher.launch_prepared_ball(),
		"Debug Boss cycle must launch through the production Launcher.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss Ball launch must preserve BOSS.")

	var phase_button := wave.get_node(
		"BossDebugCanvas/BossDebugPanel/BossDebugVBox/Phase2Button"
	) as Button
	phase_button.pressed.emit()
	await process_frame
	_expect(boss.phase_transition.is_phase_2(),
		"HP debug action must enter Phase 2 through Health damage.")
	var defeat_button := wave.get_node(
		"BossDebugCanvas/BossDebugPanel/BossDebugVBox/DefeatButton"
	) as Button
	defeat_button.pressed.emit()
	await process_frame
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"HP zero debug action must preserve production battle completion.")

	wave.queue_free()
	await process_frame

	var production_wave := ProductionWaveScene.instantiate() \
		as WaveRuntimeCoordinator
	root.add_child(production_wave)
	await process_frame
	await process_frame
	_expect(
		production_wave.wave_manager.current_stage_phase \
			== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Production scene must still start at normal Wave repair placement."
	)
	var production_boss := production_wave.get_node(
		"Stage1TeddyBossRuntime"
	) as Stage1TeddyBossRuntime
	_expect(not production_boss.is_battle_active(),
		"Production scene must not inherit Debug auto-entry behavior.")
	production_wave.queue_free()
	await process_frame
	_finish()


func _count_script(node: Node, target_script: Script) -> int:
	var count: int = 1 if node.get_script() == target_script else 0
	for child: Node in node.get_children():
		count += _count_script(child, target_script)
	return count


func _count_wave_managers(node: Node) -> int:
	var count: int = 1 if node is WaveManager else 0
	for child: Node in node.get_children():
		count += _count_wave_managers(child)
	return count


func _count_ball_flows(node: Node) -> int:
	var count: int = 1 if node is WaveBallFlowController else 0
	for child: Node in node.get_children():
		count += _count_ball_flows(child)
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Debug Teddy Boss Wave scene tests passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
