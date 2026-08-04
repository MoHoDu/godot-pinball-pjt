@tool
class_name RelicDefinition
extends Resource


## 인형사의 수리 부품 한 종을 정의합니다.


@export var relic_id: StringName = &"relic"

@export var display_name: String = "수리 부품"

## 선택 카드 하단에 표시할 컨셉 문구입니다.
@export_multiline var flavor_text: String = ""

@export var effect: RelicEffect

## 같은 부품을 최대 몇 개까지 보유할 수 있는지입니다.
@export_range(1, 9, 1)
var max_stack: int = 3:
	set(value):
		max_stack = maxi(value, 1)
		emit_changed()


func is_valid() -> bool:
	return not relic_id.is_empty() and effect != null


func describe(stack_count: int = 1) -> String:
	if effect == null:
		return ""
	return effect.describe(maxi(stack_count, 1))
