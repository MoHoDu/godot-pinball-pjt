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
- 보스·공 설정: 기본 피해와 공 무게 계수

## 게임 시스템 연결

- 범퍼·유물: 중복을 제거한 유효 타격에서 `register_hit(score_weight)` 호출
- 보스: 유효 타격에서 `register_boss_hit(base_damage)` 호출
- 낙하·발사: 각각 `on_ball_drained`, `on_ball_launched` 호출
- 웨이브 재시도: `on_wave_retried` 호출
- 이동 연출: 시작 시 `suspend_combo_timer`, 종료 시 `resume_combo_timer` 호출
- UI: `combo_changed`, `combo_tier_changed`, `combo_timer_changed` 구독
- 점수: `score_changed(total_score, added_score)` 구독
- 보스 피해: `boss_damage_calculated(damage, combo_count, tier)` 구독
