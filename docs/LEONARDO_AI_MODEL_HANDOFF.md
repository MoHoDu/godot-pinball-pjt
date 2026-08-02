# Leonardo.Ai Pro 이미지 생성 모델 인계 문서

> 대상: 이 프로젝트를 이어서 작업할 Claude 또는 다른 AI 에이전트  
> 검증 기준일: 2026-08-02 (Asia/Seoul)  
> 검증 방법: Leonardo.Ai 공식 REST API 문서와 사용자의 로그인된 Leonardo Pro 생성 화면을 교차 확인

## 1. 이 문서의 목적

이 문서는 핀볼 게임 아트 제작에 Leonardo.Ai Pro를 사용할 때, 모델마다 실제로 지원하는 설정을 혼동하지 않도록 만든 인계 자료다.

다음 원칙을 반드시 지킨다.

1. 사용자의 명시적인 작업 지시 전에는 이미지, 프롬프트, 에셋을 임의로 생성하거나 수정하지 않는다.
2. Jira는 이 작업 범위에서 제외한다.
3. 모델을 먼저 확정한 후, 그 모델이 실제로 지원하는 옵션만 안내한다.
4. Leonardo 웹 UI에 공통 입력란이 보인다는 이유만으로 해당 모델의 네이티브 기능이라고 단정하지 않는다.
5. 모델과 UI는 변경될 수 있으므로 실제 생성 직전에는 현재 UI와 공식 문서를 다시 확인한다.

## 2. 프로젝트 맥락

사용자는 AI 해커톤용 핀볼 게임을 제작 중이다. 아트 파이프라인은 대략 다음과 같다.

- Leonardo.Ai Pro: 주요 이미지 생성
- GPT 또는 Nano Banana 계열: 수정 및 세부 디테일 작업 후보
- Canva: 후처리 및 편집 후보
- 별도 VFX와 사운드 제작 예정

현재 가장 최근에 확정된 메인 보드 규격은 다음과 같다.

- 기준 캔버스: 1920×1080
- 실제 보드: 1912×1072
- 화면 좌우 및 외곽 여백: 4px
- 긴 수평 상단/하단, 수직 좌/우 변, 네 개의 얕은 대각 모서리를 가진 넓은 팔각형 실루엣
- 대각 변: 약 634px, 약 17.1도
- 보드만 필요한 단계에서는 플리퍼, 벽, 레일, 범퍼, 타깃, 보스, 캐릭터, 장식 오브젝트를 생성하지 않는다.
- 플리퍼 위치는 돌출 오브젝트가 아니라 표면과 같은 높이의 단순한 위치 마킹만 허용할 수 있다.

최신 보드 규격 이미지가 이전의 언어적 설명과 충돌할 경우 최신 보드 규격 이미지를 우선한다.

## 3. 관련 원본 자료

### 기획 PDF

- `C:\Users\robot\Downloads\핀볼로그_컨셉기획서_v0.1_강보현.pdf`
- `C:\Users\robot\Downloads\다각형 외곽 플리퍼 선택·작동·공 패링 시스템 기획서_v2_강보현.pdf`
- `C:\Users\robot\Downloads\핀볼_PL_비주얼_사운드방향성가이드_강보현.pdf`

### 주요 이미지 레퍼런스

- 비주얼 가이드: `C:\Users\robot\Downloads\content2.png`
- 비주얼 가이드 및 플리퍼 컨셉 시트: `C:\Users\robot\Downloads\content.png`
- 현재 게임 플리퍼 이미지: `C:\Users\robot\AppData\Local\Temp\codex-clipboard-d9cff2fb-5c40-4796-b844-10bf4c51053f.png`
- 최신 보드 규격 이미지: `C:\Users\robot\AppData\Local\Temp\codex-clipboard-0a52cdde-c670-464c-a971-fe143f8e4420.png`

`AppData\Local\Temp`의 파일은 사라질 수 있다. 실제 제작을 시작할 때 파일이 없다면 사용자에게 다시 첨부해 달라고 요청하고, 임의로 대체 이미지를 사용하지 않는다.

