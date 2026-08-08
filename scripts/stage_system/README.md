# Stage system

`StageFlowManager`는 인스펙터에 등록한 씬을 아래 순서로 실행한다.

```text
웨이브 1 → 보상 → ... → 웨이브 N → 보상 → 보스 1 → ... → 보스 N → 완료
```

## 설정

1. `scenes/stage_system/stage_flow_manager.tscn`을 원하는 상위 씬에 추가한다.
2. `wave_scenes`에 일반 웨이브 씬을 실행 순서대로 하나 이상 넣는다.
3. `boss_scenes`에 보스 씬을 실행 순서대로 넣는다. 보스가 아직 없으면 비워 둘 수 있다.
4. 기본 `reward_scene`은 실제 `stage_reward_shop_screen.tscn`이다. 단순 흐름 테스트에는
   `stage_reward_placeholder.tscn`으로 교체할 수 있다.

각 웨이브·보스·보상 씬은 완료 시그널을 루트 또는 자식 노드에 하나 노출해야 한다.
기본으로 인식하는 이름은 다음과 같다.

- 웨이브: `stage_segment_completed`, `wave_completed`, `wave_cleared`, `wave_won`, `stage_completed`, `completed`
- 보스: `stage_segment_completed`, `boss_completed`, `boss_defeated`, `stage_completed`, `completed`
- 보상: `reward_completed`, `continued`, `next_requested`, `completed`

기존 웨이브 씬처럼 `WaveManager.wave_won(score, target)`가 자식 노드에 있는 경우도
인자 수를 자동으로 맞춰 연결한다. 프로젝트별 이름이 다르면 매니저의 완료 시그널 배열을
인스펙터에서 수정한다. 같은 이름의 시그널이 여러 노드에 있으면 루트에서 가까운 노드를
먼저 사용한다.

기본 보상 페이지는 `dev_reward_system`의 `RewardShopController`와 `RewardShopHud`를
사용하는 실제 상점 화면이다. 마지막 일반 웨이브 뒤에도 한 번 표시되며, 확인 화면은
다음 대상에 따라 `다음 웨이브`, `보스 진행`, `스테이지 완료` 문맥을 보여 준다.

`StageFlowManager`는 보상 진행 상태도 소유한다. 구매한 공 종류는 다음 웨이브의
`SelectBallInventory`에, 구매한 수리 부품 수량은 다음 웨이브의 `RepairPartInventory`에
주입한다. 웨이브 실패 시에는 코인·구매 공·구매 부품을 모두 스테이지 시작 상태로 되돌리고
첫 웨이브부터 다시 시작한다. 외부 스테이지 매니저 아래에서는 `wave.tscn`의 내장 보상
브리지를 비활성화하므로 보상 화면이 중복으로 열리지 않는다.

## 코인 연결

`stage_flow_manager.tscn`의 `coin_wallet`은 스테이지 전체가 공유하는 지갑이다.
`StageFlowManager`가 각 웨이브의 `WaveCoinSession`에 이 지갑을 주입하므로 웨이브 씬이
교체되어도 잔액이 유지된다. 게임 오버 또는 스테이지 완료 시에는 0으로 초기화된다.

코인을 사용할 스테이지 웨이브에는 `stage_wave_coin_system.tscn`을 자식으로 추가한다.
이 씬은 코인 필드, 종료 유예 환산, 공용 지갑 연결을 제공하고, 공용 `WaveHud`의
우측 상단 코인 아이콘·보유량 표시를 갱신한다.
실제 보상 상점은 같은 공용 지갑으로 구매를 처리한다. 사용자 정의 보상 씬도
`bind_coin_wallet(wallet)` 메서드를 구현하면 같은 지갑을 전달받을 수 있다.

### 에디터에서 코인 배치

1. 코인이 없는 웨이브에 `stage_wave_coin_system.tscn`을 인스턴스한다.
2. `CoinSystem/SpawnPoints` 아래에 `coin_spawn_point.tscn`을 추가하거나 복제한다.
3. 2D 에디터에서 금색 원형 마커를 원하는 위치로 드래그한다.
4. 인스펙터에서 `point_id`, `route_kind`, 표시 반지름을 수정한다.

빈 `SpawnPoints`는 코인 0개로 유효하다. Stage 01은
최신 `wave.tscn`의 `CoinSystem/SpawnPoints`에 있는 12개 마커를 상속한다. 각
`stage_01_wave_0N.tscn`에서 `CoinSystem`의 편집 가능한 자식을 펼치면 웨이브별로 마커를
직접 추가·복제·이동할 수 있다. 배치 검증은 실제 코인 반지름을 포함해
벽·범퍼·수리 소켓·금지 영역과 코인 사이의 겹침을 검사한다.

## Stage 01 확인

`scenes/stage_01.tscn`은 현재 웨이브 3종을 연결한 실행 예시다.
`scenes/stage_system/waves/`의 각 래퍼는 프로젝트 메인 실행 씬인 `wave.tscn`을 상속하므로
최신 범퍼 그래픽·VFX, SFX, 공 선택 UI, 수리 부품 효과, 코인 HUD를 함께 사용한다.
래퍼마다 목표 점수만 하나씩 설정한다.

- 웨이브 1: 300점
- 웨이브 2: 500점
- 웨이브 3: 1,000점

세 상속 웨이브 모두 메인 씬의 코인 12개를 생성하고, 획득 코인을 다음 보상·웨이브까지
누적한다. 다른 웨이브 씬에 코인이 없다면 독립적인 `stage_wave_coin_system.tscn`을 추가해
같은 에디터 배치 방식을 사용할 수 있다.
