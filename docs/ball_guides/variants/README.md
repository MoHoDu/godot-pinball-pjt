# 보상 공 5종 — 아트 리소스 맵

> 2026-08-03 / 근거: `핀볼_PL_비주얼_사운드방향성가이드_강보현 (6).pdf` (33쪽, 보상 공 5종 전용)

## 제작 원칙

**껍질은 확정본에서 픽셀째 재사용한다.** 외곽 잉크선·아이보리 유리 외곽·두꺼운 반사면·하이라이트는
`Resources/Art/balls/glass_eye_ball.png` 에서 가져왔고, 손그림 윤곽선도 각도별 배열로 추출해 그대로 썼다.

- 동공 반지름 **192 ± 3px** · 홍채 잉크 링 **372~384px**(두께 11.9) — 5종 전부 동일
- 껍질 재색은 팔레트 맵: `ink → 공별 외곽선`, `white → 공별 하이라이트`
- **공별로 새로 만든 것**: 홍채 구조·색, 동공 내부 장식, 외곽선 색, 하이라이트 색

**Leonardo는 홍채 질감 단계에만 쓴다.** 5종을 통째로 생성하면 껍질이 5개 다 달라지고,
body/pupil 분리 출력도 안 되며, 44px에서 14px인 동공 장식은 화소를 직접 찍어야 한다.

**장식 크기 기준은 44px.** 22px 흐린 눈 테스트에서 사라지는 것은 허용한다.

## 파일 배치

### 본체 (문서 12-1 MUST)
```
Resources/Art/balls/variants/
  Ball_Clockwork_Body.png    Ball_Clockwork_Pupil.png
  Ball_Rubber_Body.png       Ball_Rubber_Pupil.png
  Ball_Gel_Body.png          Ball_Gel_Pupil.png
  Ball_Lead_Body.png         Ball_Lead_Pupil.png
  Ball_HollowBell_Body.png   Ball_HollowBell_Pupil.png
```
1024×1024 RGBA · **알파 bbox = 캔버스 전체** (`refresh_ball_size()`가 긴 변으로 나누므로 필수)

### VFX (문서 12-1 MUST)
```
Resources/Art/vfx/balls/
  Trail_{공}.png         512×128  Line2D.texture 용. 왼쪽이 머리, 오른쪽이 꼬리 끝
  ParryRing_{공}.png     256×256  패링 파동. 종료 반지름 90~120px 기준
  Particle_{공}_{종류}.png  64×64   전용 입자
settings/balls/glow/
  BallGlowOutlineRules_{공}.tres   발광 테두리 프리셋
```

입자 종류: `gear`·`dust`(태엽) / `drop`·`drop_s`(고무막) / `bubble`·`bubble_s`(젤) /
`flake`·`flake_s`(납심) / `ring`·`prism`·`star`(속빈 방울)

### 상태·연출 (문서 12-2 SHOULD + 3-4)
```
Resources/Art/vfx/balls/
  TrailFast_{공}.png     768×128  고속 이동 꼬리. 일반보다 길고 코어 강화, 감쇠 완만
  HitSpark_{공}.png      192×192  공별 충돌 입자 — 형태가 공마다 다르다
  ComboStar_{공}.png     128×128  최고 콤보 전용 별 잔상
  Overlay_Curse.png     1024²    저주 상태 공통 오버레이 (보라 + 라임)
  Overlay_Danger.png    1024²    피격 상태 공통 오버레이 (진홍 + 핫핑크)
```

충돌 입자는 문서 3-4("충돌 입자 방향·VFX 길이를 공별로 다르게")대로 **형태 자체를 갈랐다.**

| 공 | 충돌 형태 |
|---|---|
| 정속 태엽눈 | 직선 스파크 8개 — 규칙적 |
| 고무막 | 둥근 튀김 — 탄력 |
| 완충 젤 | 뭉툭한 번짐 — 완충 |
| 납심 | 날카로운 4방향 — 정밀 |
| 속빈 방울 | 고리 파편 — 혼돈 |

상태 오버레이는 **중심을 비워 동공 가독성을 지킨다.** 프로토타입 금지 항목인 균열 대신 작은 점 6개를 쓴다.

### 보상 카드 (문서 12-2 SHOULD)
```
docs/ball_guides/variants/Card_{공}.png    480×640
```

## 공별 값

| 공 | 주색 | 외곽선 | 청록 면적 | 발광 테두리 |
|---|---|---|---|---|
| 정속 태엽눈 | 앰버 `#E3A63F` | 짙은 갈색 `#2B1B12` | 6.3% | peak 0.55 · bands 5 · drift 0.45 · wobble 0.02 |
| 고무막 유리눈 | 탠저린 `#E8763A` | 자주빛 갈색 `#3A1A22` | 8.4% | peak 0.65 · bands 5 · drift 0.75 · wobble 0.09 |
| 완충 젤 유리눈 | 피스타치오 `#A9C87C` | 먹빛 청회색 `#2A3038` | 7.8% | peak 0.48 · bands 6 · drift 0.35 · wobble 0.03 |
| 납심 유리눈 | 스모크 `#6E727C` + 금 `#C8A244` | 가장 짙은 남색 `#080C16` | 5.3% | peak 0.52 · bands 4 · drift 0.28 · wobble 0.02 |
| 속빈 방울눈 | 라벤더 `#C6B2DE` + 금 `#D9B34C` | 짙은 보라 남색 `#171224` | 7.3% | peak 0.60 · bands 5 · drift 0.85 · wobble 0.07 |

공통 유지: 아이보리 `#F0E0C3` 31~38% · 청록 `#4FA692` 5.3~8.4% (문서 권장 5~10%)

## 패링 파동 — 공별 구조

문서 서술대로 갈랐다. 색만 다른 게 아니다.

- **정속 태엽눈**: 앰버 메인 + 아이보리 보조 + 청록 눈금 조각 12개 + 일정 간격 방사선 8개
- **고무막**: 메인 링이 타원(세로 0.80배) + 청록 중심 플래시
- **완충 젤**: 방사선 없음. 두껍고 완만한 링 3겹
- **납심**: 정제된 금빛 면 + 청록 보조 링 + 날카로운 방향선 4개
- **속빈 방울**: 라벤더 메인 + 청록 링 + 금빛 방울 스파크 6개

## 엔진 제약

`gl_compatibility` 렌더러라 **GPUParticles2D 트레일이 지원되지 않는다.**
꼬리는 Line2D + texture, 파동·입자는 스프라이트가 유일한 안전 선택이다.

## 남은 것

**MUST**
- 공별 SFX — 재질음 3종 + 패링 악센트 1종 (아트 아님. **2026-08-03 형락님 지시로 보류**)

**선행 확인 필요**
- 기존 변종 6종(`elastic_var` dead/rubber/super, `mass_var` heavy/light/normal)과의 매핑.
  정속 태엽눈이 새 씬인지, `super_ball`·`normal_ball`을 어떻게 할지 미정
- 노드 구조 변경 (문서 12-3): `BallVisual > BodySprite + PupilSprite + Outline + Trail +
  IdentityParticles + ParryVFX + AudioController`. 현재 `base_ball.tscn`은 Sprite2D 하나
- **이동 꼬리 시스템 자체가 미구현.** 텍스처는 준비됐으나 Line2D 링버퍼 구현이 필요하다

## 재현 스크립트

```
extract.py   확정본에서 손그림 윤곽 + 껍질 + 하이라이트 마스크 추출
build.py     본체·동공 5종
vfx.py       꼬리·파동·입자
tres.py      발광 테두리 프리셋
cards.py     보상 카드
```
