extends SceneTree
## 보스 아트 리그 검증.
##
## 확인하는 것:
## - 네 레이어가 모두 붙고 같은 캔버스 크기인가 (정렬의 전제)
## - 팔이 **어깨를 축으로** 도는가 (어깨는 안 움직이고 손끝만 움직여야 한다)
## - 좌우 팔이 **바깥쪽**으로 벌어지는가 (안쪽이면 얼굴을 덮는다)
## - 들어 올린 팔이 몸 **앞**으로 오는가 (뒤면 머리에 가려 실루엣이 사라진다)
## - 대기와 공격의 실루엣이 실제로 다른가 (보스전의 핵심)
## - 하트핵 박동이 눈에 띄지 않을 만큼 작은가 (약점으로 오해받으면 반려)
##
## 실행:
##   godot --headless --path . --script res://tests/boss_system/boss_art_rig_test.gd

const SCENE := "res://scenes/boss_system/boss_art_test.tscn"
const EPSILON := 0.5


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load(SCENE) as PackedScene
	_expect(packed != null, "검수 씬을 열 수 있어야 한다")
	if packed == null:
		_finish()
		return

	var stage := packed.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	var rig := stage.get_node_or_null(^"Rig") as BossArtRig
	_expect(rig != null, "리그 노드가 있어야 한다")
	if rig == null:
		_finish()
		return

	_test_layers(rig)
	_test_pivot(rig)
	_test_outward(rig)
	_test_silhouette(rig)
	await _test_heart(rig)
	await _test_idle_motion(rig)
	_test_expressions(rig)
	await _test_transitions(rig)
	await _test_jolt(rig)

	_finish()


func _test_layers(rig: BossArtRig) -> void:
	var names := [
		^"Sway/Pose/Body", ^"Sway/Pose/Heart",
		^"Sway/Pose/LeftShoulderPivot/ArmVisual", ^"Sway/Pose/RightShoulderPivot/ArmVisual",
	]
	var size := Vector2.ZERO
	for path in names:
		var sprite := rig.get_node_or_null(path) as Sprite2D
		_expect(sprite != null, "%s 레이어가 있어야 한다" % path)
		if sprite == null or sprite.texture == null:
			_expect(false, "%s 에 텍스처가 꽂혀 있어야 한다" % path)
			continue
		var texture_size := sprite.texture.get_size()
		if size == Vector2.ZERO:
			size = texture_size
		# 같은 캔버스여야 정렬이 유지된다. 레이어별로 자르면 팔이 어깨에서 떨어진다.
		_expect(texture_size == size,
			"%s 캔버스가 다른 레이어와 같아야 한다 (기대=%s, 실제=%s)"
				% [path, size, texture_size])


func _test_pivot(rig: BossArtRig) -> void:
	var arm := rig.get_node_or_null(^"Sway/Pose/LeftShoulderPivot/ArmVisual") as Sprite2D
	var pivot := rig.get_node_or_null(^"Sway/Pose/LeftShoulderPivot") as Node2D
	if arm == null or pivot == null:
		return

	var shoulder_before := pivot.global_position
	var tip_before := arm.global_position
	# **팔 각도만** 바꾼다. play_attack 은 몸 자세(뻗음)도 바꿔 어깨가
	# 정당하게 움직이므로 이 검사에는 못 쓴다.
	rig.set_arm_angles(BossArtRig.ATTACK_ANGLE, BossArtRig.ATTACK_ANGLE)
	var shoulder_after := pivot.global_position
	var tip_after := arm.global_position

	# 어깨는 회전 축이라 팔 각도만으로는 움직이면 안 된다.
	_expect(shoulder_before.distance_to(shoulder_after) <= EPSILON,
		"팔 각도만 바꿨을 때 어깨 피벗이 움직이면 안 된다 (%s -> %s)"
			% [shoulder_before, shoulder_after])
	# 팔은 실제로 움직여야 한다.
	_expect(tip_before.distance_to(tip_after) > 20.0,
		"팔을 들면 스프라이트가 실제로 움직여야 한다 (%.1f px)"
			% tip_before.distance_to(tip_after))
	rig.play_idle()


