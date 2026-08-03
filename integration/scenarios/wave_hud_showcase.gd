extends WaveRuntimeCoordinator


func _ready() -> void:
	super()
	call_deferred(&"_populate_showcase")


func _populate_showcase() -> void:
	combo_system.stage_base_score = 1000
	wave_ball_flow.confirm_selection()
	launcher.launch_prepared_ball()
	var source := get_node("Bumpers/BumperCenter/ComboHitSource") as ComboHitSource
	for contact_id in range(1, 19):
		source.register_contact(contact_id)
		source.release_contact(contact_id)
	combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_handle_ball_drained("HUD showcase")
	wave_ball_flow.confirm_selection()
	launcher.launch_prepared_ball()
	for contact_id in range(101, 109):
		source.register_contact(contact_id)
		source.release_contact(contact_id)
