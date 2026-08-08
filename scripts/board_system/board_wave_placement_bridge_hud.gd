class_name BoardWavePlacementBridgeHud
extends BoardWavePlacementBridge


func _set_hud_visibility(is_placement: bool) -> void:
	if wave_hud != null:
		wave_hud.visible = true
		if wave_hud.has_method(&"set_placement_mode"):
			wave_hud.call(&"set_placement_mode", is_placement)
	if is_placement and ball_selection_hud != null:
		ball_selection_hud.visible = false
	if placement_hud != null:
		placement_hud.set_placement_visible(is_placement)
