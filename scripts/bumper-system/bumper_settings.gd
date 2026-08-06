@tool
class_name BumperSettings
extends Resource


enum BumperType {
	NORMAL,
	BOUNCE,
	TRACK,
	SHOT,
}

enum MechanicsStatus {
	CONCEPT_ONLY,
	IMPLEMENTED,
}


@export_storage var object_settings := BumperObjectSettings.new():
	set(value):
		_disconnect_nested_settings(object_settings)
		object_settings = value if value != null else BumperObjectSettings.new()
		_connect_nested_settings(object_settings)
		emit_changed()
@export_storage var common_settings := BumperCommonSettings.new():
	set(value):
		_disconnect_nested_settings(common_settings)
		common_settings = value if value != null else BumperCommonSettings.new()
		_connect_nested_settings(common_settings)
		emit_changed()
@export_storage var type_settings := BumperTypeSettings.new():
	set(value):
		_disconnect_nested_settings(type_settings)
		type_settings = value if value != null else BumperTypeSettings.new()
		_connect_nested_settings(type_settings)
		emit_changed()

# 기존 .tres 직렬화 필드를 새 하위 설정 리소스로 마이그레이션하는 호환 속성입니다.
@export_storage var bumper_kind_id: StringName = &"bumper":
	get: return common_settings.bumper_kind_id
	set(value): common_settings.bumper_kind_id = value
@export_storage var display_name := "Bumper":
	get: return common_settings.display_name
	set(value): common_settings.display_name = value
@export_storage var bumper_type: BumperType = BumperType.NORMAL:
	get: return type_settings.bumper_type as BumperType
	set(value): type_settings.bumper_type = value
@export_storage var is_repair_part := false:
	get: return common_settings.is_repair_part
	set(value): common_settings.is_repair_part = value
@export_storage var mechanics_status: MechanicsStatus = MechanicsStatus.IMPLEMENTED:
	get: return common_settings.mechanics_status as MechanicsStatus
	set(value): common_settings.mechanics_status = value
@export_storage var concept_role := "":
	get: return common_settings.concept_role
	set(value): common_settings.concept_role = value
@export_storage var theme_keywords := PackedStringArray():
	get: return common_settings.theme_keywords
	set(value): common_settings.theme_keywords = value
@export_storage var base_score := 100:
	get: return common_settings.base_score
	set(value): common_settings.base_score = value
@export_storage var score_weight := 1.0:
	get: return common_settings.score_weight
	set(value): common_settings.score_weight = value
@export_storage var max_durability := 1:
	get: return common_settings.max_durability
	set(value): common_settings.max_durability = value
@export_storage var durability_damage_per_hit := 1:
	get: return common_settings.durability_damage_per_hit
	set(value): common_settings.durability_damage_per_hit = value
@export_storage var respawn_delay := 3.0:
	get: return common_settings.respawn_delay
	set(value): common_settings.respawn_delay = value
@export_storage var respawn_telegraph_duration := 0.4:
	get: return common_settings.respawn_telegraph_duration
	set(value): common_settings.respawn_telegraph_duration = value
@export_storage var speed_multiplier := 1.0:
	get: return type_settings.speed_multiplier
	set(value): type_settings.speed_multiplier = value
@export_storage var minimum_release_speed := 0.0:
	get: return type_settings.minimum_release_speed
	set(value): type_settings.minimum_release_speed = value
@export_storage var maximum_response_speed := 1540.0:
	get: return type_settings.maximum_response_speed
	set(value): type_settings.maximum_response_speed = value
@export_storage var selection_duration := 0.8:
	get: return type_settings.selection_duration
	set(value): type_settings.selection_duration = value
@export_storage var launch_speed := 1300.0:
	get: return type_settings.launch_speed
	set(value): type_settings.launch_speed = value
@export_storage var shot_launch_directions: Array[ShotLaunchAnchor] = []:
	get: return type_settings.shot_launch_directions
	set(value): type_settings.shot_launch_directions = value
@export_storage var track_target_offset := Vector2.ZERO:
	get: return type_settings.track_target_offset
	set(value): type_settings.track_target_offset = value
@export_storage var collision_diameter := 88.0:
	get: return object_settings.collision_diameter
	set(value): object_settings.collision_diameter = value
@export_storage var visual_diameter := 92.0:
	get: return object_settings.visual_diameter
	set(value): object_settings.visual_diameter = value
@export_storage var respawn_safe_margin := 40.0:
	get: return object_settings.respawn_safe_margin
	set(value): object_settings.respawn_safe_margin = value
@export_storage var maximum_per_board := 0:
	get: return object_settings.maximum_per_board
	set(value): object_settings.maximum_per_board = value
@export_storage var presentation: BumperPresentationSettings:
	get: return object_settings.presentation
	set(value): object_settings.presentation = value


func is_reward_candidate() -> bool:
	return common_settings.is_repair_part


func _connect_nested_settings(nested: Resource) -> void:
	if nested != null and not nested.changed.is_connected(_on_nested_settings_changed):
		nested.changed.connect(_on_nested_settings_changed)


func _disconnect_nested_settings(nested: Resource) -> void:
	if nested != null and nested.changed.is_connected(_on_nested_settings_changed):
		nested.changed.disconnect(_on_nested_settings_changed)


func _on_nested_settings_changed() -> void:
	emit_changed()


func is_valid() -> bool:
	return (
		object_settings != null
		and common_settings != null
		and type_settings != null
		and object_settings.is_valid()
		and common_settings.is_valid()
		and type_settings.is_valid()
	)
