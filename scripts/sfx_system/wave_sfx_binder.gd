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
const BUMPER_GROUP: StringName = &"bumper_objects"
const BALL_GROUP: StringName = &"pinball_balls"
const BODY_ENTERED_SIGNAL: StringName = &"body_entered"

# Tier 3·4 시그널. 전부 기존 스크립트에 이미 있는 것들입니다.
const LAUNCH_SIGNAL: StringName = &"ball_launched"
const DRAIN_SIGNAL: StringName = &"ball_drained"
const COMBO_CHANGED_SIGNAL: StringName = &"combo_changed"
const COMBO_TIER_SIGNAL: StringName = &"combo_tier_changed"
const COMBO_FINISHED_SIGNAL: StringName = &"combo_finished"
const TARGET_REACHED_SIGNAL: StringName = &"target_score_reached"
const BALLS_EXHAUSTED_SIGNAL: StringName = &"wave_balls_exhausted"
const BUMPER_RESPONSE_SIGNAL: StringName = &"response_resolved"
const BUMPER_STATE_SIGNAL: StringName = &"state_changed"
const SHOT_CONTROL_STARTED_SIGNAL: StringName = &"control_started"
const SHOT_CONTROL_ENDED_SIGNAL: StringName = &"control_ended"

## BumperState 와 값을 맞춥니다.
const BUMPER_STATE_DESTROYED: int = 1
const BUMPER_STATE_RESPAWN_TELEGRAPH: int = 3

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

var _bound_bumpers: Array[Node] = []
var _bound_balls: Array[Node] = []

## 공별로 "이 물리 프레임에 타격음을 이미 냈는가"를 적어 둡니다.
var _hit_frames: Dictionary = {}

## 플리퍼 상태 전이도 프레임 단위로 묶습니다. 이유는 _on_flipper_state_changed 참고.
var _state_frames: Dictionary = {}
var _bound_emitters: Array[Node] = []


@export_category("Wave SFX 배선")

## 비워두면 형제 노드에서 찾습니다.
@export var director_path: NodePath

@export_group("규칙")
@export var wall_rules: WallSfxRules
@export var flipper_rules: FlipperSfxRules
@export var ball_library: BallSfxLibrary
@export var ball_flow_rules: BallFlowSfxRules
@export var combo_rules: ComboSfxRules
@export var bumper_rules: BumperSfxRules


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
	_bind_bumpers()
	_bind_emitters(scan_root)
	_bind_ball_contacts()


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
		&"bumpers": _bound_bumpers.size(),
		&"balls": _bound_balls.size(),
		&"emitters": _bound_emitters.size(),
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


## 범퍼는 그룹으로 찾습니다. 플리퍼와 같은 이유로 같은 가지의 것만 잡습니다.
##
## 태엽 대포(`ShotBumper`)는 일반 범퍼에 없는 조작 시그널을 더 갖고 있어
## 같은 자리에서 함께 잡습니다. 별도로 훑으면 두 번 연결될 수 있습니다.
func _bind_bumpers() -> void:
	var scan_root := _scan_root()
	if scan_root == null:
		return

	for node in get_tree().get_nodes_in_group(BUMPER_GROUP):
		if not _is_in_branch(node, scan_root):
			continue

		_connect_once(node, BUMPER_RESPONSE_SIGNAL, _on_bumper_response)
		_connect_once(node, BUMPER_STATE_SIGNAL,
			_on_bumper_state_changed.bind(node))
		_connect_once(node, SHOT_CONTROL_STARTED_SIGNAL, _on_cannon_control)
		_connect_once(node, SHOT_CONTROL_ENDED_SIGNAL, _on_cannon_fire)

		_bound_bumpers.append(node)


