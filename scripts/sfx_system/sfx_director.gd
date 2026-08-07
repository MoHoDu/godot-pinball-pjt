@tool
class_name SfxDirector
extends Node
## 목소리 풀을 소유하고 우선순위에 따라 나눠주는 노드입니다.
##
## ★ 게임 지식이 없습니다. 공도 플리퍼도 범퍼도 모릅니다.
##   "이 큐를 이 상황으로 울려달라"는 요청만 받습니다. 무엇이 언제 울릴지는
##   WaveSfxBinder 가 정하고, 공별 연타 사슬은 BallAudioController 가 셉니다.
##   그래야 이 클래스를 씬 없이 단독으로 테스트할 수 있습니다.
##
## ★ 큐잉하지 않습니다. 자리가 없으면 **드롭**합니다.
##   늦게 나는 충돌음은 없는 것보다 나쁩니다. 어택 위치가 전부인 게임 사운드에서
##   타이밍이 어긋난 소리는 정보가 아니라 오정보입니다.
##
## ★ 목소리 회수를 `is_playing()` 으로 하지 않습니다.
##   헤드리스는 더미 오디오 드라이버라 그 값을 믿을 수 없습니다. 대신 배정 시점에
##   종료 예정 시각을 적어두고 그걸로 회수합니다. 덕분에 테스트가 프레임을 기다리지
##   않고 결정적으로 돌고, 스틸·로드 실패·일시정지에서도 회수가 멈추지 않습니다.


## 검수·디버그용입니다. 게임 로직은 이 시그널에 의존하지 않습니다.
signal cue_played(cue_id: StringName, priority: int, volume_db: float, pitch_scale: float)
signal cue_dropped(cue_id: StringName, priority: int, outcome: int)


const DEFAULT_RULES: SfxDirectorRules = preload(
	"res://settings/sfx/SfxDirectorRules.tres"
)

## 스트림 길이를 못 읽었을 때 쓰는 값입니다. 회수가 영영 안 되는 것보다 낫습니다.
const FALLBACK_LENGTH_SEC: float = 0.25


## 목소리 하나의 상태입니다.
class Voice:
	extends RefCounted

	var player: AudioStreamPlayer
	var priority: int = -1
	var cue_id: StringName = &""
	var started_msec: int = 0
	var expected_end_msec: int = 0

	func is_free() -> bool:
		return priority < 0

	func release() -> void:
		priority = -1
		cue_id = &""
		expected_end_msec = 0


var _rules: SfxDirectorRules = DEFAULT_RULES
var _voices: Array[Voice] = []
var _rng := RandomNumberGenerator.new()

## 시각 공급자입니다. 테스트가 시간을 직접 밀 수 있게 주입 가능합니다.
var time_source: Callable = Time.get_ticks_msec


@export var rules: SfxDirectorRules:
	get:
		return _rules
	set(value):
		_rules = value if value != null else DEFAULT_RULES
		update_configuration_warnings()

## 0이면 매번 다른 난수를 씁니다. 테스트에서는 값을 지정해 재현합니다.
@export var random_seed: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed

	_build_pool()


## 요청을 처리합니다. 실제로 울렸는지와 왜 안 울렸는지를 돌려줍니다.
func request(cue: SfxCue, context: SfxPlayContext) -> SfxPlayResult:
	var result := SfxPlayResult.new()

	if cue == null:
		return result

	_reclaim_finished()

	if not cue.is_audible(context.speed):
		result.outcome = SfxPlayResult.Outcome.DROPPED_SILENT
		cue_dropped.emit(cue.cue_id, cue.priority, result.outcome)
		return result

	var stream := cue.select_stream(context.speed, _rng, context.sequence_index)
	if stream == null:
		result.outcome = SfxPlayResult.Outcome.DROPPED_EMPTY
		cue_dropped.emit(cue.cue_id, cue.priority, result.outcome)
		return result

	# ① 클래스 하드캡 — 풀에 자리가 남아 있어도 넘지 못합니다.
	#    벽의 4가 기획서 "최대 동시 재생 4개"의 구현입니다.
	if _count_active(cue.priority) >= _rules.cap_for(cue.priority):
		result.outcome = SfxPlayResult.Outcome.DROPPED_CAP
		cue_dropped.emit(cue.cue_id, cue.priority, result.outcome)
		return result

	# ② 큐 자체의 상한
	if _count_active_cue(cue.cue_id) >= cue.maximum_concurrent:
		result.outcome = SfxPlayResult.Outcome.DROPPED_CAP
		cue_dropped.emit(cue.cue_id, cue.priority, result.outcome)
		return result

	var index := _find_free_voice()
	if index >= 0:
		result.outcome = SfxPlayResult.Outcome.PLAYED
	else:
		# ③ 자리가 없으면 나보다 낮은 우선순위에게서 뺏습니다.
		index = _find_steal_target(cue.priority)
		if index < 0:
			result.outcome = SfxPlayResult.Outcome.DROPPED_FULL
			cue_dropped.emit(cue.cue_id, cue.priority, result.outcome)
			return result

		result.outcome = SfxPlayResult.Outcome.PLAYED_STOLEN
		result.stolen_priority = _voices[index].priority
		_stop_voice(index)

	var volume := (
		cue.base_volume_db
		+ cue.get_speed_volume_db(context.speed)
		+ context.volume_offset_db
	)
	var pitch := (
		context.pitch_override
		if context.pitch_override > 0.0
		else cue.random_pitch(_rng)
	)

	_assign(index, cue, stream, volume, pitch)

	result.voice_index = index
	result.stream = stream
	result.volume_db = volume
	result.pitch_scale = pitch
	cue_played.emit(cue.cue_id, cue.priority, volume, pitch)
	return result


