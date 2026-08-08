# SFX 설정

메뉴 경로: `Pinball > Game Settings > Sfx`

- `SfxDirectorRules.tres`: 전체 동시 재생 수, 우선순위별 예약 수·상한, 출력 버스
- `BallFlowSfxRules.tres`: 공 선택·발사·낙하음과 속력 범위
- `FlipperSfxRules.tres`: 선택·작동·복귀·타격·패링음
- `BumperSfxRules.tres`: 범퍼 종류별 재질음, 파괴·재생성·대포음
- `ComboSfxRules.tres`: 콤보 상승·단계·종료·웨이브 결과음
- `BossSfxRules.tres`: 보스 공격·피격·페이즈·처치음
- `WallSfxRules.tres`: 저·중·고속 벽 충돌음

Cue의 스트림 배열, 볼륨, 피치, 속도 구간을 확인합니다. 패링과 보스처럼 중요한 소리가 벽 충돌음에 묻히지 않도록 Director의 예약 수와 우선순위를 유지하세요. 설정 팝업의 세부 SFX 슬라이더를 움직여 샘플 음량을 확인할 수 있습니다.
