class_name RepairPartSceneMap
extends Resource


## 상점의 부품 part_id를 보드 장착용 부품 씬에 잇는 표입니다.
##
## part_id는 수리 부품 시스템의 정의(settings/repair_parts/*Definition.tres)와
## 같은 id를 씁니다. 부품 씬이 바뀌면 이 표만 바꾸면 됩니다.


@export var display_names: Dictionary = {}

## part_id(StringName) → PackedScene.
@export var scenes: Dictionary = {}


func has_part(part_id: StringName) -> bool:
	return scenes.has(part_id) and scenes[part_id] != null


func scene_of(part_id: StringName) -> PackedScene:
	return scenes.get(part_id, null) as PackedScene


func display_name_of(part_id: StringName) -> String:
	return String(display_names.get(part_id, String(part_id)))


func part_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for part_id: StringName in scenes:
		ids.append(part_id)
	ids.sort()
	return ids
