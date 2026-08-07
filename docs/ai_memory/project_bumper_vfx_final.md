---
name: bumper-vfx-final
description: 범퍼·수리 부품 VFX 최종본 (2026-08-07) — 병합 시 이 목록의 파일은 resource/art 쪽이 최신이다. 태그 art/vfx-final-20260807
type: project
---

# 범퍼·수리 부품 VFX 최종본 (2026-08-07)

브랜치 `resource/art`, 태그 **`art/vfx-final-20260807`**.
태그가 이 문서를 담은 커밋을 가리킨다. 해시를 외울 필요 없이 태그로 찾으면 된다.

```
git show art/vfx-final-20260807
git log --oneline --decorate art/vfx-final-20260807~5..art/vfx-final-20260807
```

> **병합할 때 이 문서를 먼저 볼 것.** 아래 목록의 파일은 이 커밋 시점이 최종본이다.
> `CLAUDE.md` 규칙 1 은 "충돌 시 기준은 항상 main" 이지만, **아래 목록에 한해서는
> `resource/art` 가 최신**이다. main 에는 이 파일들의 이전 판이 없거나 더 오래됐다.
> 판단이 서지 않으면 아래 ★ 절의 자기검증을 돌려 보면 어느 쪽이 최신인지 갈린다.

## 최종본 파일 목록

### 스크립트 — `scripts/bumper-system/vfx/`

| 파일 | 역할 |
|---|---|
| `bumper_hit_feedback.gd` | 기반. 타격선·조각·실밥·파편·섬광·반짝임·글로우 |
| `bumper_bounce_feedback.gd` | Bounce. 원형 파동 + 방향성 방출선 |
| `bumper_shot_feedback.gd` | Shot. 포획 중 공 숨김 · 발사 연기 · 총구 섬광 |
| `bumper_vfx_rules.gd` | 공통 규칙 |
| `bumper_bounce_vfx_rules.gd` | 파동·방출선 규칙 |
| `bumper_shot_vfx_rules.gd` | 대포 규칙 |

### 설정 — `.tres`

- `settings/bumpers/vfx/` — Button / Cotton / SpringDoll / ToyDrum / ClockworkCannon (5)
- `settings/repair_parts/vfx/` — StarlightBrooch / GoldenGears / ForgottenStarBell (3)

### 씬 — 전부 상속본이다. 원본은 건드리지 않았다

- `scenes/bumper_system/vfx/` — 범퍼 5종 + `bumper_vfx_test` + `all_parts_vfx_test`
- `scenes/repair_parts/vfx/` — 부품 3종 + `repair_part_vfx_test`

### 테스트

- `tests/bumper_system/bumper_hit_feedback_test.gd`
- `tests/bumper_system/bumper_type_vfx_test.gd`
- `tests/bumper_system/bumper_vfx_scene_test.gd`
- `tests/repair_parts/repair_part_art_test.gd`
- `tests/bumper_system/bumper_vfx_capture_diagnostic.gd` (육안 검수용, 테스트 아님)

## ★ 최신인지 자기검증하는 법

병합 중에 어느 쪽이 최신인지 헷갈리면 아래 셋으로 가른다.
**하나라도 아니면 그쪽은 옛날 판이다.**

### ① VFX 는 표시 반지름에 붙는다

`bumper_hit_feedback.gd` 의 `_bumper_radius()` 가
`settings.visual_diameter * 0.5` 를 **먼저** 봐야 한다.
`get_collision_radius()` 를 바로 반환하면 옛날 판이다.

표시가 충돌보다 4.5~14.3% 커서, 충돌 기준으로 그리면 연출이 전부 아트 밑에 깔린다.

### ② 파동 시작 반경은 1.14 다

모든 `*Vfx.tres` / `*HitVfx.tres` 의 `ring_start_ratio` 가 `1.14`.
`1.02` 면 옛날 판이다. 1.02 는 첫 프레임이 아트 테두리와 겹쳐 "가린다" 로 보인다.

### ③ 대포에 `smoke_radius_ratio` 가 있다

