extends SceneTree


const SETTINGS_SCRIPT := preload(
	"res://scripts/settings/game_settings_service.gd"
)
const EPSILON := 0.001

var _failures: Array[String] = []
var _config_path := "res://.godot/settings_service_test_%d.cfg" % Time.get_ticks_usec()
var _original_bus_state: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_capture_bus_state()
	_test_default_values_and_buses()
	_test_clamping_and_persistence()
	_test_reset()
	_restore_bus_state()
	_cleanup_config()
	_finish()


func _test_default_values_and_buses() -> void:
	var service: Variant = _create_service()
	_expect(service.load_settings() == OK, "설정 파일이 없어도 기본값을 불러와야 한다.")
	_expect(service.get_volume_percent(&"master") == 100,
		"마스터 기본 음량은 100%여야 한다.")
	_expect(service.get_volume_percent(&"bgm") == 70,
		"BGM 기본 음량은 70%여야 한다.")
	_expect(service.get_volume_percent(&"sfx") == 80,
		"SFX 기본 음량은 80%여야 한다.")
	for category: StringName in service.get_supported_categories():
		var bus_name: StringName = service.get_audio_bus_name(category)
		_expect(AudioServer.get_bus_index(bus_name) >= 0,
			"%s 범주의 오디오 버스가 존재해야 한다." % category)
	service.queue_free()


func _test_clamping_and_persistence() -> void:
	var service: Variant = _create_service()
	service.load_settings()
	service.set_volume(&"master", 0.5, false)
	_expect(service.set_volume(&"master", 1.8, false),
		"마스터 음량 변경을 적용해야 한다.")
	_expect(is_equal_approx(service.get_volume(&"master"), 1.0),
		"마스터 음량은 100%로 제한되어야 한다.")
	_expect(service.set_volume(&"bgm", -0.5, false),
		"BGM 음소거 변경을 적용해야 한다.")
	_expect(is_zero_approx(service.get_volume(&"bgm")),
		"BGM 음량은 0%로 제한되어야 한다.")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"BGM")),
		"0% BGM은 해당 버스를 음소거해야 한다.")
	service.set_volume(&"ball", 0.42, false)
	_expect(service.save_settings() == OK, "변경한 설정을 파일에 저장해야 한다.")
	service.queue_free()

	var loaded: Variant = _create_service()
	_expect(loaded.load_settings() == OK, "저장된 설정을 다시 불러와야 한다.")
	_expect(is_equal_approx(loaded.get_volume(&"ball"), 0.42),
		"저장된 공 사운드 음량을 복원해야 한다.")
	_expect(is_zero_approx(loaded.get_volume(&"bgm")),
		"저장된 BGM 음소거 상태를 복원해야 한다.")
	loaded.queue_free()


func _test_reset() -> void:
	var service: Variant = _create_service()
	service.load_settings()
	service.reset_to_defaults(false)
	_expect(service.get_volume_percent(&"master") == 100,
		"초기화 시 마스터 음량을 100%로 복원해야 한다.")
	_expect(service.get_volume_percent(&"bgm") == 70,
		"초기화 시 BGM 음량을 70%로 복원해야 한다.")
	_expect(service.get_volume_percent(&"wall") == 80,
		"초기화 시 벽 사운드 음량을 80%로 복원해야 한다.")
	service.queue_free()


func _create_service() -> Variant:
	var service: Variant = SETTINGS_SCRIPT.new()
	service.auto_load_on_ready = false
	service.config_path = _config_path
	root.add_child(service)
	return service


func _capture_bus_state() -> void:
	for bus_name: StringName in [
		&"Master", &"BGM", &"SFX", &"SFXBall", &"SFXBumper", &"SFXFlipper", &"SFXWall"
	]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			_original_bus_state[bus_name] = {
				&"volume_db": AudioServer.get_bus_volume_db(index),
				&"mute": AudioServer.is_bus_mute(index),
			}


func _restore_bus_state() -> void:
	for bus_name: StringName in _original_bus_state:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var state: Dictionary = _original_bus_state[bus_name]
		AudioServer.set_bus_volume_db(index, float(state[&"volume_db"]))
		AudioServer.set_bus_mute(index, bool(state[&"mute"]))


func _cleanup_config() -> void:
	if FileAccess.file_exists(_config_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_config_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: game_settings_service_test")
		quit(0)
		return
	for failure: String in _failures:
		print("FAIL: ", failure)
	print("FAIL: game_settings_service_test (%d failures)" % _failures.size())
	quit(1)
