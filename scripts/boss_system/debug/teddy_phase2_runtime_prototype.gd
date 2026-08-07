class_name TeddyPhase2RuntimePrototype
extends Node


const MAX_EVENT_COUNT: int = 30
const PHASE_2_EVENT: String = "PHASE 2 ENTERED"
const PATTERN_1_EVENT: String = "PATTERN 1 START"
const PATTERN_2_EVENT: String = "PATTERN 2 START"


@export_category("Rules")
@export var phase1_rules: Stage1BossPhase1Rules = null
@export var phase2_rules: BossPhase2AttackRules = null

@export_category("Phase Runtime")
@export var health: BossHealthComponent = null
@export var phase_transition: BossPhaseTransitionController = null
@export var attack_runtime: BossPhase1AttackRuntime = null
@export var scheduler: BossPhase1AttackScheduler = null
@export var coordinator: BossPhase1AttackCoordinator = null
@export var controller: BossAttackController = null

@export_category("Attacks")
@export var pattern_1_attack: TeddyArmSweepAttack = null
@export var pattern_2_attack: TeddyDoubleArmUpSweepAttack = null
@export var arm_hit_tracker: BossArmHitBallTracker = null
@export var arm_ball_reflector: BossArmBallReflector = null

@export_category("Debug")
@export var reset_button: Button = null
@export var phase_label: Label = null
@export var pattern_label: Label = null
@export var phase_event_log: RichTextLabel = null


var _setup_complete: bool = false
var _phase_2_schedule_pending: bool = false
var _phase_2_schedule_active: bool = false
var _next_phase_2_pattern: int = 1
var _current_pattern: int = 1
var _event_messages: Array[String] = []


func _ready() -> void:
	call_deferred(&"_setup_phase_runtime")


func _exit_tree() -> void:
	teardown()


func teardown() -> void:
	if not _setup_complete:
		return
	_setup_complete = false
	_disconnect_signals()
	if is_instance_valid(phase_transition):
		phase_transition.unbind_health()


func is_phase_2_schedule_active() -> bool:
	return _phase_2_schedule_active


func get_current_pattern_number() -> int:
	return _current_pattern


func _setup_phase_runtime() -> void:
	if _setup_complete:
		return
	if not _validate_references():
		push_error("Teddy Phase 2 runtime has invalid references.")
		return

	_connect_signals()
	var threshold_hp: int = int(
		float(phase1_rules.boss_max_hp) * phase1_rules.phase2_hp_ratio
	)
	if not phase_transition.configure_phase_2_threshold(threshold_hp) \
			or not phase_transition.bind_health(health):
		_disconnect_signals()
		phase_transition.unbind_health()
		push_error("Teddy Phase 2 transition setup failed.")
		return

	_setup_complete = true
	_phase_2_schedule_pending = phase_transition.is_phase_2()
	_phase_2_schedule_active = false
	_next_phase_2_pattern = 1
	_select_attack(1)
	if _phase_2_schedule_pending:
		_try_activate_phase_2_schedule()
	_update_debug_ui()


func _validate_references() -> bool:
	for reference: Variant in [
		phase1_rules,
		phase2_rules,
		health,
		phase_transition,
		attack_runtime,
		scheduler,
		coordinator,
		controller,
		pattern_1_attack,
		pattern_2_attack,
		arm_hit_tracker,
		arm_ball_reflector,
		reset_button,
		phase_label,
		pattern_label,
		phase_event_log,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	return phase1_rules.validate().is_empty() \
		and phase2_rules.validate().is_empty() \
		and attack_runtime.is_ready() \
		and health.is_configured()


func _connect_signals() -> void:
	if not phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.connect(_on_phase_2_entered)
	if not scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		scheduler.state_changed.connect(_on_scheduler_state_changed)
	if not controller.attack_finished.is_connected(_on_attack_finished):
		controller.attack_finished.connect(_on_attack_finished)
	if not controller.attack_cancelled.is_connected(_on_attack_cancelled):
		controller.attack_cancelled.connect(_on_attack_cancelled)
	if not controller.attack_started.is_connected(_on_attack_started):
		controller.attack_started.connect(_on_attack_started)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)


func _disconnect_signals() -> void:
	if is_instance_valid(phase_transition) \
			and phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.disconnect(_on_phase_2_entered)
	if is_instance_valid(scheduler) \
			and scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		scheduler.state_changed.disconnect(_on_scheduler_state_changed)
	if is_instance_valid(controller):
		if controller.attack_finished.is_connected(_on_attack_finished):
			controller.attack_finished.disconnect(_on_attack_finished)
		if controller.attack_cancelled.is_connected(_on_attack_cancelled):
			controller.attack_cancelled.disconnect(_on_attack_cancelled)
		if controller.attack_started.is_connected(_on_attack_started):
			controller.attack_started.disconnect(_on_attack_started)
	if is_instance_valid(reset_button) \
			and reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.disconnect(_on_reset_pressed)


