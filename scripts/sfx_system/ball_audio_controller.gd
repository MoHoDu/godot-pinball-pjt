@tool
class_name BallAudioController
extends Node
## 공 하나의 소리 상태를 관리합니다. 문서 12-3 의 `BallVisual > … > AudioController` 자리입니다.
##
## ★ AudioStreamPlayer 를 **소유하지 않습니다.** 목소리는 SfxDirector 가 전부 갖고 있습니다.
##   이 노드가 하는 일은 "이번 요청을 보낼지, 보낸다면 얼마나 깎아서 보낼지"를 정하는 것뿐입니다.
##   목소리를 여기서 들고 있으면 공·플리퍼·범퍼가 각자 재생해서 전체 동시 재생 수를
##   아무도 세지 못하고, 우선순위도 깨집니다.
##
## 여기서만 계산하는 것 세 가지:
##   ① 최소 재생 간격 — 같은 공이 벽을 스치며 굴러갈 때 기관총이 되는 걸 막는다
##   ② 연타 감쇠 사슬 — 두 번째부터 -3dB, 바닥 -9dB
##   ③ ★ 패링 래치 — 패링 프레임의 낮은 우선순위 요청을 **보내기 전에** 막는다
##
## ★ 왜 패링 래치가 필요한가
##   패링 1회에 대해 세 개가 옵니다.
##     (1) Flipper.parry_resolved
##     (2) rotation_sweep_resolved → ComboCollisionBridge.flipper_contact_registered
##     (3) 물리 body_entered
##   `flipper.gd:1183-1191` 에서 (1)이 (2)보다 **먼저** emit 되는 것이 확인됐으므로
##   프레임 래치가 결정적으로 동작합니다.
##
##   ★ SfxDirector 의 드롭에 맡기면 안 됩니다. 드롭은 목소리가 없을 때만 일어나고,
##     목소리가 남아 있으면 패링음 위에 타격음이 정상적으로 겹쳐 어택이 두 번 찍힙니다.
##     억제는 반드시 **요청 이전**이어야 합니다.


## 이 노드의 이름입니다. 런타임에 공에 붙일 때 이 이름으로 찾습니다.
const NODE_NAME: StringName = &"_AudioController"


## 큐 하나에 대한 이 공의 상태입니다.
class CueState:
	extends RefCounted

	var last_play_msec: int = -1000000
	var repeat_count: int = 0


var _director: SfxDirector
var _states: Dictionary = {}
var _parry_frame: int = -1
var _last_volume_db: float = 0.0
var _suppressed_count: int = 0

## 시각·프레임 공급자입니다. 테스트가 직접 밀 수 있게 주입 가능합니다.
var time_source: Callable = Time.get_ticks_msec
var frame_source: Callable = Engine.get_physics_frames


## 목소리를 빌려올 디렉터입니다.
func bind_director(director: SfxDirector) -> void:
	_director = director


func get_director() -> SfxDirector:
	return _director


## 이 공의 소리 요청 전부가 여기를 지납니다.
##
## speed 는 충돌 속도(px/s)입니다. 속도가 필요 없는 소리는 0을 넣습니다.
func play(cue: SfxCue, speed: float = 0.0) -> SfxPlayResult:
	var result := SfxPlayResult.new()

	if cue == null or _director == null:
		return result

	var now := int(time_source.call())
	var frame := int(frame_source.call())

	if cue.priority >= SfxPriority.PARRY:
		# 패링은 스로틀·연타 감쇠를 받지 않습니다. 플레이어가 성공시킨 순간이라
		# 항상 또렷하게 들려야 합니다. 대신 이 프레임을 래치에 적어둡니다.
		_parry_frame = frame
	elif _parry_frame == frame:
		# ★ 같은 프레임에 패링이 있었으면 낮은 소리는 아예 보내지 않습니다.
		_suppressed_count += 1
		result.outcome = SfxPlayResult.Outcome.DROPPED_SILENT
		return result

	var state := _state_for(cue.cue_id)
	var elapsed_ms := now - state.last_play_msec

	if cue.priority < SfxPriority.PARRY:
		if elapsed_ms < int(cue.minimum_repeat_interval * 1000.0):
			result.outcome = SfxPlayResult.Outcome.DROPPED_CAP
			return result

		# 사슬이 끊겼으면 감쇠를 푼다
		if elapsed_ms > int(cue.repeat_chain_reset_time * 1000.0):
			state.repeat_count = 0

	var context := SfxPlayContext.new(get_instance_id(), speed)
	context.volume_offset_db = cue.get_repeat_volume_db(state.repeat_count)

	result = _director.request(cue, context)

	if result.is_played():
		state.last_play_msec = now
		state.repeat_count += 1
		_last_volume_db = result.volume_db

	return result


## 이 프레임에 패링이 있었다고 알립니다.
## 패링음을 이 컨트롤러가 아닌 곳에서 울릴 때 래치만 걸기 위한 것입니다.
func notify_parry() -> void:
	_parry_frame = int(frame_source.call())


## 연타 사슬을 전부 풉니다. 새 공·웨이브 리셋에서 씁니다.
func reset_chains() -> void:
	_states.clear()
	_parry_frame = -1


## 마지막으로 재생된 음량입니다. 테스트·디버그용입니다.
func get_last_volume_db() -> float:
	return _last_volume_db


## 특정 큐의 현재 연타 횟수입니다. 테스트용입니다.
func get_repeat_count(cue_id: StringName) -> int:
	var state: CueState = _states.get(cue_id)
	return state.repeat_count if state != null else 0


## 패링 래치로 막은 요청 수입니다. 테스트용입니다.
func get_suppressed_count() -> int:
	return _suppressed_count


# ── 내부 ────────────────────────────────────────────────────

func _state_for(cue_id: StringName) -> CueState:
	var state: CueState = _states.get(cue_id)
	if state == null:
		state = CueState.new()
		_states[cue_id] = state

	return state


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if get_parent() == null:
		warnings.append("BallAudioController 의 부모는 공이어야 합니다.")

	return warnings
