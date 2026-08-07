extends SceneTree


## 웨이브 승리 → 유물 선택 → 다음 웨이브 진입까지 실제 씬으로 확인합니다.
## 스테이지가 4웨이브이므로 보상은 3회 발생하고 마지막 승리는 스테이지 클리어가 됩니다.


const WAVE_REWARD_SCENE := preload("res://scenes/wave/wave_reward.tscn")

const HIT_WEIGHT := 20000.0
const WAVE_COUNT := 4


var _failures: Array[String] = []
var _finished_reason: StringName = &""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var scene := WAVE_REWARD_SCENE.instantiate() as WaveRewardCoordinator
	scene.reward_random_seed = 20260804
	root.add_child(scene)
	await process_frame
	await process_frame

	var wave_manager: WaveManager = scene.wave_manager
	var flow: WaveBallFlowController = scene.wave_ball_flow
	var ball_inventory: WaveBallInventory = scene.wave_ball_inventory
	var combo: ComboSystem = scene.combo_system
	var launcher: PinballLauncher = scene.launcher
	var controller: RewardChoiceController = scene.reward_controller
	var hud: RewardChoiceHud = scene.reward_hud
	var relics: RelicInventory = scene.relic_inventory
	controller.sequence_finished.connect(func(reason: StringName) -> void:
		_finished_reason = reason
	)

	_expect(controller != null and hud != null, "보상 노드가 씬에 붙어야 한다.")
	_expect(wave_manager.current_wave_index == 0, "웨이브 0에서 시작해야 한다.")
	_expect(
		flow.current_state == WaveBallFlowController.State.SELECTING,
		"시작 직후에는 공 선택 상태여야 한다."
	)
	_expect(not hud.visible, "웨이브 진행 중에는 보상창이 보이면 안 된다.")

	var combo_rules: Resource = combo.rules
	var parry_rules: Resource = _get_parry_rules(scene)
	var base_values := {
		&"score": float(combo_rules.get(&"normal_score_multiplier")),
		&"speed": float(launcher.default_launch_speed),
		&"perfect": float(parry_rules.get(&"perfect_parry_window_time")),
		&"stock": ball_inventory.total_remaining,
	}
	_expect(int(base_values[&"stock"]) == 3, "기준 시작 공은 3개여야 한다.")

	for wave_index in WAVE_COUNT:
		_expect(
			wave_manager.current_wave_index == wave_index,
			"웨이브 %d를 진행 중이어야 한다." % wave_index
		)
		await _win_current_wave(scene, wave_manager, flow, combo, launcher)
		_expect(
			wave_manager.current_state == WaveManager.State.WON,
			"웨이브 %d는 승리로 끝나야 한다." % wave_index
		)

		if wave_index == WAVE_COUNT - 1:
			_expect(
				not controller.is_choosing,
				"마지막 웨이브 뒤에는 선택창이 뜨지 않아야 한다."
			)
			_expect(
				_finished_reason == &"stage_cleared",
				"마지막 웨이브 뒤에는 스테이지 클리어로 끝나야 한다."
			)
			break

		_expect(controller.is_choosing, "웨이브 %d 승리 뒤 선택 대기여야 한다." % wave_index)
		var choices := controller.get_choices()
		_expect(choices.size() == 3, "선택지는 3장이어야 한다.")
		_expect(hud.visible, "선택 대기 중에는 보상창이 보여야 한다.")
		_expect(hud.get_card_count() == 3, "카드도 3장 만들어져야 한다.")

		# 키보드 이동이 실제로 선택을 바꾸는지 확인합니다.
		var start_index := controller.selected_index
		_send_action(controller, &"ball_select_next")
		_expect(
			controller.selected_index == posmod(start_index + 1, choices.size()),
			"다음 선택 입력이 선택 인덱스를 옮겨야 한다."
		)
		_send_action(controller, &"ball_select_previous")
		_expect(
			controller.selected_index == start_index,
			"이전 선택 입력이 선택 인덱스를 되돌려야 한다."
		)

		var chosen: RelicDefinition = choices[0]
		var expected_stack := relics.get_stack_count(chosen.relic_id) + 1
		controller.select_index(0)
		_send_action(controller, &"ball_select_confirm")
		await process_frame

		_expect(
			relics.get_stack_count(chosen.relic_id) == expected_stack,
			"확정한 부품이 수리함에 들어가야 한다."
		)
		_expect(not hud.visible, "확정 후에는 보상창이 닫혀야 한다.")
		_expect(
			wave_manager.current_wave_index == wave_index + 1,
			"확정 후 다음 웨이브로 진입해야 한다."
		)
		_expect(
			flow.current_state == WaveBallFlowController.State.SELECTING,
			"다음 웨이브도 공 선택부터 시작해야 한다."
		)
		_verify_effect(
			chosen,
			relics,
			combo_rules,
			parry_rules,
			launcher,
			ball_inventory,
			base_values
		)

	_expect(relics.total_count == 3, "4웨이브 스테이지에서 부품 3개를 받아야 한다.")

	# 씬이 사라지면 공유 리소스는 원래 값으로 돌아와야 합니다.
	scene.queue_free()
	await process_frame
	await process_frame
	_expect(
		is_equal_approx(
			float(combo_rules.get(&"normal_score_multiplier")),
			float(base_values[&"score"])
		),
		"씬이 해제되면 콤보 점수 배율이 기준값으로 돌아와야 한다."
	)
	_expect(
		is_equal_approx(
			float(parry_rules.get(&"perfect_parry_window_time")),
			float(base_values[&"perfect"])
		),
		"씬이 해제되면 패링 창이 기준값으로 돌아와야 한다."
	)
	_finish()


