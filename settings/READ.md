# 게임 설정 리소스 안내

이 폴더의 `.tres`는 코드 수정 없이 수치·리소스 연결을 바꾸기 위한 Godot Inspector 설정입니다.

## 여는 방법

1. Godot 상단 메뉴에서 `Pinball > Game Settings`를 엽니다.
2. 기능 폴더를 고른 뒤 설정 이름을 클릭합니다.
3. Inspector에서 값을 수정하고 `Ctrl/Cmd + S`로 저장합니다.

파일시스템 독에서 `.tres`를 직접 더블클릭해도 같은 Inspector가 열립니다. 새 설정을 만들 때는 기존 파일을 복제하고 ID와 참조 프리팹을 먼저 바꾸는 것이 안전합니다.

## 폴더 구분

- `balls`, `flippers`, `combo`: 공·플리퍼·점수 규칙
- `bumpers`, `repair_parts`: 범퍼와 장착 부품
- `bosses`: 보스 체력·공격·피드백
- `coin`, `reward`, `reward_shop`: 재화와 보상
- `ambient_vfx`, `sfx`: 화면 및 사운드 연출

각 하위 폴더의 `READ.md`에 주요 항목과 확인 방법이 적혀 있습니다. 경로를 옮겨도 Godot 리소스 UID가 유지되도록 반드시 Godot FileSystem 독에서 이동하세요.
