# 범퍼 STEP2 — Leonardo 텍스처 프롬프트

> 2026-08-05 / 짝 문서: `bumper_production_guide.md`
> 모델 사양 근거: `docs/LEONARDO_AI_MODEL_HANDOFF.md` (최종 검증 2026-08-03)

---

## 0. 이 단계에서 맡기는 것과 맡기지 않는 것

프로젝트 규칙: **실루엣은 AI 에 맡기지 않는다.**
형태는 `bumper_master.py` 가 좌표로 확정했다. Leonardo 에 맡기는 것은 다음뿐이다.

| 맡긴다 | 맡기지 않는다 |
|---|---|
| 손그림 잉크선의 우연한 맛 | 실루엣·비율·구멍 위치 |
| 목재·천·황동·고무의 재질감 | 팔레트 (확정본에서 추출한 HEX) |
| 평탄 셀 안의 미세한 명도 단차 | 충돌 범위와 외곽의 일치 |
| 낡고 뒤틀린 장난감의 마모 | 구성 요소 추가·삭제 |

**입력은 `step2_plates/*_plate.png` 여백판이다.** 사방 13% 여백을 둔 이유:
생성물이 프레임에 닿으면 마스킹으로 rim 을 제거할 수 없다.
여백 안에서 끝나면 모델이 무엇을 붙이든 원형 마스크로 깨끗이 잘린다.
(보드 작업에서 프레임에 닿아 실패한 이력이 있다.)

---

## 1. 모델 선택

핸드오프 문서 21절 기준. **범퍼는 "확정된 형태에 질감만"** 이므로 Content/Style 역할이
분리되는 모델이 유리하다.

### 1순위 — Nano Banana 2

| 설정 | 값 |
|---|---|
| Image Reference 1 | `step2_plates/<범퍼>_plate.png` — **HIGH** |
| Image Reference 2 | `Resources/Art/flippers/Flipper_cartoon.png` — **LOW/MID** |
| Prompt Enhance | **Off** |
| Fixed Seed | 동일 구도 변형 비교에만 사용 |
| 수량 | 탐색 4, 확정 1~2 |
| 해상도 | 1376×768 (탐색) → 2752×1536 (확정) |

Reference 2 를 넣는 이유: 화풍이 목적이면 **화풍 레퍼런스가 Reference 로 들어가야 한다.**
플리퍼 확정본이 이 프로젝트의 화풍 기준이다.
단 **Strength 를 MID 이상으로 올리면 플리퍼의 눈·별·빨강 액센트가 딸려온다.** LOW 부터 시작한다.

### 2순위 — Phoenix 1.0

네이티브 `negative_prompt` 를 지원하는 유일한 축이다. 금지 조건이 계속 새면 이쪽으로 옮긴다.

| 설정 | 값 |
|---|---|
| Content Reference | 여백판 — **HIGH** |
| Style Reference | `Flipper_cartoon.png` — **LOW/MID** |
| Prompt Enhance | Off |
| Mode | 탐색 Fast → 확정 Quality/Ultra |
| Negative Prompt | 4절 사용 |

### 쓰지 말 것

- **GPT Image 2**: Reference Strength 지정 불가. 형태 보존 강도를 못 잡는다.
- **Krea 2 Turbo**: Reference 자체가 없다. 형태를 못 넘긴다.

---

## 2. 공통 프롬프트 블록

모든 범퍼 프롬프트 앞뒤에 붙인다. 개별 프롬프트는 3절의 한 문단만 갈아 끼운다.

### 2-1. 머리말 (Reference 역할 명시)

```text
Reference 1 defines the exact geometry: silhouette, proportions, part placement,
and the position of every hole, ring, and seam. Reproduce it exactly.
Reference 2 defines line quality and dark-cartoon mood only.

Do not copy any object, eye, star, character, symbol, text, or scenery from
Reference 2. Take only the ink-line feel and the flat cel shading approach.
```

### 2-2. 화풍 (레퍼런스를 묘사하지 말고 화풍 언어로)

```text
Flat 2D dark-cartoon game art. Hand-inked outlines with visible thickness
variation, drawn as if by hand, slightly wobbling, never a perfect vector curve.
Solid flat cel fills with at most two flat value steps per material — no
gradients inside a shape. Individually countable hand-drawn strokes for wood
grain, cloth folds, and coil grooves. Slightly crooked, never perfectly
symmetrical. An old, warped, worn toy.
```

### 2-3. 배치 (탑뷰 고정)

```text
Strict top-down orthographic view, perfectly flat, no perspective, no tilt,
no visible side walls, no cast shadow on the ground. The object is centered
and fully contained inside the frame with clear empty margin on all four sides.
Transparent background.
```

### 2-4. 금지 문단 — Positive Prompt 안에 자연어로 쓴다

최신 모델은 UI 에 Negative Prompt 칸이 있어도 네이티브 지원을 단정할 수 없다.
**핵심 금지는 반드시 Positive 에도 넣는다.**

