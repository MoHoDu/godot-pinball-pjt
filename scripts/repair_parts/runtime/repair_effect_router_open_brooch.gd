class_name RepairEffectRouterOpenBrooch
extends RepairEffectRouter
## 브로치 완화 룰용 라우터 확장 (2026-08-10 형락님 확정).
## BROOCH 계열만 RepairBroochAnyBumperEffect(반원 제외 아무 범퍼 2개로 완성)를
## 쓰고, 나머지 계열은 기존 생성 규칙을 그대로 따른다.
## 기존 repair_effect_router.gd 는 수정하지 않았다.


func _create_effect(family: int) -> RepairPartEffect:
	if family == RepairPartDefinition.Family.BROOCH:
		return RepairBroochAnyBumperEffect.new()
	return super._create_effect(family)
