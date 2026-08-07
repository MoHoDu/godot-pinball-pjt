class_name RewardBallFlowController
extends SelectBallFlowController


## 보상 v0.2 의 생명 풀 모델에 맞춘 공 흐름 컨트롤러입니다. (기획서 7장)
##
## main 의 SelectBallFlowController 는 "종류당 1회 사용" 모델이라, 발사에 성공하면
## SelectBallInventory.mark_ball_used() 로 그 종류를 이번 웨이브에서 소진 처리합니다.
## 보상 v0.2 는 반대로 종류를 몇 번이든 다시 고를 수 있고 생명 풀에서만 1씩 깎습니다.
##
## 두 모델은 인벤토리 계약이 서로 달라서(SelectBallInventory vs WaveBallInventoryV02)
## 부모의 소진 처리가 그대로는 걸리지 않습니다. 소모 시점(발사 성공 직후)은 부모와
## 똑같이 두고, 소모 대상만 v0.2 인벤토리의 생명 풀로 바꿉니다.
## 기존 스크립트는 수정하지 않고 이 상속 스크립트만 reward 씬에서 씁니다.


func _on_ball_launched(
	launched_ball: Pinball,
	direction: Vector2,
	speed: float
) -> void:
	var v02_inventory := inventory as WaveBallInventoryV02
	if v02_inventory == null:
		# v0.2 인벤토리가 아니면 main 의 종류 소진 모델을 그대로 따른다.
		super(launched_ball, direction, speed)
		return

	if _state != State.AIMING or launched_ball != active_ball:
		return

	var launched_definition := _confirmed_definition
	_confirmed_definition = null
	if launched_definition != null:
		var consumed := v02_inventory.consume_selected_ball()
		if consumed == null:
			push_error("발사한 공을 생명 풀에서 차감하지 못했습니다.")

	_set_state(State.IN_PLAY)
	ball_launched.emit(launched_ball, inventory.total_remaining)
