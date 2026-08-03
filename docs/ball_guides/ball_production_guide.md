# 공 리소스 제작 가이드 — 캣츠아이 수정구

> Pinball_Logue / 2026-08-02 / 대상: 이 프로젝트를 이어서 작업할 사람 또는 AI

---

## 0. 컨셉 해석 — 여기서 한 번 틀렸으니 먼저 읽을 것

기획서의 **"유리눈"은 유리로 만든 눈알이 아니다.** 눈처럼 생긴 **수정구·보석**이다.
흰자(sclera)가 있는 안구를 그리면 그로테스크해지고 프로젝트 톤에서 벗어난다.

- ❌ v1 폐기: 아이보리 흰자 + 청록 홍채 + 검은 동공 = 해부학적 안구
- ✅ v3-B 확정: **캣츠아이 캐보션 보석**. 청록 크리스탈 몸체 안에 아몬드형 짙은 내포물과
  장축을 흐르는 빛줄기. 눈처럼 보이지만 명백히 광물이다.

프롬프트에도 이 구분을 **명시적으로 써야 한다.** "eyeball"이라고 쓰면 모델이 흰자를 그린다.

---

## 1. 확정 규격 (코드에서 실측)

| 항목 | 값 | 근거 |
|---|---|---|
| 표시 지름 | **64px** | `pinball.gd` `DEFAULT_BALL_DIAMETER = 64.0` |
| 텍스처 | **1024×1024 RGBA** | 64px의 16배 |
| 공 원의 위치 | **캔버스에 정확히 내접** (알파 bbox = 1024×1024) | ★ 아래 |
| 배경 | 완전 투명 | |
| 글로우·트레일 | **텍스처에 굽지 않는다** | VFX_01이 Line2D로 처리 |
| base_ball 충돌 반지름 | 28.8px (`collision_radius_ratio = 0.9`) | `base_ball.tscn` |
| 변종 충돌 반지름 | 32.0px | 각 변종 `.tscn` |

### ★ 원이 캔버스에 내접해야 하는 이유

`refresh_ball_size()`가 **텍스처의 긴 변**으로 표시 크기를 나눈다.

```gdscript
var source_diameter := maxf(absf(texture_size.x), absf(texture_size.y))
var visual_scale := ball_diameter / source_diameter
```

**캔버스 여백 = 표시 크기 손실**이다.

구본 `ball.png`는 1104×1104에 공이 931px(84%)만 채워 실제 **53px**로 그려지고 있었다.
충돌은 57.6~64px이므로 최대 **11px 어긋남** → 검수 즉시 FAIL. 원인은 구워 넣은 글로우.

---

## 2. 확정 팔레트

플리퍼 확정본 `Flipper_cartoon.png`에서 추출. 임의로 바꾸지 않는다.

| 용도 | HEX |
|---|---|
| 잉크선 · 동공 | `#0B0B0C` |
| 아이보리 (유리 테두리 · 빛줄기) | `#F0E0C3` |
| 하이라이트 | `#FFFBFC` |
| 청록 밝음 (유리 두께) | `#7FC9B4` |
| 청록 기본 | `#4FA692` |
| 청록 짙음 | `#2F7A69` |
| 코어 | `#164240` 계열 (`#16423C`) |

**금지**: 빨강·주황·보라·갈색.
특히 **주황 선버스트 스파이크는 절대 넣지 않는다** — 그게 플리퍼 축 눈알과 공을 구분하는 핵심이다.

---

## 3. 마스터 기하 (1024 기준 / 괄호는 64px 환산)

원점 = 캔버스 중심 (512, 512). **+X가 진행방향.**

**껍질 (회전 대칭 — 광원 방향을 만들지 않는다)**

| 요소 | 반지름 |
|---|---|
| 잉크 외곽선 | 482 → 512 (두께 1.9px) |
| 아이보리 유리 테두리 | 436 → 482 (2.9px) |
| 청록 밝음 | 396 → 436 (2.5px) |
| 청록 기본 | 0 → 396 |
| 청록 짙음 디스크 | 300 (18.8px) |

**코어 (방향성 요소, 중심에서 +X로 40px = 2.5px 이동)**

| 요소 | 반장축 × 반단축 |
|---|---|
| 아몬드 잉크선 | 296 × 176 (18.5 × 11.0px) |
| 아몬드 코어 | 274 × 158 (17.1 × 9.9px) |
| 동공 (원) | 중심 +52 추가 전진, 반지름 104 (6.5px) |
| 빛줄기 청록밝음 | 중심 −62, 176 × 26 |
| 빛줄기 아이보리 | 중심 −66, 138 × 13 |

