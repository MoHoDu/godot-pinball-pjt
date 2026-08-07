class_name RepairEffectRouter
extends Node


## 수리 부품 발동의 중앙 라우터입니다.
## 각 부품 런타임의 PRIMARY 접촉을 계열별 효과 클래스로 전달하고,
## 모든 2차 타격을 어댑터를 통해 한 곳에서 적립해 재귀 발동을 차단합니다.
## 효과 처리 순서: 접촉 중복 제거 → 기본 콤보 타격(기존 파이프라인) →
## 부품 상태 갱신 → 2차 효과 → 피드백.

signal part_primary_triggered(part: Node, ball: RigidBody2D, family: int)
signal part_secondary_triggered(part_id: StringName, effect_type: int)
signal repair_finish_completed(ball: RigidBody2D, bonus_weight: float)
signal bell_echo_scheduled(ball: RigidBody2D, delay: float)
## 여운이 실제로 추가한 콤보 횟수입니다(정수).
signal bell_echo_fired(ball_id: int, bonus_combo_count: int)
signal gear_overdrive_fired(
	part: Node,
	ball: RigidBody2D,
	speed_before: float,
	speed_after: float
)


@export var combo_adapter_path: NodePath = NodePath("")
@export var ball_adapter_path: NodePath = NodePath("")
## 비워 두면 기존 호환 동작대로 SceneTree 전체에서 부품을 찾습니다.
## 여러 웨이브 런타임이 상속으로 겹치는 씬에서는 각 보드 루트를 지정합니다.
@export var runtime_root_path: NodePath = NodePath("")
## true면 물리 프레임마다 내부 시계를 진행합니다. 테스트에서는 끄고
## advance_time을 직접 호출할 수 있습니다.
@export var auto_advance: bool = true


var _combo_adapter: RepairComboAdapter = null
var _ball_adapter: RepairBallAdapter = null
var _effects: Dictionary = {}
var _now: float = 0.0


func _ready() -> void:
	_combo_adapter = get_node_or_null(combo_adapter_path) as RepairComboAdapter
	_ball_adapter = get_node_or_null(ball_adapter_path) as RepairBallAdapter
	call_deferred(&"rescan_parts")


func _physics_process(delta: float) -> void:
	if auto_advance:
		advance_time(delta)


## 트리에서 부품 런타임을 다시 수집해 효과를 만들고 시그널을 연결합니다.
func rescan_parts() -> void:
	if not is_inside_tree():
		return
	for runtime: RepairPartRuntime in _get_scoped_runtimes():
		register_part(runtime)


func register_part(runtime: RepairPartRuntime) -> void:
	if runtime == null or _effects.has(runtime.get_instance_id()):
		return
	var effect := _create_effect(runtime.get_family())
	if effect == null:
		return
	effect.setup(runtime, self)
	_effects[runtime.get_instance_id()] = effect
	if not runtime.part_primary_triggered.is_connected(_on_part_primary):
		runtime.part_primary_triggered.connect(_on_part_primary)
	if not runtime.part_response_resolved.is_connected(
		_on_part_response_resolved
	):
		runtime.part_response_resolved.connect(_on_part_response_resolved)
	if not runtime.tree_exiting.is_connected(_on_part_exiting):
		runtime.tree_exiting.connect(_on_part_exiting.bind(runtime))


func get_combo_adapter() -> RepairComboAdapter:
	return _combo_adapter


func get_ball_adapter() -> RepairBallAdapter:
	return _ball_adapter


func get_now() -> float:
	return _now


func get_effect_for(runtime: RepairPartRuntime) -> RepairPartEffect:
	if runtime == null:
		return null
	return _effects.get(runtime.get_instance_id()) as RepairPartEffect


## 테스트와 일시정지에 독립적으로 시간 창·지연 발동을 진행합니다.
func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	_now += delta
	for effect: RepairPartEffect in _effects.values():
		effect.tick(_now)


## 모든 2차 타격의 단일 통로입니다. PRIMARY는 거부하고 재귀를 차단합니다.
func dispatch_secondary(
	context: RepairEffectContext,
	score_weight: float
) -> bool:
	return dispatch_secondary_combo_hits(context, 1, score_weight) > 0