### Confluence

- `https://iambiguity.atlassian.net/wiki/spaces/~712020ee2aad7553a24fbdbcd73713654d1e91/pages/15269907/Hire+us+Pls`

필요한 경우 페이지와 하위 페이지를 읽되 Jira 작업은 하지 않는다.

## 4. 2026-08-02 Leonardo Pro 화면의 모델 목록

### Featured

- Auto
- GPT Image 2
- Nano Banana 2
- Nano Banana 2 Lite
- Krea 2 Turbo
- Seedream 5.0 Pro
- Lucid Origin
- Nano Banana Pro

### Other

- Ideogram 4.0
- Recraft V4
- Recraft V4 Pro
- Seedream 4.5
- FLUX.2 Pro
- GPT Image-1.5
- Seedream 4.0
- Nano Banana
- Lucid Realism
- Ideogram 3.0
- GPT Image-1
- FLUX.1 Kontext Max
- FLUX.1 Kontext
- FLUX Dev
- FLUX Schnell
- Phoenix 1.0
- Phoenix 0.9
- Anime
- Cinematic Kino
- Concept Art
- Graphic Design
- Illustrative Albedo
- Leonardo Lightning
- Lifelike Vision
- Portrait Perfect
- Stock Photography

## 5. 반드시 구분해야 하는 Reference 체계

### 5.1 역할이 분리된 Reference

#### Phoenix 1.0 / 0.9

- Image-to-Image: 최대 1장, 강도 `LOW/MID/HIGH`
- Content Reference: 최대 1장, 강도 `LOW/MID/HIGH`
- Character Reference: 최대 1장, 강도 `LOW/MID/HIGH`
- Style Reference: 최대 4장, 강도 `LOW/MID/HIGH/ULTRA/MAX`

보드 규격과 스타일 이미지를 서로 다른 역할로 명확하게 지정할 수 있다.

#### Lucid Origin / Lucid Realism

- Content Reference: 최대 1장, 강도 `LOW/MID/HIGH`
- Style Reference: 최대 1장, 강도 `LOW/MID/HIGH/ULTRA/MAX`

두 개의 비주얼 가이드 이미지를 각각 독립적인 Style Reference로 넣을 수 없다. Style Reference는 한 장만 선택해야 한다.

### 5.2 통합 Image Reference

다음 모델들은 Style과 Content를 별도 슬롯으로 나누지 않고 통합 `Image Reference`를 사용한다.

- GPT Image 2: 최대 6장, Strength 없음
- GPT Image-1.5: 최대 6장, `LOW/MID/HIGH`
- Nano Banana 2: 최대 6장, `LOW/MID/HIGH`
- Nano Banana 2 Lite: 최대 6장, `LOW/MID/HIGH`
- Nano Banana Pro: 최대 6장, `LOW/MID/HIGH`
- Nano Banana: 최대 6장, `LOW/MID/HIGH`
- Seedream 5.0 Pro: 최대 10장, `LOW/MID/HIGH`
- Seedream 4.5 / 4.0: 최대 6장, `LOW/MID/HIGH`
- FLUX.2 Pro: 최대 4장, `LOW/MID/HIGH`
- FLUX.1 Kontext Max / Kontext: 최대 4장, `LOW/MID/HIGH`

이 계열에서는 Reference 1을 Content, Reference 2를 Style로 지정하는 별도 UI가 없다. 프롬프트 본문에서 각 이미지의 역할을 명시해야 한다.

예시 역할 설명:

- Reference 1: exact geometry and silhouette only
- Reference 2: palette and painted-wood texture only
- Reference 3: line quality and dark-cartoon mood only
- Do not copy objects, characters, eyes, toys, text, or scenery from style references

GPT Image 2는 이미지별 Strength를 받지 않는다. Strength 값을 안내하면 안 된다.

### 5.3 레거시 ControlNet 계열

일부 레거시 Leonardo 모델은 다음과 같은 제어 방식을 추가로 제공한다.

