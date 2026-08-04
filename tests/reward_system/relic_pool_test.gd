extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var pool := RelicPool.new()
	pool.definitions = [
		_make_definition(&"a", 3),
		_make_definition(&"b", 2),
		_make_definition(&"c", 1),
		_make_definition(&"d", 1),
	]

	var fixture_root := Node.new()
	root.add_child(fixture_root)
	var inventory := RelicInventory.new()
	fixture_root.add_child(inventory)
	await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260804
	var first_draw := pool.draw(3, inventory, rng)
	_expect(first_draw.size() == 3, "후보가 넉넉하면 3장을 뽑아야 한다.")
	_expect(_is_unique(first_draw), "한 번의 추첨에 같은 부품이 두 번 나오면 안 된다.")

	var rng_repeat := RandomNumberGenerator.new()
	rng_repeat.seed = 20260804
	var repeat_draw := pool.draw(3, inventory, rng_repeat)
	_expect(
		_ids(first_draw) == _ids(repeat_draw),
		"같은 시드는 같은 결과를 내야 한다."
	)

	# c를 상한(1)까지 채우면 후보에서 빠진다.
	_expect(inventory.acquire(pool.definitions[2]) == 1, "부품 c를 하나 획득해야 한다.")
	_expect(inventory.is_full(pool.definitions[2]), "상한 1인 부품은 한 개로 가득 찬다.")
	for _attempt in 12:
		var draw_without_c := pool.draw(3, inventory, rng)
		_expect(
			not _ids(draw_without_c).has(&"c"),
			"상한에 찬 부품은 후보에서 빠져야 한다."
		)

	# 상한에 찬 부품이 늘어 후보가 3장 미만이면 있는 만큼만 준다.
	inventory.acquire(pool.definitions[3])
	inventory.acquire(pool.definitions[1])
	inventory.acquire(pool.definitions[1])
	_expect(inventory.is_full(pool.definitions[1]), "상한 2인 부품은 두 개로 가득 찬다.")
	var short_draw := pool.draw(3, inventory, rng)
	_expect(short_draw.size() == 1, "남은 후보가 하나면 한 장만 준다.")
	_expect(
		short_draw[0].relic_id == &"a",
		"남은 후보는 상한에 닿지 않은 부품이어야 한다."
	)

	inventory.acquire(pool.definitions[0])
	inventory.acquire(pool.definitions[0])
	inventory.acquire(pool.definitions[0])
	_expect(pool.draw(3, inventory, rng).is_empty(), "후보가 없으면 빈 배열을 준다.")
	_expect(inventory.total_count == 7, "획득한 부품 총합이 유지되어야 한다.")

	# 효과가 없는 정의는 유효하지 않으므로 후보에 들어가지 않는다.
	var broken := RelicDefinition.new()
	broken.relic_id = &"broken"
	pool.definitions.append(broken)
	_expect(
		pool.get_valid_definitions().size() == 4,
		"효과가 없는 정의는 유효 후보에서 빠져야 한다."
	)

	fixture_root.queue_free()
	await process_frame
	_finish()


func _make_definition(relic_id: StringName, max_stack: int) -> RelicDefinition:
	var definition := RelicDefinition.new()
	definition.relic_id = relic_id
	definition.display_name = String(relic_id)
	definition.max_stack = max_stack
	definition.effect = RelicEffectScoreMultiplier.new()
	return definition


func _ids(definitions: Array[RelicDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: RelicDefinition in definitions:
		ids.append(definition.relic_id)
	return ids


func _is_unique(definitions: Array[RelicDefinition]) -> bool:
	var seen: Array[StringName] = []
	for definition: RelicDefinition in definitions:
		if seen.has(definition.relic_id):
			return false
		seen.append(definition.relic_id)
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: relic_pool_test")
		quit(0)
		return
	print("FAIL: relic_pool_test (%d failures)" % _failures.size())
	quit(1)
