@tool
class_name SfxCue
extends Resource
## 재생할 수 있는 소리 하나입니다. 무엇을 · 얼마나 크게 · 어떤 피치로 울릴지를 담습니다.
##
## "언제 울릴지"는 여기 없습니다. 그건 시그널을 구독하는 쪽(WaveSfxBinder)의 일입니다.
## "동시에 몇 개까지 울릴지"도 여기 없습니다. 그건 SfxDirector 의 일입니다.
##
## ★ `common_attack_sfx` 같은 필드를 **일부러 만들지 않았습니다.**
##   충돌음 파일에는 공통 어택이 이미 섞여 있습니다(2026-08-06 파형 상관 실측으로 확인).
##   필드를 만들어 두면 언젠가 누가 채워서 어택이 두 번 찍힙니다. 필드가 없는 게 방어입니다.


## 음원을 고르는 방식입니다.
enum SelectionMode {
	RANDOM,		## 무작위. 재질 변형이 여러 개일 때
	SPEED_TIER,	## 속도 구간별. 벽 충돌 3종이 이것입니다
	SEQUENTIAL,	## 순서대로. 콤보 상승처럼 단계가 있는 것
}

const MIN_PITCH_JITTER: float = 0.0
const MAX_PITCH_JITTER: float = 0.5
const DEFAULT_PITCH_JITTER: float = 0.05	## 기획서 p.62 "피치 랜덤 ±5%"

const MIN_INTERVAL: float = 0.0
const MAX_INTERVAL: float = 2.0
const DEFAULT_MIN_INTERVAL: float = 0.04	## 기획서 p.62 "동일 공 재생 간격 최소 0.04초"

const MIN_REPEAT_STEP: float = -12.0
const MAX_REPEAT_STEP: float = 0.0
const DEFAULT_REPEAT_STEP_DB: float = -3.0	## 기획서 p.62 "연속 충돌 두 번째부터 약 -3dB"

const MIN_REPEAT_FLOOR: float = -36.0
const MAX_REPEAT_FLOOR: float = 0.0
const DEFAULT_REPEAT_FLOOR_DB: float = -9.0

const MIN_CHAIN_RESET: float = 0.05
const MAX_CHAIN_RESET: float = 4.0
const DEFAULT_CHAIN_RESET: float = 0.24

const MIN_CONCURRENT: int = 1
const MAX_CONCURRENT: int = 8
const DEFAULT_CONCURRENT: int = 4


var _streams: Array[AudioStream] = []
var _pitch_jitter: float = DEFAULT_PITCH_JITTER
var _minimum_repeat_interval: float = DEFAULT_MIN_INTERVAL
var _repeat_attenuation_db: float = DEFAULT_REPEAT_STEP_DB
var _repeat_attenuation_floor_db: float = DEFAULT_REPEAT_FLOOR_DB
var _repeat_chain_reset_time: float = DEFAULT_CHAIN_RESET
var _maximum_concurrent: int = DEFAULT_CONCURRENT


@export_category("SFX 큐")

## 로그와 테스트에서 이 큐를 가리키는 이름입니다.
@export var cue_id: StringName = &"cue"

## 이 소리가 게임에서 무엇을 표현하는지입니다. 파일명만으로는 용도를 알 수 없습니다.
@export_multiline var role: String = ""


@export_group("음원")

## 재생할 음원들입니다. SPEED_TIER 이면 **[저속, 중속, 고속] 순서**로 넣습니다.
@export var streams: Array[AudioStream]:
	get:
		return _streams
	set(value):
		_streams = value
		emit_changed()

@export var selection_mode: SelectionMode = SelectionMode.RANDOM

## SPEED_TIER 일 때 구간 경계입니다(px/s). [중속 시작, 고속 시작].
##
## ★ 벽 충돌 3종은 랜덤 변형이 아니라 **저·중·고속 대응**입니다 (가이드 p.73 MUST).
##   고속 음원에만 유리 팅이 붙어 있어 음량 조절로 대체되지 않습니다.
##   랜덤으로 고르면 느린 충돌에서 고속 음색이 납니다.
@export var speed_tier_thresholds: PackedFloat32Array = [420.0, 1050.0]


@export_group("우선순위")

## SfxPriority 의 상수를 씁니다. 목소리 경쟁에서 이 값이 큰 쪽이 이깁니다.
@export var priority: int = SfxPriority.AMBIENT

## 이 큐 하나가 동시에 차지할 수 있는 목소리 수입니다. 클래스 상한과는 별개입니다.
@export_range(1, 8, 1)
var maximum_concurrent: int:
	get:
		return _maximum_concurrent
	set(value):
		_maximum_concurrent = clampi(value, MIN_CONCURRENT, MAX_CONCURRENT)
		emit_changed()


@export_group("음량")

## 큐 고정 오프셋입니다. 파일에 구워진 dB 관계를 뒤집을 만큼 크게 주면 안 됩니다.
@export_range(-40.0, 12.0, 0.5, "suffix:dB")
var base_volume_db: float = 0.0

## 속도→음량 매핑의 입력 구간입니다(px/s). x 이하는 가장 작고 y 이상은 가장 큽니다.
@export var speed_reference_range: Vector2 = Vector2(120.0, 900.0)

## 위 구간에 대응하는 출력 dB 입니다.
@export var speed_volume_range: Vector2 = Vector2(-14.0, 0.0)

