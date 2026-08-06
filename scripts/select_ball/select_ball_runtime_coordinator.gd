class_name SelectBallRuntimeCoordinator
extends WaveRuntimeCoordinator


## 공 선택 전용 테스트 씬은 아직 구현 대상이 아닌 수리 배치 단계를 건너뛰고
## 사용자가 바로 공 선택 플로우를 검증할 수 있도록 시작합니다.
func _ready() -> void:
	super()
	if wave_manager.current_stage_phase \
			== WaveManager.StagePhase.REPAIR_PLACEMENT:
		assert(
			wave_manager.advance_stage_phase(),
			"Select-ball test scene must advance into ball selection."
		)


## 신규 인벤토리는 BallStock.count가 아니라 고유 ball_id 하나를 보유 공
## 하나로 취급하므로, 기존 웨이브 HUD 생명 슬롯도 같은 기준으로 구성합니다.
func _configure_lives_from_inventory() -> void:
	var ball_types: Array[StringName] = []
	if wave_ball_inventory is SelectBallInventory:
		var select_inventory := wave_ball_inventory as SelectBallInventory
		for definition: BallDefinition in select_inventory.get_owned_definitions():
			ball_types.append(definition.ball_id)
	else:
		for stock: BallStock in wave_ball_inventory.starting_stock:
			if stock == null or not stock.is_valid():
				continue
			if stock.definition.ball_id not in ball_types:
				ball_types.append(stock.definition.ball_id)

	assert(ball_types.size() >= 3 and ball_types.size() <= 5,
		"Select-ball HUD requires three to five unique owned balls.")
	if ball_types.size() < 3 or ball_types.size() > 5:
		return
	hud_state.configure_lives(ball_types)
