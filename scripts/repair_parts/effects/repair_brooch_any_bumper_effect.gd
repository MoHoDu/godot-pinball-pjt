class_name RepairBroochAnyBumperEffect
extends RepairBroochEffect
## 별빛 브로치 완화 룰 (2026-08-10 형락님 확정).
##
## 기존 룰은 "브로치가 아닌 다른 부품 계열 2종 방문"이라 유물 세트가 없으면
## 브로치가 영원히 완성되지 않았다. 이 확장은 별 팔 점등 조건을
## **반원 리바운드를 제외한 서로 다른 범퍼 2개**(부품 포함, 종류 무관 개체 기준)로
## 바꾼다 — 단추뿐인 웨이브 1에서도 브로치가 완성될 수 있다.
##
## 부품 방문 경로(on_other_primary)는 비활성화하고 범퍼 타격 시그널로 일원화해
## 한 타격이 별 팔을 두 번 켜는 중복을 막는다.
## 기존 repair_brooch_effect.gd 는 수정하지 않았다 (유닛 테스트는 원 규칙 유지).


const EXCLUDED_KINDS: Array[StringName] = [&"rebound_wall", &"starlight_brooch"]

var _clock_now := 0.0
var _bumpers_bound := false


func tick(now: float) -> void:
	_clock_now = now
	if not _bumpers_bound:
		_bind_bumpers()
	super.tick(now)


func on_other_primary(
	_source: RepairPartRuntime,
	_ball: RigidBody2D,
	_context: RepairEffectContext,
	_now: float
) -> void:
	# 부품 방문은 범퍼 시그널 경로가 이미 집계한다 — 중복 점등 방지용 무시.
	pass


func _bind_bumpers() -> void:
	if runtime == null or not is_instance_valid(runtime) \
			or not runtime.is_inside_tree():
		return
	_bumpers_bound = true
	for node: Node in runtime.get_tree().get_nodes_in_group(&"bumper_objects"):
		if node is Bumper:
			(node as Bumper).valid_hit_registered.connect(
				_on_any_bumper_hit.bind(node)
			)


func _on_any_bumper_hit(
	_bumper_id: StringName,
	ball: RigidBody2D,
	_contact_id: int,
	_base_score: int,
	bumper: Node
) -> void:
	if runtime == null or not is_instance_valid(runtime) or ball == null:
		return
	if BumperSfxRules.kind_id_of(bumper) in EXCLUDED_KINDS:
		return

	var ball_id := ball.get_instance_id()
	if not _marks.has(ball_id):
		return
	var now := _clock_now
	var mark: Dictionary = _marks[ball_id]
	if now > float(mark[&"expires_at"]):
		_marks.erase(ball_id)
		_push_brooch_state(now)
		return
	# 같은 범퍼를 두 번 맞혀도 별 팔은 하나만 켜진다 (개체 기준).
	(mark[&"visited"] as Dictionary)[bumper.get_instance_id()] = true
	_push_brooch_state(now)
