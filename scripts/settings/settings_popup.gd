class_name SettingsPopup
extends Control
## 게임 위에 표시되는 설정 팝업과 내부 화면 흐름을 관리합니다.


signal close_requested
signal game_exit_requested


enum Screen {
	SOUND,
	SFX_DETAIL,
	LICENSES,
	LICENSE_DETAIL,
}

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const CARD_POSITION := Vector2(500.0, 210.0)
const CARD_SIZE := Vector2(920.0, 660.0)
const OPEN_OFFSET_Y := 24.0
const OPEN_DURATION := 0.24
const CLOSE_DURATION := 0.16
const VOLUME_ROW_SCRIPT := preload(
	"res://scripts/settings/settings_volume_row.gd"
)
const BODY_FONT_SOURCE := preload(
	"res://Resources/ui/fonts/noto_sans_kr/NotoSansKR-wght.ttf"
)

const COLOR_DIM := Color(0.008, 0.015, 0.025, 0.66)
const COLOR_DEEP_NAVY := Color("071c24")
const COLOR_PANEL := Color("0b272f")
const COLOR_PANEL_ALT := Color("15333b")
const COLOR_MINT := Color("67d8d0")
const COLOR_IVORY := Color("f1e6cb")
const COLOR_MUTED := Color("829b99")
const COLOR_HIERARCHY := Color("a98245")
const COLOR_DANGER := Color("a349a4")

const LICENSE_ENTRIES := [
	{
		&"id": &"black_han_sans",
		&"title": "Black Han Sans",
		&"summary": "Regular · SIL Open Font License 1.1",
		&"path": "res://Resources/ui/fonts/black_han_sans/OFL.txt",
	},
	{
		&"id": &"noto_sans_kr",
		&"title": "Noto Sans KR",
		&"summary": "Variable · SIL Open Font License 1.1",
		&"path": "res://Resources/ui/fonts/noto_sans_kr/OFL.txt",
	},
	{
		&"id": &"black_and_white_picture",
		&"title": "Black And White Picture",
		&"summary": "Regular · SIL Open Font License 1.1",
		&"path": "res://Resources/fonts/black_and_white_picture/OFL.txt",
	},
	{
		&"id": &"godot_engine",
		&"title": "Godot Engine",
		&"summary": "Game engine · MIT License",
		&"path": "",
	},
]

const GODOT_LICENSE_TEXT := """Godot Engine

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- Godot Engine <https://godotengine.org>"""

var _settings_service: Node
var _body_font_regular: FontVariation
var _body_font_bold: FontVariation
var _screen := Screen.SOUND
var _dim: ColorRect
var _design_space: Control
var _card: PanelContainer
var _title_label: Label
var _sound_tab: Button
var _license_tab: Button
var _content_root: Control
var _sound_view: VBoxContainer
var _sfx_view: VBoxContainer
var _licenses_view: VBoxContainer
var _license_detail_view: VBoxContainer
var _license_detail_title: Label
var _license_detail_text: RichTextLabel
var _exit_overlay: Control
var _exit_cancel_button: Button
var _exit_tab: Button
var _focus_before_exit: Control
var _sfx_context_percent: Label
var _save_toast: Label
var _volume_rows: Dictionary = {}
var _active_tween: Tween
var _toast_tween: Tween
var _is_closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	_settings_service = get_node_or_null("/root/GameSettings")
	_body_font_regular = _make_body_font(500)
	_body_font_bold = _make_body_font(750)
	_build_interface()
	get_viewport().size_changed.connect(_fit_design_space)
	visible = false


