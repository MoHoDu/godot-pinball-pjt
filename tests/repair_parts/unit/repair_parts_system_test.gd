extends SceneTree


## 수리 부품 시스템 단위 테스트 (기획서 15-1).
## 실행:
## godot --headless --path . \
##     --script res://tests/repair_parts/unit/repair_parts_system_test.gd


const BROOCH_SCENE := preload(
	"res://scenes/repair_parts/parts/starlight_brooch_part.tscn"
)
const GEARS_SCENE := preload(
	"res://scenes/repair_parts/parts/golden_gears_part.tscn"
)
const NEEDLE_SCENE := preload(
	"res://scenes/repair_parts/parts/crescent_needle_part.tscn"
)
const BELL_SCENE := preload(
	"res://scenes/repair_parts/parts/forgotten_star_bell_part.tscn"
)
const BALL_STUB := preload("res://tests/repair_parts/unit/test_ball_stub.gd")
const BOARD_TEST_SCENE_PATH := "res://tests/repair_parts/repair_parts_board_test.tscn"
const EPSILON := 0.001


var _failures: Array[String] = []
var _fixture_root: Node2D
var _combo_system: ComboSystem
var _combo_adapter: RepairComboAdapter
var _ball_adapter: RepairBallAdapter
var _router: RepairEffectRouter
var _brooch: Bumper
var _gears: Bumper
var _needle: Bumper
var _bell: Bumper
var _ball: RigidBody2D

var _overdrive_count: int = 0
var _echo_fired_count: int = 0
var _stitch_count: int = 0
var _finish_count: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _build_fixture()

	await _test_duplicate_contact_blocked()
	await _test_recontact_after_release()
	await _test_unequipped_part_does_not_trigger()
	await _test_minimum_trigger_interval()
	await _test_gear_wind_and_single_overdrive()
	await _test_gear_speed_stays_within_ball_limit()
	await _test_bell_single_reservation_and_echo()
	await _test_needle_stitch_success_and_isolation()
	await _test_brooch_distinct_families_and_finish()
	await _test_brooch_timeout_clears_progress()
	await _test_reset_rules()
	_test_board_test_scene_contract()

	_fixture_root.queue_free()
	await process_frame
	_finish()


func _build_fixture() -> void:
	_fixture_root = Node2D.new()
	root.add_child(_fixture_root)

	_combo_system = ComboSystem.new()
	_combo_system.name = "ComboSystem"
	_fixture_root.add_child(_combo_system)

	_combo_adapter = RepairComboAdapter.new()
	_combo_adapter.name = "RepairComboAdapter"
	_combo_adapter.combo_system_path = NodePath("../ComboSystem")
	_fixture_root.add_child(_combo_adapter)

	_ball_adapter = RepairBallAdapter.new()
	_ball_adapter.name = "RepairBallAdapter"
	_fixture_root.add_child(_ball_adapter)

	_router = RepairEffectRouter.new()
	_router.name = "RepairEffectRouter"
	_router.auto_advance = false
	_router.combo_adapter_path = NodePath("../RepairComboAdapter")
	_router.ball_adapter_path = NodePath("../RepairBallAdapter")
	_fixture_root.add_child(_router)

	_brooch = await _spawn_part(BROOCH_SCENE, Vector2(-260.0, 20.0))
	_gears = await _spawn_part(GEARS_SCENE, Vector2(260.0, 20.0))
	_needle = await _spawn_part(NEEDLE_SCENE, Vector2(-620.0, -330.0))
	_bell = await _spawn_part(BELL_SCENE, Vector2(680.0, 330.0))
	_router.rescan_parts()

	for bumper: Bumper in [_brooch, _gears, _needle, _bell]:
		_combo_system.bind_hit_source(bumper.combo_hit_source)
		_set_trigger_interval(bumper, 0.0)

	_router.gear_overdrive_fired.connect(
		func(_part: Node, _hit_ball: RigidBody2D, _before: float, _after: float) -> void:
			_overdrive_count += 1
	)
	_router.bell_echo_fired.connect(
		func(_ball_id: int, _weight: float) -> void:
			_echo_fired_count += 1
	)
	_router.stitch_completed.connect(
		func(_hit_ball: RigidBody2D, _target: Node, _weight: float) -> void:
			_stitch_count += 1
	)
	_router.repair_finish_completed.connect(
		func(_hit_ball: RigidBody2D, _weight: float) -> void:
			_finish_count += 1
	)

	_ball = BALL_STUB.new()
	_fixture_root.add_child(_ball)
	await process_frame


