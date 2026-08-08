class_name Stage1TeddyBossRuntime
extends Node2D


signal battle_completed


@export_category("Rules")
@export var phase1_rules: Stage1BossPhase1Rules = null
@export var phase2_rules: BossPhase2AttackRules = null
@export var weight_rules: BossBallDamageWeightRules = null
@export var reflection_rules: BossArmBallReflectionRules = null
@export var cotton_rules: CursedCottonAddRules = null
@export var first_pattern: BossAttackPattern = null
@export var repeat_pattern: BossAttackPattern = null
@export var cotton_scene: PackedScene = null

@export_category("Boss Nodes")
@export var boss_hurtbox: Area2D = null
@export var health: BossHealthComponent = null
@export var damage_adapter: BossComboDamageAdapter = null
@export var damage_applier: BossCounterGatedDamageApplier = null
@export var damage_gate: BossDamageGate = null
@export var attack_controller: BossAttackController = null
@export var attack_runtime: BossPhase1AttackRuntime = null
@export var scheduler: BossPhase1AttackScheduler = null
@export var coordinator: BossPhase1AttackCoordinator = null
@export var selector: BossPhase1AttackPatternSelector = null
@export var pattern_1_attack: TeddyArmSweepAttack = null
@export var pattern_2_attack: TeddyDoubleArmUpSweepAttack = null
@export var phase_transition: BossPhaseTransitionController = null
@export var arm_hit_tracker: BossArmHitBallTracker = null
@export var arm_ball_reflector: BossArmBallReflector = null
@export var counter_resolver: BossParryCounterResolver = null
@export var counter_window: BossCounterWindow = null
@export var completion_controller: BossBattleCompletionController = null

@export_category("Presentation")
@export var show_attack_placeholder_visuals: bool = true

@export_category("Cursed Cotton")
@export var cotton_parent: Node2D = null
@export var cotton_spawn_left: Marker2D = null
@export var cotton_spawn_right: Marker2D = null


var _combo_system: ComboSystem = null
var _ball_flow: WaveBallFlowController = null
var _flippers: Array[PinballFlipper] = []
var _active_ball: Pinball = null
var _active_contact_ids: Dictionary[int, bool] = {}
var _active_cottons: Array[CursedCottonAdd] = []
var _is_setup: bool = false
var _battle_active: bool = false
var _cotton_spawned_for_battle: bool = false
var _phase_2_schedule_pending: bool = false
var _phase_2_schedule_active: bool = false
var _next_phase_2_pattern: int = 1
var _current_pattern: int = 1


func _ready() -> void:
	visible = false
	if is_instance_valid(boss_hurtbox):
		boss_hurtbox.set_deferred(&"monitoring", false)


func _exit_tree() -> void:
	teardown()


func setup(
	combo_system: ComboSystem,
	ball_flow: WaveBallFlowController,
	flippers: Array[PinballFlipper]
) -> bool:
	if _is_setup:
		return combo_system == _combo_system \
			and ball_flow == _ball_flow \
			and flippers == _flippers \
			and _bindings_are_valid()
	if not _references_are_valid(combo_system, ball_flow, flippers):
		return false

	_combo_system = combo_system
	_ball_flow = ball_flow
	_flippers.assign(flippers)
	if not _configure_components():
		_rollback_setup()
		return false
	_connect_signals()
	_active_ball = ball_flow.active_ball \
		if is_instance_valid(ball_flow.active_ball) else null
	_active_contact_ids.clear()
	_is_setup = true
	_battle_active = false
	visible = false
	boss_hurtbox.set_deferred(&"monitoring", false)
	return true


func start_battle() -> bool:
	if not _is_setup or not _bindings_are_valid() or _battle_active:
		return false
	if not _reset_battle_state():
		return false
	if not _bind_selected_attack(pattern_1_attack):
		return false
	_battle_active = true
	visible = true
	boss_hurtbox.set_deferred(&"monitoring", true)
	if not attack_runtime.start():
		_battle_active = false
		boss_hurtbox.set_deferred(&"monitoring", false)
		visible = false
		return false
	return true