**하이라이트 (공 중심 기준)**

| | 각도 | 거리 | 반지름 |
|---|---|---|---|
| 주 | −56° | 300 | 58 (3.6px) |
| 보조 | 126° | 330 | 22 (1.4px) |

재현 스크립트: `ball_master.py` (변종 A/C도 같은 파일에 남겨둠)

---

## 4. STEP 2 — Leonardo 질감 입히기

### 목적
형태는 확정됐다. 맡기는 것은 **손그림 잉크선의 우연한 맛과 크리스탈 질감**뿐이다.
**실루엣은 절대 맡기지 않는다** — 보드 작업에서 확인된 체계적 편향은 재생성으로 안 고쳐진다.

### 레퍼런스
`ball_step2_reference_plate.png` (1024×1024, 공이 74%, 사방 여백 133px)

여백을 두는 이유: 보드에서 생성물이 프레임에 닿아 마스킹으로 rim을 못 없앤 실패가 있었다.
여백 안에서 끝나면 모델이 뭘 붙이든 원형 마스크로 깨끗이 잘린다.

### 권장 세팅

**1순위 — Nano Banana 2**

| 설정 | 값 |
|---|---|
| Image Reference | 여백판 1장, Strength **HIGH** |
| Style preset | **None** (`Game Concept`는 둘레에 밝은 rim을 붙인다) |
| Prompt Enhance | **Off** |
| 비율 | **1:1**, 생성창이 제시하는 값 중 가장 큰 것 |
| 수량 | 4 |

**2순위 — Phoenix 1.0** (네거티브 프롬프트가 필요할 때)
Content Reference `HIGH` + Style Reference `플리퍼_화풍_목재결.png` `MID`, Contrast Medium.

### Positive Prompt (영문 전문)

```text
A single cursed cat's-eye gemstone, drawn as flat 2D dark-cartoon game art, centered
on a plain dark navy background with generous empty margin on all four sides.

This is a polished mineral cabochon, NOT an organic eyeball. There is no white sclera,
no eyelid, no lashes, no veins, no flesh. It only resembles an eye because of the
almond-shaped dark inclusion trapped inside the crystal.

The reference image is the exact design to follow. Keep the same circular silhouette
and the same layout: a pale ivory glass rim around the edge, a teal crystal body in two
flat value steps, a dark almond-shaped inclusion in the middle whose long axis points to
the right, a thin bright chatoyant line running along that axis, and one strong white
highlight. Do not move, resize or restyle these shapes.

Rendering style: hand-inked cartoon. One bold black ink outline around the whole stone
and around the almond inclusion, with slight natural thickness variation like a brush
pen. Flat cel fills with at most two value steps per color. No gradients, no soft
shading, no ambient occlusion, no drop shadow. Add only a few individually countable
hand-drawn marks: two or three short curved ink strokes in the teal suggesting polished
crystal facets. Keep them sparse and clearly separate.

Palette exactly: ivory #F0E0C3, light teal #7FC9B4, teal #4FA692, deep teal #2F7A69,
ink #0B0B0C, highlight #FFFBFC. Do not introduce red, orange, purple or brown.

Flat orthographic top-down. No light source, no directional lighting, no rim light,
no bevel, no thickness, no environment reflection.

Keep the background completely empty and flat. Do not add flippers, machines, hands,
tentacles, text, numbers, watermarks, logos, frames, borders, sparkles, glow or
particles. Exactly one stone and nothing else.
```

### Negative Prompt (Phoenix 계열 네이티브. 그 외에는 보조)

```text
eyeball, sclera, eyelid, eyelashes, iris, veins, blood, flesh, organic, gore,
photograph, photorealistic, 3d render, glossy specular, ray tracing, gradient shading,
soft shadow, drop shadow, bevel, emboss, glow, bloom, sparkles, particles, text,
watermark, logo, signature, frame, border, multiple stones, orange, red, purple,
orange spikes, sunburst
```

### STEP 2 검수 체크리스트

- [ ] **안구가 아니라 광물로 보인다** (흰자·눈꺼풀·핏줄이 없다)
- [ ] 공이 프레임에 닿지 않고 사방 여백이 남아 있다
- [ ] 외곽 잉크선이 끊기지 않은 한 줄이다
- [ ] 아몬드 코어의 장축이 여전히 **오른쪽**을 향한다 (진행방향 표시)
- [ ] 강한 하이라이트가 1개다 (보조 점 1개까지 허용)
- [ ] 그라디언트·드롭섀도·비네팅이 없다
- [ ] 빨강·주황·보라가 없다 / 주황 스파이크가 없다
- [ ] 워터마크·텍스트가 없다
- [ ] **64px로 줄여도 아이보리 테 / 청록 몸체 / 짙은 아몬드 3단이 구분된다** ← 최종 관문

