class_name SfxPriority
extends RefCounted
## 사운드 우선순위입니다. 기획서가 세 곳에서 반복한 순서를 그대로 숫자로 옮겼습니다.
##
##   p.42 3-12 · p.90 6-5 · p.154 3-7
##   1. 정확한 패링 → 2. 보스 타격 → 3. 플리퍼 타격
##   → 4. 공과 주요 범퍼 충돌 → 5. 일반 벽 충돌 → 6. 환경음·장식음
##
## ★ 이 순서가 필요한 이유는 한 물리 프레임 안의 도착 순서가 **거꾸로**이기 때문입니다.
##   물리 접촉 해소가 회전 스윕 판정보다 먼저 돌아서, 벽 충돌 여러 개가 목소리를 잡은
##   뒤에 패링이 도착합니다. 선착순으로 나눠주면 가장 중요한 소리가 밀립니다.
##
## SfxDirector 안의 enum 이 아니라 별도 클래스인 이유는 순환 참조 때문입니다.
## SfxCue 가 우선순위를 참조해야 하는데 SfxDirector 는 SfxCue 를 참조합니다.


const AMBIENT: int = 0		## 6. 환경음·장식음. 조작 피드백·UI·흐름음
const WALL: int = 10		## 5. 일반 벽 충돌
const IMPACT: int = 20		## 4. 공과 주요 범퍼 충돌
const FLIPPER: int = 30		## 3. 플리퍼 타격
const BOSS: int = 40		## 2. 보스 타격 (오브젝트 미배치 — 자리만 비워둠)
const PARRY: int = 50		## 1. 정확한 패링

## 인덱스 순서입니다. SfxDirectorRules 의 예약·상한 배열과 같은 순서를 씁니다.
const ORDER: Array[int] = [AMBIENT, WALL, IMPACT, FLIPPER, BOSS, PARRY]

const NAMES: Array[StringName] = [
	&"AMBIENT", &"WALL", &"IMPACT", &"FLIPPER", &"BOSS", &"PARRY",
]


## 우선순위 값을 0~5 인덱스로 바꿉니다. 모르는 값은 가장 낮은 등급으로 봅니다.
static func to_index(priority: int) -> int:
	var index := ORDER.find(priority)
	return index if index >= 0 else 0


## 로그·테스트용 이름입니다.
static func to_name(priority: int) -> StringName:
	return NAMES[to_index(priority)]
