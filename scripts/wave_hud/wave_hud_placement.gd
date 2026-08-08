class_name WaveHudPlacement
extends WaveHud


@export_category("HUD Readability")
@export_range(0.0, 1.0, 0.01) var panel_fill_opacity := 0.68
@export_range(0.0, 1.0, 0.01) var panel_shadow_opacity := 0.28

@onready var _coin_wallet_hud: PanelContainer = %CoinWalletHud

var _placement_mode := false


func _ready() -> void:
	super()
	_apply_panel_opacity()
	_apply_placement_visibility()


func set_placement_mode(enabled: bool) -> void:
	_placement_mode = enabled
	visible = true
	_apply_placement_visibility()


func is_placement_mode() -> bool:
	return _placement_mode


func _on_snapshot_changed(snapshot: Dictionary) -> void:
	super(snapshot)
	_apply_placement_visibility()


func _apply_placement_visibility() -> void:
	if not is_node_ready():
		return
	_life_hud.visible = not _placement_mode
	_score_hud.visible = not _placement_mode
	_combo_hud.visible = not _placement_mode
	_wave_label.visible = not _placement_mode
	_coin_wallet_hud.visible = not _placement_mode
	_stage_phase_overlay.visible = not _placement_mode and bool(
		_snapshot.get(&"stage_phase_placeholder_visible", false)
	)
	_settings_button.visible = true


func _apply_panel_opacity() -> void:
	_set_child_opacity(_life_hud, "PanelFill", panel_fill_opacity)
	_set_child_opacity(_life_hud, "PanelShadow", panel_shadow_opacity)
	_set_child_opacity(_score_hud, "PanelFill", panel_fill_opacity)
	_set_child_opacity(_score_hud, "PanelShadow", panel_shadow_opacity)
	_set_child_opacity(_settings_button, "ButtonFill", panel_fill_opacity)
	_set_child_opacity(_settings_button, "ButtonShadow", panel_shadow_opacity)

	var wallet_style := _coin_wallet_hud.get_theme_stylebox(&"panel")
	if wallet_style is StyleBoxFlat:
		var transparent_style := wallet_style.duplicate() as StyleBoxFlat
		transparent_style.bg_color.a = panel_fill_opacity
		transparent_style.shadow_color.a = panel_shadow_opacity
		_coin_wallet_hud.add_theme_stylebox_override(&"panel", transparent_style)


func _set_child_opacity(parent: Node, child_name: String, opacity: float) -> void:
	var child := parent.get_node_or_null(child_name) as CanvasItem
	if child != null:
		child.modulate.a = opacity