---

## 5. STEP 3 — 마스킹 및 출력 ✅ 완료 (2026-08-02)

1. 생성물에서 공의 중심과 반지름을 서브픽셀로 측정
2. 마스터 원(중심 512, 반지름 512)에 맞도록 스케일·이동
3. 반지름을 **2~3px 안쪽으로** 파고들어 오려낸다 (가장자리 잔재 제거)
4. 알파 마스크를 씌워 **1024×1024 RGBA** 출력, 알파 bbox가 정확히 1024×1024인지 재검증

재현 스크립트: `ball_step3_mask.py`

### 실측 결과 — 보드와 달리 형태 보정이 필요 없었다

| 항목 | 값 |
|---|---|
| 생성물 | 4096×4096 **JPG** (Leonardo 다운로드는 PNG가 아니라 JPG로 나온다) |
| 적합 원 중심 | (2047.69, 2047.83) — 캔버스 중심에서 **0.35px** |
| 적합 반지름 | 1516.67 (여백판 이론값 1515.5 대비 **+1.2px**) |
| 원 적합 잔차 | 평균 **0.29px**, 최대 1.25px (1440개 방사 샘플 중 1435개 채택) |
| 인셋 | 최종 3px = 원본 8.9px |
| 알파 bbox | **1024 × 1024** = 캔버스 전체 ✅ |

**보드에서 겪은 체계적 실루엣 편향이 공에서는 나타나지 않았다.** 대상이 원 하나이고
여백판이 형태를 못 박아준 덕이다. 형태 보정 없이 마스킹만으로 끝났다.

### 팔레트 재현도 (JPEG 통과 후)

| 목표 | 실측 | 면적 |
|---|---|---|
| 아이보리 `#F0E0C3` | `#F0DEC4` | 16.8% |
| 청록밝음 `#7FC9B4` | `#81C5B3` | 13.7% |
| 청록 `#4FA692` | `#54A292` | 23.9% |
| 짙은청록 `#2F7A69` | `#36796C` | 15.3% |
| 잉크 `#0B0B0C` | `#0E0B12` | 17.2% |

목표 팔레트 반경 26 안에 **86.9%**. 표면 평탄도는 청록 링 표준편차 **2.6 이하** —
4배 다운샘플이 JPEG 아티팩트를 지웠다. (보드 원판이 sd 15.5로 FAIL이었던 것과 대비된다.)

### 마스터 대비 차이

| | 마스터 | 최종 |
|---|---|---|
| 외곽 잉크선 @1024 | 28.2px | **25.7px** (편차 0.5) |
| 64px 표시 환산 | 1.76px | **1.61px** |

잉크선이 조금 얇아졌지만 64px에서 실루엣은 유지된다. 가장자리 8배 확대 검사에서
rim 잔재·배경 프린지 없음.

### 생성물이 더해준 것

손그림 아크 스트로크 5~6개(낱개로 셀 수 있음), 잉크선 두께의 미세한 흔들림.
마스터의 기계적인 완벽함이 사라지고 손그림 맛이 생겼다 — STEP 2를 돌린 이유가 이것이다.

---

## 6. 진행방향 응시 구현 ✅ 완료 (2026-08-02)

공은 `RigidBody2D`라 충돌 마찰로 자유롭게 회전한다. 그대로 두면 아몬드가 아무 방향이나 향한다.
**Visual 노드만 속도 벡터 방향으로 회전**시킨다.

### 왜 이 방식인가
- 물리 바디의 `rotation`은 안 건드린다 → 물리 거동 영향 0
- `pinball.gd`를 수정하지 않는다 → 완성된 물리 코드에 회귀 위험 없음
- 프로젝트 확립 패턴(`FlipperParryFeedback` = 연출·물리 분리)과 일치

### 구성 파일

```
신규  scripts/ball_base_system/vfx/ball_gaze_visual.gd   BallGazeVisual  (Node2D)
신규  scripts/ball_base_system/vfx/ball_gaze_rules.gd    BallGazeRules   (Resource)
신규  settings/balls/BallGazeRules.tres                  조정값 프리셋
수정  Resources/balls/base/base_ball.tscn                기존 Visual 노드에 스크립트 지정만
신규  tests/ball_base_system/ball_gaze_visual_test.gd    헤드리스 테스트 8종
```

