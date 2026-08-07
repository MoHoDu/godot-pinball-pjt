class_name BumperHitFeedback
extends Node2D
## 범퍼 타격 VFX (Normal 타입) — `FlipperParryFeedback` 노드 패턴을 따릅니다.
##
## 물리 노드와 분리된 별도 Node2D 이며 **범퍼의 위치·회전·크기는 절대 건드리지
## 않습니다.** 시그널만 구독하고 자기 위치만 범퍼에 맞춥니다.
##
## 기획서 대응:
## - 3-3 Normal: 작고 단순한 타격선 + 재질 중심 반응
## - 3-2 내구도 감소: 실밥 한 가닥이 드러나거나 끊어짐
## - 3-2 파괴: 큰 카툰 파편. 폭발이 아니라 장난감이 망가지는 느낌
## - 3-2 복구 예고: 아주 약한 떨림
## - 3-1 공의 진행 방향과 다음 경로를 가리지 않음 → 타격 VFX 는 공보다 아래
##
## 접촉 지점은 시그널로 오지 않아 범퍼 중심과 공 위치에서 유도합니다.
## `contact_point_for()` 참고.
##
## GL Compatibility 라 GPUParticles 를 못 씁니다. 전부 `_draw()` 입니다.


## 범퍼 본체 위, 공 아래. 3-1 절의 "경로를 가리지 않음" 을 지키는 값입니다.
const HIT_Z_INDEX := 5
## 파괴 파편만 공 위로 올립니다. 아래에 두면 망가지는 연출이 묻힙니다.
const DEBRIS_Z_INDEX := 13

const FALLBACK_RADIUS := 44.0


## 파편 전용 레이어. Node2D 하나는 z 를 하나만 가지므로 자식으로 분리합니다.
class DebrisLayer:
	extends Node2D

	var owner_feedback: BumperHitFeedback = null

	func _draw() -> void:
		if owner_feedback != null:
			owner_feedback.draw_debris_into(self)


@export var rules: BumperVfxRules = null:
	set(value):
		rules = value
		queue_redraw()


var _bumper: Bumper = null
var _debris_layer: DebrisLayer = null
var _time := 0.0
var _telegraph_until := -1.0
var _telegraph_active := false

# 각 항목: {born: float, life: float, origin: Vector2, dir: Vector2, length: float,
#           radius: float, angle: float}
var _ticks: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _threads: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = HIT_Z_INDEX


func _ready() -> void:
	_debris_layer = DebrisLayer.new()
	_debris_layer.name = "_Debris"
	_debris_layer.top_level = true
	_debris_layer.z_as_relative = false
	_debris_layer.z_index = DEBRIS_Z_INDEX
	_debris_layer.owner_feedback = self
	add_child(_debris_layer)

	if rules == null:
		rules = BumperVfxRules.new()

	var parent := get_parent()
	if parent is Bumper:
		bind_to_bumper(parent as Bumper)


func bind_to_bumper(bumper: Bumper) -> void:
	if _bumper == bumper:
		return

	if is_instance_valid(_bumper):
		if _bumper.valid_hit_registered.is_connected(_on_valid_hit_registered):
			_bumper.valid_hit_registered.disconnect(_on_valid_hit_registered)
		if _bumper.durability_changed.is_connected(_on_durability_changed):
			_bumper.durability_changed.disconnect(_on_durability_changed)
		if _bumper.state_changed.is_connected(_on_state_changed):
			_bumper.state_changed.disconnect(_on_state_changed)

	_bumper = bumper
	if not is_instance_valid(_bumper):
		return

	_bumper.valid_hit_registered.connect(_on_valid_hit_registered)
	_bumper.durability_changed.connect(_on_durability_changed)
	_bumper.state_changed.connect(_on_state_changed)


