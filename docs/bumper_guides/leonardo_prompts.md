# 범퍼 Leonardo 프롬프트

> 2026-08-05 / 짝 문서: `bumper_production_guide.md`
> 모델 사양 근거: `docs/LEONARDO_AI_MODEL_HANDOFF.md` (최종 검증 2026-08-03)
> **생성 직전에 현재 Leonardo UI 를 다시 확인할 것.** 모델과 옵션은 바뀐다.

---

## 0. 먼저 — 형태판을 레퍼런스로 넣을지 말지

`step2_plates/*_plate.png` 는 **코드로 그린 배치 도면이지 완성 아트가 아니다.**
단추처럼 단순한 것은 쓸 만하지만 북의 목마, 솜 내부는 조악하다.

**이걸 HIGH 로 넣으면 모델이 조악함까지 그대로 재현한다.** 그래서 두 갈래로 나눈다.

| | 트랙 A — 형태판 사용 | 트랙 B — 텍스트만 |
|---|---|---|
| 얻는 것 | 배치·비율·충돌 원 일치가 정확 | 그림 품질이 높다 |
| 잃는 것 | 그림이 도면에 끌려간다 | 실루엣이 매번 달라진다 |
| Reference 1 | 여백판 **MID** (HIGH 아님) | `Flipper_cartoon.png` **MID** |
| Reference 2 | `Flipper_cartoon.png` LOW/MID | — |
| 권장 대상 | **대포, 미끄럼틀, 단추** (구조가 기능) | **솜, 북, 용수철 인형** (덩어리가 전부) |

★ 트랙 A 에서 **HIGH 가 아니라 MID 를 쓰는 이유**: HIGH 는 픽셀을 베끼고
MID 는 배치를 따르되 다시 그린다. 형태판이 완성 아트가 아니므로 MID 가 맞다.
프로젝트 원칙 "실루엣은 AI 에 안 맡긴다"는 유지된다 — 배치는 여전히 도면이 정한다.

**대포만은 예외로 형태판을 반드시 쓴다.** 포신이 +X 기준이어야 하고
포구가 받침대 원 안에서 끝나야 런타임 회전과 충돌 판정이 맞는다.

---

## 1. 모델 세팅

### 1순위 — Nano Banana 2

| 설정 | 값 |
|---|---|
| Image Reference | 위 표대로 (최대 6장, Strength LOW/MID/HIGH) |
| Prompt Enhance | **Off** — On/Auto 는 프롬프트를 늘려 장식을 붙인다 |
| Fixed Seed | 같은 구도의 변형 비교에만 |
| 수량 | 탐색 4, 확정 1~2 |
| 해상도 | 탐색 1376×768 → 확정 2752×1536 |

### 2순위 — Phoenix 1.0

네이티브 `negative_prompt` 를 지원하는 축이다. 금지 조건이 계속 새면 이쪽으로 옮긴다.
Content Reference = 여백판, Style Reference = 플리퍼. **프롬프트 상한 2,000자** (4절 참고).

### 쓰지 말 것

- **GPT Image 2** — Reference Strength 지정 불가. 형태 보존 강도를 못 잡는다.
- **Krea 2 Turbo** — Reference 자체가 없다.

---

## 2. 복붙용 완성 프롬프트

아래 블록은 **그대로 붙여 넣으면 되는 완성본**이다. 조립할 필요 없다.

블록 첫 문단만 트랙에 맞춰 갈아 끼운다.

**트랙 A 첫 문단** (블록에 이미 들어 있음)

```text
Reference 1 is a flat colour layout diagram, not finished art. Keep its
silhouette, proportions, and the position of every part exactly, then redraw it
as polished hand-inked cartoon art. Reference 2 defines line quality and mood
only; do not copy any object, symbol, or scenery from it.
```

**트랙 B 첫 문단** (위 문단을 이걸로 교체)

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.
```

---

### 2-1. 단추 — `button_plate.png`

```text
Reference 1 is a flat colour layout diagram, not finished art. Keep its
silhouette, proportions, and the position of every part exactly, then redraw it
as polished hand-inked cartoon art. Reference 2 defines line quality and mood
only; do not copy any object, symbol, or scenery from it.

