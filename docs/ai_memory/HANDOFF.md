# 인계 메모 — 2026-08-04 (2차: 브랜치 병합. VFX ③ 는 이미 구현돼 있다)

> 다른 컴퓨터에서 이어받는 Claude에게. `MEMORY.md` 를 읽기 전에 이걸 먼저 봐도 된다.
> 해커톤 마감 **2026-08-10**. 작업 브랜치 **`resource_ball_VFX`** (워크트리 `.worktrees\ball-vfx`).
> 문서 곳곳의 `VFX/Test` 표기는 옛 것이다.

---

## 0. 시작할 때 지켜야 할 것

1. **승인 없이 산출물을 만들지 않는다.** 계획 → 승인 → 실행 → [[workflow-rules]]
   (조사·문서 읽기·현황 파악은 바로 해도 된다)
2. **코드를 짰으면 반드시 돌려본다.** 컨테이너 Godot 다운로드는 **세션마다 갈린다** —
   08-04 오전엔 받아졌고 같은 날 오후엔 다시 막혔다. 1분 안에 확인하고 안 되면
   대체 검증으로 넘어간다 → [[godot-install-blocked]]
3. **기존 스크립트는 고치지 않는다.** 기능을 붙일 때는 상속하거나 시그널만 구독하는 별도 노드를 만든다
4. **씬에서 테스트할 때는 기존 씬을 복제한 새 씬**에서 한다
5. **모든 아트는 형태 → 텍스처 → 디테일 3단계.** 단계마다 검수 → [[staged-art-pipeline]]
6. **실루엣은 AI에게 맡기지 않는다.** 생성물에서 색·표면만 가져오고 형태는 좌표로 확정한다

---

## 1. 이번 세션(2026-08-04)에서 한 일

### ★ 브랜치 병합 — 두 브랜치가 한 기능의 반쪽씩이었다

`VFX/ball_bump_effect` 를 `resource_ball_VFX` 로 병합했다(`d3adfce`). **겹치는 파일 0개, 충돌 0건.**

병합 전 상태가 문제였다. `VFX/ball_bump_effect` 의 `pinball.gd` 는
`@export var vfx_profile: BallVfxProfile` 을 쓰는데 그 `class_name` 정의는
`resource_ball_VFX` 에만 있었다. **어느 쪽도 단독으로는 파싱이 안 됐다.**

| | 병합 전 `resource_ball_VFX` | 병합 전 `VFX/ball_bump_effect` |
|---|---|---|
| `BallVfxProfile` 정의 + 5종 `.tres` | 있음 | 없음 |
| `pinball.gd` 의 `vfx_profile` 사용 | 없음 | 있음 |
| VFX ③ 패링 파동 | 없음 | 있음 |

**교훈: 리소스 정의와 그걸 쓰는 export 를 다른 브랜치에 나눠 두면 양쪽 다 죽는다.**
`class_name` 을 새로 만들면 그걸 참조하는 코드와 같은 브랜치에 있는지부터 본다.

검증한 것: `gdparse` 113개 통과 / 병합된 씬·리소스의 `res://` 참조 71건 실재·대소문자 일치.
엔진 런타임은 이 세션에서 Godot 을 못 받아 미실행.

### 유물 보상 시스템 — 구현 완료
웨이브 승리 → 수리 부품 3장 중 1장 선택 → 다음 웨이브에 효과 적용.
**신규 파일 23개, 기존 스크립트 수정 0건.** 상세 [[wave-reward-system]]

실행 씬은 `scenes/wave/wave_reward.tscn` (기존 `wave.tscn` 복제본, script 줄만 다름).
개발용 **`G` 키로 웨이브 즉시 클리어**가 된다.

기억할 것 세 가지. 전부 **기존 코드를 읽어야만 보이는** 종류다:

1. **점수 효과를 `stage_base_score` 에 걸면 안 된다** — `ComboWaveController._apply_stage_base_score()`
   가 웨이브마다 덮어쓴다. ComboRules의 단계별 점수 배율을 건드려야 살아남는다
2. **패링 창은 normal을 먼저 늘려야 한다** — setter가 perfect를 normal 이하로 clamp해서
   순서를 바꾸면 증가분이 조용히 잘린다
3. **공 추가 상한은 5개** — `WaveRuntimeCoordinator._configure_lives_from_inventory()` 가
   라이프 슬롯을 3~5개로 assert한다

효과는 전부 `RelicRuntime` 을 거쳐 **기준값 × 배율**로 다시 계산하고, 씬이 해제될 때 복원한다.
공유 `.tres` 를 직접 누적하면 에디터에서 플레이를 반복할 때 값이 계속 부풀어 오른다.

