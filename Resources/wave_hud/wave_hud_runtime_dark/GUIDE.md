# Wave HUD Dark - Godot Runtime Guide

확정안: 다크 패널 HUD  
기준 해상도: 1920x1080  
PNG 출력 배율: 2x (`논리 크기 = PNG 픽셀 크기 / 2`)

이 폴더에는 HUD 전용 이미지 레이어만 포함한다. 보드, 플리퍼, 월드 오브젝트와 같은 게임 아트는 포함하지 않는다. 모든 PNG는 투명 배경이며 텍스트는 Godot에서 동적으로 출력한다.

## 공통 색상과 패널 스타일

| 역할 | 값 |
|---|---|
| 패널 배경 | `#15333BEF` |
| 설정 버튼 배경 | `#15333BF2` |
| 아이보리 | `#F1E6CB` |
| 플레이어 민트 | `#67D8D0` |
| 잉크/텍스트 외곽선 | `#071C24` |
| 보조 선 | `#C6BDA8` |
| 수리도 트랙 | `#A349A4` |
| 수리도 채움 | `#FFF200` |
| 패널 그림자 | `#071C2470`, blur `4`, offset `(4, 5)` |

패널 테두리는 3px이다. PNG 레이어 사용 시 `shadow -> fill -> border -> content` 순서로 쌓는다. 테두리와 그림자 PNG는 바깥쪽 픽셀이 포함되므로 논리 컨테이너의 중심에 맞춰 정렬한다.

## 화면 배치

| UI | 위치 | 논리 크기 |
|---|---:|---:|
| 라이프 | `(28, 24)` | 최대 `364x90` |
| 점수 | `(710, 22)` | `500x110` |
| 설정 | `(1820, 24)` | `72x72` |
| 최대 콤보 | `(850, 258)` | `220x76`, rotation `-2deg` |

## Life

레이어 순서:

1. `life/panel_shadow.png`
2. `life/panel_fill.png`
3. `life/panel_border.png`
4. 공 타입 아이콘
5. 현재 공에만 `life/current_outline.png`

공 슬롯은 왼쪽부터 고정되며 사용 상태가 바뀌어도 재정렬하지 않는다.

- 아이콘 논리 크기: `56x56`
- 아이콘 Y: `17`
- 좌측 패딩: `18`
- 슬롯 간격: `12`
- 슬롯 X: `18 + index * 68`
- 3-5개 가변 폭: `36 + count * 56 + (count - 1) * 12`
- 현재 공 외곽선 논리 박스: `68x68`, 해당 슬롯보다 `(-6, -6)`
- 사용한 공: 해당 타입 아이콘의 `modulate.a = 0.26`
- 남은 공: 원본 색상, `modulate.a = 1.0`
- 현재 공: 원본 색상 + 외곽선, 별도 텍스트/펄스 없음

공 타입 파일:

- `life/ball_normal.png`
- `life/ball_cat_eye.png`
- `life/ball_industrial_steel.png`

## Score / Repair Gauge

레이어 순서:

1. `score/panel_shadow.png`
2. `score/panel_fill.png`
3. `score/panel_border.png`
4. `score/top_rail.png` at `(168, 0)`, logical `164x7`
5. `score/divider.png` centered on logical box `(286, 18, 3, 54)`, rotation `2deg`
6. 수리도 게이지
7. 나사 장식
8. 동적 텍스트

게이지:

- 트랙: `score/gauge_track.png`, logical box `(126, 91, 342, 7)`
- 채움: `score/gauge_fill.png`, logical full size `342x7`, left anchored
- 표시 폭: `342 * clamp(current_score / target_score, 0.0, 1.0)`
- 눈금: `score/gauge_segment.png`, logical `2x9`, Y `90`
- 눈금 X: `169 + index * 43`, index `0..6`
- 나사: `score/screw.png`, 디자인 박스 `11x11`; 좌 `(8, 10)`, 우 `(480, 86)`

Godot에서는 `TextureProgressBar` 또는 `clip_contents`를 켠 `Control` 아래의 채움 `TextureRect`를 권장한다. 채움 이미지를 비율 스케일하지 말고 오른쪽을 클리핑해야 둥근 왼쪽 끝과 색이 유지된다.

