extends SceneTree
## 보스 SFX 배선을 검증합니다.
##
## ★ 보스 본체는 아직 씬에 없다. 그래서 여기서는 **늦게 생성되는** 보스를
##   흉내 낸다 — 연구실을 띄운 뒤 ComboBossTarget 을 트리에 더하고,
##   boss_hit · defeated 가 실제로 소리를 내는지 본다.
##   보스 구현이 들어왔을 때 이 경로가 그대로 게임의 경로다.

var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var rules := load("res://settings/sfx/BossSfxRules.tres") as BossSfxRules
	if not _expect(rules != null, "보스 규칙이 로딩된다"):
		quit(1)
		return

	for field in ["telegraph_cue", "arm_swing_cue", "hit_cue", "roar_cue",
			"cotton_telegraph_cue", "cotton_spawn_cue", "defeated_cue",
			"heartbeat_cue"]:
		var cue: SfxCue = rules.get(field)
		_expect(cue != null and not cue.streams.is_empty(),
			"%s 에 음원이 물려 있다" % field)

	var packed := load("res://scenes/test_sfx/sfx_lab_ball.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame

	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder
	_expect(binder != null and binder.boss_rules != null,
		"연구실 바인더에 보스 규칙이 물려 있다")

	var played: Array[StringName] = []
	binder.get_director().cue_played.connect(
		func(cue_id: StringName, _p: float, _v: float, _s: float) -> void:
			played.append(cue_id))

	# ★ 보스를 늦게 트리에 넣는다 — 스테이지 전환과 같은 경로다.
	var boss := ComboBossTarget.new()
	scene.add_child(boss)
	await physics_frame

	boss.boss_hit.emit(1, 10, 10, 90, 3)
	await physics_frame
	_expect(&"boss_hit" in played, "늦게 생긴 보스의 피격이 소리를 낸다")

	boss.defeated.emit()
	await physics_frame
	_expect(&"boss_defeated" in played, "처치가 소리를 낸다")

	print("PASS: boss_sfx_test" if not _failed else "FAIL: boss_sfx_test")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failed = true
		print("  실패 — %s" % label)

	return condition
