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


@export_group("디버그")

## 개발용 즉시 클리어 키입니다. 빼려면 KEY_NONE으로 두면 됩니다.
@export var debug_clear_wave_key: Key = KEY_G


## 점수를 목표까지 밀어 올릴 때 반복할 최대 횟수입니다. 무한 루프 방지용입니다.
const MAX_SCORE_INJECT_STEPS := 8

## 화면에 남겨 두는 이벤트 로그 줄 수입니다.
const EVENT_LOG_MAX_LINES := 6


var relic_inventory: RelicInventory
var relic_runtime: RelicRuntime
var reward_controller: RewardChoiceController
var reward_hud: RewardChoiceHud

var _event_log_label: Label
var _event_log_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	super()
	_build_reward_system()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if get_tree().paused or debug_clear_wave_key == KEY_NONE:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != debug_clear_wave_key:
		return
	if force_wave_clear():
		get_viewport().set_input_as_handled()


## 진행 중인 웨이브를 즉시 클리어합니다. 개발용입니다.
##
## 기존 스크립트를 고치지 않으려고 정상 경로를 그대로 흉내냅니다.
##   1) 목표 점수까지 점수를 채우고
##   2) 공 한 번의 수명주기(발사 → 낙하)를 성립시켜 클리어 선택을 띄운 뒤
##   3) 클리어를 확정합니다.
## 특히 3)이 중요합니다. ComboWaveController.choose_clear()가 ball_flow.end_wave()를
## 불러 주어야 공 흐름이 INACTIVE가 되고, 그래야 다음 enter_wave()가 성공합니다.
func force_wave_clear() -> bool:
	if wave_manager == null or not is_instance_valid(wave_manager):
		return false
	if wave_manager.current_state in [
		WaveManager.State.INACTIVE,
		WaveManager.State.WON,
		WaveManager.State.LOST,
	]:
		return false

	_inject_clear_score()

	if wave_manager.current_state == WaveManager.State.CLEAR_CHOICE:
		return wave_manager.choose_clear()

	if wave_ball_flow.current_state == WaveBallFlowController.State.AIMING:
		# 조준 중이라면 준비된 공을 실제로 쏴야 낙하 처리로 이어집니다.
		launcher.launch_prepared_ball()

	if wave_ball_flow.current_state == WaveBallFlowController.State.IN_PLAY:
		wave_ball_flow.on_ball_drained(wave_ball_flow.active_ball)
	elif wave_manager.combo_wave != null:
		# 공이 보드에 없는 상태(공 선택 중)라면 공 한 번을 그대로 흉내냅니다.
		wave_manager.combo_wave.on_ball_launched()
		wave_manager.combo_wave.on_ball_drained(wave_manager.remaining_balls)

	if wave_manager.current_state == WaveManager.State.CLEAR_CHOICE:
		return wave_manager.choose_clear()
	return wave_manager.current_state == WaveManager.State.WON


## 목표 점수에 닿을 때까지 콤보를 만들어 정산합니다.
func _inject_clear_score() -> void:
	var target_score := wave_manager.target_score
	if target_score <= 0 or not is_instance_valid(combo_system):
		return
	var rules: Resource = combo_system.rules
	if rules == null:
		return
	for _step in MAX_SCORE_INJECT_STEPS:
		var missing := target_score - wave_manager.current_score
		if missing <= 0:
			return
		var base_score := maxi(combo_system.stage_base_score, 1)
		var tier: int = rules.call(&"get_tier", combo_system.combo_count + 1)
		var multiplier := maxf(
			float(rules.call(&"get_score_multiplier", tier)),
			0.0001
		)
		var weight := ceilf(float(missing) / (float(base_score) * multiplier))
		combo_system.register_hit(maxf(weight, 1.0))
		combo_system.finish_combo(ComboSystem.EndReason.MANUAL)


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


## 옛 테스트 보드의 이벤트 로그를 대신하는 간이 로그입니다.
## 독립형 wave.tscn에는 이벤트 로그 UI가 없으므로 HUD에 라벨을 만들어 씁니다.
func _append_event(message: String) -> void:
	print("[wave] %s" % message)
	if _event_log_label == null:
		_build_event_log_label()
	if _event_log_label == null:
		return
	_event_log_lines.append(message)
	while _event_log_lines.size() > EVENT_LOG_MAX_LINES:
		_event_log_lines.remove_at(0)
	_event_log_label.text = "\n".join(_event_log_lines)


func _build_event_log_label() -> void:
	var hud_root := get_node_or_null(^"HUD")
	if hud_root == null:
		return
	_event_log_label = Label.new()
	_event_log_label.name = "EventLogLabel"
	_event_log_label.position = Vector2(24.0, 300.0)
	_event_log_label.add_theme_font_size_override(&"font_size", 20)
	_event_log_label.add_theme_color_override(
		&"font_color", Color(0.78, 0.82, 0.86)
	)
	_event_log_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	_event_log_label.add_theme_constant_override(&"outline_size", 5)
	hud_root.add_child(_event_log_label)


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
