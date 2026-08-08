extends SceneTree
## 수리 부품 아트·애니메이션 검증.
##
## 확인하는 것:
## - 상속 씬이 열리고 아트 스프라이트와 애니메이터가 붙어 있는가
## - 표시 지름이 설정(88px)과 맞는가
## - 톱니바퀴는 **휠만 돌고 허브는 고정**인가 (11쪽 허브 수축·팽창, 리벳 점등)
## - 단계가 오를수록 회전량이 커지고 3단계는 한 바퀴인가
## - 원본 씬은 그대로인가 (직접 수정 금지)
##
## 실행:
##   godot --headless --path . --script res://tests/repair_parts/repair_part_art_test.gd


const CASES := [
	[
		"res://Resources/Prefabs/repair_parts/presented/starlight_brooch_vfx.tscn",
		"res://Resources/Prefabs/bumpers/types/starlight_brooch_bumper.tscn",
	],
	[
		"res://Resources/Prefabs/repair_parts/presented/forgotten_star_bell_vfx.tscn",
		"res://Resources/Prefabs/bumpers/types/forgotten_star_bell_bumper.tscn",
	],
	[
		"res://Resources/Prefabs/repair_parts/presented/golden_gears_vfx.tscn",
		"res://Resources/Prefabs/bumpers/types/golden_gears_bumper.tscn",
	],
]
const GEARS_SCENE := "res://Resources/Prefabs/repair_parts/presented/golden_gears_vfx.tscn"
const BROOCH_SCENE := "res://Resources/Prefabs/repair_parts/presented/starlight_brooch_vfx.tscn"
const BROOCH_ANIM := preload("res://settings/repair_parts/anim/StarlightBroochAnim.tres")
const EPSILON := 0.001


var _failures: Array[String] = []
var _root: Node2D


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_root = Node2D.new()
	root.add_child(_root)
	await process_frame

	for case: Array in CASES:
		await _check_scene(String(case[0]), String(case[1]))
	await _test_gear_spin()
	await _test_brooch_spin()

	_finish()


func _check_scene(vfx_path: String, origin_path: String) -> void:
	var packed := load(vfx_path) as PackedScene
	_expect(packed != null, "%s 를 열 수 있어야 한다" % vfx_path)
	if packed == null:
		return

	var bumper := packed.instantiate() as Bumper
	_expect(bumper != null, "%s 의 루트가 Bumper 여야 한다" % vfx_path)
	if bumper == null:
		return
	_root.add_child(bumper)
	await process_frame
	await process_frame

	var sprite := bumper.get_node_or_null(^"_ArtSprite") as Sprite2D
	_expect(sprite != null, "%s 에 아트 스프라이트가 있어야 한다" % vfx_path)
	if sprite != null and sprite.texture != null:
		var long_side := float(maxi(
			sprite.texture.get_width(), sprite.texture.get_height()
		))
		var expected: float = bumper.settings.visual_diameter
		_expect(absf(long_side * sprite.scale.x - expected) <= 1.0,
			"%s 표시 지름이 설정과 맞아야 한다 (기대=%s, 실제=%s)"
				% [vfx_path, expected, long_side * sprite.scale.x])

	var visual := bumper.get_node_or_null(^"Visual") as Node2D
	_expect(visual != null and not visual.visible,
		"%s 의 프로시저럴 Visual 은 꺼져 있어야 한다" % vfx_path)

	_expect(bumper.get_node_or_null(^"_ArtAnimator") != null,
		"%s 에 애니메이터가 있어야 한다" % vfx_path)

	# 수리 부품도 범퍼와 같은 피드백 노드를 쓴다 (4-1/4-2/4-4 F 절).
	var feedback := bumper.get_node_or_null(^"_HitFeedback") as BumperHitFeedback
	_expect(feedback != null, "%s 에 타격 피드백이 있어야 한다" % vfx_path)
	if feedback != null:
		_expect(feedback.rules != null, "%s 피드백에 규칙이 꽂혀 있어야 한다" % vfx_path)
		# VFX 는 표시 반지름에 붙는다. 충돌 반지름을 쓰면 아트 밑에 깔린다.
		var visual_radius: float = bumper.settings.visual_diameter * 0.5
		var contact: Vector2 = feedback.contact_point_for(
			bumper.global_position + Vector2.RIGHT * 500.0
		)
		var reach := contact.distance_to(bumper.global_position)
		_expect(absf(reach - visual_radius) <= 1.0,
			"%s 접촉 지점이 표시 원 위여야 한다 (기대=%s, 실제=%s)"
				% [vfx_path, visual_radius, reach])

	# 원본 씬은 그대로여야 한다.
	var origin_packed := load(origin_path) as PackedScene
	if origin_packed != null:
		var origin := origin_packed.instantiate() as Bumper
		_root.add_child(origin)
		await process_frame
		_expect(origin.get_node_or_null(^"_ArtSprite") == null,
			"원본 씬 %s 에는 아트 스프라이트가 없어야 한다 (직접 수정 금지)" % origin_path)
		origin.queue_free()

	bumper.queue_free()
	await process_frame


