extends Node2D
## test_ball_physics 씬 컨트롤러입니다.
##
## 숫자키로 공 종류를 갈아끼우며 물리와 VFX를 한 자리에서 비교합니다.
##
##   1~7  공 종류 교체 (한 개만 띄우는 집중 모드)
##   0    기존 7종 나란히 보기 (비교 모드)
##   R    현재 공을 발사 위치로 되돌리기
##   Space / Enter  발사
##   [ ]  공 지름 줄이기 / 키우기
##
## 공 종류마다 stats(질량·탄성)가 변종 씬 안에 들어 있으므로
## 씬 인스턴스를 새로 만들어 띄웁니다. 이 씬의 인스펙터 오버라이드는 쓰지 않습니다.


## (표시 이름, 씬 경로) — 숫자키 1번부터 차례로 대응합니다.
## 경로는 대문자 res://Resources/ 로 씁니다. 소문자면 Linux/macOS 익스포트에서 못 엽니다.
const BALL_TYPES: Array = [
	["기본", "res://Resources/Prefabs/balls/base/base_ball.tscn"],
	["데드 (탄성 0)", "res://Resources/Prefabs/balls/variants/elastic/dead_ball.tscn"],
	["러버 (탄성 0.6)", "res://Resources/Prefabs/balls/variants/elastic/rubber_ball.tscn"],
	["슈퍼 (탄성 0.9)", "res://Resources/Prefabs/balls/variants/elastic/super_ball.tscn"],
	["가벼움 (질량 0.5)", "res://Resources/Prefabs/balls/variants/mass/light_ball.tscn"],
	["보통 (질량 2)", "res://Resources/Prefabs/balls/variants/mass/normal_ball.tscn"],
	["무거움 (질량 8)", "res://Resources/Prefabs/balls/variants/mass/heavy_ball.tscn"],
]

## 기획서 기준 실제 게임 크기입니다. VFX 검수는 이 크기로 해야 의미가 있습니다.
const DEFAULT_BALL_DIAMETER: float = 44.0
const MIN_BALL_DIAMETER: float = 16.0
const MAX_BALL_DIAMETER: float = 160.0
const DIAMETER_STEP: float = 4.0

## 집중 모드에서 공이 생성되는 위치입니다.
const SPAWN_POSITION: Vector2 = Vector2(0.0, -250.0)

## Space/Enter 로 발사할 방향입니다. 아래쪽 벽으로 떨어뜨립니다.
const LAUNCH_DIRECTION: Vector2 = Vector2(0.35, 1.0)


@export_node_path("Node2D") var comparison_group_path: NodePath = ^"Balls"
@export_node_path("Label") var guide_label_path: NodePath = ^"BallSwitchGuide/Panel/GuideLabel"

## 집중 모드에서 쓸 공 지름입니다.
@export_range(16.0, 160.0, 1.0, "suffix:px")
var ball_diameter: float = DEFAULT_BALL_DIAMETER


@onready var comparison_group: Node2D = get_node_or_null(comparison_group_path) as Node2D
@onready var guide_label: Label = get_node_or_null(guide_label_path) as Label


## -1 이면 비교 모드(기존 7종 나란히), 0 이상이면 BALL_TYPES 인덱스입니다.
var _selected_index: int = 0
var _focus_ball: Pinball
var _focus_holder: Node2D


