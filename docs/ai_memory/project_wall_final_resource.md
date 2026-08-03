---
name: wall-final-resource-handoff
description: 2026-08-03 확정 벽 아트, 모듈 생산 파이프라인, 게임 적용 경로, 검증 결과와 현재 비관련 테스트 실패
type: project
---

# 최종 벽 리소스 및 게임 적용 인수인계

업데이트 시점: **2026-08-03, 최종 벽 리소스 확정 및 게임 적용 직후**

## 한 줄 상태

사용자가 선택한 **톤다운 아이보리 외곽 프레임 + 남색 내부 + 내부 구름·별 문양** 시안을 최종본으로 확정했다. 모듈형 실사용 PNG를 다시 생산했고, `test_flipper_board.tscn`의 네 대각 벽이 모두 이 리소스를 사용한다.

벽 작업 자체는 완료 상태다. 사용자가 다시 요청하지 않는 한 새로 생성하거나 이전 시안으로 되돌리지 않는다.

## 최종 비주얼 결정

- 프레임 형태와 충돌 구조는 기존 확정안을 그대로 유지한다.
- 외곽 프레임은 플리퍼 끝의 크림 아이보리를 기준으로 한 뒤 **약 25% 톤다운한 노화 아이보리**다.
- 외곽 프레임에는 구름·별 문양을 넣지 않는다.
- 내부 면은 기존의 어두운 남색을 유지한다.
- 구름과 별 장신구는 매달린 입체물이 아니라 **내부 남색 면에 그린 평면 문양**이다.
- 얇은 청록색 내부 경계선은 유지한다.
- 검은 외곽선, 나무 결, 스크래치와 노화 표현은 유지한다.
- 현재 외부 배경은 `Resources/Art/backgrounds/cursed_circus_outside_background.png`다.

관련 원본 가이드:

- `docs/source_materials/pdfs/pinball_visual_sound_direction_guide_2026-08-03.pdf`
- 기준 수치: 시각 두께 40px, 충돌 두께 24px, 직선 몸통 256x40, 좌우 캡 64x40, 코너 64x64

## 최종 원본

최종 확정 시안의 정본은 다음 파일이다.

`Resources/Art/walls/texture_concepts/wall_texture_final_cursed_toy_v1.png`

- 크기: 1704x923
- SHA-256: `C8293A5A15CCF344F8FA8F8595A3E31B733F33F0DAAB944EC86E9391BF6B923A`
- 사용자가 마지막으로 첨부하고 "최종 벽 리소스로 확정"한 PNG를 그대로 프로젝트에 복사한 파일이다.
- `wall_texture_concept_*` 파일들은 과정 시안이다. 최종 판단 기준으로 사용하지 않는다.

## 실사용 생산 리소스

폴더:

`Resources/Art/walls/cursed_toy_frame_v1/`

필수 런타임 파일:

| 역할 | 파일 | 규격 | SHA-256 |
|---|---|---:|---|
| 반복 몸통 | `wall_body_256x40_cursed_toy_v1.png` | 256x40 | `2838617056B0397402A5B91669DA10CFB35B38A3ED83EDF1D5DEFA6E42283A68` |
| 왼쪽 캡 | `wall_end_cap_left_64x40_cursed_toy_v1.png` | 64x40 | `62EE6B1D18CA0E5DB2655F39964D57F65A1DA08C3511E3E503EA256D96CD32ED` |
| 오른쪽 캡 | `wall_end_cap_right_64x40_cursed_toy_v1.png` | 64x40 | `272DD93C4FB865553E9A083AC6420EAB6F6320EDAB0D44880EDF7718FEA26F56` |
| 90도 코너 | `wall_corner_90_64x64_cursed_toy_v1.png` | 64x64 | `9EEF7B52717832788291EEB24AD47E681CA00C447B2B7DE1A5B958DD370F81EF` |
| 활성 벽 씬 | `wall_visual_820x40_cursed_toy_v1.tscn` | 820x40 | 몸통 692px 반복 + 좌우 캡 |

추가 산출물:

- `wall_assembled_820px_cursed_toy_v1.png`
- `wall_assembled_1090px_cursed_toy_v1.png`
- `wall_assembled_1222px_cursed_toy_v1.png`
- `wall_components_cursed_toy_v1_preview.png`
- `wall_board_application_cursed_toy_v1_preview.png`

코너 리소스는 생산 완료됐지만 현재 테스트 보드의 네 대각 직선 벽에서는 사용하지 않는다. 향후 90도 벽 연결에 쓰기 위한 모듈이다.

## 생산 파이프라인

스크립트:

`tmp/imagegen/wall_texture_production_v1/produce_selected_wall_texture_v1.py`

현재 스크립트 상태:

- 최종 원본 `wall_texture_final_cursed_toy_v1.png`를 입력으로 사용한다.
- 네이비 내부뿐 아니라 밝은 아이보리 프레임까지 포함해 컴포넌트 경계를 검출한다.
- `Resources/Art/walls/shape_prototype_v1/`의 확정 알파 마스크를 적용해 실루엣과 청록 경계선을 고정한다.
- 직선 타일 좌우 끝을 평균 처리해 완전 반복되게 한다.
- 좌우 캡의 접합부를 몸통 끝색과 블렌딩한다.
- 프로젝트 루트는 `Path(__file__).resolve().parents[3]`로 찾으므로 다른 PC 경로에서도 수정 없이 실행 가능하다.
- 의존성: `numpy`, `Pillow`.

