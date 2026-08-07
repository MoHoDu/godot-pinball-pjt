class_name WaveManager
extends Node


signal state_changed(previous_state: State, current_state: State)
signal wave_entered(stage_id: StringName, wave_index: int, target_score: int)
signal active_ball_changed(ball: Pinball)
signal ball_cycle_started(ball: Pinball, remaining_balls: int)
signal ball_cycle_resolved(ball: Pinball, remaining_balls: int, awarded_score: int)
signal clear_choice_requested(current_score: int, target_score: int, remaining_balls: int)
signal wave_won(current_score: int, target_score: int)
signal wave_lost(current_score: int, target_score: int)
signal wave_retried
signal stage_entered(stage_id: StringName, wave_index: int)
signal stage_phase_changed(previous_phase: StagePhase, current_phase: StagePhase)
signal stage_completed(stage_id: StringName)


enum State {
	INACTIVE,
	ENTERING,
	SELECTING_BALL,
	AIMING,
	IN_PLAY,
	RESOLVING_BALL,
	CLEAR_CHOICE,
	WON,
	LOST,
}


enum StagePhase {
	INACTIVE,
	REPAIR_PLACEMENT,
	BALL_SELECTION,
	BALL_LAUNCH,
	PINBALL,
	WAVE_RESULT,
	REWARD,
	BOSS,
	STAGE_COMPLETE,
}


const NORMAL_WAVE_COUNT := 3
const BALLS_PER_WAVE := 3


@export_category("Runtime Dependencies")
@export var configured_ball_flow: WaveBallFlowController
@export var configured_combo_wave: ComboWaveController
@export var configured_combo_system: ComboSystem
@export var configured_collision_bridge: ComboCollisionBridge

var ball_flow: WaveBallFlowController
var combo_wave: ComboWaveController
var combo_system: ComboSystem
var collision_bridge: ComboCollisionBridge
var active_ball: Pinball
var _state: State = State.INACTIVE
var _stage_settings: Resource
var _wave_index := 0
var _clear_after_drain := false
var _pending_terminal_state: State = State.INACTIVE
var _terminal_finalize_queued := false
var _stage_phase: StagePhase = StagePhase.INACTIVE
var _stage_is_active := false
var _last_wave_was_won := false
var _boss_ball_cycle_started := false
var _boss_ball_cycle_active := false
var _boss_phase_completion_ready := false


var current_state: State:
	get:
		return _state

var current_stage_phase: StagePhase:
	get:
		return _stage_phase

var target_score: int:
	get:
		return combo_wave.target_score if combo_wave != null else 0

var current_score: int:
	get:
		return combo_wave.current_score if combo_wave != null else 0

var current_wave_index: int:
	get:
		return _wave_index

var remaining_balls: int:
	get:
		if ball_flow == null or ball_flow.inventory == null:
			return 0
		return ball_flow.inventory.total_remaining


func _ready() -> void:
	if configured_ball_flow != null:
		bind_ball_flow(configured_ball_flow)
	if configured_combo_wave != null:
		bind_combo_wave(configured_combo_wave)
	if configured_combo_system != null:
		bind_combo_system(configured_combo_system)
	if configured_collision_bridge != null:
		bind_collision_bridge(configured_collision_bridge)


func bind_ball_flow(next_flow: WaveBallFlowController) -> bool:
	if next_flow == null:
		return false
	if ball_flow == next_flow:
		return true
	_unbind_ball_flow()
	ball_flow = next_flow
	ball_flow.state_changed.connect(_on_ball_flow_state_changed)
	ball_flow.active_ball_changed.connect(_on_flow_active_ball_changed)
	ball_flow.ball_launched.connect(_on_flow_ball_launched)
	ball_flow.ball_drained.connect(_on_flow_ball_drained)
	if combo_wave != null:
		combo_wave.bind_ball_flow(ball_flow, false)
	_set_active_ball(ball_flow.active_ball)
	return true


func bind_combo_wave(next_combo_wave: ComboWaveController) -> bool:
	if next_combo_wave == null:
		return false
	if combo_wave == next_combo_wave:
		return true
	_unbind_combo_wave()
	combo_wave = next_combo_wave
	combo_wave.set_process_unhandled_input(false)
	combo_wave.clear_choice_requested.connect(_on_clear_choice_requested)
	combo_wave.clear_choice_resolved.connect(_on_clear_choice_resolved)
	combo_wave.wave_clear_requested.connect(_on_wave_clear_requested)
	combo_wave.target_score_reached.connect(_on_target_score_reached)
	if combo_system != null:
		combo_wave.bind_combo_system(combo_system)
	if ball_flow != null:
		combo_wave.bind_ball_flow(ball_flow, false)
	return true


