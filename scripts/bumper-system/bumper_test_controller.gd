class_name BumperTestController
extends Node2D


enum TestState {
	SELECTING,
	RUNNING,
	FINISHED,
}


@export_category("Test Catalog")
## Inspector에서 테스트할 범퍼 프리팹을 원하는 순서로 등록합니다.
@export var bumper_scenes: Array[PackedScene] = []
@export var ball_scene: PackedScene

@export_category("Test Placement")
@export var bumper_slot_path: NodePath = ^"TestRig/BumperSlot"
@export var ball_root_path: NodePath = ^"TestRig/Balls"
@export_range(80.0, 500.0, 1.0, "suffix:px") var drop_height := 230.0
@export_range(16.0, 256.0, 1.0, "suffix:px") var ball_diameter := 44.0
@export_range(0.0, 5.0, 0.05, "suffix:x") var ball_gravity_scale := 1.0
@export_range(0.0, 5000.0, 1.0, "suffix:px/s") var initial_drop_speed := 0.0
@export var test_bounds := Rect2(80.0, 80.0, 992.0, 520.0)

@export_category("HUD")
@export var selection_label_path: NodePath = ^"HUD/TopBar/SelectionLabel"
@export var state_label_path: NodePath = ^"HUD/StatusPanel/Margin/StatusLabel"
@export var event_label_path: NodePath = ^"HUD/EventPanel/Margin/EventLabel"


@onready var bumper_slot: Node2D = get_node_or_null(bumper_slot_path) as Node2D
@onready var ball_root: Node2D = get_node_or_null(ball_root_path) as Node2D
@onready var selection_label: Label = get_node_or_null(selection_label_path) as Label
@onready var state_label: Label = get_node_or_null(state_label_path) as Label
@onready var event_label: Label = get_node_or_null(event_label_path) as Label


var current_index := 0
var current_state := TestState.SELECTING
var current_bumper: Bumper
var current_ball: Pinball
var hit_count := 0
var restart_count := 0
var last_incoming_speed := 0.0
var last_outgoing_speed := 0.0
var _event_lines: Array[String] = []


func _ready() -> void:
	_prepare_selected_bumper()
	_refresh_hud()
	queue_redraw()


func _process(_delta: float) -> void:
	if current_state == TestState.RUNNING and is_instance_valid(current_ball):
		if not test_bounds.has_point(current_ball.global_position):
			current_state = TestState.FINISHED
			_append_event("END · 공이 테스트 영역을 벗어났습니다")
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if handle_key_input(key_event):
		get_viewport().set_input_as_handled()


## 실제 입력과 자동 테스트가 동일한 키 라우팅 규칙을 사용합니다.
func handle_key_input(key_event: InputEventKey) -> bool:
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if key_event.physical_keycode == KEY_R:
		return restart_test()
	if _is_previous_key(key_event):
		if _is_cannon_choosing_direction():
			return false
		return select_previous()
	if _is_next_key(key_event):
		if _is_cannon_choosing_direction():
			return false
		return select_next()
	if current_state == TestState.SELECTING \
			and key_event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return start_test()
	return false


func select_previous() -> bool:
	if bumper_scenes.is_empty():
		return false
	current_index = wrapi(current_index - 1, 0, bumper_scenes.size())
	restart_count = 0
	_prepare_selected_bumper()
	return true


func select_next() -> bool:
	if bumper_scenes.is_empty():
		return false
	current_index = wrapi(current_index + 1, 0, bumper_scenes.size())
	restart_count = 0
	_prepare_selected_bumper()
	return true


