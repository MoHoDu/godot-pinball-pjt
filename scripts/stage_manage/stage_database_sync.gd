@tool
class_name StageDatabaseSync
extends Node


signal sync_completed(success: bool, message: String)


const SPREADSHEET_ID := "1Q0MfGXOUsKpdfwdUjT-Sz99P-KFjJaeOnOluKiMcSaQ"
const DEFAULT_STAGE_ID := "stage_01"
const SUPPORTED_STAGE_IDS := [DEFAULT_STAGE_ID]
const DATABASES := [
	{
		&"name": "reward_balls",
		&"gid": "0",
		&"file_name": "reward_balls.csv",
	},
	{
		&"name": "reward_parts",
		&"gid": "1737279134",
		&"file_name": "reward_parts.csv",
	},
]


var _request: HTTPRequest
var _stage_id := DEFAULT_STAGE_ID
var _pending: Array[Dictionary] = []
var _downloaded: Dictionary = {}
var _syncing := false


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.name = "StageDatabaseHTTPRequest"
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func sync_stage(stage_id := DEFAULT_STAGE_ID) -> bool:
	if _syncing:
		return false
	if not SUPPORTED_STAGE_IDS.has(stage_id):
		sync_completed.emit(false, "지원하지 않는 스테이지 ID입니다: %s" % stage_id)
		return false
	_stage_id = stage_id
	_pending.clear()
	for database: Dictionary in DATABASES:
		_pending.append(database.duplicate(true))
	_downloaded.clear()
	_syncing = true
	_request_next()
	return true


func cancel() -> void:
	if _request != null:
		_request.cancel_request()
	_syncing = false
	_pending.clear()
	_downloaded.clear()


func _request_next() -> void:
	if _pending.is_empty():
		_finish_downloads()
		return
	var database: Dictionary = _pending.front()
	var url := (
		"https://docs.google.com/spreadsheets/d/%s/export?format=csv&gid=%s"
		% [SPREADSHEET_ID, database[&"gid"]]
	)
	var error: Error = _request.request(url)
	if error != OK:
		_fail("Google Sheets 요청을 시작하지 못했습니다: %s" % error_string(error))


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if not _syncing or _pending.is_empty():
		return
	var database: Dictionary = _pending.pop_front()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail(
			"%s 다운로드 실패(result=%d, HTTP=%d)"
			% [database[&"name"], result, response_code]
		)
		return
	var csv_text := body.get_string_from_utf8().replace("\r\n", "\n").replace("\r", "\n")
	if not csv_text.ends_with("\n"):
		csv_text += "\n"
	var validation := _validate_download(database, csv_text)
	if not bool(validation.get(&"ok", false)):
		_fail(String(validation.get(&"error", "CSV 검증 실패")))
		return
	_downloaded[database[&"file_name"]] = csv_text
	_request_next()


func _validate_download(database: Dictionary, csv_text: String) -> Dictionary:
	var temp_dir := "user://stage_database_sync"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	var temp_path := "%s/%s" % [temp_dir, database[&"file_name"]]
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return {&"ok": false, &"error": "임시 CSV 파일을 만들 수 없습니다."}
	temp_file.store_string(csv_text)
	temp_file.close()
	var result := StageRewardRepository.parse_csv_file(temp_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	return result


func _finish_downloads() -> void:
	var target_dir := "res://Resources/stage/%s" % _stage_id
	var mkdir_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_dir)
	)
	if mkdir_error != OK:
		_fail("스테이지 데이터 폴더를 만들 수 없습니다: %s" % error_string(mkdir_error))
		return
	_recover_interrupted_sync(target_dir)
	var prepared: Array[Dictionary] = []
	for file_name: String in _downloaded:
		var target_path := "%s/%s" % [target_dir, file_name]
		var temp_path := "%s.sync_tmp" % target_path
		var backup_path := "%s.sync_backup" % target_path
		var file := FileAccess.open(temp_path, FileAccess.WRITE)
		if file == null:
			_cleanup_transaction_files(prepared)
			_fail("CSV 임시 파일을 저장할 수 없습니다: %s" % temp_path)
			return
		file.store_string(String(_downloaded[file_name]))
		file.close()
		prepared.append({
			&"target": target_path,
			&"temp": temp_path,
			&"backup": backup_path,
			&"had_target": FileAccess.file_exists(target_path),
			&"promoted": false,
		})
	if not _promote_transaction(prepared):
		_fail("CSV 파일 교체에 실패하여 기존 데이터베이스로 복원했습니다.")
		return
	_syncing = false
	_pending.clear()
	_downloaded.clear()
	sync_completed.emit(
		true,
		"Google Sheets의 최신 보상 DB를 %s에 저장했습니다." % target_dir
	)


func _promote_transaction(prepared: Array[Dictionary]) -> bool:
	for item: Dictionary in prepared:
		var target := ProjectSettings.globalize_path(String(item[&"target"]))
		var temp := ProjectSettings.globalize_path(String(item[&"temp"]))
		var backup := ProjectSettings.globalize_path(String(item[&"backup"]))
		if bool(item[&"had_target"]):
			var backup_error := DirAccess.rename_absolute(target, backup)
			if backup_error != OK:
				_rollback_transaction(prepared)
				return false
		var promote_error := DirAccess.rename_absolute(temp, target)
		if promote_error != OK:
			_rollback_transaction(prepared)
			return false
		item[&"promoted"] = true
	for item: Dictionary in prepared:
		var backup := ProjectSettings.globalize_path(String(item[&"backup"]))
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
	return true


func _rollback_transaction(prepared: Array[Dictionary]) -> void:
	for item: Dictionary in prepared:
		var target := ProjectSettings.globalize_path(String(item[&"target"]))
		var temp := ProjectSettings.globalize_path(String(item[&"temp"]))
		var backup := ProjectSettings.globalize_path(String(item[&"backup"]))
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)
		if FileAccess.file_exists(backup):
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(target)
			DirAccess.rename_absolute(backup, target)
		elif bool(item.get(&"promoted", false)) \
				and not bool(item.get(&"had_target", false)) \
				and FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)


func _cleanup_transaction_files(prepared: Array[Dictionary]) -> void:
	for item: Dictionary in prepared:
		var temp := ProjectSettings.globalize_path(String(item[&"temp"]))
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)


func _recover_interrupted_sync(target_dir: String) -> void:
	for database: Dictionary in DATABASES:
		var target_path := "%s/%s" % [target_dir, database[&"file_name"]]
		var temp := ProjectSettings.globalize_path("%s.sync_tmp" % target_path)
		var backup := ProjectSettings.globalize_path("%s.sync_backup" % target_path)
		var target := ProjectSettings.globalize_path(target_path)
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)
		if not FileAccess.file_exists(backup):
			continue
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(backup, target)


func _fail(message: String) -> void:
	_syncing = false
	_pending.clear()
	_downloaded.clear()
	sync_completed.emit(false, message)
