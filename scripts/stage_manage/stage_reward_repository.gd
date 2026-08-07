class_name StageRewardRepository
extends Node


signal stage_loaded(stage_id: StringName)
signal stage_load_failed(stage_id: StringName, reason: String)


const DEFAULT_STAGE_ID: StringName = &"stage_01"
const CATEGORY_BALL: StringName = &"ball"
const CATEGORY_PART: StringName = &"part"
const REQUIRED_HEADERS := [
	"reward_id",
	"first_wave_id",
	"probability",
	"price",
]
const VALID_FIRST_WAVE_IDS := [
	&"wave_01",
	&"wave_02",
	&"wave_03",
	&"boss_wave",
]


var _stage_records: Dictionary = {}


func _ready() -> void:
	load_stage(DEFAULT_STAGE_ID)


func load_stage(stage_id: StringName) -> bool:
	var stage_key := String(stage_id)
	var categories := {
		CATEGORY_BALL: _database_path(stage_key, "reward_balls.csv"),
		CATEGORY_PART: _database_path(stage_key, "reward_parts.csv"),
	}
	var loaded_categories: Dictionary = {}
	for category: StringName in categories:
		var result := parse_csv_file(String(categories[category]))
		if not bool(result.get(&"ok", false)):
			var reason := String(result.get(&"error", "알 수 없는 CSV 오류"))
			stage_load_failed.emit(stage_id, reason)
			push_error("Stage reward database load failed: %s" % reason)
			return false
		loaded_categories[category] = result[&"records"]
	_stage_records[stage_id] = loaded_categories
	stage_loaded.emit(stage_id)
	return true


func reload_stage(stage_id: StringName = DEFAULT_STAGE_ID) -> bool:
	_stage_records.erase(stage_id)
	return load_stage(stage_id)


func is_stage_loaded(stage_id: StringName) -> bool:
	return _stage_records.has(stage_id)


func get_reward(
	stage_id: StringName,
	category: StringName,
	reward_id: StringName
) -> Dictionary:
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return {}
	var categories: Dictionary = _stage_records.get(stage_id, {})
	var records: Dictionary = categories.get(category, {})
	return (records.get(reward_id, {}) as Dictionary).duplicate(true)


func get_rewards(
	stage_id: StringName,
	category: StringName,
	wave_id: StringName = &""
) -> Array[Dictionary]:
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return []
	var categories: Dictionary = _stage_records.get(stage_id, {})
	var records: Dictionary = categories.get(category, {})
	var result: Array[Dictionary] = []
	for reward_id: StringName in records:
		var record := (records[reward_id] as Dictionary).duplicate(true)
		if wave_id != &"" and not is_available_in_wave(
			StringName(record[&"first_wave_id"]), wave_id
		):
			continue
		result.append(record)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left[&"reward_id"]) < String(right[&"reward_id"])
	)
	return result


func apply_to_catalog(
	stage_id: StringName,
	catalog: RewardShopCatalog
) -> bool:
	if catalog == null:
		return false
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return false
	var categories: Dictionary = _stage_records.get(stage_id, {})
	var ball_records: Dictionary = categories.get(CATEGORY_BALL, {})
	var part_records: Dictionary = categories.get(CATEGORY_PART, {})
	var ball_definitions: Dictionary = {}
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer == null:
			continue
		ball_definitions[offer.ball_id] = offer
	var part_definitions: Dictionary = {}
	for offer: RepairPartOffer in catalog.part_offers:
		if offer == null:
			continue
		part_definitions[offer.part_id] = offer
	if not _records_have_definitions(
		stage_id, CATEGORY_BALL, ball_records, ball_definitions
	) or not _records_have_definitions(
		stage_id, CATEGORY_PART, part_records, part_definitions
	):
		return false

	var enabled_balls: Array[RewardBallOffer] = []
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer == null or not ball_records.has(offer.ball_id):
			continue
		_apply_record(offer, ball_records[offer.ball_id])
		enabled_balls.append(offer)
	var enabled_parts: Array[RepairPartOffer] = []
	for offer: RepairPartOffer in catalog.part_offers:
		if offer == null or not part_records.has(offer.part_id):
			continue
		_apply_record(offer, part_records[offer.part_id])
		enabled_parts.append(offer)
	catalog.ball_offers = enabled_balls
	catalog.part_offers = enabled_parts
	return true


