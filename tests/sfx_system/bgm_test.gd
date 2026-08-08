extends SceneTree
## BGM 루프가 규격대로인지 검증합니다.

var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	# 파일 규격 — 루프 임포트와 음량. 웨이브·보스 두 루프 다 본다.
	for entry: Array in [["BGM_Wave_Loop", 20.0], ["BGM_Boss_Loop", 10.0]]:
		var stream := load("res://Resources/sfx/bgm/%s.wav" % entry[0]) as AudioStreamWAV
		_expect(stream != null, "%s 가 임포트된다" % entry[0])
		if stream == null:
			continue
		# ★ 루프 모드가 꺼져 있으면 끝난 뒤 조용해지는데, 게임 중엔
		#   아무도 눈치 못 채고 "가끔 음악이 없다" 는 버그가 된다.
		_expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"%s 이 무한 루프로 임포트됐다" % entry[0])
		_expect(stream.get_length() >= entry[1],
			"%s 길이가 충분하다 (%.1fs)" % [entry[0], stream.get_length()])

	# 씬 배선 — wave 씬에 재생기가 있고 스트림이 물려 있다
	var packed := load("res://scenes/wave/wave.tscn") as PackedScene
	_expect(packed != null, "wave 씬이 로딩된다")
	if packed != null:
		var scene := packed.instantiate()
		root.add_child(scene)
		await physics_frame
		var bgm := scene.get_node_or_null(^"BgmPlayer") as AudioStreamPlayer
		_expect(bgm != null, "wave 씬에 BgmPlayer 가 있다")
		if bgm != null:
			_expect(bgm.stream != null, "스트림이 물려 있다")
			_expect(bgm.playing, "시작하면 바로 흐른다")
			_expect(bgm.bus == &"BGM", "웨이브 BGM이 설정의 BGM 버스를 사용한다")
			_expect(bgm.volume_db <= 0.0, "BGM 이 SFX 위로 올라가지 않는다 (가이드 15장)")
		scene.queue_free()
		await process_frame

	# stage_01이 실제 사용하는 프로덕션 보스 씬에 보스 루프가 물려 있다.
	var boss_packed := load(
		"res://scenes/wave/stage1_teddy_boss_scene.tscn"
	) as PackedScene
	if _expect(boss_packed != null, "프로덕션 보스 씬이 로딩된다"):
		var boss_scene := boss_packed.instantiate()
		root.add_child(boss_scene)
		await physics_frame
		var boss_bgm := boss_scene.get_node_or_null(^"BgmPlayer") as AudioStreamPlayer
		_expect(boss_bgm != null and boss_bgm.playing,
			"프로덕션 보스 씬에서 보스 루프가 흐른다")
		_expect(boss_bgm != null and boss_bgm.bus == &"BGM",
			"프로덕션 보스 루프가 설정의 BGM 버스를 사용한다")
		_expect(boss_bgm != null and boss_bgm.stream != null
			and boss_bgm.stream.resource_path
				== "res://Resources/sfx/bgm/BGM_Boss_Loop.wav",
			"프로덕션 보스 씬이 보스 전용 루프를 사용한다")

	print("PASS: bgm_test" if not _failed else "FAIL: bgm_test")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failed = true
		print("  실패 — %s" % label)

	return condition
