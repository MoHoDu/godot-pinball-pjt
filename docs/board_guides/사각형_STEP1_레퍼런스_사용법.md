# 사각형(팔각형) 보드 — STEP 1 "형태" 레퍼런스 사용법

작성일 2026-08-02 · 대상 Leonardo.Ai Pro
근거 문서: `docs/LEONARDO_AI_MODEL_HANDOFF.md`, `docs/board_guides/사각형보드_형태가이드.png`

---

## 0. 3단계 진행 계획

| 단계 | 목표 | 고정할 것 | 이번에 새로 얻을 것 |
|---|---|---|---|
| **STEP 1 (지금)** | 보드 **형태**만 | 팔각형 실루엣 | 정확한 외곽, 완전히 빈 표면 |
| STEP 2 | **텍스처** | STEP 1 통과본 | 재질·팔레트·붓결 |
| STEP 3 | **디테일** | STEP 2 통과본 | 저주 문양·존 구분·모서리 장식 |

각 단계는 **직전 단계 통과본을 Reference 1(강도 HIGH)로 고정**하고, 프롬프트에서는 새로 추가할 것만 서술한다. 형태를 다시 말로 설명하지 않는다.

> ### ★ 가장 중요한 원칙 (2026-08-02 1차 생성 결과로 확인)
> **실루엣은 AI에게 맡기지 않는다. 마지막에 마스크로 잘라서 확정한다.**
>
> Leonardo는 대각 *각도*는 거의 완벽하게 재현하지만(오차 0.05°), 변의 *길이 배분*은 미세하게 어긋난다. 그리고 그 오차는 재생성해도 매번 똑같이 나온다 — 시드 문제가 아니라 체계적 편향이다.
>
> 그러니 생성 결과의 실루엣을 프롬프트로 고치려 들지 말 것. 생성물은 **표면 그림**만 얻는 용도로 쓰고, 최종 외곽은 `사각형_STEP1_A_실루엣.png`(또는 `사각형_mask_playfield.png`)를 알파 마스크로 씌워서 픽셀 단위로 확정한다. 이러면 Godot 충돌 폴리곤과 아트가 100% 일치한다.
>
> 이 원칙 때문에 **STEP 1 검수는 "실루엣이 정확한가"가 아니라 "표면이 깨끗하고 평평한가"가 핵심**이 된다.

---

## 1. 파일 3종 — 무엇을 언제 쓰나

원본 도면(`사각형보드_형태가이드.png`)은 글자·치수선·표·별표·보스 원이 가득해서 **레퍼런스로 그대로 넣으면 안 된다.** Leonardo가 그 텍스트와 치수선을 그림의 일부로 베껴 그린다. 아래 3종은 도면에서 기하만 남기고 전부 제거한 것이다.

### A. `사각형_STEP1_A_실루엣.png` — 기본값
- 순수 흰색 팔각형 / 순수 검정 배경, 2240×1260
- **형태 신호가 가장 강함.** 대부분의 경우 이거 한 장이면 된다.
- 흑백이라 색을 끌고 올 수 있음 → 프롬프트에 `use reference 1 for geometry only, ignore its colors` 를 반드시 넣는다.

### B. `사각형_STEP1_B_벽밴드.png` — 벽 위치까지 같이 잡을 때
- 3톤: 배경 / 외곽 벽 밴드 24px / 플레이필드 내부
- 밴드 두께는 도면의 **충돌 두께 24px** 기준(시각 두께 6px이 아님 — 6px은 이 크기에서 안 보인다)
- 밴드는 폴리곤 변에서 **안쪽으로만** 그렸다 (도면 규칙 준수)
- ⚠️ 부작용: 모델이 이 밴드를 **입체 림/베벨**로 해석해 두께 있는 테두리를 만들 수 있다. 강도를 A보다 한 단계 낮춰 쓰고, 결과에 림이 생기면 A로 되돌린다.

### C. `사각형_STEP1_C_라인아트.png` — 엣지 계열 전용
- 흰 배경 + 16px 검정 아웃라인 (안쪽 스트로크라 외곽 경계는 도면 좌표 그대로)
- Phoenix / FLUX 레거시의 **Edge-to-Image, Sketch, Line Art** 슬롯용
- ⚠️ 통합 Image Reference에 넣으면 **흰 배경을 결과 배경색으로 끌고 온다.** 통합 계열에서는 쓰지 말거나, 프롬프트에 `ignore its white background` 를 명시.

### 정확도 검증
세 파일 모두 렌더 후 픽셀에서 정점을 역추출해 도면과 대조했다. 최대 오차 **약 1~2px** (안티에일리어싱 경계 판정 폭 수준).

| 항목 | 도면 | 렌더 결과 |
|---|---|---|
| 정점 | (770,0)(1470,0)(2240,280)(2240,980)(1470,1260)(770,1260)(0,980)(0,280) | 동일 |
| 평평한 변 | 700px × 4 | 700px |
| 대각 | 819.33px × 4 | 819.33px |
| 대각 각도 | 19.98° | 19.98° |
| 외곽 여백 | 0 (보드 = 화면) | 4변 모두 프레임에 접함 |