func _win_current_wave(
	scene: WaveRewardCoordinator,
	wave_manager: WaveManager,
	flow: WaveBallFlowController,
	combo: ComboSystem,
	launcher: PinballLauncher
) -> void:
	_send_action(flow, &"ball_select_confirm")
	_expect(
		flow.current_state == WaveBallFlowController.State.AIMING,
		"공 선택 확정은 조준으로 넘어가야 한다."
	)
	var launched_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "준비된 공이 발사되어야 한다.")
	combo.register_hit(HIT_WEIGHT)
	_expect(flow.on_ball_drained(launched_ball), "공이 낙하 처리되어야 한다.")
	_expect(
		wave_manager.current_state == WaveManager.State.CLEAR_CHOICE,
		"목표 점수를 넘기면 클리어 선택이 떠야 한다."
	)
	_send_action(wave_manager, &"wave_choose_clear")
	await process_frame
	await process_frame
	if scene == null:
		return


func _verify_effect(
	chosen: RelicDefinition,
	relics: RelicInventory,
	combo_rules: Resource,
	parry_rules: Resource,
	launcher: PinballLauncher,
	ball_inventory: WaveBallInventory,
	base_values: Dictionary
) -> void:
	var stack := relics.get_stack_count(chosen.relic_id)
	match chosen.relic_id:
		&"star_brooch":
			_expect(
				is_equal_approx(
					float(combo_rules.get(&"normal_score_multiplier")),
					float(base_values[&"score"]) * (1.0 + 0.25 * stack)
				),
				"별모양 브로치는 콤보 점수 배율을 올려야 한다."
			)
		&"clockwork_gear":
			_expect(
				is_equal_approx(
					launcher.default_launch_speed,
					float(base_values[&"speed"]) * (1.0 + 0.1 * stack)
				),
				"태엽 및 톱니바퀴는 발사 속력을 올려야 한다."
			)
		&"curved_needle":
			_expect(
				is_equal_approx(
					float(parry_rules.get(&"perfect_parry_window_time")),
					float(base_values[&"perfect"]) * (1.0 + 0.35 * stack)
				),
				"곡선 바늘은 정확 패링 창을 넓혀야 한다."
			)
		&"bell":
			_expect(
				ball_inventory.total_remaining
					== mini(int(base_values[&"stock"]) + stack, RelicRuntime.MAX_LIFE_SLOTS),
				"방울은 다음 웨이브 시작 공을 늘려야 한다."
			)
		_:
			_expect(false, "알 수 없는 부품이 선택됐다: %s" % chosen.relic_id)


func _get_parry_rules(scene: Node) -> Resource:
	for flipper: Node in scene.find_children("*", "PinballFlipper", true, false):
		var rules: Resource = flipper.get(&"parry_rules")
		if rules != null:
			return rules
	return null


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
		print("PASS: wave_reward_flow_test")
		quit(0)
		return
	print("FAIL: wave_reward_flow_test (%d failures)" % _failures.size())
	quit(1)