## 지금 울리고 있는 목소리 수입니다. 테스트·디버그용입니다.
func get_active_voice_count() -> int:
	_reclaim_finished()

	var count := 0
	for voice: Voice in _voices:
		if not voice.is_free():
			count += 1

	return count


## 우선순위별로 울리고 있는 수입니다.
func get_active_count(priority: int) -> int:
	_reclaim_finished()
	return _count_active(priority)


## 목소리가 지금 무슨 우선순위를 물고 있는지입니다. 비어 있으면 -1.
func get_voice_priority(index: int) -> int:
	if index < 0 or index >= _voices.size():
		return -1

	return _voices[index].priority


## 전부 멈춥니다. 웨이브 리셋·일시정지에서 씁니다.
func stop_all() -> void:
	for i in _voices.size():
		_stop_voice(i)


# ── 내부 ────────────────────────────────────────────────────

func _build_pool() -> void:
	for voice: Voice in _voices:
		if is_instance_valid(voice.player):
			voice.player.queue_free()

	_voices.clear()

	for i in _rules.voice_count:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % i
		player.bus = _rules.bus
		# 목소리 1개당 소리 1개입니다. 폴리포니는 풀이 관리합니다.
		player.max_polyphony = 1
		add_child(player)

		var voice := Voice.new()
		voice.player = player
		_voices.append(voice)


func _now() -> int:
	return int(time_source.call())


## 종료 예정 시각이 지난 목소리를 회수합니다.
func _reclaim_finished() -> void:
	var now := _now()
	for voice: Voice in _voices:
		if not voice.is_free() and now >= voice.expected_end_msec:
			voice.release()


func _count_active(priority: int) -> int:
	var count := 0
	for voice: Voice in _voices:
		if voice.priority == priority:
			count += 1

	return count


func _count_active_cue(cue_id: StringName) -> int:
	var count := 0
	for voice: Voice in _voices:
		if not voice.is_free() and voice.cue_id == cue_id:
			count += 1

	return count


func _find_free_voice() -> int:
	for i in _voices.size():
		if _voices[i].is_free():
			return i

	return -1


## 뺏을 목소리를 고릅니다.
##
## 조건 둘을 **모두** 만족해야 합니다.
##   - 나보다 **엄격히 낮은** 우선순위 (같은 등급끼리는 안 뺏습니다)
##   - 그 클래스가 예약 몫을 **초과해서** 쓰고 있을 것 (예약분은 성역입니다)
##
## 후보가 여럿이면 가장 낮은 우선순위 → 그중 가장 오래된 것 순입니다.
func _find_steal_target(priority: int) -> int:
	var best := -1
	var best_priority := priority
	var best_started := 0

	for i in _voices.size():
		var voice := _voices[i]
		if voice.is_free() or voice.priority >= priority:
			continue

		if _count_active(voice.priority) <= _rules.reserved_for(voice.priority):
			continue

		if best < 0 or voice.priority < best_priority \
				or (voice.priority == best_priority and voice.started_msec < best_started):
			best = i
			best_priority = voice.priority
			best_started = voice.started_msec

	return best


func _assign(
	index: int,
	cue: SfxCue,
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float
) -> void:
	var voice := _voices[index]
	var now := _now()

	var length := stream.get_length()
	if length <= 0.0:
		length = FALLBACK_LENGTH_SEC

	voice.priority = cue.priority
	voice.cue_id = cue.cue_id
	voice.started_msec = now
	voice.expected_end_msec = now + int(length / maxf(pitch_scale, 0.01) * 1000.0)

	var player := voice.player
	if is_instance_valid(player):
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()


func _stop_voice(index: int) -> void:
	if index < 0 or index >= _voices.size():
		return

	var voice := _voices[index]
	var player := voice.player

	if is_instance_valid(player) and player.playing:
		if _rules.steal_fade_time > 0.0 and is_inside_tree():
			# 즉시 끊으면 파형 중간이 잘려 딱 소리가 납니다.
			var tween := create_tween()
			tween.tween_property(player, "volume_db", -60.0, _rules.steal_fade_time)
			tween.tween_callback(player.stop)
		else:
			player.stop()

	voice.release()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _rules == null:
		warnings.append("SfxDirectorRules 리소스를 지정해야 합니다.")
		return warnings

	if AudioServer.get_bus_index(_rules.bus) < 0:
		warnings.append("버스 '%s' 가 프로젝트에 없습니다." % _rules.bus)

	return warnings
