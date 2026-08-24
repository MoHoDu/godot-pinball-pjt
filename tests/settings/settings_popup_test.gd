extends SceneTree


const POPUP_SCENE := preload("res://Resources/Prefabs/ui/settings/settings_popup.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var popup: Variant = POPUP_SCENE.instantiate()
	root.add_child(popup)
	await process_frame

	popup.open_popup()
	_expect(popup.visible, "팝업을 열면 즉시 입력과 딤을 표시해야 한다.")
	_expect(popup.get_current_screen() == 0,
		"팝업 최초 화면은 사운드 설정이어야 한다.")
	_expect(popup.find_child("MasterVolumeRow", true, false) != null,
		"최초 화면에 마스터 음량 컴포넌트가 있어야 한다.")
	_expect(popup.find_child("SfxDetailButton", true, false) != null,
		"최초 화면에서 세부 SFX 화면으로 진입할 수 있어야 한다.")

	popup.show_sfx_detail()
	_expect(popup.get_current_screen() == 1,
		"세부 효과음 화면으로 전환되어야 한다.")
	for row_name: String in [
		"BallVolumeRow", "BumperVolumeRow", "FlipperVolumeRow", "WallVolumeRow"
	]:
		_expect(popup.find_child(row_name, true, false) != null,
			"%s 컴포넌트가 있어야 한다." % row_name)

	popup.show_licenses()
	_expect(popup.get_current_screen() == 2,
		"라이선스 목록 화면으로 전환되어야 한다.")
	var license_text := popup.find_child("LicenseText", true, false) as RichTextLabel
	var expected_license_markers := {
		&"black_han_sans": "Copyright 2015 The Black Han Sans Project Authors",
		&"noto_sans_kr": "Copyright 2014-2021 Adobe",
		&"black_and_white_picture": "Copyright (c) 1992-2018 AsiaSoft Inc.",
		&"godot_engine": "Permission is hereby granted, free of charge",
	}
	for entry_id: StringName in expected_license_markers:
		popup.show_license_detail(entry_id)
		_expect(popup.get_current_screen() == 3,
			"%s 라이선스 상세 화면으로 전환되어야 한다." % entry_id)
		_expect(
			license_text != null and license_text.text.contains(
				expected_license_markers[entry_id]
			),
			"%s의 실제 라이선스 전문을 표시해야 한다." % entry_id
		)
		popup.show_licenses()

	popup.show_exit_confirmation()
	_expect(popup.is_exit_confirmation_visible(),
		"게임 종료는 확인창을 거쳐야 한다.")
	popup.close_popup()
	_expect(not popup.is_exit_confirmation_visible(),
		"확인창에서 ESC 동작은 게임 종료 대신 취소여야 한다.")

	var exit_state := {&"requested": false}
	popup.game_exit_requested.connect(
		func() -> void: exit_state[&"requested"] = true
	)
	popup.show_exit_confirmation()
	var confirm_button := popup.find_child("ExitConfirmButton", true, false) as Button
	confirm_button.pressed.emit()
	_expect(bool(exit_state[&"requested"]),
		"확인 버튼을 눌렀을 때만 게임 종료를 요청해야 한다.")

	popup.close_popup()
	popup.show_licenses()
	popup.close_popup()
	await popup.close_requested
	_expect(not popup.visible, "최상위 화면을 닫으면 닫기 연출 후 팝업이 숨겨져야 한다.")

	popup.open_popup()
	popup.show_sfx_detail()
	popup.close_immediately()
	await popup.close_requested
	_expect(not popup.visible,
		"닫기 버튼 경로는 하위 화면에서도 즉시 팝업 전체를 닫아야 한다.")
	popup.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: settings_popup_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: settings_popup_test (%d failures)" % _failures.size())
	quit(1)
