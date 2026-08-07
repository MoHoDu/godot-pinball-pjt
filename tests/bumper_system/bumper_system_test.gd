extends SceneTree


const BUTTON_SCENE := preload("res://scenes/bumper_system/button_bumper.tscn")
const COTTON_SCENE := preload("res://scenes/bumper_system/cotton_bumper.tscn")
const SPRING_SCENE := preload("res://scenes/bumper_system/spring_doll_bumper.tscn")
const DRUM_SCENE := preload("res://scenes/bumper_system/toy_drum_bumper.tscn")
const CANNON_SCENE := preload("res://scenes/bumper_system/clockwork_toy_cannon.tscn")
const STARLIGHT_SCENE := preload(
	"res://scenes/bumper_system/starlight_brooch_bumper.tscn"
)
const GOLDEN_GEARS_SCENE := preload(
	"res://scenes/bumper_system/golden_gears_bumper.tscn"
)
const CRESCENT_NEEDLE_SCENE := preload(
	"res://scenes/bumper_system/crescent_needle_bumper.tscn"
)
const FORGOTTEN_STAR_BELL_SCENE := preload(
	"res://scenes/bumper_system/forgotten_star_bell_bumper.tscn"
)
const BUMPER_TEST_SCENE := preload("res://scenes/bumper_system/bumper_test.tscn")
const STAGE_LAYOUT := preload("res://settings/bumpers/stage_01/Stage01BumperLayout.tres")
const BUMPER_WAVE_LOADOUT_SCRIPT := preload(
	"res://scripts/bumper-system/bumper_wave_loadout.gd"
)
const EPSILON := 0.001


var _failures: Array[String] = []
var _fixture_root: Node2D
var _ball: RigidBody2D


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_fixture_root = Node2D.new()
	root.add_child(_fixture_root)
	_ball = _create_ball()
	_fixture_root.add_child(_ball)
	await process_frame

	await _test_stage01_settings_and_strategies()
	await _test_contact_lifecycle_and_overrides()
	await _test_repair_part_eligibility()
	await _test_shot_control_and_deferred_destruction()
	_test_stage01_wave_layout()
	await _test_bumper_test_scene_contract()

	_fixture_root.queue_free()
	await process_frame
	_finish()


