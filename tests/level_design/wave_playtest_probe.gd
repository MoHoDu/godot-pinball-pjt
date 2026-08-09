extends SceneTree
## 웨이브 4종 헤드리스 플레이 프로브 (레벨 디자인 검증용, 2026-08-09)
##
## 발사구 3종 속도 + 플리퍼 4방향 x 5각도 부채꼴 샷을 실제 물리로 굴려
## 범퍼별 유효 타격 분포 / 드레인율 / 평균 랠리 시간 / 무접촉률을 측정한다.
## 실패 판정이 아니라 계측 리포트를 JSON으로 출력한다.

const WAVES := {
	"wave_01": "res://scenes/game/stages/stage_01/waves/stage_01_wave_01.tscn",
	"wave_02": "res://scenes/game/stages/stage_01/waves/stage_01_wave_02.tscn",
	"wave_03": "res://scenes/game/stages/stage_01/waves/stage_01_wave_03.tscn",
	"boss": "res://scenes/game/stages/stage_01/boss/stage1_teddy_boss_wave.tscn",
}
const BALL_SCENE := "res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"
const TRIAL_TICKS := 720
const DRAIN_X := 1280.0
const DRAIN_Y := 800.0

var _hits: Dictionary = {}
var _report: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var filter := OS.get_environment("PROBE_WAVES")
	for wave_id: String in WAVES:
		if not filter.is_empty() and not filter.contains(wave_id):
			continue
		await _probe_wave(wave_id, WAVES[wave_id])
	print("PROBE_REPORT_BEGIN")
	print(JSON.stringify(_report, "  "))
	print("PROBE_REPORT_END")
	quit(0)


func _probe_wave(wave_id: String, path: String) -> void:
	var wave := (load(path) as PackedScene).instantiate()
	root.add_child(wave)
	await physics_frame
	await physics_frame
	var drain_area := wave.get_node("BallDrainArea") as Area2D
	drain_area.monitoring = false
	_hits.clear()
	for bumper: Node in wave.call(&"get_bumpers"):
		(bumper as Bumper).valid_hit_registered.connect(
			_on_hit.bind(String(bumper.name))
		)
	for child: Node in wave.get_node("Walls").get_children():
		if child is Bumper:
			(child as Bumper).valid_hit_registered.connect(
				_on_hit.bind("Wall/" + String(child.name))
			)
	var trials := _build_trials()
	var drained := 0
	var touched := 0
	var total_hits := 0
	var rally_ticks := 0
	for trial: Dictionary in trials:
		var result := await _run_trial(wave, trial)
		drained += 1 if result.drained else 0
		touched += 1 if result.hits > 0 else 0
		total_hits += int(result.hits)
		rally_ticks += int(result.ticks)
	_report[wave_id] = {
		"trials": trials.size(),
		"drain_rate": snappedf(float(drained) / trials.size(), 0.01),
		"touch_rate": snappedf(float(touched) / trials.size(), 0.01),
		"avg_hits_per_ball": snappedf(float(total_hits) / trials.size(), 0.01),
		"avg_rally_seconds": snappedf(
			float(rally_ticks) / trials.size() / 120.0, 0.01
		),
		"hits_by_bumper": _hits.duplicate(),
	}
	wave.free()
	await process_frame


func _build_trials() -> Array[Dictionary]:
	var trials: Array[Dictionary] = []
	for speed: float in [700.0, 940.0, 1300.0]:
		trials.append({"pos": Vector2(0.0, 340.0), "vel": Vector2(0.0, -speed)})
	var mouths := [
		{"pos": Vector2(0.0, 440.0), "dir": Vector2.UP},
		{"pos": Vector2(0.0, -520.0), "dir": Vector2.DOWN},
		{"pos": Vector2(-985.0, 0.0), "dir": Vector2.RIGHT},
		{"pos": Vector2(935.0, 0.0), "dir": Vector2.LEFT},
	]
	for mouth: Dictionary in mouths:
		for angle_deg: float in [-40.0, -20.0, 0.0, 20.0, 40.0]:
			var direction := (mouth.dir as Vector2).rotated(deg_to_rad(angle_deg))
			trials.append({"pos": mouth.pos, "vel": direction * 1100.0})
	return trials


func _run_trial(wave: Node, trial: Dictionary) -> Dictionary:
	var before := _total_hit_count()
	var ball := (load(BALL_SCENE) as PackedScene).instantiate() as RigidBody2D
	wave.add_child(ball)
	ball.global_position = trial.pos
	ball.linear_velocity = trial.vel
	var ticks := 0
	var drained := false
	while ticks < TRIAL_TICKS:
		await physics_frame
		ticks += 1
		if not is_instance_valid(ball):
			break
		var p := ball.global_position
		if absf(p.x) > DRAIN_X or absf(p.y) > DRAIN_Y:
			drained = true
			break
	if is_instance_valid(ball):
		ball.queue_free()
	await physics_frame
	for bumper: Node in wave.call(&"get_bumpers"):
		(bumper as Bumper).reset_for_new_ball()
	await physics_frame
	return {
		"drained": drained,
		"hits": _total_hit_count() - before,
		"ticks": ticks,
	}


func _total_hit_count() -> int:
	var total := 0
	for key: String in _hits:
		total += int(_hits[key])
	return total


func _on_hit(
	_bumper_id: StringName,
	_ball: RigidBody2D,
	_contact_id: int,
	_base_score: int,
	node_name: String
) -> void:
	_hits[node_name] = int(_hits.get(node_name, 0)) + 1
