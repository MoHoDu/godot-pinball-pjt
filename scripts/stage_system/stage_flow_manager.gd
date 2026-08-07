@tool
class_name StageFlowManager
extends Node


## 인스펙터에 등록한 웨이브·보스 씬을 스테이지 순서대로 실행합니다.
##
## 일반 웨이브는 항상 보상 페이지를 거친 뒤 다음 웨이브 또는 보스로 이어집니다.
## 각 플레이 씬은 완료 시그널을 루트나 자식 노드 중 하나에 노출해야 합니다.


signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal scene_started(phase: Phase, index: int, scene: Node)
signal scene_completed(phase: Phase, index: int)
signal stage_completed
signal configuration_failed(reason: String)


enum Phase {
	IDLE,
	WAVE,
	REWARD,
	BOSS,
	COMPLETE,
	ERROR,
}


const DEFAULT_REWARD_SCENE := preload(
	"res://scenes/stage_system/stage_reward_placeholder.tscn"
)

const DEFAULT_WAVE_COMPLETION_SIGNALS: Array[StringName] = [
	&"stage_segment_completed",
	&"wave_completed",
	&"wave_cleared",
	&"wave_won",
	&"stage_completed",
	&"completed",
]

const DEFAULT_BOSS_COMPLETION_SIGNALS: Array[StringName] = [
	&"stage_segment_completed",
	&"boss_completed",
	&"boss_defeated",
	&"stage_completed",
	&"completed",
]

const DEFAULT_REWARD_COMPLETION_SIGNALS: Array[StringName] = [
	&"reward_completed",
	&"continued",
	&"next_requested",
	&"completed",
]


@export_category("Stage Scenes")

## 실행할 일반 웨이브 씬입니다. 최소 하나가 필요하며 배열 순서대로 진행합니다.
@export var wave_scenes: Array[PackedScene] = []

## 일반 웨이브가 모두 끝난 뒤 실행할 보스 씬입니다. 비어 있어도 됩니다.
@export var boss_scenes: Array[PackedScene] = []

## 각 일반 웨이브를 클리어한 뒤 표시할 보상 페이지입니다.
@export var reward_scene: PackedScene = DEFAULT_REWARD_SCENE

@export_category("Stage Coin")

## 웨이브 씬 교체 사이에 유지할 스테이지 공용 코인 지갑입니다.
## 비어 있으면 코인 시스템 연결 없이 기존 스테이지 흐름만 실행합니다.
@export var coin_wallet: CoinWallet

@export_category("Runtime")

## 현재 웨이브·보상·보스 씬을 자식으로 붙일 컨테이너입니다.
@export var scene_container: Node

## 씬 트리에 들어오면 자동으로 첫 웨이브를 시작합니다.
@export var auto_start := true

## 완료 시그널을 현재 씬의 자식 노드에서도 탐색합니다.
@export var search_completion_signal_in_descendants := true

@export_category("Completion Signal Contract")

## 앞쪽 이름일수록 우선합니다. 인자가 있는 시그널도 자동으로 연결됩니다.
@export var wave_completion_signals: Array[StringName] = (
	DEFAULT_WAVE_COMPLETION_SIGNALS.duplicate()
)

@export var boss_completion_signals: Array[StringName] = (
	DEFAULT_BOSS_COMPLETION_SIGNALS.duplicate()
)

@export var reward_completion_signals: Array[StringName] = (
	DEFAULT_REWARD_COMPLETION_SIGNALS.duplicate()
)


var _phase := Phase.IDLE
var _wave_index := -1
var _boss_index := -1
var _active_scene: Node
var _completion_source: Node
var _completion_signal := StringName()
var _completion_callable := Callable()
var _transition_pending := false
var _run_generation := 0


var current_phase: Phase:
	get:
		return _phase

var current_wave_index: int:
	get:
		return _wave_index

var current_boss_index: int:
	get:
		return _boss_index

var active_scene: Node:
	get:
		return _active_scene

var current_coin_balance: int:
	get:
		return coin_wallet.balance if coin_wallet != null else 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if scene_container == null:
		scene_container = self
	if auto_start:
		call_deferred(&"start_stage")


