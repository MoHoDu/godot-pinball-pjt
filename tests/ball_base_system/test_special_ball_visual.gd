extends "res://tests/ball_base_system/test_ball_physics.gd"
## 특수 공(보상 공 5종) 가시성·크기 검수용 컨트롤러입니다.
##
## test_ball_physics 컨트롤러를 상속해 로스터만 특수 공으로 바꿉니다.
## 발사·리셋·크기 조절·비교 모드 등 조작은 원본 것을 그대로 씁니다.
##
##   1     기본 공 (비교 기준)
##   2~6   정속 태엽눈 / 고무막 / 완충 젤 / 납심 / 속빈 방울
##   0     6종 나란히 보기 (씬에 미리 놓인 공은 오버라이드 없이 프로덕션 값 그대로)
##
## 부모의 BALL_TYPES 상수는 컴파일 시점에 부모 메서드에 묶이므로,
## 로스터를 읽는 메서드 3개(select_ball_type · _spawn_focus_ball · _refresh_hud)를
## 특수 공 로스터 기준으로 오버라이드합니다.


## (표시 이름, 씬 경로) — 숫자키 1번부터 차례로 대응합니다.
const SPECIAL_BALL_TYPES: Array = [
	["기본 (유리눈)", "res://Resources/Prefabs/balls/base/base_ball.tscn"],
	["정속 태엽눈", "res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn"],
	["고무막 유리눈", "res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn"],
	["완충 젤 유리눈", "res://Resources/Prefabs/balls/variants/reward/gel_ball.tscn"],
	["납심 유리눈", "res://Resources/Prefabs/balls/variants/reward/lead_ball.tscn"],
	["속빈 방울눈", "res://Resources/Prefabs/balls/variants/reward/hollow_bell_ball.tscn"],
]


## 숫자키로 고른 특수 공을 띄웁니다. 미리 놓인 비교 그룹은 숨깁니다.
func select_ball_type(index: int) -> void:
	if index < 0 or index >= SPECIAL_BALL_TYPES.size():
		return

	_selected_index = index
	if is_instance_valid(comparison_group):
		comparison_group.visible = false
		_set_group_physics_active(false)

	_spawn_focus_ball()


func _spawn_focus_ball() -> void:
	_clear_focus_ball()

	var scene := load(SPECIAL_BALL_TYPES[_selected_index][1]) as PackedScene
	if scene == null:
		push_warning("공 씬을 불러오지 못했습니다: %s" % SPECIAL_BALL_TYPES[_selected_index][1])
		return

	_focus_ball = scene.instantiate() as Pinball
	if _focus_ball == null:
		push_warning("공 씬의 루트가 Pinball이 아닙니다: %s" % SPECIAL_BALL_TYPES[_selected_index][1])
		return

	_focus_holder.add_child(_focus_ball)
	# ball_diameter 는 _ready 의 refresh_ball_size() 뒤에 줘야 덮어써지지 않습니다.
	_focus_ball.ball_diameter = ball_diameter
	_reset_body(_focus_ball, SPAWN_POSITION)


func _refresh_hud() -> void:
	if not is_instance_valid(guide_label):
		return

	var lines: Array[String] = []
	lines.append("[특수 공 검수]  1~6 선택 · 0 비교 모드 · R 리셋 · Space 발사 · [ ] 크기")
	lines.append("")

	for i in SPECIAL_BALL_TYPES.size():
		var mark := "▶" if i == _selected_index else "  "
		lines.append("%s %d. %s" % [mark, i + 1, SPECIAL_BALL_TYPES[i][0]])

	var comparison_mark := "▶" if _selected_index < 0 else "  "
	lines.append("%s 0. 6종 나란히 비교 (프로덕션 크기·프리셋 그대로)" % comparison_mark)
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
		lines.append("비교 모드 — 기본 공 + 특수 공 5종이 각자 자리에 있습니다")

	guide_label.text = "\n".join(lines)
