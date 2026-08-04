---
name: wave-reward-system
description: 웨이브 사이 유물(인형사의 수리 부품) 선택 시스템 — 구조, 효과 4종, 밟기 쉬운 함정 3개
type: project
---

# 유물 보상 시스템 (2026-08-04 구현)

웨이브 승리 → 수리 부품 3장 중 1장 선택 → 다음 웨이브에 효과 적용.
**신규 파일 23개, 기존 스크립트 수정 0건.** 실행 씬은 `scenes/wave/wave_reward.tscn`.

원본 컨셉 문서: `핀볼_수리부품_컨셉_기획서_강보현.pdf` (강보현, v0.1).
"유물"이라는 이름을 **"인형사의 수리 부품"** 으로 재정의한 문서다. 부품 4종의 컨셉·세계관만 있고
효과 수치는 없다. 아래 수치는 이번 구현에서 임시로 정한 것이므로 **기획 확정 시 바뀔 수 있다.**

## 붙는 지점은 세 곳뿐이다

기존 웨이브 코드에 이미 필요한 게 다 열려 있어서 수정할 이유가 없었다.

| 지점 | 쓰임 |
|---|---|
| `WaveManager.wave_won` | 승리 통지 |
| `WaveManager.enter_wave(settings, index+1, true)` | WON 상태에서 재호출이 허용돼 있다 |
| `RelicRuntime` | 값 변경의 유일한 통로 |

`WaveRewardCoordinator extends WaveRuntimeCoordinator` 가 보상 노드를 **코드로** 붙인다.
`wave.tscn` 이 `test_flipper_wave_board.tscn` 의 인스턴스라, 손으로 노드를 끼워 넣으면
`parent_id_path` 가 깨지기 쉽다. 그래서 `wave_reward.tscn` 은 `wave.tscn` 복제본에서
**script 줄 하나만** 다르다.

## 파일 구성

```
scripts/reward_system/
  relic_definition.gd          부품 1종 정의 (id, 이름, 효과, 최대 스택)
  relic_effect.gd              효과 베이스. apply(runtime, stack_count)
  effects/                     효과 4종
  relic_pool.gd                후보 추첨 (중복 없음, 상한 찬 것 제외)
  relic_inventory.gd           획득 부품 보관
  relic_runtime.gd             ★ 값 변경의 유일한 통로. 기준값 스냅샷·복원
  reward_choice_controller.gd  승리 → 제시 → 확정 → 다음 웨이브 상태 머신
  reward_choice_hud.gd         임시 카드 UI
scripts/wave_hud/wave_reward_coordinator.gd   씬 배선 + 디버그 G키
scenes/reward_system/reward_choice_hud.tscn
scenes/wave/wave_reward.tscn                  wave.tscn 복제본
settings/reward/RelicPool.tres + relics/ 4종
tests/reward_system/                          테스트 4종
```

## 부품 4종과 효과

| 부품 | 효과 | 건드리는 대상 | 상한 |
|---|---|---|---|
| 별모양 브로치 | 콤보 점수 배율 +25%/스택 | `ComboRules` 의 단계별 점수 배율 4개 | 3 |
| 태엽 및 톱니바퀴 | 발사 속력 +10%/스택 | `PinballLauncher` 의 기본·상한 속력 | 3 |
| 곡선 바늘 | 패링 판정 창 +35%/스택 | `FlipperParryRules` 의 normal·perfect | 2 |
| 방울 | 다음 웨이브 시작 공 +1/스택 | `WaveBallInventory.starting_stock` | 2 |

스테이지가 4웨이브(`wave_target_scores` 4개)라 **보상은 3회**, 마지막 승리는 스테이지 클리어다.

## ★ 값 변경은 반드시 기준값 스냅샷을 거친다

`RelicRuntime` 이 처음 접근할 때 기준값을 저장하고, 스택이 늘면
**누적이 아니라 기준값 × 배율**로 다시 계산한다. `_exit_tree()` 에서 전부 복원한다.

복원이 없으면 에디터에서 플레이를 반복할 때 preload된 공유 `.tres`(`ComboRules`,
`FlipperParryRules`)가 이전 판의 버프를 계속 들고 있다. 디스크 파일은 건드리지 않는다.

`restore_all()` 은 같은 순회를 **두 번** 돈다. setter가 서로를 clamp하는 값들은
한 번으로는 원래 값까지 못 돌아가는 경우가 있다.

## 밟기 쉬운 함정 3개

### ① 점수 효과를 `stage_base_score` 에 걸면 안 된다
`ComboWaveController._apply_stage_base_score()` 가 웨이브마다 스테이지 설정 값으로 덮어쓴다.
다음 웨이브에 들어가는 순간 효과가 사라진다. **ComboRules의 단계별 점수 배율**을 건드려야 살아남는다.

### ② 패링 창은 normal을 먼저 늘려야 한다
`FlipperParryRules` 의 setter가 perfect를 normal 이하로 clamp한다.
순서를 바꾸면 perfect 증가분이 **조용히** 잘린다. 에러도 경고도 안 난다.

### ③ 공 추가 상한은 5개다
`WaveRuntimeCoordinator._configure_lives_from_inventory()` 가 라이프 슬롯을 3~5개로 `assert` 한다.
그리고 효과는 `enter_wave()` **전에** 적용해야 `reset_stock()` 에 반영된다.
방울이 2스택인 이유가 이것이다(기준 3개 + 2 = 5).

## 조작

- 카드 이동: `←`/`→` 또는 `A`/`D` (기존 `ball_select_previous`/`next` 액션 재사용 — 인풋맵 추가 없음)
- 확정: `Space` (`ball_select_confirm`), 카드 마우스 클릭도 동작
- **`G` — 개발용 즉시 클리어.** 인스펙터 `디버그 → Debug Clear Wave Key` 를 `KEY_NONE` 으로 두면 빠진다

`G` 는 상태를 강제로 갈아끼우지 않고 **정상 경로를 흉내낸다**. 목표 점수까지 콤보를 만들어 정산한 뒤
클리어 선택을 띄우고 확정한다. 마지막 확정이 중요한데, `ComboWaveController.choose_clear()` 가
`ball_flow.end_wave()` 를 불러 주어야 공 흐름이 INACTIVE가 되고 그래야 다음 `enter_wave()` 가 성공한다.
상태만 WON으로 바꿨다면 다음 웨이브 진입에서 조용히 실패한다.

## 검증 (2026-08-04, 컨테이너에서 엔진 실행)

```
PASS: relic_pool_test          추첨 규칙 (중복 없음 / 상한 제외 / 시드 재현)
PASS: relic_effect_test        효과값 · 스택 재계산 · 상한 · 복원
PASS: wave_reward_flow_test    씬 통합 4웨이브 전 구간
PASS: wave_debug_clear_test    G키 (공 선택 중 / 진행 중 / 조준 중 / 선택 대기 무시 / 마지막 웨이브)
PASS: wave_scene_integration_test            (기존, 회귀 없음)
PASS: wave_ball_selection_integration_test   (기존, 회귀 없음)
```

형락님이 에디터에서 실제 보드로 선택창 동작까지 확인했다.

## 남은 것

- **아트 없음.** 지금 카드는 도형 + 한글 텍스트뿐인 임시 UI다. 확정 아트가 나오면
  `reward_choice_hud.gd` 의 카드 생성부만 갈면 된다 (`_create_card`)
- **효과 수치는 임시값이다.** 기획 확정 시 `settings/reward/relics/*.tres` 에서 숫자만 바꾸면 된다
- 부품 4종 외 추가, 희귀도, 보스 웨이브 연동은 미착수
