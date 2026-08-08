# BGM 앰비언트 3겹 Firefly 프롬프트

생성 2026-08-08. 각 30초, 4변형. 채택 기준 = 전후반 RMS 차가 가장 작은
변형 (가장 정상적이라 루프에 유리).

| 파일 | 프롬프트 | 채택 | 전후반차 |
| --- | --- | --- | --- |
| `E1_clockwork.wav` | `An old clockwork mechanism ticking slowly and unevenly, quiet ambience` | 변형1 | 0.7dB |
| `E2_musicbox.wav` | `A creepy old music box playing slow sparse notes, distant and faint` | 변형2 | 0.2dB |
| `E3_drone.wav` | `A low dark humming drone, faint eerie room resonance` | 변형4 | 0.7dB |

혼합비: 오르골 -28dB(표정) > 태엽 -34dB(결) ≈ 드론 -33dB(바닥).
2초 등전력 크로스페이드로 28초 무이음 루프. 최종 RMS -33.5dB.

## 보스 루프 (2026-08-08)

| 파일 | 프롬프트 | 채택 |
| --- | --- | --- |
| `F1_heartbeat.wav` | `A slow heavy heartbeat thumping steadily, dark and muffled` | 변형1 (전후반차 0.1dB) |
| `F2_warpedbox.wav` | `A warped detuned music box playing slow twisted notes, unsettling` | 변형1 |
| `F3_rumble.wav` | `A deep ominous rumble slowly swelling and receding, tense` | 변형4 |

심장은 4변형 전부 30Hz 초저역이라 1.8배 + 새추레이션으로 70Hz 에 세웠다
(박동 80% 빨라짐 = 보스전 긴장감). 혼합: 박동 -27 > 오르골 -29 > 저역 -33dB.
14.7초 루프, 이음매 0.08%.

★ 함정: 길이 다른 겹은 **자른 뒤에** 루프를 만들어야 한다. 루프를 만들고
자르면 루프점이 사라져 이음매가 30% 점프했다.