### ★ 컨테이너에서 엔진 검증이 다시 가능해졌다
`release-assets.githubusercontent.com` 이 열려서 Godot 4.7.1을 받아 **헤드리스 테스트와
스크린샷 검증까지** 돌렸다. 방법은 [[godot-install-blocked]] 에 정리했다.
핵심은 **프로젝트를 통째로 스테이징하지 않는다**는 것 — 코드·씬·설정만 옮기고
참조된 이미지 경로에 자리표시자 PNG를 생성한 뒤 `--import` 한다.

---

## 2. ★ 다음 사람이 밟기 쉬운 지뢰 4개

### ① 새 `class_name` 은 `--import` 를 한 번 더 돌려야 인식된다
스크립트를 새로 추가하면 `.godot/global_script_class_cache.cfg` 에 등록되기 전까지
`Identifier "X" not declared in the current scope` 파스 에러가 난다. **코드 문제가 아니다.**

### ② 꼬리 리본 PNG를 씬에 물리지 말 것
`Resources/Art/vfx/balls/Trail_*.png` · `TrailFast_*.png` 는 **컨셉 참고물이다.**
이동 꼬리는 이미 셰이더로 구현돼 있고(`Resources/shaders/ball_trail.gdshader`),
색을 uniform 5개로 받는다. 아트 슬롯이 없다.
→ 공별 꼬리는 `settings/balls/trail/BallTrailRules_{공}.tres` 로 연결한다.

### ③ 새 공 텍스처는 채움률부터 본다
`refresh_ball_size()` 가 **텍스처 긴 변**으로 나눈다. 캔버스에 여백이 있으면 그만큼 작게 그려지고
충돌 크기와 어긋난다. → **알파 bbox == 캔버스 크기**를 먼저 확인할 것. → [[ball-texture-fixed]]

### ④ 수치가 기준을 벗어났다고 결함이 아니다
검수 수치를 "문제"로 보고했는데 형락님이 **전부 의도한 것**이라고 한 적이 있다.
수치는 그대로 보고하되 "고쳐야 한다"가 아니라 **"이런 상태다"** 로 제시하고 판단을 넘긴다.

---

## 3. 지금 걸려 있는 것

### 아직 안 돌린 엔진 테스트 (아트 계열)
컨테이너에서 엔진은 돌릴 수 있게 됐지만, 아래는 **실제 텍스처가 있어야 의미가 있다.**
자리표시자로는 통과해도 검증이 안 된다. 실제 아트를 스테이징하거나 로컬에서 돌린다.

```
godot --headless --path . --import
godot --headless --path . --script res://tests/ball_base_system/pinball_size_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_gaze_visual_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_glow_outline_test.gd
godot --headless --path . --script res://tests/ball_base_system/ball_trail_test.gd
godot --headless --path . --script res://tests/ball_base_system/test_ball_physics_scene_test.gd
```

**엔진에서만 확인되는 것 2건:**

- `ball_trail.gdshader` 는 Line2D 의 `UV.x = 0` 이 **공 쪽**이라고 가정한다.
  뒤집혀 있으면 셰이더에서 `t = 1.0 - UV.x` 한 줄로 끝난다
- 꼬리가 여러 개 겹칠 때 어느 게 어느 공 건지 갈리는지

### 결정 대기 — 유물 효과 수치
지금 값(점수 +25% / 발사 속력 +10% / 패링 창 +35% / 공 +1)은 **이번 구현에서 임시로 정한 것**이다.
컨셉 기획서에 수치가 없다. `settings/reward/relics/*.tres` 에서 숫자만 바꾸면 된다.

### 결정 대기 — 보상 공 5종을 어느 씬에 붙일지
코드는 `elastic_var`(dead/rubber/super) + `mass_var`(heavy/light/normal) **6종**인데
문서는 **5종**이고 이름·성격이 다르다.
고무막=rubber / 완충 젤=dead / 납심=heavy / 속빈 방울=light 까지는 보이지만
**정속 태엽눈은 대응이 없고 `super_ball`·`normal_ball` 이 남는다.** PL·형락님 확인이 필요하다.

### VFX ③ 패링 원형 파동 — 구현 완료. 남은 건 "공별로 갈리게" 하는 것

**미착수가 아니다.** `scripts/ball_base_system/vfx/ball_parry_wave.gd` (852줄)에
셰이더까지 전부 들어 있다. 씬 아무 데나 붙인 Node2D 하나가 `parry_resolved` 를 자동으로
찾아 **PERFECT 만** 받는다. 확정값·결정 이력은 그 파일 **헤더 주석에 전부 적혀 있다.**

