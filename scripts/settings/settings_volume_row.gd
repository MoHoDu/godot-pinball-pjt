class_name SettingsVolumeRow
extends VBoxContainer
## 설정 팝업에서 공통으로 쓰는 음량 슬라이더 행입니다.


signal volume_edited(category: StringName, linear_volume: float)


const COLOR_TEXT := Color("f1e6cb")
const COLOR_MINT := Color("67d8d0")
const COLOR_MUTED := Color("829b99")
const COLOR_DEEP_NAVY := Color("071c24")
const KNOB_TEXTURE := preload("res://Resources/ui/settings/slider_knob.svg")

var category: StringName = &"master"
var _title_label: Label
var _percent_label: Label
var _slider: HSlider
var _syncing := false


func _ready() -> void:
	if _slider == null:
		_build()


func configure(
	category_value: StringName,
	title: String,
	initial_volume: float,
	is_child := false
) -> void:
	category = category_value
	if _slider == null:
		_build()
	_title_label.text = title
	_title_label.add_theme_font_size_override(&"font_size", 15 if is_child else 17)
	_title_label.add_theme_color_override(
		&"font_color",
		COLOR_MUTED if is_child else COLOR_TEXT
	)
	set_volume(initial_volume)


func set_volume(linear_volume: float) -> void:
	if _slider == null:
		_build()
	_syncing = true
	_slider.value = clampf(linear_volume, 0.0, 1.0)
	_update_percent()
	_syncing = false


func get_slider() -> HSlider:
	return _slider


func _build() -> void:
	custom_minimum_size = Vector2(0.0, 68.0)
	add_theme_constant_override(&"separation", 8)

	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override(&"font_color", COLOR_TEXT)
	_title_label.add_theme_font_size_override(&"font_size", 17)
	heading.add_child(_title_label)

	_percent_label = Label.new()
	_percent_label.custom_minimum_size.x = 74.0
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent_label.add_theme_color_override(&"font_color", COLOR_MINT)
	_percent_label.add_theme_font_size_override(&"font_size", 20)
	heading.add_child(_percent_label)

	_slider = HSlider.new()
	_slider.name = "VolumeSlider"
	_slider.unique_name_in_owner = true
	_slider.custom_minimum_size.y = 24.0
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slider.add_theme_stylebox_override(&"slider", _track_style(COLOR_DEEP_NAVY, COLOR_MUTED))
	_slider.add_theme_stylebox_override(&"grabber_area", _track_style(COLOR_MINT, COLOR_MINT))
	_slider.add_theme_stylebox_override(
		&"grabber_area_highlight",
		_track_style(COLOR_MINT, COLOR_MINT)
	)
	_slider.add_theme_stylebox_override(&"focus", _focus_style())
	_slider.add_theme_icon_override(&"grabber", KNOB_TEXTURE)
	_slider.add_theme_icon_override(&"grabber_highlight", KNOB_TEXTURE)
	_slider.value_changed.connect(_on_value_changed)
	add_child(_slider)

func _on_value_changed(value: float) -> void:
	_update_percent()
	if not _syncing:
		volume_edited.emit(category, value)


func _update_percent() -> void:
	_percent_label.text = "%d%%" % roundi(_slider.value * 100.0)
	var muted := is_zero_approx(_slider.value)
	_percent_label.add_theme_color_override(
		&"font_color",
		COLOR_MUTED if muted else COLOR_MINT
	)
	var active_color := COLOR_MUTED if muted else COLOR_MINT
	_slider.add_theme_stylebox_override(
		&"grabber_area",
		_track_style(active_color, active_color)
	)
	_slider.add_theme_stylebox_override(
		&"grabber_area_highlight",
		_track_style(active_color, active_color)
	)


func _track_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 2
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_MINT
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 4
	style.expand_margin_top = 3.0
	style.expand_margin_bottom = 3.0
	return style
