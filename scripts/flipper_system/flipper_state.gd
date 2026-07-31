class_name FlipperState
extends RefCounted


enum Type {
	IDLE,
	ACTIVE,
	HOLD,
	RETURNING,
	COOLDOWN,
}


var type: Type
var elapsed_time: float = 0.0


func _init(p_type: Type) -> void:
	type = p_type


func enter() -> void:
	elapsed_time = 0.0


func advance(delta: float) -> void:
	elapsed_time += maxf(delta, 0.0)
