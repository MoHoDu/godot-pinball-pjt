extends SceneTree


## 수리함·보상 후보 규칙 단위 테스트 (기획서 3-2, 3-3 + v0.3 랭크 삭제).
## 실행:
## godot --headless --path . \
##     --script res://tests/repair_parts/unit/repair_reward_test.gd


const BROOCH_DEF := preload(
	"res://settings/repair_parts/StarlightBroochDefinition.tres"
)
const GEARS_DEF := preload(
	"res://settings/repair_parts/GoldenGearsDefinition.tres"
)
const BELL_DEF := preload(
	"res://settings/repair_parts/ForgottenStarBellDefinition.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_definitions_are_valid()
	_test_values_match_spec()
	_test_inventory_has_no_rank()
	_test_candidates_exclude_owned()
	_test_first_reward_includes_unowned()
	_test_reroll_limit()
	_finish()


func _all_definitions() -> Array[RepairPartDefinition]:
	var definitions: Array[RepairPartDefinition] = [
		BROOCH_DEF, GEARS_DEF, BELL_DEF
	]
	return definitions


func _make_inventory() -> RepairInventory:
	var inventory := RepairInventory.new()
	for definition: RepairPartDefinition in _all_definitions():
		inventory.register_definition(definition)
	return inventory


func _test_definitions_are_valid() -> void:
	_expect(_all_definitions().size() == 3,
		"v0.3 수리 부품 정의는 세 개여야 한다.")
	for definition: RepairPartDefinition in _all_definitions():
		_expect(definition.is_valid(),
			"%s 정의가 유효해야 한다." % definition.part_id)
	_expect(
		not ResourceLoader.exists(
			"res://settings/repair_parts/CrescentNeedleDefinition.tres"
		),
		"초승달 바늘 정의 리소스는 삭제되어야 한다."
	)


func _test_values_match_spec() -> void:
	_expect(
		is_equal_approx(BROOCH_DEF.brooch_window_seconds, 6.0)
			and is_equal_approx(BROOCH_DEF.brooch_finish_multiplier, 3.0)
			and BROOCH_DEF.brooch_required_visits == 2,
		"브로치 수치는 6.0초 / x3.0 / 다른 부품 2종이어야 한다."
	)
	_expect(
		GEARS_DEF.gear_contact_multiplier > 1.0
			and is_equal_approx(GEARS_DEF.gear_overdrive_boost, 180.0)
			and is_equal_approx(GEARS_DEF.gear_window_seconds, 2.4)
			and GEARS_DEF.gear_max_stack == 3,
		"톱니 수치는 접촉 배율 / 과회전 +180px/s / 2.4초 3단계여야 한다."
	)
	_expect(
		is_equal_approx(BELL_DEF.bell_echo_delay, 0.6)
			and is_equal_approx(BELL_DEF.bell_echo_combo_multiplier, 0.25)
			and is_equal_approx(BELL_DEF.bell_cooldown_seconds, 1.0),
		"방울 수치는 0.6초 지연 / 콤보 가중치 0.25 / 쿨다운 1.0초여야 한다."
	)


func _test_inventory_has_no_rank() -> void:
	var inventory := _make_inventory()
	_expect(inventory.acquire(&"golden_gears"),
		"새 부품은 수리함에 추가되어야 한다.")
	_expect(inventory.owns(&"golden_gears"), "추가된 부품은 보유 상태여야 한다.")
	_expect(not inventory.acquire(&"golden_gears"),
		"랭크가 없으므로 같은 부품 재획득은 아무 변화도 만들지 않아야 한다.")
	_expect(not inventory.has_method(&"get_rank"),
		"RepairInventory에 랭크 API가 남아 있으면 안 된다.")
	_expect(not inventory.has_method(&"is_max_rank"),
		"RepairInventory에 최대 랭크 API가 남아 있으면 안 된다.")


func _test_candidates_exclude_owned() -> void:
	var inventory := _make_inventory()
	inventory.acquire(&"golden_gears")
	var generator := RepairRewardGenerator.new()
	generator.setup(inventory, 12345)
	for _trial: int in range(20):
		var candidates := generator.generate_candidates(_all_definitions())
		_expect(not candidates.has(&"golden_gears"),
			"이미 보유한 부품은 후보에서 제외되어야 한다.")
		_expect(candidates.size() == 2,
			"남은 미보유 부품 수만큼만 후보가 제시되어야 한다.")


func _test_first_reward_includes_unowned() -> void:
	var inventory := _make_inventory()
	inventory.acquire(&"starlight_brooch")
	var generator := RepairRewardGenerator.new()
	generator.setup(inventory, 777)
	for _trial: int in range(20):
		var candidates := generator.generate_candidates(
			_all_definitions(), 3, true
		)
		_expect(not candidates.is_empty(), "첫 보상 후보는 비어 있으면 안 된다.")
		for part_id: StringName in candidates:
			_expect(not inventory.owns(part_id),
				"첫 보상 후보는 모두 미보유 부품이어야 한다.")


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
