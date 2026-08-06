extends SceneTree

## 게임에 반입된 음원이 기획서 규격을 지키는지 검증합니다.
##
## 오디션으로 귀 검수를 하기 **전에** 수치가 어긋난 것을 걸러냅니다.
## 여기서 걸리면 소리를 들어볼 필요도 없습니다.

const WALL_RULES_PATH := "res://settings/sfx/WallSfxRules.tres"
const FLIPPER_RULES_PATH := "res://settings/sfx/FlipperSfxRules.tres"
const SFX_DIR := "res://Resources/sfx/"

## 벽 규격(p.62 0.06~0.14)과 공 공통 규격(p.42/90 0.08~0.20)이 겹치는 구간입니다.
const HIT_MIN_LENGTH := 0.08
const HIT_MAX_LENGTH := 0.14

## 기획서 p.62 "패링음 대비 볼륨 약 -8~-10dB"
const PARRY_HEADROOM_MIN := 8.0
const PARRY_HEADROOM_MAX := 10.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wall_streams()
	_test_flipper_streams()
	_test_parry_headroom()
	_test_speed_tier_picks_three_different_streams()
	_test_import_settings()
	_finish()


func _test_wall_streams() -> void:
	var rules := load(WALL_RULES_PATH) as WallSfxRules
	if rules == null or rules.hit_cue == null:
		_expect(false, "벽 규칙을 불러올 수 없다.")
		return

	var streams := rules.hit_cue.streams
	_expect(streams.size() == 3,
		"벽 충돌은 저·중·고속 3종이어야 한다 (기획서 p.73 MUST). (%d개)" % streams.size())

	var labels: Array[String] = ["저속", "중속", "고속"]
	for i in mini(streams.size(), 3):
		var wav := streams[i] as AudioStreamWAV
		_expect(wav != null, "%s 음원이 AudioStreamWAV 여야 한다." % labels[i])

		if wav == null:
			continue

		var length := wav.get_length()
		_expect(length >= HIT_MIN_LENGTH and length <= HIT_MAX_LENGTH,
			"%s 벽 충돌음 길이는 0.08~0.14초여야 한다. (%.4f초)" % [labels[i], length])
		_expect(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"%s 음원이 루프로 임포트되면 끝없이 울린다." % labels[i])
		_expect(wav.format != AudioStreamWAV.FORMAT_QOA,
			"%s 음원은 무손실이어야 한다. QOA 는 어택 트랜지언트를 흔든다." % labels[i])


func _test_flipper_streams() -> void:
	var rules := load(FLIPPER_RULES_PATH) as FlipperSfxRules
	if rules == null:
		_expect(false, "플리퍼 규칙을 불러올 수 없다.")
		return

	# 플리퍼 6종이 전부 채워져야 합니다 (Tier 1 + Tier 2).
	var required: Array = [
		[rules.hit_cue, "일반 타격"],
		[rules.strong_hit_cue, "강한 타격"],
		[rules.parry_perfect_cue, "정확한 패링"],
		[rules.select_cue, "선택"],
		[rules.activate_cue, "작동"],
		[rules.return_cue, "복귀"],
	]

	for entry: Array in required:
		var cue: SfxCue = entry[0]
		var label: String = entry[1]
		_expect(cue != null and not cue.streams.is_empty(),
			"%s 음원이 붙어 있어야 한다." % label)

		if cue == null or cue.streams.is_empty():
			continue

		var wav := cue.streams[0] as AudioStreamWAV
		if wav == null:
			continue

		_expect(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"%s 이 루프면 안 된다." % label)
		_expect(wav.format != AudioStreamWAV.FORMAT_QOA,
			"%s 은 무손실이어야 한다." % label)

	# ★ 같은 Space 입력이 세 갈래로 갈린다. 셋의 음원이 서로 달라야 한다.
	#   헛침(작동만) / 타격(작동+타격) / 패링(작동+패링)
	var distinct: Array[AudioStream] = []
	for cue: SfxCue in [rules.select_cue, rules.activate_cue, rules.hit_cue,
			rules.strong_hit_cue, rules.parry_perfect_cue, rules.return_cue]:
		if cue != null and not cue.streams.is_empty():
			_expect(not distinct.has(cue.streams[0]),
				"플리퍼 6종은 서로 다른 음원이어야 한다. '%s' 가 겹친다." % cue.cue_id)
			distinct.append(cue.streams[0])

	_expect(distinct.size() == 6, "플리퍼 6종 음원이 전부 있어야 한다. (%d)" % distinct.size())

	# 작동음은 Space 를 누를 때마다 난다. 타격보다 작아야 피로하지 않다
	_expect(_peak_of(rules.activate_cue) < _peak_of(rules.hit_cue),
		"작동음은 타격음보다 작아야 한다. 매 입력마다 나기 때문이다.")
	_expect(_peak_of(rules.select_cue) < _peak_of(rules.activate_cue),
		"선택음은 작동음보다 작아야 한다 (조작 확인음).")
	_expect(_peak_of(rules.return_cue) < _peak_of(rules.select_cue),
		"복귀음이 가장 작아야 한다. 있는 줄 모를 만큼.")

	# 우선순위대로 패링이 가장 길어야 한다
	var hit_len := _length_of(rules.hit_cue)
	var parry_len := _length_of(rules.parry_perfect_cue)
	_expect(parry_len > hit_len,
		"패링은 일반 타격보다 길어야 구분된다. (타격 %.3f초 vs 패링 %.3f초)"
			% [hit_len, parry_len])