- Image-to-Image
- Style Reference
- Content Reference
- Character Reference
- Edge-to-Image
- Depth-to-Image
- Pose-to-Image
- Text Image Input
- 모델에 따라 Sketch, Line Art, Normal, Pattern, QR 등

정확한 실루엣 고정이 필요할 때 Edge 계열이 유용할 수 있지만, 현재 선택한 레거시 모델에서 해당 옵션이 실제로 활성화되는지 먼저 확인한다.

## 6. 모델별 주요 설정

### 6.1 GPT Image 2

실제 Pro UI:

- Prompt Enhance: `Auto/On/Off`
- Style preset: `Dynamic`, `None`, `Game Concept`, `Graphic Design 2D` 등
- Quality: `Low/Medium/High`
- 수량: 1–8
- Reference: Image Reference
- Fixed Seed: 현재 UI에 없음

실제 UI의 16:9 해상도:

- Small: 1376×768
- Medium: 2048×1136
- Large: 3584×2016

공식 API:

- Image Reference 최대 6장
- Reference Strength 미지원
- Quality `LOW/MEDIUM/HIGH`
- 사용자 지정 해상도는 각 변이 16의 배수여야 한다.
- 긴 변은 3840 미만, 종횡비는 최대 3:1, 전체 픽셀 수 제한이 있다.
- API에 `negative_prompt`, `seed`, `style_ids`가 문서화되어 있지 않다.

공식 문서: https://docs.leonardo.ai/me/docs/gpt-image-2

### 6.2 Nano Banana 2

실제 Pro UI:

- Prompt Enhance: `Auto/On/Off`
- Style preset
- 수량: 1–8
- Advanced Settings: `Use Fixed Seed`
- Image Reference
- 현재 모델 메뉴에 Video Reference 지원도 표시됨

실제 UI의 16:9 해상도:

- Small: 1376×768
- Medium: 2752×1536
- Large: 5504×3072

공식 API:

- Image Reference 최대 6장
- Strength `LOW/MID/HIGH`
- Prompt Enhance `ON/OFF`
- Seed 지원
- 수량 최대 8
- 지원되는 너비와 높이의 올바른 조합을 사용해야 한다. 개별 값만 유효하고 조합이 잘못되면 1:1로 조용히 대체될 수 있다.

공식 문서: https://docs.leonardo.ai/docs/nano-banana-2

### 6.3 Nano Banana 2 Lite

- Prompt Enhance `AUTO/ON/OFF`
- Style preset 1개
- Image Reference 최대 6장
- Strength `LOW/MID/HIGH`
- Fixed Seed
- 수량 최대 8
- Nano Banana 2보다 지원 해상도 범위가 작다.

공식 문서: https://docs.leonardo.ai/docs/nano-banana-2-lite

### 6.4 Nano Banana Pro

- API 모델 ID: `gemini-image-2`
- Prompt Enhance
- Style preset
- Fixed Seed
- Image Reference 최대 6장
- Strength `LOW/MID/HIGH`
- 수량 최대 8
- 별도의 Content/Style Reference 역할 분리 없음

공식 문서: https://docs.leonardo.ai/me/docs/nano-banana-pro

### 6.5 Lucid Origin

실제 Pro UI:

- Prompt Enhance: `Auto/On/Off`
- Style preset
- Generation Mode: `Fast/Ultra`
- Advanced Settings: Fixed Seed
- Content Reference 1장
- Style Reference 1장
- 프롬프트 최대 2,000자

실제 UI의 16:9 해상도:

- Small: 1376×768
- Medium: 1600×896
- Large: 1920×1088

공식 API 최대 크기:

- Width: 16–3840, 8의 배수
- Height: 16–3616, 8의 배수

공식 문서: https://docs.leonardo.ai/docs/lucid-origin

### 6.6 Lucid Realism