func start_test() -> bool:
	if (
		current_state != TestState.SELECTING
		or not is_instance_valid(current_bumper)
		or ball_scene == null
		or ball_root == null
	):
		return false

	_clear_ball()
	var instance := ball_scene.instantiate()
	if not instance is Pinball:
		if instance != null:
			instance.free()
		push_warning("Bumper Test의 Ball Scene 루트는 Pinball이어야 합니다.")
		return false

	current_ball = instance as Pinball
	ball_root.add_child(current_ball)
	current_ball.ball_diameter = ball_diameter
	current_ball.stats = current_ball.stats.duplicate(true) as PinballStats
	current_ball.stats.gravity_scale = ball_gravity_scale
	current_ball.stats.minimum_speed = 0.0
	current_ball.stats.maximum_speed = maxf(
		current_ball.stats.maximum_speed,
		current_bumper.get_maximum_response_speed()
	)
	current_ball.global_position = (
		current_bumper.global_position + Vector2.UP * drop_height
	)
	current_ball.linear_velocity = Vector2.DOWN * initial_drop_speed
	current_state = TestState.RUNNING
	_append_event("START · 공 낙하")
	return true


func restart_test() -> bool:
	if bumper_scenes.is_empty():
		return false
	restart_count += 1
	_prepare_selected_bumper()
	return start_test()


func get_selected_scene() -> PackedScene:
	if bumper_scenes.is_empty():
		return null
	current_index = clampi(current_index, 0, bumper_scenes.size() - 1)
	return bumper_scenes[current_index]


func get_selected_display_name() -> String:
	if is_instance_valid(current_bumper) and current_bumper.settings != null:
		return current_bumper.settings.display_name
	var selected_scene := get_selected_scene()
	if selected_scene == null:
		return "등록된 범퍼 없음"
	return selected_scene.resource_path.get_file().get_basename()


func _prepare_selected_bumper() -> void:
	_clear_ball()
	_clear_bumper()
	hit_count = 0
	last_incoming_speed = 0.0
	last_outgoing_speed = 0.0
	current_state = TestState.SELECTING

	var selected_scene := get_selected_scene()
	if selected_scene == null or bumper_slot == null:
		_append_event("ERROR · Inspector의 Bumper Scenes를 확인하세요")
		return
	var instance := selected_scene.instantiate()
	if not instance is Bumper:
		if instance != null:
			instance.free()
		push_warning("Bumper Scenes 항목의 루트는 Bumper여야 합니다.")
		_append_event("ERROR · Bumper가 아닌 Scene")
		return

	current_bumper = instance as Bumper
	bumper_slot.add_child(current_bumper)
	current_bumper.position = Vector2.ZERO
	current_bumper.bumper_id = &"bumper_lab_subject"
	current_bumper.valid_hit_registered.connect(_on_valid_hit_registered)
	current_bumper.state_changed.connect(_on_bumper_state_changed)
	current_bumper.response_resolved.connect(_on_response_resolved)
	if current_bumper is ShotBumper:
		var shot := current_bumper as ShotBumper
		shot.control_started.connect(_on_shot_control_started)
		shot.selection_changed.connect(_on_shot_selection_changed)
		shot.control_ended.connect(_on_shot_control_ended)
	_append_event("SELECT · %s" % get_selected_display_name())
	queue_redraw()


func _clear_bumper() -> void:
	if is_instance_valid(current_bumper):
		current_bumper.free()
	current_bumper = null


func _clear_ball() -> void:
	if is_instance_valid(current_ball):
		if current_bumper is ShotBumper:
			(current_bumper as ShotBumper).reset_for_new_ball()
		current_ball.free()
	current_ball = null


func _on_valid_hit_registered(
	_bumper_id: StringName,
	ball: RigidBody2D,
	_contact_id: int,
	base_score: int
) -> void:
	hit_count += 1
	last_incoming_speed = ball.linear_velocity.length()
	_append_event("HIT %d · score %d · in %.0f" % [
		hit_count,
		base_score,
		last_incoming_speed,
	])


func _on_response_resolved(
	_bumper: Bumper,
	ball: RigidBody2D,
	_response: BumperResponse
) -> void:
	last_outgoing_speed = ball.linear_velocity.length()
	_append_event("RESPONSE · out %.0f px/s" % last_outgoing_speed)


func _on_bumper_state_changed(
	_previous: Bumper.BumperState,
	current: Bumper.BumperState
) -> void:
	_append_event("STATE · %s" % Bumper.BumperState.keys()[current])


func _on_shot_control_started(
	_bumper: ShotBumper,
	_ball: RigidBody2D
) -> void:
	_append_event("SHOT · W/A/D 방향 · Space 발사")