---

## 2. 모델 선택 — STEP 1 추천 순위

STEP 1은 **실루엣 고정**이 전부다. 스타일은 아직 중요하지 않다.

### ① Nano Banana 2 (1순위)
| 설정 | 값 |
|---|---|
| Image Reference | `A 실루엣` → **HIGH** |
| Prompt Enhance | **Off** |
| 해상도 (16:9) | 탐색 Medium 2752×1536 / 최종 Large 5504×3072 |
| 수량 | 4 |
| Fixed Seed | 탐색 단계엔 끔. 마음에 드는 컷이 나오면 그 시드로 고정하고 변형 비교 |

Reference Strength가 있어서 형태 고정력을 직접 조절할 수 있다. 실루엣이 안 지켜지면 HIGH 유지한 채 프롬프트의 금지 문장을 늘린다.

### ② GPT Image 2 (2순위)
| 설정 | 값 |
|---|---|
| Image Reference | `A 실루엣` (Strength 항목 **없음**) |
| Prompt Enhance | **Off** |
| Style preset | `Game Concept` 또는 `None` |
| Quality | 구조 검증 Medium → 최종 High |
| 해상도 (16:9) | Medium 2048×1136 / Large 3584×2016 |

Strength 슬라이더가 아예 없으므로 **금지 조건을 Positive Prompt에 전부 문장으로** 써야 한다. Negative Prompt는 신뢰하지 않는다.

### ③ Phoenix 1.0 (형태가 계속 무너질 때)
| 설정 | 값 |
|---|---|
| Content Reference | `A 실루엣` → **HIGH** |
| Negative Prompt | 네이티브 지원 — 아래 4절 사용 |
| Prompt Enhance | **Off** |
| Contrast | Medium |
| Generation Mode | 탐색 Fast → 확정 후 Quality/Ultra |
| 해상도 (16:9) | Large 1472×832 |

역할 분리가 되고 네거티브가 진짜로 먹는 대신 **출력 해상도가 1472×832로 작다.** 형태 잡는 용도로만 쓰고, 최종 해상도는 Nano Banana 2나 GPT Image 2로 다시 뽑는다.

> 참고: Krea 2 Turbo / Ideogram 4.0 / Recraft V4는 Reference 슬롯이 없어 STEP 1에 부적합.

---

## 3. Positive Prompt (STEP 1)

영문 그대로 붙여넣기. 약 1,100자 — Phoenix·Lucid Origin의 2,000자 제한 안에 들어간다.

```text
Top-down orthographic view of one empty pinball playfield board, 16:9,
filling the entire frame.

Use reference image 1 for exact geometry only, ignore its colors. Copy the
silhouette exactly: a wide eight-sided polygon with a flat horizontal top
edge, a flat horizontal bottom edge, straight vertical left and right edges,
and four shallow diagonal corners at about 20 degrees. All four sides of the
board touch the frame edges, so the only background visible is four small
dark triangles in the frame corners. Perfectly symmetric left to right and
top to bottom.

The surface is one flat matte painted panel in a dark desaturated ink-navy
tone. Even lighting across the whole board, no gradient hotspot, no vignette,
no glow, no reflection. Clean hard silhouette edge.

Keep the entire surface completely empty. Do not add flippers, walls, rails,
rims, frames, bevels, raised thickness, bumpers, targets, ramps, holes, eyes,
characters, toys, altars, candles, symbols, logos, arrows, dimension lines,
tables, legends, text or numbers. No central motif, no decorative panel, no
border pattern.

No perspective, no isometric tilt, no camera angle, no drop shadow, no 3D
render. Flat 2D game asset, painted cartoon rendering, low visual noise.
```

### 자주 나는 사고와 대응

| 증상 | 대응 |
|---|---|
| 대각 모서리가 둥글게 말림 | `four shallow diagonal corners` 뒤에 `with sharp straight cut corners, not rounded` 추가 |
| 테두리에 입체 림이 생김 | B 대신 A 사용 + `no rim, no raised border, the edge is a flat cut` 추가 |
| 보드가 프레임 안에 작게 들어감 | `filling the entire frame` 를 첫 문장으로 올리고 `no margin, no letterbox` 추가 |
| 표면에 무늬가 생김 | `completely empty` → `completely empty and untextured` 로 바꾸고 재생성 |
| 글자가 그려짐 | 레퍼런스에 원본 도면을 넣지 않았는지 확인 (3종만 사용) |

---

## 4. Negative Prompt

**Phoenix 1.0 / 0.9 에서만 네이티브로 동작한다.** Nano Banana·GPT Image·Seedream·FLUX·Lucid 계열은 입력란이 보여도 반영이 보장되지 않으므로, 위 3절 Positive Prompt의 금지 문단이 본체다.

```text
flippers, walls, rails, rim, raised border, frame, bevel, thickness, bumpers,
targets, ramps, holes, eyes, characters, toys, altar, candles, symbols, logo,
arrows, dimension lines, blueprint annotations, table, legend, text, numbers,
watermark, UI, perspective, isometric, camera tilt, drop shadow, reflection,
vignette, glow, gradient, ornate border, clutter, noise, grunge
```