- Prompt Enhance `AUTO/ON/OFF`
- Style preset
- Generation Mode `FAST/ULTRA`
- Fixed Seed
- Content Reference 최대 1장
- Style Reference 최대 1장
- 프롬프트 최대 9,999자
- 최대 2496×2496 범위, 8의 배수
- 사진적·시네마틱 결과용이며 현재의 평면 보드 작업에서는 우선순위가 낮다.

공식 문서: https://docs.leonardo.ai/me/docs/lucid-realism

### 6.7 Phoenix 1.0 / 0.9

실제 Pro UI:

- Prompt Enhance: `Auto/On/Off`
- Style preset
- Contrast: `Low/Medium/High`
- Generation Mode: `Fast/Quality/Ultra`
- Advanced Settings: Fixed Seed
- Negative Prompt 입력란

실제 UI의 16:9 해상도:

- Small: 1184×672
- Medium: 1376×768
- Large: 1472×832

공식 API:

- 프롬프트 최대 2,000자
- `negative_prompt` 네이티브 지원
- Seed 지원
- Tiling 지원
- Width/Height 32–2048, 8의 배수
- Style 최대 4장, Content/Character/Image-to-Image 각각 최대 1장

공식 문서: https://docs.leonardo.ai/docs/phoenix

### 6.8 Krea 2 Turbo

실제 Pro UI:

- Prompt Enhance `Auto/On/Off`
- Image Dimensions
- 수량 1–8
- Private Mode
- Style, Quality, Reference, Fixed Seed 옵션 없음
- 프롬프트 최대 9,999자

실제 UI의 16:9 해상도:

- Small: 1376×768
- Medium: 2064×1152
- Large: 2752×1536

공식 API는 16–4096 범위의 8의 배수 해상도를 지원한다.

공식 문서: https://docs.leonardo.ai/docs/krea-2-turbo

### 6.9 Seedream 5.0 Pro

- Image Reference 최대 10장
- Strength `LOW/MID/HIGH`
- Prompt Enhance `AUTO/ON/OFF`
- Seed 지원
- Width/Height 768–2048
- 수량 1–6
- 출력 포맷 `JPEG/PNG`
- 별도의 Content/Style Reference 구분 없음

공식 문서: https://docs.leonardo.ai/docs/seedream-50-pro

### 6.10 Seedream 4.5 / 4.0

- Image Reference 최대 6장
- Strength `LOW/MID/HIGH`
- Prompt Enhance
- Style preset
- Seed
- 별도의 Content/Style 역할 구분 없음

Seedream 4.5 공식 문서에는 1920×1080 예시와 너비 범위 설명이 서로 일치하지 않는 부분이 있다. 실제 생성 전 UI에서 선택 가능한 해상도를 기준으로 재확인한다.

공식 문서:

- https://docs.leonardo.ai/me/docs/seedream-4-5
- https://docs.leonardo.ai/docs/seedream-4-0

### 6.11 FLUX.2 Pro

- Image Reference 최대 4장
- Strength `LOW/MID/HIGH`
- Prompt Enhance
- Style preset
- Seed 최대 `4294967295`
- 수량 최대 8
- 공식 API 해상도 범위 256–1440
- 공식 16:9 해상도 1440×810

공식 문서: https://docs.leonardo.ai/docs/flux-2-pro

### 6.12 FLUX.1 Kontext Max / Kontext

- 통합 Image Reference 최대 4장
- Strength `LOW/MID/HIGH`
- Prompt Enhance `AUTO/ON/OFF`
- Style preset
- Fixed Seed
- Kontext Max 프롬프트 최대 9,999자
- Kontext Max Width/Height 32–2048

공식 문서: https://docs.leonardo.ai/docs/flux1-kontext-max

### 6.13 FLUX Dev / Schnell

현재 모델 메뉴 기준:

- FLUX Dev: Style Reference, Content Reference, Elements, Unlimited 표시
- FLUX Schnell: Style Reference, Content Reference, Unlimited 표시

세부 ControlNet 옵션은 생성 화면에서 해당 모델을 선택한 후 다시 확인한다.

### 6.14 GPT Image-1.5

