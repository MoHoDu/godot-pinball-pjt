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
## 더미 도형 대신 범퍼 외형으로 사용할 실제 이미지 Texture 리소스입니다. 비워 두면 기존 더미 외형을 표시합니다.
@export var graphic_texture: Texture2D:
	set(value):
		graphic_texture = value
		emit_changed()
## 이미지의 긴 변이 Visual Diameter에서 차지할 비율입니다. 범퍼 노드 Scale이나 충돌 Shape에는 영향을 주지 않습니다.
@export_range(0.1, 1.0, 0.01, "suffix:x") var graphic_size_ratio := 1.0:
	set(value):
		graphic_size_ratio = value
		emit_changed()
## 이미지 중심을 범퍼 중심에서 이동할 픽셀 거리입니다. 충돌 위치에는 영향을 주지 않습니다.
@export var graphic_offset := Vector2.ZERO:
	set(value):
		graphic_offset = value
		emit_changed()
## 실제 이미지에 곱할 색상과 투명도입니다. 원본 색상을 유지하려면 흰색을 사용합니다.
@export var graphic_modulate := Color.WHITE:
	set(value):
		graphic_modulate = value
		emit_changed()


func get_graphic_draw_rect() -> Rect2:
	if graphic_texture == null:
		return Rect2()
	var texture_size := graphic_texture.get_size()
	var longest_side := maxf(texture_size.x, texture_size.y)
	if longest_side <= 0.0:
		return Rect2()
	var target_size := visual_diameter * graphic_size_ratio
	var draw_size := texture_size * (target_size / longest_side)
	return Rect2(graphic_offset - draw_size * 0.5, draw_size)


func is_valid() -> bool:
	return collision_diameter > 0.0 and visual_diameter > 0.0
