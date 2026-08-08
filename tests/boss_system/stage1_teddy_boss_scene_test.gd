extends SceneTree


const BossScene: PackedScene = preload(
	"res://scenes/wave/stage1_teddy_boss_scene.tscn"
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
	_expect(BossScene != null and BossScene.can_instantiate(),
		"Stage 1 Teddy Boss scene must load.")
	if BossScene == null or not BossScene.can_instantiate():
		_finish()
		return

	var scene := BossScene.instantiate() as WaveRuntimeCoordinator
	var manager := scene.get_node("WaveManager") as WaveManager
	var visited_phases: Array[WaveManager.StagePhase] = []
	var normal_wave_entries: Array[int] = []
	manager.stage_phase_changed.connect(func(
		_previous: WaveManager.StagePhase,
		current: WaveManager.StagePhase
	) -> void:
		visited_phases.append(current)
	)
	manager.wave_entered.connect(func(
		_stage_id: StringName,
		wave_index: int,
		_target_score: int
	) -> void:
		normal_wave_entries.append(wave_index)
	)
	root.add_child(scene)
	for _frame: int in 5:
		await process_frame

	var boss := scene.get_node("Stage1TeddyBossRuntime") \
		as Stage1TeddyBossRuntime
	var bridge := scene.get_node("Stage1TeddyBossWaveBridge") \
		as Stage1TeddyBossWaveBridge
	var flow := scene.get_node("WaveBallFlowController") \
		as WaveBallFlowController
	var launcher := scene.get_node("PinballLauncher") as PinballLauncher
	var placement := scene.get_node("RepairBoardLayout/PlacementSession") \
		as BoardPlacementSession
	var feedback := boss.get_node(
		"Feedback/TeddyBossFeedbackController"
	) as TeddyBossFeedbackController
	var feedback_ports := boss.get_node_or_null(
		"Feedback/TeddyBossFeedbackPorts"
	)
	var presentation := boss.get_node_or_null(
		"Feedback/TeddyBossPresentationBridge"
	) as TeddyBossPresentationBridge
	var art_rig := boss.get_node_or_null("Presentation/Rig") as BossArtRig
	var boss_vfx := boss.get_node_or_null("Presentation/Vfx") as BossVfxLayer
	var bgm := scene.get_node_or_null("BgmPlayer") as AudioStreamPlayer

	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss scene must start directly in BOSS.")
	_expect(visited_phases == [WaveManager.StagePhase.BOSS],
		"Boss scene must not visit repair placement, normal Wave, or reward.")
	_expect(normal_wave_entries.is_empty(),
		"Boss scene must not start a normal Wave.")
	_expect(placement.current_state == BoardPlacementSession.State.IDLE,
		"Boss scene must not begin repair placement.")
	_expect(bridge.is_ready(), "Production Boss bridge must be ready.")
	_expect(boss.is_ready() and boss.is_battle_active(),
		"Production Boss Runtime must be active.")
	_expect(manager.is_boss_ball_cycle_active(),
		"Boss Ball cycle must be active.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING,
		"Boss Ball cycle must expose existing Ball selection.")
	_expect(scene.get_node_or_null("BoardBackground") != null,
		"Boss scene must reuse the production Board.")
	_expect(scene.get_node_or_null("Walls") != null,
		"Boss scene must reuse production Walls.")
	_expect(scene.get_node_or_null("Bumpers") != null,
		"Boss scene must reuse production Bumpers.")
	_expect(scene.get_node_or_null("BossDebugCanvas") == null,
		"Boss scene must not contain Debug UI.")
	_expect(feedback != null and feedback.is_ready(),
		"Boss scene must expose the production Feedback Controller.")
	_expect(feedback_ports != null,
		"Boss scene must expose Feedback Ports.")
	_expect(presentation != null and presentation.is_ready(),
		"Boss scene must bridge runtime feedback into presentation.")
	if presentation != null:
		_expect(feedback.arm_ball_reflected.is_connected(Callable(
			presentation, &"_on_arm_ball_reflected"
		)), "Impact VFX must use the post-reflection Ball direction.")
	_expect(art_rig != null and boss_vfx != null,
		"Boss scene must include production art and VFX.")
	_expect(bgm != null and bgm.stream != null and bgm.stream.resource_path
			== "res://Resources/sfx/bgm/BGM_Boss_Loop.wav",
		"Boss scene must override the wave ambience with the Boss BGM.")
	await _test_production_presentation_feedback(scene, feedback, art_rig)
	_test_no_duplicate_gameplay_systems(scene, boss)

	_expect(flow.confirm_selection(),
		"Boss scene must prepare a Ball through existing selection.")
	var ball: Pinball = flow.active_ball
	_expect(is_instance_valid(ball), "Boss selection must create a Pinball.")
	_expect(launcher.launch_prepared_ball(),
		"Boss scene must launch through the existing Launcher.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss launch must preserve BOSS.")

	var health := boss.get_node("Components/BossHealthComponent") \
		as BossHealthComponent
	var threshold_hp: int = int(
		float(health.get_max_health()) * boss.phase1_rules.phase2_hp_ratio
	)
	health.apply_damage(health.get_current_health() - threshold_hp)
	await process_frame
	_expect(boss.phase_transition.is_phase_2(),
		"Boss scene must support Phase 2.")
	_expect(boss.get_active_cotton_count() == 2,
		"Phase 2 must spawn two Cursed Cottons.")

	health.apply_damage(health.get_current_health())
	await process_frame
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"Boss defeat must complete the stage.")
	_expect(not manager.is_boss_ball_cycle_active(),
		"Boss defeat must finish the Boss Ball cycle.")
	_expect(not boss.is_battle_active(),
		"Boss defeat must stop the Boss Runtime.")

	scene.queue_free()
	await process_frame
	_finish()