- Image Reference 최대 6장
- Strength `LOW/MID/HIGH`
- Quality `LOW/MEDIUM/HIGH`
- Prompt Enhance
- Seed
- 공식 고정 비율: 1024×1024, 1024×1536, 1536×1024
- 공식적으로 16:9 출력이 없음

공식 문서: https://docs.leonardo.ai/me/docs/gpt-image-1-5

### 6.15 Ideogram 4.0

2026-08-02 실제 Pro UI에서 확인한 설정:

- Prompt Enhance `Auto/On/Off`
- Quality `Low/Medium/High`
- Custom Dimensions
- 수량 1–4
- Private Mode
- 프롬프트 입력 한도 10,000자
- Style, Reference, Fixed Seed는 현재 화면에 없음

### 6.16 Ideogram 3.0

- Prompt Enhance
- Style preset
- Seed
- Quality `TURBO/BALANCED/QUALITY`
- API의 구형 `mode` 파라미터는 폐기되었으므로 `quality`를 사용한다.

공식 문서: https://docs.leonardo.ai/docs/ideogram-30

### 6.17 Recraft V4 / Recraft V4 Pro

공통:

- Prompt Enhance `ON/OFF`
- 수량 1–6
- 사용자 지정 해상도 미지원
- 공식 API에 Reference, Style preset, Seed, Negative Prompt가 문서화되어 있지 않음

16:9:

- Recraft V4: 1344×768
- Recraft V4 Pro: 2688×1536

공식 문서:

- https://docs.leonardo.ai/v1.0/docs/recraft-v4
- https://docs.leonardo.ai/v1.0/docs/recraft-v4-pro

## 7. Negative Prompt 사용 규칙

### 공식 네이티브 지원이 확인된 모델

- Phoenix 1.0 / 0.9
- 일부 레거시 생성 모델

### 네이티브 지원을 단정하면 안 되는 최신 모델

- GPT Image 2 / GPT Image-1.5
- Nano Banana 계열
- Seedream 계열
- Krea 2 Turbo
- Recraft V4 계열
- FLUX.2 Pro / FLUX Kontext 계열
- Lucid Origin / Lucid Realism

Leonardo 웹 UI가 모델 변경 후에도 Negative Prompt 입력란을 유지할 수 있다. 하지만 공식 모델별 API 문서에 `negative_prompt`가 없으면 독립적인 네거티브 조건으로 얼마나 반영되는지 보장할 수 없다.

따라서 최신 Omni 계열 모델에서는 핵심 금지 조건을 Positive Prompt에도 자연어 문장으로 작성한다.

예:

```text
Keep the entire surface completely empty. Do not add flippers, walls, rails,
bumpers, targets, eyes, characters, symbols, text, props or raised objects.
```

Negative Prompt 입력란은 보조 수단으로만 사용한다.

## 8. Prompt Enhance 사용 규칙

정밀한 보드 구조, 정확한 실루엣, 빈 표면, 오브젝트 금지처럼 제약이 많은 작업에서는 `Off`를 기본값으로 한다.

- `On`: Leonardo가 프롬프트를 확장하므로 장식이나 오브젝트를 추가할 수 있다.
- `Auto`: 짧은 프롬프트가 자동 확장될 수 있다.
- `Off`: 작성한 문장을 그대로 전달하는 데 가장 유리하다.

분위기 탐색이나 자유로운 컨셉 발산 단계에서만 `Auto` 또는 `On`을 고려한다.

## 9. 프롬프트 글자 수

글자 수는 모델마다 다르다.

| 모델 | 확인된 최대 길이 |
|---|---:|
| Phoenix 1.0 / 0.9 | 2,000자 |
| Lucid Origin | 2,000자 |
| Lucid Realism | 9,999자 |
| FLUX.1 Kontext Max | 9,999자 |
| Krea 2 Turbo | 실제 UI 9,999자 |
| Ideogram 4.0 | 실제 UI 10,000자 |

나머지 모델은 공식 문서에 명확한 글자 수가 없으면 추측하지 않는다. 입력창의 `maxlength` 또는 실제 카운터를 확인한다.