```text
Keep the silhouette and every part position exactly as Reference 1. Do not add,
remove, move, or resize any part. Do not add glow, bloom, light rays, sparkles,
particles, motion lines, impact effects, or drop shadows. Do not add eyes,
teeth, faces, tentacles, skulls, magic circles, arrows, gauges, text, logos,
or watermarks. No photographic texture, no grunge overlay, no dirt map, no
noise, no painterly blending, no 3D rendering, no specular highlights.
No neon, no fluorescent colors, no rainbow, no pure white areas, no saturated
primary red.
```

### 2-5. Phoenix 전용 Negative Prompt

```text
photorealistic, 3d render, painterly, airbrush, gradient shading, bloom, glow,
lens flare, drop shadow, perspective, tilted view, side view, isometric,
extra objects, text, watermark, signature, neon, fluorescent, rainbow,
saturated red, pure white background
```

---

## 3. 범퍼별 프롬프트 본문

각 항목의 코드 블록을 2-1 → 2-2 → **본문** → 2-3 → 2-4 순서로 이어 붙인다.

---

### 3-1. 단추 (`button_plate.png`)

```text
A thick round wooden toy button seen from directly above, with four holes
arranged in a square. The disc is slightly irregular, not a perfect circle.
Main color is a low-saturation burgundy rose; the raised outer ring is darker
than the sunken inner face, and that value difference is the only thing that
conveys thickness. Faint aged-brown wood grain runs only across the inner face
in a few long, uneven horizontal strokes. The four holes are dark slate wells
with a crisp ink rim. Two dusty purple threads cross between the holes, and one
thread is frayed and trails past the edge of the inner face. A short muted
ivory highlight sits on the outer ring at the upper left.
```

**검수 포인트** — 구멍 4개가 탑뷰에서 명확히 구분되는가 / 옆면이 노출되지 않았는가 /
목재 결이 안쪽 면 밖으로 나가지 않았는가.

---

### 3-2. 솜 (`cotton_plate.png`)

```text
A torn stuffing-cotton wad seen from directly above, read as a soft cushioning
pad lying flat on the board rather than a tall fluffy ball. The outline is an
asymmetric cloud made of overlapping lobes, held by one continuous bold ink
line — no internal lobe outlines. Main color is toned-down cream with a warmer
pale core. Interior detail is only a few broad sweeping curves that show which
way the cotton is rolled and bunched; no fine hairs, no fuzz, no stray fibers.
One lobe on the lower left is shaded a dusty grey-violet. A small square cloth
patch in muted teal is stitched onto the lower right edge, with short pale-brown
stitches. A crooked pale-brown seam runs across the upper area with uneven
cross-stitches, and a single purple thread knot sits at its end. The center of
the wad is kept clear and unobstructed.
```

**검수 포인트** — 중심 타격 위치가 장식에 가리지 않는가 / 잔선이 늘어나
인게임 크기에서 뭉개지지 않는가 / 큰 먼지 구름처럼 보이지 않는가.

---

### 3-3. 용수철 인형 — 기본 (`spring_doll_plate.png`)

```text
A wind-up spring doll seen from directly above in its resting state. A round
ivory doll face fills almost the entire bumper and reads as the impact surface;
the spring itself is hidden underneath and only short brass and gold coil
segments peek out at four points around the rim. A thin blue-grey base ring
frames the face. The doll wears a muted mustard cap brim across the top of the
head. Two simple round eyes with bold ink rims, a small crooked mouth, and two
flat muted teal cheek dots. A dusty purple stitch line crosses the forehead.
The face is calm and blank, cute but not quite right.
```

**검수 포인트** — 얼굴 중심이 실제 충돌 위치와 일치하는가 / 용수철이 상시 노출되지 않았는가.

---

### 3-4. 용수철 인형 — 타격 (`spring_doll_hit_plate.png`)

```text
The same wind-up spring doll seen from directly above at the moment of impact.
The round ivory face is squashed and pushed back, compressed into a short wide
oval near the top, and the short thick coil spring that was hidden underneath is
now fully exposed as four bold gold loops with darker brass on their back edges,
widening toward the bottom. The eyes are squeezed shut into two short ink lines
and the mouth is open in a small dark oval. Same blue-grey base ring, same
mustard cap brim now compressed, same teal cheek dots.
```

**검수 포인트** — 기본 상태와 **형태 차이만으로** Bounce 기능이 읽히는가.
이 두 장은 같은 팔레트·같은 선 두께여야 한다. **한 번에 두 장을 뽑지 말고,
기본 상태를 먼저 확정한 뒤 그 결과물을 Reference 로 넣어 타격 상태를 뽑는다.**
(AI 는 "공통이어야 하는 것"을 따로 뽑으면 전부 다르게 낸다 — 공 5종에서 밟은 지뢰.)

