extends SceneTree

## WaveSfxBinder 의 배선을 검증합니다.
##
## ★ 이 테스트가 존재하는 이유:
##   과거에 `current_scene` 으로 대상을 찾는 코드가 있었는데, 씬을 코드로
##   인스턴스화하면 그 값이 null 이라 **아무것도 못 찾고 에러 없이 통과**했습니다.
##   소리가 안 나는데 원인을 알 수 없었습니다.
##
##   이 테스트는 정확히 그 조건(코드 인스턴스화 = current_scene 이 null)에서
##   배선이 되는지 봅니다. 옛 방식이면 여기서 0을 찾고 실패합니다.

const SCENE_PATH := "res://scenes/wave/wave_sfx.tscn"
const WALL_RULES_PATH := "res://settings/sfx/WallSfxRules.tres"
const FLIPPER_RULES_PATH := "res://settings/sfx/FlipperSfxRules.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_rules_resources()
	await _test_scene_wiring()
	await _test_sound_test_scene()
	await _test_sfx_lab_scene()
	await _test_main_scene_wiring()
	_finish()


## ★ 사운드 연구실이 실제로 조작 가능한 상태인가
##
## 과거 실패: `.tscn` 에 `node_paths=PackedStringArray("ball_path", "director_path")` 를
## 적었는데, 그건 **Node 타입 익스포트**용이다. NodePath 타입에 쓰면 로더가 노드 참조로
## 바꾸려다 실패하고 **빈 값을 남긴다**. 에러도 경고도 없다.
## 그 결과 공도 디렉터도 못 찾아 **모든 키가 먹통**이었다.
func _test_sfx_lab_scene() -> void:
	var packed := load("res://scenes/test_sfx/sfx_lab.tscn") as PackedScene
	_expect(packed != null, "사운드 연구실 씬을 불러올 수 있어야 한다.")

	if packed == null:
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	# ★ NodePath 익스포트가 비어 있지 않은가 — 이게 비면 모든 키가 안 먹는다
	_expect(not (scene.ball_path as NodePath).is_empty(),
		"연구실의 ball_path 가 비어 있다. 공을 못 찾으면 발사·리셋·중력이 전부 안 된다.")
	_expect(not (scene.director_path as NodePath).is_empty(),
		"연구실의 director_path 가 비어 있다. 디렉터를 못 찾으면 1~6 키가 무음이다.")

	_expect(scene.get_node_or_null(scene.ball_path) != null,
		"ball_path 가 실제 노드를 가리켜야 한다.")
	_expect(scene.get_node_or_null(scene.director_path) is SfxDirector,
		"director_path 가 SfxDirector 를 가리켜야 한다.")

	_expect(scene.wall_rules != null and scene.flipper_rules != null,
		"연구실에 규칙 리소스가 물려 있어야 한다.")

	var flippers := 0
	for node in get_nodes_in_group(&"combo_flippers"):
		if _is_descendant(node, scene):
			flippers += 1

	var walls := 0
	for node in get_nodes_in_group(&"combo_walls"):
		if _is_descendant(node, scene):
			walls += 1

	_expect(flippers >= 2, "연구실에 플리퍼가 있어야 타격·패링을 물리로 확인한다. (%d)" % flippers)
	_expect(walls == 4, "연구실은 벽 4개짜리 닫힌 방이어야 한다. (%d)" % walls)

	# 직접 재생 키가 실제로 소리를 내는가 (음원 없으면 여기서 걸린다)
	var director := scene.get_node_or_null(scene.director_path) as SfxDirector
	if director != null and scene.wall_rules != null:
		var result := director.request(
			scene.wall_rules.hit_cue, SfxPlayContext.new(1, 700.0)
		)
		_expect(result.is_played(),
			"연구실에서 벽 충돌음이 재생돼야 한다. (%s)" % result.outcome)

	scene.queue_free()
	await physics_frame


