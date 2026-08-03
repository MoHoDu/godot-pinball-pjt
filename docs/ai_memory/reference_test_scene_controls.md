---
name: test-scene-controls
description: 개발용 테스트 씬 조작키 모음 — 공 종류 전환, 플리퍼 패링 모드. VFX 검수는 여기서 한다
type: reference
---

# 테스트 씬 조작키

VFX·물리를 눈으로 확인할 때 쓰는 씬들이다. 새 VFX를 만들면 여기서 먼저 본다.

## `scenes/test_ball/test_ball_physics.tscn` — 공 종류 전환

컨트롤러: `tests/ball_base_system/test_ball_physics.gd` (2026-08-03 추가)

| 키 | 동작 |
|---|---|
| **1~7** | 공 종류 교체 — 기본 / 데드 / 러버 / 슈퍼 / 가벼움 / 보통 / 무거움 |
| **0** | 기존 7종 나란히 보기 (원래 화면) |
| **R** | 발사 위치로 리셋 |
| **Space · Enter** | 발사 |
| **[ ]** | 공 지름 조절 |

좌상단에 현재 선택·질량·탄성·속도가 뜬다.

설계 이유 두 가지:

- **기존 7개 공을 지우지 않고 0번으로 되돌아갈 수 있게 남겼다.** 이 씬의 원래 용도가 물리 비교다.
  1~7 을 누르면 기존 그룹은 숨기고 **`sleeping` 까지 건다** — `visible` 만 끄면
  안 보이는 공들이 계속 굴러다닌다.
- **기본 지름 44px.** 기존 씬은 32px 이었는데 기획서 실제 게임 크기가 44px 이고
  VFX 검수는 그 크기로 해야 의미가 있다.

공을 띄울 때 변종 씬을 그대로 인스턴스화하므로 각 변종의 `stats`(질량·탄성)가 살아 있다.
이 씬의 인스펙터 오버라이드는 쓰지 않는다.

## `scenes/test_flipper/` — 플리퍼

- `test_flipper_board.tscn` : R 리셋 / Enter 발사. **실제 게임 크기(공 44px) 보드**
- `test_flipper_parry.tscn` : 0~3 패링 모드 전환 (없음 / 실전 / 일반 고정 / 정확 고정)
- `test_flipper_area_direction.tscn` : 0~6, Tab, Space

## ★ RigidBody2D 를 순간이동시킬 때

노드 속성만 쓰면 **물리 서버가 다음 프레임에 덮어쓴다.** 리포에서 검증된 방식은 둘 다 하는 것이다:

1. `PhysicsServer2D.body_set_state` 로 서버에 직접 쓰고
2. **한 프레임 뒤에 한 번 더** 같은 위치를 쓴다

`test_ball_physics.gd` 의 `_place_body()` / `_replace_next_frame()` 참고.
같은 함정을 `BallGazeVisual` 에서도 겪었다 → [[codebase-conventions]]
