@tool
class_name BallGazeVisual
extends Node2D
## 공의 시각 노드를 진행방향으로 향하게 합니다.
##
## 공은 RigidBody2D라 충돌 마찰로 자유롭게 회전합니다. 그대로 두면 시각 노드가
## 부모의 회전을 물려받아 아몬드형 코어가 아무 방향이나 향합니다.
## 이 스크립트는 **자기 자신의 global_rotation만** 매 물리 프레임 덮어써서
## 코어가 항상 진행방향을 보게 만듭니다.
##
## 물리 바디의 rotation·position·velocity는 절대 건드리지 않습니다.
## FlipperParryFeedback과 같은 "연출은 물리와 분리한다" 패턴을 따릅니다.


const DEFAULT_GAZE_RULES: BallGazeRules = preload(
	"res://settings/balls/BallGazeRules.tres"
)

## 지수 감쇠 가중치가 1을 넘지 않도록 막는 안전값입니다.
const MAX_INTERPOLATION_WEIGHT: float = 1.0


var _gaze_rules: BallGazeRules = DEFAULT_GAZE_RULES
var _target_angle: float = 0.0
var _has_locked_on: bool = false


## 시선 반응 규칙입니다. 씬에 내장하거나 .tres 프리셋으로 교체할 수 있습니다.
@export var gaze_rules: BallGazeRules:
	get:
		return _gaze_rules
	set(value):
		_gaze_rules = value if value != null else DEFAULT_GAZE_RULES
		update_configuration_warnings()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 부모 바디가 이미 회전해 있어도 시작 시선은 월드 기준 0으로 맞춥니다.
	global_rotation = _target_angle


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var body := get_parent() as RigidBody2D
	if body == null:
		return

	var velocity := body.linear_velocity
	var is_moving := velocity.length() >= _gaze_rules.gaze_speed_threshold

	if is_moving:
		_target_angle = velocity.angle()

		if not _has_locked_on:
			_has_locked_on = true

			if _gaze_rules.instant_on_spawn:
				# 발사 순간은 보간 없이 즉시 정렬합니다.
				global_rotation = _target_angle
				return

	if not _has_locked_on:
		# 아직 한 번도 움직인 적이 없으면 부모 회전만 상쇄하고 대기합니다.
		global_rotation = _target_angle
		return

	global_rotation = lerp_angle(
		global_rotation,
		_target_angle,
		_interpolation_weight(delta)
	)


## 프레임레이트와 무관한 지수 감쇠 가중치입니다.
## delta가 커져도 목표를 지나치지 않도록 1로 잘라냅니다.
func _interpolation_weight(delta: float) -> float:
	return minf(
		1.0 - exp(-_gaze_rules.gaze_sharpness * delta),
		MAX_INTERPOLATION_WEIGHT
	)


## 현재 바라보고 있는 목표 각도입니다. 테스트와 디버그용입니다.
func get_target_angle() -> float:
	return _target_angle


## 한 번이라도 임계 속력을 넘어 시선이 고정된 적이 있는지 여부입니다.
func has_locked_on() -> bool:
	return _has_locked_on


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is RigidBody2D):
		warnings.append("BallGazeVisual의 부모는 RigidBody2D여야 합니다.")

	if _gaze_rules == null:
		warnings.append("Gaze Rules 리소스를 지정해야 합니다.")

	return warnings
