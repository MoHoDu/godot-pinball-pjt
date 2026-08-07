extends SceneTree


const TEST_SCENE_PATH := "res://scenes/wave/test_teddy_arm_sweep.tscn"
const BALL_SCENE_PATH := "res://Resources/balls/mass_var/normal_ball.tscn"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(TEST_SCENE_PATH) as PackedScene
	_expect(packed_scene != null and packed_scene.can_instantiate(),
		"The Teddy arm sweep test scene must load and instantiate.")
	if packed_scene == null or not packed_scene.can_instantiate():
		_finish()
		return

	var wave := packed_scene.instantiate() as Node2D
	root.add_child(wave)
	await process_frame
	await process_frame

	var prototype := wave.get_node_or_null("BossPrototype") as TeddyArmSweepPrototype
	var controller := wave.get_node_or_null(
		"BossPrototype/BossAttackController"
	) as BossAttackController
	var attack := wave.get_node_or_null(
		"BossPrototype/TeddyArmSweepAttack"
	) as TeddyArmSweepAttack
	var button := wave.get_node_or_null(
		"BossPrototype/DebugUI/Panel/VBox/AttackButton"
	) as Button
	var label := wave.get_node_or_null(
		"BossPrototype/DebugUI/Panel/VBox/StatusLabel"
	) as Label

	_expect(prototype != null, "Wave must contain BossPrototype directly.")
	_expect(controller != null, "BossPrototype must contain BossAttackController.")
	_expect(attack != null, "BossPrototype must contain TeddyArmSweepAttack.")
	_expect(button != null and button.text == "공격 테스트",
		"BossPrototype must expose the authored attack test Button.")
	_expect(label != null, "BossPrototype must expose a status Label.")
	if prototype == null \
			or controller == null \
			or attack == null \
			or button == null \
			or label == null:
		wave.queue_free()
		await process_frame
		_finish()
		return

	_expect(attack.hit_area.collision_layer == 0,
		"The attack Area2D must not provide a physical collision layer.")
	_expect(attack.hit_area.collision_mask == 1,
		"The attack Area2D must detect the Pinball default collision layer.")

	var fast_pattern := BossAttackPattern.new()
	fast_pattern.attack_id = &"scene_test_sweep"
	fast_pattern.telegraph_duration = 0.05
	fast_pattern.active_duration = 0.3
	fast_pattern.recovery_duration = 0.05
	fast_pattern.cooldown_duration = 0.05
	controller.pattern = fast_pattern

	var packed_ball := load(BALL_SCENE_PATH) as PackedScene
	var ball := packed_ball.instantiate() as Pinball
	wave.add_child(ball)
	ball.gravity_scale = 0.0
	ball.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.global_position = Vector2(5000.0, 5000.0)
	ball.linear_velocity = Vector2.ZERO
	await physics_frame

	var hit_count := {&"value": 0}
	var last_target := {&"value": null}
	attack.attack_hit.connect(func(target: Node) -> void:
		hit_count.value += 1
		last_target.value = target
	)

	button.emit_signal(&"pressed")
	await process_frame
	_expect(controller.current_state == BossAttackController.State.TELEGRAPH,
		"The attack test Button must call start_attack.")
	_expect(not attack.is_detection_active(),
		"Detection must remain disabled during TELEGRAPH.")
	_expect(await _wait_until_state(controller, BossAttackController.State.ACTIVE),
		"The Button-started attack must reach ACTIVE.")
	_expect(attack.is_detection_active(),
		"Detection must be enabled during ACTIVE.")

	ball.global_position = attack.hit_area.global_position
	ball.reset_physics_interpolation()
	var first_contact_position := ball.global_position
	var first_contact_velocity := ball.linear_velocity
	await physics_frame
	await physics_frame
	_expect(int(hit_count.value) == 1 and last_target.value == ball,
		"An actual Pinball overlap must emit attack_hit once.")
	_expect(ball.global_position.is_equal_approx(first_contact_position),
		"Attack contact must not move the frozen Pinball.")
	_expect(ball.linear_velocity.is_equal_approx(first_contact_velocity),
		"Attack contact must not change Pinball velocity.")
	_expect(is_instance_valid(ball) and not ball.is_queued_for_deletion(),
		"Attack contact must not delete or drain the Pinball.")

	ball.global_position = Vector2(5000.0, 5000.0)
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	ball.global_position = attack.hit_area.global_position
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	_expect(int(hit_count.value) == 1,
		"Leaving and re-entering during one ACTIVE must not hit twice.")

	_expect(await _wait_until_state(controller, BossAttackController.State.RECOVERY),
		"The first attack must reach RECOVERY.")
	_expect(not attack.is_detection_active(),
		"Detection must disable immediately in RECOVERY.")
	_expect(await _wait_until_state(controller, BossAttackController.State.COOLDOWN),
		"The first attack must reach COOLDOWN.")
	_expect(not attack.is_detection_active(),
		"Detection must remain disabled in COOLDOWN.")
	_expect(await _wait_until_state(controller, BossAttackController.State.IDLE),
		"The first attack must return to IDLE.")
	_expect(not attack.is_detection_active(),
		"Detection must remain disabled in IDLE.")

	_expect(controller.start_attack(),
		"A second explicit attack must start after IDLE.")
	_expect(await _wait_until_state(controller, BossAttackController.State.ACTIVE),
		"The second attack must reach ACTIVE.")
	ball.global_position = Vector2(5000.0, 5000.0)
	ball.reset_physics_interpolation()
	await physics_frame
	ball.global_position = attack.hit_area.global_position
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	_expect(int(hit_count.value) == 2,
		"The same Pinball must be hittable once in a newly started attack.")
	_expect(label.text.contains("PinballBall"),
		"The prototype Label must show the last contacted target name.")

	_expect(controller.cancel_attack(),
		"The second active attack must be cancellable.")
	_expect(attack.get_registered_target_count() == 0,
		"Cancelling must clear the per-attack target registry.")
	_expect(controller.start_attack(),
		"A third attack must start after the active cancellation.")
	_expect(await _wait_until_state(controller, BossAttackController.State.ACTIVE),
		"The post-cancellation attack must reach ACTIVE.")
	ball.global_position = Vector2(5000.0, 5000.0)
	ball.reset_physics_interpolation()
	await physics_frame
	ball.global_position = attack.hit_area.global_position
	ball.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	_expect(int(hit_count.value) == 3,
		"A cancelled attack's target registry must not block the next attack.")
	controller.cancel_attack()
	ball.queue_free()
	wave.queue_free()
	await process_frame
	_finish()


func _wait_until_state(
	controller: BossAttackController,
	target_state: BossAttackController.State,
	maximum_frames := 300
) -> bool:
	for _frame in maximum_frames:
		if controller.current_state == target_state:
			return true
		await process_frame
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: teddy_arm_sweep_scene_test")
		quit(0)
		return
	print("FAIL: teddy_arm_sweep_scene_test (%d failures)" % _failures.size())
	quit(1)
