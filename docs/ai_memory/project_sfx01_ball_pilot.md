---
name: sfx01-ball-pilot
description: 공 SFX 파일럿(정속 태엽눈) — 3단계 파이프라인의 사운드판. AI 최소 0.5초 제약 때문에 어택은 반드시 절차적
type: project
---

# 공 SFX ① 형태 단계 — 정속 태엽눈 파일럿 (2026-08-03)

관련: [[board-step-pipeline]], [[ball-reward-variants]], [[vfx-ball-effects]], [[prompt-style-drift]]

착수 시점 저장소에 **오디오 파일 0개, `AudioStreamPlayer` 참조 0건.** 완전 그린필드였다.

## ★ AI 사운드 툴은 어택을 못 만든다 (2026-08-03 확정)

| | 문서 요구 | AI 현실 |
|---|---|---|
| 일반 충돌음 | 0.08~0.20초 (PDF 6-4) / 0.06~0.14초 (75쪽 11.1) | ElevenLabs `duration_seconds` **최소 0.5초** |

0.12초를 만들려고 0.5초를 뽑으면 75%를 버리는데 **어택이 어디 찍힐지 제어할 수 없다.**
게임 사운드는 어택 위치가 전부다.

**두 번째 이유가 더 결정적이다.** PDF 6-2가 "공 종류가 달라도 충돌 시점을 인지하는 기준은 유지한다"
= 5종이 **같은 어택 파형**을 공유해야 한다. AI로 5번 뽑으면 5개가 다 달라진다 —
Leonardo로 껍질 5종을 통째로 뽑으면 안 됐던 것과 **완전히 같은 구조의 함정**이다.

→ 아트와 같은 3단계: **①형태 = 절차적 / ②텍스처 = AI 재질음만 / ③디테일 = 정규화·실측**

## 툴 결정 (2026-08-03 조사)

- **ElevenLabs SFX, Starter $5/월** — 원샷 프롬프트 이해도가 가장 좋다. 48kHz, 요청당 4변형.
  **무료 플랜은 상업 이용 금지 + 출처 표기 의무**라 해커톤 출품작에는 못 쓴다.
- **Stable Audio 3 오픈웨이트는 탈락** — Community License가 **비상업 전용**, 상업은 별도 계약.
- Stable Audio: punchy 단발엔 과하고 부정확. AudioCraft: 품질 미달 + GPU 필요(컨테이너에 없음).
- 형락님 결정: **하이브리드 / 생성은 형락님이 직접(내가 프롬프트만) / 파일럿 1종 먼저.**

## 확정 수치 (파일럿)

| 파일 | 길이 | peak | 스펙트럼 중심 |
|---|---|---|---|
| 공통 어택 ×3 | 22.0ms | -10 dBFS | 3.4~3.9kHz |
| 태엽눈 일반 충돌 ×3 | **87.8 / 92.7 / 89.5ms** | -10 dBFS | 4.7~5.1kHz |
| 태엽눈 패링 ×1 | **266.9ms** | -1 dBFS | 2.5kHz |

- **패링 대비 충돌: peak -9.00dB / rms -9.29dB** (목표 -8~-10dB 충족)
- 피치 ±5%는 **파일에 굽지 않는다** → Godot `AudioStreamPlayer.pitch_scale` 런타임 처리
- 길이는 `trim_floor`(-60dBFS 컷)로 정하고 `gate`는 상한만 강제한다.
  게이트만 쓰면 파일 뒤가 무음으로 채워져 **길이가 실제보다 길게 보고된다** (1차 시안 132ms → 실제 88ms)

## 1차 시안에서 실측으로 잡은 것 2개

1. **유효 길이가 규격 하한 밑이었다** — 모달 tau가 짧아 실제 55ms. 규격 0.06초 미달.
   → clockwork/glass tau를 약 1.4배로 올려 88~93ms.
2. **패링 스펙트럼 중심 1939Hz** — 저역 원형 파동이 "밝은 유리 팅 + 짧은 종"을 먹었다.
   → ring 게인 0.40 → **0.26**, material 0.78 → 0.98. 2476Hz.

**패링(2.5kHz)이 충돌(4.7~5.1kHz)보다 어둡다.** 종 기본음이 1.2/2.4kHz라 당연한 결과다.
결함으로 보고 고치지 않았다 — 구분 자체는 길이(88ms vs 267ms)와 음색으로 명확하다. 판단은 형락님 몫.

## 미해결

- **`AudioController` 노드가 없다.** 문서 12-3은 `BallVisual > … + AudioController`인데
  `base_ball.tscn`은 아직 Sprite2D + _Trail 뿐. 꼬리 VFX처럼 별도 노드 + `.tres` 규칙으로 신설해야 한다.
- **엔진 테스트 불가.** github.com 403 → 재생·믹스 확인은 형락님 로컬에서.
- 총 예상 산출 ≈ 25개 WAV (공통 어택 3 + 공별 재질음 5×3 + 패링 공통 2 + 공별 패링 악센트 5).

## 산출물

> ★ **2026-08-06 형락님 지시로 이 산출물은 전부 삭제됐다.** 아래 목록은 이력이다.
> `docs/sfx/build_sfx.py` 를 돌리면 바이트 단위로 같은 파일이 복원된다.
> 삭제 범위와 다시 만들 때 알아야 할 것은 [[sound-spec]] §9 참고.

폴더는 대상별로 나뉘어 있다. 위치는 `docs/sfx/` 다 (`ball_guides` 아래가 아니다 —
벽·플리퍼 소리가 들어오면서 이름이 안 맞게 됐다). 전체 구조는 `docs/sfx/README.md` 참고.

```
docs/sfx/
  build_sfx.py                              ① 절차적 합성 (재현 스크립트)
  make_review.py                            ③ 실측 + 오디션 + 시트
  ball/SFX_Ball_Common_Attack_01..03.wav    5종 공유
  ball/SFX_Ball_Clockwork_Hit_01..03.wav
  ball/SFX_Ball_Clockwork_Parry_01.wav
  audition/SFX_Clockwork_audition.mp3       A어택 B충돌 C8연타 D패링 E실전리듬
  layers/ball/                              레이어 분해본. ②단계에서 재질만 갈아끼운다
  prompts/sfx_elevenlabs_prompts.md         ② 텍스처 단계 프롬프트 3종 + 금지 단어
  prompts/sfx_pilot_clockwork_sheet.png
  raw/                                      ← ElevenLabs 원본 받을 자리 (형락님이 생성)
```

## 프롬프트 금지 단어 (화풍 이탈 규칙의 사운드판)

`metal clang` / `machinery` / `industrial` / `heavy` / `steel` / `hammer` / `factory` /
`gear grinding` / `echo` / `hall` / `cinematic` / `impact boom`
→ 전부 폐기된 구 컨셉(산업 호러)으로 모델을 끌어당긴다. PDF 6-1이 직접 금지한다.
