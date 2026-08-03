---
name: vfx-ball-effects
description: 공 VFX 3종 — 비주얼 가이드 기준 재설계. ① 발광 테두리 구현·테스트 통과, ② 꼬리 ③ 파동 대기
type: project
---

# 공 VFX — 발광 테두리 / 이동 꼬리 / 패링 파동

관련: [[pinball-logue]], [[ball-glass-eye]], [[workflow-rules]], [[run-tests-before-delivering]]

## ★ 비주얼 가이드가 정한 구조 (2026-08-03 문서 학습 후 재설계)

Google Docs `1ryazSYd1k1NmgsNz6iqHspCRaZSEBfOWXoJV1XC9GLM` 의 `3. 공` 탭.
**공 VFX는 딱 3종으로 제한**한다.

| 구분 | 역할 | 발생 조건 |
|---|---|---|
| ① 발광 테두리 | 위치·상태 표시 | **항상 유지** |
| ② 이동 꼬리 | 방향·속도 표시 | 공이 움직일 때 |
| ③ 패링 원형 파동 | 정확한 패링 성공 | 패링 성공 순간 |

**일반 충돌·고속·강화·저주는 새 VFX를 추가하지 말고 이 셋의 색·밝기·길이·형태만 조절한다.**
가독성 우선순위: 공 본체·동공 > 발광 테두리 > 이동 꼬리 > 패링 파동 > 충돌 스파크.
레이어: 꼬리(공 뒤) → 공 본체 → 발광 테두리 → 파동 → 스파크.

### 기존 VFX_01 설계가 문서와 어긋났던 점 (교정 완료)

- 옛 설계: "1000px/s 초과할 때만 트레일"
- 문서: 꼬리는 **움직이면 상시**. 일반 이동 60~100px, 고속은 그 꼬리의 길이·밝기를 올리는 것
- 옛 설계엔 **발광 테두리가 아예 없었다**. 문서에선 이게 우선순위가 더 높은 상시 VFX
- → 2026-08-03 형락님 확정: **문서대로 상시 꼬리**로 간다

## 확정 수치 (문서)

- 충돌 반지름 22 / 본체 지름 44 / VFX 포함 시각 반지름 30 / 전체 지름 60
- 발광 테두리 외곽 반지름 **28~30px**
- 이동 꼬리 일반 이동 **60~100px**
- 패링 파동: 시작 25~30 → 종료 90~120px, **0.12~0.20초**, 중심 플래시 0.03~0.06초,
  링 두께 4~8px, 중심을 타격 방향으로 2~5px 이동
- 기능색: 기본 청록·아이보리 / 패링 밝은 청록+금색 / 저주 보라+라임 / 위험 진홍·핫핑크

## 엔진 제약

`gl_compatibility` 렌더러 → **GPUParticles2D 트레일 미지원.** Line2D 기반이 유일한 안전 선택.

## ★ 레퍼런스 이미지 5장은 전부 블룸 기반

전기 링 구체 / 방사형 충격 3분할 / 카툰 히트 스파크 / 청록 소용돌이 링 / 빛기둥 포탈.
**구조와 팔레트만 가져오고 렌더링 방식은 가져오지 않는다** — [[prompt-style-drift]]와 같은 함정.
소프트 글로우 그라디언트 대신 **알파가 다른 평탄한 링 2겹**으로 번역했다.
다행히 문서도 "매끈한 네온 원보다 약간 끊어지고 흔들리는 카툰형 원"이라고 같은 말을 한다.

## ① 발광 테두리 — 구현 완료 (2026-08-03)

```
scripts/ball_base_system/vfx/ball_glow_outline.gd        BallGlowOutline (Node2D)
scripts/ball_base_system/vfx/ball_glow_outline_rules.gd  BallGlowOutlineRules (Resource)
settings/balls/BallGlowOutlineRules.tres
tests/ball_base_system/ball_glow_outline_test.gd         테스트 9종
Resources/balls/base/base_ball.tscn                      _GlowOutline 자식 노드 추가
docs/ball_guides/vfx01_glow_outline_mock.png             목표 그림
docs/ball_guides/vfx01_ingame_render.png                 실제 엔진 렌더 결과
```

