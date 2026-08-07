class_name TeddyPhase1AttackRuntimePrototype
extends Node

const MAX_EVENT_COUNT: int = 30

@export_category("Resources")
@export var rules: Stage1BossPhase1Rules = null
@export var first_pattern: BossAttackPattern = null
@export var repeat_pattern: BossAttackPattern = null

@export_category("Runtime Components")
@export var runtime: BossPhase1AttackRuntime = null
@export var scheduler: BossPhase1AttackScheduler = null
@export var coordinator: BossPhase1AttackCoordinator = null
@export var selector: BossPhase1AttackPatternSelector = null
@export var controller: BossAttackController = null
@export var teddy_attack: TeddyArmSweepAttack = null

@export_category("Controls")
@export var start_button: Button = null
@export var stop_button: Button = null
@export var reset_button: Button = null
@export var new_ball_grace_button: Button = null

@export_category("Status")
@export var runtime_state_label: Label = null
@export var scheduler_state_label: Label = null
@export var controller_state_label: Label = null
@export var current_pattern_label: Label = null
@export var remaining_wait_label: Label = null
@export var remaining_grace_label: Label = null
@export var last_repeat_delay_label: Label = null
@export var event_log: RichTextLabel = null

var _event_messages: Array[String] = []
var _setup_succeeded: bool = false


func _ready() -> void:
	if not _validate_references():
		_set_available_buttons_disabled(true)
		_append_event("SETUP FAILED: invalid Node or Resource reference")
		push_error("Teddy phase 1 runtime prototype has invalid references.")
		_update_status_labels()
		return

	_connect_buttons()
	_connect_observer_signals()
	_setup_succeeded = runtime.setup(
		rules,
		scheduler,
		coordinator,
		selector,
		controller,
		first_pattern,
		repeat_pattern
	)
	if _setup_succeeded:
		_append_event("SETUP SUCCEEDED")
	else:
		_set_available_buttons_disabled(true)
		_append_event("SETUP FAILED: Runtime rejected configuration")
	_update_status_labels()


func _process(_delta: float) -> void:
	_update_status_labels()


func _exit_tree() -> void:
	if runtime != null and is_instance_valid(runtime):
		runtime.teardown(true)


func _validate_references() -> bool:
	if rules == null \
			or first_pattern == null \
			or repeat_pattern == null \
			or runtime == null \
			or scheduler == null \
			or coordinator == null \
			or selector == null \
			or controller == null \
			or teddy_attack == null \
			or start_button == null \
			or stop_button == null \
			or reset_button == null \
			or new_ball_grace_button == null \
			or runtime_state_label == null \
			or scheduler_state_label == null \
			or controller_state_label == null \
			or current_pattern_label == null \
			or remaining_wait_label == null \
			or remaining_grace_label == null \
			or last_repeat_delay_label == null \
			or event_log == null:
		return false
	if not is_instance_valid(rules) \
			or not is_instance_valid(first_pattern) \
			or not is_instance_valid(repeat_pattern) \
			or not is_instance_valid(runtime) \
			or not is_instance_valid(scheduler) \
			or not is_instance_valid(coordinator) \
			or not is_instance_valid(selector) \
			or not is_instance_valid(controller) \
			or not is_instance_valid(teddy_attack) \
			or not is_instance_valid(start_button) \
			or not is_instance_valid(stop_button) \
			or not is_instance_valid(reset_button) \
			or not is_instance_valid(new_ball_grace_button) \
			or not is_instance_valid(runtime_state_label) \
			or not is_instance_valid(scheduler_state_label) \
			or not is_instance_valid(controller_state_label) \
			or not is_instance_valid(current_pattern_label) \
			or not is_instance_valid(remaining_wait_label) \
			or not is_instance_valid(remaining_grace_label) \
			or not is_instance_valid(last_repeat_delay_label) \
			or not is_instance_valid(event_log):
		return false
	if not rules.validate().is_empty():
		return false
	if not first_pattern.is_valid() or not repeat_pattern.is_valid():
		return false
	return controller.attack == teddy_attack


