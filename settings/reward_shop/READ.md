# 보상 상점 설정

메뉴 경로: `Pinball > Game Settings > Reward Shop`

- `RewardShopCatalog_Stage01.tres`: 상점에 등장할 공·부품 카드 목록과 가격
- `RewardBallSceneMap_Stage01.tres`: `ball_id`에서 실제 공 프리팹으로 가는 매핑
- `RepairPartSceneMap_Stage01.tres`: `part_id`에서 실제 장착 부품 프리팹으로 가는 매핑
- `WaveShopBumperLayout_Demo.tres`: 상점·배치 데모용 범퍼 레이아웃

카탈로그 ID, 표시 이름, 프리팹 매핑의 Dictionary 키가 정확히 같아야 합니다. 새 상품은 카탈로그와 SceneMap을 함께 추가하고 구매 후 다음 웨이브까지 유지되는지 확인하세요.
