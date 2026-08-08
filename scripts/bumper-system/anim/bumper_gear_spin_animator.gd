class_name BumperGearSpinAnimator
extends BumperArtAnimator
## 황금 톱니바퀴의 회전입니다. `BumperArtAnimator` 를 확장합니다.
##
## 기획서 11쪽 (수리 부품 가이드 4-2 E):
## - 1단계: 접촉 방향으로 기어가 짧게 회전한다
## - 2단계: 회전 속도가 1단계보다 약간 빨라진다
## - 3단계 과회전: 기어가 빠르게 한 바퀴 회전한다
##
## 단 2026-08-06 형락님 지시로 **단계를 나누지 않고 매번 같게** 돈다.
## 어떻게 맞아도 빠르게 한 바퀴 돌다가 감속하며 멈춘다.
##
## **돌리는 것은 바깥 이빨 링뿐이다.** 이빨은 동심이라 반지름으로 깨끗이 갈린다
## (0.88 부터 이빨 사이 틈이 생기는 것을 실측했다).
##
## 안쪽 금색 링은 **반대 방향**으로 돈다. 동심이라 반지름으로 갈렸고, 아이보리
## 기어에 가려 안 그려진 각도는 상하 대칭 복사로 메웠다.
##
## 나머지 얼굴 레이어에는 작은 기어 두 개·허브·리벳·홈이 들어가고 돌지 않는다.
## 허브는 수축·팽창, 리벳은 점등이라 회전에서 빼야 하고(11쪽), 작은 기어는
## 한 장에 붙어 있어 같이 돌리면 **공전해 버린다**(2026-08-07 지적).
##
## 이빨 레이어는 0.80 부터 잘라 얼굴 밑으로 넉넉히 밀어 넣는다. 얼굴이 눌려
## 작아져도 그 밑에서 이빨이 이어져 틈이 안 생긴다.
##
## 남은 한계: 작은 기어가 맞물려 제자리에서 도는 것까지는 못 한다. 뒤의 큰 기어가
## 가려져 안 그려져 있어 오려내면 구멍이 난다. 레이어를 따로 그려야 해결된다.


const WHEEL_SPRITE := ^"_ArtSpriteWheel"
## 안쪽 금색 링. 이빨 링과 **반대 방향**으로 돈다.
## 맞물린 기어처럼 보이게 하는 장치다 (2026-08-07 지시).
const RING_SPRITE := ^"_ArtSpriteRing"
## 안쪽 링은 지름이 작아 같은 각속도면 더 빨라 보인다. 조금 덜 돌린다.
const RING_RATIO: float = -0.75

## 한 번 감길 때 도는 각도. **단계와 무관하게 항상 같다.**
## 기획서 11쪽은 1·2단계를 짧게, 3단계만 한 바퀴로 나눴지만
## 2026-08-06 형락님 지시로 "어떻게 맞아도 빠르게 돌다가 감속하며 멈춘다" 로 통일했다.
const SPIN_ARC: float = TAU

## 단계 수. wind_stack 상한과 맞춘다.
const MAX_STAGE: int = 3

## 감속 계수(1/초). **남은 각도에 비례해 속도를 준다.**
## 그래서 감긴 직후에는 휙 돌고 목표에 가까워질수록 서서히 느려진다.
## 등속으로 돌리면 딱 멈춰서 기계처럼 보인다.
const SPIN_DECAY: float = 7.0
## 감속만 쓰면 목표에 무한히 가까워지기만 하므로 바닥 속도를 둔다.
const SPIN_MIN_SPEED: float = 1.2
## 과회전(한 바퀴)에서 시작 속도가 지나치게 튀는 것을 막는다.
const SPIN_MAX_SPEED: float = 26.0
## 이보다 가까우면 붙여서 끝낸다.
const SPIN_SNAP: float = 0.004


var _wheel: Sprite2D = null
var _ring: Sprite2D = null
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
	_ring = bumper.get_node_or_null(RING_SPRITE) as Sprite2D

	# 수리 부품 런타임이 붙어 있으면 단계를 그쪽에서 읽는다.
	var runtime := bumper.get_node_or_null(^"RepairPartRuntime")
	if runtime != null and runtime.has_signal(&"part_state_changed"):
		_runtime = runtime
		if not runtime.is_connected(&"part_state_changed", _on_part_state_changed):
			runtime.connect(&"part_state_changed", _on_part_state_changed)
		return

	# 런타임이 없으면(검수 씬 등) 타격만으로 단계를 올린다.
	# 실제 게임에서는 RepairEffectRouter 가 단계를 주도하므로 이 경로를 타지 않는다.
	if not bumper.valid_hit_registered.is_connected(_on_hit_advance_stage):
		bumper.valid_hit_registered.connect(_on_hit_advance_stage)


func _on_part_state_changed(_source: Node, state: Dictionary) -> void:
	set_stage(int(state.get(&"wind_stack", 0)))


func _on_hit_advance_stage(
	_bumper_id: StringName,
	_ball: RigidBody2D,
	_contact_id: int,
	_base_score: int
) -> void:
	advance_stage()


## 다음 감김 단계로 올립니다. 3단계(과회전) 다음은 기본 상태로 되돌아갑니다.
## 11쪽: 과회전 직후 모든 단계 표시가 꺼지고 기본 상태로 복귀한다.
func advance_stage() -> void:
	if _stage >= MAX_STAGE:
		set_stage(0)
		set_stage(1)
		return
	set_stage(_stage + 1)


## 감김 단계를 반영해 그만큼 더 돌립니다.
func set_stage(stage: int) -> void:
	var clamped := clampi(stage, 0, MAX_STAGE)
	if clamped == _stage:
		return
	# 0 으로 되돌아가는 것은 과회전 직후의 초기화라 추가 회전을 넣지 않는다.
	if clamped > _stage:
		_target_angle += SPIN_ARC
	_stage = clamped


func get_stage() -> int:
	return _stage


func get_ring_angle() -> float:
	return _angle * RING_RATIO


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

	# 남은 각도에 비례한 속도. 처음엔 빠르고 끝에서 서서히 느려진다.
	var remaining := _target_angle - _angle
	_speed = clampf(absf(remaining) * SPIN_DECAY, SPIN_MIN_SPEED, SPIN_MAX_SPEED)
	var step: float = minf(_speed * delta, absf(remaining))
	_angle += signf(remaining) * step
	if absf(_target_angle - _angle) < SPIN_SNAP:
		_angle = _target_angle
	_wheel.rotation = _angle
	if _ring != null:
		_ring.rotation = _angle * RING_RATIO
