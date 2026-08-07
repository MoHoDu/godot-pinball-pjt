class_name WaveRewardShopBridge
extends Node


signal stage_state_rolled_back(
	stage_id: StringName,
	failure_wave: int
)


const DEFAULT_CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)
const DEFAULT_BALL_SCENE_MAP := preload(
	"res://settings/reward_shop/RewardBallSceneMap_Stage01.tres"
)
const MAIN_COORDINATOR_SCRIPT_PATH := \
	"res://scripts/wave_hud/wave_runtime_coordinator.gd"


@export_category("Stage Reward")
@export var stage_id: StringName = &"stage_01"
@export var shop_catalog: RewardShopCatalog = DEFAULT_CATALOG
@export var ball_scene_map: RewardBallSceneMap = DEFAULT_BALL_SCENE_MAP
@export var random_seed := 0

@export_category("Runtime Dependencies")
@export var wave_manager: RewardWaveManager
@export var combo_system: ComboSystem
@export var ball_inventory: SelectBallInventory
@export var part_inventory: RepairPartInventory
@export var placement_session: BoardPlacementSession
@export var wave_hud: CanvasItem
@export var ball_selection_hud: CanvasItem
@export var wallet: CoinWallet
@export var clear_delay: WaveClearDelayController

## 외부 StageFlowManager가 보상 씬을 교체하는 경우 중복 보상 화면을 만들지 않습니다.
@export var embedded_reward_enabled := true

@export_category("Score Coin")
@export_range(0.5, 10.0, 0.1) var clear_delay_seconds := 3.0
@export_range(0.01, 1.0, 0.01) var score_ratio_per_coin := 0.05
@export_range(0, 20, 1) var score_coin_cap := 5

@export_group("Debug")
@export var debug_fill_coin_key: Key = KEY_C
@export var debug_fill_coin_amount := 999


var shop_controller: RewardShopController
var shop_hud: RewardShopHud

var _shop_layer: CanvasLayer
var _last_delay_coin := 0
var _rollback_queued := false
var _entry_coin_balance := 0
var _entry_owned_definitions: Array[BallDefinition] = []
var _entry_unlocked_reward_ids: Array[StringName] = []
var _entry_part_counts: Dictionary = {}


func _ready() -> void:
	call_deferred(&"_initialize")


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or debug_fill_coin_key == KEY_NONE or wallet == null:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != debug_fill_coin_key:
		return
	wallet.reset(debug_fill_coin_amount)
	get_viewport().set_input_as_handled()


func _initialize() -> void:
	if not embedded_reward_enabled:
		set_process_unhandled_input(false)
		return
	# wave.tscn을 상속하는 기존 데모들은 각자 코인·상점 조립자를 갖습니다.
	# 메인 WaveRuntimeCoordinator 씬에서만 새 통합 브리지를 활성화합니다.
	var parent_script := get_parent().get_script() as Script
	if parent_script == null \
			or parent_script.resource_path != MAIN_COORDINATOR_SCRIPT_PATH \
			or not ball_inventory is SelectBallInventory:
		set_process_unhandled_input(false)
		return
	_assert_dependencies()
	if wave_manager == null or combo_system == null \
			or ball_inventory == null or part_inventory == null:
		return

	if wallet == null:
		wallet = CoinWallet.new()
		wallet.name = "RewardCoinWallet"
		add_child(wallet)
	if clear_delay == null:
		clear_delay = WaveClearDelayController.new()
		clear_delay.name = "RewardClearDelay"
		clear_delay.duration = clear_delay_seconds
		clear_delay.score_ratio_per_coin = score_ratio_per_coin
		clear_delay.clear_delay_coin_cap = score_coin_cap
		add_child(clear_delay)
		assert(
			clear_delay.bind(wave_manager, wallet, null),
			"Reward bridge could not bind score coin settlement."
		)

	shop_controller = RewardShopController.new()
	shop_controller.name = "RewardShopController"
	shop_controller.catalog = shop_catalog.duplicate(true) as RewardShopCatalog
	shop_controller.stage_id = stage_id
	shop_controller.random_seed = random_seed
	add_child(shop_controller)
	assert(
		shop_controller.bind(wallet, part_inventory),
		"Reward bridge could not bind the wallet and repair inventory."
	)

	_shop_layer = CanvasLayer.new()
	_shop_layer.name = "RewardShopLayer"
	_shop_layer.layer = 25
	add_child(_shop_layer)
	shop_hud = RewardShopHud.new()
	shop_hud.name = "RewardShopHud"
	_shop_layer.add_child(shop_hud)
	assert(
		shop_hud.bind(shop_controller, wallet, part_inventory),
		"Reward bridge could not bind the reward HUD."
	)

	shop_hud.proceed_requested.connect(_on_shop_proceed)
	shop_controller.ball_unlocked.connect(_on_ball_unlocked)
	clear_delay.wave_clear_delay_finished.connect(_on_clear_delay_finished)
	wave_manager.stage_phase_changed.connect(_on_stage_phase_changed)
	wave_manager.stage_entered.connect(_on_stage_entered)
	wave_manager.wave_lost.connect(_on_wave_lost)
	wave_manager.stage_completed.connect(_on_stage_completed)

	_capture_stage_entry()
	_sync_current_phase()


