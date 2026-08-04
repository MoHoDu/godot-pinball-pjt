@tool
class_name BumperPresentationSettings
extends Resource


enum VisualStyle {
	BUTTON,
	COTTON,
	SPRING_DOLL,
	DRUM,
	CANNON,
	REPAIR_PART,
}


@export var visual_style: VisualStyle = VisualStyle.BUTTON:
	set(value):
		visual_style = value
		emit_changed()

@export var fill_color := Color("d8c99b"):
	set(value):
		fill_color = value
		emit_changed()

@export var rim_color := Color("f4df8b"):
	set(value):
		rim_color = value
		emit_changed()

@export var accent_color := Color("5baca4"):
	set(value):
		accent_color = value
		emit_changed()

@export var curse_color := Color("754b86"):
	set(value):
		curse_color = value
		emit_changed()

@export var label: String = "Bumper":
	set(value):
		label = value
		emit_changed()

