# Stage 01 웨이브·보스 에디터 설정 가이드

이 문서는 현재 시스템 구조를 변경하지 않고 Godot 에디터에서 Stage 01의 웨이브와
보스를 조정하는 방법을 설명합니다.

## 먼저 알아둘 현재 구조

- 실제 게임 진입 씬은 `scenes/game/start/start_screen.tscn`입니다.
- Stage 01 구성 씬은 `scenes/game/stages/stage_01/stage_01.tscn`입니다.
- 일반 웨이브 3개와 보스는 모두 `Resources/Prefabs/wave/base/wave_unique.tscn`을
  상속합니다.
- 현재 일반 웨이브 3개는 목표 점수만 서로 다르고, 범퍼·수리 영역·소켓·기본 코인
  배치는 공통 베이스에서 상속합니다.
- 보스도 같은 웨이브 베이스를 상속하므로 기본 범퍼와 수리 영역·소켓을 공유합니다.

씬이나 리소스를 수정하기 전에 Git 브랜치를 확인하고, 한 항목씩 수정한 뒤 해당 씬을
F6으로 실행하여 확인하는 것을 권장합니다.

## 웨이브 범퍼 위치와 설정

### 작업할 씬

조정하려는 웨이브 씬을 엽니다.

- 웨이브 1: `scenes/game/stages/stage_01/waves/stage_01_wave_01.tscn`
- 웨이브 2: `scenes/game/stages/stage_01/waves/stage_01_wave_02.tscn`
- 웨이브 3: `scenes/game/stages/stage_01/waves/stage_01_wave_03.tscn`

### 위치 설정

1. Scene 트리에서 `Bumpers`를 펼칩니다.
2. 이동할 범퍼를 선택합니다.
3. 2D 화면에서 이동 도구로 드래그하거나 Inspector의
   `Transform > Position`을 수정합니다.
4. 범퍼끼리 겹치거나 플리퍼 스윕·발사구를 막지 않는지 F6으로 확인합니다.

위치 변경은 열린 웨이브 씬의 오버라이드로 저장할 수 있습니다. 다만 상속된 범퍼의
삭제·종류 교체·구성 전체 변경은 현재 씬 구조에서 편하지 않습니다.

### 크기 설정

범퍼 노드의 `Transform > Scale`은 변경하지 않습니다. Scale을 사용하면 그래픽과 물리
크기, 안전 복구 계산이 서로 어긋날 수 있습니다.

1. Scene 트리에서 범퍼 루트 노드를 선택합니다.
2. Inspector의 `Bumper Configuration > Object Settings`를 펼칩니다.
3. 다음 값을 수정합니다.
   - `Collision Diameter`: 실제 공 충돌 지름
   - `Visual Diameter`: 화면에 보이는 범퍼 지름
   - `Respawn Safe Margin`: 재생성 시 공과 확보할 추가 안전거리
   - `Graphic Size Ratio`: 실제 이미지가 표시 지름에서 차지하는 비율
   - `Graphic Offset`: 이미지 중심 보정

`Object Settings`는 범퍼 종류가 공유하는 외부 설정 리소스입니다. 여기서 크기를 바꾸면
같은 종류의 범퍼를 사용하는 다른 웨이브와 보스에도 반영됩니다. 현재
`BumperInstanceOverrides`에는 크기 전용 오버라이드가 없습니다.

### 점수·내구도·물리 반응 설정

범퍼 루트 Inspector에서 다음 리소스를 펼칩니다.

- `Common Bumper Settings`
  - `Base Score`: 이 범퍼의 기본 점수
  - `Score Weight`: 콤보 점수 가중치
  - `Max Durability`: 최대 내구도
  - `Durability Damage Per Hit`: 타격당 내구도 피해
  - `Respawn Delay`: 파괴 후 복구 대기 시간
- `Type Settings`
  - `Speed Multiplier`: 충돌 속력 배율
  - `Minimum Release Speed`: Bounce 최소 방출 속력
  - `Maximum Response Speed`: 최대 반응 속력
  - Shot 범퍼의 `Selection Duration`, `Launch Speed`, 발사 방향 목록
- `Instance Overrides`
  - 특정 범퍼 인스턴스만 점수·내구도·속력·Shot 수치를 다르게 설정
  - 음수 값은 공용 설정을 사용한다는 뜻입니다.

특정 웨이브의 한 범퍼만 밸런스를 바꾸려면 공유 `Common/Type Settings`보다
`Instance Overrides`를 우선 사용합니다.

## 웨이브 영역과 소켓 위치 설정

