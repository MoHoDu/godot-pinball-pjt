class_name TeddyPhase1ParryCounterRuntimePrototype
extends TeddyPhase1DamageGateRuntimePrototype


const ARM_TRACKED_EVENT: String = "BOSS ARM BALL TRACKED"
const COUNTER_EARNED_EVENT: String = "COUNTER EARNED: PERFECT"
const COUNTER_CONSUMED_EVENT: String = "COUNTER CONSUMED"
const COUNTER_EXPIRED_EVENT: String = "COUNTER EXPIRED"


@export_category("Parry Counter Components")
@export var arm_hit_tracker: BossArmHitBallTracker = null
@export var counter_resolver: BossParryCounterResolver = null
@export var counter_window: BossCounterWindow = null
@export var counter_damage_applier: BossCounterGatedDamageApplier = null
@export var teddy_attack: TeddyArmSweepAttack = null

@export_category("Explicit Flippers")
@export var bottom_left_flipper: PinballFlipper = null
@export var bottom_right_flipper: PinballFlipper = null
@export var top_left_flipper: PinballFlipper = null
@export var top_right_flipper: PinballFlipper = null
@export var left_left_flipper: PinballFlipper = null
@export var left_right_flipper: PinballFlipper = null
@export var right_left_flipper: PinballFlipper = null
@export var right_right_flipper: PinballFlipper = null

@export_category("Counter Status")
@export var tracked_ball_label: Label = null
@export var counter_state_label: Label = null
@export var counter_time_label: Label = null
@export var last_counter_label: Label = null


var _last_arm_ball: Pinball = null
var _last_counter_state: String = "OFF"


func teardown() -> void:
	_disconnect_counter_signals()
	if is_instance_valid(counter_damage_applier):
		counter_damage_applier.unbind_counter_window()
	if is_instance_valid(counter_resolver):
		counter_resolver.unbind_flippers()
	if is_instance_valid(arm_hit_tracker):
		arm_hit_tracker.unbind_attack()
	if is_instance_valid(counter_window):
		counter_window.reset()
	_last_arm_ball = null
	_last_counter_state = "OFF"
	super.teardown()
	_update_counter_ui()


func _setup() -> bool:
	if not super._setup():
		return false
	if not _validate_counter_references():
		_rollback_counter_setup()
		return false
	if not arm_hit_tracker.configure(rules.boss_launch_duration_sec):
		_rollback_counter_setup()
		return false
	if not counter_window.configure(rules.counter_ready_duration_sec):
		_rollback_counter_setup()
		return false
	if not counter_damage_applier.configure_counter_multiplier(
		rules.parry_counter_multiplier
	):
		_rollback_counter_setup()
		return false
	if not arm_hit_tracker.bind_attack(teddy_attack):
		_rollback_counter_setup()
		return false
	if not counter_resolver.bind_tracker(arm_hit_tracker):
		_rollback_counter_setup()
		return false
	if not counter_resolver.bind_flippers(_get_flippers()):
		_rollback_counter_setup()
		return false
	if not counter_damage_applier.bind_counter_window(counter_window):
		_rollback_counter_setup()
		return false

	_connect_counter_signals()
	_last_arm_ball = null
	_last_counter_state = "OFF"
	_update_counter_ui()
	_append_event("PARRY COUNTER SETUP SUCCEEDED")
	return true


func _process(_delta: float) -> void:
	_update_counter_ui()