func _on_shot_selection_changed(
	_bumper: ShotBumper,
	anchor: ShotLaunchAnchor
) -> void:
	_append_event("SHOT SELECT · %s" % anchor.name)


func _on_shot_control_ended(
	_bumper: ShotBumper,
	_ball: RigidBody2D
) -> void:
	_append_event("SHOT · 안전 이탈 완료")


func _append_event(message: String) -> void:
	_event_lines.push_front(message)
	if _event_lines.size() > 6:
		_event_lines.resize(6)
	_refresh_hud()


func _refresh_hud() -> void:
	if is_instance_valid(selection_label):
		var count := bumper_scenes.size()
		selection_label.text = "<  %02d / %02d   %s  >" % [
			current_index + 1 if count > 0 else 0,
			count,
			get_selected_display_name(),
		]

	if is_instance_valid(state_label):
		state_label.text = _build_status_text()
	if is_instance_valid(event_label):
		event_label.text = "EVENT LOG\n\n%s" % "\n".join(_event_lines)


func _build_status_text() -> String:
	if not is_instance_valid(current_bumper) or current_bumper.settings == null:
		return "범퍼 프리팹을 Inspector 목록에 등록하세요."
	var state_name: String = str(TestState.keys()[current_state])
	var bumper_state: String = str(
		Bumper.BumperState.keys()[current_bumper.state]
	)
	var ball_speed := (
		current_ball.linear_velocity.length()
		if is_instance_valid(current_ball)
		else 0.0
	)
	var repair_part_status := (
		"YES · reward / own / place"
		if current_bumper.is_repair_part()
		else "NO · stage only"
	)
	return (
		"TEST  %s\n"
		+ "TYPE  %s\n"
		+ "REPAIR PART  %s\n\n"
		+ "score              %d\n"
		+ "durability         %d / %d\n"
		+ "speed multiplier   %.2fx\n"
		+ "minimum release    %.0f px/s\n"
		+ "respawn delay      %.1f s\n\n"
		+ "test state         %s\n"
		+ "bumper state       %s\n"
		+ "ball speed         %.0f px/s\n"
		+ "hits               %d\n"
		+ "restarts           %d"
	) % [
		get_selected_display_name(),
		BumperSettings.BumperType.keys()[current_bumper.settings.bumper_type],
		repair_part_status,
		current_bumper.get_base_score(),
		current_bumper.current_durability,
		current_bumper.get_max_durability(),
		current_bumper.get_speed_multiplier(),
		current_bumper.get_minimum_release_speed(),
		current_bumper.get_respawn_delay(),
		state_name,
		bumper_state,
		ball_speed,
		hit_count,
		restart_count,
	]


func _is_previous_key(event: InputEventKey) -> bool:
	return event.physical_keycode in [KEY_LEFT, KEY_A]


func _is_next_key(event: InputEventKey) -> bool:
	return event.physical_keycode in [KEY_RIGHT, KEY_D]


func _is_cannon_choosing_direction() -> bool:
	return (
		current_bumper is ShotBumper
		and is_instance_valid(current_ball)
		and current_ball.freeze
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152.0, 648.0)), Color("08111d"))
	draw_rect(Rect2(300.0, 92.0, 552.0, 500.0), Color("101f2b"), true)
	draw_rect(Rect2(300.0, 92.0, 552.0, 500.0), Color("355064"), false, 2.0)
	if bumper_slot == null:
		return
	var center := bumper_slot.global_position
	var drop_start := center + Vector2.UP * drop_height
	draw_dashed_line(drop_start, center, Color("547286"), 2.0, 10.0)
	draw_circle(drop_start, 7.0, Color("f1d589"), false, 2.0)
	draw_arc(center, 82.0, 0.0, TAU, 48, Color("3f6175"), 2.0)
	draw_line(center + Vector2(-110.0, 0.0), center + Vector2(110.0, 0.0), Color("294456"), 1.0)
	draw_line(center + Vector2(0.0, -110.0), center + Vector2(0.0, 110.0), Color("294456"), 1.0)
