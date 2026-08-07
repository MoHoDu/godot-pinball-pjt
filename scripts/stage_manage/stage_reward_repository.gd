class_name StageRewardRepository
extends Node


signal stage_loaded(stage_id: StringName)
signal stage_load_failed(stage_id: StringName, reason: String)


const DEFAULT_STAGE_ID: StringName = &"stage_01"
const CATEGORY_BALL: StringName = &"ball"
const CATEGORY_PART: StringName = &"part"
const BALL_HEADERS := [
	"reward_id",
	"display_name",
	"performance_group",
	"first_stage_num",
	"first_wave_num",
	"weight",
	"price",
	"enabled",
]
const PART_HEADERS := [
	"reward_id",
	"display_name",
	"first_stage_num",
	"first_wave_num",
	"weight",
	"price",
	"bundle_count",
	"works_standalone",
	"needs_partner",
	"required_partner_kinds",
	"enabled",
]
const OVERRIDE_HEADERS := [
	"stage_num",
	"wave_num",
	"reward_id",
	"weight",
]
const PERFORMANCE_GROUPS := {
	"GOOD": RewardBallOffer.PerformanceGroup.GOOD,
	"MID": RewardBallOffer.PerformanceGroup.MID,
	"HARDCORE": RewardBallOffer.PerformanceGroup.HARDCORE,
}


var _stage_records: Dictionary = {}
var _stage_overrides: Dictionary = {}


func _ready() -> void:
	load_stage(DEFAULT_STAGE_ID)


func load_stage(stage_id: StringName) -> bool:
	var stage_key := String(stage_id)
	var result := validate_database_files(
		_database_path(stage_key, "reward_balls.csv"),
		_database_path(stage_key, "reward_parts.csv"),
		_database_path(stage_key, "reward_weight_overrides.csv")
	)
	if not bool(result.get(&"ok", false)):
		return _report_load_failure(stage_id, result)
	var ball_records: Dictionary = result[&"ball_records"]
	var part_records: Dictionary = result[&"part_records"]
	var overrides: Dictionary = result[&"overrides"]
	_stage_records[stage_id] = {
		CATEGORY_BALL: ball_records,
		CATEGORY_PART: part_records,
	}
	_stage_overrides[stage_id] = overrides
	stage_loaded.emit(stage_id)
	return true


func reload_stage(stage_id: StringName = DEFAULT_STAGE_ID) -> bool:
	_stage_records.erase(stage_id)
	_stage_overrides.erase(stage_id)
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
		if not bool(record[&"enabled"]):
			continue
		if current_stage_num >= 1 and current_wave_num >= 1:
			if not is_available_at(
				int(record[&"first_stage_num"]),
				int(record[&"first_wave_num"]),
				current_stage_num,
				current_wave_num
			):
				continue
			record[&"weight"] = get_effective_weight(
				stage_id, reward_id, current_stage_num, current_wave_num
			)
		result.append(record)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left[&"reward_id"]) < String(right[&"reward_id"])
	)
	return result


func get_effective_weight(
	stage_id: StringName,
	reward_id: StringName,
	current_stage_num: int,
	current_wave_num: int
) -> float:
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return 0.0
	var override_key := _override_key(
		current_stage_num, current_wave_num, reward_id
	)
	var overrides: Dictionary = _stage_overrides.get(stage_id, {})
	if overrides.has(override_key):
		return float((overrides[override_key] as Dictionary)[&"weight"])
	var categories: Dictionary = _stage_records.get(stage_id, {})
	for category: StringName in [CATEGORY_BALL, CATEGORY_PART]:
		var records: Dictionary = categories.get(category, {})
		if records.has(reward_id):
			return float((records[reward_id] as Dictionary)[&"weight"])
	return 0.0


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
		if offer != null:
			ball_definitions[offer.ball_id] = offer
	var part_definitions: Dictionary = {}
	for offer: RepairPartOffer in catalog.part_offers:
		if offer != null:
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
		var record: Dictionary = ball_records[offer.ball_id]
		_apply_record(offer, record)
		if bool(record[&"enabled"]):
			enabled_balls.append(offer)
	var enabled_parts: Array[RepairPartOffer] = []
	for offer: RepairPartOffer in catalog.part_offers:
		if offer == null or not part_records.has(offer.part_id):
			continue
		var record: Dictionary = part_records[offer.part_id]
		_apply_record(offer, record)
		if bool(record[&"enabled"]):
			enabled_parts.append(offer)
	catalog.ball_offers = enabled_balls
	catalog.part_offers = enabled_parts
	return true