## 범퍼 중심과 공 위치로 접촉 지점을 유도합니다.
## 시그널이 충돌 위치를 넘겨주지 않아 필요한 계산입니다.
## 88~128px 범퍼에서는 이 근사로 충분합니다.
func contact_point_for(ball_position: Vector2) -> Vector2:
	var center := _bumper_center()
	var normal := contact_normal_for(ball_position)
	return center + normal * _bumper_radius()


func contact_normal_for(ball_position: Vector2) -> Vector2:
	var center := _bumper_center()
	var offset := ball_position - center
	if offset.length_squared() <= 0.0:
		return Vector2.UP
	return offset.normalized()


func _bumper_center() -> Vector2:
	if is_instance_valid(_bumper):
		return _bumper.global_position
	return global_position


## VFX 는 **표시 반지름**에 붙는다. 충돌 반지름을 쓰면 아트 밑에 깔려 안 보인다.
## 표시가 충돌보다 4.5~14.3% 크다(범퍼마다 다름). 2026-08-07 에 실제로 걸렸다.
func _bumper_radius() -> float:
	if is_instance_valid(_bumper):
		if _bumper.settings != null and _bumper.settings.visual_diameter > 0.0:
			return _bumper.settings.visual_diameter * 0.5
		var radius := _bumper.get_collision_radius()
		if radius > 0.0:
			return radius
	return FALLBACK_RADIUS


func _process(delta: float) -> void:
	_time += delta

	if is_instance_valid(_bumper):
		global_position = _bumper.global_position
		if _debris_layer != null:
			_debris_layer.global_position = _bumper.global_position

	if _telegraph_active and _telegraph_until >= 0.0 and _time > _telegraph_until:
		_telegraph_active = false

	var flashes_alive := _expire(_flashes)
	var sparkles_alive := _expire(_sparkles)
	var ticks_alive := _expire(_ticks)
	var chips_alive := _expire(_chips)
	var threads_alive := _expire(_threads)
	var alive := (
		ticks_alive or chips_alive or threads_alive
		or flashes_alive or sparkles_alive
	)
	var debris_alive := _expire(_debris)

	if alive or _telegraph_active:
		queue_redraw()
	if debris_alive and _debris_layer != null:
		_debris_layer.queue_redraw()


func _expire(pool: Array[Dictionary]) -> bool:
	if pool.is_empty():
		return false
	var index := pool.size() - 1
	while index >= 0:
		var item: Dictionary = pool[index]
		if _time - float(item["born"]) >= float(item["life"]):
			pool.remove_at(index)
		index -= 1
	return true


# --------------------------------------------------------------------------
# 시그널
# --------------------------------------------------------------------------


func _on_valid_hit_registered(
	_bumper_id: StringName,
	ball: RigidBody2D,
	_contact_id: int,
	_base_score: int
) -> void:
	if not is_instance_valid(ball):
		return
	spawn_hit(ball.global_position)


func _on_durability_changed(current: int, maximum: int) -> void:
	# 최초 통지(_ready 직후)는 감소가 아니므로 거른다.
	if maximum <= 0 or current >= maximum:
		return
	spawn_thread_snap()


func _on_state_changed(
	_previous: Bumper.BumperState,
	current: Bumper.BumperState
) -> void:
	match current:
		Bumper.BumperState.DESTROYED_TIMER:
			spawn_debris()
			_telegraph_active = false
		Bumper.BumperState.RESPAWN_TELEGRAPH:
			_telegraph_active = true
			_telegraph_until = -1.0
		Bumper.BumperState.ACTIVE:
			_telegraph_active = false


# --------------------------------------------------------------------------
# 생성 (테스트에서 직접 호출한다)
# --------------------------------------------------------------------------


