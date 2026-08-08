extends SceneTree


const WAVE_SCENE := preload(
	"res://Resources/Prefabs/wave/base/wave_unique.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred(&"_run")


func _run() -> void:
	var wave := WAVE_SCENE.instantiate() as WaveRuntimeCoordinator
	root.add_child(wave)
	await process_frame
	await process_frame

	_test_full_bleed_camera(wave)
	_test_transparent_panels(wave)
	_test_placement_settings_only(wave)

	wave.queue_free()
	await process_frame
	_finish()


func _test_full_bleed_camera(wave: WaveRuntimeCoordinator) -> void:
	wave.call(&"_fit_board_camera", true)
	var viewport_size: Vector2 = wave.get_viewport_rect().size
	var bounds: Rect2 = wave.board_world_bounds
	var zoom: Vector2 = wave.board_camera.zoom
	var projected_size: Vector2 = bounds.size * zoom
	_expect(is_equal_approx(zoom.x, zoom.y),
		"Full-bleed camera must keep uniform board scaling.")
	_expect(projected_size.x + 0.5 >= viewport_size.x \
		and projected_size.y + 0.5 >= viewport_size.y,
		"The board must cover the complete landscape viewport without margins.")
	_expect(wave.board_camera.position.is_equal_approx(bounds.get_center()),
		"Full-bleed board cropping must stay centered.")


func _test_transparent_panels(wave: WaveRuntimeCoordinator) -> void:
	var life_fill := wave.get_node(
		"HUD/WaveHud/DesignSpace/LifeHud/PanelFill"
	) as CanvasItem
	var score_fill := wave.get_node(
		"HUD/WaveHud/DesignSpace/ScoreRepairHud/PanelFill"
	) as CanvasItem
	var life_border := wave.get_node(
		"HUD/WaveHud/DesignSpace/LifeHud/PanelBorder"
	) as CanvasItem
	_expect(life_fill.modulate.a < 0.75 and score_fill.modulate.a < 0.75,
		"HUD background fills must be translucent over the full board.")
	_expect(is_equal_approx(life_border.modulate.a, 1.0),
		"HUD borders and foreground content must remain readable.")


func _test_placement_settings_only(wave: WaveRuntimeCoordinator) -> void:
	var hud := wave.wave_hud
	var design: Node = wave.get_node("HUD/WaveHud/DesignSpace")
	_expect(wave.wave_manager.current_stage_phase \
		== WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Production Wave must begin in repair placement.")
	_expect(hud.visible and bool(hud.call(&"is_placement_mode")),
		"Wave HUD must stay active in its placement-only mode.")
	_expect(design.get_node("SettingsButton").visible,
		"Settings must remain available during placement.")
	for hidden_name: String in [
		"LifeHud",
		"ScoreRepairHud",
		"WorldComboHud",
		"WaveLabel",
		"CoinWalletHud",
	]:
		_expect(not design.get_node(hidden_name).visible,
			"Placement mode must hide %s." % hidden_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_full_bleed_hud_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: wave_full_bleed_hud_test (%d failures)" % _failures.size())
	quit(1)
