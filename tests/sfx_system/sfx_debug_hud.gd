extends CanvasLayer
## 사운드 테스트 씬의 디버그 표시입니다. 어떤 소리가 왜 났는지를 눈으로 봅니다.
##
## 소리만 들어서는 "지금 저게 중속인가 고속인가", "왜 안 울렸나"를 알 수 없습니다.
## 검수는 귀로 하지만, 무엇을 듣고 있는지는 눈으로 확인해야 판단이 됩니다.

const BALL_GROUP: StringName = &"pinball_balls"
const HISTORY_SIZE: int = 8

const TIER_NAMES: Array[String] = ["저속", "중속", "고속"]

const OUTCOME_NAMES: Array[String] = [
	"재생", "재생(뺏음)", "상한초과", "목소리없음", "무음속도", "음원없음",
]


@export var director_path: NodePath
@export var wall_rules: WallSfxRules
## 연구실 씬에서만 씁니다. 게임 씬에서는 비워둡니다.
@export var lab_path: NodePath

var _director: SfxDirector
var _label: Label
var _history: Array[String] = []
var _played: int = 0
var _dropped: int = 0
var _tier_counts: Array[int] = [0, 0, 0]


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(24, 24)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.87, 0.95, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.08))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

	_director = get_node_or_null(director_path) as SfxDirector
	if _director == null:
		_director = _find_director(get_tree().root)

	if _director != null:
		_director.cue_played.connect(_on_cue_played)
		_director.cue_dropped.connect(_on_cue_dropped)


func _process(_delta: float) -> void:
	if _label == null:
		return

	var lines := PackedStringArray()
	var lab := get_node_or_null(lab_path)

	if lab != null:
		lines.append("[ 사운드 연구실 ]")
		lines.append("  1 2 3  벽 저·중·고속     4 5 6  플리퍼 타격·강타격·패링")
		lines.append("  7 벽 8연타   8 ★우선순위 시험   0 정지")
		lines.append("  Enter 발사   [ ] 속도   , . 각도   R 리셋   G 중력")
		lines.append("  ★ Space 플리퍼 작동   방향키 플리퍼 선택")
		lines.append("  발사 %.0f px/s  %.0f°   중력 %s"
			% [lab.get_launch_speed(), lab.get_launch_angle(),
				"켬" if lab.is_gravity_on() else "끔"])
		lines.append("  > %s" % lab.get_status())
		lines.append("")
	else:
		lines.append("[ 공 사운드 테스트 ]  Space 발사·플리퍼 / 방향키 선택 / R 리셋")

	var ball := _find_ball()
	if ball != null:
		var speed := (ball.get(&"linear_velocity") as Vector2).length()
		var tier := _tier_of(speed)
		lines.append("공 속도 %6.0f px/s   →   벽 충돌 구간 [ %s ]" % [speed, TIER_NAMES[tier]])
	else:
		lines.append("공 없음")

	if _director != null:
		lines.append("목소리 %d / %d 사용   재생 %d · 드롭 %d"
			% [_director.get_active_voice_count(), 16, _played, _dropped])

	lines.append("구간별 재생 횟수   저속 %d · 중속 %d · 고속 %d"
		% [_tier_counts[0], _tier_counts[1], _tier_counts[2]])
	lines.append("")
	lines.append("최근 재생")
	for entry: String in _history:
		lines.append("  " + entry)

	_label.text = "\n".join(lines)


func _tier_of(speed: float) -> int:
	if wall_rules == null or wall_rules.hit_cue == null:
		return 0

	return wall_rules.hit_cue.get_speed_tier(speed)


func _find_ball() -> Node:
	for node in get_tree().get_nodes_in_group(BALL_GROUP):
		if is_instance_valid(node):
			return node

	return null


func _find_director(node: Node) -> SfxDirector:
	if node is SfxDirector:
		return node

	for child in node.get_children():
		var found := _find_director(child)
		if found != null:
			return found

	return null


func _on_cue_played(cue_id: StringName, priority: int, volume_db: float, pitch: float) -> void:
	_played += 1

	# 벽 충돌이면 어느 구간이었는지 같이 센다
	if cue_id == &"wall_hit":
		var ball := _find_ball()
		if ball != null:
			var speed := (ball.get(&"linear_velocity") as Vector2).length()
			_tier_counts[_tier_of(speed)] += 1

	_push("%-22s %-8s %+6.1fdB  x%.3f"
		% [cue_id, SfxPriority.to_name(priority), volume_db, pitch])


func _on_cue_dropped(cue_id: StringName, priority: int, outcome: int) -> void:
	_dropped += 1
	var name := OUTCOME_NAMES[outcome] if outcome < OUTCOME_NAMES.size() else "?"
	_push("%-22s %-8s 드롭: %s" % [cue_id, SfxPriority.to_name(priority), name])


func _push(entry: String) -> void:
	_history.push_front(entry)
	while _history.size() > HISTORY_SIZE:
		_history.pop_back()