func _test_outward(rig: BossArtRig) -> void:
	var left := rig.get_node_or_null(^"Sway/Pose/LeftShoulderPivot/ArmVisual") as Sprite2D
	var right := rig.get_node_or_null(^"Sway/Pose/RightShoulderPivot/ArmVisual") as Sprite2D
	if left == null or right == null:
		return

	rig.play_idle(true)
	var lx0 := left.global_position.x
	var rx0 := right.global_position.x
	rig.play_attack(true)

	# 화면 좌표는 아래가 +y 다. 부호를 뒤집으면 팔이 안쪽으로 돌아 얼굴을 덮는다.
	_expect(left.global_position.x < lx0,
		"왼팔은 **바깥(왼쪽)** 으로 벌어져야 한다 (%.1f -> %.1f)"
			% [lx0, left.global_position.x])
	_expect(right.global_position.x > rx0,
		"오른팔은 **바깥(오른쪽)** 으로 벌어져야 한다 (%.1f -> %.1f)"
			% [rx0, right.global_position.x])
	rig.play_idle()


func _test_silhouette(rig: BossArtRig) -> void:
	var left := rig.get_node_or_null(^"Sway/Pose/LeftShoulderPivot/ArmVisual") as Sprite2D
	if left == null:
		return

	rig.play_idle(true)
	var rest := left.global_position
	_expect(not rig.is_arm_raised(), "대기 상태에서는 팔이 들린 것으로 치면 안 된다")
	var back_z := (rig.get_node(^"Sway/Pose/LeftShoulderPivot") as Node2D).z_index

	rig.play_attack(true)
	var attack := left.global_position
	_expect(rig.is_arm_raised(), "공격 상태에서는 팔이 들린 것으로 쳐야 한다")
	var front_z := (rig.get_node(^"Sway/Pose/LeftShoulderPivot") as Node2D).z_index

	# 기획서·가이드가 요구하는 핵심: 실루엣 자체가 완전히 바뀌어야 한다.
	_expect(rest.distance_to(attack) > 100.0,
		"대기와 공격의 실루엣이 크게 달라야 한다 (실제 %.1f px)"
			% rest.distance_to(attack))
	# 들어 올린 팔은 몸 앞. 뒤에 두면 머리에 가려 사라진다.
	_expect(front_z > back_z,
		"들어 올린 팔은 몸 앞으로 와야 한다 (대기 z=%d, 공격 z=%d)"
			% [back_z, front_z])

	# 진행도 보간이 예고와 공격 사이를 채우는가.
	rig.set_attack_progress(0.5)
	var mid: float = rig.get_arm_angles().x
	_expect(
		BossArtRig.TELEGRAPH_ANGLE < mid and mid < BossArtRig.ATTACK_ANGLE,
		"진행도 0.5 는 예고와 공격 사이여야 한다 (실제 %.1f)" % mid
	)
	rig.play_idle(true)


func _test_heart(rig: BossArtRig) -> void:
	var heart := rig.get_node_or_null(^"Sway/Pose/Heart") as Sprite2D
	if heart == null:
		return
	var lo := heart.scale.x
	var hi := lo
	var waited := 0.0
	while waited < 1.6:
		await process_frame
		waited += root.get_process_delta_time()
		lo = minf(lo, heart.scale.x)
		hi = maxf(hi, heart.scale.x)

	_expect(hi > lo, "하트핵이 박동해야 한다")
	# 크게 뛰면 약점 아이콘처럼 보인다. 기획서 1-2 가 약점이 아니라고 못박았다.
	var swing := (hi - lo) / BossArtRig.ART_SCALE
	_expect(swing <= 0.12,
		"하트핵 박동이 너무 커서 약점처럼 보이면 안 된다 (실제 %.3f)" % swing)


