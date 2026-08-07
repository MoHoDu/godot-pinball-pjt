# MEMORY

Pinball_Logue (NAN AI 해커톤, 팀 Hire us Pls) 프로젝트 메모리.
스냅샷 시점 **2026-08-03** — 공 SFX 파일럿 ① 형태 단계 완료, 형락님 검수 대기.

## 먼저 읽을 것 (순서대로)

1. ★ [인계 메모 HANDOFF](HANDOFF.md) — **이어받는 사람은 이것부터.** 이번 세션에 한 일 / 밟기 쉬운 지뢰 3개 /
   지금 걸려 있는 것 / 다음 순번(VFX ③ 패링 파동) / 엔진 테스트 명령어
2. [Pinball_Logue 프로젝트](project_pinball_logue.md) — 컨셉·비주얼 방향·스펙 수치·현재 진척 요약
3. [작업 진행 규칙](feedback_workflow.md) — **승인 없이 산출물 만들지 않는다.** 계획 → 승인 → 실행
4. [3단계 파이프라인](feedback_staged_pipeline.md) — 아트·VFX·SFX 전부 형태 → 텍스처 → 디테일. 단계마다 검수
5. [Godot 설치 차단](reference_godot_install_blocked.md) — 컨테이너에 엔진을 못 받는다. 엔진 없이 하는 대체 검증 목록

## 규칙 · 피드백

- [작업 진행 규칙](feedback_workflow.md) — 승인 없이 산출물 만들지 않기, 확정된 작업 순서
- [3단계 파이프라인](feedback_staged_pipeline.md) — 형태 → 텍스처 → 디테일. 도메인별로 AI가 맡는 범위 표 포함
- [테스트 반드시 실행](feedback_run_tests.md) — 실행 검증 원칙·스테이징 캐시 함정 ※ 설치 가능 여부는 아래 문서가 최신
- [프롬프트 화풍 이탈 주의](feedback_prompt_style_drift.md) — 레퍼런스에서 팔레트만 가져오고 렌더링 방식은 가져오지 않는다

## 레퍼런스

- [Godot 설치 차단](reference_godot_install_blocked.md) — 릴리스 에셋 호스트 막힘. 엔진 없이 하는 검증 목록
- [아트 파이프라인](reference_art_pipeline.md) — Leonardo/GPT/Canva 툴 체인과 리소스 검수 통과 기준
- [코드베이스 컨벤션](reference_codebase_conventions.md) — 폴더·코드 스타일·연출 노드 패턴·테스트 형식, GL Compatibility 제약
- [테스트 씬 조작키](reference_test_scene_controls.md) — 공 종류 전환 1~7, 패링 모드 0~3. **VFX 검수는 여기서 한다**
- [경로 대소문자 문제](reference_path_case_issue.md) — `res://resources` 소문자 참조 17곳, Linux/macOS 익스포트 시 전부 깨짐

## 공

- [공 텍스처 확정](project_ball_texture_fixed.md) — `glass_eye_ball.png` 하나만. 새 이미지는 **채움률 100%** 부터 확인
- [공 리디자인 v6](project_ball_v6_redesign.md) — 원안 회귀·확정. 축 눈 47px vs 공 44px, 구분은 "링 vs 초승달" 덩어리 구조로만 갈린다
- [보상 공 5종](project_ball_reward_variants.md) — 껍질은 확정본 재사용, 홍채·동공만 공별. Leonardo는 홍채 질감에만
- [공 캣츠아이 리소스](project_ball_glass_eye.md) — ※ **2026-08-03 폐기.** 이력 문서로만 읽을 것

## VFX

- [공 VFX 3종](project_vfx01_ball_trail.md) — 테두리·꼬리·파동 공통 규격과 시그널 연결 지점
- [VFX ① 안개 오라](project_vfx01_mist_aura.md) — Line2D 링 → 셰이더 안개. 외곽 40px 확정, llvmpipe 셰이더 검증법
- [VFX ② 이동 꼬리](project_vfx02_trail.md) — 2겹 레이저+블룸, 길이 140px / 레이저 9px / 블룸 60px. 두께 3배는 시도 후 롤백
- ③ 패링 원형 파동 — **미착수.** 규격은 `project_vfx02_trail.md` 마지막 절

## SFX

- [공 SFX 파일럿](project_sfx01_ball_pilot.md) — AI 사운드는 최소 0.5초라 어택을 못 만든다. 어택·길이는 절차적, AI는 재질음만

## 범퍼 · 수리 부품

- [수리 부품 시스템](project_repair_parts_system.md) — 범퍼 합성 구조로 4계열 구현(2026-08-04). 엔진 테스트는 로컬에서 미실행
- [범퍼 아트 리소스](project_bumper_art_resources.md) — STEP1 형태 확정(2026-08-05). **아트 대상 6종 · 이미지 7장 · 인게임 존재 5종**(기차 취소, 용수철 인형만 2프레임, 미끄럼틀 슬롯 없음). 범퍼에는 **텍스처 슬롯 자체가 없다**
- [수리 부품 아트](project_repair_parts_art.md) — 3종 기본 상태 완료(2026-08-06). **초승달 바늘은 기획서 취소인데 코드엔 구현돼 있다.** 진행 표시는 코드가 그리니 그림에 굽지 말 것
- [범퍼·수리 부품 VFX 최종본](project_bumper_vfx_final.md) — **2026-08-07 최종. 태그 `art/vfx-final-20260807`.** 병합 시 이 목록의 파일은 `resource/art` 가 최신이다. 최신 여부를 가르는 자기검증 3개가 안에 있다

## 보드 · 벽

- [보드 스펙](project_board_spec.md) — 기준 캔버스 2240×1260 월드유닛, 두 보드 정점 좌표, 플리퍼 크기 3종 충돌
- [보드 3단계 파이프라인](project_board_step_pipeline.md) — 실루엣은 AI에 안 맡기고 마스크로 확정, 여백판 기법
- [보드 텍스처 방향](project_board_texture_direction.md) — 슬레이트 블루 `#2E3A47`, 플리퍼에 화풍 맞추기, 가져오면 안 되는 것 목록
- [벽 최종 리소스](project_wall_final_resource.md) — 톤다운 아이보리 프레임 확정·게임 적용 완료. 모듈 생산 파이프라인과 검증 결과
