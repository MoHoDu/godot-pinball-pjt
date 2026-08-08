extends Node


signal stage_segment_completed


func complete() -> void:
	stage_segment_completed.emit()


func complete_twice() -> void:
	stage_segment_completed.emit()
	stage_segment_completed.emit()