func open_popup() -> void:
	if visible and not _is_closing:
		return
	_is_closing = false
	visible = true
	set_process_input(true)
	_show_screen(Screen.SOUND)
	_sync_volume_rows()
	_fit_design_space()
	_kill_active_tween()
	_dim.color.a = 0.0
	_card.position = CARD_POSITION + Vector2(0.0, OPEN_OFFSET_Y)
	_card.scale = Vector2.ONE * 0.98
	_card.modulate.a = 0.0
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_dim, "color:a", COLOR_DIM.a, OPEN_DURATION)
	_active_tween.tween_property(_card, "position:y", CARD_POSITION.y, OPEN_DURATION)
	_active_tween.tween_property(_card, "scale", Vector2.ONE, OPEN_DURATION)
	_active_tween.tween_property(_card, "modulate:a", 1.0, OPEN_DURATION)
	_sound_tab.grab_focus()


func close_popup() -> void:
	if not visible or _is_closing:
		return
	if _exit_overlay.visible:
		_hide_exit_confirmation()
		return
	if _screen == Screen.LICENSE_DETAIL:
		_show_screen(Screen.LICENSES)
		return
	if _screen == Screen.SFX_DETAIL:
		_show_screen(Screen.SOUND)
		return
	_animate_close()


func close_immediately() -> void:
	if not visible or _is_closing:
		return
	_exit_overlay.visible = false
	_animate_close()


func get_current_screen() -> int:
	return _screen


func is_exit_confirmation_visible() -> bool:
	return _exit_overlay.visible


func show_sfx_detail() -> void:
	_show_screen(Screen.SFX_DETAIL)


func show_licenses() -> void:
	_show_screen(Screen.LICENSES)


func show_license_detail(entry_id: StringName) -> void:
	for entry: Dictionary in LICENSE_ENTRIES:
		if entry[&"id"] == entry_id:
			_open_license_entry(entry)
			return


func show_exit_confirmation() -> void:
	_focus_before_exit = get_viewport().gui_get_focus_owner()
	_exit_overlay.visible = true
	_exit_cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_popup()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = COLOR_DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_design_space = Control.new()
	_design_space.name = "DesignSpace"
	_design_space.size = DESIGN_SIZE
	_design_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design_space)

	_card = PanelContainer.new()
	_card.name = "SettingsCard"
	_card.position = CARD_POSITION
	_card.size = CARD_SIZE
	_card.custom_minimum_size = CARD_SIZE
	_card.pivot_offset = CARD_SIZE * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override(&"panel", _panel_style())
	_design_space.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 42)
	margin.add_theme_constant_override(&"margin_top", 34)
	margin.add_theme_constant_override(&"margin_right", 42)
	margin.add_theme_constant_override(&"margin_bottom", 30)
	_card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 20)
	margin.add_child(layout)
	_build_header(layout)
	_build_tabs(layout)

	_content_root = Control.new()
	_content_root.name = "ContentRoot"
	_content_root.custom_minimum_size = Vector2(0.0, 456.0)
	_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_content_root)
	_build_sound_view()
	_build_sfx_view()
	_build_licenses_view()
	_build_license_detail_view()
	_build_save_toast()
	_build_exit_confirmation()


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	parent.add_child(header)

	_title_label = Label.new()
	_title_label.text = "설정"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_override(
		&"font",
		load("res://Resources/fonts/black_and_white_picture/BlackAndWhitePicture-Regular.ttf")
	)
	_title_label.add_theme_color_override(&"font_color", COLOR_IVORY)
	_title_label.add_theme_font_size_override(&"font_size", 36)
	header.add_child(_title_label)

	var close_button := _make_button("×", &"icon")
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(52.0, 48.0)
	close_button.pressed.connect(close_immediately)
	header.add_child(close_button)


func _build_tabs(parent: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 10)
	parent.add_child(tabs)

	_sound_tab = _make_button("사운드", &"tab")
	_sound_tab.name = "SoundTab"
	_sound_tab.pressed.connect(func() -> void: _show_screen(Screen.SOUND))
	tabs.add_child(_sound_tab)

	_license_tab = _make_button("라이선스", &"tab")
	_license_tab.name = "LicenseTab"
	_license_tab.pressed.connect(func() -> void: _show_screen(Screen.LICENSES))
	tabs.add_child(_license_tab)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)

	_exit_tab = _make_button("게임 종료", &"danger")
	_exit_tab.name = "ExitTab"
	_exit_tab.pressed.connect(show_exit_confirmation)
	tabs.add_child(_exit_tab)


