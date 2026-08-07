extends SceneTree
## 보스 VFX 검증.
##
## 확인하는 것:
## - 검수 씬에 VFX 레이어가 붙고 규칙이 꽂혀 있는가
## - 예고 위험선이 리그 상태를 따라 켜지고 꺼지는가 (폴링 연동)
## - 팔 공격 스윙에서 잔상이 생기고, 대기 흔들림에서는 안 생기는가
## - 피격 푹+팡 / 고콤보 링 / 충돌 충격선 / 포효 연기가 수만큼 생기는가
## - 전부 수명이 지나면 사라지는가 (공 추적을 가리면 안 된다)
## - **시간 조작을 하지 않는가** — 팔-공 충돌 히트스톱은 기획서가 금지한다
## - 위험선 색이 위험색(진홍 계열)인가 — 기능색 원칙
##
## 실행:
##   godot --headless --path . --script res://tests/boss_system/boss_vfx_test.gd

const SCENE := "res://scenes/boss_system/boss_art_test.tscn"


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
	var vfx := stage.get_node_or_null(^"Vfx") as BossVfxLayer
	_expect(rig != null and vfx != null, "리그와 VFX 레이어가 있어야 한다")
	if rig == null or vfx == null:
		_finish()
		return
	_expect(vfx.rules != null, "VFX 규칙이 꽂혀 있어야 한다")

	# VFX 는 보스 **뒤**에 깔린다 (2026-08-08 지시). 리그 최하 레이어 이하 + 트리 앞.
	_expect(vfx.z_index <= 0 and not vfx.z_as_relative,
		"VFX z 는 리그 최하 레이어(0) 이하의 절대 z 여야 한다 (실제 %d)" % vfx.z_index)
	_expect(vfx.get_index() < rig.get_index(),
		"VFX 노드는 트리에서 리그보다 앞(위)에 있어야 같은 z 에서 뒤로 간다")

	var scale_before := Engine.time_scale

	await _test_telegraph(rig, vfx)
	await _test_trail(rig, vfx)
	await _test_spawns(vfx)
	await _test_expiry(vfx)
	_test_colours(vfx)

	# 히트스톱 금지. VFX 레이어가 시간을 만지면 공 추적이 끊긴다.
	_expect(is_equal_approx(Engine.time_scale, scale_before),
		"VFX 가 Engine.time_scale 을 만지면 안 된다 (%.2f -> %.2f)"
			% [scale_before, Engine.time_scale])

	_finish()


## 예고 위험선은 리그 상태 폴링이다. 런타임이 신호를 따로 줄 필요가 없어야 한다.
func _test_telegraph(rig: BossArtRig, vfx: BossVfxLayer) -> void:
	rig.play_idle(true)
	await _wait(0.1)
	_expect(not vfx.is_telegraph_visible(),
		"대기 상태에서 위험선이 보이면 안 된다")

	rig.play_telegraph(true)
	await _wait(0.1)
	_expect(vfx.is_telegraph_visible(),
		"예고 상태에 들어가면 위험선이 켜져야 한다")

	rig.play_attack(true)
	await _wait(0.1)
	_expect(not vfx.is_telegraph_visible(),
		"공격이 시작되면 위험선이 꺼져야 한다 (예고 정보가 남으면 혼동된다)")
	rig.play_idle(true)
	await _wait(0.2)


## 잔상은 팔이 빠르게 움직일 때만. 대기 흔들림(느림)에 반응하면 상시 잔상이 된다.
func _test_trail(rig: BossArtRig, vfx: BossVfxLayer) -> void:
	rig.play_idle(true)
	vfx.clear_all()  # 앞 검사의 잔열·이력이 남으면 간헐 실패한다
	await _wait(0.6)
	var idle_trails := vfx.live_trail_count()
	_expect(idle_trails == 0,
		"대기 흔들림으로 잔상이 생기면 안 된다 (실제 %d)" % idle_trails)

	# 예고에서 공격으로 스냅 없이 빠르게 전환하면 팔 각속도가 임계를 넘는다.
	rig.play_telegraph(true)
	await _wait(0.05)
	rig.play_attack()
	await _wait(0.15)
	_expect(vfx.live_trail_count() > 0,
		"팔 공격 스윙에서 잔상이 남아야 한다")
	await _wait(0.6)

	# **내려갈 때도** 따라와야 한다. 경직의 팔 낙하는 초반 ~370°/s 다.
	# 처음 판은 스폰식 부채라 낙하 궤적을 안 따라왔다 (2026-08-08 지적).
	rig.play_attack(true)
	vfx.clear_all()  # 스냅 점프가 이력에 남으면 낙하 검사가 오염된다
	await _wait(0.15)
	rig.play_recovery()
	await _wait(0.18)
	_expect(vfx.live_trail_count() > 0,
		"팔이 내려갈 때도 잔상이 궤적을 따라와야 한다")
	rig.play_idle(true)
	await _wait(0.7)