- 시작 27px → 종료 90px / 지속 **0.42초** / 링 **12px** / 플래시 0.06초 / 밴드 5단 / 중심 이동 없음(안 A)
- 지속·링 두께는 가이드(0.12~0.20 / 4~8)를 **가시성 개정 2차로 의도적으로 넘긴 값**이다.
  잘 보이는 구간이 5.9 → 12.3 → 22.3프레임(60fps)이 됐다
- **종료 반지름을 줄인 게 핵심이었다.** 같은 잉크를 좁은 둘레에 모아야 선이 굵게 읽힌다.
  크게 만드는 것과 잘 보이는 것은 반대 방향이었다
- 공의 자식이 아니다. 패링 직후 공이 1000px/s 이상으로 날아가 파동이 끌려가면
  "그 자리에서 터졌다"로 안 읽힌다. 덕분에 `base_ball.tscn` 과 변종 6종을 안 건드렸다
- 검수 씬 `scenes/test_flipper/test_flipper_board_parry.tscn`

**남은 연결 3가지** (전부 "이런 상태다"이지 결함이 아니다):

1. `BallVfxProfile.parry_ring` 슬롯을 **아무도 안 읽는다.** 파동이 공별로 갈리지 않는다.
   텍스처 5종 `Resources/Art/vfx/balls/ParryRing_*.png` 도 아직 미사용
2. `ball_parry_wave_rules.gd` (508줄) + `settings/balls/BallParryWaveRules.tres` 는
   **참조하는 코드가 0건**이다. 파동이 파일 하나로 합쳐지면서 남은 것이고,
   담긴 값도 **가시성 개정 1차**(0.26s / 9px / 95px)라 최종본(0.42s / 12px / 90px)과 다르다.
   지우든 되살리든 결정이 필요하다 — 그냥 두면 다음 사람이 옛 수치를 읽는다
3. `ball_parry_wave.gd` · `ball_parry_wave_rules.gd` 에 `.uid` 가 없다.
   로컬에서 열면 Godot 이 만들어 untracked 로 뜬다

### 미착수
- **보상 공 5종 씬 (1b)** — `Ball_{공}_Body.png` / `_Pupil.png` 가 분리돼 있어 문서 12-3 노드 구조가 필요하다.
  병합으로 `pinball.gd` 의 `refresh_profile_art()` 가 같은 브랜치에 왔으므로 이제 이어서 할 수 있다
- **유물 카드 아트** — 지금은 도형 + 텍스트 임시 UI다 → [[wave-reward-system]]
- **공 SFX** — 파일럿(정속 태엽눈)만. 2026-08-03 형락님 지시로 **보류** → [[sfx01-ball-pilot]]
- 노드 구조 변경 (문서 12-3): `BallVisual > BodySprite + PupilSprite + Outline + Trail +
  IdentityParticles + ParryVFX + AudioController`. 현재 `base_ball.tscn` 은 Sprite2D 하나
- 삼각형 보드 / 범퍼·코인·보스
- **경로 대소문자 17곳** — Linux/macOS 익스포트 시 전부 깨진다. 아직 승인 안 받음 → [[path-case-issue]]

### 정리 가능
`Resources/Art/balls/` 의 `ball.png` · `cats_eye_ball.png` · `industrial_steel_ball.png` —
코드·씬 참조 **0건**.

---

## 4. 원본 기획 문서

- 수리 부품(유물) 컨셉: `핀볼_수리부품_컨셉_기획서_강보현.pdf` — 부품 4종의 컨셉만, 수치 없음
- 보상 공 5종 전용: `핀볼_PL_비주얼_사운드방향성가이드_강보현 (6).pdf` (33쪽)
- 비주얼·사운드 가이드 / 플리퍼 시스템 기획서 / 컨셉기획서: `docs/source_materials/pdfs/`
- Leonardo 모델별 세팅: `docs/LEONARDO_AI_MODEL_HANDOFF.md`

## 5. 아트 산출물 위치

```
Resources/Art/balls/glass_eye_ball.png          기본 공 확정본
Resources/Art/balls/variants/                   보상 공 5종 본체·동공
Resources/Art/vfx/balls/                        공 VFX 텍스처 (Trail_* 은 참고물)
settings/balls/glow/                            발광 테두리 프리셋 5종
settings/balls/trail/                           이동 꼬리 프리셋 5종
settings/reward/                                유물 정의 4종 + 후보 풀
docs/ball_guides/v6_master/                     기본 공 마스터·STEP2 가이드
docs/ball_guides/v7_final/                      마스킹 결과·검수 시트
docs/ball_guides/variants/                      보상 공 README·카드·재현 스크립트·검수 시트
```

재현 스크립트가 전부 남아 있으므로 **색·수치만 바꿔 다시 뽑을 수 있다.**
