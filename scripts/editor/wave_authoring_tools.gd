@tool
class_name WaveAuthoringTools
extends Node


@export_category("Authoring Targets")
@export var coordinator: WaveRuntimeCoordinator
@export var coin_field: CoinFieldController
@export var default_board_layout: BoardLayout
@export var board_placement_bridge: BoardWavePlacementBridge
@export var repair_placement_controller: RepairPartPlacementController
@export var reward_shop_bridge: WaveRewardShopBridge
@export var repair_effect_router: RepairEffectRouter

@export_category("Bumper Add Delete")
@export var bumper_scene: PackedScene
@export var bumper_position := Vector2.ZERO
## Scene 트리의 범퍼를 이 슬롯으로 드래그한 뒤 삭제 버튼을 누릅니다.
@export var bumper_to_delete: Bumper
@export_tool_button("Add Bumper", "Add") var add_bumper_button = add_bumper
@export_tool_button("Delete Selected Bumper", "Remove")
var delete_bumper_button = delete_selected_bumper
@export_tool_button("Restore Inherited Bumpers", "Reload")
var restore_bumpers_button = restore_inherited_bumpers

@export_category("Coin Add Delete")
@export var coin_route_kind := CoinSpawnPoint.RouteKind.MAIN
@export var coin_position := Vector2.ZERO
## Scene 트리의 코인 Marker2D를 이 슬롯으로 드래그한 뒤 삭제 버튼을 누릅니다.
@export var coin_to_delete: CoinSpawnPoint
@export_tool_button("Add Coin", "Add") var add_coin_button = add_coin
@export_tool_button("Delete Selected Coin", "Remove")
var delete_coin_button = delete_selected_coin
@export_tool_button("Restore Inherited Coins", "Reload")
var restore_coins_button = restore_inherited_coins
@export_tool_button("Validate Coin Placement", "Search")
var validate_coins_button = validate_coin_placement

@export_category("Stage Board Layout")
## 적용할 BoardLayout 씬입니다. Apply 버튼을 누르면 현재 스테이지에 로컬 인스턴스로 추가됩니다.
@export var board_layout_scene: PackedScene
## Apply 버튼으로 생성한 스테이지 전용 레이아웃입니다.
@export_node_path("BoardLayout") var stage_board_layout_path: NodePath
@export_tool_button("Apply Board Layout Scene", "Add")
var apply_layout_button = apply_board_layout_scene
@export_tool_button("Use Default Board Layout", "Reload")
var use_default_layout_button = use_default_board_layout


func _enter_tree() -> void:
	_apply_active_layout_dependencies()


func add_bumper() -> Bumper:
	if not Engine.is_editor_hint() or coordinator == null \
			or coordinator.bumpers_root == null or bumper_scene == null:
		push_warning("Assign a Bumper Scene before pressing Add Bumper.")
		return null
	var instance := bumper_scene.instantiate()
	if not instance is Bumper:
		if instance != null:
			instance.free()
		push_warning("The selected scene root must inherit Bumper.")
		return null
	var bumper := instance as Bumper
	bumper.name = _unique_child_name(coordinator.bumpers_root, "Bumper")
	bumper.position = bumper_position
	bumper.bumper_id = _unique_bumper_id(bumper)
	coordinator.bumpers_root.add_child(bumper)
	_assign_editor_owner(bumper)
	coordinator.enforce_stage_bumper_limits = false
	coordinator.sync_expected_bumper_roster()
	_select_editor_node(bumper)
	return bumper


func delete_selected_bumper() -> bool:
	if not Engine.is_editor_hint() or coordinator == null \
			or coordinator.bumpers_root == null:
		return false
	var bumper := bumper_to_delete
	if bumper == null:
		bumper = _get_editor_selected_node() as Bumper
	if bumper == null or not coordinator.bumpers_root.is_ancestor_of(bumper):
		push_warning("Select a bumper under Bumpers before pressing Delete Selected Bumper.")
		return false
	var edited_root := get_tree().edited_scene_root
	if edited_root != null and bumper.owner == edited_root:
		bumper.get_parent().remove_child(bumper)
		bumper.free()
	else:
		coordinator.set_bumper_disabled(bumper, true)
	coordinator.enforce_stage_bumper_limits = false
	coordinator.sync_expected_bumper_roster()
	bumper_to_delete = null
	return true


func restore_inherited_bumpers() -> void:
	if coordinator == null:
		return
	coordinator.restore_disabled_bumpers()
	coordinator.enforce_stage_bumper_limits = false
	coordinator.sync_expected_bumper_roster()


func add_coin() -> CoinSpawnPoint:
	if not Engine.is_editor_hint() or coin_field == null \
			or coin_field.spawn_points_root == null:
		push_warning("Coin Field requires a SpawnPoints root.")
		return null
	var point := CoinSpawnPoint.new()
	var prefix := "Main" if coin_route_kind == CoinSpawnPoint.RouteKind.MAIN else "Risk"
	point.name = _unique_child_name(coin_field.spawn_points_root, prefix)
	point.point_id = _unique_coin_id(coin_route_kind)
	point.route_kind = coin_route_kind
	point.position = coin_position
	coin_field.spawn_points_root.add_child(point)
	_assign_editor_owner(point)
	coin_field.sync_expected_counts_to_authored_points()
	_select_editor_node(point)
	return point


