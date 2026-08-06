@tool
class_name WaveSfxBinder
extends Node
## 게임 시그널을 SFX 요청으로 옮기는 곳입니다. 배선은 전부 여기 한 군데에 모읍니다.
##
## ★ `get_tree().current_scene` 을 쓰지 않습니다.
##   씬을 코드로 인스턴스화해서 붙이면 current_scene 이 null 이라, 아무것도 못 찾고
##   **에러 없이 조용히 실패**합니다. 소리가 안 나는데 원인을 알 수 없습니다.
##   대신 자기가 매달린 가지의 꼭대기를 찾아 그 아래에서만 훑습니다.
##
## ★ 벽·플리퍼 접촉은 `ComboCollisionBridge` 를 재사용합니다.
##   공의 body_entered 를 직접 구독하면 **대기·복귀 중인 플리퍼의 패시브 접촉**을
##   거르는 로직을 처음부터 다시 짜야 합니다. 브릿지에 이미 들어 있습니다
##   (combo_collision_bridge.gd:167-171).


const BRIDGE_WALL_SIGNAL: StringName = &"wall_contact_registered"
const BRIDGE_FLIPPER_SIGNAL: StringName = &"flipper_contact_registered"
const PARRY_SIGNAL: StringName = &"parry_resolved"
const FLIPPER_STATE_SIGNAL: StringName = &"state_changed"

const FLIPPER_GROUP: StringName = &"combo_flippers"

## FlipperState.Type 과 값을 맞춥니다.
const FLIPPER_STATE_ACTIVE: int = 1
const FLIPPER_STATE_RETURNING: int = 3

const PARRY_GRADE_NONE: int = 0


var _director: SfxDirector
var _bound_flippers: Array[Node] = []
var _bound_bridges: Array[Node] = []
var _source_controllers: Dictionary = {}

## ★ FlipperSelector 에는 시그널이 하나도 없습니다.
##   그런데 검수 항목에 "선택음·작동음·패링 성공음이 서로 다른가"(p.5)가 있어
##   선택음은 반드시 필요합니다. 컨트롤러가 4개뿐이라 폴링 비용이 무시할 만하고,
##   기존 스크립트를 고치지 않아도 됩니다.
##   시그널 신설은 별도 작업으로 남겨둡니다.
var _selector: Node
var _last_selected: Object = null


@export_category("Wave SFX 배선")

## 비워두면 형제 노드에서 찾습니다.
@export var director_path: NodePath

@export_group("규칙")
@export var wall_rules: WallSfxRules
@export var flipper_rules: FlipperSfxRules
@export var ball_library: BallSfxLibrary


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_director = _resolve_director()
	if _director == null:
		push_warning("SfxDirector 를 못 찾아 SFX 배선을 건너뜁니다.")
		return

	var scan_root := _scan_root()
	if scan_root == null:
		return

	_bind_bridges(scan_root)
	_bind_flippers()
	_bind_selector(scan_root)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _selector == null or flipper_rules == null:
		return

	var current: Variant = _selector.get(&"selected")
	if current == _last_selected:
		return

	# 시작 시점의 최초 선택은 조작이 아니므로 울리지 않습니다.
	var had_previous := _last_selected != null
	_last_selected = current

	if had_previous and current != null and flipper_rules.select_cue != null:
		var controller := _controller_for_source(_selector)
		if controller != null:
			controller.play(flipper_rules.select_cue, 0.0)


## 무엇에 몇 개 연결됐는지입니다. 배선이 조용히 실패하는 것을 잡는 테스트용입니다.
func get_bound_source_counts() -> Dictionary:
	return {
		&"bridges": _bound_bridges.size(),
		&"flippers": _bound_flippers.size(),
	}


func get_director() -> SfxDirector:
	return _director


# ── 발견 ────────────────────────────────────────────────────

## 자기가 매달린 가지의 꼭대기입니다. current_scene 을 쓰지 않는 이유는 클래스 주석 참고.
func _scan_root() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var node: Node = self
	while node.get_parent() != null and node.get_parent() != tree.root:
		node = node.get_parent()

	return node


func _resolve_director() -> SfxDirector:
	if not director_path.is_empty():
		var explicit := get_node_or_null(director_path) as SfxDirector
		if explicit != null:
			return explicit

	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is SfxDirector:
				return child

	return null


## 브릿지는 그룹에 등록돼 있지 않아 가지 안에서 시그널로 찾습니다.
func _bind_bridges(node: Node) -> void:
	if node.has_signal(BRIDGE_WALL_SIGNAL) and node.has_signal(BRIDGE_FLIPPER_SIGNAL):
		if not node.is_connected(BRIDGE_WALL_SIGNAL, _on_wall_contact):
			node.connect(BRIDGE_WALL_SIGNAL, _on_wall_contact)
		if not node.is_connected(BRIDGE_FLIPPER_SIGNAL, _on_flipper_contact):
			node.connect(BRIDGE_FLIPPER_SIGNAL, _on_flipper_contact)
		_bound_bridges.append(node)

	for child in node.get_children():
		_bind_bridges(child)