## 흐름·콤보 시그널을 내는 노드들입니다.
##
## ★ 이것들은 그룹에 등록돼 있지 않고 종류도 제각각입니다
##   (`PinballLauncher` · `WaveBallFlowController` · `ComboSystem` ·
##    `ComboWaveController`). 클래스로 찾으면 어느 하나가 이름을 바꿀 때
##   조용히 무음이 됩니다. **시그널 이름으로 찾습니다** — 시그널이 있으면
##   그것이 우리가 원하는 노드입니다.
func _bind_emitters(node: Node) -> void:
	var connected := false

	for entry: Array in [
		[LAUNCH_SIGNAL, _on_ball_launched],
		[DRAIN_SIGNAL, _on_ball_drained],
		[COMBO_CHANGED_SIGNAL, _on_combo_changed],
		[COMBO_TIER_SIGNAL, _on_combo_tier_changed],
		[COMBO_FINISHED_SIGNAL, _on_combo_finished],
		[TARGET_REACHED_SIGNAL, _on_target_score_reached],
		[BALLS_EXHAUSTED_SIGNAL, _on_wave_balls_exhausted],
	]:
		if _connect_once(node, entry[0], entry[1]):
			connected = true

	if connected:
		_bound_emitters.append(node)

	for child in node.get_children():
		_bind_emitters(child)


## 시그널이 있으면 한 번만 잇습니다. 이미 이어져 있으면 아무것도 하지 않습니다.
func _connect_once(node: Node, signal_name: StringName, target: Callable) -> bool:
	if not node.has_signal(signal_name):
		return false

	if node.is_connected(signal_name, target):
		return false

	node.connect(signal_name, target)
	return true


## ★ 공이 플리퍼에 닿는 **모든** 순간을 잡습니다.
##
## 브릿지의 `flipper_contact_registered` 는 **ACTIVE 스윕 접촉일 때만** 옵니다
## (combo_collision_bridge.gd:165-172). 콤보 타이머가 대기·복귀 중인 플리퍼의
## 패시브 접촉으로 갱신되면 안 되기 때문입니다. 그건 콤보에는 맞는 조건입니다.
##
## 그런데 **소리는 조건이 다릅니다.** 공이 멈춰 있는 플리퍼에 부딪혀도 소리는
## 나야 합니다. 실제로 "플리퍼가 공을 칠 때마다 소리가 나야 하는데 안 난다"는
## 지적이 나왔고, 원인이 정확히 이것이었습니다.
##
## 공은 `contact_monitor` 가 켜져 있어(pinball.gd:92) 접촉을 직접 알려줍니다.
## 브릿지 구독은 그대로 둡니다 — 겹쳐 울리는 것은 큐의 최소 간격(0.04초)이 막습니다.
func _bind_ball_contacts() -> void:
	var scan_root := _scan_root()
	if scan_root == null:
		return

	for ball in get_tree().get_nodes_in_group(BALL_GROUP):
		if not _is_in_branch(ball, scan_root):
			continue

		_connect_once(ball, BODY_ENTERED_SIGNAL, _on_ball_body_entered.bind(ball))
		_bound_balls.append(ball)


## 벽은 브릿지가 맡습니다. 여기서는 플리퍼 접촉만 봅니다.
func _on_ball_body_entered(body: Node, ball: RigidBody2D) -> void:
	if body == null or not body.is_in_group(FLIPPER_GROUP):
		return

	_play_flipper_hit(ball)


## ★ 한 번의 접촉에는 타격음 **하나**만 납니다.
##
## 같은 접촉이 두 경로로 들어옵니다 — 공의 `body_entered` 와 브릿지의
## `flipper_contact_registered`. 둘 다 각자 속도를 읽어 큐를 고르는데,
## 그 사이에 속도가 임계값(1200px/s)을 넘나들면 **하나는 일반 타격,
## 하나는 강한 타격**을 골라 두 소리가 겹칩니다. 큐가 다르면 최소 간격
## 스로틀도 막지 못합니다.
##
## 그래서 물리 프레임 단위로 래치를 걸어 먼저 온 것만 울립니다.
## 세게 친 것은 강한 타격 하나로 들려야지, 둘이 같이 나면 안 됩니다.
func _play_flipper_hit(ball: RigidBody2D) -> void:
	if flipper_rules == null or not is_instance_valid(ball):
		return

	var frame := Engine.get_physics_frames()
	var ball_id := ball.get_instance_id()
	if _hit_frames.get(ball_id, -1) == frame:
		return

	var speed := _ball_speed(ball)
	var cue := flipper_rules.get_hit_cue(speed)
	if cue == null:
		return

	var controller := _controller_for_ball(ball)
	if controller == null:
		return

	_hit_frames[ball_id] = frame
	controller.play(cue, speed)


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
	# 공의 body_entered 와 같은 래치를 탑니다. 자세한 이유는 _play_flipper_hit 참고.
	_play_flipper_hit(ball)



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


