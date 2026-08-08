class_name BossVfxLayer
extends Node2D
## 보스 VFX 레이어입니다. `BossArtRig` 옆에 두고 리그를 참조합니다.
##
## GL Compatibility 라 GPUParticles 를 못 씁니다. 전부 `_draw()` 입니다.
##
## ## 스타일
##
## 이 게임 아트는 굵은 잉크 외곽선의 손그림 카툰이다. VFX 도 같은 언어를 쓴다.
## - 맨 `draw_line` 을 쓰지 않는다. 전부 **끝이 가늘어지는 폴리곤**이다
## - 큰 도형에는 **잉크 림**을 두른다 (아트의 외곽선과 같은 문법)
## - 한 색이 아니라 **어두운 바깥 → 본색 → 밝은 코어** 세 겹이다
## 처음 판은 평면 단색 선·부채라 "싼티" 지적을 받았다 (2026-08-08).
##
## ## 배치
##
## **보스 뒤에 깐다** (z 는 리그 최하 레이어보다 아래). 잔상·연기·위험선이
## 실루엣 뒤에서 비쳐 나와 보스를 가리지 않는다. 형락님 지시 (2026-08-08).
## 씬에서 이 노드를 리그보다 **먼저**(트리 위쪽) 둬야 같은 z 에서 뒤로 간다.
##
## ## 스윙 잔상은 스폰이 아니라 추적이다
##
## 처음 판은 프레임마다 정지 부채를 스폰해서, 팔이 내려갈 때 잔상이 궤적을
## 안 따라왔다 (2026-08-08 지적). 지금은 **팔 각도 이력을 매 프레임 기록**하고
## 그 이력으로 리본을 다시 그린다. 올라가든 내려가든 실제 궤적을 그대로 탄다.
##
## ## 무엇을 안 하나
##
## - 히트스톱·시간 조작 (팔-공 충돌 히트스톱은 기획서가 금지)
## - 정확한 반격 VFX (가이드 메모 "패링 vfx 와 똑같은 거 쓰자!" → 재사용)
## - 전투 로직 (런타임이 spawn_* 를 부른다)


## 리그 최하 레이어(UNDER_Z=0)와 같은 z. 트리에서 리그보다 먼저 두면 뒤로 간다.
const VFX_Z: int = 0
## 타격 피드백 전용 앞 레이어. 스파이크·솜·링은 **정보**라 몸에 가려지면 안 된다.
## 기획서 13-2 의 타격 피드백은 보여야 하고, 대신 수명을 짧게 잡아 공을 안 가린다.
const FRONT_Z: int = 5

## 팔 길이(인게임 px). 아트 실측 435 의 절반이다.
const ARM_LENGTH: float = 217.0

## 잉크 림 색. 아트 외곽선(먹빛 청흑)과 같은 계열이다.
const INK := Color(0.07, 0.086, 0.11, 1.0)

## 각도 이력 보관 시간. 리본 창보다 넉넉하면 된다.
const HISTORY_KEEP: float = 0.5


@export var rules: BossVfxRules = null
## 참조할 리그. 비우면 형제 중에서 찾는다.
@export var rig_path: NodePath = ^""


var _rig: BossArtRig = null
var _time := 0.0

var _impacts: Array[Dictionary] = []
var _hit_ticks: Array[Dictionary] = []
var _fluffs: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _smokes: Array[Dictionary] = []

## 팔 각도 이력. {t: float, a: float} 목록, 최신이 뒤.
var _hist_l: Array[Dictionary] = []
var _hist_r: Array[Dictionary] = []
## 잔상 열기. 팔이 빠르면 차오르고 멈추면 식는다. 리본 알파에 곱한다.
var _heat_l := 0.0
var _heat_r := 0.0

var _front: FrontLayer = null
var _telegraph_visible := false
## 예고 붓획이 자라나는 진행도. 상태에 들어올 때 0 에서 시작한다.
var _telegraph_grow := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = VFX_Z
	if rules == null:
		rules = BossVfxRules.new()
	_front = FrontLayer.new()
	_front.name = "Front"
	_front.owner_layer = self
	_front.z_as_relative = false
	_front.z_index = FRONT_Z
	add_child(_front)
	_resolve_rig()