## 접촉 지점에서 타격선과 재질 조각을 띄웁니다.
func spawn_hit(ball_position: Vector2) -> void:
	if rules == null:
		return
	var radius := _bumper_radius()
	var origin := contact_point_for(ball_position)
	var normal := contact_normal_for(ball_position)
	var base_angle := normal.angle()
	var spread := deg_to_rad(rules.tick_spread_degrees)

	for index in rules.tick_count:
		var offset := 0.0
		if rules.tick_count > 1:
			offset = (float(index) / float(rules.tick_count - 1) - 0.5) * 2.0 * spread
		# 길이를 조금씩 어긋나게 둔다. 가이드 2-2 의 대칭 금지와 같은 이유다.
		var wobble := 0.82 + 0.36 * float((index * 7) % 5) / 4.0
		_ticks.append({
			"born": _time,
			"life": rules.tick_lifetime,
			"origin": origin,
			"dir": Vector2.from_angle(base_angle + offset),
			"length": radius * rules.tick_length_ratio * wobble,
		})

	for index in rules.chip_count:
		var chip_angle := base_angle + randf_range(-spread, spread)
		_chips.append({
			"born": _time,
			"life": rules.chip_lifetime,
			"origin": origin,
			"dir": Vector2.from_angle(chip_angle),
			"length": radius * rules.chip_travel_ratio * randf_range(0.6, 1.0),
			"radius": radius * rules.chip_radius_ratio * randf_range(0.7, 1.0),
		})

	if rules.flash_radius_ratio > 0.0:
		_flashes.append({
			"born": _time,
			"life": rules.flash_lifetime,
			"origin": origin,
			"radius": radius * rules.flash_radius_ratio,
		})

	for index in rules.sparkle_count:
		# 접촉 지점 주변에 흩어 둔다. 전부 한 점에 겹치면 하나로 보인다.
		var scatter := base_angle + randf_range(-spread, spread) * 1.4
		var away := randf_range(0.15, 0.75) * radius * 0.5
		_sparkles.append({
			"born": _time,
			# 조금씩 늦게 터져야 "반짝" 하고 이어진다.
			"life": rules.flash_lifetime * randf_range(1.0, 1.7),
			"origin": origin + Vector2.from_angle(scatter) * away,
			"radius": radius * rules.sparkle_radius_ratio * randf_range(0.6, 1.0),
			"angle": randf_range(0.0, PI),
		})

	queue_redraw()


## 내구도가 깎일 때 실밥 한 가닥이 끊어지는 표시입니다 (3-2, 5-1).
func spawn_thread_snap() -> void:
	if rules == null:
		return
	var radius := _bumper_radius()
	var angle := randf_range(0.0, TAU)
	_threads.append({
		"born": _time,
		"life": rules.chip_lifetime * 1.6,
		# 실밥은 범퍼 표면 위에 있어야 한다. 바깥으로 나가면 허공에 뜬 자국이 된다.
		"origin": _bumper_center() + Vector2.from_angle(angle) * radius * 0.32,
		"dir": Vector2.from_angle(angle),
		"length": radius * 0.30,
	})
	queue_redraw()


## 파괴 시 큰 카툰 파편입니다. 폭발이 아니라 장난감이 망가지는 느낌 (3-2).
func spawn_debris() -> void:
	if rules == null:
		return
	var radius := _bumper_radius()
	for index in rules.debris_count:
		var angle := TAU * float(index) / float(maxi(rules.debris_count, 1))
		angle += randf_range(-0.35, 0.35)
		_debris.append({
			"born": _time,
			"life": rules.debris_lifetime,
			"origin": _bumper_center(),
			"dir": Vector2.from_angle(angle),
			"length": radius * randf_range(0.55, 1.05),
			"radius": radius * rules.chip_radius_ratio * randf_range(1.4, 2.2),
			"angle": randf_range(0.0, TAU),
		})
	if _debris_layer != null:
		_debris_layer.queue_redraw()


func live_flash_count() -> int:
	return _flashes.size()


func live_sparkle_count() -> int:
	return _sparkles.size()


func live_tick_count() -> int:
	return _ticks.size()


func live_chip_count() -> int:
	return _chips.size()


