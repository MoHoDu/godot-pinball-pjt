extends SceneTree


const BOARD_SCENE_PATH := (
	"res://scenes/test_flipper/test_flipper_combo_board.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load(BOARD_SCENE_PATH) as PackedScene
	_expect(packed_scene != null and packed_scene.can_instantiate(), \
		"콤보 통합 보드 씬을 인스턴스화할 수 있어야 한다.")
	if packed_scene == null or not packed_scene.can_instantiate():
		_finish()
		return

	var board := packed_scene.instantiate()
	root.add_child(board)
	await process_frame

	_test_integrated_structure(board)
	await _test_custom_drain_area(board)
	_test_manual_tier_progression(board)
	_test_timer_and_settlement(board)
	await _test_real_bumper_contact(board)

	board.queue_free()
	await process_frame
	_finish()


func _test_integrated_structure(board: Node) -> void:
	var combo := board.get_node_or_null("ComboSystem") as ComboSystem
	var hud := board.get_node_or_null("HUD/ComboHud") as ComboHud
	var inspector := board.get_node_or_null("HUD/ComboInspector")
	var ball := board.get_node_or_null("PinballBall") as Pinball
	var selector := board.get_node_or_null("FlipperSelector") as FlipperSelector
	var collision_bridge := board.get_node_or_null(
		"ComboCollisionBridge"
	) as ComboCollisionBridge

	_expect(combo != null, "보드에 실제 ComboSystem 노드가 필요하다.")
	_expect(hud != null, "콤보 수·티어·시간·점수를 표시할 ComboHud가 필요하다.")
	_expect(inspector != null, "콤보 검증 키와 이벤트를 표시할 패널이 필요하다.")
	_expect(ball != null and selector != null, \
		"원본 보드의 공과 4방향 플리퍼 선택기를 유지해야 한다.")
	_expect(collision_bridge != null, \
		"플리퍼·벽 접촉을 콤보 판정으로 전달하는 브리지가 필요하다.")
	var drain_area := board.get_node_or_null("BallDrainArea") as Area2D
	_expect(drain_area != null,
		"Board drain must be authored as a customizable Area2D.")
	if drain_area != null:
		_expect(drain_area.get_child_count() == 4,
			"Default drain Area2D must expose four editable edge colliders.")
	var walls := board.get_node_or_null("Walls")
	_expect(walls != null, "콤보 보드에 벽 루트가 필요하다.")
	if walls != null:
		for wall: Node in walls.get_children():
			_expect(wall.is_in_group(&"combo_timer_refresh_walls"), \
				"모든 보드 벽은 최초 접촉 시간 갱신 대상으로 표시되어야 한다.")

	var bumpers := board.get_node_or_null("Bumpers")
	_expect(bumpers != null and bumpers.get_child_count() == 3, \
		"원본 보드의 범퍼 3개를 유지해야 한다.")
	if bumpers == null:
		return
	for bumper: Node in bumpers.get_children():
		_expect(bumper.get_node_or_null("ComboHitSource") is ComboHitSource, \
			"각 범퍼가 중복 접촉을 제거하는 ComboHitSource를 가져야 한다.")


func _test_custom_drain_area(board: Node) -> void:
	var ball := board.get_node("PinballBall") as Pinball
	var launcher := board.get_node("PinballLauncher") as PinballLauncher
	var reset_count := [0]
	board.ball_reset_completed.connect(func() -> void: reset_count[0] += 1)
	ball.stats.gravity_scale = 0.0
	ball.global_position = Vector2(-350.0, -550.0)
	ball.linear_velocity = Vector2.ZERO
	ball.freeze = false
	ball.sleeping = false
	await physics_frame
	await physics_frame
	_expect(reset_count[0] == 0,
		"A ball beside the top flipper pivot must not be treated as drained.")

	ball.global_position = Vector2(0.0, 800.0)
	ball.reset_physics_interpolation()
	ball.sleeping = false
	for _frame in 4:
		await physics_frame
	_expect(reset_count[0] == 1,
		"Entering an authored drain collider must settle the ball exactly once.")
	_expect(launcher.is_aiming,
		"The base combo board must reset after its custom drain collider fires.")
	board.call(&"reset_combo_test")


func _test_manual_tier_progression(board: Node) -> void:
	var combo := board.get_node("ComboSystem") as ComboSystem
	var hud := board.get_node("HUD/ComboHud") as ComboHud
	board.call(&"advance_to_next_tier")
	_expect(combo.combo_count == 11, \
		"T 검증 진입점은 실제 규칙의 Super 경계인 11콤보로 이동해야 한다.")
	_expect(combo.current_tier == ComboRules.Tier.SUPER, \
		"11콤보에서 실제 ComboRules가 Super를 반환해야 한다.")
	var tier_label := hud.find_child("TierLabel", true, false) as Label
	_expect(tier_label != null and tier_label.text == "Super", \
		"ComboHud가 Super 티어 전환을 즉시 표시해야 한다.")


func _test_timer_and_settlement(board: Node) -> void:
	var combo := board.get_node("ComboSystem") as ComboSystem
	board.call(&"toggle_combo_timer")
	_expect(combo.is_timer_suspended, \
		"P 검증 진입점이 활성 콤보 타이머를 정지해야 한다.")
	var held_time := combo.time_remaining
	combo.advance_time(10.0)
	_expect(is_equal_approx(combo.time_remaining, held_time), \
		"정지한 콤보 타이머는 시간이 지나도 감소하면 안 된다.")
	board.call(&"toggle_combo_timer")
	_expect(not combo.is_timer_suspended, \
		"P 검증 진입점을 다시 호출하면 타이머가 재개되어야 한다.")

	var score := int(board.call(&"finish_combo_manually"))
	_expect(score == 5500, \
		"11회 기본 타격 수동 정산은 Super 5배로 5,500점을 지급해야 한다.")
	_expect(combo.combo_count == 0 and combo.total_score == 5500, \
		"정산 뒤 활성 콤보는 비우고 누적 점수는 유지해야 한다.")


func _test_real_bumper_contact(board: Node) -> void:
	var combo := board.get_node("ComboSystem") as ComboSystem
	var ball := board.get_node("PinballBall") as Pinball
	var bumper := board.get_node("Bumpers/BumperCenter") as StaticBody2D
	board.call(&"reset_combo_test")

	ball.freeze = true
	ball.stats.minimum_speed = 0.0
	ball.stats.maximum_speed = 1540.0
	ball.stats.gravity_scale = 0.0
	ball.global_position = bumper.global_position + Vector2(0.0, -130.0)
	ball.linear_velocity = Vector2.ZERO
	ball.reset_physics_interpolation()
	await physics_frame
	ball.freeze = false
	ball.linear_velocity = Vector2(0.0, 600.0)
	ball.sleeping = false
	for _frame in 14:
		await physics_frame

	_expect(combo.combo_count == 1, \
		"실제 공이 범퍼 감지 영역에 들어오면 유효 타격이 1회 적립되어야 한다.")
	_expect(is_equal_approx(combo.total_score_weight, 1.0), \
		"실제 범퍼 접촉은 기본 점수 가중치 1을 적립해야 한다.")
	ball.freeze = true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: test_flipper_combo_board_scene_test")
		quit(0)
		return
	print("FAIL: test_flipper_combo_board_scene_test (%d failures)" \
		% _failures.size())
	quit(1)
