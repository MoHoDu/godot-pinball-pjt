class_name ComboSystem
extends Node


signal combo_changed(combo_count: int, tier: int, time_remaining: float)
signal combo_tier_changed(previous_tier: int, current_tier: int, combo_count: int)
signal combo_timer_changed(time_remaining: float, hold_time: float)
signal combo_finished(combo_count: int, tier: int, awarded_score: int, reason: int)
signal score_changed(total_score: int, added_score: int)
signal timer_suspension_changed(is_suspended: bool, time_remaining: float)
signal boss_damage_calculated(damage: int, combo_count: int, tier: int)


enum EndReason {
	TIMEOUT,
	BALL_DRAINED,
	MANUAL,
}


const ComboRulesClass := preload(
	"res://scripts/combo_system/combo_rules.gd"
)
const DEFAULT_RULES: Resource = preload(
	"res://settings/combo/ComboRules.tres"
)


var _rules: Resource = DEFAULT_RULES
var _combo_count: int = 0
var _total_score_weight: float = 0.0
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

var total_score_weight: float:
	get:
		return _total_score_weight

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


## 범퍼·유물 등 스코어 대상의 새로운 유효 타격에서 호출합니다.
## score_weight 기본값 1은 stage_base_score 한 단위를 뜻합니다.
func register_hit(score_weight: float = 1.0) -> int:
	var previous_tier := current_tier
	_combo_count += 1
	_total_score_weight += maxf(score_weight, 0.0)
	_time_remaining = _get_hold_time()
	var next_tier := current_tier

	if previous_tier != next_tier:
		combo_tier_changed.emit(previous_tier, next_tier, _combo_count)
	combo_changed.emit(_combo_count, next_tier, _time_remaining)
	combo_timer_changed.emit(_time_remaining, _get_hold_time())
	_refresh_processing()
	return _combo_count


## 콤보를 증가시키지 않고 활성 콤보의 유지 시간만 초기값으로 갱신합니다.
## 벽처럼 시간 갱신만 담당하는 오브젝트가 사용하며 0콤보에서는 아무 상태도 만들지 않습니다.
func refresh_combo_timer() -> bool:
	if _combo_count <= 0:
		return false
	_time_remaining = _get_hold_time()
	combo_timer_changed.emit(_time_remaining, _get_hold_time())
	_refresh_processing()
	return true


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
		_total_score_weight,
		finished_count
	)

	_total_score += awarded_score
	_clear_active_combo()
	if awarded_score > 0:
		score_changed.emit(_total_score, awarded_score)
	combo_finished.emit(
		finished_count,
		finished_tier,
		awarded_score,
		reason
	)
	return awarded_score


## 웨이브 재시도에서 정산 없이 콤보와 웨이브 스코어를 0으로 만듭니다.
func reset_wave() -> void:
	var score_was_changed := _total_score != 0
	_total_score = 0
	_clear_active_combo()
	if score_was_changed:
		score_changed.emit(0, 0)


func reset_run() -> void:
	reset_wave()


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


## 범퍼·유물의 중복 제거된 유효 타격 신호를 콤보 적립에 연결합니다.
func bind_hit_source(source: Node) -> bool:
	if source == null or not source.has_signal(&"valid_hit_registered"):
		return false
	var callback := Callable(self, &"_on_valid_hit_registered")
	if not source.is_connected(&"valid_hit_registered", callback):
		source.connect(&"valid_hit_registered", callback)
	return true


func unbind_hit_source(source: Node) -> void:
	if source == null or not source.has_signal(&"valid_hit_registered"):
		return
	var callback := Callable(self, &"_on_valid_hit_registered")
	if source.is_connected(&"valid_hit_registered", callback):
		source.disconnect(&"valid_hit_registered", callback)


## 게임 상태의 낙하/새 발사 이벤트에 직접 연결할 수 있는 수명주기 진입점입니다.
func on_ball_drained() -> int:
	return finish_combo(EndReason.BALL_DRAINED)


func on_ball_launched() -> int:
	# 낙하에서 이미 정산했으므로 새 발사는 남은 상태만 정산 없이 제거합니다.
	_clear_active_combo()
	return 0


func on_wave_retried() -> void:
	reset_wave()


## 보스 타격을 먼저 콤보에 포함한 뒤 증가된 카운트로 피해를 계산합니다.
## 보스 타격은 일반 웨이브용 점수 가중치를 추가하지 않습니다.
func register_boss_hit(base_damage: float) -> int:
	register_hit(0.0)
	var damage := calculate_current_damage(base_damage)
	boss_damage_calculated.emit(damage, _combo_count, current_tier)
	return damage


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


func _on_valid_hit_registered(
	_source: Node,
	_contact_id: int,
	score_weight: float
) -> void:
	register_hit(score_weight)


func _clear_active_combo() -> void:
	_combo_count = 0
	_total_score_weight = 0.0
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
