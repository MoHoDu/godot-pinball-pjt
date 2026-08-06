extends SceneTree
## 범퍼 VFX 육안 검수용 캡처. **테스트가 아니라 진단 도구다.**
##
## VFX 는 수치를 눈으로 봐야 판단이 된다. 헤드리스 테스트는 "생성됐다" 까지만
## 확인해 준다. 이 스크립트는 5종을 한 화면에 놓고 연출을 강제로 띄운 뒤
## 시간대별로 뷰포트를 캡처한다.
##
## **--headless 로 돌리면 안 된다.** 헤드리스에는 렌더러가 없어 캡처가 비어 나온다.
##
## 실행:
##   godot --path . --script res://tests/bumper_system/bumper_vfx_capture_diagnostic.gd
##
## 결과: tests/evidence/bumper_vfx/frame_*.png


const OUT_DIR := "res://tests/evidence/bumper_vfx"
const BACKGROUND := Color(0.078, 0.106, 0.149, 1.0)

const CASES := [
	["res://scenes/bumper_system/vfx/button_bumper_vfx.tscn", "button", Vector2(180.0, 200.0)],
	["res://scenes/bumper_system/vfx/cotton_bumper_vfx.tscn", "cotton", Vector2(420.0, 200.0)],
	["res://scenes/bumper_system/vfx/spring_doll_bumper_vfx.tscn", "spring", Vector2(660.0, 200.0)],
	["res://scenes/bumper_system/vfx/toy_drum_bumper_vfx.tscn", "drum", Vector2(900.0, 200.0)],
	["res://scenes/bumper_system/vfx/clockwork_toy_cannon_vfx.tscn", "cannon", Vector2(540.0, 460.0)],
]

## 캡처 시점(초). 파동과 조각이 퍼지는 중간을 잡는다.
const CAPTURE_TIMES := [0.05, 0.13, 0.30]


var _bumpers: Array[Bumper] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var stage := Node2D.new()
	root.add_child(stage)

	for case: Array in CASES:
		var packed := load(String(case[0])) as PackedScene
		if packed == null:
			push_error("씬을 못 열었다: %s" % case[0])
			continue
		var bumper := packed.instantiate() as Bumper
		bumper.position = case[2]
		stage.add_child(bumper)
		_bumpers.append(bumper)

	await process_frame
	await process_frame

	_fire_effects()

	var elapsed := 0.0
	for index in CAPTURE_TIMES.size():
		var target := float(CAPTURE_TIMES[index])
		while elapsed < target:
			elapsed += await _step()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "%s/frame_%d_%dms.png" % [OUT_DIR, index, int(target * 1000.0)]
		image.save_png(ProjectSettings.globalize_path(path))
		print("저장: %s" % path)

	print("DONE: bumper_vfx_capture")
	quit(0)


func _step() -> float:
	await process_frame
	return root.get_process_delta_time()


## 시그널을 기다리지 않고 연출을 직접 띄운다. 물리 낙하를 재현할 필요가 없다.
func _fire_effects() -> void:
	for bumper in _bumpers:
		var feedback := bumper.get_node_or_null(^"_HitFeedback")
		if feedback == null:
			continue

		# 공이 위에서 떨어져 맞은 상황을 가정한다.
		var ball_position: Vector2 = bumper.global_position + Vector2(0.0, -140.0)

		if feedback is BumperShotFeedback:
			var shot := feedback as BumperShotFeedback
			shot._on_control_started(bumper as ShotBumper, null)
			shot.spawn_launch()
		elif feedback is BumperBounceFeedback:
			var bounce := feedback as BumperBounceFeedback
			bounce.spawn_hit(ball_position)
			bounce.spawn_bounce(ball_position, Vector2(0.0, -520.0))
		else:
			var normal := feedback as BumperHitFeedback
			normal.spawn_hit(ball_position)
			normal.spawn_thread_snap()
