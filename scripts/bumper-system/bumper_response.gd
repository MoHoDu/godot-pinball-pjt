class_name BumperResponse
extends BallImpactResult


## 전략이 계산한 최종 충돌 반응입니다.
## 공이 이 값을 한 번만 적용하므로 기본 반사와 특수 반응이 중복되지 않습니다.
var source_bumper_id: StringName = &""
var response_tag: StringName = &""
## 충돌 순간의 상대 속력입니다. Deferred 적용에서도 같은 입력으로 계산합니다.
var source_speed: float = -1.0
