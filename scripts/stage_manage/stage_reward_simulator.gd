@tool
class_name StageRewardSimulator
extends RefCounted


const DEFAULT_ITERATIONS := 100000
const DEFAULT_SEED := 20260807
const DEFAULT_WALLET_BALANCE := 18
const NORMAL_WAVE_COUNT := 3
const REPORT_HEADERS := [
	"stage_num",
	"wave_num",
	"category",
	"reward_id",
	"weight",
	"appearance_count",
	"appearance_rate",
]


static func simulate_and_save(
	stage_id: StringName,
	source_catalog: RewardShopCatalog,
	iterations: int = DEFAULT_ITERATIONS,
	seed: int = DEFAULT_SEED,
	wallet_balance: int = DEFAULT_WALLET_BALANCE,
	output_path: String = ""
) -> Dictionary:
	if source_catalog == null or iterations < 1:
		return {&"ok": false, &"error": "카탈로그와 반복 횟수를 확인해 주세요."}
	var stage_num := StageRewardRepository.stage_num_from_id(stage_id)
	if stage_num < 1:
		return {&"ok": false, &"error": "스테이지 ID 형식이 올바르지 않습니다: %s" % stage_id}
	var catalog := source_catalog.duplicate(true) as RewardShopCatalog
	var repository := StageRewardRepository.new()
	if not repository.apply_to_catalog(stage_id, catalog):
		repository.free()
		return {&"ok": false, &"error": "스테이지 보상 DB를 카탈로그에 적용하지 못했습니다."}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rows: Array[Dictionary] = []
	for wave_num in range(1, NORMAL_WAVE_COUNT + 1):
		repository.apply_context_weights(stage_id, catalog, stage_num, wave_num)
		var ball_counts := _empty_ball_counts(catalog)
		var part_counts := _empty_part_counts(catalog)
		for _iteration in iterations:
			var balls := RewardOfferGenerator.generate_ball_offers(
				catalog, [], wave_num - 1, rng, stage_num
			)
			var parts := RewardOfferGenerator.generate_part_offers(
				catalog, wave_num - 1, rng, [], stage_num
			)
			RewardOfferGenerator.ensure_affordable_pair(
				balls, parts, catalog, [], wallet_balance, wave_num - 1, stage_num
			)
			for offer: RewardBallOffer in balls:
				ball_counts[offer.ball_id] = int(ball_counts.get(offer.ball_id, 0)) + 1
			for offer: RepairPartOffer in parts:
				part_counts[offer.part_id] = int(part_counts.get(offer.part_id, 0)) + 1
		_append_ball_rows(rows, catalog, stage_num, wave_num, iterations, ball_counts)
		_append_part_rows(rows, catalog, stage_num, wave_num, iterations, part_counts)
	repository.free()
	var report_path := output_path
	if report_path.is_empty():
		report_path = "res://Resources/stage/%s/reward_simulation.csv" % stage_id
	var save_result := save_report(report_path, rows)
	if not bool(save_result.get(&"ok", false)):
		return save_result
	return {
		&"ok": true,
		&"path": report_path,
		&"rows": rows,
		&"iterations": iterations,
		&"seed": seed,
		&"wallet_balance": wallet_balance,
	}


static func save_report(path: String, rows: Array[Dictionary]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {&"ok": false, &"error": "시뮬레이션 CSV를 저장할 수 없습니다: %s" % path}
	file.store_csv_line(PackedStringArray(REPORT_HEADERS))
	for row: Dictionary in rows:
		file.store_csv_line(PackedStringArray([
			str(row[&"stage_num"]),
			str(row[&"wave_num"]),
			String(row[&"category"]),
			String(row[&"reward_id"]),
			"%.2f" % float(row[&"weight"]),
			str(row[&"appearance_count"]),
			"%.6f" % float(row[&"appearance_rate"]),
		]))
	file.close()
	return {&"ok": true}


static func _empty_ball_counts(catalog: RewardShopCatalog) -> Dictionary:
	var counts: Dictionary = {}
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer != null:
			counts[offer.ball_id] = 0
	return counts


static func _empty_part_counts(catalog: RewardShopCatalog) -> Dictionary:
	var counts: Dictionary = {}
	for offer: RepairPartOffer in catalog.part_offers:
		if offer != null:
			counts[offer.part_id] = 0
	return counts


static func _append_ball_rows(
	rows: Array[Dictionary],
	catalog: RewardShopCatalog,
	stage_num: int,
	wave_num: int,
	iterations: int,
	counts: Dictionary
) -> void:
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer == null:
			continue
		var count := int(counts.get(offer.ball_id, 0))
		rows.append(_report_row(
			stage_num, wave_num, StageRewardRepository.CATEGORY_BALL,
			offer.ball_id, offer.weight, count, iterations
		))


static func _append_part_rows(
	rows: Array[Dictionary],
	catalog: RewardShopCatalog,
	stage_num: int,
	wave_num: int,
	iterations: int,
	counts: Dictionary
) -> void:
	for offer: RepairPartOffer in catalog.part_offers:
		if offer == null:
			continue
		var count := int(counts.get(offer.part_id, 0))
		rows.append(_report_row(
			stage_num, wave_num, StageRewardRepository.CATEGORY_PART,
			offer.part_id, offer.weight, count, iterations
		))


static func _report_row(
	stage_num: int,
	wave_num: int,
	category: StringName,
	reward_id: StringName,
	weight: float,
	count: int,
	iterations: int
) -> Dictionary:
	return {
		&"stage_num": stage_num,
		&"wave_num": wave_num,
		&"category": category,
		&"reward_id": reward_id,
		&"weight": weight,
		&"appearance_count": count,
		&"appearance_rate": float(count) / float(iterations),
	}
