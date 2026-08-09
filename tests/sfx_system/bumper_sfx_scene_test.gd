extends SceneTree
## 범퍼 사운드 검수 씬이 실제로 소리를 내는지 확인합니다.
##
## ★ 이 테스트가 생긴 이유
##   씬을 처음 붙였을 때 배선이 **범퍼 0건**이었습니다. 테스트 리그가 범퍼를
##   `_ready()` 뒤에 만들기 때문입니다. 바인더가 한 번만 훑으면 그 뒤에 생긴
##   것은 전부 무음이 됩니다. 게임에서도 공은 웨이브마다 새로 만들어지므로
##   같은 함정이 그대로 있었습니다.
##
##   그래서 여기서는 **범퍼를 하나씩 갈아 끼우며** 매번 잡히는지 봅니다.
##   한 번 성공하는 것으로는 늦은 배선을 검증할 수 없습니다.

const SCENE := "res://scenes/tests/sfx/bumper_sfx_test.tscn"

## VFX 테스트 씬에 배치된 5종입니다. 재질음이 서로 갈리는 것들입니다.
const EXPECTED_KINDS: Array[StringName] = [
	&"stage01_button",
	&"stage01_cotton",
	&"stage01_spring_doll",
	&"stage01_toy_drum",
	&"stage01_clockwork_cannon",
]

## 공이 낙하 높이에서 범퍼까지 떨어지기를 기다리는 최대 시간입니다.
## 넉넉히 3초를 잡아도 소리가 나는 즉시 빠져나갑니다.
const DROP_TIMEOUT_SECONDS := 3.0

var _failed := false

