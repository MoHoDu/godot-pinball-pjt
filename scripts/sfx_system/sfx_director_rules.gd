@tool
class_name SfxDirectorRules
extends Resource
## 목소리 풀의 크기와 우선순위 클래스별 몫입니다.
##
## ★ 설계의 핵심은 **벽에 예약 레인을 0으로 주는 것**입니다.
##   벽은 항상 빌려 쓰고 항상 먼저 뺏깁니다. 그래서 벽 충돌이 아무리 많이 나도
##   패링이 밀리지 않습니다. 패링이 보장되는 이유는 세 겹입니다.
##     ① 벽 하드캡 4 — 풀에 자리가 남아 있어도 벽은 4개를 넘지 못한다
##     ② 패링 예약 2 — 다른 클래스가 절대 가져가지 못하는 자리
##     ③ 우선순위 스틸링 — 그마저 찼을 때 낮은 우선순위에게서 뺏는다
##
## 배열은 전부 SfxPriority.ORDER 순서입니다: [AMBIENT, WALL, IMPACT, FLIPPER, BOSS, PARRY]


const MIN_VOICES: int = 4
const MAX_VOICES: int = 64
const DEFAULT_VOICE_COUNT: int = 16

## 스틸할 때 바로 끊지 않고 이만큼 볼륨을 내린 뒤 멈춥니다.
## 즉시 stop() 하면 파형 중간이 잘려 딱 소리가 납니다.
const MIN_STEAL_FADE: float = 0.0
const MAX_STEAL_FADE: float = 0.05
const DEFAULT_STEAL_FADE: float = 0.008

## [AMBIENT, WALL, IMPACT, FLIPPER, BOSS, PARRY]
##
## ★ `PackedInt32Array([...])` 로 쓰면 안 됩니다. 생성자는 상수 표현식이 아니라
##   클래스 전체가 컴파일되지 않고, 다른 스크립트에서 이 클래스의 멤버를
##   "Could not resolve external class member" 로 못 찾습니다.
##   → docs/ai_memory/reference_codebase_conventions.md 의 GDScript 함정
const DEFAULT_RESERVED: PackedInt32Array = [0, 0, 2, 2, 1, 2]
const DEFAULT_HARD_CAPS: PackedInt32Array = [2, 4, 5, 4, 2, 3]


var _voice_count: int = DEFAULT_VOICE_COUNT
var _steal_fade_time: float = DEFAULT_STEAL_FADE


@export_category("SFX 디렉터")

## 목소리 총 개수입니다. 이 값이 곧 동시에 날 수 있는 소리의 절대 상한입니다.
@export_range(4, 64, 1)
var voice_count: int:
	get:
		return _voice_count
	set(value):
		_voice_count = clampi(value, MIN_VOICES, MAX_VOICES)
		emit_changed()

## 출력 버스입니다. default_bus_layout.tres 에 정의돼 있습니다.
@export var bus: StringName = &"SFX"

## 클래스별 예약 레인입니다. 다른 클래스가 이 몫은 뺏지 못합니다.
## 순서: [AMBIENT, WALL, IMPACT, FLIPPER, BOSS, PARRY]
@export var reserved_voices: PackedInt32Array = DEFAULT_RESERVED

## 클래스별 동시 재생 상한입니다. 풀에 자리가 남아 있어도 이 수를 넘지 못합니다.
## ★ WALL 의 4 가 기획서 p.62 "최대 동시 재생 4개"의 구현입니다. 별도 로직이 아닙니다.
@export var hard_caps: PackedInt32Array = DEFAULT_HARD_CAPS

## 스틸 시 페이드 시간입니다.
@export_range(0.0, 0.05, 0.001, "suffix:s")
var steal_fade_time: float:
	get:
		return _steal_fade_time
	set(value):
		_steal_fade_time = clampf(value, MIN_STEAL_FADE, MAX_STEAL_FADE)
		emit_changed()


## 우선순위의 예약 몫입니다.
func reserved_for(priority: int) -> int:
	var index := SfxPriority.to_index(priority)
	return reserved_voices[index] if index < reserved_voices.size() else 0


## 우선순위의 동시 재생 상한입니다.
func cap_for(priority: int) -> int:
	var index := SfxPriority.to_index(priority)
	return hard_caps[index] if index < hard_caps.size() else _voice_count


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var expected := SfxPriority.ORDER.size()

	if reserved_voices.size() != expected:
		warnings.append("예약 레인은 %d개여야 합니다 (지금 %d개)."
			% [expected, reserved_voices.size()])

	if hard_caps.size() != expected:
		warnings.append("하드캡은 %d개여야 합니다 (지금 %d개)."
			% [expected, hard_caps.size()])

	var reserved_total := 0
	for value in reserved_voices:
		reserved_total += value

	if reserved_total > _voice_count:
		warnings.append("예약 합계(%d)가 목소리 수(%d)를 넘습니다."
			% [reserved_total, _voice_count])

	for i in mini(reserved_voices.size(), hard_caps.size()):
		if reserved_voices[i] > hard_caps[i]:
			warnings.append("%s 의 예약(%d)이 하드캡(%d)보다 큽니다."
				% [SfxPriority.NAMES[i], reserved_voices[i], hard_caps[i]])

	return warnings