A thick round wooden toy button seen from directly above, with four holes in a
square arrangement. The disc is slightly irregular, not a perfect circle. Main
colour is a low-saturation burgundy rose. A raised outer ring sits darker than
the sunken inner face, and that value difference is the only thing conveying
thickness. Aged brown wood grain runs across the inner face only, as a few long
uneven horizontal strokes. The four holes are dark slate wells with crisp ink
rims. Two dusty purple threads cross between the holes; one thread is frayed and
trails off past the inner face. A short muted ivory highlight sits on the outer
ring at the upper left.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Interior lines are thinner and less
steady than the outline. Slightly crooked, never perfectly symmetrical. An old,
warped, faintly unsettling toy. Muted low-saturation palette that sits on a dark
navy-slate wooden board.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
visible side wall, no cast shadow. Single object, centred, fully inside the
frame with clear empty margin on all four sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or drop shadows. Do not add eyes, teeth, faces, tentacles, skulls,
magic circles, arrows, gauges, text, logos, or watermarks. No photographic
texture, no grunge overlay, no dirt map, no noise, no painterly blending, no 3D
rendering, no specular highlight. No neon, no fluorescent colour, no rainbow, no
pure white area, no saturated primary red.
```

**검수** — 구멍 4개가 탑뷰에서 구분되는가 / 옆면이 노출되지 않았는가 /
목재 결이 안쪽 면 밖으로 나가지 않았는가.

---

### 2-2. 솜 — 트랙 B 권장

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A torn wad of stuffing cotton seen from directly above, reading as a soft
cushioning pad lying flat on a board rather than a tall fluffy ball. The outline
is an asymmetric cloud of overlapping lobes held by one continuous bold ink line,
with no internal lobe outlines. Main colour is a toned-down greyish cream, never
near-white, with a slightly warmer core. Interior detail is only a few broad
sweeping curves nested around one centre, showing which way the cotton is rolled
and bunched; no fine hairs, no fuzz, no stray fibres, no crossing scratches. One
lobe on the lower left is shaded dusty grey-violet. A small square cloth patch in
muted teal is stitched onto the lower right edge with short pale brown stitches.
A crooked pale brown seam crosses the upper area with uneven cross-stitches, and
a single purple thread knot sits at its end. The centre of the wad is left clear
and unobstructed.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Interior lines are thinner and less
steady than the outline. Slightly crooked, never perfectly symmetrical. An old,
worn, faintly unsettling toy. Muted low-saturation palette that sits on a dark
navy-slate wooden board and stays darker than a bright teal glass ball.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
visible side wall, no cast shadow. Single object, centred, fully inside the
frame with clear empty margin on all four sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or drop shadows. Do not add eyes, teeth, faces, tentacles, skulls,
magic circles, arrows, gauges, text, logos, or watermarks. No photographic
texture, no grunge overlay, no dirt map, no noise, no painterly blending, no 3D
rendering, no specular highlight. No neon, no fluorescent colour, no rainbow, no
pure white area, no saturated primary red.
```

**검수** — 중심 타격 위치가 장식에 가리지 않는가 / 잔선이 많아 인게임 크기에서
뭉개지지 않는가 / **공보다 밝지 않은가** (첫 STEP1 에서 실제로 걸린 항목).

---

### 2-3. 용수철 인형 · 기본 — 트랙 B 권장

> ⚠️ 이 범퍼만 **금지 문단에서 `eyes, teeth, faces` 를 뺐다.** 얼굴이 있어야 하는 범퍼다.
> 다른 범퍼 프롬프트를 복사해 쓰면 얼굴이 지워진다.

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A wind-up spring doll seen from directly above in its resting state. A round
doll face in muted aged ivory fills almost the entire bumper and reads as the
impact surface. The spring is hidden underneath; only short gold and dark brass
coil segments peek out at four points around the rim. A thin blue-grey base ring
frames the face. The doll wears a muted mustard cap brim across the top of its
head. Two simple round eyes with bold ink rims, a small crooked mouth, two flat
muted teal cheek dots, and a dusty purple stitch line across the forehead. The
expression is calm and blank — cute, but not quite right.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Interior lines are thinner and less
steady than the outline. Slightly crooked, never perfectly symmetrical. An old,
warped, faintly unsettling toy. Muted low-saturation palette that sits on a dark
navy-slate wooden board and stays darker than a bright teal glass ball.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
visible side wall, no cast shadow. Single object, centred, fully inside the
frame with clear empty margin on all four sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or drop shadows. Do not add tentacles, skulls, magic circles, arrows,
gauges, text, logos, or watermarks. No photographic texture, no grunge overlay,
no dirt map, no noise, no painterly blending, no 3D rendering, no specular
highlight. No neon, no fluorescent colour, no rainbow, no pure white area, no
saturated primary red. Do not show the spring fully; it stays hidden under the
face.
```

**검수** — 얼굴 중심이 충돌 위치와 일치하는가 / 용수철이 상시 노출되지 않았는가.

---

### 2-4. 용수철 인형 · 타격

> ★ **기본 상태를 먼저 확정하고, 그 결과물을 Reference 1 (HIGH) 로 넣어 뽑는다.**
> 따로 뽑으면 팔레트와 선 두께가 어긋난다. 공 보상 5종에서 실제로 밟은 함정이다.

```text
Reference 1 is the approved resting-state artwork of this same doll. Keep its
palette, ink line weight, base ring, cap brim, and cheek dots identical. Only the
pose changes.