## 플리퍼는 그룹으로 찾되, **같은 가지에 있는 것만** 잡습니다.
## 같은 SceneTree 에 씬 사본이 둘 있으면 남의 플리퍼를 잡을 수 있습니다.
func _bind_flippers() -> void:
	var scan_root := _scan_root()
	if scan_root == null:
		return

	for node in get_tree().get_nodes_in_group(FLIPPER_GROUP):
		if not _is_in_branch(node, scan_root):
			continue

		if node.has_signal(PARRY_SIGNAL) \
				and not node.is_connected(PARRY_SIGNAL, _on_parry_resolved):
			node.connect(PARRY_SIGNAL, _on_parry_resolved)

		if node.has_signal(FLIPPER_STATE_SIGNAL):
			var bound := _on_flipper_state_changed.bind(node)
			if not node.is_connected(FLIPPER_STATE_SIGNAL, bound):
				node.connect(FLIPPER_STATE_SIGNAL, bound)

		_bound_flippers.append(node)


## FlipperSelector 를 찾습니다. 그룹에 등록돼 있지 않고 시그널도 없어
## 가지 안에서 속성과 메서드로 알아봅니다.
func _bind_selector(node: Node) -> void:
	if node.has_method(&"select_controller") and node.get(&"selected") != null:
		_selector = node
		_last_selected = node.get(&"selected")
		return

	for child in node.get_children():
		if _selector == null:
			_bind_selector(child)


## 선택 폴링이 붙었는지입니다. 테스트용입니다.
func has_selector() -> bool:
	return _selector != null


func _is_in_branch(node: Node, branch_root: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == branch_root:
			return true
		current = current.get_parent()

	return false


# ── 소스별 컨트롤러 ─────────────────────────────────────────

## 공에 붙는 컨트롤러입니다. 문서 12-3 의 노드 구조대로 공의 자식으로 답니다.
## 씬을 고치지 않고 런타임에 붙입니다 — Flipper._ensure_parry_feedback() 과 같은 방식입니다.
func _controller_for_ball(ball: Node) -> BallAudioController:
	if not is_instance_valid(ball):
		return null

	var existing := ball.get_node_or_null(NodePath(BallAudioController.NODE_NAME))
	var controller := existing as BallAudioController
	if controller == null:
		controller = BallAudioController.new()
		controller.name = String(BallAudioController.NODE_NAME)
		ball.add_child(controller)

	controller.bind_director(_director)
	return controller


## 공이 아닌 소스(플리퍼 조작음 등)의 컨트롤러입니다. 바인더의 자식으로 둡니다.
func _controller_for_source(source: Object) -> BallAudioController:
	var id := source.get_instance_id()
	var controller: BallAudioController = _source_controllers.get(id)

	if controller == null or not is_instance_valid(controller):
		controller = BallAudioController.new()
		controller.name = "_Source%d" % id
		add_child(controller)
		controller.bind_director(_director)
		_source_controllers[id] = controller

	return controller


func _ball_speed(ball: Node) -> float:
	if not is_instance_valid(ball):
		return 0.0

	var velocity: Variant = ball.get(&"linear_velocity")
	if velocity == null:
		return 0.0

	return (velocity as Vector2).length()


# ── 시그널 처리 ─────────────────────────────────────────────

func _on_wall_contact(_wall: Node, ball: RigidBody2D) -> void:
	if wall_rules == null or wall_rules.hit_cue == null:
		return

	var controller := _controller_for_ball(ball)
	if controller != null:
		controller.play(wall_rules.hit_cue, _ball_speed(ball))


func _on_flipper_contact(_flipper: Node, ball: RigidBody2D) -> void:
	if flipper_rules == null:
		return

	var speed := _ball_speed(ball)
	var cue := flipper_rules.get_hit_cue(speed)
	if cue == null:
		return

	var controller := _controller_for_ball(ball)
	if controller != null:
		controller.play(cue, speed)


func _on_parry_resolved(
	ball: RigidBody2D,
	grade: int,
	_contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_speed_multiplier: float
) -> void:
	if flipper_rules == null or grade == PARRY_GRADE_NONE:
		return

	var cue := flipper_rules.get_parry_cue(grade)
	if cue == null:
		return

	# ★ 공의 컨트롤러로 보내야 같은 프레임의 타격음·충돌음이 래치로 막힙니다.
	var controller := _controller_for_ball(ball)
	if controller != null:
		controller.play(cue, _ball_speed(ball))


func _on_flipper_state_changed(_previous: int, current: int, flipper: Node) -> void:
	if flipper_rules == null:
		return

	var cue: SfxCue = null
	match current:
		FLIPPER_STATE_ACTIVE:
			cue = flipper_rules.activate_cue
		FLIPPER_STATE_RETURNING:
			cue = flipper_rules.return_cue

	if cue == null:
		return

	var controller := _controller_for_source(flipper)
	if controller != null:
		controller.play(cue, 0.0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if wall_rules == null:
		warnings.append("벽 SFX 규칙이 없으면 벽 충돌음이 안 납니다.")

	if flipper_rules == null:
		warnings.append("플리퍼 SFX 규칙이 없으면 타격·패링음이 안 납니다.")

	return warnings