func _resolve_rig() -> void:
	if not rig_path.is_empty():
		_rig = get_node_or_null(rig_path) as BossArtRig
	if _rig == null and get_parent() != null:
		for child in get_parent().get_children():
			if child is BossArtRig:
				_rig = child
				break


# --------------------------------------------------------------------------
# 스폰
# --------------------------------------------------------------------------


## 팔이 공을 쳐낸 지점의 방향성 충격입니다 (9-2).
## `direction` 은 공이 튕겨 나간 방향 — 반드시 그쪽으로 퍼져야 경로를 읽는다.
func spawn_ball_impact(local_position: Vector2, direction: Vector2) -> void:
	if rules == null:
		return
	var base := direction.normalized() if direction.length_squared() > 0.0 \
		else Vector2.UP
	# 진행 방향 스파이크는 길고, 반대쪽은 짧다. 방향이 읽히는 이유다.
	for index in rules.impact_ticks:
		var spread := 0.0
		if rules.impact_ticks > 1:
			spread = (
				float(index) / float(rules.impact_ticks - 1) - 0.5
			) * deg_to_rad(64.0)
		var wobble := 0.8 + 0.4 * float((index * 7) % 5) / 4.0
		_impacts.append({
			"born": _time,
			"life": rules.impact_lifetime,
			"origin": local_position,
			"dir": base.rotated(spread),
			"length": rules.impact_length * wobble,
			"width": 13.0 - 3.0 * absf(spread),
		})
	# 반대쪽 짧은 스파이크 두 개. 터짐이 한쪽으로만 쏠리면 어색하다.
	for index in 2:
		var back := (-base).rotated((float(index) - 0.5) * 0.9)
		_impacts.append({
			"born": _time,
			"life": rules.impact_lifetime * 0.7,
			"origin": local_position,
			"dir": back,
			"length": rules.impact_length * 0.38,
			"width": 8.0,
		})
	queue_redraw()


## 보스 피격 "푹+팡" 입니다 (10절). `strong` 은 고콤보 — 충격링이 추가된다.
func spawn_hit(local_position: Vector2, direction: Vector2, strong: bool = false) -> void:
	if rules == null:
		return
	var base := direction.normalized() if direction.length_squared() > 0.0 \
		else Vector2.UP
	var base_angle := base.angle()

	for index in rules.hit_ticks:
		var offset := 0.0
		if rules.hit_ticks > 1:
			offset = (
				float(index) / float(rules.hit_ticks - 1) - 0.5
			) * deg_to_rad(78.0)
		var wobble := 0.75 + 0.5 * float((index * 5) % 4) / 3.0
		_hit_ticks.append({
			"born": _time,
			"life": rules.hit_lifetime,
			"origin": local_position,
			"dir": Vector2.from_angle(base_angle + offset),
			"length": rules.hit_tick_length * wobble * (1.3 if strong else 1.0),
			"width": 10.0 if strong else 8.0,
		})

	var fluff_total := rules.fluff_count * (2 if strong else 1)
	for index in fluff_total:
		var angle := base_angle + randf_range(-1.1, 1.1)
		_fluffs.append({
			"born": _time,
			"life": rules.fluff_lifetime * randf_range(0.7, 1.0),
			"origin": local_position,
			"dir": Vector2.from_angle(angle),
			"length": randf_range(30.0, 72.0) * (1.4 if strong else 1.0),
			"radius": rules.fluff_radius * randf_range(0.7, 1.15),
			"seed": randf_range(0.0, TAU),
			"spin": randf_range(-3.0, 3.0),
		})

	if strong:
		_rings.append({
			"born": _time,
			"life": rules.ring_lifetime,
			"origin": local_position,
		})
	queue_redraw()