func _spawn_part(scene: PackedScene, at: Vector2) -> Bumper:
	var part := scene.instantiate() as Bumper
	part.position = at
	_fixture_root.add_child(part)
	await process_frame
	return part


func _set_trigger_interval(bumper: Bumper, interval: float) -> void:
	var source := bumper.get_node(^"ComboHitSource") as RepairPartHitSource
	source.minimum_trigger_interval = interval


func _hit(bumper: Bumper) -> bool:
	return bumper.register_valid_hit(_ball, _ball.get_instance_id())


func _release(bumper: Bumper) -> void:
	bumper.release_contact(_ball.get_instance_id())


func _hit_and_release(bumper: Bumper) -> bool:
	var registered := _hit(bumper)
	_release(bumper)
	return registered


func _reset_counters_and_state() -> void:
	_router.on_full_reset()
	_overdrive_count = 0
	_echo_fired_count = 0
	_stitch_count = 0
	_finish_count = 0
	for bumper: Bumper in [_brooch, _gears, _needle, _bell]:
		bumper.release_contact(_ball.get_instance_id())
		bumper.reset_for_new_ball()
	_combo_system.reset_wave()


func _effect_of(bumper: Bumper) -> RepairPartEffect:
	var runtime := bumper.get_node(^"RepairPartRuntime") as RepairPartRuntime
	return _router.get_effect_for(runtime)


## 1. 같은 접촉 ID가 분리 전 두 번 발동하지 않는다.
func _test_duplicate_contact_blocked() -> void:
	_reset_counters_and_state()
	var first := _hit(_gears)
	var second := _hit(_gears)
	_expect(first, "첫 접촉은 유효 타격으로 등록되어야 한다.")
	_expect(not second, "분리 전 같은 접촉 ID는 두 번 등록되면 안 된다.")
	var gear_effect := _effect_of(_gears) as RepairGearEffect
	_expect(gear_effect.get_wind_stack() == 1,
		"분리 전 중복 접촉으로 회전 단계가 오르면 안 된다.")
	_release(_gears)
	await process_frame


## 2. 분리 후 재접촉하면 다시 발동한다.
func _test_recontact_after_release() -> void:
	_reset_counters_and_state()
	_expect(_hit_and_release(_gears), "첫 접촉은 등록되어야 한다.")
	_expect(_hit_and_release(_gears), "분리 후 재접촉은 새 타격으로 인정되어야 한다.")
	var gear_effect := _effect_of(_gears) as RepairGearEffect
	_expect(gear_effect.get_wind_stack() == 2,
		"분리 후 재접촉으로 회전 단계가 2가 되어야 한다.")
	await process_frame


## 3. 비활성 소켓과 미장착 부품은 발동하지 않는다.
func _test_unequipped_part_does_not_trigger() -> void:
	_reset_counters_and_state()
	var runtime := _gears.get_node(^"RepairPartRuntime") as RepairPartRuntime
	runtime.is_equipped = false
	_hit_and_release(_gears)
	var gear_effect := _effect_of(_gears) as RepairGearEffect
	_expect(gear_effect.get_wind_stack() == 0,
		"미장착 부품은 부품 효과를 발동하면 안 된다.")
	runtime.is_equipped = true
	await process_frame


