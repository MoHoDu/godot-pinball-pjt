# 범퍼 소재 Firefly 프롬프트

재생성 2026-08-07. 1초, 4변형.

| 파일 | 프롬프트 | 채택 |
| --- | --- | --- |
| `C1_button.wav` | `Two quick plastic ticks, dry and crisp` | 변형4 |
| `C2_cotton.wav` | `A pillow landing on a bed, one puffy thump` | 변형1 |
| `C4_drum.wav` | `A bass drum kick, one deep booming thump` | 변형3 |
| `C6_fire.wav` | `A cannon firing once, sharp cracking bang` | 변형3 |

## 프롬프트에서 배운 것

**부드러운 재질을 말하면 Firefly 는 가청대역을 비운다.** 쿠션 4변형 중 셋이
150Hz 아래에 79~97% 를 쏟았다. `soft` `muffled` 를 안 쓰고 `fabric compressing`
으로 우회했는데도 그랬다. 여섯 번째 같은 결과다.

반대로 **팽팽함·밝음을 명시하면 대역에 들어온다.** 북은 `taut` `bright ringing`
을 넣자 4변형 전부 150Hz 아래 0% 로 나왔다. 직전 `A small toy drum` 은 203Hz 에
저역 99% 였다.

대포는 `cannon` `explosion` 을 피하고 **다른 물체(종이봉투)** 로 우회했다.
터지는 결은 얻었지만 무게가 없어서, 기존 `C6_fire.wav` 를 저역 레이어로 겹친다.

## 2차 재생성 (2026-08-07 저녁)

형락님 지시로 셋을 갈았다 — 장난감 북 → **악기 북**, 쿠션 주먹질 → **일반 솜**,
종이봉투 → **진짜 대포**.

배운 것: **진짜 푹신한 소리·대포 소리는 원래 초저역이다.** 베개 4변형 중심이
6~17Hz, 대포도 75~190Hz 였다. 이건 Firefly 의 함정이 아니라 물리라서, 이번엔
소재를 버리지 않고 100Hz 하이패스로 초저역만 걷어냈다 — 그 밑에 깔려 있던
진짜 결이 가청대역에 남는다.

## 3차 재생성 (2026-08-07 밤)

북을 톰 → **베이스 드럼**으로, 대포는 하이패스를 100 → 40Hz 로 내렸다.
킥 4변형 전부 중심 41~46Hz 라 1.5배 + 새추레이션으로 60~150Hz 에 앉혔다.
재질 검사 바닥도 150 → 60Hz 로 내렸다 — 저역 자체가 재질인 소리가 있다.

## 솜 부스럭 레이어 추가 (2026-08-07 밤)

"솜은 저렇게 둔탁한 소리를 내지 않는다"는 지적. 베개 몸통 위에
`A fluffy cotton ball squeezed softly, airy gentle rustle` (변형4, `C2_rustle.wav`)
를 3.5kHz 로 눌러 0.45 로 얹었다. 떨어지는 퍽 → 쥐어지는 푸슥.
