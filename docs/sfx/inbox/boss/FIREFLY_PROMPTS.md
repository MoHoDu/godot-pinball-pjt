# 보스(눈 잃은 테디베어) Firefly 프롬프트

생성 2026-08-07 밤. 단발 1초 · 장면 3초, 각 4변형 (총 32개).
근거: 보스 기획서 11장 + 비주얼·사운드 가이드 13~16장.

| 파일 | 프롬프트 | 채택 |
| --- | --- | --- |
| `E1_telegraph.wav` | `A thick rope stretching and creaking, taut fibers straining` | 변형3 |
| `E2_swing.wav` | `A heavy cloth sack swung fast then thudding, fabric whoosh and hollow thump` | 변형2 |
| `E3_hit.wav` | `A plush toy punched hard, bouncy deep thump` | 변형3 |
| `E4_spawn.wav` | `A thread unspooling fast then a soft cotton plop` | 변형3 |
| `E5_blink.wav` | `A short eerie glassy shimmer, dark magical blink` | 변형4 |
| `E6_roar.wav` | `A warped music box groaning low and slow, long cloth tearing breath` | 변형3 |
| `E7_defeat.wav` | `Seams ripping open one after another, threads popping and soft wind` | 변형1 |
| `E8_heart.wav` | `A slow muffled heartbeat with faint irregular clockwork ticking` | 변형2 |

## 레이어 재사용

가이드가 정의한 레이어 구조는 빌드에서 기존 소재를 겹쳐 완성했다.
- 처치 = E7 봉제선 + `A4_glass`(유리 공명, 1.6s) + `D1_rise` 0.75배(오르골 종, 2.1s)
- 솜 생성 = E4 푹 + `C2_rustle`(솜 부스럭)
- 포효는 한 프롬프트로 두 레이어(오르골+숨)가 다 들어왔다 — 악기가 절반이면 수율이 좋다.