func _test_stage01_settings_and_strategies() -> void:
	var button := await _spawn(BUTTON_SCENE)
	var cotton := await _spawn(COTTON_SCENE)
	var spring := await _spawn(SPRING_SCENE)
	var drum := await _spawn(DRUM_SCENE)
	var cannon := await _spawn(CANNON_SCENE)

	_expect(button.settings.bumper_type == BumperSettings.BumperType.NORMAL,
		"단추는 Normal 타입이어야 한다.")
	_expect(cotton.settings.bumper_type == BumperSettings.BumperType.NORMAL,
		"솜은 Normal 타입이어야 한다.")
	_expect(spring.settings.bumper_type == BumperSettings.BumperType.BOUNCE,
		"용수철 인형은 Bounce 타입이어야 한다.")
	_expect(drum.settings.bumper_type == BumperSettings.BumperType.BOUNCE,
		"장난감 북은 Bounce 타입이어야 한다.")
	_expect(cannon.settings.bumper_type == BumperSettings.BumperType.SHOT,
		"태엽 장난감 대포는 Shot 타입이어야 한다.")
	_expect(cannon.object_settings is BumperObjectSettings,
		"범퍼 루트 Inspector에는 별도 Object Settings 리소스가 있어야 한다.")
	_expect(cannon.common_bumper_settings is BumperCommonSettings,
		"범퍼 루트 Inspector에는 별도 Common Bumper Settings 리소스가 있어야 한다.")
	_expect(cannon.type_settings is BumperTypeSettings,
		"범퍼 루트 Inspector에는 별도 Type Settings 리소스가 있어야 한다.")
	_expect(not _is_editor_property_visible(cannon, &"settings"),
		"전체 Settings 묶음은 Inspector에서 중복 노출되면 안 된다.")
	_expect(_is_editor_property_visible(cannon, &"object_settings") \
			and _is_editor_property_visible(cannon, &"common_bumper_settings") \
			and _is_editor_property_visible(cannon, &"type_settings"),
		"범퍼 루트 Inspector에는 분리된 설정 슬롯 3개가 표시되어야 한다.")
	_expect(not _is_editor_property_visible(button.type_settings, &"track_target_offset"),
		"Normal 범퍼 Inspector에는 Track 목표 위치가 표시되면 안 된다.")
	_expect(not _is_editor_property_visible(button.type_settings, &"launch_speed"),
		"Normal 범퍼 Inspector에는 Shot 발사 속력이 표시되면 안 된다.")
	_expect(_is_editor_property_visible(cannon.type_settings, &"launch_speed"),
		"Shot 범퍼 Inspector에는 발사 속력이 표시되어야 한다.")
	_expect(_is_editor_property_visible(cannon.type_settings, &"add_shot_direction_button"),
		"Shot 범퍼 Inspector에는 파일 생성 없는 발사 방향 추가 버튼이 보여야 한다.")
	_expect(not _is_editor_property_visible(cannon.type_settings, &"speed_multiplier"),
		"Shot 범퍼 Inspector에는 사용하지 않는 일반 반응 배율이 표시되면 안 된다.")
	var track_settings := button.settings.duplicate(true) as BumperSettings
	track_settings.bumper_type = BumperSettings.BumperType.TRACK
	_expect(_is_editor_property_visible(track_settings.type_settings, &"track_target_offset"),
		"Track 범퍼 Inspector에는 목표 위치가 표시되어야 한다.")
	_expect(not _is_editor_property_visible(track_settings.type_settings, &"selection_duration"),
		"Track 범퍼 Inspector에는 Shot 선택 시간이 표시되면 안 된다.")
	_expect(_is_editor_property_visible(button.object_settings, &"graphic_texture"),
		"Object Settings에는 실제 그래픽 Texture 교체 속성이 표시되어야 한다.")

	button.settings = button.settings.duplicate(true) as BumperSettings
	var original_collision_radius := button.get_collision_radius()
	var original_bumper_scale := button.scale
	var test_image := Image.create(200, 100, false, Image.FORMAT_RGBA8)
	var test_texture := ImageTexture.create_from_image(test_image)
	button.object_settings.graphic_texture = test_texture
	button.object_settings.visual_diameter = 120.0
	button.object_settings.graphic_size_ratio = 0.75
	var graphic_rect := button.object_settings.get_graphic_draw_rect()
	_expect(graphic_rect.size.is_equal_approx(Vector2(90.0, 45.0)),
		"실제 이미지는 긴 변을 기준으로 목표 외형 크기 안에 비율 유지되어야 한다.")
	_expect_float(button.get_collision_radius(), original_collision_radius,
		"그래픽 크기 변경은 범퍼 충돌 반경을 바꾸면 안 된다.")
	_expect(button.scale == original_bumper_scale,
		"그래픽 맞춤은 범퍼 루트 Scale을 변경하면 안 된다.")

	var context := BallImpactContext.new(
		_ball,
		Vector2(0.0, 940.0),
		Vector2.ZERO,
		Vector2.UP,
		Vector2.ZERO
	)
	var original_velocity := _ball.linear_velocity
	var button_response := button.response_strategy.build_response(context, button)
	var cotton_response := cotton.response_strategy.build_response(context, cotton)
	var spring_response := spring.response_strategy.build_response(context, spring)
	var drum_response := drum.response_strategy.build_response(context, drum)

	_expect(button_response is BumperResponse,
		"전략은 BumperResponse를 반환해야 한다.")
	_expect_float(button_response.speed_multiplier, 1.10,
		"단추 반사 배율은 1.10이어야 한다.")
	_expect_float(cotton_response.speed_multiplier, 0.90,
		"솜 반사 배율은 0.90이어야 한다.")
	_expect_float(spring_response.speed_multiplier, 1.25,
		"용수철 인형 반사 배율은 1.25여야 한다.")
	_expect_float(spring_response.minimum_speed, 1150.0,
		"용수철 인형 최저 방출 속력은 1150이어야 한다.")
	_expect_float(drum_response.speed_multiplier, 1.50,
		"장난감 북 반사 배율은 1.50이어야 한다.")
	_expect_float(drum_response.minimum_speed, 1400.0,
		"장난감 북 최저 방출 속력은 1400이어야 한다.")
	_expect(_ball.linear_velocity == original_velocity,
		"전략 계산 자체는 공의 속도를 직접 변경하면 안 된다.")
	_expect(button.response_strategy is NormalResponseStrategy,
		"Normal 범퍼는 NormalResponseStrategy를 공유해야 한다.")
	_expect(cotton.response_strategy is NormalResponseStrategy,
		"같은 Normal 타입은 같은 전략 클래스를 사용해야 한다.")
	_expect(spring.response_strategy is BounceResponseStrategy,
		"Bounce 범퍼는 BounceResponseStrategy를 공유해야 한다.")
	_expect(drum.response_strategy is BounceResponseStrategy,
		"같은 Bounce 타입은 같은 전략 클래스를 사용해야 한다.")

	for bumper: Bumper in [button, cotton, spring, drum, cannon]:
		bumper.queue_free()
	await process_frame


