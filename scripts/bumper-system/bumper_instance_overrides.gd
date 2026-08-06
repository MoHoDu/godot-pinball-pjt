@tool
class_name BumperInstanceOverrides
extends Resource


## 음수 값은 공용 BumperSettings 값을 사용한다는 뜻입니다.
## 보드에 놓인 개별 인스턴스에서 필요한 수치만 선택적으로 덮어씁니다.
@export_category("Optional Instance Overrides")
## 이 인스턴스의 기본 점수입니다. -1이면 공용 설정을 사용합니다.
@export_range(-1, 999999, 1) var base_score: int = -1
## 이 인스턴스의 콤보 점수 가중치입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 100.0, 0.05, "suffix:x") var score_weight: float = -1.0
## 이 인스턴스의 최대 내구도입니다. -1이면 공용 설정을 사용합니다.
@export_range(-1, 999, 1) var max_durability: int = -1
## 이 인스턴스의 파괴 후 대기 시간입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 60.0, 0.1, "suffix:s") var respawn_delay: float = -1.0
## 이 인스턴스의 속력 배율입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 3.0, 0.01, "suffix:x") var speed_multiplier: float = -1.0
## 이 인스턴스의 최소 방출 속력입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 5000.0, 1.0, "suffix:px/s") var minimum_release_speed: float = -1.0
## 이 인스턴스의 최대 반응 속력입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 5000.0, 1.0, "suffix:px/s") var maximum_response_speed: float = -1.0
## 이 Shot 인스턴스의 방향 선택 시간입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 5.0, 0.05, "suffix:s") var selection_duration: float = -1.0
## 이 Shot 인스턴스의 고정 발사 속력입니다. 음수이면 공용 설정을 사용합니다.
@export_range(-1.0, 5000.0, 1.0, "suffix:px/s") var launch_speed: float = -1.0
