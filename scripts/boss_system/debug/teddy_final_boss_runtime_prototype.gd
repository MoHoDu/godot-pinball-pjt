class_name TeddyFinalBossRuntimePrototype
extends TeddyBattleCompletionRuntimePrototype


const MAX_COTTON_EVENT_COUNT: int = 30
const COTTON_SPAWNED_EVENT: String = "CURSED COTTON SPAWNED: 2"
const COTTON_HIT_EVENT: String = "CURSED COTTON HIT"
const COTTON_CLEARED_EVENT: String = "CURSED COTTON CLEARED"


@export_category("Cursed Cotton")
@export var cotton_scene: PackedScene = null
@export var cotton_rules: CursedCottonAddRules = null
@export var cotton_parent: Node = null
@export var cotton_spawn_left: Node2D = null
@export var cotton_spawn_right: Node2D = null

@export_category("Cursed Cotton Debug")
@export var cotton_label: Label = null
@export var cotton_event_log: RichTextLabel = null


var _cotton_setup_complete: bool = false
var _cotton_spawned_for_battle: bool = false
var _active_cottons: Array[CursedCottonAdd] = []
var _cotton_event_messages: Array[String] = []


func _ready() -> void:
	call_deferred(&"_setup_cotton_integration")


func teardown() -> void:
	if not _cotton_setup_complete:
		return
	_cotton_setup_complete = false
	_disconnect_cotton_runtime_signals()
	_remove_all_cottons()


func get_active_cotton_count() -> int:
	_prune_invalid_cottons()
	return _active_cottons.size()


func _setup_cotton_integration() -> void:
	if _cotton_setup_complete:
		return
	if not _validate_cotton_references():
		push_error("Teddy final Boss Cotton integration has invalid references.")
		return
	_connect_cotton_runtime_signals()
	_cotton_setup_complete = true
	_cotton_spawned_for_battle = false
	_update_cotton_ui()
	if phase_transition.is_phase_2() and not completion_controller.is_completed():
		_spawn_phase_2_cottons()


func _validate_cotton_references() -> bool:
	for reference: Variant in [
		completion_controller,
		phase_transition,
		reset_button,
		cotton_scene,
		cotton_rules,
		cotton_parent,
		cotton_spawn_left,
		cotton_spawn_right,
		cotton_label,
		cotton_event_log,
	]:
		if reference == null or not is_instance_valid(reference):
			return false
	return cotton_scene.can_instantiate() and cotton_rules.validate().is_empty()


func _connect_cotton_runtime_signals() -> void:
	if not phase_transition.phase_2_entered.is_connected(_on_cotton_phase_2_entered):
		phase_transition.phase_2_entered.connect(_on_cotton_phase_2_entered)
	if not completion_controller.battle_completed.is_connected(
		_on_cotton_battle_completed
	):
		completion_controller.battle_completed.connect(
			_on_cotton_battle_completed
		)
	if not reset_button.pressed.is_connected(_on_cotton_reset_pressed):
		reset_button.pressed.connect(_on_cotton_reset_pressed)


func _disconnect_cotton_runtime_signals() -> void:
	if is_instance_valid(phase_transition) \
			and phase_transition.phase_2_entered.is_connected(
				_on_cotton_phase_2_entered
			):
		phase_transition.phase_2_entered.disconnect(_on_cotton_phase_2_entered)
	if is_instance_valid(completion_controller) \
			and completion_controller.battle_completed.is_connected(
				_on_cotton_battle_completed
			):
		completion_controller.battle_completed.disconnect(
			_on_cotton_battle_completed
		)
	if is_instance_valid(reset_button) \
			and reset_button.pressed.is_connected(_on_cotton_reset_pressed):
		reset_button.pressed.disconnect(_on_cotton_reset_pressed)


func _on_cotton_phase_2_entered(_current_hp: int) -> void:
	if completion_controller.is_completed():
		return
	_spawn_phase_2_cottons()


