# 콤보 시스템 연동 가이드

## 규칙

- 플리퍼·벽 등 유효 충돌마다 콤보가 1 증가하고 유지 시간이 3초로 갱신됩니다.
- 단계는 Normal 1~10회, Super 11~20회, Hyper 21~35회, Ultra 36회 이상입니다.
- 콤보가 종료되면 `stage_base_score × combo_count × 단계 배율`을 한 번 정산합니다. 단계 배율은 1/5/10/20입니다.
- 보스 피해는 `base_damage × (1 + 0.025 × min(combo_count - 1, 39)) × 단계 배율`입니다. 단계 배율은 1/1.25/1.6/2이며 횟수 계수는 40콤보에서 멈춥니다.
- 시간 초과, 공 낙하, 새 공 발사에서 현재 콤보를 종료합니다. 서로 다른 콤보 사이에는 횟수가 이어지지 않습니다.
- 경로 이동·자동 이동 연출 중에는 유지 시간을 3초로 되돌린 뒤 타이머를 멈추고, 연출이 끝나면 남은 시간부터 다시 진행합니다.

## 게임 시스템 연결

씬에 `ComboSystem` 노드를 추가한 뒤 스테이지별 `stage_base_score`를 설정합니다.

- 플리퍼: `watch_flipper(flipper)`를 호출하면 기존 `rotation_sweep_resolved` 신호가 자동으로 콤보를 올립니다.
- 벽·범퍼: 유효 충돌 신호를 `register_hit`에 연결합니다.
- 낙하·발사: 게임 상태 신호를 각각 `on_ball_drained`, `on_ball_launched`에 연결합니다.
- 이동 연출: 시작 시 `suspend_combo_timer`, 종료 시 `resume_combo_timer`를 호출합니다. 중첩 호출도 지원합니다.
- UI: `combo_changed`, `combo_tier_changed`, `combo_timer_changed`를 구독합니다.
- 점수: 자체 `total_score`를 사용하거나 `score_changed(total_score, added_score)`를 외부 점수 시스템에 연결합니다.
- 보스 전투: 충돌 시 `calculate_current_damage(base_damage)`를 호출합니다. 공 무게 기반 기본 피해는 `calculate_base_damage`로 구할 수 있습니다.

새 게임을 시작할 때 `reset_run()`을 호출하면 진행 중인 콤보를 정산하지 않고 콤보와 누적 점수를 모두 초기화합니다.
