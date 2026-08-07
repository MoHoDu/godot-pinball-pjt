class_name BoardValidationResult
extends RefCounted


var issues: Array[Dictionary] = []


var is_valid: bool:
	get:
		return issues.is_empty()


func add_error(
	code: StringName,
	message: String,
	node_path: NodePath = NodePath()
) -> void:
	issues.append({
		&"code": code,
		&"message": message,
		&"node_path": node_path,
	})


func append(other: BoardValidationResult) -> void:
	if other == null:
		return
	issues.append_array(other.issues)


func to_messages() -> PackedStringArray:
	var messages := PackedStringArray()
	for issue: Dictionary in issues:
		var node_path := NodePath(issue.get(&"node_path", NodePath()))
		var prefix := ""
		if not node_path.is_empty():
			prefix = "%s: " % node_path
		messages.append(
			"[%s] %s%s" % [
				String(issue.get(&"code", &"invalid")),
				prefix,
				String(issue.get(&"message", "Invalid board layout.")),
			]
		)
	return messages


func summary() -> String:
	if is_valid:
		return "Board layout is valid."
	return "\n".join(to_messages())