func _spawn_phase_2_cottons() -> void:
	if _cotton_spawned_for_battle or completion_controller.is_completed():
		return

	var spawned_cottons: Array[CursedCottonAdd] = []
	for spawn_point: Node2D in [cotton_spawn_left, cotton_spawn_right]:
		var cotton: CursedCottonAdd = cotton_scene.instantiate() as CursedCottonAdd
		if cotton == null or not cotton.configure(cotton_rules):
			for spawned: CursedCottonAdd in spawned_cottons:
				_disconnect_cotton_signals(spawned)
				spawned.queue_free()
			return
		cotton_parent.add_child(cotton)
		cotton.global_position = spawn_point.global_position
		_connect_cotton_signals(cotton)
		spawned_cottons.append(cotton)

	_active_cottons.append_array(spawned_cottons)
	_cotton_spawned_for_battle = true
	_append_cotton_event(COTTON_SPAWNED_EVENT)
	_update_cotton_ui()


func _connect_cotton_signals(cotton: CursedCottonAdd) -> void:
	var hit_callback: Callable = _on_cotton_hit.bind(cotton)
	var cleared_callback: Callable = _on_cotton_cleared.bind(cotton)
	var exited_callback: Callable = _on_cotton_tree_exited.bind(cotton)
	if not cotton.cotton_hit.is_connected(hit_callback):
		cotton.cotton_hit.connect(hit_callback)
	if not cotton.cotton_cleared.is_connected(cleared_callback):
		cotton.cotton_cleared.connect(cleared_callback)
	if not cotton.tree_exited.is_connected(exited_callback):
		cotton.tree_exited.connect(exited_callback)


func _disconnect_cotton_signals(cotton: CursedCottonAdd) -> void:
	if not is_instance_valid(cotton):
		return
	var hit_callback: Callable = _on_cotton_hit.bind(cotton)
	var cleared_callback: Callable = _on_cotton_cleared.bind(cotton)
	var exited_callback: Callable = _on_cotton_tree_exited.bind(cotton)
	if cotton.cotton_hit.is_connected(hit_callback):
		cotton.cotton_hit.disconnect(hit_callback)
	if cotton.cotton_cleared.is_connected(cleared_callback):
		cotton.cotton_cleared.disconnect(cleared_callback)
	if cotton.tree_exited.is_connected(exited_callback):
		cotton.tree_exited.disconnect(exited_callback)


func _on_cotton_hit(_ball: Pinball, cotton: CursedCottonAdd) -> void:
	if not _active_cottons.has(cotton):
		return
	_append_cotton_event(COTTON_HIT_EVENT)


func _on_cotton_cleared(cotton: CursedCottonAdd) -> void:
	if not _active_cottons.has(cotton):
		return
	_active_cottons.erase(cotton)
	_append_cotton_event(COTTON_CLEARED_EVENT)
	_update_cotton_ui()


func _on_cotton_tree_exited(cotton: CursedCottonAdd) -> void:
	_active_cottons.erase(cotton)
	_update_cotton_ui()


func _on_cotton_battle_completed() -> void:
	_remove_all_cottons()


func _on_cotton_reset_pressed() -> void:
	call_deferred(&"_reset_cotton_battle_state")


func _reset_cotton_battle_state() -> void:
	_remove_all_cottons()
	_cotton_spawned_for_battle = false
	_update_cotton_ui()


func _remove_all_cottons() -> void:
	var existing_cottons: Array[CursedCottonAdd] = []
	existing_cottons.assign(_active_cottons)
	_active_cottons.clear()
	for cotton: CursedCottonAdd in existing_cottons:
		if not is_instance_valid(cotton):
			continue
		_disconnect_cotton_signals(cotton)
		if not cotton.is_queued_for_deletion():
			cotton.queue_free()
	_update_cotton_ui()


func _prune_invalid_cottons() -> void:
	var valid_cottons: Array[CursedCottonAdd] = []
	for cotton: CursedCottonAdd in _active_cottons:
		if is_instance_valid(cotton) and not cotton.is_queued_for_deletion():
			valid_cottons.append(cotton)
	_active_cottons = valid_cottons


func _update_cotton_ui() -> void:
	if is_instance_valid(cotton_label):
		cotton_label.text = "Cotton: %d / 2" % get_active_cotton_count()


func _append_cotton_event(message: String) -> void:
	_cotton_event_messages.append(message)
	while _cotton_event_messages.size() > MAX_COTTON_EVENT_COUNT:
		_cotton_event_messages.pop_front()
	if is_instance_valid(cotton_event_log):
		cotton_event_log.text = "\n".join(_cotton_event_messages)