**`pinball.gd`는 한 줄도 고치지 않았다.** 완성된 물리 코드에 회귀를 만들지 않기 위해서다.

### 핵심 로직

```gdscript
var velocity := body.linear_velocity
if velocity.length() >= _gaze_rules.gaze_speed_threshold:
	_target_angle = velocity.angle()
	if not _has_locked_on:
		_has_locked_on = true
		if _gaze_rules.instant_on_spawn:
			global_rotation = _target_angle    # 발사 순간은 즉시 정렬
			return
global_rotation = lerp_angle(global_rotation, _target_angle, _interpolation_weight(delta))
```

```gdscript
func _interpolation_weight(delta: float) -> float:
	return minf(1.0 - exp(-_gaze_rules.gaze_sharpness * delta), 1.0)
```

**`global_rotation`을 쓰는 이유**: 부모 바디가 회전해도 Visual은 월드 절대각을 유지한다.
바디의 `rotation`은 건드리지 않으므로 물리 거동에 영향이 0이다.

**`minf(..., 1.0)`이 있는 이유**: 프레임이 튀어 delta가 커져도 목표를 지나치지 않게 막는다.

**임계 속력 미만에서도 매 프레임 `global_rotation`을 덮어쓰는 이유**: 안 쓰면 Visual이
부모의 회전을 그대로 물려받아 멈춘 공이 계속 돈다.

### 조정값 (`settings/balls/BallGazeRules.tres`)

| 항목 | 기본값 | 범위 | 의미 |
|---|---|---|---|
| `gaze_speed_threshold` | 120.0 px/s | 0~2000 | 이하에서는 시선 갱신 정지 (떨림 방지) |
| `gaze_sharpness` | 18.0 | 1~60 | 클수록 즉각 반응 |
| `instant_on_spawn` | true | - | 발사 순간 보간 없이 즉시 정렬 |

`gaze_sharpness = 18`의 체감: **90% 도달 128ms, 99% 도달 256ms.**
느리게 하려면 낮추고, 패링 직후 급반전을 더 즉각적으로 만들려면 올린다.

### 프레임레이트 독립성 (수치 검증 완료)

지수 감쇠라 30fps 한 걸음과 120fps 네 걸음의 총 진행량이 **1e-16 이내로 일치**한다.

| fps | 프레임당 가중치 |
|---|---|
| 30 | 0.4512 |
| 60 | 0.2592 |
| 120 | 0.1393 |
| 144 | 0.1175 |

### 테스트

```
godot --headless --path . --script res://tests/ball_base_system/ball_gaze_visual_test.gd
```

`PASS: ball_gaze_visual_test` 가 나오면 통과다. 검증 항목 8종:

1. 규칙 리소스 기본값과 상·하한 보정
2. `base_ball.tscn`의 Visual에 스크립트가 붙어 있고 `Visual/Sprite2D` 경로가 유지됨
3. 발사 첫 프레임에 보간 없이 진행방향과 정확히 일치
4. 속도 방향이 바뀌면 시선이 따라가 수렴
5. 임계 속력 미만에서는 목표 각도를 갱신하지 않고 마지막 방향 유지
6. **바디가 회전해도 시각 노드의 월드 각도는 진행방향 유지** (이 시스템의 존재 이유)
7. 170도 반전 시 `lerp_angle`이 짧은 쪽으로 회전
8. 지수 감쇠 가중치의 프레임레이트 독립성과 상한 1.0

### 남은 검수 (실기 확인 필요)

- 패링으로 방향이 급반전할 때 체감이 어색하지 않은가 -> 어색하면 `gaze_sharpness` 조정
- VFX_01 트레일 방향과 시선이 어긋나 보이지 않는가

---

## 7. 교체 절차

1. 최종 파일을 `Resources/Art/balls/cats_eye_ball.png`로 저장
2. `base_ball.tscn`의 텍스처 `ext_resource` 경로 교체
   (Sprite2D의 `scale`은 `refresh_ball_size()`가 자동 갱신하므로 손대지 않는다)
3. 구본 `ball.png`, 폐기 대상 `industrial_steel_ball.png` 정리
4. 변종 6종(`dead/rubber/super`, `heavy/light/normal`)은 base 상속이라 자동 반영

---

## 8. 미결

- 변종별 전용 아트 여부 (현재 base 1종 공유). 만든다면 실루엣 고정 + 코어 색·굵기만 변경
- 피격·저주 상태 표현
- 발사·조준 UI와 공의 관계
- 반려된 A(수정구슬) / C(컷젬) 시안은 범퍼·유물 아트로 전용 가능
