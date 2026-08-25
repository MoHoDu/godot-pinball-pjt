extends SceneTree
## 공 바운스 스파크(BallHitSpark) 테스트.
##
## 1) 특수 공 5종 씬에 _HitSpark 노드와 공별 스파크 프리셋이 연결됐는지
## 2) 속도 변화량(Δv) 감지 — 발사는 무시하고, 급격한 방향 전환에만 터지는지
## 3) 스파크가 수명이 다하면 소멸하는지
## 4) spawn_burst 직접 호출 시 규칙 수치대로 요소가 생성되는지


const EPSILON := 0.001

const SPARK_CASES: Array[Dictionary] = [
	{
		&"name": &"clockwork_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn",
		&"spark_rules_path": "res://settings/balls/spark/BallHitSparkRules_Clockwork.tres",
		&"chip_shape": BallHitSparkRules.ChipShape.GEAR,
	},
	{
		&"name": &"rubber_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn",
		&"spark_rules_path": "res://settings/balls/spark/BallHitSparkRules_Rubber.tres",
		&"chip_shape": BallHitSparkRules.ChipShape.DROP,
	},
	{
		&"name": &"gel_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn",
		&"spark_rules_path": "res://settings/balls/spark/BallHitSparkRules_Gel.tres",
		&"chip_shape": BallHitSparkRules.ChipShape.BUBBLE,
	},
	{
		&"name": &"lead_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/lead_ball.tscn",
		&"spark_rules_path": "res://settings/balls/spark/BallHitSparkRules_Lead.tres",
		&"chip_shape": BallHitSparkRules.ChipShape.FLAKE,
	},
	{
		&"name": &"hollow_bell_ball",
		&"scene_path": "res://Resources/Prefabs/balls/variants/reward/hollow_bell_ball.tscn",
		&"spark_rules_path": "res://settings/balls/spark/BallHitSparkRules_HollowBell.tres",
		&"chip_shape": BallHitSparkRules.ChipShape.RING,
		&"chip_shape_secondary": BallHitSparkRules.ChipShape.STAR,
	},
]


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_special_balls_have_spark_presets()
	await _test_bounce_detection_and_expiry()
	await _test_spawn_burst_matches_rules()
	_finish()


func _test_special_balls_have_spark_presets() -> void:
	for spark_case: Dictionary in SPARK_CASES:
		var ball_name := StringName(spark_case[&"name"])
		var packed_scene := load(String(spark_case[&"scene_path"])) as PackedScene
		_expect(packed_scene != null, "%s 씬을 불러올 수 있어야 한다." % ball_name)
		if packed_scene == null:
			continue

		var ball := packed_scene.instantiate() as Pinball
		root.add_child(ball)
		await process_frame

		var spark := ball.get_node_or_null("_HitSpark") as BallHitSpark
		_expect(spark != null, "%s는 _HitSpark 노드가 있어야 한다." % ball_name)
		if spark != null:
			var expected_path := String(spark_case[&"spark_rules_path"])
			_expect(spark.spark_rules != null \
				and spark.spark_rules.resource_path == expected_path, \
				"%s 스파크는 공별 프리셋(%s)을 써야 한다. (actual=%s)" % [
					ball_name,
					expected_path,
					spark.spark_rules.resource_path \
						if spark.spark_rules != null else "null",
				])
			if spark.spark_rules != null:
				var expected_shape: int = spark_case[&"chip_shape"]
				_expect(spark.spark_rules.chip_shape == expected_shape, \
					"%s 조각 모양은 공 특성에 맞아야 한다. (expected=%d, actual=%d)" % [
						ball_name,
						expected_shape,
						spark.spark_rules.chip_shape,
					])
				if spark_case.has(&"chip_shape_secondary"):
					var expected_secondary: int = spark_case[&"chip_shape_secondary"]
					_expect(
						spark.spark_rules.chip_shape_secondary == expected_secondary,
						"%s 보조 조각 모양이 지정과 달라선 안 된다. (expected=%d, actual=%d)" % [
							ball_name,
							expected_secondary,
							spark.spark_rules.chip_shape_secondary,
						]
					)

		ball.queue_free()
		await process_frame


func _test_bounce_detection_and_expiry() -> void:
	var ball := await _make_gel_ball()
	if ball == null:
		return

	var spark := ball.get_node("_HitSpark") as BallHitSpark

	# 정지 상태에서 발사 — 직전 속력이 없으므로 스파크가 터지면 안 된다.
	ball.launch(Vector2.RIGHT)
	await physics_frame
	await physics_frame
	_expect(spark.live_tick_count() == 0 and spark.live_flash_count() == 0, \
		"정지 상태에서의 발사는 스파크로 오인되면 안 된다.")

	# 달리던 공의 급반전 — 바운스로 감지되어야 한다.
	ball.linear_velocity = -ball.linear_velocity
	await physics_frame
	await physics_frame
	_expect(spark.live_tick_count() > 0, \
		"임계값 이상 속도 변화는 바운스 스파크를 터뜨려야 한다.")
	_expect(spark.live_flash_count() > 0, \
		"바운스 스파크에는 섬광이 포함되어야 한다.")

	# 수명이 지나면 전부 소멸해야 한다.
	await create_timer(0.6).timeout
	_expect(
		spark.live_tick_count() == 0
		and spark.live_chip_count() == 0
		and spark.live_flash_count() == 0,
		"수명이 지난 스파크는 전부 소멸해야 한다."
	)

	ball.queue_free()
	await process_frame


func _test_spawn_burst_matches_rules() -> void:
	var ball := await _make_gel_ball()
	if ball == null:
		return

	var spark := ball.get_node("_HitSpark") as BallHitSpark
	var rules := spark.spark_rules

	spark.spawn_burst(Vector2(rules.reference_delta_v, 0.0))
	_expect(spark.live_tick_count() == rules.tick_count, \
		"타격선은 규칙의 tick_count만큼 생성되어야 한다. (expected=%d, actual=%d)"
		% [rules.tick_count, spark.live_tick_count()])
	_expect(spark.live_chip_count() == rules.chip_count, \
		"조각은 규칙의 chip_count만큼 생성되어야 한다. (expected=%d, actual=%d)"
		% [rules.chip_count, spark.live_chip_count()])
	_expect(spark.live_flash_count() == 1, \
		"섬광은 바운스당 1개여야 한다. (actual=%d)" % spark.live_flash_count())

	ball.queue_free()
	await process_frame


func _make_gel_ball() -> Pinball:
	var packed_scene := load(String(SPARK_CASES[2][&"scene_path"])) as PackedScene
	_expect(packed_scene != null, "완충 젤 씬을 불러올 수 있어야 한다.")
	if packed_scene == null:
		return null

	var ball := packed_scene.instantiate() as Pinball
	root.add_child(ball)
	await physics_frame
	# 중력 가속이 Δv 검사에 섞이지 않게 끕니다.
	ball.stats = ball.stats.duplicate(true) as PinballStats
	ball.stats.gravity_scale = 0.0
	await physics_frame
	return ball


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error(message)


func _finish() -> void:
	await process_frame
	if _failures.is_empty():
		print("PASS: ball_hit_spark_test")
		quit(0)
		return

	print("FAIL: ball_hit_spark_test (%d failures)" % _failures.size())
	quit(1)