func _test_gear_spin() -> void:
	var bumper := (load(GEARS_SCENE) as PackedScene).instantiate() as Bumper
	_root.add_child(bumper)
	await process_frame
	await process_frame

	var gear := bumper.get_node_or_null(^"_ArtAnimator") as BumperGearSpinAnimator
	var wheel := bumper.get_node_or_null(^"_ArtSpriteWheel") as Sprite2D
	var hub := bumper.get_node_or_null(^"_ArtSprite") as Sprite2D
	_expect(gear != null and wheel != null and hub != null,
		"톱니바퀴에 회전 애니메이터와 휠·허브 레이어가 있어야 한다")
	if gear == null or wheel == null or hub == null:
		bumper.queue_free()
		return

	_expect(wheel.z_index < hub.z_index, "허브가 휠 위에 그려져야 한다")
	_expect(wheel.scale.is_equal_approx(hub.scale),
		"두 레이어는 같은 캔버스 정렬이라 scale 이 같아야 한다")

	# 단계를 나누지 않고 매번 한 바퀴씩 돈다 (2026-08-06 지시).
	var stage1 := await _spin_to(gear, wheel, 1, 1.2)
	_expect(absf(stage1 - TAU) <= 0.05,
		"1단계도 한 바퀴여야 한다 (실제=%s)" % stage1)
	_expect(absf(hub.rotation) <= EPSILON,
		"허브는 돌면 안 된다 (11쪽 허브는 수축·팽창, 리벳은 점등) (실제=%s)"
			% hub.rotation)

	var stage2 := await _spin_to(gear, wheel, 2, 1.2)
	_expect(absf((stage2 - stage1) - TAU) <= 0.05,
		"2단계도 같은 각도만큼 돌아야 한다 (실제=%s)" % (stage2 - stage1))

	# 어떤 타격이든 처음에 휙 돌고 끝에서 서서히 멈춰야 한다.
	gear.set_stage(3)
	var first := wheel.rotation
	await _wait(0.10)
	var early := wheel.rotation - first
	await _wait(0.10)
	var mid := wheel.rotation - first - early
	await _wait(1.2)
	var stage3 := wheel.rotation
	_expect(early > mid,
		"회전이 갈수록 느려져야 한다 (앞 0.1s=%s, 뒤 0.1s=%s)" % [early, mid])
	_expect(absf((stage3 - stage2) - TAU) <= 0.05,
		"3단계도 한 바퀴여야 한다 (실제=%s)" % (stage3 - stage2))
	_expect(not gear.is_spinning(), "감속이 끝나면 멈춰 있어야 한다")

	# 런타임이 없는 검수 씬에서는 타격만으로 단계가 올라야 한다.
	var before := wheel.rotation
	bumper.valid_hit_registered.emit(bumper.bumper_id, null, 1, 0)
	await _wait(1.2)
	_expect(absf((wheel.rotation - before) - TAU) <= 0.05,
		"런타임이 없으면 타격만으로 한 바퀴 돌아야 한다 (검수 씬용) (실제=%s)"
			% (wheel.rotation - before))
	var after_hit := wheel.rotation

	# 과회전 직후 0 으로 초기화돼도 되감기지 않아야 한다.
	gear.set_stage(0)
	var settled := await _spin_to(gear, wheel, 0, 0.4)
	_expect(absf(settled - after_hit) <= 0.05,
		"단계 초기화가 휠을 되감으면 안 된다 (실제=%s -> %s)" % [after_hit, settled])

	bumper.queue_free()
	await process_frame


## 4-1 E: 기본 상태에는 상시 회전을 쓰지 않는다. 타격 순간에만 돌고 멈춰야 한다.
func _test_brooch_spin() -> void:
	var bumper := (load(BROOCH_SCENE) as PackedScene).instantiate() as Bumper
	_root.add_child(bumper)
	await process_frame
	await process_frame

	var spin := bumper.get_node_or_null(^"_ArtAnimator") as BumperArtSpinAnimator
	_expect(spin != null, "브로치에 회전 애니메이터가 있어야 한다")
	if spin == null:
		bumper.queue_free()
		return
	var sprite := spin.get_target_sprite()

	# 가만히 두면 돌지 않아야 한다.
	await _wait(0.3)
	_expect(absf(sprite.rotation) <= EPSILON,
		"기본 상태에서 상시 회전하면 안 된다 (실제=%s)" % sprite.rotation)

	bumper.valid_hit_registered.emit(bumper.bumper_id, null, 1, 0)
	await _wait(0.10)
	var early := sprite.rotation
	await _wait(0.10)
	var mid := sprite.rotation - early
	await _wait(1.2)

	_expect(early > mid, "회전이 갈수록 느려져야 한다 (앞=%s, 뒤=%s)" % [early, mid])
	_expect(absf(sprite.rotation - BROOCH_ANIM.spin_arc) <= 0.05,
		"타격 한 번에 규칙만큼 돌아야 한다 (기대=%s, 실제=%s)"
			% [BROOCH_ANIM.spin_arc, sprite.rotation])
	_expect(not spin.is_spinning(), "감속이 끝나면 멈춰 있어야 한다")

	# 물리 노드는 그대로여야 한다.
	_expect(absf(bumper.global_rotation) <= EPSILON,
		"아트 회전이 범퍼 본체를 돌리면 안 된다")

	bumper.queue_free()
	await process_frame


func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await process_frame
		waited += root.get_process_delta_time()


func _spin_to(
	gear: BumperGearSpinAnimator,
	wheel: Sprite2D,
	stage: int,
	seconds: float
) -> float:
	gear.set_stage(stage)
	var waited := 0.0
	while waited < seconds:
		await process_frame
		waited += root.get_process_delta_time()
	return wheel.rotation


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: repair_part_art_test")
		quit(0)
		return
	print("FAIL: repair_part_art_test (%d failures)" % _failures.size())
	quit(1)