func use_external_stage_rewards() -> void:
	embedded_reward_enabled = false
	set_process_unhandled_input(false)


func _on_clear_delay_finished(
	_reason: StringName,
	_clear_delay_score: int,
	clear_delay_coin: int,
	_board_coin: int
) -> void:
	_last_delay_coin = clear_delay_coin


func _on_stage_phase_changed(
	_previous_phase: WaveManager.StagePhase,
	current_phase: WaveManager.StagePhase
) -> void:
	if current_phase == WaveManager.StagePhase.WAVE_RESULT \
			and wave_manager.current_state == WaveManager.State.WON:
		# _finish_won()의 같은 시그널 체인에서 wave_won 코인 정산이 끝난 뒤
		# 보상 화면을 열어야 하므로 다음 프레임으로 넘깁니다.
		call_deferred(&"_advance_won_result_to_reward")
	elif current_phase == WaveManager.StagePhase.REWARD:
		_open_reward_shop()
	elif shop_controller != null and shop_controller.is_open:
		shop_controller.close_shop()


func _advance_won_result_to_reward() -> void:
	if wave_manager.current_state != WaveManager.State.WON \
			or wave_manager.current_stage_phase \
			!= WaveManager.StagePhase.WAVE_RESULT:
		return
	if not wave_manager.advance_stage_phase():
		push_error("Reward bridge could not advance a won result to rewards.")


func _sync_current_phase() -> void:
	if wave_manager.current_stage_phase == WaveManager.StagePhase.REWARD:
		_open_reward_shop()


func _open_reward_shop() -> void:
	if shop_controller == null or shop_controller.is_open:
		return
	if wave_hud != null:
		wave_hud.visible = false
	if ball_selection_hud != null:
		ball_selection_hud.visible = false
	shop_hud.set_wave_summary(
		wave_manager.current_wave_index, 0, _last_delay_coin
	)
	if not shop_controller.open_shop(
		wave_manager.current_wave_index, wave_manager.current_wave_index
	):
		push_error("Reward bridge could not open the stage reward shop.")


func _on_shop_proceed() -> void:
	if shop_controller == null or not shop_controller.is_open:
		return
	shop_controller.close_shop()
	_last_delay_coin = 0
	if not wave_manager.advance_stage_phase():
		push_error("Reward bridge could not advance from the reward phase.")


func _on_ball_unlocked(ball_id: StringName) -> void:
	var definition := ball_scene_map.make_definition(ball_id) \
		if ball_scene_map != null else null
	if definition != null:
		var select_definition := definition as SelectBallDefinition
		if select_definition == null:
			select_definition = SelectBallDefinition.new()
			select_definition.ball_id = definition.ball_id
			select_definition.display_name = definition.display_name
			select_definition.ball_scene = definition.ball_scene
		var offer := _find_ball_offer(ball_id)
		if offer != null:
			select_definition.feature_summary = offer.merit_text
		if ball_inventory.add_owned_definition(select_definition):
			return
	_rollback_ball_purchase(ball_id)


