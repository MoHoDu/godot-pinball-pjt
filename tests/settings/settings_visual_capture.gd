extends SceneTree
## Stage 01 위에 설정 팝업을 연 상태를 Movie Writer로 검수하는 캡처 진입점입니다.


const STAGE_SCENE := preload("res://scenes/stage_01.tscn")


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := STAGE_SCENE.instantiate()
	root.add_child(stage)
	for frame in 8:
		await process_frame

	var hud := stage.find_child("WaveHud", true, false) as WaveHud
	if hud == null:
		push_error("Stage 01에서 WaveHud를 찾지 못했습니다.")
		quit(1)
		return
	hud.settings_requested.emit()
	await process_frame
	var popup := stage.find_child("SettingsPopup", true, false) as SettingsPopup
	var capture_mode := "sound"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		capture_mode = arguments[0]
	match capture_mode:
		"sfx":
			popup.show_sfx_detail()
		"licenses":
			popup.show_licenses()
		"license_detail":
			popup.show_license_detail(&"godot_engine")
		"exit":
			popup.show_exit_confirmation()
	for frame in 32:
		await process_frame
	print("PASS: settings_visual_capture")
	quit(0)