## 기획서 상태 2: "몸이 좌우로 불안정하게 흔들림".
## 폭이 커지면 가이드 20절 "과한 흔들림으로 공 경로가 가려짐" 에 걸린다.
func _test_idle_motion(rig: BossArtRig) -> void:
	rig.play_idle()
	var sway := rig.get_node_or_null(^"Sway") as Node2D
	var arm := rig.get_node_or_null(^"Sway/Pose/LeftShoulderPivot") as Node2D
	if sway == null or arm == null:
		return

	var rot_lo := 999.0
	var rot_hi := -999.0
	var pos_lo := 9999.0
	var pos_hi := -9999.0
	var lag_seen := 0.0
	var waited := 0.0
	while waited < 3.2:
		await process_frame
		waited += root.get_process_delta_time()
		rot_lo = minf(rot_lo, sway.rotation)
		rot_hi = maxf(rot_hi, sway.rotation)
		pos_lo = minf(pos_lo, sway.position.x)
		pos_hi = maxf(pos_hi, sway.position.x)
		# 팔이 몸을 그대로 따라가면 차이가 0 이다. 천 인형이면 뒤처져야 한다.
		var body_deg := rad_to_deg(sway.rotation)
		lag_seen = maxf(lag_seen, absf(body_deg - rig.get_arm_trail()))

	_expect(rot_hi > rot_lo, "기본 대기에서 몸이 좌우로 흔들려야 한다")
	_expect(pos_hi > pos_lo, "회전만이 아니라 좌우로도 미끄러져야 한다")

	var swing := rad_to_deg(rot_hi - rot_lo)
	_expect(swing <= 8.0,
		"흔들림이 과하면 공 경로를 가린다 (실제 %.1f°)" % swing)
	_expect(swing >= 0.6,
		"흔들림이 너무 작으면 살아 있어 보이지 않는다 (실제 %.1f°)" % swing)

	# 이게 천 인형 느낌의 핵심이다. 팔이 몸에 붙어 통째로 움직이면 나무 인형이다.
	_expect(lag_seen > 0.05,
		"팔이 몸보다 늦게 따라와야 한다 (최대 지연 %.3f°)" % lag_seen)

	# 공격 자세에서는 흔들림이 죽어야 한다. 예고가 흐려지면 안 된다.
	rig.play_attack(true)
	var attack_hi := -999.0
	var attack_lo := 999.0
	waited = 0.0
	while waited < 1.6:
		await process_frame
		waited += root.get_process_delta_time()
		attack_hi = maxf(attack_hi, sway.rotation)
		attack_lo = minf(attack_lo, sway.rotation)
	var attack_swing := rad_to_deg(attack_hi - attack_lo)
	_expect(attack_swing < swing,
		"팔을 들었을 때는 흔들림이 줄어야 한다 (대기 %.1f° vs 공격 %.1f°)"
			% [swing, attack_swing])
	rig.play_idle()