이전에 긴 프롬프트가 `hand-pain...` 부근에서 잘린 것은 Phoenix 또는 Lucid Origin의 2,000자 제한에 걸린 것으로 판단된다.

## 10. 현재 보드 작업에서의 모델 선택 원칙

사용자가 모델을 지정하지 않은 경우 임의 생성하지 말고 먼저 후보와 차이를 설명한다.

### 역할 분리가 중요한 경우

추천 후보:

- Phoenix 1.0
- Lucid Origin

이유:

- 규격 이미지를 Content Reference로 지정할 수 있다.
- 비주얼 가이드를 Style Reference로 분리할 수 있다.
- Phoenix는 네이티브 Negative Prompt와 최대 4장의 Style Reference를 지원한다.

### 여러 장의 통합 레퍼런스를 함께 해석시키는 경우

추천 후보:

- GPT Image 2
- Nano Banana 2
- Seedream 5.0 Pro
- FLUX.1 Kontext Max

주의:

- Content와 Style의 역할이 별도 슬롯으로 분리되지 않는다.
- GPT Image 2는 Reference Strength가 없다.
- 각 이미지의 역할을 프롬프트 안에서 명시해야 한다.

### 정확한 규격 이미지가 없는 순수 텍스트 생성

후보:

- Krea 2 Turbo
- Ideogram 4.0
- Recraft V4 / V4 Pro

현재처럼 정확한 보드 외곽 실루엣을 유지해야 하는 작업에는 우선순위가 낮다.

## 11. 최신 보드용 Reference 배치 원칙

### Phoenix 1.0을 사용할 때

- 최신 보드 규격 이미지 → Content Reference `HIGH`
- 비주얼 가이드 1장 → Style Reference `MID`부터 시험
- 필요하면 두 번째 비주얼 가이드 → 두 번째 Style Reference `LOW/MID`
- Prompt Enhance → `Off`
- 최초 탐색 → `Fast`
- 후보 확정 후 → `Quality` 또는 `Ultra`
- Negative Prompt 사용 가능

### Lucid Origin을 사용할 때

- 최신 보드 규격 이미지 → Content Reference `HIGH`
- 가장 적합한 비주얼 가이드 한 장 → Style Reference `MID`
- 두 번째 Style Reference를 추가할 수 없음
- Prompt Enhance → `Off`
- 최초 탐색 → `Fast`
- 후보 확정 후 → `Ultra`

### GPT Image 2를 사용할 때

- 규격 이미지와 비주얼 가이드를 모두 Image Reference로 추가
- Strength 설정을 안내하지 않음
- 프롬프트에서 각 레퍼런스의 역할을 순서대로 명시
- Prompt Enhance → `Off`
- 구조 검증 단계 → Quality `Medium`
- 최종 후보 → Quality `High`
- 핵심 금지 조건을 Positive Prompt에도 작성

### Nano Banana 2를 사용할 때

- 규격 이미지 → Image Reference `HIGH`
- 비주얼 가이드 → Image Reference `LOW` 또는 `MID`
- Prompt Enhance → `Off`
- Fixed Seed는 동일 구도를 변형 비교할 때만 사용
- 핵심 금지 조건을 Positive Prompt에도 작성

## 12. 빈 보드 생성 결과 검수 체크리스트

생성 후 다음 항목을 순서대로 확인한다.

### 형태

- 보드 전체가 프레임 안에 보이는가?
- 크롭되지 않았는가?
- 정사영 탑다운인가?
- 원근, 아이소메트릭, 카메라 틸트가 없는가?
- 최신 규격의 긴 상하단, 수직 좌우, 네 대각 모서리가 유지되는가?
- 실루엣이 좌우 및 상하 대칭인가?

### 빈 표면

- 플리퍼 실물이 없는가?
- 벽, 레일, 림, 프레임, 베벨, 돌출 두께가 없는가?
- 범퍼, 타깃, 별, 눈, 보스, 캐릭터, 장난감, 촛불, 제단이 없는가?
- 중앙 모티프나 장식 패널이 없는가?
- 텍스트, 숫자, 치수선, UI, 컨셉 시트 구성이 없는가?

