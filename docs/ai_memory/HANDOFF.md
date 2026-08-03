# 인계 메모 — 2026-08-03 세션 종료 (VFX ②까지 완료, 다음은 VFX ③ 패링 파동)

> 다른 컴퓨터에서 이어받는 Claude에게. `MEMORY.md` 를 읽기 전에 이걸 먼저 봐도 된다.
> 해커톤 마감 **2026-08-10**. 작업 브랜치 `VFX/Test`.

---

## 0. 시작할 때 지켜야 할 것

1. **승인 없이 산출물을 만들지 않는다.** 계획 → 승인 → 실행 → [[workflow-rules]]
   (조사·문서 읽기·현황 파악은 바로 해도 된다)
2. **코드를 짰으면 반드시 돌려본다.** 다만 지금 **컨테이너에서 Godot을 못 받는다**
   → [[godot-install-blocked]]. 엔진 없이 하는 대체 검증 목록이 거기 있다.
3. **모든 아트는 형태 → 텍스처 → 디테일 3단계.** 단계마다 검수 → [[staged-art-pipeline]]
4. **실루엣은 AI에게 맡기지 않는다.** 생성물에서 색·표면만 가져오고 형태는 좌표로 확정한다.

---

## 1. 이번 세션에서 한 일

### 공 리소스 최종 확정
캣츠아이를 폐기하고 **기획서 원안**(큰 청록 홍채 + 둥근 검은 동공 + 아이보리 외곽)으로 회귀했다.
→ `Resources/Art/balls/glass_eye_ball.png`, `base_ball.tscn` 연결 완료. 상세 [[ball-v6-redesign]]

기억할 수치: 알파 bbox **1024×1024**(캔버스 내접 필수) · 외곽 잉크 바깥 경계 **511.45 ± 0.114px** ·
잉크 두께 44px 환산 **0.80px**.

### 보상 공 5종 아트 전부
정속 태엽눈 / 고무막 / 완충 젤 / 납심 / 속빈 방울눈. **63개 파일.** 상세 [[ball-reward-variants]]

핵심 기법: **껍질을 확정본에서 픽셀째 재사용**한다. 손그림 윤곽선까지 각도별 배열로 추출해 썼다.
공별로 새로 만든 건 홍채·동공·외곽선색·하이라이트색뿐이다.

### VFX ① 안개 오라 — 구현 완료
Line2D 링을 버리고 **셰이더 안개**로 리디자인했다. 외곽 40px 확정. → [[vfx01-mist-aura]]

### VFX ② 이동 꼬리 — 구현 완료, 형태 확정
**2겹 구조**(안쪽 흰 레이저 + 바깥 청록 블룸), 길이 140px, 레이저 뿌리 9px / 블룸 뿌리 60px,
밝기는 길이 방향 4단 계단. 실루엣은 **삼각형(올챙이 꼬리)** — 테이퍼 지수 1.0. → [[vfx02-trail]]

인게임 영상 피드백으로 잡은 것 세 가지. 전부 **수치·시뮬레이션으로만 잡히는** 종류다:

1. **감속하면 꼬리 끝이 제자리에 얼어붙는다** — 궤적 점에 수명이 없었다. `point_lifetime` 0.22s 추가
2. **느린 공에서 꼬리가 점 하나로 붕괴한다** — 간격 검사를 "매 프레임 움직이는 머리"와 하고 있었다.
   **마지막으로 확정된 점(`_history[1]`)** 과 비교해야 한다. 고속에서만 우연히 동작하고 있었다
3. 꼬리 끝에서 1px 경계 완화가 레이저보다 넓어져 **밝기 계단이 22단으로 뭉개졌다**

### 테스트 씬에 공 종류 전환 추가
`test_ball_physics` 에서 **숫자키 1~7 로 공 종류 교체**, 0 으로 기존 7종 비교 화면 복귀.
VFX 검수는 이제 여기서 한다. → [[test-scene-controls]]

---

## 2. ★ 다음 사람이 밟기 쉬운 지뢰 3개

### ① 꼬리 리본 PNG를 씬에 물리지 말 것
`Resources/Art/vfx/balls/Trail_*.png` · `TrailFast_*.png` 는 **컨셉 참고물이다.**
이동 꼬리는 이미 셰이더로 구현돼 있고(`Resources/shaders/ball_trail.gdshader`),
색을 uniform 5개로 받는다. 아트 슬롯이 없다.
→ 공별 꼬리는 `settings/balls/trail/BallTrailRules_{공}.tres` 로 연결한다.

### ② 새 공 텍스처는 채움률부터 본다
`refresh_ball_size()` 가 **텍스처 긴 변**으로 나눈다. 캔버스에 여백이 있으면 그만큼 작게 그려지고
충돌 크기와 어긋난다. 이번 세션에서만 두 번 밟았다(구본 `ball.png`, 형락님이 올린 최종본 764px).
→ **알파 bbox == 캔버스 크기**를 먼저 확인할 것. → [[ball-texture-fixed]]

### ③ 수치가 기준을 벗어났다고 결함이 아니다
검수 수치 3건을 "문제"로 보고했는데 형락님이 **전부 의도한 것**이라고 했다.
수치는 그대로 보고하되 "고쳐야 한다"가 아니라 **"이런 상태다"** 로 제시하고 판단을 넘긴다.

