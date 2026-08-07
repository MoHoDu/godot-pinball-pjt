extends SceneTree


var _finished := false
var _success := false
var _message := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var sync := StageDatabaseSync.new()
	root.add_child(sync)
	sync.sync_completed.connect(_on_sync_completed)
	if not sync.sync_stage():
		push_error("Stage database sync could not start.")
		quit(1)
		return
	for _frame in 1200:
		if _finished:
			break
		await process_frame
	if not _finished:
		sync.cancel()
		push_error("Stage database sync timed out.")
		quit(1)
		return
	if not _success:
		push_error(_message)
		quit(1)
		return
	var repository := StageRewardRepository.new()
	root.add_child(repository)
	if repository.get_rewards(
		&"stage_01", StageRewardRepository.CATEGORY_BALL
	).size() != 5:
		push_error("Synced reward_balls.csv did not reload correctly.")
		quit(1)
		return
	if not FileAccess.file_exists(
		"res://Resources/stage/stage_01/reward_weight_overrides.csv"
	):
		push_error("Synced reward_weight_overrides.csv is missing.")
		quit(1)
		return
	print("PASS: stage_database_sync_test")
	quit(0)


func _on_sync_completed(success: bool, message: String) -> void:
	_finished = true
	_success = success
	_message = message
