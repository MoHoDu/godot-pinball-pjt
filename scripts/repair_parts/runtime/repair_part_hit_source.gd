class_name RepairPartHitSource
extends ComboHitSource


## 수리 부품용 접촉 소스입니다. ComboHitSource의 접촉 중복 제거에 더해
## 직전 발동 후 최소 간격(기본 0.12초)을 지난 새 접촉만 유효 접촉으로 인정합니다.
## 부품 씬에서 기존 ComboHitSource 노드의 스크립트를 이 클래스로 교체해 사용합니다.

signal part_contact_registered(contact_id: int)


const DEFAULT_MINIMUM_TRIGGER_INTERVAL := 0.12


## 직전 유효 접촉 후 이 시간이 지나야 다음 접촉을 인정합니다.
@export_range(0.0, 5.0, 0.01, "suffix:s")
var minimum_trigger_interval: float = DEFAULT_MINIMUM_TRIGGER_INTERVAL:
	set(value):
		minimum_trigger_interval = maxf(value, 0.0)


var _last_trigger_physics_frame: int = -1


## 접촉 중복 제거를 통과해도 최소 간격이 지나지 않았다면 거부합니다.
## 거부되면 기본 콤보 타격과 부품 발동이 모두 일어나지 않습니다.
## 간격은 물리 프레임 기준이라 배속·일시정지와 무관하게 게임 시간과 일치합니다.
func register_contact(contact_id: int) -> bool:
	if not _has_interval_elapsed():
		return false
	if not super.register_contact(contact_id):
		return false
	_last_trigger_physics_frame = Engine.get_physics_frames()
	part_contact_registered.emit(contact_id)
	return true


func reset_trigger_interval() -> void:
	_last_trigger_physics_frame = -1


func _has_interval_elapsed() -> bool:
	if _last_trigger_physics_frame < 0:
		return true
	var interval_frames := int(ceil(
		minimum_trigger_interval * Engine.physics_ticks_per_second
	))
	var elapsed_frames := (
		Engine.get_physics_frames() - _last_trigger_physics_frame
	)
	return elapsed_frames >= interval_frames
