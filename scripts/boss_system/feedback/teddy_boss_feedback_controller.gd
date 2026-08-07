class_name TeddyBossFeedbackController
extends Node


signal boss_battle_started
signal attack_telegraph_started(pattern_id: int)
signal attack_active_started(pattern_id: int)
signal attack_recovery_started(pattern_id: int)
signal arm_ball_hit(ball: Pinball)
signal arm_ball_reflected(ball: Pinball)
signal boss_hit_feedback(damage: int, was_counter: bool)
signal counter_earned_feedback
signal counter_expired_feedback
signal phase_2_feedback
signal cotton_spawn_feedback
signal cotton_hit_feedback
signal boss_defeated_feedback


const PATTERN_ARM_SWEEP: int = 1
const PATTERN_DOUBLE_ARM_UP_SWEEP: int = 2


@export var boss_runtime: Stage1TeddyBossRuntime = null
@export var attack_controller: BossAttackController = null
@export var pattern_1_attack: TeddyArmSweepAttack = null
@export var pattern_2_attack: TeddyArmSweepAttack = null
@export var arm_ball_reflector: BossArmBallReflector = null
@export var damage_applier: BossDamageApplier = null
@export var counter_resolver: BossParryCounterResolver = null
@export var counter_window: BossCounterWindow = null
@export var phase_transition: BossPhaseTransitionController = null
@export var completion_controller: BossBattleCompletionController = null
@export var cotton_parent: Node = null


var _connected_cottons: Dictionary[int, CursedCottonAdd] = {}
var _is_setup: bool = false
var _battle_started_reported: bool = false
var _phase_2_reported: bool = false
var _defeat_reported: bool = false


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	teardown()


func setup() -> bool:
	if not _references_are_valid():
		return false
	_connect_signals()
	for child: Node in cotton_parent.get_children():
		_register_cotton(child, false)
	_is_setup = true
	return true


func teardown() -> void:
	_disconnect_signals()
	_disconnect_all_cottons()
	_is_setup = false
	_battle_started_reported = false
	_phase_2_reported = false
	_defeat_reported = false


func is_ready() -> bool:
	return _is_setup and _references_are_valid()


