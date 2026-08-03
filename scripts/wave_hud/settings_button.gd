class_name WaveSettingsButton
extends Button


signal settings_requested


@onready var _border: TextureRect = %ButtonBorder


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func set_paused_state(is_paused: bool) -> void:
	_border.modulate = Color("67d8d0") if is_paused else Color.WHITE


func _on_pressed() -> void:
	settings_requested.emit()


func _on_mouse_entered() -> void:
	modulate = Color(1.1, 1.1, 1.1, 1.0)
	scale = Vector2(1.04, 1.04)
	pivot_offset = size * 0.5


func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE


func _on_button_down() -> void:
	scale = Vector2(0.96, 0.96)
	pivot_offset = size * 0.5


func _on_button_up() -> void:
	scale = Vector2(1.04, 1.04) if is_hovered() else Vector2.ONE