---

## 5. STEP 1 검수 체크리스트

하나라도 걸리면 재생성. 통과본만 STEP 2로 넘긴다.

**형태**
- [ ] 보드 전체가 프레임 안에 보이고 크롭되지 않았다
- [ ] 정사영 탑다운이다 (원근·아이소메트릭·틸트 없음)
- [ ] 평평한 상/하단, 수직 좌/우, 네 개의 얕은 대각이 유지된다
- [ ] 좌우·상하 대칭이다
- [ ] 네 변이 모두 화면 끝에 닿는다 (외곽 여백 0)
- [ ] 대각 모서리가 둥글게 말리지 않았다

**빈 표면**
- [ ] 플리퍼·벽·레일·림·프레임·베벨·돌출 두께가 없다
- [ ] 범퍼·타깃·별·눈·보스·캐릭터·장난감·촛불·제단이 없다
- [ ] 중앙 모티프나 장식 패널이 없다
- [ ] 텍스트·숫자·치수선·표·UI가 없다

**게임 적용성**
- [ ] 2240×1260으로 리사이즈해도 경계가 또렷하다
- [ ] 이후 플리퍼·범퍼·VFX를 별도 레이어로 얹을 여백이 남는다

---

## 5-1. 1차 생성 실측 결과 (2026-08-02, Nano Banana 2)

설정: Nano Banana 2 · 2752×1536 · Style preset `Game Concept` · Reference = A 실루엣 · 4장

썸네일에서 경계를 서브픽셀로 뽑아 직선 적합(잔차 0.10~0.15px)한 결과:

| 항목 | 스펙 | 실측 (3장 평균) | 판정 |
|---|---|---|---|
| 대각 각도 | 19.98° | **19.89°** | ✅ 오차 0.09° |
| 상단 평평한 변 끝점 X | 770 | **742** | ⚠️ −28 |
| 좌측 수직변 시작 Y | 280 | **272** | ⚠️ −8 |
| 평평한 변 길이 | 700 | 약 758 | ⚠️ +58 |
| 대각 길이 | 819.3 | 약 790 | ⚠️ −29 |
| 충돌 경계와 최대 어긋남 | 0 | **약 10px** | ⚠️ 공 반지름 22px의 절반 |
| 네 변이 프레임에 접함 | 여백 0 | 4변 모두 접함 | ✅ |
| 표면 균일도 | 평평 | 밝기 47~48, 표준편차 ≤0.5 | ✅ 그라디언트·비네팅·텍스처 전부 없음 |
| 정사영 / 대칭 / 텍스트 없음 | — | 전부 통과 | ✅ |
| 외곽 테두리 | 없어야 함 | **밝은 rim 발생** — 평평한 변 약 4px / 수직변·대각 약 8px (보드 환산) | ❌ |
| 보드 색 | — | `#293040` RGB(41,48,64) | ✅ 요청한 ink-navy 그대로 |
| 배경 색 | — | `#161925` RGB(22,25,37) | ✅ |

> rim 폭은 처음에 썸네일로 20~30px으로 추정했으나, **원본 2752×1536으로 재측정한 값은 4~8px**이다. 썸네일 다운샘플 블러 때문에 과대추정됐던 것. 원본이 있으면 반드시 원본으로 측정할 것.

### 여기서 배운 것

1. **4장이 전부 같은 오차다** (X = 740.5 / 742.3 / 742.7 — 편차 2px). 랜덤이 아니라 체계적 편향이므로 **재생성·시드 변경으로 안 고쳐진다.** 생성 횟수를 낭비하지 말 것.
2. 각도는 완벽한데 길이 배분만 틀린다 → 모델은 "기울기"는 잘 보고 "정점 위치"는 대충 본다.
3. **표면 품질은 기대 이상**이다. 밝기 편차 0.5 이하면 완전한 단색 평면이다. STEP 2에서 이 위에 텍스처를 얹기 좋은 상태.
4. rim은 지금 지워야 한다. 이유: 마스크로 자르면 **대각에서는 rim이 통째로 잘려나가고 평평한 변에는 남아** 비대칭이 된다. STEP 2에서 벽을 그릴 거라면 그때 의도적으로 넣는다.

### 다음 롤에 추가할 문장 (rim 제거)

```text
The board edge is a flat cut with no outline. Do not draw any stroke, contour
line, edge highlight, rim light, border or trim along the board boundary. The
board colour meets the background directly.
```

`Style preset` 도 `Game Concept` → **`None`** 으로 바꾼다. Game Concept이 패널에 테두리를 붙이는 경향이 있다.

---

## 5-2. STEP 1 통과본 확정 (2026-08-02)

원본 2752×1536을 받아 다음을 확인한 뒤 재구성했다.