func _connect_buttons() -> void:
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not stop_button.pressed.is_connected(_on_stop_pressed):
		stop_button.pressed.connect(_on_stop_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if not new_ball_grace_button.pressed.is_connected(_on_new_ball_grace_pressed):
		new_ball_grace_button.pressed.connect(_on_new_ball_grace_pressed)


func _connect_observer_signals() -> void:
	if not runtime.binding_lost.is_connected(_on_runtime_binding_lost):
		runtime.binding_lost.connect(_on_runtime_binding_lost)
	if not scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		scheduler.state_changed.connect(_on_scheduler_state_changed)
	if not scheduler.grace_started.is_connected(_on_grace_started):
		scheduler.grace_started.connect(_on_grace_started)
	if not scheduler.grace_finished.is_connected(_on_grace_finished):
		scheduler.grace_finished.connect(_on_grace_finished)
	if not scheduler.attack_requested.is_connected(_on_attack_requested):
		scheduler.attack_requested.connect(_on_attack_requested)
	if not selector.pattern_applied.is_connected(_on_pattern_applied):
		selector.pattern_applied.connect(_on_pattern_applied)
	if not selector.pattern_application_failed.is_connected(
		_on_pattern_application_failed
	):
		selector.pattern_application_failed.connect(_on_pattern_application_failed)
	if not coordinator.attack_dispatch_succeeded.is_connected(
		_on_attack_dispatch_succeeded
	):
		coordinator.attack_dispatch_succeeded.connect(_on_attack_dispatch_succeeded)
	if not coordinator.attack_dispatch_failed.is_connected(_on_attack_dispatch_failed):
		coordinator.attack_dispatch_failed.connect(_on_attack_dispatch_failed)
	if not controller.state_changed.is_connected(_on_controller_state_changed):
		controller.state_changed.connect(_on_controller_state_changed)
	if not controller.attack_finished.is_connected(_on_controller_attack_finished):
		controller.attack_finished.connect(_on_controller_attack_finished)
	if not controller.attack_cancelled.is_connected(_on_controller_attack_cancelled):
		controller.attack_cancelled.connect(_on_controller_attack_cancelled)
	if not teddy_attack.attack_hit.is_connected(_on_attack_hit):
		teddy_attack.attack_hit.connect(_on_attack_hit)


func _on_start_pressed() -> void:
	var succeeded: bool = runtime.start()
	_append_event("START: %s" % _result_text(succeeded))


func _on_stop_pressed() -> void:
	var succeeded: bool = runtime.stop(true)
	_append_event("STOP: %s" % _result_text(succeeded))


func _on_reset_pressed() -> void:
	var succeeded: bool = runtime.reset(true)
	_append_event("RESET: %s" % _result_text(succeeded))


func _on_new_ball_grace_pressed() -> void:
	var succeeded: bool = runtime.begin_new_ball_grace()
	_append_event("NEW BALL GRACE: %s" % _result_text(succeeded))


func _on_scheduler_state_changed(
	previous_state: BossPhase1AttackScheduler.State,
	current_state: BossPhase1AttackScheduler.State
) -> void:
	_append_event("SCHEDULER: %s -> %s" % [
		_scheduler_state_name(previous_state),
		_scheduler_state_name(current_state),
	])


func _on_grace_started(duration_sec: float) -> void:
	_append_event("GRACE STARTED: %.2f s" % duration_sec)


func _on_grace_finished() -> void:
	_append_event("GRACE FINISHED")


func _on_attack_requested() -> void:
	_append_event("ATTACK REQUESTED")


func _on_pattern_applied(
	pattern: BossAttackPattern,
	is_first_attack: bool
) -> void:
	var pattern_kind: String = "First" if is_first_attack else "Repeat"
	_append_event("PATTERN APPLIED: %s (%s)" % [pattern_kind, pattern.attack_id])


func _on_pattern_application_failed(is_first_attack: bool) -> void:
	var pattern_kind: String = "First" if is_first_attack else "Repeat"
	_append_event("PATTERN APPLICATION FAILED: %s" % pattern_kind)


func _on_attack_dispatch_succeeded() -> void:
	_append_event("ATTACK DISPATCH SUCCEEDED")


func _on_attack_dispatch_failed() -> void:
	_append_event("ATTACK DISPATCH FAILED")


func _on_controller_state_changed(
	previous_state: BossAttackController.State,
	current_state: BossAttackController.State
) -> void:
	_append_event("CONTROLLER: %s -> %s" % [
		_controller_state_name(previous_state),
		_controller_state_name(current_state),
	])


func _on_controller_attack_finished() -> void:
	_append_event("ATTACK FINISHED")


func _on_controller_attack_cancelled() -> void:
	_append_event("ATTACK CANCELLED")


func _on_attack_hit(target: Node) -> void:
	_append_event("ATTACK HIT: %s" % target.name)


func _on_runtime_binding_lost() -> void:
	_setup_succeeded = false
	_set_available_buttons_disabled(true)
	_append_event("RUNTIME BINDING LOST")


func _update_status_labels() -> void:
	if is_instance_valid(runtime_state_label):
		var ready: bool = is_instance_valid(runtime) and runtime.is_ready()
		var running: bool = is_instance_valid(runtime) and runtime.is_running()
		runtime_state_label.text = "Runtime: Ready=%s  Running=%s" % [ready, running]
	if is_instance_valid(scheduler_state_label):
		var scheduler_name: String = "Unavailable"
		if is_instance_valid(scheduler):
			scheduler_name = _scheduler_state_name(scheduler.get_current_state())
		scheduler_state_label.text = "Scheduler: %s" % scheduler_name
	if is_instance_valid(controller_state_label):
		var controller_name: String = "Unavailable"
		if is_instance_valid(controller):
			controller_name = _controller_state_name(controller.current_state)
		controller_state_label.text = "Controller: %s" % controller_name
	if is_instance_valid(current_pattern_label):
		current_pattern_label.text = "Current Pattern: %s" % _current_pattern_name()
	if is_instance_valid(remaining_wait_label):
		var wait_time: float = 0.0
		if is_instance_valid(scheduler):
			wait_time = scheduler.get_wait_time_remaining()
		remaining_wait_label.text = "Remaining Wait: %.2f s" % wait_time
	if is_instance_valid(remaining_grace_label):
		var grace_time: float = 0.0
		if is_instance_valid(scheduler):
			grace_time = scheduler.get_grace_time_remaining()
		remaining_grace_label.text = "Remaining Grace: %.2f s" % grace_time
	if is_instance_valid(last_repeat_delay_label):
		var repeat_delay: float = 0.0
		if is_instance_valid(scheduler):
			repeat_delay = scheduler.get_last_selected_repeat_delay()
		last_repeat_delay_label.text = "Last Repeat Delay: %.2f s" % repeat_delay


func _current_pattern_name() -> String:
	if not is_instance_valid(controller):
		return "Unavailable"
	if controller.pattern == null:
		return "None"
	if controller.pattern == first_pattern:
		return "First"
	if controller.pattern == repeat_pattern:
		return "Repeat"
	return "Unknown"


func _scheduler_state_name(state: BossPhase1AttackScheduler.State) -> String:
	return str(BossPhase1AttackScheduler.State.keys()[state])


func _controller_state_name(state: BossAttackController.State) -> String:
	return str(BossAttackController.State.keys()[state])


func _result_text(succeeded: bool) -> String:
	return "SUCCESS" if succeeded else "REJECTED"


func _append_event(message: String) -> void:
	_event_messages.append(message)
	while _event_messages.size() > MAX_EVENT_COUNT:
		_event_messages.pop_front()
	if is_instance_valid(event_log):
		event_log.text = "\n".join(_event_messages)


func _set_available_buttons_disabled(disabled: bool) -> void:
	for button: Button in [
		start_button,
		stop_button,
		reset_button,
		new_ball_grace_button,
	]:
		if is_instance_valid(button):
			button.disabled = disabled