func live_debris_count() -> int:
	return _debris.size()


func live_thread_count() -> int:
	return _threads.size()


func is_telegraph_active() -> bool:
	return _telegraph_active


# --------------------------------------------------------------------------
# 그리기
# --------------------------------------------------------------------------


func _draw() -> void:
	if rules == null:
		return
	var center := _bumper_center()

	for item in _ticks:
		var t := _progress(item)
		var color := rules.tick_color
		color.a *= 1.0 - t
		var origin: Vector2 = item["origin"] - center
		# 태어나는 순간부터 길이의 80% 를 쓴다. 예전엔 55% 라 한 프레임짜리
		# 타격선이 실제 설정값보다 훨씬 짧게 보였다 (2026-08-07).
		var start: Vector2 = origin + item["dir"] * float(item["length"]) * 0.35 * t
		var end: Vector2 = origin + item["dir"] * float(item["length"]) * (0.80 + 0.20 * t)
		draw_glow_line(start, end, color, rules.tick_width * (1.0 - 0.4 * t))

	# 섬광은 가장 먼저 커졌다 사라진다. 다른 요소 밑에 깔려야 자연스럽다.
	for item in _flashes:
		var t := _progress(item)
		var color := rules.flash_color
		color.a *= (1.0 - t) * (1.0 - t)
		var position: Vector2 = item["origin"] - center
		var flash_radius: float = float(item["radius"]) * (0.45 + 0.85 * t)
		_draw_glow_disc(position, flash_radius, color, rules.glow_strength)

	for item in _sparkles:
		var t := _progress(item)
		var color := rules.sparkle_color
		color.a *= 1.0 - t
		# 빠르게 커졌다가 다시 줄어든다. 한 번 "반짝" 하는 리듬을 만든다.
		var pop := sin(clampf(t, 0.0, 1.0) * PI)
		_draw_sparkle(
			item["origin"] - center,
			float(item["radius"]) * pop,
			float(item["angle"]) + t * 1.2,
			color
		)

	for item in _chips:
		var t := _progress(item)
		var color := rules.chip_color
		color.a *= 1.0 - t * t
		var position: Vector2 = item["origin"] - center + item["dir"] * float(item["length"]) * t
		var chip_radius: float = float(item["radius"]) * (1.0 - 0.35 * t)
		if rules.chip_star_points >= 3:
			# 조각이 날아가며 같이 돈다. 별이 굳어 보이지 않게 한다.
			draw_colored_polygon(
				_star_points(
					position, chip_radius, rules.chip_star_points, t * PI
				),
				color
			)
		else:
			draw_circle(position, chip_radius, color)

	for item in _threads:
		var t := _progress(item)
		var color := rules.telegraph_color
		color.a = 0.9 * (1.0 - t)
		var origin: Vector2 = item["origin"] - center
		# 끊어진 실이 양쪽으로 벌어진다.
		var gap: Vector2 = item["dir"] * float(item["length"]) * 0.12 * t
		var tip: Vector2 = item["dir"] * float(item["length"])
		draw_line(origin, origin + tip * 0.45 - gap, color, 2.0, true)
		draw_line(origin + tip * 0.55 + gap, origin + tip, color, 2.0, true)

	if _telegraph_active:
		var radius := _bumper_radius()
		var shiver := sin(_time * TAU * rules.telegraph_hz)
		var ring := radius * (1.0 + rules.telegraph_amplitude_ratio * shiver)
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, rules.telegraph_color, 2.0, true)


## 파편 레이어가 자기 `_draw()` 안에서 호출합니다.
func draw_debris_into(layer: Node2D) -> void:
	if rules == null:
		return
	var center := _bumper_center()
	for item in _debris:
		var t := _progress(item)
		var color := rules.chip_color
		color.a *= 1.0 - t * t
		var position: Vector2 = item["origin"] - center + item["dir"] * float(item["length"]) * t
		var size: float = float(item["radius"]) * (1.0 - 0.25 * t)
		var spin: float = float(item["angle"]) + t * 2.2
		# 카툰 파편이라 원이 아니라 각진 조각으로 그린다.
		var points := PackedVector2Array()
		for corner in 3:
			var a := spin + TAU * float(corner) / 3.0
			points.append(position + Vector2.from_angle(a) * size)
		layer.draw_colored_polygon(points, color)


