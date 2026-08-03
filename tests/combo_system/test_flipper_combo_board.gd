extends "res://tests/flipper_system/test_flipper_board.gd"


const MAX_EVENT_LINES := 6


@onready var combo_system: ComboSystem = get_node_or_null(
	"ComboSystem"
) as ComboSystem
@onready var combo_hud: ComboHud = get_node_or_null(
	"HUD/ComboHud"
) as ComboHud
@onready var manual_hit_source: ComboHitSource = get_node_or_null(
	"ManualHitSource"
) as ComboHitSource
@onready var combo_wave_controller: ComboWaveController = get_node_or_null(
	"ComboWaveController"
) as ComboWaveController
@onready var combo_state_label: Label = get_node_or_null(
	"HUD/ComboInspector/Panel/Margin/VBox/StateLabel"
) as Label
@onready var event_log_label: Label = get_node_or_null(
	"HUD/ComboInspector/Panel/Margin/VBox/EventLogLabel"
) as Label
@export_node_path("Area2D") var ball_drain_area_path: NodePath = ^"BallDrainArea"
@onready var ball_drain_area: Area2D = get_node_or_null(
	ball_drain_area_path
) as Area2D


var _event_lines: Array[String] = []
var _manual_contact_id := 0
var _drain_pending := false


func _ready() -> void:
	super()
	if is_instance_valid(ball_drain_area) \
			and not ball_drain_area.body_entered.is_connected(
				_on_ball_drain_area_body_entered
			):
		ball_drain_area.body_entered.connect(_on_ball_drain_area_body_entered)
	_setup_combo_system()
	_append_event("READY · Space로 공을 발사하세요")


func _on_ball_drain_area_body_entered(body: Node2D) -> void:
	if _drain_pending or body != ball or ball.freeze:
		return
	_drain_pending = true
	call_deferred(&"_handle_ball_drained", "커스텀 낙하 영역")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			match key_event.physical_keycode:
				KEY_C:
					_register_manual_hit()
					get_viewport().set_input_as_handled()
					return
				KEY_T:
					advance_to_next_tier()
					get_viewport().set_input_as_handled()
					return
				KEY_P:
					toggle_combo_timer()
					get_viewport().set_input_as_handled()
					return
				KEY_F:
					finish_combo_manually()
					get_viewport().set_input_as_handled()
					return
				KEY_X:
					reset_combo_test()
					get_viewport().set_input_as_handled()
					return

	super(event)


## R 리셋과 실제 보드 이탈은 현재 콤보를 공 낙하 사유로 정산합니다.
func reset_ball() -> void:
	_settle_combo_for_drain("R 리셋")
	super()


## 현재 규칙의 다음 단계 경계까지 유효 타격을 만들어 빠르게 검증합니다.
func advance_to_next_tier() -> void:
	if not is_instance_valid(combo_system):
		return

	var rules := combo_system.rules
	var target_count := combo_system.combo_count + 1
	if combo_system.combo_count < int(rules.get(&"super_start_count")):
		target_count = int(rules.get(&"super_start_count"))
	elif combo_system.combo_count < int(rules.get(&"hyper_start_count")):
		target_count = int(rules.get(&"hyper_start_count"))
	elif combo_system.combo_count < int(rules.get(&"ultra_start_count")):
		target_count = int(rules.get(&"ultra_start_count"))

	while combo_system.combo_count < target_count:
		_register_manual_hit()


func toggle_combo_timer() -> void:
	if not is_instance_valid(combo_system):
		return
	if combo_system.is_timer_suspended:
		combo_system.resume_combo_timer()
		_append_event("TIMER · 재개")
	else:
		combo_system.suspend_combo_timer()
		_append_event("TIMER · 일시정지")


func finish_combo_manually() -> int:
	if not is_instance_valid(combo_system):
		return 0
	var awarded_score := combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	if awarded_score == 0:
		_append_event("SETTLE · 활성 콤보 없음")
	return awarded_score


func reset_combo_test() -> void:
	if not is_instance_valid(combo_system):
		return
	combo_system.reset_wave()
	_append_event("RESET · 콤보와 누적 점수 초기화")


