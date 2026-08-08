# 보스 Leonardo 프롬프트 — 눈 잃은 테디베어

> 짝 문서: `boss_production_sheet.md` · 형태 마스터: `boss_master.py` → `step1/`
> 프롬프트 구조는 `docs/bumper_guides/leonardo_prompts.md` 와 같은 5문단 형식이다.
> **생성 직전에 현재 Leonardo UI 를 다시 확인할 것.** 모델과 옵션은 바뀐다.

---

## 0. ★ 범퍼와 다른 점 두 가지

### ① 시점이 다르다

범퍼·수리 부품은 전부 **top-down**(보드를 위에서 내려다봄)이다.
보스는 기획서 4-1 이 "전신이 보드 중앙에 **서 있는** 구조" 로 정의했고,
유지해야 할 특징(둥근 귀 / 넓고 납작한 머리 / 아래로 처진 양팔)이 전부
정면에서만 보이는 것이다. 원본 테디베어 레퍼런스도 정면 전신이다.

**따라서 시점 문단을 `top-down` → `front-facing flat elevation` 으로 바꾼다.**
다른 프롬프트를 복사해 오면 여기서 틀린다.

### ② 포즈가 7장이라 일관성이 문제다

AI 는 같은 캐릭터를 여러 장에 걸쳐 똑같이 못 그린다. 그래서 순서가 중요하다.

1. **기본 대기 1장만 먼저 확정한다.** 이게 원본이 된다
2. 확정본을 **Reference 1 (HIGH)** 로 넣고 나머지 포즈를 뽑는다
3. 그래도 어긋나면 그 포즈는 확정본을 **직접 편집**해서 만든다
   (팔은 어차피 코드가 회전시키므로 포즈 원화가 꼭 필요한 것은 아니다)

**형태 마스터(`step1/*.png`)를 Reference 로 넣지 않는다.** 범퍼 2026-08-06 검수에서
형태판을 레퍼런스로 넣었더니 모델이 도면을 그대로 재현해 6장이 반려됐다.
마스터는 **사람이 보고 판단하는 기준**이지 모델 입력이 아니다.

---

## 1. 모델 세팅

| 설정 | 값 |
|---|---|
| 모델 | Nano Banana 2 (1순위) / Phoenix 1.0 (negative 필요 시) |
| Reference 1 | `Resources/Art/flippers/Flipper_cartoon.png` **MID** — 선질·팔레트만 |
| Prompt Enhance | **Off** |
| 수량 | 탐색 4, 확정 1~2 |
| 해상도 | 세로 구도. 탐색 768×1376 → 확정 1536×2752 |

비율이 중요하다. 보스는 **520×620(세로가 김)** 이므로 가로 구도로 뽑으면
팔을 늘일 자리가 없어 짧아진다.

---

## 2. 기본 대기 — 제일 먼저 뽑는 1장

```text
Reference 1 defines line quality, palette temperature, and dark-cartoon mood
only. Do not copy any object, eye, star, symbol, text, or scenery from it.

A huge, sagging teddy bear made of dark cursed cloth, standing upright and facing
straight forward, seen in full body. It is not a monster or a demon bear — it is
a curse that only half-remembers what a teddy bear looked like and rebuilt it
wrong. The head is broad and flattened, wider than a real bear's, tilted slightly
to one side, with two rounded ears of clearly different size and height. Both eyes
are completely empty dark sockets — hollow holes where eyes used to be, ringed
with short crooked stitches, with only a very faint dull violet haze deep inside.
The mouth is not a mouth: it is a short place where the face seam has come
slightly apart, closed with uneven stitching. The torso is a heavy rounded mass,
noticeably lopsided, one shoulder higher than the other. Both arms are
extraordinarily long and heavy and hang all the way down past the body like
weighted cloth sacks, ending in big rounded lumps of stuffing instead of hands —
these long arms are the single most recognisable feature of the figure. Thick
crooked seams run down the centre of the face and body and across the belly,
holding the body together by force rather than repairing it, with dark stuffing
pushing out between them. A few patches of the original faded greyish-brown
fabric survive on the belly and arms, stitched on with pale thread. In the centre
of the chest sits a small lumpy heart-shaped core in deep crimson, squashed and
asymmetrical, never a pretty valentine heart, held in place by several taut
threads sewn into the body. The core is quiet and dim, a status light, not a
glowing weak point.

Flat 2D dark-cartoon game art. Bold hand-inked outlines with visible thickness
variation, drawn by hand, slightly wobbling, never a clean vector curve. Solid
flat cel fills, at most two flat value steps per material, no gradients inside a
shape. Interior lines are thinner and less steady than the outline. Slightly
crooked, never perfectly symmetrical. An old, worn, faintly unsettling toy.
Muted low-saturation palette of ink-blue black, dark navy, desaturated violet and
dull grey-brown cloth, sitting on a dark navy-slate board and staying darker than
a bright teal glass ball.

Front-facing flat elevation view, straight on at eye level. Perfectly flat, no
perspective, no tilt, no three-quarter turn, no foreshortening, no cast shadow,
no ground plane. Tall vertical composition. Single figure, centred, fully inside
the frame with clear empty margin on all four sides. Plain transparent
background.

Do not add glow, bloom, light rays, sparkles, particles, motion lines, impact
effects, or drop shadows. Do not give it visible eyeballs, irises, pupils, button
eyes, glowing eyes, or red eyes — the sockets stay empty and dark. Do not add
teeth, fangs, a wide open monster mouth, claws, horns, tentacles, skulls, magic
circles, arrows, gauges, text, logos, or watermarks. Do not make the chest heart
brighter or more eye-catching than the long arms. No photographic texture, no
grunge overlay, no dirt map, no noise, no painterly blending, no 3D rendering, no
specular highlight. No neon, no fluorescent colour, no rainbow, no pure white
area, no saturated primary red.
```

