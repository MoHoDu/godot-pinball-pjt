class_name Stage1TeddyBossScene
extends WaveRuntimeCoordinator


func _enter_initial_stage(
	stage_settings: Resource,
	_start_wave_index: int
) -> bool:
	return wave_manager.enter_boss_stage(stage_settings)