## 4-3. 직전 발동 후 최소 0.12초가 지나야 한다.
func _test_minimum_trigger_interval() -> void:
	_reset_counters_and_state()
	_set_trigger_interval(_gears, 10.0)
	_expect(_hit_and_release(_gears), "간격 게이트의 첫 접촉은 통과해야 한다.")
	var combo_after_first := _combo_system.combo_count
	# 범퍼 자체의 접촉 등록은 유지되지만(기존 스크립트 계약),
	# 간격 게이트가 기본 콤보 적립과 부품 발동을 모두 차단해야 한다.
	_hit_and_release(_gears)
	var gear_effect := _effect_of(_gears) as RepairGearEffect
	_expect(gear_effect.get_wind_stack() == 1,
		"최소 간격이 지나기 전의 재접촉은 회전 단계를 올리면 안 된다.")
	_expect(_combo_system.combo_count == combo_after_first,
		"간격 거부된 접촉은 콤보를 적립하면 안 된다.")
	_set_trigger_interval(_gears, 0.0)
	await process_frame


## 6. 톱니는 세 번째 접촉에서 한 번만 과회전한다.
func _test_gear_wind_and_single_overdrive() -> void:
	_reset_counters_and_state()
	_ball.linear_velocity = Vector2(400.0, 0.0)
	_hit_and_release(_gears)
	_hit_and_release(_gears)
	_router.advance_time(0.001)
	_expect(_overdrive_count == 0, "두 번째 접촉까지는 과회전이 없어야 한다.")
	_hit_and_release(_gears)
	_router.advance_time(0.001)
	_expect(_overdrive_count == 1, "세 번째 접촉에서 과회전이 정확히 한 번 발동해야 한다.")
	var gear_effect := _effect_of(_gears) as RepairGearEffect
	_expect(gear_effect.get_wind_stack() == 0,
		"과회전 후 회전 단계는 0으로 돌아가야 한다.")
	_router.advance_time(3.0)
	_hit_and_release(_gears)
	_expect(_overdrive_count == 1,
		"단계 유지 시간이 지난 뒤의 접촉은 과회전을 다시 만들면 안 된다.")
	await process_frame


## 7. 톱니 가속 후 공 속도가 공 고유 최대값을 넘지 않고,
## 범퍼의 지연 최종 반응이 가속을 되돌리지 않는다 (실제 물리 경로 통합).
func _test_gear_speed_stays_within_ball_limit() -> void:
	_reset_counters_and_state()
	_ball.linear_velocity = Vector2(1500.0, 0.0)
	# Pinball._integrate_forces가 실제로 호출하는 get_ball_impact 경로를 사용해
	# 지연 반응 → response_resolved → 톱니 가속 합성 순서를 검증합니다.
	for _hit_index: int in range(3):
		var context := BallImpactContext.new(
			_ball,
			_ball.linear_velocity,
			Vector2.ZERO,
			Vector2.UP,
			_gears.global_position
		)
		var response := _gears.get_ball_impact(context)
		_expect(response == null,
			"범퍼는 기본 반사를 유지하기 위해 null을 반환해야 한다.")
		await physics_frame
		_release(_gears)
	await physics_frame
	var final_speed := _ball.linear_velocity.length()
	_expect(final_speed <= 1540.0 + EPSILON,
		"과회전 가속 후에도 공 최대 속도 1540을 넘으면 안 된다.")
	# 가속이 되돌려지면 속도는 타격 전 1500 이하로 남는다.
	# 감쇠 여유를 두고 1520 이상이면 가속이 보존된 것으로 판정한다.
	_expect(final_speed >= 1520.0,
		"톱니 가속이 범퍼의 지연 최종 반응에 덮어써지면 안 된다.")
	_expect(_overdrive_count == 1,
		"물리 경로에서도 세 번째 접촉의 과회전이 한 번 발동해야 한다.")
	await process_frame