func _setup_combo_system() -> void:
	if not is_instance_valid(combo_system):
		push_warning("ComboSystem 노드가 필요합니다.")
		return

	if is_instance_valid(combo_hud):
		combo_hud.bind_combo_system(combo_system)
	_bind_hit_source(manual_hit_source)

	var bumpers := get_node_or_null("Bumpers")
	if bumpers != null:
		for bumper: Node in bumpers.get_children():
			var source := bumper.get_node_or_null(
				"ComboHitSource"
			) as ComboHitSource
			var detection_area := bumper.get_node_or_null(
				"SpeedDetectionArea"
			) as Area2D
			_bind_hit_source(source)
			if source == null or detection_area == null:
				continue
			detection_area.body_entered.connect(
				_on_bumper_body_entered.bind(source)
			)
			detection_area.body_exited.connect(
				_on_bumper_body_exited.bind(source)
			)

	combo_system.combo_tier_changed.connect(_on_combo_tier_changed)
	combo_system.combo_finished.connect(_on_combo_finished)
	ball_launched.connect(_on_combo_test_ball_launched)


func _bind_hit_source(source: ComboHitSource) -> void:
	if not is_instance_valid(source):
		return
	combo_system.bind_hit_source(source)
	source.valid_hit_registered.connect(_on_valid_hit_registered)


func _register_manual_hit() -> void:
	if not is_instance_valid(manual_hit_source):
		return
	_manual_contact_id += 1
	manual_hit_source.register_contact(_manual_contact_id)
	manual_hit_source.release_contact(_manual_contact_id)


func _on_bumper_body_entered(
	body: Node2D,
	source: ComboHitSource
) -> void:
	if body != ball:
		return
	source.register_contact(body.get_instance_id())


func _on_bumper_body_exited(
	body: Node2D,
	source: ComboHitSource
) -> void:
	if body != ball:
		return
	source.release_contact(body.get_instance_id())


func _on_valid_hit_registered(
	source: Node,
	_contact_id: int,
	_score_weight: float
) -> void:
	var source_name := String(source.get(&"source_id"))
	_append_event("HIT · %s · x%d" % [source_name, combo_system.combo_count])


func _on_combo_tier_changed(
	_previous_tier: int,
	current_tier: int,
	combo_count: int
) -> void:
	var tier_name := String(combo_system.rules.call(
		&"get_tier_label",
		current_tier
	))
	_append_event("TIER · %s 진입 · x%d" % [tier_name, combo_count])


func _on_combo_finished(
	combo_count: int,
	_tier: int,
	awarded_score: int,
	reason: int
) -> void:
	var reason_name := "TIMEOUT"
	if reason == ComboSystem.EndReason.BALL_DRAINED:
		reason_name = "DRAIN"
	elif reason == ComboSystem.EndReason.MANUAL:
		reason_name = "MANUAL"
	_append_event("SETTLE · %s · x%d · +%d" % [
		reason_name,
		combo_count,
		awarded_score,
	])


func _on_combo_test_ball_launched() -> void:
	if not is_instance_valid(combo_system):
		return
	if is_instance_valid(combo_wave_controller):
		_append_event("BALL · 발사 · 웨이브 상태 연동")
		return
	combo_system.on_ball_launched()
	_append_event("BALL · 발사 · 새 콤보 시작")


func _handle_ball_drained(source_name: String) -> void:
	_settle_combo_for_drain(source_name)
	super.reset_ball()
	_drain_pending = false


func _settle_combo_for_drain(source_name: String) -> void:
	if not is_instance_valid(combo_system):
		return
	var had_combo := combo_system.combo_count > 0
	combo_system.on_ball_drained()
	if not had_combo:
		_append_event("DRAIN · %s · 활성 콤보 없음" % source_name)


func _refresh_hud() -> void:
	super()
	if is_instance_valid(guide_label):
		guide_label.text = (
			"[공·보드·플리퍼·콤보 통합 테스트]\n"
			+ "WASD/방향키: 조준·플리퍼 선택   Space: 선택·발사·플리퍼\n"
			+ "R: 공 리셋/낙하 정산   오른쪽 패널: 콤보 검증 조작"
		)
	if is_instance_valid(combo_state_label) and is_instance_valid(combo_system):
		var rules := combo_system.rules
		combo_state_label.text = (
			"현재 x%d · 가중치 %.1f · 남은 시간 %.2fs\n"
			+ "티어 경계: Normal 1 / Super %d / Hyper %d / Ultra %d"
		) % [
			combo_system.combo_count,
			combo_system.total_score_weight,
			combo_system.time_remaining,
			int(rules.get(&"super_start_count")),
			int(rules.get(&"hyper_start_count")),
			int(rules.get(&"ultra_start_count")),
		]


func _append_event(message: String) -> void:
	_event_lines.push_front(message)
	if _event_lines.size() > MAX_EVENT_LINES:
		_event_lines.resize(MAX_EVENT_LINES)
	if is_instance_valid(event_log_label):
		event_log_label.text = "최근 이벤트\n" + "\n".join(_event_lines)
