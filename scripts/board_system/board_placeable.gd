@tool
class_name BoardPlaceable
extends Node2D


@export var placement_id: StringName = &"placement"
@export var zone_id: StringName = &"zone"
@export var socket_id: StringName
@export var kind_id_override: StringName
@export_range(1.0, 512.0, 1.0, "suffix:px") var reserve_radius := 72.0:
	set(value):
		reserve_radius = maxf(value, 1.0)
		queue_redraw()
@export var show_reserve_radius := true:
	set(value):
		show_reserve_radius = value
		queue_redraw()


var committed := false
var runtime_locked := false
var _locked_transform := Transform2D.IDENTITY
var _restoring_transform := false


func _ready() -> void:
	set_notify_transform(true)
	set_notify_local_transform(true)
	queue_redraw()


func _process(_delta: float) -> void:
	_restore_locked_transform()


func get_bumper() -> Bumper:
	for candidate: Node in find_children("*", "", true, false):
		if candidate is Bumper:
			return candidate as Bumper
	return null


func get_kind_id() -> StringName:
	if not kind_id_override.is_empty():
		return kind_id_override
	var bumper := get_bumper()
	if bumper != null and bumper.settings != null:
		return bumper.settings.bumper_kind_id
	return &""


func is_repair_part() -> bool:
	var bumper := get_bumper()
	return bumper != null and bumper.is_repair_part()


func set_committed(value: bool) -> void:
	committed = value
	queue_redraw()


func set_runtime_locked(value: bool) -> void:
	runtime_locked = value
	set_process(runtime_locked)
	if runtime_locked:
		_locked_transform = transform


func _notification(what: int) -> void:
	if what not in [NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_LOCAL_TRANSFORM_CHANGED]:
		return
	_restore_locked_transform()


func _restore_locked_transform() -> void:
	if not runtime_locked \
			or _restoring_transform \
			or transform.is_equal_approx(_locked_transform):
		return
	_restoring_transform = true
	transform = _locked_transform
	_restoring_transform = false


func _draw() -> void:
	if not show_reserve_radius:
		return
	var ring_color := (
		Color(0.24, 0.88, 0.74, 0.75)
		if committed
		else Color(0.95, 0.78, 0.24, 0.75)
	)
	draw_arc(Vector2.ZERO, reserve_radius, 0.0, TAU, 64, ring_color, 3.0)
	draw_circle(Vector2.ZERO, 5.0, ring_color)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if placement_id.is_empty():
		warnings.append("Placeable requires a non-empty placement_id.")
	if zone_id.is_empty():
		warnings.append("Placeable requires a target zone_id.")
	if socket_id.is_empty():
		warnings.append("Placeable requires a target socket_id.")
	if get_bumper() == null:
		warnings.append("Placeable requires a Bumper descendant.")
	elif not is_repair_part():
		warnings.append("The descendant Bumper must have settings.is_repair_part enabled.")
	return warnings
