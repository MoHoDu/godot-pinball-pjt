extends SceneTree


const BALL_SCENE := preload("res://Resources/Prefabs/balls/base/base_ball.tscn")
const BUTTON_SCENE := preload("res://Resources/Prefabs/bumpers/types/button_bumper.tscn")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var bumper := BUTTON_SCENE.instantiate() as Bumper
	var ball := BALL_SCENE.instantiate() as Pinball
	fixture.add_child(bumper)
	fixture.add_child(ball)
	bumper.global_position = Vector2.ZERO
	ball.global_position = Vector2(-180.0, 0.0)
	ball.ball_diameter = 44.0
	ball.stats = ball.stats.duplicate(true) as PinballStats
	ball.stats.gravity_scale = 0.0
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 1540.0
	ball.stats.elasticity = 1.0
	ball.linear_velocity = Vector2(940.0, 0.0)

	var hit_count := [0]
	bumper.valid_hit_registered.connect(func(
		_bumper_id: StringName,
		_ball_value: RigidBody2D,
		_contact_id: int,
		_base_score: int
	) -> void:
		hit_count[0] += 1
	)

	var reflected := false
	for _frame in 120:
		await physics_frame
		if ball.linear_velocity.x < -1.0:
			reflected = true
			break

	_expect(reflected,
		("실제 Pinball 접촉에서 단추 범퍼가 공을 반사해야 한다. "
		+ "(position=%s ball_layer=%d ball_mask=%d bumper_layer=%d disabled=%s state=%s durability=%d)") % [
			ball.global_position,
			ball.collision_layer,
			ball.collision_mask,
			bumper.collision_layer,
			bumper.collision_shape.disabled,
			Bumper.BumperState.keys()[bumper.state],
			bumper.current_durability,
		])
	_expect(hit_count[0] == 1,
		"실제 접촉 구간은 유효 타격을 정확히 한 번 발생시켜야 한다. (actual=%d)"
			% hit_count[0])
	# 속력 전략은 기본 물리가 반사 방향을 확정한 뒤 Deferred로 한 번 적용됩니다.
	await process_frame
	_expect(ball.linear_velocity.length() >= 1090.0 \
			and ball.linear_velocity.length() <= 1160.0,
		"940px/s 공은 단추(x1.2)에서 약 1,128px/s로 반사되어야 한다. (actual=%.2f)"
			% ball.linear_velocity.length())
	_expect(bumper.current_durability == 1,
		"실제 접촉에서 내구도는 한 번만 감소해야 한다.")

	for _frame in 10:
		await physics_frame
	_expect(hit_count[0] == 1,
		"분리되기 전 물리 프레임 반복이 중복 타격을 만들면 안 된다.")

	fixture.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_physics_integration_test")
		quit(0)
		return
	print("FAIL: bumper_physics_integration_test (%d failures)" % _failures.size())
	quit(1)
