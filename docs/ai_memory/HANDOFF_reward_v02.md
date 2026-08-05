# 인계 메모 — 보상 v0.2 세션 종료 (2026-08-05, 브랜치 dev_reward_system)

> 보상 v0.2 작업을 이어받는 AI에게. 구현 상세는 [보상 v0.2 시스템](project_reward_v02.md),
> 코드 컨벤션은 [코드베이스 컨벤션](reference_codebase_conventions.md)을 먼저 읽어라.
> ※ 기존 `HANDOFF.md`는 VFX 세션(다른 작업 흐름)의 인계 메모다. 헷갈리지 말 것.

---

## 0. 반드시 지킬 작업 규칙 (형락님 지정)

1. 씬 테스트는 기존 씬을 **복제한 새 씬**에서 한다.
2. **기존 스크립트는 절대 수정하지 않는다.** 기능 추가는 상속받은 별개 스크립트로.
   (이 세션의 `*V02` 클래스들, 파생 씬의 스크립트 오버라이드가 그 방식이다)
3. 새 채팅 시작 시 프로젝트 구조와 내부 MD를 학습한다.
4. 새로운 산출물·최종본이 생성될 때만 커밋하고, 커밋 시기를 알린다.
5. **커밋 전 반드시 물어본다.** 단, "페이즈 완료 → 오류·UI 재확인 → 이상 없으면
   단계별 커밋 → 다음 페이즈" 루프는 승인돼 있다. **push는 별도 승인 전 금지.**
6. main 브랜치는 절대 수정하지 않는다 (가져오는 머지만 허용).

## 1. 지금 브랜치 상태

- `dev_reward_system`, 작업 트리 클린. **전부 로컬 커밋 — 미푸시.**
- main을 머지해 범퍼 시스템까지 포함된 상태 (b7dadeb). main 자체는 안 건드렸다.
- 이번 세션 커밋 (오래된 것부터):

```
b7dadeb  main+수리부품 머지 (충돌 25건은 전부 main 채택 — 우리 쪽은 CRLF 재저장뿐이었다)
e7fefa8  부품 part_id 통일 (starlight_brooch·golden_gears·crescent_needle·forgotten_star_bell)
4fd2bcb  공 확정본 아트(전용 씬 5종·BallArtLibrary)·상점 카드 아이콘·패널 확장 버그
da58072  수리 부품 배치·소비 (소켓 12·예약→첫 발사 차감→종료 소멸)
db3e126  웨이브 전환 시 콤보 점수 리셋 (진입 즉시 클리어 버그)
9e3569d  공 보유 모델 v0.2 (생명 3 풀 공유·무제한 재선택·해금 실패 코인 롤백)
d888062  생명 슬롯 유령 자식 수정
aa686dc  StageEntrySnapshot·restore_unlocked
168ffd9  실패 롤백(스냅샷 통복원+웨이브1 재시작)·클리어 정산
86ea137  카드 5상태·상세 확인 안내
a1a0bdf  발사 준비 UI 보유 종류·계열·장점·대가
f7d91fe  인계 문서(project_reward_v02.md)
fdf5e26  보스 직전 보상 보장 (§6-2, required_partner_kinds)
fc92c58  상점 보유 요약·조합 부족 안내 (§5-1·§6-4)
3ad6c78  발사 중 '다음 발사에서 공 변경 가능' 안내 (§7-2)
c0dadcb  유예 타임아웃 경로 테스트 (§3-2)
```

## 2. 검증 상태

- 헤드리스 테스트 **22본 전부 PASS** 상태로 정지했다.
- 엔진: `C:\Users\robot\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
- 실행: `godot --headless --path . --import` 후
  `godot --headless --path . --script res://tests/<시스템>/<이름>_test.gd`
- 씬 테스트가 멈추면 프레임 대기 무한루프다 — `timeout`을 걸고 돌려라.

## 3. 다음 순번 후보 (남은 일)

1. **메인 씬 승격** — project.godot 메인 씬을 `wave_repair.tscn`으로 바꿀지
   **팀 결정 대기**. 팀 공용 설정이라 임의로 바꾸지 말 것.
2. **push** — 형락님 승인 후에만.
3. 부품 카드 실루엣(§5-3) — 부품 아트 리소스 대기.
4. 물리 등급 5단계(§5-2·§7-2) — 기획 수치 원본이 없다. 강보현 님 확인 필요.
5. `wave_coin_earned` 단일 합산 신호(§3-3) — 소비처가 생기면 추가.
6. §10-2 권장 데이터 구조 명명 정합(RewardEconomyData 등) — 세이브 기능 붙일 때.
7. **범퍼 배치 시스템은 다른 프로그래머 담당** — 절대 만들지 말 것
   (이 세션에서 두 번 만들었다 제거했다). 합류 시
   `WaveRepairCoordinator`의 `wave_entered` 훅에 연결만 하면 된다.

## 4. 밟기 쉬운 지뢰 (실측)

1. **유령 자식**: `queue_free()`만 하면 다음 프레임까지 자식으로 남아
   최소 크기·이름·개수 검증에 섞인다. UI/보드 재구성은 `remove_child()` 먼저.
   (상점 패널·생명 슬롯에서 실제 버그였다)
2. **웨이브 전환 점수**: `enter_wave()`는 콤보 점수를 리셋하지 않는다.
   전환 전에 `combo_system.reset_wave()`를 불러야 진입 즉시 클리어가 안 난다.
3. **콤보 정산 시점**: 점수는 `register_hit()`이 아니라 콤보 정산(낙하 또는
   `finish_combo`)에 반영된다. 테스트에서 목표 달성시키려면 정산까지 할 것.
4. **wave.tscn 기본값**: `wave_stage_index = 2`(웨이브3 시연), 정적 범퍼 6종은
   웨이브 0 로드아웃과 안 맞는다. 파생 씬은 index 0 + 관대 로드아웃
   (`WaveShopBumperLayout_Demo.tres`)을 쓴다.
5. **part_id는 수리부품 시스템과 통일됨** — 카탈로그에서 임의 변경 금지.
6. 상속 체인: `WaveRuntime → Reward → Coin → Shop → ShopBall → Repair`.
   새 기능은 `WaveRepairCoordinator`를 상속하거나 그 위에 얹어라.
