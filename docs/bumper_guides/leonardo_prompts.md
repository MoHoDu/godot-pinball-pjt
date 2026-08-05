# 범퍼 Leonardo 프롬프트

> 2026-08-05 / 짝 문서: `bumper_production_guide.md`
> 모델 사양 근거: `docs/LEONARDO_AI_MODEL_HANDOFF.md` (최종 검증 2026-08-03)
> **생성 직전에 현재 Leonardo UI 를 다시 확인할 것.** 모델과 옵션은 바뀐다.

---

## 0. 먼저 — 무엇을 코드로 두고 무엇을 뽑을지

**2026-08-06 결정: 단추만 코드 확정본을 쓰고, 나머지 5종은 전부 Leonardo 로 뽑는다.**

| 범퍼 | 처리 |
|---|---|
| 단추 | **생성하지 않는다.** `bumper_master_v2.py` 확정본(`step1_v2/button.png`) |
| 솜 · 용수철 인형(2장) · 북 · 미끄럼틀 · 대포 | **트랙 B — 텍스트만으로 생성** |

형태판(`step2_plates/*_plate.png`)은 코드로 그린 배치 도면이지 완성 아트가 아니다.
2026-08-06 검수에서 단추 외 6장이 전부 반려됐으므로 **레퍼런스로 넣지 않는다.**
넣으면 반려된 형태를 모델이 다시 재현한다.

| | 트랙 B — 텍스트만 (채택) | 트랙 A — 형태판 사용 (보류) |
|---|---|---|
| 얻는 것 | 그림 품질이 높다 | 배치·비율·충돌 원 일치가 정확 |
| 잃는 것 | **실루엣이 매번 달라진다** | 그림이 반려된 도면에 끌려간다 |
| Reference 1 | `Flipper_cartoon.png` **MID** | 여백판 MID |

### ★ 트랙 B 를 쓰면 반드시 따라오는 후처리

실루엣을 모델이 정하므로 **표시 크기가 충돌 크기와 어긋날 수 있다.**
프로젝트 원칙 "실루엣은 AI 에 안 맡긴다"를 이번만 트랙 B 로 완화하는 대가다.
생성물마다 5절을 빠짐없이 돌린다. 특히 **알파 bbox == 캔버스**를 빠뜨리면
표시 지름이 충돌 지름과 어긋난다 (공에서 두 번 밟은 지뢰).

**대포는 여기에 하나 더 걸린다.** 포신이 **+X(오른쪽)** 기준이어야 하고 포구가
받침대 원 **안에서** 끝나야 런타임 회전·충돌 판정이 맞는다. 텍스트로 지시하되
결과물에서 반드시 눈으로 확인하고, 어긋나면 회전·마스킹으로 잡는다.
그래도 안 잡히면 대포만 형태판(트랙 A, MID)으로 되돌린다.

---

## 1. 모델 세팅

### 1순위 — Nano Banana 2

| 설정 | 값 |
|---|---|
| Image Reference | 플리퍼 아트 1장, Strength **MID** (형태판은 넣지 않는다) |
| Prompt Enhance | **Off** — On/Auto 는 프롬프트를 늘려 장식을 붙인다 |
| Fixed Seed | 같은 구도의 변형 비교에만 |
| 수량 | 탐색 4, 확정 1~2 |
| 해상도 | 탐색 1376×768 → 확정 2752×1536 |

### 2순위 — Phoenix 1.0

네이티브 `negative_prompt` 를 지원하는 축이다. 금지 조건이 계속 새면 이쪽으로 옮긴다.
Style Reference = 플리퍼 아트. **프롬프트 상한 2,000자** (4절 참고).

### 쓰지 말 것

- **GPT Image 2** — Reference Strength 지정 불가. 형태 보존 강도를 못 잡는다.
- **Krea 2 Turbo** — Reference 자체가 없다.

---

## 2. 복붙용 완성 프롬프트

아래 블록은 **그대로 붙여 넣으면 되는 완성본**이다. 조립하거나 갈아 끼울 게 없다.
5개 블록 전부 **트랙 B(텍스트만)** 로 통일돼 있고, 첫 문단은 이미 트랙 B 문단이다.

Reference 슬롯에는 **플리퍼 확정 아트 한 장만** MID 로 넣는다.

```
Resources/Art/flippers/Flipper_cartoon.png
```

대포만 계속 실패하면 그때 첫 문단을 아래 트랙 A 문단으로 바꾸고
`step2_plates/clockwork_cannon_plate.png` 를 Reference 1 (MID) 로 추가한다.

