# ② 텍스처 단계 — ElevenLabs 재질음 프롬프트 (정속 태엽눈 파일럿)

작성 2026-08-03 · 대상 `SFX_Ball_Clockwork_*`

---

## 0. 이 단계에서 AI가 맡는 것 / 맡지 않는 것

| | 담당 | 이유 |
|---|---|---|
| 어택 트랜지언트 · 총 길이 · 레이어 밸런스 | **절차적 (확정됨)** | 요구 길이 0.06~0.14초인데 ElevenLabs `duration_seconds` **최소가 0.5초**다. 어택이 어디 찍힐지 제어할 수 없다 |
| 공통 어택 파형 | **절차적 (확정됨)** | PDF 6-2가 5종이 같은 어택을 쓰라고 요구한다. AI로 5번 뽑으면 5개가 다 달라진다 |
| **재질 캐릭터 (태엽 클릭의 질감)** | **ElevenLabs** | 절차적 모달 합성은 "황동 4개 모드"까지는 되지만, 실제 태엽 걸림쇠의 불규칙한 마찰음은 못 만든다 |

받은 파일에서 **0.5초 중 재질 구간만 잘라내** 이미 확정된 엔벨로프에 얹습니다.
Leonardo에서 홍채 질감만 가져와 확정 껍질에 얹은 것과 같은 구조입니다.

---

## 1. 공통 설정

| 항목 | 값 | 근거 |
|---|---|---|
| `duration_seconds` | **0.5** (최소값) | 짧을수록 모델이 원샷으로 뽑는다. 길면 반복 시퀀스를 만든다 |
| `prompt_influence` | **0.8** | 재질 지정을 지켜야 한다. 낮추면 일반적인 "클릭"으로 수렴 |
| `loop` | **끔** | 원샷이다 |
| `output_format` | **가장 높은 PCM / 48kHz** | 우리 파이프라인이 48kHz다. MP3면 어택에 프리에코가 낀다 |
| 변형 | 요청당 4개가 자동으로 나옴 | **4개 다 받아주세요.** 고르는 건 제가 합니다 |

---

## 2. 정속 태엽눈 프롬프트 3종

각각 4변형 = **12개**. 전부 받으면 됩니다.

### A. 주력 — 태엽 걸림쇠 클릭

```
A single dry click of a small brass clockwork escapement, one tooth
slipping past the pallet. Tiny wind-up toy mechanism, close-miked in a
dead room. Bright metallic tick with a very short brass ring. No
reverb, no room tone, no music, no repetition — one isolated click
then silence.
```

### B. 보조 — 유리구슬 위의 금속 톡

```
One short tick of a small brass pin tapping a hollow glass marble.
Toy-sized, delicate, close-miked, completely dry. Clear glassy ping
with a fast decay. Single isolated hit, no reverb, no echo, no
background noise, silence after.
```

### C. 대안 — 태엽 감기 멈춤

```
The single detent click of a wind-up music box spring catching. Small,
light, wooden-and-brass, recorded very close with no room. One crisp
snap only, no ratcheting sequence, no reverb, no hum, silence before
and after.
```

---

## 3. 쓰면 안 되는 단어

프롬프트 화풍 이탈 규칙의 사운드 판입니다. 아래 단어는 모델을 **산업 호러** 쪽으로 끌어당깁니다 — 폐기된 구 컨셉입니다.

> `metal clang` / `machinery` / `industrial` / `heavy` / `steel` / `hammer` /
> `factory` / `gear grinding` / `echo` / `hall` / `cinematic` / `impact boom`

PDF 6-1이 직접 금지합니다 — *"사실적인 쇠구슬이나 무거운 산업 기계음보다 장난감, 태엽, 스프링, 유리, 작은 금속 클릭음을 사용한다."*

---

## 4. 채택 기준 (제가 볼 것)

받은 12개 중 아래를 만족하는 걸 씁니다. **형락님이 미리 거르실 필요 없습니다.**

1. 앞쪽 30ms 안에 재질 특성이 다 들어있는가 (뒤로 갈수록 잔향뿐이면 버림)
2. 잔향·룸톤이 안 붙었는가 (붙으면 우리 "짧은 잔향" 레이어와 충돌)
3. 3~9kHz에 황동 모드가 뚜렷한가
4. 클릭이 **하나**인가 (모델이 종종 2~3연타를 넣는다)

---

## 5. 넘기는 방법

`docs/ball_guides/sfx/raw/` 폴더를 만들고 **받은 파일명 그대로** 넣어주시면 됩니다.
(파일명은 손대지 마세요 — 어느 프롬프트에서 나왔는지 추적해야 합니다.)

---

## 6. 나머지 4종 — 방향만 (파일럿 승인 후 정식 작성)

| 공 | 재질음 (PDF 6-2) | 프롬프트 핵심어 방향 |
|---|---|---|
| 고무막 유리눈 | 고무 뽕 | rubber band snap / balloon skin thump / toy bouncy ball |
| 완충 젤 유리눈 | 젤 폭 | soft gel blob / water balloon tap / muted damp thud |
| 납심 유리눈 | 낮은 클랙 | dense dark glass clack / heavy marble on wood, no metal ring |
| 속빈 방울눈 | 속빈 유리 팅 | hollow glass bauble / tiny bell inside / thin crystal ring |
