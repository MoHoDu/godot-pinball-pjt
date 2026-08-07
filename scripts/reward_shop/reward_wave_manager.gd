class_name RewardWaveManager
extends WaveManager


## 보상 웨이브는 목표 점수에 닿자마자 공을 제거하지 않습니다.
## WaveClearDelayController가 3초 유예를 시작하고, 현재 공의 낙하 또는
## 타이머 만료 시 기존 clear-choice 경로로 승리를 확정합니다.
func _on_target_score_reached(_score: int, _target: int) -> void:
	pass


## 실패한 스테이지를 웨이브 1의 배치 단계로 되돌립니다.
## WaveManager 본체의 단계 계약을 수정하지 않고 보상 세션에서만 확장합니다.
func rollback_to_stage_entry() -> bool:
	if current_state != State.LOST or _stage_settings == null:
		return false
	_wave_index = 0
	_last_wave_was_won = false
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	if combo_system != null:
		combo_system.reset_wave()
	_set_stage_phase(StagePhase.REPAIR_PLACEMENT)
	return true
