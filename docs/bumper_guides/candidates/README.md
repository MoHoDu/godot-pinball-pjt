# 범퍼 아트 후보 전량

Leonardo(Nano Banana 2)로 뽑은 후보를 전부 둔다. 종별 채택본은 `../final/` 에 있다.

| 폴더 | 내용 |
| --- | --- |
| `unmasked/<이름>/` | Leonardo 원본 JPG 4장 |
| `masked/<이름>/` | 위를 배경 제거 + 알파 bbox 정규화한 PNG |
| `review_sheet.png` | 확정 보드 위에 실제 표시 지름으로 올린 인게임 크기 대조 |

재생성:

```
python docs/bumper_guides/cutout_and_finalize.py          # unmasked -> masked
python docs/bumper_guides/make_cutout_review_sheet.py     # review_sheet.png
```

## 폴더 이름의 `_r2` `_r3`

재생성 회차다. 1차는 화풍 지시가 프롬프트 뒤쪽에 묻혀 전부 반려됐고 보관하지 않았다.
용수철 인형만 회차가 둘이다.

- `spring_doll_r2` — 아이보리 얼굴이 화면의 90%를 먹어 주·보조색이 뒤집힌 버전
- `spring_doll_r3` — 기획서 5-3절대로 붉은 갈색 받침 + 금색 스프링을 주색으로 되돌린 버전

## 후처리가 실패한 2장

배경 제거는 테두리에서 flood fill 한 뒤 화면 중앙과 연결된 덩어리만 남기는 방식이다.
아래 둘은 이 방식으로 살릴 수 없다. 둘 다 채택 후보가 아니다.

- 그림 안에 액자 테두리가 그려진 경우 — 테두리에서 액자 안쪽으로 도달할 수 없다
- 배경 장식이 오브젝트 외곽선에 닿은 경우 — 같은 덩어리로 판정된다

안쪽으로 씨앗을 넣어 뚫는 방법은 오브젝트 내부의 큰 단색 면을 삼켜 폐기했다.
