class_name RepairEffectRouter
extends Node


## 수리 부품 발동의 중앙 라우터입니다.
## 각 부품 런타임의 PRIMARY 접촉을 계열별 효과 클래스로 전달하고,
## 모든 2차 타격을 어댑터를 통해 한 곳에서 적립해 재귀 발동을 차단합니다.
## 효과 처리 순서: 접촉 중복 제거 → 기본 콤보 타격(기존 파이프라인) →
## 부품 상태 갱신 → 2차 효과 → 피드백.

signal part_primary_triggered(
	part: Node,
	ball: RigidBody2D,
	family: int,
	rank: int
)
signal part_secondary_triggered(part_id: StringName, effect_type: int)
signal repair_finish_completed(ball: RigidBody2D, bonus_weight: float)
signal stitch_completed(
	ball: RigidBody2D,
	target_part: Node,
	bonus_weight: float
)
signal bell_echo_scheduled(ball: RigidBody2D, delay: float)
signal bell_echo_fired(ball_id: int, bonus_weight: float)
signal gear_overdrive_fired(
	part: Node,
	ball: RigidBody2D,
	speed_before: float,
	speed_after: float
)


@export var combo_adapter_path: NodePath = NodePath("")
@export var ball_adapter_path: NodePath = NodePath("")
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
	for runtime: Node in get_tree().get_nodes_in_group(
		RepairPartRuntime.RUNTIME_GROUP
	):
		register_part(runtime as RepairPartRuntime)


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
	assert(context.trigger_kind != RepairEffectContext.TriggerKind.PRIMARY)
	context.can_trigger_parts = false
	var registered := (
		_combo_adapter != null
		and _combo_adapter.register_secondary_hit(context, score_weight)
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


func notify_stitch_completed(
	_needle: RepairPartRuntime,
	ball: RigidBody2D,
	target_part: RepairPartRuntime,
	bonus_weight: float
) -> void:
	stitch_completed.emit(ball, target_part, bonus_weight)


func notify_bell_echo_scheduled(
	_bell: RepairPartRuntime,
	ball: RigidBody2D,
	delay: float
) -> void:
	bell_echo_scheduled.emit(ball, delay)


func notify_bell_echo_fired(
	_bell: RepairPartRuntime,
	ball_id: int,
	bonus_weight: float
) -> void:
	bell_echo_fired.emit(ball_id, bonus_weight)


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
	part_primary_triggered.emit(
		runtime,
		ball,
		runtime.get_family(),
		runtime.current_rank
	)

	# 1) 자기 부품 상태 갱신 (톱니 가속·방울 예약·바늘 대기·브로치 표식/완성)
	var own_effect := get_effect_for(runtime)
	if own_effect != null:
		own_effect.on_own_primary(ball, context, _now)

	# 2) 다른 부품의 교차 판정 (바늘 봉합 성공·브로치 방문 점등)
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
	for runtime: Node in get_tree().get_nodes_in_group(
		RepairPartRuntime.RUNTIME_GROUP
	):
		(runtime as RepairPartRuntime).reset_transient()


func _create_effect(family: int) -> RepairPartEffect:
	match family:
		RepairPartDefinition.Family.BROOCH:
			return RepairBroochEffect.new()
		RepairPartDefinition.Family.GEAR:
			return RepairGearEffect.new()
		RepairPartDefinition.Family.NEEDLE:
			return RepairNeedleEffect.new()
		RepairPartDefinition.Family.BELL:
			return RepairBellEffect.new()
	return null
