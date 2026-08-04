---
name: godot-install-blocked
description: 컨테이너 Godot 설치 — 2026-08-04 재개통. 받는 법과 프로젝트를 통째로 옮기지 않고 검증하는 법
type: reference
---

# ★ 2026-08-04 — 다시 열렸다. 먼저 받아 볼 것

파일 이름은 "blocked"지만 **지금은 받아진다.** 세션마다 다를 수 있으니 **1분 안에 확인하고** 넘어간다.

```bash
curl -sL -o /tmp/godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip"
cd /tmp && unzip -q godot.zip && chmod +x Godot_v4.7.1-stable_linux.x86_64
```

## 프로젝트를 통째로 스테이징하지 않는다

아트가 수백 MB라 `device_stage_files` 한도에 걸린다. **코드·씬·설정만** 옮기고,
`.tscn`/`.tres` 가 참조하는 이미지 경로를 훑어 **자리표시자 PNG를 생성**한 뒤 `--import` 한다.
파일명의 `256x40` 같은 숫자를 크기로 쓰면 레이아웃도 얼추 맞는다.

**주의**: 자리표시자로는 **아트 검증 테스트(`pinball_size_test` 등)가 의미 없다.**
텍스처 크기·알파 bbox를 보는 테스트는 실제 아트를 스테이징하거나 로컬에서 돌린다.

## 새 `class_name` 은 `--import` 를 한 번 더 돌려야 인식된다

스크립트를 새로 추가하면 `.godot/global_script_class_cache.cfg` 에 등록되기 전까지
`Identifier "X" not declared in the current scope` 파스 에러가 난다. **코드 문제가 아니다.**

`.uid` 파일을 안 옮기면 `invalid UID ... using text path instead` 경고가 뜨는데, 경로로 폴백하므로 무해하다.

## 스크린샷 검증도 된다

```bash
xvfb-run -a /tmp/Godot_v4.7.1-stable_linux.x86_64 --path <프로젝트> \
  --rendering-driver opengl3 --resolution 1920x1080 --script res://<shot>.gd
```

스크립트 안에서 `RenderingServer.force_draw()` 뒤 `root.get_texture().get_image().save_png(...)`.
UI 작업은 이걸로 눈으로 확인하고 넘긴다. 한글은 기본 폰트로도 정상 출력됐다.

---

## 이전 상태 (2026-08-03) — 이력

당시에는 `github.com` 은 200이지만 릴리스 에셋이 **`release-assets.githubusercontent.com`** 으로
302되고 그 호스트가 차단됐다. npm·PyPI·apt 어디에도 Godot 바이너리를 직접 배포하는 패키지가 없다
(npm의 godot-* 패키지들은 전부 GitHub에서 받아오므로 같이 막힌다).

| 호스트 | 2026-08-03 상태 |
|---|---|
| `github.com` | 200 (세션에 따라 CONNECT 403이 되기도 한다) |
| `objects.githubusercontent.com` | 도달 가능 (구 에셋 호스트, 지금은 안 씀) |
| `pypi.org` / `files.pythonhosted.org` / `registry.npmjs.org` | 200 |
| `release-assets.githubusercontent.com` | 차단 → **2026-08-04 200** |
| `raw.githubusercontent.com` / `downloads.godotengine.org` / `deb.debian.org` | 차단 |

**How to apply**: 엔진 다운로드가 다시 막히면 아래 대체 검증을 쓰고,
엔진이 꼭 필요한 것만 형락님 로컬에서 돌리게 명령어를 같이 넘긴다.

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
