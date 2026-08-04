extends SceneTree


const COMBO_SYSTEM_PATH := "res://scripts/combo_system/combo_system.gd"
const COLLISION_BRIDGE_PATH := (
	"res://scripts/combo_system/combo_collision_bridge.gd"
)
const EPSILON := 0.001


class FakeFlipper extends StaticBody2D:
	signal rotation_sweep_resolved(ball: RigidBody2D)
	signal state_changed(previous_state: int, current_state: int)

	var overlaps_ball := true

	func is_circle_overlapping_at_rotation(
		_ball_center: Vector2,
		_ball_radius: float,
		_test_rotation: float
	) -> bool:
		return overlaps_ball


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var combo_script := load(COMBO_SYSTEM_PATH) as Script
	var bridge_script := load(COLLISION_BRIDGE_PATH) as Script
	_expect(combo_script != null and combo_script.can_instantiate(), \
		"ComboSystem 스크립트를 인스턴스화할 수 있어야 한다.")
	_expect(bridge_script != null and bridge_script.can_instantiate(), \
		"ComboCollisionBridge 스크립트를 인스턴스화할 수 있어야 한다.")
	if not _failures.is_empty():
		_finish()
		return

	var combo := combo_script.new() as Node
	var bridge := bridge_script.new() as Node
	var ball := RigidBody2D.new()
	var first_flipper := _make_flipper("FirstFlipper")
	var second_flipper := _make_flipper("SecondFlipper")
	var wall := StaticBody2D.new()
	wall.name = "Wall"
	var ball_collision := CollisionShape2D.new()
	ball_collision.name = "CollisionShape2D"
	var ball_shape := CircleShape2D.new()
	ball_shape.radius = 16.0
	ball_collision.shape = ball_shape
	ball.add_child(ball_collision)
	root.add_child(combo)
	root.add_child(ball)
	root.add_child(first_flipper)
	root.add_child(second_flipper)
	root.add_child(wall)
	root.add_child(bridge)
	first_flipper.add_to_group(&"combo_flippers")
	second_flipper.add_to_group(&"combo_flippers")
	wall.add_to_group(&"combo_timer_refresh_walls")
	await process_frame

	_expect(bool(bridge.call(&"bind_combo_system", combo)), \
		"브리지가 ComboSystem을 연결해야 한다.")
	_expect(bool(bridge.call(&"bind_ball", ball)), \
		"브리지가 공의 물리 접촉 신호를 연결해야 한다.")
	_expect(bool(bridge.call(&"bind_flipper", first_flipper)), \
		"첫 번째 플리퍼 스윕 신호를 연결해야 한다.")
	_expect(bool(bridge.call(&"bind_flipper", second_flipper)), \
		"두 번째 플리퍼 스윕 신호를 연결해야 한다.")

	_test_physical_contact_session(combo, ball, first_flipper, second_flipper)
	await _test_swept_contact_session(combo, ball, first_flipper)
	_test_wall_contact_session(combo, ball, wall)

	bridge.queue_free()
	wall.queue_free()
	second_flipper.queue_free()
	first_flipper.queue_free()
	ball.queue_free()
	combo.queue_free()
	await process_frame
	_finish()


func _test_physical_contact_session(
	combo: Node,
	ball: RigidBody2D,
	first_flipper: FakeFlipper,
	second_flipper: FakeFlipper
) -> void:
	ball.body_entered.emit(first_flipper)
	_expect(int(combo.get(&"combo_count")) == 1, \
		"첫 플리퍼 접촉은 콤보를 1 증가시켜야 한다.")
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"첫 플리퍼 접촉은 콤보 시간을 초기값으로 갱신해야 한다.")

	combo.call(&"advance_time", 1.0)
	ball.body_entered.emit(first_flipper)
	_expect(int(combo.get(&"combo_count")) == 1, \
		"같은 플리퍼의 지속 접촉 신호는 콤보를 중복 증가시키면 안 된다.")
	_expect_float(float(combo.get(&"time_remaining")), 2.0, \
		"중복 플리퍼 접촉은 콤보 시간도 다시 갱신하면 안 된다.")

	ball.body_entered.emit(second_flipper)
	_expect(int(combo.get(&"combo_count")) == 1, \
		"한 타격 중 인접한 두 플리퍼 접촉도 한 콤보로 계산해야 한다.")
	ball.body_exited.emit(first_flipper)
	ball.body_entered.emit(first_flipper)
	_expect(int(combo.get(&"combo_count")) == 1, \
		"다른 플리퍼 접촉이 유지되면 동일 타격 세션을 유지해야 한다.")

	ball.body_exited.emit(first_flipper)
	ball.body_exited.emit(second_flipper)
	ball.body_entered.emit(first_flipper)
	_expect(int(combo.get(&"combo_count")) == 2, \
		"모든 플리퍼에서 분리된 뒤 재접촉하면 새 콤보로 인정해야 한다.")
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"분리 후 새 플리퍼 타격은 콤보 시간을 다시 갱신해야 한다.")
	ball.body_exited.emit(first_flipper)