func _on_phase_2_entered(_current_hp: int) -> void:
	_phase_2_schedule_pending = true
	_append_event(PHASE_2_EVENT)
	_try_activate_phase_2_schedule()
	_update_debug_ui()


func _try_activate_phase_2_schedule() -> bool:
	if not _phase_2_schedule_pending:
		return false
	if controller.current_state != BossAttackController.State.IDLE \
			or coordinator.is_attack_in_flight():
		return false

	var restart_runtime: bool = attack_runtime.is_running()
	if restart_runtime and not attack_runtime.stop(false):
		return false
	if not scheduler.configure(
		phase2_rules.attack_interval_min_sec,
		phase1_rules.new_ball_grace_sec,
		phase2_rules.attack_interval_min_sec,
		phase2_rules.attack_interval_max_sec
	):
		if restart_runtime:
			attack_runtime.start()
		return false

	_phase_2_schedule_pending = false
	_phase_2_schedule_active = true
	_next_phase_2_pattern = 1
	if restart_runtime and not attack_runtime.start():
		_phase_2_schedule_active = false
		return false
	return true


func _on_attack_finished() -> void:
	if _phase_2_schedule_pending:
		_try_activate_phase_2_schedule()


func _on_attack_cancelled() -> void:
	if _phase_2_schedule_pending:
		call_deferred(&"_try_activate_phase_2_schedule")


func _on_scheduler_state_changed(
	previous_state: BossPhase1AttackScheduler.State,
	current_state: BossPhase1AttackScheduler.State
) -> void:
	if current_state != BossPhase1AttackScheduler.State.WAITING_FOR_ATTACK_FINISH:
		return
	if previous_state != BossPhase1AttackScheduler.State.WAITING_FIRST_ATTACK \
			and previous_state != BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK:
		return

	if not phase_transition.is_phase_2():
		_select_attack(1)
		return
	var selected_pattern: int = _next_phase_2_pattern
	_next_phase_2_pattern = 2 if selected_pattern == 1 else 1
	_select_attack(selected_pattern)


func _select_attack(pattern_number: int) -> bool:
	var selected_attack: TeddyArmSweepAttack = (
		pattern_1_attack if pattern_number == 1 else pattern_2_attack
	)
	if not is_instance_valid(selected_attack) \
			or controller.current_state != BossAttackController.State.IDLE:
		return false
	if not arm_hit_tracker.bind_attack(selected_attack):
		return false
	if not arm_ball_reflector.bind_attack(selected_attack):
		arm_hit_tracker.bind_attack(controller.attack)
		return false

	controller.attack = selected_attack
	pattern_1_attack.visible = pattern_number == 1
	pattern_2_attack.visible = pattern_number == 2
	_current_pattern = pattern_number
	_update_debug_ui()
	return true


func _on_attack_started(_attack_id: StringName) -> void:
	_append_event(PATTERN_1_EVENT if _current_pattern == 1 else PATTERN_2_EVENT)


func _on_reset_pressed() -> void:
	call_deferred(&"_reset_phase_state")


func _reset_phase_state() -> void:
	if not _setup_complete \
			or controller.current_state != BossAttackController.State.IDLE \
			or scheduler.get_current_state() != BossPhase1AttackScheduler.State.STOPPED:
		return
	phase_transition.reset()
	_phase_2_schedule_pending = false
	_phase_2_schedule_active = false
	_next_phase_2_pattern = 1
	scheduler.configure(
		phase1_rules.first_attack_delay_sec,
		phase1_rules.new_ball_grace_sec,
		phase1_rules.phase1_attack_delay_min_sec,
		phase1_rules.phase1_attack_delay_max_sec
	)
	_select_attack(1)
	_update_debug_ui()


func _update_debug_ui() -> void:
	if is_instance_valid(phase_label):
		phase_label.text = "Phase: %d" % (2 if phase_transition.is_phase_2() else 1)
	if is_instance_valid(pattern_label):
		pattern_label.text = "Current Pattern: %d" % _current_pattern


func _append_event(message: String) -> void:
	_event_messages.append(message)
	while _event_messages.size() > MAX_EVENT_COUNT:
		_event_messages.pop_front()
	if is_instance_valid(phase_event_log):
		phase_event_log.text = "\n".join(_event_messages)
