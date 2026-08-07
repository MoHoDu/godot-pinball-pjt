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
		&"stage_01", StageRewardRepository.CATEGORY_BALL, 1, 1
	)
	var parts := repository.get_rewards(
		&"stage_01", StageRewardRepository.CATEGORY_PART, 1, 1
	)
	_expect(balls.size() == 5, "Stage 01 must load five reward balls.")
	_expect(parts.size() == 4, "Stage 01 must load four repair-part rewards.")

	var clockwork := repository.get_reward(
		&"stage_01", StageRewardRepository.CATEGORY_BALL, &"clockwork"
	)
	_expect(int(clockwork.get(&"price", 0)) == 13,
		"Clockwork price must come from reward_balls.csv.")
	_expect(is_equal_approx(float(clockwork.get(&"weight", 0.0)), 1.0),
		"Clockwork weight must come from reward_balls.csv.")
	_expect(String(clockwork.get(&"display_name", "")) == "정속 태엽눈" \
		and int(clockwork.get(&"performance_group", -1)) \
			== RewardBallOffer.PerformanceGroup.GOOD \
		and bool(clockwork.get(&"enabled", false)),
		"Display name, performance group, and enabled must come from CSV.")
	_expect(int(clockwork.get(&"first_stage_num", 0)) == 1 \
		and int(clockwork.get(&"first_wave_num", 0)) == 1,
		"Clockwork first stage and wave must come from reward_balls.csv.")
	_expect(not StageRewardRepository.is_available_at(1, 2, 1, 1) \
		and StageRewardRepository.is_available_at(1, 2, 1, 2) \
		and StageRewardRepository.is_available_at(1, 4, 2, 1),
		"Stage and wave filtering must preserve chronological availability.")
	_expect(StageRewardRepository.stage_num_from_id(&"stage_01") == 1 \
		and StageRewardRepository.stage_num_from_id(&"stage_12_bonus") == 12 \
		and StageRewardRepository.stage_num_from_id(&"invalid") == -1,
		"Stage folder IDs must resolve to their one-based numeric stage.")
	var invalid_path := "user://stage_reward_invalid_wave.csv"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string(
		"reward_id,display_name,performance_group,first_stage_num," \
			+ "first_wave_num,weight,price,enabled\n" \
			+ "invalid,잘못된 공,GOOD,0,1,1.0,9,TRUE\n"
	)
	invalid_file.close()
	var invalid_result := StageRewardRepository.parse_reward_csv_file(
		invalid_path, StageRewardRepository.CATEGORY_BALL
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	_expect(not bool(invalid_result.get(&"ok", true)),
		"Stage and wave values below one must fail CSV validation.")
	var invalid_late_path := "user://stage_reward_invalid_late_wave.csv"
	var invalid_late_file := FileAccess.open(invalid_late_path, FileAccess.WRITE)
	invalid_late_file.store_string(
		"reward_id,display_name,performance_group,first_stage_num," \
			+ "first_wave_num,weight,price,enabled\n" \
			+ "invalid,늦은 공,GOOD,1,5,1.0,9,TRUE\n"
	)
	invalid_late_file.close()
	var invalid_late_result := StageRewardRepository.parse_reward_csv_file(
		invalid_late_path, StageRewardRepository.CATEGORY_BALL
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_late_path))
	_expect(not bool(invalid_late_result.get(&"ok", true)),
		"Wave values above the four-wave stage must fail CSV validation.")

	var catalog := (CATALOG as RewardShopCatalog).duplicate(true) as RewardShopCatalog
	var clockwork_offer := _find_ball(catalog, &"clockwork")
	clockwork_offer.price = 999
	clockwork_offer.first_stage_num = 3
	clockwork_offer.first_wave_num = 3
	clockwork_offer.weight = 0.25
	clockwork_offer.display_name = "덮어쓰기 전"
	_expect(repository.apply_to_catalog(&"stage_01", catalog),
		"Repository must apply loaded values to the reward catalog.")
	_expect(clockwork_offer.price == 13 \
		and clockwork_offer.first_stage_num == 1 \
		and clockwork_offer.first_wave_num == 1 \
		and clockwork_offer.display_name == "정속 태엽눈" \
		and is_equal_approx(clockwork_offer.weight, 1.0),
		"Catalog display, price, stage/wave, and weight must be overwritten by CSV.")
	var extra_offer := RewardBallOffer.new()
	extra_offer.ball_id = &"not_in_stage_csv"
	extra_offer.display_name = "CSV에서 제거된 공"
	extra_offer.price = 1
	catalog.ball_offers.append(extra_offer)
	_expect(repository.apply_to_catalog(&"stage_01", catalog) \
		and not _ball_ids(catalog.ball_offers).has(&"not_in_stage_csv"),
		"Catalog definitions omitted from CSV must be removed from the active list.")

	clockwork_offer.first_stage_num = 1
	clockwork_offer.first_wave_num = 3
	var generated := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new()
	)
	_expect(not _ball_ids(generated).has(&"clockwork"),
		"Offers must exclude rewards before their first appearance wave.")

	clockwork_offer.first_stage_num = 2
	clockwork_offer.first_wave_num = 1
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer != clockwork_offer:
			offer.weight = 0.0
	var before_stage := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new(),
		1
	)
	var at_stage := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new(),
		2
	)
	_expect(not _ball_ids(before_stage).has(&"clockwork") \
		and _ball_ids(at_stage).has(&"clockwork"),
		"Offers must first appear at their configured stage and wave.")

	clockwork_offer.first_stage_num = 1
	clockwork_offer.first_wave_num = 3
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
		"Pre-boss rewards must first appear after clearing normal wave three.")

	clockwork_offer.first_wave_num = 1
	clockwork_offer.weight = 0.0
	var disabled := RewardOfferGenerator.generate_ball_offers(
		catalog,
		[],
		0,
		RandomNumberGenerator.new()
	)
	_expect(not _ball_ids(disabled).has(&"clockwork"),
		"A zero weight must disable the reward.")

	var override_path := "user://stage_reward_override.csv"
	var override_file := FileAccess.open(override_path, FileAccess.WRITE)
	override_file.store_string(
		"stage_num,wave_num,reward_id,weight\n1,2,clockwork,7.5\n"
	)
	override_file.close()
	var override_result := StageRewardRepository.parse_override_csv_file(override_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path))
	_expect(bool(override_result.get(&"ok", false)) \
		and is_equal_approx(float(
			(override_result[&"records"] as Dictionary)["1:2:clockwork"][&"weight"]
		), 7.5),
		"Wave-specific weights must parse from reward_weight_overrides.csv.")
	if bool(override_result.get(&"ok", false)):
		repository._stage_overrides[&"stage_01"] = override_result[&"records"]
		_expect(repository.apply_context_weights(&"stage_01", catalog, 1, 2) \
			and is_equal_approx(clockwork_offer.weight, 7.5),
			"Wave-specific weights must override the catalog at that checkpoint.")
		_expect(repository.apply_context_weights(&"stage_01", catalog, 1, 1) \
			and is_equal_approx(clockwork_offer.weight, 1.0),
			"Base weight must return when no checkpoint override exists.")

	var disabled_catalog := (CATALOG as RewardShopCatalog).duplicate(true) \
		as RewardShopCatalog
	var stage_categories: Dictionary = repository._stage_records[&"stage_01"]
	var ball_records: Dictionary = stage_categories[StageRewardRepository.CATEGORY_BALL]
	var disabled_record := (ball_records[&"clockwork"] as Dictionary).duplicate(true)
	disabled_record[&"enabled"] = false
	ball_records[&"clockwork"] = disabled_record
	_expect(repository.apply_to_catalog(&"stage_01", disabled_catalog) \
		and not _ball_ids(disabled_catalog.ball_offers).has(&"clockwork"),
		"An enabled=FALSE row must be removed from the active reward catalog.")

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