func _test_swept_contact_session(
	combo: Node,
	ball: RigidBody2D,
	flipper: FakeFlipper
) -> void:
	combo.call(&"advance_time", 1.0)
	flipper.emit_signal(&"rotation_sweep_resolved", ball)
	_expect(int(combo.get(&"combo_count")) == 3, \
		"회전 스윕 플리퍼 타격도 콤보를 증가시켜야 한다.")
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"회전 스윕 플리퍼 타격도 콤보 시간을 갱신해야 한다.")

	combo.call(&"advance_time", 1.0)
	flipper.emit_signal(&"rotation_sweep_resolved", ball)
	_expect(int(combo.get(&"combo_count")) == 3, \
		"같은 작동 중 반복된 스윕 신호는 콤보를 중복 증가시키면 안 된다.")
	_expect_float(float(combo.get(&"time_remaining")), 2.0, \
		"중복 스윕 신호는 콤보 시간도 다시 갱신하면 안 된다.")

	ball.body_entered.emit(flipper)
	_expect(int(combo.get(&"combo_count")) == 3, \
		"스윕 뒤 같은 물리 접촉 신호가 와도 한 타격으로 합쳐야 한다.")
	ball.body_exited.emit(flipper)
	flipper.emit_signal(&"rotation_sweep_resolved", ball)
	_expect(int(combo.get(&"combo_count")) == 4, \
		"플리퍼가 아직 작동 중이어도 실제 분리 뒤 다음 스윕은 새 타격이어야 한다.")

	combo.call(&"advance_time", 1.0)
	flipper.emit_signal(&"rotation_sweep_resolved", ball)
	_expect(int(combo.get(&"combo_count")) == 4, \
		"재타격의 반복 스윕 신호도 다시 중복 증가시키면 안 된다.")
	flipper.overlaps_ball = false
	await physics_frame
	await process_frame
	flipper.emit_signal(&"rotation_sweep_resolved", ball)
	_expect(int(combo.get(&"combo_count")) == 5, \
		"물리 신호 없는 스윕도 실제 분리 뒤 IDLE 전에 새 타격을 허용해야 한다.")
	flipper.overlaps_ball = true


func _test_wall_contact_session(
	combo: Node,
	ball: RigidBody2D,
	wall: StaticBody2D
) -> void:
	combo.call(&"reset_run")
	ball.body_entered.emit(wall)
	_expect(int(combo.get(&"combo_count")) == 0, \
		"0콤보의 벽 접촉은 콤보를 시작하면 안 된다.")
	_expect_float(float(combo.get(&"time_remaining")), 0.0, \
		"0콤보의 벽 접촉은 타이머도 시작하면 안 된다.")

	combo.call(&"register_hit", 2.5)
	combo.call(&"advance_time", 1.0)
	ball.body_entered.emit(wall)
	_expect_float(float(combo.get(&"time_remaining")), 2.0, \
		"벽에 계속 붙은 채 콤보가 시작돼도 같은 접촉은 시간을 갱신하면 안 된다.")

	ball.body_exited.emit(wall)
	ball.body_entered.emit(wall)
	_expect(int(combo.get(&"combo_count")) == 1, \
		"벽 재접촉은 콤보 카운트를 증가시키면 안 된다.")
	_expect_float(float(combo.get(&"total_score_weight")), 2.5, \
		"벽 재접촉은 점수 가중치를 추가하면 안 된다.")
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"활성 콤보 중 새 벽 접촉은 시간을 초기값으로 갱신해야 한다.")

	combo.call(&"advance_time", 1.0)
	ball.body_entered.emit(wall)
	_expect_float(float(combo.get(&"time_remaining")), 2.0, \
		"벽을 타고 구르며 반복된 접촉 신호는 시간을 계속 갱신하면 안 된다.")
	ball.body_exited.emit(wall)
	combo.call(&"advance_time", 0.5)
	ball.body_entered.emit(wall)
	_expect_float(float(combo.get(&"time_remaining")), 3.0, \
		"벽에서 실제 분리된 뒤 재접촉하면 시간을 다시 갱신해야 한다.")


func _make_flipper(node_name: String) -> FakeFlipper:
	var flipper := FakeFlipper.new()
	flipper.name = node_name
	return flipper


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_collision_bridge_test")
		quit(0)
		return
	print("FAIL: combo_collision_bridge_test (%d failures)" % _failures.size())
	quit(1)
