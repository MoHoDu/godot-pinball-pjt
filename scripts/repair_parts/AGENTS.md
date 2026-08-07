# Repair Parts System Development Guide

이 문서는 `scripts/repair_parts/`와 연관된 부품 씬, 설정 리소스, 테스트를 수정하는 개발자를 위한 계약 문서입니다.
기준 기획서: 인형사의 수리 부품 시스템 기획서 v0.2 (2026-08-04) + v0.3 수정 사항 (2026-08-07).

## v0.3 수정 사항 (현재 구현 기준)

1. **랭크 시스템 삭제.** `RepairPartRankData`와 `current_rank`가 없습니다. 부품마다 고정 수치 한 벌만 있고, 같은 부품 재획득은 아무 변화도 만들지 않습니다.
2. **초승달 바늘(NEEDLE) 삭제.** 계열은 `BROOCH`(0) / `GEAR`(1) / `BELL`(2) 셋뿐이고 `SECONDARY_STITCH`도 제거했습니다. `crescent_needle` 범퍼 자체는 보드 콘텐츠로 남아 있지만 수리 부품 효과·보상 카드에서는 빠졌습니다.
3. **황금 톱니바퀴 접촉 가속을 배율로.** `gear_contact_multiplier`(기본 x1.15)를 기존 범퍼 `speed_multiplier`와 같은 방식으로 곱합니다. 과회전 추가 가속만 `gear_overdrive_boost`(+180px/s) 절대 가산으로 남겨 두었습니다 — 테스트 후 배율로 전환할 수 있게 필드를 분리해 둔 것입니다.
4. **별빛 브로치.** 제한 시간 6.0초 고정, 이 6.0초가 곧 완성 연출 애니메이션 길이입니다. 완성 타격은 기본 타격의 x3.0 배수(`brooch_finish_multiplier`)로 `register_hit(3.0)` 한 번. '다른 부품 2종' 조건은 브로치 위 별 아이콘 두 개로 표시합니다.
5. **잊혀진 별방울 여운은 정수 콤보.** 접촉 순간의 콤보 횟수를 기준선으로 잡고, 지연 시간 동안 실제로 추가된 콤보 수에 `bell_echo_combo_multiplier`(0.25)를 곱해 반올림한 **정수만큼 콤보를 한 번에 추가**합니다. 1 → +0, 2 → +1. 추가분이 0이면 콤보를 올리지 않고 연출만 끝냅니다.
범퍼 공통 계약은 `scripts/bumper-system/AGENTS.md`를 먼저 읽으세요.

## 도메인 용어

- **수리 부품(Repair Part)**: `BumperSettings.is_repair_part = true`인 표준 범퍼 위에, 합성 노드(`RepairPartRuntime`)와 효과 클래스를 얹은 보드 장착형 장치입니다.
- **계열(Family)**: `BROOCH`(별빛 브로치), `GEAR`(황금 톱니바퀴), `BELL`(잊혀진 별방울). v0.3에서 `NEEDLE`은 삭제되었습니다.
- **PRIMARY**: 공의 실제 물리 접촉으로 생긴 유효 접촉. 오직 PRIMARY만 부품을 발동할 수 있습니다.
- **SECONDARY**: 코드로 생성된 2차 타격(`SECONDARY_ECHO`, `SECONDARY_FINISH`). 다른 부품을 발동하지 못합니다.
- **수리 소켓(RepairSocket2D)**: 기획자가 충돌 안전성을 검증한 장착 지점. 부품은 자유 좌표에 놓지 않습니다.

## 반드시 유지할 계약

