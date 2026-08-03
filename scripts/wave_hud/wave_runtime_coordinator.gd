class_name WaveRuntimeCoordinator
extends "res://tests/flipper_system/test_flipper_board.gd"


const BOARD_LIMITS := Vector2(980.0, 560.0)


@export var stage_settings: ComboStageSettings
@export_range(0, 99, 1) var wave_index := 0
@export var initial_ball_types: Array[StringName] = [
	&"cat_eye",
	&"normal",
	&"industrial_steel",
]

@onready var hud_state: WaveHudStateSource = get_node_or_null(
	"WaveHudStateSource"
) as WaveHudStateSource
@onready var wave_hud: WaveHud = get_node_or_null("HUD/WaveHud") as WaveHud
@onready var combo_system: ComboSystem = get_node_or_null(
	"ComboSystem"
) as ComboSystem
@onready var combo_wave_controller: ComboWaveController = get_node_or_null(
	"ComboWaveController"
) as ComboWaveController
@onready var combo_anchor: Node2D = get_node_or_null(
	"Bumpers/BumperCenter"
) as Node2D

var _drain_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super()
	assert(is_instance_valid(hud_state), "Wave scene requires WaveHudStateSource.")
	assert(is_instance_valid(wave_hud), "Wave scene requires WaveHud.")
	assert(is_instance_valid(combo_system), "Wave scene requires ComboSystem.")
	assert(is_instance_valid(combo_wave_controller), \
		"Wave scene requires ComboWaveController.")
	wave_hud.bind_state_source(hud_state)
	wave_hud.settings_requested.connect(_toggle_pause)
	_setup_combo_runtime()
	hud_state.begin_batch()
	hud_state.configure_lives(initial_ball_types)
	hud_state.set_score(combo_system.total_score, combo_wave_controller.target_score)
	hud_state.end_batch()
	_update_combo_anchor()


func _process(_delta: float) -> void:
	super(_delta)
	_update_combo_anchor()


func _physics_process(_delta: float) -> void:
	if get_tree().paused or _drain_pending \
			or not is_instance_valid(ball) or ball.freeze:
		return
	var ball_position := ball.global_position
	if absf(ball_position.x) <= BOARD_LIMITS.x \
			and absf(ball_position.y) <= BOARD_LIMITS.y:
		return
	_drain_pending = true
	call_deferred(&"_handle_wave_ball_drained")


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	super(event)


## Debug repositioning does not consume a life. Only a board drain does.
func reset_ball() -> void:
	super()
	_drain_pending = false


func retry_wave() -> void:
	get_tree().paused = false
	hud_state.begin_batch()
	combo_wave_controller.on_wave_retried()
	hud_state.reset_lives()
	hud_state.reset_combo()
	hud_state.set_score(combo_system.total_score, combo_wave_controller.target_score)
	hud_state.set_paused(false)
	hud_state.end_batch()
	super.reset_ball()
	_drain_pending = false


func _setup_combo_runtime() -> void:
	combo_wave_controller.bind_combo_system(combo_system)
	combo_wave_controller.wave_configured.connect(_on_wave_configured)
	combo_system.combo_changed.connect(_on_combo_changed)
	combo_system.score_changed.connect(_on_score_changed)
	ball_launched.connect(_on_wave_ball_launched)
	_bind_bumper_hit_sources()
	var configured := combo_wave_controller.configure_wave(stage_settings, wave_index)
	assert(configured, "Wave scene requires valid ComboStageSettings.")


func _bind_bumper_hit_sources() -> void:
	var bumpers := get_node_or_null("Bumpers")
	if bumpers == null:
		return
	for bumper: Node in bumpers.get_children():
		var source := bumper.get_node_or_null("ComboHitSource") as ComboHitSource
		var detection_area := bumper.get_node_or_null("SpeedDetectionArea") as Area2D
		if source == null:
			continue
		combo_system.bind_hit_source(source)
		if detection_area == null:
			continue
		var entered := Callable(self, &"_on_bumper_body_entered").bind(source)
		var exited := Callable(self, &"_on_bumper_body_exited").bind(source)
		if not detection_area.body_entered.is_connected(entered):
			detection_area.body_entered.connect(entered)
		if not detection_area.body_exited.is_connected(exited):
			detection_area.body_exited.connect(exited)


func _on_bumper_body_entered(body: Node2D, source: ComboHitSource) -> void:
	if body == ball:
		source.register_contact(body.get_instance_id())


func _on_bumper_body_exited(body: Node2D, source: ComboHitSource) -> void:
	if body == ball:
		source.release_contact(body.get_instance_id())


func _on_wave_ball_launched() -> void:
	combo_wave_controller.on_ball_launched()


func _handle_wave_ball_drained() -> void:
	if not combo_wave_controller.ball_is_active:
		_drain_pending = false
		return
	var remaining_after_drain := maxi(hud_state.get_remaining_life_count() - 1, 0)
	hud_state.begin_batch()
	# Settlement emits score first; the slot transition joins the same snapshot batch.
	combo_wave_controller.on_ball_drained(remaining_after_drain)
	hud_state.consume_current_life()
	hud_state.end_batch()
	if remaining_after_drain > 0:
		super.reset_ball()
	_drain_pending = false


func _on_wave_configured(
	_stage_id: StringName,
	configured_wave_index: int,
	target_score: int
) -> void:
	hud_state.begin_batch()
	hud_state.set_wave_index(configured_wave_index)
	hud_state.set_score(combo_system.total_score, target_score)
	hud_state.end_batch()


func _on_combo_changed(combo_count: int, _tier: int, _time_remaining: float) -> void:
	hud_state.observe_combo(combo_count)


func _on_score_changed(total_score: int, _added_score: int) -> void:
	hud_state.set_score(total_score, combo_wave_controller.target_score)


func _update_combo_anchor() -> void:
	if not is_instance_valid(combo_anchor):
		hud_state.set_combo_anchor(Vector2.ZERO, false)
		return
	var viewport_position := combo_anchor.get_global_transform_with_canvas().origin
	hud_state.set_combo_anchor(viewport_position, true)


func _toggle_pause() -> void:
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	hud_state.set_paused(next_paused)