현재 실제 웨이브들이 사용하는 공통 레이아웃은 다음 씬입니다.

`Resources/Prefabs/boards/wave_repair_board_layout.tscn`

### 영역 설정

1. 위 레이아웃 씬을 직접 엽니다.
2. Scene 트리에서 `Zones`를 펼칩니다.
3. `Upper`, `Middle`, `Lower` 중 수정할 `Polygon2D`를 선택합니다.
4. 2D 툴바의 폴리곤 점 편집 도구로 꼭짓점을 이동합니다.
5. Inspector에서 다음 항목을 확인합니다.
   - `Zone Id`: 소켓이 참조하는 영역 ID
   - `Allowed Kind Ids`: 이 영역에 배치할 수 있는 수리 부품 ID

### 소켓 위치 설정

1. Scene 트리에서 `Sockets`를 펼칩니다.
2. 수정할 `Marker2D` 소켓을 선택합니다.
3. 2D 화면에서 소켓을 이동합니다.
4. Inspector에서 다음 항목을 확인합니다.
   - `Socket Id`: 중복되지 않는 소켓 ID
   - `Zone Id`: 소켓이 속한 영역
   - `Reserve Radius`: 수리 부품을 위해 예약할 반경
   - `Enabled`: 런타임에서 사용할지 여부
5. 레이아웃 루트 `WaveRepairBoardLayout`을 선택합니다.
6. Inspector의 `Validate & Save` 버튼을 누릅니다.

현재 검증 규칙은 다음과 같습니다.

- 소켓은 정확히 12개여야 합니다.
- 소켓 중심은 144px 그리드에 정렬되어야 합니다.
- 소켓 예약 원 전체가 보드 및 대상 영역 안에 있어야 합니다.
- 소켓끼리, 금지 영역, 플리퍼 스윕, 발사구와 겹치면 안 됩니다.

공통 레이아웃을 수정하면 웨이브 1·2·3과 보스에 함께 반영됩니다.

## 웨이브 코인 위치 설정

### 작업 방법

1. 수정할 `stage_01_wave_0N.tscn`을 엽니다.
2. Scene 트리에서 `CoinSystem > SpawnPoints`를 펼칩니다.
3. `Main01`~`Main10` 또는 `Risk01`~`Risk02` 마커를 선택합니다.
4. 2D 화면에서 마커를 원하는 위치로 드래그합니다.
5. Inspector에서 다음 값을 확인합니다.
   - `Point Id`: 같은 웨이브 안에서 중복되지 않는 ID
   - `Route Kind`: `MAIN` 또는 `RISK`
   - `Editor Radius`: 에디터 마커 표시 크기

`Editor Radius`는 편집용 표시 크기입니다. 실제 코인 크기와 겹침 검증 반경은
`settings/coin/BasicCoin.tres`의 `Visual Radius`를 사용합니다.

### 코인 개수 변경 시

코인 마커를 추가·복제·삭제했다면 `CoinSystem` 루트 Inspector의 다음 기대값도 실제
배치와 맞춰야 합니다.

- `Expected Spawn Count`: 전체 코인 수
- `Expected Main Count`: MAIN 코인 수
- `Expected Risk Count`: RISK 코인 수

현재 기본값은 전체 12개, MAIN 10개, RISK 2개입니다.

코인 배치는 코드상 다음 항목을 검증할 수 있지만, 현재 Inspector에 실행 버튼은 없습니다.

- 보드 밖 배치
- 코인끼리의 겹침
- 범퍼와의 겹침
- 소켓 예약 반경과의 겹침
- 금지 영역과의 겹침

변경 후 해당 웨이브를 F6으로 실행하여 실제 생성 위치와 획득 동작을 확인합니다.

## 웨이브 타겟 스코어 설정

1. 수정할 `stage_01_wave_0N.tscn`을 엽니다.
2. Scene 트리에서 루트 `Stage01Wave0N`을 선택합니다.
3. Inspector에서 `Wave Configuration > Wave Stage Settings`를 펼칩니다.
4. `Wave Target Scores` 배열의 0번 값을 수정합니다.

각 Stage 01 웨이브 래퍼는 내부적으로 하나의 목표 점수만 사용하므로 배열의 첫 번째 값이
해당 웨이브 목표 점수입니다.

현재 값은 다음과 같습니다.

| 웨이브 | 목표 점수 |
|---|---:|
| 웨이브 1 | 1,000 |
| 웨이브 2 | 1,500 |
| 웨이브 3 | 3,000 |

## 웨이브 기본 스코어 설정

