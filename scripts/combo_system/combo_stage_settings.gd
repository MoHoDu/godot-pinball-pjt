@tool
class_name ComboStageSettings
extends Resource


## 스테이지를 식별하는 기획용 ID입니다.
@export var stage_id: StringName = &"stage"

## 점수 가중치 1.0인 유효 타격 한 번의 기준 점수입니다.
@export_range(0, 1000000, 1)
var stage_base_score: int = 100:
	set(value):
		stage_base_score = maxi(value, 0)
		emit_changed()

## 0번 인덱스부터 시작하는 각 웨이브의 목표 점수입니다.
@export var wave_target_scores: PackedInt32Array = PackedInt32Array():
	set(value):
		wave_target_scores = value
		for index in wave_target_scores.size():
			wave_target_scores[index] = maxi(wave_target_scores[index], 0)
		emit_changed()


func get_wave_target_score(wave_index: int) -> int:
	if wave_index < 0 or wave_index >= wave_target_scores.size():
		return 0
	return maxi(wave_target_scores[wave_index], 0)
