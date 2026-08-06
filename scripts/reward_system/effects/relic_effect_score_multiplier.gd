@tool
class_name RelicEffectScoreMultiplier
extends RelicEffect


## 별모양 브로치 — 콤보 단계별 점수 배율을 함께 올립니다.
## ComboRules의 네 배율을 기준값에서 다시 계산합니다.
## ComboWaveController가 웨이브마다 덮어쓰는 stage_base_score 대신 이쪽을 건드려야
## 다음 웨이브 진입 후에도 효과가 살아남습니다.


const SCORE_MULTIPLIER_PROPERTIES: Array[StringName] = [
	&"normal_score_multiplier",
	&"super_score_multiplier",
	&"hyper_score_multiplier",
	&"ultra_score_multiplier",
]


@export_range(0.0, 2.0, 0.01, "suffix:x")
var bonus_per_stack: float = 0.25:
	set(value):
		bonus_per_stack = maxf(value, 0.0)
		emit_changed()


func apply(runtime: RelicRuntime, stack_count: int) -> bool:
	if runtime == null or runtime.combo_system == null:
		return false
	var rules: Resource = runtime.combo_system.get(&"rules")
	if rules == null:
		return false
	var factor := 1.0 + bonus_per_stack * maxi(stack_count, 0)
	var changed := false
	for property: StringName in SCORE_MULTIPLIER_PROPERTIES:
		changed = runtime.set_scaled(rules, property, factor) or changed
	return changed


func describe(stack_count: int = 1) -> String:
	return "콤보 점수 배율 +%d%%" % roundi(bonus_per_stack * maxi(stack_count, 1) * 100.0)