func _ready() -> void:
	_focus_holder = Node2D.new()
	_focus_holder.name = "FocusBall"
	add_child(_focus_holder)

	select_ball_type(0)


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_0:
			show_comparison()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			# KEY_1 이 1번 공이 되도록 1을 뺍니다.
			select_ball_type(key_event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_R:
			reset_ball()
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			launch_ball()
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			set_ball_diameter(ball_diameter - DIAMETER_STEP)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			set_ball_diameter(ball_diameter + DIAMETER_STEP)
			get_viewport().set_input_as_handled()


## 숫자키로 고른 공 종류를 띄웁니다. 기존 7종은 숨깁니다.
func select_ball_type(index: int) -> void:
	if index < 0 or index >= BALL_TYPES.size():
		return

	_selected_index = index
	if is_instance_valid(comparison_group):
		comparison_group.visible = false
		_set_group_physics_active(false)

	_spawn_focus_ball()


## 기존 7종을 나란히 보는 원래 화면으로 돌아갑니다.
func show_comparison() -> void:
	_selected_index = -1
	_clear_focus_ball()

	if is_instance_valid(comparison_group):
		comparison_group.visible = true
		_set_group_physics_active(true)


## 현재 공을 발사 위치로 되돌리고 모든 운동을 제거합니다.
func reset_ball() -> void:
	if _selected_index < 0:
		# 비교 모드에서는 7종 전부를 되돌립니다
		for ball: Pinball in _collect_group_balls():
			_reset_body(ball, ball.get_meta(&"home_position", ball.global_position))
		return

	if is_instance_valid(_focus_ball):
		_reset_body(_focus_ball, SPAWN_POSITION)


## 현재 공을 발사합니다.
func launch_ball() -> void:
	if not is_instance_valid(_focus_ball):
		return

	_focus_ball.launch(LAUNCH_DIRECTION.normalized())


## 집중 모드 공의 지름을 바꿉니다. VFX는 크기 비율로 만들어져 있어 같이 따라옵니다.
func set_ball_diameter(value: float) -> void:
	ball_diameter = clampf(value, MIN_BALL_DIAMETER, MAX_BALL_DIAMETER)
	if is_instance_valid(_focus_ball):
		_focus_ball.ball_diameter = ball_diameter


## 현재 선택된 공입니다. 테스트용입니다.
func get_focus_ball() -> Pinball:
	return _focus_ball


## 현재 선택 인덱스입니다. -1 이면 비교 모드입니다. 테스트용입니다.
func get_selected_index() -> int:
	return _selected_index


# ── 내부 ────────────────────────────────────────────────────

func _spawn_focus_ball() -> void:
	_clear_focus_ball()

	var scene := load(BALL_TYPES[_selected_index][1]) as PackedScene
	if scene == null:
		push_warning("공 씬을 불러오지 못했습니다: %s" % BALL_TYPES[_selected_index][1])
		return

	_focus_ball = scene.instantiate() as Pinball
	if _focus_ball == null:
		push_warning("공 씬의 루트가 Pinball이 아닙니다: %s" % BALL_TYPES[_selected_index][1])
		return

	_focus_holder.add_child(_focus_ball)
	# ball_diameter 는 _ready 의 refresh_ball_size() 뒤에 줘야 덮어써지지 않습니다.
	_focus_ball.ball_diameter = ball_diameter
	_reset_body(_focus_ball, SPAWN_POSITION)


func _clear_focus_ball() -> void:
	if is_instance_valid(_focus_ball):
		_focus_ball.queue_free()

	_focus_ball = null


func _reset_body(body: RigidBody2D, position_value: Vector2) -> void:
	if not is_instance_valid(body):
		return

	if body.has_method(&"clear_temporary_maximum_speed"):
		body.call(&"clear_temporary_maximum_speed")

	_place_body(body, position_value)
	# 한 프레임 뒤에 한 번 더 밀어 넣습니다.
	# 우리가 쓴 뒤 물리 서버가 바디를 한 번 더 적분해 위치를 덮어쓰기 때문입니다.
	# (BallGazeVisual 에서 같은 함정을 이미 겪었습니다)
	_replace_next_frame(body, position_value)


func _place_body(body: RigidBody2D, position_value: Vector2) -> void:
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.global_position = position_value
	body.rotation = 0.0
	# 노드 속성만 쓰면 물리 서버 내부 상태가 그대로 남습니다. 서버에도 직접 씁니다.
	var rid := body.get_rid()
	PhysicsServer2D.body_set_state(
		rid,
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, position_value)
	)
	PhysicsServer2D.body_set_state(
		rid,
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		Vector2.ZERO
	)
	PhysicsServer2D.body_set_state(
		rid,
		PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY,
		0.0
	)


func _replace_next_frame(body: RigidBody2D, position_value: Vector2) -> void:
	await get_tree().physics_frame
	if not is_instance_valid(body):
		return

	_place_body(body, position_value)


## 비교 모드가 아닐 때 기존 7종이 계속 굴러다니면 화면이 지저분해집니다.
## visible 만 끄면 물리는 계속 도므로 sleeping 도 같이 걸어 둡니다.
func _set_group_physics_active(active: bool) -> void:
	for ball: Pinball in _collect_group_balls():
		ball.sleeping = not active
		if active:
			continue

		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0


func _collect_group_balls() -> Array[Pinball]:
	var found: Array[Pinball] = []
	if not is_instance_valid(comparison_group):
		return found

	_collect_recursive(comparison_group, found)
	return found


func _collect_recursive(node: Node, found: Array[Pinball]) -> void:
	var ball := node as Pinball
	if ball != null:
		if not ball.has_meta(&"home_position"):
			ball.set_meta(&"home_position", ball.global_position)

		found.append(ball)

	for child in node.get_children():
		_collect_recursive(child, found)


func _refresh_hud() -> void:
	if not is_instance_valid(guide_label):
		return

	var lines: Array[String] = []
	lines.append("[공 종류 전환]  1~7 선택 · 0 비교 모드 · R 리셋 · Space 발사 · [ ] 크기")
	lines.append("")

	for i in BALL_TYPES.size():
		var mark := "▶" if i == _selected_index else "  "
		lines.append("%s %d. %s" % [mark, i + 1, BALL_TYPES[i][0]])

	var comparison_mark := "▶" if _selected_index < 0 else "  "
	lines.append("%s 0. 7종 나란히 비교" % comparison_mark)
	lines.append("")
	lines.append("공 지름: %.0fpx" % ball_diameter)

	if is_instance_valid(_focus_ball):
		var stats: PinballStats = _focus_ball.stats
		if stats != null:
			lines.append(
				"질량 %.2f · 탄성 %.2f · 속도 %.0f px/s"
				% [stats.mass, stats.elasticity, _focus_ball.linear_velocity.length()]
			)
	elif _selected_index < 0:
		lines.append("비교 모드 — 7종이 각자 자리에 있습니다")

	guide_label.text = "\n".join(lines)