## 현재 설정으로 첫 웨이브부터 스테이지를 시작합니다.
func start_stage() -> bool:
	if Engine.is_editor_hint() or _phase not in [Phase.IDLE, Phase.COMPLETE, Phase.ERROR]:
		return false
	if scene_container == null:
		scene_container = self
	var error := get_configuration_error()
	if not error.is_empty():
		_fail_configuration(error)
		return false

	_clear_active_scene()
	_run_generation += 1
	_reset_stage_coin_wallet()
	_wave_index = 0
	_boss_index = -1
	_transition_pending = false
	return _show_wave()


## 진행 중인 씬을 닫고 시작 전 상태로 돌아갑니다.
func stop_stage() -> void:
	_run_generation += 1
	_transition_pending = false
	_clear_active_scene()
	_reset_stage_coin_wallet()
	_wave_index = -1
	_boss_index = -1
	_set_phase(Phase.IDLE)


func restart_stage() -> bool:
	stop_stage()
	return start_stage()


## 런타임 시작 가능 여부를 설명하는 오류 문장입니다. 빈 문자열이면 유효합니다.
func get_configuration_error() -> String:
	if wave_scenes.is_empty():
		return "StageFlowManager requires at least one wave scene."
	for index in wave_scenes.size():
		if wave_scenes[index] == null:
			return "Wave scene %d is empty." % (index + 1)
	for index in boss_scenes.size():
		if boss_scenes[index] == null:
			return "Boss scene %d is empty." % (index + 1)
	if reward_scene == null:
		return "Reward scene is empty."
	if scene_container == null and is_inside_tree():
		return "Scene container is empty."
	if wave_completion_signals.is_empty():
		return "At least one wave completion signal name is required."
	if boss_completion_signals.is_empty() and not boss_scenes.is_empty():
		return "At least one boss completion signal name is required."
	if reward_completion_signals.is_empty():
		return "At least one reward completion signal name is required."
	return ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var error := get_configuration_error()
	if not error.is_empty():
		warnings.append(error)
	return warnings


func _show_wave() -> bool:
	return _show_scene(
		wave_scenes[_wave_index],
		Phase.WAVE,
		_wave_index,
		wave_completion_signals
	)


func _show_reward() -> bool:
	var shown := _show_scene(
		reward_scene,
		Phase.REWARD,
		_wave_index,
		reward_completion_signals
	)
	if not shown:
		return false
	if _active_scene.has_method(&"configure_reward"):
		_active_scene.call(
			&"configure_reward",
			_wave_index,
			wave_scenes.size(),
			_get_reward_destination_text()
		)
	return true


func _show_boss() -> bool:
	return _show_scene(
		boss_scenes[_boss_index],
		Phase.BOSS,
		_boss_index,
		boss_completion_signals
	)


func _show_scene(
	packed_scene: PackedScene,
	next_phase: Phase,
	index: int,
	completion_signals: Array[StringName]
) -> bool:
	_clear_active_scene()
	var instance := packed_scene.instantiate()
	if instance == null:
		_fail_configuration("Configured scene %d could not be instantiated." % (index + 1))
		return false

	var binding := _find_completion_binding(instance, completion_signals)
	if binding.is_empty():
		instance.free()
		_fail_configuration(
			"Configured %s scene %d has no supported completion signal."
			% [Phase.keys()[next_phase].to_lower(), index + 1]
		)
		return false

	_active_scene = instance
	_prepare_stage_coin_integration(_active_scene)
	_completion_source = binding.source as Node
	_completion_signal = binding.signal_name as StringName
	_completion_callable = _completion_handler_for(
		_completion_source,
		_completion_signal
	)
	_completion_source.connect(_completion_signal, _completion_callable)
	_set_phase(next_phase)
	scene_container.add_child(_active_scene)
	scene_started.emit(_phase, index, _active_scene)
	return true


func _find_completion_binding(
	root: Node,
	completion_signals: Array[StringName]
) -> Dictionary:
	var candidates: Array[Node] = [root]
	if search_completion_signal_in_descendants:
		var cursor := 0
		while cursor < candidates.size():
			var current := candidates[cursor]
			cursor += 1
			for child in current.get_children():
				candidates.append(child)

	for signal_name in completion_signals:
		for candidate in candidates:
			if candidate.has_signal(signal_name):
				return {
					&"source": candidate,
					&"signal_name": signal_name,
				}
	return {}


