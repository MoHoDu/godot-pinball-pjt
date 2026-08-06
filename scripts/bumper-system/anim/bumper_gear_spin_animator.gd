class_name BumperGearSpinAnimator
extends BumperArtAnimator
## 황금 톱니바퀴의 회전입니다. `BumperArtAnimator` 를 확장합니다.
##
## 기획서 11쪽 (수리 부품 가이드 4-2 E):
## - 1단계: 접촉 방향으로 기어가 짧게 회전한다
## - 2단계: 회전 속도가 1단계보다 약간 빨라진다
## - 3단계 과회전: 기어가 빠르게 한 바퀴 회전한다
##
## **허브와 리벳은 돌지 않는다.** 허브는 짧게 수축·팽창하고 리벳은 순서대로
## 점등되므로 회전에서 빼야 한다. 아트를 휠/허브 두 레이어로 갈라 휠만 돌린다.
## 허브는 동심이라 반지름으로 깔끔히 갈렸다.
##
## 알려진 근사: 작은 기어 두 개가 큰 기어와 한 장에 붙어 있어 휠이 돌면 같이
## 공전한다. 맞물려 제자리에서 도는 것이 정확하지만, 세 기어가 팔레트를 공유하고
## 겹쳐 있어 프로그램으로는 못 가른다. 레이어를 따로 그려야 해결된다.


const WHEEL_SPRITE := ^"_ArtSpriteWheel"

## 단계별 회전량(라디안). 3단계는 한 바퀴다.
const STEP_ARCS: Array[float] = [0.0, 0.55, 0.85, TAU]
## 단계별 회전 속도(라디안/초).
const STEP_SPEEDS: Array[float] = [0.0, 3.2, 5.0, 14.0]


var _wheel: Sprite2D = null
var _runtime: Node = null
var _stage := 0
var _target_angle := 0.0
var _angle := 0.0
var _speed := 0.0


func bind_to_bumper(bumper: Bumper) -> void:
	super.bind_to_bumper(bumper)
	if not is_instance_valid(bumper):
		return

	_wheel = bumper.get_node_or_null(WHEEL_SPRITE) as Sprite2D

	# 수리 부품 런타임이 붙어 있으면 단계를 그쪽에서 읽는다.
	var runtime := bumper.get_node_or_null(^"RepairPartRuntime")
	if runtime != null and runtime.has_signal(&"part_state_changed"):
		_runtime = runtime
		if not runtime.is_connected(&"part_state_changed", _on_part_state_changed):
			runtime.connect(&"part_state_changed", _on_part_state_changed)


func _on_part_state_changed(_source: Node, state: Dictionary) -> void:
	set_stage(int(state.get(&"wind_stack", 0)))


## 감김 단계를 반영해 그만큼 더 돌립니다.
func set_stage(stage: int) -> void:
	var clamped := clampi(stage, 0, STEP_ARCS.size() - 1)
	if clamped == _stage:
		return
	# 0 으로 되돌아가는 것은 과회전 직후의 초기화라 추가 회전을 넣지 않는다.
	if clamped > _stage:
		_target_angle += STEP_ARCS[clamped]
		_speed = STEP_SPEEDS[clamped]
	_stage = clamped


func get_stage() -> int:
	return _stage


func get_wheel_angle() -> float:
	return _angle


func is_spinning() -> bool:
	return not is_equal_approx(_angle, _target_angle)


func _process(delta: float) -> void:
	super._process(delta)

	if _wheel == null:
		if not is_instance_valid(_bumper):
			return
		_wheel = _bumper.get_node_or_null(WHEEL_SPRITE) as Sprite2D
		if _wheel == null:
			return

	if is_equal_approx(_angle, _target_angle):
		return

	# 목표까지 감속하며 붙는다. 등속으로 딱 멈추면 기계처럼 보인다.
	var remaining := _target_angle - _angle
	var step: float = maxf(_speed, 1.0) * delta
	step = minf(step, absf(remaining))
	_angle += signf(remaining) * step
	if absf(_target_angle - _angle) < 0.001:
		_angle = _target_angle
	_wheel.rotation = _angle
