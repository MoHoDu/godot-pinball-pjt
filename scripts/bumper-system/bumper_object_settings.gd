@tool
class_name BumperObjectSettings
extends Resource


## 실제 공과 부딪히는 물리 충돌 원의 지름입니다. 씬에서 주황색 실선으로 표시됩니다.
@export_range(16.0, 256.0, 1.0, "suffix:px") var collision_diameter := 88.0:
	set(value):
		collision_diameter = value
		emit_changed()
## 화면에 그려지는 범퍼 외형의 지름입니다. 씬에서 청록색 가이드로 표시됩니다.
@export_range(16.0, 320.0, 1.0, "suffix:px") var visual_diameter := 92.0:
	set(value):
		visual_diameter = value
		emit_changed()
## 복구할 때 공과 확보해야 하는 충돌 원 바깥쪽 추가 여유 거리입니다.
@export_range(0.0, 256.0, 1.0, "suffix:px") var respawn_safe_margin := 40.0:
	set(value):
		respawn_safe_margin = value
		emit_changed()
## 보드에 동시에 배치할 수 있는 최대 개수입니다. 0은 제한 없음입니다.
@export_range(0, 99, 1) var maximum_per_board := 0:
	set(value):
		maximum_per_board = value
		emit_changed()
## 범퍼의 색상, 모양, 라벨을 정의하는 외형 설정입니다.
@export var presentation: BumperPresentationSettings:
	set(value):
		presentation = value
		emit_changed()


func is_valid() -> bool:
	return collision_diameter > 0.0 and visual_diameter > 0.0