static func parse_csv_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			&"ok": false,
			&"error": "CSV 파일이 없습니다: %s" % path,
		}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			&"ok": false,
			&"error": "CSV 파일을 열 수 없습니다: %s" % path,
		}
	var headers := file.get_csv_line()
	if not headers.is_empty():
		headers[0] = headers[0].trim_prefix("\ufeff")
	if not _headers_match(headers):
		return {
			&"ok": false,
			&"error": "CSV 헤더가 올바르지 않습니다: %s" % path,
		}
	var records: Dictionary = {}
	var row_number := 1
	while not file.eof_reached():
		var row := file.get_csv_line()
		row_number += 1
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != REQUIRED_HEADERS.size():
			return {
				&"ok": false,
				&"error": "%s:%d 열 개수가 올바르지 않습니다." % [path, row_number],
			}
		var reward_id_text := row[0].strip_edges()
		var first_wave_text := row[1].strip_edges()
		var probability_text := row[2].strip_edges()
		var price_text := row[3].strip_edges()
		if reward_id_text.is_empty() or first_wave_text.is_empty():
			return {
				&"ok": false,
				&"error": "%s:%d id 또는 최초 웨이브가 비어 있습니다." % [path, row_number],
			}
		if not VALID_FIRST_WAVE_IDS.has(StringName(first_wave_text)):
			return {
				&"ok": false,
				&"error": "%s:%d 지원하지 않는 first_wave_id입니다: %s" \
					% [path, row_number, first_wave_text],
			}
		if not probability_text.is_valid_float() or not price_text.is_valid_int():
			return {
				&"ok": false,
				&"error": "%s:%d 확률 또는 가격 형식이 올바르지 않습니다." % [path, row_number],
			}
		var probability := probability_text.to_float()
		var price := price_text.to_int()
		if probability < 0.0 or price <= 0:
			return {
				&"ok": false,
				&"error": "%s:%d 확률은 0 이상, 가격은 1 이상이어야 합니다." % [path, row_number],
			}
		var reward_id := StringName(reward_id_text)
		if records.has(reward_id):
			return {
				&"ok": false,
				&"error": "%s:%d 중복 reward_id입니다: %s" % [path, row_number, reward_id],
			}
		records[reward_id] = {
			&"reward_id": reward_id,
			&"first_wave_id": StringName(first_wave_text),
			&"probability": probability,
			&"price": price,
		}
	return {&"ok": true, &"records": records}


static func is_available_in_wave(
	first_wave_id: StringName,
	current_wave_id: StringName
) -> bool:
	var first_order := _wave_order(first_wave_id)
	var current_order := _wave_order(current_wave_id)
	return first_order >= 0 and current_order >= first_order


static func _headers_match(headers: PackedStringArray) -> bool:
	if headers.size() != REQUIRED_HEADERS.size():
		return false
	for index in REQUIRED_HEADERS.size():
		if headers[index] != String(REQUIRED_HEADERS[index]):
			return false
	return true


static func _wave_order(wave_id: StringName) -> int:
	var text := String(wave_id).strip_edges().to_lower()
	if text == "boss_wave":
		return 999
	if not text.begins_with("wave_"):
		return -1
	var suffix := text.trim_prefix("wave_")
	return suffix.to_int() if suffix.is_valid_int() else -1


static func _database_path(stage_id: String, file_name: String) -> String:
	return "res://Resources/stage/%s/%s" % [stage_id, file_name]


static func _apply_record(offer: Resource, record: Dictionary) -> void:
	offer.set(&"first_wave_id", record[&"first_wave_id"])
	offer.set(&"probability", record[&"probability"])
	offer.set(&"price", record[&"price"])


static func _records_have_definitions(
	stage_id: StringName,
	category: StringName,
	records: Dictionary,
	definitions: Dictionary
) -> bool:
	for reward_id: StringName in records:
		if definitions.has(reward_id):
			continue
		push_error(
			"Stage %s %s CSV has no catalog definition for reward_id: %s"
			% [stage_id, category, reward_id]
		)
		return false
	return true