**표면에 지킬 텍스처가 없었다.** 심층 내부 밝기를 25배 증폭해 확인한 결과 보이는 것은 JPEG 8×8 블록 노이즈뿐이었고, 64px 블록 평균의 진폭은 255 중 **1.08**(0.4%)이었다. 그라디언트도, 붓결도, 의도된 무늬도 없는 완전한 단색 평면이다.

따라서 원본을 픽셀 보정하는 대신, **모델이 만든 두 색만 뽑아내고 형태는 도면 좌표로 새로 그렸다.** 이러면 JPEG 아티팩트·rim·기하 오차가 한 번에 사라진다.

### 산출물

| 파일 | 내용 |
|---|---|
| `사각형_STEP1_통과본.png` | 2240×1260 RGB. STEP 2 Reference 1으로 사용 |
| `사각형_STEP1_통과본_알파.png` | 2240×1260 RGBA. 배경 투명. Godot 합성 / 마스크용 |

- 보드 `#293040` · 배경 `#161925` (둘 다 생성물에서 실측 추출)
- 전 스캔라인 외곽 오차 **최대 1.12px** (안티에일리어싱 판정 폭)
- rim **없음** — 외곽부터 내부까지 밝기 48로 균일
- 내부 표준편차 **0.000**
- 알파본 불투명 84.5% (팔각형 이론 면적 84.72%와 일치)

---

## 5-3. STEP 2 프롬프트 (텍스처)

> ### 카메라 각도 확정 — 없음 (2026-08-02 형락님 결정)
> 45° vs 58° 논의는 종료. **완전한 정사영 평면**으로 간다. 카메라 틸트 없음.
>
> 아트 전반에 걸리는 결정이므로 보드에만 적용되는 게 아니다.
> - 광원 방향이 없다 → 어느 쪽이 밝고 어느 쪽이 어두운 음영을 넣지 않는다
> - 두께·옆면·베벨·드롭섀도가 없다 → 벽·플리퍼·범퍼 전부 위에서 본 납작한 형태
> - 입체감은 **명도 단차와 굵은 외곽선**으로만 만든다. 그라디언트 음영으로 만들지 않는다
> - 유리눈(공)의 하이라이트는 예외 — 그건 재질 표현이지 광원 표현이 아니다

### 확정된 방식 (2026-08-02 형락님 지시)

1. 보드의 원형이 되는 **마스크/레퍼런스 이미지를 하나 만든다**
2. 그 이미지를 레퍼런스로 써서 **보드에 텍스처를 채운다**
3. **외곽 삼각형 4개는 전부 마스크로 오려낸다**

1번은 완료. 3번도 방법이 확정돼 있다. 문제는 2번과 3번 사이에 생기는 구멍 하나다.

### ★ 여백판을 쓰는 이유

생성물의 팔각형은 도면보다 **약 10px 바깥에 그려진다**(5-1절). 그래서 도면 폴리곤으로 오려내면

- **대각 4변** — 모델이 붙인 rim이 마스크 바깥이라 통째로 잘려나간다 ✅
- **평평한 4변** — 보드 변이 화면 끝에 붙어 있어 마스크 경계와 겹친다. **rim이 그대로 남는다** ❌

결과는 대각엔 테두리가 없고 상하좌우엔 있는 **비대칭 보드**. 3번 마스킹만으로는 못 막는다.

그래서 2번에 넣을 레퍼런스를 **보드가 프레임에 닿지 않는 여백판**으로 만든다. 모델이 무슨 짓을 하든 그 흔적이 여백 안에서 끝나고, 오려낼 때 8변 전부 똑같이 잘린다.

| 파일 | `사각형_STEP2_레퍼런스_여백판.png` |
|---|---|
| 크기 | 2240×1260 (16:9 유지) |
| 보드 | 도면 팔각형을 **92%로 축소**해 중앙 배치. 대각 각도 19.98° 그대로 (잔차 0.07px) |
| 여백 | 상하 50px · 좌우 89px — 실측 rim 4~8px의 **6~11배** |
| 색 | 보드 `#293040` · 배경 `#161925` (STEP 1 통과본과 동일) |

축소해도 해상도는 남는다. 2752×1536으로 뽑으면 보드가 2532×1413을 차지해 최종 2240×1260 대비 1.13배, 5504×3072로 뽑으면 2.26배다.

### 3번 마스킹을 할 때 (내가 처리)

1. 생성물의 실제 팔각형 정점을 서브픽셀로 측정한다 (5-1절과 같은 직선 적합)
2. 그 팔각형을 도면 폴리곤에 맞추는 변환을 구해 적용한다 → 기하 오차가 얼마든 흡수된다
3. 안쪽으로 아주 살짝(수 px) 파고들어 오려낸다 → 경계에 걸친 rim 잔재까지 제거
4. 도면 폴리곤 알파 마스크를 씌워 2240×1260으로 출력

### 5-3-1. 형락님 제공 레퍼런스 분석 (2026-08-02, 8장)

형락님이 고른 것 = **파랑+빨강 사각 보드**. 나머지 7장과 비교해 측정한 결과:

