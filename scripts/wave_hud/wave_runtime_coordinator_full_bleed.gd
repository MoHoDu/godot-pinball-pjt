class_name WaveRuntimeCoordinatorFullBleed
extends WaveRuntimeCoordinator


const SETTINGS_POPUP_SFX_PREVIEW_SCENE := preload(
	"res://Resources/Prefabs/ui/settings/settings_popup_sfx_preview.tscn"
)


@export_category("Full Bleed Board")
@export_range(0.5, 2.0, 0.01) var minimum_full_bleed_aspect := 1.45


func _fit_board_camera(force := false) -> void:
	if not is_instance_valid(board_camera) or not is_instance_valid(wave_hud):
		return
	var viewport_size := get_viewport_rect().size
	if not force and viewport_size.is_equal_approx(_camera_viewport_size):
		return
	_camera_viewport_size = viewport_size

	if viewport_size.y <= 0.0 \
			or viewport_size.x / viewport_size.y < minimum_full_bleed_aspect:
		super(force)
		return

	var fitted_zoom := maxf(
		viewport_size.x / maxf(board_world_bounds.size.x, 1.0),
		viewport_size.y / maxf(board_world_bounds.size.y, 1.0)
	)
	fitted_zoom = maxf(fitted_zoom, 0.01)
	board_camera.zoom = Vector2.ONE * fitted_zoom
	board_camera.position = board_world_bounds.get_center()


func _setup_settings_popup() -> void:
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsOverlay"
	_settings_layer.layer = 100
	_settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings_layer)

	_settings_popup = SETTINGS_POPUP_SFX_PREVIEW_SCENE.instantiate()
	_settings_layer.add_child(_settings_popup)
	_settings_popup.close_requested.connect(_on_settings_closed)
	_settings_popup.game_exit_requested.connect(_on_game_exit_requested)
