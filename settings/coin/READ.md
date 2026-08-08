# 코인 설정

메뉴 경로: `Pinball > Game Settings > Coin`

- `BasicCoin.tres`: 코인 ID, 표시 이름, 획득 가치, 필드·HUD 이미지
- `CoinSpawnLayout_Stage01.tres`: 좌표 배열 기반 배치가 필요한 테스트·호환 씬용 레이아웃

현재 Stage 01 프로덕션 코인은 씬의 2D 마커 배치를 우선 사용합니다. 코인 가치는 `BasicCoin.tres`에서 바꾸며, 이미지 변경 시 필드 코인과 HUD 이동 연출이 같은 텍스처를 쓰는지 확인하세요.
