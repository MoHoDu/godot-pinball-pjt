class_name RepairPartInventoryEntry
extends Resource


@export var settings: BumperSettings
@export var placeable_scene: PackedScene
@export_range(0, 99, 1) var starting_count := 0
@export_multiline var one_line_feature := ""
@export var placeholder_icon := "?"


func is_valid() -> bool:
	return settings != null \
		and settings.is_repair_part \
		and not settings.bumper_kind_id.is_empty() \
		and placeable_scene != null \
		and starting_count >= 0


func get_kind_id() -> StringName:
	return settings.bumper_kind_id if settings != null else &""