---

### 3-5. 장난감 북 (`toy_drum_plate.png`)

```text
A toy circus drum seen from directly above, reinterpreted as a flat round
bumper. A wide pale cream drumhead takes up most of the area and is clearly the
impact surface. Around it sits a thick burgundy drum frame ring with a brass
gold band and small gold five-pointed stars spaced around it. Depth is implied
only by a soft shade arc just inside the frame and by the frame thickness —
never by drawing the drum's cylindrical side. A few uneven tension lines run
from the center to the frame across the drumhead. Painted flat on the drumhead
is a simple rocking horse in reddish brown, drawn as one clean silhouette with
a bowed rocker beneath it and a muted ivory mane; no fine detail inside the
horse. Slightly warped, aged, hand-painted.
```

**검수 포인트** — 북막이 주요 충돌면으로 읽히는가 / 옆면 원통이 그려지지 않았는가 /
말 실루엣이 인게임 크기에서 덩어리로 뭉개지지 않는가.

---

### 3-6. 구슬 미끄럼틀 (`marble_slide_plate.png`)

> ⚠️ 이 범퍼는 **코드에 아트 슬롯이 없다.** `bumper_production_guide.md` 0-2절 확인.
> 개발 슬롯이 생기기 전에는 생성해도 붙일 곳이 없다.

```text
A toy marble-run slide seen from directly above, reduced to just the channel the
ball travels through. A round dish plate forms the body: a muted purple outer
rim and a lighter aged-ivory floor with two faint uneven concentric rings that
are deliberately not perfect circles. A U-shaped trough runs from an open
entry mouth at the upper left, curves down around the bottom of the dish, and
rises to an exit at the upper right. The trough has bold ink edges on both
sides, a dark plum interior wall, and a lighter floor so the path reads at a
glance. Two small gold connector studs sit along the trough. A short muted teal
structural line follows the inside of the dish rim on the left. The exit
direction is conveyed only by the final curve and the lip silhouette. A thin
shadow under the lower edge implies the slide floats slightly above the board.
```

**검수 포인트** — 진입점에서 출구까지 경로가 한눈에 읽히는가 /
**화살표처럼 보이는 장식이 없는가** / 몸체가 공을 덮지 않는가.

---

### 3-7. 태엽 장난감 대포 (`clockwork_cannon_plate.png`)

```text
A wind-up toy cannon seen from directly above. A round reddish-brown rotating
base plate forms the whole collision silhouette, with two faint brass concentric
rings whose center is exactly the rotation center. A short thick dark-teal
barrel projects from the center toward the right and ends in a muted ivory
muzzle collar with a very dark bore, so front and back are instantly
distinguishable; the muzzle stops inside the base circle and never breaks the
round outline. At the center sits a dark slate ball-capture well ringed in deep
teal, left clear so a ball resting there would not be hidden. Two brass
spoked toy wheels sit on the left as identity decoration, not as working
wheels. Behind the barrel on the left is a large brass wind-up key with two
gold wings and a bold uneven spiral. Two dusty purple stitches on the base
plate. Slightly crooked and toy-like.
```

**검수 포인트** — 포신 방향과 공 포획 중심이 즉시 구분되는가 /
**포구가 받침대 원 밖으로 나가지 않았는가** (충돌 실루엣 = 받침대 원) /
받침대 동심원 중심이 회전축과 일치하는가.

> ★ 대포 마스터는 **+X(오른쪽) 기준**이다. 런타임 회전은 Godot 이 준다.
> 생성물을 기울여 뽑으면 안 된다.

---

## 4. STEP2 결과물 처리

1. 여백판 기준으로 생성했으므로 **원형(또는 실루엣) 마스크로 잘라낸다.**
2. `finalize()` 와 같은 규칙으로 **알파 bbox == 캔버스** 를 맞춘다.
   `bumper_master.py` 의 `finalize()` 를 그대로 재사용할 수 있다.
3. 저장 위치: `Resources/Art/bumpers/<이름>.png`
   (아직 폴더가 없다. STEP2 통과본이 나오면 만든다.)
4. **글로우·충격파·점멸을 텍스처에 굽지 않는다.** VFX 레이어가 따로 처리한다.

## 5. 생성 전 최종 확인

핸드오프 문서 24절 절차.

- [ ] 결과물이 범퍼임을 확인했는가 (보드·벽·공·VFX 와 구분)
- [ ] 사용할 모델을 명시했는가
- [ ] **생성 직전에 현재 Leonardo UI 와 공식 문서를 다시 확인했는가**
      (문서 최종 검증일 2026-08-03. 모델과 UI 는 변경될 수 있다)
- [ ] Reference 역할과 장수 제한을 확인했는가
- [ ] Prompt Enhance 가 Off 인가
- [ ] **STEP1 형태 마스터가 검수를 통과했는가** — 통과 전에는 돌리지 않는다
