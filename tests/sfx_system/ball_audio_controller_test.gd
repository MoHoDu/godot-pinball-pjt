extends SceneTree

## BallAudioController 의 공별 스로틀·연타 감쇠·패링 래치를 검증합니다.
##
## 시각과 프레임을 주입하므로 프레임을 기다리지 않고 결정적으로 돕니다.
## 음원 파일도 필요 없습니다.

var _failures: Array[String] = []
var _fake_msec: int = 0
var _fake_frame: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_minimum_interval()
	await _test_repeat_attenuation()
	await _test_chain_reset()
	await _test_balls_are_independent()
	await _test_parry_latch_suppresses_lower_sounds()
	await _test_parry_is_not_throttled()
	_finish()


## 기획서 p.62 "동일 공 재생 간격 최소 0.04초"
func _test_minimum_interval() -> void:
	var rig := await _make_rig()
	var cue := _make_cue(&"wall", SfxPriority.WALL)
	cue.minimum_repeat_interval = 0.04

	_expect(rig.controller.play(cue, 500.0).is_played(), "첫 충돌은 울려야 한다.")

	_fake_msec += 30
	_expect(not rig.controller.play(cue, 500.0).is_played(),
		"0.03초 뒤의 충돌은 막혀야 한다. 안 막으면 벽을 스치는 공이 기관총이 된다.")

	_fake_msec += 20	# 누적 0.05초
	_expect(rig.controller.play(cue, 500.0).is_played(),
		"0.05초가 지나면 다시 울려야 한다.")

	_free_rig(rig)


## 기획서 p.62 "연속 충돌 두 번째부터 약 -3dB", 바닥 -9dB
## ★ 검수용 오디션(docs/sfx/build_wall_sfx.py)과 같은 수식이어야 한다
func _test_repeat_attenuation() -> void:
	var rig := await _make_rig()
	var cue := _make_cue(&"wall", SfxPriority.WALL)
	cue.minimum_repeat_interval = 0.04
	cue.repeat_chain_reset_time = 0.24

	var volumes: Array[float] = []
	for i in 5:
		var result := rig.controller.play(cue, 500.0)
		if result.is_played():
			volumes.append(result.volume_db)
		_fake_msec += 50

	var expected: Array[float] = [0.0, -3.0, -6.0, -9.0, -9.0]
	_expect(volumes.size() == 5, "5연타가 전부 울려야 한다. (%d)" % volumes.size())

	if volumes.size() == 5:
		var matched := true
		for i in 5:
			if absf(volumes[i] - expected[i]) > 0.001:
				matched = false

		_expect(matched,
			"연타 감쇠는 0/-3/-6/-9/-9 여야 한다. 실제 %s" % str(volumes))

	_free_rig(rig)


func _test_chain_reset() -> void:
	var rig := await _make_rig()
	var cue := _make_cue(&"wall", SfxPriority.WALL)
	cue.minimum_repeat_interval = 0.04
	cue.repeat_chain_reset_time = 0.24

	for i in 3:
		rig.controller.play(cue, 500.0)
		_fake_msec += 50

	_expect(rig.controller.get_repeat_count(&"wall") == 3,
		"연타가 세어져야 한다. (%d)" % rig.controller.get_repeat_count(&"wall"))

	_fake_msec += 300	# 사슬 판정 시간(0.24초)을 넘긴다
	var result := rig.controller.play(cue, 500.0)

	_expect(result.is_played() and absf(result.volume_db) < 0.001,
		"사슬이 풀린 뒤 첫 타격은 감쇠가 없어야 한다. (%.2f)" % result.volume_db)

	_free_rig(rig)


func _test_balls_are_independent() -> void:
	var rig_a := await _make_rig()
	var rig_b := await _make_rig(rig_a.director)
	var cue := _make_cue(&"wall", SfxPriority.WALL)
	cue.minimum_repeat_interval = 0.04

	for i in 3:
		rig_a.controller.play(cue, 500.0)
		_fake_msec += 50

	var result := rig_b.controller.play(cue, 500.0)
	_expect(result.is_played() and absf(result.volume_db) < 0.001,
		"공 A 의 연타가 공 B 의 사슬에 영향을 주면 안 된다. (%.2f)" % result.volume_db)

	rig_b.controller.queue_free()
	rig_b.ball.queue_free()
	_free_rig(rig_a)


