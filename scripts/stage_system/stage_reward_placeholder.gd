@tool
class_name StageRewardPlaceholder
extends Control


## 실제 보상 시스템이 연결되기 전 사용하는 스테이지 전환 페이지입니다.


signal reward_completed


@export var title_label: Label
@export var description_label: Label
@export var next_button: Button


var _completed := false
var _completed_wave_index := 0
var _total_waves := 1
var _destination_text := "다음 웨이브"
var _coin_wallet: CoinWallet


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if next_button != null:
		next_button.pressed.connect(continue_stage)
		next_button.grab_focus()
	_refresh_text()


## 스테이지 공용 코인 지갑을 받아 보상 페이지에서도 누적 잔액을 보여 줍니다.
func bind_coin_wallet(wallet: CoinWallet) -> void:
	if _coin_wallet == wallet:
		_refresh_text()
		return
	if _coin_wallet != null \
			and _coin_wallet.wallet_changed.is_connected(_on_wallet_changed):
		_coin_wallet.wallet_changed.disconnect(_on_wallet_changed)
	_coin_wallet = wallet
	if _coin_wallet != null \
			and not _coin_wallet.wallet_changed.is_connected(_on_wallet_changed):
		_coin_wallet.wallet_changed.connect(_on_wallet_changed)
	_refresh_text()


## 스테이지 매니저가 현재 진행 정보를 주입합니다.
func configure_reward(
	completed_wave_index: int,
	total_waves: int,
	destination_text: String
) -> void:
	_completed_wave_index = maxi(completed_wave_index, 0)
	_total_waves = maxi(total_waves, 1)
	_destination_text = destination_text
	_refresh_text()


func continue_stage() -> bool:
	if _completed:
		return false
	_completed = true
	if next_button != null:
		next_button.disabled = true
	reward_completed.emit()
	return true


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	_refresh_text()


func _refresh_text() -> void:
	if title_label != null:
		title_label.text = "보상 페이지"
	if description_label != null:
		var coin_text := ""
		if _coin_wallet != null:
			coin_text = "\n보유 코인: %d" % _coin_wallet.balance
		description_label.text = (
			"웨이브 %d / %d 클리어\n"
			+ "보상 시스템 구현 후 이 페이지가 실제 보상 화면으로 교체됩니다."
			+ coin_text
		) % [_completed_wave_index + 1, _total_waves]
	if next_button != null:
		next_button.text = _destination_text


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if title_label == null:
		warnings.append("Title label is not assigned.")
	if description_label == null:
		warnings.append("Description label is not assigned.")
	if next_button == null:
		warnings.append("Next button is not assigned.")
	return warnings