func _validate_counter_references() -> bool:
	for reference: Variant in [
		arm_hit_tracker,
		counter_resolver,
		counter_window,
		counter_damage_applier,
		teddy_attack,
		tracked_ball_label,
		counter_state_label,
		counter_time_label,
		last_counter_label,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	if damage_applier != counter_damage_applier \
			or gated_damage_applier != counter_damage_applier:
		return false
	for flipper: PinballFlipper in _get_flippers():
		if flipper == null or not is_instance_valid(flipper):
			return false
	return true


func _get_flippers() -> Array[PinballFlipper]:
	var flippers: Array[PinballFlipper] = [
		bottom_left_flipper,
		bottom_right_flipper,
		top_left_flipper,
		top_right_flipper,
		left_left_flipper,
		left_right_flipper,
		right_left_flipper,
		right_right_flipper,
	]
	return flippers


func _connect_counter_signals() -> void:
	if not teddy_attack.attack_hit.is_connected(_on_arm_attack_hit):
		teddy_attack.attack_hit.connect(_on_arm_attack_hit)
	if not counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.connect(_on_counter_earned)
	if not counter_window.counter_consumed.is_connected(_on_counter_consumed):
		counter_window.counter_consumed.connect(_on_counter_consumed)
	if not counter_window.counter_expired.is_connected(_on_counter_expired):
		counter_window.counter_expired.connect(_on_counter_expired)


func _disconnect_counter_signals() -> void:
	if is_instance_valid(teddy_attack) \
			and teddy_attack.attack_hit.is_connected(_on_arm_attack_hit):
		teddy_attack.attack_hit.disconnect(_on_arm_attack_hit)
	if is_instance_valid(counter_resolver) \
			and counter_resolver.counter_earned.is_connected(_on_counter_earned):
		counter_resolver.counter_earned.disconnect(_on_counter_earned)
	if is_instance_valid(counter_window):
		if counter_window.counter_consumed.is_connected(_on_counter_consumed):
			counter_window.counter_consumed.disconnect(_on_counter_consumed)
		if counter_window.counter_expired.is_connected(_on_counter_expired):
			counter_window.counter_expired.disconnect(_on_counter_expired)


func _rollback_counter_setup() -> void:
	_disconnect_counter_signals()
	if is_instance_valid(counter_damage_applier):
		counter_damage_applier.unbind_counter_window()
	if is_instance_valid(counter_resolver):
		counter_resolver.unbind_flippers()
	if is_instance_valid(arm_hit_tracker):
		arm_hit_tracker.unbind_attack()
	if is_instance_valid(counter_window):
		counter_window.reset()
	super.teardown()
	_update_counter_ui()


func _on_arm_attack_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target is Pinball:
		return
	var ball: Pinball = target as Pinball
	if not arm_hit_tracker.is_ball_tracked(ball):
		return
	_last_arm_ball = ball
	_append_event(ARM_TRACKED_EVENT)
	_update_counter_ui()


func _on_counter_earned(ball: Pinball) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if not counter_window.activate():
		return
	_last_arm_ball = null
	_last_counter_state = "EARNED"
	_append_event(COUNTER_EARNED_EVENT)
	_update_counter_ui()


func _on_counter_consumed() -> void:
	_last_counter_state = "CONSUMED"
	_append_event(COUNTER_CONSUMED_EVENT)
	_update_counter_ui()


func _on_counter_expired() -> void:
	_last_counter_state = "EXPIRED"
	_append_event(COUNTER_EXPIRED_EVENT)
	_update_counter_ui()


func _update_counter_ui() -> void:
	var is_tracked: bool = is_instance_valid(_last_arm_ball) \
		and is_instance_valid(arm_hit_tracker) \
		and arm_hit_tracker.is_ball_tracked(_last_arm_ball)
	if is_instance_valid(tracked_ball_label):
		tracked_ball_label.text = "Tracked Boss Ball: %s" % (
			"YES" if is_tracked else "NO"
		)
	if is_instance_valid(counter_state_label):
		counter_state_label.text = "Counter: %s" % (
			"READY" if is_instance_valid(counter_window) \
				and counter_window.is_ready() else "OFF"
		)
	if is_instance_valid(counter_time_label):
		var remaining: float = 0.0
		if is_instance_valid(counter_window):
			remaining = counter_window.get_remaining_time_sec()
		counter_time_label.text = "Counter Time: %.2f" % remaining
	if is_instance_valid(last_counter_label):
		last_counter_label.text = "Last Counter: %s" % _last_counter_state
