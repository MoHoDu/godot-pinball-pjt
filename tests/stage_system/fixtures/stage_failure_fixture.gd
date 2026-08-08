extends Node


signal stage_segment_completed
signal wave_lost(current_score: int, target_score: int)


func complete() -> void:
	stage_segment_completed.emit()


func fail() -> void:
	wave_lost.emit(0, 100)
