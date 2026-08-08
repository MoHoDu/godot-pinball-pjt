extends SceneTree


const STAGE_SCENE := preload(
	"res://scenes/game/stages/stage_01/stage_01.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := STAGE_SCENE.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	var manager := stage.get_node("StageFlowManager") as ConfiguredStageFlowManager
	_expect(manager != null, "Stage 01 must use the Inspector-configured flow manager.")
	if manager != null:
		_expect(manager.initial_balls.size() == 3,
			"Stage 01 Inspector must expose three initial ball prefabs.")
		_expect(manager.initial_repair_parts.size() == 3,
			"Stage 01 Inspector must expose the repair part prefab catalog.")
		_expect(manager.get_configuration_error().is_empty(),
			"The authored Stage 01 loadout must be valid.")
		var initial_ids: Array[StringName] = []
		for entry: StageInitialBallEntry in manager.initial_balls:
			initial_ids.append(entry.ball_id)
		_expect(initial_ids == [&"gel", &"normal", &"heavy"],
			"Stage 01 must preserve the authored ball id and prefab order.")
		_expect(manager.initial_balls[0].ball_prefab.resource_path.ends_with(
			"/gel_ball.tscn"
		) and manager.initial_balls[2].ball_prefab.resource_path.ends_with(
			"/heavy_ball.tscn"
		), "Stage 01 ball ids must point to their matching prefabs.")
		_expect(manager.initial_balls[0].display_name == "젤 공",
			"Stage 01 gel ball display name must not contain stale whitespace.")
		_expect(manager.initial_coin_balance == 0,
			"Stage 01 initial coin balance must be an explicit safe integer.")
		var wave := manager.active_scene
		var inventory := wave.find_child(
			"WaveBallInventory", true, false
		) as WaveUniqueBallInventory if wave != null else null
		_expect(inventory != null,
			"The active wave must use the unique-per-wave ball inventory.")
		if inventory != null:
			_expect(inventory.get_owned_definitions().size() == 3,
				"The active wave must receive all Inspector ball prefabs.")
			_expect(inventory.total_remaining == 3,
				"The active wave must receive the Inspector launch count.")
		_expect(manager.reward_part_inventory.entries.size() == 3,
			"Stage reward runtime must receive Inspector repair part prefabs.")
		var wave_parts := wave.find_child(
			"RepairPartInventory", true, false
		) as RepairPartInventory if wave != null else null
		_expect(wave_parts != null and wave_parts.entries.size() == 3,
			"The active wave must receive all Inspector repair part prefabs.")
		if wave_parts != null:
			for entry: RepairPartInventoryEntry in wave_parts.entries:
				var expected_count := 3 \
					if entry.get_kind_id() == &"starlight_brooch" else 0
				_expect(entry.starting_count == expected_count \
					and entry.placeable_scene != null \
					and entry.icon != null,
					"Stage 01 repair entries must preserve prefab, icon, and starting count.")

	stage.queue_free()
	await process_frame
	_test_invalid_loadout_warning()
	_finish()


func _test_invalid_loadout_warning() -> void:
	var manager := ConfiguredStageFlowManager.new()
	manager.auto_start = false
	manager.scene_container = manager
	manager.wave_scenes = [STAGE_SCENE]
	manager.reward_scene = STAGE_SCENE
	manager.launches_per_wave = 2
	var only_ball := StageInitialBallEntry.new()
	only_ball.ball_id = &"normal"
	only_ball.display_name = "보통 공"
	only_ball.ball_prefab = preload(
		"res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
	)
	manager.initial_balls = [only_ball]
	_expect(
		manager.get_configuration_error().contains("Launches Per Wave"),
		"Inspector validation must reject more launches than unique ball prefabs."
	)
	manager.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_initial_loadout_test")
		quit(0)
		return
	print("FAIL: stage_initial_loadout_test (%d failures)" % _failures.size())
	quit(1)
