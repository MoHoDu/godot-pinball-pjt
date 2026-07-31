extends "res://tests/flipper_system/test_flipper_scene.gd"


enum TestMode {
	BASELINE,
	SPEED,
	ANGLE,
}


const ZONE_NAMES: Array[String] = ["A", "B", "C", "D"]
const SPEED_MULTIPLIERS: Array[float] = [0.65, 0.9, 1.15, 1.4]
const ANGLE_CORRECTIONS: Array[float] = [-20.0, -8.0, 8.0, 20.0]


@export_node_path("PinballFlipper") var left_flipper_path: NodePath = \
	^"FlipperControllers/FlipperController/LeftFlipper"
@export_node_path("PinballFlipper") var right_flipper_path: NodePath = \
	^"FlipperControllers/FlipperController/RightFlipper"
@export_node_path("Label") var guide_label_path: NodePath = \
	^"TestGuide/Panel/GuideLabel"


@onready var left_flipper: PinballFlipper = get_node_or_null(
	left_flipper_path
) as PinballFlipper
@onready var right_flipper: PinballFlipper = get_node_or_null(
	right_flipper_path
) as PinballFlipper
@onready var guide_label: Label = get_node_or_null(guide_label_path) as Label


var current_mode: TestMode = TestMode.SPEED
var current_zone: PinballFlipper.ContactZone = PinballFlipper.ContactZone.B
var target_right_flipper: bool = true
var _test_parry_rules: FlipperParryRules


func _ready() -> void:
	super._ready()
	_test_parry_rules = FlipperParryRules.new()
	_test_parry_rules.show_contact_zones_in_editor = true
	_test_parry_rules.zone_a_end_percent = 35.0
	_test_parry_rules.zone_b_end_percent = 70.0
	_test_parry_rules.zone_c_end_percent = 90.0
	_test_parry_rules.left_angle_direction_sign = -1.0
	_test_parry_rules.right_angle_direction_sign = 1.0

	for flipper: PinballFlipper in [left_flipper, right_flipper]:
		if not is_instance_valid(flipper):
			continue
		flipper.contact_zone_a_speed_multiplier = 1.0
		flipper.contact_zone_b_speed_multiplier = 1.0
		flipper.contact_zone_c_speed_multiplier = 1.0
		flipper.contact_zone_d_speed_multiplier = 1.0
		flipper.set_parry_rules(_test_parry_rules)

	if is_instance_valid(ball) and ball.has_method(&"get"):
		var ball_stats: Variant = ball.get(&"stats")
		if ball_stats is Resource:
			ball_stats.set(&"maximum_speed", 5000.0)

	select_test_mode(TestMode.SPEED)


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
			select_test_mode(TestMode.SPEED)
		KEY_2:
			select_test_mode(TestMode.ANGLE)
		KEY_3:
			select_contact_zone(PinballFlipper.ContactZone.A)
		KEY_4:
			select_contact_zone(PinballFlipper.ContactZone.B)
		KEY_5:
			select_contact_zone(PinballFlipper.ContactZone.C)
		KEY_6:
			select_contact_zone(PinballFlipper.ContactZone.D)
		KEY_TAB:
			toggle_target_flipper()
		KEY_SPACE:
			release_ball_for_hit()


func select_test_mode(mode: int) -> void:
	current_mode = clampi(mode, TestMode.BASELINE, TestMode.ANGLE) as TestMode
	if _test_parry_rules == null:
		return

	for zone_index in PinballFlipper.ContactZone.size():
		var zone_name := ZONE_NAMES[zone_index].to_lower()
		var speed_multiplier := (
			SPEED_MULTIPLIERS[zone_index]
			if current_mode == TestMode.SPEED
			else 1.0
		)
		_test_parry_rules.set(
			StringName("zone_%s_speed_multiplier" % zone_name),
			speed_multiplier
		)
		_test_parry_rules.set(
			StringName("zone_%s_angle_correction_enabled" % zone_name),
			current_mode == TestMode.ANGLE
		)
		_test_parry_rules.set(
			StringName("zone_%s_angle_correction_degrees" % zone_name),
			ANGLE_CORRECTIONS[zone_index]
		)

	reset_ball()


func select_contact_zone(zone: int) -> void:
	current_zone = clampi(
		zone,
		PinballFlipper.ContactZone.A,
		PinballFlipper.ContactZone.D
	) as PinballFlipper.ContactZone
	reset_ball()


