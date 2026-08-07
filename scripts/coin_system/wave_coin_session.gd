class_name WaveCoinSession
extends Node


## 최신 wave 씬에 코인 지갑·필드·종료 유예를 조립하는 세션 수명주기입니다.
## 코인은 일반 웨이브 사이에서 유지되고 게임 오버와 보스 클리어에서 초기화됩니다.


signal wave_coin_settled(
	wave_id: int,
	board_coin: int,
	clear_delay_coin: int,
	wave_coin_earned: int,
	wallet_after: int
)


@export_category("Runtime Dependencies")
@export var wave_manager: WaveManager
@export var wallet: CoinWallet
@export var field: CoinFieldController
@export var clear_delay: WaveClearDelayController
@export var wallet_label: Label

## 단독 웨이브 씬에서는 이 세션이 스테이지 시작·완료 시 지갑을 초기화합니다.
## 외부 StageFlowManager가 지갑을 소유할 때는 false로 주입되어 웨이브 씬 교체
## 사이에도 같은 잔액을 유지합니다. 게임 오버 초기화는 이 값과 무관하게 적용됩니다.
@export var manages_stage_wallet_lifecycle := true


var last_board_coin := 0
var last_clear_delay_coin := 0
var last_wave_coin_earned := 0
var _respawn_after_game_over := false


## 외부 스테이지 흐름이 소유한 지갑과 현재 웨이브 런타임을 트리 진입 전에 주입합니다.
func bind_stage_runtime(
	stage_wallet: CoinWallet,
	stage_wave_manager: WaveManager
) -> bool:
	if stage_wallet == null or stage_wave_manager == null or is_inside_tree():
		return false
	wallet = stage_wallet
	wave_manager = stage_wave_manager
	manages_stage_wallet_lifecycle = false
	return true


func _ready() -> void:
	assert(wave_manager != null, "CoinSession requires WaveManager.")
	assert(wallet != null, "CoinSession requires CoinWallet.")
	assert(field != null, "CoinSession requires CoinFieldController.")
	assert(clear_delay != null, "CoinSession requires WaveClearDelayController.")
	if wallet_label == null:
		wallet_label = get_node_or_null(
			^"../../HUD/WaveHud/DesignSpace/CoinWalletHud/Margin/Row/BalanceLabel"
		) as Label
	assert(field.bind_wallet(wallet), "Coin field could not bind its wallet.")
	assert(
		clear_delay.bind(wave_manager, wallet, field),
		"Clear-delay coin controller could not bind the wave runtime."
	)

	wallet.wallet_changed.connect(_on_wallet_changed)
	field.board_coin_changed.connect(_on_board_coin_changed)
	clear_delay.wave_clear_delay_finished.connect(_on_clear_delay_finished)
	wave_manager.stage_entered.connect(_on_stage_entered)
	wave_manager.wave_entered.connect(_on_wave_entered)
	wave_manager.wave_retried.connect(_on_wave_retried)
	wave_manager.wave_lost.connect(_on_game_over)
	wave_manager.stage_phase_changed.connect(_on_stage_phase_changed)
	wave_manager.stage_completed.connect(_on_stage_completed)
	_refresh_wallet_label()


func _on_stage_entered(_stage_id: StringName, _wave_index: int) -> void:
	if manages_stage_wallet_lifecycle:
		wallet.reset(0)
	field.reset_wave()
	_respawn_after_game_over = false
	_reset_last_settlement()


func _on_wave_entered(
	_stage_id: StringName,
	wave_index: int,
	_target_score: int
) -> void:
	if wave_index >= WaveManager.NORMAL_WAVE_COUNT:
		field.reset_wave()
		return
	field.spawn_for_wave(wave_index)
	_respawn_after_game_over = false
	_reset_last_settlement()


func _on_wave_retried() -> void:
	if _respawn_after_game_over:
		# 패배는 지갑까지 초기화된 새 시도이므로 보드 코인을 다시 공급합니다.
		field.spawn_for_wave(wave_manager.current_wave_index)
	else:
		# 승리 결과에서 같은 웨이브를 재시도해도 이미 정산된 코인은 되살리지 않습니다.
		field.reset_wave()
	_respawn_after_game_over = false
	_reset_last_settlement()


func _on_game_over(_current_score: int, _target_score: int) -> void:
	wallet.reset(0)
	field.reset_wave()
	_respawn_after_game_over = true
	_reset_last_settlement()


func _on_stage_phase_changed(
	_previous_phase: WaveManager.StagePhase,
	current_phase: WaveManager.StagePhase
) -> void:
	if current_phase in [
		WaveManager.StagePhase.BOSS,
		WaveManager.StagePhase.STAGE_COMPLETE,
	]:
		# 보스에는 코인을 공급하지 않지만 지갑은 보스 클리어까지 유지합니다.
		field.reset_wave()


func _on_stage_completed(_stage_id: StringName) -> void:
	if manages_stage_wallet_lifecycle:
		wallet.reset(0)
	field.reset_wave()
	_respawn_after_game_over = false
	_reset_last_settlement()


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	_refresh_wallet_label()


func _on_board_coin_changed(_board_coin: int) -> void:
	_refresh_wallet_label()


func _on_clear_delay_finished(
	_reason: StringName,
	_clear_delay_score: int,
	clear_delay_coin: int,
	board_coin: int
) -> void:
	last_board_coin = board_coin
	last_clear_delay_coin = clear_delay_coin
	last_wave_coin_earned = board_coin + clear_delay_coin
	wave_coin_settled.emit(
		wave_manager.current_wave_index,
		last_board_coin,
		last_clear_delay_coin,
		last_wave_coin_earned,
		wallet.balance
	)
	_refresh_wallet_label()


func _reset_last_settlement() -> void:
	last_board_coin = 0
	last_clear_delay_coin = 0
	last_wave_coin_earned = 0
	_refresh_wallet_label()


func _refresh_wallet_label() -> void:
	if wallet_label == null:
		return
	wallet_label.text = "× %d" % (wallet.balance if wallet != null else 0)
