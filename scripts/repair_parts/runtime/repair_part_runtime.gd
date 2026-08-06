class_name RepairPartRuntime
extends Node


## 보드에 장착된 수리 부품 하나의 런타임입니다.
## 부모 Bumper의 유효 타격 신호와 RepairPartHitSource의 간격 검증을 짝지어
## 실제 물리 접촉(PRIMARY)만 부품 발동으로 바꿉니다.
## RepairPart 같은 별도 Bumper 하위 타입을 만들지 않기 위한 합성 노드입니다.

signal part_primary_triggered(runtime: RepairPartRuntime, ball: RigidBody2D)
signal part_response_resolved(runtime: RepairPartRuntime, ball: RigidBody2D)
signal part_state_changed(runtime: RepairPartRuntime, state: Dictionary)


const RUNTIME_GROUP: StringName = &"repair_part_runtimes"


@export var definition: RepairPartDefinition

## 세션 동안 유지되는 현재 랭크입니다. 공 단위 상태는 여기 두지 않습니다.
@export_range(1, 9, 1) var current_rank: int = 1:
	set(value):
		current_rank = (
			definition.clamp_rank(value)
			if definition != null
			else maxi(value, 1)
		)

## 소켓 장착 여부입니다. 미장착 부품은 발동하지 않습니다.
@export var is_equipped: bool = true


var bumper: Bumper = null
var _pending_contact_id: int = -1
var _display_state: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(RUNTIME_GROUP)


func _ready() -> void:
	bumper = get_parent() as Bumper
	if bumper == null:
		push_warning("RepairPartRuntime은 Bumper의 자식이어야 합니다.")
		return
	if not bumper.valid_hit_registered.is_connected(_on_bumper_valid_hit):
		bumper.valid_hit_registered.connect(_on_bumper_valid_hit)
	if not bumper.response_resolved.is_connected(_on_bumper_response_resolved):
		bumper.response_resolved.connect(_on_bumper_response_resolved)
	var source := bumper.get_node_or_null(^"ComboHitSource")
	if source is RepairPartHitSource:
		var part_source := source as RepairPartHitSource
		if not part_source.part_contact_registered.is_connected(
			_on_part_contact_registered
		):
			part_source.part_contact_registered.connect(
				_on_part_contact_registered
			)


func get_part_id() -> StringName:
	return definition.part_id if definition != null else &""


func get_family() -> int:
	return (
		definition.family
		if definition != null
		else RepairPartDefinition.Family.BROOCH
	)


func get_rank_data() -> RepairPartRankData:
	return definition.get_rank_data(current_rank) if definition != null else null


func is_active_part() -> bool:
	return (
		is_equipped
		and definition != null
		and bumper != null
		and bumper.state == Bumper.BumperState.ACTIVE
	)


## 효과 클래스가 피드백 표시용 상태를 갱신할 때 호출합니다.
func set_display_state(state: Dictionary) -> void:
	_display_state = state.duplicate()
	part_state_changed.emit(self, _display_state)


func get_display_state() -> Dictionary:
	return _display_state.duplicate()


## 공 낙하·웨이브 종료 등에서 접촉·간격 상태를 정리합니다.
func reset_transient() -> void:
	_pending_contact_id = -1
	if bumper == null:
		return
	var source := bumper.get_node_or_null(^"ComboHitSource")
	if source is RepairPartHitSource:
		(source as RepairPartHitSource).reset_trigger_interval()


func _on_part_contact_registered(contact_id: int) -> void:
	# 간격 검증을 통과한 접촉만 기억해 두었다가
	# 곧이어 도착하는 Bumper 유효 타격 신호와 짝지어 공 참조를 얻습니다.
	_pending_contact_id = contact_id


func _on_bumper_valid_hit(
	_bumper_id: StringName,
	ball: RigidBody2D,
	contact_id: int,
	_base_score: int
) -> void:
	if _pending_contact_id != contact_id:
		return
	_pending_contact_id = -1
	if not is_active_part() or not is_instance_valid(ball):
		return
	part_primary_triggered.emit(self, ball)


func _on_bumper_response_resolved(
	_bumper: Bumper,
	ball: RigidBody2D,
	_response: BumperResponse
) -> void:
	if not is_active_part() or not is_instance_valid(ball):
		return
	part_response_resolved.emit(self, ball)
