# 보스 전투 설정

메뉴 경로: `Pinball > Game Settings > Bosses`

- `Stage1BossPhase1Rules.tres`: 최대 체력, 페이즈 2 진입 비율, 목표 타격 수, 공격 간격, 카운터 배율
- `BossBallDamageWeightRules.tres`: 공 종류별 보스 피해 배율과 공 ID 그룹
- `TeddyArmBallReflectionRules.tres`: 팔에 맞은 공의 반사 속력과 방향 비율
- `CursedCottonAddRules.tres`: 저주 솜 충돌 반경과 속력 유지율
- `TeddyArmSweep*.tres`: 공격 예고·활성·회복 시간과 공격 ID
- `TeddyPhase2AttackRules.tres`: 페이즈 2 공격 간격

보스 체력을 바꾸면 `target_valid_hit_count`도 함께 검토해 1회 피해량이 의도한 전투 시간과 맞는지 확인하세요. 공격 패턴 시간은 예고→활성→회복 순서를 유지해야 합니다.
