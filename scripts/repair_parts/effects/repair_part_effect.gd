class_name RepairPartEffect
extends RefCounted


## 수리 부품 효과 하나의 공통 계약입니다.
## 효과는 자기 부품의 PRIMARY 접촉과 다른 부품의 PRIMARY 접촉만 관찰하며,
## 2차 타격은 반드시 라우터의 dispatch_secondary를 통해 적립합니다.
## 여기에는 공 단위·부품 단위의 임시 상태만 두고, 랭크는 런타임이 보관합니다.


var runtime: RepairPartRuntime = null
var router: RepairEffectRouter = null


func setup(
	part_runtime: RepairPartRuntime,
	effect_router: RepairEffectRouter
) -> void:
	runtime = part_runtime
	router = effect_router


func get_definition() -> RepairPartDefinition:
	return runtime.definition if runtime != null else null


## 자기 부품의 유효 접촉입니다. context는 항상 PRIMARY입니다.
func on_own_primary(
	_ball: RigidBody2D,
	_context: RepairEffectContext,
	_now: float
) -> void:
	pass


## 자기 부품 범퍼의 최종 충돌 반응이 공에 적용된 직후입니다.
## 톱니 가속처럼 범퍼 기본 반사 이후에 합성해야 하는 효과가 사용합니다.
func on_own_response_resolved(_ball: RigidBody2D, _now: float) -> void:
	pass


## 다른 부품의 유효 접촉입니다. 바늘 봉합·브로치 방문 판정에 사용합니다.
func on_other_primary(
	_source: RepairPartRuntime,
	_ball: RigidBody2D,
	_context: RepairEffectContext,
	_now: float
) -> void:
	pass


## 라우터 시계로 시간 창·지연 발동을 진행합니다.
func tick(_now: float) -> void:
	pass


## 공 낙하·새 공 발사·웨이브 종료·재시도·재배치에서 임시 상태를 제거합니다.
func reset_transient() -> void:
	pass


func _push_state(state: Dictionary) -> void:
	if runtime != null:
		runtime.set_display_state(state)
