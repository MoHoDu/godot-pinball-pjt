class_name BumperArtSpinAnimator
extends BumperArtAnimator
## 타격할 때마다 아트가 한 바퀴 도는 애니메이터입니다. `BumperArtAnimator` 를 확장합니다.
##
## 별빛 브로치에 쓴다. 눌림·프레임 교체·상태 표시는 부모가 그대로 처리하고
## 여기서는 `rotation` 만 더한다.
##
## 수리 부품 가이드 4-1 E: 기본 상태에는 "상시 회전이나 강한 점멸을 사용하지 않는다".
## 그래서 **타격 순간에만** 돌고 감속하며 멈춘다.
##
## 톱니바퀴(`BumperGearSpinAnimator`)와 회전 방식은 같지만 그쪽은 휠/허브 두 레이어를
## 나눠 감김 단계를 따라가므로 따로 둔다.


const SPIN_SNAP: float = 0.004


var _angle := 0.0
var _target := 0.0


func bind_to_bumper(bumper: Bumper) -> void:
	super.bind_to_bumper(bumper)
	if not is_instance_valid(bumper):
		return
	if not bumper.valid_hit_registered.is_connected(_on_hit_spin):
		bumper.valid_hit_registered.connect(_on_hit_spin)


func _on_hit_spin(
	_bumper_id: StringName,
	_ball: RigidBody2D,
	_contact_id: int,
	_base_score: int
) -> void:
	spin_once()


## 한 바퀴(규칙값)만큼 더 돌립니다. 연타하면 목표가 쌓여 계속 돈다.
func spin_once() -> void:
	var spin_rules := rules as BumperSpinAnimRules
	if spin_rules == null:
		return
	_target += spin_rules.spin_arc


func get_spin_angle() -> float:
	return _angle


func is_spinning() -> bool:
	return not is_equal_approx(_angle, _target)


func _process(delta: float) -> void:
	super._process(delta)

	var spin_rules := rules as BumperSpinAnimRules
	var sprite := get_target_sprite()
	if spin_rules == null or sprite == null:
		return
	if is_equal_approx(_angle, _target):
		return

	# 남은 각도에 비례한 속도. 처음엔 빠르고 끝에서 서서히 느려진다.
	var remaining := _target - _angle
	var speed := clampf(
		absf(remaining) * spin_rules.spin_decay,
		spin_rules.spin_min_speed,
		spin_rules.spin_max_speed
	)
	_angle += signf(remaining) * minf(speed * delta, absf(remaining))
	if absf(_target - _angle) < SPIN_SNAP:
		_angle = _target
	sprite.rotation = _angle
