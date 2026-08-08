extends SceneTree

## SfxDirector 의 우선순위 보장을 검증합니다.
##
## ★ 이 테스트가 존재하는 이유:
##   한 물리 프레임 안에서 벽 충돌 여러 개가 **패링보다 먼저** 도착합니다.
##   물리 접촉 해소가 회전 스윕 판정보다 먼저 돌기 때문에 생기는 구조적 순서입니다.
##   선착순으로 목소리를 나눠주면 가장 중요한 소리가 밀립니다.
##
## 음원 파일이 없어도 돌아갑니다. 메모리에서 무음 WAV 를 만들어 씁니다.
## 시각도 주입하므로 프레임을 기다리지 않고 결정적으로 검증됩니다.

const RULES_PATH := "res://settings/sfx/SfxDirectorRules.tres"

var _failures: Array[String] = []
var _fake_msec: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resource()
	await _test_wall_hard_cap()
	await _test_parry_reserved_lane()
	await _test_parry_never_loses_to_walls()
	await _test_low_priority_cannot_steal()
	await _test_reserved_share_is_protected()
	await _test_steal_picks_lowest_then_oldest()
	await _test_cue_own_limit()
	await _test_settings_bus_routing()
	_finish()


# ── 규칙 리소스 ─────────────────────────────────────────────

func _test_rules_resource() -> void:
	var rules := load(RULES_PATH) as SfxDirectorRules
	_expect(rules != null, "SfxDirectorRules.tres 를 불러올 수 있어야 한다.")

	if rules == null:
		return

	_expect(rules.cap_for(SfxPriority.WALL) == 4,
		"벽 하드캡은 4여야 한다 (기획서 p.62 최대 동시 재생 4개). (%d)"
			% rules.cap_for(SfxPriority.WALL))
	_expect(rules.reserved_for(SfxPriority.WALL) == 0,
		"★ 벽의 예약 레인은 0이어야 한다. 벽은 항상 빌려 쓰고 항상 먼저 뺏긴다.")
	_expect(rules.reserved_for(SfxPriority.PARRY) >= 2,
		"패링은 예약 레인이 있어야 한다. 없으면 포화 시 밀린다.")
	_expect(rules.bus == &"SFX", "디렉터는 SFX 버스로 나가야 한다.")

	var reserved_total := 0
	for value in rules.reserved_voices:
		reserved_total += value

	_expect(reserved_total < rules.voice_count,
		"예약이 목소리를 다 먹으면 유동 목소리가 없다. (%d/%d)"
			% [reserved_total, rules.voice_count])


# ── 하드캡 ──────────────────────────────────────────────────

func _test_wall_hard_cap() -> void:
	var director := await _make_director()
	var cue := _make_cue(&"wall", SfxPriority.WALL, 0.5)
	cue.maximum_concurrent = 8

	var played := 0
	var capped := 0
	for i in 10:
		var result := director.request(cue, SfxPlayContext.new(1, 500.0))
		if result.is_played():
			played += 1
		elif result.outcome == SfxPlayResult.Outcome.DROPPED_CAP:
			capped += 1

	_expect(played == 4,
		"벽은 풀에 자리가 남아 있어도 4개를 넘지 못해야 한다. (%d개 재생)" % played)
	_expect(capped == 6, "나머지 6개는 하드캡으로 막혀야 한다. (%d개)" % capped)
	_expect(director.get_active_voice_count() == 4,
		"풀 16칸 중 4칸만 쓰고 있어야 한다.")

	_free_director(director)


# ── 예약 레인 ───────────────────────────────────────────────

func _test_parry_reserved_lane() -> void:
	var director := await _make_director()

	# 유동 목소리를 상한까지 채운다 (예약분을 넘겨 쓰는 상태)
	_fill(director, SfxPriority.IMPACT, 5)
	_fill(director, SfxPriority.FLIPPER, 4)
	_fill(director, SfxPriority.WALL, 4)

	var parry := _make_cue(&"parry", SfxPriority.PARRY, 0.27)
	var result := director.request(parry, SfxPlayContext.new(1, 900.0))

	_expect(result.is_played(), "패링은 예약 레인 덕분에 항상 자리가 있어야 한다.")
	_expect(result.outcome == SfxPlayResult.Outcome.PLAYED,
		"아직 빈 목소리가 있으므로 뺏지 않고 배정돼야 한다. (%s)" % result.outcome)

	_free_director(director)