The same wind-up spring doll at the moment of impact, seen from directly above.
The round ivory face is squashed and pushed back, compressed into a short wide
oval near the top of the bumper. The short thick coil spring that was hidden
underneath is now fully exposed as four bold gold loops with darker brass on
their back edges, widening toward the bottom. The eyes are squeezed shut into two
short ink lines and the mouth is open as a small dark oval. Same blue-grey base
ring, same mustard cap brim now compressed, same muted teal cheek dots.

Flat 2D dark-cartoon game art. Bold hand-inked outlines with visible thickness
variation, slightly wobbling. Solid flat cel fills, at most two flat value steps
per material. Slightly crooked, never perfectly symmetrical.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
cast shadow. Single object, centred, fully inside the frame with clear empty
margin on all four sides. Plain transparent background.

Do not add glow, bloom, sparkles, particles, motion lines, impact effects, speed
lines, or drop shadows. Do not add text, logos, or watermarks. No photographic
texture, no noise, no painterly blending, no 3D rendering. No neon, no rainbow,
no pure white area, no saturated primary red.
```

**검수** — 기본 상태와 **형태 차이만으로** Bounce 가 읽히는가 / 두 장의 팔레트와
선 두께가 같은가.

---

### 2-5. 장난감 북 — 트랙 B 권장

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A toy circus drum seen from directly above, reinterpreted as a flat round bumper.
A wide drumhead in muted aged cream takes most of the area and is clearly the
impact surface. Around it sits a thick burgundy drum frame ring carrying a brass
gold band and small gold five-pointed stars spaced around it. Depth is implied
only by a soft shade arc just inside the frame and by the frame thickness — the
cylindrical side of the drum is never drawn. A few uneven tension lines run from
the centre out to the frame across the drumhead. Painted flat on the drumhead is
a simple rocking horse in reddish brown: one clean readable silhouette with a
raised head, four straight legs, a short tail, a muted ivory mane, and a bowed
rocker attached directly beneath the hooves. No detail inside the horse. Aged,
slightly warped, hand-painted.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Interior lines are thinner and less
steady than the outline. Slightly crooked, never perfectly symmetrical. Muted
low-saturation palette that sits on a dark navy-slate wooden board and stays
darker than a bright teal glass ball.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
visible side wall, no cast shadow. Single object, centred, fully inside the
frame with clear empty margin on all four sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or drop shadows. Do not add eyes, teeth, faces, tentacles, skulls,
magic circles, arrows, gauges, text, logos, drumsticks, side handles, ropes, or
watermarks. No photographic texture, no grunge overlay, no dirt map, no noise, no
painterly blending, no 3D rendering, no specular highlight. No neon, no
fluorescent colour, no rainbow, no pure white area, no saturated primary red.
```

**검수** — 북막이 주요 충돌면으로 읽히는가 / 원통 옆면이 그려지지 않았는가 /
말이 인게임 크기에서 덩어리로 뭉개지지 않는가 / 북채·손잡이가 원형 범위를 벗어나지 않았는가.

---

### 2-6. 구슬 미끄럼틀 — 트랙 A 권장 (`marble_slide_plate.png`)

