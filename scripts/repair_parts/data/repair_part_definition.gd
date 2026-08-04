@tool
class_name RepairPartDefinition
extends Resource


## 수리 부품 하나의 정체성과 랭크별 수치를 정의합니다.
## 부품은 별도 런타임 타입이 아니라 기존 Bumper 프리팹 위에 얹히는 정의 데이터입니다.
## 수리 부품 자격 자체는 BumperSettings.is_repair_part가 단일 출처입니다.

enum Family {
	BROOCH,
	GEAR,
	NEEDLE,
	BELL,
}


const MIN_RANK := 1


@export_category("Identity")
## 보상·인벤토리·배치가 공유하는 안정적인 부품 ID입니다. 출시 후 변경 금지.
@export var part_id: StringName = &""
@export var family: Family = Family.BROOCH
@export var display_name: String = ""
## 이 부품이 사용하는 BumperSettings.bumper_kind_id와 일치해야 합니다.
@export var bumper_kind_id: StringName = &""
## 보상 카드에 쓰는 행동 중심 한 줄 설명입니다.
@export_multiline var action_line: String = ""

@export_category("Ranks")
## 랭크 1부터 순서대로 담습니다. 배열 크기가 최대 랭크입니다.
@export var rank_data: Array[RepairPartRankData] = []


func get_max_rank() -> int:
	return rank_data.size()


func clamp_rank(rank: int) -> int:
	return clampi(rank, MIN_RANK, maxi(get_max_rank(), MIN_RANK))


func get_rank_data(rank: int) -> RepairPartRankData:
	if rank_data.is_empty():
		return null
	return rank_data[clamp_rank(rank) - 1]


func is_valid() -> bool:
	return (
		not part_id.is_empty()
		and not bumper_kind_id.is_empty()
		and not rank_data.is_empty()
	)