## ★ 핵심 회귀 — 패링 프레임에 충돌음이 겹치지 않는가
func _test_parry_latch_suppresses_lower_sounds() -> void:
	var rig := await _make_rig()
	var parry := _make_cue(&"parry", SfxPriority.PARRY)
	var flipper := _make_cue(&"flipper_hit", SfxPriority.FLIPPER)
	var wall := _make_cue(&"wall", SfxPriority.WALL)

	# flipper.gd 가 실제로 emit 하는 순서 그대로: 패링 → 스윕 → 물리 접촉
	var parry_result := rig.controller.play(parry, 900.0)
	var flipper_result := rig.controller.play(flipper, 900.0)
	var wall_result := rig.controller.play(wall, 900.0)

	_expect(parry_result.is_played(), "패링은 울려야 한다.")
	_expect(not flipper_result.is_played(),
		"★ 같은 프레임의 플리퍼 타격음은 막혀야 한다. 안 막으면 어택이 두 번 찍힌다.")
	_expect(not wall_result.is_played(),
		"★ 같은 프레임의 벽 충돌음도 막혀야 한다.")
	_expect(rig.controller.get_suppressed_count() == 2,
		"막힌 요청이 2건이어야 한다. (%d)" % rig.controller.get_suppressed_count())

	# 다음 프레임에는 정상적으로 울려야 한다
	_fake_frame += 1
	_fake_msec += 17
	_expect(rig.controller.play(flipper, 900.0).is_played(),
		"다음 프레임의 타격음은 정상적으로 울려야 한다.")

	_free_rig(rig)


func _test_parry_is_not_throttled() -> void:
	var rig := await _make_rig()
	var parry := _make_cue(&"parry", SfxPriority.PARRY)
	parry.minimum_repeat_interval = 0.5

	_expect(rig.controller.play(parry, 900.0).is_played(), "첫 패링은 울려야 한다.")

	_fake_frame += 1
	_expect(rig.controller.play(parry, 900.0).is_played(),
		"패링은 간격 제한을 받지 않아야 한다. 플레이어가 성공시킨 순간이다.")

	_free_rig(rig)


# ── 헬퍼 ────────────────────────────────────────────────────

class Rig:
	extends RefCounted

	var director: SfxDirector
	var ball: Node2D
	var controller: BallAudioController


func _make_rig(shared_director: SfxDirector = null) -> Rig:
	var rig := Rig.new()

	if shared_director != null:
		rig.director = shared_director
	else:
		_fake_msec = 1000
		_fake_frame = 100
		rig.director = SfxDirector.new()
		rig.director.random_seed = 999
		rig.director.time_source = func() -> int: return _fake_msec
		root.add_child(rig.director)

	rig.ball = Node2D.new()
	root.add_child(rig.ball)

	rig.controller = BallAudioController.new()
	rig.controller.name = String(BallAudioController.NODE_NAME)
	rig.controller.time_source = func() -> int: return _fake_msec
	rig.controller.frame_source = func() -> int: return _fake_frame
	rig.ball.add_child(rig.controller)
	rig.controller.bind_director(rig.director)

	await physics_frame
	return rig


func _free_rig(rig: Rig) -> void:
	rig.ball.queue_free()
	rig.director.queue_free()


func _make_cue(id: StringName, priority: int) -> SfxCue:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 48000
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(4800)	# 0.05초
	wav.data = data

	var cue := SfxCue.new()
	cue.cue_id = id
	cue.priority = priority
	cue.streams = [wav] as Array[AudioStream]
	cue.pitch_jitter = 0.0
	cue.speed_volume_range = Vector2.ZERO
	cue.maximum_concurrent = 8
	return cue


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: ball_audio_controller_test")
		quit(0)
		return

	print("FAIL: ball_audio_controller_test (%d failures)" % _failures.size())
	quit(1)