1. `RepairPart extends Bumper` 같은 별도 런타임 상속 구조를 만들지 마세요. 부품은 기존 범퍼 씬을 **씬 상속**하고 `RepairPartRuntime` 자식 노드로 확장합니다.
2. 기존 `combo_system.gd`, `combo_hit_source.gd`, `pinball.gd`, `flipper.gd`, `wave_manager.gd`, `bumper.gd`는 수정하지 않습니다. 확장은 상속 스크립트(`RepairPartHitSource`)와 어댑터로만 합니다.
3. 모든 2차 타격은 `RepairEffectRouter.dispatch_secondary`를 거쳐야 하며, `can_trigger_parts = false`로 고정됩니다. 2차 효과가 부품 접촉 신호를 만드는 순간 무한 연쇄 금지 계약이 깨집니다.
4. 톱니 외의 부품은 공의 속도에 영향을 주지 않고, 어떤 부품도 공의 `global_position`·`transform`을 직접 변경하지 않습니다. 톱니 가속은 `RepairBallAdapter`가 `Pinball.get_limited_velocity()`를 거쳐 impulse 한 번으로 적용합니다. **적용 시점은 반드시 범퍼의 최종 충돌 반응 이후**(`Bumper.response_resolved` 경유)여야 합니다 — 접촉 즉시 적용하면 같은 프레임의 지연 반응(`_apply_deferred_physical_response`)이 타격 전 속도로 되돌려 가속이 무효화됩니다.
5. 유효 접촉 조건: 부품 장착·활성 + 접촉 집합에 없는 새 접촉(기존 `Bumper.active_contacts`) + 직전 발동 후 최소 0.12초(`RepairPartHitSource.minimum_trigger_interval`).
6. 장착 정보만 세션 동안 유지합니다. 공 단위 상태(표식·회전 단계·봉합 대기·여운 예약)는 공 낙하/새 발사/웨이브 종료/재시도/재배치에서 모두 초기화합니다 (기획서 9장 표).
7. 보상·인벤토리는 런타임 노드가 아니라 `part_id`(= `bumper_kind_id`)만 저장합니다.
8. 부품 파괴·내구도는 제외 범위입니다. 부품 씬은 `RepairPartBoardOverrides.tres`(max_durability 999)를 유지하세요.

## 주요 구조

| 구성 요소 | 책임 |
|---|---|
| `data/repair_part_definition.gd` | 부품 ID, 계열, 계열별 고정 수치 |
| `runtime/repair_part_hit_source.gd` | ComboHitSource 상속. 0.12초 간격 게이트 |
| `runtime/repair_part_runtime.gd` | 부품 발동 신호, 장착 상태, 표시 상태 |
| `runtime/repair_effect_router.gd` | PRIMARY 라우팅, 2차 타격 단일 통로, 내부 시계 |
| `runtime/repair_session_controller.gd` | WaveManager 신호 구독으로 상태 초기화 |
| `runtime/repair_board_controller.gd` | 소켓 관리, 부품 콤보 바인딩, 새 공 리셋 |
| `runtime/repair_inventory.gd` / `repair_reward_generator.gd` | 수리함, 보상 후보·재추첨 1회 (랭크업 없음) |
| `effects/repair_*_effect.gd` | 계열별 상태 기계 (브로치/톱니/방울) |
| `adapters/repair_combo_adapter.gd` | `ComboSystem.register_hit()` 호출, 여운의 다중 콤보 적립 |
| `adapters/repair_ball_adapter.gd` | 안전 가속 impulse 적용 |
| `ui/repair_part_feedback.gd` | 상태 표시 (금빛 테두리·브로치 별 2개와 6.0초 호·톱니 단계·방울 파동) |

## 테스트

테스트 씬: `tests/repair_parts/repair_parts_v3_board_test.tscn` (기존 웨이브 보드 씬 복제 + 소켓 6개 + 부품 3종). 기존 씬에 프로토타입 노드를 직접 추가하지 마세요.

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/repair_parts/unit/repair_parts_system_test.gd
godot --headless --path . --script res://tests/repair_parts/unit/repair_reward_test.gd
```

부품·콤보·공 관련 변경 후에는 기존 회귀 테스트도 실행하세요.

```bash
godot --headless --path . --script res://tests/bumper_system/bumper_system_test.gd
godot --headless --path . --script res://tests/combo_system/combo_system_test.gd
```

마지막으로 `git diff --check`를 실행하고, `RepairPart` 상속이나 2차 효과의 부품 발동 경로가 다시 도입되지 않았는지 검색하세요.
