extends SceneTree


## 수리함·보상 후보 규칙 단위 테스트 (기획서 3-2, 3-3).
## 실행:
## godot --headless --path . \
##     --script res://tests/repair_parts/unit/repair_reward_test.gd


const BROOCH_DEF := preload(
	"res://settings/repair_parts/StarlightBroochDefinition.tres"
)
const GEARS_DEF := preload(
	"res://settings/repair_parts/GoldenGearsDefinition.tres"
)
const NEEDLE_DEF := preload(
	"res://settings/repair_parts/CrescentNeedleDefinition.tres"
)
const BELL_DEF := preload(
	"res://settings/repair_parts/ForgottenStarBellDefinition.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_definitions_are_valid()
	_test_rank_values_match_spec()
	_test_inventory_acquire_and_rank_up()
	_test_candidates_exclude_max_rank()
	_test_first_reward_includes_unowned()
	_test_reroll_limit()
	_finish()


func _all_definitions() -> Array[RepairPartDefinition]:
	var definitions: Array[RepairPartDefinition] = [
		BROOCH_DEF, GEARS_DEF, NEEDLE_DEF, BELL_DEF
	]
	return definitions


func _make_inventory() -> RepairInventory:
	var inventory := RepairInventory.new()
	for definition: RepairPartDefinition in _all_definitions():
		inventory.register_definition(definition)
	return inventory


func _test_definitions_are_valid() -> void:
	for definition: RepairPartDefinition in _all_definitions():
		_expect(definition.is_valid(),
			"%s 정의가 유효해야 한다." % definition.part_id)
		_expect(definition.get_max_rank() == 3,
			"%s 최대 랭크는 3이어야 한다." % definition.part_id)


func _test_rank_values_match_spec() -> void:
	_expect(
		is_equal_approx(BROOCH_DEF.get_rank_data(1).window_seconds, 6.0)
			and is_equal_approx(BROOCH_DEF.get_rank_data(3).score_weight, 5.0),
		"브로치 랭크 수치가 기획서 표와 일치해야 한다."
	)
	_expect(
		is_equal_approx(GEARS_DEF.get_rank_data(2).contact_boost, 120.0)
			and is_equal_approx(GEARS_DEF.get_rank_data(3).overdrive_boost, 300.0)
			and is_equal_approx(GEARS_DEF.get_rank_data(1).window_seconds, 2.4),
		"톱니 랭크 수치가 기획서 표와 일치해야 한다."
	)
	_expect(
		is_equal_approx(NEEDLE_DEF.get_rank_data(1).score_weight, 0.0)
			and is_equal_approx(NEEDLE_DEF.get_rank_data(3).window_seconds, 5.0),
		"바늘 랭크 수치가 기획서 표와 일치해야 한다."
	)
	_expect(
		is_equal_approx(BELL_DEF.get_rank_data(1).echo_delay, 0.6)
			and is_equal_approx(BELL_DEF.get_rank_data(3).cooldown_seconds, 0.7),
		"방울 랭크 수치가 기획서 표와 일치해야 한다."
	)


func _test_inventory_acquire_and_rank_up() -> void:
	var inventory := _make_inventory()
	_expect(inventory.acquire(&"golden_gears") == 1,
		"새 부품은 랭크 1로 추가되어야 한다.")
	_expect(inventory.acquire(&"golden_gears") == 2,
		"기존 부품 재획득은 랭크를 올려야 한다.")
	inventory.acquire(&"golden_gears")
	_expect(inventory.is_max_rank(&"golden_gears"),
		"랭크 3이면 최대 랭크여야 한다.")
	_expect(inventory.acquire(&"golden_gears") == 3,
		"최대 랭크에서 추가 획득해도 랭크가 넘치면 안 된다.")


func _test_candidates_exclude_max_rank() -> void:
	var inventory := _make_inventory()
	for _index: int in range(3):
		inventory.acquire(&"golden_gears")
	var generator := RepairRewardGenerator.new()
	generator.setup(inventory, 12345)
	for _trial: int in range(20):
		var candidates := generator.generate_candidates(_all_definitions())
		_expect(not candidates.has(&"golden_gears"),
			"최대 랭크 부품은 후보에서 제외되어야 한다.")
		_expect(candidates.size() == 3, "후보는 3개가 제시되어야 한다.")


func _test_first_reward_includes_unowned() -> void:
	var inventory := _make_inventory()
	inventory.acquire(&"starlight_brooch")
	var generator := RepairRewardGenerator.new()
	generator.setup(inventory, 777)
	for _trial: int in range(20):
		var candidates := generator.generate_candidates(
			_all_definitions(), 3, true
		)
		var has_unowned := false
		for part_id: StringName in candidates:
			if not inventory.owns(part_id):
				has_unowned = true
		_expect(has_unowned,
			"첫 보상에는 현재 보유하지 않은 부품이 최소 하나 포함되어야 한다.")


func _test_reroll_limit() -> void:
	var inventory := _make_inventory()
	var generator := RepairRewardGenerator.new()
	generator.setup(inventory, 42)
	generator.on_wave_started()
	_expect(generator.can_reroll(), "웨이브 시작 시 재추첨 1회가 있어야 한다.")
	var rerolled := generator.reroll(_all_definitions())
	_expect(not rerolled.is_empty(), "재추첨은 새 후보를 반환해야 한다.")
	_expect(not generator.can_reroll(), "웨이브당 재추첨은 1회만 허용된다.")
	_expect(generator.reroll(_all_definitions()).is_empty(),
		"재추첨 소진 후에는 빈 결과를 반환해야 한다.")
	generator.on_wave_started()
	_expect(generator.can_reroll(), "새 웨이브에서 재추첨이 회복되어야 한다.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: repair_reward_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: repair_reward_test (%d failures)" % _failures.size())
	quit(1)