---
name: repair-parts-system
description: 수리 부품 시스템 MVP 구현 (2026-08-04) — 범퍼 합성 구조, 4계열 효과, 검증 상태
type: project
---

# 수리 부품 시스템 (2026-08-04 구현)

기획서: 인형사의 수리 부품 시스템 기획서 v0.2 (26쪽). 브랜치 `dev/bumper_reapair`.

## 구조 결정

- 수리 부품 = **기존 범퍼 씬을 씬 상속** + `RepairPartRuntime` 자식 노드 합성.
  [[bumper-system]] AGENTS.md 계약(RepairPart 상속 금지, is_repair_part 단일 출처) 준수.
- 기존 스크립트·씬 무수정. 확장은 `RepairPartHitSource extends ComboHitSource`(0.12s 간격 게이트),
  어댑터 2종(`ComboSystem.register_hit` / `Pinball.get_limited_velocity`)으로만.
- PRIMARY(물리 접촉)만 부품 발동. 2차 타격(봉합·여운·완성)은 `RepairEffectRouter.dispatch_secondary`
  단일 통로로 `can_trigger_parts = false` 고정 → 재귀 차단.
- `wave_runtime_coordinator.get_bumpers()`는 `Bumpers` 노드 자식만 보므로, 부품은
  `RepairPartSystem/Sockets` 서브트리에 두면 기존 로드아웃 검증과 충돌하지 않는다.
  대신 콤보 바인딩·새 공 리셋은 `RepairBoardController`가 별도로 한다.

## 파일 위치

- 스크립트: `scripts/repair_parts/` (data/runtime/effects/adapters/ui) + AGENTS.md
- 설정: `settings/repair_parts/` (부품 정의 4종 = 랭크 3단 수치, 소켓 정의 6종, 내구도 999 오버라이드)
- 씬: `scenes/repair_parts/parts/` 4종, `scenes/repair_parts/sockets/repair_socket_2d.tscn`
- 테스트: `tests/repair_parts/` (wave.tscn 복제 보드 씬 + 단위 테스트 2본)

## 검증 상태

- 대화 기록 없는 독립 검증 에이전트 2회 검토 완료.
  - 1차에서 치명 결함 1건 발견·수정: **톱니 가속을 접촉 즉시 적용하면 같은 프레임의
    범퍼 지연 반응(`_apply_deferred_physical_response`)이 타격 전 속도로 되돌린다.**
    → 가속은 `Bumper.response_resolved` 이후에만 합성 (repair_gear_effect의 pending 구조).
  - 2차에서 A-1 해소 판정. 테스트 어서션 결함(B-1)·검출력(B-2)·표시값(B-3)까지 수정 완료.
- gdparse 정적 검사 통과. **엔진 실행 미완** — 컨테이너에 Godot 없음 [[godot-install-blocked]].
- 로컬 실행 필요:
  `godot --headless --path . --import` 후
  `res://tests/repair_parts/unit/repair_parts_system_test.gd`,
  `res://tests/repair_parts/unit/repair_reward_test.gd`,
  기존 bumper/combo 회귀 테스트.

## 미결

- 보상 선택 UI(카드)·시작 부품 선택 UI — 로직(`RepairInventory`/`RepairRewardGenerator`)만 존재.
- repair_parts .tres 4종의 `mechanics_status`는 CONCEPT_ONLY 유지 중. **런타임 검증 통과 후**
  IMPLEMENTED 전환을 별도 작업으로 제안할 것 (기존 리소스 수정이므로 승인 필요).
- 보스전 소켓 비활성화는 API(`set_boss_phase`)만 있고 보스 시스템 미연결.
