# 수리 부품 아트 후보 전량

부품별 후보 4장씩. 채택본은 `../final/` 에 있다.

| 폴더 | 내용 |
| --- | --- |
| `unmasked/<이름>/` | Leonardo 원본 JPG 4장 |
| `masked/<이름>/` | 위를 배경 제거 + 알파 bbox 정규화한 PNG |
| `review_sheet.png` | 보드 위 표시 88px 대조 |

재생성:

```
python docs/bumper_guides/cutout_and_finalize.py --root docs/repair_part_guides
python docs/bumper_guides/make_cutout_review_sheet.py --repair
```

## 초승달 바늘 폴더가 없는 이유

가이드 14쪽에 **"초승달 바늘은 개발 취소됨, 구현하지 말것"** 이 명시돼 있다.
그 아래로 규격이 그대로 남아 있어 놓치기 쉽다. 아트를 만들지 않았다.

단 **코드에는 구현돼 있다** (`repair_needle_effect.gd`, `CrescentNeedle.tres`,
`crescent_needle_part.tscn`). 기획서와 코드가 어긋난 상태이며 PL 확인이 필요하다.

## 살릴 수 없는 2장

별방울 후보 중 둘은 배경 제거가 안 된다. 하나는 그림 안에 회색 액자가 그려져 있고,
다른 하나는 배경의 빨간 별이 방울 외곽선에 닿아 같은 덩어리로 판정된다.
둘 다 채택 후보가 아니라 재생성하지 않았다.