func _test_production_presentation_feedback(
	scene: WaveRuntimeCoordinator,
	feedback: TeddyBossFeedbackController,
	rig: BossArtRig
) -> void:
	var binder := scene.get_node_or_null("_WaveSfxBinder") as WaveSfxBinder
	var played: Array[StringName] = []
	_expect(binder != null and binder.boss_rules != null,
		"Production Boss scene must keep Boss SFX rules.")
	if binder == null:
		return
	binder.get_director().cue_played.connect(func(
		cue_id: StringName,
		_pitch: float,
		_volume: float,
		_speed: float
	) -> void:
		played.append(cue_id)
	)

	feedback.attack_telegraph_started.emit(1)
	await process_frame
	_expect(rig.get_state() == &"telegraph",
		"Telegraph feedback must drive the production art rig.")
	_expect(&"boss_telegraph" in played,
		"Telegraph feedback must play the Boss telegraph SFX.")

	feedback.attack_active_started.emit(1)
	await process_frame
	_expect(rig.get_state() == &"attack",
		"Active attack feedback must drive the production art rig.")
	_expect(&"boss_arm_swing" in played,
		"Active attack feedback must play the Boss arm SFX.")

	feedback.boss_hit_feedback.emit(10, true)
	await process_frame
	_expect(rig.get_expression() == &"hit_strong",
		"Counter hit feedback must drive the strong hit presentation.")
	_expect(&"boss_hit" in played,
		"Boss hit feedback must play the production hit SFX.")


func _test_no_duplicate_gameplay_systems(
	scene: WaveRuntimeCoordinator,
	boss: Stage1TeddyBossRuntime
) -> void:
	_expect(_count_wave_managers(scene) == 1,
		"Boss scene must contain exactly one WaveManager.")
	_expect(_count_ball_flows(scene) == 1,
		"Boss scene must contain exactly one BallFlow.")
	_expect(_count_script(scene, ComboSystemScript) == 1,
		"Boss scene must contain exactly one ComboSystem.")
	_expect(_count_script(scene, FlipperScript) == 8,
		"Boss scene must reuse exactly eight Flippers.")
	_expect(_count_wave_managers(boss) == 0,
		"Boss Runtime must not duplicate WaveManager.")
	_expect(_count_ball_flows(boss) == 0,
		"Boss Runtime must not duplicate BallFlow.")
	_expect(_count_script(boss, ComboSystemScript) == 0,
		"Boss Runtime must not duplicate ComboSystem.")
	_expect(_count_script(boss, FlipperScript) == 0,
		"Boss Runtime must not duplicate Flippers.")


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
		print("Stage 1 Teddy Boss direct scene tests passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