## 선을 세 겹으로 겹쳐 빛나 보이게 그립니다.
## GL Compatibility 에 블룸이 없어 이렇게 흉내 냅니다.
func draw_glow_line(
	start: Vector2, end: Vector2, color: Color, width: float
) -> void:
	var glow: float = rules.glow_strength if rules != null else 0.0
	if glow > 0.0:
		var halo := color
		halo.a *= 0.16 * glow
		draw_line(start, end, halo, width * 3.2, true)
		halo.a = color.a * 0.30 * glow
		draw_line(start, end, halo, width * 1.9, true)
	draw_line(start, end, color, width, true)


## 원호를 세 겹으로 겹쳐 빛나 보이게 그립니다.
func draw_glow_arc(radius: float, color: Color, width: float) -> void:
	var glow: float = rules.glow_strength if rules != null else 0.0
	if glow > 0.0:
		var halo := color
		halo.a *= 0.15 * glow
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, halo, width * 3.4, true)
		halo.a = color.a * 0.28 * glow
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, halo, width * 2.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, width, true)


## 가운데가 밝고 가장자리로 사라지는 빛 덩어리입니다.
##
## 반투명 원 하나로 그리면 배경 위에 **테두리가 뚜렷한 회색 얼룩**이 됩니다.
## 동심원을 바깥(옅게)부터 안쪽(진하게)으로 겹쳐 그려 그러데이션을 만듭니다.
## 알파가 누적돼 가운데가 저절로 밝아집니다.
func _draw_glow_disc(
	center: Vector2, radius: float, color: Color, glow: float
) -> void:
	var steps := 5 if glow > 0.0 else 1
	for index in steps:
		# 1.0 -> 0.2 로 좁혀 들어간다.
		var shrink := 1.0 - 0.8 * (float(index) / float(steps))
		var layer := color
		# 바깥은 아주 옅게, 안으로 갈수록 진하게.
		layer.a = color.a * lerpf(0.10 * glow, 1.0, float(index) / float(steps - 1)) 			if steps > 1 else color.a
		draw_circle(center, radius * (1.6 * shrink), layer)


## 네 갈래 반짝임입니다. 가로·세로로 길고 가운데가 밝은 고전적인 별빛 모양입니다.
func _draw_sparkle(
	center: Vector2, radius: float, angle: float, color: Color
) -> void:
	var long_axis := radius
	var short_axis := radius * 0.16
	var points := PackedVector2Array()
	for index in 8:
		var step := float(index) * PI * 0.25
		var r: float = long_axis if index % 2 == 0 else short_axis
		points.append(center + Vector2.from_angle(angle + step) * r)
	draw_colored_polygon(points, color)


## 별 폴리곤 꼭짓점입니다. 안쪽 반지름은 바깥의 0.45 배로 둡니다.
## 더 크면 별이 아니라 톱니로, 더 작으면 바늘처럼 보입니다.
func _star_points(
	center: Vector2, radius: float, points: int, phase: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var step := PI / float(points)
	for index in points * 2:
		var r: float = radius if index % 2 == 0 else radius * 0.45
		# -PI/2 를 더해 꼭짓점 하나가 위를 보게 한다.
		var angle := phase - PI * 0.5 + float(index) * step
		result.append(center + Vector2.from_angle(angle) * r)
	return result


func _progress(item: Dictionary) -> float:
	var life := float(item["life"])
	if life <= 0.0:
		return 1.0
	return clampf((_time - float(item["born"])) / life, 0.0, 1.0)
