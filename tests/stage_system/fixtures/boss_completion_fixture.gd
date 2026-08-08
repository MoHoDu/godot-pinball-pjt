extends Node


signal boss_defeated


func complete() -> void:
	boss_defeated.emit()
