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


func _bumper_radius() -> float:
	if is_instance_valid(_bumper):
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

	var ticks_alive := _expire(_ticks)
	var chips_alive := _expire(_chips)
	var threads_alive := _expire(_threads)
	var alive := ticks_alive or chips_alive or threads_alive
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
		"origin": _bumper_center() + Vector2.from_angle(angle) * radius * 0.55,
		"dir": Vector2.from_angle(angle),
		"length": radius * 0.42,
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
		var start: Vector2 = origin + item["dir"] * float(item["length"]) * 0.25 * t
		var end: Vector2 = origin + item["dir"] * float(item["length"]) * (0.55 + 0.45 * t)
		draw_line(start, end, color, rules.tick_width * (1.0 - 0.4 * t), true)

	for item in _chips:
		var t := _progress(item)
		var color := rules.chip_color
		color.a *= 1.0 - t * t
		var position: Vector2 = item["origin"] - center + item["dir"] * float(item["length"]) * t
		draw_circle(position, float(item["radius"]) * (1.0 - 0.35 * t), color)

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


func _progress(item: Dictionary) -> float:
	var life := float(item["life"])
	if life <= 0.0:
		return 1.0
	return clampf((_time - float(item["born"])) / life, 0.0, 1.0)