현재 PC의 기본 `python`에는 NumPy가 없었다. Codex 번들 Python으로 실행했다. 다른 PC에서도 먼저 `codex_app__load_workspace_dependencies`로 번들 Python 경로를 찾는 것이 안전하다.

실행 예시:

```powershell
& '<Codex 번들 Python 경로>\python.exe' 'tmp\imagegen\wall_texture_production_v1\produce_selected_wall_texture_v1.py'
```

정상 로그 핵심:

```text
source_size=(1704, 923)
wall_body_256x40_cursed_toy_v1.png size=(256, 40) alpha=(0, 255)
wall_end_cap_left_64x40_cursed_toy_v1.png size=(64, 40) alpha=(0, 255)
wall_end_cap_right_64x40_cursed_toy_v1.png size=(64, 40) alpha=(0, 255)
wall_corner_90_64x64_cursed_toy_v1.png size=(64, 64) alpha=(0, 255)
body_tile_edge_match=True
```

## 게임 적용 상태

활성 보드 씬:

`scenes/test_flipper/test_flipper_board.tscn`

이 씬은 다음 벽 씬을 `ExtResource("10_wall_visual")`로 참조한다.

`res://Resources/Art/walls/cursed_toy_frame_v1/wall_visual_820x40_cursed_toy_v1.tscn`

적용 노드:

- `Walls/TopRightDiagonal/Visual`
- `Walls/BottomRightDiagonal/Visual`
- `Walls/BottomLeftDiagonal/Visual`
- `Walls/TopLeftDiagonal/Visual`

확정 벽의 물리 구조는 바꾸지 않았다.

- 각 벽 충돌 길이: 819.329
- 충돌 두께: 24
- 충돌 위치: `Vector2(0, 12)`
- 시각 길이: 820
- 몸통 반복 영역: 692x40
- 좌우 캡 중심: x=-378, x=378

PNG 파일이 같은 실사용 경로에 갱신됐기 때문에 별도의 노드 재배치는 필요 없다.

## 검증 결과

1. 생산 스크립트: 성공, `body_tile_edge_match=True`.
2. 부품 프리뷰: 직선·좌우 캡·코너의 최종 색과 문양 확인 완료.
3. 보드 합성 프리뷰: 네 대각 벽에 적용된 모습 확인 완료.
4. Godot 4.7.1 헤드리스 에디터 재임포트: 종료 코드 0.
5. 별도 Godot 경로·규격 검사: 종료 코드 0.

검사 결과:

```text
PASS: final wall resources are active on all four board walls
```

Godot 실행 시 아래 셰이더 컴파일 경고가 반복되지만 벽 리소스와 무관한 기존 경고다.

```text
Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)" is true.
```

## 전체 보드 테스트의 현재 비관련 실패 3건

명령:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path '<project>' --script res://tests/flipper_system/test_flipper_board_scene_test.gd
```

벽 관련 검사는 모두 통과했지만 전체 테스트는 현재 3건 실패한다.

1. 하단 플리퍼 x축 간격이 테스트 기대값 700이 아니다.
   - 현재 `BottomController/LeftFlipper`: `Vector2(-351, 72.00001)`
   - 현재 `BottomController/RightFlipper`: `Vector2(369, 76.00001)`
   - x축 차이 720
2. 외부 배경의 렌더 크기가 정확히 2240x1260이 아니다.
3. 외부 배경 중심이 원점이 아니다.
   - 현재 위치: `Vector2(7, 23)`
   - 현재 스케일: `Vector2(1.3494952, 1.4303268)`

이 값들은 벽 최종화 작업과 별개로 씬에 존재하던 사용자 조정이다. 사용자의 명시적 요청 없이 700 간격이나 배경 원점/정규 스케일로 되돌리지 않는다.

실제 헤드리스 화면 캡처는 `root.get_texture().get_image()` 이후 프레임이 반환되지 않아 중단했다. 임시 검증 스크립트는 삭제했다. 시각 확인에는 다음 생산 프리뷰를 사용한다.

`Resources/Art/walls/cursed_toy_frame_v1/wall_board_application_cursed_toy_v1_preview.png`

## 작업 트리 주의

현재 작업 트리는 매우 더럽다. 공, VFX, 보드, 플리퍼, PDF 렌더와 `.import` 파일 등 벽과 무관한 변경이 다수 있다.

- `git reset --hard`, `git checkout --`, 광범위 삭제를 하지 않는다.
- 다른 작업자의 변경을 정리하거나 롤백하지 않는다.
- 벽 관련 핵심 경로만 좁혀서 다룬다.
- 벽 폴더와 텍스처 콘셉트 폴더는 현재 Git에서 untracked로 보일 수 있다.
- `scenes/test_flipper/test_flipper_board.tscn`과 `tests/flipper_system/test_flipper_board_scene_test.gd`에는 벽 적용 변경과 다른 사용자 변경이 함께 있다.

## 다음 Codex 시작 절차

1. `docs/ai_memory/MEMORY.md`와 이 문서를 먼저 읽는다.
2. 최종 상태 확인만 필요하면 `wall_texture_final_cursed_toy_v1.png`, 생산 폴더, 활성 벽 씬의 경로를 확인한다.
3. 벽 리소스는 이미 최종 확정됐다. 사용자가 새 변경을 요구하지 않으면 재생성하지 않는다.
4. 재생산이 필요하면 최종 원본을 유지하고 생산 스크립트를 실행한 뒤 `body_tile_edge_match=True`를 확인한다.
5. Godot 임포트 후 네 벽의 Body/LeftCap/RightCap 경로와 규격을 검사한다.
6. 전체 보드 테스트의 위 3건은 벽 실패로 오진하지 않는다.

