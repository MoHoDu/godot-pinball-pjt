class_name RepairBoardControllerV02
extends RepairBoardController


## 동시 배치 상한을 기획서 v0.2(9-1)의 6개로 넓힌 보드 컨트롤러입니다.
##
## 기존 RepairBoardController는 수정하지 않습니다. mount_part_at()이
## can_mount_more()를 거치므로 이 오버라이드만으로 상한이 바뀝니다.


const MAX_PLACED_PARTS_V02 := 6


func can_mount_more() -> bool:
	return get_equipped_count() < MAX_PLACED_PARTS_V02