## 10·11. 방울은 예약을 하나만 유지하고, 여운은 다른 부품을 발동하지 않는다.
func _test_bell_single_reservation_and_echo() -> void:
	_reset_counters_and_state()
	var bell_effect := _effect_of(_bell) as RepairBellEffect
	_hit_and_release(_bell)
	_expect(bell_effect.has_pending_echo(_ball.get_instance_id()),
		"방울 접촉 후 여운이 예약되어야 한다.")
	_hit_and_release(_bell)
	_expect(_echo_fired_count == 0, "지연 시간 전에는 여운이 울리면 안 된다.")
	var combo_before := _combo_system.combo_count
	var gear_stack_before := (_effect_of(_gears) as RepairGearEffect).get_wind_stack()
	_router.advance_time(0.7)
	_expect(_echo_fired_count == 1,
		"여운 대기 중 추가 접촉이 있어도 여운은 정확히 한 번만 울려야 한다.")
	_expect(_combo_system.combo_count == combo_before + 1,
		"여운 타격은 콤보 횟수를 정확히 한 번 올려야 한다.")
	var gear_stack_after := (_effect_of(_gears) as RepairGearEffect).get_wind_stack()
	_expect(gear_stack_after == gear_stack_before,
		"방울 여운이 톱니 회전 단계를 갱신하면 안 된다.")
	_expect(not bell_effect.has_pending_echo(_ball.get_instance_id()),
		"여운이 울린 뒤 예약은 소모되어야 한다.")
	await process_frame


## 8·9. 바늘은 다른 부품의 실제 접촉에서만 성공하고,
## 봉합 타격이 새 봉합·브로치 방문을 만들지 않는다.
func _test_needle_stitch_success_and_isolation() -> void:
	_reset_counters_and_state()
	var needle_effect := _effect_of(_needle) as RepairNeedleEffect
	_hit_and_release(_needle)
	_expect(needle_effect.has_pending_stitch(_ball.get_instance_id()),
		"바늘 접촉 후 봉합 대기가 걸려야 한다.")
	_hit_and_release(_needle)
	_expect(_stitch_count == 0, "바늘 재접촉은 봉합을 성공시키면 안 된다.")
	_expect(needle_effect.has_pending_stitch(_ball.get_instance_id()),
		"바늘 재접촉은 제한 시간만 갱신해야 한다.")
	var brooch_effect := _effect_of(_brooch) as RepairBroochEffect
	_hit_and_release(_gears)
	_expect(_stitch_count == 1, "다른 부품의 실제 접촉에서 봉합이 성공해야 한다.")
	_expect(not needle_effect.has_pending_stitch(_ball.get_instance_id()),
		"봉합 성공 후 대기 상태는 소모되어야 한다.")
	_expect(
		brooch_effect.get_visited_family_count(_ball.get_instance_id()) == 0,
		"봉합 타격은 브로치 방문을 만들면 안 된다. (표식이 없으므로 방문 0)"
	)
	# 봉합 제한 시간 초과 시 실이 끊어진다.
	_hit_and_release(_needle)
	_router.advance_time(4.0)
	_hit_and_release(_gears)
	_expect(_stitch_count == 1, "제한 시간이 지난 봉합은 성공하면 안 된다.")
	await process_frame


## 4. 브로치는 서로 다른 두 부품만 방문으로 세고 귀환 시 완성된다.
func _test_brooch_distinct_families_and_finish() -> void:
	_reset_counters_and_state()
	var brooch_effect := _effect_of(_brooch) as RepairBroochEffect
	var ball_id := _ball.get_instance_id()
	_hit_and_release(_brooch)
	_expect(brooch_effect.has_mark(ball_id), "브로치 접촉으로 마감 표식이 생겨야 한다.")
	_hit_and_release(_gears)
	_hit_and_release(_gears)
	_expect(brooch_effect.get_visited_family_count(ball_id) == 1,
		"같은 부품을 두 번 맞혀도 별 팔은 하나만 켜져야 한다.")
	_hit_and_release(_bell)
	_expect(brooch_effect.get_visited_family_count(ball_id) == 2,
		"서로 다른 두 번째 부품 방문으로 별 팔 두 개가 켜져야 한다.")
	var combo_before := _combo_system.combo_count
	_hit_and_release(_brooch)
	_expect(_finish_count == 1, "준비된 브로치 귀환에서 수리 완성이 발동해야 한다.")
	_expect(not brooch_effect.has_mark(ball_id),
		"수리 완성 후 표식은 초기화되어야 한다.")
	_expect(_combo_system.combo_count == combo_before + 2,
		"귀환 접촉은 기본 타격 1회와 완성 타격 1회만 적립해야 한다.")
	await process_frame