func _test_contact_lifecycle_and_overrides() -> void:
	var button := await _spawn(BUTTON_SCENE)
	var hit_count := [0]
	button.valid_hit_registered.connect(func(
		_bumper_id: StringName,
		_ball_value: RigidBody2D,
		_contact_id: int,
		_base_score: int
	) -> void:
		hit_count[0] += 1
	)

	_expect(button.current_durability == 2,
		"단추는 최대 내구도 2로 시작해야 한다.")
	_expect(button.register_valid_hit(_ball, 101),
		"새 접촉은 유효 타격으로 등록되어야 한다.")
	_expect(button.current_durability == 1,
		"첫 타격에서 내구도가 한 번 감소해야 한다.")
	_expect(not button.register_valid_hit(_ball, 101),
		"지속 접촉은 중복 타격으로 거절해야 한다.")
	_expect(hit_count[0] == 1,
		"지속 접촉에서 이벤트는 한 번만 발생해야 한다.")
	_expect(button.release_contact(101),
		"실제 분리 시 접촉 잠금을 해제할 수 있어야 한다.")
	_expect(button.register_valid_hit(_ball, 101),
		"분리 후 재접촉은 새 타격이어야 한다.")
	_expect(button.state == Bumper.BumperState.DESTROYED_TIMER,
		"내구도 소진 후 파괴 타이머 상태로 전환해야 한다.")
	_expect(not button.register_valid_hit(_ball, 202),
		"파괴 상태에서는 새 타격을 받으면 안 된다.")

	button.respawn_timer.stop()
	button.begin_safe_respawn_wait()
	_expect(button.state == Bumper.BumperState.SAFE_RESPAWN_WAIT,
		"최소 복구 시간 후 안전 복구 대기로 전환해야 한다.")
	_ball.freeze = false
	_ball.global_position = button.global_position
	_ball.linear_velocity = Vector2(600.0, 0.0)
	_expect(not button.can_reactivate(),
		"공이 복구 위치와 겹치면 범퍼를 활성화하면 안 된다.")
	_ball.global_position = button.global_position + Vector2(1000.0, 0.0)
	_ball.linear_velocity = Vector2(600.0, 0.0)
	await physics_frame
	await physics_frame
	_expect(button.can_reactivate(),
		"공과 짧은 예상 경로가 안전 영역을 벗어나면 복구할 수 있어야 한다.")
	button.reactivate()
	_expect(button.state == Bumper.BumperState.ACTIVE,
		"안전 조건 충족 후 활성 상태로 복구해야 한다.")
	_expect(button.current_durability == 2,
		"복구 시 내구도를 최대값으로 초기화해야 한다.")

	var overrides := BumperInstanceOverrides.new()
	overrides.speed_multiplier = 1.35
	overrides.max_durability = 4
	overrides.base_score = 175
	button.instance_overrides = overrides
	_expect_float(button.get_speed_multiplier(), 1.35,
		"개별 Inspector 배율이 공용 설정을 덮어써야 한다.")
	_expect(button.get_max_durability() == 4,
		"개별 Inspector 내구도가 공용 설정을 덮어써야 한다.")
	_expect(button.get_base_score() == 175,
		"개별 Inspector 점수가 공용 설정을 덮어써야 한다.")

	button.queue_free()
	await process_frame


