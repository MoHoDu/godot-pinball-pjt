# Bumper System Development Guide

이 문서는 `scripts/bumper-system/`과 연관된 범퍼 프리팹, 설정 리소스, 테스트를 수정하는 개발자를 위한 계약 문서입니다.

## 도메인 용어

- **범퍼(Bumper)**: 공과 충돌하고 점수, 내구도, 파괴, 안전 복구, 최종 반응을 처리하는 런타임 객체입니다.
- **범퍼 타입(BumperType)**: `NORMAL`, `BOUNCE`, `TRACK`, `SHOT`처럼 공과 충돌했을 때의 기능을 구분합니다.
- **수리 부품(Repair Part)**: 범퍼의 하위 클래스나 별도 종류가 아닙니다. 플레이어가 스테이지 보상으로 획득하고, 인벤토리에 보유하고, 보드에 직접 배치할 수 있는 범퍼를 뜻합니다.
- **수리 부품 자격**: `BumperSettings.is_repair_part`에 저장합니다. 범퍼 타입, 충돌 전략, 인스턴스 밸런스와 독립적입니다.

## 반드시 유지할 계약

1. `RepairPart extends Bumper` 같은 별도 런타임 상속 구조를 다시 만들지 마세요.
2. `RepairPartKind`처럼 수리 부품만을 위한 별도 범퍼 종류 열거형을 만들지 마세요.
3. 수리 부품 여부는 `BumperSettings.is_repair_part`에서만 관리하세요.
4. `BumperInstanceOverrides`에 수리 부품 여부를 추가하지 마세요. 보상 자격은 같은 범퍼 종류의 모든 인스턴스에서 안정적이어야 합니다.
5. `is_repair_part = true`는 다음 세 권한을 하나의 도메인 계약으로 의미합니다.
   - 스테이지 보상으로 획득 가능
   - 플레이어 인벤토리에 보유 가능
   - 플레이어가 보드에 직접 배치 가능
6. `bumper_kind_id`는 보상, 인벤토리, 배치 시스템이 공유하는 안정적인 식별자입니다. 출시된 ID를 파일명 변경에 맞춰 임의로 바꾸지 마세요.
7. 수리 부품 자격이 물리 반응, 점수, 내구도, 시각 스타일을 자동으로 변경해서는 안 됩니다.
8. 범퍼의 최종 충돌 반응은 한 번만 적용해야 합니다. Godot 기본 반사와 커스텀 반사를 중복 적용하지 마세요.
9. 실제 물리 접촉 한 번에는 유효 타격을 한 번만 등록하고, 실제 분리 후에만 같은 공의 재타격을 허용하세요.

## 주요 구조

| 구성 요소 | 책임 |
|---|---|
| `bumper.gd` | 접촉 중복 제거, 점수 신호, 내구도, 상태 전이, 안전 복구, 최종 반응 적용 |
| `bumper_settings.gd` | 세 설정 리소스를 묶어 보상·저장 시스템에 제공하는 호환 계약 |
| `bumper_object_settings.gd` | 크기, 충돌, 안전 여백, 배치 제한, 실제 그래픽 Texture와 표현 리소스 |
| `bumper_common_settings.gd` | 범퍼 정체성, 수리 부품 자격, 점수, 내구도, 복구 |
| `bumper_type_settings.gd` | Normal, Bounce, Track, Shot 타입별 동작 설정 |
| `bumper_instance_overrides.gd` | 보드에 배치된 특정 인스턴스의 선택적 밸런스 덮어쓰기 |
| `bumper_response_strategy.gd` | 충돌 반응 전략의 추상 계약 |
| `normal_response_strategy.gd` | 기본 물리 반사 방향을 유지하면서 속력 배율 적용 |
| `bounce_response_strategy.gd` | 배율과 최소 방출 속력을 적용 |
| `shot_response_strategy.gd` | 선택 방향과 고정 발사 속력 계산 |
| `shot_bumper.gd` | 공 포획, 방향 선택, 발사, 안전 이탈 처리 |
| `shot_launch_anchor.gd` | Inspector 배열에서 추가·삭제하는 Shot 발사 방향 데이터 |
| `bumper_test_controller.gd` | Inspector 범퍼 목록, 낙하 테스트, 입력, 상태 HUD |

`ShotBumper`는 공 포획과 입력 제어라는 고유 런타임 상태가 있으므로 `Bumper`의 하위 타입입니다. 수리 부품 자격 때문에 하위 타입인 것은 아닙니다.

## 설정 계층

공용 설정은 `settings/bumpers/`의 `BumperSettings` `.tres`에서 관리합니다.

```text
범퍼 루트 Inspector
├─ Object Settings → BumperObjectSettings
│  ├─ 외형·충돌 크기
│  ├─ 안전 복구 여백·배치 제한
│  └─ 실제 그래픽 Texture·맞춤 비율·표현 리소스
├─ Common Bumper Settings → BumperCommonSettings
│  ├─ ID·이름·수리 부품 자격
│  ├─ 기획 상태
│  └─ 점수·내구도·복구
└─ Type Settings → BumperTypeSettings
   ├─ Normal / Bounce 반응 수치
   ├─ Track 목표 위치
   └─ Shot 선택 시간·발사 속력·발사 방향 배열
```

`BumperSettings`는 위 세 리소스를 묶어 보상·저장 시스템에 제공하지만 범퍼 노드
Inspector에는 직접 표시하지 않습니다. 편집자는 반드시 범퍼 루트의 세 설정 슬롯을
각각 펼쳐 수정합니다.

