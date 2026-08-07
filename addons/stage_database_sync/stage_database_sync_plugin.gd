@tool
extends EditorPlugin


const MENU_TITLE := "Stage DB/Google Sheets에서 최신 CSV 가져오기"
const SYNC_SERVICE := preload(
	"res://scripts/stage_manage/stage_database_sync.gd"
)


var _sync_service: StageDatabaseSync


func _enter_tree() -> void:
	_sync_service = SYNC_SERVICE.new() as StageDatabaseSync
	_sync_service.name = "StageDatabaseSync"
	add_child(_sync_service)
	_sync_service.sync_completed.connect(_on_sync_completed)
	add_tool_menu_item(MENU_TITLE, _sync_from_google_sheets)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TITLE)
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
