class_name TeddyPhase1DamageGateRuntimePrototype
extends TeddyPhase1DamageRuntimePrototype


const BLOCKED_ACTIVE_EVENT: String = "DAMAGE BLOCKED: BOSS ACTIVE"
const BLOCKED_UNAVAILABLE_EVENT: String = "DAMAGE BLOCKED: GATE UNAVAILABLE"


@export_category("Damage Gate Integration")
@export var damage_gate: BossDamageGate = null
@export var attack_controller: BossAttackController = null
@export var gated_damage_applier: BossGatedDamageApplier = null


func teardown() -> void:
	_disconnect_gate_signals()
	if is_instance_valid(gated_damage_applier):
		gated_damage_applier.unbind_damage_gate()
	if is_instance_valid(damage_gate):
		damage_gate.unbind_controller()
	super.teardown()
	_update_invulnerability_ui()


func _setup() -> bool:
	if not super._setup():
		return false
	if not _validate_gate_references():
		_rollback_gate_setup()
		return false
	if not damage_gate.bind_controller(attack_controller):
		_rollback_gate_setup()
		return false
	if not gated_damage_applier.bind_damage_gate(damage_gate):
		_rollback_gate_setup()
		return false

	_connect_gate_signals()
	_update_invulnerability_ui()
	_append_event("DAMAGE GATE SETUP SUCCEEDED")
	return true


func _update_damage_ui() -> void:
	super._update_damage_ui()
	_update_invulnerability_ui()


func _validate_gate_references() -> bool:
	return is_instance_valid(damage_gate) \
		and is_instance_valid(attack_controller) \
		and is_instance_valid(gated_damage_applier) \
		and damage_applier == gated_damage_applier


func _connect_gate_signals() -> void:
	if not damage_gate.invulnerability_changed.is_connected(
		_on_invulnerability_changed
	):
		damage_gate.invulnerability_changed.connect(
			_on_invulnerability_changed
		)
	if not gated_damage_applier.damage_blocked.is_connected(
		_on_damage_blocked
	):
		gated_damage_applier.damage_blocked.connect(_on_damage_blocked)


func _disconnect_gate_signals() -> void:
	if is_instance_valid(damage_gate) \
			and damage_gate.invulnerability_changed.is_connected(
				_on_invulnerability_changed
			):
		damage_gate.invulnerability_changed.disconnect(
			_on_invulnerability_changed
		)
	if is_instance_valid(gated_damage_applier) \
			and gated_damage_applier.damage_blocked.is_connected(
				_on_damage_blocked
			):
		gated_damage_applier.damage_blocked.disconnect(_on_damage_blocked)


func _rollback_gate_setup() -> void:
	_disconnect_gate_signals()
	if is_instance_valid(gated_damage_applier):
		gated_damage_applier.unbind_damage_gate()
	if is_instance_valid(damage_gate):
		damage_gate.unbind_controller()
	super.teardown()
	_update_invulnerability_ui()


func _on_invulnerability_changed(_is_invulnerable: bool) -> void:
	_update_invulnerability_ui()


func _on_damage_blocked(reason: StringName) -> void:
	match reason:
		BossGatedDamageApplier.BLOCK_REASON_BOSS_ACTIVE:
			_append_event(BLOCKED_ACTIVE_EVENT)
		BossGatedDamageApplier.BLOCK_REASON_GATE_UNAVAILABLE:
			_append_event(BLOCKED_UNAVAILABLE_EVENT)


func _update_invulnerability_ui() -> void:
	if not is_instance_valid(invulnerability_label):
		return
	if not is_instance_valid(damage_gate) or not damage_gate.is_bound():
		invulnerability_label.text = "Boss Invulnerability: UNAVAILABLE"
		return
	invulnerability_label.text = "Boss Invulnerability: %s" % (
		"ACTIVE" if damage_gate.is_invulnerable() else "OFF"
	)
