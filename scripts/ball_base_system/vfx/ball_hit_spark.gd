@tool
class_name BallHitSpark
extends Node2D
## 공이 튕길 때마다 접촉 지점에 터지는 바운스 스파크입니다 (비주얼 가이드 충돌 스파크).
##
## 역할은 "예쁘게 빛나기"가 아니라 **타격감을 몸으로 읽게 하는 것**입니다.
## 세게 부딪힐수록 크게 터져서 충돌의 세기가 화면에서 바로 보여야 합니다.
##
## 감지는 시그널이 아니라 **속도 변화량(Δv)** 입니다. 매 물리 프레임
## linear_velocity 를 비교해 임계값 이상 꺾이면 바운스로 봅니다.
## 벽·플리퍼·범퍼 어디에 맞아도 같은 코드로 잡히고, 굴러가는 접촉은
## Δv 가 작아 자동으로 걸러집니다.
##
## 물리 바디의 위치·회전·크기는 절대 건드리지 않습니다.
## FlipperParryFeedback / BallGlowOutline / BumperHitFeedback 과 같은
## "연출은 물리와 분리" 패턴입니다.
##
## GL Compatibility 라 GPUParticles 를 못 씁니다. 전부 `_draw()` 입니다
## (BumperHitFeedback 과 같은 방식).


const DEFAULT_SPARK_RULES: BallHitSparkRules = preload(
	"res://settings/balls/BallHitSparkRules.tres"
)

## 비주얼 가이드의 레이어 순서입니다. 꼬리(5) < 공 본체(6) < 발광 테두리(10)
## < 패링 파동(11 예약) < 충돌 스파크. 범퍼 파괴 파편(13)보다는 아래입니다.
const Z_INDEX_SPARK: int = 12

## 부모에서 공 지름을 읽지 못했을 때 쓰는 값입니다. 기획서 기준 22px 반지름.
const FALLBACK_BALL_RADIUS: float = 22.0

## 직전 프레임 속력이 이보다 느리면 바운스로 보지 않습니다.
## 정지 상태에서의 발사(launch)가 스파크로 오인되지 않게 합니다.
const MIN_INCOMING_SPEED: float = 40.0


var _spark_rules: BallHitSparkRules = DEFAULT_SPARK_RULES
var _ball: RigidBody2D
var _time: float = 0.0
var _cooldown_until: float = 0.0
var _previous_velocity: Vector2 = Vector2.ZERO
var _has_previous_velocity: bool = false

# 각 항목: {born: float, life: float, origin: Vector2(월드), dir: Vector2,
#           length: float, radius: float}
var _ticks: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []


## 스파크 규칙입니다. 씬에 내장하거나 .tres 프리셋으로 교체할 수 있습니다.
@export var spark_rules: BallHitSparkRules:
	get:
		return _spark_rules
	set(value):
		_spark_rules = value if value != null else DEFAULT_SPARK_RULES
		update_configuration_warnings()


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX_SPARK


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_ball = get_parent() as RigidBody2D
	if _ball != null:
		global_position = _ball.global_position


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var ball := _ball
	if ball == null:
		return

	# top_level 이라 위치를 상속하지 않으므로 직접 따라갑니다.
	global_position = ball.global_position
	visible = ball.visible

	var velocity := ball.linear_velocity
	if _has_previous_velocity:
		_detect_bounce(velocity)

	_previous_velocity = velocity
	_has_previous_velocity = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta

	var ticks_alive := _expire(_ticks)
	var chips_alive := _expire(_chips)
	var flashes_alive := _expire(_flashes)
	if ticks_alive or chips_alive or flashes_alive:
		queue_redraw()


