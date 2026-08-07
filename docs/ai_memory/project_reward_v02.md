---
name: reward-v02-system
description: 보상 구매·코인·수리부품 배치 시스템 v0.2 구현 현황 — 씬 구성, 조작키, 테스트, 미결 사항
type: project
---

# 보상 v0.2 시스템 (2026-08-05 구현)

기획서: 「보상 구매·코인·수리 부품 배치 시스템 기획서 v0.2」(강보현, 2026-08-04).
브랜치 `dev_reward_system`. 확인용 씬 **`scenes/wave/wave_repair.tscn`** (독립형 wave.tscn 상속).

## 시스템 구성 (코디네이터 상속 체인)

```
WaveRuntimeCoordinator (main 독립형)
 └ WaveRewardCoordinator   유물 3택1(구) + 이벤트 로그 + G키 즉시 클리어
    └ WaveCoinCoordinator  코인 12×2·종료 유예 3초·점수 환산(§3)
       └ WaveShopCoordinator      보상 상점(§4~6) — 유물 대체, C키 코인 채우기
          └ WaveShopBallCoordinator  공 해금(§7 기초)
             └ WaveRepairCoordinator  부품 배치(§8~9)·공 모델 v0.2(§7)·롤백(§10)
```

기존 스크립트·씬은 무수정 — 전부 상속(`*V02`)·신규 파일·씬 오버라이드로 얹었다.

## 기획서 대비 구현 상태

- §3 코인·유예: 완료 (환산식·신호 이름까지 일치, 타임아웃 경로 포함 테스트 4본)
- §5-1 보유 정보: 완료 — 상점 헤더에 보유 공 목록·부품 종류별 재고 표시
- §6-2 보스 직전 보상 보장: 완료 — `RepairPartOffer.required_partner_kinds`
  (브로치 2·바늘 1) 기준으로 보유 부품과 결합해 발동 가능한 카드 1장 이상 보장
- §6-4 조합 부족 안내: 완료 — `reward_offers_generated.affordable_pair`를 소비해
  "공+부품을 모두 살 코인이 부족합니다" 표시
- §7-2 잠금 안내: 완료 — 발사 중 "다음 발사에서 공 변경 가능" 표시
- §4~6 상점: 완료 — 가격표·후보 생성 규칙·18코인 가드·카드 5상태(5-4)·상세 확인 단계
- §7 공 모델: 완료 — 기본 공 1종 × 생명 3, 해금 공은 생명 풀 공유·무제한 재선택
  (`WaveBallInventoryV02`·`StageBallInventoryV02`), 해금 실패 시 코인 롤백,
  `ball_selected` 신호. ※ 물리 등급 5단계(7-2)는 데이터 원본이 없어 계열·장점·대가만 표시
- §8~9 부품 배치: 완료 — 소켓 12개(하4·중4·상4, 예약반경 72px)·동시 6개·
  예약 → 첫 발사 차감 → 웨이브 종료 소멸. `repair_layout_committed` 신호
- §10 롤백: 완료 — `StageEntrySnapshot`(코인·해금 공·부품), 실패 시 통복원 후
  웨이브 1 자동 재시작, `stage_state_rolled_back` 신호, 클리어 시 코인 0·부품 이월

## 확인용 조작키 (wave_repair.tscn 우측 상단에도 표시됨)

C 코인 999 · G 즉시 클리어 · 공 선택 A/D · Space 조준→발사 ·
클리어 B/계속 V · 상점 A/D·Space(선택→구매)·B 진행 · 배치 Q/E 소켓·1~4 예약·X 해제

## 밟기 쉬운 지뢰

1. **유령 자식 패턴**: `queue_free()`만 하면 다음 프레임까지 자식으로 남아
   최소 크기 계산·이름·개수 검증에 섞인다. UI 재구성·보드 갈아끼우기는
   `remove_child()` 후 `queue_free()`. (상점 패널·생명 슬롯에서 실제로 두 번 밟음)
2. **웨이브 전환 점수 리셋**: `enter_wave()`는 콤보 점수를 리셋하지 않는다.
   이전 점수가 남으면 목표 재달성 판정으로 진입 즉시 클리어된다.
   상점 진행 시 `combo_system.reset_wave()`를 먼저 부른다.
3. **wave.tscn은 `wave_stage_index = 2`**(웨이브3 시연용)라 파생 씬에서 0으로
   되돌려야 하고, 정적 범퍼 6종은 웨이브 0 로드아웃과 안 맞아
   `WaveShopBumperLayout_Demo.tres`(관대 로드아웃)를 물린다.
4. **part_id는 수리부품 시스템과 통일됨** (`starlight_brooch`·`golden_gears`·
   `crescent_needle`·`forgotten_star_bell`). 카탈로그에서 임의로 바꾸지 말 것.

## 담당 구분·미결

- **웨이브별 범퍼 배치는 다른 담당자 구현 중** — 여기서는 다루지 않는다.
  합류 시 `WaveRepairCoordinator`의 `wave_entered` 훅에 연결하면 된다.
- 메인 씬(project.godot)은 아직 `wave.tscn` — 정식 승격은 팀 결정 필요.
- 소켓·코인 좌표는 자리표시자. 레벨 디자인 조정 대상.
- 부품 카드 실루엣(5-3)은 부품 아트 대기, 물리 등급 5단계(5-2·7-2)는
  기획 수치 원본이 없어 계열·장점·대가 표시로 대체 중 — 강보현 님 확인 필요.

## 테스트 (헤드리스, 전부 PASS 상태로 커밋)

```
godot --headless --path . --script res://tests/reward_shop/wave_repair_flow_test.gd
```
- coin_system 3본 / reward_shop 7본(core·stage_ball·shop flow·shop_ball flow·
  repair flow·ball model v02·stage rollback) / reward_system 4본 / repair_parts 2본
