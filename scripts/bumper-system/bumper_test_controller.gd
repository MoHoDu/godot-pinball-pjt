class_name BumperTestController
extends Node


@export var bumper_root_path: NodePath = ^"../Stage01Bumpers"
@export var combo_system_path: NodePath = ^"../ComboSystem"
@export var wave_manager_path: NodePath = ^"../WaveManager"
@export var status_label_path: NodePath = ^"../HUD/BumperStatusPanel/StatusLabel"
@export var stage_layout: Resource


@onready var bumper_root: Node = get_node_or_null(bumper_root_path)
@onready var combo_system: ComboSystem = get_node_or_null(
	combo_system_path
) as ComboSystem
@onready var wave_manager: WaveManager = get_node_or_null(
	wave_manager_path
) as WaveManager
@onready var status_label: Label = get_node_or_null(status_label_path) as Label


var _event_lines: Array[String] = []
var _bound_bumpers: Array[Bumper] = []


func _ready() -> void:
	_bind_bumpers()
	if is_instance_valid(wave_manager):
		wave_manager.active_ball_changed.connect(_on_active_ball_changed)
	_append_event("READY · Stage 01 범퍼 5종 + 수리 부품 4종")
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _bind_bumpers() -> void:
	if bumper_root == null:
		push_warning("Stage01Bumpers 루트가 필요합니다.")
		return
	for child: Node in bumper_root.get_children():
		if not child is Bumper:
			continue
		var bumper := child as Bumper
		_bound_bumpers.append(bumper)
		if is_instance_valid(combo_system) and bumper.combo_hit_source != null:
			combo_system.bind_hit_source(bumper.combo_hit_source)
		bumper.valid_hit_registered.connect(_on_valid_hit_registered)
		bumper.state_changed.connect(_on_bumper_state_changed.bind(bumper))
		if bumper is ShotBumper:
			var shot := bumper as ShotBumper
			shot.control_started.connect(_on_shot_control_started)
			shot.control_ended.connect(_on_shot_control_ended)


func _on_active_ball_changed(ball: Pinball) -> void:
	for bumper: Bumper in _bound_bumpers:
		bumper.reset_for_new_ball()
	if is_instance_valid(combo_system):
		while combo_system.is_timer_suspended:
			combo_system.resume_combo_timer()
	if is_instance_valid(ball):
		# 기획 기준인 지름 44px을 이 전용 테스트 씬에서만 적용합니다.
		ball.ball_diameter = 44.0
	_append_event("BALL · 새 발사 준비 · 범퍼 전체 복구")


func _on_valid_hit_registered(
	bumper_id: StringName,
	_ball: RigidBody2D,
	_contact_id: int,
	base_score: int
) -> void:
	_append_event("HIT · %s · base %d" % [bumper_id, base_score])


func _on_bumper_state_changed(
	_previous: Bumper.BumperState,
	current: Bumper.BumperState,
	bumper: Bumper
) -> void:
	_append_event("STATE · %s · %s" % [
		bumper.bumper_id,
		Bumper.BumperState.keys()[current],
	])


func _on_shot_control_started(
	_bumper: ShotBumper,
	_ball: RigidBody2D
) -> void:
	if is_instance_valid(combo_system):
		combo_system.suspend_combo_timer()
	_append_event("SHOT · 방향 선택 · 타이머 정지")


func _on_shot_control_ended(
	_bumper: ShotBumper,
	_ball: RigidBody2D
) -> void:
	_append_event("SHOT · 안전 이탈 · 0.3초 유예")
	_resume_combo_after_shot_grace()


func _resume_combo_after_shot_grace() -> void:
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(combo_system):
		combo_system.resume_combo_timer()


func _append_event(message: String) -> void:
	_event_lines.push_front(message)
	if _event_lines.size() > 5:
		_event_lines.resize(5)
	_refresh_status()


func _refresh_status() -> void:
	if not is_instance_valid(status_label):
		return
	var active_count := 0
	for bumper: Bumper in _bound_bumpers:
		if bumper.state == Bumper.BumperState.ACTIVE:
			active_count += 1
	status_label.text = (
		"범퍼 모듈 · ACTIVE %d/%d\n"
		+ "Stage 01 · Normal → Bounce → Shot · Track 제외\n"
		+ "수리 부품: Bumper 상속 / 효과는 기획 대기\n\n%s"
	) % [active_count, _bound_bumpers.size(), "\n".join(_event_lines)]
