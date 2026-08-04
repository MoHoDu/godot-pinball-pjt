class_name RewardChoiceController
extends Node


## 웨이브 승리 → 유물 세 장 제시 → 선택 확정 → 다음 웨이브 진입까지를 담당합니다.
##
## 기존 웨이브 코드는 한 줄도 고치지 않습니다. 붙는 지점은 세 곳뿐입니다.
##   - WaveManager.wave_won  (승리 통지)
##   - WaveManager.enter_wave()  (WON 상태에서 다시 호출 가능)
##   - RelicRuntime  (효과 적용)


signal choices_presented(choices: Array[RelicDefinition], wave_index: int)
signal selection_changed(selected_index: int)
signal choice_confirmed(definition: RelicDefinition, stack_count: int)
signal next_wave_entered(wave_index: int)
signal sequence_finished(reason: StringName)


enum State {
	IDLE,
	CHOOSING,
	ADVANCING,
	FINISHED,
}


@export var pool: RelicPool

@export_range(1, 5, 1)
var choice_count: int = 3

## 0이면 매번 다르게 뽑습니다. 테스트에서는 고정 시드를 넣습니다.
@export var random_seed: int = 0

@export_group("입력 액션")

## 기존 공 선택 조작과 같은 액션을 씁니다. 인풋맵을 새로 추가하지 않습니다.
@export var previous_action: StringName = &"ball_select_previous"
@export var next_action: StringName = &"ball_select_next"
@export var confirm_action: StringName = &"ball_select_confirm"


var wave_manager: WaveManager
var relic_inventory: RelicInventory
var runtime: RelicRuntime
var stage_settings: Resource

var _choices: Array[RelicDefinition] = []
var _selected_index: int = 0
var _state: State = State.IDLE
var _rng := RandomNumberGenerator.new()


var current_state: State:
	get:
		return _state

var selected_index: int:
	get:
		return _selected_index

var is_choosing: bool:
	get:
		return _state == State.CHOOSING


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.CHOOSING:
		return
	if event.is_action_pressed(previous_action):
		if move_selection(-1):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(next_action):
		if move_selection(1):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(confirm_action):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if confirm_selection():
			get_viewport().set_input_as_handled()


func bind_wave(
	next_wave_manager: WaveManager,
	next_relic_inventory: RelicInventory,
	next_runtime: RelicRuntime,
	next_stage_settings: Resource
) -> bool:
	if next_wave_manager == null \
			or next_relic_inventory == null \
			or next_runtime == null \
			or next_stage_settings == null:
		return false
	unbind_wave()
	wave_manager = next_wave_manager
	relic_inventory = next_relic_inventory
	runtime = next_runtime
	stage_settings = next_stage_settings
	wave_manager.wave_won.connect(_on_wave_won)
	return true


func unbind_wave() -> void:
	if wave_manager != null and is_instance_valid(wave_manager):
		if wave_manager.wave_won.is_connected(_on_wave_won):
			wave_manager.wave_won.disconnect(_on_wave_won)
	wave_manager = null


func get_choices() -> Array[RelicDefinition]:
	return _choices.duplicate()


func move_selection(direction: int) -> bool:
	if _state != State.CHOOSING or _choices.is_empty():
		return false
	var next_index := posmod(_selected_index + signi(direction), _choices.size())
	if next_index == _selected_index:
		return false
	_selected_index = next_index
	selection_changed.emit(_selected_index)
	return true


func select_index(index: int) -> bool:
	if _state != State.CHOOSING \
			or index < 0 \
			or index >= _choices.size() \
			or index == _selected_index:
		return false
	_selected_index = index
	selection_changed.emit(_selected_index)
	return true


## 선택을 확정하고 효과를 적용한 뒤 다음 웨이브로 넘어갑니다.
func confirm_selection(index: int = -1) -> bool:
	if _state != State.CHOOSING or _choices.is_empty():
		return false
	if index >= 0:
		if index >= _choices.size():
			return false
		_selected_index = index
	var definition := _choices[_selected_index]
	if definition == null or not definition.is_valid():
		return false

	var stack_count := relic_inventory.acquire(definition)
	# 효과는 반드시 다음 웨이브 진입 "전"에 적용합니다.
	# enter_wave(reset_inventory=true)가 starting_stock을 다시 읽기 때문입니다.
	runtime.apply_all(relic_inventory)
	_choices.clear()
	_state = State.ADVANCING
	choice_confirmed.emit(definition, stack_count)
	return _advance_to_next_wave()


func _on_wave_won(_current_score: int, _target_score: int) -> void:
	if _state != State.IDLE or wave_manager == null:
		return
	var next_wave_index := wave_manager.current_wave_index + 1
	if not _has_wave(next_wave_index):
		_state = State.FINISHED
		sequence_finished.emit(&"stage_cleared")
		return

	_choices = pool.draw(choice_count, relic_inventory, _rng) if pool != null else []
	if _choices.is_empty():
		# 뽑을 후보가 없으면 보상 없이 넘어갑니다. 조용히 멈추지 않습니다.
		push_warning("남은 유물 후보가 없어 보상 없이 다음 웨이브로 넘어갑니다.")
		_state = State.ADVANCING
		_advance_to_next_wave()
		return

	_selected_index = 0
	_state = State.CHOOSING
	choices_presented.emit(_choices.duplicate(), wave_manager.current_wave_index)


func _advance_to_next_wave() -> bool:
	var next_wave_index := wave_manager.current_wave_index + 1
	if wave_manager.enter_wave(stage_settings, next_wave_index, true):
		_state = State.IDLE
		next_wave_entered.emit(next_wave_index)
		return true
	_state = State.FINISHED
	sequence_finished.emit(&"enter_wave_failed")
	return false


func _has_wave(wave_index: int) -> bool:
	if stage_settings == null \
			or not stage_settings.has_method(&"get_wave_target_score"):
		return false
	return int(stage_settings.call(&"get_wave_target_score", wave_index)) > 0


func _exit_tree() -> void:
	unbind_wave()
