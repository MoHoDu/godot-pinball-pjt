# 보드 배치 시스템

이 디렉터리의 씬은 기존 웨이브/범퍼 씬을 수정하지 않고 보드 배치 기능을 독립적으로 실행하고 검증하기 위한 전용 씬입니다.

## 씬

- `board_system_demo.tscn`: 보드 경계, 영역, 12개 후보 소켓, 금지 영역, 수리 부품 6개를 독립적으로 확인하는 씬입니다.
- `board_system_wave_integration.tscn`: 기존 `scenes/wave/wave.tscn`과 `BoardWavePlacementBridge`를 합성한 연결 검증 씬입니다.

## 에디터 작업 순서

1. `Resources/boards/square_board_layout.tscn`을 엽니다.
2. `Boundary` 또는 `Zones` 아래 `Polygon2D`를 선택하고 Godot의 폴리곤 편집 도구로 점을 마우스로 이동합니다.
3. `Sockets` 아래 `BoardPlacementSocket`을 144px 격자에 맞춰 이동합니다. 소켓 예약 반경 기본값은 72px입니다.
4. `Resources/boards/*_placeable.tscn` 프리팹을 `Placeables` 아래에 배치하고 `zone_id`, `socket_id`를 지정합니다.
5. 저장할 때는 `BoardLayout` Inspector의 `Validate & Save` 버튼을 사용합니다. 검증 실패 시 저장을 실행하지 않습니다. `run_validation_before_save` 수동 preflight와 Inspector 경고도 동일한 검증기를 사용합니다.

검증 실패 상태에서는 `BoardPlacementSession.commit()`이 거부되므로 첫 공 선택 잠금이 풀리지 않습니다.

런타임 편집 중에는 숫자 1~4로 부품을 고르고 빈 소켓을 좌클릭해 추가합니다. 기존 부품을 좌클릭한 다음 다른 소켓을 좌클릭하면 이동하며, 우클릭하면 인벤토리로 회수합니다. 커밋 이후에는 세 API가 모두 거부되고 배치물 transform도 커밋 위치로 복원됩니다.

## 강제 규칙

- 보드 경계는 기획 좌표를 중심 원점으로 변환한 2240×1260 월드 캔버스의 8각형입니다.
- 영역, 소켓의 전체 예약 반경, 생성되는 격자점은 보드 내부에 있어야 합니다. 모든 배치물은 활성 소켓을 지정하고 격자에 정렬해야 합니다.
- 현재 기획 규칙은 144px 격자, 후보 소켓 12개, 동시 배치 최대 6개로 코드 상수로 고정되어 Inspector에서 우회할 수 없습니다.
- 보스, 범퍼/장치, 플리퍼 스윕, 발사/조준, 드레인, 벽 모서리 같은 공간은 `BoardForbiddenArea`로 예약합니다.
- 배치 프리팹은 `Bumper` 하위 노드를 포함하고 `settings.is_repair_part == true`여야 합니다.
- 첫 발사 전에는 편집할 수 있고, 커밋 후에는 해당 웨이브 동안 잠깁니다.

## 확장 지점

- 영역별 허용 부품은 `BoardPlacementZone.allowed_kind_ids`로 제한합니다.
- 추가 금지 영역은 `BoardForbiddenArea` 폴리곤과 여유 반경으로 정의합니다.
- 런타임 인벤토리는 `placement_committed(wave_id, placements, consumed_counts)` 신호에 연결합니다.
- 다른 웨이브 구현은 `BoardWavePlacementBridge` 대신 같은 `BoardPlacementSession` 공개 API만 사용해 연결할 수 있습니다.

관련 기획서:

- [공/보드 시스템 기획서](https://docs.google.com/document/d/1ryazSYd1k1NmgsNz6iqHspCRaZSEBfOWXoJV1XC9GLM/edit?usp=sharing)
- [보상·수리 부품·배치 시스템 기획서](https://docs.google.com/document/d/1lCrcWxu-3JJLqECY19CDutHmuYWE7X4Kqa3sv8WAgvI/edit?tab=t.0)