func _test_spawns(vfx: BossVfxLayer) -> void:
	vfx.clear_all()

	vfx.spawn_hit(Vector2.ZERO, Vector2.LEFT, false)
	_expect(vfx.live_hit_tick_count() == vfx.rules.hit_ticks,
		"피격 타격선이 규칙 수만큼 생겨야 한다 (기대 %d, 실제 %d)"
			% [vfx.rules.hit_ticks, vfx.live_hit_tick_count()])
	_expect(vfx.live_fluff_count() == vfx.rules.fluff_count,
		"솜 파편이 규칙 수만큼 생겨야 한다 (기대 %d, 실제 %d)"
			% [vfx.rules.fluff_count, vfx.live_fluff_count()])
	_expect(vfx.live_ring_count() == 0,
		"일반 피격에는 충격링이 없어야 한다 (고콤보 전용)")

	vfx.clear_all()
	vfx.spawn_hit(Vector2.ZERO, Vector2.RIGHT, true)
	_expect(vfx.live_ring_count() == 1,
		"고콤보 피격에는 충격링이 하나 생겨야 한다")
	_expect(vfx.live_fluff_count() == vfx.rules.fluff_count * 2,
		"고콤보 피격은 솜 파편이 두 배여야 한다 (기대 %d, 실제 %d)"
			% [vfx.rules.fluff_count * 2, vfx.live_fluff_count()])

	vfx.clear_all()
	vfx.spawn_ball_impact(Vector2(-150, 40), Vector2(-0.5, -0.86))
	# 진행 방향 스파이크 + 반대쪽 짧은 스파이크 2개. 한쪽으로만 터지면 어색하다.
	_expect(vfx.live_impact_count() == vfx.rules.impact_ticks + 2,
		"충돌 스파이크는 진행 방향 %d개 + 반대쪽 2개여야 한다 (실제 %d)"
			% [vfx.rules.impact_ticks, vfx.live_impact_count()])

	vfx.clear_all()
	vfx.spawn_roar()
	_expect(vfx.live_smoke_count() == vfx.rules.smoke_count,
		"포효 연기가 규칙 수만큼 생겨야 한다 (기대 %d, 실제 %d)"
			% [vfx.rules.smoke_count, vfx.live_smoke_count()])
	_expect(vfx.live_fluff_count() > 0, "포효에는 떠오르는 솜이 있어야 한다")
	await process_frame


## 수명이 지나면 전부 사라져야 한다. 남으면 공 진행 경로를 가린다.
func _test_expiry(vfx: BossVfxLayer) -> void:
	vfx.clear_all()
	vfx.spawn_hit(Vector2.ZERO, Vector2.UP, true)
	vfx.spawn_ball_impact(Vector2.ZERO, Vector2.UP)
	vfx.spawn_roar()

	var longest: float = maxf(
		maxf(vfx.rules.hit_lifetime, vfx.rules.fluff_lifetime),
		maxf(
			maxf(vfx.rules.ring_lifetime, vfx.rules.impact_lifetime),
			vfx.rules.smoke_lifetime
		)
	)
	await _wait(longest + 0.3)

	var remaining := (
		vfx.live_hit_tick_count() + vfx.live_fluff_count()
		+ vfx.live_ring_count() + vfx.live_impact_count()
		+ vfx.live_smoke_count()
	)
	_expect(remaining == 0,
		"수명이 지나면 전부 사라져야 한다 (남은 항목 %d)" % remaining)


## 색 통일 (2026-08-08 형락님 지시): 시인성 높은 **보라 계열**.
## 가이드 6절 위험색 "진홍·적자·핑크" 중 적자 축이라 원칙과도 맞는다.
## 보라 판정 = 붉은·푸른 채널이 초록보다 우세.
func _test_colours(vfx: BossVfxLayer) -> void:
	for pair: Array in [
		["위험선", vfx.rules.telegraph_color],
		["위험선 밝은색", vfx.rules.telegraph_color_bright],
		["잔상", vfx.rules.trail_color],
		["잔상 코어", vfx.rules.trail_core_color],
		["충돌 충격선", vfx.rules.impact_color],
		["피격 타격선", vfx.rules.hit_tick_color],
		["충격링", vfx.rules.ring_color],
		["솜 파편", vfx.rules.fluff_color],
	]:
		var colour: Color = pair[1]
		_expect(colour.r > colour.g and colour.b > colour.g,
			"%s 은 보라 계열이어야 한다 (실제 %s)" % [pair[0], colour])
	var smoke := vfx.rules.smoke_color
	_expect(smoke.r < 0.3 and smoke.g < 0.3 and smoke.b > smoke.g,
		"포효 연기는 검은 보라여야 한다 (실제 %s)" % smoke)
	# 코어가 본색보다 밝아야 시인성 층이 산다.
	_expect(vfx.rules.trail_core_color.v > vfx.rules.trail_color.v,
		"잔상 코어가 본색보다 밝아야 한다")


func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await process_frame
		waited += root.get_process_delta_time()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: boss_vfx_test")
		quit(0)
		return
	print("FAIL: boss_vfx_test (%d failures)" % _failures.size())
	quit(1)
