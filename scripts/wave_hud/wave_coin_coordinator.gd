class_name WaveCoinCoordinator
extends WaveRewardCoordinator


## 웨이브 씬에 코인 경제(기획서 3장)를 얹습니다.
##
## WaveRewardCoordinator를 상속만 하고 기존 로직은 건드리지 않습니다.
## 코인 노드는 유물 보상과 같은 이유로 씬 파일이 아니라 코드로 붙입니다.
##
## 구성 요소
##   CoinWallet                — 세션 지갑
##   CoinFieldController       — 웨이브마다 코인 12개 스폰, 획득 → 지갑 반영
##   WaveClearDelayController  — 3초 종료 유예와 추가 점수 → 코인 환산


const DEFAULT_COIN_LAYOUT := preload(
	"res://settings/coin/CoinSpawnLayout_Stage01.tres"
)


@export_category("Wave Coin")

@export var coin_layout: CoinSpawnLayout = DEFAULT_COIN_LAYOUT


var coin_wallet: CoinWallet
var coin_field: CoinFieldController
var clear_delay: WaveClearDelayController

var _coin_label: Label


func _ready() -> void:
	super()
	_build_coin_system()


func _build_coin_system() -> void:
	# 최신 wave.tscn은 에디터 배치가 보이는 CoinSystem을 직접 보유합니다.
	# 과거 파생 씬도 이를 상속하므로 두 번째 필드/지갑을 만들지 않고 재사용합니다.
	var authored_field := get_node_or_null(^"CoinSystem") as CoinFieldController
	var authored_session := get_node_or_null(
		^"CoinSystem/CoinSession"
	) as WaveCoinSession
	if authored_field != null and authored_session != null:
		coin_field = authored_field
		coin_wallet = authored_session.wallet
		clear_delay = authored_session.clear_delay
		_coin_label = authored_session.wallet_label
		_connect_coin_event_log()
		return

	coin_wallet = CoinWallet.new()
	coin_wallet.name = "CoinWallet"
	add_child(coin_wallet)

	coin_field = CoinFieldController.new()
	coin_field.name = "CoinFieldController"
	coin_field.layout = coin_layout
	add_child(coin_field)
	coin_field.bind_wallet(coin_wallet)

	clear_delay = WaveClearDelayController.new()
	clear_delay.name = "WaveClearDelayController"
	add_child(clear_delay)
	var bound := clear_delay.bind(wave_manager, coin_wallet, coin_field)
	assert(bound, "종료 유예 컨트롤러가 웨이브에 연결되지 못했습니다.")

	_build_coin_label()

	coin_wallet.wallet_changed.connect(_on_wallet_changed)
	_connect_coin_event_log()
	wave_manager.wave_entered.connect(_on_coin_wave_entered)
	wave_manager.wave_retried.connect(_on_coin_wave_retried)

	# 첫 웨이브는 부모 _ready()의 enter_wave()가 이미 지나갔으므로 직접 깝니다.
	if wave_manager.current_state != WaveManager.State.INACTIVE:
		coin_field.spawn_for_wave(wave_manager.current_wave_index)
	_refresh_coin_label()


func _connect_coin_event_log() -> void:
	if not coin_field.coin_pickup_collected.is_connected(_on_coin_collected):
		coin_field.coin_pickup_collected.connect(_on_coin_collected)
	if not clear_delay.wave_clear_delay_started.is_connected(_on_delay_started):
		clear_delay.wave_clear_delay_started.connect(_on_delay_started)
	if not clear_delay.wave_clear_delay_finished.is_connected(_on_delay_finished):
		clear_delay.wave_clear_delay_finished.connect(_on_delay_finished)


## 오래된 파생 웨이브에 정식 HUD가 없을 때만 쓰는 호환용 라벨입니다.
func _build_coin_label() -> void:
	var hud_root := get_node_or_null("HUD")
	if hud_root == null:
		push_warning("코인 라벨을 붙일 HUD 노드가 없습니다.")
		return
	_coin_label = Label.new()
	_coin_label.name = "CoinWalletLabel"
	_coin_label.position = Vector2(1604.0, 24.0)
	_coin_label.add_theme_font_size_override(&"font_size", 26)
	_coin_label.add_theme_color_override(
		&"font_color", Color(0.90, 0.72, 0.25)
	)
	_coin_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	_coin_label.add_theme_constant_override(&"outline_size", 6)
	hud_root.add_child(_coin_label)


func _refresh_coin_label() -> void:
	if _coin_label == null:
		return
	_coin_label.text = "× %d" % (
		coin_wallet.balance if coin_wallet != null else 0
	)


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	_refresh_coin_label()


func _on_coin_collected(
	_wave_id: int,
	_pickup_id: StringName,
	value: int,
	wallet_after: int
) -> void:
	_append_event("COIN +%d · 지갑 %d" % [value, wallet_after])


func _on_delay_started(
	_wave_id: int,
	_target_score: int,
	_score_at_start: int,
	delay_duration: float
) -> void:
	_append_event("CLEAR! 종료 유예 %.1f초 · 콤보를 마무리하세요" % delay_duration)


func _on_delay_finished(
	reason: StringName,
	clear_delay_score: int,
	clear_delay_coin: int,
	board_coin: int
) -> void:
	var reason_text := "시간 종료" \
		if reason == WaveClearDelayController.REASON_TIMEOUT else "공 낙하"
	_append_event(
		"유예 종료(%s) · 추가점수 %d → 코인 +%d · 보드 코인 %d"
		% [reason_text, clear_delay_score, clear_delay_coin, board_coin]
	)
	_refresh_coin_label()


func _on_coin_wave_entered(
	_stage_id: StringName,
	wave_index: int,
	_target_score: int
) -> void:
	if coin_field != null:
		coin_field.spawn_for_wave(wave_index)
	_refresh_coin_label()


func _on_coin_wave_retried() -> void:
	if coin_field != null:
		coin_field.spawn_for_wave(wave_manager.current_wave_index)
	_refresh_coin_label()