## 포효 연기입니다 (11절). 봉제선에서 검은 연기가 **연달아** 솟는다.
## 전부 동시에 터지면 판때기처럼 보여서 퍼프마다 시차를 둔다.
func spawn_roar() -> void:
	if rules == null:
		return
	# 실루엣 **가장자리**에서 새어 나오게 한다. 뒤 레이어라 몸 안쪽 좌표는
	# 통째로 가려진다 (2026-08-08). 어깨 위·옆구리·머리 옆이 뚫린 자리다.
	var seams: Array[Vector2] = [
		Vector2(-206.0, -190.0), Vector2(210.0, -196.0),
		Vector2(-178.0, 40.0), Vector2(182.0, 52.0),
		Vector2(-88.0, -262.0), Vector2(94.0, -266.0),
		Vector2(0.0, -276.0),
	]
	for index in rules.smoke_count:
		var seam: Vector2 = seams[index % seams.size()]
		_smokes.append({
			"born": _time + float(index) * 0.055,
			"life": rules.smoke_lifetime * randf_range(0.75, 1.0),
			"origin": seam + Vector2(randf_range(-14.0, 14.0), 0.0),
			"length": randf_range(60.0, 130.0),
			"radius": rules.smoke_radius * randf_range(0.7, 1.3),
			"seed": randf_range(0.0, TAU),
		})
	for index in 4:
		_fluffs.append({
			"born": _time + float(index) * 0.08,
			"life": rules.smoke_lifetime * 0.8,
			"origin": Vector2(randf_range(-70.0, 70.0), randf_range(-40.0, 60.0)),
			"dir": Vector2.UP,
			"length": randf_range(50.0, 100.0),
			"radius": rules.fluff_radius * randf_range(0.7, 1.2),
			"seed": randf_range(0.0, TAU),
			"spin": randf_range(-2.0, 2.0),
		})
	queue_redraw()


func clear_all() -> void:
	_impacts.clear()
	_hit_ticks.clear()
	_fluffs.clear()
	_rings.clear()
	_smokes.clear()
	_hist_l.clear()
	_hist_r.clear()
	_heat_l = 0.0
	_heat_r = 0.0
	queue_redraw()


# 검사용.
func live_impact_count() -> int:
	return _impacts.size()


func live_hit_tick_count() -> int:
	return _hit_ticks.size()


func live_fluff_count() -> int:
	return _fluffs.size()


func live_ring_count() -> int:
	return _rings.size()


func live_smoke_count() -> int:
	return _smokes.size()


## 지금 보이는 잔상 리본 수 (0~2). 열기가 남은 팔의 수다.
func live_trail_count() -> int:
	var count := 0
	if _heat_l > 0.06:
		count += 1
	if _heat_r > 0.06:
		count += 1
	return count


func is_telegraph_visible() -> bool:
	return _telegraph_visible


# --------------------------------------------------------------------------
# 갱신
# --------------------------------------------------------------------------


func _process(delta: float) -> void:
	_time += delta

	if _rig == null:
		_resolve_rig()

	var alive := false
	for pool: Array[Dictionary] in [
		_impacts, _hit_ticks, _fluffs, _rings, _smokes,
	]:
		_expire(pool)
		# 항목이 **살아 있는 동안** 매 프레임 다시 그린다. 만료 변화가 있을
		# 때만 그리면 스폰 프레임(t=0, 페이드 0)에 멈춰 아무것도 안 보인다
		# (2026-08-08 포효 연기가 실제로 그렇게 사라졌다).
		alive = alive or not pool.is_empty()

	if _rig != null:
		var telegraph_now: bool = _rig.get_state() == &"telegraph"
		if telegraph_now and not _telegraph_visible:
			_telegraph_grow = 0.0
		_telegraph_visible = telegraph_now
		if _telegraph_visible:
			_telegraph_grow = minf(_telegraph_grow + delta * 5.0, 1.0)
			alive = true

		# 팔 각도 이력. 잔상 리본은 이걸로 매 프레임 다시 그린다.
		var angles := _rig.get_arm_angles()
		_push_history(_hist_l, angles.x)
		_push_history(_hist_r, angles.y)
		_heat_l = _update_heat(_hist_l, _heat_l, delta)
		_heat_r = _update_heat(_hist_r, _heat_r, delta)
		if _heat_l > 0.06 or _heat_r > 0.06:
			alive = true

	if alive or _telegraph_visible:
		queue_redraw()


