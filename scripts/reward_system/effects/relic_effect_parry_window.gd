@tool
class_name RelicEffectParryWindow
extends RelicEffect


## 곡선 바늘 — 패링 판정 창을 넓힙니다.
##
## FlipperParryRules의 setter가 perfect를 normal 이하로 clamp합니다.
## 그래서 normal을 먼저 늘리지 않으면 perfect 증가분이 잘려 나갑니다. 순서가 곧 로직입니다.


@export_range(0.0, 3.0, 0.01, "suffix:x")
var bonus_per_stack: float = 0.35:
	set(value):
		bonus_per_stack = maxf(value, 0.0)
		emit_changed()


func apply(runtime: RelicRuntime, stack_count: int) -> bool:
	if runtime == null or runtime.flippers.is_empty():
		return false
	var factor := 1.0 + bonus_per_stack * maxi(stack_count, 0)
	var changed := false
	for rules: Resource in _collect_parry_rules(runtime):
		# normal 먼저, perfect 나중. 반대로 하면 clamp에 잘립니다.
		changed = runtime.set_scaled(rules, &"normal_parry_window_time", factor) or changed
		changed = runtime.set_scaled(rules, &"perfect_parry_window_time", factor) or changed
	return changed


func describe(stack_count: int = 1) -> String:
	return "패링 판정 창 +%d%%" % roundi(bonus_per_stack * maxi(stack_count, 1) * 100.0)


## 플리퍼들이 같은 .tres를 공유하므로 중복을 제거합니다.
func _collect_parry_rules(runtime: RelicRuntime) -> Array[Resource]:
	var collected: Array[Resource] = []
	for flipper: Node in runtime.flippers:
		if flipper == null or not is_instance_valid(flipper):
			continue
		var rules: Resource = flipper.get(&"parry_rules")
		if rules == null or collected.has(rules):
			continue
		collected.append(rules)
	return collected
