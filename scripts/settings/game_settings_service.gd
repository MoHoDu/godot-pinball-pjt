class_name GameSettingsService
extends Node
## 사용자 설정의 저장과 오디오 버스 적용을 한 곳에서 관리합니다.


signal volume_changed(category: StringName, linear_volume: float)
signal settings_loaded
signal settings_reset


const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const MIN_AUDIBLE_LINEAR := 0.0001

const CATEGORY_MASTER: StringName = &"master"
const CATEGORY_BGM: StringName = &"bgm"
const CATEGORY_SFX: StringName = &"sfx"
const CATEGORY_BALL: StringName = &"ball"
const CATEGORY_BUMPER: StringName = &"bumper"
const CATEGORY_FLIPPER: StringName = &"flipper"
const CATEGORY_WALL: StringName = &"wall"

const AUDIO_CATEGORIES := [
	CATEGORY_MASTER,
	CATEGORY_BGM,
	CATEGORY_SFX,
	CATEGORY_BALL,
	CATEGORY_BUMPER,
	CATEGORY_FLIPPER,
	CATEGORY_WALL,
]

const CATEGORY_BUS := {
	CATEGORY_MASTER: &"Master",
	CATEGORY_BGM: &"BGM",
	CATEGORY_SFX: &"SFX",
	CATEGORY_BALL: &"SFXBall",
	CATEGORY_BUMPER: &"SFXBumper",
	CATEGORY_FLIPPER: &"SFXFlipper",
	CATEGORY_WALL: &"SFXWall",
}

const DEFAULT_VOLUMES := {
	CATEGORY_MASTER: 1.0,
	CATEGORY_BGM: 0.7,
	CATEGORY_SFX: 0.8,
	CATEGORY_BALL: 0.8,
	CATEGORY_BUMPER: 0.8,
	CATEGORY_FLIPPER: 0.8,
	CATEGORY_WALL: 0.8,
}


@export var auto_load_on_ready := true

var config_path := DEFAULT_CONFIG_PATH
var _volumes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if auto_load_on_ready:
		load_settings()


func load_settings() -> Error:
	_set_default_values()
	var config := ConfigFile.new()
	var error := config.load(config_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		_apply_all_audio_buses()
		return error

	if error == OK:
		for category: StringName in AUDIO_CATEGORIES:
			var fallback := float(DEFAULT_VOLUMES[category])
			_volumes[category] = clampf(
				float(config.get_value(AUDIO_SECTION, String(category), fallback)),
				0.0,
				1.0
			)

	_apply_all_audio_buses()
	settings_loaded.emit()
	return OK


func save_settings() -> Error:
	var config := ConfigFile.new()
	for category: StringName in AUDIO_CATEGORIES:
		config.set_value(
			AUDIO_SECTION,
			String(category),
			get_volume(category)
		)
	return config.save(config_path)


func get_volume(category: StringName) -> float:
	if not DEFAULT_VOLUMES.has(category):
		return 1.0
	return float(_volumes.get(category, DEFAULT_VOLUMES[category]))


func get_volume_percent(category: StringName) -> int:
	return roundi(get_volume(category) * 100.0)


func set_volume(
	category: StringName,
	linear_volume: float,
	save_immediately := true
) -> bool:
	if not DEFAULT_VOLUMES.has(category):
		return false
	var next_volume := clampf(linear_volume, 0.0, 1.0)
	if is_equal_approx(get_volume(category), next_volume):
		return false
	_volumes[category] = next_volume
	_apply_audio_bus(category)
	volume_changed.emit(category, next_volume)
	if save_immediately:
		save_settings()
	return true


func reset_to_defaults(save_immediately := true) -> void:
	_set_default_values()
	_apply_all_audio_buses()
	for category: StringName in AUDIO_CATEGORIES:
		volume_changed.emit(category, get_volume(category))
	if save_immediately:
		save_settings()
	settings_reset.emit()


func get_supported_categories() -> Array[StringName]:
	var categories: Array[StringName] = []
	for category: StringName in AUDIO_CATEGORIES:
		categories.append(category)
	return categories


func get_audio_bus_name(category: StringName) -> StringName:
	return StringName(CATEGORY_BUS.get(category, &""))


func _set_default_values() -> void:
	_volumes.clear()
	for category: StringName in AUDIO_CATEGORIES:
		_volumes[category] = float(DEFAULT_VOLUMES[category])


func _apply_all_audio_buses() -> void:
	for category: StringName in AUDIO_CATEGORIES:
		_apply_audio_bus(category)


func _apply_audio_bus(category: StringName) -> void:
	var bus_name := get_audio_bus_name(category)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("설정 오디오 버스를 찾을 수 없습니다: %s" % bus_name)
		return
	var linear_volume := get_volume(category)
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.0)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(maxf(linear_volume, MIN_AUDIBLE_LINEAR))
	)
