@abstract
class_name BumperResponseStrategy
extends Resource


## 범퍼와 공을 직접 변경하지 않고 최종 반응 값만 생성합니다.
@abstract
func build_response(
	context: BallImpactContext,
	bumper: Node
) -> BumperResponse

