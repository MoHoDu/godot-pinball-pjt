extends Node2D
## 사운드 연구실. 게임 보드가 아니라 **소리를 확인하려고 만든 방**입니다.
##
## 게임 씬에서는 원하는 소리를 원하는 때에 낼 수 없습니다. 고속 벽 충돌을 들으려면
## 공을 세게 쏴서 운 좋게 벽에 맞기를 기다려야 하고, 패링음은 타이밍을 맞춰야 합니다.
## 여기서는 **키 하나로 원하는 소리를 바로** 냅니다.
##
## 조작
##   1~3     벽 충돌 저속 / 중속 / 고속 (구간을 강제로 지정해 재생)
##   4~6     플리퍼 일반 타격 / 강한 타격 / 정확한 패링
##   7       벽 8연타 (연타 감쇠 확인)
##   8       ★ 우선순위 시험 — 벽을 쏟아부은 직후 패링. 패링이 밀리는가
##   Enter   공 발사 (현재 속도로)
##   [ / ]   발사 속도 조절
##   , / .   발사 각도 조절
##   R       공을 가운데로 되돌림
##   G       중력 켜기·끄기 (끄면 공이 계속 튕겨 다닌다)
##   0       전부 정지
##
##   Space   ★ 플리퍼 작동 (project.godot 의 flipper 액션)
##   방향키   플리퍼 그룹 선택
##
## ★ 발사를 Space 가 아니라 Enter 로 둔 이유
##   project.godot 에서 Space 는 플리퍼 작동, WASD·방향키는 플리퍼 그룹 선택이다.
##   연구실 키를 거기 겹치면 공을 쏠 때마다 플리퍼가 같이 올라가 소리가 섞인다.

const BALL_GROUP: StringName = &"pinball_balls"

const MIN_LAUNCH_SPEED: float = 150.0
const MAX_LAUNCH_SPEED: float = 2200.0
const SPEED_STEP: float = 60.0
const ANGLE_STEP: float = 6.0

## 구간을 강제로 고르기 위한 속도값입니다. 경계 사이 한가운데를 씁니다.
const TIER_SPEEDS: Array[float] = [200.0, 700.0, 1600.0]


@export var ball_path: NodePath
@export var director_path: NodePath
@export var wall_rules: WallSfxRules
@export var flipper_rules: FlipperSfxRules
@export var ball_flow_rules: BallFlowSfxRules
@export var combo_rules: ComboSfxRules
@export var bumper_rules: BumperSfxRules
@export var boss_rules: BossSfxRules

var _ball: RigidBody2D
var _director: SfxDirector
var _launch_speed: float = 900.0
var _launch_angle: float = -35.0
var _gravity_on: bool = false
var _status: String = "준비"


func _ready() -> void:
	_ball = get_node_or_null(ball_path) as RigidBody2D
	_director = get_node_or_null(director_path) as SfxDirector

	if _ball == null:
		return

	_ball.gravity_scale = 0.0
	_reset_ball()

	# ★ 시작하자마자 공을 쏜다.
	#   중력이 꺼져 있고 공이 정지 상태면 키를 누르기 전까지 **아무 소리도 안 난다**.
	#   연구실을 열었는데 조용하면 "적용이 안 됐다"로 보인다. 열면 바로 들려야 한다.
	_auto_launch()


func _auto_launch() -> void:
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(_ball):
		_launch()


func get_status() -> String:
	return _status


func get_launch_speed() -> float:
	return _launch_speed


func get_launch_angle() -> float:
	return _launch_angle