Shot 발사 방향은 씬 자식 노드가 아니라 `BumperSettings.shot_launch_directions`의
`ShotLaunchAnchor` 리소스 배열로 관리합니다. Inspector 배열에서 항목을 추가·삭제하고,
각 항목의 표시 이름, 안전 기본 여부, 발사 위치를 수정하세요. 방향별 입력 액션은
지정하지 않습니다. 런타임에서는 `Left` / `Right`로 배열의 모든 방향을 순환하므로
방향 개수에 제한이 없습니다.

실제 범퍼 이미지는 `BumperObjectSettings.graphic_texture`에 지정합니다. 이미지는
`visual_diameter × graphic_size_ratio` 안에 원본 비율을 유지해 직접 그리며, 범퍼 루트의
`scale`과 물리 충돌 Shape는 변경하지 않습니다. Texture가 비어 있을 때만 기존 더미
도형을 표시합니다.

Shot 방향을 추가할 때는 `Type Settings`의 `발사 방향 추가` 버튼을 사용합니다. 별도
리소스 파일을 만들 필요가 없습니다. Shot 범퍼 루트가 선택된 상태에서 2D 화면의 원형
핸들을 드래그하면 `release_position`과 발사 각도가 함께 갱신됩니다. 초록색 핸들은 안전
기본 방향이고 하늘색 핸들은 일반 방향입니다.

특정 씬 인스턴스만 조정할 때는 `BumperInstanceOverrides`를 사용합니다. 음수 값은 공용 `BumperSettings` 값을 사용한다는 뜻입니다.

## 보상 시스템 연동 계약

보상 시스템은 범퍼 노드를 인스턴스화하지 않고 스테이지 보상 테이블에 저장된 `BumperSettings`를 검사할 수 있어야 합니다.

```gdscript
var candidates: Array[BumperSettings] = []

for settings: BumperSettings in stage_reward_table:
	if settings.is_repair_part:
		candidates.append(settings)
```

동일한 의미의 공개 API가 필요하면 `settings.is_reward_candidate()`를 사용할 수 있습니다. 보상 지급과 인벤토리 저장에는 `settings.bumper_kind_id`를 사용하세요.

보상 테이블이나 인벤토리가 런타임 `Bumper` 노드를 직접 소유하지 않도록 하세요. 데이터 리소스와 안정적인 ID를 저장하고, 실제 보드 배치 시 프리팹을 인스턴스화하는 구조를 권장합니다.

## 현재 데이터 상태

- `settings/bumpers/stage_01/`의 Stage 01 범퍼 5종은 현재 `is_repair_part = false`입니다.
- `settings/bumpers/repair_parts/`의 콘셉트 범퍼 4종은 `is_repair_part = true`입니다.
- 콘셉트 범퍼 4종은 모두 표준 `Bumper` 프리팹이며 별도 RepairPart 클래스가 없습니다.
- 콘셉트 고유 효과가 확정되지 않은 리소스는 `mechanics_status = CONCEPT_ONLY`를 유지하세요.

## 새 범퍼 추가 절차

1. `settings/bumpers/` 아래에 `BumperSettings` 리소스를 만듭니다.
2. 중복되지 않는 `bumper_kind_id`를 지정합니다.
3. `bumper_type`과 반응 전략에 필요한 수치를 설정합니다.
4. 보상·보유·직접 배치가 가능한 범퍼라면 `is_repair_part = true`로 설정합니다.
5. 외형은 `BumperPresentationSettings`로 별도 구성합니다. 수리 부품 여부로 외형을 분기하지 마세요.
6. 일반 범퍼는 `scenes/bumper_system/bumper_base.tscn`을 상속합니다.
7. 공 포획과 방향 선택이 필요한 Shot 범퍼는 `ShotBumper` 구조를 사용합니다.
8. `scenes/bumper_system/bumper_test.tscn` 루트의 Inspector `Bumper Scenes` 배열에 프리팹을 추가합니다.
9. `tests/bumper_system/bumper_system_test.gd`에 설정, 전략, 자격, 고유 ID 테스트를 추가합니다.

## 범퍼 테스트 실험실

테스트 씬: `scenes/bumper_system/bumper_test.tscn`

| 입력 | 기능 |
|---|---|
| `Left` / `Right` 또는 `A` / `D` | Inspector 목록의 범퍼 선택 |
| `Space` / `Enter` | 선택한 범퍼 위에서 공 낙하 시작 |
| `R` | 같은 범퍼를 새 범퍼·새 공 인스턴스로 즉시 재시작 |
| 캐논 제어 중 `Left` / `Right` 또는 `A` / `D` | 모든 발사 방향을 이전 / 다음 순서로 선택 |
| 캐논 제어 중 `Space` | 선택 방향으로 발사 |

HUD의 `REPAIR PART` 항목에서 현재 범퍼의 보상·보유·배치 자격을 확인할 수 있습니다.

## 필수 검증

범퍼 변경 후 최소한 다음 테스트를 실행하세요.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless \
	--path . \
	--script res://tests/bumper_system/bumper_system_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless \
	--path . \
	--script res://tests/bumper_system/bumper_physics_integration_test.gd
```

관련 시스템을 변경했다면 공 물리와 콤보 회귀 테스트도 실행하세요.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless \
	--path . \
	--script res://tests/ball_base_system/pinball_bounce_regression_test.gd

/Applications/Godot.app/Contents/MacOS/Godot --headless \
	--path . \
	--script res://tests/combo_system/combo_system_test.gd
```

Godot 실행 시 macOS 인증서 조회 경고나 기존 shader custom sampler 경고가 출력될 수 있습니다. 종료 코드, `PASS`, `SCRIPT ERROR`, `Parse Error`, `FAIL`을 기준으로 실제 실패를 판별하세요.

마지막으로 `git diff --check`를 실행하고, 범퍼 변경에 `RepairPart` 상속이나 전용 Kind가 다시 도입되지 않았는지 검색하세요.
