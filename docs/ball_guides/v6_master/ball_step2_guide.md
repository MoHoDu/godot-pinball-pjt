# 공 STEP 2 — 질감 입히기 (Leonardo)

> Pinball_Logue / 2026-08-03
> 대상 마스터: `ball_v7_rough_1024.png` (V4 큰 홍채 · 홍채 중앙 정면 응시 · 굶지마풍 거친 잉크선)

---

## 0. 이 단계가 하는 일 / 안 하는 일

**카툰 화풍을 새로 입히는 단계가 아니다.** 평탄 셀·굵은 잉크선·다크 카툰은 이미 마스터에 들어 있다.

| 맡긴다 | 절대 안 맡긴다 |
|---|---|
| 잉크선의 **우연한** 떨림·번짐·붓 갈라짐 | **실루엣** — 원의 중심·반지름 |
| 손으로 그은 티 (수식으로는 못 만드는 불규칙) | 요소 배치 — 홍채·동공·하이라이트 위치 |
| 낱개로 셀 수 있는 붓 마크 2~3개 | 팔레트 |

이전 캣츠아이 STEP 2에서 실제로 얻은 것: **손그림 아크 스트로크 5~6개 + 잉크선 두께의 미세한 흔들림.**
마스터의 기계적인 완벽함이 사라진 것, 그게 이 단계를 도는 유일한 이유다.

**44px에서는 대부분 안 보인다.** 남는 건 잉크선 인상뿐이다.

---

## 1. 화풍 목표 — 굶지마 잉크선 (2026-08-03 형락님 지시)

형락님이 굶지마 눈알 몬스터를 레퍼런스로 지목했다. 그 그림에서 가져올 것과 버릴 것:

| 가져온다 | 버린다 |
|---|---|
| 잉크선 두께가 **크게 널뛴다** — 굵은 데와 가는 데가 5배 차이 | **빨간 촉수·다리** |
| 한 방향으로 **붓 압력**이 실려 한쪽이 굵다 | **핏줄·살·고어** |
| 선이 급하게 그은 티 — 약간 삐뚤고 끝이 뾰족하다 | 찌그러진 실루엣 (우리는 완벽한 원) |
| 따뜻한 검정 잉크 (순검정 아님) | 사실적 음영·질감 |

**빨강을 버리는 이유**: 기능색 규칙에서 빨강·핫핑크 = 피해와 위험이다.
공에 빨강이 들어가면 플레이어가 자기 공을 위험 요소로 읽는다.

**레퍼런스 이미지를 Leonardo에 통째로 넣지 않는다.** 보드 작업에서 레퍼런스의 워터마크까지
베껴 그린 전례가 있다. 촉수·다리·빨강이 딸려온다. 대신 아래 화풍 목표판을 쓴다.

### 절차적으로 이미 넣은 것 (마스터 `ball_v7_rough_1024.png`)

- 외곽 잉크선 두께 **13.0 ~ 72.0px @1024 (5.5배 변동)** — 44px 환산 0.56 ~ 3.09px
- 붓 압력 방향 **232°** (좌하단이 굵다) — 외곽·홍채·동공에 공통 적용
- 끝이 뾰족하게 빠지는 덧그은 스트로크 3개
- **실루엣은 안 건드렸다** — 원 적합 반지름 512.08 ± **0.31px** (안티에일리어싱 판정 폭)

절차적으로 낼 수 있는 건 여기까지다. 진짜 손그림의 불규칙은 Leonardo가 채운다.

---

## 2. 레퍼런스 파일

| 파일 | 용도 | 강도 |
|---|---|---|
| `ball_v7_step2_reference_plate.png` | **Reference 1 — 형태·배치·팔레트·선질 방향** | **HIGH** |
| `docs/board_guides/플리퍼_화풍_목재결.png` | Reference 2 — 잉크선 질감만 (선택) | LOW~MID |

### 여백판 규격

- 1024×1024 · 공 지름 **758px (74%)** · 사방 여백 **133px** · 배경 `#161925`
- 이론 반지름 379px → 4096으로 생성하면 1516px

**여백을 두는 이유**: 보드 작업에서 생성물이 프레임에 닿아 마스킹으로 rim을 못 없앤 실패가 있었다.
여백 안에서 끝나면 모델이 뭘 붙이든 원형 마스크로 8방향이 똑같이 깨끗하게 잘린다.

**플리퍼 원본을 통째로 넣지 않는다** — 눈·이빨·볼트·별·주황 스파이크가 딸려 나온다. 크롭본만.

---

## 3. Leonardo 세팅

