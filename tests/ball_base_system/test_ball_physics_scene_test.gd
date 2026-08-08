extends SceneTree

const SCENE_PATH := "res://scenes/tests/balls/test_ball_physics.tscn"
const CONTROLLER_SCRIPT := "res://tests/ball_base_system/test_ball_physics.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_scene_wiring()
	await _test_number_keys_switch_type()
	await _test_zero_returns_to_comparison()
	await _test_focus_ball_uses_variant_stats()
	await _test_diameter_applies_to_focus_ball()
	await _test_reset_returns_to_spawn()
	_finish()


func _test_scene_wiring() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	_expect(root_node.get_script() != null, "씬 루트에 컨트롤러 스크립트가 붙어 있어야 한다.")
	_expect(root_node.get_node_or_null("Balls") != null,
		"기존 비교용 공 그룹(Balls)이 남아 있어야 한다.")
	_expect(root_node.get_node_or_null("BallSwitchGuide/Panel/GuideLabel") is Label,
		"조작 안내 라벨이 있어야 한다.")
	_expect(root_node.get_node_or_null("FocusBall") != null,
		"집중 모드 공을 담을 FocusBall 홀더가 만들어져야 한다.")

	_free_scene(root_node)


func _test_number_keys_switch_type() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	# 시작은 1번(기본 공) 집중 모드
	_expect(root_node.get_selected_index() == 0, "시작 시 1번 공이 선택되어야 한다.")
	_expect(root_node.get_focus_ball() != null, "집중 모드에는 공이 하나 떠 있어야 한다.")

	# root_node 가 Node2D 로 잡혀 있어 get_focus_ball() 반환이 Variant 로 보인다.
	# := 추론은 여기서 실패하므로 타입을 명시한다.
	var first: Pinball = root_node.get_focus_ball()
	root_node.select_ball_type(6)
	await physics_frame
	await physics_frame

	_expect(root_node.get_selected_index() == 6, "7번을 고르면 인덱스가 6이어야 한다.")
	_expect(root_node.get_focus_ball() != first,
		"종류를 바꾸면 공 인스턴스가 새로 만들어져야 한다.")

	var group := root_node.get_node("Balls") as Node2D
	_expect(not group.visible, "집중 모드에서는 기존 7종이 보이면 안 된다.")

	# 범위를 벗어난 인덱스는 무시해야 한다
	root_node.select_ball_type(99)
	await physics_frame
	_expect(root_node.get_selected_index() == 6,
		"없는 번호를 누르면 선택이 바뀌지 않아야 한다.")

	_free_scene(root_node)


func _test_zero_returns_to_comparison() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	root_node.show_comparison()
	await physics_frame
	await physics_frame

	_expect(root_node.get_selected_index() == -1, "비교 모드 인덱스는 -1이어야 한다.")
	_expect(root_node.get_focus_ball() == null, "비교 모드에서는 집중 공이 없어야 한다.")

	var group := root_node.get_node("Balls") as Node2D
	_expect(group.visible, "비교 모드에서는 기존 7종이 보여야 한다.")

	_free_scene(root_node)


func _test_focus_ball_uses_variant_stats() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	# 2번 데드볼(탄성 0) vs 4번 슈퍼볼(탄성 0.9)
	root_node.select_ball_type(1)
	await physics_frame
	await physics_frame
	var dead_elasticity := _elasticity_of(root_node.get_focus_ball())

	root_node.select_ball_type(3)
	await physics_frame
	await physics_frame
	var super_elasticity := _elasticity_of(root_node.get_focus_ball())

	_expect(super_elasticity > dead_elasticity,
		"변종 씬의 stats가 그대로 적용되어야 한다. (데드 %.2f vs 슈퍼 %.2f)"
			% [dead_elasticity, super_elasticity])

	# 7번 무거운 공은 5번 가벼운 공보다 무거워야 한다
	root_node.select_ball_type(4)
	await physics_frame
	await physics_frame
	var light_mass := _mass_of(root_node.get_focus_ball())

	root_node.select_ball_type(6)
	await physics_frame
	await physics_frame
	var heavy_mass := _mass_of(root_node.get_focus_ball())

	_expect(heavy_mass > light_mass,
		"질량 변종도 그대로 적용되어야 한다. (가벼움 %.2f vs 무거움 %.2f)"
			% [light_mass, heavy_mass])

	_free_scene(root_node)


func _test_diameter_applies_to_focus_ball() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	# 기본은 기획서 실제 게임 크기 44px
	_expect(absf(root_node.ball_diameter - 44.0) < 0.001,
		"기본 지름은 실제 게임 크기 44px여야 VFX 검수가 의미 있다. (%.1f)"
			% root_node.ball_diameter)
	_expect(absf(root_node.get_focus_ball().ball_diameter - 44.0) < 0.001,
		"공에도 같은 지름이 적용되어야 한다.")

	root_node.set_ball_diameter(96.0)
	await physics_frame
	_expect(absf(root_node.get_focus_ball().ball_diameter - 96.0) < 0.001,
		"지름을 바꾸면 현재 공에 바로 반영되어야 한다.")

	# 종류를 바꿔도 지름은 유지되어야 한다
	root_node.select_ball_type(2)
	await physics_frame
	await physics_frame
	_expect(absf(root_node.get_focus_ball().ball_diameter - 96.0) < 0.001,
		"종류를 바꿔도 지름 설정은 유지되어야 한다.")

	# 상한을 넘기면 보정되어야 한다
	root_node.set_ball_diameter(9999.0)
	_expect(root_node.ball_diameter <= 160.0, "지름은 상한으로 보정되어야 한다.")

	_free_scene(root_node)


func _test_reset_returns_to_spawn() -> void:
	var root_node: Node2D = await _make_scene()
	if root_node == null:
		return

	# 위 48행과 같은 이유로 타입을 명시한다.
	var ball: Pinball = root_node.get_focus_ball()
	ball.global_position = Vector2(400.0, 400.0)
	ball.linear_velocity = Vector2(600.0, 200.0)
	await physics_frame

	root_node.reset_ball()
	await physics_frame

	_expect(ball.global_position.distance_to(Vector2(0.0, -250.0)) < 2.0,
		"리셋하면 발사 위치로 돌아와야 한다. (%s)" % ball.global_position)
	_expect(ball.linear_velocity.length() < 1.0,
		"리셋하면 속도가 0이어야 한다. (%.1f)" % ball.linear_velocity.length())

	_free_scene(root_node)


# ── 헬퍼 ────────────────────────────────────────────────────

func _make_scene() -> Node2D:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(packed != null, "test_ball_physics 씬을 불러올 수 있어야 한다.")
	if packed == null:
		return null

	var node := packed.instantiate() as Node2D
	_expect(node != null, "씬 루트는 Node2D여야 한다.")
	if node == null:
		return null

	root.add_child(node)
	await physics_frame
	await physics_frame
	return node


func _free_scene(node: Node) -> void:
	node.queue_free()


func _elasticity_of(ball: Pinball) -> float:
	if ball == null or ball.stats == null:
		return -1.0

	return ball.stats.elasticity


func _mass_of(ball: Pinball) -> float:
	if ball == null or ball.stats == null:
		return -1.0

	return ball.stats.mass


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_ball_physics_scene_test")
		quit(0)
		return

	print("FAIL: test_ball_physics_scene_test (%d failures)" % _failures.size())
	quit(1)
