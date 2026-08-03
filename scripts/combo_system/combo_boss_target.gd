class_name ComboBossTarget
extends Node


signal boss_reset(current_health: int, max_health: int)
signal boss_hit(
	contact_id: int,
	calculated_damage: int,
	applied_damage: int,
	current_health: int,
	combo_count: int
)
signal health_changed(current_health: int, max_health: int, applied_damage: int)
signal defeated


var _combo_system: Node
var _settings: Resource
var _current_health: int = 0
var _active_contacts: Dictionary = {}
var _is_defeated: bool = false


var current_health: int:
	get:
		return _current_health

var max_health: int:
	get:
		if _settings == null:
			return 0
		return maxi(int(_settings.get(&"max_health")), 1)

var is_defeated: bool:
	get:
		return _is_defeated


func bind_combo_system(combo_system: Node) -> bool:
	if combo_system == null \
			or not combo_system.has_method(&"calculate_base_damage") \
			or not combo_system.has_method(&"register_boss_hit"):
		return false
	_combo_system = combo_system
	return true


func configure_boss(settings: Resource) -> bool:
	if settings == null \
			or not _has_property(settings, &"max_health") \
			or not _has_property(settings, &"target_hit_count"):
		return false
	_settings = settings
	reset_encounter()
	return true


## ball_weight_multiplier는 공 설정에서 전달하는 보스 피해용 무게 계수입니다.
## 새 접촉일 때만 이번 타격을 콤보에 먼저 포함하고 보스 피해를 적용합니다.
func register_contact(contact_id: int, ball_weight_multiplier: float = 1.0) -> int:
	if _combo_system == null \
			or _settings == null \
			or _is_defeated \
			or _active_contacts.has(contact_id):
		return 0
	_active_contacts[contact_id] = true

	var base_damage := float(_combo_system.call(
		&"calculate_base_damage",
		max_health,
		maxi(int(_settings.get(&"target_hit_count")), 1),
		maxf(ball_weight_multiplier, 0.0)
	))
	var calculated_damage := int(_combo_system.call(
		&"register_boss_hit",
		base_damage
	))
	var applied_damage := mini(maxi(calculated_damage, 0), _current_health)
	_current_health -= applied_damage
	health_changed.emit(_current_health, max_health, applied_damage)
	boss_hit.emit(
		contact_id,
		calculated_damage,
		applied_damage,
		_current_health,
		int(_combo_system.get(&"combo_count"))
	)
	if _current_health <= 0 and not _is_defeated:
		_is_defeated = true
		defeated.emit()
	return applied_damage


## PinballStats.mass를 보스 피해 무게 계수로 사용하는 실제 공 설정 연결점입니다.
func register_ball_contact(contact_id: int, ball_stats: Resource) -> int:
	if ball_stats == null or not _has_property(ball_stats, &"mass"):
		return 0
	return register_contact(
		contact_id,
		maxf(float(ball_stats.get(&"mass")), 0.0)
	)


func release_contact(contact_id: int) -> bool:
	if not _active_contacts.has(contact_id):
		return false
	_active_contacts.erase(contact_id)
	return true


func reset_contacts() -> void:
	_active_contacts.clear()


func reset_encounter() -> void:
	_current_health = max_health
	_is_defeated = false
	reset_contacts()
	boss_reset.emit(_current_health, max_health)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get(&"name", &"")) == property_name:
			return true
	return false
