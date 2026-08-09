class_name PopNormalResponseStrategy
extends NormalResponseStrategy
## Normal 반사를 유지하되 설정의 minimum_release_speed를 하한으로 적용해
## 느린 공도 일정 속도 이상으로 튕겨 나가게 한다 (탱탱볼 보정).
##
## NormalResponseStrategy는 minimum_speed를 0으로 고정하므로 느리게 닿은
## 공이 힘없이 떨어진다. 이 확장은 그 한 줄만 보강한다 — response_tag가
## "normal" 그대로라 SFX/VFX 분기와 로드아웃 타입 분류에는 영향이 없다.
## (2026-08-09 형락님 지시. 기존 전략 스크립트는 수정하지 않았다.)


func build_response(
	context: BallImpactContext,
	bumper: Node
) -> BumperResponse:
	var response := super.build_response(context, bumper)
	response.minimum_speed = float(bumper.call(&"get_minimum_release_speed"))
	return response
