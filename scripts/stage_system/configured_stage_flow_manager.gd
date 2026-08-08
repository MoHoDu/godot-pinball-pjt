@tool
class_name ConfiguredStageFlowManager
extends StageFlowManager


@export_category("Initial Inventory")

## 한 웨이브에서 발사할 공 수입니다. 각 공은 웨이브당 한 번만 사용합니다.
@export_range(1, 5, 1) var launches_per_wave := 3

## 배열의 +/-로 항목을 추가하고 Ball Prefab 슬롯에 공 씬을 드래그합니다.
@export var initial_balls: Array[StageInitialBallEntry] = []

## 배열의 +/-로 항목을 추가하고 Part Prefab과 Starting Count를 설정합니다.
@export var initial_repair_parts: Array[StageInitialRepairPartEntry] = []


func start_stage() -> bool:
	_apply_initial_inventory()
	return super()


func get_configuration_error() -> String:
	var base_error := super()
	if not base_error.is_empty():
		return base_error
	if initial_balls.is_empty():
		return "Initial Balls requires at least one ball prefab."
	if initial_balls.size() > StageBallInventory.MAX_LIFE_SLOTS:
		return "Initial Balls cannot exceed five owned ball prefabs."
	var ball_ids: Dictionary[StringName, bool] = {}
	var valid_ball_count := 0
	for index: int in initial_balls.size():
		var entry := initial_balls[index]
		if entry == null or not entry.is_valid():
			return "Initial ball %d requires id, display name, and prefab." % (index + 1)
		if ball_ids.has(entry.ball_id):
			return "Initial ball id is duplicated: %s" % entry.ball_id
		if not entry.is_pinball_prefab():
			return "Initial ball prefab root must extend Pinball: %s" % entry.ball_id
		ball_ids[entry.ball_id] = true
		valid_ball_count += 1
	if launches_per_wave > valid_ball_count:
		return "Launches Per Wave cannot exceed the number of unique initial balls."
	var part_ids: Dictionary[StringName, bool] = {}
	for index: int in initial_repair_parts.size():
		var entry := initial_repair_parts[index]
		if entry == null or not entry.is_valid():
			return "Initial repair part %d requires settings and prefab." % (index + 1)
		var part_id := entry.settings.bumper_kind_id
		if not entry.is_placeable_prefab():
			return "Initial repair part prefab root must extend BoardPlaceable: %s" % part_id
		if part_id == &"crescent_needle":
			return "Crescent Needle is not an active repair part."
		if part_ids.has(part_id):
			return "Initial repair part id is duplicated: %s" % part_id
		part_ids[part_id] = true
	return ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var error := get_configuration_error()
	if not error.is_empty():
		warnings.append(error)
	return warnings


func _prepare_wave_ball_inventory(instance: Node) -> void:
	var wave_inventory := instance.find_child(
		"WaveBallInventory", true, false
	) as SelectBallInventory
	if wave_inventory != null:
		wave_inventory.reusable_owned_balls = true
		wave_inventory.launches_per_wave = launches_per_wave
		# 씬에 직렬화된 레거시 starting_stock이 Inspector 초기 공 목록에
		# 다시 병합되지 않도록 현재 스테이지 재고를 런타임 기준값으로 맞춥니다.
		# 예: 초기 공을 light에서 gel로 바꿔도 light가 네 번째 공으로 남지 않습니다.
		if stage_ball_inventory != null:
			wave_inventory.starting_stock = stage_ball_inventory.build_stock()
	super(instance)


func _apply_initial_inventory() -> void:
	_ensure_stage_reward_runtime()
	var base_stock: Array[BallStock] = []
	for entry: StageInitialBallEntry in initial_balls:
		if entry == null:
			continue
		var stock := entry.make_stock()
		if stock != null:
			base_stock.append(stock)
	stage_ball_inventory.capture_base_stock(base_stock)

	var part_entries: Array[RepairPartInventoryEntry] = []
	for entry: StageInitialRepairPartEntry in initial_repair_parts:
		if entry == null:
			continue
		var inventory_entry := entry.make_inventory_entry()
		if inventory_entry != null:
			part_entries.append(inventory_entry)
	reward_part_inventory.entries = part_entries
	reward_part_inventory.reset_to_starting_counts()