func _build_sound_view() -> void:
	_sound_view = _new_view("SoundView")
	_sound_view.add_child(_section_heading("사운드 볼륨", ""))
	_add_volume_row(_sound_view, &"master", "마스터 사운드")
	_add_volume_row(_sound_view, &"bgm", "BGM")
	_add_volume_row(_sound_view, &"sfx", "SFX 전체")

	var detail_button := _make_button("세부 효과음 설정  ›", &"secondary")
	detail_button.name = "SfxDetailButton"
	detail_button.pressed.connect(func() -> void: _show_screen(Screen.SFX_DETAIL))
	_sound_view.add_child(detail_button)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 12)
	_sound_view.add_child(footer)
	var reset_button := _make_button("기본값으로 초기화", &"quiet")
	reset_button.pressed.connect(_reset_settings)
	footer.add_child(reset_button)
	var hint := _make_label("ESC  닫기", 15, COLOR_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)


func _build_sfx_view() -> void:
	_sfx_view = _new_view("SfxDetailView")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 12)
	_sfx_view.add_child(heading)
	var back_button := _make_button("‹", &"icon")
	back_button.name = "SfxBackButton"
	back_button.pressed.connect(func() -> void: _show_screen(Screen.SOUND))
	heading.add_child(back_button)
	var title := _section_heading("SFX 세부 설정", "각 효과음은 SFX 전체 볼륨의 영향을 함께 받습니다.")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)

	var context := HBoxContainer.new()
	context.add_theme_constant_override(&"separation", 12)
	_sfx_view.add_child(context)
	var context_label := _make_label("SFX 전체", 17, COLOR_IVORY)
	context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_child(context_label)
	_sfx_context_percent = _make_label("80%", 17, COLOR_MINT)
	_sfx_context_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	context.add_child(_sfx_context_percent)

	var hierarchy := HBoxContainer.new()
	hierarchy.add_theme_constant_override(&"separation", 16)
	_sfx_view.add_child(hierarchy)
	var hierarchy_line := ColorRect.new()
	hierarchy_line.custom_minimum_size = Vector2(2.0, 0.0)
	hierarchy_line.color = COLOR_HIERARCHY
	hierarchy_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hierarchy.add_child(hierarchy_line)
	var child_rows := VBoxContainer.new()
	child_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child_rows.add_theme_constant_override(&"separation", 4)
	hierarchy.add_child(child_rows)
	_add_volume_row(child_rows, &"ball", "공 사운드", true)
	_add_volume_row(child_rows, &"bumper", "범퍼 사운드", true)
	_add_volume_row(child_rows, &"flipper", "플리퍼 사운드", true)
	_add_volume_row(child_rows, &"wall", "벽 충돌 사운드", true)


func _build_licenses_view() -> void:
	_licenses_view = _new_view("LicensesView")
	_licenses_view.add_child(_section_heading("라이선스", ""))
	for entry: Dictionary in LICENSE_ENTRIES:
		_licenses_view.add_child(_make_license_row(entry))


func _build_license_detail_view() -> void:
	_license_detail_view = _new_view("LicenseDetailView")
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override(&"separation", 14)
	_license_detail_view.add_child(heading)
	var back_button := _make_button("‹  라이선스 목록", &"secondary")
	back_button.name = "LicenseBackButton"
	back_button.custom_minimum_size = Vector2(210.0, 48.0)
	back_button.pressed.connect(func() -> void: _show_screen(Screen.LICENSES))
	heading.add_child(back_button)
	_license_detail_title = _make_label("라이선스 상세", 28, COLOR_IVORY)
	_license_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_license_detail_title)

	_license_detail_text = RichTextLabel.new()
	_license_detail_text.name = "LicenseText"
	_license_detail_text.custom_minimum_size = Vector2(0.0, 376.0)
	_license_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_license_detail_text.fit_content = false
	_license_detail_text.scroll_active = true
	_license_detail_text.bbcode_enabled = false
	_license_detail_text.add_theme_color_override(&"default_color", COLOR_MUTED)
	_license_detail_text.add_theme_font_override(
		&"normal_font",
		_body_font_regular
	)
	_license_detail_text.add_theme_font_size_override(&"normal_font_size", 16)
	_license_detail_view.add_child(_license_detail_text)