## ★ 핵심 회귀 — 풀이 꽉 찬 상태에서 패링이 밀리지 않는가
func _test_parry_never_loses_to_walls() -> void:
	var director := await _make_director()

	# 16칸을 전부 채운다. 벽이 먼저 도착한 상황을 재현한다.
	_fill(director, SfxPriority.WALL, 4)		# 하드캡까지
	_fill(director, SfxPriority.AMBIENT, 2)		# 하드캡까지
	_fill(director, SfxPriority.IMPACT, 5)		# 하드캡까지
	_fill(director, SfxPriority.FLIPPER, 4)		# 하드캡까지
	_fill(director, SfxPriority.BOSS, 1)

	_expect(director.get_active_voice_count() == 16,
		"먼저 16칸이 전부 차 있어야 이 테스트가 의미가 있다. (%d)"
			% director.get_active_voice_count())

	var parry := _make_cue(&"parry", SfxPriority.PARRY, 0.27)
	var stolen: Array[int] = []
	var played := 0

	for i in 3:
		var result := director.request(parry, SfxPlayContext.new(1, 900.0))
		if result.is_played():
			played += 1
		if result.stolen_priority >= 0:
			stolen.append(result.stolen_priority)

	_expect(played == 3,
		"★ 풀이 꽉 차 있어도 패링 3개는 전부 울려야 한다. (%d개) "
		% played + "선착순 구현이면 여기서 실패한다.")

	# 뺏긴 것은 낮은 우선순위부터여야 한다.
	# AMBIENT(예약0, 2개) 가 먼저, 그다음 WALL(예약0, 4개).
	_expect(stolen.size() == 3, "빈 자리가 없으니 3개 다 뺏어야 한다. (%d)" % stolen.size())

	var expected: Array[int] = [
		SfxPriority.AMBIENT, SfxPriority.AMBIENT, SfxPriority.WALL,
	]
	_expect(stolen == expected,
		"뺏는 순서는 가장 낮은 우선순위부터여야 한다. 기대 %s, 실제 %s"
			% [_names(expected), _names(stolen)])

	for priority: int in stolen:
		_expect(priority < SfxPriority.FLIPPER,
			"플리퍼 타격 이상은 패링에게도 뺏기면 안 된다 (예약 보호). (%s)"
				% SfxPriority.to_name(priority))

	_free_director(director)


func _test_low_priority_cannot_steal() -> void:
	var director := await _make_director()

	# ★ 환경음을 섞지 않는다. 환경음(6순위)은 벽 충돌(5순위)보다 낮아서
	#   벽이 뺏는 게 **정상**이다. 그러면 이 테스트가 검증하려는 것과 어긋난다.
	#   남은 2칸은 벽 자신으로 채워 "같은 등급끼리도 못 뺏는다"까지 함께 본다.
	_fill(director, SfxPriority.PARRY, 3)
	_fill(director, SfxPriority.BOSS, 2)
	_fill(director, SfxPriority.FLIPPER, 4)
	_fill(director, SfxPriority.IMPACT, 5)
	_fill(director, SfxPriority.WALL, 2)

	_expect(director.get_active_voice_count() == 16,
		"먼저 16칸이 전부 차 있어야 한다. (%d)" % director.get_active_voice_count())

	var wall := _make_cue(&"wall", SfxPriority.WALL, 0.1)
	var result := director.request(wall, SfxPlayContext.new(1, 500.0))

	_expect(not result.is_played(),
		"낮거나 같은 우선순위만 남았으면 뺏지 못하고 드롭돼야 한다.")
	_expect(result.outcome == SfxPlayResult.Outcome.DROPPED_FULL,
		"풀이 찼고 뺏을 후보가 없으면 DROPPED_FULL 이어야 한다. (%s)" % result.outcome)

	_free_director(director)


func _test_reserved_share_is_protected() -> void:
	var director := await _make_director()

	# FLIPPER 를 예약 몫(2)만큼만 쓰게 두고 나머지를 다른 클래스로 채운다
	_fill(director, SfxPriority.FLIPPER, 2)
	_fill(director, SfxPriority.IMPACT, 5)
	_fill(director, SfxPriority.WALL, 4)
	_fill(director, SfxPriority.AMBIENT, 2)
	_fill(director, SfxPriority.BOSS, 2)
	_fill(director, SfxPriority.PARRY, 1)

	var before := director.get_active_count(SfxPriority.FLIPPER)
	var parry := _make_cue(&"parry", SfxPriority.PARRY, 0.27)
	director.request(parry, SfxPlayContext.new(1, 900.0))
	director.request(parry, SfxPlayContext.new(1, 900.0))

	_expect(director.get_active_count(SfxPriority.FLIPPER) == before,
		"예약 몫만 쓰고 있는 클래스는 더 높은 우선순위에게도 뺏기면 안 된다. (%d → %d)"
			% [before, director.get_active_count(SfxPriority.FLIPPER)])

	_free_director(director)


