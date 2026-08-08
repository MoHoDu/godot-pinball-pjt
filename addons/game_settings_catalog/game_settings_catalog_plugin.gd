@tool
extends EditorPlugin


const MENU_TITLE := "Pinball/Game Settings"
const SETTINGS_ROOT := "res://settings"


var _root_menu: PopupMenu
var _resource_paths: Dictionary[int, String] = {}


func _enter_tree() -> void:
	_build_catalog_menu()
	add_tool_submenu_item(MENU_TITLE, _root_menu)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TITLE)
	if _root_menu != null:
		_root_menu.queue_free()
	_root_menu = null
	_resource_paths.clear()


func _build_catalog_menu() -> void:
	_root_menu = PopupMenu.new()
	_root_menu.name = "GameSettingsCatalog"
	var paths := _collect_tres_files(SETTINGS_ROOT)
	paths.sort()
	var categories: Dictionary[String, PopupMenu] = {}
	var next_id := 1
	for path: String in paths:
		var relative := path.trim_prefix(SETTINGS_ROOT + "/")
		var segments := relative.split("/", false)
		var category := segments[0] if segments.size() > 1 else "general"
		var submenu := categories.get(category) as PopupMenu
		if submenu == null:
			submenu = PopupMenu.new()
			submenu.name = "Category_%s" % category.validate_node_name()
			submenu.id_pressed.connect(_on_resource_selected)
			_root_menu.add_child(submenu)
			_root_menu.add_submenu_item(category.capitalize(), submenu.name)
			categories[category] = submenu
		var label := relative.trim_prefix(category + "/").trim_suffix(".tres")
		submenu.add_item(label, next_id)
		submenu.set_item_tooltip(submenu.item_count - 1, path)
		_resource_paths[next_id] = path
		next_id += 1


func _on_resource_selected(id: int) -> void:
	var path := _resource_paths.get(id, "") as String
	if path.is_empty():
		return
	var resource := ResourceLoader.load(path)
	if resource == null:
		push_error("Game Settings Catalog: 리소스를 열 수 없습니다: %s" % path)
		return
	EditorInterface.edit_resource(resource)


func _collect_tres_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := root_path.path_join(entry)
			if directory.current_is_dir():
				result.append_array(_collect_tres_files(path))
			elif entry.get_extension().to_lower() == "tres":
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return result