func delete_selected_coin() -> bool:
	if not Engine.is_editor_hint() or coin_field == null \
			or coin_field.spawn_points_root == null:
		return false
	var point := coin_to_delete
	if point == null:
		point = _get_editor_selected_node() as CoinSpawnPoint
	if point == null or not coin_field.spawn_points_root.is_ancestor_of(point):
		push_warning("Select a marker under CoinSystem/SpawnPoints before pressing Delete Selected Coin.")
		return false
	var edited_root := get_tree().edited_scene_root
	if edited_root != null and point.owner == edited_root:
		point.get_parent().remove_child(point)
		point.free()
	else:
		coin_field.set_spawn_point_disabled(point, true)
	coin_field.sync_expected_counts_to_authored_points()
	coin_to_delete = null
	return true


func restore_inherited_coins() -> void:
	if coin_field != null:
		coin_field.restore_disabled_spawn_points()


func validate_coin_placement() -> bool:
	if coin_field == null:
		return false
	var errors := coin_field.validate_authored_placement()
	if errors.is_empty():
		print("PASS: coin placement authoring validation")
		return true
	for message: String in errors:
		push_warning(message)
	return false


func apply_board_layout_scene() -> BoardLayout:
	if not Engine.is_editor_hint() or board_layout_scene == null:
		push_warning("Assign a Board Layout Scene before pressing Apply.")
		return null
	var instance := board_layout_scene.instantiate()
	if not instance is BoardLayout:
		if instance != null:
			instance.free()
		push_warning("The selected scene root must inherit BoardLayout.")
		return null
	_remove_local_stage_layout()
	var layout := instance as BoardLayout
	var scene_root := get_tree().edited_scene_root
	if scene_root == null:
		layout.free()
		return null
	layout.name = _unique_child_name(scene_root, "StageRepairBoardLayout")
	scene_root.add_child(layout)
	layout.owner = scene_root
	stage_board_layout_path = get_path_to(layout)
	_apply_active_layout_dependencies()
	_select_editor_node(layout)
	return layout


func use_default_board_layout() -> void:
	if not Engine.is_editor_hint():
		return
	_remove_local_stage_layout()
	stage_board_layout_path = NodePath()
	_apply_active_layout_dependencies()
	if default_board_layout != null:
		_select_editor_node(default_board_layout)


func get_active_board_layout() -> BoardLayout:
	var stage_layout := get_node_or_null(stage_board_layout_path) as BoardLayout
	return stage_layout if stage_layout != null else default_board_layout


func _apply_active_layout_dependencies() -> void:
	var active_layout := get_active_board_layout()
	if active_layout == null:
		return
	if default_board_layout != null:
		default_board_layout.visible = active_layout == default_board_layout
	active_layout.visible = true
	var session := _find_placement_session(active_layout)
	if coin_field != null:
		coin_field.board_layout = active_layout
	if board_placement_bridge != null:
		board_placement_bridge.placement_session = session
	if repair_placement_controller != null:
		repair_placement_controller.placement_session = session
	if reward_shop_bridge != null:
		reward_shop_bridge.placement_session = session
	if repair_effect_router != null:
		repair_effect_router.runtime_root_path = repair_effect_router.get_path_to(active_layout)


func _find_placement_session(layout: BoardLayout) -> BoardPlacementSession:
	if layout == null:
		return null
	for child: Node in layout.get_children():
		if child is BoardPlacementSession:
			return child as BoardPlacementSession
	return null


func _remove_local_stage_layout() -> void:
	var layout := get_node_or_null(stage_board_layout_path) as BoardLayout
	if layout == null or layout == default_board_layout:
		return
	var edited_root := get_tree().edited_scene_root
	if edited_root != null and layout.owner == edited_root:
		layout.get_parent().remove_child(layout)
		layout.free()


func _unique_bumper_id(bumper: Bumper) -> StringName:
	var kind := "bumper"
	if bumper.settings != null and not bumper.settings.bumper_kind_id.is_empty():
		kind = String(bumper.settings.bumper_kind_id)
	var used: Dictionary = {}
	for existing: Bumper in coordinator.get_bumpers():
		used[existing.bumper_id] = true
	var index := 1
	var candidate := StringName("%s_%02d" % [kind, index])
	while used.has(candidate):
		index += 1
		candidate = StringName("%s_%02d" % [kind, index])
	return candidate


func _unique_coin_id(route_kind: CoinSpawnPoint.RouteKind) -> StringName:
	var prefix := "main" if route_kind == CoinSpawnPoint.RouteKind.MAIN else "risk"
	var used: Dictionary = {}
	for point: CoinSpawnPoint in coin_field.get_spawn_points():
		used[point.point_id] = true
	var index := 1
	var candidate := StringName("%s_%02d" % [prefix, index])
	while used.has(candidate):
		index += 1
		candidate = StringName("%s_%02d" % [prefix, index])
	return candidate


func _unique_child_name(parent: Node, prefix: String) -> String:
	var index := 1
	var candidate := "%s%02d" % [prefix, index]
	while parent.has_node(NodePath(candidate)):
		index += 1
		candidate = "%s%02d" % [prefix, index]
	return candidate


func _assign_editor_owner(node: Node) -> void:
	var edited_root := get_tree().edited_scene_root
	if edited_root != null:
		node.owner = edited_root


func _get_editor_selected_node() -> Node:
	if not Engine.has_singleton(&"EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton(&"EditorInterface")
	var selection: Object = editor_interface.call(&"get_selection")
	if selection == null:
		return null
	var nodes: Array = selection.call(&"get_selected_nodes")
	return nodes[0] as Node if not nodes.is_empty() else null


func _select_editor_node(node: Node) -> void:
	if node == null or not Engine.has_singleton(&"EditorInterface"):
		return
	var editor_interface: Object = Engine.get_singleton(&"EditorInterface")
	var selection: Object = editor_interface.call(&"get_selection")
	if selection == null:
		return
	selection.call(&"clear")
	selection.call(&"add_node", node)
