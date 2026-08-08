class_name WaveClearDelayController
extends Node


## 목표 스코어 달성 후 3초 종료 유예 규칙(기획서 3-2)을 기존 웨이브 흐름 위에 얹습니다.
##
## 기존 스크립트는 수정하지 않습니다. 세 가지 연결로 동작합니다.
##   1) ComboWaveController.target_score_reached — 점수가 목표를 넘는 순간 발화한다.
##      여기서 유예를 시작하고 달성 시점 점수를 스냅샷한다.
##   2) WaveManager.clear_choice_requested — 기존 "클리어/계속" 선택지.
##      v0.2에는 선택이 없으므로 즉시 choose_clear()로 자동 확정한다.
##      (시그널 발화 중 재진입을 피하려고 지연 호출한다)
##   3) 타이머 만료 시 공이 아직 보드에 있으면 강제 낙하시킨다.
##      WaveRewardCoordinator.force_wave_clear()가 이미 쓰는
##      wave_ball_flow.on_ball_drained() 경로를 그대로 재사용한다.
##
## "3초 경과 또는 현재 공 낙하 중 먼저 발생한 조건으로 종료"는
## 낙하 쪽이 기존 흐름(낙하 → 선택지 → 자동 확정)으로 자연히 성립하고,
## 타이머 쪽만 이 컨트롤러가 강제한다.


signal wave_clear_delay_started(
	wave_id: int,
	target_score: int,
	score_at_start: int,
	duration: float
)
signal wave_clear_delay_finished(
	reason: StringName,
	clear_delay_score: int,
	clear_delay_coin: int,
	board_coin: int
)


const REASON_TIMEOUT: StringName = &"timeout"
const REASON_BALL_DRAINED: StringName = &"ball_drained"


## 기획서 초기 권장값. 플레이테스트 후 조정 목록(11-4)에 있다.
@export_range(0.5, 10.0, 0.1) var duration := 3.0
@export_range(0.01, 1.0, 0.01) var score_ratio_per_coin := 0.05
@export_range(0, 20, 1) var clear_delay_coin_cap := 5


var _wave_manager: WaveManager
var _combo_wave: ComboWaveController
var _ball_flow: WaveBallFlowController
var _wallet: CoinWallet
var _coin_field: CoinFieldController
var _timer: Timer

var _delay_active := false
var _score_at_start := 0
var _finish_reason: StringName = REASON_BALL_DRAINED


var is_delay_active: bool:
	get:
		return _delay_active


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "ClearDelayTimer"
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func bind(
	wave_manager: WaveManager,
	wallet: CoinWallet,
	coin_field: CoinFieldController
) -> bool:
	if wave_manager == null or wave_manager.combo_wave == null \
			or wave_manager.ball_flow == null:
		return false
	if _wave_manager == wave_manager and _wallet == wallet \
			and _coin_field == coin_field:
		return true
	_wave_manager = wave_manager
	_combo_wave = wave_manager.combo_wave
	_ball_flow = wave_manager.ball_flow
	_wallet = wallet
	_coin_field = coin_field
	_wave_manager.set_target_completion_deferred(true)

	if not _combo_wave.target_score_reached.is_connected(_on_target_score_reached):
		_combo_wave.target_score_reached.connect(_on_target_score_reached)
	if not _wave_manager.clear_choice_requested.is_connected(_on_clear_choice_requested):
		_wave_manager.clear_choice_requested.connect(_on_clear_choice_requested)
	if not _wave_manager.wave_won.is_connected(_on_wave_won):
		_wave_manager.wave_won.connect(_on_wave_won)
	if not _wave_manager.wave_entered.is_connected(_on_wave_entered):
		_wave_manager.wave_entered.connect(_on_wave_entered)
	if not _wave_manager.wave_retried.is_connected(_on_wave_retried):
		_wave_manager.wave_retried.connect(_on_wave_retried)
	return true


## 유예 추가 점수 → 코인 환산식(기획서 3-3). 테스트에서 직접 검증합니다.
static func convert_delay_score(
	clear_delay_score: int,
	target_score: int,
	ratio := 0.05,
	cap := 5
) -> int:
	if clear_delay_score <= 0 or target_score <= 0 or ratio <= 0.0:
		return 0
	var unit := float(target_score) * ratio
	if unit <= 0.0:
		return 0
	return mini(int(floorf(float(clear_delay_score) / unit)), maxi(cap, 0))


func _on_target_score_reached(current_score: int, target_score: int) -> void:
	if _delay_active:
		return
	_delay_active = true
	_score_at_start = current_score
	_finish_reason = REASON_BALL_DRAINED
	_timer.start(duration)
	wave_clear_delay_started.emit(
		_wave_manager.current_wave_index,
		target_score,
		current_score,
		duration
	)


func _on_timer_timeout() -> void:
	if not _delay_active:
		return
	_finish_reason = REASON_TIMEOUT
	# 공이 보드에 있으면 강제 낙하로 유예를 끝냅니다.
	if _ball_flow.current_state == WaveBallFlowController.State.IN_PLAY \
			and is_instance_valid(_ball_flow.active_ball):
		_ball_flow.on_ball_drained(_ball_flow.active_ball)
		return
	# 공이 이미 없다면(선택 대기 등) 남은 선택지만 정리합니다.
	if _wave_manager.current_state == WaveManager.State.CLEAR_CHOICE:
		_wave_manager.choose_clear()


func _on_clear_choice_requested(
	_current_score: int,
	_target_score: int,
	_remaining_balls: int
) -> void:
	# v0.2에는 "남은 공으로 계속" 선택이 없습니다. 성공은 달성 순간 확정이므로
	# 선택지가 뜨는 즉시 클리어로 확정합니다. 시그널 체인 안이라 지연 호출합니다.
	call_deferred(&"_auto_confirm_clear")


func _auto_confirm_clear() -> void:
	if _wave_manager == null or not is_instance_valid(_wave_manager):
		return
	if _wave_manager.current_state == WaveManager.State.CLEAR_CHOICE:
		_wave_manager.choose_clear()


func _on_wave_won(current_score: int, target_score: int) -> void:
	_timer.stop()
	if not _delay_active:
		return
	_delay_active = false
	var clear_delay_score := maxi(current_score - _score_at_start, 0)
	var clear_delay_coin := convert_delay_score(
		clear_delay_score,
		target_score,
		score_ratio_per_coin,
		clear_delay_coin_cap
	)
	if _wallet != null and clear_delay_coin > 0:
		_wallet.add(clear_delay_coin)
	var board_coin := 0
	if _coin_field != null:
		board_coin = _coin_field.board_coin_this_wave
	wave_clear_delay_finished.emit(
		_finish_reason,
		clear_delay_score,
		clear_delay_coin,
		board_coin
	)


func _on_wave_entered(
	_stage_id: StringName,
	_wave_index: int,
	_target_score: int
) -> void:
	_reset_delay_state()


func _on_wave_retried() -> void:
	_reset_delay_state()


func _reset_delay_state() -> void:
	_timer.stop()
	_delay_active = false
	_score_at_start = 0
	_finish_reason = REASON_BALL_DRAINED
