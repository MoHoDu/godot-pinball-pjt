# Stage 1 Teddy Boss Feedback Handoff

이 문서는 Stage 1 Teddy Boss의 Gameplay 판정을 다시 구현하지 않고 아트, VFX, 사운드를 연결하기 위한 작업 기준이다. 연결 지점은 `TeddyBossFeedbackController`의 의미 중심 signal이며, 실제 슬롯은 `TeddyBossFeedbackPorts`에 비어 있는 상태로 제공된다.

## 연결 원칙

- Counter 여부를 Damage 값으로 추측하지 않는다. `boss_hit_feedback(damage, was_counter)`의 `was_counter`를 사용한다.
- Phase 2 여부를 HP로 다시 계산하지 않는다. `phase_2_feedback`을 사용한다.
- 공격 단계를 Timer로 추측하지 않는다. Telegraph, ACTIVE, Recovery signal을 사용한다.
- Feedback 코드는 Damage, Physics, Counter, Scheduler, Phase, Cotton, BallFlow 상태를 변경하지 않는다.
- Visual 슬롯에는 실제 VFX Scene 또는 AnimationPlayer 연결을 추가하고, Audio 슬롯에는 AudioStream과 volume/pitch 설정을 추가한다.

## 이벤트 연결표

| Gameplay Event | Feedback Signal | Visual Slot | Audio Slot | 작업 의도 |
|---|---|---|---|---|
| Boss Battle Start | `boss_battle_started()` | `BossVisualRoot` | `BattleStart` | 전투 시작 연출과 시작음 |
| Pattern 1 Telegraph | `attack_telegraph_started(1)` | `TelegraphPattern1` | `TelegraphPattern1` | 팔 휘두르기 전 위험 예고 |
| Pattern 2 Telegraph | `attack_telegraph_started(2)` | `TelegraphPattern2` | `TelegraphPattern2` | 양팔 올려치기 전 위험 예고 |
| Pattern 1/2 ACTIVE | `attack_active_started(pattern_id)` | 해당 공격 Visual | `ArmSwing` | 실제 공격 시작 강조 |
| Pattern 1/2 Recovery | `attack_recovery_started(pattern_id)` | 해당 공격 Visual | 필요 시 기존 슬롯 재사용 | 공격 종료와 안전 구간 전환 |
| Arm Ball Hit | `arm_ball_hit(ball)` | `ArmImpact` | `ArmImpact` | 공이 팔 공격에 맞은 순간의 피드백 |
| Arm Reflection | `arm_ball_reflected(ball)` | `ArmReflection` | `ArmReflection` | 실제 impulse 적용 직후 경로 변경 강조 |
| Normal Boss Hit | `boss_hit_feedback(damage, false)` | `BossNormalHit` | `BossNormalHit` | 일반 보스 피격 |
| Counter Boss Hit | `boss_hit_feedback(damage, true)` | `BossCounterHit` | `BossCounterHit` | 일반 Hit보다 강한 Counter 피격 |
| PERFECT Counter Earned | `counter_earned_feedback()` | `CounterEarned` | `CounterEarned` | 정확한 패링 성공 보상 |
| Counter Expired | `counter_expired_feedback()` | `CounterExpired` | `CounterExpired` | 사용하지 못한 Counter 만료 |
| Phase 2 Entered | `phase_2_feedback()` | `Phase2Transition` | `Phase2Transition` | 전투 강도 전환 |
| Cotton Spawn | `cotton_spawn_feedback()` | `CottonSpawn` | `CottonSpawn` | Cotton 인스턴스 하나당 한 번 발생 |
| Cotton Ball Hit | `cotton_hit_feedback()` | `CottonHit` | `CottonHit` | Cotton이 공 경로를 바꾼 순간 |
| Boss Defeated | `boss_defeated_feedback()` | `BossDefeat` | `BossDefeat` | 보스전 종료 피드백 |

## Pattern ID

- `TeddyBossFeedbackController.PATTERN_ARM_SWEEP == 1`
- `TeddyBossFeedbackController.PATTERN_DOUBLE_ARM_UP_SWEEP == 2`

Telegraph, ACTIVE, Recovery에서 전달되는 ID를 사용해 Pattern별 연출을 구분한다.

## 슬롯 작업

### 아트/VFX

1. `Visual` 아래의 의미가 맞는 슬롯에 실제 VFX Scene을 자식으로 추가한다.
2. 필요한 AnimationPlayer를 슬롯 또는 VFX Scene에 둔다.
3. Feedback signal을 받아 animation을 재생한다.
4. Gameplay Controller의 HP, Timer, Damage 값을 직접 읽어 판정하지 않는다.

### 사운드

1. `Audio` 아래 AudioStreamPlayer의 비어 있는 `stream`에 실제 리소스를 연결한다.
2. volume, pitch, bus를 사운드 기준에 맞게 설정한다.
3. Feedback signal에서 해당 AudioStreamPlayer의 `play()`를 호출한다.

## 관찰 Hook

Arm Reflection은 `BossArmBallReflector.ball_reflected(ball)`의 실제 성공 signal을 `arm_ball_reflected(ball)`로 전달한다. 아트와 사운드 담당자는 이 Feedback signal에 `Visual/ArmReflection`과 `Audio/ArmReflection`을 연결한다. `attack_hit`만으로 Reflection 성공을 추측하지 않는다.

Boss Battle Start는 현재 Runtime의 공개 `visibility_changed`를 의미 이벤트로 변환한다. Cotton Spawn은 명시적으로 연결된 CottonContainer의 `child_entered_tree`, Cotton Hit은 각 `CursedCottonAdd.cotton_hit`을 사용한다.

## 금지 사항

- Counter를 Damage 크기로 판정하지 않는다.
- Phase 2를 HP 직접 계산으로 판정하지 않는다.
- ACTIVE를 자체 Timer로 추측하지 않는다.
- Feedback 처리에서 Gameplay 상태나 Resource 값을 변경하지 않는다.
- 이 슬롯 작업에서 임시 최종 VFX/SFX asset을 제작하지 않는다.