func _completion_handler_for(source: Node, signal_name: StringName) -> Callable:
	var handler := Callable(self, &"_on_active_scene_completed")
	var argument_count := _get_signal_argument_count(source, signal_name)
	if argument_count > 0:
		handler = handler.unbind(argument_count)
	return handler


func _get_signal_argument_count(source: Node, signal_name: StringName) -> int:
	for signal_info in source.get_signal_list():
		if StringName(signal_info.get(&"name", &"")) == signal_name:
			return (signal_info.get(&"args", []) as Array).size()
	return 0


func _on_active_scene_completed() -> void:
	if _transition_pending or _phase not in [Phase.WAVE, Phase.REWARD, Phase.BOSS]:
		return
	_transition_pending = true
	var completed_phase := _phase
	var run_generation := _run_generation
	var completed_index := _wave_index if _phase != Phase.BOSS else _boss_index
	scene_completed.emit(_phase, completed_index)
	_disconnect_completion_signal()
	call_deferred(
		&"_advance_after_completion",
		completed_phase,
		run_generation
	)


func _advance_after_completion(
	completed_phase: Phase,
	run_generation: int
) -> void:
	if (
		run_generation != _run_generation
		or completed_phase != _phase
		or not _transition_pending
	):
		return
	_transition_pending = false
	match completed_phase:
		Phase.WAVE:
			_show_reward()
		Phase.REWARD:
			if _wave_index + 1 < wave_scenes.size():
				_wave_index += 1
				_show_wave()
			elif not boss_scenes.is_empty():
				_boss_index = 0
				_show_boss()
			else:
				_complete_stage()
		Phase.BOSS:
			if _boss_index + 1 < boss_scenes.size():
				_boss_index += 1
				_show_boss()
			else:
				_complete_stage()


func _complete_stage() -> void:
	_clear_active_scene()
	_reset_stage_coin_wallet()
	_set_phase(Phase.COMPLETE)
	stage_completed.emit()


func _prepare_stage_coin_integration(instance: Node) -> void:
	if coin_wallet == null:
		return
	if instance.has_method(&"bind_coin_wallet"):
		instance.call(&"bind_coin_wallet", coin_wallet)

	var stage_wave_manager := instance.find_child(
		"WaveManager", true, false
	) as WaveManager
	var candidates: Array[Node] = [instance]
	var cursor := 0
	while cursor < candidates.size():
		var current := candidates[cursor]
		cursor += 1
		if current.has_method(&"bind_stage_runtime"):
			current.call(
				&"bind_stage_runtime",
				coin_wallet,
				stage_wave_manager
			)
		for child in current.get_children():
			candidates.append(child)


func _reset_stage_coin_wallet() -> void:
	if coin_wallet != null:
		coin_wallet.reset(0)


func _get_reward_destination_text() -> String:
	if _wave_index + 1 < wave_scenes.size():
		return "다음 웨이브"
	if not boss_scenes.is_empty():
		return "보스 진행"
	return "스테이지 완료"


func _clear_active_scene() -> void:
	_disconnect_completion_signal()
	if _active_scene == null or not is_instance_valid(_active_scene):
		_active_scene = null
		return
	if _active_scene.get_parent() != null:
		_active_scene.get_parent().remove_child(_active_scene)
	_active_scene.queue_free()
	_active_scene = null


func _disconnect_completion_signal() -> void:
	if (
		_completion_source != null
		and is_instance_valid(_completion_source)
		and not _completion_signal.is_empty()
		and _completion_callable.is_valid()
		and _completion_source.is_connected(
				_completion_signal,
				_completion_callable
			)
	):
		_completion_source.disconnect(_completion_signal, _completion_callable)
	_completion_source = null
	_completion_signal = StringName()
	_completion_callable = Callable()


func _fail_configuration(reason: String) -> void:
	_run_generation += 1
	_transition_pending = false
	_clear_active_scene()
	_set_phase(Phase.ERROR)
	push_error(reason)
	configuration_failed.emit(reason)


func _set_phase(next_phase: Phase) -> void:
	if next_phase == _phase:
		return
	var previous_phase := _phase
	_phase = next_phase
	phase_changed.emit(previous_phase, _phase)
