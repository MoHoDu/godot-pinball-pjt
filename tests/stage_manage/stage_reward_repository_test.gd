extends SceneTree


const CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var repository := StageRewardRepository.new()
	root.add_child(repository)
	_expect(repository.is_stage_loaded(&"stage_01"),
		"Repository must load stage_01 CSV files on first tree entry.")

	var balls := repository.get_rewards(
		&"stage_01", StageRewardRepository.CATEGORY_BALL, &"wave_01"
	)
	var parts := repository.get_rewards(
		&"stage_01", StageRewardRepository.CATEGORY_PART, &"wave_01"
	)
	_expect(balls.size() == 5, "Stage 01 must load five reward balls.")
	_expect(parts.size() == 4, "Stage 01 must load four repair-part rewards.")

	var clockwork := repository.get_reward(
		&"stage_01", StageRewardRepository.CATEGORY_BALL, &"clockwork"
	)
	_expect(int(clockwork.get(&"price", 0)) == 13,
		"Clockwork price must come from reward_balls.csv.")
	_expect(is_equal_approx(float(clockwork.get(&"probability", 0.0)), 1.0),
		"Clockwork probability must come from reward_balls.csv.")
	_expect(not StageRewardRepository.is_available_in_wave(&"wave_02", &"wave_01") \
		and StageRewardRepository.is_available_in_wave(&"wave_02", &"wave_02") \
		and StageRewardRepository.is_available_in_wave(&"wave_02", &"boss_wave"),
		"First-wave filtering must preserve chronological availability.")
	var invalid_path := "user://stage_reward_invalid_wave.csv"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string(
		"reward_id,first_wave_id,probability,price\ninvalid,wave_04,1.0,9\n"
	)
	invalid_file.close()
	var invalid_result := StageRewardRepository.parse_csv_file(invalid_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	_expect(not bool(invalid_result.get(&"ok", true)),
		"Unsupported first_wave_id values must fail CSV validation.")

	var catalog := (CATALOG as RewardShopCatalog).duplicate(true) as RewardShopCatalog
	var clockwork_offer := _find_ball(catalog, &"clockwork")
	clockwork_offer.price = 999
	clockwork_offer.first_wave_id = &"wave_03"
	clockwork_offer.probability = 0.25
	_expect(repository.apply_to_catalog(&"stage_01", catalog),
		"Repository must apply loaded values to the reward catalog.")
	_expect(clockwork_offer.price == 13 \
		and clockwork_offer.first_wave_id == &"wave_01" \
		and is_equal_approx(clockwork_offer.probability, 1.0),
		"Catalog price, first wave, and probability must be overwritten by CSV.")
	var extra_offer := RewardBallOffer.new()
	extra_offer.ball_id = &"not_in_stage_csv"
	extra_offer.display_name = "CSV에서 제거된 공"
	extra_offer.price = 1
	catalog.ball_offers.append(extra_offer)
	_expect(repository.apply_to_catalog(&"stage_01", catalog) \
		and not _ball_ids(catalog.ball_offers).has(&"not_in_stage_csv"),
		"Catalog definitions omitted from CSV must be removed from the active list.")

	clockwork_offer.first_wave_id = &"wave_03"
	var generated := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new()
	)
	_expect(not _ball_ids(generated).has(&"clockwork"),
		"Offers must exclude rewards before their first appearance wave.")

	clockwork_offer.first_wave_id = &"boss_wave"
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer != clockwork_offer:
			offer.probability = 0.0
	var before_boss := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		1,
		RandomNumberGenerator.new()
	)
	var at_boss := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		2,
		RandomNumberGenerator.new()
	)
	_expect(not _ball_ids(before_boss).has(&"clockwork") \
		and _ball_ids(at_boss).has(&"clockwork"),
		"Boss-only rewards must first appear in the pre-boss reward.")

	clockwork_offer.first_wave_id = &"wave_01"
	clockwork_offer.probability = 0.0
	var disabled := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new()
	)
	_expect(not _ball_ids(disabled).has(&"clockwork"),
		"A zero probability must disable the reward.")

	repository.queue_free()
	_finish()


func _find_ball(
	catalog: RewardShopCatalog,
	ball_id: StringName
) -> RewardBallOffer:
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer != null and offer.ball_id == ball_id:
			return offer
	return null


func _ball_ids(offers: Array[RewardBallOffer]) -> Array[StringName]:
	var result: Array[StringName] = []
	for offer: RewardBallOffer in offers:
		result.append(offer.ball_id)
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: stage_reward_repository_test")
		quit(0)
		return
	print("FAIL: stage_reward_repository_test (%d failures)" % _failures.size())
	quit(1)