func is_gravity_on() -> bool:
	return _gravity_on


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_1:
			_play_wall(0)
		KEY_2:
			_play_wall(1)
		KEY_3:
			_play_wall(2)
		KEY_4:
			_play_flipper(flipper_rules.hit_cue if flipper_rules else null, "플리퍼 일반 타격")
		KEY_5:
			_play_flipper(flipper_rules.strong_hit_cue if flipper_rules else null, "플리퍼 강한 타격")
		KEY_6:
			_play_flipper(flipper_rules.parry_perfect_cue if flipper_rules else null, "정확한 패링")
		KEY_7:
			_burst_walls()
		KEY_8:
			_priority_probe()
		KEY_0:
			if _director != null:
				_director.stop_all()
			_status = "전부 정지"
		KEY_ENTER, KEY_KP_ENTER:
			_launch()
		KEY_BRACKETRIGHT:
			_launch_speed = minf(_launch_speed + SPEED_STEP, MAX_LAUNCH_SPEED)
			_status = "발사 속도 %.0f px/s" % _launch_speed
		KEY_BRACKETLEFT:
			_launch_speed = maxf(_launch_speed - SPEED_STEP, MIN_LAUNCH_SPEED)
			_status = "발사 속도 %.0f px/s" % _launch_speed
		KEY_COMMA:
			_launch_angle -= ANGLE_STEP
			_status = "발사 각도 %.0f°" % _launch_angle
		KEY_PERIOD:
			_launch_angle += ANGLE_STEP
			_status = "발사 각도 %.0f°" % _launch_angle
		KEY_R:
			_reset_ball()
		KEY_G:
			_toggle_gravity()

		# ★ W A S D 와 Space 는 플리퍼 조작용이라 쓰지 않습니다.
		#   R · G · 0~8 · Enter · [ ] · , . 도 이미 쓰고 있습니다.

		# ── Tier 3 흐름 (Q E) ──
		KEY_Q:
			_play_raw(_flow(&"launch_cue"), 1400.0, "공 발사 (세게)")
		KEY_E:
			_play_raw(_flow(&"drain_cue"), 0.0, "공 낙하")

		# ── Tier 3 콤보·웨이브 (T Y U I O) ──
		KEY_T:
			# ★ 한 번 누르면 8단 상승을 통째로 들려줍니다.
			#   한 발씩 들으면 사다리인지 알 수 없습니다.
			_combo_ladder()
		KEY_Y:
			_play_raw(_combo(&"tier_cue"), 0.0, "콤보 단계 상승")
		KEY_U:
			_play_raw(_combo(&"timeout_cue"), 0.0, "콤보 실패")
		KEY_I:
			_play_raw(_combo(&"wave_won_cue"), 0.0, "웨이브 승리")
		KEY_O:
			_play_raw(_combo(&"wave_lost_cue"), 0.0, "웨이브 패배")
		KEY_P:
			_play_raw(_combo(&"target_reached_cue"), 0.0, "목표 점수 도달")

		# ── 보스 (H J K L N / ; 9) — 기획서 11장 순서대로 ──
		KEY_H:
			_play_raw(_boss(&"telegraph_cue"), 0.0, "보스 팔 예고 — 실 끼익")
		KEY_J:
			_play_raw(_boss(&"arm_swing_cue"), 0.0, "보스 팔 공격 — 휙 + 턱")
		KEY_K:
			_play_raw(_boss(&"hit_cue"), 0.0, "보스 피격 — 팡")
		KEY_L:
			_play_raw(_boss(&"roar_cue"), 0.0, "보스 포효 — 뒤틀린 오르골")
		KEY_N:
			_play_raw(_boss(&"cotton_telegraph_cue"), 0.0, "솜뭉치 예고 — 저주 점멸")
		KEY_SLASH:
			_play_raw(_boss(&"cotton_spawn_cue"), 0.0, "솜뭉치 생성 — 스르륵 + 푹")
		KEY_SEMICOLON:
			_play_raw(_boss(&"defeated_cue"), 0.0, "보스 처치 — 저주 정화")
		KEY_9:
			_play_raw(_boss(&"heartbeat_cue"), 0.0, "보스 환경 — 하트 핵 박동")

		# ── Tier 4 범퍼 5종 (Z X C V B) ──
		KEY_Z:
			_play_bumper(&"stage01_button", "단추 범퍼")
		KEY_X:
			_play_bumper(&"stage01_cotton", "솜 범퍼")
		KEY_C:
			_play_bumper(&"stage01_spring_doll", "용수철 인형")
		KEY_V:
			_play_bumper(&"stage01_toy_drum", "장난감 북")
		KEY_B:
			_play_bumper(&"stage01_clockwork_cannon", "태엽 대포 몸통")

		# ── Tier 4 기능 악센트 (N M P) ──
		KEY_M:
			_play_raw(_bumper(&"respawn_telegraph_cue"), 0.0, "범퍼 리스폰 예고")
		KEY_P:
			_play_raw(_bumper(&"cannon_fire_cue"), 0.0, "태엽 대포 발사")
		_:
			return

	get_viewport().set_input_as_handled()


# ── 직접 재생 ───────────────────────────────────────────────

## 공에 붙은 컨트롤러를 거치지 않고 디렉터에 바로 넣습니다.
## 스로틀·연타 감쇠 없이 **음원 자체**를 듣기 위한 것입니다.
func _play_raw(cue: SfxCue, speed: float, label: String) -> void:
	if cue == null or _director == null:
		_status = "%s — 큐가 없다" % label
		return

	var context := SfxPlayContext.new(get_instance_id(), speed)
	var result := _director.request(cue, context)
	_status = "%s   %s" % [
		label,
		"재생 %+.1fdB" % result.volume_db if result.is_played() else "드롭",
	]


func _play_wall(tier: int) -> void:
	if wall_rules == null:
		return

	var names: Array[String] = ["저속", "중속", "고속"]
	_play_raw(wall_rules.hit_cue, TIER_SPEEDS[tier], "벽 충돌 %s" % names[tier])


func _play_flipper(cue: SfxCue, label: String) -> void:
	_play_raw(cue, 900.0, label)