**검수 항목** (가이드 20절 즉시 반려 기준에서 뽑았다)

- 일반적인 악마·좀비 곰처럼 보이지 않는가
- 원본 테디베어와 연결되는 실루엣이 있는가
- **긴 양팔보다 하트핵이 먼저 보이지 않는가**
- 눈에 단추눈·동공·발광이 들어가지 않았는가
- 하트핵이 약점처럼 보이지 않는가
- 세로 비율이 520:620 에 가까운가 (가로로 퍼지면 팔이 짧아진다)

---

## 3. 나머지 포즈 — 확정본을 레퍼런스로

2절 확정본을 **Reference 1 (HIGH)** 로 넣고, 2문단만 아래로 갈아 끼운다.
1·3·4·5 문단은 그대로 둔다.

> Reference 1 is the finished design of this exact character. Keep its
> silhouette, proportions, colours, seams, patches and face exactly the same.
> Change only the pose described below.

### 3-1. 팔 공격 예고

```text
The same bear, still standing and facing forward, compressing downward just
before an attack. Both long arms press down against the ground and shorten
slightly, as if loading. The whole body squashes down a little. Nothing else
changes.
```

### 3-2. 양팔 들어올리기 (공격)

```text
The same bear, both long arms swung up and out to either side at once, raised
high above the shoulders in a wide open V, completely changing the silhouette
from the hanging-arm rest pose. The body stretches slightly upward. The face and
torso are unchanged and stay fully visible; the arms do not cross in front of
the face.
```

### 3-3. 공격 후 경직

```text
The same bear with both long arms dropped limply straight down, hanging slack
and lifeless, body slumped slightly. Nothing else changes.
```

### 3-4. 일반 피격

```text
The same bear squashed briefly by an impact, body compressed and tilted a little
to one side, arms swinging outward from the jolt. Nothing else changes.
```

### 3-5. 강한 피격 (정확한 반격)

```text
The same bear twisted hard by a strong impact, body clearly compressed and
leaning to one side much more than a normal hit, arms flung outward. Thin lime
green cracks show briefly inside the chest heart core. Nothing else changes.
```

### 3-6. 페이즈 전환 포효

```text
The same bear with its head tilted up, roaring. The stitched mouth seam has torn
open abnormally downward into a dark gap — a split in sewn cloth, not a monster
jaw with teeth. Dark smoke leaks from between the body seams. The chest heart
core is brighter than usual. Arms still hang down. Nothing else changes.
```

---

## 4. 하트형 저주핵 — 단독

코드가 박동시키므로 몸과 분리해 뽑는다.

```text
Reference 1 defines line quality and palette only. Do not copy any object from it.

A small lumpy heart-shaped core made of dark cursed cloth and thread, squashed
and asymmetrical, one side larger than the other, never a smooth symmetrical
valentine heart. Deep crimson with a darker inner mass. Its surface is uneven and
bumpy. Several taut dark threads are sewn through it from the outside, pinning it
in place by force. Thin lime green cracks glow faintly in the inner seams.

Flat 2D dark-cartoon game art. Bold hand-inked outlines with visible thickness
variation, drawn by hand, slightly wobbling, never a clean vector curve. Solid
flat cel fills, at most two flat value steps per material, no gradients.

Front-facing flat elevation view. Perfectly flat, no perspective, no cast shadow.
Single object, centred, fully inside the frame with clear empty margin on all four
sides. Plain transparent background.

Do not add glow, bloom, light rays, sparkles, particles, or drop shadows. Do not
add a crosshair, target mark, weak-point icon, arrow, gauge, text or watermark.
Do not make it look like an attack target. No photographic texture, no noise, no
3D rendering, no specular highlight. No neon, no pure white area.
```

---

## 5. 후처리

`docs/bumper_guides/cutout_and_finalize.py --root docs/boss_guides` 를 쓴다.

**단 보스는 알파 bbox 정규화를 하면 안 된다.** 범퍼는 `visual_diameter` 하나로
크기가 정해져 bbox == 캔버스가 필수지만, 보스는 포즈끼리 정렬이 유지돼야 한다.
각 포즈를 따로 잘라 맞추면 프레임 교체 때 그림이 튄다.

보스는 **한 포즈의 bbox 를 기준으로 전부 같은 오프셋으로** 자른다.
