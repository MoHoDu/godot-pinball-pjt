@tool
class_name RelicPool
extends Resource


## 웨이브 종료 시 제시할 후보를 뽑습니다.


@export var definitions: Array[RelicDefinition] = []


func get_valid_definitions() -> Array[RelicDefinition]:
	var valid: Array[RelicDefinition] = []
	for definition: RelicDefinition in definitions:
		if definition != null and definition.is_valid():
			valid.append(definition)
	return valid


## 스택이 꽉 찬 부품은 후보에서 빠집니다.
## 남은 후보가 count보다 적으면 있는 만큼만 돌려줍니다. 조용히 채우지 않습니다.
func draw(
	count: int,
	inventory: RelicInventory = null,
	rng: RandomNumberGenerator = null
) -> Array[RelicDefinition]:
	var candidates: Array[RelicDefinition] = []
	for definition: RelicDefinition in get_valid_definitions():
		if inventory != null and inventory.is_full(definition):
			continue
		candidates.append(definition)

	var draw_count := mini(maxi(count, 0), candidates.size())
	if draw_count <= 0:
		return []

	var picked: Array[RelicDefinition] = []
	var pool_indices: Array[int] = []
	for index in candidates.size():
		pool_indices.append(index)

	for _step in draw_count:
		var slot := 0
		if rng != null:
			slot = rng.randi_range(0, pool_indices.size() - 1)
		else:
			slot = randi_range(0, pool_indices.size() - 1)
		picked.append(candidates[pool_indices[slot]])
		pool_indices.remove_at(slot)
	return picked