func apply_context_weights(
	stage_id: StringName,
	catalog: RewardShopCatalog,
	current_stage_num: int,
	current_wave_num: int
) -> bool:
	if catalog == null:
		return false
	if not is_stage_loaded(stage_id) and not load_stage(stage_id):
		return false
	for offer: RewardBallOffer in catalog.ball_offers:
		if offer != null:
			offer.weight = get_effective_weight(
				stage_id, offer.ball_id, current_stage_num, current_wave_num
			)
	for offer: RepairPartOffer in catalog.part_offers:
		if offer != null:
			offer.weight = get_effective_weight(
				stage_id, offer.part_id, current_stage_num, current_wave_num
			)
	return true


static func parse_reward_csv_file(
	path: String,
	category: StringName
) -> Dictionary:
	var expected_headers := BALL_HEADERS if category == CATEGORY_BALL else PART_HEADERS
	var read_result := _read_csv_rows(path, expected_headers)
	if not bool(read_result.get(&"ok", false)):
		return read_result
	var records: Dictionary = {}
	var row_number := 1
	for row: PackedStringArray in read_result[&"rows"]:
		row_number += 1
		var parsed := _parse_ball_row(path, row_number, row) \
			if category == CATEGORY_BALL \
			else _parse_part_row(path, row_number, row)
		if not bool(parsed.get(&"ok", false)):
			return parsed
		var record: Dictionary = parsed[&"record"]
		var reward_id: StringName = record[&"reward_id"]
		if records.has(reward_id):
			return _csv_error(path, row_number, "중복 reward_id입니다: %s" % reward_id)
		records[reward_id] = record
	return {&"ok": true, &"records": records}


static func parse_override_csv_file(path: String) -> Dictionary:
	var read_result := _read_csv_rows(path, OVERRIDE_HEADERS)
	if not bool(read_result.get(&"ok", false)):
		return read_result
	var records: Dictionary = {}
	var row_number := 1
	for row: PackedStringArray in read_result[&"rows"]:
		row_number += 1
		var stage_text := row[0].strip_edges()
		var wave_text := row[1].strip_edges()
		var reward_text := row[2].strip_edges()
		var weight_text := row[3].strip_edges()
		if not stage_text.is_valid_int() or not wave_text.is_valid_int() \
				or reward_text.is_empty() or not weight_text.is_valid_float():
			return _csv_error(path, row_number, "오버라이드 형식이 올바르지 않습니다.")
		var stage_num := stage_text.to_int()
		var wave_num := wave_text.to_int()
		var weight := weight_text.to_float()
		if stage_num < 1 or wave_num < 1 or wave_num > 4 or weight < 0.0:
			return _csv_error(
				path, row_number, "스테이지는 1 이상, 웨이브는 1~4, 가중치는 0 이상이어야 합니다."
			)
		var reward_id := StringName(reward_text)
		var key := _override_key(stage_num, wave_num, reward_id)
		if records.has(key):
			return _csv_error(path, row_number, "중복 가중치 오버라이드입니다: %s" % key)
		records[key] = {
			&"stage_num": stage_num,
			&"wave_num": wave_num,
			&"reward_id": reward_id,
			&"weight": weight,
		}
	return {&"ok": true, &"records": records}