func _is_descendant(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()

	return false


## 공 사운드 테스트 씬이 실제로 소리를 낼 수 있는 상태인가
func _test_sound_test_scene() -> void:
	var packed := load("res://scenes/test_sfx/test_ball_sfx.tscn") as PackedScene
	_expect(packed != null, "공 사운드 테스트 씬을 불러올 수 있어야 한다.")

	if packed == null:
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder
	var bridge := scene.get_node_or_null(^"ComboCollisionBridge")
	var ball := scene.get_node_or_null(^"PinballBall")

	_expect(binder != null, "테스트 씬에 바인더가 있어야 한다.")
	_expect(bridge != null, "브릿지가 없으면 벽·플리퍼 충돌음이 통째로 안 난다.")
	_expect(ball != null, "테스트 씬에 공이 있어야 한다.")

	if binder != null:
		var counts := binder.get_bound_source_counts()
		_expect(int(counts[&"bridges"]) >= 1,
			"테스트 씬에서도 브릿지를 찾아야 한다. (%d)" % int(counts[&"bridges"]))
		_expect(int(counts[&"flippers"]) >= 8,
			"테스트 씬 플리퍼 8개를 전부 찾아야 한다. (%d)" % int(counts[&"flippers"]))
		_expect(binder.get_director() != null, "테스트 씬 디렉터를 찾아야 한다.")

	# 원본 test_flipper_board.tscn 은 그대로여야 한다
	var original := (load("res://scenes/test_flipper/test_flipper_board.tscn") as PackedScene).instantiate()
	_expect(original.get_node_or_null(^"SfxDirector") == null,
		"원본 test_flipper_board.tscn 은 그대로여야 한다 (씬 복제 규칙).")
	original.free()

	scene.queue_free()
	await physics_frame


func _test_rules_resources() -> void:
	var wall := load(WALL_RULES_PATH) as WallSfxRules
	_expect(wall != null, "WallSfxRules.tres 를 불러올 수 있어야 한다.")

	if wall != null and wall.hit_cue != null:
		_expect(wall.hit_cue.selection_mode == SfxCue.SelectionMode.SPEED_TIER,
			"벽 충돌 3종은 속도 구간별이어야 한다. 랜덤이면 느린 충돌에 고속 음색이 난다.")
		_expect(wall.hit_cue.priority == SfxPriority.WALL,
			"벽 충돌은 WALL 우선순위여야 한다.")
		_expect(is_equal_approx(wall.hit_cue.minimum_repeat_interval, 0.04),
			"기획서 p.62 간격 0.04초.")
		_expect(is_equal_approx(wall.hit_cue.repeat_attenuation_db, -3.0),
			"기획서 p.62 연타 -3dB.")
		_expect(is_equal_approx(wall.hit_cue.pitch_jitter, 0.05),
			"기획서 p.62 피치 ±5%%.")
		_expect(wall.hit_cue.maximum_concurrent <= 4,
			"기획서 p.62 최대 동시 재생 4개.")

	var flipper := load(FLIPPER_RULES_PATH) as FlipperSfxRules
	_expect(flipper != null, "FlipperSfxRules.tres 를 불러올 수 있어야 한다.")

	if flipper == null:
		return

	_expect(flipper.hit_cue != null, "플리퍼 타격 큐는 필수다 (기획서 MUST).")
	_expect(flipper.select_cue != null and flipper.activate_cue != null,
		"선택음과 작동음이 둘 다 있어야 한다.")
	_expect(flipper.select_cue.cue_id != flipper.activate_cue.cue_id,
		"선택음과 작동음은 분명히 달라야 한다 (p.20, p.5 검수).")
	_expect(flipper.parry_perfect_cue != null
			and flipper.parry_perfect_cue.priority == SfxPriority.PARRY,
		"정확한 패링은 PARRY 우선순위여야 한다.")

	# 타격보다 패링이 우선순위가 높아야 한다
	_expect(flipper.parry_perfect_cue.priority > flipper.hit_cue.priority,
		"패링이 플리퍼 타격보다 우선해야 한다 (기획서 우선순위).")

	# 속도로 일반/강한 타격이 갈리는가
	var normal := flipper.get_hit_cue(flipper.strong_hit_speed_threshold - 100.0)
	var strong := flipper.get_hit_cue(flipper.strong_hit_speed_threshold + 100.0)
	_expect(normal != strong, "속도 임계값을 넘으면 강한 타격으로 갈려야 한다.")


## ★ 핵심 회귀 — 코드 인스턴스화 상태에서 배선되는가
func _test_scene_wiring() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(packed != null, "wave_sfx.tscn 을 불러올 수 있어야 한다.")

	if packed == null:
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame

	# 이 경로에서는 current_scene 이 이 씬이 아니다.
	_expect(current_scene != scene,
		"이 테스트는 current_scene 이 아닌 상태를 재현해야 의미가 있다.")

	var director := scene.get_node_or_null(^"SfxDirector") as SfxDirector
	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder

	_expect(director != null, "호환 씬에 SfxDirector 가 있어야 한다.")
	_expect(binder != null, "호환 씬에 _WaveSfxBinder 가 있어야 한다.")

	if binder == null:
		scene.queue_free()
		return

	_expect(binder.get_director() == director,
		"바인더가 형제 SfxDirector 를 찾아야 한다.")

	var counts := binder.get_bound_source_counts()
	_expect(int(counts[&"bridges"]) >= 1,
		"★ ComboCollisionBridge 를 찾아야 한다. 못 찾으면 벽·플리퍼 충돌음이 통째로 안 난다. (%d)"
			% int(counts[&"bridges"]))
	_expect(int(counts[&"flippers"]) >= 8,
		"★ 플리퍼 8개(4그룹×좌우)를 전부 찾아야 한다. (%d)" % int(counts[&"flippers"]))

	# ★ "승인된 것만 씬에 물린다"는 정책은 그대로다. 승인 목록만 바뀐다.
	#   2026-08-07 현재 플리퍼 5종 · 벽 3종 · 공 흐름 3종 · 범퍼 8종이 통과했다.
	#   콤보·웨이브만 아직 만들지 않아 규칙이 settings/sfx/_pending/ 에 있다.
	_expect(binder.wall_rules != null and binder.flipper_rules != null
			and binder.ball_flow_rules != null and binder.bumper_rules != null,
		"승인된 벽·플리퍼·흐름·범퍼 규칙이 씬에 물려 있어야 한다.")
	_expect(binder.combo_rules == null,
		"아직 만들지 않은 콤보 규칙이 물려 있으면 안 된다.")

	# ★ FlipperSelector 에는 시그널이 없어 폴링으로 붙는다.
	#   못 찾으면 선택음이 통째로 안 나고, 검수 항목
	#   "선택음·작동음·패링 성공음이 서로 다른가"(p.5)를 볼 수 없다.
	_expect(binder.has_selector(),
		"FlipperSelector 를 찾아야 선택음이 난다.")

	# 목소리 풀이 실제로 만들어졌는지
	if director != null:
		_expect(director.get_active_voice_count() == 0,
			"시작 시점에는 울리는 목소리가 없어야 한다.")

	scene.queue_free()
	await physics_frame


## 승인된 SFX가 실제 메인 웨이브에 병합되었는지
func _test_main_scene_wiring() -> void:
	var original := load("res://scenes/wave/wave.tscn") as PackedScene
	_expect(original != null, "메인 wave.tscn 을 불러올 수 있어야 한다.")

	if original == null:
		return

	var scene := original.instantiate()
	var director := scene.get_node_or_null(^"SfxDirector") as SfxDirector
	var binder := scene.get_node_or_null(^"_WaveSfxBinder") as WaveSfxBinder
	_expect(director != null,
		"메인 wave.tscn 에 승인된 SfxDirector가 있어야 한다.")
	_expect(binder is WaveSfxBinderStrict,
		"메인 wave.tscn 은 인자 수를 검증하는 엄격한 바인더를 사용해야 한다.")
	_expect(binder != null and binder.wall_rules != null \
		and binder.flipper_rules != null,
		"메인 wave.tscn 에 승인된 벽·플리퍼 규칙이 연결되어야 한다.")
	scene.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: wave_sfx_binder_test")
		quit(0)
		return

	print("FAIL: wave_sfx_binder_test (%d failures)" % _failures.size())
	quit(1)
