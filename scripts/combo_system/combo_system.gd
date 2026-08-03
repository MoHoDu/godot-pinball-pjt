class_name ComboSystem
extends Node


signal combo_changed(combo_count: int, tier: int, time_remaining: float)
signal combo_tier_changed(previous_tier: int, current_tier: int, combo_count: int)
signal combo_timer_changed(time_remaining: float, hold_time: float)
signal combo_finished(combo_count: int, tier: int, awarded_score: int, reason: int)
signal score_changed(total_score: int, added_score: int)
signal timer_suspension_changed(is_suspended: bool, time_remaining: float)


enum EndReason {
	TIMEOUT,
	BALL_DRAINED,
	NEW_BALL,
	MANUAL,
}


const ComboRulesClass := preload(
	"res://scripts/combo_system/combo_rules.gd"
)
const DEFAULT_RULES: Resource = preload(
	"res://settings/combo/ComboRules.tres"
)
const FLIPPER_HIT_SIGNAL: StringName = &"rotation_sweep_resolved"


var _rules: Resource = DEFAULT_RULES
var _combo_count: int = 0
var _time_remaining: float = 0.0
var _total_score: int = 0
var _timer_suspension_depth: int = 0


## 프로젝트 전체가 공유하는 단계, 점수, 피해 규칙입니다.
var rules: Resource:
	get:
		return _rules
	set(value):
		_rules = value if value != null else DEFAULT_RULES
		if _combo_count > 0:
			_time_remaining = minf(_time_remaining, _get_hold_time())

## 스테이지 난이도에 맞춰 주입하는 콤보 점수의 기준값입니다.
@export_range(0, 1000000, 1)
var stage_base_score: int = 100:
	set(value):
		stage_base_score = maxi(value, 0)

var combo_count: int:
	get:
		return _combo_count

var current_tier: int:
	get:
		return int(_rules.call(&"get_tier", _combo_count))

var time_remaining: float:
	get:
		return _time_remaining

var total_score: int:
	get:
		return _total_score

var is_timer_suspended: bool:
	get:
		return _timer_suspension_depth > 0


func _ready() -> void:
	add_to_group(&"combo_systems")
	set_process(false)


func _process(delta: float) -> void:
	advance_time(delta)


## 플리퍼, 벽, 범퍼 등 유효 충돌 이벤트에서 호출합니다.
## source는 신호 직접 연결을 허용하기 위한 선택 인자이며 계산에는 사용하지 않습니다.
func register_hit(_source: Node = null) -> int:
	var previous_tier := current_tier
	_combo_count += 1
	_time_remaining = _get_hold_time()
	var next_tier := current_tier

	if previous_tier != next_tier:
		combo_tier_changed.emit(previous_tier, next_tier, _combo_count)
	combo_changed.emit(_combo_count, next_tier, _time_remaining)
	combo_timer_changed.emit(_time_remaining, _get_hold_time())
	_refresh_processing()
	return _combo_count


## 테스트와 일시정지에 독립적인 게임 상태 구동을 위해 시간을 명시적으로 진행합니다.
func advance_time(delta: float) -> void:
	if _combo_count <= 0 or is_timer_suspended or delta <= 0.0:
		return

	_time_remaining = maxf(_time_remaining - delta, 0.0)
	combo_timer_changed.emit(_time_remaining, _get_hold_time())
	if is_zero_approx(_time_remaining):
		finish_combo(EndReason.TIMEOUT)


## 현재 콤보 점수를 정산하고 콤보 상태를 초기화합니다.
func finish_combo(reason: EndReason = EndReason.MANUAL) -> int:
	if _combo_count <= 0:
		return 0

	var finished_count := _combo_count
	var finished_tier := current_tier
	var awarded_score: int = _rules.call(
		&"calculate_score",
		stage_base_score,
		finished_count
	)

	_total_score += awarded_score
	_clear_active_combo()
	score_changed.emit(_total_score, awarded_score)
	combo_finished.emit(
		finished_count,
		finished_tier,
		awarded_score,
		reason
	)
	return awarded_score


## 새 게임 시작 등에서 정산 없이 진행 중 콤보와 누적 점수를 모두 지웁니다.
func reset_run() -> void:
	var score_was_changed := _total_score != 0
	_total_score = 0
	_clear_active_combo()
	if score_was_changed:
		score_changed.emit(0, 0)


## 경로 이동·자동 이동 연출 시작 시 유지 시간을 새로 채우고 멈춥니다.
## 중첩된 연출도 마지막 resume_combo_timer 호출 전까지 안전하게 멈춰 있습니다.
func suspend_combo_timer() -> void:
	_timer_suspension_depth += 1
	if _combo_count > 0:
		_time_remaining = _get_hold_time()
		combo_timer_changed.emit(_time_remaining, _get_hold_time())
	timer_suspension_changed.emit(true, _time_remaining)
	_refresh_processing()


func resume_combo_timer() -> void:
	if _timer_suspension_depth <= 0:
		return
	_timer_suspension_depth -= 1
	timer_suspension_changed.emit(is_timer_suspended, _time_remaining)
	_refresh_processing()


## 기존 플리퍼의 회전 충돌 신호를 콤보 적립 이벤트에 연결합니다.
func watch_flipper(flipper: Node) -> bool:
	if flipper == null or not flipper.has_signal(FLIPPER_HIT_SIGNAL):
		return false
	var callback := Callable(self, &"register_hit")
	if not flipper.is_connected(FLIPPER_HIT_SIGNAL, callback):
		flipper.connect(FLIPPER_HIT_SIGNAL, callback)
	return true


func unwatch_flipper(flipper: Node) -> void:
	if flipper == null or not flipper.has_signal(FLIPPER_HIT_SIGNAL):
		return
	var callback := Callable(self, &"register_hit")
	if flipper.is_connected(FLIPPER_HIT_SIGNAL, callback):
		flipper.disconnect(FLIPPER_HIT_SIGNAL, callback)


## 게임 상태의 낙하/새 발사 이벤트에 직접 연결할 수 있는 수명주기 진입점입니다.
func on_ball_drained() -> int:
	return finish_combo(EndReason.BALL_DRAINED)


func on_ball_launched() -> int:
	return finish_combo(EndReason.NEW_BALL)


func calculate_current_damage(base_damage: float) -> int:
	return int(_rules.call(&"calculate_damage", base_damage, _combo_count))


func calculate_base_damage(
	boss_health: float,
	target_hit_count: int,
	ball_weight_multiplier: float
) -> float:
	return float(_rules.call(
		&"calculate_base_damage",
		boss_health,
		target_hit_count,
		ball_weight_multiplier
	))


func _clear_active_combo() -> void:
	_combo_count = 0
	_time_remaining = 0.0
	_timer_suspension_depth = 0
	combo_changed.emit(0, ComboRulesClass.Tier.NONE, 0.0)
	combo_timer_changed.emit(0.0, _get_hold_time())
	timer_suspension_changed.emit(false, 0.0)
	_refresh_processing()


func _get_hold_time() -> float:
	return maxf(float(_rules.get(&"hold_time")), 0.1)


func _refresh_processing() -> void:
	set_process(_combo_count > 0 and not is_timer_suspended)
