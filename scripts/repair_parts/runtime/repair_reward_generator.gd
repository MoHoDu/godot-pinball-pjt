class_name RepairRewardGenerator
extends RefCounted


## 웨이브 종료 후 수리함 보상 후보를 만듭니다 (기획서 3-3 후보 생성 규칙).
##  - 첫 보상에는 현재 보유하지 않은 부품을 최소 하나 포함한다.
##  - 같은 후보 세 개가 모두 동일 계열이 되지 않게 한다.
##  - 최대 랭크 부품은 후보에서 제외한다.
##  - 웨이브당 재추첨 1회를 허용한다.


const DEFAULT_CANDIDATE_COUNT := 3
const DEFAULT_REROLLS_PER_WAVE := 1


var inventory: RepairInventory = null
var rng := RandomNumberGenerator.new()

var _rerolls_remaining: int = DEFAULT_REROLLS_PER_WAVE


func setup(target_inventory: RepairInventory, seed_value: int = -1) -> void:
	inventory = target_inventory
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func on_wave_started() -> void:
	_rerolls_remaining = DEFAULT_REROLLS_PER_WAVE


func can_reroll() -> bool:
	return _rerolls_remaining > 0


func reroll(
	all_definitions: Array[RepairPartDefinition],
	is_first_reward: bool = false
) -> Array[StringName]:
	if not can_reroll():
		return []
	_rerolls_remaining -= 1
	return generate_candidates(
		all_definitions,
		DEFAULT_CANDIDATE_COUNT,
		is_first_reward
	)


## 후보 part_id 목록을 반환합니다. 새 부품 획득과 기존 부품 랭크업이 섞입니다.
## is_first_reward가 true면 미보유 부품을 최소 하나 보장합니다 (3-3 규칙 1).
func generate_candidates(
	all_definitions: Array[RepairPartDefinition],
	candidate_count: int = DEFAULT_CANDIDATE_COUNT,
	is_first_reward: bool = false
) -> Array[StringName]:
	var pool: Array[StringName] = []
	for definition: RepairPartDefinition in all_definitions:
		if definition == null or not definition.is_valid():
			continue
		if inventory != null and inventory.is_max_rank(definition.part_id):
			continue
		pool.append(definition.part_id)

	if pool.is_empty():
		return []

	var candidates: Array[StringName] = []
	var attempts := 0
	while candidates.size() < candidate_count and attempts < 64:
		attempts += 1
		var picked := pool[rng.randi_range(0, pool.size() - 1)]
		if picked in candidates:
			continue
		candidates.append(picked)
	# 부품 종류가 후보 수보다 적으면 중복 없이 가능한 만큼만 제시합니다.

	if is_first_reward:
		_ensure_unowned_included(candidates, pool)
	return candidates


func _ensure_unowned_included(
	candidates: Array[StringName],
	pool: Array[StringName]
) -> void:
	if inventory == null or candidates.is_empty():
		return
	var has_unowned := false
	for part_id: StringName in candidates:
		if not inventory.owns(part_id):
			has_unowned = true
			break
	if has_unowned:
		return
	var unowned_pool: Array[StringName] = []
	for part_id: StringName in pool:
		if not inventory.owns(part_id):
			unowned_pool.append(part_id)
	if unowned_pool.is_empty():
		return
	candidates[candidates.size() - 1] = unowned_pool[
		rng.randi_range(0, unowned_pool.size() - 1)
	]
