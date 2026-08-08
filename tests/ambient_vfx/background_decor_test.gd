extends SceneTree
## 배경 데코 애니메이션(별 반짝임·구름 숨쉬기) 헤드리스 검증입니다.
##
## 확인하는 것:
## 1. 연구실 씬이 원본 wave.tscn 구조를 그대로 유지하는가
## 2. 데코가 배경의 변환(위치·스케일·modulate)을 정확히 복제하는가
## 3. 별 알파가 맥동하고, 구름 스케일이 1.0 밑으로 절대 안 내려가는가
## 4. 구름 위의 별이 구름의 자식으로 실려 있는가


const LAB_SCENE := "res://scenes/tests/ambient/ambient_lab.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(LAB_SCENE) as PackedScene
	_expect(packed != null and packed.can_instantiate(),
		"앰비언트 연구실 씬이 로드·인스턴스돼야 한다.")
	if packed == null or not packed.can_instantiate():
		_finish()
		return

	var lab := packed.instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame

	_test_scene_copy_is_intact(lab)

	var decor := lab.get_node_or_null(^"_BackgroundDecor") as BackgroundDecorAnimator
	_expect(decor != null, "연구실 씬에 _BackgroundDecor 노드가 있어야 한다.")
	if decor == null:
		lab.queue_free()
		await process_frame
		_finish()
		return

	_test_transform_replication(lab, decor)
	_test_layout(decor)
	_test_rays(decor)
	await _test_animation(decor)

	lab.queue_free()
	await process_frame
	_finish()


func _test_scene_copy_is_intact(lab: Node) -> void:
	var outside := lab.get_node_or_null(^"OutsideBackground") as Sprite2D
	var board := lab.get_node_or_null(^"BoardBackground") as Sprite2D
	_expect(outside != null and outside.z_index == -20,
		"복제 씬의 외경 배경(z -20)이 원본 그대로여야 한다.")
	_expect(board != null and board.z_index == -10,
		"복제 씬의 보드 배경(z -10)이 원본 그대로여야 한다.")
	_expect(lab.get_node_or_null(^"_BackgroundGears") == null,
		"취소된 기어 노드는 남아 있으면 안 된다.")

	# 검수 전에는 "원본 wave.tscn 에 데코가 없어야 한다" 였으나,
	# 통합 브랜치에서 형락님 승인으로 데코를 본 씬에 적용했다(2026-08-08).
	# 이제는 반대로 — 본 씬에 데코가 규칙 리소스와 함께 배선돼 있어야 한다.
	var wave_source := FileAccess.get_file_as_string("res://Resources/Prefabs/wave/base/wave.tscn")
	_expect(wave_source.contains("background_decor_animator.gd"),
		"wave.tscn 에 데코 노드가 배선돼 있어야 한다.")
	_expect(wave_source.contains("AmbientDecorRules.tres"),
		"wave.tscn 데코에 규칙 리소스가 물려 있어야 한다.")


func _test_transform_replication(lab: Node, decor: BackgroundDecorAnimator) -> void:
	var background := lab.get_node(^"OutsideBackground") as Sprite2D
	_expect(decor.global_position == background.global_position,
		"데코는 배경과 같은 위치여야 패치가 원본과 겹친다.")
	_expect(decor.scale == background.scale,
		"데코는 배경과 같은 스케일이어야 한다.")
	_expect(decor.modulate == background.modulate,
		"데코는 배경과 같은 modulate 여야 색이 이질감 없이 섞인다.")
	_expect(decor.z_index == BackgroundDecorAnimator.Z_INDEX_DECOR,
		"데코는 z -19 — 배경(-20) 바로 위, 보드(-10) 아래여야 한다.")
	_expect(decor.top_level and not decor.z_as_relative,
		"데코는 top_level + 절대 z 로 분리돼야 한다.")


func _test_layout(decor: BackgroundDecorAnimator) -> void:
	var rules := decor.decor_rules
	_expect(rules != null, "기본 Rules 리소스가 물려 있어야 한다.")
	if rules == null:
		return

	_expect(decor.get_star_count() == rules.star_positions.size(),
		"별 수는 Rules 배치 수를 따라야 한다.")

	if rules.clouds_enabled:
		_expect(decor.get_cloud_count() == rules.cloud_origins.size(),
			"구름 수는 Rules 배치 수를 따라야 한다.")
		# 구름 사각형 안 별(예: 8번째, 205,775 는 BL 구름 안)은 구름의 자식이어야 한다.
		var hosted := decor.get_star(7)
		_expect(hosted != null and hosted.get_parent() == decor.get_cloud(2),
			"구름 위의 별은 구름의 자식으로 실려 숨쉬기에 같이 움직여야 한다.")
	else:
		_expect(decor.get_cloud_count() == 0,
			"구름 숨쉬기가 꺼져 있으면 구름 스프라이트가 없어야 한다.")
		var grounded := decor.get_star(7)
		_expect(grounded != null and grounded.get_parent() == decor,
			"구름이 꺼지면 모든 별은 데코 루트의 자식이어야 한다.")

	# 자유 별(예: 3번째, 495,66 은 어떤 구름 사각형에도 안 들어간다)
	var free_star := decor.get_star(2)
	_expect(free_star != null and free_star.get_parent() == decor,
		"구름 밖의 별은 데코 루트의 자식이어야 한다.")


