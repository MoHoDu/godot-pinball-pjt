extends SceneTree


const POPUP_SCENE := preload(
	"res://Resources/Prefabs/ui/settings/settings_popup_sfx_preview.tscn"
)
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


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var popup: Variant = POPUP_SCENE.instantiate()
	root.add_child(popup)
	await process_frame

	var player := popup.get_node(^"SfxPreviewPlayer") as AudioStreamPlayer
	var debounce := popup.get_node(^"SfxPreviewDebounce") as Timer
	_expect(player != null, "미리듣기는 AudioStreamPlayer 하나를 가져야 한다.")
	_expect(debounce != null, "미리듣기는 디바운스 Timer 하나를 가져야 한다.")
	if player == null or debounce == null:
		popup.queue_free()
		await process_frame
		_finish()
		return

	_expect(player.process_mode == Node.PROCESS_MODE_ALWAYS,
		"미리듣기 플레이어는 일시정지 중에도 처리되어야 한다.")
	_expect(debounce.process_mode == Node.PROCESS_MODE_ALWAYS,
		"미리듣기 타이머는 일시정지 중에도 처리되어야 한다.")
	_expect(debounce.one_shot and is_equal_approx(debounce.wait_time, 0.15),
		"미리듣기는 150ms 단발 디바운스를 사용해야 한다.")

	_test_volume_row_integration(popup, debounce)
	_test_representative_streams(popup)
	_test_ball_bus(popup, player)
	await _test_debounce_restarts(popup, player)
	await _test_preview_while_paused(popup, player)
	_test_zero_stops_preview(popup, player, debounce)

	popup.queue_free()
	await process_frame
	_finish()


func _test_volume_row_integration(popup: Variant, debounce: Timer) -> void:
	# 사용자 설정 파일을 쓰지 않고, 실제 행의 시그널이 확장 콜백에 연결됐는지만 봅니다.
	popup.set(&"_settings_service", null)
	var ball_row: Node = popup.find_child("BallVolumeRow", true, false)
	_expect(ball_row != null, "공 SFX 음량 행을 찾을 수 있어야 한다.")
	if ball_row == null:
		return
	ball_row.emit_signal(&"volume_edited", &"ball", 0.45)
	_expect(not debounce.is_stopped(),
		"공 SFX 행을 조절하면 실제 150ms 미리듣기 예약이 시작되어야 한다.")
	debounce.stop()


func _test_representative_streams(popup: Variant) -> void:
	_expect(
		popup.call(&"_get_sfx_preview_stream", &"ball")
			== BALL_FLOW_RULES.select_cue.streams[0],
		"공 미리듣기는 실제 공 선택 규칙의 대표음을 사용해야 한다."
	)
	_expect(
		popup.call(&"_get_sfx_preview_stream", &"bumper")
			== BUMPER_RULES.button_cue.streams[0],
		"범퍼 미리듣기는 실제 단추 범퍼 규칙의 대표음을 사용해야 한다."
	)
	_expect(
		popup.call(&"_get_sfx_preview_stream", &"flipper")
			== FLIPPER_RULES.activate_cue.streams[0],
		"플리퍼 미리듣기는 실제 작동 규칙의 대표음을 사용해야 한다."
	)
	_expect(
		popup.call(&"_get_sfx_preview_stream", &"wall")
			== WALL_RULES.hit_cue.streams[1],
		"벽 미리듣기는 실제 중간 속도 충돌음을 사용해야 한다."
	)


func _test_ball_bus(popup: Variant, player: AudioStreamPlayer) -> void:
	popup.call(&"_queue_sfx_preview", &"ball", 0.5)
	popup.call(&"_play_pending_sfx_preview")
	_expect(player.stream == BALL_FLOW_RULES.select_cue.streams[0] \
		and player.bus == &"SFXBall",
		"공 대표음은 실제 SFXBall 버스로 재생 준비되어야 한다.")
	popup.call(&"_stop_sfx_preview")


func _test_debounce_restarts(
	popup: Variant,
	player: AudioStreamPlayer
) -> void:
	popup.call(&"_queue_sfx_preview", &"ball", 0.4)
	await create_timer(0.08, true).timeout
	popup.call(&"_queue_sfx_preview", &"bumper", 0.6)
	await create_timer(0.09, true).timeout
	_expect(player.stream == null,
		"연속 조절 중에는 앞선 150ms 예약음을 재생하면 안 된다.")
	await create_timer(0.08, true).timeout
	_expect(player.stream == BUMPER_RULES.button_cue.streams[0],
		"마지막으로 조절한 범퍼 대표음만 재생해야 한다.")
	_expect(player.bus == &"SFXBumper",
		"범퍼 미리듣기는 실제 SFXBumper 버스를 거쳐야 한다.")


func _test_preview_while_paused(
	popup: Variant,
	player: AudioStreamPlayer
) -> void:
	popup.call(&"_stop_sfx_preview")
	paused = true
	popup.call(&"_queue_sfx_preview", &"flipper", 0.7)
	await create_timer(0.18, true).timeout
	_expect(player.stream == FLIPPER_RULES.activate_cue.streams[0],
		"게임 일시정지 중에도 플리퍼 대표음을 준비해야 한다.")
	_expect(player.bus == &"SFXFlipper",
		"플리퍼 미리듣기는 실제 SFXFlipper 버스를 거쳐야 한다.")
	paused = false


func _test_zero_stops_preview(
	popup: Variant,
	player: AudioStreamPlayer,
	debounce: Timer
) -> void:
	popup.call(&"_queue_sfx_preview", &"wall", 0.5)
	popup.call(&"_play_pending_sfx_preview")
	_expect(player.stream == WALL_RULES.hit_cue.streams[1]
		and player.bus == &"SFXWall",
		"벽 대표음은 실제 SFXWall 버스로 재생 준비되어야 한다.")
	popup.call(&"_queue_sfx_preview", &"wall", 0.0)
	_expect(player.stream == null and not player.playing and debounce.is_stopped(),
		"0%로 바꾸면 예약과 현재 미리듣기를 즉시 중지해야 한다.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: settings_sfx_preview_test")
		quit(0)
		return
	print("FAIL: settings_sfx_preview_test (%d failures)" % _failures.size())
	quit(1)
