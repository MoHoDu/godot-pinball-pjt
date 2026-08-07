class_name StageRewardRepository
extends Node


signal stage_loaded(stage_id: StringName)
signal stage_load_failed(stage_id: StringName, reason: String)


const DEFAULT_STAGE_ID: StringName = &"stage_01"
const CATEGORY_BALL: StringName = &"ball"
const CATEGORY_PART: StringName = &"part"
const REQUIRED_HEADERS := [
	"reward_id",
	"first_stage_num",
	"first_wave_num",
	"probability",
	"price",
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
	current_stage_num: int = -1,
	current_wave_num: int = -1
) -> Array[Dictionary]:
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return []
	var categories: Dictionary = _stage_records.get(stage_id, {})
	var records: Dictionary = categories.get(category, {})
	var result: Array[Dictionary] = []
	for reward_id: StringName in records:
		var record := (records[reward_id] as Dictionary).duplicate(true)
		if current_stage_num >= 1 and current_wave_num >= 1 \
				and not is_available_at(
			int(record[&"first_stage_num"]),
			int(record[&"first_wave_num"]),
			current_stage_num,
			current_wave_num
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
		var first_stage_text := row[1].strip_edges()
		var first_wave_text := row[2].strip_edges()
		var probability_text := row[3].strip_edges()
		var price_text := row[4].strip_edges()
		if reward_id_text.is_empty() \
				or first_stage_text.is_empty() \
				or first_wave_text.is_empty():
			return {
				&"ok": false,
				&"error": "%s:%d id 또는 최초 등장 위치가 비어 있습니다." \
					% [path, row_number],
			}
		if not first_stage_text.is_valid_int() or not first_wave_text.is_valid_int():
			return {
				&"ok": false,
				&"error": "%s:%d 최초 스테이지와 웨이브는 정수여야 합니다." \
					% [path, row_number],
			}
		if not probability_text.is_valid_float() or not price_text.is_valid_int():
			return {
				&"ok": false,
				&"error": "%s:%d 확률 또는 가격 형식이 올바르지 않습니다." % [path, row_number],
			}
		var first_stage_num := first_stage_text.to_int()
		var first_wave_num := first_wave_text.to_int()
		var probability := probability_text.to_float()
		var price := price_text.to_int()
		if first_stage_num < 1 or first_wave_num < 1 or first_wave_num > 4:
			return {
				&"ok": false,
				&"error": "%s:%d 최초 스테이지는 1 이상, 웨이브는 1~4여야 합니다." \
					% [path, row_number],
			}
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
			&"first_stage_num": first_stage_num,
			&"first_wave_num": first_wave_num,
			&"probability": probability,
			&"price": price,
		}
	return {&"ok": true, &"records": records}


static func is_available_at(
	first_stage_num: int,
	first_wave_num: int,
	current_stage_num: int,
	current_wave_num: int
) -> bool:
	if first_stage_num < 1 or first_wave_num < 1 or first_wave_num > 4 \
			or current_stage_num < 1 or current_wave_num < 1 \
			or current_wave_num > 4:
		return false
	return current_stage_num > first_stage_num \
		or (current_stage_num == first_stage_num \
			and current_wave_num >= first_wave_num)


static func stage_num_from_id(stage_id: StringName) -> int:
	var text := String(stage_id).strip_edges().to_lower()
	if not text.begins_with("stage_"):
		return -1
	var suffix := text.trim_prefix("stage_")
	var delimiter := suffix.find("_")
	if delimiter >= 0:
		suffix = suffix.left(delimiter)
	if not suffix.is_valid_int():
		return -1
	var stage_num := suffix.to_int()
	return stage_num if stage_num >= 1 else -1


static func _headers_match(headers: PackedStringArray) -> bool:
	if headers.size() != REQUIRED_HEADERS.size():
		return false
	for index in REQUIRED_HEADERS.size():
		if headers[index] != String(REQUIRED_HEADERS[index]):
			return false
	return true


static func _database_path(stage_id: String, file_name: String) -> String:
	return "res://Resources/stage/%s/%s" % [stage_id, file_name]


static func _apply_record(offer: Resource, record: Dictionary) -> void:
	offer.set(&"first_stage_num", record[&"first_stage_num"])
	offer.set(&"first_wave_num", record[&"first_wave_num"])
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
