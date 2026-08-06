@tool
class_name BumperPresentationSettings
extends Resource


enum VisualStyle {
	BUTTON,
	COTTON,
	SPRING_DOLL,
	DRUM,
	CANNON,
	STARLIGHT_BROOCH,
	GOLDEN_GEARS,
	CRESCENT_NEEDLE,
	FORGOTTEN_STAR_BELL,
}


## 범퍼를 에디터와 게임 화면에 그릴 기본 외형 종류입니다.
@export var visual_style: VisualStyle = VisualStyle.BUTTON:
	set(value):
		visual_style = value
		emit_changed()

## 범퍼 몸체 내부를 채우는 기본 색상입니다.
@export var fill_color := Color("d8c99b"):
	set(value):
		fill_color = value
		emit_changed()

## 범퍼 테두리와 밝은 장식에 사용하는 색상입니다.
@export var rim_color := Color("f4df8b"):
	set(value):
		rim_color = value
		emit_changed()

## 범퍼의 핵심 장식과 강조 부분에 사용하는 색상입니다.
@export var accent_color := Color("5baca4"):
	set(value):
		accent_color = value
		emit_changed()

## 저주, 손상, 어두운 세부 묘사에 사용하는 색상입니다.
@export var curse_color := Color("754b86"):
	set(value):
		curse_color = value
		emit_changed()

## 범퍼 외형 또는 HUD에 표시할 짧은 이름입니다.
@export var label: String = "Bumper":
	set(value):
		label = value
		emit_changed()
