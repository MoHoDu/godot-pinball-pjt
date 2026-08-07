class_name RepairPartFeedback
extends Node2D


## 수리 부품 상태의 피드백입니다 (FlipperParryFeedback 노드 패턴).
## 물리 노드와 분리된 별도 Node2D로, 부품의 위치·회전·크기는 절대 건드리지 않습니다.
## 이름·긴 설명은 보드 위에 표시하지 않고 상태만 도형으로 읽히게 합니다.
##
## v0.3
##  - 브로치: 별 아이콘 두 개로 '다른 부품 2종' 조건 진행도를 표시하고,
##    6.0초 제한 시간을 줄어드는 금빛 호로 함께 애니메이션합니다.
##    두 별이 모두 켜지면 완성 준비 상태로 맥동합니다.
##  - 톱니: 회전 단계 칸(기본 3칸)
##  - 방울: 퍼지는 원형 파동과 직전 여운 콤보 수만큼의 점


const READY_RING_COLOR := Color(0.94, 0.78, 0.35, 0.55)
const PIP_ON_COLOR := Color(0.98, 0.86, 0.45, 0.9)
const PIP_OFF_COLOR := Color(0.35, 0.33, 0.3, 0.6)
const STAR_ON_COLOR := Color(1.0, 0.91, 0.55, 0.95)
const STAR_OFF_COLOR := Color(0.42, 0.4, 0.36, 0.55)
const STAR_EDGE_COLOR := Color(1.0, 0.97, 0.82, 0.85)
const BROOCH_ARC_COLOR := Color(1.0, 0.86, 0.42, 0.85)
const WAVE_COLOR := Color(0.75, 0.92, 0.9, 0.6)
const PIP_RADIUS := 5.0
const PIP_SPACING := 16.0
const STAR_OUTER_RADIUS := 9.0
const STAR_INNER_RATIO := 0.45
const STAR_SPACING := 26.0
const STATE_Z_INDEX := 12


var _runtime: RepairPartRuntime = null
var _state: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = STATE_Z_INDEX
	var parent := get_parent()
	if parent is Bumper:
		var runtime := parent.get_node_or_null(^"RepairPartRuntime")
		if runtime is RepairPartRuntime:
			bind_to_runtime(runtime as RepairPartRuntime)


func bind_to_runtime(runtime: RepairPartRuntime) -> void:
	_runtime = runtime
	if not runtime.part_state_changed.is_connected(_on_part_state_changed):
		runtime.part_state_changed.connect(_on_part_state_changed)


func _process(delta: float) -> void:
	if _runtime == null or _runtime.bumper == null:
		return
	_elapsed += delta
	global_position = _runtime.bumper.global_position
	queue_redraw()


func _on_part_state_changed(
	_runtime_source: RepairPartRuntime,
	state: Dictionary
) -> void:
	_state = state
	queue_redraw()


func _draw() -> void:
	if _runtime == null or _runtime.bumper == null:
		return
	var radius := _runtime.bumper.get_collision_radius() + 8.0
	if _runtime.is_active_part():
		# 준비 가능 상태는 약한 금빛 테두리로 표시합니다.
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, READY_RING_COLOR, 2.0)

	match int(_state.get(&"family", -1)):
		RepairPartDefinition.Family.BROOCH:
			_draw_brooch(radius)
		RepairPartDefinition.Family.GEAR:
			_draw_pips(
				int(_state.get(&"wind_stack", 0)),
				int(_state.get(&"max_stack", 3)),
				radius
			)
		RepairPartDefinition.Family.BELL:
			_draw_bell(radius)


## 별 아이콘 두 개 + 6.0초 제한 시간 애니메이션.
func _draw_brooch(radius: float) -> void:
	if int(_state.get(&"mark_count", 0)) <= 0:
		return

	var required := maxi(int(_state.get(&"required_arms", 2)), 1)
	var lit := int(_state.get(&"lit_arms", 0))
	var progress := clampf(float(_state.get(&"mark_progress", 0.0)), 0.0, 1.0)
	var is_ready := bool(_state.get(&"is_ready_to_finish", false))

	# 남은 제한 시간을 줄어드는 호로 그립니다. 6.0초 동안 한 바퀴가 사라집니다.
	if progress > 0.0:
		draw_arc(
			Vector2.ZERO,
			radius + 6.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			48,
			BROOCH_ARC_COLOR,
			3.0
		)

	# 완성 준비 상태는 맥동하는 바깥 링을 하나 더 겹칩니다.
	if is_ready:
		var pulse := 0.5 + 0.5 * sin(_elapsed * 7.0)
		draw_arc(
			Vector2.ZERO,
			radius + 12.0 + pulse * 4.0,
			0.0,
			TAU,
			48,
			Color(BROOCH_ARC_COLOR, 0.25 + pulse * 0.45),
			2.0
		)

	var origin := Vector2(
		-(required - 1) * STAR_SPACING * 0.5,
		-radius - 22.0
	)
	for index: int in range(required):
		var center := origin + Vector2(index * STAR_SPACING, 0.0)
		var is_on := index < lit
		var scale_factor := 1.0
		if is_on and is_ready:
			scale_factor = 1.0 + 0.12 * sin(_elapsed * 7.0)
		_draw_star(
			center,
			STAR_OUTER_RADIUS * scale_factor,
			STAR_ON_COLOR if is_on else STAR_OFF_COLOR
		)


func _draw_bell(radius: float) -> void:
	var remaining := float(_state.get(&"echo_remaining", 0.0))
	if remaining > 0.0:
		var ripple := fmod(_elapsed * 1.6, 1.0)
		draw_arc(
			Vector2.ZERO,
			radius + 4.0 + ripple * 16.0,
			0.0,
			TAU,
			40,
			Color(WAVE_COLOR, WAVE_COLOR.a * (1.0 - ripple)),
			2.0
		)
	var echo_count := int(_state.get(&"last_echo_combo_count", 0))
	if echo_count > 0:
		_draw_pips(echo_count, echo_count, radius)


func _draw_pips(lit: int, total: int, radius: float) -> void:
	if total <= 0:
		return
	var origin := Vector2(-(total - 1) * PIP_SPACING * 0.5, -radius - 14.0)
	for index: int in range(total):
		var color := PIP_ON_COLOR if index < lit else PIP_OFF_COLOR
		draw_circle(
			origin + Vector2(index * PIP_SPACING, 0.0),
			PIP_RADIUS,
			color
		)


## 오각별 하나를 그립니다. 브로치의 '별 팔' 점등 표시에 사용합니다.
func _draw_star(center: Vector2, outer_radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(10):
		var is_outer := index % 2 == 0
		var point_radius := (
			outer_radius
			if is_outer
			else outer_radius * STAR_INNER_RATIO
		)
		var angle := -PI * 0.5 + TAU * float(index) / 10.0
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(STAR_EDGE_COLOR, color.a * 0.8), 1.0)
