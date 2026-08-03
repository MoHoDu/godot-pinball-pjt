---
name: path-case-issue
description: res://resources 소문자 참조 17곳 — Windows에선 통과하지만 Linux/macOS 익스포트 시 전부 깨진다
type: reference
---

# `res://resources/` 소문자 참조 — 익스포트 폭탄

실제 폴더는 `Resources/`(대문자 R)인데 코드·씬 17곳이 `res://resources/`로 참조한다.
Windows는 대소문자를 무시해서 지금까지 통과했지만, **대소문자를 구분하는 플랫폼에선 전부 못 연다.**

## 2026-08-03 리눅스 Godot 4.7.1로 실측한 결과

경로 대소문자 **하나만** 고쳤더니 실패하던 테스트가 전부 통과했다.

| 테스트 | 고치기 전 | 고친 뒤 |
|---|---|---|
| pinball_size_test | FAIL | PASS |
| pinball_physics_rules_test | FAIL | PASS |
| pinball_variation_test | FAIL | PASS |
| pinball_physics_test | FAIL | PASS |
| pinball_bounce_regression_test | PASS | PASS |

즉 **로직 문제가 아니라 순전히 경로 문제**다.

## 해당 파일 (17곳)

```
scenes/test_flipper/test_flipper_board.tscn
scenes/test_flipper/test_flipper.tscn
scenes/test_ball/test_ball_physics.tscn
tests/flipper_system/flipper_parry_feedback_test.gd
tests/ball_base_system/pinball_size_test.gd
tests/ball_base_system/pinball_physics_rules_test.gd
tests/ball_base_system/pinball_physics_test.gd
tests/ball_base_system/pinball_variation_test.gd
Resources/flippers/flipper/flipper_controller_sample.tscn
Resources/flippers/sub_flipper/normal_flipper_left.tscn
Resources/flippers/sub_flipper/normal_flipper_right.tscn
Resources/balls/elastic_var/{dead,rubber,super}_ball.tscn
Resources/balls/mass_var/{heavy,light,normal}_ball.tscn
```

**이미 고친 것**: `Resources/balls/base/base_ball.tscn`,
`tests/ball_base_system/ball_gaze_visual_test.gd`, `ball_glow_outline_test.gd`

## 고치는 법

```bash
grep -rl "res://resources/" . --include=*.gd --include=*.tscn --include=*.tres \
  | xargs sed -i 's|res://resources/|res://Resources/|g'
```

Godot이 경고로도 알려준다: `Case mismatch opening requested file ... This file will not open
when exported to other case-sensitive platforms.`

**아직 형락님 승인 안 받음.** 남은 17곳은 손대지 않은 상태.

관련: [[codebase-conventions]], [[run-tests-before-delivering]]