func _build_save_toast() -> void:
	_save_toast = _make_label("설정이 저장되었습니다", 15, COLOR_IVORY)
	_save_toast.name = "SaveToast"
	_save_toast.position = CARD_POSITION + Vector2(640.0, 598.0)
	_save_toast.size = Vector2(230.0, 38.0)
	_save_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_toast.add_theme_stylebox_override(
		&"normal",
		_button_style(COLOR_DEEP_NAVY, COLOR_MINT, 1.0)
	)
	_save_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_toast.visible = false
	_design_space.add_child(_save_toast)


func _build_exit_confirmation() -> void:
	_exit_overlay = Control.new()
	_exit_overlay.name = "ExitConfirmation"
	_exit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_overlay.visible = false
	_design_space.add_child(_exit_overlay)

	var confirmation_dim := ColorRect.new()
	confirmation_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation_dim.color = Color(0.005, 0.008, 0.014, 0.72)
	confirmation_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_overlay.add_child(confirmation_dim)

	var dialog := PanelContainer.new()
	dialog.position = Vector2(700.0, 400.0)
	dialog.size = Vector2(520.0, 280.0)
	dialog.custom_minimum_size = dialog.size
	dialog.add_theme_stylebox_override(
		&"panel",
		_panel_style(COLOR_PANEL, COLOR_IVORY, 12, Color("020b0fcc"))
	)
	_exit_overlay.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 42)
	margin.add_theme_constant_override(&"margin_top", 34)
	margin.add_theme_constant_override(&"margin_right", 42)
	margin.add_theme_constant_override(&"margin_bottom", 34)
	dialog.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(&"separation", 22)
	margin.add_child(content)
	var title := _make_label("게임을 종료하시겠습니까?", 30, COLOR_IVORY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var body := _make_label("저장된 설정은 유지됩니다.", 17, COLOR_MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 12)
	content.add_child(actions)
	_exit_cancel_button = _make_button("취소", &"secondary")
	_exit_cancel_button.name = "ExitCancelButton"
	_exit_cancel_button.pressed.connect(_hide_exit_confirmation)
	actions.add_child(_exit_cancel_button)
	var confirm := _make_button("게임 종료", &"danger")
	confirm.name = "ExitConfirmButton"
	confirm.pressed.connect(func() -> void: game_exit_requested.emit())
	actions.add_child(confirm)


func _new_view(node_name: String) -> VBoxContainer:
	var view := VBoxContainer.new()
	view.name = node_name
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_theme_constant_override(&"separation", 12)
	_content_root.add_child(view)
	return view


func _make_license_row(entry: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "%sLicenseRow" % String(entry[&"id"]).to_pascal_case()
	row.custom_minimum_size = Vector2(0.0, 80.0)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_ALT
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	row.add_theme_stylebox_override(&"panel", style)

	var content := HBoxContainer.new()
	content.add_theme_constant_override(&"separation", 16)
	row.add_child(content)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override(&"separation", 2)
	content.add_child(labels)
	var name_label := _make_label(String(entry[&"title"]), 17, COLOR_IVORY)
	name_label.add_theme_font_override(
		&"font",
		load("res://Resources/ui/fonts/black_han_sans/BlackHanSans-Regular.ttf")
	)
	labels.add_child(name_label)
	labels.add_child(_make_label(String(entry[&"summary"]), 13, COLOR_MUTED))
	var action := _make_button("전문 보기", &"secondary")
	action.name = "%sLicenseButton" % String(entry[&"id"]).to_pascal_case()
	action.custom_minimum_size = Vector2(132.0, 42.0)
	action.pressed.connect(_open_license_entry.bind(entry))
	content.add_child(action)
	return row


func _add_volume_row(
	parent: VBoxContainer,
	category: StringName,
	title: String,
	is_child := false
) -> void:
	var row: Variant = VOLUME_ROW_SCRIPT.new()
	row.name = "%sVolumeRow" % String(category).to_pascal_case()
	row.configure(category, title, _get_volume(category), is_child)
	row.volume_edited.connect(_on_volume_edited)
	parent.add_child(row)
	_volume_rows[category] = row


func _show_screen(next_screen: int) -> void:
	_screen = next_screen
	_sound_view.visible = next_screen == Screen.SOUND
	_sfx_view.visible = next_screen == Screen.SFX_DETAIL
	_licenses_view.visible = next_screen == Screen.LICENSES
	_license_detail_view.visible = next_screen == Screen.LICENSE_DETAIL
	_sound_tab.button_pressed = next_screen in [Screen.SOUND, Screen.SFX_DETAIL]
	_license_tab.button_pressed = next_screen in [Screen.LICENSES, Screen.LICENSE_DETAIL]
	_title_label.text = "설정"
	_sync_volume_rows()


func _open_license_entry(entry: Dictionary) -> void:
	_license_detail_title.text = String(entry[&"title"])
	var path := String(entry[&"path"])
	if path.is_empty():
		_license_detail_text.text = GODOT_LICENSE_TEXT
	elif FileAccess.file_exists(path):
		_license_detail_text.text = FileAccess.get_file_as_string(path)
	else:
		_license_detail_text.text = "라이선스 문서를 불러올 수 없습니다."
	_license_detail_text.scroll_to_line(0)
	_show_screen(Screen.LICENSE_DETAIL)


func _on_volume_edited(category: StringName, value: float) -> void:
	if is_instance_valid(_settings_service) \
			and _settings_service.has_method(&"set_volume"):
		_settings_service.call(&"set_volume", category, value)
	_show_save_toast()


func _sync_volume_rows() -> void:
	for category: StringName in _volume_rows:
		var row: Variant = _volume_rows[category]
		row.set_volume(_get_volume(category))
	if is_instance_valid(_sfx_context_percent):
		_sfx_context_percent.text = "%d%%" % roundi(_get_volume(&"sfx") * 100.0)


func _get_volume(category: StringName) -> float:
	if is_instance_valid(_settings_service) \
			and _settings_service.has_method(&"get_volume"):
		return float(_settings_service.call(&"get_volume", category))
	return 1.0


func _reset_settings() -> void:
	if is_instance_valid(_settings_service) \
			and _settings_service.has_method(&"reset_to_defaults"):
		_settings_service.call(&"reset_to_defaults")
	_sync_volume_rows()
	_show_save_toast()


func _show_save_toast() -> void:
	if not is_instance_valid(_save_toast):
		return
	if is_instance_valid(_toast_tween) and _toast_tween.is_running():
		_toast_tween.kill()
	_save_toast.visible = true
	_save_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(0.7)
	_toast_tween.tween_property(_save_toast, "modulate:a", 0.0, 0.18)
	_toast_tween.tween_callback(func() -> void: _save_toast.visible = false)


func _hide_exit_confirmation() -> void:
	_exit_overlay.visible = false
	if is_instance_valid(_focus_before_exit):
		_focus_before_exit.grab_focus()
	else:
		_exit_tab.grab_focus()
	_focus_before_exit = null


func _animate_close() -> void:
	_is_closing = true
	_kill_active_tween()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_dim, "color:a", 0.0, CLOSE_DURATION)
	_active_tween.tween_property(
		_card,
		"position:y",
		CARD_POSITION.y + OPEN_OFFSET_Y,
		CLOSE_DURATION
	)
	_active_tween.tween_property(_card, "scale", Vector2.ONE * 0.98, CLOSE_DURATION)
	_active_tween.tween_property(_card, "modulate:a", 0.0, CLOSE_DURATION)
	_active_tween.chain().tween_callback(_complete_close)


func _complete_close() -> void:
	visible = false
	set_process_input(false)
	_is_closing = false
	close_requested.emit()


func _kill_active_tween() -> void:
	if is_instance_valid(_active_tween) and _active_tween.is_running():
		_active_tween.kill()


func _fit_design_space() -> void:
	var viewport_size := get_viewport_rect().size
	var fit_scale := minf(
		viewport_size.x / (CARD_SIZE.x + 80.0),
		viewport_size.y / (CARD_SIZE.y + 80.0)
	)
	fit_scale = clampf(fit_scale, 0.01, 1.0)
	_design_space.scale = Vector2.ONE * fit_scale
	_design_space.position = (viewport_size - DESIGN_SIZE * fit_scale) * 0.5


func _section_heading(title: String, subtitle: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override(&"separation", 2)
	section.add_child(_make_label(title, 26, COLOR_IVORY))
	if not subtitle.is_empty():
		section.add_child(_make_label(subtitle, 15, COLOR_MUTED))
	return section


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override(
		&"font",
		_body_font_regular
	)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text_value: String, role: StringName) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override(
		&"font",
		_body_font_bold
	)
	button.add_theme_font_size_override(&"font_size", 18)
	button.add_theme_color_override(&"font_color", COLOR_IVORY)
	button.add_theme_color_override(&"font_hover_color", COLOR_IVORY)
	button.add_theme_color_override(&"font_focus_color", COLOR_IVORY)
	button.add_theme_color_override(&"font_pressed_color", COLOR_DEEP_NAVY)
	var accent := COLOR_MINT
	var background := COLOR_PANEL_ALT
	match role:
		&"icon":
			button.custom_minimum_size = Vector2(52.0, 48.0)
			button.add_theme_font_size_override(&"font_size", 30)
		&"tab":
			button.custom_minimum_size = Vector2(150.0, 48.0)
			button.toggle_mode = true
		&"danger":
			button.custom_minimum_size = Vector2(150.0, 48.0)
			accent = COLOR_DANGER
			background = COLOR_DANGER
		&"secondary":
			button.custom_minimum_size = Vector2(230.0, 50.0)
		&"quiet":
			button.custom_minimum_size = Vector2(190.0, 42.0)
			accent = COLOR_MUTED
			background = COLOR_DEEP_NAVY
		&"license":
			button.custom_minimum_size = Vector2(0.0, 76.0)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override(&"font_size", 17)
	button.add_theme_stylebox_override(&"normal", _button_style(background, COLOR_IVORY, 1.0))
	button.add_theme_stylebox_override(&"hover", _button_style(background.lightened(0.08), COLOR_MINT, 1.0))
	button.add_theme_stylebox_override(
		&"focus",
		_button_style(Color.TRANSPARENT, COLOR_MINT, 1.0)
	)
	button.add_theme_stylebox_override(&"pressed", _button_style(accent, COLOR_MINT, 1.0))
	return button


func _panel_style(
	background: Color = COLOR_PANEL,
	border: Color = COLOR_IVORY,
	shadow_y := 14,
	shadow_color := Color("020b0fa6")
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 11
	style.corner_radius_bottom_left = 5
	style.shadow_color = shadow_color
	style.shadow_size = 0
	style.shadow_offset = Vector2(0.0, float(shadow_y))
	return style


func _button_style(
	background: Color,
	border: Color,
	border_alpha: float
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(border, border_alpha)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_body_font(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = BODY_FONT_SOURCE
	var text_server := TextServerManager.get_primary_interface()
	font.variation_opentype = {text_server.name_to_tag("wght"): weight}
	return font
