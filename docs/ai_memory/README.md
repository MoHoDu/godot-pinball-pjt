# ai_memory — Claude 프로젝트 메모리 스냅샷

Cowork 세션의 **프로젝트 메모리**를 리포에 복사해 둔 것이다.
원본은 Claude 데스크톱 앱에 저장되므로 **다른 컴퓨터로 옮기면 따라오지 않는다.**
그래서 여기에 사본을 둔다.

## 쓰는 법

다른 컴퓨터에서 새 대화를 시작하면 이 폴더를 읽게 하면 된다.

> `docs/ai_memory/MEMORY.md` 부터 읽고 이어서 작업해줘

`MEMORY.md` 상단의 **"먼저 읽을 것"** 4개만 읽어도 작업 규칙과 현재 위치는 잡힌다.

## 주의

- **이건 스냅샷이다.** 이후 세션에서 메모리가 갱신되면 여기 사본은 낡는다.
- 새 컴퓨터에서 작업을 마칠 때는 **라이브 메모리와 이 폴더를 함께 갱신**해야 다음 컴퓨터로 따라간다.
- 스냅샷 시점: **2026-08-04** (유물 보상 시스템 구현 완료, 형락님 인게임 확인까지 끝남)

## 이 스냅샷에서 갱신된 것 (2026-08-04)

- 신규: `project_wave_reward_system.md`
- 갱신: `HANDOFF.md`(2026-08-04 세션으로 교체) · `MEMORY.md`(스냅샷 시점 + 웨이브·보상 절) ·
  `project_pinball_logue.md`(현재 진척 + 다음 할 일 + 결정 대기) ·
  `reference_godot_install_blocked.md`(다운로드 재개통) · `feedback_run_tests.md`(같은 내용 반영)

### 이전 스냅샷 (2026-08-03)

- 신규: `HANDOFF.md` · `feedback_staged_pipeline.md` · `reference_godot_install_blocked.md` ·
  `reference_test_scene_controls.md` · `project_ball_texture_fixed.md` · `project_vfx02_trail.md` ·
  `project_wall_final_resource.md` · `project_sfx01_ball_pilot.md`
- 갱신: `MEMORY.md`(구조 재편) · `project_pinball_logue.md`(현재 진척 + 다음 할 일 + 사운드 문서 2종 위치)

## ⚠ 같은 폴더를 두 세션이 동시에 갱신하지 말 것

2026-08-03 실제로 두 Cowork 세션이 동시에 이 폴더를 썼고, 나중 세션이 `MEMORY.md` 와
`project_pinball_logue.md` 를 덮어써서 앞 세션의 인덱스 항목을 잠깐 날렸다(복구함).
**여러 세션을 동시에 돌릴 거면 각자 다른 파일만 건드리게 하고, `MEMORY.md` 는 마지막에 한 번만 합친다.**
