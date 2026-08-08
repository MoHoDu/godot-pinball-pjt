extends SceneTree


const RESOURCE_ROOTS := [
	"res://Resources",
	"res://scenes",
	"res://settings",
	"res://tests",
	"res://integration",
]
const SOURCE_ROOTS := [
	"res://scripts",
	"res://integration",
]


var _failures := 0
var _literal_pattern := RegEx.new()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_literal_pattern.compile("[\\\"'](res://[^\\\"'\\r\\n]+)[\\\"']")
	_test_serialized_resources()
	_test_source_path_literals()
	_test_scene_roles()
	if _failures == 0:
		print("PASS: resource_dependency_test")
		quit(0)
		return
	print("FAIL: resource_dependency_test (%d failures)" % _failures)
	quit(1)


func _test_serialized_resources() -> void:
	for root_path: String in RESOURCE_ROOTS:
		for path: String in _collect_files(root_path, [&"tscn", &"tres"]):
			_expect(ResourceLoader.exists(path), "리소스를 인식해야 합니다: %s" % path)
			var source := FileAccess.get_file_as_string(path)
			for result: RegExMatch in _literal_pattern.search_all(source):
				_check_literal_path(result.get_string(1), path)
			var resource := ResourceLoader.load(path)
			_expect(resource != null, "리소스를 로드해야 합니다: %s" % path)


func _test_source_path_literals() -> void:
	for root_path: String in SOURCE_ROOTS:
		for path: String in _collect_files(root_path, [&"gd"]):
			var source := FileAccess.get_file_as_string(path)
			for result: RegExMatch in _literal_pattern.search_all(source):
				_check_literal_path(result.get_string(1), path)


func _test_scene_roles() -> void:
	var allowed_roots := ["res://scenes/game/", "res://scenes/tests/", "res://scenes/dev/"]
	for path: String in _collect_files("res://scenes", [&"tscn"]):
		var is_classified := false
		for allowed_root: String in allowed_roots:
			if path.begins_with(allowed_root):
				is_classified = true
				break
		_expect(is_classified, "scenes의 씬은 game/tests/dev로 분류해야 합니다: %s" % path)


func _check_literal_path(literal: String, owner_path: String) -> void:
	if literal.contains("%") or literal.contains("{"):
		return
	var clean_path := literal.trim_suffix("\\")
	var exists := FileAccess.file_exists(clean_path) or DirAccess.dir_exists_absolute(clean_path)
	_expect(exists, "끊어진 res:// 경로입니다: %s (%s)" % [clean_path, owner_path])


func _collect_files(root_path: String, extensions: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var path := root_path.path_join(name)
			if directory.current_is_dir():
				result.append_array(_collect_files(path, extensions))
			elif extensions.has(StringName(path.get_extension().to_lower())):
				result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