`bumper_shot_vfx_rules.gd` 에 `smoke_radius_ratio` 가 있어야 한다.
없으면 옛날 판이다. 예전에는 `chip_radius_ratio` 를 빌려 써서 연기가 9px 점으로 나왔다.

## 병합할 때 밟기 쉬운 것

### UID 충돌

`.tres` / `.tscn` 의 `uid://` 는 브랜치마다 새로 발급돼 **한 줄만 다른 충돌**이 잘 난다.
이때는 **main 쪽 UID 를 채택**하고, 그 UID 를 참조하던 `ext_resource` 도 같이 갱신해야
참조가 안 끊긴다. → `CLAUDE.md` Godot 주의사항

`settings/repair_parts/vfx/` 3개는 이 브랜치에서 새로 만든 것이라 main 에 없다.
충돌 나지 않는다.

### main 과 겹치는 파일은 없었다 (2026-08-07 기준)

`b22dfc6` 시점의 main 이 건드린 곳은 `scenes/repair_parts/parts/`,
`settings/bumpers/stage_01_compact/`, `settings/repair_parts/*Definition.tres`,
`tests/repair_parts/unit/` 이고 전부 `vfx` 밖이다.

다만 main 이 새로 넣은 `stage_01_compact` 설정이 위 ①의 앵커에 물린다.
5종 모두 `visual_diameter` 가 유효하다(68 / 86 / 74 / 78 / 84, 전부 충돌 지름보다 큼).
**compact 설정을 새로 추가할 때 `visual_diameter` 를 빼먹으면** 연출이 조용히
충돌 반지름으로 물러선다. 안 죽지만 아트 밑에 깔린다.

### 새 `class_name` 을 쓰기 전에

`--headless --import` 를 한 번 돌려야 한다. 안 그러면
`Could not find type "BumperBounceFeedback"` 이 난다.

## 검수하는 법

```
godot --path . res://scenes/bumper_system/vfx/all_parts_vfx_test.tscn
```

8종이 한 씬에 들어 있다. `←`/`→` 선택, `Space` 공 투하, `R` 재시작.
→ [[test-scene-controls]]

캡처 시트를 다시 뽑으려면:

```
godot --fixed-fps 60 --path . --script res://tests/bumper_system/bumper_vfx_capture_diagnostic.gd
```

**`--fixed-fps` 를 반드시 붙인다.** 없으면 씬 8개를 올리는 순간 첫 프레임 델타가
0.2초까지 뛰어서 `50ms` 라벨이 실제로는 200ms 가 된다. 수명 0.17초짜리 타격선이
통째로 사라져 "VFX 가 안 나온다" 로 오진하게 된다. **헤드리스로 돌리면 안 된다.**

결과: `tests/evidence/bumper_vfx/`

## 아직 안 된 것

- **트랙 VFX** — `BumperType.TRACK` 을 쓰는 범퍼 정의가 하나도 없어 막혀 있다
  → [[bumper-art-resources]]
- **작은 기어 맞물림** — 뒤의 큰 기어가 가려져 안 그려져 있어 오려내면 구멍이 난다.
  레이어를 따로 그려야 한다 → [[repair-parts-art]]
- **`_draw_durability()` 의 실밥** — 프로시저럴 `Visual` 을 끄면서 잃었다.
  내구도 표시가 필요하면 아트 쪽에서 되살려야 한다
- **초승달 바늘** — 기획서는 취소인데 코드엔 구현돼 있다. PL 확인 필요

## 형락님 지시로 가이드를 덮은 곳

가이드와 코드가 다르다고 되돌리지 말 것.

| 가이드 | 코드 | 사유 |
|---|---|---|
| 5-7 "제한된 연기" | 퍼프 11개 | 2026-08-07 "쏘면 연기 같은것도 나게" |
| 4-2 E 단계별 회전량 차등 | 단계 무관 1바퀴 | 2026-08-06 "어떻게 맞아도 빠르게 돌다 감속" |

반대로 5-2 "큰 먼지 구름 금지" 는 **살아 있다.** 솜 조각을 7개로 올렸다가
테스트에 걸려 5개로 되돌렸다.
