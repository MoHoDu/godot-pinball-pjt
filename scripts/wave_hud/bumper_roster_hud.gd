class_name BumperRosterHud
extends PanelContainer

## 현재 씬에 배치된 범퍼의 종류·개수·기능을 목록으로 보여주는 HUD입니다.
## 표시 내용은 전부 각 범퍼의 `BumperSettings`에서 직접 읽으므로,
## 씬에서 범퍼를 더하거나 빼면 코드 수정 없이 그대로 반영됩니다.

## 기능색 규약(비주얼 가이드)에 맞춘 타입별 색입니다.
## 아이보리=기본 / 금색=보상·고득점 / 청록=플레이어가 조작 가능.
const COLOR_NORMAL: String = "e8e0cc"
const COLOR_BOUNCE: String = "f0c040"
const COLOR_SHOT: String = "4fd1c5"
const COLOR_TRACK: String = "b48ee0"
const COLOR_DIM: String = "93a7b4"
const COLOR_TITLE: String = "7fe3dc"

## 범퍼 인스턴스들이 들어 있는 부모 노드 경로입니다.
@export var bumpers_root_path: NodePath = NodePath("../../Bumpers")
## 목록 본문을 그릴 RichTextLabel 경로입니다.
@export var body_path: NodePath = NodePath("Margin/Rows/Body")
## 제목 라벨 경로입니다.
@export var title_path: NodePath = NodePath("Margin/Rows/Title")
## 제목에 함께 표시할 웨이브 이름입니다. 비우면 씬 이름을 씁니다.
@export var wave_label: String = ""


func _ready() -> void:
	call_deferred(&"refresh")


## 배치된 범퍼를 다시 읽어 목록을 갱신합니다.
func refresh() -> void:
	var body := get_node_or_null(body_path) as RichTextLabel
	if body == null:
		return

	var title := get_node_or_null(title_path) as Label
	if title != null:
		var name_text := wave_label
		if name_text.is_empty():
			name_text = _guess_wave_name()
		title.text = "배치된 범퍼  —  %s" % name_text

	var groups := _collect_groups()
	if groups.is_empty():
		body.text = "[color=#%s]배치된 범퍼가 없습니다.[/color]" % COLOR_DIM
		return

	var lines: Array[String] = []
	var total := 0
	for kind_id: StringName in groups:
		var entry: Dictionary = groups[kind_id]
		var settings: BumperSettings = entry["settings"]
		var count: int = entry["count"]
		total += count
		var color := _type_color(settings.bumper_type)
		lines.append("[color=#%s]● %s[/color]  [color=#%s]×%d[/color]" % [
			color, settings.display_name, COLOR_DIM, count,
		])
		lines.append("[color=#%s]    %s[/color]" % [COLOR_DIM, _describe(settings)])

	lines.append("[color=#%s]합계 %d개[/color]" % [COLOR_DIM, total])
	body.text = "\n".join(lines)


## 같은 종류끼리 묶어 개수를 셉니다. 배치 순서를 유지합니다.
func _collect_groups() -> Dictionary:
	var groups: Dictionary = {}
	var root := get_node_or_null(bumpers_root_path)
	if root == null:
		return groups

	for child: Node in root.get_children():
		var settings: BumperSettings = child.get(&"settings") as BumperSettings
		if settings == null:
			continue
		var kind_id := settings.bumper_kind_id
		if groups.has(kind_id):
			var entry: Dictionary = groups[kind_id]
			entry["count"] = int(entry["count"]) + 1
		else:
			groups[kind_id] = {"settings": settings, "count": 1}
	return groups


## 설정 수치만으로 기능 한 줄을 만듭니다. 하드코딩한 설명을 쓰지 않습니다.
func _describe(settings: BumperSettings) -> String:
	var parts: Array[String] = []
	match settings.bumper_type:
		BumperSettings.BumperType.NORMAL:
			parts.append("기본 반사")
			parts.append("속도 ×%.2f" % settings.speed_multiplier)
		BumperSettings.BumperType.BOUNCE:
			parts.append("강한 반사")
			parts.append("속도 ×%.2f" % settings.speed_multiplier)
			if settings.minimum_release_speed > 0.0:
				parts.append("최소 %.0f로 튕겨냄" % settings.minimum_release_speed)
		BumperSettings.BumperType.SHOT:
			parts.append("공을 붙잡고 ↑ ← → 로 조준 발사")
			parts.append("%.1f초 안에 선택" % settings.selection_duration)
			parts.append("발사 %.0f" % settings.launch_speed)
		BumperSettings.BumperType.TRACK:
			parts.append("지정 위치로 공을 옮김")

	parts.append("점수 ×%.1f" % settings.score_weight)
	if settings.max_durability > 1:
		parts.append("내구 %d" % settings.max_durability)
	parts.append("지름 %.0f" % settings.collision_diameter)
	return "  ·  ".join(parts)


func _type_color(bumper_type: int) -> String:
	match bumper_type:
		BumperSettings.BumperType.BOUNCE:
			return COLOR_BOUNCE
		BumperSettings.BumperType.SHOT:
			return COLOR_SHOT
		BumperSettings.BumperType.TRACK:
			return COLOR_TRACK
		_:
			return COLOR_NORMAL


func _guess_wave_name() -> String:
	var scene_root := get_tree().current_scene if get_tree() != null else null
	if scene_root != null and not String(scene_root.scene_file_path).is_empty():
		return String(scene_root.scene_file_path).get_file().get_basename()
	return "현재 웨이브"
