extends SceneTree


const CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)
const SIMULATOR := preload(
	"res://scripts/stage_manage/stage_reward_simulator.gd"
)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var result: Dictionary = SIMULATOR.simulate_and_save(
		StageRewardRepository.DEFAULT_STAGE_ID,
		CATALOG,
		SIMULATOR.DEFAULT_ITERATIONS
	)
	if not bool(result.get(&"ok", false)):
		push_error(result.get(&"error", "보상 시뮬레이션 실패"))
		quit(1)
		return
	print(
		"PASS: stage_reward_simulation_runner iterations=%d path=%s"
		% [result[&"iterations"], result[&"path"]]
	)
	quit(0)
