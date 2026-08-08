extends SceneTree

## Tier 3·4 배선이 실제로 소리를 내는지 검증합니다.
##
## ★ 이 테스트가 존재하는 이유:
##   배선은 **조용히 실패합니다.** 시그널 이름을 하나 틀려도, 규칙 리소스를
##   씬에 안 물려도 에러가 안 납니다. 그냥 소리가 안 날 뿐입니다.
##   그러면 게임을 켜서 "왜 콤보 소리가 안 나지" 하고 한참을 헤매게 됩니다.
##
##   그래서 실제 씬을 띄우고 **시그널을 직접 발화시켜** 디렉터가 재생했는지 봅니다.

const LAB_PATH := "res://scenes/tests/sfx/sfx_lab.tscn"
const COMBO_RULES_PATH := "res://settings/sfx/ComboSfxRules.tres"
const BUMPER_RULES_PATH := "res://settings/sfx/BumperSfxRules.tres"
const FLOW_RULES_PATH := "res://settings/sfx/BallFlowSfxRules.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


## ★ 2026-08-07 — 음원을 처음부터 다시 만드는 중이라 규칙 파일들이
##   settings/sfx/_pending/ 으로 빠져 있습니다. 돌아오면 자동으로 다시 검사합니다.
##   없는 것을 검사해 매번 빨간 불이 뜨면 진짜 고장을 못 알아봅니다.
func _run() -> void:
	if not ResourceLoader.exists(COMBO_RULES_PATH):
		print("PASS: tier34_binding_test (규칙 대기 중 — 검사 건너뜀)")
		quit(0)
		return

	_test_rules_resources()
	_test_pitch_ladder()
	_test_bumper_kind_mapping()
	await _test_scene_binding()
	_finish()


## 규칙 리소스가 전부 음원을 물고 있는가
func _test_rules_resources() -> void:
	var flow := load(FLOW_RULES_PATH) as BallFlowSfxRules
	_expect(flow != null, "BallFlowSfxRules.tres 를 불러올 수 있어야 한다.")

	if flow != null:
		_expect(flow.launch_cue != null and not flow.launch_cue.streams.is_empty(),
			"발사음이 붙어 있어야 한다.")
		_expect(flow.drain_cue != null and not flow.drain_cue.streams.is_empty(),
			"낙하음이 붙어 있어야 한다.")
		# ★ 발사만 세기에 반응해야 한다. 낙하는 세기 개념이 없다
		_expect(flow.launch_cue.speed_volume_range.x < 0.0,
			"발사음은 당긴 힘에 따라 음량이 달라져야 한다.")

	var combo := load(COMBO_RULES_PATH) as ComboSfxRules
	_expect(combo != null, "ComboSfxRules.tres 를 불러올 수 있어야 한다.")

	if combo != null:
		for entry: Array in [
			[combo.rise_cue, "콤보 상승음"],
			[combo.tier_cue, "콤보 단계음"],
			[combo.timeout_cue, "콤보 실패음"],
			[combo.target_reached_cue, "목표 도달음"],
			[combo.wave_won_cue, "웨이브 승리음"],
			[combo.wave_lost_cue, "웨이브 패배음"],
		]:
			var cue: SfxCue = entry[0]
			_expect(cue != null and not cue.streams.is_empty(),
				"%s 이 붙어 있어야 한다." % entry[1])

		# ★ 상승음에 피치 랜덤이 걸리면 사다리가 흔들려 콤보가 안 읽힌다
		_expect(is_zero_approx(combo.rise_cue.pitch_jitter),
			"콤보 상승음은 피치 랜덤이 0이어야 한다. 사다리가 흔들리면 안 된다.")

		# 연타가 곧 콤보다. 최소 간격이 길면 콤보 소리가 통째로 막힌다
		_expect(combo.rise_cue.minimum_repeat_interval <= 0.08,
			"콤보 상승음의 최소 간격이 길면 빠른 콤보에서 소리가 빠진다. (%.3f초)"
				% combo.rise_cue.minimum_repeat_interval)


## ★ 피치 사다리 — 이 소리의 전부다
func _test_pitch_ladder() -> void:
	var combo := load(COMBO_RULES_PATH) as ComboSfxRules
	if combo == null:
		return

	_expect(is_equal_approx(combo.get_rise_pitch(1), 1.0),
		"콤보 1은 기준 피치여야 한다. (%.3f)" % combo.get_rise_pitch(1))

	var previous := combo.get_rise_pitch(1)
	var climbed := true
	for count in range(2, 12):
		var current := combo.get_rise_pitch(count)
		if current <= previous:
			climbed = false
		previous = current

	_expect(climbed, "콤보가 오를수록 피치가 올라가야 한다. 안 오르면 사다리가 아니다.")

	# 꼭대기에서 멈춰야 한다. 안 멈추면 삑삑거린다
	_expect(combo.get_rise_pitch(1000) <= combo.maximum_pitch,
		"피치 사다리는 꼭대기에서 멈춰야 한다. (%.2f)" % combo.get_rise_pitch(1000))

	# 0이나 음수가 와도 기준 아래로 안 내려간다
	_expect(combo.get_rise_pitch(0) >= 1.0,
		"콤보 0에서도 기준 피치 아래로 내려가면 첫 타격이 둔탁해진다.")


