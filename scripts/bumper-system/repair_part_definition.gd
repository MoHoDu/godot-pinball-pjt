@tool
class_name RepairPartDefinition
extends Resource


enum RepairPartKind {
	STARLIGHT_BROOCH,
	GOLDEN_GEARS,
	CRESCENT_NEEDLE,
	FORGOTTEN_STAR_BELL,
}

enum MechanicsStatus {
	CONCEPT_ONLY,
	IMPLEMENTED,
}


@export var repair_part_id: StringName = &"repair_part"
@export var display_name: String = "Repair Part"
@export var kind: RepairPartKind = RepairPartKind.STARLIGHT_BROOCH
@export var concept_role: String = ""
@export var theme_keywords: PackedStringArray = PackedStringArray()
@export var mechanics_status: MechanicsStatus = MechanicsStatus.CONCEPT_ONLY


func is_valid() -> bool:
	return not repair_part_id.is_empty() and not display_name.is_empty()

