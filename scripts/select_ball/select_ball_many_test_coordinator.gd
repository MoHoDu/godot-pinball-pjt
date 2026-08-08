class_name SelectBallManyTestCoordinator
extends SelectBallRuntimeCoordinator


const CLOCKWORK_BALL := preload(
	"res://Resources/Prefabs/balls/variants/reward/clockwork_ball.tscn"
)
const RUBBER_BALL := preload(
	"res://Resources/Prefabs/balls/variants/reward/rubber_ball.tscn"
)


func _ready() -> void:
	var inventory := wave_ball_inventory as SelectBallInventory
	if inventory != null:
		inventory.starting_stock.append(
			_make_stock(&"clockwork", "정속 태엽눈", CLOCKWORK_BALL)
		)
		inventory.starting_stock.append(
			_make_stock(&"rubber", "고무막 유리눈", RUBBER_BALL)
		)
		inventory.reset_stock()
	super()


func _make_stock(
	ball_id: StringName,
	display_name: String,
	prefab: PackedScene
) -> BallStock:
	var definition := SelectBallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name
	definition.ball_scene = prefab
	definition.feature_summary = "다섯 공 UI 표시 검사용 프리팹입니다."
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = 1
	return stock