func _test_rays(decor: BackgroundDecorAnimator) -> void:
	var rules := decor.decor_rules
	var rays := decor.get_rays()
	if not rules.rays_enabled:
		_expect(rays == null, "광선이 꺼져 있으면 쿼드가 없어야 한다.")
		return

	_expect(rays != null, "회전 광선 쿼드가 생성돼야 한다.")
	if rays == null:
		return

	var material := rays.material as ShaderMaterial
	_expect(
		(
			material != null
			and material.shader != null
			and material.shader.resource_path
				== "res://Resources/shaders/background_rays.gdshader"
		),
		"광선 쿼드에 배경 광선 셰이더가 물려 있어야 한다."
	)
	_expect(rules.ray_max_alpha <= 0.4,
		"광선 밝기는 0.4 이하 — 배경이 게임보다 눈에 띄면 FAIL.")
	_expect(decor.get_child(0) == rays,
		"광선은 맨 밑에 그려져야 별·구름을 가리지 않는다.")


func _test_animation(decor: BackgroundDecorAnimator) -> void:
	var rules := decor.decor_rules
	var alpha_before: Array[float] = []
	var rotation_before: Array[float] = []
	for i in decor.get_star_count():
		alpha_before.append(decor.get_star_glint(i).self_modulate.a)
		rotation_before.append(decor.get_star(i).rotation)

	for _frame in 30:
		await process_frame

	var changed := 0
	for i in decor.get_star_count():
		var glint := decor.get_star_glint(i)
		_expect(glint.get_parent() == decor.get_star(i),
			"글린트는 회전 본체의 자식이어야 같이 돈다.")
		var alpha := glint.self_modulate.a
		_expect(alpha >= 0.0 and alpha <= rules.star_max_alpha + 0.001,
			"별 알파는 0~최대 알파 범위 안이어야 한다.")
		if absf(alpha - alpha_before[i]) > 0.001:
			changed += 1

		var cover := decor.get_star_cover(i)
		_expect(cover != null and cover.position == decor.get_star(i).position,
			"지움 패치는 본체와 같은 자리에서 원본 별을 덮어야 한다.")
		_expect(is_zero_approx(cover.rotation),
			"지움 패치는 회전하면 안 된다 — 배경과 픽셀 단위로 겹쳐야 한다.")

		var spun := decor.get_star(i).rotation - rotation_before[i]
		if rules.star_spin_enabled:
			_expect(absf(spun) > 0.0001,
				"%d번 별이 천천히 회전해야 한다." % i)
			_expect(absf(spun) < 0.3,
				"%d번 별의 회전은 '천천히'여야 한다 — 반 초에 0.3rad 미만." % i)
			var expected_sign := 1.0 if i % 2 == 0 else -1.0
			_expect(signf(spun) == expected_sign,
				"%d번 별의 회전 방향은 번호별로 엇갈려야 한다." % i)
	_expect(changed > 0, "반 초가 지나면 적어도 별 몇 개는 알파가 변해야 한다.")

	for i in decor.get_cloud_count():
		var cloud_scale: float = decor.get_cloud(i).scale.x
		_expect(cloud_scale >= 1.0 - 0.0001,
			"구름 스케일은 절대 1.0 밑으로 안 내려간다 — 원본을 늘 덮어야 고스트가 없다.")
		_expect(cloud_scale <= 1.0 + rules.cloud_scale_amp + 0.0001,
			"구름 스케일은 숨쉬기 진폭 안이어야 한다.")

	# 켜져 있는 요소는 시간이 지나면 실제로 움직인다
	if decor.get_cloud_count() > 0 or decor.get_rays() != null:
		var scale_before := 0.0
		if decor.get_cloud_count() > 0:
			scale_before = decor.get_cloud(0).scale.x
		var ray_phase_before := decor.get_ray_phase()
		for _frame in 30:
			await process_frame
		if decor.get_cloud_count() > 0:
			_expect(absf(decor.get_cloud(0).scale.x - scale_before) > 0.000001,
				"구름 숨쉬기가 시간에 따라 진행돼야 한다.")
		if decor.get_rays() != null:
			_expect(decor.get_ray_phase() != ray_phase_before,
				"광선 위상이 시간에 따라 전진해야 한다.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: background_decor_test")
		quit(0)
		return
	print("FAIL: background_decor_test (%d failures)" % _failures.size())
	quit(1)
