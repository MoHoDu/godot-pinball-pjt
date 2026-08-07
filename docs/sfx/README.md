# SFX 작업 폴더

절차적 합성으로 만드는 게임 사운드의 **재현 스크립트**가 있는 곳이다.

> ## ★ 2026-08-06 현재 오디오 파일이 하나도 없다
>
> 형락님 지시로 그때까지 만든 SFX를 **전부 지웠다.** 게임 쪽 연결(SFX 버스,
> `BallAudioRules`, `BallAudioController`, 오디오 테스트, 검수 씬)도 함께 되돌렸다.
> 저장소에 오디오 파일과 `AudioStreamPlayer` 참조가 0개인 상태로 돌아갔다.
>
> **아래 스크립트를 돌리면 지워진 파일이 그대로 복원된다.** 시드가 고정돼 있어
> 바이트 단위로 같은 결과가 나온다. 지운 것은 산출물이지 만드는 방법이 아니다.
>
> 규격 조사와 판단 근거는 남아 있다 → [사운드 규격 전문](../ai_memory/reference_sound_spec.md)

> 2026-08-06 `docs/ball_guides/sfx/` 에서 옮겨왔다.
> 벽·플리퍼 소리가 들어오면서 "ball_guides 아래"라는 위치가 맞지 않게 됐다.

규격은 [사운드 규격 전문](../ai_memory/reference_sound_spec.md)에 정리돼 있다.
파일럿의 배경과 결정 이력은 [공 SFX 파일럿](../ai_memory/project_sfx01_ball_pilot.md).

## 구조

스크립트를 돌리면 아래 폴더가 다시 생긴다.

| 폴더 | 내용 | 만드는 스크립트 |
| --- | --- | --- |
| `ball/` | 공 SFX. 공통 어택 3 + 정속 태엽눈 충돌 3 + 패링 1 | `build_sfx.py` |
| `wall/` | 벽 충돌 SFX 3종 — **저·중·고속 대응** (가이드 p.73 MUST) | `build_wall_sfx.py` |
| `flipper/` | 플리퍼 SFX 5종 — 선택·작동·타격·강타격·복귀 | `build_flipper_sfx.py` |
| `audition/` | 검수용 오디션. 게임이 하는 처리(피치 랜덤·연타 감쇠·속도별 음량)를 걸어 리듬 위에 얹은 것 | 위 셋 |
| `layers/<대상>/` | 레이어 분해본. ② 텍스처 단계에서 재질 레이어만 갈아끼울 때 쓴다 | 위 셋 |
| `prompts/` | ElevenLabs 프롬프트와 검수 시트 | (수기) |
| `raw/<그룹>/` | AI 생성물. **역할별 폴더**로 나뉜다 (아래) | `generate_elevenlabs.py` |

## AI 생성물 폴더 — 무엇을 재생해야 하는가

한 폴더에 수십 개를 평평하게 쌓으면 **뭘 들어야 할지 알 수 없다.**
그래서 `raw/<그룹>/` 아래를 **역할마다 폴더 하나**로 나눈다.

```
raw/flipper/
  1_select/     flipper_select_01.wav   ← ★ 이걸 재생하면 된다
                _source/                ← 생성 원본. 길이를 바꿔 다시 자를 때만
  2_activate/
  3_hit/
  ...
  README.md     ← 역할별로 뭐가 남았고 뭐가 왜 반려됐는지
```

- 폴더 앞 숫자는 **오디션 순서**다. 위에서부터 재생하면 게임에서 소리가 나는 차례가 된다
- **반려본은 지운다.** 남아 있으면 헷갈린다. 사유는 그룹 `README.md` 에 남는다
- 구조의 기준은 `sfx_layout.py` 한 곳이다. 생성·추출·필터·정리가 전부 여기를 본다

```bash
python generate_elevenlabs.py flipper --variants 6   # 생성 → _source/
python extract_material.py flipper --length 200      # 첫 타격만 추출 → 역할 폴더
python filter_candidates.py flipper                  # 판정만 (안 지운다)
python organize_takes.py flipper --dry-run           # 지울 목록 확인
python organize_takes.py flipper                     # 반려본 삭제 + README
```

★ **무음 판정은 `_source/` 원본으로 해야 한다.** 추출본은 전부 -10dBFS 로
정규화되므로 원본이 -38dB 짜리여도 겉보기엔 멀쩡하다. 실제로 이 함정에
`flipper_parry_05` 가 걸렸다.

## 재현

```bash
python build_sfx.py          # ball/     + layers/ball/
python build_wall_sfx.py     # wall/     + layers/wall/     + audition/
python build_flipper_sfx.py  # flipper/  + layers/flipper/  + audition/
python make_review.py        # audition/ + prompts/ (실측 시트)
```

`numpy` 와 `scipy` 가 필요하다. 시드가 고정돼 있어 **몇 번을 돌려도 바이트 단위로 같은 파일**이 나온다.
돌렸는데 git diff 가 생기면 그건 재현이 깨진 것이니 원인을 찾아야 한다.

`build_wall_sfx.py` 와 `build_flipper_sfx.py` 는 `build_sfx.py` 를 import 해서
공통 도구(어택·유리·잔향·게이트·정규화)를 재사용한다. **세 스크립트는 같은 폴더에 있어야 한다.**

## 지켜야 하는 것

- **어택·길이·레이어 밸런스는 절차적으로 확정한다.** AI 생성물에 맡기지 않는다
  (ElevenLabs 최소 길이가 0.5초라 어택 위치를 제어할 수 없다)
- **피치 ±5% 랜덤은 파일에 굽지 않는다.** 런타임 `AudioStreamPlayer.pitch_scale` 로 처리한다
- 음량 차이도 파일에 굽지 않는다. 속도→음량은 `BallAudioRules` 가 런타임에 건다.
  단 **패링 대비 충돌 -8~-10dB 는 파일에 구워져 있다** (피크 -1dBFS vs -10dBFS)
- 각 스크립트 끝에 **규격 자가 검증**이 있다. 여기서 걸리면 게임에 넣지 않는다

## 게임 리소스와의 관계

**현재 `Resources/sfx/` 는 없다.** 2026-08-06 삭제와 함께 지워졌다.

다시 붙일 때는 여기서 만든 WAV 중 게임에 쓰는 것만 `Resources/sfx/<대상>/` 로 복사하고,
**무손실 PCM(`compress/mode=0`)으로 임포트**한다. 기본값인 QOA 는 손실 압축이라
어택 트랜지언트와 피크 관계가 흔들린다.

게임 쪽 재생 규칙(동시 4개·간격 0.04초·피치 ±5%·연타 -3dB 등)을 다시 만들 때
참고할 것들은 [사운드 규격 전문](../ai_memory/reference_sound_spec.md) §1·§7 에 남아 있다.