## 직전 프레임과 속도를 비교해 바운스를 감지합니다.
func _detect_bounce(velocity: Vector2) -> void:
	var delta_v := velocity - _previous_velocity

	if (
		_previous_velocity.length() < MIN_INCOMING_SPEED
		or delta_v.length() < _spark_rules.min_bounce_delta_v
		or _time < _cooldown_until
	):
		return

	spawn_burst(delta_v)
	_cooldown_until = _time + _spark_rules.cooldown


## Δv 방향과 세기로 스파크 한 벌(타격선+조각+섬광)을 터뜨립니다.
## 테스트에서 직접 호출할 수 있습니다.
func spawn_burst(delta_v: Vector2) -> void:
	var rules := _spark_rules
	if rules == null or delta_v.is_zero_approx():
		return

	var radius := _ball_radius()
	var burst_scale := clampf(
		delta_v.length() / rules.reference_delta_v,
		rules.min_burst_scale,
		1.0
	)
	# Δv 는 표면에서 밀려난 방향입니다. 접촉 지점은 그 반대쪽 공 가장자리입니다.
	var away := delta_v.normalized()
	var tangent := away.orthogonal()
	var origin := global_position - away * radius
	var base_angle := away.angle()
	var spread := deg_to_rad(rules.tick_spread_degrees)
	# 전부 한 점에서 나오면 뭉쳐 하나로 보입니다 (범퍼 VFX 실측).
	# 접촉면을 따라 시작점을 흩뿌립니다.
	var scatter := radius * rules.chip_scatter_ratio

	for index in rules.tick_count:
		var offset := 0.0
		if rules.tick_count > 1:
			offset = (float(index) / float(rules.tick_count - 1) - 0.5) * 2.0 * spread
		# 길이를 조금씩 어긋나게 둡니다. 대칭이면 도장 찍은 것처럼 보입니다.
		var wobble := 0.80 + 0.40 * float((index * 7) % 5) / 4.0
		_ticks.append({
			"born": _time,
			"life": rules.tick_lifetime,
			# 타격선은 조각의 절반 강도로만 흩뿌립니다. 뿌리가 너무 흩어지면
			# "타격"이 아니라 "비"처럼 보입니다.
			"origin": origin + tangent * randf_range(-0.5, 0.5) * scatter,
			"dir": Vector2.from_angle(base_angle + offset),
			"length": radius * rules.tick_length_ratio * wobble * burst_scale,
		})

	for index in rules.chip_count:
		var chip_angle := base_angle + randf_range(-spread, spread)
		# 편차 0이면 전부 균일(정속형), 1이면 크게 들쭉날쭉(혼돈형)합니다.
		var jitter := rules.chip_travel_jitter
		var chip_origin := (
			origin
			+ tangent * randf_range(-1.0, 1.0) * scatter
			+ away * randf_range(0.0, 0.35) * scatter
		)
		_chips.append({
			"born": _time,
			"life": rules.chip_lifetime,
			"origin": chip_origin,
			"dir": Vector2.from_angle(chip_angle),
			"length": (
				radius * rules.chip_travel_ratio
				* (1.0 - jitter * randf()) * burst_scale
			),
			"radius": (
				radius * rules.chip_radius_ratio
				* (1.0 - 0.6 * jitter * randf()) * burst_scale
			),
			"shape": _chip_shape_for(index, rules),
			"spin": randf_range(0.0, TAU),
		})

	if rules.flash_radius_ratio > 0.0:
		_flashes.append({
			"born": _time,
			"life": rules.flash_lifetime,
			"origin": origin,
			"radius": radius * rules.flash_radius_ratio * burst_scale,
		})

	queue_redraw()


func live_tick_count() -> int:
	return _ticks.size()


func live_chip_count() -> int:
	return _chips.size()


func live_flash_count() -> int:
	return _flashes.size()


