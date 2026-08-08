class_name TeddyBattleCompletionRuntimePrototype
extends Node


const MAX_EVENT_COUNT: int = 30
const BOSS_DEFEATED_EVENT: String = "BOSS DEFEATED"
const BATTLE_COMPLETED_EVENT: String = "BATTLE COMPLETED"


@export_category("Completion")
@export var completion_controller: BossBattleCompletionController = null
@export var health: BossHealthComponent = null
@export var phase_transition: BossPhaseTransitionController = null

@export_category("Attack Runtime Reassembly")
@export var phase1_rules: Stage1BossPhase1Rules = null
@export var attack_runtime: BossPhase1AttackRuntime = null
@export var scheduler: BossPhase1AttackScheduler = null
@export var coordinator: BossPhase1AttackCoordinator = null
@export var selector: BossPhase1AttackPatternSelector = null
@export var attack_controller: BossAttackController = null
@export var first_pattern: BossAttackPattern = null
@export var repeat_pattern: BossAttackPattern = null

@export_category("Combat Shutdown")
@export var arm_hit_tracker: BossArmHitBallTracker = null
@export var arm_ball_reflector: BossArmBallReflector = null
@export var counter_window: BossCounterWindow = null

@export_category("Controls")
@export var start_button: Button = null
@export var stop_button: Button = null
@export var reset_button: Button = null
@export var grace_button: Button = null

@export_category("Debug")
@export var battle_label: Label = null
@export var battle_event_log: RichTextLabel = null


var _setup_complete: bool = false
var _event_messages: Array[String] = []


func _ready() -> void:
	call_deferred(&"_setup_completion")


func _exit_tree() -> void:
	teardown()


func teardown() -> void:
	if not _setup_complete:
		return
	_setup_complete = false
	_disconnect_signals()
	if is_instance_valid(completion_controller):
		completion_controller.unbind_health()


func _setup_completion() -> void:
	if _setup_complete:
		return
	if not _validate_references():
		push_error("Teddy battle completion runtime has invalid references.")
		return
	_connect_signals()
	if not completion_controller.bind_health(health):
		_disconnect_signals()
		push_error("Teddy battle completion Health binding failed.")
		return
	_setup_complete = true
	_update_battle_ui()


func _validate_references() -> bool:
	for reference: Variant in [
		completion_controller,
		health,
		phase_transition,
		phase1_rules,
		attack_runtime,
		scheduler,
		coordinator,
		selector,
		attack_controller,
		first_pattern,
		repeat_pattern,
		arm_hit_tracker,
		arm_ball_reflector,
		counter_window,
		start_button,
		stop_button,
		reset_button,
		grace_button,
		battle_label,
		battle_event_log,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	return phase1_rules.validate().is_empty() and attack_runtime.is_ready()


func _connect_signals() -> void:
	if not completion_controller.battle_completed.is_connected(
		_on_battle_completed
	):
		completion_controller.battle_completed.connect(_on_battle_completed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)


func _disconnect_signals() -> void:
	if is_instance_valid(completion_controller) \
			and completion_controller.battle_completed.is_connected(
				_on_battle_completed
			):
		completion_controller.battle_completed.disconnect(_on_battle_completed)
	if is_instance_valid(reset_button) \
			and reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.disconnect(_on_reset_pressed)


func _on_battle_completed() -> void:
	_append_event(BOSS_DEFEATED_EVENT)
	_append_event(BATTLE_COMPLETED_EVENT)
	_shutdown_combat()
	_update_battle_ui()


func _shutdown_combat() -> void:
	if is_instance_valid(attack_runtime):
		attack_runtime.teardown(true)
	if is_instance_valid(scheduler) and scheduler.is_running():
		scheduler.stop()
	if is_instance_valid(attack_controller) \
			and attack_controller.current_state != BossAttackController.State.IDLE:
		attack_controller.cancel_attack()
	if is_instance_valid(arm_hit_tracker):
		arm_hit_tracker.unbind_attack()
	if is_instance_valid(arm_ball_reflector):
		arm_ball_reflector.unbind_attack()
	if is_instance_valid(counter_window):
		counter_window.reset()
	_set_combat_buttons_for_completion()


func _on_reset_pressed() -> void:
	if not completion_controller.is_completed():
		return
	if not attack_runtime.setup(
		phase1_rules,
		scheduler,
		coordinator,
		selector,
		attack_controller,
		first_pattern,
		repeat_pattern
	):
		return
	completion_controller.reset()
	health.reset_health()
	_set_combat_buttons_disabled(false)
	_update_battle_ui()


func _set_combat_buttons_for_completion() -> void:
	for button: Button in [start_button, stop_button, grace_button]:
		if is_instance_valid(button):
			button.disabled = true
	if is_instance_valid(reset_button):
		reset_button.disabled = false


func _set_combat_buttons_disabled(disabled: bool) -> void:
	for button: Button in [start_button, stop_button, reset_button, grace_button]:
		if is_instance_valid(button):
			button.disabled = disabled


func _update_battle_ui() -> void:
	if is_instance_valid(battle_label):
		battle_label.text = "Battle: %s" % (
			"COMPLETED" if completion_controller.is_completed() else "ACTIVE"
		)


func _append_event(message: String) -> void:
	_event_messages.append(message)
	while _event_messages.size() > MAX_EVENT_COUNT:
		_event_messages.pop_front()
	if is_instance_valid(battle_event_log):
		battle_event_log.text = "\n".join(_event_messages)
