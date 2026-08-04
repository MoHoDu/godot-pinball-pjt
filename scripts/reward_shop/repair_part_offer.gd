class_name RepairPartOffer
extends Resource


## 보상 상점의 수리 부품 카드 한 장입니다. (기획서 4-3, 10-2)
##
## 랭크가 없으므로 카드는 "묶음 수량 × 가격"만 다룹니다.
## 부품의 실제 보드 효과는 부품 시스템 단계에서 연결합니다.


@export var part_id: StringName = &"part"
@export var display_name: String = "수리 부품"

## 구매 시 인벤토리에 더해지는 수량입니다. x2 · 12코인처럼 한 줄로 표시합니다.
@export_range(1, 9, 1) var bundle_count := 1
@export var price := 9

## 대표 동사(5-3). 완성한다 / 감고 터뜨린다 / 잇는다 / 늦게 울린다.
@export var verb_text := ""
## 발동 조건을 행동 중심으로 설명합니다.
@export_multiline var condition_text := ""
## 스테이지 01 고정 효과 설명(8-3).
@export_multiline var effect_text := ""

## 단독으로 효과를 낼 수 있는 부품인지(6-2). 보상 1 구성 보장에 씁니다.
@export var works_standalone := true

## 다른 부품과의 연결을 요구하는 부품인지(6-2). 보상 2 이후 구성 보장에 씁니다.
@export var needs_partner := false


func is_valid() -> bool:
	return part_id != &"" and price > 0 and bundle_count > 0