func _draw() -> void:
	var rules := _spark_rules
	if rules == null:
		return

	# 섬광은 다른 요소 밑에 깔려야 자연스럽습니다.
	for item in _flashes:
		var t := _progress(item)
		var color := rules.flash_color
		color.a *= (1.0 - t) * (1.0 - t)
		var position: Vector2 = item["origin"] - global_position
		var flash_radius: float = float(item["radius"]) * (0.5 + 0.8 * t)
		_draw_glow_disc(position, flash_radius, color, rules.glow_strength)

	for item in _ticks:
		var t := _progress(item)
		var color := rules.tick_color
		color.a *= 1.0 - t
		var origin: Vector2 = item["origin"] - global_position
		var start: Vector2 = origin + item["dir"] * float(item["length"]) * 0.35 * t
		var end: Vector2 = origin + item["dir"] * float(item["length"]) * (0.80 + 0.20 * t)
		_draw_glow_line(start, end, color, rules.tick_width * (1.0 - 0.4 * t))

	for item in _chips:
		var t := _progress(item)
		var color := rules.chip_color
		color.a *= 1.0 - t * t
		var position: Vector2 = (
			item["origin"] - global_position
			+ item["dir"] * float(item["length"]) * t
		)
		_draw_chip(
			position,
			float(item["radius"]) * (1.0 - 0.35 * t),
			item["dir"],
			float(item["spin"]) + t * 3.2,
			int(item["shape"]),
			color
		)


## 짝수/홀수 조각에 기본·보조 모양을 번갈아 배정합니다. 두 모양이 같으면 섞지 않습니다.
func _chip_shape_for(index: int, rules: BallHitSparkRules) -> int:
	if rules.chip_shape_secondary != rules.chip_shape and index % 2 == 1:
		return rules.chip_shape_secondary
	return rules.chip_shape


## 조각 하나를 규칙의 모양대로 그립니다. 공별 개성(컨셉의 직선/튀김/번짐/
## 4방향/고리파편)을 절차 폴리곤으로 표현합니다.
##
## 아주 작은 반지름에서는 폴리곤 꼭짓점이 한 점으로 붕괴해 삼각분할이
## 실패하므로("Invalid polygon data" — BumperHitFeedback 에서 실측) 원으로
## 대체합니다.
func _draw_chip(
	center: Vector2,
	chip_radius: float,
	direction: Vector2,
	spin: float,
	shape: int,
	color: Color
) -> void:
	if chip_radius < 0.7 and shape != BallHitSparkRules.ChipShape.CIRCLE:
		draw_circle(center, maxf(chip_radius, 0.3), color)
		return

	match shape:
		BallHitSparkRules.ChipShape.DROP:
			_draw_drop(center, chip_radius, direction, color)
		BallHitSparkRules.ChipShape.BUBBLE:
			# 말랑한 거품 — 옅은 속 + 또렷한 테두리
			var fill := color
			fill.a *= 0.35
			draw_circle(center, chip_radius, fill)
			draw_arc(
				center, chip_radius, 0.0, TAU, 12,
				color, maxf(1.0, chip_radius * 0.35), true
			)
		BallHitSparkRules.ChipShape.FLAKE:
			_draw_flake(center, chip_radius, direction, color)
		BallHitSparkRules.ChipShape.RING:
			draw_arc(
				center, chip_radius, 0.0, TAU, 12,
				color, maxf(1.0, chip_radius * 0.3), true
			)
		BallHitSparkRules.ChipShape.STAR:
			_draw_star(center, chip_radius, spin, color)
		BallHitSparkRules.ChipShape.GEAR:
			_draw_gear(center, chip_radius, spin, color)
		_:
			draw_circle(center, chip_radius, color)


## 물방울 — 진행 방향으로 둥근 머리, 뒤로 뾰족한 꼬리 (폭발형).
func _draw_drop(
	center: Vector2, chip_radius: float, direction: Vector2, color: Color
) -> void:
	var head_angle := direction.angle()
	var points := PackedVector2Array()
	for index in 5:
		var a := head_angle - PI * 0.5 + PI * float(index) / 4.0
		points.append(center + Vector2.from_angle(a) * chip_radius)
	points.append(center - direction * chip_radius * 1.9)
	draw_colored_polygon(points, color)