static func validate_database_files(
	ball_path: String,
	part_path: String,
	override_path: String
) -> Dictionary:
	var ball_result := parse_reward_csv_file(ball_path, CATEGORY_BALL)
	if not bool(ball_result.get(&"ok", false)):
		return ball_result
	var part_result := parse_reward_csv_file(part_path, CATEGORY_PART)
	if not bool(part_result.get(&"ok", false)):
		return part_result
	var override_result := parse_override_csv_file(override_path)
	if not bool(override_result.get(&"ok", false)):
		return override_result
	var ball_records: Dictionary = ball_result[&"records"]
	var part_records: Dictionary = part_result[&"records"]
	for reward_id: StringName in ball_records:
		if part_records.has(reward_id):
			return {&"ok": false, &"error": "공과 부품에 중복 reward_id가 있습니다: %s" % reward_id}
	var known_ids: Dictionary = {}
	for reward_id: StringName in ball_records:
		known_ids[reward_id] = true
	for reward_id: StringName in part_records:
		known_ids[reward_id] = true
	var overrides: Dictionary = override_result[&"records"]
	for override_key: String in overrides:
		var record: Dictionary = overrides[override_key]
		if not known_ids.has(record[&"reward_id"]):
			return {
				&"ok": false,
				&"error": "가중치 오버라이드에 없는 reward_id가 있습니다: %s" \
					% record[&"reward_id"],
			}
	return {
		&"ok": true,
		&"ball_records": ball_records,
		&"part_records": part_records,
		&"overrides": overrides,
	}


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