func _push_history(history: Array[Dictionary], angle: float) -> void:
	history.append({"t": _time, "a": angle})
	while history.size() > 2 and _time - float(history[0]["t"]) > HISTORY_KEEP:
		history.remove_at(0)


## 최근 0.1 초 각속도로 열기를 올리고, 멈추면 식힌다.
func _update_heat(history: Array[Dictionary], heat: float, delta: float) -> float:
	var speed := 0.0
	if history.size() >= 2:
		var newest := history[history.size() - 1]
		for index in range(history.size() - 2, -1, -1):
			var item := history[index]
			var dt := float(newest["t"]) - float(item["t"])
			if dt >= 0.08:
				speed = absf(float(newest["a"]) - float(item["a"])) / dt
				break
	if speed >= rules.trail_min_speed:
		return minf(heat + delta * 9.0, 1.0)
	return maxf(heat - delta / maxf(rules.trail_lifetime, 0.01), 0.0)


func _expire(pool: Array[Dictionary]) -> bool:
	var changed := false
	for index in range(pool.size() - 1, -1, -1):
		var item := pool[index]
		if _time - float(item["born"]) >= float(item["life"]):
			pool.remove_at(index)
			changed = true
	return changed


func _progress(item: Dictionary) -> float:
	return clampf((_time - float(item["born"])) / float(item["life"]), 0.0, 1.0)


# --------------------------------------------------------------------------
# 그리기
# --------------------------------------------------------------------------


func _draw() -> void:
	if rules == null:
		return

	# 뒤 레이어부터: 연기 → 잔상 → 위험선 → 링 → 스파이크 → 솜.
	for item in _smokes:
		_draw_smoke(item)

	_draw_trail_ribbon(&"L", _hist_l, _heat_l)
	_draw_trail_ribbon(&"R", _hist_r, _heat_r)

	if _telegraph_visible:
		_draw_telegraph()

	if _front != null:
		_front.queue_redraw()


## 앞 레이어가 자기 `_draw()` 안에서 호출합니다. 타격 피드백 전용.
func draw_front(canvas: Node2D) -> void:
	for item in _rings:
		_draw_ring(canvas, item)

	for item in _hit_ticks:
		var t := _progress(item)
		if t < 1.0:
			_draw_spike(
				canvas, item["origin"], item["dir"],
				float(item["length"]), float(item["width"]),
				t, rules.hit_tick_color
			)

	for item in _impacts:
		var t := _progress(item)
		if t < 1.0:
			_draw_spike(
				canvas, item["origin"], item["dir"],
				float(item["length"]), float(item["width"]),
				t, rules.impact_color
			)

	for item in _fluffs:
		_draw_fluff(canvas, item)


## 타격 피드백을 보스 앞(z 5)에서 그리는 자식 레이어입니다.
## 분위기 연출(잔상·연기·위험선)은 부모가 뒤(z 0)에서 그린다.
class FrontLayer:
	extends Node2D

	var owner_layer: BossVfxLayer = null

	func _draw() -> void:
		if owner_layer != null:
			owner_layer.draw_front(self)


