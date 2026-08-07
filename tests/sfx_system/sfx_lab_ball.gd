extends "res://tests/sfx_system/sfx_lab.gd"
## B 그룹(공·벽) 전용 연구실입니다.
##
## ★ 왜 씬을 따로 두는가
##   플리퍼 연구실은 좌우 한 쌍씩 두 그룹이 있어 **벽 소리를 들으려 해도
##   플리퍼가 계속 끼어듭니다.** 공이 벽을 때리기 전에 플리퍼에 먼저 맞고,
##   Space 를 누르면 작동음이 벽 소리를 덮습니다.
##
##   여기는 플리퍼가 **하나뿐**입니다. 공을 튕겨 올리는 데는 하나면 충분하고,
##   나머지 소리는 전부 공과 벽에서만 납니다.
##
## 조작 — 부모(sfx_lab.gd)의 키를 그대로 물려받고 아래를 더합니다.
##
##   ★ B  벽 속도 3단 자동 시연 — 저 → 중 → 고를 이어서 냅니다.
##        하나씩 들으면 "다른 소리"인지 "같은 벽의 세기 차이"인지 판단이 안 됩니다.
##
##   Z    공 발사음 (약하게 당김)
##   X    공 발사음 (끝까지 당김) — 세기로 음량이 갈리는지
##   C    공 낙하음
##   V    공 선택음
##
##   물려받은 것: 1~3 벽 구간 · 7 벽 8연타 · Enter 발사 · [ ] 속도 ·
##                , . 각도 · R 리셋 · G 중력 · 0 정지 · Space 플리퍼

## 자동 시연에서 각 구간 사이에 두는 간격입니다.
## 너무 붙이면 앞 소리의 꼬리에 묻혀 구간이 안 갈립니다.
const DEMO_GAP: float = 0.55


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key := event as InputEventKey
	if not key.pressed or key.echo:
		super(event)
		return

	match key.physical_keycode:
		KEY_B:
			_demo_wall_tiers()
		KEY_Z:
			_play_raw(_flow(&"launch_cue"), 320.0, "공 발사 (약하게)")
		KEY_X:
			_play_raw(_flow(&"launch_cue"), 1900.0, "공 발사 (세게)")
		KEY_C:
			_play_raw(_flow(&"drain_cue"), 0.0, "공 낙하")
		KEY_V:
			_play_raw(_ball_select_cue(), 0.0, "공 선택")
		_:
			super(event)
			return

	get_viewport().set_input_as_handled()


## ★ 벽 3종은 "다른 물체 셋"이 아니라 **같은 벽의 세기 차이**여야 합니다.
##   그래서 반드시 이어서 들어야 판단이 됩니다.
func _demo_wall_tiers() -> void:
	if wall_rules == null or wall_rules.hit_cue == null:
		_status = "벽 3단 — 음원이 아직 없다"
		return

	var names: Array[String] = ["저속", "중속", "고속"]
	for i in 3:
		_play_wall(i)
		_status = "벽 3단 시연 — %s" % names[i]
		await get_tree().create_timer(DEMO_GAP).timeout

	_status = "벽 3단 시연 끝 — 같은 벽의 세기 차이로 들렸는가"


## 공 선택음은 아직 규칙에 자리가 없습니다. 생기면 여기만 고칩니다.
func _ball_select_cue() -> SfxCue:
	if ball_flow_rules == null:
		return null

	return ball_flow_rules.get(&"select_cue")
