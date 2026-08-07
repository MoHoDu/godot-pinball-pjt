class_name RepairEffectContext
extends RefCounted


## 부품 효과 한 번의 발동 맥락입니다.
## PRIMARY(실제 물리 접촉)만 다른 부품을 발동할 수 있고,
## 코드로 생성된 모든 2차 효과는 can_trigger_parts = false로 고정합니다.

enum TriggerKind {
	PRIMARY,
	SECONDARY_ECHO,
	SECONDARY_FINISH,
}


var trigger_kind: TriggerKind = TriggerKind.PRIMARY
var source_part_id: StringName = &""
var source_family: int = RepairPartDefinition.Family.BROOCH
var ball_instance_id: int = 0
var physics_frame: int = 0
var can_trigger_parts: bool = false


static func make_primary(
	part_id: StringName,
	family: int,
	ball_id: int
) -> RepairEffectContext:
	var context := RepairEffectContext.new()
	context.trigger_kind = TriggerKind.PRIMARY
	context.source_part_id = part_id
	context.source_family = family
	context.ball_instance_id = ball_id
	context.physics_frame = Engine.get_physics_frames()
	context.can_trigger_parts = true
	return context


static func make_secondary(
	kind: TriggerKind,
	part_id: StringName,
	family: int,
	ball_id: int
) -> RepairEffectContext:
	assert(kind != TriggerKind.PRIMARY)
	var context := RepairEffectContext.new()
	context.trigger_kind = kind
	context.source_part_id = part_id
	context.source_family = family
	context.ball_instance_id = ball_id
	context.physics_frame = Engine.get_physics_frames()
	context.can_trigger_parts = false
	return context
