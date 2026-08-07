class_name TeddyPhase1ArmReflectionRuntimePrototype
extends TeddyPhase1ParryCounterRuntimePrototype


const ARM_REFLECTED_EVENT: String = "BOSS ARM BALL REFLECTED"


@export_category("Arm Reflection Integration")
@export var reflection_rules: BossArmBallReflectionRules = null
@export var arm_ball_reflector: BossArmBallReflector = null


func teardown() -> void:
	_disconnect_reflection_log()
	if is_instance_valid(arm_ball_reflector):
		arm_ball_reflector.unbind_attack()
	super.teardown()


func _setup() -> bool:
	if not super._setup():
		return false
	if not _validate_reflection_references():
		_rollback_reflection_setup()
		return false
	if not arm_ball_reflector.configure(reflection_rules):
		_rollback_reflection_setup()
		return false
	if not arm_ball_reflector.bind_attack(teddy_attack):
		_rollback_reflection_setup()
		return false

	_connect_reflection_log()
	_append_event("ARM REFLECTION SETUP SUCCEEDED")
	return true


func _validate_reflection_references() -> bool:
	return reflection_rules != null \
		and is_instance_valid(reflection_rules) \
		and reflection_rules.validate().is_empty() \
		and arm_ball_reflector != null \
		and is_instance_valid(arm_ball_reflector) \
		and teddy_attack != null \
		and is_instance_valid(teddy_attack)


func _connect_reflection_log() -> void:
	if not teddy_attack.attack_hit.is_connected(_on_reflection_attack_hit):
		teddy_attack.attack_hit.connect(_on_reflection_attack_hit)


func _disconnect_reflection_log() -> void:
	if is_instance_valid(teddy_attack) \
			and teddy_attack.attack_hit.is_connected(_on_reflection_attack_hit):
		teddy_attack.attack_hit.disconnect(_on_reflection_attack_hit)


func _rollback_reflection_setup() -> void:
	_disconnect_reflection_log()
	if is_instance_valid(arm_ball_reflector):
		arm_ball_reflector.unbind_attack()
	super.teardown()


func _on_reflection_attack_hit(target: Node) -> void:
	if target == null \
			or not is_instance_valid(target) \
			or not target is Pinball \
			or not target.is_inside_tree() \
			or not target.is_in_group(Pinball.PINBALL_GROUP) \
			or not is_instance_valid(arm_ball_reflector) \
			or not arm_ball_reflector.is_bound():
		return
	_append_event(ARM_REFLECTED_EVENT)
