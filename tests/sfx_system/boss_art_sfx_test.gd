extends SceneTree
## 보스 애니메이션에 소리가 붙었는지 검증합니다.
##
## 키 입력이 아니라 **리그의 상태 전이**를 직접 몰아, 애니메이션이 흐르면
## 소리가 같은 순간에 나는지 봅니다. Space 시퀀스와 같은 경로입니다.
##
## ★ 컨트롤러는 _process(아이들 프레임) 폴링이다. physics_frame 만 기다리면
##   _process 가 안 돌아서 전이 두 개가 한 프레임에 뭉개진다 — 실제로
##   telegraph→attack 이 attack 하나로 붙어 예고음이 사라졌다.
##   그래서 여기서는 반드시 process_frame 을 기다린다.

var _failed := false


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/test_sfx/boss_art_sfx_test.tscn") as PackedScene
	if not _expect(packed != null, "검수 씬이 로딩된다"):
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var director := scene.get_node_or_null(^"SfxDirector") as SfxDirector
	var rig := scene.get_node_or_null(^"Rig")
	_expect(director != null, "디렉터가 있다")
	_expect(rig != null, "리그가 있다")
	_expect(scene.boss_rules != null, "보스 규칙이 물려 있다")

	if _failed:
		quit(1)
		return

	var played: Array[StringName] = []
	director.cue_played.connect(
		func(cue_id: StringName, _p: float, _v: float, _s: float) -> void:
			played.append(cue_id))

	# 예고 → 공격 → 포효 → 피격 반동. 전부 애니메이션 쪽 API 로만 몬다.
	rig.play_telegraph()
	await process_frame
	_expect(&"boss_telegraph" in played, "예고 자세에 실 끼익이 붙는다")

	rig.play_attack()
	await process_frame
	_expect(&"boss_arm_swing" in played, "공격 자세에 천 휙이 붙는다")

	rig.play_roar()
	await process_frame
	_expect(&"boss_roar" in played, "포효 자세에 오르골이 붙는다")

	rig.play_hit(1.0)
	await process_frame
	_expect(&"boss_hit" in played, "피격 반동에 팡이 붙는다")

	# 같은 상태를 다시 켜도 소리가 겹으로 나면 안 된다
	var before := played.size()
	rig.play_roar()
	await process_frame
	_expect(played.size() == before, "같은 상태 반복은 소리를 겹치지 않는다")

	print("PASS: boss_art_sfx_test" if not _failed else "FAIL: boss_art_sfx_test")
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failed = true
		print("  실패 — %s" % label)

	return condition