> ⚠️ 이 범퍼는 **코드에 아트 슬롯이 없다** (`bumper_production_guide.md` 0-2절).
> 개발 슬롯이 생기기 전에는 뽑아도 붙일 곳이 없다.
> **표시 지름도 미정이다.** 통로가 공(64px)을 담으려면 240px 급이어야 한다 (가이드 1절).

```text
Reference 1 is a flat colour layout diagram, not finished art. Keep its
silhouette, proportions, and the position of every part exactly, then redraw it
as polished hand-inked cartoon art. Reference 2 defines line quality and mood
only; do not copy any object, symbol, or scenery from it.

A toy marble-run slide seen from directly above, reduced to only the channel the
ball travels through. A round dish plate forms the body: a muted purple outer rim
and a darker taupe floor with two faint uneven concentric rings that are
deliberately not perfect circles. A wide U-shaped trough runs from an open entry
mouth at the upper left, curves down around the bottom of the dish, and rises to
an exit at the upper right. The trough has bold ink edges on both sides, a dark
plum interior wall, and a distinctly lighter aged-ivory floor so the path reads
at a glance. The trough floor is wide enough to hold a ball. Two small gold
connector studs sit along the trough, and two short muted teal structural clips
grip the dish rim on the left. The exit direction is conveyed only by the final
curve and the lip silhouette. A thin shadow under the lower edge implies the
slide floats slightly above the board.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Slightly crooked, never perfectly
symmetrical. Muted low-saturation palette on a dark navy-slate wooden board.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
support legs, no tall side structure, no cast shadow other than the thin one
described. Single object, centred, fully inside the frame with clear empty margin
on all four sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or extra shadows. Do not add arrows or any directional marking. Do not
add eyes, teeth, faces, tentacles, skulls, magic circles, gauges, text, logos, or
watermarks. Do not draw a ball or marble inside the trough. No photographic
texture, no grunge overlay, no noise, no painterly blending, no 3D rendering, no
specular highlight. No neon, no fluorescent colour, no rainbow, no pure white
area, no saturated primary red.
```

**검수** — 진입점에서 출구까지 경로가 한눈에 읽히는가 / **화살표처럼 보이는 장식이 없는가** /
몸체가 공을 덮지 않는가 / 통로 바닥이 공을 담을 폭인가.

---

### 2-7. 태엽 장난감 대포 — **트랙 A 필수** (`clockwork_cannon_plate.png`)

> ★ 형태판을 반드시 쓴다. 포신이 **+X(오른쪽)** 기준이어야 하고
> 포구가 받침대 원 안에서 끝나야 런타임 회전·충돌 판정이 맞는다.
> **기울여 뽑으면 안 된다.**

```text
Reference 1 is a flat colour layout diagram, not finished art. Keep its
silhouette, proportions, the barrel direction, and the position of every part
exactly, then redraw it as polished hand-inked cartoon art. Reference 2 defines
line quality and mood only; do not copy any object, symbol, or scenery from it.

A wind-up toy cannon seen from directly above. A round reddish-brown rotating
base plate forms the entire collision silhouette, carrying two faint brass
concentric rings whose centre is exactly the rotation centre. A short thick
dark-teal barrel projects from the centre toward the right and ends in a muted
ivory muzzle collar with a very dark bore, so front and back are instantly
distinguishable. The muzzle stops inside the base circle and never breaks the
round outline. At the centre sits a dark slate ball-capture well ringed in deep
teal, left clear so a ball resting there would not be hidden. Two brass spoked
toy wheels sit on the left as identity decoration rather than working wheels.
Behind the barrel on the left is a large brass wind-up key with two gold wings
and a bold uneven spiral. Two dusty purple stitches on the base plate. Slightly
crooked and toy-like.

Flat 2D dark-cartoon game art for a top-down pinball board. Bold hand-inked
outlines with visible thickness variation, drawn by hand, slightly wobbling,
never a clean vector curve. Solid flat cel fills, at most two flat value steps
per material, no gradients inside a shape. Interior lines are thinner and less
steady than the outline. Never perfectly symmetrical. Muted low-saturation
palette on a dark navy-slate wooden board.

Strict top-down orthographic view. Perfectly flat, no perspective, no tilt, no
visible side wall, no cast shadow. The barrel points exactly to the right. Single
object, centred, fully inside the frame with clear empty margin on all four
sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, smoke, muzzle flash,
motion lines, or drop shadows. Do not add eyes, teeth, faces, tentacles, skulls,
magic circles, arrows, gauges, text, logos, or watermarks. Do not draw a ball or
cannonball. No photographic texture, no grunge overlay, no noise, no painterly
blending, no 3D rendering, no specular highlight. No neon, no fluorescent colour,
no rainbow, no pure white area, no saturated primary red.
```