func bind_combo_system(next_combo_system: ComboSystem) -> bool:
	if next_combo_system == null:
		return false
	combo_system = next_combo_system
	var combo_wave_bound := combo_wave == null \
		or combo_wave.bind_combo_system(combo_system)
	var bridge_bound := collision_bridge == null \
		or collision_bridge.bind_combo_system(combo_system)
	return combo_wave_bound and bridge_bound


func bind_collision_bridge(next_bridge: ComboCollisionBridge) -> bool:
	if next_bridge == null:
		return false
	if collision_bridge != null \
			and is_instance_valid(collision_bridge) \
			and collision_bridge != next_bridge:
		collision_bridge.bind_ball(null)
	collision_bridge = next_bridge
	if combo_system != null:
		collision_bridge.bind_combo_system(combo_system)
	collision_bridge.bind_ball(active_ball)
	return true


func enter_stage(stage_settings: Resource, start_wave_index := 0) -> bool:
	if stage_settings == null \
			or not stage_settings.has_method(&"get_wave_target_score") \
			or ball_flow == null \
			or combo_wave == null \
			or combo_system == null \
			or _stage_phase not in [StagePhase.INACTIVE, StagePhase.STAGE_COMPLETE]:
		return false
	if ball_flow.inventory == null \
			or not ball_flow.inventory.reset_stock() \
			or ball_flow.inventory.total_remaining != BALLS_PER_WAVE:
		push_warning("Confirmed stage flow requires exactly three wave balls.")
		return false

	_stage_settings = stage_settings
	_wave_index = clampi(start_wave_index, 0, NORMAL_WAVE_COUNT - 1)
	_stage_is_active = true
	_last_wave_was_won = false
	_boss_ball_cycle_started = false
	_boss_ball_cycle_active = false
	_boss_phase_completion_ready = false
	combo_system.reset_wave()
	_set_state(State.INACTIVE)
	_set_stage_phase(StagePhase.REPAIR_PLACEMENT)
	stage_entered.emit(
		StringName(stage_settings.get(&"stage_id")),
		_wave_index
	)
	return true


func advance_stage_phase() -> bool:
	if not _stage_is_active or _stage_settings == null:
		return false
	match _stage_phase:
		StagePhase.REPAIR_PLACEMENT:
			return enter_wave(_stage_settings, _wave_index, true)
		StagePhase.WAVE_RESULT:
			if _last_wave_was_won:
				_set_stage_phase(StagePhase.REWARD)
			else:
				_set_stage_phase(StagePhase.REPAIR_PLACEMENT)
			return true
		StagePhase.REWARD:
			if _wave_index + 1 < NORMAL_WAVE_COUNT:
				_wave_index += 1
				_set_stage_phase(StagePhase.REPAIR_PLACEMENT)
			else:
				_boss_ball_cycle_started = false
				_boss_ball_cycle_active = false
				_boss_phase_completion_ready = false
				_set_stage_phase(StagePhase.BOSS)
			return true
		StagePhase.BOSS:
			if not _boss_phase_completion_ready:
				return false
			_boss_phase_completion_ready = false
			_set_stage_phase(StagePhase.STAGE_COMPLETE)
			stage_completed.emit(StringName(_stage_settings.get(&"stage_id")))
			return true
		StagePhase.STAGE_COMPLETE:
			_stage_is_active = false
			_set_stage_phase(StagePhase.INACTIVE)
			return enter_stage(_stage_settings, 0)
	return false


func start_boss_ball_cycle() -> bool:
	if not _stage_is_active \
			or _stage_phase != StagePhase.BOSS \
			or _boss_ball_cycle_started \
			or _boss_phase_completion_ready \
			or ball_flow == null \
			or combo_system == null \
			or ball_flow.inventory == null \
			or ball_flow.current_state \
				not in [
					WaveBallFlowController.State.INACTIVE,
					WaveBallFlowController.State.EXHAUSTED,
				]:
		return false

	_boss_ball_cycle_started = true
	_boss_ball_cycle_active = true
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	_set_state(State.ENTERING)
	if ball_flow.start_wave(true):
		combo_system.reset_wave()
		return true

	_boss_ball_cycle_started = false
	_boss_ball_cycle_active = false
	_set_state(State.INACTIVE)
	return false


