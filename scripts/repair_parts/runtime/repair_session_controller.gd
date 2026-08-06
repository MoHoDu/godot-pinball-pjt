class_name RepairSessionController
extends Node


## 기존 WaveManager를 수정하지 않고 신호 연결만으로
## 수리 부품의 공 단위·웨이브 단위 상태를 정리합니다 (기획서 9장 표).
## 랭크와 장착 정보만 세션 동안 유지하고, 공 단위 상태는 다음 공으로 넘기지 않습니다.


@export var wave_manager_path: NodePath = NodePath("")
@export var router_path: NodePath = NodePath("")
@export var board_controller_path: NodePath = NodePath("")


var _wave_manager: Node = null
var _router: RepairEffectRouter = null
var _board_controller: RepairBoardController = null


func _ready() -> void:
	_router = get_node_or_null(router_path) as RepairEffectRouter
	_board_controller = get_node_or_null(
		board_controller_path
	) as RepairBoardController
	_wave_manager = get_node_or_null(wave_manager_path)
	if _wave_manager == null or _router == null:
		push_warning(
			"RepairSessionController에 WaveManager와 RepairEffectRouter 경로가 필요합니다."
		)
		return
	_connect_signal(&"active_ball_changed", _on_active_ball_changed)
	_connect_signal(&"ball_cycle_resolved", _on_ball_cycle_resolved)
	_connect_signal(&"wave_won", _on_wave_finished)
	_connect_signal(&"wave_lost", _on_wave_finished)
	_connect_signal(&"wave_retried", _on_wave_retried)


func _connect_signal(signal_name: StringName, callback: Callable) -> void:
	if not _wave_manager.has_signal(signal_name):
		return
	if not _wave_manager.is_connected(signal_name, callback):
		_wave_manager.connect(signal_name, callback)


func _on_active_ball_changed(_ball: Node) -> void:
	# 새 공 발사: 브로치 비활성 · 톱니 회전 0 · 바늘 비활성 · 방울 예약 없음.
	_router.on_new_ball()
	if _board_controller != null:
		_board_controller.reset_parts_for_new_ball()


func _on_ball_cycle_resolved(
	_ball: Node,
	_remaining_balls: int,
	_awarded_score: int
) -> void:
	# 공 낙하: 기존 콤보 정산이 먼저 끝난 뒤 모든 부품의 임시 상태를 초기화합니다.
	_router.on_ball_drained()


func _on_wave_finished(_current_score: int, _target_score: int) -> void:
	_router.on_wave_ended()


func _on_wave_retried() -> void:
	_router.on_full_reset()