**1순위 — Nano Banana 2**

| 설정 | 값 |
|---|---|
| Image Reference | 여백판 1장, Strength **HIGH** |
| Style preset | **None** ← `Game Concept`은 둘레에 밝은 rim을 붙인다 |
| Prompt Enhance | **Off** |
| 비율 | **1:1**, 생성창이 제시하는 값 중 가장 큰 것 |
| 수량 | 4 |
| Fixed Seed | 탐색 단계엔 끔. 마음에 드는 컷이 나오면 그 시드로 고정 |

**2순위 — Phoenix 1.0** (네거티브 프롬프트가 진짜로 필요할 때)
Content Reference `HIGH` + Style Reference `플리퍼_화풍_목재결.png` `MID`, Contrast Medium.

다운로드는 PNG가 아니라 **JPG로 나온다.** 4배 다운샘플이 있으므로 아티팩트는 지워진다.

---

## 4. Positive Prompt (영문 전문)

```text
A single glass eye marble from a cursed toy, drawn as flat 2D dark-cartoon game art,
centered on a plain dark navy background with generous empty margin on all four sides.

This is a polished glass marble, not an organic eyeball. There is no white sclera,
no eyelid, no lashes, no veins, no flesh, no wetness, no tentacles, no legs, no limbs.
Everything inside is sealed under smooth glass.

The reference image is the exact design to follow. Keep the same perfectly circular
silhouette and the same concentric layout: a pale ivory glass shell around the edge,
one large teal iris in two flat value steps, one round black pupil at the exact center,
one thick pale reflection sweeping along one side of the outer glass edge, one strong
white highlight and one small secondary highlight. Do not move, resize, restyle,
duplicate or remove any of these shapes. The pupil stays centered and perfectly round.

Line quality is the most important thing. Every ink line is drawn by hand with a loaded
brush or dip pen, in warm near-black ink, never a uniform vector stroke. The line swells
thick where the brush presses down and thins almost to nothing elsewhere, changing
weight dramatically along its length, and the thick side is consistent as if one hand
drew it in one pass. The edges of the ink are slightly uneven and a little crooked, with
occasional small overshoots and tapered stroke ends. Despite all this, the outer
silhouette of the marble still reads as a true circle - only the weight of the line
varies, never the roundness.

Flat cel fills with at most two value steps per colour, hard edges. No gradients, no
soft shading, no ambient occlusion, no drop shadow. Add only a few individually
countable hand-drawn marks: two or three short curved brush strokes in the teal
suggesting glass sheen. Keep them sparse and clearly separate. Do not turn them into
a texture, and do not draw cracks.

Palette exactly: ivory #F0E0C3, light teal #7FC9B4, teal #4FA692, deep teal #2F7A69,
warm near-black ink #0E0E14, highlight #FFFBFC. Do not introduce red, orange, purple
or brown anywhere.

Flat orthographic top-down. No light source, no directional lighting, no rim light,
no bevel, no thickness, no environment reflection. The bright sweep on the glass is a
material reflection, not a lit side.

Keep the background completely empty and flat. Do not add flippers, machines, hands,
spikes, sunbursts, tentacles, creatures, text, numbers, watermarks, logos, frames,
borders, sparkles, glow or particles. Exactly one marble and nothing else.
```

### 이전 캣츠아이 프롬프트와 달라진 점

- 이번엔 **눈이 맞다.** `eyeball`을 무조건 금지하지 않고 `glass eye marble`로 쓴다.
  다만 흰자·눈꺼풀·속눈썹·핏줄·살은 여전히 금지.
- `almond-shaped inclusion` → `round black pupil at the exact center`
- **선질 문단을 통째로 새로 넣었다** — 이번 요청의 핵심이라 분량을 가장 많이 줬다
- **`tentacles` / `legs` / `limbs` / `creatures` 를 금지에 명시** ← 굶지마 레퍼런스에서 딸려올 것들
- **`sunburst` / `spikes` 금지 명시** ← 플리퍼 축 눈의 시그니처라 붙으면 안 된다
- `thick pale reflection along one side of the outer glass edge` 추가 (3-6 재질 규격)
- **"선 두께는 변하되 실루엣은 진짜 원"** 을 한 문장으로 못 박음 ← PL 정정 반영

---

## 5. Negative Prompt

Phoenix 1.0 / 0.9 네이티브. 그 외 모델에서는 위 Positive의 금지 문단이 본체다.

