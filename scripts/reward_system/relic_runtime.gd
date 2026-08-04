class_name RelicRuntime
extends Node


## 유물 효과가 실제 게임 값에 닿는 유일한 통로입니다.
##
## 기존 스크립트를 수정하지 않고 효과를 붙이기 위해, 이 노드가
## 1) 건드릴 값의 기준값을 처음 한 번 스냅샷하고
## 2) 효과를 항상 "기준값 × 배율"로 다시 계산해 덮어쓰고
## 3) 트리에서 빠질 때 전부 원래 값으로 되돌립니다.
##
## 3번이 없으면 에디터에서 플레이를 반복할 때 preload된 공유 .tres가
## 이전 판의 버프를 그대로 들고 있게 됩니다. 디스크 파일은 건드리지 않습니다.


signal effects_applied(applied_count: int)


## WaveRuntimeCoordinator._configure_lives_from_inventory()가 라이프 슬롯을
## 3~5개로 단언합니다. 공을 늘리는 효과는 이 상한을 넘을 수 없습니다.
const MAX_LIFE_SLOTS := 5
const MIN_LIFE_SLOTS := 3


var combo_system: Node
var launcher: PinballLauncher
var ball_inventory: WaveBallInventory
var flippers: Array[Node] = []

var _baselines: Dictionary = {}
var _baseline_order: Array = []


func bind_board(
	next_combo_system: Node,
	next_launcher: PinballLauncher,
	next_ball_inventory: WaveBallInventory,
	next_flippers: Array[Node] = []
) -> bool:
	combo_system = next_combo_system
	launcher = next_launcher
	ball_inventory = next_ball_inventory
	flippers = next_flippers
	return combo_system != null \
		and launcher != null \
		and ball_inventory != null


## 보유 중인 유물 전체를 기준값에서 다시 계산해 적용합니다.
func apply_all(inventory: RelicInventory) -> int:
	if inventory == null:
		return 0
	var applied := 0
	for definition: RelicDefinition in inventory.get_owned():
		if definition == null or not definition.is_valid():
			continue
		var stack_count := inventory.get_stack_count(definition.relic_id)
		if definition.effect.apply(self, stack_count):
			applied += 1
	effects_applied.emit(applied)
	return applied


## 처음 읽을 때의 값을 기준값으로 저장하고 돌려줍니다.
func get_baseline(target: Object, property: StringName) -> Variant:
	if target == null:
		return null
	var key := _make_key(target, property)
	if not _baselines.has(key):
		_baselines[key] = target.get(property)
		_baseline_order.append({
			&"target": target,
			&"property": property,
			&"key": key,
		})
	return _baselines[key]


func set_value(target: Object, property: StringName, value: Variant) -> bool:
	if target == null:
		return false
	get_baseline(target, property)
	target.set(property, value)
	return true


## 기준값에 배율을 곱해 덮어씁니다. 누적이 아니라 항상 기준값 기준입니다.
func set_scaled(target: Object, property: StringName, factor: float) -> bool:
	if target == null:
		return false
	var base: Variant = get_baseline(target, property)
	if typeof(base) == TYPE_INT:
		return set_value(target, property, roundi(float(base) * factor))
	if typeof(base) == TYPE_FLOAT:
		return set_value(target, property, float(base) * factor)
	return false


func has_baseline(target: Object, property: StringName) -> bool:
	return _baselines.has(_make_key(target, property))


func restore_all() -> void:
	# 두 번 돌립니다. FlipperParryRules처럼 setter가 서로를 clamp하는 값들은
	# 한 번의 순회로는 원래 값까지 못 돌아가는 경우가 있습니다.
	for _pass in 2:
		for entry: Dictionary in _baseline_order:
			var target: Object = entry[&"target"]
			if target == null or not is_instance_valid(target):
				continue
			target.set(entry[&"property"], _baselines[entry[&"key"]])
	_baselines.clear()
	_baseline_order.clear()


func _exit_tree() -> void:
	restore_all()


func _make_key(target: Object, property: StringName) -> String:
	return "%d:%s" % [target.get_instance_id(), property]
