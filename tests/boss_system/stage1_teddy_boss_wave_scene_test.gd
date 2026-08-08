extends SceneTree


const ProductionWaveScene: PackedScene = preload(
	"res://scenes/wave/stage1_teddy_boss_wave.tscn"
)
const ComboSystemScript: Script = preload(
	"res://scripts/combo_system/combo_system.gd"
)
const FlipperScript: Script = preload(
	"res://scripts/flipper_system/flipper.gd"
)
const WaveHudScript: Script = preload(
	"res://scripts/wave_hud/wave_hud.gd"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_expect(
		ProductionWaveScene != null and ProductionWaveScene.can_instantiate(),
		"Stage 1 Teddy production Wave scene must load."
	)
	if ProductionWaveScene == null or not ProductionWaveScene.can_instantiate():
		_finish()
		return

	var wave: WaveRuntimeCoordinator = (
		ProductionWaveScene.instantiate() as WaveRuntimeCoordinator
	)
	root.add_child(wave)
	await process_frame
	await process_frame
	await process_frame

	var bridge := wave.get_node_or_null("Stage1TeddyBossWaveBridge") \
		as Stage1TeddyBossWaveBridge
	var boss := wave.get_node_or_null("Stage1TeddyBossRuntime") \
		as Stage1TeddyBossRuntime
	var manager := wave.get_node_or_null("WaveManager") as WaveManager
	var combo := wave.get_node_or_null("ComboSystem") as ComboSystem
	var ball_flow := wave.get_node_or_null(
		"WaveBallFlowController"
	) as WaveBallFlowController
	var launcher := wave.get_node_or_null("PinballLauncher") as PinballLauncher
	var placement_bridge := wave.get_node_or_null(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge
	var hud := wave.get_node_or_null("HUD/WaveHud") as WaveHud
	var hud_state := wave.get_node_or_null(
		"WaveHudStateSource"
	) as WaveHudStateSource

	for check: Array in [
		[bridge, "Production Boss bridge must exist."],
		[boss, "Boss-only production Runtime must exist."],
		[manager, "Existing WaveManager must be reused."],
		[combo, "Existing ComboSystem must be reused."],
		[ball_flow, "Existing BallFlow must be reused."],
		[launcher, "Existing Launcher must be reused."],
		[placement_bridge, "Existing Board placement bridge must be reused."],
		[hud, "Existing WaveHud must be reused."],
		[hud_state, "Existing HUD state source must be reused."],
	]:
		_expect(check[0] != null, String(check[1]))
	if bridge == null or boss == null or manager == null or combo == null \
			or ball_flow == null or launcher == null \
			or placement_bridge == null or hud == null \
			or hud_state == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_test_no_duplicate_wave_systems(wave, boss)
	_expect(bridge.is_ready(), "Bridge must bind the production Wave instances.")
	_expect(boss.is_ready(), "Boss Runtime must finish production setup.")
	_expect(not boss.is_battle_active(),
		"Boss Runtime must stay inactive before the BOSS phase.")
	_expect(not boss.visible, "Boss visuals must be hidden before BOSS.")

	await _advance_three_normal_waves(
		manager,
		placement_bridge,
		ball_flow,
		launcher,
		combo
	)
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Three normal Waves must lead to BOSS.")
	_expect(boss.is_battle_active(), "Entering BOSS must start Teddy Runtime.")
	_expect(
		not boss.pattern_1_attack.visible
			and not boss.pattern_2_attack.visible,
		"Production Boss must keep legacy attack placeholders hidden."
	)
	_expect(manager.is_boss_ball_cycle_active(),
		"Entering BOSS must start the managed Boss Ball cycle.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss Ball selection must preserve the BOSS phase.")
	_expect(not manager.advance_stage_phase(),
		"BOSS must not advance before battle completion.")
	_expect(hud.get_stage_phase_button().disabled,
		"BOSS placeholder advance must be disabled until defeat.")
	_expect(
		not bool(hud_state.get_snapshot().get(
			&"stage_phase_placeholder_visible", true
		)),
		"BOSS placeholder overlay must be hidden during the live battle."
	)

	await _test_existing_ball_damage_counter_and_phase(wave, boss, ball_flow)
	await _test_battle_completion(manager, boss, ball_flow, hud)

	wave.queue_free()
	await process_frame
	_finish()


func _test_no_duplicate_wave_systems(
	wave: WaveRuntimeCoordinator,
	boss: Stage1TeddyBossRuntime
) -> void:
	_expect(_count_script(wave, ComboSystemScript) == 1,
		"Production Wave must contain exactly one ComboSystem.")
	_expect(_count_wave_managers(wave) == 1,
		"Production Wave must contain exactly one WaveManager.")
	_expect(_count_ball_flows(wave) == 1,
		"Production Wave must contain exactly one BallFlow.")
	_expect(_count_script(wave, FlipperScript) == 8,
		"Production Wave must reuse exactly eight Flippers.")
	_expect(_count_script(boss, ComboSystemScript) == 0,
		"Boss-only Runtime must not contain ComboSystem.")
	_expect(_count_wave_managers(boss) == 0,
		"Boss-only Runtime must not contain WaveManager.")
	_expect(_count_ball_flows(boss) == 0,
		"Boss-only Runtime must not contain BallFlow.")
	_expect(_count_script(boss, FlipperScript) == 0,
		"Boss-only Runtime must not create Flippers.")
	_expect(_count_script(boss, WaveHudScript) == 0,
		"Boss-only Runtime must not contain production or Debug HUD.")


func _advance_three_normal_waves(
	manager: WaveManager,
	placement_bridge: BoardWavePlacementBridge,
	ball_flow: WaveBallFlowController,
	launcher: PinballLauncher,
	combo: ComboSystem
) -> void:
	for wave_index: int in 3:
		_expect(placement_bridge.commit_placement(),
			"Repair placement must be committed before each normal Wave.")
		_expect(ball_flow.confirm_selection(),
			"Existing BallFlow must prepare the selected Ball.")
		var active_ball: Pinball = ball_flow.active_ball
		_expect(launcher.launch_prepared_ball(),
			"Existing Launcher must launch the selected Ball.")
		combo.stage_base_score = manager.target_score
		combo.register_hit(1.0)
		combo.finish_combo(ComboSystem.EndReason.MANUAL)
		if ball_flow.current_state == WaveBallFlowController.State.IN_PLAY:
			_expect(ball_flow.on_ball_drained(active_ball),
				"Normal Wave Ball must settle through the existing BallFlow.")
		await process_frame
		await process_frame
		_expect(
			manager.current_stage_phase in [
				WaveManager.StagePhase.WAVE_RESULT,
				WaveManager.StagePhase.REWARD,
			],
			"Normal Wave clear must reach its result or reward phase."
		)
		if manager.current_stage_phase == WaveManager.StagePhase.WAVE_RESULT:
			_expect(manager.advance_stage_phase(),
				"WAVE_RESULT must advance to REWARD.")
		_expect(manager.current_stage_phase == WaveManager.StagePhase.REWARD,
			"Normal Wave result must expose REWARD before continuing.")
		_expect(manager.advance_stage_phase(),
			"REWARD must advance to the next Wave or BOSS.")
		if wave_index < 2:
			_expect(
				manager.current_stage_phase \
					== WaveManager.StagePhase.REPAIR_PLACEMENT,
				"The first two rewards must return to repair placement."
			)


func _test_existing_ball_damage_counter_and_phase(
	wave: WaveRuntimeCoordinator,
	boss: Stage1TeddyBossRuntime,
	ball_flow: WaveBallFlowController
) -> void:
	var health := boss.get_node("Components/BossHealthComponent") \
		as BossHealthComponent
	var transition := boss.get_node("Components/BossPhaseTransitionController") \
		as BossPhaseTransitionController
	var tracker := boss.get_node("Components/BossArmHitBallTracker") \
		as BossArmHitBallTracker
	var window := boss.get_node("Components/BossCounterWindow") \
		as BossCounterWindow
	var attack := boss.get_node("TeddyArmSweepAttack") as TeddyArmSweepAttack
	var pattern_2 := boss.get_node(
		"TeddyDoubleArmUpSweepAttack"
	) as TeddyDoubleArmUpSweepAttack
	var controller := boss.get_node("BossAttackController") \
		as BossAttackController
	var scheduler := boss.get_node("AttackLoop/Scheduler") \
		as BossPhase1AttackScheduler
	var hurtbox := boss.get_node("BossHurtbox") as Area2D
	var flipper := wave.get_node(
		"FlipperSelector/BottomController/LeftFlipper"
	) as PinballFlipper
	_expect(
		ball_flow.current_state == WaveBallFlowController.State.SELECTING,
		"Boss Ball cycle must reuse existing Ball selection."
	)
	_expect(ball_flow.confirm_selection(),
		"Boss Ball cycle must prepare an existing inventory Ball.")
	var ball: Pinball = ball_flow.active_ball
	var launcher := wave.get_node("PinballLauncher") as PinballLauncher
	_expect(is_instance_valid(ball),
		"Boss Ball selection must create the actual active Pinball.")
	_expect(launcher.launch_prepared_ball(),
		"Boss Ball cycle must use the existing Launcher.")
	_expect(ball_flow.current_state == WaveBallFlowController.State.IN_PLAY,
		"Boss Ball launch must enter the existing in-play state.")
	_expect(
		wave.wave_manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss Ball launch must not replace the BOSS phase."
	)
	ball.global_position = Vector2(-200.0, -100.0)

	var hp_before: int = health.get_current_health()
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() < hp_before,
		"Boss Hurtbox must apply damage through the existing ComboSystem.")
	hurtbox.body_exited.emit(ball)

	attack.attack_hit.emit(ball)
	_expect(tracker.is_ball_tracked(ball),
		"Arm hit must track the same production Pinball instance.")
	flipper.parry_resolved.emit(
		ball,
		FlipperParryEvaluator.Grade.PERFECT,
		Vector2.ZERO,
		0,
		0.0,
		1.0
	)
	_expect(window.is_ready(), "PERFECT on the tracked Ball must ready Counter.")
	hurtbox.body_entered.emit(ball)
	_expect(not window.is_ready(),
		"The next valid Boss hit must consume Counter exactly once.")
	hurtbox.body_exited.emit(ball)
	_expect(ball_flow.on_ball_drained(ball),
		"Boss Ball drain must use the existing BallFlow contract.")
	await process_frame
	_expect(
		wave.wave_manager.current_stage_phase == WaveManager.StagePhase.BOSS,
		"Boss Ball drain must preserve the BOSS phase."
	)
	_expect(
		ball_flow.current_state == WaveBallFlowController.State.SELECTING,
		"A Boss Ball drain with stock remaining must select the next Ball."
	)
	_expect(ball_flow.confirm_selection(),
		"The next Boss Ball must come from the existing inventory.")
	ball = ball_flow.active_ball
	_expect(launcher.launch_prepared_ball(),
		"The next Boss Ball must use the existing Launcher.")

	var threshold_hp: int = int(
		float(health.get_max_health()) * boss.phase1_rules.phase2_hp_ratio
	)
	health.apply_damage(maxi(health.get_current_health() - threshold_hp, 1))
	await process_frame
	_expect(transition.is_phase_2(), "HP threshold must enter Phase 2.")
	_expect(boss.get_active_cotton_count() == 2,
		"Phase 2 must spawn exactly two Cursed Cottons.")

	scheduler.advance_time(2.8)
	_expect(boss.get_current_pattern_number() == 1,
		"The first Phase 2 request must select Pattern 1.")
	controller.cancel_attack()
	scheduler.advance_time(3.8)
	_expect(boss.get_current_pattern_number() == 2,
		"The next Phase 2 request must select Pattern 2.")
	_expect(controller.attack == pattern_2,
		"Controller must own only the selected Pattern 2 Attack.")
	_expect(boss.arm_ball_reflector.is_bound(),
		"Production Arm Reflector must remain bound to Pattern 2.")
	await controller.active_started
	ball.freeze = false
	ball.gravity_scale = 0.0
	ball.linear_velocity = Vector2(120.0, -180.0)
	await physics_frame
	var velocity_before_pattern_2: Vector2 = ball.linear_velocity
	pattern_2.attack_hit.emit(ball)
	await physics_frame
	await physics_frame
	_expect(tracker.is_ball_tracked(ball),
		"Pattern 2 attack_hit must bind to the existing Ball Tracker.")
	_expect(ball.linear_velocity != velocity_before_pattern_2,
		"Pattern 2 attack_hit must use the existing Arm Reflector. before=%s after=%s" % [
			velocity_before_pattern_2,
			"%s freeze=%s sleeping=%s mass=%s" % [
				ball.linear_velocity, ball.freeze, ball.sleeping, ball.mass
			]
		])
	flipper.parry_resolved.emit(
		ball,
		FlipperParryEvaluator.Grade.PERFECT,
		Vector2.ZERO,
		0,
		0.0,
		1.0
	)
	_expect(window.is_ready(),
		"Pattern 2 tracked Ball PERFECT must ready Counter.")
	var active_hp: int = health.get_current_health()
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() == active_hp,
		"ACTIVE Boss Damage Gate must preserve HP.")
	_expect(window.is_ready(),
		"ACTIVE damage blocking must preserve the ready Counter.")
	hurtbox.body_exited.emit(ball)
	await controller.recovery_started
	hurtbox.body_entered.emit(ball)
	_expect(health.get_current_health() < active_hp,
		"RECOVERY must restore the existing Boss Damage flow.")
	_expect(not window.is_ready(),
		"The first valid RECOVERY hit must consume Counter.")
	hurtbox.body_exited.emit(ball)

