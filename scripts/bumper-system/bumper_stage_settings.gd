@tool
class_name BumperStageSettings
extends Resource


@export var stage_id: StringName = &"stage"
@export var waves: Array[Resource] = []


func is_valid() -> bool:
	if stage_id.is_empty() or waves.is_empty():
		return false
	var ids: Dictionary = {}
	for wave: Resource in waves:
		if (
			wave == null
			or not wave.has_method(&"is_valid")
			or not bool(wave.call(&"is_valid"))
			or ids.has(wave.get(&"wave_id"))
		):
			return false
		ids[wave.get(&"wave_id")] = true
	return true


func get_wave(index: int) -> Resource:
	if index < 0 or index >= waves.size():
		return null
	return waves[index]
