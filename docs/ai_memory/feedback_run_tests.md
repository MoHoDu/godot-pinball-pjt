---
name: run-tests-before-delivering
description: 코드를 짰으면 반드시 직접 돌려서 에러를 확인하고 넘긴다 — 2026-08-03 형락님 지적
type: feedback
---

# 코드를 넘기기 전에 반드시 직접 실행한다

2026-08-03 형락님 지적: **"코드를 짠 후 테스트 돌려보고 에러 체크를 반드시 해."**

## 무엇이 잘못됐나

응시 시스템과 발광 테두리를 만들면서 **두 번 연속으로 안 돌려보고 넘겼다.**
"컨테이너에 Godot이 없다"고 했지만 실제로는 한 번 GitHub API가 403을 준 걸 보고 포기한 것이었다.
그 결과 형락님이 파스 에러를 대신 발견했다.

## Godot은 컨테이너에 설치된다 (경로 확인됨)

GitHub **API**(`api.github.com`)와 릴리스 **목록** 페이지는 403이지만,
릴리스 **에셋 직링크는 200으로 열린다.**

```bash
curl -sL -o /tmp/godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip"
cd /tmp && unzip -q godot.zip && chmod +x Godot_v4.7.1-stable_linux.x86_64
```

프로젝트는 `device_stage_files`로 컨테이너에 복사한 뒤 실행한다.

```bash
/tmp/Godot_v4.7.1-stable_linux.x86_64 --headless --path /tmp/pj --import   # 최초 1회
/tmp/Godot_v4.7.1-stable_linux.x86_64 --headless --path /tmp/pj --script res://tests/.../xxx_test.gd
```

**`xvfb-run`이 설치돼 있어 실제 렌더링 확인도 된다.**
`xvfb-run -a godot --rendering-driver opengl3 --script ...` 로 띄우고
`root.get_texture().get_image().save_png(...)` 로 스크린샷을 뽑으면 눈으로 검증할 수 있다.

## ★ 스테이징 캐시 함정

`device_stage_files`로 **이미 스테이징한 적 있는 파일을 다시 스테이징해도
`/mnt/user-data/uploads/` 의 사본은 옛날 것으로 남아 있을 수 있다.**
(도구는 새 바이트 수를 보고하는데 마운트에는 반영이 안 됨)

How to apply: 내가 만든 파일은 **업로드 마운트가 아니라 `/home/claude` 의 원본에서** 복사해 쓴다.
한 번 이것 때문에 "씬이 되돌아갔다"고 잘못 진단할 뻔했다.

## 실제로 잡힌 버그 (안 돌렸으면 못 잡았다)

1. `const GAP_CENTERS: PackedFloat32Array = PackedFloat32Array([...])` — 생성자는 상수 표현식이 아니다
2. `_ball`을 `Node2D`로 타입 지정하고 `_ball.ball_diameter` 직접 접근 — 정적 검사가 막는다. `get(&"...")` 로
3. **시선 지연 버그** — `lerp_angle(global_rotation, ...)`으로 보간하면 부모 바디 회전이 오차로 섞여
   회전 속도에 비례한 고정 오차가 남는다(3rad/s에서 0.19rad). 자체 각도 변수를 보간해야 한다
4. 그래도 남는 한 스텝 지연 — 자식 노드는 우리가 쓴 뒤 물리 서버가 바디를 한 번 더 돌린다.
   **`top_level = true`** 로 부모 변환을 아예 끊어야 정확해진다

Why: 3번과 4번은 코드만 읽어서는 절대 못 찾는다. 수치가 나와야 보인다.
