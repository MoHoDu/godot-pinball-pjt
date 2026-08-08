# 보드 배치 시스템

보드 배치 기능의 수동 씬과 재사용 프리팹은 역할에 따라 분리되어 있습니다.

## 수동 확인 씬

- `scenes/dev/boards/board_system_demo.tscn`: 보드 경계, 영역, 후보 소켓과 금지 영역을 독립 확인합니다.
- `scenes/tests/boards/board_system_wave_integration.tscn`: 보드 배치와 웨이브 연결을 확인합니다.
- `scenes/tests/boards/repair_part_placement_wave_demo.tscn`: 실제 배치 UI의 장착·해제·교체·확정을 확인합니다.

## 실제 배치 UI 테스트

1. `scenes/tests/boards/repair_part_placement_wave_demo.tscn`을 열고 F6으로 실행합니다.
2. `REPAIR_PLACEMENT`에서 그리드·영역·소켓이 보이는지 확인합니다.
3. 수량이 0인 부품은 카드가 없고, 재고를 추가하거나 부품을 회수하면 카드가 나타나는지 확인합니다.
4. 부품을 장착·교체·회수한 뒤 `배치 확정`을 누릅니다.
5. `BALL_SELECTION`과 `IN_PLAY`에서는 그리드·영역·소켓·금지영역 가이드가 모두 숨겨지는지 확인합니다.

## 에디터 작업 위치

- 독립 보드: `Resources/Prefabs/boards/square_board_layout.tscn`
- 실제 웨이브 보드: `Resources/Prefabs/boards/wave_repair_board_layout.tscn`
- 수리 부품 프리팹: `Resources/Prefabs/repair_parts/placeables/`
- 배치 UI: `Resources/Prefabs/ui/repair_placement/`

`BoardLayout`의 Boundary·Zones·Sockets·ForbiddenAreas를 2D 에디터에서 수정하고, Inspector의 `Validate & Save`로 검증합니다. 현재 규칙은 144px 격자, 후보 소켓 12개, 동시 배치 최대 6개입니다.

자동 검증:

- `tests/board_system/board_system_integration_test.gd`
- `tests/board_system/repair_part_placement_ui_test.gd`

관련 기획서:

- [공/보드 시스템 기획서](https://docs.google.com/document/d/1ryazSYd1k1NmgsNz6iqHspCRaZSEBfOWXoJV1XC9GLM/edit?usp=sharing)
- [보상·수리 부품·배치 시스템 기획서](https://docs.google.com/document/d/1lCrcWxu-3JJLqECY19CDutHmuYWE7X4Kqa3sv8WAgvI/edit?tab=t.0)