```text
Reference 1 is a flat colour layout diagram, not finished art. Keep its
silhouette, proportions, and the position of every part exactly, then redraw it
as polished hand-inked cartoon art. Reference 2 defines line quality and mood
only; do not copy any object, symbol, or scenery from it.
```

---

### 2-1. 단추 — 생성하지 않는다

2026-08-06 검수 통과. **코드 확정본을 그대로 쓴다.**

```
docs/bumper_guides/step1_v2/button.png
```

재생성: `python docs/bumper_guides/bumper_master_v2.py`

v1 형태·명도 단차를 그대로 두고 가이드 11쪽 레퍼런스의 **눌려 찍힌 별 문양**만
얹은 것이다. 여기에 Leonardo 를 다시 돌리지 않는다.

다른 5종의 **팔레트·잉크 두께 기준**이 이 파일이다. 결과물이 이것과 따로 놀면
그쪽을 고친다.

---

### 2-2. 솜 — 트랙 B

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A wad of soft stuffing cotton torn out of a plush toy, seen from directly above,
reading as a flat cushioning pad on the board rather than a tall fluffy ball.
The silhouette is a ring of many small rounded bumps all the way around the
perimeter, unmistakably bunched cotton — not a smooth blob, not a weather-cloud
icon, not a flower. One continuous bold ink line holds the whole outline; the
bumps are never outlined individually. Main colour is a toned-down greyish cream,
never near-white, clearly darker than a bright ivory ball, with a slightly warmer
core. Interior detail is only three or four broad sweeping curves nested around
one centre, showing which way the cotton is rolled and compressed; no fine hairs,
no fuzz, no stray fibres, no crossing scratches. One bump group on the lower left
is shaded dusty grey-violet. A small torn square of muted teal cloth is stitched
onto the lower right edge with short pale brown stitches. A crooked pale brown
seam crosses the upper area with uneven cross-stitches and ends in a single
purple thread knot. The centre of the wad is left clear and unobstructed.

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

### 2-3. 용수철 인형 · 기본 — 트랙 B

> ⚠️ 이 범퍼만 **금지 문단에서 `eyes, teeth, faces` 를 뺐다.** 얼굴이 있어야 하는 범퍼다.
> 다른 범퍼 프롬프트를 복사해 쓰면 얼굴이 지워진다.

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A spring-mounted doll seen from directly above in its resting state. The doll's
head is a ball, so from above it reads as one round face in muted aged ivory that
fills almost the entire bumper and is clearly the impact surface. Two small
rounded stub arms poke out at the left and right edges, and a muted mustard cap
brim with a short stalk sits across the top of the head. The spring is hidden
underneath; only short gold and dark brass coil segments peek out at four points
around the rim. A thin blue-grey base ring frames the face. Two simple round eyes
with bold ink rims, a small crooked mouth, two flat muted teal cheek dots, and a
dusty purple stitch line across the forehead. The expression is calm and blank —
cute, but not quite right.

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

