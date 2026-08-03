---
name: godot-install-blocked
description: 컨테이너에서 Godot 설치 불가 — 릴리스 에셋 호스트 차단. 엔진 없이 하는 대체 검증 목록
type: reference
---

# Godot 컨테이너 설치는 막혀 있다 (2026-08-03 재확인)

`github.com` 자체는 200이지만 릴리스 에셋이 **`release-assets.githubusercontent.com`** 으로
302되고 **그 호스트가 차단**된다. 4.2 / 4.3 / 4.7.1 전부 같다.
npm·PyPI·apt 어디에도 Godot 바이너리를 직접 배포하는 패키지가 없다
(npm의 godot-* 패키지들은 전부 GitHub에서 받아오므로 같이 막힌다).

| 호스트 | 상태 |
|---|---|
| `github.com` | 200 (세션에 따라 CONNECT 403이 되기도 한다) |
| `objects.githubusercontent.com` | 도달 가능 (구 에셋 호스트, 지금은 안 씀) |
| `pypi.org` / `files.pythonhosted.org` / `registry.npmjs.org` | 200 |
| `release-assets.githubusercontent.com` | **차단** |
| `raw.githubusercontent.com` / `downloads.godotengine.org` / `deb.debian.org` | **차단** |

**Why**: `feedback_run_tests.md` 에 "릴리스 에셋 직링크는 200으로 열린다"고 적혀 있는데 **이제 아니다.**
그걸 믿고 시간 쓰지 말 것. (2026-08-03 세션 중에도 한 번은 되고 한 번은 안 됐다 — 먼저 1분 안에 확인하고 넘어간다.)

**How to apply**: 엔진이 필요한 검증은 형락님 로컬에서 돌리게 하고 명령어를 같이 넘긴다.
엔진 없이 할 수 있는 것은 먼저 다 한다.

## 엔진 없이 하는 대체 검증 (실제로 쓴 것)

- 텍스처 크기·알파 bbox 확인 → `pinball_size_test` 가 보는 값과 동일
- 엔진 수식(`refresh_ball_size` 등)을 파이썬으로 재현해 대조
- `.tscn` ext_resource 경로가 실제 파일과 **대소문자까지** 일치하는지 → [[path-case-issue]]
- 구본 텍스처 참조 잔존 / 변종 씬 상속 확인
- 원본 텍스처 + 규칙 `.tres` 값으로 **파이썬 근사 합성** → 눈으로 확인
- `pip install gdtoolkit` → `gdparse`(구문) / `gdlint`(스타일).
  리포 기존 파일도 같은 `class-definitions-order` 경고가 나므로 그건 컨벤션이지 회귀가 아니다
- **`pip install moderngl` + `xvfb-run` → llvmpipe로 실제 `.gdshader` 를 컴파일·실행.**
  Godot 셰이더를 GLSL 330으로 기계 치환(`shader_type`/`render_mode` 제거, `COLOR`→out, `UV`→in)하면
  사본이 아니라 **리포의 진짜 셰이더 파일**을 돌려볼 수 있다. 유니폼도 `.tres` 에서 읽어 넣는다
- GDScript 링버퍼 같은 순수 로직은 파이썬으로 1:1 이식해 시뮬레이션
  (`docs/ball_guides/trail_history_sim.py` — **원본을 고치면 이 파일도 같이 고쳐야 한다**)
- 오디오는 애초에 엔진이 필요 없다 — numpy/scipy/ffmpeg 로 합성·실측이 전부 된다 → [[sfx01-ball-pilot]]

**여전히 못 하는 것**: 씬 트리·시그널·물리 등 엔진 런타임 테스트. 형락님 로컬 실행 필요.

```
godot --headless --path . --script res://tests/<시스템>/<이름>_test.gd
```

관련: [[run-tests-before-delivering]], [[codebase-conventions]]