## 이 속도 미만의 접촉은 아예 울리지 않습니다. 벽에 얹혀 떠는 공을 거릅니다.
@export_range(0.0, 400.0, 1.0, "suffix:px/s")
var silence_below_speed: float = 0.0


@export_group("피치")

## 재생할 때마다 얹는 피치 랜덤 폭입니다. **파일에 굽지 않습니다.**
@export_range(0.0, 0.5, 0.01, "suffix:x")
var pitch_jitter: float:
	get:
		return _pitch_jitter
	set(value):
		_pitch_jitter = clampf(value, MIN_PITCH_JITTER, MAX_PITCH_JITTER)
		emit_changed()


@export_group("연타")

## 같은 소스가 이 시간 안에 다시 요청하면 막습니다.
@export_range(0.0, 2.0, 0.005, "suffix:s")
var minimum_repeat_interval: float:
	get:
		return _minimum_repeat_interval
	set(value):
		_minimum_repeat_interval = clampf(value, MIN_INTERVAL, MAX_INTERVAL)
		emit_changed()

## 연타 1회마다 깎는 양입니다.
@export_range(-12.0, 0.0, 0.5, "suffix:dB")
var repeat_attenuation_db: float:
	get:
		return _repeat_attenuation_db
	set(value):
		_repeat_attenuation_db = clampf(value, MIN_REPEAT_STEP, MAX_REPEAT_STEP)
		emit_changed()

## 연타 감쇠의 바닥입니다. 없으면 오래 구르는 공이 완전히 무음이 됩니다.
@export_range(-36.0, 0.0, 0.5, "suffix:dB")
var repeat_attenuation_floor_db: float:
	get:
		return _repeat_attenuation_floor_db
	set(value):
		_repeat_attenuation_floor_db = clampf(value, MIN_REPEAT_FLOOR, MAX_REPEAT_FLOOR)
		emit_changed()

## 이 시간 동안 요청이 없으면 연타 사슬이 풀립니다.
@export_range(0.05, 4.0, 0.01, "suffix:s")
var repeat_chain_reset_time: float:
	get:
		return _repeat_chain_reset_time
	set(value):
		_repeat_chain_reset_time = clampf(value, MIN_CHAIN_RESET, MAX_CHAIN_RESET)
		emit_changed()


## 이 속도의 접촉이 소리를 낼지입니다.
func is_audible(speed: float) -> bool:
	return speed >= silence_below_speed


## 속도에 해당하는 구간 인덱스입니다. 0=저속 1=중속 2=고속.
## 경계가 뒤집혀 설정돼도 순서가 보장되도록 정렬해서 씁니다.
func get_speed_tier(speed: float) -> int:
	if speed_tier_thresholds.size() < 2:
		return 0

	var low_edge := minf(speed_tier_thresholds[0], speed_tier_thresholds[1])
	var high_edge := maxf(speed_tier_thresholds[0], speed_tier_thresholds[1])

	if speed >= high_edge:
		return 2

	return 1 if speed >= low_edge else 0


## 이번에 재생할 음원을 고릅니다. rng 를 주입받아 테스트에서 재현할 수 있게 합니다.
func select_stream(speed: float, rng: RandomNumberGenerator, sequence_index: int = 0) -> AudioStream:
	var usable: Array[AudioStream] = []
	for stream: AudioStream in _streams:
		if stream != null:
			usable.append(stream)

	if usable.is_empty():
		return null

	match selection_mode:
		SelectionMode.SPEED_TIER:
			# 비어 있는 칸이 있으면 아래 구간으로 내려가며 찾습니다.
			return usable[mini(get_speed_tier(speed), usable.size() - 1)]
		SelectionMode.SEQUENTIAL:
			return usable[posmod(sequence_index, usable.size())]
		_:
			return usable[rng.randi_range(0, usable.size() - 1)]


## 충돌 속도에 대응하는 음량(dB)입니다.
func get_speed_volume_db(speed: float) -> float:
	var low := speed_reference_range.x
	var high := speed_reference_range.y
	if is_equal_approx(low, high):
		return speed_volume_range.y

	var t := clampf((speed - low) / (high - low), 0.0, 1.0)
	return lerpf(speed_volume_range.x, speed_volume_range.y, t)


## 연타 횟수에 대응하는 감쇠(dB)입니다. 0회가 감쇠 없음입니다.
##
## 검수용 오디션 스크립트(docs/sfx/build_wall_sfx.py)와 **같은 수식**이어야 합니다.
## 다르면 오디션에서 들은 것과 게임에서 나는 것이 달라져 검수가 무의미해집니다.
func get_repeat_volume_db(repeat_count: int) -> float:
	if repeat_count <= 0:
		return 0.0

	return maxf(_repeat_attenuation_db * float(repeat_count), _repeat_attenuation_floor_db)


## ±jitter 범위의 피치입니다.
func random_pitch(rng: RandomNumberGenerator) -> float:
	if _pitch_jitter <= 0.0:
		return 1.0

	return 1.0 + rng.randf_range(-_pitch_jitter, _pitch_jitter)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _streams.is_empty():
		warnings.append("음원이 하나도 없습니다.")
	elif selection_mode == SelectionMode.SPEED_TIER and _streams.size() < 3:
		warnings.append("속도 구간 방식은 저·중·고속 3종이 필요합니다 (지금 %d개)." % _streams.size())

	return warnings
