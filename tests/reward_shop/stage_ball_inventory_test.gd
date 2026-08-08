extends SceneTree


## 스테이지 공 인벤토리(해금·재고 생성·상한·리셋) 단위 테스트입니다.


const SCENE_MAP := preload(
	"res://settings/reward_shop/RewardBallSceneMap_Stage01.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_scene_map()
	await _test_inventory()
	_finish()


func _test_scene_map() -> void:
	var scene_map := SCENE_MAP as RewardBallSceneMap
	for ball_id in [&"clockwork", &"rubber", &"gel", &"lead", &"hollow_bell"]:
		_expect(scene_map.has_ball(ball_id), "%s 매핑이 있어야 한다." % ball_id)
		var definition := scene_map.make_definition(ball_id)
		_expect(
			definition != null and definition.is_valid(),
			"%s 정의가 유효해야 한다." % ball_id
		)
	_expect(not scene_map.has_ball(&"base"), "기본 공은 보상 매핑에 없어야 한다.")


func _test_inventory() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var inventory := StageBallInventory.new()
	inventory.scene_map = SCENE_MAP
	holder.add_child(inventory)

	# 기본 재고 3개(생명 3)를 만든다.
	var base_stock: Array[BallStock] = [
		_make_base_stock(&"light"),
		_make_base_stock(&"normal"),
		_make_base_stock(&"heavy"),
	]
	inventory.capture_base_stock(base_stock)
	_expect(inventory.base_life_count() == 3, "기본 생명은 3이어야 한다.")

	var events: Array = []
	inventory.unlocked_balls_changed.connect(func(ids: Array[StringName]) -> void:
		events.append(ids.size())
	)

	# 처음 재고는 기본 3개뿐.
	_expect(inventory.build_stock().size() == 3, "해금 전 재고는 3개여야 한다.")

	_expect(inventory.unlock(&"rubber"), "고무막 해금은 성공해야 한다.")
	_expect(not inventory.unlock(&"rubber"), "같은 공은 다시 해금할 수 없다.")
	_expect(not inventory.unlock(&"unknown"), "매핑 없는 공은 해금할 수 없다.")
	_expect(inventory.unlocked_ids == [&"rubber"], "해금 목록은 rubber 하나여야 한다.")

	var stock_after_one := inventory.build_stock()
	_expect(stock_after_one.size() == 4, "해금 1개 뒤 재고는 4개여야 한다.")
	var ids_after_one: Array[StringName] = []
	for item in stock_after_one:
		ids_after_one.append(item.definition.ball_id)
	_expect(ids_after_one.has(&"rubber"), "해금한 공이 재고에 들어가야 한다.")

	# 상한(5) 검사: 기본 3 + 해금은 최대 2까지만 재고에 실린다.
	inventory.unlock(&"gel")
	inventory.unlock(&"lead")
	_expect(inventory.unlocked_ids.size() == 3, "해금 기록 자체는 3개여야 한다.")
	_expect(inventory.build_stock().size() == 5, "재고는 상한 5로 막혀야 한다.")
	_expect(
		inventory.selectable_unlocked_ids().size() == 2,
		"이번 재고에 실릴 수 있는 해금 공은 2종이어야 한다."
	)

	# 리셋: 구매 공을 비우고 기본만 남긴다.
	inventory.reset_to_base()
	_expect(inventory.unlocked_ids.is_empty(), "리셋 후 해금 목록은 비어야 한다.")
	_expect(inventory.build_stock().size() == 3, "리셋 후 재고는 기본 3개여야 한다.")

	holder.queue_free()
	await process_frame


func _make_base_stock(ball_id: StringName) -> BallStock:
	var definition := BallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = String(ball_id)
	# 유효성 검사를 통과하도록 아무 씬이나 물려 둔다.
	definition.ball_scene = SCENE_MAP.scene_of(&"rubber")
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 1
	return stock


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_ball_inventory_test")
		quit(0)
		return
	print("FAIL: stage_ball_inventory_test (%d failures)" % _failures.size())
	quit(1)
