---
name: path-case-issue
description: res://Resources 경로 대소문자 통일 기록과 플랫폼별 검증 기준
type: reference
---

# `res://resources/` 소문자 참조 — 해결 기록

## 해결 상태

2026-08-03 `VFX/Test`와 `main` 병합 후 남은 코드·씬·프로젝트 설정의
`res://resources/` 참조를 저장소 표준인 `res://Resources/`로 통일했다.
macOS 작업 폴더의 실제 `Resources/Art` 표기도 Git 트리와 일치시킨 뒤
Godot 헤드리스 회귀 테스트에서 대소문자 경고가 사라진 것을 확인했다.

검증 명령에서 코드·씬·리소스·프로젝트 설정의 소문자 참조는 0건이어야 한다.

```bash
rg -n 'res://resources/' -g '*.gd' -g '*.tscn' -g '*.tres' -g '*.godot'
```

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

## 최초 확인된 파일 (17곳)

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

## 수정 방법

```bash
grep -rl "res://resources/" . --include=*.gd --include=*.tscn --include=*.tres \
  | xargs sed -i 's|res://resources/|res://Resources/|g'
```

Godot이 경고로도 알려준다: `Case mismatch opening requested file ... This file will not open
when exported to other case-sensitive platforms.`

**해결 완료:** 병합 이후 추가된 참조까지 같은 기준으로 정규화했다.

관련: [[codebase-conventions]], [[run-tests-before-delivering]]