| # | 내용 | 평균 채도 | 판정 |
|---|---|---:|---|
| **1** | **어두운 슬레이트 블루 패널 + 빨강 브래킷 + 금속 보스** | 0.39 | ★ 채택 |
| 2 | 다이아몬드 보드, 남색 플레이필드 + 빨강/크림 레일 + 선버스트 | 0.41 | 팔레트 동일 계열 |
| 3 | 진한 빨강 목재 바닥 + 총·잡동사니 + 금색 오컬트 원 | 0.62 | 참고만 |
| 4 | 회녹색 판자 + 흰 문양 + 텍스트 | 0.13 | 참고만 |
| 5·8 | 보라 판자 + 프레임 (동일 파일 중복) | 0.31 | 참고만 |
| 6 | 적자 판자 + 오컬트 원 + 잡동사니 | 0.46 | 참고만 |
| 7 | 적자 판자 + 프레임 | 0.45 | 참고만 |

**1번과 2번의 플레이필드 색이 사실상 같다.** `#33424F` / `#3F4E5B` — 둘 다 어두운 슬레이트 블루. 어느 쪽을 가리켰든 색 방향은 같은 곳으로 수렴한다.

**1번이 좋은 선택인 이유**: 3·6·7번은 보드 전체가 진한 빨강/적자다. 그러면 **빨강 = 피해와 위험** 이라는 기능색 규칙이 죽는다. 1번은 베이스가 슬레이트 블루고 빨강은 테두리 부속에만 작게 쓰인다. 기능색과 충돌하지 않는다.

### 확정 사항 (형락님 선택)