func _test_battle_completion(
	manager: WaveManager,
	boss: Stage1TeddyBossRuntime,
	ball_flow: WaveBallFlowController,
	hud: WaveHud
) -> void:
	var health := boss.get_node("Components/BossHealthComponent") \
		as BossHealthComponent
	var completion_count: Array[int] = [0]
	manager.stage_completed.connect(
		func(_stage_id: StringName) -> void: completion_count[0] += 1
	)
	health.apply_damage(health.get_current_health())
	await process_frame
	_expect(manager.current_stage_phase == WaveManager.StagePhase.STAGE_COMPLETE,
		"Boss completion must advance BOSS to STAGE_COMPLETE.")
	_expect(not manager.is_boss_ball_cycle_active(),
		"Boss completion must close the managed Boss Ball cycle.")
	_expect(ball_flow.current_state == WaveBallFlowController.State.INACTIVE,
		"Boss completion must close the existing BallFlow safely.")
	_expect(completion_count[0] == 1,
		"Existing WaveManager stage_completed must occur exactly once.")
	_expect(not boss.is_battle_active(),
		"Boss Runtime must stop after battle completion.")
	_expect(boss.get_active_cotton_count() == 0,
		"Battle completion must clear all remaining Cottons.")
	_expect(not hud.get_stage_phase_button().disabled,
		"Stage completion placeholder may be enabled after Boss defeat.")


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
		print("Stage 1 Teddy production Wave scene tests passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
