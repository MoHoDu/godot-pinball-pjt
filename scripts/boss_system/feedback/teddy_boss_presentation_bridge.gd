class_name TeddyBossPresentationBridge
extends Node
## 최신 보스 전투 피드백을 연출 브랜치의 아트 리그와 VFX에 연결합니다.
##
## 전투 판정과 상태 전이는 `Stage1TeddyBossRuntime`에 그대로 남겨 두고,
## 이 노드는 `TeddyBossFeedbackController`가 발행한 읽기 전용 피드백만 소비합니다.


@export var feedback: TeddyBossFeedbackController = null
@export var rig: BossArtRig = null
@export var vfx: BossVfxLayer = null


var _is_setup: bool = false
var _hit_direction: float = 1.0


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	teardown()


func setup() -> bool:
	if _is_setup:
		return _references_are_valid()
	if not _references_are_valid():
		return false
	_connect_signals()
	rig.play_idle(true)
	_is_setup = true
	return true


func teardown() -> void:
	if not _is_setup:
		return
	_disconnect_signals()
	_is_setup = false


func is_ready() -> bool:
	return _is_setup and _references_are_valid()


func _references_are_valid() -> bool:
	return feedback != null and is_instance_valid(feedback) \
		and rig != null and is_instance_valid(rig) \
		and vfx != null and is_instance_valid(vfx)


func _connect_signals() -> void:
	_connect_once(feedback.boss_battle_started, _on_boss_battle_started)
	_connect_once(feedback.attack_telegraph_started, _on_attack_telegraph_started)
	_connect_once(feedback.attack_active_started, _on_attack_active_started)
	_connect_once(feedback.attack_recovery_started, _on_attack_recovery_started)
	_connect_once(feedback.arm_ball_reflected, _on_arm_ball_reflected)
	_connect_once(feedback.boss_hit_feedback, _on_boss_hit_feedback)
	_connect_once(feedback.phase_2_feedback, _on_phase_2_feedback)
	_connect_once(feedback.boss_defeated_feedback, _on_boss_defeated_feedback)


func _disconnect_signals() -> void:
	if not is_instance_valid(feedback):
		return
	_disconnect_once(feedback.boss_battle_started, _on_boss_battle_started)
	_disconnect_once(feedback.attack_telegraph_started, _on_attack_telegraph_started)
	_disconnect_once(feedback.attack_active_started, _on_attack_active_started)
	_disconnect_once(feedback.attack_recovery_started, _on_attack_recovery_started)
	_disconnect_once(feedback.arm_ball_reflected, _on_arm_ball_reflected)
	_disconnect_once(feedback.boss_hit_feedback, _on_boss_hit_feedback)
	_disconnect_once(feedback.phase_2_feedback, _on_phase_2_feedback)
	_disconnect_once(feedback.boss_defeated_feedback, _on_boss_defeated_feedback)


func _connect_once(source: Signal, target: Callable) -> void:
	if not source.is_connected(target):
		source.connect(target)


func _disconnect_once(source: Signal, target: Callable) -> void:
	if source.is_connected(target):
		source.disconnect(target)


func _on_boss_battle_started() -> void:
	rig.play_idle(true)


func _on_attack_telegraph_started(_pattern_id: int) -> void:
	rig.play_telegraph()


func _on_attack_active_started(_pattern_id: int) -> void:
	rig.play_attack()


func _on_attack_recovery_started(_pattern_id: int) -> void:
	rig.play_recovery()


func _on_arm_ball_reflected(ball: Pinball) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var direction := ball.linear_velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	vfx.spawn_ball_impact(vfx.to_local(ball.global_position), direction)


func _on_boss_hit_feedback(_damage: int, was_counter: bool) -> void:
	_hit_direction *= -1.0
	if was_counter:
		rig.play_hit_strong(_hit_direction)
	else:
		rig.play_hit(_hit_direction)
	var direction := Vector2(_hit_direction, -0.25).normalized()
	vfx.spawn_hit(Vector2.ZERO, direction, was_counter)


func _on_phase_2_feedback() -> void:
	rig.play_roar()
	vfx.spawn_roar()


func _on_boss_defeated_feedback() -> void:
	rig.play_hit_strong(_hit_direction)
	vfx.spawn_hit(Vector2.ZERO, Vector2.UP, true)