## 2차 타격으로 콤보를 한 번에 여러 번 적립합니다(방울 여운).
## 실제로 적립한 콤보 횟수를 반환합니다.
func dispatch_secondary_combo_hits(
	context: RepairEffectContext,
	hit_count: int,
	score_weight_each: float
) -> int:
	assert(context.trigger_kind != RepairEffectContext.TriggerKind.PRIMARY)
	context.can_trigger_parts = false
	var registered := 0
	if _combo_adapter != null:
		registered = _combo_adapter.register_secondary_combo_hits(
			context,
			hit_count,
			score_weight_each
		)
	part_secondary_triggered.emit(context.source_part_id, context.trigger_kind)
	return registered


## 상태 초기화 규칙(기획서 9장): 공 낙하.
func on_ball_drained() -> void:
	_reset_all_transient()


## 상태 초기화 규칙: 새 공 발사.
func on_new_ball() -> void:
	_reset_all_transient()


## 상태 초기화 규칙: 웨이브 종료.
func on_wave_ended() -> void:
	_reset_all_transient()


## 상태 초기화 규칙: 웨이브 재시도·부품 재배치. 랭크와 장착 정보는 유지합니다.
func on_full_reset() -> void:
	_reset_all_transient()
	_now = 0.0


func notify_finish_completed(
	_part: RepairPartRuntime,
	ball: RigidBody2D,
	bonus_weight: float
) -> void:
	repair_finish_completed.emit(ball, bonus_weight)


func notify_bell_echo_scheduled(
	_bell: RepairPartRuntime,
	ball: RigidBody2D,
	delay: float
) -> void:
	bell_echo_scheduled.emit(ball, delay)


func notify_bell_echo_fired(
	_bell: RepairPartRuntime,
	ball_id: int,
	bonus_combo_count: int
) -> void:
	bell_echo_fired.emit(ball_id, bonus_combo_count)


func notify_gear_overdrive(
	part: RepairPartRuntime,
	ball: RigidBody2D,
	speed_before: float,
	speed_after: float
) -> void:
	gear_overdrive_fired.emit(part, ball, speed_before, speed_after)


func _on_part_primary(runtime: RepairPartRuntime, ball: RigidBody2D) -> void:
	var context := RepairEffectContext.make_primary(
		runtime.get_part_id(),
		runtime.get_family(),
		ball.get_instance_id()
	)
	part_primary_triggered.emit(runtime, ball, runtime.get_family())

	# 1) 자기 부품 상태 갱신 (톱니 가속·방울 예약·브로치 표식/완성)
	var own_effect := get_effect_for(runtime)
	if own_effect != null:
		own_effect.on_own_primary(ball, context, _now)

	# 2) 다른 부품의 교차 판정 (브로치 방문 점등)
	for effect: RepairPartEffect in _effects.values():
		if effect == own_effect:
			continue
		effect.on_other_primary(runtime, ball, context, _now)


func _on_part_response_resolved(
	runtime: RepairPartRuntime,
	ball: RigidBody2D
) -> void:
	# 범퍼의 최종 충돌 반응이 공에 적용된 뒤에만 톱니 가속을 합성합니다.
	var effect := get_effect_for(runtime)
	if effect != null:
		effect.on_own_response_resolved(ball, _now)


func _on_part_exiting(runtime: RepairPartRuntime) -> void:
	_effects.erase(runtime.get_instance_id())


func _reset_all_transient() -> void:
	for effect: RepairPartEffect in _effects.values():
		effect.reset_transient()
	for runtime: RepairPartRuntime in _get_scoped_runtimes():
		runtime.reset_transient()


func _get_scoped_runtimes() -> Array[RepairPartRuntime]:
	var runtimes: Array[RepairPartRuntime] = []
	if not is_inside_tree():
		return runtimes
	var runtime_root: Node
	if not runtime_root_path.is_empty():
		runtime_root = get_node_or_null(runtime_root_path)
		if runtime_root == null:
			return runtimes
	for candidate: Node in get_tree().get_nodes_in_group(
		RepairPartRuntime.RUNTIME_GROUP
	):
		if not candidate is RepairPartRuntime:
			continue
		if runtime_root != null \
				and candidate != runtime_root \
				and not runtime_root.is_ancestor_of(candidate):
			continue
		runtimes.append(candidate as RepairPartRuntime)
	return runtimes


func _create_effect(family: int) -> RepairPartEffect:
	match family:
		RepairPartDefinition.Family.BROOCH:
			return RepairBroochEffect.new()
		RepairPartDefinition.Family.GEAR:
			return RepairGearEffect.new()
		RepairPartDefinition.Family.BELL:
			return RepairBellEffect.new()
	return null
