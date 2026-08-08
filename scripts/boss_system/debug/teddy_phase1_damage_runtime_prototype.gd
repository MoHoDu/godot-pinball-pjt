class_name TeddyPhase1DamageRuntimePrototype
extends Node


signal phase_threshold_reached


const MAX_EVENT_COUNT: int = 30
const PHASE_THRESHOLD_EVENT: String = "PHASE 2 THRESHOLD REACHED"


@export_category("Resources")
@export var rules: Stage1BossPhase1Rules = null
@export var weight_rules: BossBallDamageWeightRules = null

@export_category("Runtime Components")
@export var combo_system: ComboSystem = null
@export var ball_flow: WaveBallFlowController = null
@export var boss_hurtbox: Area2D = null
@export var health: BossHealthComponent = null
@export var damage_adapter: BossComboDamageAdapter = null
@export var damage_applier: BossDamageApplier = null

@export_category("Damage Status")
@export var boss_health_label: Label = null
@export var health_ratio_label: Label = null
@export var last_damage_label: Label = null
@export var total_boss_hits_label: Label = null
@export var current_ball_weight_label: Label = null
@export var current_multiplier_label: Label = null
@export var phase_threshold_label: Label = null
@export var invulnerability_label: Label = null
@export var damage_event_log: RichTextLabel = null


var _is_setup: bool = false
var _pending_ball_id: StringName = &""
var _active_ball: Pinball = null
var _active_ball_id: StringName = &""
var _active_contact_ids: Dictionary[int, bool] = {}
var _event_messages: Array[String] = []
var _total_boss_hits: int = 0
var _last_calculated_damage: int = 0
var _last_applied_damage: int = 0
var _threshold_reached: bool = false


func _ready() -> void:
	if not _setup():
		_append_event("SETUP FAILED")
		push_error("Teddy phase 1 damage runtime prototype setup failed.")


func _exit_tree() -> void:
	teardown()


func teardown() -> void:
	_disconnect_runtime_signals()
	_active_contact_ids.clear()
	_pending_ball_id = &""
	_active_ball = null
	_active_ball_id = &""
	_is_setup = false

	if damage_applier != null and is_instance_valid(damage_applier):
		damage_applier.unbind()
	if damage_adapter != null and is_instance_valid(damage_adapter):
		damage_adapter.unbind_combo_system()


func _setup() -> bool:
	if not _validate_references():
		return false
	if not rules.validate().is_empty() or not weight_rules.validate().is_empty():
		return false
	if not damage_adapter.bind_combo_system(combo_system):
		return false
	if not damage_applier.bind(damage_adapter, health):
		damage_adapter.unbind_combo_system()
		return false
	if not health.configure(rules.boss_max_hp):
		damage_applier.unbind()
		damage_adapter.unbind_combo_system()
		return false

	_connect_runtime_signals()
	_active_contact_ids.clear()
	_pending_ball_id = &""
	_active_ball = null
	_active_ball_id = &""
	_total_boss_hits = 0
	_last_calculated_damage = 0
	_last_applied_damage = 0
	_threshold_reached = health.get_health_ratio() <= rules.phase2_hp_ratio
	_is_setup = true
	_update_damage_ui()
	_append_event("DAMAGE SETUP SUCCEEDED")
	return true


