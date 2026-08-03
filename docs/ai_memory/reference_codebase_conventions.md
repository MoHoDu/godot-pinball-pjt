---
name: codebase-conventions
description: godot-pinball-pjt 코드·폴더·테스트 컨벤션 — 새 시스템을 추가할 때 따라야 할 형식
type: reference
---

# godot-pinball-pjt 컨벤션

Godot 4.7 / **GL Compatibility 렌더러** (`renderer/rendering_method="gl_compatibility"`).
Compatibility 제약: GPUParticles 트레일·파티클 충돌·어트랙터 미지원. VFX는 Line2D/셰이더 위주로 설계할 것.

## 폴더 분리
- `scripts/<시스템>/` — 로직. 하위에 기능별 폴더 (`flipper_system/parrying/`, `ball_base_system/vfx/`)
- `Resources/<시스템>/` — 씬(.tscn)과 아트. **코드 안 경로도 대문자 `res://Resources/...` 로 쓸 것** → [[path-case-issue]]
- `settings/<시스템>/` — 규칙 `.tres`
- `tests/<시스템>/` — 테스트

## 코드 스타일
- `@tool` + `class_name`, **탭 들여쓰기**, 한글 `##` 독스트링
- `@export_range(min, max, step, "suffix:px")` + setter 안에서 `clampf`로 강제 보정
- 상수는 `MIN_/MAX_/DEFAULT_` 접두어로 스크립트 상단에 모음
- **규칙은 별도 `Resource`로 분리**해 `.tres`로 저장 (`PinballPhysicsRules`, `FlipperParryRules`, `BallGazeRules`, `BallGlowOutlineRules`)
- `_get_configuration_warnings()`로 에디터에서 설정 오류를 잡아줌
- 여러 줄 조건은 백슬래시 말고 **괄호**로 감싼다 (`pinball.gd` 방식)

### GDScript 함정 (실측)
- `const X: PackedFloat32Array = PackedFloat32Array([...])` — 생성자는 상수 표현식이 아님. 배열 리터럴로
- 타입 지정 변수에 그 타입에 없는 속성을 직접 접근하면 **파스 에러**. `obj.get(&"prop")` 로
- `await` 하는 함수 결과는 `var x: Type = await f()` 로 타입을 명시

## 연출(VFX/피드백) 노드 패턴 — `FlipperParryFeedback`이 표준
물리 노드와 **분리된 별도 Node2D**를 만들고:
- `top_level = true`, `z_as_relative = false`, `z_index` 명시
- `bind_to_*(target)`로 붙이고 시그널만 구독
- **대상의 위치·회전·크기는 절대 안 건드림**
- 노드 이름은 `_ParryFeedback`, `_GlowOutline`처럼 언더스코어 접두

**`top_level`은 선택이 아니라 필수다.** 자식으로 두고 `global_rotation`만 덮어쓰면
물리 서버가 바디를 한 스텝 더 돌려서 회전 속도에 비례한 오차가 남는다 → [[run-tests-before-delivering]]

### 레이어 순서 (비주얼 가이드)
꼬리(공 뒤) → 공 본체 → 발광 테두리 → 패링 파동 → 충돌 스파크

## 테스트
`extends SceneTree` + `_init()`에서 `call_deferred(&"_run")` + `_expect(condition, "한글 기대 문장")`
+ 끝에 `PASS: <이름>` / `FAIL: <이름> (N failures)` 출력 후 `quit(0/1)`. 헤드리스 실행형.
씬 테스트는 `load(PATH).instantiate()` → `root.add_child()` → `await physics_frame` 루프로 검증.

실행: `godot --headless --path . --script res://tests/<시스템>/<이름>_test.gd`
