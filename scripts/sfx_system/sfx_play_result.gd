class_name SfxPlayResult
extends RefCounted
## 재생 요청의 결과입니다. 테스트가 "왜 안 났는지"까지 볼 수 있어야 합니다.


enum Outcome {
	PLAYED,			## 빈 목소리에 배정됨
	PLAYED_STOLEN,	## 낮은 우선순위에게서 뺏어 배정됨
	DROPPED_CAP,	## 클래스 하드캡에 걸림 (벽 4개 규격이 여기)
	DROPPED_FULL,	## 풀이 찼고 뺏을 후보도 없음
	DROPPED_SILENT,	## 속도가 무음 임계 미만
	DROPPED_EMPTY,	## 큐에 음원이 없음
}


var outcome: Outcome = Outcome.DROPPED_EMPTY
var voice_index: int = -1
var stream: AudioStream = null
var volume_db: float = 0.0
var pitch_scale: float = 1.0

## 뺏은 경우 뺏긴 쪽의 우선순위입니다. 안 뺏었으면 -1.
var stolen_priority: int = -1


func is_played() -> bool:
	return outcome == Outcome.PLAYED or outcome == Outcome.PLAYED_STOLEN