## 5. 브로치 제한 시간이 끝나면 진행도가 제거된다.
func _test_brooch_timeout_clears_progress() -> void:
	_reset_counters_and_state()
	var brooch_effect := _effect_of(_brooch) as RepairBroochEffect
	var ball_id := _ball.get_instance_id()
	_hit_and_release(_brooch)
	_hit_and_release(_gears)
	_router.advance_time(6.5)
	_expect(not brooch_effect.has_mark(ball_id),
		"제한 시간이 끝난 마감 표식은 제거되어야 한다.")
	_hit_and_release(_bell)
	_expect(brooch_effect.get_visited_family_count(ball_id) == 0,
		"표식이 없는 상태의 방문은 세지 않아야 한다.")
	await process_frame


## 12. 공 낙하와 재시도에서 모든 임시 상태가 제거된다.
func _test_reset_rules() -> void:
	_reset_counters_and_state()
	_hit_and_release(_brooch)
	_hit_and_release(_needle)
	_hit_and_release(_bell)
	_hit_and_release(_gears)
	_router.on_ball_drained()
	var ball_id := _ball.get_instance_id()
	_expect(
		not (_effect_of(_brooch) as RepairBroochEffect).has_mark(ball_id),
		"공 낙하 시 마감 표식이 제거되어야 한다."
	)
	_expect(
		(_effect_of(_gears) as RepairGearEffect).get_wind_stack() == 0,
		"공 낙하 시 회전 단계가 0이 되어야 한다."
	)
	_expect(
		not (_effect_of(_needle) as RepairNeedleEffect).has_pending_stitch(ball_id),
		"공 낙하 시 봉합 대기가 제거되어야 한다."
	)
	_expect(
		not (_effect_of(_bell) as RepairBellEffect).has_pending_echo(ball_id),
		"공 낙하 시 여운 예약이 취소되어야 한다."
	)
	var combo_before := _combo_system.combo_count
	_router.advance_time(2.0)
	_expect(_combo_system.combo_count == combo_before,
		"취소된 여운은 시간이 지나도 울리면 안 된다.")
	await process_frame


## 복제 보드 테스트 씬 계약: 소켓 6개, 장착 부품 4개, 시스템 노드 존재.
func _test_board_test_scene_contract() -> void:
	var packed := load(BOARD_TEST_SCENE_PATH) as PackedScene
	_expect(packed != null, "repair_parts_board_test.tscn을 로드할 수 있어야 한다.")
	if packed == null:
		return
	var state := packed.get_state()
	var socket_count := 0
	var part_count := 0
	var has_router := false
	var has_session := false
	for node_index: int in range(state.get_node_count()):
		var node_name := String(state.get_node_name(node_index))
		# 컨테이너 노드 "Sockets"는 소켓 개수에서 제외합니다.
		if node_name.begins_with("Socket") and node_name != "Sockets":
			socket_count += 1
		if node_name.ends_with("Part"):
			part_count += 1
		if node_name == "RepairEffectRouter":
			has_router = true
		if node_name == "RepairSessionController":
			has_session = true
	_expect(socket_count == 6, "복제 보드 씬에는 수리 소켓이 6개 있어야 한다.")
	_expect(part_count == 4, "복제 보드 씬에는 부품 4종이 장착되어 있어야 한다.")
	_expect(has_router, "복제 보드 씬에 RepairEffectRouter가 있어야 한다.")
	_expect(has_session, "복제 보드 씬에 RepairSessionController가 있어야 한다.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: repair_parts_system_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: repair_parts_system_test (%d failures)" % _failures.size())
	quit(1)