### 허용되는 표현

- 평평한 페인트 표면
- 절제된 목재 질감
- 낮은 시각적 노이즈
- 표면과 같은 높이의 단순한 플리퍼 위치 마킹
- 비주얼 가이드의 팔레트와 선화 감각

### 게임 적용성

- 공의 이동 경로를 방해할 시각적 오브젝트가 없는가?
- 충돌체와 실제 아트의 경계가 혼동되지 않는가?
- 1920×1080 화면에서 보드 경계가 읽히는가?
- 후속 플리퍼, 범퍼, VFX를 별도 레이어로 얹을 수 있는가?

## 13. 작업 절차

새 이미지 작업을 요청받으면 다음 순서를 따른다.

1. 사용자가 원하는 결과물이 보드, 플리퍼, 범퍼, VFX 중 무엇인지 확인한다.
2. 사용할 Leonardo 모델을 명시한다.
3. 해당 모델의 현재 UI에서 지원 옵션을 다시 확인한다.
4. Reference 역할과 장수 제한을 확인한다.
5. Prompt Enhance, Style, Quality/Mode, 해상도, 수량, Seed를 모델에 맞게 제안한다.
6. Positive Prompt를 해당 모델의 입력 한도 안으로 작성한다.
7. 네이티브 Negative Prompt 지원 여부를 구분한다.
8. 사용자의 승인 또는 명시적 생성 지시 전에는 생성하지 않는다.

## 14. 공식 문서 링크

- Phoenix: https://docs.leonardo.ai/docs/phoenix
- Lucid Origin: https://docs.leonardo.ai/docs/lucid-origin
- Lucid Realism: https://docs.leonardo.ai/me/docs/lucid-realism
- GPT Image 2: https://docs.leonardo.ai/me/docs/gpt-image-2
- GPT Image-1.5: https://docs.leonardo.ai/me/docs/gpt-image-1-5
- Nano Banana 2: https://docs.leonardo.ai/docs/nano-banana-2
- Nano Banana 2 Lite: https://docs.leonardo.ai/docs/nano-banana-2-lite
- Nano Banana Pro: https://docs.leonardo.ai/me/docs/nano-banana-pro
- Seedream 5.0 Pro: https://docs.leonardo.ai/docs/seedream-50-pro
- Seedream 4.5: https://docs.leonardo.ai/me/docs/seedream-4-5
- Seedream 4.0: https://docs.leonardo.ai/docs/seedream-4-0
- FLUX.2 Pro: https://docs.leonardo.ai/docs/flux-2-pro
- FLUX.1 Kontext Max: https://docs.leonardo.ai/docs/flux1-kontext-max
- Krea 2 Turbo: https://docs.leonardo.ai/docs/krea-2-turbo
- Ideogram 3.0: https://docs.leonardo.ai/docs/ideogram-30
- Recraft V4: https://docs.leonardo.ai/v1.0/docs/recraft-v4
- Recraft V4 Pro: https://docs.leonardo.ai/v1.0/docs/recraft-v4-pro
- Image Guidance 개요: https://docs.leonardo.ai/docs/generate-images-using-image-to-image-guidance

## 15. 불확실성 처리 규칙

- 공식 문서와 웹 UI가 다르면 실제 Pro UI에 노출된 설정을 우선하되 차이를 기록한다.
- API에 없는 UI 옵션은 Leonardo의 프런트엔드 래퍼일 수 있으므로 네이티브 모델 기능이라고 표현하지 않는다.
- 공식 문서에 없는 수치, Strength, Seed, 해상도, 글자 수를 추측하지 않는다.
- 모델 업데이트 후에는 이 문서의 검증 기준일을 갱신하고 변경 내용을 기록한다.
- 사용자가 최신 스펙이나 레퍼런스를 새로 제공하면 기존 문서보다 최신 사용자 자료를 우선한다.
