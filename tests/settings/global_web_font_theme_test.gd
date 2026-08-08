extends SceneTree


const THEME_PATH := "res://Resources/ui/themes/global_web_font_theme.tres"
const REQUIRED_TEXT := "한글 웹 폰트 확인"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var configured_path := String(
		ProjectSettings.get_setting("gui/theme/custom", "")
	)
	_expect(configured_path == THEME_PATH,
		"Project must configure the bundled global UI theme.")
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "Global UI theme must load as a Theme resource.")
	if theme != null:
		var font := theme.default_font
		_expect(font != null,
			"Global UI theme must provide a bundled default font.")
		if font != null:
			for character: String in REQUIRED_TEXT:
				_expect(font.has_char(character.unicode_at(0)),
					"Global UI font must contain '%s'." % character)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: global_web_font_theme_test")
		quit(0)
		return
	print("FAIL: global_web_font_theme_test (%d failures)" % _failures.size())
	quit(1)
