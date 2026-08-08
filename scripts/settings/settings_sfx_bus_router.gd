class_name SettingsSfxBusRouter
extends RefCounted
## 효과음 큐 이름을 세부 설정 버스로 분류합니다.


const DEFAULT_BUS: StringName = &"SFX"
const PREFIX_TO_BUS := {
	"ball_": &"SFXBall",
	"bumper_": &"SFXBumper",
	"flipper_": &"SFXFlipper",
	"wall_": &"SFXWall",
}


static func bus_for_cue(
	cue_id: StringName,
	fallback: StringName = DEFAULT_BUS
) -> StringName:
	var cue_name := String(cue_id)
	for prefix: String in PREFIX_TO_BUS:
		if cue_name.begins_with(prefix):
			return StringName(PREFIX_TO_BUS[prefix])
	return fallback
