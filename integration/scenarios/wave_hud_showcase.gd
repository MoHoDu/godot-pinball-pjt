extends WaveRuntimeCoordinator


func _ready() -> void:
	super()
	call_deferred(&"_populate_showcase")


func _populate_showcase() -> void:
	combo_system.stage_base_score = 1000
	var source := get_node("Bumpers/BumperCenter/ComboHitSource") as ComboHitSource
	for contact_id in range(1, 19):
		source.register_contact(contact_id)
		source.release_contact(contact_id)
	combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	call(&"_on_wave_ball_launched")
	call(&"_handle_wave_ball_drained")
	for contact_id in range(101, 109):
		source.register_contact(contact_id)
		source.release_contact(contact_id)
