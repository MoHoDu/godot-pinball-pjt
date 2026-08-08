class_name SettingsPopupSfxPreview
extends SettingsPopup
## SFX 세부 음량을 조절한 뒤 실제 게임 규칙의 대표음을 짧게 미리 듣습니다.


const PREVIEW_DEBOUNCE_SECONDS := 0.15

const BALL_FLOW_RULES := preload(
	"res://settings/sfx/BallFlowSfxRules.tres"
)
const BUMPER_RULES := preload(
	"res://settings/sfx/BumperSfxRules.tres"
)
const FLIPPER_RULES := preload(
	"res://settings/sfx/FlipperSfxRules.tres"
)
const WALL_RULES := preload(
	"res://settings/sfx/WallSfxRules.tres"
)

const CATEGORY_BUSES := {
	&"ball": &"SFXBall",
	&"bumper": &"SFXBumper",
	&"flipper": &"SFXFlipper",
	&"wall": &"SFXWall",
}


@onready var _sfx_preview_player: AudioStreamPlayer = $SfxPreviewPlayer
@onready var _sfx_preview_debounce: Timer = $SfxPreviewDebounce

var _pending_preview_category := StringName()


func _ready() -> void:
	super()
	_sfx_preview_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_preview_debounce.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_preview_debounce.one_shot = true
	_sfx_preview_debounce.wait_time = PREVIEW_DEBOUNCE_SECONDS
	_sfx_preview_debounce.timeout.connect(_play_pending_sfx_preview)


func _on_volume_edited(category: StringName, value: float) -> void:
	super(category, value)
	_queue_sfx_preview(category, value)


func _queue_sfx_preview(category: StringName, value: float) -> void:
	if not CATEGORY_BUSES.has(category):
		return
	if value <= 0.0 or is_zero_approx(value):
		_pending_preview_category = &""
		_sfx_preview_debounce.stop()
		_stop_sfx_preview()
		return

	_pending_preview_category = category
	_sfx_preview_debounce.start(PREVIEW_DEBOUNCE_SECONDS)


func _play_pending_sfx_preview() -> void:
	var category := _pending_preview_category
	_pending_preview_category = &""
	if category.is_empty():
		return

	var preview_stream := _get_sfx_preview_stream(category)
	if preview_stream == null:
		return

	_sfx_preview_player.stop()
	_sfx_preview_player.bus = CATEGORY_BUSES[category]
	_sfx_preview_player.stream = preview_stream
	_sfx_preview_player.play()


func _get_sfx_preview_stream(category: StringName) -> AudioStream:
	var cue: SfxCue
	match category:
		&"ball":
			# 선택음은 짧아 슬라이더를 반복 조절할 때 흐름을 방해하지 않습니다.
			cue = BALL_FLOW_RULES.select_cue
		&"bumper":
			cue = BUMPER_RULES.button_cue
		&"flipper":
			cue = FLIPPER_RULES.activate_cue
		&"wall":
			cue = WALL_RULES.hit_cue
		_:
			return null

	if cue == null or cue.streams.is_empty():
		return null
	if category == &"wall" and cue.streams.size() >= 2:
		return cue.streams[1]
	return cue.streams[0]


func _stop_sfx_preview() -> void:
	_sfx_preview_player.stop()
	_sfx_preview_player.stream = null


func _complete_close() -> void:
	_sfx_preview_debounce.stop()
	_pending_preview_category = &""
	_stop_sfx_preview()
	super()
