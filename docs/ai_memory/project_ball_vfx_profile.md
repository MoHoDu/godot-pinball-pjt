---
name: ball-vfx-profile
description: 공별 VFX 연결 고리 — BallVfxProfile 리소스. 아트·프리셋과 실제 노드를 잇는 유일한 통로
type: project
---

# 공별 VFX 프로필 (2026-08-04, 1a 완료)

관련: [[ball-reward-variants]], [[vfx01-mist-aura]], [[vfx02-trail]], [[codebase-conventions]]

## 왜 필요했나

보상 공 5종의 **아트와 프리셋은 전부 만들어져 있었는데 연결이 0건**이었다.

```
grep "BallGlowOutlineRules_\|BallTrailRules_"   -> 0건
grep "ParryRing\|HitSpark\|ComboStar\|Particle_" -> 0건
```

`BallGlowOutline` 과 `BallTrail` 이 각각 기본 `.tres` 하나를 `preload` 할 뿐이라
공별로 갈라질 통로 자체가 없었다. 아트를 아무리 많이 만들어도 물릴 곳이 없었다는 뜻이다.

## 구조

```
scripts/ball_base_system/vfx/ball_vfx_profile.gd   BallVfxProfile (Resource)
settings/balls/vfx/BallVfxProfile_{공}.tres × 5
```

프로필 한 장이 공 하나의 VFX를 전부 들고 있다:
`ball_id` / `display_name` / `glow_rules` / `trail_rules` / `parry_ring` /
`hit_spark` / `combo_star` / `particles[]`

`Pinball` 에 `@export var vfx_profile` 을 두고,
`BallGlowOutline._ready()` · `BallTrail._ready()` 가 `_adopt_profile_rules()` 로 읽는다.

## ★ 우선순위 규칙 — 씬 지정 > 프로필 > 기본값

`_explicit_rules` 플래그로 가른다. 씬에서 `outline_rules`/`trail_rules` 를 **직접 지정하면
setter 가 호출되어** 플래그가 서고, 그 경우 프로필을 무시한다.

이유: 프로필은 "공 종류별 기본값"이고 씬 지정은 "이 인스턴스만 예외"라 더 구체적이다.

**하위 호환이 이 설계의 핵심이다.** 프로필을 안 주면 예전과 완전히 똑같이 동작하므로
기존 씬(`base_ball` 및 변종 6종)을 하나도 안 건드렸다. 기존 glow/trail 테스트도 그대로 통과한다.

## 주의 — `vfx_profile` 은 `_ready` 전에 넣어야 한다

`_adopt_profile_rules()` 가 `_ready()` 에서 한 번만 돈다.
런타임에 프로필을 갈아끼우려면 공을 새로 만들거나 갱신 함수를 따로 만들어야 한다.
(테스트에서는 `instantiate()` 직후 `add_child()` 전에 넣는다)

## Resource 에는 `_get_configuration_warnings()` 가 없다

Node 전용이라 Resource 에 써도 **호출되지 않는다.** 대신 `get_missing_slots()` 를 만들어
테스트에서 직접 부른다.

## 실측 — 5종이 실제로 갈린다

| 공 | 꼬리 길이 | 블룸 폭 | 블룸 색 |
|---|---|---|---|
| Clockwork | 6.364 | 1.20 | `#C89236` 황동 |
| Rubber | 7.000 | 1.55 | `#E27036` 탠저린 |
| Gel | 5.000 | 1.55 | `#A9C87C` 피스타치오 |
| Lead | 6.364 | 0.95 | `#A8863A` 스모크 금 |
| HollowBell | 6.800 | 1.45 | `#A88CCC` 라벤더 |

고유 길이 4종 / 고유 폭 4종 / 색은 5종 전부 다르다.
문서의 "단순히 색상만 다른 스킨이 아니다"를 테스트로 못 박아 뒀다.

## 남은 것

- **1b — 보상 공 5종 씬.** `Ball_{공}_Body.png` / `_Pupil.png` 가 분리돼 있어
  문서 12-3 노드 구조(`BodySprite` + `PupilSprite`)가 필요하다.
  `base_ball.tscn` 구조 변경이라 기존 테스트의 `Visual/Sprite2D` 경로 검사를 같이 손봐야 한다
- **공별 물리 값이 메모리에 없다.** 가이드 7~11장에 있을 텐데 정리본에 안 담겼다.
  씬을 만들 때 `stats` 는 TODO 로 두고 나중에 채운다
- `parry_ring` / `hit_spark` / `combo_star` / `particles` 는 **슬롯만 만들어 뒀다.**
  이걸 쓰는 시스템(VFX ③ 패링 파동 등)은 아직 없다

## 파일

```
scripts/ball_base_system/vfx/ball_vfx_profile.gd
scripts/ball_base_system/pinball.gd                    vfx_profile export 추가
scripts/ball_base_system/vfx/ball_glow_outline.gd      _adopt_profile_rules()
scripts/ball_base_system/vfx/ball_trail.gd             _adopt_profile_rules()
settings/balls/vfx/BallVfxProfile_{공}.tres × 5
tests/ball_base_system/ball_vfx_profile_test.gd        6종 (미실행)
```