func stop_battle() -> void:
	_battle_active = false
	if is_instance_valid(boss_hurtbox):
		boss_hurtbox.set_deferred(&"monitoring", false)
	if is_instance_valid(attack_runtime) and attack_runtime.is_running():
		attack_runtime.stop(true)
	if is_instance_valid(attack_controller) \
			and attack_controller.current_state != BossAttackController.State.IDLE:
		attack_controller.cancel_attack()
	if is_instance_valid(arm_hit_tracker):
		arm_hit_tracker.unbind_attack()
		arm_hit_tracker.clear()
	if is_instance_valid(arm_ball_reflector):
		arm_ball_reflector.unbind_attack()
	if is_instance_valid(counter_window):
		counter_window.reset()
	_remove_all_cottons()
	_active_contact_ids.clear()
	visible = false


func reset_battle() -> bool:
	if not _is_setup:
		return false
	stop_battle()
	return _reset_battle_state()


func teardown() -> void:
	if not _is_setup and _combo_system == null and _ball_flow == null:
		return
	stop_battle()
	_disconnect_signals()
	if is_instance_valid(completion_controller):
		completion_controller.unbind_health()
	if is_instance_valid(phase_transition):
		phase_transition.unbind_health()
	if is_instance_valid(counter_resolver):
		counter_resolver.unbind_flippers()
	if is_instance_valid(damage_applier):
		damage_applier.unbind_counter_window()
		damage_applier.unbind_damage_gate()
		damage_applier.unbind()
	if is_instance_valid(damage_gate):
		damage_gate.unbind_controller()
	if is_instance_valid(damage_adapter):
		damage_adapter.unbind_combo_system()
	if is_instance_valid(attack_runtime):
		attack_runtime.teardown(true)
	_combo_system = null
	_ball_flow = null
	_flippers.clear()
	_active_ball = null
	_is_setup = false


func is_ready() -> bool:
	return _is_setup and _bindings_are_valid()


func is_battle_active() -> bool:
	return _battle_active and is_ready() \
		and not completion_controller.is_completed()


func get_active_cotton_count() -> int:
	_prune_invalid_cottons()
	return _active_cottons.size()


func get_current_pattern_number() -> int:
	return _current_pattern