## 표정. 가이드 4-2·4-3 이 아주 좁게 못박아 둔 영역이다.
## 눈은 **빈 검은 구멍**만, 입은 **포효할 때만** 늘어난다.
func _test_expressions(rig: BossArtRig) -> void:
	var left := rig.get_node_or_null(^"Sway/Pose/LeftEye") as Node2D
	var right := rig.get_node_or_null(^"Sway/Pose/RightEye") as Node2D
	_expect(left != null and right != null, "눈구멍이 레이어로 떨어져 있어야 한다")
	if left == null or right == null:
		return

	var seen: Array[Vector2] = []
	for name: StringName in BossArtRig.EXPRESSIONS.keys():
		rig.set_expression(name)
		_expect(rig.get_expression() == name, "%s 표정이 반영돼야 한다" % name)
		# 좌우가 같은 방향으로 기울면 얼굴이 통째로 돌아간 것처럼 보인다.
		_expect(is_equal_approx(left.rotation, -right.rotation),
			"%s 에서 두 눈이 서로 반대로 기울어야 한다" % name)
		seen.append(left.scale)

	# 표정이 전부 같은 값이면 다양하게 만든 의미가 없다.
	var distinct := {}
	for v in seen:
		distinct["%.2f_%.2f" % [v.x, v.y]] = true
	_expect(distinct.size() >= 5,
		"표정이 서로 충분히 달라야 한다 (서로 다른 눈 모양 %d개)" % distinct.size())

	# 입은 포효에서 가장 크게 벌어져야 한다 (가이드 4-3).
	rig.set_expression(&"idle")
	_expect(not rig.is_mouth_open(), "기본 대기에서는 입이 다물려 있어야 한다")
	rig.set_expression(&"telegraph")
	_expect(not rig.is_mouth_open(), "공격 예고에서도 입은 다물려 있어야 한다")

	var widest := 0.0
	var roar := 0.0
	for name: StringName in BossArtRig.EXPRESSIONS.keys():
		var amount: float = BossArtRig.EXPRESSIONS[name]["mouth"]
		widest = maxf(widest, amount)
		if name == &"roar":
			roar = amount
	_expect(is_equal_approx(roar, widest) and roar > 0.0,
		"입은 포효에서 가장 크게 벌어져야 한다 (포효 %.2f, 최대 %.2f)" % [roar, widest])

	rig.set_expression(&"idle")


## 상태 전환이 **부드러워야** 한다. 즉시 스냅이 "어색함" 의 첫 번째 원인이었다.
func _test_transitions(rig: BossArtRig) -> void:
	rig.play_idle(true)
	await process_frame
	rig.play_attack()
	await process_frame
	await process_frame
	var early: float = rig.get_arm_angles().x
	_expect(early > 1.0, "전환이 시작되면 팔이 움직이기 시작해야 한다 (%.1f°)" % early)
	_expect(early < BossArtRig.ATTACK_ANGLE - 10.0,
		"전환은 즉시 스냅되면 안 된다 (두 프레임 만에 %.1f°)" % early)

	var waited := 0.0
	while waited < 1.2:
		await process_frame
		waited += root.get_process_delta_time()
	_expect(absf(rig.get_arm_angles().x - BossArtRig.ATTACK_ANGLE) < 6.0,
		"충분히 기다리면 목표 각도에 도달해야 한다 (%.1f°)" % rig.get_arm_angles().x)

	# 예고는 몸이 아래로 눌려야 한다 (기획서 상태 3 "몸 전체가 아래로 압축").
	rig.play_telegraph(true)
	var pose := rig.get_node(^"Sway/Pose") as Node2D
	_expect(pose.transform.y.length() < 0.95,
		"예고에서 몸이 세로로 눌려야 한다 (배율 %.3f)" % pose.transform.y.length())
	rig.play_idle(true)


## 피격은 반동으로 표현한다 (기획서 상태 6 "짧게 찌그러지고 흔들림").
func _test_jolt(rig: BossArtRig) -> void:
	rig.play_idle(true)
	await process_frame
	var pose := rig.get_node(^"Sway/Pose") as Node2D
	rig.play_hit(1.0)
	_expect(rig.is_jolting(), "피격 직후에는 반동 중이어야 한다")

	var min_scale := 99.0
	var waited := 0.0
	while waited < 0.6:
		await process_frame
		waited += root.get_process_delta_time()
		min_scale = minf(min_scale, pose.transform.y.length())
	_expect(min_scale < 0.985,
		"피격에서 몸이 실제로 찌그러져야 한다 (최소 배율 %.3f)" % min_scale)
	_expect(not rig.is_jolting(), "반동은 잦아들어야 한다")
	_expect(absf(pose.transform.y.length() - 1.0) < 0.03,
		"반동이 끝나면 원래 크기로 돌아와야 한다 (%.3f)" % pose.transform.y.length())


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_art_rig_test")
		quit(0)
		return
	print("FAIL: boss_art_rig_test (%d failures)" % _failures.size())
	quit(1)
