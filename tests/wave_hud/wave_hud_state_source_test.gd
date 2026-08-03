extends SceneTree


class ContractOnlySnapshotProvider:
	extends Node

	signal snapshot_changed(snapshot: Dictionary)

	func get_snapshot() -> Dictionary:
		return {
			&"life_slots": [],
			&"current_score": 0,
			&"target_score": 0,
			&"active_combo": 0,
			&"max_combo": 0,
			&"combo_visible": false,
			&"combo_anchor_viewport": Vector2.ZERO,
			&"combo_anchor_visible": false,
			&"wave_index": 0,
			&"paused": false,
		}


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var source := WaveHudStateSource.new()
	root.add_child(source)
	var publish_count := [0]
	source.snapshot_changed.connect(func(_snapshot: Dictionary) -> void:
		publish_count[0] += 1
	)

	source.begin_batch()
	source.configure_lives([&"cat_eye", &"normal", &"industrial_steel"])
	source.set_score(125000, 250000)
	source.observe_combo(7)
	source.set_wave_index(1)
	source.end_batch()
	_expect(publish_count[0] == 1, "A batch must publish one atomic HUD snapshot.")

	var snapshot := source.get_snapshot()
	var slots: Array = snapshot[&"life_slots"]
	_expect(slots.size() == 3, "Three configured balls must create three fixed slots.")
	_expect(int(slots[0][&"state"]) == WaveHudStateSource.LifeState.CURRENT,
		"The first configured ball must be current.")
	_expect(int(slots[1][&"state"]) == WaveHudStateSource.LifeState.UPCOMING,
		"Later configured balls must remain upcoming.")
	_expect(int(snapshot[&"max_combo"]) == 7, "Observed combo must update wave max.")
	_expect(bool(snapshot[&"combo_visible"]),
		"An active combo must show the world combo UI.")

	source.observe_combo(2)
	_expect(int(source.get_snapshot()[&"max_combo"]) == 7,
		"Wave max combo must not fall with the active chain.")
	source.observe_combo(0)
	_expect(int(source.get_snapshot()[&"active_combo"]) == 2 \
		and bool(source.get_snapshot()[&"combo_visible"]),
		"Zero combo must stay visible until score conversion finishes.")
	source.finish_combo_display()
	_expect(int(source.get_snapshot()[&"active_combo"]) == 0 \
		and not bool(source.get_snapshot()[&"combo_visible"]),
		"Combo finish must hide the world UI without erasing wave max.")
	var remaining := source.consume_current_life()
	snapshot = source.get_snapshot()
	slots = snapshot[&"life_slots"]
	_expect(remaining == 2, "Consuming one of three lives must leave two.")
	_expect(int(slots[0][&"state"]) == WaveHudStateSource.LifeState.SPENT,
		"Consumed slot must stay in place and become spent.")
	_expect(int(slots[1][&"state"]) == WaveHudStateSource.LifeState.CURRENT,
		"The next fixed slot must become current.")
	_expect(source.select_life(&"industrial_steel"),
		"An available ball type must become the selected current life.")
	snapshot = source.get_snapshot()
	slots = snapshot[&"life_slots"]
	_expect(int(slots[1][&"state"]) == WaveHudStateSource.LifeState.UPCOMING,
		"Changing selection must return the previous unspent slot to upcoming.")
	_expect(int(slots[2][&"state"]) == WaveHudStateSource.LifeState.CURRENT,
		"Selection must support a non-sequential remaining ball.")
	_expect(source.consume_current_life() == 1,
		"Consuming the selected last slot must preserve earlier remaining lives.")
	_expect(source.get_current_life_type() == &"normal",
		"Life consumption must wrap to the next remaining slot.")

	var hud_scene := load("res://scenes/wave_hud/wave_hud.tscn") as PackedScene
	var hud := hud_scene.instantiate() as WaveHud
	root.add_child(hud)
	await process_frame
	hud.bind_state_source(source)
	await process_frame

	var life := hud.get_node("DesignSpace/LifeHud") as WaveLifeHud
	_expect(is_equal_approx(life.size.x, 228.0),
		"Three slots must use 36 + 3*56 + 2*12 = 228 logical pixels.")
	var rendered_slots := life.get_node("Slots").get_children()
	for slot_control: Control in rendered_slots:
		var expected_size := Vector2(68.0, 68.0) \
			if slot_control.name == &"CurrentOutline" else Vector2(56.0, 56.0)
		_expect(slot_control.size.is_equal_approx(expected_size),
			"Life icon layers must keep their explicit logical size.")
	var score := hud.get_node("DesignSpace/ScoreRepairHud") as WaveScoreRepairHud
	_expect(is_equal_approx(score.get_repair_ratio(), 0.5),
		"Repair gauge must clip to current / target.")
	source.set_score(999, 0)
	_expect(is_equal_approx(score.get_repair_ratio(), 0.0),
		"A zero target must produce a safe empty repair gauge.")
	source.set_score(300000, 250000)
	_expect(is_equal_approx(score.get_repair_ratio(), 1.0),
		"Repair gauge must clamp scores above target to full.")

	source.configure_lives([
		&"normal", &"cat_eye", &"industrial_steel", &"normal", &"cat_eye"
	])
	_expect(is_equal_approx(life.size.x, 364.0),
		"Five slots must use the documented 364 logical pixel width.")

	var contract_only_provider := ContractOnlySnapshotProvider.new()
	root.add_child(contract_only_provider)
	_expect(hud.bind_state_source(contract_only_provider),
		"HUD must accept any Node that provides the snapshot contract.")

	hud.queue_free()
	source.queue_free()
	contract_only_provider.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_hud_state_source_test")
		quit(0)
		return
	print("FAIL: wave_hud_state_source_test (%d failures)" % _failures.size())
	quit(1)
