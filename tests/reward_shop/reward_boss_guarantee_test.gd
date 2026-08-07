extends SceneTree


## 보스 직전 보상 보장(기획서 6-2)을 검증합니다.
## 보유 부품과 결합해 보스전에서 실제로 쓸 수 있는 카드가
## 후보 3장에 최소 1장 있어야 합니다.


const CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_test_catalog_partner_kinds()
	_test_usable_judgement()
	_test_boss_reward_guarantee()
	_finish()


## 카탈로그의 연결 요구 수치가 8-3 효과와 맞는지 확인합니다.
func _test_catalog_partner_kinds() -> void:
	var by_id := {}
	for offer in (CATALOG as RewardShopCatalog).part_offers:
		by_id[offer.part_id] = offer.required_partner_kinds
	_expect(
		by_id.get(&"starlight_brooch", -1) == 2,
		"별빛 브로치는 다른 부품 2종이 필요해야 한다."
	)
	_expect(
		not by_id.has(&"crescent_needle"),
		"v0.3에서 삭제된 초승달 바늘은 부품 카드에 남아 있으면 안 된다."
	)
	_expect(
		by_id.get(&"golden_gears", -1) == 0
			and by_id.get(&"forgotten_star_bell", -1) == 0,
		"단독형 부품은 연결 요구가 0이어야 한다."
	)


## 보스전 사용 가능 판정 자체를 검증합니다.
func _test_usable_judgement() -> void:
	var catalog := CATALOG as RewardShopCatalog
	var brooch: RepairPartOffer
	var gears: RepairPartOffer
	for offer in catalog.part_offers:
		match offer.part_id:
			&"starlight_brooch": brooch = offer
			&"golden_gears": gears = offer
	var none: Array[StringName] = []
	var one: Array[StringName] = [&"golden_gears"]
	var two: Array[StringName] = [&"golden_gears", &"forgotten_star_bell"]
	_expect(
		RewardOfferGenerator._offer_boss_usable(gears, none),
		"단독형은 보유 부품이 없어도 사용 가능해야 한다."
	)
	_expect(
		not RewardOfferGenerator._offer_boss_usable(brooch, one),
		"브로치는 다른 부품 1종만으로는 사용 불가여야 한다."
	)
	_expect(
		RewardOfferGenerator._offer_boss_usable(brooch, two),
		"브로치는 다른 부품 2종이 있으면 사용 가능해야 한다."
	)


## 연결형 위주의 합성 카탈로그로도 보장이 강제되는지 확인합니다.
func _test_boss_reward_guarantee() -> void:
	var catalog := RewardShopCatalog.new()
	var offers: Array[RepairPartOffer] = []
	offers.append(_make_part(&"solo", true, 0))
	for part_index in 3:
		offers.append(
			_make_part(StringName("linked_%d" % part_index), false, 1)
		)
	catalog.part_offers = offers

	var none: Array[StringName] = []
	for seed_value in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260805 + seed_value
		var picked := RewardOfferGenerator.generate_part_offers(
			catalog, RewardOfferGenerator.BOSS_REWARD_INDEX, rng, none
		)
		_expect(picked.size() == 3, "후보는 3장이어야 한다.")
		_expect(
			RewardOfferGenerator._has_boss_usable(picked, none),
			"보스 직전 보상에는 사용 가능한 카드가 1장 이상이어야 한다. (seed %d)"
			% seed_value
		)


func _make_part(
	part_id: StringName,
	standalone: bool,
	partner_kinds: int
) -> RepairPartOffer:
	var offer := RepairPartOffer.new()
	offer.part_id = part_id
	offer.display_name = String(part_id)
	offer.bundle_count = 1
	offer.price = 9
	offer.works_standalone = standalone
	offer.needs_partner = not standalone
	offer.required_partner_kinds = partner_kinds
	return offer


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: reward_boss_guarantee_test")
		quit(0)
		return
	print("FAIL: reward_boss_guarantee_test (%d failures)" % _failures.size())
	quit(1)