```text
sclera, eyelid, eyelashes, veins, blood, flesh, organic, gore, wet, tentacles, legs,
limbs, creature, monster body, glossy specular, photograph, photorealistic, 3d render,
ray tracing, gradient shading, soft shadow, drop shadow, bevel, emboss, glow, bloom,
sparkles, particles, cracks, sunburst, spikes, star burst, rivets, screws, socket,
machine parts, text, watermark, logo, signature, frame, border, multiple marbles,
uniform line weight, vector art, clean flat outline, orange, red, purple, brown
```

`uniform line weight` / `vector art` / `clean flat outline` 을 네거티브에 넣은 건
이번 요청 때문이다. 매끈한 선으로 되돌아가는 걸 막는다.

---

## 6. STEP 2 검수 체크리스트

**선질 (이번 요청의 핵심 — 여기부터 본다)**

- [ ] 잉크선 두께가 **눈에 띄게 변한다** (한 바퀴 도는 동안 굵은 데와 가는 데가 확실히 다르다)
- [ ] 굵은 쪽이 **한 방향으로 일관**된다 (여기저기 무작위로 굵으면 손그림이 아니라 노이즈다)
- [ ] 선 가장자리가 매끈한 벡터가 아니다
- [ ] 그런데도 **외곽은 여전히 원**이다 — 찌그러졌으면 FAIL

**형태 (하나라도 걸리면 재생성)**

- [ ] 공이 프레임에 닿지 않고 사방 여백이 남아 있다
- [ ] 동공이 **정중앙**에 있고 둥글다 (기울거나 밀리지 않았다)
- [ ] 홍채·동공·하이라이트가 하나씩만 있다 (복제 없음)
- [ ] 아이보리 유리 테가 끊기지 않고 한 바퀴 돈다

**화풍**

- [ ] 그라디언트·드롭섀도·비네팅·소프트 글로우가 없다
- [ ] 손그림 마크가 **낱개로 셀 수 있는** 수준이다 (텍스처가 되면 FAIL)
- [ ] 균열이 안 생겼다 (프로토타입 미제작 항목)

**금지물**

- [ ] **빨간 촉수·다리·핏줄이 없다** ← 굶지마 레퍼런스에서 딸려올 1순위
- [ ] **주황 선버스트·스파이크가 없다** ← 플리퍼 축 눈과 혼동되는 즉시 FAIL
- [ ] 흰자·눈꺼풀·속눈썹이 없다
- [ ] 빨강·주황·보라·갈색이 없다
- [ ] 워터마크·텍스트·프레임이 없다

**최종 관문**

- [ ] **44px로 줄여도 아이보리 테 / 청록 홍채 / 검은 동공 3단이 구분된다**
- [ ] 44px에서 플리퍼 축 눈(47px)과 나란히 놓고 헷갈리지 않는다

---

## 7. STEP 3 — 마스킹 (내가 처리)

1. 생성물에서 공의 중심과 반지름을 **서브픽셀**로 측정 (방사 샘플 1440개 원 적합)
2. 마스터 원(중심 512, 반지름 512)에 맞도록 스케일·이동
3. 반지름을 **2~3px 안쪽으로** 파고들어 오려낸다 (가장자리 rim 잔재 제거)
4. 알파 마스크를 씌워 **1024×1024 RGBA** 출력, 알파 bbox가 정확히 1024×1024인지 재검증

이전 공 작업 실측: 중심 오차 0.35px, 반지름 오차 1.2px, 원 적합 잔차 평균 0.29px.
**대상이 원 하나면 보드에서 겪은 체계적 실루엣 편향이 안 나타난다.** 형태 보정 없이 마스킹만으로 끝났다.

재현 스크립트는 `docs/ball_guides/ball_step3_mask.py` 를 그대로 쓸 수 있다.

⚠️ 마스킹은 실루엣을 원으로 강제하므로, 생성물의 외곽이 조금 찌그러져 있어도 잘려서 원이 된다.
**단, 잘리면서 잉크선의 가는 부분이 사라질 수 있다.** 인셋을 2px로 줄이고 결과를 확대해서 확인할 것.

---

## 8. 형락님이 할 일

1. Leonardo에서 위 세팅으로 4장 생성
2. **다운로드 파일을 프로젝트 폴더로 옮겨주기** — 다운로드 폴더에 있으면 내가 못 읽는다
3. 4장 다 주시면 검수하고 제일 나은 걸로 STEP 3 마스킹까지 진행

썸네일이 아니라 **원본 해상도**로 봐야 한다. 다운샘플 블러가 얇은 선을 부풀려서
이전에 rim 폭을 20~30px로 과대추정한 적이 있다 (실제 4~8px).
