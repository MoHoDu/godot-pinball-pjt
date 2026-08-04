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
| **1~6** | **꼬리 VFX 확인** — 기본(청록) / 태엽눈(황동) / 고무막(탠저린) / 젤(연두) / 납심(스모크 금) / 방울눈(라벤더) |
| **7~8** | 물리 감각 — 데드볼(안 튐) / 슈퍼볼(잘 튐) |
| **0** | 기존 7종 나란히 보기 (원래 화면) |
| **R** | 발사 위치로 리셋 |
| **Space · Enter** | 발사 |
| **[ ]** | 공 지름 조절 |

좌상단에 현재 선택·질량·탄성·속도, 그리고 **꼬리 길이·블룸폭·색 HEX** 가 뜬다.
꼬리 값은 눈으로 "다른 것 같다"가 아니라 숫자로 프로필이 먹었는지 확인하려고 찍는다.

**1~6 은 전부 기본 공 씬이다.** `vfx_profile` 만 갈아끼운다.
전용 씬 없이도 **공 그림·동공·꼬리·안개가 전부 갈린다** — 프로필이 `Visual/Sprite2D` 의 텍스처를
`Ball_{공}_Body.png` 로 바꾸고 그 자식으로 `PupilSprite`(`Ball_{공}_Pupil.png`)를 얹는다.

껍질과 동공은 같은 1024 캔버스에 제자리로 그려져 있어서 **위치 계산이 없다.**
동공을 껍질의 자식으로 두면 배율도 저절로 따라온다 — 따로 스케일하면 공 크기를 바꿀 때마다 눈만 어긋난다.

`refresh_profile_art()` 는 반드시 `refresh_ball_size()` **앞**이다.
뒤집으면 배율이 옛 텍스처의 긴 변으로 잡혀 공이 다른 크기로 그려진다.

**프로필은 `add_child()` 전에 대입해야 한다.** `_GlowOutline` / `_Trail` 이
`_ready()` 에서 딱 한 번 읽는다. 뒤에 넣으면 조용히 기본값이 나온다 — 에러가 안 난다.

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
