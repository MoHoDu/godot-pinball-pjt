extends SceneTree


const HUD_SCENE := preload(
	"res://scenes/ball_base_system/ball_selection_hud.tscn"
)
const LIGHT_BALL := preload("res://Resources/balls/mass_var/light_ball.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for action in [
		&"ball_select_previous",
		&"ball_select_next",
		&"ball_select_confirm",
	]:
		_expect(InputMap.has_action(action), "%s input action should be registered." % action)

	var fixture_root := Node2D.new()
	root.add_child(fixture_root)
	var combo := ComboSystem.new()
	var combo_wave := ComboWaveController.new()
	var inventory := WaveBallInventory.new()
	var launcher := PinballLauncher.new()
	var flow := WaveBallFlowController.new()
	var hud := HUD_SCENE.instantiate() as BallSelectionHud
	fixture_root.add_child(combo)
	fixture_root.add_child(combo_wave)
	fixture_root.add_child(inventory)
	fixture_root.add_child(launcher)
	fixture_root.add_child(flow)
	fixture_root.add_child(hud)
	launcher.spawn_parent_path = ^".."

	var definition := BallDefinition.new()
	definition.ball_id = &"light"
	definition.display_name = "가벼운 공"
	definition.ball_scene = LIGHT_BALL
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 2
	inventory.starting_stock = [stock]

	var stage := ComboStageSettings.new()
	stage.stage_id = &"ball_selection_integration"
	stage.stage_base_score = 100
	stage.wave_target_scores = PackedInt32Array([100])
	await process_frame
	_expect(flow.bind_inventory(inventory), "Flow should bind inventory.")
	_expect(flow.bind_launcher(launcher), "Flow should bind launcher.")
	_expect(combo_wave.bind_combo_system(combo), "Combo wave should bind combo system.")
	_expect(combo_wave.bind_ball_flow(flow), "Combo wave should bind ball flow.")
	_expect(combo_wave.configure_wave(stage, 0), "Combo wave should configure target.")
	_expect(hud.bind_ball_flow(flow), "HUD should bind ball flow.")
	var selection_font := hud.title_label.get_theme_font(&"font")
	_expect(selection_font != null, "Selection HUD should resolve its runtime font.")

	var clear_count := {&"value": 0}
	var clear_state_at_emit := {&"value": WaveBallFlowController.State.INACTIVE}
	combo_wave.wave_clear_requested.connect(func(_score: int, _target: int) -> void:
		clear_count.value += 1
		clear_state_at_emit.value = flow.current_state
	)
	_expect(flow.start_wave(), "Wave ball flow should start in selection.")
	_expect(hud.visible, "Selection HUD should be visible before aiming.")
	_expect(hud.ball_name_label.text == "가벼운 공", "HUD should show selected ball name.")
	_expect("전체 2개" in hud.stock_label.text, "HUD should show total remaining stock.")
	if selection_font != null:
		_expect_labels_use_supported_glyphs(hud, selection_font)

	_send_action(flow, &"ball_select_confirm")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING, "Confirm input should enter aiming.")
	_expect(not hud.visible, "Selection HUD should hide while aiming and playing.")
	var first_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "First selected ball should launch.")
	_expect(combo_wave.ball_is_active, "Flow launch should notify combo wave automatically.")
	combo.register_hit(1.0)
	_expect(flow.on_ball_drained(first_ball), "First ball should drain through flow.")
	_expect(combo_wave.choice_is_pending, "Reached target with stock left should request clear choice.")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Drain should return to selection.")
	_expect(flow.selection_locked, "Clear choice should lock ball confirmation.")
	_expect(hud.visible and "클리어 선택 대기" in hud.title_label.text, "HUD should explain locked choice.")

	_send_action(flow, &"ball_select_confirm")
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Locked confirm must not bypass clear choice.")
	_expect(inventory.total_remaining == 1, "Locked confirm must not consume stock.")
	_send_wave_action(combo_wave, &"wave_choose_remaining_balls")
	_expect(not combo_wave.choice_is_pending, "Continue input should resolve clear choice.")
	_expect(not flow.selection_locked, "Continue choice should unlock selection confirmation.")

	_send_action(flow, &"ball_select_confirm")
	_expect(flow.current_state == WaveBallFlowController.State.AIMING, "Unlocked selection should enter aiming.")
	var last_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Last selected ball should launch.")
	_expect(flow.on_ball_drained(last_ball), "Last ball should drain.")
	_expect(flow.current_state == WaveBallFlowController.State.EXHAUSTED, "Last drain should exhaust stock.")
	_expect(clear_count.value == 1 and combo_wave.clear_was_requested, "Exhaustion should request wave clear once.")
	_expect(not hud.visible, "Selection HUD should hide after exhaustion.")

	combo_wave.on_wave_retried()
	_expect(flow.current_state == WaveBallFlowController.State.SELECTING, "Retry should reset stock and return to selection.")
	_expect(inventory.total_remaining == 2, "Retry should restore starting stock.")
	_send_action(flow, &"ball_select_confirm")
	var retry_ball := flow.active_ball
	_expect(launcher.launch_prepared_ball(), "Retry ball should launch.")
	combo.register_hit(1.0)
	_expect(flow.on_ball_drained(retry_ball), "Retry ball should drain.")
	_expect(combo_wave.choice_is_pending and flow.selection_locked, "Retry target should reach clear choice.")
	_send_wave_action(combo_wave, &"wave_choose_clear")
	_expect(flow.current_state == WaveBallFlowController.State.INACTIVE, "Clear input should end the active ball flow.")
	_expect(clear_state_at_emit.value == WaveBallFlowController.State.INACTIVE, "Explicit clear signal should emit after flow ends.")
	_expect(clear_count.value == 2, "Explicit clear should request one additional clear.")
	_expect(combo_wave.configure_wave(stage, 0), "A cleared controller should configure the next wave.")
	_expect(flow.start_wave(), "A cleared flow should start the next wave.")

	fixture_root.queue_free()
	await process_frame
	_finish()


func _send_action(flow: WaveBallFlowController, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	flow._unhandled_input(event)


func _expect_labels_use_supported_glyphs(hud: BallSelectionHud, font: Font) -> void:
	var checked_characters: Dictionary[String, bool] = {}
	for label: Label in [
		hud.title_label,
		hud.ball_name_label,
		hud.stock_label,
		hud.guide_label,
	]:
		for character in label.text:
			if character == " " or checked_characters.has(character):
				continue
			checked_characters[character] = true
			_expect(font.has_char(character.unicode_at(0)),
				"Selection HUD font should contain the %s glyph." % character)


func _send_wave_action(combo_wave: ComboWaveController, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	combo_wave._unhandled_input(event)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_ball_selection_integration_test")
		quit(0)
		return
	print("FAIL: wave_ball_selection_integration_test (%d failures)" % _failures.size())
	quit(1)
