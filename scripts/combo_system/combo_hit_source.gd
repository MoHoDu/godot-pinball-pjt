class_name ComboHitSource
extends Node


signal valid_hit_registered(source: Node, contact_id: int, score_weight: float)
signal contact_released(source: Node, contact_id: int)


## 보드와 로그에서 이 타격 소스를 식별하는 값입니다.
@export var source_id: StringName = &""

## stage_base_score에 곱하는 상대 점수 가중치입니다.
@export_range(0.0, 100.0, 0.05, "suffix:x")
var score_weight: float = 1.0:
	set(value):
		score_weight = maxf(value, 0.0)

## 파괴·복구 대기 중에는 false로 전환해 타격 등록을 막습니다.
@export var is_active: bool = true:
	set(value):
		if is_active == value:
			return
		is_active = value
		if not is_active:
			reset_contacts()


var _active_contacts: Dictionary = {}


## 새로운 접촉만 한 번 등록합니다. 같은 contact_id는 분리 전까지 중복됩니다.
func register_contact(contact_id: int) -> bool:
	if not is_active or _active_contacts.has(contact_id):
		return false

	_active_contacts[contact_id] = true
	valid_hit_registered.emit(self, contact_id, score_weight)
	return true


## 실제 분리 시 호출하면 같은 대상의 다음 접촉을 새 타격으로 인정할 수 있습니다.
func release_contact(contact_id: int) -> bool:
	if not _active_contacts.erase(contact_id):
		return false
	contact_released.emit(self, contact_id)
	return true


func reset_contacts() -> void:
	var contact_ids := _active_contacts.keys()
	_active_contacts.clear()
	for contact_id: int in contact_ids:
		contact_released.emit(self, contact_id)


func has_active_contact(contact_id: int) -> bool:
	return _active_contacts.has(contact_id)


func get_active_contact_count() -> int:
	return _active_contacts.size()
