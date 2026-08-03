# 콤보 시스템 연동 가이드

## 확정 규칙

- 범퍼·유물의 새로운 유효 타격만 일반 콤보 점수를 적립합니다. 벽·플리퍼·코인은 콤보에 영향을 주지 않습니다.
- 유지 시간 기본값은 3초이며 콤보가 1 이상일 때만 작동합니다.
- 단계는 Normal 1~10회, Super 11~20회, Hyper 21~35회, Ultra 36회 이상입니다.
- 종료 점수는 `stage_base_score × 유효 타격 가중치 합계 × 단계 배율`로 한 번 정산합니다.
- 시간 초과·공 낙하는 1콤보 이상일 때만 점수를 정산하고 콤보를 0으로 초기화합니다.
- 새 공 발사는 정산하지 않고 남은 콤보 상태만 제거합니다.
- 보스 타격은 콤보를 먼저 1 증가시킨 뒤 현재 콤보로 피해를 계산하며 일반 웨이브용 점수 가중치는 0입니다.
- Track·Shot 강제 이동 중에는 유지 시간을 초기화하고 타이머를 일시정지합니다.

## 설정 책임

- `ComboRules.tres`: 유지 시간, 단계 경계, 점수·피해 배율, 피해 증가율과 상한
- `ComboSystem.stage_base_score`: 가중치 1.0인 한 유효 타격의 스테이지 기준 점수
- 충돌 오브젝트: 상대 `score_weight` 값. 일반 타격의 기본값은 1.0
- 보스 설정: 최대 체력과 목표 유효 타격 횟수
- 공 설정: `PinballStats.mass`를 보스 피해 무게 계수로 사용

## 게임 시스템 연결

- 범퍼·유물: `ComboHitSource`를 자식으로 두고 생성한 접촉 ID로 `register_contact`·`release_contact` 호출
- 콤보 연결: 씬 준비 시 `bind_hit_source(source)` 호출하고 제거 시 `unbind_hit_source(source)` 호출
- 스테이지: `ComboStageSettings`에서 유효 타격 1회 기준 점수와 웨이브별 목표 점수를 설정
- 웨이브: `ComboWaveController`에 콤보 시스템과 스테이지 설정을 연결하고 공 발사·낙하·재시도 이벤트 전달
- 보스: `ComboBossSettings`를 `ComboBossTarget`에 연결하고 유효 타격에서 접촉 ID와 `PinballStats`를 `register_ball_contact`로 전달
- 낙하·발사: 각각 `on_ball_drained`, `on_ball_launched` 호출
- 웨이브 재시도: `on_wave_retried` 호출

목표 점수를 넘겨도 현재 공이 낙하하기 전에는 플레이를 중단하지 않습니다. 낙하 뒤 남은 공이 있으면 즉시 클리어하거나 남은 공을 모두 사용할지 선택하며, 남은 공 사용을 선택하면 마지막 공 낙하 뒤 자동으로 클리어를 요청합니다.

보스 타격은 일반 웨이브 점수 가중치를 더하지 않습니다. `ComboBossTarget`이 접촉을 중복 제거한 뒤 보스 체력과 목표 타격 수, 공 무게 배율로 기본 피해를 계산하고, 이번 타격으로 증가한 콤보 단계·횟수 계수를 적용합니다.

`scenes/combo_system/combo_hud.tscn`은 콤보 수, 단계, 유지 시간, 강제 이동 일시정지, 누적 점수, 마지막 정산 점수를 표시합니다. `hit_feedback_requested`, `tier_feedback_requested`, `settlement_feedback_requested` 신호에 프로젝트의 VFX·사운드를 연결할 수 있습니다.

## 통합 순서

1. `ComboSystem`을 생성하고 일반 오브젝트의 `ComboHitSource`를 연결합니다.
2. `ComboWaveController`에 `ComboSystem`을 연결한 뒤 `ComboStageSettings`와 0부터 시작하는 웨이브 인덱스를 적용합니다.
3. 보스 웨이브에서는 `ComboBossTarget`에 `ComboSystem`과 `ComboBossSettings`를 연결합니다.
4. `ComboHud`를 `ComboSystem`에 연결합니다.
5. 게임 상태에서 공 발사·낙하 이벤트를 `ComboWaveController`로 전달합니다.
6. Track·Shot 강제 이동 시작/종료에서 각각 `suspend_combo_timer`, `resume_combo_timer`를 호출합니다.
7. 웨이브 재시도에서는 `ComboWaveController.on_wave_retried`, `ComboBossTarget.reset_encounter`, 모든 `ComboHitSource.reset_contacts`를 함께 호출합니다.