func _test_repair_part_eligibility() -> void:
	var button := await _spawn(BUTTON_SCENE)
	var spring := await _spawn(SPRING_SCENE)
	var cannon := await _spawn(CANNON_SCENE) as ShotBumper
	var repair_scenes: Array[PackedScene] = [
		STARLIGHT_SCENE,
		GOLDEN_GEARS_SCENE,
		CRESCENT_NEEDLE_SCENE,
		FORGOTTEN_STAR_BELL_SCENE,
	]
	var repair_bumpers: Array[Bumper] = []
	var reward_table: Array[BumperSettings] = [button.settings]
	var unique_ids: Dictionary = {}

	_expect(not button.is_repair_part(),
		"Stage 01 단추의 수리 부품 자격은 명시적으로 false여야 한다.")
	_expect(not button.settings.is_reward_candidate(),
		"수리 부품이 아닌 범퍼는 보상 후보에서 제외되어야 한다.")

	for repair_scene: PackedScene in repair_scenes:
		var bumper := await _spawn(repair_scene)
		repair_bumpers.append(bumper)
		reward_table.append(bumper.settings)
		_expect(bumper.get_script() == Bumper,
			"수리 부품 자격 범퍼는 별도 하위 타입이 아닌 Bumper여야 한다.")
		_expect(bumper.is_repair_part(),
			"플레이어 보상·보유·배치 범퍼는 수리 부품 자격이 true여야 한다.")
		_expect(bumper.settings.is_reward_candidate(),
			"보상 시스템 공개 계약이 수리 부품 범퍼를 후보로 반환해야 한다.")
		_expect(
			bumper.settings.mechanics_status
				== BumperSettings.MechanicsStatus.CONCEPT_ONLY,
			"미정 고유 효과는 BumperSettings에서 CONCEPT_ONLY로 보존해야 한다."
		)
		_expect(not unique_ids.has(bumper.settings.bumper_kind_id),
			"보상 시스템이 비교할 bumper_kind_id는 중복되면 안 된다.")
		unique_ids[bumper.settings.bumper_kind_id] = true

	var reward_cannon_settings := cannon.settings.duplicate(true) as BumperSettings
	reward_cannon_settings.is_repair_part = true
	cannon.settings = reward_cannon_settings
	reward_table.append(cannon.settings)
	_expect(cannon.is_repair_part(),
		"ShotBumper도 설정에 따라 수리 부품이 될 수 있어야 한다.")
	_expect(cannon.response_strategy is ShotResponseStrategy,
		"수리 부품 자격은 Shot 충돌 전략을 변경하면 안 된다.")

	var reward_spring_settings := spring.settings.duplicate(true) as BumperSettings
	reward_spring_settings.is_repair_part = true
	spring.settings = reward_spring_settings
	var spring_overrides := BumperInstanceOverrides.new()
	spring_overrides.speed_multiplier = 1.75
	spring.instance_overrides = spring_overrides
	reward_table.append(spring.settings)
	_expect(spring.is_repair_part(),
		"Bounce 범퍼도 설정에 따라 수리 부품이 될 수 있어야 한다.")
	_expect(spring.response_strategy is BounceResponseStrategy,
		"수리 부품 자격과 인스턴스 오버라이드는 Bounce 전략을 변경하면 안 된다.")
	_expect_float(spring.get_speed_multiplier(), 1.75,
		"인스턴스 밸런스 오버라이드는 수리 부품 자격과 독립적으로 적용되어야 한다.")

	var reward_candidate_ids: Array[StringName] = []
	for settings: BumperSettings in reward_table:
		if settings.is_reward_candidate():
			reward_candidate_ids.append(settings.bumper_kind_id)
	_expect(reward_candidate_ids.size() == 6,
		"테이블형 보상 목록은 자격 속성만으로 후보 6개를 필터링해야 한다.")
	_expect(not reward_candidate_ids.has(button.settings.bumper_kind_id),
		"보상 필터는 수리 부품 자격이 없는 범퍼를 포함하면 안 된다.")

	button.queue_free()
	spring.queue_free()
	cannon.queue_free()
	for bumper: Bumper in repair_bumpers:
		bumper.queue_free()
	await process_frame