**검수** — 포신 방향과 공 포획 중심이 즉시 구분되는가 / **포구가 받침대 원 밖으로
나가지 않았는가** / 동심원 중심이 회전축과 일치하는가 / 포신이 오른쪽을 향하는가.

---

## 3. Phoenix 전용 Negative Prompt

Phoenix 는 네이티브 지원이므로 위 블록의 마지막 금지 문단을 지우고 여기에 넣어도 된다.
**단 다른 모델에서는 금지 조건을 Positive 안에 남겨 둔다** — UI 에 칸이 있어도
네이티브 지원을 단정할 수 없다.

```text
photorealistic, 3d render, painterly, airbrush, gradient shading, bloom, glow,
lens flare, drop shadow, perspective, tilted view, side view, isometric, extra
objects, text, watermark, signature, neon, fluorescent, rainbow, saturated red,
pure white background
```

용수철 인형에는 위 목록을 그대로 쓰되 **얼굴 관련 단어를 넣지 않는다.**

---

## 4. 프롬프트 길이 확인

Phoenix 1.0 / Lucid Origin 은 **2,000자 상한**이다. 실측 결과 7개 중 6개가 넘는다.

| 블록 | 길이 | 2,000자 |
|---|---:|---|
| 2-1 단추 | 2,112 | 초과 |
| 2-2 솜 | 2,264 | 초과 |
| 2-3 용수철 인형 기본 | 2,020 | 초과 |
| 2-4 용수철 인형 타격 | 1,443 | 이내 |
| 2-5 장난감 북 | 2,188 | 초과 |
| 2-6 구슬 미끄럼틀 | 2,381 | 초과 |
| 2-7 태엽 대포 | 2,354 | 초과 |

**Nano Banana 2 를 1순위로 둔 이유가 이것도 있다.** 상한이 확인되지 않은 모델이라
자를 필요 없이 그대로 넣을 수 있다. Phoenix / Lucid 로 옮길 때만 아래 순서로 줄인다.

재확인: `python3 docs/bumper_guides/check_prompt_lengths.py`

넘칠 때 자르는 순서 — **아래에서 위로** 지운다. 위쪽일수록 결과를 좌우한다.

1. 금지 문단의 뒤쪽 절반 (`No neon, ...` 이하)
2. 화풍 문단의 마지막 문장 (`Muted low-saturation palette ...`)
3. 본문의 세계관 연결색 문장 (보라 실밥 등)

**첫 문단(Reference 역할)과 배치 문단은 절대 자르지 않는다.**

---

## 5. 결과물 처리

1. 여백판 기준으로 생성했으면 **실루엣 마스크로 잘라낸다.**
2. **알파 bbox == 캔버스** 를 맞춘다. `bumper_master.py` 의 `finalize()` 를 그대로 쓸 수 있다.
   이걸 빠뜨리면 표시 크기가 충돌 크기와 어긋난다 (공에서 두 번 밟은 지뢰).
3. 저장 위치: `Resources/Art/bumpers/<이름>.png` — 폴더는 통과본이 나오면 만든다.
4. **글로우·충격파·점멸을 텍스처에 굽지 않는다.** VFX 레이어가 따로 처리한다.
5. `make_review_sheet.py` 의 `STEP1` 경로만 바꿔 돌리면 **인게임 크기 검수 시트**가 그대로 나온다.
   공보다 밝지 않은지 여기서 확인한다.

## 6. 생성 전 체크

- [ ] 트랙 A/B 를 범퍼별로 정했는가 (0절 표)
- [ ] 대포는 형태판을 넣었는가
- [ ] Prompt Enhance 가 Off 인가
- [ ] Reference Strength 가 HIGH 가 아니라 MID 인가 (형태판을 쓸 때)
- [ ] 용수철 인형 프롬프트에서 얼굴 금지어를 뺐는가
- [ ] 타격 상태는 기본 상태 확정본을 Reference 로 넣는가
- [ ] 현재 Leonardo UI 와 공식 문서를 다시 확인했는가 (문서 검증일 2026-08-03)