func finish_boss_ball_cycle() -> bool:
	if not _stage_is_active \
			or _stage_phase != StagePhase.BOSS \
			or not _boss_ball_cycle_started \
			or _boss_phase_completion_ready \
			or ball_flow == null:
		return false

	var active_ball_was_in_play: bool = (
		ball_flow.current_state == WaveBallFlowController.State.IN_PLAY
	)
	if ball_flow.current_state in [
		WaveBallFlowController.State.SELECTING,
		WaveBallFlowController.State.AIMING,
		WaveBallFlowController.State.IN_PLAY,
		WaveBallFlowController.State.EXHAUSTED,
	]:
		if not ball_flow.finish_wave_immediately():
			return false
	if active_ball_was_in_play and combo_system != null:
		combo_system.on_ball_drained()

	_boss_ball_cycle_active = false
	_boss_phase_completion_ready = true
	_set_state(State.INACTIVE)
	return true


func is_boss_ball_cycle_active() -> bool:
	return _boss_ball_cycle_active \
		and _stage_phase == StagePhase.BOSS \
		and ball_flow != null \
		and is_instance_valid(ball_flow)


func is_placeholder_phase() -> bool:
	return _stage_phase in [
		StagePhase.REPAIR_PLACEMENT,
		StagePhase.WAVE_RESULT,
		StagePhase.REWARD,
		StagePhase.BOSS,
		StagePhase.STAGE_COMPLETE,
	]


func get_stage_phase_title() -> String:
	match _stage_phase:
		StagePhase.REPAIR_PLACEMENT:
			return "수리 부품 배치 단계"
		StagePhase.BALL_SELECTION:
			return "공 선택 단계"
		StagePhase.BALL_LAUNCH:
			return "공 발사 단계"
		StagePhase.PINBALL:
			return "핀볼 진행 단계"
		StagePhase.WAVE_RESULT:
			return "결과 판정 단계"
		StagePhase.REWARD:
			return "보상 단계"
		StagePhase.BOSS:
			return "보스 단계"
		StagePhase.STAGE_COMPLETE:
			return "스테이지 완료 단계"
	return ""


func get_stage_phase_button_text() -> String:
	return "다음 단계"


func enter_wave(
	stage_settings: Resource,
	wave_index := 0,
	reset_inventory := true
) -> bool:
	if stage_settings == null \
			or ball_flow == null \
			or combo_wave == null \
			or combo_system == null \
			or _state not in [State.INACTIVE, State.WON, State.LOST]:
		return false
	combo_system.reset_wave()
	if not combo_wave.configure_wave(stage_settings, wave_index):
		return false

	_stage_settings = stage_settings
	_wave_index = maxi(wave_index, 0)
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	_set_state(State.ENTERING)
	if not ball_flow.start_wave(reset_inventory):
		if ball_flow.current_state == WaveBallFlowController.State.EXHAUSTED:
			_finish_lost()
		return false
	wave_entered.emit(
		StringName(stage_settings.get(&"stage_id")),
		_wave_index,
		target_score
	)
	return true


func choose_clear() -> bool:
	if _state != State.CLEAR_CHOICE or combo_wave == null:
		return false
	if ball_flow != null \
			and ball_flow.current_state == WaveBallFlowController.State.IN_PLAY:
		_clear_after_drain = true
		return true
	return combo_wave.choose_clear()


func choose_remaining_balls() -> bool:
	# 확정된 흐름에서는 목표 점수 달성 즉시 결과 판정으로 이동합니다.
	return false


func retry_wave() -> bool:
	if _state not in [State.WON, State.LOST] \
			or ball_flow == null \
			or combo_wave == null \
			or _stage_settings == null:
		return false
	combo_wave.on_wave_retried(false)
	_clear_after_drain = false
	_pending_terminal_state = State.INACTIVE
	_terminal_finalize_queued = false
	_set_state(State.ENTERING)
	var started := false
	if ball_flow.current_state == WaveBallFlowController.State.INACTIVE:
		started = ball_flow.start_wave(true)
	else:
		started = ball_flow.retry_wave()
	if not started:
		if ball_flow.current_state == WaveBallFlowController.State.EXHAUSTED:
			_finish_lost()
		return false
	wave_retried.emit()
	return true