---

## 3. 지금 걸려 있는 것

### 즉시 필요 — 형락님 로컬에서 엔진 테스트
컨테이너에서 Godot 을 못 받아 **아래 전부 미실행**이다. 다른 컴퓨터에 엔진이 있으면 먼저 돌릴 것.

```
godot --headless --path . --import
godot --headless --path . --script res://tests/ball_base_system/pinball_size_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_gaze_visual_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_glow_outline_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_trail_test.gd
godot --headless --path . --script res://tests/ball_base_system/test_ball_physics_scene_test.gd
```

`ball_trail_test.gd` 12종 · `test_ball_physics_scene_test.gd` 6종이 새로 추가됐고 둘 다 미실행이다.
정적 검사(`gdparse`)와 셰이더 실행 검증은 통과했지만 **씬 트리·시그널·물리는 엔진에서만 확인된다.**

**엔진에서만 확인되는 것 2건:**

- `ball_trail.gdshader` 는 Line2D 의 `UV.x = 0` 이 **공 쪽**이라고 가정한다.
  뒤집혀 있으면 셰이더에서 `t = 1.0 - UV.x` 한 줄로 끝난다
- 꼬리가 여러 개 겹칠 때 어느 게 어느 공 건지 갈리는지

### 결정 대기 — 보상 공 5종을 어느 씬에 붙일지
코드는 `elastic_var`(dead/rubber/super) + `mass_var`(heavy/light/normal) **6종**인데
문서는 **5종**이고 이름·성격이 다르다.

고무막=rubber / 완충 젤=dead / 납심=heavy / 속빈 방울=light 까지는 보이지만
**정속 태엽눈은 대응이 없고 `super_ball`·`normal_ball` 이 남는다.** PL·형락님 확인이 필요하다.

### ★ 다음 순번 — VFX ③ 패링 원형 파동
2026-08-03 형락님이 "꼬리는 넘어가고 패링 VFX로" 라고 지시했다. **이것부터 하면 된다.**

텍스처 5종(`Resources/Art/vfx/balls/ParryRing_*.png`)은 있으나 시스템이 없다.
비주얼 가이드 3-5 확정 수치:

- **정확한 패링에만.** 일반 플리퍼 타격에는 쓰지 않는다
- 시작 반지름 25~30px → 종료 90~120px · 전체 0.12~0.20초
- 중심 플래시 0.03~0.06초 · 링 두께 4~8px
- 중심을 타격 방향으로 2~5px 이동
- 색은 밝은 청록 + 아이보리·**금색**. 금색은 여기서만 쓴다(발광 테두리에는 안 쓴다)
- **빨강을 주색으로 쓰지 않는다** — 피해 연출로 오해한다

붙일 곳은 이미 있다: 플리퍼의 `parry_resolved` 시그널.
`BallGlowOutline._on_parry_resolved()` 가 `PARRY_GRADE_PERFECT` 를 거르는 방식 그대로 쓰면 된다.
레이어는 발광 테두리(10)보다 위.

### 미착수
- **공 SFX** — 파일럿(정속 태엽눈)만. 2026-08-03 형락님 지시로 **보류** → [[sfx01-ball-pilot]]
- 노드 구조 변경 (문서 12-3): `BallVisual > BodySprite + PupilSprite + Outline + Trail +
  IdentityParticles + ParryVFX + AudioController`. 현재 `base_ball.tscn` 은 Sprite2D 하나
- 삼각형 보드 / 범퍼·유물·코인·보스
- **경로 대소문자 17곳** — Linux/macOS 익스포트 시 전부 깨진다. 아직 승인 안 받음 → [[path-case-issue]]

### 정리 가능
`Resources/Art/balls/` 의 `ball.png` · `cats_eye_ball.png` · `industrial_steel_ball.png` —
코드·씬 참조 **0건**.

---

## 4. 원본 기획 문서

- 보상 공 5종 전용: `핀볼_PL_비주얼_사운드방향성가이드_강보현 (6).pdf` (33쪽)
- 비주얼·사운드 가이드 / 플리퍼 시스템 기획서 / 컨셉기획서: `docs/source_materials/pdfs/`
- Leonardo 모델별 세팅: `docs/LEONARDO_AI_MODEL_HANDOFF.md`

## 5. 아트 산출물 위치

```
Resources/Art/balls/glass_eye_ball.png          기본 공 확정본
Resources/Art/balls/variants/                   보상 공 5종 본체·동공
Resources/Art/vfx/balls/                        공 VFX 텍스처 (Trail_* 은 참고물)
settings/balls/glow/                            발광 테두리 프리셋 5종
settings/balls/trail/                           이동 꼬리 프리셋 5종
docs/ball_guides/v6_master/                     기본 공 마스터·STEP2 가이드
docs/ball_guides/v7_final/                      마스킹 결과·검수 시트
docs/ball_guides/variants/                      보상 공 README·카드·재현 스크립트·검수 시트
```

재현 스크립트가 전부 남아 있으므로 **색·수치만 바꿔 다시 뽑을 수 있다.**