## 팔 스윙 잔상. **이력 리본**이라 어느 방향으로 움직여도 궤적을 그대로 탄다.
func _draw_trail_ribbon(
	side: StringName, history: Array[Dictionary], heat: float
) -> void:
	if heat <= 0.06 or history.size() < 3:
		return
	var shoulder := BossArtRig.LEFT_SHOULDER if side == &"L" \
		else BossArtRig.RIGHT_SHOULDER
	var sign_value := 1.0 if side == &"L" else -1.0

	# 최근 창 안의 이력을 **최신부터 거슬러** 모은다. 방향이 반전되면 거기서
	# 끊는다 — 올라갔다 내려오는 궤적이 한 리본에 섞이면 폴리곤이 자기교차해
	# 삼각분할이 터진다 (2026-08-08 실제 오류). 거의 같은 각도는 건너뛴다.
	var newest_t := float(history[history.size() - 1]["t"])
	var angles: Array[float] = []
	var direction_sign := 0.0
	for index in range(history.size() - 1, -1, -1):
		var item := history[index]
		if newest_t - float(item["t"]) > rules.trail_window:
			break
		var a := float(item["a"])
		if angles.is_empty():
			angles.append(a)
			continue
		var last := angles[angles.size() - 1]
		var step := a - last
		if absf(step) < 0.4:
			continue
		if direction_sign == 0.0:
			direction_sign = signf(step)
		elif signf(step) != direction_sign:
			break
		angles.append(a)
	if angles.size() < 3:
		return
	# 모은 순서가 최신→과거라, 꼬리→머리가 되게 뒤집는다.
	angles.reverse()
	var points: Array[Vector2] = []
	for a in angles:
		points.append(Vector2.from_angle(PI / 2 + deg_to_rad(a) * sign_value))
	# 움직임이 없으면 리본이 점이 된다. 각도 폭이 좁으면 건너뛴다.
	var total_arc := 0.0
	for index in points.size() - 1:
		total_arc += points[index].angle_to(points[index + 1])
	if absf(total_arc) < deg_to_rad(3.0):
		return

	var outer := ARM_LENGTH * 1.04
	var count := points.size()

	# 세 겹: 어두운 바깥 → 본색 → 손끝 쪽 밝은 코어. 평면 한 겹이 싼티의 원인이었다.
	var passes := [
		{"in": rules.trail_inner_ratio - 0.10, "alpha": 0.30, "color": Color(0.29, 0.16, 0.44, 1.0)},
		{"in": rules.trail_inner_ratio, "alpha": 1.0, "color": rules.trail_color},
		{"in": rules.trail_inner_ratio + 0.22, "alpha": 1.0, "color": rules.trail_core_color},
	]
	for pass_data: Dictionary in passes:
		var inner: float = ARM_LENGTH * clampf(float(pass_data["in"]), 0.05, 0.98)
		var color: Color = pass_data["color"]
		color.a *= float(pass_data["alpha"]) * heat
		var polygon := PackedVector2Array()
		# 바깥 가장자리 (꼬리→머리), 폭은 꼬리로 갈수록 좁아진다.
		for index in count:
			var k := float(index) / float(count - 1)  # 0 꼬리, 1 머리
			var direction := points[index]
			var width_scale := 0.25 + 0.75 * k
			var radius := lerpf(inner, outer, width_scale)
			polygon.append(shoulder + direction * radius)
		for index in range(count - 1, -1, -1):
			polygon.append(shoulder + points[index] * inner)
		draw_colored_polygon(polygon, color)


## 예고 위험선. **팔이 그릴 궤적을 따라 휘어진 붓획**입니다 (9-1).
## 곧은 막대 3개는 화살표 UI 처럼 보여 싼티 지적을 받았다. 팔 스윙 호를 따라
## 안쪽에서 위로 자라나며, 끝이 가늘어지는 카툰 붓획으로 그린다.
func _draw_telegraph() -> void:
	var pulse := 0.78 + 0.22 * sin(_time * TAU * rules.telegraph_pulse_hz)
	for side_sign: float in [-1.0, 1.0]:
		var shoulder := BossArtRig.LEFT_SHOULDER if side_sign < 0.0 \
			else BossArtRig.RIGHT_SHOULDER
		for stroke in rules.telegraph_strokes:
			var k := float(stroke) / maxf(float(rules.telegraph_strokes - 1), 1.0)
			# 붓획마다 반지름이 다르고, 안쪽 획이 먼저 자란다.
			# **팔보다 바깥**이어야 한다. 뒤 레이어라 팔과 겹치면 통째로
			# 가려져 예고가 안 보인다 (2026-08-08 캡처에서 실제로 사라졌다).
			var radius := ARM_LENGTH * (1.06 + 0.14 * k)
			var grow := clampf(_telegraph_grow * (1.15 - 0.3 * k), 0.0, 1.0)
			if grow <= 0.05:
				continue
			# 아래(팔이 있는 곳)에서 바깥 위로. 리그 각도 0°=아래, 115°=공격 끝.
			var start_deg := 12.0 + 6.0 * k
			var end_deg := start_deg + (52.0 + 14.0 * k) * grow
			var color := rules.telegraph_color_bright if stroke == 0 \
				else rules.telegraph_color
			color.a *= pulse * (1.0 - 0.18 * k)
			# side_sign 을 그대로 넘긴다. 부호를 뒤집으면 호가 몸 안쪽에
			# 그려져 뒤 레이어에서 통째로 가려진다 (2026-08-08 캡처).
			_draw_arc_brush(
				shoulder, radius, start_deg, end_deg, side_sign,
				rules.telegraph_width * (1.0 - 0.22 * k), color
			)


