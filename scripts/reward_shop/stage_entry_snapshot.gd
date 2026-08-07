class_name StageEntrySnapshot
extends Resource


## 스테이지 입장 시점의 세션 상태 스냅샷입니다. (기획서 10-1, 10-2)
##
## 실패 시 구매·소비를 개별 역산하지 않고 이 스냅샷 전체를 복원합니다.
##   - coin_balance: 입장 시점 지갑 잔액
##   - unlocked_ball_ids: 입장 시점 해금 공 목록
##   - part_counts: 입장 시점 부품 종류별 수량 (미사용분 이월 포함)


@export var snapshot_id: StringName = &""
@export var coin_balance: int = 0
@export var unlocked_ball_ids: Array[StringName] = []
@export var part_counts: Dictionary = {}


static func capture(
	snapshot_name: StringName,
	wallet: CoinWallet,
	stage_balls: StageBallInventory,
	parts: RepairPartInventory
) -> StageEntrySnapshot:
	var snapshot := StageEntrySnapshot.new()
	snapshot.snapshot_id = snapshot_name
	snapshot.coin_balance = wallet.balance if wallet != null else 0
	snapshot.unlocked_ball_ids = (
		stage_balls.unlocked_ids if stage_balls != null
		else [] as Array[StringName]
	)
	snapshot.part_counts = parts.snapshot() if parts != null else {}
	return snapshot