func _validate_references() -> bool:
	for reference: Variant in [
		rules,
		weight_rules,
		combo_system,
		ball_flow,
		boss_hurtbox,
		health,
		damage_adapter,
		damage_applier,
		boss_health_label,
		health_ratio_label,
		last_damage_label,
		total_boss_hits_label,
		current_ball_weight_label,
		current_multiplier_label,
		phase_threshold_label,
		invulnerability_label,
		damage_event_log,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	return true


func _connect_runtime_signals() -> void:
	if not ball_flow.ball_selection_confirmed.is_connected(
		_on_ball_selection_confirmed
	):
		ball_flow.ball_selection_confirmed.connect(_on_ball_selection_confirmed)
	if not ball_flow.active_ball_changed.is_connected(_on_active_ball_changed):
		ball_flow.active_ball_changed.connect(_on_active_ball_changed)
	if not boss_hurtbox.body_entered.is_connected(_on_boss_hurtbox_body_entered):
		boss_hurtbox.body_entered.connect(_on_boss_hurtbox_body_entered)
	if not boss_hurtbox.body_exited.is_connected(_on_boss_hurtbox_body_exited):
		boss_hurtbox.body_exited.connect(_on_boss_hurtbox_body_exited)
	if not damage_applier.boss_hit_resolved.is_connected(_on_boss_hit_resolved):
		damage_applier.boss_hit_resolved.connect(_on_boss_hit_resolved)


func _disconnect_runtime_signals() -> void:
	if ball_flow != null and is_instance_valid(ball_flow):
		if ball_flow.ball_selection_confirmed.is_connected(
			_on_ball_selection_confirmed
		):
			ball_flow.ball_selection_confirmed.disconnect(
				_on_ball_selection_confirmed
			)
		if ball_flow.active_ball_changed.is_connected(_on_active_ball_changed):
			ball_flow.active_ball_changed.disconnect(_on_active_ball_changed)
	if boss_hurtbox != null and is_instance_valid(boss_hurtbox):
		if boss_hurtbox.body_entered.is_connected(_on_boss_hurtbox_body_entered):
			boss_hurtbox.body_entered.disconnect(_on_boss_hurtbox_body_entered)
		if boss_hurtbox.body_exited.is_connected(_on_boss_hurtbox_body_exited):
			boss_hurtbox.body_exited.disconnect(_on_boss_hurtbox_body_exited)
	if damage_applier != null and is_instance_valid(damage_applier):
		if damage_applier.boss_hit_resolved.is_connected(_on_boss_hit_resolved):
			damage_applier.boss_hit_resolved.disconnect(_on_boss_hit_resolved)


func _on_ball_selection_confirmed(
	definition: BallDefinition,
	_remaining_balls: int
) -> void:
	_pending_ball_id = definition.ball_id if definition != null else &""


func _on_active_ball_changed(ball: Pinball) -> void:
	_active_contact_ids.clear()
	_active_ball = ball if ball != null and is_instance_valid(ball) else null
	_active_ball_id = _pending_ball_id if _active_ball != null else &""
	_pending_ball_id = &""
	_update_current_ball_profile()


func _on_boss_hurtbox_body_entered(body: Node2D) -> void:
	if not _is_setup or not body is Pinball:
		return
	var ball: Pinball = body as Pinball
	if ball == null or not is_instance_valid(ball) or ball != _active_ball:
		return

	var contact_id: int = ball.get_instance_id()
	if _active_contact_ids.has(contact_id):
		return
	_active_contact_ids[contact_id] = true

	if _active_ball_id.is_empty() or not weight_rules.has_profile(_active_ball_id):
		_append_event("UNKNOWN PROFILE: %s" % _display_ball_id(_active_ball_id))
		_update_current_ball_profile()
		return

	var multiplier: float = weight_rules.get_damage_multiplier(_active_ball_id)
	if multiplier <= 0.0:
		_append_event("UNKNOWN PROFILE: %s" % _display_ball_id(_active_ball_id))
		_update_current_ball_profile()
		return

	damage_applier.resolve_and_apply_hit(
		rules.target_valid_hit_count,
		multiplier,
		false,
		1.0
	)


func _on_boss_hurtbox_body_exited(body: Node2D) -> void:
	if body != null and is_instance_valid(body):
		_active_contact_ids.erase(body.get_instance_id())


func _on_boss_hit_resolved(
	calculated_damage: int,
	applied_damage: int,
	previous_health: int,
	current_health: int,
	_max_health: int,
	_was_counter: bool
) -> void:
	_last_calculated_damage = calculated_damage
	_last_applied_damage = applied_damage
	_total_boss_hits += 1

	var weight_class: int = weight_rules.get_weight_class(_active_ball_id)
	var weight_name: String = _weight_class_name(weight_class)
	var multiplier: float = weight_rules.get_damage_multiplier(_active_ball_id)
	_append_event("BOSS HIT")
	_append_event("Ball: %s" % _display_ball_id(_active_ball_id))
	_append_event("Weight: %s" % weight_name)
	_append_event("Multiplier: %.2f" % multiplier)
	_append_event("Damage: %d" % calculated_damage)
	_append_event("Applied: %d" % applied_damage)
	_append_event("HP: %d -> %d" % [previous_health, current_health])
	_append_event("Combo: %d" % combo_system.combo_count)

	var threshold_health: int = int(
		float(health.get_max_health()) * rules.phase2_hp_ratio
	)
	if not _threshold_reached \
			and previous_health > threshold_health \
			and current_health <= threshold_health:
		_threshold_reached = true
		_append_event(PHASE_THRESHOLD_EVENT)
		_append_event("HP: %d / %d" % [current_health, health.get_max_health()])
		phase_threshold_reached.emit()
	_update_damage_ui()


func _update_damage_ui() -> void:
	if is_instance_valid(boss_health_label):
		boss_health_label.text = "Boss HP: %d / %d" % [
			health.get_current_health(),
			health.get_max_health(),
		]
	if is_instance_valid(health_ratio_label):
		health_ratio_label.text = "HP Ratio: %.3f" % health.get_health_ratio()
	if is_instance_valid(last_damage_label):
		last_damage_label.text = "Last Damage: Calculated %d / Applied %d" % [
			_last_calculated_damage,
			_last_applied_damage,
		]
	if is_instance_valid(total_boss_hits_label):
		total_boss_hits_label.text = "Total Boss Hits: %d" % _total_boss_hits
	if is_instance_valid(phase_threshold_label):
		phase_threshold_label.text = "Phase Threshold: %s" % (
			"BELOW_50" if _threshold_reached else "ABOVE_50"
		)
	if is_instance_valid(invulnerability_label):
		invulnerability_label.text = "INVULNERABILITY: NOT IMPLEMENTED"
	_update_current_ball_profile()


func _update_current_ball_profile() -> void:
	var weight_name: String = "None"
	var multiplier: float = 0.0
	if _active_ball != null and is_instance_valid(_active_ball):
		var weight_class: int = weight_rules.get_weight_class(_active_ball_id)
		if weight_class == BossBallDamageWeightRules.INVALID_WEIGHT_CLASS:
			weight_name = "UNKNOWN"
		else:
			weight_name = _weight_class_name(weight_class)
			multiplier = weight_rules.get_damage_multiplier(_active_ball_id)

	if is_instance_valid(current_ball_weight_label):
		current_ball_weight_label.text = (
			"Current Ball Damage Weight: %s" % weight_name
		)
	if is_instance_valid(current_multiplier_label):
		current_multiplier_label.text = (
			"Current Ball Damage Multiplier: %.2f" % multiplier
		)
	if _active_ball != null and is_instance_valid(_active_ball):
		_append_profile_event(weight_name, multiplier)


func _append_profile_event(weight_name: String, multiplier: float) -> void:
	_append_event("BALL PROFILE: %s / %s / %.2f" % [
		_display_ball_id(_active_ball_id),
		weight_name,
		multiplier,
	])


func _weight_class_name(weight_class: int) -> String:
	if weight_class < 0 \
			or weight_class >= BossBallDamageWeightRules.WeightClass.size():
		return "UNKNOWN"
	return str(BossBallDamageWeightRules.WeightClass.keys()[weight_class])


func _display_ball_id(ball_id: StringName) -> String:
	return "<empty>" if ball_id.is_empty() else String(ball_id)


func _append_event(message: String) -> void:
	_event_messages.append(message)
	while _event_messages.size() > MAX_EVENT_COUNT:
		var removal_index: int = 0
		if _event_messages[removal_index] == PHASE_THRESHOLD_EVENT:
			removal_index = 1
		_event_messages.remove_at(removal_index)
	if is_instance_valid(damage_event_log):
		damage_event_log.text = "\n".join(_event_messages)
