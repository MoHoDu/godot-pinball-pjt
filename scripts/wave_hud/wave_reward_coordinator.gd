class_name WaveRewardCoordinator
extends WaveRuntimeCoordinator


## 웨이브 씬에 유물 보상 흐름을 얹습니다.
##
## WaveRuntimeCoordinator를 상속만 하고 기존 로직은 건드리지 않습니다.
## 보상 노드는 씬 파일이 아니라 코드로 붙입니다. wave.tscn이 다른 씬의 인스턴스라
## 손으로 노드를 끼워 넣으면 parent_id_path가 깨지기 쉽기 때문입니다.


const REWARD_CHOICE_HUD_SCENE := preload(
	"res://scenes/reward_system/reward_choice_hud.tscn"
)
const DEFAULT_RELIC_POOL := preload("res://settings/reward/RelicPool.tres")


@export_category("Wave Reward")

@export var relic_pool: RelicPool = DEFAULT_RELIC_POOL

@export_range(1, 5, 1)
var reward_choice_count: int = 3

## 0이면 매번 다르게 뽑습니다.
@export var reward_random_seed: int = 0


var relic_inventory: RelicInventory
var relic_runtime: RelicRuntime
var reward_controller: RewardChoiceController
var reward_hud: RewardChoiceHud


func _ready() -> void:
	super()
	_build_reward_system()


func get_relic_summary() -> String:
	if relic_inventory == null:
		return ""
	return relic_inventory.describe_all()


func _build_reward_system() -> void:
	relic_inventory = RelicInventory.new()
	relic_inventory.name = "RelicInventory"
	add_child(relic_inventory)

	relic_runtime = RelicRuntime.new()
	relic_runtime.name = "RelicRuntime"
	add_child(relic_runtime)
	var bound := relic_runtime.bind_board(
		combo_system,
		launcher,
		wave_ball_inventory,
		_find_flippers()
	)
	assert(bound, "보상 런타임이 보드 노드를 찾지 못했습니다.")

	reward_controller = RewardChoiceController.new()
	reward_controller.name = "RewardChoiceController"
	reward_controller.pool = relic_pool
	reward_controller.choice_count = reward_choice_count
	reward_controller.random_seed = reward_random_seed
	add_child(reward_controller)

	var hud_root := get_node_or_null("HUD")
	assert(hud_root != null, "보상 HUD를 붙일 HUD 노드가 없습니다.")
	reward_hud = REWARD_CHOICE_HUD_SCENE.instantiate() as RewardChoiceHud
	reward_hud.name = "RewardChoiceHud"
	hud_root.add_child(reward_hud)
	reward_hud.bind_controller(reward_controller, relic_inventory)

	var wave_bound := reward_controller.bind_wave(
		wave_manager,
		relic_inventory,
		relic_runtime,
		_wave_settings
	)
	assert(wave_bound, "보상 컨트롤러가 웨이브에 연결되지 못했습니다.")

	reward_controller.choice_confirmed.connect(_on_relic_chosen)
	reward_controller.next_wave_entered.connect(_on_next_wave_entered)
	reward_controller.sequence_finished.connect(_on_reward_sequence_finished)


func _find_flippers() -> Array[Node]:
	return find_children("*", "PinballFlipper", true, false)


func _on_relic_chosen(definition: RelicDefinition, stack_count: int) -> void:
	_append_event("RELIC · %s x%d · %s" % [
		definition.display_name,
		stack_count,
		definition.describe(stack_count),
	])


func _on_next_wave_entered(wave_index: int) -> void:
	_append_event("WAVE %02d 시작 · 다음 공을 선택하세요" % (wave_index + 1))


func _on_reward_sequence_finished(reason: StringName) -> void:
	if reason == &"stage_cleared":
		_append_event("STAGE CLEAR · 수리 완료")
		return
	_append_event("REWARD · 다음 웨이브 진입 실패 (%s)" % reason)
