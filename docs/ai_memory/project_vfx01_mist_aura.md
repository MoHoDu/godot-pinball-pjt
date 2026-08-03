---
name: vfx01-mist-aura
description: VFX ① 발광 테두리 리디자인 — Line2D 링에서 셰이더 안개 오라로. 안 B(외곽 40px) 확정, 셰이더까지 구현
type: project
---

# VFX ① 안개 오라 (2026-08-03 리디자인)

관련: [[vfx-ball-effects]], [[staged-art-pipeline]], [[run-tests-before-delivering]]

형락님 요구: **"사우론의 눈처럼 주변에 오라가 은은하게 퍼지는 마법의 안개에 감싸인 느낌."**

## 구조 전환 — 선에서 면으로

Line2D 2겹(링) → **Sprite2D + ShaderMaterial**. 안개는 선이 아니라 면이라 Line2D로는 안 된다.
gl_compatibility는 GPUParticles만 막고 셰이더는 제약이 없다.
갭(gap_half_width/gap_softness)은 링 전용 개념이라 삭제했다.

## ★ 밴딩은 최종 알파에 딱 한 번만

층마다 따로 밴딩을 걸어 겹쳤더니 계단이 서로 어긋나 **다시 매끈한 글로우**가 됐다.
누적된 최종 알파에 한 번만 `ceil(a*bands)/bands`를 걸어야 계단이 산다.

안개다움(가닥·결)은 **극좌표 노이즈**에서 나온다 — `nt(각도분할) >> nr(반경분할)`로 두면
반경 방향으로 길쭉한 결이 생긴다. 실루엣을 흔드는 혓바닥(plume)은 작게 유지해야
"반드시 원으로 읽힐 것" 기준을 지킨다. 결과적으로 **결은 텍스처가, 실루엣은 원이** 담당한다.

## 확정값 (안 B)

- 외곽 반경 **공 반지름 × 1.818** = 44px 기준 **40px** (전체 80px)
  → 비주얼 가이드의 28~30px을 의도적으로 초과. 30px으로는 안개가 공에 밀착해 안 퍼진다
  → **이 값은 상한이다.** 혓바닥 최장 방향과 진행방향이 겹쳐야 40px에 닿고, 실측 도달은 약 36px
- peak 0.60 / bands 5 / falloff_exp 0.85 / plume 0.14(lobes 5)
- wisp 0.75(lobes 11, radial 1) / inner_bloom 0.30 / gaze_stretch 0.10
- core_alpha 0.72 / core_width_ratio 0.062 / wobble 0.05 / drift 0.6rad/s
- outer_darken 0.58 — 바깥 색은 안개 색을 어둡게 해서 만든다(상태마다 색 3개씩 두지 않으려고)

## 실측으로만 잡힌 버그 4개 (전부 눈으로는 안 보인다)

1. **`smoothstep(e0,e1,x)`에서 분모를 `max(e1-e0, 1e-6)`로 클램프하면 안 된다.**
   내림차순(e0>e1) falloff에서 부호가 뒤집혀 **캔버스 전체가 네모로 칠해진다.**
   GLSL 내장 smoothstep도 e0>=e1이면 정의되지 않으므로 직접 만들어야 한다.
2. **혓바닥·응시 늘림이 곱해지면 실제 외곽이 명목값을 크게 넘는다.**
   정규화 없이는 "40px"이라 적고 **58px을 그린다.** 최대 배율로 나눠야 한다.
3. **inner_bloom을 `ball_r` 배수로 박으면 작은 반경에서 안개 끝보다 밖으로 샌다.**
   외곽 30px안과 40px안이 **같은 크기로 측정**됐다. 반드시 edge 기준으로.
4. **GLSL `pow(음수, 2.0)`은 정의되지 않는다.** 코어 링 감쇠는 `rd*rd`로 써야 한다.

## 검수 결과 (44px 기준, 실제 .gdshader를 llvmpipe로 실행)

가독성 VFX 0.62 vs 공 0.955 / 원형 편차 8.6% / 보드 대비 +0.042 / 상태 구분 최소 0.248 — 전부 통과.

## ★ Godot 컨테이너 설치가 막혔다 (2026-08-03)

`feedback_run_tests.md`에 적힌 릴리스 직링크가 **더 이상 안 된다.**
프록시가 `github.com`을 CONNECT 단계에서 403으로 막는다.
도달 가능한 호스트는 **pypi.org / files.pythonhosted.org / registry.npmjs.org 뿐**이고,
엔진 바이너리를 담은 패키지는 둘 다에 없다(godot-mcp 류는 전부 로컬 설치본을 전제).

대체 수단 (이번에 실제로 쓴 것):

- `pip install gdtoolkit` → `gdparse`(구문) / `gdlint`(스타일). 리포 기존 파일도 같은
  `class-definitions-order` 경고가 나므로 그건 컨벤션이지 회귀가 아니다
- **`pip install moderngl` + `xvfb-run` → llvmpipe로 실제 .gdshader를 컴파일·실행**.
  Godot 셰이더를 GLSL 330으로 기계 치환(`shader_type`/`render_mode` 제거, `COLOR`→out, `UV`→in)하면
  사본이 아니라 **리포의 진짜 셰이더 파일**을 돌려볼 수 있다. 유니폼도 .tres에서 읽어 넣는다
- 엔진 런타임(씬 트리·시그널·물리) 테스트는 **여전히 못 돌린다.** 형락님 로컬 실행 필요:
  `godot --headless --path . --script res://tests/ball_base_system/ball_glow_outline_test.gd`

## 파일

```
Resources/shaders/ball_mist_aura.gdshader                 셰이더
scripts/ball_base_system/vfx/ball_glow_outline.gd         Sprite2D 쿼드 + 유니폼
scripts/ball_base_system/vfx/ball_glow_outline_rules.gd   규칙(갭 삭제, 안개 파라미터 추가)
settings/balls/BallGlowOutlineRules.tres
tests/ball_base_system/ball_glow_outline_test.gd          11종으로 재작성 (미실행)
docs/ball_guides/vfx01_mist_aura_mock.png                 ① 형태 단계 승인본
docs/ball_guides/vfx01_mist_shader_result.png             ② 텍스처 단계 결과
docs/ball_guides/{mist_aura,run_shader,shader_check}.py   목표 그림·셰이더 실행·검수 스크립트
```

`pinball.gd`와 `base_ball.tscn`은 안 건드렸다.