func _references_are_valid() -> bool:
	for reference: Variant in [
		boss_runtime,
		attack_controller,
		pattern_1_attack,
		pattern_2_attack,
		arm_ball_reflector,
		damage_applier,
		counter_resolver,
		counter_window,
		phase_transition,
		completion_controller,
		cotton_parent,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	return pattern_1_attack != pattern_2_attack


func _connect_signals() -> void:
	if not boss_runtime.visibility_changed.is_connected(
		_on_boss_runtime_visibility_changed
	):
		boss_runtime.visibility_changed.connect(
			_on_boss_runtime_visibility_changed
		)
	if not attack_controller.telegraph_started.is_connected(
		_on_attack_telegraph_started
	):
		attack_controller.telegraph_started.connect(
			_on_attack_telegraph_started
		)
	if not attack_controller.active_started.is_connected(
		_on_attack_active_started
	):
		attack_controller.active_started.connect(_on_attack_active_started)
	if not attack_controller.recovery_started.is_connected(
		_on_attack_recovery_started
	):
		attack_controller.recovery_started.connect(
			_on_attack_recovery_started
		)
	if not pattern_1_attack.attack_hit.is_connected(_on_arm_ball_hit):
		pattern_1_attack.attack_hit.connect(_on_arm_ball_hit)
	if not pattern_2_attack.attack_hit.is_connected(_on_arm_ball_hit):
		pattern_2_attack.attack_hit.connect(_on_arm_ball_hit)
	if not arm_ball_reflector.ball_reflected.is_connected(_on_arm_ball_reflected):
		arm_ball_reflector.ball_reflected.connect(_on_arm_ball_reflected)
	if not damage_applier.boss_hit_resolved.is_connected(_on_boss_hit_resolved):
		damage_applier.boss_hit_resolved.connect(_on_boss_hit_resolved)
	if not counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.connect(_on_counter_earned)
	if not counter_window.counter_expired.is_connected(_on_counter_expired):
		counter_window.counter_expired.connect(_on_counter_expired)
	if not phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.connect(_on_phase_2_entered)
	if not completion_controller.battle_completed.is_connected(
		_on_battle_completed
	):
		completion_controller.battle_completed.connect(_on_battle_completed)
	if not cotton_parent.child_entered_tree.is_connected(_on_cotton_child_entered):
		cotton_parent.child_entered_tree.connect(_on_cotton_child_entered)
	if not cotton_parent.child_exiting_tree.is_connected(_on_cotton_child_exiting):
		cotton_parent.child_exiting_tree.connect(_on_cotton_child_exiting)


func _disconnect_signals() -> void:
	if is_instance_valid(boss_runtime) \
			and boss_runtime.visibility_changed.is_connected(
				_on_boss_runtime_visibility_changed
			):
		boss_runtime.visibility_changed.disconnect(
			_on_boss_runtime_visibility_changed
		)
	if is_instance_valid(attack_controller):
		if attack_controller.telegraph_started.is_connected(
			_on_attack_telegraph_started
		):
			attack_controller.telegraph_started.disconnect(
				_on_attack_telegraph_started
			)
		if attack_controller.active_started.is_connected(
			_on_attack_active_started
		):
			attack_controller.active_started.disconnect(_on_attack_active_started)
		if attack_controller.recovery_started.is_connected(
			_on_attack_recovery_started
		):
			attack_controller.recovery_started.disconnect(
				_on_attack_recovery_started
			)
	if is_instance_valid(pattern_1_attack) \
			and pattern_1_attack.attack_hit.is_connected(_on_arm_ball_hit):
		pattern_1_attack.attack_hit.disconnect(_on_arm_ball_hit)
	if is_instance_valid(pattern_2_attack) \
			and pattern_2_attack.attack_hit.is_connected(_on_arm_ball_hit):
		pattern_2_attack.attack_hit.disconnect(_on_arm_ball_hit)
	if is_instance_valid(arm_ball_reflector) \
			and arm_ball_reflector.ball_reflected.is_connected(
				_on_arm_ball_reflected
			):
		arm_ball_reflector.ball_reflected.disconnect(_on_arm_ball_reflected)
	if is_instance_valid(damage_applier) \
			and damage_applier.boss_hit_resolved.is_connected(
				_on_boss_hit_resolved
			):
		damage_applier.boss_hit_resolved.disconnect(_on_boss_hit_resolved)
	if is_instance_valid(counter_resolver) \
			and counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.disconnect(_on_counter_earned)
	if is_instance_valid(counter_window) \
			and counter_window.counter_expired.is_connected(_on_counter_expired):
		counter_window.counter_expired.disconnect(_on_counter_expired)
	if is_instance_valid(phase_transition) \
			and phase_transition.phase_2_entered.is_connected(_on_phase_2_entered):
		phase_transition.phase_2_entered.disconnect(_on_phase_2_entered)
	if is_instance_valid(completion_controller) \
			and completion_controller.battle_completed.is_connected(
				_on_battle_completed
			):
		completion_controller.battle_completed.disconnect(_on_battle_completed)
	if is_instance_valid(cotton_parent):
		if cotton_parent.child_entered_tree.is_connected(_on_cotton_child_entered):
			cotton_parent.child_entered_tree.disconnect(_on_cotton_child_entered)
		if cotton_parent.child_exiting_tree.is_connected(_on_cotton_child_exiting):
			cotton_parent.child_exiting_tree.disconnect(_on_cotton_child_exiting)


func _on_boss_runtime_visibility_changed() -> void:
	if not boss_runtime.visible:
		_battle_started_reported = false
		return
	if _battle_started_reported:
		return
	_battle_started_reported = true
	_phase_2_reported = false
	_defeat_reported = false
	boss_battle_started.emit()


func _on_attack_telegraph_started() -> void:
	attack_telegraph_started.emit(_get_current_pattern_id())


func _on_attack_active_started() -> void:
	attack_active_started.emit(_get_current_pattern_id())


func _on_attack_recovery_started() -> void:
	attack_recovery_started.emit(_get_current_pattern_id())


func _get_current_pattern_id() -> int:
	var pattern_id: int = boss_runtime.get_current_pattern_number()
	if pattern_id == PATTERN_ARM_SWEEP \
			or pattern_id == PATTERN_DOUBLE_ARM_UP_SWEEP:
		return pattern_id
	return 0


func _on_arm_ball_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target is Pinball:
		return
	arm_ball_hit.emit(target as Pinball)


func _on_arm_ball_reflected(ball: Pinball) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	arm_ball_reflected.emit(ball)


func _on_boss_hit_resolved(
	_calculated_damage: int,
	applied_damage: int,
	_previous_health: int,
	_current_health: int,
	_max_health: int,
	was_counter: bool
) -> void:
	boss_hit_feedback.emit(applied_damage, was_counter)


func _on_counter_earned(_ball: Pinball) -> void:
	counter_earned_feedback.emit()


func _on_counter_expired() -> void:
	counter_expired_feedback.emit()


func _on_phase_2_entered(_current_hp: int) -> void:
	if _phase_2_reported:
		return
	_phase_2_reported = true
	phase_2_feedback.emit()


func _on_battle_completed() -> void:
	if _defeat_reported:
		return
	_defeat_reported = true
	boss_defeated_feedback.emit()


func _on_cotton_child_entered(child: Node) -> void:
	_register_cotton(child, true)


func _on_cotton_child_exiting(child: Node) -> void:
	_unregister_cotton(child)


func _register_cotton(child: Node, report_spawn: bool) -> void:
	if child == null or not is_instance_valid(child) or not child is CursedCottonAdd:
		return
	var cotton: CursedCottonAdd = child as CursedCottonAdd
	var cotton_id: int = cotton.get_instance_id()
	if _connected_cottons.has(cotton_id):
		return
	_connected_cottons[cotton_id] = cotton
	if not cotton.cotton_hit.is_connected(_on_cotton_hit):
		cotton.cotton_hit.connect(_on_cotton_hit)
	if report_spawn:
		cotton_spawn_feedback.emit()


func _unregister_cotton(child: Node) -> void:
	if child == null or not is_instance_valid(child) or not child is CursedCottonAdd:
		return
	var cotton: CursedCottonAdd = child as CursedCottonAdd
	_connected_cottons.erase(cotton.get_instance_id())
	if cotton.cotton_hit.is_connected(_on_cotton_hit):
		cotton.cotton_hit.disconnect(_on_cotton_hit)


func _disconnect_all_cottons() -> void:
	var connected: Array[CursedCottonAdd] = []
	for value: CursedCottonAdd in _connected_cottons.values():
		connected.append(value)
	_connected_cottons.clear()
	for cotton: CursedCottonAdd in connected:
		if is_instance_valid(cotton) \
				and cotton.cotton_hit.is_connected(_on_cotton_hit):
			cotton.cotton_hit.disconnect(_on_cotton_hit)


func _on_cotton_hit(_ball: Pinball) -> void:
	cotton_hit_feedback.emit()
