# Stage system

`StageFlowManager`는 인스펙터에 등록한 씬을 아래 순서로 실행한다.

```text
웨이브 1 → 보상 → ... → 웨이브 N → 보상 → 보스 1 → ... → 보스 N → 완료
```

## 설정

1. `scenes/stage_system/stage_flow_manager.tscn`을 원하는 상위 씬에 추가한다.
2. `wave_scenes`에 일반 웨이브 씬을 실행 순서대로 하나 이상 넣는다.
3. `boss_scenes`에 보스 씬을 실행 순서대로 넣는다. 보스가 아직 없으면 비워 둘 수 있다.
4. 필요하면 `reward_scene`을 실제 보상 씬으로 교체한다.

각 웨이브·보스·보상 씬은 완료 시그널을 루트 또는 자식 노드에 하나 노출해야 한다.
기본으로 인식하는 이름은 다음과 같다.

- 웨이브: `stage_segment_completed`, `wave_completed`, `wave_cleared`, `wave_won`, `stage_completed`, `completed`
- 보스: `stage_segment_completed`, `boss_completed`, `boss_defeated`, `stage_completed`, `completed`
- 보상: `reward_completed`, `continued`, `next_requested`, `completed`

기존 웨이브 씬처럼 `WaveManager.wave_won(score, target)`가 자식 노드에 있는 경우도
인자 수를 자동으로 맞춰 연결한다. 프로젝트별 이름이 다르면 매니저의 완료 시그널 배열을
인스펙터에서 수정한다. 같은 이름의 시그널이 여러 노드에 있으면 루트에서 가까운 노드를
먼저 사용한다.

기본 보상 페이지는 실제 보상 시스템을 대신하는 전환용 화면이다. 마지막 일반 웨이브 뒤에도
한 번 표시되며, 다음 대상에 따라 버튼 문구가 `다음 웨이브`, `보스 진행`, `스테이지 완료`로
바뀐다.

## Stage 01 확인

`scenes/stage_01.tscn`은 현재 웨이브 3종을 연결한 실행 예시다. 기존 웨이브 씬은 수정하지 않고
`scenes/stage_system/waves/`의 상속 씬에서 목표 점수를 웨이브별로 하나씩 설정한다.

- 웨이브 1: 300점
- 웨이브 2: 500점
- 웨이브 3: 1,000점