# ── Tier 3·4 ────────────────────────────────────────────────

## 규칙이 안 물려 있어도 죽지 않게 감싸 꺼냅니다.
func _flow(field: StringName) -> SfxCue:
	return ball_flow_rules.get(field) if ball_flow_rules != null else null


func _boss(field: StringName) -> SfxCue:
	return boss_rules.get(field) if boss_rules != null else null


func _combo(field: StringName) -> SfxCue:
	return combo_rules.get(field) if combo_rules != null else null


func _bumper(field: StringName) -> SfxCue:
	return bumper_rules.get(field) if bumper_rules != null else null


## ★ 콤보 상승음은 **한 발씩 들으면 판단이 안 됩니다.**
##   피치가 콤보 수에 따라 올라가는 것이 이 소리의 전부라서,
##   8단을 이어서 들려줘야 사다리인지 알 수 있습니다.
func _combo_ladder() -> void:
	var cue := _combo(&"rise_cue")
	if cue == null or _director == null:
		_status = "콤보 상승 — 큐가 없다"
		return

	for i in 8:
		var context := SfxPlayContext.new(2000 + i, 0.0)
		context.pitch_override = combo_rules.get_rise_pitch(i + 1)
		_director.request(cue, context)
		await get_tree().create_timer(0.16).timeout

	_status = "콤보 사다리 8단 (피치 1.00 → %.2f)" % combo_rules.get_rise_pitch(8)


func _play_bumper(kind_id: StringName, label: String) -> void:
	if bumper_rules == null:
		_status = "%s — 범퍼 규칙이 없다" % label
		return

	_play_raw(bumper_rules.get_material_cue(kind_id), 700.0, label)


## 벽 8연타. 연타 감쇠가 과한지 부족한지 확인합니다.
## 여기서는 공의 컨트롤러를 거쳐야 감쇠가 걸립니다.
func _burst_walls() -> void:
	if wall_rules == null or _ball == null:
		return

	var controller := _ball.get_node_or_null(NodePath(BallAudioController.NODE_NAME)) as BallAudioController
	if controller == null:
		_status = "8연타 — 공에 컨트롤러가 아직 없다 (한 번 부딪혀야 붙는다)"
		return

	_status = "벽 8연타 (연타 감쇠 확인)"
	for i in 8:
		controller.play(wall_rules.hit_cue, 700.0)
		await get_tree().create_timer(0.11).timeout


## ★ 우선순위 시험 — 벽을 쏟아부은 **직후** 패링을 넣습니다.
## 선착순 구현이면 패링이 드롭됩니다. 여기서 패링이 들려야 정상입니다.
func _priority_probe() -> void:
	if wall_rules == null or flipper_rules == null or _director == null:
		return

	for i in 10:
		_director.request(wall_rules.hit_cue, SfxPlayContext.new(1000 + i, 1600.0))

	var before := _director.get_active_count(SfxPriority.WALL)
	var result := _director.request(
		flipper_rules.parry_perfect_cue,
		SfxPlayContext.new(get_instance_id(), 900.0)
	)

	_status = "우선순위 시험 — 벽 %d개 재생 중, 패링 %s" % [
		before,
		"통과 ✔" if result.is_played() else "★밀림",
	]


# ── 공 조작 ─────────────────────────────────────────────────

func _launch() -> void:
	if _ball == null:
		return

	_ball.freeze = false
	var direction := Vector2.RIGHT.rotated(deg_to_rad(_launch_angle))
	_ball.linear_velocity = direction * _launch_speed
	_status = "발사 %.0f px/s  %.0f°" % [_launch_speed, _launch_angle]


func _reset_ball() -> void:
	if _ball == null:
		return

	_ball.freeze = false
	_ball.linear_velocity = Vector2.ZERO
	_ball.angular_velocity = 0.0
	# RigidBody2D 는 노드 속성만 써서는 물리 서버가 다음 프레임에 덮어씁니다.
	# 서버에 직접 쓰고 한 프레임 뒤에 한 번 더 씁니다 (test_ball_physics 와 같은 방식).
	PhysicsServer2D.body_set_state(
		_ball.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY
	)
	_replace_next_frame()
	_status = "리셋"


func _replace_next_frame() -> void:
	await get_tree().physics_frame
	if not is_instance_valid(_ball):
		return

	PhysicsServer2D.body_set_state(
		_ball.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D.IDENTITY
	)
	PhysicsServer2D.body_set_state(
		_ball.get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
		Vector2.ZERO
	)


func _toggle_gravity() -> void:
	_gravity_on = not _gravity_on
	if _ball != null:
		_ball.gravity_scale = 1.0 if _gravity_on else 0.0

	_status = "중력 %s" % ("켬" if _gravity_on else "끔 — 공이 계속 튕긴다")
