extends SceneTree

## 게임에 반입된 음원이 규격을 지키는지 검증합니다.
##
## ★ 2026-08-07 부터 **채택된 것만** 검사합니다.
##   음원을 처음부터 다시 만들기로 하면서 전부 지웠고, 하나씩 되돌아옵니다.
##   하드코딩한 목록으로 검사하면 아직 안 만든 것 때문에 매번 빨간 불이 뜨고,
##   그러면 **진짜 고장을 못 알아봅니다.**
##
##   그래서 규칙 리소스에 **실제로 물려 있는 큐**만 봅니다.
##   음원이 하나 반입되면 검사도 자동으로 하나 늘어납니다.

const FLIPPER_RULES_PATH := "res://settings/sfx/FlipperSfxRules.tres"
const WALL_RULES_PATH := "res://settings/sfx/WallSfxRules.tres"

## 벽 규격(p.62 0.06~0.14)과 공 공통 규격(p.42/90 0.08~0.20)이 겹치는 구간입니다.
const HIT_MIN_LENGTH := 0.08
const HIT_MAX_LENGTH := 0.14

var _failures: Array[String] = []
var _checked := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_flipper_streams()
	_test_wall_streams_if_adopted()
	_test_import_settings()
	_finish()


## 지금 물려 있는 플리퍼 큐들만 봅니다.
func _test_flipper_streams() -> void:
	var rules := load(FLIPPER_RULES_PATH) as FlipperSfxRules
	_expect(rules != null, "플리퍼 규칙을 불러올 수 있어야 한다.")

	if rules == null:
		return

	# 순서는 음량 위계 순입니다. 물려 있는 것만 남깁니다.
	var ordered: Array = [
		[rules.return_cue, "복귀"],
		[rules.select_cue, "선택"],
		[rules.activate_cue, "작동"],
		[rules.hit_cue, "일반 타격"],
		[rules.strong_hit_cue, "강한 타격"],
		[rules.parry_perfect_cue, "정확한 패링"],
	]

	var live: Array = []
	for entry: Array in ordered:
		var cue: SfxCue = entry[0]
		if cue != null and not cue.streams.is_empty():
			live.append(entry)

	_expect(not live.is_empty(),
		"플리퍼 큐가 하나도 안 물려 있다. 전부 무음이다.")

	var seen: Array[AudioStream] = []
	for entry: Array in live:
		var cue: SfxCue = entry[0]
		var label: String = entry[1]
		_checked += 1

		var wav := cue.streams[0] as AudioStreamWAV
		_expect(wav != null, "%s 음원이 AudioStreamWAV 여야 한다." % label)

		if wav == null:
			continue

		_expect(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"%s 이 루프면 끝없이 울린다." % label)
		_expect(wav.format != AudioStreamWAV.FORMAT_QOA,
			"%s 은 무손실이어야 한다. QOA 는 어택 트랜지언트를 흔든다." % label)

		# ★ 같은 Space 입력이 여러 갈래로 갈린다. 음원이 겹치면 구분이 안 된다.
		_expect(not seen.has(cue.streams[0]),
			"플리퍼 큐끼리 음원이 겹친다. '%s' 가 중복이다." % cue.cue_id)
		seen.append(cue.streams[0])

	# ★ 음량 위계 — 물려 있는 것들 사이에서만 봅니다.
	#   복귀 < 선택 < 작동 < 타격 < 강타격 < 패링
	var previous_peak := -999.0
	var previous_label := ""
	for entry: Array in live:
		var peak := _peak_of(entry[0])
		if previous_label != "":
			_expect(previous_peak < peak,
				"음량 위계가 뒤집혔다. %s(%.1fdB) 가 %s(%.1fdB) 보다 크면 안 된다."
					% [previous_label, previous_peak, entry[1], peak])
		previous_peak = peak
		previous_label = entry[1]


## 벽 3종은 규칙 파일이 돌아왔을 때만 검사합니다.
func _test_wall_streams_if_adopted() -> void:
	if not ResourceLoader.exists(WALL_RULES_PATH):
		return

	var rules := load(WALL_RULES_PATH) as WallSfxRules
	if rules == null or rules.hit_cue == null:
		return

	var streams := rules.hit_cue.streams
	_expect(streams.size() == 3,
		"벽 충돌은 저·중·고속 3종이어야 한다 (기획서 p.73 MUST). (%d개)" % streams.size())

	var labels: Array[String] = ["저속", "중속", "고속"]
	for i in mini(streams.size(), 3):
		var wav := streams[i] as AudioStreamWAV
		if wav == null:
			continue

		_checked += 1
		var length := wav.get_length()
		_expect(length >= HIT_MIN_LENGTH and length <= HIT_MAX_LENGTH,
			"%s 벽 충돌음 길이는 0.08~0.14초여야 한다. (%.4f초)" % [labels[i], length])

	# ★ 3종이 랜덤이 아니라 속도 구간별로 갈리는가
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cue := rules.hit_cue
	var low := cue.select_stream(0.0, rng)
	var mid := cue.select_stream(cue.speed_tier_thresholds[0], rng)
	var high := cue.select_stream(cue.speed_tier_thresholds[1], rng)
	_expect(low != mid and mid != high and low != high,
		"★ 속도 구간마다 다른 음원이어야 한다. 같으면 구간을 나눈 의미가 없다.")


## 반입된 모든 음원의 임포트 설정을 봅니다. 목록을 적지 않고 폴더를 훑습니다.
func _test_import_settings() -> void:
	var found := 0
	for path in _all_wav_imports("res://Resources/sfx"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue

		var text := file.get_as_text()
		file.close()
		found += 1

		var file_name := path.get_file()
		_expect(text.contains("compress/mode=0"),
			"%s 는 무손실 PCM 이어야 한다. 기본값 QOA 는 손실 압축이다." % file_name)
		_expect(text.contains("edit/loop_mode=0"),
			"%s 는 루프가 꺼져 있어야 한다." % file_name)
		_expect(text.contains("edit/normalize=false"),
			"%s 는 정규화가 꺼져 있어야 한다. 켜지면 구워둔 dB 관계가 깨진다." % file_name)

	_expect(found > 0, "반입된 음원이 하나도 없다.")


func _all_wav_imports(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			out.append_array(_all_wav_imports(full))
		elif entry.ends_with(".wav"):
			out.append(full + ".import")
		entry = dir.get_next()

	dir.list_dir_end()
	return out


func _peak_of(cue: SfxCue) -> float:
	if cue == null or cue.streams.is_empty():
		return -999.0

	var wav := cue.streams[0] as AudioStreamWAV
	if wav == null:
		return -999.0

	var bytes := wav.data
	var peak := 0
	for i in bytes.size() / 2:
		peak = maxi(peak, absi(bytes.decode_s16(i * 2)))

	if peak <= 0:
		return -999.0

	return 20.0 * (log(float(peak) / 32768.0) / log(10.0))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: sfx_asset_spec_test (검사한 음원 %d종)" % _checked)
		quit(0)
		return

	print("FAIL: sfx_asset_spec_test (%d failures)" % _failures.size())
	quit(1)