- **보드 색 `#2E3A47`** — 레퍼런스(#33424F, 밝음)와 STEP 1 통과본(#293040, 어두움)의 중간. 레퍼런스 느낌을 살리면서 공·플리퍼가 떠오르는 선
- **빨강 액센트는 STEP 2 표면에 넣지 않는다.** 빨강은 나중에 벽·범퍼 오브젝트로만. 충돌 범위와 아트가 일치하고 기능색도 살아남는다. 레퍼런스에서도 빨강은 전부 테두리 부속물이다

### 레퍼런스에서 가져오면 안 되는 것

| 항목 | 어디에 | 왜 안 되나 |
|---|---|---|
| 중앙 오컬트 원·문양 | 3, 4, 6번 | 중앙은 **보스 전용 ø420**. 비워둬야 함 |
| 바닥에 흩어진 총·도구·잡동사니 | 3, 6, 7번 | "배경 장식이 공·플리퍼보다 눈에 띈다 → FAIL" |
| 텍스트 | 4번 (`MARIARS DUSTE`) | 허용 텍스트는 4개뿐 |
| 입체 나무 프레임·베벨·리벳 | 1, 2, 5, 7, 8번 | **완전 평면 결정 위반.** 게다가 보드가 화면 끝에 닿아 프레임 넣을 자리가 없다 |
| 강한 비네팅·방향성 조명 | 대부분 | 평면 결정 위반 |
| 가로 판자 이음선 | 3~8번 | 1번 플레이필드엔 없다. 팔각형 대각변에 어색하게 잘린다 |
| 코너 금속 보스·빨강 브래킷 | 1번 | STEP 2 표면이 아니라 **별도 벽·범퍼 오브젝트**로 제작 |

### 스타일 레퍼런스 파일

`사각형_STEP2_스타일_표면.png` — 1번 레퍼런스에서 **플레이필드 표면만 잘라낸 것**. 프레임·리벳·브래킷·금속 보스를 전부 제외했다. 원본을 통째로 넣으면 모델이 테두리를 따라 그리므로 이 크롭본을 쓴다.

낡은 칠판 같은 슬레이트 블루 도장면, 세로로 흐르는 마른 붓 마모 자국, 분필 같은 얼룩. 판자 이음선 없음.

### STEP 2 프롬프트 (여백판용)

- Reference 1 = `사각형_STEP2_레퍼런스_여백판.png` → **HIGH** (구조)
- Reference 2 = `사각형_STEP2_스타일_표면.png` → **LOW~MID** (질감·팔레트)

```text
Reference image 1 defines the shape. Reference image 2 defines only the
surface texture and palette.

Repaint only the surface of the panel in reference image 1. Keep its exact
eight-sided outline, its exact size and its exact position — the panel does
not touch the frame edges, and the plain dark margin around it must stay empty
and unchanged. The panel edge is a flat cut with no outline, stroke, rim
light, border or trim.

Paint the panel as an old dark slate-blue painted board, like a worn
chalkboard or weathered painted panel. Desaturated slate-blue base, matte
hand-painted finish, soft chalky mottling, broad worn patches where the paint
has thinned. Two to four long sweeping dry-brush wear streaks cross the panel
— confident, slightly crooked, not fine detail. Muted and dusty. No wooden
plank seams, no boards, no joints, no grid.

Completely flat lighting. No light direction, no lit side and dark side, no
shading gradient, no ambient occlusion, no cast shadow, no depth, no
thickness, no bevel, no camera tilt, no vignette. Ignore the lighting of
reference image 2.

Keep contrast low and values dark — this is a background surface, not a focal
point. No bright spot, no glow. Do not repeat fine scratches, rust, grease or
film grain evenly across the whole surface.

Keep the panel free of objects and marks: no flippers, walls, rails, rivets,
bolts, screws, metal corner plates, brackets, bumpers, targets, ramps, holes,
eyes, characters, toys, occult circles, sigils, runes, symbols, logos, text
or numbers. No central motif, no border pattern.

Flat 2D top-down orthographic game asset. No perspective, no isometric tilt,
no 3D render.
```

---

### 참고: 여백 없이 가는 변형안

레퍼런스 없이 **화면 전체를 채우는 텍스처만** 뽑고 팔각형을 오려내는 방법도 있다. rim이 생길 외곽 자체가 없어 가장 안전하지만, 모델이 팔각 패널이라는 걸 모르고 그리므로 구도를 잡아주지 못한다. 여백판 방식이 실패하면 이쪽으로 바꾼다.

```text
A single flat dark-cartoon painted wooden surface, filling the entire frame
edge to edge, seen straight from directly above.

Deep ink-navy base with a few large soft tonal masses. Hand-painted with
visible brush direction. Two to four exaggerated wood-grain lines sweep across
the whole panel — long, confident, slightly crooked, drawn like ink brush
strokes, not fine detail. Muted desaturated palette: ink navy, deep violet,
dark teal. Slightly uneven and hand-made rather than perfectly flat.

Completely flat lighting. No light direction, no lit side and dark side, no
shading gradient, no ambient occlusion, no cast shadow, no depth, no
thickness, no bevel, no camera tilt.

Keep contrast low and values dark. No bright spot, no glow, no vignette. Do
not repeat realistic rust, grease, dirt, film grain or fine scratches across
the surface.

No objects of any kind: no flippers, walls, rails, rims, borders, bumpers,
targets, ramps, holes, eyes, characters, toys, symbols, logos, text or
numbers. No central motif, no panel, no frame, no border pattern.

Flat 2D top-down orthographic game texture. No perspective, no isometric
tilt, no 3D render.
```

비주얼 가이드를 Reference로 넣는다면 어느 방식이든 아래 문장을 추가한다.

```text
Use the reference image only for palette, brush quality and line character.
Do not copy any object, character, eye, toy, creature, altar, prop, scenery
or text from it.
```

### STEP 2 세팅

- 모델 Nano Banana 2 · **Style preset `None`** · Prompt Enhance `Off`
- 해상도 2752×1536 (탐색) → 마음에 들면 5504×3072로 같은 시드 재생성
- 수량 4, Fixed Seed는 확정 후에만

### STEP 2 검수 기준

실루엣은 보지 않는다 (마스크로 확정하므로). 볼 것은:

- [ ] 값이 충분히 어둡고 대비가 낮은가 — 나중에 올릴 공·플리퍼보다 눈에 띄면 FAIL
- [ ] 마모 자국이 2~4개의 큰 흐름인가 (잔 디테일이 화면 전체에 반복되면 FAIL)
- [ ] **가로 판자 이음선이 안 생겼는가** — 레퍼런스 3~8번에서 딸려올 수 있음
- [ ] **중앙에 원·문양·기호가 안 생겼는가** — 레퍼런스 3·4·6번에서 딸려올 수 있음
- [ ] **리벳·볼트·코너 금속판이 안 생겼는가** — 레퍼런스 1번에서 딸려올 수 있음
- [ ] **광원 방향이 없는가** — 한쪽이 밝고 반대쪽이 어두우면 FAIL
- [ ] **두께·베벨·그림자로 입체감을 만든 곳이 없는가** — 평면 결정 위반
- [ ] 밝은 초점·글로우·비네팅이 생기지 않았는가
- [ ] 2240×1260으로 줄여도 결이 뭉개지지 않는가
- [ ] 우연히 얼굴·기호·글자처럼 읽히는 얼룩이 없는가

---

## 5-4. 화풍을 플리퍼에 맞추기 (2026-08-02 형락님 지시)

보드 원판을 정하고, 그 화풍을 **확정 플리퍼(`Flipper_cartoon.png`)** 에 맞추기로 했다.

### 화풍 격차 실측

| | 플리퍼 (목표) | 생성된 보드 원판 |
|---|---|---|
| 외곽선 | **굵은 검정** (3328px 폭에서 약 12px = 0.36%) | 없음 |
| 색면 | 완전 평탄 셀 | 고주파 텍스처, 중앙부 sd **15.5** |
| 결 표현 | **끝이 뾰족한 밝은 청록 세로 스트로크** — 낱개로 셀 수 있음 | 사실적 균열·얼룩·때 |
| 조명 | 평면 | **심한 비네팅** — 중앙 L 60.8 vs 우끝 L 19.0 (**3.2배**) |
| 어두운 영역 비율 | 42.3% (외곽선+암부) | — |
| 주조색 | `#1A3C55` / 결 스트로크 `#1A516B` | 중앙부 `#3C4354` |

**주조색은 이미 거의 맞다** (`#1A3C55` vs `#3C4354`, 둘 다 어두운 슬레이트 블루). 문제는 색이 아니라 **표현 방식**이다.

### 반드시 고쳐야 할 것

1. **비네팅** — 중앙이 우측 끝보다 3.2배 밝다. 공이 오른쪽으로 갈수록 배경이 급격히 어두워져 아트가 아니라 버그처럼 보인다. 평면 결정 위반이기도 하다
2. **워터마크** — 우하단에 `kuso` 가 찍혀 있다. 형락님이 넣은 게 아니라 **레퍼런스 이미지의 워터마크를 모델이 베껴 그린 것**. 레퍼런스에 워터마크가 있으면 결과에 딸려온다
3. **상단 공백(약 5%)과 하단 벽/보(약 5%)** — 전부 판자로 채워야 마스킹했을 때 균일하다

### ★ 주의 — 플리퍼와 "똑같이" 맞추면 안 된다

플리퍼와 동일한 굵기의 검정 외곽선을 보드 전면에 깔면 배경이 전경만큼 시끄러워진다. 검수 기준에 **"배경 장식이 공·플리퍼보다 눈에 띈다 → FAIL"** 이 있다.

맞출 것 / 물러설 것을 나눈다.

| 맞춘다 (같은 세계관으로 읽히게) | 물러선다 (배경이므로) |
|---|---|
| 평탄 셀 채색 — 사진 텍스처 제거 | 외곽선은 **판자 이음선에만**, 전면에 깔지 않음 |
| 결 = 낱개로 보이는 세로 스트로크 | 스트로크 밀도는 플리퍼보다 **성기게** |
| 팔레트 (슬레이트 블루 + 청록 결) | 채도·대비는 플리퍼보다 낮게 |
| 손그림 선 두께 흔들림 | 액센트색(빨강·주황·크림) 사용 안 함 |

### 화풍 레퍼런스 파일

`플리퍼_화풍_목재결.png` — 플리퍼 패널 내부의 **파란 목재 + 세로 결 스트로크**만 크롭. 눈·이빨·볼트·별·크림 턱을 전부 제외했다. 플리퍼 원본을 통째로 넣으면 그 부속물이 보드에 딸려 나온다.

### 수정 화면 vs 생성창 — **생성창을 권장**

| | 잘하는 것 | 이 작업에는 |
|---|---|---|
| **수정 화면** (`Add or remove things`) | 국소 추가·제거. 나머지 픽셀 보존 | 워터마크 지우기·판자 채우기엔 적합. **화풍 전환은 전역 변경이라 어중간하게 섞인다** |
| **생성창** (Reference 2장) | 전역 재해석 | ✅ 화풍·비네팅·상하단 판자를 한 번에 해결. 워터마크도 자동 소멸 |

어차피 화풍을 바꾸면 전부 다시 그려진다. 국소 수정을 먼저 하면 그 작업이 버려진다. **생성창에서 한 번에 가고, 결과에 잔재가 남으면 그때만 수정 화면**으로 지운다.

### ★ 실패 기록 — 사진풍으로 흘러간 원인 (2026-08-02)

첫 STEP 2 프롬프트에 **`worn chalkboard`, `chalky mottling`, `broad worn patches`, `weathered painted panel`** 을 썼다. 형락님이 준 레퍼런스가 사진풍이라 그 표면을 문자 그대로 묘사한 것인데, 이 단어들이 전부 **사실적 질감** 쪽으로 끌어당겼다. 프로젝트 방향은 처음부터 **다크 카툰**인데 거기서 벗어났다.

교훈: **사진풍 레퍼런스를 말로 옮기지 말고, 프로젝트의 화풍 언어로 번역해서 쓴다.** 레퍼런스에서 가져올 것은 팔레트와 낡은 정도지 렌더링 방식이 아니다.

또 하나: **보드 원판(사진풍)을 Reference로 넣으면 계속 사진풍으로 끌려간다.** 원판의 가치는 "가로 판자가 화면을 채운다"는 구도뿐인데, 그건 말로 한 줄이면 된다. 화풍이 목적이면 **화풍 레퍼런스가 Reference 1이어야 한다.**

### 생성창 프롬프트 (카툰 우선)

- Reference 1 = `플리퍼_화풍_목재결.png` → **HIGH** ← 화풍이 주역
- Reference 2 = `카툰_판자_목표.png` → **MID** (판자 배치·밀도·잉크선 굵기)
- **보드 원판은 넣지 않는다.** 넣으면 사진풍으로 되돌아간다
- Nano Banana 2 · Style preset `None` · Prompt Enhance `Off` · 5504×3072

```text
A flat cartoon illustration of horizontal wooden planks, seen straight from
directly above, filling the entire frame edge to edge and top to bottom.
Reference image 1 is the drawing style — match it closely. Reference image 2
is the plank layout and line weight.

Hand-inked cartoon game art. Every plank is filled with one solid flat colour,
vector-like, at most two tones per plank. Bold near-black ink lines separate
the planks, drawn by hand with visible thickness variation and slightly
crooked edges. Wood grain is a small number of separate thin tapered strokes
in a lighter teal tone — individually countable hand-drawn marks, five or six
per plank, never a texture. A few large simple worn patches as flat shapes
with hard edges.

Absolutely no realism. No photographic wood texture, no grunge overlay, no
dirt map, no noise, no film grain, no fine cracks, no stains, no rust, no
scratches, no rendering, no painterly blending, no soft airbrush, no
photobashing.

Planks fill everything. No plain strip at the top. No beam, wall, baseboard,
frame or border at the bottom or sides.

Palette: desaturated slate-blue planks, lighter teal grain strokes, near-black
ink lines. Dark and low contrast. No red, orange or cream.

Completely flat and even lighting. No vignette, no darkened edges, no corner
falloff, no light direction, no lit side and dark side, no shading gradient,
no shadow, no depth, no thickness, no bevel, no camera tilt. Every part of
the image is exactly the same brightness.

Take only line weight, flat colour fills and grain stroke style from the
references. Do not copy any object from them: no eyes, teeth, bolts, screws,
holes, stars, rivets, rounded panels or character parts.

Nothing on the surface: no text, letters, numbers, watermark, signature, logo,
symbols, occult circles, sigils, tools, props or debris.

Flat 2D top-down orthographic game background. No perspective, no isometric
tilt, no 3D render.
```

### 카툰 판자 목표 이미지

`카툰_판자_목표.png` — 플리퍼 팔레트로 직접 그린 **목표 상태**. 2240×1260, 판자 8장.

- 판자 `#1E4058` (판자당 단색, 밝기만 ±3 흔듦)
- 결 스트로크 `#2A6580` — 끝이 뾰족한 가로 스트로크, 판자당 5~7줄, 낱개로 셈
- 잉크선 `#0D161D` — 두께 8~13px, 구간마다 흔들림
- 마모 패치 — 단색 다각형, 하드 엣지, 그라디언트 없음
- **비네팅 0** — 좌 53.7 / 중앙 53.8 / 우 53.6 (실측)

레퍼런스로 그대로 써도 되고, 방향만 확인하고 버려도 된다. AI 결과가 이것보다 못하면 이걸 베이스로 삼고 GPT·Canva에서 손보는 것도 방법이다.

### 수정 화면을 쓸 경우 (잔재 정리용)

한 번에 하나씩, 영어로 짧게 지시한다.

```text
Remove the watermark and all small logos from the bottom corners.
```
```text
Replace the plain dark strip at the very top with the same horizontal wooden
planks that fill the rest of the image.
```
```text
Replace the dark beam at the bottom with the same horizontal wooden planks.
```
```text
Remove the vignette. Make the brightness completely even from edge to edge,
with no darkening at the corners or sides.
```

### 검수 (5-3절 체크리스트에 추가)

- [ ] 비네팅이 완전히 사라졌는가 — 좌·중·우 밝기를 재서 차이 10% 이내
- [ ] 워터마크·서명·로고가 없는가
- [ ] 상단 공백·하단 벽이 판자로 채워졌는가
- [ ] 결 스트로크가 플리퍼보다 성긴가 — 같거나 더 빽빽하면 배경이 전경을 이긴다
- [ ] 빨강·주황·크림 액센트가 안 들어갔는가 (기능색 보호)

---

## 6. 다음 단계 미리보기

**STEP 2 — 텍스처**
- Reference 1 = STEP 1 통과본 → **HIGH** (구조 고정)
- Reference 2 = 비주얼 가이드 1장 → **LOW~MID** (팔레트·붓결만)
- 프롬프트: 표면 재질만 서술. 형태 설명 반복 금지. `Do not copy objects, characters, eyes, toys, text or scenery from reference 2` 명시
- 방향: 다크 카툰, 거친 잉크 붓선, 먹색 남색 / 짙은 보라 / 어두운 청록. 사실적 녹·기름때·미세 스크래치를 화면 전체에 반복하지 않는다

**STEP 3 — 디테일**
- Reference 1 = STEP 2 통과본 → **HIGH**
- 배치 규칙은 이미 만들어둔 `사각형_zone_decor.png` 를 따른다
  - 🟩 초록 영역 = 장식·범퍼·유물 배치 가능
  - 🟥 빨강 영역 = 공 경로, **장식 금지**
  - 🟪 보라 ø420 = 보스 전용, 비워둔다
- 화면 비중 유지: 60% 어두운 배경·보드 / 25% 주조색 / 10% 조작 피드백 / 5% 특수 연출

---

## 7. 남아 있는 확정 필요 항목

- ~~**카메라 각도** 45° vs 58°~~ → **2026-08-02 확정: 각도 없음, 완전 평면 정사영.** 5-3절 참조
- **삼각형(육각형) 보드**는 아직 미착수. 같은 3종 세트를 동일 규격으로 뽑을 수 있음
- **배경 코너 4개** — 팔각형 바깥 4개 삼각형(화면의 15%)을 무엇으로 채울지 미정. STEP 3에서 결정
