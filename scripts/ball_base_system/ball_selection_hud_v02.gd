class_name BallSelectionHudV02
extends BallSelectionHud


## 공 선택 화면에 현재 선택한 공의 모습을 보여 주는 확장 HUD입니다.
##
## 기존 BallSelectionHud는 수정하지 않고 상속으로 미리보기만 더합니다.
## 미리보기는 [[BallArtLibrary]]의 확정본 합성 아트를 씁니다.


const PREVIEW_SIZE := Vector2(128.0, 128.0)


var _preview: TextureRect


func _ready() -> void:
	super()
	_build_preview()


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
	_refresh_preview()


func _refresh() -> void:
	super()
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview == null or _inventory == null:
		return
	var definition := _inventory.selected_definition
	var ball_id: StringName = \
		definition.ball_id if definition != null else &""
	_preview.texture = BallArtLibrary.composite_of(ball_id)
	_preview.visible = _preview.texture != null