func _rollback_ball_purchase(ball_id: StringName) -> void:
	var refund := 0
	var offer := _find_ball_offer(ball_id)
	if offer != null:
		refund = offer.price
	if refund > 0:
		wallet.add(refund)
	var remaining_ids := shop_controller.unlocked_ball_ids
	remaining_ids.erase(ball_id)
	shop_controller.reset_unlocked_balls(remaining_ids)
	push_error("Reward ball unlock failed and was refunded: %s" % ball_id)


func _find_ball_offer(ball_id: StringName) -> RewardBallOffer:
	if shop_controller == null or shop_controller.catalog == null:
		return null
	for offer: RewardBallOffer in shop_controller.catalog.ball_offers:
		if offer != null and offer.ball_id == ball_id:
			return offer
	return null


func _on_stage_entered(
	_stage_runtime_id: StringName,
	_wave_index: int
) -> void:
	call_deferred(&"_capture_stage_entry")


func _capture_stage_entry() -> void:
	if wallet == null or shop_controller == null \
			or ball_inventory == null or part_inventory == null:
		return
	_entry_coin_balance = wallet.balance
	_entry_owned_definitions = ball_inventory.get_owned_definitions()
	_entry_unlocked_reward_ids = shop_controller.unlocked_ball_ids
	_entry_part_counts = part_inventory.snapshot()


func _on_wave_lost(_current_score: int, _target_score: int) -> void:
	if _rollback_queued:
		return
	_rollback_queued = true
	call_deferred(&"_rollback_to_stage_entry")


func _rollback_to_stage_entry() -> void:
	_rollback_queued = false
	if wave_manager.current_state != WaveManager.State.LOST:
		return
	var failure_wave := wave_manager.current_wave_index
	_clear_runtime_placements()
	part_inventory.restore(_entry_part_counts)
	ball_inventory.restore_owned_definitions(_entry_owned_definitions)
	shop_controller.reset_unlocked_balls(_entry_unlocked_reward_ids)
	wallet.reset(_entry_coin_balance)
	_last_delay_coin = 0
	if not wave_manager.rollback_to_stage_entry():
		push_error("Reward bridge could not roll the stage back to wave one.")
		return
	stage_state_rolled_back.emit(stage_id, failure_wave)


func _clear_runtime_placements() -> void:
	part_inventory.cancel_reservation()
	if placement_session == null:
		return
	if placement_session.current_state != BoardPlacementSession.State.IDLE:
		placement_session.end_wave()
	if placement_session.layout == null:
		return
	# manager의 REPAIR_PLACEMENT 신호가 같은 호출에서 새 예약 세션을 열므로
	# queue_free가 아니라 즉시 트리에서 제거해 기존 배치가 용량에 섞이지 않게 합니다.
	for placeable: BoardPlaceable in placement_session.layout.get_placeables():
		var parent := placeable.get_parent()
		if parent != null:
			parent.remove_child(placeable)
		placeable.free()


func _on_stage_completed(_stage_runtime_id: StringName) -> void:
	if shop_controller != null:
		shop_controller.reset_unlocked_balls()
	if ball_inventory != null:
		ball_inventory.reset_owned_to_starting_stock()
	if wallet != null:
		wallet.reset(0)
	_last_delay_coin = 0


func _assert_dependencies() -> void:
	assert(wave_manager != null, "Reward bridge requires RewardWaveManager.")
	assert(combo_system != null, "Reward bridge requires ComboSystem.")
	assert(ball_inventory != null, "Reward bridge requires SelectBallInventory.")
	assert(part_inventory != null, "Reward bridge requires RepairPartInventory.")
	assert(placement_session != null,
		"Reward bridge requires BoardPlacementSession.")
	assert(ball_inventory == null or ball_inventory.reusable_owned_balls,
		"Reward bridge requires reusable-owned-ball inventory mode.")
