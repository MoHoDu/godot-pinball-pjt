extends "res://tests/flipper_system/test_flipper_scene.gd"


enum TestMode {
	BASELINE,
	ACTUAL_TIMING,
	FORCE_NORMAL,
	FORCE_PERFECT,
}


const DEFAULT_PARRY_RULES: Resource = preload(
	"res://settings/flippers/FlipperParryRules.tres"
)
const MODE_NAMES: Array[String] = [
	"패링 없음 비교",
	"기획값 실전 타이밍",
	"일반 패링 고정 비교",
	"정확 패링 고정 비교",
]


@export_node_path("PinballFlipper") var left_flipper_path: NodePath = \
	^"FlipperControllers/FlipperController/LeftFlipper"
@export_node_path("PinballFlipper") var right_flipper_path: NodePath = \
	^"FlipperControllers/FlipperController/RightFlipper"
@export_node_path("Label") var guide_label_path: NodePath = \
	^"ParryTestGuide/Panel/GuideLabel"


@onready var left_flipper: PinballFlipper = get_node_or_null(
	left_flipper_path
) as PinballFlipper
@onready var right_flipper: PinballFlipper = get_node_or_null(
	right_flipper_path
) as PinballFlipper
@onready var guide_label: Label = get_node_or_null(guide_label_path) as Label


var current_mode: TestMode = TestMode.ACTUAL_TIMING
var _test_parry_rules: FlipperParryRules
var _last_result := "아직 충돌 없음"
var _last_elapsed_time := -1.0
var _last_multiplier := 1.0
var _last_outgoing_speed := 0.0
var _last_parry_physics_frame := -1


func _ready() -> void:
	super._ready()
	_test_parry_rules = DEFAULT_PARRY_RULES.duplicate(true) as FlipperParryRules
	_test_parry_rules.resource_local_to_scene = true

	for flipper: PinballFlipper in [left_flipper, right_flipper]:
		if not is_instance_valid(flipper):
			continue
		flipper.set_parry_rules(_test_parry_rules)
		flipper.contact_zone_a_speed_multiplier = 1.0
		flipper.contact_zone_b_speed_multiplier = 1.0
		flipper.contact_zone_c_speed_multiplier = 1.0
		flipper.contact_zone_d_speed_multiplier = 1.0
		if not flipper.parry_resolved.is_connected(_on_parry_resolved):
			flipper.parry_resolved.connect(_on_parry_resolved)
		if not flipper.rotation_sweep_resolved.is_connected(
			_on_rotation_sweep_resolved
		):
			flipper.rotation_sweep_resolved.connect(_on_rotation_sweep_resolved)

	if is_instance_valid(ball):
		var ball_stats: Variant = ball.get(&"stats")
		if ball_stats is Resource:
			ball_stats.set(&"maximum_speed", 5000.0)

	_normalize_contact_zone_rules()
	select_test_mode(TestMode.ACTUAL_TIMING)


func _process(_delta: float) -> void:
	_refresh_guide_text()


func _input(event: InputEvent) -> void:
	super._input(event)
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_0:
			select_test_mode(TestMode.BASELINE)
		KEY_1:
			select_test_mode(TestMode.ACTUAL_TIMING)
		KEY_2:
			select_test_mode(TestMode.FORCE_NORMAL)
		KEY_3:
			select_test_mode(TestMode.FORCE_PERFECT)


func select_test_mode(mode: int) -> void:
	current_mode = clampi(
		mode,
		TestMode.BASELINE,
		TestMode.FORCE_PERFECT
	) as TestMode
	if _test_parry_rules == null:
		return

	match current_mode:
		TestMode.BASELINE:
			_set_timing_windows(0.0, 0.0)
		TestMode.ACTUAL_TIMING:
			_set_timing_windows(0.095, 0.042)
		TestMode.FORCE_NORMAL:
			_set_timing_windows(2.0, 0.0)
		TestMode.FORCE_PERFECT:
			_set_timing_windows(2.0, 2.0)

	_test_parry_rules.normal_parry_speed_multiplier = 1.08
	_test_parry_rules.perfect_parry_speed_multiplier = 1.18
	reset_ball()


func get_test_parry_rules() -> Resource:
	return _test_parry_rules


func reset_ball() -> void:
	_last_result = "공 낙하 중 — Space 타이밍을 맞추세요"
	_last_elapsed_time = -1.0
	_last_multiplier = 1.0
	_last_outgoing_speed = 0.0
	super.reset_ball()


func _set_timing_windows(normal_time: float, perfect_time: float) -> void:
	# Resource setter가 정확 시간을 일반 시간 안으로 제한하므로 일반 시간을 먼저 설정합니다.
	_test_parry_rules.normal_parry_window_time = normal_time
	_test_parry_rules.perfect_parry_window_time = perfect_time


func _normalize_contact_zone_rules() -> void:
	for zone_name: String in ["a", "b", "c", "d"]:
		_test_parry_rules.set(
			StringName("zone_%s_speed_multiplier" % zone_name),
			1.0
		)
		_test_parry_rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			false
		)


func _on_parry_resolved(
	hit_ball: RigidBody2D,
	grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	elapsed_time: float,
	multiplier: float
) -> void:
	_last_parry_physics_frame = Engine.get_physics_frames()
	_last_result = "PERFECT!" if grade == 2 else "PARRY!"
	_last_elapsed_time = elapsed_time
	_last_multiplier = multiplier
	call_deferred(&"_capture_outgoing_speed", hit_ball)


func _on_rotation_sweep_resolved(hit_ball: RigidBody2D) -> void:
	var collision_frame := Engine.get_physics_frames()
	call_deferred(&"_record_non_parry_if_needed", hit_ball, collision_frame)


func _record_non_parry_if_needed(
	hit_ball: RigidBody2D,
	collision_frame: int
) -> void:
	if collision_frame == _last_parry_physics_frame:
		return
	_last_result = "패링 판정 밖 충돌"
	_last_elapsed_time = -1.0
	_last_multiplier = 1.0
	_capture_outgoing_speed(hit_ball)


func _capture_outgoing_speed(hit_ball: RigidBody2D) -> void:
	if is_instance_valid(hit_ball):
		_last_outgoing_speed = hit_ball.linear_velocity.length()


func _refresh_guide_text() -> void:
	if not is_instance_valid(guide_label) or _test_parry_rules == null:
		return

	var elapsed_text := (
		"%.1f ms" % (_last_elapsed_time * 1000.0)
		if _last_elapsed_time >= 0.0
		else "판정 없음"
	)
	var current_ball_speed := ball.linear_velocity.length() \
		if is_instance_valid(ball) else 0.0
	guide_label.text = (
		"일반·정확 패링 타이밍 테스트\n"
		+ "[0] 패링 없음  [1] 실전 판정  [2] 일반 고정  [3] 정확 고정\n"
		+ "[R] 공 재배치  [Space] 플리퍼 작동\n\n"
		+ "현재 모드: %s\n" % MODE_NAMES[int(current_mode)]
		+ "판정 구간: 정확 %.0f ms / 일반 %.0f ms\n" % [
			_test_parry_rules.perfect_parry_window_time * 1000.0,
			_test_parry_rules.normal_parry_window_time * 1000.0,
		]
		+ "최근 결과: %s\n" % _last_result
		+ "입력→접촉: %s / 적용 배율: %.2fx\n" % [
			elapsed_text,
			_last_multiplier,
		]
		+ "충돌 후 속력: %.1f px/s / 현재 속력: %.1f px/s" % [
			_last_outgoing_speed,
			current_ball_speed,
		]
	)
