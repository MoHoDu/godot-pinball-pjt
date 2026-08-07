extends SceneTree


const CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)
const SIMULATOR := preload(
	"res://scripts/stage_manage/stage_reward_simulator.gd"
)
const ITERATIONS := 2000
const TEST_REPORT_PATH := "user://stage_reward_simulator_test.csv"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var result: Dictionary = SIMULATOR.simulate_and_save(
		&"stage_01", CATALOG, ITERATIONS, 20260807, 18, TEST_REPORT_PATH
	)
	_expect(bool(result.get(&"ok", false)),
		"Reward simulation must complete and save its CSV report.")
	if not bool(result.get(&"ok", false)):
		_finish()
		return
	var rows: Array = result[&"rows"]
	_expect(rows.size() == 24,
		"Three waves must report five balls and three enabled parts each.")
	for wave_num in range(1, 4):
		var ball_total := 0
		var part_total := 0
		for row: Dictionary in rows:
			if int(row[&"wave_num"]) != wave_num:
				continue
			if row[&"category"] == StageRewardRepository.CATEGORY_BALL:
				ball_total += int(row[&"appearance_count"])
			else:
				part_total += int(row[&"appearance_count"])
		_expect(ball_total == ITERATIONS * 3,
			"Each simulated reward must show three ball cards.")
		_expect(part_total == ITERATIONS * 3,
			"Each simulated reward must show three part cards.")
	_expect(String(result[&"path"]) == TEST_REPORT_PATH,
		"Simulation test must use its isolated output path.")
	_expect(FileAccess.file_exists(TEST_REPORT_PATH),
		"Simulation report CSV must exist in the test user folder.")
	if FileAccess.file_exists(TEST_REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REPORT_PATH))
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_reward_simulator_test")
		quit(0)
		return
	print("FAIL: stage_reward_simulator_test (%d failures)" % _failures.size())
	quit(1)
