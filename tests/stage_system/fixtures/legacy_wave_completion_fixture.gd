extends Node


signal wave_won(current_score: int, target_score: int)


func complete() -> void:
	wave_won.emit(100, 100)
