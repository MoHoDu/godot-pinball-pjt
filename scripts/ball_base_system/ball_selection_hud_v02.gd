class_name BallSelectionHudV02
extends BallSelectionHud


## 공 선택 화면에 현재 선택한 공의 모습을 보여 주는 확장 HUD입니다.
##
## 기존 BallSelectionHud는 수정하지 않고 상속으로 미리보기만 더합니다.
## 미리보기는 [[BallArtLibrary]]의 확정본 합성 아트를 씁니다.


const PREVIEW_SIZE := Vector2(128.0, 128.0)

## 장점·대가·성능 계열 문구를 상점 카탈로그에서 그대로 가져옵니다(7-2).
const SHOP_CATALOG := preload(
	"res://settings/reward_shop/RewardShopCatalog_Stage01.tres"
)

const PERFORMANCE_GROUP_NAMES: Array[String] = ["안정형", "중간형", "도전형"]


var _preview: TextureRect
var _info_label: Label

## 활성 공이 있는 동안 보이는 안내입니다(7-2 잠금 안내).
## 선택 패널은 SELECTING에서만 보이므로 패널 밖(부모 레이어)에 둡니다.
var _play_hint_label: Label


func _ready() -> void:
	super()
	_build_preview()
	call_deferred(&"_attach_play_hint")


func _attach_play_hint() -> void:
	var hud_parent := get_parent()
	if hud_parent == null:
		return
	_play_hint_label = Label.new()
	_play_hint_label.name = "_BallChangeHintLabel"
	_play_hint_label.position = Vector2(24.0, 24.0)
	_play_hint_label.add_theme_font_size_override(&"font_size", 18)
	_play_hint_label.add_theme_color_override(
		&"font_color", Color(0.70, 0.76, 0.78)
	)
	_play_hint_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	_play_hint_label.add_theme_constant_override(&"outline_size", 5)
	_play_hint_label.text = "공 진행 중 · 다음 발사에서 공 변경 가능"
	_play_hint_label.visible = false
	hud_parent.add_child(_play_hint_label)
	_refresh_play_hint()


## 패널 오른쪽 옆에 미리보기 이미지를 붙입니다. 씬 파일은 건드리지 않습니다.
func _build_preview() -> void:
	_preview = TextureRect.new()
	_preview.name = "_BallPreview"
	_preview.position = Vector2(size.x + 10.0, 8.0)
	_preview.size = PREVIEW_SIZE
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)

	# 보유 종류 나열과 장점·대가 문구를 패널 아래에 붙입니다(7-2).
	_info_label = Label.new()
	_info_label.name = "_BallInfoLabel"
	_info_label.position = Vector2(0.0, size.y + 8.0)
	_info_label.add_theme_font_size_override(&"font_size", 16)
	_info_label.add_theme_color_override(
		&"font_color", Color(0.80, 0.86, 0.84)
	)
	_info_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	_info_label.add_theme_constant_override(&"outline_size", 5)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info_label)
	_refresh_preview()


func _refresh() -> void:
	super()
	_refresh_preview()
	_refresh_play_hint()
	# v0.2 모델: 공 종류는 소모되지 않으므로(7-1) 종류별 개수 대신
	# 생명 풀의 남은 발사 횟수를 보여 줍니다.
	if visible and _inventory is WaveBallInventoryV02:
		stock_label.text = "남은 발사 %d회" % _inventory.total_remaining


## 활성 공이 있는 동안 "다음 발사에서 변경 가능"을 보여 줍니다(7-2).
func _refresh_play_hint() -> void:
	if _play_hint_label == null:
		return
	_play_hint_label.visible = (
		_flow != null
		and _flow.current_state == WaveBallFlowController.State.IN_PLAY
	)


func _refresh_preview() -> void:
	if _preview == null or _inventory == null:
		return
	var definition := _inventory.selected_definition
	var ball_id: StringName = \
		definition.ball_id if definition != null else &""
	_preview.texture = BallArtLibrary.composite_of(ball_id)
	_preview.visible = _preview.texture != null
	_refresh_info(ball_id)


## 보유 종류 나열 + 선택한 공의 계열·장점·대가 문구입니다(7-2).
func _refresh_info(selected_id: StringName) -> void:
	if _info_label == null or _inventory == null:
		return
	_info_label.visible = visible
	if not visible:
		return
	var type_names: PackedStringArray = PackedStringArray()
	for definition in _inventory.get_available_definitions():
		if definition.ball_id == selected_id:
			type_names.append("[%s]" % definition.display_name)
		else:
			type_names.append(definition.display_name)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("보유: " + "  ".join(type_names))
	var offer := _find_catalog_offer(selected_id)
	if offer != null:
		lines.append("%s · + %s" % [
			PERFORMANCE_GROUP_NAMES[clampi(
				offer.performance_group, 0, PERFORMANCE_GROUP_NAMES.size() - 1
			)],
			offer.merit_text,
		])
		lines.append("- " + offer.cost_text)
	else:
		lines.append("기본 유리눈 · 균형형 — 추가 효과 없음")
	_info_label.text = "\n".join(lines)


func _find_catalog_offer(ball_id: StringName) -> RewardBallOffer:
	if SHOP_CATALOG == null:
		return null
	for offer in SHOP_CATALOG.ball_offers:
		if offer != null and offer.ball_id == ball_id:
			return offer
	return null