## 기획서 p.62 — 파일에 구워진 dB 관계입니다. 코드로 또 깎으면 이중 적용입니다.
func _test_parry_headroom() -> void:
	var wall := load(SFX_DIR + "walls/SFX_Wall_Hit_Mid.wav") as AudioStreamWAV
	var parry := load(SFX_DIR + "flippers/SFX_Flipper_Parry.wav") as AudioStreamWAV

	_expect(wall != null and parry != null, "벽·패링 음원을 불러올 수 있어야 한다.")

	if wall == null or parry == null:
		return

	var headroom := _peak_dbfs(parry) - _peak_dbfs(wall)
	_expect(headroom >= PARRY_HEADROOM_MIN and headroom <= PARRY_HEADROOM_MAX,
		"벽 충돌은 패링 대비 -8~-10dB 여야 한다. (실측 -%.2fdB)" % headroom)


## ★ 3종이 랜덤이 아니라 속도 구간별로 갈리는가
func _test_speed_tier_picks_three_different_streams() -> void:
	var rules := load(WALL_RULES_PATH) as WallSfxRules
	if rules == null or rules.hit_cue == null:
		return

	var cue := rules.hit_cue
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var low := cue.select_stream(0.0, rng)
	var mid := cue.select_stream(cue.speed_tier_thresholds[0], rng)
	var high := cue.select_stream(cue.speed_tier_thresholds[1], rng)

	_expect(low != null and mid != null and high != null,
		"세 구간 모두 음원이 나와야 한다.")
	_expect(low != mid and mid != high and low != high,
		"★ 속도 구간마다 다른 음원이어야 한다. 같으면 구간을 나눈 의미가 없다.")

	# 같은 속도를 여러 번 물어도 같은 결과여야 한다 (랜덤이 아니다)
	var repeated := true
	for i in 20:
		if cue.select_stream(0.0, rng) != low:
			repeated = false

	_expect(repeated, "속도 구간 선택은 결정적이어야 한다. 랜덤이면 저속에 고속 음색이 난다.")


func _test_import_settings() -> void:
	var paths: Array[String] = [
		"Resources/sfx/walls/SFX_Wall_Hit_Low.wav.import",
		"Resources/sfx/walls/SFX_Wall_Hit_Mid.wav.import",
		"Resources/sfx/walls/SFX_Wall_Hit_High.wav.import",
		"Resources/sfx/flippers/SFX_Flipper_Hit.wav.import",
		"Resources/sfx/flippers/SFX_Flipper_StrongHit.wav.import",
		"Resources/sfx/flippers/SFX_Flipper_Parry.wav.import",
	]

	for path: String in paths:
		var file := FileAccess.open("res://" + path, FileAccess.READ)
		_expect(file != null, "%s 를 읽을 수 있어야 한다." % path)

		if file == null:
			continue

		var text := file.get_as_text()
		file.close()

		_expect(text.contains("compress/mode=0"),
			"%s 는 무손실 PCM(compress/mode=0)이어야 한다. 기본값 QOA 는 손실 압축이다."
				% path.get_file())
		_expect(text.contains("edit/loop_mode=0"),
			"%s 는 루프가 꺼져 있어야 한다." % path.get_file())
		_expect(text.contains("edit/normalize=false"),
			"%s 는 정규화가 꺼져 있어야 한다. 켜지면 구워둔 dB 관계가 깨진다."
				% path.get_file())


# ── 헬퍼 ────────────────────────────────────────────────────

## 큐 첫 음원의 피크(dBFS)입니다.
func _peak_of(cue: SfxCue) -> float:
	if cue == null or cue.streams.is_empty():
		return -999.0

	var wav := cue.streams[0] as AudioStreamWAV
	return _peak_dbfs(wav) if wav != null else -999.0


func _length_of(cue: SfxCue) -> float:
	if cue == null or cue.streams.is_empty() or cue.streams[0] == null:
		return 0.0

	return cue.streams[0].get_length()


## 16bit 모노 WAV 의 피크를 dBFS 로 잽니다.
func _peak_dbfs(wav: AudioStreamWAV) -> float:
	var bytes := wav.data
	if bytes.is_empty():
		return -999.0

	var peak := 0
	var count := bytes.size() / 2
	for i in count:
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
		print("PASS: sfx_asset_spec_test")
		quit(0)
		return

	print("FAIL: sfx_asset_spec_test (%d failures)" % _failures.size())
	quit(1)