## ★ Space 한 번에 소리 하나.
##
## 한 컨트롤러의 **좌우 플리퍼가 함께** 움직입니다. 그래서 상태 전이가 두 번
## 오고 작동음도 두 번 요청됩니다. 문제가 둘입니다.
##
##   ① 기계는 하나인데 소리가 둘이면 겹쳐서 지저분해집니다
##   ② 작동음·복귀음은 AMBIENT 클래스(하드캡 2)라, 좌우 작동음이 두 자리를
##      다 먹으면 **뒤따라오는 복귀음이 통째로 버려집니다.**
##      실제로 그래서 "A3 가 작동을 안 한다"는 지적이 나왔습니다.
##
## 그래서 같은 물리 프레임의 같은 상태 전이는 **먼저 온 것만** 울립니다.
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

	var frame := Engine.get_physics_frames()
	if _state_frames.get(current, -1) == frame:
		return

	_state_frames[current] = frame

	# 소스를 플리퍼가 아니라 바인더로 둡니다. 좌우가 각자 컨트롤러를 가지면
	# 연타 감쇠와 최소 간격이 따로 세어져 묶은 의미가 없어집니다.
	var controller := _controller_for_source(self)
	if controller != null:
		controller.play(cue, 0.0)



# ── Tier 3 흐름·콤보 ────────────────────────────────────────

## ★ 발사 세기는 speed 가 정합니다. 살짝 당긴 것과 끝까지 당긴 것이
##   같은 소리면 조작 피드백이 죽습니다.
func _on_ball_launched(ball: Node, _direction: Vector2, speed: float) -> void:
	if ball_flow_rules == null or ball_flow_rules.launch_cue == null:
		return

	var controller := _controller_for_ball(ball)
	if controller != null:
		controller.play(ball_flow_rules.launch_cue,
			ball_flow_rules.get_launch_speed(speed))


## ★ 컨트롤러를 공이 아니라 바인더에 답니다.
##   낙하한 공은 곧 사라집니다. 공에 달면 소리가 나다 말고 끊깁니다.
func _on_ball_drained(_ball: Node, _remaining: int) -> void:
	if ball_flow_rules == null or ball_flow_rules.drain_cue == null:
		return

	var controller := _controller_for_source(self)
	if controller != null:
		controller.play(ball_flow_rules.drain_cue, 0.0)


## 콤보가 오를 때마다. **피치 사다리가 이 소리의 전부입니다.**
func _on_combo_changed(combo_count: int, _tier: int, _time_remaining: float) -> void:
	if combo_rules == null or combo_rules.rise_cue == null:
		return

	if combo_count <= 0:
		return

	var controller := _controller_for_source(combo_rules)
	if controller == null:
		return

	controller.play_with_pitch(combo_rules.rise_cue, 0.0,
		combo_rules.get_rise_pitch(combo_count))


func _on_combo_tier_changed(previous: int, current: int, _count: int) -> void:
	# 단계가 내려갈 때는 울리지 않습니다. 오른 것만 알립니다.
	if combo_rules == null or combo_rules.tier_cue == null or current <= previous:
		return

	var controller := _controller_for_source(combo_rules)
	if controller != null:
		controller.play(combo_rules.tier_cue, 0.0)


