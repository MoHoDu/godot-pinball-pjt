# CLAUDE.md

Pinball_Logue (Godot 4.7, GL Compatibility 렌더러) 작업 규칙.
AI 어시스턴트는 세션 시작 시 이 파일을 먼저 읽고, 이어서 `docs/ai_memory/MEMORY.md` → `docs/ai_memory/HANDOFF.md` → `docs/ai_memory/reference_codebase_conventions.md` 순으로 읽는다.

## 작업 규칙

1. **머지 전 충돌 선점검**
   push 전에 `origin/main`과 작업 브랜치를 비교해 충돌 가능 지점을 먼저 찾아낸다.
   찾은 지점을 수정하고, 끊어진 참조가 없는지 검증한 뒤에 push한다.
   충돌 해결 시 **최신 파일의 기준은 항상 `main`**이다. 작업 브랜치가 main의 변경을 되돌리는 방향으로 해결하지 않는다.

2. **씬은 복제해서 작업**
   기존 씬을 직접 수정하지 않는다. 테스트가 필요하면 복제한 새 씬에서 작업한다.

3. **스크립트는 상속해서 확장**
   기존 스크립트를 수정하지 않는다. 기능 추가가 필요하면 해당 스크립트를 `extends`한 별개의 새 스크립트를 만든다.

4. **커밋은 잘게 나눈다**
   나중에 머지할 때 편하도록 논리 단위로 분리해 커밋한다.
   커밋 시점은 **중요한 내용 또는 핵심 동작이 바뀔 때**다. 중간 저장용 커밋은 만들지 않는다.

5. **커밋 전 반드시 확인받는다**
   커밋·push 전에는 항상 사용자에게 무엇을 어느 브랜치에 커밋할지 알리고 승인을 받는다.

## 저장소 구조

| 경로 | 용도 |
| --- | --- |
| `scripts/<시스템>/` | 게임 로직 |
| `Resources/<시스템>/` | 씬·아트 (대문자 R 주의) |
| `settings/<시스템>/` | `.tres` 설정 리소스 |
| `scenes/<시스템>/` | 씬 파일 |
| `tests/<시스템>/` | 헤드리스 SceneTree 테스트 |
| `docs/ai_memory/` | AI 인계 문서 |

시스템: `ball_base_system`, `flipper_system`(패링 포함), `combo_system`, `coin_system`, `reward_system`, `reward_shop`, `bumper-system`, `repair_parts`, `wave_hud`

`scripts/bumper-system/`과 `scripts/repair_parts/`에는 별도 `AGENTS.md`가 있으니 해당 시스템을 건드릴 때 함께 읽는다.

메인 씬: `scenes/wave/wave.tscn`

## 워크트리

브랜치별로 워크트리를 나눠 병행 작업한다. 이 파일은 git으로 공유되므로 모든 워크트리에 동일하게 적용된다.

| 폴더 | 브랜치 |
| --- | --- |
| `godot-pinball-pjt` | `resource/art` |
| `pinball-bumper` | `dev/bumper_reapair` |
| `pinball-sound` | `resource/Sound` |

- 같은 브랜치를 두 워크트리에서 동시에 체크아웃할 수 없다.
- `git fetch`는 한 번이면 전체에 반영되지만, 머지는 워크트리마다 따로 실행한다.
- `.godot/` 캐시는 워크트리마다 새로 생성된다(`.gitignore` 처리됨). 새 폴더를 처음 열면 전체 리임포트가 한 번 돈다.

## Godot 주의사항

- **GL Compatibility 렌더러**라 `GPUParticles` 트레일 등이 동작하지 않는다. VFX는 `Line2D`나 셰이더로 구현한다.
- `.tres`/`.tscn`의 `uid://`는 브랜치마다 새로 발급되어 **UID 한 줄만 다른 충돌**이 자주 난다. 이 경우 main 쪽 UID를 채택하고, 그 UID를 참조하던 다른 파일(`ext_resource`)도 함께 갱신해야 참조가 끊기지 않는다.
- 경로 대소문자 문제는 `docs/ai_memory/reference_path_case_issue.md` 참고.
