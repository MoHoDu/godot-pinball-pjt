@tool
class_name StageInitialBallEntry
extends Resource


## 스테이지 씬 Inspector에서 초기 보유 공 프리팹을 직접 구성하는 항목입니다.
@export var ball_id: StringName
@export var display_name := ""
@export var ball_prefab: PackedScene
@export_multiline var feature_summary := ""


func is_valid() -> bool:
	return not ball_id.is_empty() \
		and not display_name.strip_edges().is_empty() \
		and ball_prefab != null


func is_pinball_prefab() -> bool:
	if ball_prefab == null:
		return false
	var instance := ball_prefab.instantiate()
	var result := instance is Pinball
	instance.free()
	return result


func make_stock() -> BallStock:
	if not is_valid():
		return null
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = ball_prefab
	definition.feature_summary = feature_summary
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 1
	return stock