## ★ reason 열거값이 아니라 **점수가 붙었는지**로 실패를 가릅니다.
##   combo_system.gd 의 열거값이 바뀌어도 따라 깨지지 않습니다.
func _on_combo_finished(
	_count: int, _tier: int, awarded_score: int, _reason: int
) -> void:
	if combo_rules == null or combo_rules.timeout_cue == null:
		return

	if not combo_rules.is_failed_finish(awarded_score):
		return

	var controller := _controller_for_source(combo_rules)
	if controller != null:
		controller.play(combo_rules.timeout_cue, 0.0)


func _on_target_score_reached(_current: int, _target: int) -> void:
	if combo_rules == null:
		return

	# 목표 도달이 곧 웨이브 승리입니다. 승리음이 있으면 그것을 우선합니다.
	var cue := combo_rules.wave_won_cue
	if cue == null:
		cue = combo_rules.target_reached_cue

	if cue == null:
		return

	var controller := _controller_for_source(combo_rules)
	if controller != null:
		controller.play(cue, 0.0)


func _on_wave_balls_exhausted() -> void:
	if combo_rules == null or combo_rules.wave_lost_cue == null:
		return

	var controller := _controller_for_source(combo_rules)
	if controller != null:
		controller.play(combo_rules.wave_lost_cue, 0.0)


# ── Tier 4 범퍼 ─────────────────────────────────────────────

## 범퍼를 맞았을 때. 종류마다 다른 재질음이 납니다.
func _on_bumper_response(bumper: Node, ball: RigidBody2D, _response: Variant) -> void:
	if bumper_rules == null:
		return

	var cue := bumper_rules.get_material_cue(BumperSfxRules.kind_id_of(bumper))
	if cue == null:
		return

	# 공의 컨트롤러로 보내야 같은 프레임의 패링 래치가 걸립니다.
	var controller := _controller_for_ball(ball)
	if controller != null:
		controller.play(cue, _ball_speed(ball))


## ★ 파괴·리스폰 컨트롤러를 범퍼가 아니라 바인더에 답니다.
##   부서진 범퍼는 노드가 정리될 수 있습니다. 범퍼에 달면 파괴음이 끊깁니다.
func _on_bumper_state_changed(_previous: int, current: int, _bumper: Node) -> void:
	if bumper_rules == null:
		return

	var cue: SfxCue = null
	match current:
		BUMPER_STATE_DESTROYED:
			cue = bumper_rules.destroy_cue
		BUMPER_STATE_RESPAWN_TELEGRAPH:
			cue = bumper_rules.respawn_telegraph_cue

	if cue == null:
		return

	var controller := _controller_for_source(self)
	if controller != null:
		controller.play(cue, 0.0)


func _on_cannon_control(bumper: Node, _ball: RigidBody2D) -> void:
	if bumper_rules == null or bumper_rules.cannon_control_cue == null:
		return

	var controller := _controller_for_source(bumper)
	if controller != null:
		controller.play(bumper_rules.cannon_control_cue, 0.0)


func _on_cannon_fire(bumper: Node, ball: RigidBody2D) -> void:
	if bumper_rules == null or bumper_rules.cannon_fire_cue == null:
		return

	# 조준을 취소해도 control_ended 가 옵니다. 공이 없으면 발사가 아닙니다.
	if not is_instance_valid(ball):
		return

	var controller := _controller_for_source(bumper)
	if controller != null:
		controller.play(bumper_rules.cannon_fire_cue, 0.0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if wall_rules == null:
		warnings.append("벽 SFX 규칙이 없으면 벽 충돌음이 안 납니다.")

	if flipper_rules == null:
		warnings.append("플리퍼 SFX 규칙이 없으면 타격·패링음이 안 납니다.")

	if combo_rules == null:
		warnings.append("콤보 SFX 규칙이 없으면 콤보·웨이브 승패음이 안 납니다.")

	if bumper_rules == null:
		warnings.append("범퍼 SFX 규칙이 없으면 범퍼 5종이 전부 무음입니다.")

	return warnings
