class_name RepairPartFeedback
extends Node2D


## 수리 부품 상태의 최소 피드백입니다 (FlipperParryFeedback 노드 패턴).
## 물리 노드와 분리된 별도 Node2D로, 부품의 위치·회전·크기는 절대 건드리지 않습니다.
## 브로치는 별 팔 두 개, 톱니는 회전 단계 세 칸, 바늘은 실, 방울은 원형 파동으로
## 상태를 구분하고, 이름·긴 설명은 보드 위에 표시하지 않습니다.


const READY_RING_COLOR := Color(0.94, 0.78, 0.35, 0.55)
const PIP_ON_COLOR := Color(0.98, 0.86, 0.45, 0.9)
const PIP_OFF_COLOR := Color(0.35, 0.33, 0.3, 0.6)
const THREAD_COLOR := Color(0.55, 0.9, 0.85, 0.85)
const WAVE_COLOR := Color(0.75, 0.92, 0.9, 0.6)
const PIP_RADIUS := 5.0
const PIP_SPACING := 16.0
const STATE_Z_INDEX := 12


var _runtime: RepairPartRuntime = null
var _state: Dictionary = {}


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


func _process(_delta: float) -> void:
	if _runtime == null or _runtime.bumper == null:
		return
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
		draw_arc(
			Vector2.ZERO, radius, 0.0, TAU, 40, READY_RING_COLOR, 2.0
		)

	match int(_state.get(&"family", -1)):
		RepairPartDefinition.Family.BROOCH:
			_draw_pips(int(_state.get(&"lit_arms", 0)), 2, radius)
		RepairPartDefinition.Family.GEAR:
			_draw_pips(int(_state.get(&"wind_stack", 0)), 3, radius)
		RepairPartDefinition.Family.NEEDLE:
			if int(_state.get(&"pending_count", 0)) > 0:
				draw_line(
					Vector2.ZERO,
					Vector2(0.0, -radius - 18.0),
					THREAD_COLOR,
					2.0
				)
		RepairPartDefinition.Family.BELL:
			var remaining := float(_state.get(&"echo_remaining", 0.0))
			if remaining > 0.0:
				draw_arc(
					Vector2.ZERO,
					radius + 10.0,
					0.0,
					TAU,
					40,
					WAVE_COLOR,
					2.0
				)


func _draw_pips(lit: int, total: int, radius: float) -> void:
	var origin := Vector2(
		-(total - 1) * PIP_SPACING * 0.5,
		-radius - 14.0
	)
	for index: int in range(total):
		var color := PIP_ON_COLOR if index < lit else PIP_OFF_COLOR
		draw_circle(
			origin + Vector2(index * PIP_SPACING, 0.0),
			PIP_RADIUS,
			color
		)
