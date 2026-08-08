extends SceneTree


## Release 내보내기에서 제거되는 assert() 안에 런타임 연결·상점 열기 호출을
## 다시 넣지 못하도록 소스 계약을 검증합니다.


const TARGET_SCRIPTS := [
	"res://scripts/stage_system/stage_reward_shop_screen.gd",
	"res://scripts/coin_system/wave_coin_session.gd",
	"res://scripts/reward_shop/wave_reward_shop_bridge.gd",
]


var _failures: Array[String] = []
var _assert_pattern := RegEx.new()


func _init() -> void:
	_assert_pattern.compile("\\bassert\\s*\\(")
	call_deferred(&"_run")


func _run() -> void:
	for script_path in TARGET_SCRIPTS:
		_check_script(script_path)
	if _failures.is_empty():
		print("PASS: release_side_effect_guard_test")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print(
		"FAIL: release_side_effect_guard_test (%d failures)"
		% _failures.size()
	)
	quit(1)


func _check_script(script_path: String) -> void:
	var source := FileAccess.get_file_as_string(script_path)
	if source.is_empty():
		_failures.append("검사할 스크립트를 읽지 못했습니다: %s" % script_path)
		return
	var lines := source.split("\n")
	var collecting := false
	var block := ""
	var depth := 0
	var start_line := 0
	for line_index in lines.size():
		var line := lines[line_index]
		if not collecting:
			var match := _assert_pattern.search(line)
			if match == null:
				continue
			collecting = true
			start_line = line_index + 1
			line = line.substr(match.get_start())
		block += line + "\n"
		depth += line.count("(") - line.count(")")
		if depth > 0:
			continue
		_check_assert_block(script_path, start_line, block)
		collecting = false
		block = ""
		depth = 0
	if collecting:
		_failures.append(
			"닫히지 않은 assert 표현식: %s:%d" % [script_path, start_line]
		)


func _check_assert_block(
	script_path: String,
	line_number: int,
	block: String
) -> void:
	for side_effect_call in [".bind(", ".open_shop("]:
		if block.contains(side_effect_call):
			_failures.append(
				"Release에서 제거될 부작용 호출이 assert 안에 있습니다: %s:%d (%s)"
				% [script_path, line_number, side_effect_call]
			)
