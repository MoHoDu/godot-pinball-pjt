# Select Ball UI Image Manifest

공 아이콘은 별도 제작 작업과 충돌하지 않도록 생성하지 않는다. 현재 화면 설계에서는 `Resources/Art/balls/glass_eye_ball.png`를 더미 아이콘으로 사용한다.

## Existing ball layers

다음 본체/동공 레이어는 원본 위치에서 참조하며 UI 폴더에 복제하지 않는다.

- `Resources/Art/balls/variants/Ball_Clockwork_Body.png`
- `Resources/Art/balls/variants/Ball_Clockwork_Pupil.png`
- `Resources/Art/balls/variants/Ball_Rubber_Body.png`
- `Resources/Art/balls/variants/Ball_Rubber_Pupil.png`
- `Resources/Art/balls/variants/Ball_Gel_Body.png`
- `Resources/Art/balls/variants/Ball_Gel_Pupil.png`
- `Resources/Art/balls/variants/Ball_Lead_Body.png`
- `Resources/Art/balls/variants/Ball_Lead_Pupil.png`
- `Resources/Art/balls/variants/Ball_HollowBell_Body.png`
- `Resources/Art/balls/variants/Ball_HollowBell_Pupil.png`

## Generated assets

공통 생성 방식은 built-in `image_gen`과 `#00ff00` 크로마 배경 제거다. 확정본은 모두 RGBA이며 네 모서리가 완전 투명하고, 가시 영역에 key-green 픽셀이 없다.

## Final UI mapping

| 리소스 | Pencil 설계 | Godot 런타임 |
| --- | --- | --- |
| `selection_slot_pedestal.png` | 사용 가능·선택·사용 완료 슬롯 공통 받침 | `select_ball_slot_button.tscn`의 슬롯 받침 |
| `selection_focus_sigil.png` | 현재 선택 슬롯에만 표시 | 선택된 버튼의 `FocusRing` 레이어 |
| `selection_surface_overlay.png` | 중앙 팝업 외곽 위주의 희미한 스크래치 | 선택 패널의 저강도 표면 오버레이 |
| `selection_confirm_burst.png` | 확정 직후 닫히기 전 일시 상태 | 런타임 `ConfirmBurst` 연출을 위한 비표시 기본 레이어 |

추가 장식 이미지는 제작하지 않는다. 현재 네 리소스로 슬롯 구조, 선택 상태,
패널 재질, 확정 피드백의 역할이 모두 분리되며, 리소스를 더 추가하면 인게임
가독성과 최소 가림 원칙에 불리하다.

### Slot pedestal

- 파일: `slots/selection_slot_pedestal.png`
- 크기: 1254x1254

```text
Use case: stylized-concept
Asset type: reusable game UI ball-selection pedestal sprite
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal; one uniform color only, with no shadows, gradients, texture, reflections, floor plane, or lighting variation
Primary request: a strictly flat 2D cut-paper and painted-wood illustration of one empty circular toy-machine socket for holding a magic glass-eye ball
Subject: dark teal circular socket body; crooked ivory double rim; exactly two large mint circular screw heads, each drawn only as one flat mint circle plus one single thick dark slot line; exactly one small flat brass alignment mark at the top; completely empty open center
Style/medium: bold hand-painted dark-cartoon game UI sprite; thick imperfect near-black ink outlines; deliberately simple flat cut-paper shapes; slightly crooked handmade contours
Composition/framing: single centered front-facing circular asset, generous even padding, crisp readable silhouette, fully separated from the background
Color palette: #15333B dark teal, #F1E6CB ivory, #67D8D0 mint, small #A98245 brass accent, near-black ink outlines only
Constraints: no ball, eyeball, pupil, text, letters, watermark, bevel, 3D depth, gradients, highlights, shadows, photorealism, purple, or red; do not use #00ff00 in the subject; readable at 128 px
```

### Selection focus

- 파일: `states/selection_focus_sigil.png`
- 크기: 1254x1254

```text
Use case: stylized-concept
Asset type: game UI selected-state overlay sprite
Primary request: a strictly flat 2D hand-painted cut-paper focus ring for the currently selected magic glass-eye ball
Subject: one slightly irregular mint ring, exactly two ivory tick marks at upper-right, exactly one simple brass triangular pointer at right, empty center
Style/medium: bold dark-cartoon UI ornament with thick imperfect near-black outlines and uniform solid fills
Composition/framing: centered ring, generous padding, crisp silhouette, empty central area
Color palette: #67D8D0 mint, #F1E6CB ivory, #A98245 brass, near-black outline
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal
Constraints: exactly four subject colors maximum; no bevel, gradient, glow, highlight, shadow, texture shading, text, ball, eye, pupil, rune, red, purple, or watermark; do not use #00ff00 in the subject
```

### Confirmation burst

- 파일: `effects/selection_confirm_burst.png`
- 크기: 1254x1254

```text
Use case: stylized-concept
Asset type: short game UI confirmation VFX sprite
Scene/backdrop: perfectly flat, perfectly uniform solid #00ff00 chroma-key background for local removal
Subject: one irregular ivory center impact flash with a thick hand-inked near-black outline; exactly five separate chunky mint radial rays with uneven hand-cut paper edges and thick near-black outlines; exactly two small warm-gold paper shards with uneven hand-cut edges and near-black outlines
Style/medium: strictly flat 2D hand-inked cut-paper impact sprite, bold dark-cartoon game art, visibly handmade and slightly crooked
Composition/framing: compact centered radial burst with wide empty padding; all seven outer elements fully separated and clearly countable; readable at 128 px
Color palette: uniform solid #F1E6CB ivory, #67D8D0 mint, #E1B84A warm gold, near-black outline
Constraints: no gradient, glow, blur, bevel, lens flare, shadow, smooth vector geometry, 3D lighting, text, ball, eye, red, purple, explosion cloud, extra particles, or watermark; do not use #00ff00 in the subject
```

### Surface overlay

- 파일: `overlays/selection_surface_overlay.png`
- 크기: 1672x941

```text
Use case: stylized-concept
Asset type: sparse game UI surface decoration overlay
Primary request: six to ten isolated crooked broad handmade scratch strokes and exactly two small chipped-paint marks for a cursed toy UI panel
Style/medium: flat illustrated texture overlay, rough paper-and-painted-wood cartoon style; restrained low-intensity marks with crisp irregular silhouettes
Composition/framing: wide horizontal layout; scratches concentrated near the outer edges and corners; the large central 55% must remain mostly empty for UI content
Color palette: muted #829B99 and ivory #F1E6CB at low visual intensity
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal
Constraints: no panel, text, symbols, grid, shadows, rust, blood, dense noise, repeated pattern, center clusters, or watermark; do not use #00ff00 in the subject
```
