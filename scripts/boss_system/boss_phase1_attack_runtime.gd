class_name BossPhase1AttackRuntime
extends Node

signal binding_lost

var _rules: Stage1BossPhase1Rules = null
var _scheduler: BossPhase1AttackScheduler = null
var _coordinator: BossPhase1AttackCoordinator = null
var _selector: BossPhase1AttackPatternSelector = null
var _controller: BossAttackController = null
var _first_pattern: BossAttackPattern = null
var _repeat_pattern: BossAttackPattern = null
var _setup_complete: bool = false


func _process(_delta: float) -> void:
	if _setup_complete and not is_ready():
		_handle_binding_lost()


func setup(
	rules: Stage1BossPhase1Rules,
	scheduler: BossPhase1AttackScheduler,
	coordinator: BossPhase1AttackCoordinator,
	selector: BossPhase1AttackPatternSelector,
	controller: BossAttackController,
	first_pattern: BossAttackPattern,
	repeat_pattern: BossAttackPattern
) -> bool:
	if _setup_complete:
		if not _matches_setup(
			rules,
			scheduler,
			coordinator,
			selector,
			controller,
			first_pattern,
			repeat_pattern
		):
			return false
		if is_ready():
			return true
		_cleanup_broken_setup()
		return false

	if not _are_setup_inputs_valid(
		rules,
		scheduler,
		coordinator,
		selector,
		controller,
		first_pattern,
		repeat_pattern
	):
		return false
	if scheduler.get_current_state() != BossPhase1AttackScheduler.State.STOPPED:
		return false
	if controller.current_state != BossAttackController.State.IDLE:
		return false
	if selector.is_bound() or coordinator.is_bound():
		return false

	if not selector.bind(scheduler, controller, first_pattern, repeat_pattern):
		return false
	if not coordinator.bind(scheduler, controller):
		selector.unbind()
		return false
	if not scheduler.configure(
		rules.first_attack_delay_sec,
		rules.new_ball_grace_sec,
		rules.phase1_attack_delay_min_sec,
		rules.phase1_attack_delay_max_sec
	):
		coordinator.unbind(false)
		selector.unbind()
		return false

	_rules = rules
	_scheduler = scheduler
	_coordinator = coordinator
	_selector = selector
	_controller = controller
	_first_pattern = first_pattern
	_repeat_pattern = repeat_pattern
	_setup_complete = true
	return true


func start() -> bool:
	if not is_ready() or _coordinator.is_running():
		return false
	return _coordinator.start()


func stop(cancel_active_attack: bool = true) -> bool:
	if not is_ready() or not _coordinator.is_running():
		return false
	return _coordinator.stop(cancel_active_attack)


func reset(cancel_active_attack: bool = true) -> bool:
	if not is_ready():
		return false
	if not cancel_active_attack:
		if _coordinator.is_attack_in_flight():
			return false
		if _controller.current_state != BossAttackController.State.IDLE:
			return false

	var coordinator: BossPhase1AttackCoordinator = _coordinator
	var scheduler: BossPhase1AttackScheduler = _scheduler
	var selector: BossPhase1AttackPatternSelector = _selector
	var controller: BossAttackController = _controller

	coordinator.unbind(cancel_active_attack)
	scheduler.reset()
	if coordinator.bind(scheduler, controller):
		return true

	coordinator.unbind(false)
	selector.unbind()
	_setup_complete = false
	_clear_references()
	return false


func begin_new_ball_grace() -> bool:
	if not is_ready() or not _coordinator.is_running():
		return false
	return _scheduler.begin_new_ball_grace()


func teardown(cancel_active_attack: bool = true) -> void:
	if not _setup_complete:
		return

	_setup_complete = false
	if is_instance_valid(_coordinator):
		_coordinator.unbind(cancel_active_attack)
	if is_instance_valid(_selector):
		_selector.unbind()
	_clear_references()


func is_ready() -> bool:
	if not _setup_complete or not _has_valid_references():
		return false
	return _selector.is_bound() \
		and _coordinator.is_bound() \
		and _scheduler.is_configured()


func is_running() -> bool:
	if not is_ready():
		return false
	return _coordinator.is_running()


func _are_setup_inputs_valid(
	rules: Stage1BossPhase1Rules,
	scheduler: BossPhase1AttackScheduler,
	coordinator: BossPhase1AttackCoordinator,
	selector: BossPhase1AttackPatternSelector,
	controller: BossAttackController,
	first_pattern: BossAttackPattern,
	repeat_pattern: BossAttackPattern
) -> bool:
	if rules == null \
			or scheduler == null \
			or coordinator == null \
			or selector == null \
			or controller == null \
			or first_pattern == null \
			or repeat_pattern == null:
		return false
	if not is_instance_valid(rules) \
			or not is_instance_valid(scheduler) \
			or not is_instance_valid(coordinator) \
			or not is_instance_valid(selector) \
			or not is_instance_valid(controller) \
			or not is_instance_valid(first_pattern) \
			or not is_instance_valid(repeat_pattern):
		return false
	if not rules.validate().is_empty():
		return false
	return first_pattern.is_valid() and repeat_pattern.is_valid()


func _matches_setup(
	rules: Stage1BossPhase1Rules,
	scheduler: BossPhase1AttackScheduler,
	coordinator: BossPhase1AttackCoordinator,
	selector: BossPhase1AttackPatternSelector,
	controller: BossAttackController,
	first_pattern: BossAttackPattern,
	repeat_pattern: BossAttackPattern
) -> bool:
	return rules == _rules \
		and scheduler == _scheduler \
		and coordinator == _coordinator \
		and selector == _selector \
		and controller == _controller \
		and first_pattern == _first_pattern \
		and repeat_pattern == _repeat_pattern


func _has_valid_references() -> bool:
	return _rules != null \
		and is_instance_valid(_rules) \
		and _scheduler != null \
		and is_instance_valid(_scheduler) \
		and _coordinator != null \
		and is_instance_valid(_coordinator) \
		and _selector != null \
		and is_instance_valid(_selector) \
		and _controller != null \
		and is_instance_valid(_controller) \
		and _first_pattern != null \
		and is_instance_valid(_first_pattern) \
		and _repeat_pattern != null \
		and is_instance_valid(_repeat_pattern)


func _cleanup_broken_setup() -> void:
	_setup_complete = false
	if is_instance_valid(_coordinator):
		_coordinator.unbind(true)
	if is_instance_valid(_selector):
		_selector.unbind()
	_clear_references()


func _handle_binding_lost() -> void:
	if not _setup_complete:
		return

	_setup_complete = false
	if is_instance_valid(_coordinator):
		_coordinator.unbind(true)
	if is_instance_valid(_selector):
		_selector.unbind()
	_clear_references()
	binding_lost.emit()


func _clear_references() -> void:
	_rules = null
	_scheduler = null
	_coordinator = null
	_selector = null
	_controller = null
	_first_pattern = null
	_repeat_pattern = null