func _test_shot_control_and_deferred_destruction() -> void:
	var cannon := await _spawn(CANNON_SCENE) as ShotBumper
	var anchors := cannon.get_launch_anchors()
	var safe_count := 0
	var safe_anchor: ShotLaunchAnchor
	for anchor: ShotLaunchAnchor in anchors:
		if anchor.is_safe_default:
			safe_count += 1
			safe_anchor = anchor
	_expect(anchors.size() > 3,
		"캐논은 기본 입력 키 수보다 많은 발사 방향을 설정할 수 있어야 한다.")
	_expect(not cannon.has_node(^"LaunchAnchors"),
		"Shot 발사 방향은 씬 자식 노드가 아닌 Settings 배열에서 관리해야 한다.")
	_expect(safe_count == 1,
		"캐논 안전 기본 방향은 정확히 하나여야 한다.")
	_expect_float(cannon.get_selection_duration(), 2.0,
		"캐논 방향 선택 시간은 2.0초여야 한다.")
	_expect_float(cannon.get_launch_speed(), 1300.0,
		"캐논 고정 발사 속력은 1300이어야 한다.")
	_expect(not safe_anchor.release_position.is_zero_approx(),
		"캐논 안전 발사 위치는 Inspector에서 편집 가능한 좌표여야 한다.")
	_expect(cannon.get_selected_launch_direction().is_equal_approx(
			safe_anchor.get_local_launch_direction()),
		"캐논 발사 위치 좌표가 실제 발사 방향에 적용되어야 한다.")
	var editable_settings := cannon.settings.duplicate(true) as BumperSettings
	var editable_directions := editable_settings.shot_launch_directions.duplicate()
	editable_directions.remove_at(2)
	var diagonal_direction := ShotLaunchAnchor.new()
	diagonal_direction.display_name = "오른쪽 위"
	diagonal_direction.release_position = Vector2(82.0, -82.0)
	editable_directions.append(diagonal_direction)
	editable_settings.shot_launch_directions = editable_directions
	_expect(editable_settings.shot_launch_directions.size() == anchors.size(),
		"Inspector 배열에서 Shot 방향을 삭제하고 새 방향을 추가할 수 있어야 한다.")
	_expect(editable_settings.shot_launch_directions[-1].display_name == "오른쪽 위",
		"Inspector 배열에서 Shot 방향 속성을 수정할 수 있어야 한다.")
	var direction_count_before_add := editable_settings.shot_launch_directions.size()
	var mouse_editable_direction := editable_settings.type_settings.add_shot_direction()
	_expect(editable_settings.shot_launch_directions.size() == direction_count_before_add + 1,
		"발사 방향 추가 버튼은 Shot 방향을 즉시 하나 추가해야 한다.")
	_expect(mouse_editable_direction.resource_path.is_empty(),
		"추가 버튼으로 만든 방향은 별도 Resource 파일을 요구하면 안 된다.")
	_expect(mouse_editable_direction.release_position.length() > 0.0,
		"새 방향은 2D 핸들로 즉시 편집할 수 있는 초기 위치를 가져야 한다.")
	_expect(not _is_editor_property_visible(
			mouse_editable_direction, &"input_action"),
		"Shot 방향에는 방향별 키를 지정하는 input_action이 표시되면 안 된다.")

	var editor_settings := cannon.settings.duplicate(true) as BumperSettings
	cannon.settings = editor_settings
	editor_settings.collision_diameter = 140.0
	var cannon_shape := cannon.get_node(^"CollisionShape2D") as CollisionShape2D
	_expect_float((cannon_shape.shape as CircleShape2D).radius, 70.0,
		"Inspector 크기 변경은 물리 충돌 범위에 즉시 반영되어야 한다.")

	_expect(cannon.register_valid_hit(_ball, 301),
		"캐논 첫 접촉은 유효 타격이어야 한다.")
	await process_frame
	_expect(_ball.freeze,
		"캐논 방향 선택 중에는 공을 포신 내부에 고정해야 한다.")
	_expect(cannon.current_durability == 1,
		"캐논 첫 사용 후 내구도는 1이어야 한다.")
	var visited_anchors: Dictionary = {
		cannon.get_selected_launch_anchor().get_instance_id(): true,
	}
	for _index in range(anchors.size() - 1):
		var next_direction_event := InputEventAction.new()
		next_direction_event.action = ShotBumper.NEXT_DIRECTION_ACTION
		next_direction_event.pressed = true
		cannon._unhandled_input(next_direction_event)
		visited_anchors[
			cannon.get_selected_launch_anchor().get_instance_id()
		] = true
	_expect(visited_anchors.size() == anchors.size(),
		"Shot 방향이 네 개를 넘어도 오른쪽 입력으로 모든 방향을 순회해야 한다.")
	var selected_before_previous := cannon.get_selected_launch_anchor()
	var previous_direction_event := InputEventAction.new()
	previous_direction_event.action = ShotBumper.PREVIOUS_DIRECTION_ACTION
	previous_direction_event.pressed = true
	cannon._unhandled_input(previous_direction_event)
	_expect(cannon.get_selected_launch_anchor() != selected_before_previous,
		"왼쪽 입력은 현재 방향의 이전 방향을 선택해야 한다.")
	_expect(cannon.release_controlled_ball(),
		"스페이스 입력과 같은 즉시 발사 경로를 제공해야 한다.")
	_expect_float(_ball.linear_velocity.length(), 1300.0,
		"캐논은 진입 속도와 무관하게 1300으로 발사해야 한다.")
	_ball.global_position = cannon.global_position + Vector2(500.0, 0.0)
	await physics_frame
	await physics_frame
	_expect(cannon.state == Bumper.BumperState.ACTIVE,
		"첫 사용의 안전 이탈 후 캐논은 활성 상태를 유지해야 한다.")

	cannon.release_contact(301)
	_ball.linear_velocity = Vector2(0.0, -600.0)
	_expect(cannon.register_valid_hit(_ball, 302),
		"캐논 두 번째 분리 후 접촉은 새 타격이어야 한다.")
	await process_frame
	_expect(cannon.current_durability == 0,
		"캐논 두 번째 사용에서 내구도는 0이어야 한다.")
	_expect(cannon.state == Bumper.BumperState.ACTIVE,
		"캐논은 발사 전에 즉시 파괴되면 안 된다. (state=%s)" \
			% Bumper.BumperState.keys()[cannon.state])
	cannon.release_controlled_ball()
	_ball.global_position = cannon.global_position + Vector2(500.0, 0.0)
	await physics_frame
	await physics_frame
	_expect(cannon.state == Bumper.BumperState.DESTROYED_TIMER,
		"두 번째 발사와 안전 이탈을 마친 뒤 파괴되어야 한다.")
	cannon.reset_for_new_ball()
	_expect(cannon.state == Bumper.BumperState.ACTIVE \
			and cannon.current_durability == 2,
		"새 발사 준비에서는 Shot 제어 상태와 타이머를 정리하고 즉시 복구해야 한다.")

	cannon.queue_free()
	await process_frame


