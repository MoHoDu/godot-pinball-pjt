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

## 아직 이 기준을 안 따르는 것

- `scenes/wave/levels/wave_02.tscn` 및 `wave_02_repair_layout.tscn`
- `scenes/wave/levels/wave_03.tscn`, `boss_wave`
- `scenes/wave/wave.tscn` (프로젝트 메인 씬)

이들은 아직 이전 보드 수치를 쓴다. 확정본으로 맞출 때 이 문서를 기준으로 한다.
