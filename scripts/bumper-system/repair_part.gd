@tool
class_name RepairPart
extends Bumper


## 수리 부품은 Bumper의 하위 타입이며 보드에 직접 배치할 수 있습니다.
## 콘셉트 문서에 효과가 정해지기 전까지 임의의 고유 능력은 적용하지 않습니다.
@export_category("Repair Part Identity")
@export var definition: RepairPartDefinition:
	set(value):
		definition = value
		if is_inside_tree():
			update_configuration_warnings()


func get_repair_part_kind() -> int:
	return (
		definition.kind
		if definition != null
		else RepairPartDefinition.RepairPartKind.STARLIGHT_BROOCH
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if definition == null or not definition.is_valid():
		warnings.append("RepairPartDefinition Resource가 필요합니다.")
	return warnings