## 원호를 따라 휘어진 붓획. 시작이 굵고 끝(진행 방향)이 뾰족하다.
func _draw_arc_brush(
	centre: Vector2, radius: float, from_deg: float, to_deg: float,
	x_sign: float, width: float, color: Color
) -> void:
	var steps := 14
	var polygon := PackedVector2Array()
	# 리그 각도 → 화면 각도. x_sign 이 좌우를 가른다.
	var outer_points: Array[Vector2] = []
	var inner_points: Array[Vector2] = []
	for index in steps + 1:
		var t := float(index) / float(steps)
		var a := PI / 2 + deg_to_rad(lerpf(from_deg, to_deg, t)) * -x_sign
		var direction := Vector2.from_angle(a)
		# 폭: 뿌리 60% 지점에서 최대, 양 끝으로 가늘어진다 (붓 눌림).
		var profile := sin(clampf(t, 0.0, 1.0) * PI)
		profile = pow(profile, 0.7) * (1.0 - 0.35 * t)
		var half := width * 0.5 * (0.15 + 0.85 * profile)
		outer_points.append(centre + direction * (radius + half))
		inner_points.append(centre + direction * (radius - half))
	for point in outer_points:
		polygon.append(point)
	for index in range(inner_points.size() - 1, -1, -1):
		polygon.append(inner_points[index])

	# 잉크 림 → 본색. 림이 있어야 아트의 외곽선 문법과 맞는다.
	var rim := INK
	rim.a = color.a * 0.85
	draw_colored_polygon(_inflate_polygon(polygon, 2.4), rim)
	draw_colored_polygon(polygon, color)


## 고콤보 충격링. 겹 링(넓은 헤일로 + 본선 + 안쪽 하이라이트)입니다.
func _draw_ring(canvas: Node2D, item: Dictionary) -> void:
	var t := _progress(item)
	if t >= 1.0:
		return
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var radius := lerpf(26.0, rules.ring_end_radius, eased)
	var origin: Vector2 = item["origin"]
	var fade := 1.0 - t

	var halo := rules.ring_color
	halo.a *= 0.18 * fade
	canvas.draw_arc(origin, radius, 0.0, TAU, 64, halo, rules.ring_width * 3.2, true)

	var ink := INK
	ink.a = 0.5 * fade
	canvas.draw_arc(origin, radius + rules.ring_width * 0.7, 0.0, TAU, 64, ink, 2.2, true)

	var main := rules.ring_color
	main.a *= fade
	canvas.draw_arc(origin, radius, 0.0, TAU, 64, main, rules.ring_width * (1.0 - 0.45 * t), true)

	var core := Color(0.94, 0.87, 1.0, 0.9 * fade)
	canvas.draw_arc(origin, radius - rules.ring_width * 0.55, 0.0, TAU, 64, core, 2.0, true)


## 끝이 뾰족한 스파이크. 맨 draw_line 대신 쓰는 기본 도형입니다.
func _draw_spike(
	canvas: Node2D, origin: Vector2, direction: Vector2, length: float,
	base_width: float, t: float, color: Color
) -> void:
	var fade := 1.0 - t
	var start := origin + direction * length * 0.22 * t
	var tip := origin + direction * length * (0.72 + 0.28 * t)
	var normal := direction.orthogonal()
	var half := base_width * 0.5 * (1.0 - 0.35 * t)

	var polygon := PackedVector2Array([
		start + normal * half,
		tip,
		start - normal * half,
	])
	var rim := INK
	rim.a = 0.6 * fade
	canvas.draw_colored_polygon(_inflate_polygon(polygon, 2.0), rim)
	var body := color
	body.a *= fade
	canvas.draw_colored_polygon(polygon, body)
	# 밝은 코어. 뿌리 쪽 절반에만.
	var core := Color(0.95, 0.89, 1.0, 0.85 * fade)
	var mid := start.lerp(tip, 0.55)
	canvas.draw_colored_polygon(PackedVector2Array([
		start + normal * half * 0.4, mid, start - normal * half * 0.4,
	]), core)