func _test_bumper_test_scene_contract() -> void:
	var scene := BUMPER_TEST_SCENE.instantiate() as BumperTestController
	_expect(scene != null, "bumper_test.tscn을 인스턴스화할 수 있어야 한다.")
	if scene == null:
		return
	_expect(scene.bumper_scenes.size() == 9,
		"Inspector 목록에 Stage 01 범퍼 5종과 자격 범퍼 4종이 필요하다.")
	var eligible_count := 0
	for bumper_scene: PackedScene in scene.bumper_scenes:
		var preview := bumper_scene.instantiate() as Bumper
		_expect(preview != null,
			"테스트 목록의 모든 프리팹 루트는 Bumper여야 한다.")
		if preview != null:
			if preview.is_repair_part():
				eligible_count += 1
			preview.free()
	_expect(eligible_count == 4,
		"테스트 목록은 별도 타입 없이 수리 부품 자격 범퍼 4종을 포함해야 한다.")
	_expect(scene.ball_scene != null,
		"낙하 테스트에 사용할 Pinball Scene이 필요하다.")
	_expect(scene.get_node_or_null("TestRig/BumperSlot") != null,
		"선택 범퍼를 교체할 단일 BumperSlot이 필요하다.")
	_expect(scene.get_node_or_null("TestRig/Balls") != null,
		"낙하 공을 생성할 Balls 루트가 필요하다.")

	_fixture_root.add_child(scene)
	await process_frame
	_expect(scene.current_state == BumperTestController.TestState.SELECTING,
		"테스트 씬은 범퍼 선택 상태로 시작해야 한다.")
	_expect(scene.current_bumper is Bumper,
		"첫 Inspector 목록 범퍼가 즉시 미리보기 되어야 한다.")
	var first_scene := scene.get_selected_scene()
	await _send_key(KEY_RIGHT)
	_expect(scene.current_index == 1 \
			and scene.get_selected_scene() != first_scene,
		"좌우 선택은 Inspector 목록의 다음 범퍼로 교체해야 한다.")
	await _send_key(KEY_SPACE)
	_expect(scene.current_state == BumperTestController.TestState.RUNNING,
		"Space 입력 후 테스트 상태는 RUNNING이어야 한다.")
	_expect(is_instance_valid(scene.current_ball),
		"선택 범퍼 위에 실제 Pinball을 생성해야 한다.")
	if is_instance_valid(scene.current_ball) and is_instance_valid(scene.current_bumper):
		_expect(scene.current_ball.global_position.y \
				< scene.current_bumper.global_position.y,
			"공은 선택 범퍼 바로 위에서 낙하를 시작해야 한다.")
	for _frame in 120:
		if scene.hit_count > 0:
			break
		await physics_frame
	_expect(scene.hit_count == 1,
		"수직 낙하한 공은 선택 범퍼에 실제 타격을 한 번 등록해야 한다.")
	var previous_ball := scene.current_ball
	var previous_bumper := scene.current_bumper
	await _send_key(KEY_R)
	_expect(is_instance_valid(scene.current_ball) \
			and scene.current_ball != previous_ball \
			and scene.current_bumper != previous_bumper \
			and scene.current_index == 1,
		"재시작은 선택을 유지하고 공과 범퍼를 새 인스턴스로 교체해야 한다.")

	await _send_key(KEY_LEFT)
	_expect(scene.current_index == 0 \
			and scene.current_state == BumperTestController.TestState.SELECTING,
		"실행 중 범퍼 전환은 현재 테스트를 중단하고 선택 상태로 돌아가야 한다.")
	await _send_key(KEY_ENTER)
	_expect(scene.current_state == BumperTestController.TestState.RUNNING,
		"Enter 입력으로도 공 낙하를 시작할 수 있어야 한다.")

	while scene.current_index != 4:
		await _send_key(KEY_D)
	_expect(scene.current_bumper is ShotBumper,
		"Inspector 목록의 캐논 항목은 ShotBumper여야 한다.")
	await _send_key(KEY_SPACE)
	_expect(scene.current_state == BumperTestController.TestState.RUNNING,
		"캐논 테스트도 Space 입력으로 시작해야 한다.")
	var cannon := scene.current_bumper as ShotBumper
	cannon.call(&"_begin_selection", scene.current_ball)
	await process_frame
	_expect(scene.current_ball.freeze,
		"캐논 입력 검증은 실제 Shot 제어 상태에서 실행해야 한다.")
	var cannon_index := scene.current_index
	var cannon_anchors := cannon.get_launch_anchors()
	var initial_anchor := cannon.get_selected_launch_anchor()
	var initial_anchor_index := cannon_anchors.find(initial_anchor)
	await _send_key(KEY_LEFT)
	_expect(scene.current_index == cannon_index \
			and cannon.get_selected_launch_anchor() \
				== cannon_anchors[wrapi(
					initial_anchor_index - 1, 0, cannon_anchors.size())],
		"캐논 제어 중 왼쪽 방향키는 이전 발사 방향을 선택해야 한다.")
	await _send_key(KEY_RIGHT)
	_expect(scene.current_index == cannon_index \
			and cannon.get_selected_launch_anchor() == initial_anchor,
		"캐논 제어 중 오른쪽 방향키는 다음 발사 방향을 선택해야 한다.")
	await _send_key(KEY_RIGHT)
	var selected_launch_direction := cannon.get_selected_launch_direction()
	await _send_key(KEY_SPACE)
	_expect(not scene.current_ball.freeze \
			and scene.current_ball.linear_velocity.normalized() \
				.dot(selected_launch_direction) > 0.99,
		"캐논 제어 중 Space 입력은 선택 방향으로 공을 발사해야 한다.")

	var saved_scenes := scene.bumper_scenes
	scene.bumper_scenes = []
	_expect(not scene.select_next() and not scene.restart_test(),
		"빈 Inspector 목록은 선택과 재시작을 안전하게 거절해야 한다.")
	scene.bumper_scenes = [null]
	scene.current_index = 0
	scene.call(&"_prepare_selected_bumper")
	_expect(scene.current_bumper == null,
		"null Inspector 항목은 오류 없이 거절해야 한다.")
	var invalid_scene := PackedScene.new()
	var invalid_root := Node2D.new()
	invalid_scene.pack(invalid_root)
	invalid_root.free()
	scene.bumper_scenes = [invalid_scene]
	scene.call(&"_prepare_selected_bumper")
	_expect(scene.current_bumper == null,
		"Bumper가 아닌 PackedScene 항목은 오류 없이 거절해야 한다.")
	scene.bumper_scenes = saved_scenes

	scene.queue_free()
	await process_frame


