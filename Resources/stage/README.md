# 스테이지 데이터베이스

보상 밸런스의 원본은 [Pinball_DB Google Sheets](https://docs.google.com/spreadsheets/d/1Q0MfGXOUsKpdfwdUjT-Sz99P-KFjJaeOnOluKiMcSaQ/edit)입니다.

## 폴더 구조

스테이지마다 `Resources/stage/<stage_id>/` 폴더를 사용합니다.

- `reward_balls.csv`: 공 보상 데이터베이스
- `reward_parts.csv`: 수리 부품 보상 데이터베이스

현재 구현된 스테이지 ID는 `stage_01`입니다.

## 공통 스키마

| 열 | 형식 | 설명 |
| --- | --- | --- |
| `reward_id` | 문자열 | 카탈로그의 공 또는 부품 ID와 일치하는 고유 ID |
| `first_wave_id` | 문자열 | 처음 후보에 등장할 웨이브 ID (`wave_01`~`wave_03`, `boss_wave`) |
| `probability` | 0 이상의 실수 | 후보 추첨의 상대 가중치. `0`이면 등장하지 않음 |
| `price` | 1 이상의 정수 | 구매에 필요한 코인 |

CSV는 해당 스테이지에서 활성화할 보상 목록입니다. 기존 카탈로그 정의가 CSV에서 빠지면 후보에서도 제거됩니다. 새 `reward_id`를 추가할 때는 표시명·효과·에셋을 가진 Godot 카탈로그 정의를 먼저 추가해야 하며, 정의가 없는 ID는 동기화 후 적용 단계에서 오류로 보고됩니다.

## 갱신 절차

1. Google Sheets의 `reward_balls`, `reward_parts` 탭을 수정합니다.
2. Godot 상단 메뉴에서 `프로젝트 > 도구 > Stage DB/Google Sheets에서 최신 CSV 가져오기`를 실행합니다.
3. 두 CSV가 모두 다운로드되고 스키마 검증을 통과한 경우에만 임시 파일을 기존 파일과 교체합니다. 교체 실패 시 기존 두 파일로 롤백합니다.
4. 변경된 CSV와 코드 동작을 테스트한 뒤 함께 커밋합니다.

Godot에서는 CSV를 `Keep File (exported as is)`로 유지합니다. 런타임은 `StageDataRepository` 오토로드가 최초 실행 시 `stage_01`을 읽고 보상 카탈로그에 가격·최초 등장 웨이브·확률을 적용합니다.