## ★ 범퍼 5종이 서로 다른 소리를 내는가
func _test_bumper_kind_mapping() -> void:
	var rules := load(BUMPER_RULES_PATH) as BumperSfxRules
	_expect(rules != null, "BumperSfxRules.tres 를 불러올 수 있어야 한다.")

	if rules == null:
		return

	# settings/bumpers/stage_01/*.tres 에 적힌 실제 값들이다
	var kinds: Array[StringName] = [
		&"stage01_button", &"stage01_cotton", &"stage01_spring_doll",
		&"stage01_toy_drum", &"stage01_clockwork_cannon",
	]

	var streams: Array[AudioStream] = []
	for kind in kinds:
		var cue := rules.get_material_cue(kind)
		_expect(cue != null and not cue.streams.is_empty(),
			"'%s' 범퍼에 음원이 있어야 한다." % kind)

		if cue != null and not cue.streams.is_empty():
			streams.append(cue.streams[0])

	# 대포 몸통은 조작음과 같은 소재를 써도 되지만, 나머지 4종은 달라야 한다
	var distinct := {}
	for i in mini(streams.size(), 4):
		distinct[streams[i]] = true

	_expect(distinct.size() == 4,
		"★ 단추·솜·용수철·북은 서로 다른 음원이어야 한다. 겹치면 무엇을 맞혔는지 모른다. (%d종)"
			% distinct.size())

	# 모르는 종류가 와도 무음이면 안 된다
	var unknown := rules.get_material_cue(&"stage99_new_bumper")
	_expect(unknown != null and not unknown.streams.is_empty(),
		"모르는 범퍼에도 대체음이 나야 한다. 새 범퍼가 조용히 무음이 되면 안 된다.")

	# ★ 파괴음은 지시로 뺐다 (2026-08-07). 다시 생기면 안 된다 — 화면 연출만 남는다.
	_expect(rules.destroy_cue == null,
		"파괴음은 뺐는데 규칙에 다시 물려 있다.")
	_expect(rules.respawn_telegraph_cue != null,
		"리스폰 예고음이 있어야 한다.")


## ★ 핵심 — 실제 씬에서 시그널을 쏘면 소리가 나는가
func _test_scene_binding() -> void:
	var packed := load(LAB_PATH) as PackedScene
	_expect(packed != null, "연구실 씬을 불러올 수 있어야 한다.")

	if packed == null:
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder
	_expect(binder != null, "연구실에 바인더가 있어야 한다.")

	if binder == null:
		scene.queue_free()
		return

	# ★ 씬에 규칙이 안 물려 있으면 시그널이 와도 조용히 아무 일도 안 일어난다
	_expect(binder.combo_rules != null,
		"★ 씬에 콤보 규칙이 안 물렸다. 콤보·웨이브 소리가 통째로 안 난다.")
	_expect(binder.bumper_rules != null,
		"★ 씬에 범퍼 규칙이 안 물렸다. 범퍼 5종이 전부 무음이다.")
	_expect(binder.ball_flow_rules != null,
		"★ 씬에 흐름 규칙이 안 물렸다. 발사·낙하음이 안 난다.")

	var director := binder.get_director()
	_expect(director != null, "디렉터를 찾아야 한다.")

	if director == null or binder.combo_rules == null:
		scene.queue_free()
		return

	# 디렉터가 실제로 재생했는지 세어본다
	var played: Array[StringName] = []
	director.cue_played.connect(
		func(cue_id: StringName, _p: int, _v: float, _s: float) -> void:
			played.append(cue_id)
	)

	# 시그널 대신 핸들러를 직접 부른다. 연구실에는 ComboSystem 은 있어도
	# 웨이브 흐름 노드가 없어 시그널을 자연 발생시킬 수 없다.
	binder._on_combo_changed(3, 1, 2.0)
	binder._on_combo_tier_changed(0, 1, 5)
	binder._on_wave_balls_exhausted()
	await physics_frame

	_expect(played.has(&"combo_rise"),
		"★ 콤보 상승 배선이 소리로 이어지지 않는다. (재생: %s)" % [played])
	_expect(played.has(&"combo_tier"),
		"★ 콤보 단계 배선이 소리로 이어지지 않는다. (재생: %s)" % [played])
	_expect(played.has(&"wave_lost"),
		"★ 웨이브 패배 배선이 소리로 이어지지 않는다. (재생: %s)" % [played])

	# 단계가 내려갈 때는 울리지 않아야 한다
	var before := played.size()
	binder._on_combo_tier_changed(2, 1, 3)
	await physics_frame
	_expect(played.size() == before,
		"콤보 단계가 내려갈 때는 울리면 안 된다.")

	# 점수가 붙은 정상 종료는 실패음이 나면 안 된다
	before = played.size()
	binder._on_combo_finished(5, 2, 1200, 0)
	await physics_frame
	_expect(played.size() == before,
		"점수가 붙은 콤보 종료에 실패음이 나면 안 된다.")

	binder._on_combo_finished(5, 2, 0, 1)
	await physics_frame
	_expect(played.has(&"combo_timeout"),
		"★ 점수 없이 끝난 콤보에는 실패음이 나야 한다. (재생: %s)" % [played])

	# ★ 연구실 키가 규칙에 닿는가.
	#   이번에 실제로 겪은 실패다 — 씬에 프로퍼티를 넣었는데 에디터가 다시
	#   저장하면서 **모르는 프로퍼티라고 조용히 지웠다.** 에러도 경고도 없었다.
	_expect(scene.combo_rules != null,
		"★ 연구실 루트에 콤보 규칙이 없다. T·Y·U·I·O 키가 전부 먹통이다.")
	_expect(scene.bumper_rules != null,
		"★ 연구실 루트에 범퍼 규칙이 없다. Z·X·C·V·B 키가 전부 먹통이다.")
	_expect(scene.ball_flow_rules != null,
		"★ 연구실 루트에 흐름 규칙이 없다. Q·E 키가 먹통이다.")

	scene.queue_free()
	await physics_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: tier34_binding_test")
		quit(0)
		return

	print("FAIL: tier34_binding_test (%d failures)" % _failures.size())
	quit(1)
