extends SceneTree


const WAVE_SCENE := preload(
	"res://scenes/game/stages/stage_01/waves/stage_01_wave_01.tscn"
)
const ALT_LAYOUT_SCENE := preload(
	"res://Resources/Prefabs/boards/layouts/wave_01_repair_layout.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	var wave := WAVE_SCENE.instantiate()
	_test_bumper_authoring(wave)
	_test_coin_authoring(wave)
	_test_board_layout_authoring(wave)
	_test_stage_layout_swap(wave)
	wave.free()
	if _failures.is_empty():
		print("PASS: wave_authoring_tools_test")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_bumper_authoring(wave: Node) -> void:
	var coordinator := wave as WaveRuntimeCoordinator
	_expect(coordinator != null, "Stage wave must use WaveRuntimeCoordinator.")
	if coordinator == null:
		return
	_expect(coordinator.get_bumpers().size() == 6, "Default wave must expose six bumpers.")
	var bumper := coordinator.get_bumpers()[0]
	_expect(coordinator.set_bumper_disabled(bumper, true), "Inherited bumper must be disableable.")
	coordinator.enforce_stage_bumper_limits = false
	coordinator.sync_expected_bumper_roster()
	_expect(coordinator.get_bumpers().size() == 5, "Disabled bumper must leave the authored roster.")
	_expect(coordinator.is_current_bumper_loadout_valid(), "Synced custom bumper roster must validate.")
	coordinator.restore_disabled_bumpers()
	coordinator.sync_expected_bumper_roster()
	_expect(coordinator.get_bumpers().size() == 6, "Restored bumper must return to the roster.")


func _test_coin_authoring(wave: Node) -> void:
	var field := wave.get_node("CoinSystem") as CoinFieldController
	_expect(field != null, "Stage wave must expose CoinFieldController.")
	if field == null:
		return
	var points := field.get_spawn_points()
	_expect(points.size() == 12, "Default wave must expose twelve coin points.")
	_expect(field.set_spawn_point_disabled(points[0], true), "Inherited coin must be disableable.")
	_expect(field.get_spawn_points().size() == 11, "Disabled coin must leave the authored layout.")
	_expect(field.expected_spawn_count == 11, "Coin expected count must sync after deletion.")
	field.restore_disabled_spawn_points()
	_expect(field.get_spawn_points().size() == 12, "Restored coin must return to the layout.")
	_expect(field.expected_spawn_count == 12, "Coin expected count must sync after restore.")


func _test_board_layout_authoring(wave: Node) -> void:
	var layout := wave.get_node("RepairBoardLayout") as BoardLayout
	_expect(layout != null, "Stage wave must expose BoardLayout.")
	if layout == null:
		return
	var zone := layout.create_zone(&"bonus", Vector2.ZERO, Vector2(576.0, 288.0))
	_expect(zone != null, "BoardLayout must create a rectangular zone.")
	var socket := layout.create_socket(&"bonus_01", &"bonus", Vector2(130.0, 130.0))
	_expect(socket != null, "BoardLayout must create a socket for the new zone.")
	if socket != null:
		_expect(socket.position == Vector2(144.0, 144.0), "New socket must snap to the 144-unit grid.")
	_expect(layout.required_candidate_sockets == 13, "Socket count contract must sync after addition.")


func _test_stage_layout_swap(wave: Node) -> void:
	var tools := wave.get_node("WaveAuthoringTools") as WaveAuthoringTools
	_expect(tools != null, "Stage wave must expose WaveAuthoringTools.")
	if tools == null:
		return
	var alternate := ALT_LAYOUT_SCENE.instantiate() as BoardLayout
	alternate.name = "TestAlternateLayout"
	wave.add_child(alternate)
	tools.stage_board_layout_path = tools.get_path_to(alternate)
	tools.call(&"_apply_active_layout_dependencies")
	_expect(tools.get_active_board_layout() == alternate, "Stage layout path must select the alternate layout.")
	_expect(tools.coin_field.board_layout == alternate, "Coin validation must use the alternate layout.")
	var session := alternate.get_node("PlacementSession") as BoardPlacementSession
	_expect(tools.board_placement_bridge.placement_session == session, "Wave bridge must use the alternate session.")
	_expect(tools.repair_placement_controller.placement_session == session, "Placement UI must use the alternate session.")
	_expect(tools.reward_shop_bridge.placement_session == session, "Reward bridge must use the alternate session.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