func _test_steal_picks_lowest_then_oldest() -> void:
	var director := await _make_director()

	# 같은 클래스 안에서는 오래된 것부터 뺏는다.
	# 벽 4개를 시각을 벌려 채운 뒤, 다른 클래스로 나머지를 채운다.
	var wall := _make_cue(&"wall", SfxPriority.WALL, 5.0)
	wall.maximum_concurrent = 8
	var first_index := -1
	for i in 4:
		var result := director.request(wall, SfxPlayContext.new(1, 500.0))
		if i == 0:
			first_index = result.voice_index
		_fake_msec += 10

	_fill(director, SfxPriority.IMPACT, 5)
	_fill(director, SfxPriority.FLIPPER, 4)
	_fill(director, SfxPriority.BOSS, 2)
	_fill(director, SfxPriority.AMBIENT, 1)

	var parry := _make_cue(&"parry", SfxPriority.PARRY, 0.27)
	var result := director.request(parry, SfxPlayContext.new(1, 900.0))

	_expect(result.stolen_priority == SfxPriority.AMBIENT,
		"가장 낮은 우선순위(환경음)를 먼저 뺏어야 한다. (%s)"
			% SfxPriority.to_name(result.stolen_priority))

	# 환경음이 없어지면 그다음은 벽 중 가장 오래된 것
	var second := director.request(parry, SfxPlayContext.new(1, 900.0))
	_expect(second.stolen_priority == SfxPriority.WALL,
		"환경음이 떨어지면 그다음은 벽이어야 한다. (%s)"
			% SfxPriority.to_name(second.stolen_priority))
	_expect(second.voice_index == first_index,
		"같은 클래스 안에서는 가장 오래된 목소리를 뺏어야 한다. (기대 %d, 실제 %d)"
			% [first_index, second.voice_index])

	_free_director(director)


func _test_cue_own_limit() -> void:
	var director := await _make_director()

	var cue := _make_cue(&"limited", SfxPriority.IMPACT, 0.5)
	cue.maximum_concurrent = 2

	var played := 0
	for i in 5:
		if director.request(cue, SfxPlayContext.new(1, 500.0)).is_played():
			played += 1

	_expect(played == 2,
		"큐 자체의 상한도 지켜져야 한다. 클래스 상한(5)보다 작으면 그쪽이 이긴다. (%d)"
			% played)

	_free_director(director)


# ── 헬퍼 ────────────────────────────────────────────────────

func _test_settings_bus_routing() -> void:
	var cases := {
		&"ball_launch": &"SFXBall",
		&"bumper_button": &"SFXBumper",
		&"flipper_hit": &"SFXFlipper",
		&"wall_hit": &"SFXWall",
		&"combo_rise": &"SFX",
	}

	for cue_id: StringName in cases:
		var director := await _make_director()
		var cue := _make_cue(cue_id, SfxPriority.IMPACT, 0.1)
		var result := director.request(cue, SfxPlayContext.new(1, 500.0))
		_expect(result.is_played(), "%s 큐가 재생되어야 한다." % cue_id)
		_expect(director.get_voice_bus(result.voice_index) == cases[cue_id],
			"%s 큐는 %s 버스로 출력되어야 한다. (현재 %s)"
				% [cue_id, cases[cue_id], director.get_voice_bus(result.voice_index)])
		_free_director(director)


## 시간을 주입한 디렉터를 만듭니다. 프레임을 기다리지 않고 결정적으로 돕니다.
func _make_director() -> SfxDirector:
	_fake_msec = 1000

	var director := SfxDirector.new()
	director.random_seed = 12345
	director.time_source = func() -> int: return _fake_msec
	root.add_child(director)
	await physics_frame
	return director


func _free_director(director: SfxDirector) -> void:
	director.queue_free()


## 무음 WAV 입니다. 음원 파일 없이 디렉터를 검증하기 위한 것입니다.
func _make_stream(seconds: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 48000
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(maxi(int(48000.0 * seconds), 2) * 2)
	wav.data = data
	return wav


func _make_cue(id: StringName, priority: int, seconds: float) -> SfxCue:
	var cue := SfxCue.new()
	cue.cue_id = id
	cue.priority = priority
	cue.streams = [_make_stream(seconds)] as Array[AudioStream]
	cue.pitch_jitter = 0.0
	cue.speed_volume_range = Vector2.ZERO
	cue.maximum_concurrent = 8
	return cue


func _fill(director: SfxDirector, priority: int, count: int) -> void:
	var cue := _make_cue(StringName("fill_%d" % priority), priority, 5.0)
	for i in count:
		director.request(cue, SfxPlayContext.new(1, 500.0))


func _names(values: Array[int]) -> String:
	var parts := PackedStringArray()
	for value: int in values:
		parts.append(String(SfxPriority.to_name(value)))

	return "[%s]" % ", ".join(parts)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: sfx_director_priority_test")
		quit(0)
		return

	print("FAIL: sfx_director_priority_test (%d failures)" % _failures.size())
	quit(1)