## 재질 -> 그 범퍼에서 처음 난 큐. 서로 갈리는지 마지막에 봅니다.
var _first_cue := {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(SCENE) as PackedScene
	if not _expect(packed != null, "검수 씬이 로딩된다"):
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame

	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder
	_expect(binder != null, "바인더가 붙어 있다")
	_expect(binder != null and binder.bumper_rules != null, "범퍼 규칙이 물려 있다")
	_expect(binder != null and binder.get_director() != null, "디렉터를 찾았다")

	if _failed:
		quit(1)
		return

	var played: Array[StringName] = []
	binder.get_director().cue_played.connect(
		func(cue_id: StringName, _p: float, _v: float, _s: float) -> void:
			played.append(cue_id))

	# 배치된 범퍼를 하나씩 돌면서 매번 새로 잡히는지 본다.
	var seen: Array[StringName] = []
	for i in EXPECTED_KINDS.size():
		scene.start_test()
		for _f in 4:
			await physics_frame

		var bumper := _live_bumper(scene)
		if not _expect(bumper != null, "%d번째 범퍼가 배치된다" % (i + 1)):
			break

		var kind := BumperSfxRules.kind_id_of(bumper)
		seen.append(kind)

		# ★ 늦게 생긴 범퍼를 바인더가 잡았는가. 이 씬의 핵심 회귀다.
		_expect(bumper in binder.get_bound_bumpers(),
			"늦게 생긴 범퍼(%s)가 배선된다" % kind)

		# ★ 시그널을 손으로 쏘지 않고 **실제로 떨어뜨립니다.**
		#   손으로 쏘면 공이 null 이라 속도별 음량도, 공별 연타 감쇠도 타지
		#   않습니다. 게임에서 소리가 나는지는 그 경로로만 알 수 있습니다.
		var before := played.size()
		var drop_frames := ceili(
			DROP_TIMEOUT_SECONDS * Engine.physics_ticks_per_second
		)
		for _f in drop_frames:
			if played.size() > before:
				break
			await physics_frame

		_expect(played.size() > before, "%s 에 공이 떨어지면 소리가 난다" % kind)
		_expect(binder.get_bound_source_counts()[&"balls"] > 0,
			"늦게 생긴 공도 배선된다")

		# 파괴·리스폰 예고까지 다 나오도록 조금 더 듣는다.
		for _f in ceili(0.5 * Engine.physics_ticks_per_second):
			await physics_frame

		var heard: Array[StringName] = []
		for i2 in range(before, played.size()):
			heard.append(played[i2])

		print("  %-26s %s" % [kind, ", ".join(heard)])

		# ★ 태엽 대포만 예외입니다. 공을 튕기지 않고 **물어서** 조준 모드로
		#   들어가므로 `response_resolved` 가 오지 않습니다. 이 범퍼가 내는
		#   "무엇을 맞혔는가" 신호는 재질음이 아니라 철컥(조작음)입니다.
		var expected: SfxCue = (
			binder.bumper_rules.cannon_control_cue
			if kind == &"stage01_clockwork_cannon"
			else binder.bumper_rules.get_material_cue(kind)
		)

		if expected != null:
			_expect(expected.cue_id in heard, "%s 를 알리는 소리가 난다" % kind)
			_first_cue[kind] = expected.cue_id

		# ★ 파괴음이 재질음보다 먼저 나면 "부서지고 나서 때린" 소리가 됩니다.
		var destroy := binder.bumper_rules.destroy_cue
		if expected != null and destroy != null \
				and destroy.cue_id in heard and expected.cue_id in heard:
			_expect(heard.find(expected.cue_id) < heard.find(destroy.cue_id),
				"%s 는 때린 뒤에 부서진다" % kind)

		if kind == &"stage01_clockwork_cannon":
			await _check_cannon(bumper, binder, played)

		scene.select_next()
		await physics_frame

	for kind in EXPECTED_KINDS:
		_expect(kind in seen, "%s 가 씬에 배치돼 있다" % kind)

	# ★ 재질음은 "무엇을 맞혔는가"를 소리로 알려주는 것이라 서로 달라야 합니다.
	#   같은 큐가 두 종에서 나오면 눈으로 봐야 알게 됩니다.
	var ids := {}
	for kind in _first_cue:
		ids[_first_cue[kind]] = true

	_expect(ids.size() == _first_cue.size(),
		"재질 %d종이 서로 다른 큐를 낸다 (실제 %d종)" % [_first_cue.size(), ids.size()])
	for kind in _first_cue:
		print("  %-26s → %s" % [kind, _first_cue[kind]])

	print("PASS: 범퍼 검수 씬" if not _failed else "FAIL: 범퍼 검수 씬")
	quit(1 if _failed else 0)


## ★ 태엽 대포는 공을 물고 나서가 본론입니다.
##
##   방향을 옮길 때마다 태엽이 맞물려야 하고, 놓을 때 대포가 울려야 합니다.
##   조준음이 없으면 방향이 바뀌었는지 화면을 봐야만 알 수 있습니다.
func _check_cannon(bumper: Node, binder: WaveSfxBinder, played: Array) -> void:
	var aim := binder.bumper_rules.cannon_aim_cue
	var fire := binder.bumper_rules.cannon_fire_cue

	# ★ null 이면 조용히 건너뛰어 통과처럼 보입니다. 존재부터 못 박습니다.
	if not _expect(aim != null, "조준음 큐가 규칙에 있다"):
		return
	if not _expect(fire != null, "발사음 큐가 규칙에 있다"):
		return

	var before := played.size()
	bumper.select_relative_launch_anchor(1)
	await physics_frame

	_expect(aim.cue_id in played.slice(before), "방향을 옮기면 태엽이 맞물린다")

	before = played.size()
	bumper.release_controlled_ball()
	for _f in 10:
		await physics_frame

	_expect(fire.cue_id in played.slice(before), "발사하면 대포가 울린다")


## 슬롯에 지금 서 있는 범퍼입니다. 리그가 한 번에 하나만 세웁니다.
func _live_bumper(scene: Node) -> Node:
	for node in get_nodes_in_group(&"bumper_objects"):
		if scene.is_ancestor_of(node):
			return node

	return null


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failed = true
		print("  실패 — %s" % label)

	return condition