func _test_stage01_wave_layout() -> void:
	var layout: Resource = STAGE_LAYOUT
	_expect(layout != null and bool(layout.call(&"is_valid")),
		"Stage 01 웨이브 배치 Resource가 유효해야 한다.")
	if layout == null:
		return
	var waves: Array = layout.get(&"waves")
	_expect(waves.size() == 4,
		"Stage 01은 일반 3웨이브와 보스 웨이브를 정의해야 한다.")
	var wave1: Resource = layout.call(&"get_wave", 0)
	var wave2: Resource = layout.call(&"get_wave", 1)
	var wave3: Resource = layout.call(&"get_wave", 2)
	var boss: Resource = layout.call(&"get_wave", 3)
	_expect(wave1.get(&"normal_count_range") == Vector2i(4, 6) \
			and wave1.get(&"bounce_count_range") == Vector2i.ZERO \
			and wave1.get(&"shot_count_range") == Vector2i.ZERO,
		"웨이브 1은 Normal 4~6개만 사용해야 한다.")
	_expect(wave2.get(&"bounce_count_range") == Vector2i(2, 3) \
			and wave2.get(&"shot_count_range") == Vector2i.ZERO,
		"웨이브 2에서 Bounce 2~3개를 처음 도입해야 한다.")
	_expect(wave3.get(&"board_shape") \
			== BUMPER_WAVE_LOADOUT_SCRIPT.BoardShape.SQUARE \
			and wave3.get(&"shot_count_range") == Vector2i(1, 2),
		"웨이브 3은 사각 보드에서 Shot 1~2개를 도입해야 한다.")
	_expect(boss.get(&"shot_count_range") == Vector2i(2, 2),
		"보스 웨이브에는 Shot 범퍼 2개가 필요하다.")


func _spawn(scene: PackedScene) -> Bumper:
	var bumper := scene.instantiate() as Bumper
	_fixture_root.add_child(bumper)
	await process_frame
	return bumper


func _create_ball() -> RigidBody2D:
	var ball := RigidBody2D.new()
	ball.add_to_group(&"pinball_balls")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	collision.shape = circle
	ball.add_child(collision)
	ball.linear_velocity = Vector2(0.0, 940.0)
	return ball


func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _send_key(keycode: Key) -> void:
	Input.parse_input_event(_pressed_key(keycode))
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON,
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _is_editor_property_visible(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) != property_name:
			continue
		return (int(property.usage) & PROPERTY_USAGE_EDITOR) != 0
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bumper_system_test")
		quit(0)
		return
	print("FAIL: bumper_system_test (%d failures)" % _failures.size())
	quit(1)
