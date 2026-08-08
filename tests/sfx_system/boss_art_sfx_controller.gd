extends "res://scripts/boss_system/anim/boss_art_test_controller.gd"
## 보스 아트 검수 씬에 **소리를 얹은** 컨트롤러입니다.
##
## ★ 리그(BossArtRig)에는 시그널이 없습니다 — 상태는 play_state() 로만
##   바뀝니다. 그래서 키 입력을 다시 해석하지 않고 **리그의 상태 전이를
##   감시**합니다. 키로 바꾸든 Space 시퀀스가 자동으로 넘기든, 상태가
##   telegraph → attack 으로 흐르면 소리도 같은 순간에 흐릅니다.
##   애니메이션과 소리가 어긋나면 여기서 바로 들립니다.
##
## 조작은 부모 그대로: 1 대기 · 2 예고 · 3 공격 · 4 경직 · 5 피격 ·
##                     6 강한 피격 · 7 포효 · Space 시퀀스

## 상태 -> 큐 필드. 대기·경직은 사건이 아니라 소리가 없다.
const STATE_CUES := {
	&"telegraph": &"telegraph_cue",
	&"attack": &"arm_swing_cue",
	&"roar": &"roar_cue",
}

@export var boss_rules: BossSfxRules

var _sfx_last_state: StringName = &"idle"
var _sfx_was_jolting := false

@onready var _sfx_director: SfxDirector = $SfxDirector


func _process(delta: float) -> void:
	super(delta)

	if _rig == null:
		return

	# 상태 전이 → 그 상태의 소리
	var state := _rig.get_state()
	if state != _sfx_last_state:
		_sfx_last_state = state
		if STATE_CUES.has(state):
			_sfx_play(STATE_CUES[state])

	# 피격 반동(jolt)은 상태가 아니라 별도 흔들림이라 따로 감시한다
	var jolting := _rig.is_jolting()
	if jolting and not _sfx_was_jolting:
		_sfx_play(&"hit_cue")
	_sfx_was_jolting = jolting


func _sfx_play(field: StringName) -> void:
	if boss_rules == null or _sfx_director == null:
		return

	var cue: SfxCue = boss_rules.get(field)
	if cue == null:
		return

	_sfx_director.request(cue, SfxPlayContext.new())
