class_name WaveHud
extends Control


signal settings_requested
signal advance_stage_phase_requested


const DESIGN_SIZE := Vector2(1920.0, 1080.0)

@onready var _design_space: Control = %DesignSpace
@onready var _life_hud: WaveLifeHud = %LifeHud
@onready var _score_hud: WaveScoreRepairHud = %ScoreRepairHud
@onready var _combo_hud: WaveWorldComboHud = %WorldComboHud
@onready var _settings_button: WaveSettingsButton = %SettingsButton
@onready var _wave_label: Label = %WaveLabel
@onready var _stage_phase_overlay: Control = %StagePhaseOverlay
@onready var _stage_phase_title: Label = %StagePhaseTitle
@onready var _stage_phase_button: Button = %StagePhaseButton

var _state_source: Node
var _snapshot: Dictionary = {}
var _design_scale := 1.0
var _design_offset := Vector2.ZERO
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_button.settings_requested.connect(
		func() -> void: settings_requested.emit()
	)
	_stage_phase_button.pressed.connect(
		func() -> void: advance_stage_phase_requested.emit()
	)
	_update_design_transform()


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size != _last_viewport_size:
		_update_design_transform()
	if not _snapshot.is_empty():
		_render_world_combo()


func bind_state_source(state_source: Node) -> bool:
	if state_source == null \
			or not state_source.has_signal(&"snapshot_changed") \
			or not state_source.has_method(&"get_snapshot"):
		return false
	unbind_state_source()
	_state_source = state_source
	_state_source.connect(&"snapshot_changed", _on_snapshot_changed)
	var initial_snapshot: Dictionary = _state_source.call(&"get_snapshot")
	_on_snapshot_changed(initial_snapshot)
	return true


func unbind_state_source() -> void:
	if not is_instance_valid(_state_source):
		_state_source = null
		return
	var callback := Callable(self, &"_on_snapshot_changed")
	if _state_source.is_connected(&"snapshot_changed", callback):
		_state_source.disconnect(&"snapshot_changed", callback)
	_state_source = null


func get_design_scale() -> float:
	return _design_scale


func get_design_offset() -> Vector2:
	return _design_offset


func is_stage_phase_placeholder_visible() -> bool:
	return _stage_phase_overlay.visible


func get_stage_phase_title_text() -> String:
	return _stage_phase_title.text


func get_stage_phase_button() -> Button:
	return _stage_phase_button


func _on_snapshot_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_life_hud.render(_snapshot)
	_score_hud.render(_snapshot)
	_settings_button.set_paused_state(bool(_snapshot.get(&"paused", false)))
	_wave_label.text = "WAVE %02d" % (int(_snapshot.get(&"wave_index", 0)) + 1)
	_stage_phase_title.text = String(_snapshot.get(&"stage_phase_title", ""))
	_stage_phase_button.text = String(
		_snapshot.get(&"stage_phase_button", "다음 단계")
	)
	_stage_phase_overlay.visible = bool(
		_snapshot.get(&"stage_phase_placeholder_visible", false)
	)
	_render_world_combo()


func _render_world_combo() -> void:
	var viewport_anchor: Vector2 = _snapshot.get(
		&"combo_anchor_viewport",
		Vector2.ZERO
	)
	var design_anchor := (viewport_anchor - _design_offset) / maxf(_design_scale, 0.001)
	_combo_hud.render(_snapshot, design_anchor)


func _update_design_transform() -> void:
	_last_viewport_size = get_viewport_rect().size
	_design_scale = minf(
		_last_viewport_size.x / DESIGN_SIZE.x,
		_last_viewport_size.y / DESIGN_SIZE.y
	)
	_design_offset = (_last_viewport_size - DESIGN_SIZE * _design_scale) * 0.5
	_design_space.position = _design_offset
	_design_space.scale = Vector2.ONE * _design_scale