1. 수정할 `stage_01_wave_0N.tscn`을 엽니다.
2. 루트 `Stage01Wave0N`을 선택합니다.
3. `Wave Configuration > Wave Stage Settings`를 펼칩니다.
4. `Stage Base Score`를 수정합니다.

`Stage Base Score`는 점수 가중치 1.0인 유효 타격 한 번의 기준 점수입니다. 실제 콤보
정산 점수는 다음 값들의 영향을 함께 받습니다.

- `Stage Base Score`
- 범퍼의 `Score Weight`
- 현재 콤보 단계의 점수 배율

각 웨이브 씬의 `Wave Stage Settings`는 로컬 서브리소스이므로 웨이브별로 다른 기본
스코어를 설정할 수 있습니다. 현재 직렬화된 값이 없으면 기본값 100을 사용합니다.

## 보스 범퍼 위치와 설정

### 작업할 씬

보스 콘텐츠 편집은 다음 씬에서 진행합니다.

`scenes/game/stages/stage_01/boss/stage1_teddy_boss_wave.tscn`

실제 단독 플레이 확인은 다음 엔트리 씬을 F6으로 실행합니다.

`scenes/game/stages/stage_01/boss/stage1_teddy_boss_scene.tscn`

### 위치 설정

1. `stage1_teddy_boss_wave.tscn`의 Scene 트리에서 `Bumpers`를 펼칩니다.
2. 이동할 범퍼를 선택합니다.
3. 2D 화면 또는 `Transform > Position`에서 위치를 수정합니다.
4. `stage1_teddy_boss_scene.tscn`을 F6으로 실행해 보스 몸체·팔 공격·플리퍼와 겹치지
   않는지 확인합니다.

보스는 일반 웨이브와 동일한 기본 범퍼 6개를 상속합니다. 크기·점수·내구도·반응
설정 방법도 일반 웨이브 범퍼와 같습니다.

보스만의 범퍼 크기를 만들기 위해 공용 `Object Settings`를 수정하면 일반 웨이브도 함께
바뀝니다. 현재 크기에는 인스턴스 전용 오버라이드가 없습니다.

## 보스 영역과 소켓 위치 설정

현재 보스 전용 영역·소켓 레이아웃은 없습니다. 보스도 다음 공통 레이아웃을 사용합니다.

`Resources/Prefabs/boards/wave_repair_board_layout.tscn`

따라서 설정 방법은 앞의 **웨이브 영역과 소켓 위치 설정**과 동일합니다. 이 레이아웃을
수정하면 일반 웨이브와 보스가 모두 변경됩니다.

보스에만 다른 영역이나 소켓을 사용하려면 전용 레이아웃을 보스 씬에 연결하는 추가 구현이
필요합니다.

## 보스 HP 설정

보스 HP는 다음 리소스에서 설정합니다.

`settings/bosses/Stage1BossPhase1Rules.tres`

1. FileSystem에서 위 리소스를 선택합니다.
2. Inspector의 `Boss Max Hp`를 수정합니다.
3. 필요하면 `Phase 2 Hp Ratio`도 함께 조정합니다.

현재 기본값은 다음과 같습니다.

- `Boss Max Hp`: 12,000
- `Phase 2 Hp Ratio`: 0.5
- 페이즈 2 진입 HP: 6,000

`Boss Max Hp`는 0보다 커야 하고, `Phase 2 Hp Ratio`는 0보다 크고 1보다 작아야 합니다.

## 보스 기본 데미지 설정

현재 보스에는 `Base Damage`라는 독립적인 Inspector 필드가 없습니다. 기본 피해는 다음
공식으로 계산됩니다.

```text
기본 피해 = Boss Max Hp ÷ Target Valid Hit Count × 공 무게 배율
최종 피해 = 기본 피해 × 콤보 횟수 성장 배율 × 콤보 단계 배율
카운터 피해 = 최종 피해 × Parry Counter Multiplier
```

관련 설정 위치는 다음과 같습니다.

### 기본 피해량과 목표 타격 수

`settings/bosses/Stage1BossPhase1Rules.tres`

- `Boss Max Hp`
- `Target Valid Hit Count`
- `Parry Counter Multiplier`

현재 `Boss Max Hp = 12000`, `Target Valid Hit Count = 30`이므로 보통 공의 첫 타격 기준
피해는 400입니다.

### 공 무게별 피해 배율

`settings/bosses/BossBallDamageWeightRules.tres`

- Light: 0.90
- Normal: 1.00
- Heavy: 1.15
- Super Heavy: 1.30

### 콤보 피해 배율

`settings/combo/ComboRules.tres`