### 2-5. 장난감 북 — 트랙 B

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A toy circus drum seen from directly above, reinterpreted as a flat round bumper.
A wide drumhead in muted aged cream takes most of the area and is clearly the
impact surface. Around it sits a thick burgundy drum frame ring. Alternating
cream and burgundy triangles run all the way around that ring like a pennant
band, edged by a brass gold rim. Small gold five-pointed stars sit at uneven
intervals on the ring, and short muted teal tension cords zigzag between them in
shallow V shapes, read as lacing seen from above — never long dangling rope, and
never crossing onto the drumhead. Depth is implied only by a soft shade arc just
inside the frame and by the frame thickness — the cylindrical side of the drum is
never drawn. A few uneven tension lines run from the centre out to the frame
across the drumhead. Painted flat on the drumhead is
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
magic circles, arrows, gauges, text, logos, drumsticks, side handles, or
watermarks. No photographic texture, no grunge overlay, no dirt map, no noise, no
painterly blending, no 3D rendering, no specular highlight. No neon, no
fluorescent colour, no rainbow, no pure white area, no saturated primary red.
```

**검수** — 북막이 주요 충돌면으로 읽히는가 / 원통 옆면이 그려지지 않았는가 /
말이 인게임 크기에서 덩어리로 뭉개지지 않는가 / 북채·손잡이가 원형 범위를 벗어나지 않았는가.

---

### 2-6. 구슬 미끄럼틀 — 트랙 B

> ⚠️ 이 범퍼는 **코드에 아트 슬롯이 없다** (`bumper_production_guide.md` 0-2절).
> 개발 슬롯이 생기기 전에는 뽑아도 붙일 곳이 없다.
> **표시 지름도 미정이다.** 통로가 공(64px)을 담으려면 240px 급이어야 한다 (가이드 1절).

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A toy marble-run slide seen from directly above, reduced to only the channel the
ball travels through. A round dish plate forms the body: a muted purple outer rim
and a darker taupe floor with two faint uneven concentric rings that are
deliberately not perfect circles. A wide channel enters at an open mouth on the
upper left, sweeps across the plate in one long continuous S curve, and leaves at
an open lip on the lower right, so entry, path, and exit read as a single
unbroken route at a glance. The trough has bold ink edges on both sides, a dark
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

### 2-7. 태엽 장난감 대포 — 트랙 B (제약이 가장 많다)

> ★ **이 범퍼만 런타임 제약이 걸려 있다.** 포신이 **+X(오른쪽)** 기준이어야 하고
> 포구가 받침대 원 **안에서** 끝나야 회전·충돌 판정이 맞는다.
> 형태판을 빼면 이 둘이 자주 어긋난다. **생성물마다 눈으로 확인하고**,
> 어긋나면 회전·마스킹으로 잡는다. 계속 실패하면 이 범퍼만 형태판
> (`clockwork_cannon_plate.png`, MID)으로 되돌린다.

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, symbol, text, or scenery from it.

A wind-up circus toy cannon seen from directly above. A round reddish-brown
rotating base plate forms the entire collision silhouette, carrying two faint
brass concentric rings whose centre is exactly the rotation centre. A short thick
dark-teal barrel projects from the centre toward the right and ends in a muted
ivory muzzle collar with a very dark bore, so front and back are instantly
distinguishable. Small flat gold five-pointed stars are painted along the barrel
as circus decoration. The muzzle stops inside the base circle and never breaks
the round outline. At the centre sits a dark slate ball-capture well ringed in
deep teal, left clear so a ball resting there would not be hidden. Two toy wheels
sit on the left as identity decoration rather than working wheels, each drawn as
a brass rim with a few thick uneven spokes. Behind the barrel on the left is a
large brass wind-up key with two gold wings and a bold uneven spiral. Two dusty
purple stitches on the base plate. Slightly crooked and toy-like.

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

Phoenix 1.0 / Lucid Origin 은 **2,000자 상한**이다. 실측 결과 6개 중 5개가 넘는다.
(2026-08-06 레퍼런스 반영으로 블록이 길어져 재측정한 값이다.)

| 블록 | 길이 | 2,000자 |
|---|---:|---|
| 2-2 솜 | 2,475 | 초과 |
| 2-3 용수철 인형 기본 | 2,156 | 초과 |
| 2-4 용수철 인형 타격 | 1,443 | 이내 |
| 2-5 장난감 북 | 2,465 | 초과 |
| 2-6 구슬 미끄럼틀 | 2,319 | 초과 |
| 2-7 태엽 대포 | 2,328 | 초과 |

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

1. 배경을 지우고 **범퍼 하나만 남긴다.** 트랙 B 는 실루엣을 모델이 정하므로 이 단계가 필수다.
2. **알파 bbox == 캔버스** 를 맞춘다. `bumper_master.py` 의 `finalize()` 를 그대로 쓸 수 있다.
   이걸 빠뜨리면 표시 크기가 충돌 크기와 어긋난다 (공에서 두 번 밟은 지뢰).
3. 저장 위치: `Resources/Art/bumpers/<이름>.png` — 폴더는 통과본이 나오면 만든다.
4. **글로우·충격파·점멸을 텍스처에 굽지 않는다.** VFX 레이어가 따로 처리한다.
5. `make_review_sheet_v2.py` 를 돌리면 **인게임 크기 검수 시트**가 나온다(한글 폰트 반영본).
   공보다 밝지 않은지, 92~128px 에서 뭉개지지 않는지 여기서 확인한다.

## 6. 생성 전 체크

- [ ] **단추는 생성 대상이 아니다** — 코드 확정본을 쓴다 (2-1)
- [ ] Reference 에 플리퍼 아트만 MID 로 넣었는가 (형태판은 넣지 않는다)
- [ ] Prompt Enhance 가 Off 인가
- [ ] 용수철 인형 프롬프트에서 얼굴 금지어를 뺐는가
- [ ] 타격 상태는 기본 상태 확정본을 Reference 로 넣는가
- [ ] 생성 후 **알파 bbox == 캔버스** 를 맞췄는가 (5절, 트랙 B 필수 후처리)
- [ ] 대포 포신이 오른쪽을 향하고 포구가 받침대 원 안에서 끝나는가
- [ ] 현재 Leonardo UI 와 공식 문서를 다시 확인했는가 (문서 검증일 2026-08-03)