## 각진 금속 파편 — 진행 방향으로 길쭉한 마름모 (정밀형).
func _draw_flake(
	center: Vector2, chip_radius: float, direction: Vector2, color: Color
) -> void:
	var forward := direction * chip_radius * 1.7
	var side := direction.orthogonal() * chip_radius * 0.45
	var points := PackedVector2Array([
		center + forward,
		center + side,
		center - forward,
		center - side,
	])
	draw_colored_polygon(points, color)


## 4갈래 별 — 길고 짧은 꼭짓점을 번갈아 돌립니다 (혼돈형 보조).
func _draw_star(
	center: Vector2, chip_radius: float, spin: float, color: Color
) -> void:
	var points := PackedVector2Array()
	for index in 8:
		var r := chip_radius if index % 2 == 0 else chip_radius * 0.35
		var a := spin + PI * 0.25 * float(index)
		points.append(center + Vector2.from_angle(a) * r)
	draw_colored_polygon(points, color)


## 톱니 — 바깥·안쪽 반지름을 번갈아 도는 8치 기어 실루엣 (안정형).
func _draw_gear(
	center: Vector2, chip_radius: float, spin: float, color: Color
) -> void:
	var points := PackedVector2Array()
	for index in 16:
		var r := chip_radius if index % 2 == 0 else chip_radius * 0.72
		var a := spin + TAU * float(index) / 16.0
		points.append(center + Vector2.from_angle(a) * r)
	draw_colored_polygon(points, color)
	# 축 구멍 — 태엽 장식과 같은 문법입니다.
	var hole := color
	hole.a *= 0.55
	draw_circle(center, chip_radius * 0.28, hole)


## 선을 세 겹으로 겹쳐 빛나 보이게 그립니다. GL Compatibility 에 블룸이 없어
## 이렇게 흉내 냅니다 (BumperHitFeedback.draw_glow_line 과 같은 기법).
func _draw_glow_line(
	start: Vector2, end: Vector2, color: Color, width: float
) -> void:
	var glow := _spark_rules.glow_strength
	if glow > 0.0:
		var halo := color
		halo.a *= 0.16 * glow
		draw_line(start, end, halo, width * 3.2, true)
		halo.a = color.a * 0.30 * glow
		draw_line(start, end, halo, width * 1.9, true)
	draw_line(start, end, color, width, true)


## 가운데가 밝고 가장자리로 사라지는 빛 덩어리입니다.
## 동심원을 바깥(옅게)부터 안쪽(진하게)으로 겹쳐 그러데이션을 만듭니다.
func _draw_glow_disc(
	center: Vector2, radius: float, color: Color, glow: float
) -> void:
	var steps := 5 if glow > 0.0 else 1
	for index in steps:
		var shrink := 1.0 - 0.8 * (float(index) / float(steps))
		var layer := color
		layer.a = (
			color.a * lerpf(0.10 * glow, 1.0, float(index) / float(steps - 1))
			if steps > 1 else color.a
		)
		draw_circle(center, radius * (1.6 * shrink), layer)


func _ball_radius() -> float:
	if _ball != null:
		var diameter: Variant = _ball.get(&"ball_diameter")
		if diameter is float and float(diameter) > 0.0:
			return float(diameter) * 0.5
	return FALLBACK_BALL_RADIUS


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


func _progress(item: Dictionary) -> float:
	var life := float(item["life"])
	if life <= 0.0:
		return 1.0
	return clampf((_time - float(item["born"])) / life, 0.0, 1.0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not (get_parent() is RigidBody2D):
		warnings.append("BallHitSpark의 부모는 RigidBody2D여야 합니다.")

	if _spark_rules == null:
		warnings.append("Spark Rules 리소스를 지정해야 합니다.")

	return warnings