## 검은 솜 파편. 잉크 림을 두른 카툰 덩어리입니다.
func _draw_fluff(canvas: Node2D, item: Dictionary) -> void:
	if _time < float(item["born"]):
		return
	var t := _progress(item)
	if t >= 1.0:
		return
	var fade := 1.0 - t * t
	var origin: Vector2 = item["origin"]
	var direction: Vector2 = item["dir"]
	var position := origin + direction * float(item["length"]) * (1.0 - (1.0 - t) * (1.0 - t))
	var radius := float(item["radius"]) * (1.0 - 0.25 * t)
	var seed_value := float(item["seed"]) + t * float(item["spin"])

	var offsets := [
		Vector2.ZERO,
		Vector2.from_angle(seed_value) * radius * 0.72,
		Vector2.from_angle(seed_value + 2.2) * radius * 0.8,
		Vector2.from_angle(seed_value + 4.3) * radius * 0.66,
	]
	# 잉크 림 (뒤에 큰 원) → 본색 → 밝은 면. 아트의 솜과 같은 문법.
	var rim := INK
	rim.a = 0.8 * fade
	for offset: Vector2 in offsets:
		canvas.draw_circle(position + offset, radius * (0.62 + 0.1) + 2.2, rim)
	var body := rules.fluff_color
	body.a *= fade
	for offset: Vector2 in offsets:
		canvas.draw_circle(position + offset, radius * 0.62, body)
	var lit := rules.fluff_color.lightened(0.22)
	lit.a *= fade * 0.9
	canvas.draw_circle(
		position + Vector2.from_angle(seed_value + 1.1) * radius * 0.3 - Vector2(0, radius * 0.2),
		radius * 0.4, lit
	)


## 포효 연기 퍼프. 시차를 두고 솟는 잉크 림 덩어리입니다.
func _draw_smoke(item: Dictionary) -> void:
	if _time < float(item["born"]):
		return
	var t := _progress(item)
	if t >= 1.0:
		return
	# 부드럽게 나타났다 사라진다. 뚝 나타나면 팝핑이 보인다.
	var fade := clampf(t / 0.12, 0.0, 1.0) * clampf((1.0 - t) / 0.45, 0.0, 1.0)
	var seed_value := float(item["seed"])
	var origin: Vector2 = item["origin"]
	var rise := float(item["length"]) * t
	var swayx := sin(seed_value + t * 4.6) * 16.0 * t
	var position := origin + Vector2(swayx, -rise)
	var radius := float(item["radius"]) * (0.55 + 0.85 * t)

	var offsets := [
		Vector2.ZERO,
		Vector2.from_angle(seed_value) * radius * 0.62,
		Vector2.from_angle(seed_value + 2.4) * radius * 0.7,
		Vector2(0, -radius * 0.5),
	]
	var rim := INK
	rim.a = 0.55 * fade
	for offset: Vector2 in offsets:
		draw_circle(position + offset, radius * 0.68 + 2.4, rim)
	var body := rules.smoke_color
	body.a *= fade
	for offset: Vector2 in offsets:
		draw_circle(position + offset, radius * 0.68, body)
	# 안쪽 저주 보라 빛.
	var glow := rules.smoke_glow_color
	glow.a *= fade
	draw_circle(position + Vector2(0, radius * 0.1), radius * 0.34, glow)


## 폴리곤을 무게중심 기준으로 살짝 부풀립니다. 잉크 림용입니다.
func _inflate_polygon(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	var centre := Vector2.ZERO
	for point in polygon:
		centre += point
	centre /= float(polygon.size())
	var out := PackedVector2Array()
	for point in polygon:
		var away := point - centre
		var length := away.length()
		if length < 0.001:
			out.append(point)
		else:
			out.append(centre + away * ((length + amount) / length))
	return out
