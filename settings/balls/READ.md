# 공 공통 설정

메뉴 경로: `Pinball > Game Settings > Balls`

- `PinballPhysicsRules.tres`: 모든 공에 적용되는 무게·탄성·속력·중력 허용 범위
- `PinballLaunchRules.tres`: 조준 각도 변화 속도와 발사 속력 조절 속도
- `BallGazeRules.tres`: 눈동자가 진행 방향을 따라가는 임계 속도와 반응 속도
- `BallGlowOutlineRules.tres`: 기본 발광 외곽선 규칙
- `BallTrailRules.tres`: 기본 이동 꼬리 규칙

공 개별 프리팹 값은 이 공통 허용 범위 안으로 제한됩니다. 공이 너무 빠르거나 무거운 문제는 개별 프리팹과 이 폴더 값을 함께 확인하세요. 변경 후 `scenes/tests/balls/test_ball_physics.tscn`에서 저속·고속 움직임을 확인합니다.
