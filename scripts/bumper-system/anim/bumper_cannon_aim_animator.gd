class_name BumperCannonAimAnimator
extends BumperArtAnimator
## 태엽 대포의 조준 회전입니다. `BumperArtAnimator` 를 확장합니다.
##
## 기획서 38쪽: **포신이 받침대 중심축을 기준으로 회전하고, 포신의 회전만으로도
## 현재 방향을 확인할 수 있어야 한다.**
##
## 아트가 포신 +X 기준으로 뽑혀 있어 회전각이 곧 발사 방향이다.
## 받침대 동심원이 중심에 맞춰져 있어 스프라이트를 통째로 돌려도 회전축이 어긋나지 않는다.
## (37쪽: 받침대의 동심원과 방향축은 실제 회전 중심과 일치해야 한다)
##
## 눌림·프레임 교체는 부모가 그대로 처리하고 여기서는 `rotation` 만 더한다.


var _shot: ShotBumper = null
var _aim_angle := 0.0
var _aim_initialised := false
var _settle := 0.0


func bind_to_bumper(bumper: Bumper) -> void:
	super.bind_to_bumper(bumper)
	_shot = bumper as ShotBumper
	if is_instance_valid(_shot) and not _shot.selection_changed.is_connected(
		_on_selection_changed
	):
		_shot.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(_source: ShotBumper, _anchor: ShotLaunchAnchor) -> void:
	# 방향이 바뀔 때마다 살짝 흔들리게 해 손으로 돌린 장난감처럼 보이게 한다.
	var cannon_rules := rules as BumperCannonAnimRules
	if cannon_rules != null:
		_settle = cannon_rules.aim_settle_swing


func _process(delta: float) -> void:
	super._process(delta)

	var cannon_rules := rules as BumperCannonAnimRules
	var sprite := get_target_sprite()
	if cannon_rules == null or sprite == null or not is_instance_valid(_shot):
		return

	# 기본 상태는 "조용한 상태" 라 포획 중에만 따라 도는 것이 기본값이다 (3-2).
	if not cannon_rules.aim_while_idle and not is_holding() and _aim_initialised:
		_decay_settle(delta)
		sprite.rotation = _aim_angle + _settle
		return

	var direction := _shot.get_selected_launch_direction()
	if direction.length_squared() <= 0.0:
		return
	var target := direction.angle()

	if not _aim_initialised:
		_aim_angle = target
		_aim_initialised = true
	else:
		var step := cannon_rules.aim_turn_speed * delta
		_aim_angle = _rotate_toward(_aim_angle, target, step)

	_decay_settle(delta)
	sprite.rotation = _aim_angle + _settle


func _decay_settle(delta: float) -> void:
	if is_zero_approx(_settle):
		return
	# 지나친 만큼을 빠르게 되돌린다.
	_settle = move_toward(_settle, 0.0, delta * 1.6)


## 최단 방향으로 회전합니다. -PI/PI 경계에서 한 바퀴 도는 것을 막습니다.
func _rotate_toward(current: float, target: float, step: float) -> float:
	var difference := wrapf(target - current, -PI, PI)
	if absf(difference) <= step:
		return target
	return current + signf(difference) * step


func get_aim_angle() -> float:
	return _aim_angle


func is_aim_initialised() -> bool:
	return _aim_initialised
