class_name RewardBallSceneMap
extends Resource


## 상점의 공 ball_id를 실제 물리 씬에 잇는 표입니다.
##
## 보상 공 5종에는 아직 전용 물리 씬이 없어(1b 미착수) 기존 물리 씬으로
## 임시 매핑합니다. 전용 씬이 생기면 이 표만 바꾸면 됩니다.
##   정속 태엽눈(clockwork) → normal_ball  (임시. 대응 씬 미정)
##   고무막(rubber)         → rubber_ball
##   완충 젤(gel)           → dead_ball
##   납심(lead)             → heavy_ball
##   속빈 방울(hollow_bell) → light_ball


@export var display_names: Dictionary = {}

## ball_id(StringName) → PackedScene.
@export var scenes: Dictionary = {}


func has_ball(ball_id: StringName) -> bool:
	return scenes.has(ball_id) and scenes[ball_id] != null


func scene_of(ball_id: StringName) -> PackedScene:
	return scenes.get(ball_id, null) as PackedScene


func display_name_of(ball_id: StringName) -> String:
	return String(display_names.get(ball_id, String(ball_id)))


func make_definition(ball_id: StringName) -> BallDefinition:
	if not has_ball(ball_id):
		return null
	var definition := BallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = display_name_of(ball_id)
	definition.ball_scene = scene_of(ball_id)
	return definition