static func _read_csv_rows(path: String, expected_headers: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {&"ok": false, &"error": "CSV 파일이 없습니다: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {&"ok": false, &"error": "CSV 파일을 열 수 없습니다: %s" % path}
	var headers := file.get_csv_line()
	if not headers.is_empty():
		headers[0] = headers[0].trim_prefix("\ufeff")
	if not _headers_match(headers, expected_headers):
		return {&"ok": false, &"error": "CSV 헤더가 올바르지 않습니다: %s" % path}
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != expected_headers.size():
			return _csv_error(path, rows.size() + 2, "열 개수가 올바르지 않습니다.")
		rows.append(row)
	return {&"ok": true, &"rows": rows}


static func _parse_ball_row(
	path: String,
	row_number: int,
	row: PackedStringArray
) -> Dictionary:
	var reward_id := row[0].strip_edges()
	var display_name := row[1].strip_edges()
	var group_text := row[2].strip_edges().to_upper()
	var common := _parse_common_fields(
		path, row_number, reward_id, display_name,
		row[3], row[4], row[5], row[6], row[7]
	)
	if not bool(common.get(&"ok", false)):
		return common
	if not PERFORMANCE_GROUPS.has(group_text):
		return _csv_error(path, row_number, "지원하지 않는 performance_group입니다: %s" % group_text)
	var record: Dictionary = common[&"record"]
	record[&"performance_group"] = int(PERFORMANCE_GROUPS[group_text])
	return {&"ok": true, &"record": record}


static func _parse_part_row(
	path: String,
	row_number: int,
	row: PackedStringArray
) -> Dictionary:
	var common := _parse_common_fields(
		path, row_number, row[0].strip_edges(), row[1].strip_edges(),
		row[2], row[3], row[4], row[5], row[10]
	)
	if not bool(common.get(&"ok", false)):
		return common
	var bundle_text := row[6].strip_edges()
	var required_text := row[9].strip_edges()
	var standalone_result := _parse_bool(row[7])
	var partner_result := _parse_bool(row[8])
	if not bundle_text.is_valid_int() or not required_text.is_valid_int() \
			or not bool(standalone_result.get(&"ok", false)) \
			or not bool(partner_result.get(&"ok", false)):
		return _csv_error(path, row_number, "부품 규칙 형식이 올바르지 않습니다.")
	var bundle_count := bundle_text.to_int()
	var required_partner_kinds := required_text.to_int()
	if bundle_count < 1 or required_partner_kinds < 0 or required_partner_kinds > 3:
		return _csv_error(path, row_number, "묶음은 1 이상, 필요 파트너 종류는 0~3이어야 합니다.")
	var record: Dictionary = common[&"record"]
	record[&"bundle_count"] = bundle_count
	record[&"works_standalone"] = bool(standalone_result[&"value"])
	record[&"needs_partner"] = bool(partner_result[&"value"])
	record[&"required_partner_kinds"] = required_partner_kinds
	return {&"ok": true, &"record": record}


static func _parse_common_fields(
	path: String,
	row_number: int,
	reward_id_text: String,
	display_name: String,
	first_stage_source: String,
	first_wave_source: String,
	weight_source: String,
	price_source: String,
	enabled_source: String
) -> Dictionary:
	var first_stage_text := first_stage_source.strip_edges()
	var first_wave_text := first_wave_source.strip_edges()
	var weight_text := weight_source.strip_edges()
	var price_text := price_source.strip_edges()
	var enabled_result := _parse_bool(enabled_source)
	if reward_id_text.is_empty() or display_name.is_empty():
		return _csv_error(path, row_number, "reward_id 또는 표시 이름이 비어 있습니다.")
	if not first_stage_text.is_valid_int() or not first_wave_text.is_valid_int():
		return _csv_error(path, row_number, "최초 스테이지와 웨이브는 정수여야 합니다.")
	if not weight_text.is_valid_float() or not price_text.is_valid_int() \
			or not bool(enabled_result.get(&"ok", false)):
		return _csv_error(path, row_number, "가중치, 가격 또는 enabled 형식이 올바르지 않습니다.")
	var first_stage_num := first_stage_text.to_int()
	var first_wave_num := first_wave_text.to_int()
	var weight := weight_text.to_float()
	var price := price_text.to_int()
	if first_stage_num < 1 or first_wave_num < 1 or first_wave_num > 4:
		return _csv_error(path, row_number, "최초 스테이지는 1 이상, 웨이브는 1~4여야 합니다.")
	if weight < 0.0 or price <= 0:
		return _csv_error(path, row_number, "가중치는 0 이상, 가격은 1 이상이어야 합니다.")
	return {
		&"ok": true,
		&"record": {
			&"reward_id": StringName(reward_id_text),
			&"display_name": display_name,
			&"first_stage_num": first_stage_num,
			&"first_wave_num": first_wave_num,
			&"weight": weight,
			&"price": price,
			&"enabled": bool(enabled_result[&"value"]),
		},
	}


static func _parse_bool(source: String) -> Dictionary:
	var text := source.strip_edges().to_lower()
	if text in ["true", "1"]:
		return {&"ok": true, &"value": true}
	if text in ["false", "0"]:
		return {&"ok": true, &"value": false}
	return {&"ok": false}


static func _headers_match(headers: PackedStringArray, expected: Array) -> bool:
	if headers.size() != expected.size():
		return false
	for index in expected.size():
		if headers[index] != String(expected[index]):
			return false
	return true


static func _override_key(
	stage_num: int,
	wave_num: int,
	reward_id: StringName
) -> String:
	return "%d:%d:%s" % [stage_num, wave_num, reward_id]


static func _database_path(stage_id: String, file_name: String) -> String:
	return "res://Resources/stage/%s/%s" % [stage_id, file_name]


static func _apply_record(offer: Resource, record: Dictionary) -> void:
	offer.set(&"display_name", record[&"display_name"])
	offer.set(&"first_stage_num", record[&"first_stage_num"])
	offer.set(&"first_wave_num", record[&"first_wave_num"])
	offer.set(&"weight", record[&"weight"])
	offer.set(&"price", record[&"price"])
	offer.set(&"enabled", record[&"enabled"])
	if offer is RewardBallOffer:
		offer.set(&"performance_group", record[&"performance_group"])
	elif offer is RepairPartOffer:
		offer.set(&"bundle_count", record[&"bundle_count"])
		offer.set(&"works_standalone", record[&"works_standalone"])
		offer.set(&"needs_partner", record[&"needs_partner"])
		offer.set(&"required_partner_kinds", record[&"required_partner_kinds"])


static func _records_have_definitions(
	stage_id: StringName,
	category: StringName,
	records: Dictionary,
	definitions: Dictionary
) -> bool:
	for reward_id: StringName in records:
		var record: Dictionary = records[reward_id]
		if not bool(record[&"enabled"]) or definitions.has(reward_id):
			continue
		push_error(
			"Stage %s %s CSV has no catalog definition for reward_id: %s"
			% [stage_id, category, reward_id]
		)
		return false
	return true


func _report_load_failure(stage_id: StringName, result: Dictionary) -> bool:
	var reason := String(result.get(&"error", "알 수 없는 CSV 오류"))
	stage_load_failed.emit(stage_id, reason)
	push_error("Stage reward database load failed: %s" % reason)
	return false


static func _csv_error(path: String, row_number: int, message: String) -> Dictionary:
	return {&"ok": false, &"error": "%s:%d %s" % [path, row_number, message]}
