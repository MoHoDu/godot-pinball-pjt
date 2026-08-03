---
name: ball-glass-eye
description: 공 리소스 — "유리눈"은 안구가 아니라 캣츠아이 보석이다. 아트 STEP1~3 + 응시 시스템까지 완료
type: project
---

# 공 = 캣츠아이 수정구 — **아트·코드 모두 완료** (2026-08-02~03)

관련: [[pinball-logue]], [[art-pipeline]], [[board-step-pipeline]], [[vfx-ball-effects]]

## ★ 컨셉 해석 — 여기서 한 번 틀렸다

기획서의 **"유리눈"은 유리로 만든 눈알이 아니다.** 형락님 정정:
"눈처럼 생긴 수정구나 보석 느낌. 눈알이면 그로테스크할 수 있으니까."

- ❌ v1 폐기: 아이보리 흰자 + 청록 홍채 + 검은 동공 = 해부학적 안구
- ✅ 확정: **캣츠아이 캐보션 보석.** 청록 크리스탈 + 아몬드형 짙은 내포물 + 장축을 흐르는 빛줄기

Why: 흰자(sclera)가 안구다움의 원인이다. 전체를 하나의 광물 재질로 통일하고
눈다움은 **코어 실루엣(아몬드)** 에서만 나오게 하면 그로테스크해지지 않는다.

How to apply: 프롬프트에 `eyeball`이라 쓰면 모델이 흰자를 그린다.
`cat's-eye gemstone / polished mineral cabochon, NOT an organic eyeball`로 명시하고
네거티브에 `eyeball, sclera, eyelid, veins, flesh`를 넣는다.

반려된 A(수정구슬·완전 동심원) / C(컷젬·육각 커팅) 시안은 범퍼·유물 아트로 전용 가능.

## ★ 코드 제약 — 원이 캔버스에 내접해야 한다

`pinball.gd`의 `refresh_ball_size()`가 **텍스처의 긴 변**으로 나눈다:
`visual_scale = ball_diameter / max(tex.x, tex.y)`. **캔버스 여백 = 표시 크기 손실.**

구본 `ball.png` 실패: 1104×1104에 공이 931px(84%)만 채워 실제 표시 **53px**.
충돌은 57.6px(base)/64px(변종) → 최대 **11px 어긋남**, 즉시 FAIL.
**글로우·트레일은 텍스처에 절대 굽지 않는다** (VFX가 Line2D로 따로 처리).

## 확정 수치

- 표시 지름: 코드 기본 64px이지만 **실제 보드 씬은 44px** → [[pinball-logue]] 크기표
- 텍스처 **1024×1024 RGBA**, 알파 bbox = 캔버스 전체
- 팔레트(플리퍼 확정본 추출): 잉크 `#0B0B0C` / 아이보리 `#F0E0C3` / 하이라이트 `#FFFBFC` /
  청록 밝음 `#7FC9B4` / 기본 `#4FA692` / 짙음 `#2F7A69` / 코어 `#16423C`
- 껍질(회전 대칭): 잉크 482~512 · 아이보리 테 436~482 · 청록밝음 396~436 · 짙은 디스크 r300
- 코어(+X로 40 이동): 아몬드 잉크 296×176, 코어 274×158, 동공 원 +52 r104, 빛줄기 −62 176×26

**아이보리 테두리가 어두운 보드 위 시인성의 핵심**이다. 얇게 하면 배경에 묻힌다.

## ★ 플리퍼 축 눈알과의 구분

플리퍼 회전축 장식이 **게임 크기 약 70px 눈알**이라 공과 크기가 비슷하다.
구분 수단: 플리퍼 눈은 **주황 선버스트 스파이크 + 아이보리 링**, 공은 **스파이크 없는 매끈한 원**.
→ **공에 주황을 절대 넣지 않는다.** 44px에서는 공이 더 작아 혼동 여지가 더 줄어든다.

## STEP 2~3 실측 — 보드와 결과가 달랐다

Leonardo Nano Banana 2, 여백판 레퍼런스, Style `None`, 1:1 4096×4096, 4장, 640크레딧.

**보드에서 겪은 체계적 실루엣 편향이 공에서는 안 나타났다.** 대상이 원 하나이고
여백판이 형태를 못 박아준 덕이다. 형태 보정 없이 마스킹만으로 끝났다.

- 적합 원 중심 (2047.69, 2047.83) — 캔버스 중심에서 **0.35px**
- 적합 반지름 1516.67 — 여백판 이론값 1515.5 대비 **+1.2px**
- 원 적합 잔차 평균 **0.29px** (1440 샘플 중 1435 채택)
- 팔레트 재현도 목표 반경 26 안에 **86.9%**, 청록 표면 표준편차 **2.6**
  (보드 원판이 sd 15.5로 FAIL이었던 것과 대비. 4배 다운샘플이 JPEG 아티팩트를 지운다)

## 진행방향 응시 시스템 (구현·테스트 통과)

```
scripts/ball_base_system/vfx/ball_gaze_visual.gd   BallGazeVisual (Node2D)
scripts/ball_base_system/vfx/ball_gaze_rules.gd    BallGazeRules (Resource)
settings/balls/BallGazeRules.tres                  threshold 120 / sharpness 18 / instant_on_spawn true
tests/ball_base_system/ball_gaze_visual_test.gd    테스트 8종 PASS
```

**`pinball.gd`는 한 줄도 안 고쳤다.**

### ★ 실행해서만 잡히는 버그 두 개 (반복 금지)

1. **`lerp_angle(global_rotation, ...)` 로 보간하면 안 된다.** `global_rotation`을 읽어 보간하면
   매 프레임 부모 바디가 돌려놓은 만큼이 오차로 섞여 **회전 속도에 비례한 고정 오차**가 남는다.
   (3rad/s + sharpness 18 → 0.19rad = 프레임당 밀림 0.05 ÷ 따라잡는 비율 0.259)
   → **자체 각도 변수 `_current_angle`을 보간**하고 그 결과를 `global_rotation`에 대입한다.
2. 그래도 한 스텝 지연(0.05rad)이 남는다. 우리가 쓴 뒤 물리 서버가 바디를 한 번 더 돌리기 때문.
   → **`top_level = true`** 로 부모 변환을 끊고 위치를 직접 따라간다. 이게 유일한 정답.

`sharpness 18` 체감: 90% 도달 128ms / 99% 도달 256ms. 지수 감쇠라 프레임레이트 독립.

## 현재 상태

- `Resources/Art/balls/cats_eye_ball.png` — 최종 텍스처
- `Resources/balls/base/base_ball.tscn` — 텍스처 교체 + `Visual`에 BallGazeVisual + `_GlowOutline` 추가
- `docs/ball_guides/` — 마스터·여백판·검수시트·인게임합성·최종검수·가이드·스크립트·VFX 렌더
- 변종 6종(`dead/rubber/super`, `heavy/light/normal`)은 base 상속이라 자동 반영

## 남은 일

- 변종별 전용 아트 여부 (현재 base 1종 공유)
- 피격·저주 상태 표현 / 발사·조준 UI
- 동공이 충돌 지점을 보는 연출 (문서상 프로토타입 제외 항목)

## 파일명 주의

`SendUserFile`이 한글 파일명을 깨뜨린다(자모 분리). **전달 파일명은 ASCII로** 짓는다.
