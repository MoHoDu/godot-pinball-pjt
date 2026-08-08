class_name TeddyArmSweepPrototype
extends Node2D


@export var attack_controller: BossAttackController
@export var attack: TeddyArmSweepAttack
@export var attack_button: Button
@export var status_label: Label


var _last_target_name := "-"


func _ready() -> void:
	assert(is_instance_valid(attack_controller), "Prototype requires a controller.")
	assert(is_instance_valid(attack), "Prototype requires an attack node.")
	assert(is_instance_valid(attack_button), "Prototype requires a test Button.")
	assert(is_instance_valid(status_label), "Prototype requires a status Label.")
	attack_button.pressed.connect(_on_attack_button_pressed)
	attack_controller.state_changed.connect(_on_state_changed)
	attack_controller.attack_cancelled.connect(_on_attack_cancelled)
	attack.attack_hit.connect(_on_attack_hit)
	_update_label()


func _on_attack_button_pressed() -> void:
	if attack_controller.start_attack():
		print("[TeddyArmSweep] attack started")
	else:
		print("[TeddyArmSweep] start ignored: attack is already running")


func _on_state_changed(
	_previous_state: BossAttackController.State,
	current_state: BossAttackController.State
) -> void:
	_update_label()
	print("[TeddyArmSweep] state: %s" % BossAttackController.State.keys()[current_state])


func _on_attack_cancelled() -> void:
	_last_target_name = "-"
	_update_label()
	print("[TeddyArmSweep] attack cancelled")


func _on_attack_hit(target: Node) -> void:
	_last_target_name = target.name
	_update_label()
	print("[TeddyArmSweep] attack_hit: %s" % target.name)


func _update_label() -> void:
	if not is_instance_valid(status_label) \
			or not is_instance_valid(attack_controller):
		return
	status_label.text = "현재 공격 상태: %s\n마지막 접촉 대상: %s" % [
		BossAttackController.State.keys()[attack_controller.current_state],
		_last_target_name,
	]
