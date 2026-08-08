extends SceneTree


const WAVE_SCENE := preload("res://scenes/wave/wave.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var wave := WAVE_SCENE.instantiate()
	root.add_child(wave)
	await process_frame
	await physics_frame

	var hud := wave.get_node("HUD/WaveHud") as WaveHud
	var hud_state := wave.get_node("WaveHudStateSource") as WaveHudStateSource
	var overlay := wave.get_node_or_null("SettingsOverlay") as CanvasLayer
	var popup: Variant = overlay.get_child(0) if overlay != null else null
	_expect(overlay != null and overlay.layer == 100,
		"설정 팝업은 수리 UI보다 높은 CanvasLayer 100에 있어야 한다.")
	_expect(popup != null and not popup.visible,
		"게임 시작 시 설정 팝업은 숨겨져 있어야 한다.")

	hud.settings_requested.emit()
	_expect(paused, "설정 버튼을 누르면 SceneTree가 일시정지되어야 한다.")
	_expect(popup.visible, "설정 버튼을 누르면 팝업이 표시되어야 한다.")
	_expect(bool(hud_state.get_snapshot()[&"paused"]),
		"HUD도 설정 팝업의 일시정지 상태를 표시해야 한다.")

	popup.show_sfx_detail()
	hud.settings_requested.emit()
	await popup.close_requested
	_expect(not paused, "플레이 중 연 설정을 닫으면 게임이 재개되어야 한다.")
	_expect(not bool(hud_state.get_snapshot()[&"paused"]),
		"팝업을 닫은 뒤 HUD의 일시정지 표시도 해제되어야 한다.")

	paused = true
	hud_state.set_paused(true)
	hud.settings_requested.emit()
	popup.close_popup()
	await popup.close_requested
	_expect(paused,
		"이미 일시정지된 단계에서 연 설정은 닫아도 기존 정지 상태를 유지해야 한다.")
	_expect(bool(hud_state.get_snapshot()[&"paused"]),
		"기존 정지 상태를 복원할 때 HUD 표시도 유지되어야 한다.")

	paused = false
	wave.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: settings_pause_integration_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: settings_pause_integration_test (%d failures)" % _failures.size())
	quit(1)
