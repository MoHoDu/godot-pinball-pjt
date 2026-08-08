extends SceneTree


const GAMEPLAY_SCENE := preload(
	"res://tests/stage_system/fixtures/stage_failure_fixture.tscn"
)
const REWARD_SCENE := preload(
	"res://scenes/tests/stage/fixtures/stage_reward_placeholder.tscn"
)
const DESTINATION_SCENE := preload(
	"res://tests/stage_system/fixtures/stage_segment_fixture.tscn"
)


class TransitionProbe:
	extends StageFlowManager

	var requested_destination: PackedScene

	func _transition_to_destination(destination: PackedScene) -> void:
		requested_destination = destination


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_defeat_destination_and_initial_coin()
	await _test_clear_destination()
	_finish()


func _test_defeat_destination_and_initial_coin() -> void:
	var manager := _make_manager()
	manager.initial_coin_balance = 37
	manager.defeat_destination_scene = DESTINATION_SCENE
	root.add_child(manager)
	_expect(manager.start_stage(), "패배 목적지 테스트 스테이지를 시작해야 한다.")
	_expect(manager.coin_wallet.balance == 37,
		"Inspector의 Initial Coin Balance를 스테이지 시작 지갑에 적용해야 한다.")
	manager.active_scene.call(&"fail")
	await process_frame
	await process_frame
	_expect(manager.requested_destination == DESTINATION_SCENE,
		"패배 후 Inspector에 지정한 PackedScene으로 전환을 요청해야 한다.")
	manager.queue_free()
	await process_frame


func _test_clear_destination() -> void:
	var manager := _make_manager()
	manager.clear_destination_scene = DESTINATION_SCENE
	root.add_child(manager)
	_expect(manager.start_stage(), "클리어 목적지 테스트 스테이지를 시작해야 한다.")
	manager.active_scene.call(&"complete")
	await process_frame
	await process_frame
	var reward := manager.active_scene as StageRewardPlaceholder
	_expect(reward != null and reward.continue_stage(),
		"마지막 웨이브 보상 화면을 진행해야 한다.")
	await process_frame
	await process_frame
	_expect(manager.current_phase == StageFlowManager.Phase.COMPLETE,
		"마지막 보상 이후 스테이지 COMPLETE 상태를 거쳐야 한다.")
	_expect(manager.requested_destination == DESTINATION_SCENE,
		"클리어 후 Inspector에 지정한 PackedScene으로 전환을 요청해야 한다.")
	manager.queue_free()
	await process_frame


func _make_manager() -> TransitionProbe:
	var manager := TransitionProbe.new()
	manager.auto_start = false
	manager.wave_scenes = [GAMEPLAY_SCENE]
	manager.reward_scene = REWARD_SCENE
	var container := Node.new()
	container.name = "SceneContainer"
	manager.add_child(container)
	manager.scene_container = container
	var wallet := CoinWallet.new()
	wallet.name = "CoinWallet"
	manager.add_child(wallet)
	manager.coin_wallet = wallet
	return manager


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_exit_configuration_test")
		quit(0)
		return
	print("FAIL: stage_exit_configuration_test (%d failures)" % _failures.size())
	quit(1)