- `Normal Damage Multiplier`
- `Super Damage Multiplier`
- `Hyper Damage Multiplier`
- `Ultra Damage Multiplier`
- `Damage Growth Per Hit`
- `Damage Combo Cap`

이 리소스는 보스 전용이 아니라 콤보 시스템 공용 설정입니다. 값을 바꾸면 보스 피해 계산
전체에 영향을 줍니다.

## 에디터에서 어렵거나 현재 구현되지 않은 항목

1. **웨이브별 범퍼 구성 완전 분리**
   - 웨이브 1·2·3이 공통 베이스의 같은 범퍼 6개를 상속합니다.
   - 위치 오버라이드는 가능하지만 상속된 범퍼의 삭제·종류 교체·서로 다른 로스터 구성은
     편하지 않습니다.

2. **웨이브별 범퍼 크기 오버라이드**
   - 크기는 공유 `Object Settings`에만 있습니다.
   - 특정 웨이브 또는 보스의 범퍼 하나만 다른 충돌/표시 지름을 쓰는 인스턴스 설정은
     구현되어 있지 않습니다.

3. **웨이브별 영역·소켓 연결**
   - `wave_01_repair_layout.tscn`, `wave_02_repair_layout.tscn`,
     `wave_03_repair_layout.tscn` 파일은 존재하지만 현재 실제 Stage 01 웨이브에는 연결되어
     있지 않습니다.
   - 현재는 `wave_repair_board_layout.tscn` 하나를 웨이브와 보스가 공유합니다.

4. **보스 전용 영역·소켓**
   - 보스 전용 레이아웃은 구현되어 있지 않습니다.
   - 공통 레이아웃을 수정하면 일반 웨이브도 함께 변경됩니다.

5. **코인 배치 Inspector 검증 버튼**
   - 코인 겹침 검증 코드는 있지만 에디터 Inspector에서 바로 실행할 버튼과 구성 경고가
     없습니다.
   - 현재는 F6 실행 또는 자동 테스트로 확인해야 합니다.

6. **코인별 가치·종류 설정**
   - 각 SpawnPoint에는 위치와 경로 종류만 있습니다.
   - 코인 가치와 그래픽 정의는 `CoinSystem` 전체가 하나의 `CoinDefinition`을 공유합니다.

7. **보스 기본 데미지 단일 필드**
   - 독립적인 `Base Damage` 설정은 구현되어 있지 않습니다.
   - HP, 목표 타격 수, 공 무게, 콤보 배율을 조합해 간접 조정해야 합니다.

8. **Stage 01의 모든 공에 대한 보스 피해 프로필**
   - 현재 `BossBallDamageWeightRules.tres`에는 `light`, `normal`, `heavy` ID만 등록되어
     있습니다.
   - Stage 01 초기 공의 `gel`과 보상으로 얻는 다른 공 ID는 피해 무게 프로필이 없어
     보스 피해가 0이 될 수 있습니다. 사용할 모든 공 ID를 한 무게 등급 배열에 등록해야
     합니다.

9. **웨이브 2·3 통합 상태로 바로 시작하는 테스트 옵션**
   - 각 웨이브 씬을 F6으로 단독 실행할 수는 있지만 Stage 01이 주입하는 누적 코인·구매
     공·수리 부품 상태와 동일하지 않습니다.
   - 실제 통합 상태 확인은 현재 시작 화면부터 순서대로 진행해야 합니다.

## 변경 후 권장 확인

### 일반 웨이브

1. 수정한 `stage_01_wave_0N.tscn`을 F6으로 실행합니다.
2. 수리 배치 화면에서 영역과 소켓을 확인합니다.
3. 공을 선택하고 발사하여 범퍼 충돌 크기와 위치를 확인합니다.
4. 코인 생성 위치와 획득을 확인합니다.
5. 목표 점수와 기본 점수 반영을 확인합니다.
6. 마지막으로 `start_screen.tscn`을 실행해 Stage 01 전체 흐름을 확인합니다.

### 보스

1. `stage1_teddy_boss_scene.tscn`을 F6으로 실행합니다.
2. 범퍼와 보스 몸체·팔 공격의 겹침을 확인합니다.
3. HUD의 최대 HP와 페이즈 2 전환 HP를 확인합니다.
4. Normal/Heavy 등 서로 다른 공으로 실제 피해량을 확인합니다.
5. 카운터 성공 시 `Parry Counter Multiplier`가 반영되는지 확인합니다.

보스 기능을 빠르게 진단해야 할 때는
`scenes/tests/boss/debug_teddy_boss_wave.tscn`의 디버그 버튼도 사용할 수 있습니다.