func get_state_name() -> StringName:
	return State.keys()[_state].to_snake_case()


func _exit_tree() -> void:
	if collision_bridge != null and is_instance_valid(collision_bridge):
		collision_bridge.bind_ball(null)
	collision_bridge = null
	_unbind_combo_wave()
	_unbind_ball_flow()
	combo_system = null


func _unbind_ball_flow() -> void:
	if ball_flow == null or not is_instance_valid(ball_flow):
		ball_flow = null
		return
	if combo_wave != null and is_instance_valid(combo_wave):
		combo_wave.unbind_ball_flow()
	if ball_flow.state_changed.is_connected(_on_ball_flow_state_changed):
		ball_flow.state_changed.disconnect(_on_ball_flow_state_changed)
	if ball_flow.active_ball_changed.is_connected(_on_flow_active_ball_changed):
		ball_flow.active_ball_changed.disconnect(_on_flow_active_ball_changed)
	if ball_flow.ball_launched.is_connected(_on_flow_ball_launched):
		ball_flow.ball_launched.disconnect(_on_flow_ball_launched)
	if ball_flow.ball_drained.is_connected(_on_flow_ball_drained):
		ball_flow.ball_drained.disconnect(_on_flow_ball_drained)
	ball_flow = null


func _unbind_combo_wave() -> void:
	if combo_wave == null or not is_instance_valid(combo_wave):
		combo_wave = null
		return
	if combo_wave.clear_choice_requested.is_connected(_on_clear_choice_requested):
		combo_wave.clear_choice_requested.disconnect(_on_clear_choice_requested)
	if combo_wave.clear_choice_resolved.is_connected(_on_clear_choice_resolved):
		combo_wave.clear_choice_resolved.disconnect(_on_clear_choice_resolved)
	if combo_wave.wave_clear_requested.is_connected(_on_wave_clear_requested):
		combo_wave.wave_clear_requested.disconnect(_on_wave_clear_requested)
	if combo_wave.target_score_reached.is_connected(_on_target_score_reached):
		combo_wave.target_score_reached.disconnect(_on_target_score_reached)
	combo_wave.unbind_ball_flow()
	combo_wave.unbind_combo_system()
	combo_wave.set_process_unhandled_input(true)
	combo_wave = null


func _on_ball_flow_state_changed(
	_previous_state: WaveBallFlowController.State,
	next_state: WaveBallFlowController.State
) -> void:
	if _boss_ball_cycle_active:
		_on_boss_ball_flow_state_changed(next_state)
		return
	match next_state:
		WaveBallFlowController.State.INACTIVE:
			if _state not in [State.CLEAR_CHOICE, State.WON, State.LOST]:
				_set_state(State.INACTIVE)
		WaveBallFlowController.State.SELECTING:
			if _state == State.CLEAR_CHOICE and _clear_after_drain:
				_clear_after_drain = false
				combo_wave.choose_clear()
			elif _state == State.CLEAR_CHOICE \
					and combo_wave != null \
					and not combo_wave.choice_is_pending:
				_set_state(State.SELECTING_BALL)
			elif _state not in [State.CLEAR_CHOICE, State.WON, State.LOST]:
				_set_state(State.SELECTING_BALL)
				_set_stage_phase(StagePhase.BALL_SELECTION)
		WaveBallFlowController.State.AIMING:
			_set_state(State.AIMING)
			_set_stage_phase(StagePhase.BALL_LAUNCH)
		WaveBallFlowController.State.IN_PLAY:
			_set_state(State.IN_PLAY)
			_set_stage_phase(StagePhase.PINBALL)
		WaveBallFlowController.State.EXHAUSTED:
			if _state in [State.WON, State.LOST]:
				return
			if combo_wave != null and combo_wave.clear_was_requested:
				_queue_terminal_state(State.WON)
			else:
				_queue_terminal_state(State.LOST)


func _on_boss_ball_flow_state_changed(
	next_state: WaveBallFlowController.State
) -> void:
	match next_state:
		WaveBallFlowController.State.INACTIVE:
			_set_state(State.INACTIVE)
		WaveBallFlowController.State.SELECTING:
			_set_state(State.SELECTING_BALL)
		WaveBallFlowController.State.AIMING:
			_set_state(State.AIMING)
		WaveBallFlowController.State.IN_PLAY:
			_set_state(State.IN_PLAY)
		WaveBallFlowController.State.EXHAUSTED:
			_set_state(State.INACTIVE)


