# wave_01 최종 확정 보드 (기준 지오메트리)

확정일: 2026-08-07 · 확정자: 형락님(수작업)

`scenes/wave/levels/wave_01.tscn`의 **보드 지오메트리는 확정본**이다.
이후 웨이브(`wave_02`, `wave_03`, `boss_wave`)와 파생 씬은 이 수치를 기준으로 맞춘다.
머지 충돌 시 보드 지오메트리는 **이 문서의 값이 우선**한다.

## 확정 수치

### 플리퍼 (4방향 × 2)

| 항목 | 값 |
|---|---|
| `flipper_length` | 360.0 |
| `initial_angle_degrees` | 좌 +25.0 / 우 −25.0 |
| 컨트롤러 로컬 오프셋 | 좌 −258 ~ −259, 우 +258 ~ +259 |

| 컨트롤러 | position | rotation |
|---|---|---|
| Bottom | (0, 473) | 0 |
| Top | (0, −553) | π |
| Left | (−1018, 0) | π/2 |
| Right | (969, 0) | −π/2 |

실측 스윕 AABB (대기각·최대각 양 끝 기준):

| 컨트롤러 | x | y |
|---|---|---|
| Bottom | −308 ~ 307 | 521 ~ 683 |
| Top | −307 ~ 307 | −665 ~ −503 |
| Left | −1106 ~ −944 | −307 ~ 308 |
| Right | 943 ~ 1105 | −307 ~ 307 |

### 벽 (대각선 4개 — 리바운드가 붙는 면)

| 벽 | position | rotation |
|---|---|---|
| Walls/Top/TopLeftDiagonal | (−633.0001, −402) | −0.348772 |
| Walls/Top/TopRightDiagonal | (632, −402) | 0.34877196 |
| Walls/Bottom/BottomLeftDiagonal | (−626.0001, 413) | −2.7928207 |
| Walls/Bottom/BottomRightDiagonal | (625, 413) | 2.7928207 |

충돌 Shape는 모두 로컬 (0, 12) 오프셋, 두께 24. 벽 시각물은 로컬 y −20 ~ +20.

### 맵 넓이

| 항목 | 값 |
|---|---|
| 반너비 | 1186 |
| 반높이 | 673 |
| 상하 짧은 변 | x ±330 |
| 발사구 | (0, 372), rotation −π/2 |

보드 경계 폴리곤:

```
(-330,-673) (330,-673) (1186,-330) (1186,330)
(330,673) (-330,673) (-1186,330) (-1186,-330)
```

## 이 값에서 파생된 것 (보드가 바뀌면 반드시 다시 계산)

1. **리바운드 4개** — 대각 벽 좌표 + `R(wall_rot) * (0, 25)`, 회전 = `wall_rot + π`
2. **수리 소켓 12개** — `board_placement_validator` 검사 통과 필요
   - 144px 그리드 정렬
   - `reserve_radius` 72 원이 존 폴리곤 안에 완전 포함
   - 플리퍼 스윕·발사 레인·고정 범퍼와 비교차
3. **`ForbiddenAreas`의 `*FlipperSweep`** — 위 실측 AABB에 여유를 더한 사각형
4. **`Zones` 폴리곤** — 소켓을 감싸도록

검증: `layout.validate_layout().issues.size() == 0`

## 이 기준을 따르는 씬 (2026-08-07 전부 정렬 완료)

| 씬 | 파생 레이아웃 |
|---|---|
| `scenes/wave/levels/wave_01.tscn` | `wave_01_repair_layout.tscn` |
| `scenes/wave/levels/wave_02.tscn` | `wave_02_repair_layout.tscn` |
| `scenes/wave/levels/wave_03.tscn` | `wave_03_repair_layout.tscn` |
| `scenes/wave/wave.tscn` (메인) | `wave_repair_board_layout.tscn` |

네 씬 모두 `Walls` / `FlipperSelector` / `PinballLauncher` / `BallDrainArea`
노드 트리가 wave_01 과 동일하다. 보드를 다시 손보면 **네 씬 전부**에
같은 트리를 이식하고 위 파생물 4종을 다시 계산해야 한다.

## 제외

- `scenes/wave/wave01.tscn`
  어디서도 참조되지 않는 프로토타입이라 정렬 대상에서 뺐다.
- `wave01_triangle.tscn`(삼각형 보드 프로토타입)은 2026-08-09 형락님 결정으로
  **전면 삭제**했다. 스테이지 01은 8각 보드 확정.
- 보스 웨이브는 아직 전용 씬이 없다 (`Stage01BumperLayout` 에 로드아웃만 존재).
