extends Node2D
## 보스 아트 리그 검수 씬 컨트롤러입니다.
##
## 전투 로직이 아닙니다. 상태 전환이 자연스러운지, 피격 반동이 살아 있는지,
## 표정이 상태와 같이 움직이는지를 눈으로 확인하는 용도입니다.
##
## 조작: 1 대기 · 2 예고 · 3 공격 · 4 경직 · 5 피격 · 6 강한 피격 · 7 포효
##       Space 예고→공격→경직 시퀀스 재생

## 기획서 7절 상태 지속 시간을 그대로 쓴다.
const TELEGRAPH_SECONDS: float = 0.85
const ATTACK_SECONDS: float = 0.22
const RECOVERY_SECONDS: float = 1.35

@onready var _rig: BossArtRig = $Rig
@onready var _vfx: BossVfxLayer = $Vfx
@onready var _label: Label = $Label

var _sequence := -1.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1: _play("기본 대기", func() -> void: _rig.play_idle())
		KEY_2: _play("팔 공격 예고", func() -> void: _rig.play_telegraph())
		KEY_3: _play("팔 공격", func() -> void: _rig.play_attack())
		KEY_4: _play("공격 후 경직", func() -> void: _rig.play_recovery())
		KEY_5: _play("일반 피격", func() -> void:
			_rig.play_hit(1.0)
			_vfx.spawn_hit(Vector2(-126.0, -10.0), Vector2.LEFT, false))
		KEY_6: _play("강한 피격(고콤보)", func() -> void:
			_rig.play_hit_strong(-1.0)
			_vfx.spawn_hit(Vector2(128.0, -6.0), Vector2.RIGHT, true))
		KEY_7: _play("페이즈 전환 포효", func() -> void:
			_rig.play_roar()
			_vfx.spawn_roar())
		KEY_B: _play("팔-공 충돌", func() -> void:
			_vfx.spawn_ball_impact(Vector2(-150.0, 40.0), Vector2(-0.55, -0.84)))
		KEY_SPACE:
			_sequence = 0.0
			_rig.play_telegraph()
			_label.text = "시퀀스: 예고 %.2f초 → 공격 %.2f초 → 경직" % [
				TELEGRAPH_SECONDS, ATTACK_SECONDS
			]


func _play(name: String, fn: Callable) -> void:
	_sequence = -1.0
	fn.call()
	_label.text = "%s   상태 %s   표정 %s" % [
		name, _rig.get_state(), _rig.get_expression()
	]


func _process(delta: float) -> void:
	if _sequence < 0.0:
		return
	_sequence += delta
	# 예고(압축 유지) -> 0.22초 공격 -> 경직. 실전과 같은 흐름이다.
	if _sequence <= TELEGRAPH_SECONDS:
		pass
	elif _sequence <= TELEGRAPH_SECONDS + ATTACK_SECONDS:
		_rig.set_attack_progress((_sequence - TELEGRAPH_SECONDS) / ATTACK_SECONDS)
	elif _sequence <= TELEGRAPH_SECONDS + ATTACK_SECONDS + RECOVERY_SECONDS:
		if _rig.get_state() != &"recovery":
			_rig.play_recovery()
	else:
		_sequence = -1.0
		_rig.play_idle()
		_label.text = "시퀀스 종료 → 기본 대기"
