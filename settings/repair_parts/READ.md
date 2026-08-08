# 수리 부품 정의

메뉴 경로: `Pinball > Game Settings > Repair Parts`

`*Definition.tres`는 부품 ID, 표시 이름, 연결 범퍼 종류, 설명과 고유 효과 수치를 정의합니다. `RepairPartBoardOverrides.tres`는 장착된 부품이 보드에서 덮어쓸 값을 모읍니다.

- 브로치: 연계 방문 수, 제한 시간, 완성 배율
- 톱니: 회전 유지 시간, 접촉 가속, 과회전 스택
- 방울: 메아리 지연, 쿨다운, 콤보·점수 배율

부품 ID는 보상 상점, 범퍼 설정, 프리팹 매핑에서 동일해야 합니다. 시작 보유 수량은 이 폴더가 아니라 `stage_01.tscn > StageFlowManager > Initial Inventory`에서 설정합니다.
