@tool
class_name StageInitialRepairPartEntry
extends Resource


## 스테이지 씬 Inspector에서 초기 수리 부품 프리팹과 수량을 구성합니다.
@export var settings: BumperSettings
@export var part_prefab: PackedScene
@export_range(0, 99, 1) var starting_count := 0
@export_multiline var one_line_feature := ""
@export var placeholder_icon := "?"


func is_valid() -> bool:
	return settings != null \
		and settings.is_repair_part \
		and not settings.bumper_kind_id.is_empty() \
		and part_prefab != null \
		and starting_count >= 0


func is_placeable_prefab() -> bool:
	if part_prefab == null:
		return false
	var instance := part_prefab.instantiate()
	var result := instance is BoardPlaceable
	instance.free()
	return result


func make_inventory_entry() -> RepairPartInventoryEntry:
	if not is_valid():
		return null
	var entry := RepairPartInventoryEntry.new()
	entry.settings = settings
	entry.placeable_scene = part_prefab
	entry.starting_count = starting_count
	entry.one_line_feature = one_line_feature
	entry.placeholder_icon = placeholder_icon
	return entry
