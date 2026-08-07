# 스테이지 보상 데이터베이스

보상 밸런스의 원본은 [Pinball_DB Google Sheets](https://docs.google.com/spreadsheets/d/1Q0MfGXOUsKpdfwdUjT-Sz99P-KFjJaeOnOluKiMcSaQ/edit)입니다.

## 폴더 구조

스테이지마다 `Resources/stage/<stage_id>/` 폴더를 사용합니다.

- `reward_balls.csv`: 공의 표시명·성능 그룹·등장 시점·기본 가중치·가격·활성 상태
- `reward_parts.csv`: 부품의 표시명·등장 시점·기본 가중치·가격·구성 규칙·활성 상태
- `reward_weight_overrides.csv`: 특정 스테이지·웨이브에서만 바꿀 가중치
- `reward_simulation.csv`: 에디터가 생성한 실제 카드 등장률 보고서

현재 구현된 스테이지 ID는 `stage_01`입니다.

## 공 보상 스키마

| 열 | 형식 | 설명 |
| --- | --- | --- |
| `reward_id` | 문자열 | Godot 카탈로그 정의와 일치하는 고유 ID |
| `display_name` | 문자열 | 보상 화면에 표시할 이름 |
| `performance_group` | `GOOD`, `MID`, `HARDCORE` | 첫 보상 화면의 공 구성 그룹 |
| `first_stage_num` | 1 이상의 정수 | 처음 후보에 등장할 스테이지 번호 |
| `first_wave_num` | 1~4 정수 | 처음 후보에 등장할 웨이브 번호 |
| `weight` | 0 이상의 실수 | 상대 추첨 가중치. `0`이면 등장하지 않음 |
| `price` | 1 이상의 정수 | 구매 코인 |
| `enabled` | `TRUE`, `FALSE` | `FALSE`이면 카탈로그에서 제외 |

## 부품 보상 스키마

공통 등장·가격 열 외에 다음 규칙을 시트에서 관리합니다.

| 열 | 형식 | 설명 |
| --- | --- | --- |
| `bundle_count` | 1 이상의 정수 | 구매 시 지급 수량 |
| `works_standalone` | `TRUE`, `FALSE` | 다른 부품 없이 동작 가능한지 |
| `needs_partner` | `TRUE`, `FALSE` | 다른 부품과의 연결이 필요한지 |
| `required_partner_kinds` | 0~3 정수 | 발동에 필요한 다른 부품 종류 수 |

효과 설명과 실제 에셋 연결은 Godot 카탈로그에 유지합니다. 시트에 새 `reward_id`를 활성화하려면 해당 ID의 Godot 정의가 먼저 있어야 합니다.

## 등장 시점

`first_stage_num=1`, `first_wave_num=1`이면 1스테이지 1웨이브 클리어 보상부터 등장합니다. 보상 화면은 클리어한 일반 웨이브 번호 `1, 2, 3`을 사용합니다. `4`는 보스 웨이브 번호로 예약되어 있습니다.

## 가중치와 웨이브별 변경

`weight`는 퍼센트가 아니라 추첨권 수입니다. 같은 후보가 `5, 3, 2`라면 한 장을 뽑을 때 기본 비율은 `50%, 30%, 20%`입니다. 실제 화면은 여러 장을 비복원 추첨하고 구성 보정 규칙도 적용하므로 최종 등장률은 시뮬레이션 보고서로 확인합니다.

`reward_weight_overrides`에는 기본값과 다르게 만들 항목만 기록합니다.

| `stage_num` | `wave_num` | `reward_id` | `weight` |
| ---: | ---: | --- | ---: |
| 1 | 2 | clockwork | 3 |

위 예시는 시계태엽 공의 1스테이지 2웨이브 가중치만 `3`으로 바꿉니다. 행이 없으면 공·부품 시트의 기본 `weight`를 사용합니다. 공과 부품의 `reward_id`는 전체 보상 DB에서 서로 중복될 수 없습니다.

## 에디터 메뉴

1. `프로젝트 > 도구 > Stage DB/Google Sheets에서 최신 CSV 가져오기`
   - 공·부품·오버라이드 CSV를 모두 다운로드합니다.
   - 헤더, 자료형, ID 참조를 세트 단위로 검증합니다.
   - 세 파일이 모두 유효할 때만 기존 파일을 한꺼번에 교체합니다.
2. `프로젝트 > 도구 > Stage DB/보상 확률 10만 회 시뮬레이션`
   - 미해금 공과 보유 부품이 없고 지갑이 18코인인 기준 조건으로 일반 웨이브 1~3을 각각 10만 회 생성합니다.
   - 성능 그룹, 연결 부품, 보스 사용 가능성, 구매 가능성 보정을 포함한 최종 카드 등장률을 `reward_simulation.csv`에 저장합니다.

Google Sheets의 `reward_simulation` 탭은 보고서를 공유하는 보기입니다. 에디터가 만든 로컬 CSV의 `appearance_rate`는 `0~1` 값이며 시트에서는 퍼센트 형식으로 표시합니다.