**`pinball.gd`는 안 건드렸다.** `top_level = true`, `z_as_relative = false`, `z_index = 10`.

구조: Line2D 2겹(넓고 흐린 Glow + 얇고 밝은 Core)을 닫힌 원으로 깔고,
**Gradient의 알파로 갭을 뚫어** "빛이 원을 따라 흐르다 옅어지는" 인상을 만든다.
노드를 `drift_speed`로 천천히 회전시켜 갭이 원을 돈다.

### 목표 그림 1차를 내가 반려한 이유 (반복 금지)

갭 절반 각도를 0.17~0.26rad로 크게 줬더니 **44px에서 링이 아니라 조각난 호 두 개**로 보였다.
문서의 "전체 형태는 반드시 원으로 읽혀야 함"에 정면으로 걸린다.
→ 갭 0.06rad 2개 + 소프트니스 0.55rad. 테스트에 `gap_half_width <= 0.1` 로 못 박아뒀다.

링에서 뻗는 잔가지(갈라짐)는 이 크기에서 긁힘처럼 읽혀 뺐다.
순백 코어는 공의 아이보리 테보다 밝아져 "공 본체가 가독성 1순위" 규칙을 어겼다.
→ 코어 알파를 1.0 미만으로 잠그고 테스트로 강제한다.

### 확정값

- `radius_ratio 1.24` (공 반지름 대비) → 44px 기준 코어 외곽 29.0 / 글로우 외곽 31.4px
- 두께는 **공 반지름 대비 비율**: core 0.059 / glow 0.282. 44 vs 64 문제로 px 하드코딩 금지
- `drift_speed 0.6 rad/s`, `wobble 0.04` (저주파만 섞어 원으로 읽히게)
- `flash_hold 0.04s` / `flash_fade 0.18s` / `flash_width_scale 1.4`
- 패링 등급 매핑: PERFECT → flash(1.0) 전체 점등 / NORMAL → flash(0.45) 약한 점등
- **금색은 테두리에 안 쓴다.** 금색은 VFX ③ 파동의 언어라 겹치면 뭉개진다

패링 연결은 `auto_bind_parry`가 현재 씬에서 `parry_resolved` 시그널을 가진 노드를 훑어 자동 연결하고,
콜백에서 `ball == _ball`로 자기 공만 거른다.

## 테스트 결과 — 전부 통과 (2026-08-03, Godot 4.7.1 리눅스 실측)

컨테이너에 Godot을 설치해 직접 돌렸다. 방법은 [[run-tests-before-delivering]].

```
ball_glow_outline_test    PASS   (9종)
ball_gaze_visual_test     PASS   (8종)
기존 공 테스트 5종         PASS   (경로 대소문자 수정 후, 회귀 없음)
```

`xvfb-run` + `opengl3`로 실제 렌더링까지 확인했다 → `docs/ball_guides/vfx01_ingame_render.png`.
상태 4종(normal/parry/curse/danger) × 크기 44/96/150px. 링이 공을 따라가고 상태색이 확실히 갈린다.

### 실행해서 잡은 것

- `const GAP_CENTERS: PackedFloat32Array = PackedFloat32Array([...])` — 생성자는 상수 표현식이 아님
- `_ball: Node2D` 에 `_ball.ball_diameter` 직접 접근 — 정적 검사가 막음. `get(&"...")` 로
- **큰 크기(96·150px)에서 글로우 링에 계단 뭉침이 보인다.** 44px에선 안 보인다. 실사용은 44px이라 방치

## 다음

- **② 이동 꼬리** — Line2D 링버퍼, 상시, 60~100px, 속도로 길이·밝기 스케일
- **③ 패링 파동** — 플리퍼 `parry_resolved` PERFECT에만. 금색 보조 링은 여기서
- 1단계는 절차적으로 완성하고, 2단계에서 Leonardo 잉크 리본 텍스처를 `Line2D.texture`에 갈아끼운다 (구조 동일 = 리테이크 0)