func _on_flow_active_ball_changed(next_ball: Pinball) -> void:
	_set_active_ball(next_ball)


func _on_flow_ball_launched(ball: Pinball, balls_remaining: int) -> void:
	if _boss_ball_cycle_active:
		if combo_system != null:
			combo_system.on_ball_launched()
		_set_state(State.IN_PLAY)
		ball_cycle_started.emit(ball, balls_remaining)
		return
	if combo_wave == null or not combo_wave.on_ball_launched():
		return
	_set_state(State.IN_PLAY)
	ball_cycle_started.emit(ball, balls_remaining)


func _on_flow_ball_drained(ball: Pinball, balls_remaining: int) -> void:
	if _boss_ball_cycle_active:
		_set_state(State.RESOLVING_BALL)
		var boss_awarded_score: int = 0
		if combo_system != null:
			boss_awarded_score = combo_system.on_ball_drained()
		ball_cycle_resolved.emit(ball, balls_remaining, boss_awarded_score)
		return
	if combo_wave == null:
		return
	_set_state(State.RESOLVING_BALL)
	var score_before := current_score
	combo_wave.on_ball_drained(balls_remaining)
	var awarded_score := current_score - score_before
	ball_cycle_resolved.emit(ball, balls_remaining, awarded_score)


func _on_clear_choice_requested(
	_score: int,
	_target: int,
	_balls_remaining: int
) -> void:
	if _boss_ball_cycle_active:
		return
	_set_state(State.CLEAR_CHOICE)
	clear_choice_requested.emit(_score, _target, _balls_remaining)
	choose_clear()


func _on_clear_choice_resolved(use_remaining_balls: bool) -> void:
	if _boss_ball_cycle_active:
		return
	if use_remaining_balls \
			and ball_flow != null \
			and ball_flow.current_state == WaveBallFlowController.State.SELECTING:
		_set_state(State.SELECTING_BALL)


func _on_wave_clear_requested(_score: int, _target: int) -> void:
	if _boss_ball_cycle_active:
		return
	_queue_terminal_state(State.WON)


func _on_target_score_reached(_score: int, _target: int) -> void:
	if _boss_ball_cycle_active:
		return
	if _state == State.IN_PLAY and combo_wave != null:
		combo_wave.complete_reached_target()


func _set_active_ball(next_ball: Pinball) -> void:
	active_ball = next_ball
	if collision_bridge != null and is_instance_valid(collision_bridge):
		collision_bridge.bind_ball(active_ball)
	active_ball_changed.emit(active_ball)


func _queue_terminal_state(terminal_state: State) -> void:
	if terminal_state not in [State.WON, State.LOST] \
			or _state in [State.WON, State.LOST]:
		return
	if _pending_terminal_state != State.WON:
		_pending_terminal_state = terminal_state
	if _terminal_finalize_queued:
		return
	_terminal_finalize_queued = true
	call_deferred(&"_finalize_pending_terminal_state")


func _finalize_pending_terminal_state() -> void:
	_terminal_finalize_queued = false
	var terminal_state := _pending_terminal_state
	_pending_terminal_state = State.INACTIVE
	if terminal_state == State.WON:
		_finish_won()
	elif terminal_state == State.LOST:
		_finish_lost()


func _finish_won() -> void:
	if _state == State.WON:
		return
	_clear_after_drain = false
	_last_wave_was_won = true
	_set_state(State.WON)
	_set_stage_phase(StagePhase.WAVE_RESULT)
	wave_won.emit(current_score, target_score)


func _finish_lost() -> void:
	if _state == State.LOST:
		return
	_clear_after_drain = false
	_last_wave_was_won = false
	_set_state(State.LOST)
	_set_stage_phase(StagePhase.WAVE_RESULT)
	wave_lost.emit(current_score, target_score)


func _set_state(next_state: State) -> void:
	if next_state == _state:
		return
	var previous_state := _state
	_state = next_state
	state_changed.emit(previous_state, _state)


func _set_stage_phase(next_phase: StagePhase) -> void:
	if next_phase == _stage_phase:
		return
	var previous_phase := _stage_phase
	_stage_phase = next_phase
	stage_phase_changed.emit(previous_phase, _stage_phase)