## Settings

레이어 순서:

1. `settings/button_shadow.png`
2. `settings/button_fill.png`
3. `settings/button_border.png`
4. `settings/inner_ring.png` at `(9, 9)`, logical `54x54`
5. `settings/gear_icon.png`, `30x30` 박스 안에 중앙 정렬, 박스 위치 `(21, 21)`

버튼 논리 크기는 `72x72`이다. Hover/pressed 상태는 이미지를 추가하지 않고 Godot의 `modulate`와 scale로 처리한다.

- Hover: 민트 밝기 `+10%`, scale `1.04`
- Pressed: scale `0.96`
- 포커스 표시는 `button_border.png`의 민트 색상 복제 레이어 사용

## World Max Combo

텍스트 배경 패널은 사용하지 않는다. 장식 레이어는 다음 순서로 텍스트와 함께 배치한다.

- `combo/accent_rail.png`: `(0, 61)`, logical `110x3`, rotation `-1deg`
- `combo/anchor_pointer.png`: `(100, 61)`, logical `14x9`, rotation `180deg`
- `combo/impact_tick_mint.png`: 디자인 박스 `(118, 29, 18, 3)`, rotation `-28deg`
- `combo/impact_tick_ivory.png`: 디자인 박스 `(124, 42, 13, 3)`, rotation `8deg`

## Dynamic Text

폰트: [Black And White Picture](https://fonts.google.com/specimen/Black+And+White+Picture)  
Godot에서는 `Label`의 Theme Overrides에서 font, font size, color, outline size, outline color를 지정한다.

| 텍스트 | 위치 | 크기 | 색상 | 외곽선 | 기타 |
|---|---:|---:|---|---|---|
| 현재 스코어 라벨 | `(24, 13)` | 15 | `#67D8D0` | 없음 | - |
| 현재 스코어 값 | `(24, 36)` | 40 | `#F1E6CB` | 2px `#071C24` | letter spacing 1 |
| 목표 스코어 라벨 | `(310, 13)` | 15 | `#67D8D0` | 없음 | - |
| 목표 스코어 값 | `(310, 40)` | 28 | `#F1E6CB` | 없음 | - |
| 수리도 라벨 | `(24, 85)` | 13 | `#67D8D0` | 없음 | 예: `REPAIR 73.6%` |
| 콤보 라벨 | `(0, 0)` | 15 | `#67D8D0` | 3px `#071C24` | letter spacing 2 |
| 콤보 값 | `(0, 19)` | 42 | `#F1E6CB` | 4px `#071C24` | 예: `x18` |
| 웨이브 라벨 | 화면 `(906, 140)` | 18 | `#8BC7C180` | 없음 | letter spacing 5 |

콤보 텍스트 그림자: `#071C24CC`, offset `(3, 3)`. 콤보는 연관 월드 오브젝트의 화면 좌표를 추적하되 보드 진행 방향을 가리는 배경 창을 추가하지 않는다.

## PNG Manifest

| 파일 | 출력 픽셀 |
|---|---:|
| `life/panel_shadow.png` | 744x196 |
| `life/panel_fill.png` | 728x180 |
| `life/panel_border.png` | 734x186 |
| `life/current_outline.png` | 173x173 |
| `life/ball_*.png` | 112x112 |
| `score/panel_shadow.png` | 1016x236 |
| `score/panel_fill.png` | 1000x220 |
| `score/panel_border.png` | 1006x226 |
| `score/gauge_track.png` | 686x16 |
| `score/gauge_fill.png` | 684x14 |
| `score/gauge_segment.png` | 4x18 |
| `settings/button_fill.png` | 144x144 |
| `settings/button_border.png` | 150x150 |
| `settings/button_shadow.png` | 160x160 |

HUD 텍스처 Import는 lossless, mipmaps off를 권장한다. 2x 리소스를 기준 해상도에서 절반 크기로 표시하고 필터링을 켜면 회전된 장식과 곡선 외곽선이 안정적으로 보인다.
