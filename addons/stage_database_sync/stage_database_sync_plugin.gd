@tool
extends EditorPlugin


const MENU_TITLE := "Stage DB/Google Sheets에서 최신 CSV 가져오기"
const SIMULATION_MENU_TITLE := "Stage DB/보상 확률 10만 회 시뮬레이션"
const SYNC_SERVICE := preload(
	"res://scripts/stage_manage/stage_database_sync.gd"
)
const SIMULATOR := preload(
	"res://scripts/stage_manage/stage_reward_simulator.gd"
)
const STAGE_01_CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)


var _sync_service: StageDatabaseSync


func _enter_tree() -> void:
	_sync_service = SYNC_SERVICE.new() as StageDatabaseSync
	_sync_service.name = "StageDatabaseSync"
	add_child(_sync_service)
	_sync_service.sync_completed.connect(_on_sync_completed)
	add_tool_menu_item(MENU_TITLE, _sync_from_google_sheets)
	add_tool_menu_item(SIMULATION_MENU_TITLE, _simulate_reward_rates)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TITLE)
	remove_tool_menu_item(SIMULATION_MENU_TITLE)
	if _sync_service != null:
		_sync_service.cancel()
		_sync_service.queue_free()
	_sync_service = null


func _sync_from_google_sheets() -> void:
	if _sync_service == null or not _sync_service.sync_stage():
		push_warning("Stage DB 동기화가 이미 실행 중입니다.")
		return
	print("Stage DB: Google Sheets 동기화를 시작했습니다.")


func _on_sync_completed(success: bool, message: String) -> void:
	if success:
		EditorInterface.get_resource_filesystem().scan()
		print("Stage DB: %s" % message)
		return
	push_error("Stage DB: %s" % message)


func _simulate_reward_rates() -> void:
	print("Stage DB: 보상 확률 10만 회 시뮬레이션을 시작했습니다.")
	var result: Dictionary = SIMULATOR.simulate_and_save(
		StageRewardRepository.DEFAULT_STAGE_ID,
		STAGE_01_CATALOG,
		SIMULATOR.DEFAULT_ITERATIONS
	)
	if not bool(result.get(&"ok", false)):
		push_error("Stage DB: %s" % result.get(&"error", "시뮬레이션 실패"))
		return
	EditorInterface.get_resource_filesystem().scan()
	print(
		"Stage DB: %d회 시뮬레이션 결과를 %s에 저장했습니다."
		% [result[&"iterations"], result[&"path"]]
	)