func _references_are_valid(
	combo_system: ComboSystem,
	ball_flow: WaveBallFlowController,
	flippers: Array[PinballFlipper]
) -> bool:
	for reference: Variant in [
		phase1_rules, phase2_rules, weight_rules, reflection_rules,
		cotton_rules, first_pattern, repeat_pattern, cotton_scene,
		boss_hurtbox, health, damage_adapter, damage_applier, damage_gate,
		attack_controller, attack_runtime, scheduler, coordinator, selector,
		pattern_1_attack, pattern_2_attack, phase_transition,
		arm_hit_tracker, arm_ball_reflector, counter_resolver, counter_window,
		completion_controller, cotton_parent, cotton_spawn_left,
		cotton_spawn_right, combo_system, ball_flow,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	if flippers.size() != 8:
		return false
	for flipper: PinballFlipper in flippers:
		if flipper == null or not is_instance_valid(flipper) \
				or not flipper.is_inside_tree():
			return false
	return phase1_rules.validate().is_empty() \
		and phase2_rules.validate().is_empty() \
		and weight_rules.validate().is_empty() \
		and reflection_rules.validate().is_empty() \
		and cotton_rules.validate().is_empty() \
		and first_pattern.is_valid() \
		and repeat_pattern.is_valid() \
		and cotton_scene.can_instantiate()


func _configure_components() -> bool:
	if not damage_adapter.bind_combo_system(_combo_system):
		return false
	if not damage_applier.bind(damage_adapter, health):
		return false
	if not health.configure(phase1_rules.boss_max_hp):
		return false
	if not damage_gate.bind_controller(attack_controller):
		return false
	if not damage_applier.bind_damage_gate(damage_gate):
		return false
	if not damage_applier.configure_counter_multiplier(
		phase1_rules.parry_counter_multiplier
	):
		return false
	if not counter_window.configure(phase1_rules.counter_ready_duration_sec):
		return false
	if not damage_applier.bind_counter_window(counter_window):
		return false
	if not arm_hit_tracker.configure(phase1_rules.boss_launch_duration_sec):
		return false
	if not arm_ball_reflector.configure(reflection_rules):
		return false
	if not counter_resolver.bind_tracker(arm_hit_tracker):
		return false
	if not counter_resolver.bind_flippers(_flippers):
		return false
	var threshold_hp: int = int(
		float(phase1_rules.boss_max_hp) * phase1_rules.phase2_hp_ratio
	)
	if not phase_transition.configure_phase_2_threshold(threshold_hp) \
			or not phase_transition.bind_health(health):
		return false
	if not completion_controller.bind_health(health):
		return false
	if not attack_runtime.setup(
		phase1_rules,
		scheduler,
		coordinator,
		selector,
		attack_controller,
		first_pattern,
		repeat_pattern
	):
		return false
	return _bind_selected_attack(pattern_1_attack)


func _rollback_setup() -> void:
	if is_instance_valid(arm_hit_tracker):
		arm_hit_tracker.unbind_attack()
		arm_hit_tracker.clear()
	if is_instance_valid(arm_ball_reflector):
		arm_ball_reflector.unbind_attack()
	if is_instance_valid(counter_window):
		counter_window.reset()
	if is_instance_valid(completion_controller):
		completion_controller.unbind_health()
	if is_instance_valid(phase_transition):
		phase_transition.unbind_health()
	if is_instance_valid(counter_resolver):
		counter_resolver.unbind_flippers()
	if is_instance_valid(damage_applier):
		damage_applier.unbind_counter_window()
		damage_applier.unbind_damage_gate()
		damage_applier.unbind()
	if is_instance_valid(damage_gate):
		damage_gate.unbind_controller()
	if is_instance_valid(damage_adapter):
		damage_adapter.unbind_combo_system()
	if is_instance_valid(attack_runtime):
		attack_runtime.teardown(true)
	_combo_system = null
	_ball_flow = null
	_flippers.clear()


func _reset_battle_state() -> bool:
	if attack_runtime.is_running():
		attack_runtime.stop(true)
	if not attack_runtime.reset(true):
		return false
	if not scheduler.configure(
		phase1_rules.first_attack_delay_sec,
		phase1_rules.new_ball_grace_sec,
		phase1_rules.phase1_attack_delay_min_sec,
		phase1_rules.phase1_attack_delay_max_sec
	):
		return false
	completion_controller.reset()
	phase_transition.reset()
	if not health.reset_health():
		return false
	counter_window.reset()
	arm_hit_tracker.clear()
	_remove_all_cottons()
	_cotton_spawned_for_battle = false
	_phase_2_schedule_pending = false
	_phase_2_schedule_active = false
	_next_phase_2_pattern = 1
	_current_pattern = 1
	_active_contact_ids.clear()
	return _bind_selected_attack(pattern_1_attack)


func _bindings_are_valid() -> bool:
	return _combo_system != null and is_instance_valid(_combo_system) \
		and _ball_flow != null and is_instance_valid(_ball_flow) \
		and attack_runtime.is_ready() \
		and damage_adapter.is_bound() \
		and damage_applier.is_bound() \
		and damage_gate.is_bound() \
		and damage_applier.is_damage_gate_bound() \
		and damage_applier.is_counter_window_bound() \
		and completion_controller.is_bound()


func _connect_signals() -> void:
	if not _ball_flow.active_ball_changed.is_connected(_on_active_ball_changed):
		_ball_flow.active_ball_changed.connect(_on_active_ball_changed)
	if not boss_hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
		boss_hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	if not boss_hurtbox.body_exited.is_connected(_on_hurtbox_body_exited):
		boss_hurtbox.body_exited.connect(_on_hurtbox_body_exited)
	if not counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.connect(_on_counter_earned)
	if not phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.connect(_on_phase_2_entered)
	if not scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		scheduler.state_changed.connect(_on_scheduler_state_changed)
	if not attack_controller.attack_finished.is_connected(_on_attack_finished):
		attack_controller.attack_finished.connect(_on_attack_finished)
	if not attack_controller.attack_cancelled.is_connected(_on_attack_cancelled):
		attack_controller.attack_cancelled.connect(_on_attack_cancelled)
	if not completion_controller.battle_completed.is_connected(
		_on_completion_reported
	):
		completion_controller.battle_completed.connect(_on_completion_reported)


func _disconnect_signals() -> void:
	if is_instance_valid(_ball_flow):
		if _ball_flow.active_ball_changed.is_connected(_on_active_ball_changed):
			_ball_flow.active_ball_changed.disconnect(_on_active_ball_changed)
	if is_instance_valid(boss_hurtbox):
		if boss_hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			boss_hurtbox.body_entered.disconnect(_on_hurtbox_body_entered)
		if boss_hurtbox.body_exited.is_connected(_on_hurtbox_body_exited):
			boss_hurtbox.body_exited.disconnect(_on_hurtbox_body_exited)
	if is_instance_valid(counter_resolver) \
			and counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.disconnect(_on_counter_earned)
	if is_instance_valid(phase_transition) \
			and phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.disconnect(_on_phase_2_entered)
	if is_instance_valid(scheduler) \
			and scheduler.state_changed.is_connected(_on_scheduler_state_changed):
		scheduler.state_changed.disconnect(_on_scheduler_state_changed)
	if is_instance_valid(attack_controller):
		if attack_controller.attack_finished.is_connected(_on_attack_finished):
			attack_controller.attack_finished.disconnect(_on_attack_finished)
		if attack_controller.attack_cancelled.is_connected(_on_attack_cancelled):
			attack_controller.attack_cancelled.disconnect(_on_attack_cancelled)
	if is_instance_valid(completion_controller) \
			and completion_controller.battle_completed.is_connected(
				_on_completion_reported
			):
		completion_controller.battle_completed.disconnect(_on_completion_reported)


func _on_active_ball_changed(ball: Pinball) -> void:
	_active_contact_ids.clear()
	_active_ball = ball if ball != null and is_instance_valid(ball) else null
	if _battle_active and _active_ball != null and attack_runtime.is_running():
		attack_runtime.begin_new_ball_grace()


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if not _battle_active or completion_controller.is_completed() \
			or not body is Pinball:
		return
	var ball: Pinball = body as Pinball
	if not is_instance_valid(ball) or ball != _active_ball:
		return
	var contact_id: int = ball.get_instance_id()
	if _active_contact_ids.has(contact_id):
		return
	_active_contact_ids[contact_id] = true
	var multiplier: float = weight_rules.get_damage_multiplier(ball.mass)
	if multiplier <= 0.0:
		return
	damage_applier.resolve_and_apply_hit(
		phase1_rules.target_valid_hit_count,
		multiplier,
		false,
		1.0
	)


func _on_hurtbox_body_exited(body: Node2D) -> void:
	if body != null and is_instance_valid(body):
		_active_contact_ids.erase(body.get_instance_id())


func _on_counter_earned(ball: Pinball) -> void:
	if _battle_active and ball != null and is_instance_valid(ball):
		counter_window.activate()


func _on_phase_2_entered(_current_hp: int) -> void:
	if not _battle_active or completion_controller.is_completed():
		return
	_phase_2_schedule_pending = true
	_spawn_phase_2_cottons()
	_try_activate_phase_2_schedule()


func _try_activate_phase_2_schedule() -> bool:
	if not _phase_2_schedule_pending \
			or attack_controller.current_state != BossAttackController.State.IDLE \
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
	if not _battle_active \
			or current_state \
				!= BossPhase1AttackScheduler.State.WAITING_FOR_ATTACK_FINISH:
		return
	if previous_state != BossPhase1AttackScheduler.State.WAITING_FIRST_ATTACK \
			and previous_state \
				!= BossPhase1AttackScheduler.State.WAITING_REPEAT_ATTACK:
		return
	if not phase_transition.is_phase_2():
		_bind_selected_attack(pattern_1_attack)
		return
	var selected_pattern: int = _next_phase_2_pattern
	_next_phase_2_pattern = 2 if selected_pattern == 1 else 1
	_bind_selected_attack(
		pattern_1_attack if selected_pattern == 1 else pattern_2_attack
	)


func _bind_selected_attack(attack: TeddyArmSweepAttack) -> bool:
	if attack == null or not is_instance_valid(attack) \
			or attack_controller.current_state != BossAttackController.State.IDLE:
		return false
	if not arm_hit_tracker.bind_attack(attack):
		return false
	if not arm_ball_reflector.bind_attack(attack):
		return false
	attack_controller.attack = attack
	pattern_1_attack.visible = show_attack_placeholder_visuals \
		and attack == pattern_1_attack
	pattern_2_attack.visible = show_attack_placeholder_visuals \
		and attack == pattern_2_attack
	_current_pattern = 1 if attack == pattern_1_attack else 2
	return true


func _spawn_phase_2_cottons() -> void:
	if _cotton_spawned_for_battle or completion_controller.is_completed():
		return
	var spawned: Array[CursedCottonAdd] = []
	for spawn_point: Marker2D in [cotton_spawn_left, cotton_spawn_right]:
		var cotton: CursedCottonAdd = cotton_scene.instantiate() as CursedCottonAdd
		if cotton == null or not cotton.configure(cotton_rules):
			for pending: CursedCottonAdd in spawned:
				pending.queue_free()
			return
		cotton_parent.add_child(cotton)
		cotton.global_position = spawn_point.global_position
		_connect_cotton(cotton)
		spawned.append(cotton)
	_active_cottons.append_array(spawned)
	_cotton_spawned_for_battle = true


func _connect_cotton(cotton: CursedCottonAdd) -> void:
	var cleared_callback: Callable = _on_cotton_cleared.bind(cotton)
	var exited_callback: Callable = _on_cotton_tree_exited.bind(cotton)
	if not cotton.cotton_cleared.is_connected(cleared_callback):
		cotton.cotton_cleared.connect(cleared_callback)
	if not cotton.tree_exited.is_connected(exited_callback):
		cotton.tree_exited.connect(exited_callback)


func _disconnect_cotton(cotton: CursedCottonAdd) -> void:
	if not is_instance_valid(cotton):
		return
	var cleared_callback: Callable = _on_cotton_cleared.bind(cotton)
	var exited_callback: Callable = _on_cotton_tree_exited.bind(cotton)
	if cotton.cotton_cleared.is_connected(cleared_callback):
		cotton.cotton_cleared.disconnect(cleared_callback)
	if cotton.tree_exited.is_connected(exited_callback):
		cotton.tree_exited.disconnect(exited_callback)


func _on_cotton_cleared(cotton: CursedCottonAdd) -> void:
	_active_cottons.erase(cotton)


func _on_cotton_tree_exited(cotton: CursedCottonAdd) -> void:
	_active_cottons.erase(cotton)


func _remove_all_cottons() -> void:
	var existing: Array[CursedCottonAdd] = []
	existing.assign(_active_cottons)
	_active_cottons.clear()
	for cotton: CursedCottonAdd in existing:
		if not is_instance_valid(cotton):
			continue
		_disconnect_cotton(cotton)
		if not cotton.is_queued_for_deletion():
			cotton.queue_free()


func _prune_invalid_cottons() -> void:
	var valid: Array[CursedCottonAdd] = []
	for cotton: CursedCottonAdd in _active_cottons:
		if is_instance_valid(cotton) and not cotton.is_queued_for_deletion():
			valid.append(cotton)
	_active_cottons = valid


func _on_completion_reported() -> void:
	if not _battle_active:
		return
	stop_battle()
	battle_completed.emit()
