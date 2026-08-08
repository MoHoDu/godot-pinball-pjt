extends SceneTree


const WAVE_SCENE := preload("res://Resources/Prefabs/wave/base/wave_unique.tscn")
const LIGHT_BALL := preload(
	"res://Resources/Prefabs/balls/variants/mass/light_ball.tscn"
)
const NORMAL_BALL := preload(
	"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
)
const HEAVY_BALL := preload(
	"res://Resources/Prefabs/balls/variants/mass/heavy_ball.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var wave := WAVE_SCENE.instantiate() as WaveRuntimeCoordinator
	var authored_inventory := wave.wave_ball_inventory as WaveUniqueBallInventory
	authored_inventory.starting_stock = [
		_make_stock(&"light", "가벼운 공", LIGHT_BALL),
		_make_stock(&"normal", "보통 공", NORMAL_BALL),
		_make_stock(&"heavy", "무거운 공", HEAVY_BALL),
	]
	root.add_child(wave)
	await process_frame
	await process_frame
	await process_frame

	var bridge := wave.get_node("WaveRewardShopBridge") as WaveRewardShopBridge
	var manager := wave.wave_manager as RewardWaveManager
	var inventory := wave.wave_ball_inventory as SelectBallInventory
	var parts := wave.get_node("RepairPartInventory") as RepairPartInventory
	var placement_controller := wave.get_node(
		"RepairPartPlacementController"
	) as RepairPartPlacementController
	var placement_session := wave.get_node(
		"RepairBoardLayout/PlacementSession"
	) as BoardPlacementSession
	var placement := wave.get_node(
		"BoardWavePlacementBridge"
	) as BoardWavePlacementBridge

	_expect(bridge != null and bridge.wallet != null \
		and bridge.clear_delay != null and bridge.shop_controller != null,
		"The main Wave scene must initialize the complete reward bridge.")
	_expect(bridge.wallet.balance == 0 and parts.total_count == 0,
		"A new stage must start with no coins and no repair parts.")
	_expect(inventory.reusable_owned_balls \
		and inventory.get_owned_definitions().size() == 3 \
		and inventory.total_remaining == 3,
		"The stage must start with three unique balls and three launches.")
	_expect(WaveClearDelayController.convert_delay_score(
		999999, 250000, 0.05, 5
	) == 5, "Score reward conversion must cap each normal wave at five coins.")

	_expect(placement.commit_placement(),
		"Empty placement must enter wave one through the main phase bridge.")
	_expect(wave.wave_ball_flow.confirm_selection(),
		"The normal ball must prepare for the score-reward integration test.")
	var active_ball := wave.wave_ball_flow.active_ball
	_expect(wave.launcher.launch_prepared_ball(),
		"The prepared ball must launch through the main launcher.")

	# 목표 점수를 공이 살아 있는 상태에서 정산해 3초 유예를 시작합니다.
	wave.combo_system.register_hit(20000.0)
	wave.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_expect(manager.current_state == WaveManager.State.IN_PLAY,
		"Target score must not remove the active ball immediately.")
	_expect(bridge.clear_delay.is_delay_active,
		"Target score must start the configured three-second clear delay.")

	# 유예 동안 충분한 추가 점수를 정산한 뒤 공을 낙하시킵니다.
	wave.combo_system.register_hit(20000.0)
	wave.combo_system.finish_combo(ComboSystem.EndReason.MANUAL)
	_expect(wave.wave_ball_flow.on_ball_drained(active_ball),
		"Ball drain must close the clear delay through the main flow.")
	await process_frame
	await process_frame
	_expect(manager.current_state == WaveManager.State.WON,
		"The clear delay must settle into a normal wave victory.")
	_expect(bridge.wallet.balance == 5,
		"Only score-based reward coins should be paid, capped at five.")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.REWARD \
		and bridge.shop_controller.is_open and bridge.shop_hud.visible,
		"Victory must automatically open the reward shop in the main Wave scene.")
	_expect(bridge.shop_controller.ball_offers.size() == 3 \
		and bridge.shop_controller.part_offers.size() == 3,
		"The reward screen must expose three ball and three v0.3 part cards.")
	for offer: RepairPartOffer in bridge.shop_controller.part_offers:
		_expect(offer.part_id != &"crescent_needle",
			"Crescent Needle must not appear in the v0.3 reward screen.")

	# 실제 가격과 무관하게 구매 연동 자체를 확인하기 위한 테스트 잔액입니다.
	bridge.wallet.reset(999)
	var bought_ball := bridge.shop_controller.buy_ball(0)
	var bought_part := bridge.shop_controller.buy_part(0)
	_expect(bought_ball and inventory.get_owned_definitions().size() == 4,
		"Buying a ball must add it to the selectable main inventory.")
	_expect(bought_part and parts.total_count > 0,
		"Buying a part must add its bundle to the placement inventory.")
	var carried_balance := bridge.wallet.balance
	bridge.call(&"_on_shop_proceed")
	_expect(manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT \
		and manager.current_wave_index == 1,
		"Proceeding must enter the next wave repair-placement phase.")
	_expect(bridge.wallet.balance == carried_balance,
		"Unused coins must carry across normal waves in the stage.")

	# 상점이 닫히면 후보 배열이 비워지므로, 보유 수량이 생긴 실제 부품 ID를 찾습니다.
	var placed_part_id: StringName = &""
	for part_id: StringName in parts.snapshot():
		if parts.count_of(part_id) > 0:
			placed_part_id = part_id
			break
	_expect(not placed_part_id.is_empty(),
		"The purchased part id must remain available for placement.")
	var placed := false
	for socket: BoardPlacementSocket in placement_session.layout.get_sockets():
		if placement_controller.place_kind_at_socket(
			placed_part_id, socket.socket_id
		):
			placed = true
			break
	_expect(placed,
		"A purchased part must be placeable before the rollback check.")
	_expect(placement.commit_placement(),
		"Purchased inventory must proceed into the next wave.")
	manager.call(&"_finish_lost")
	await process_frame
	await process_frame
	_expect(manager.current_wave_index == 0 \
		and manager.current_stage_phase == WaveManager.StagePhase.REPAIR_PLACEMENT,
		"Failure must roll the stage back to wave-one placement.")
	_expect(bridge.wallet.balance == 0 \
		and inventory.get_owned_definitions().size() == 3 \
		and parts.total_count == 0,
		"Failure must restore stage-entry coins, reward balls, and parts.")
	_expect(placement_session.layout.get_placeables().is_empty(),
		"Failure must remove stage-purchased parts already placed on the board.")

	wave.queue_free()
	await process_frame
	_finish()


func _make_stock(
	ball_id: StringName,
	display_name: String,
	prefab: PackedScene
) -> BallStock:
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = prefab
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 1
	return stock


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_reward_shop_bridge_test")
		quit(0)
		return
	print("FAIL: wave_reward_shop_bridge_test (%d failures)" % _failures.size())
	quit(1)