func toggle_target_flipper() -> void:
	target_right_flipper = not target_right_flipper
	reset_ball()


func get_test_parry_rules() -> Resource:
	return _test_parry_rules


func get_target_flipper() -> PinballFlipper:
	return right_flipper if target_right_flipper else left_flipper


func reset_ball() -> void:
	if not is_instance_valid(ball):
		return

	var target_flipper := get_target_flipper()
	if not is_instance_valid(target_flipper):
		return

	ball.freeze = true
	ball.global_position = _get_zone_test_position(target_flipper, current_zone)
	ball_reset_position = ball.global_position
	ball.rotation = 0.0
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.reset_physics_interpolation()
	ball_reset_completed.emit()


func release_ball_for_hit() -> void:
	if not is_instance_valid(ball):
		return

	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.sleeping = false
	ball.freeze = false


func _get_zone_test_position(
	flipper: PinballFlipper,
	zone: PinballFlipper.ContactZone
) -> Vector2:
	var axis_data := flipper.call(&"_get_local_contact_zone_axis_data") as Dictionary
	if axis_data.is_empty():
		return flipper.global_position

	var axis: Vector2 = axis_data.get(&"axis", Vector2.RIGHT)
	var tip_distance := float(axis_data.get(&"tip_distance", flipper.flipper_length))
	var percent := _get_zone_center_percent(zone)
	var local_contact_point := axis * tip_distance * percent / 100.0
	var middle_rotation := lerp_angle(
		deg_to_rad(flipper.initial_angle_degrees),
		deg_to_rad(flipper.maximum_angle_degrees),
		0.5
	)
	var parent_transform := Transform2D.IDENTITY
	if flipper.get_parent() is Node2D:
		parent_transform = (flipper.get_parent() as Node2D).global_transform
	var middle_flipper_transform := Transform2D(middle_rotation, flipper.position)
	return parent_transform * middle_flipper_transform * local_contact_point


func _get_zone_center_percent(zone: PinballFlipper.ContactZone) -> float:
	var a_end := float(_test_parry_rules.zone_a_end_percent)
	var b_end := float(_test_parry_rules.zone_b_end_percent)
	var c_end := float(_test_parry_rules.zone_c_end_percent)
	match zone:
		PinballFlipper.ContactZone.A:
			return a_end * 0.5
		PinballFlipper.ContactZone.B:
			return (a_end + b_end) * 0.5
		PinballFlipper.ContactZone.C:
			return (b_end + c_end) * 0.5
		PinballFlipper.ContactZone.D:
			return (c_end + 100.0) * 0.5
	return 50.0


func _refresh_guide_text() -> void:
	if not is_instance_valid(guide_label) or _test_parry_rules == null:
		return

	var zone_index := int(current_zone)
	var mode_name: String
	match current_mode:
		TestMode.BASELINE:
			mode_name = "기준값"
		TestMode.SPEED:
			mode_name = "속도 배율"
		TestMode.ANGLE:
			mode_name = "각도 보정"
	var side_name := "오른쪽" if target_right_flipper else "왼쪽"
	var condition_text: String
	match current_mode:
		TestMode.BASELINE:
			condition_text = "속도 1.00x / 각도 보정 Off"
		TestMode.SPEED:
			condition_text = "적용 속도 배율: %.2fx" % SPEED_MULTIPLIERS[zone_index]
		TestMode.ANGLE:
			condition_text = "적용 각도: %+.1f° × 좌우 부호" % ANGLE_CORRECTIONS[zone_index]
	var ball_speed := ball.linear_velocity.length() if is_instance_valid(ball) else 0.0
	guide_label.text = (
		"플리퍼 구역 충돌 테스트\n"
		+ "[0] 기준값  [1] 속도 배율  [2] 각도 보정\n"
		+ "[3] A  [4] B  [5] C  [6] D  [Tab] 좌우 전환\n"
		+ "[R] 현재 위치 재배치  [Space] 공 해제 + 플리퍼 작동\n\n"
		+ "현재: %s / %s 플리퍼 / %s 구역\n" % [
			mode_name,
			side_name,
			ZONE_NAMES[zone_index],
		]
		+ "%s\n공 속력: %.1f px/s" % [condition_text, ball_speed]
	)
