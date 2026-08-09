class_name RepairPartPlacementHudFolded
extends RepairPartPlacementHud
## 배치 단계 진입 시 인벤토리 서랍을 접힌 상태로 시작한다 (2026-08-10 형락님 확정).
## 보드와 소켓을 먼저 보여주고, 상단 "펼치기" 탭이나 소켓 선택으로 서랍을 연다.
## 원본 repair_part_placement_hud.gd 는 수정하지 않았다 — 프로덕션 웨이브의
## 베이스 씬 인스턴스에만 이 스크립트가 배선된다 (UI 테스트는 원본 동작 유지).


func set_placement_visible(value: bool) -> void:
	super.set_placement_visible(value)
	if value:
		_drawer_open = false
		_set_drawer_position(false)
