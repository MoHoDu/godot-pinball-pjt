class_name BallArtLibrary
extends RefCounted


## 공 확정본 아트 조회 표입니다. UI 어디서든 같은 매핑을 쓰도록 한 곳에 모읍니다.
##
## 기본 공 3종은 유리눈 확정본, 보상 공 5종은 본체(Body)+동공(Pupil) 최종본입니다.
## composite_of()는 본체 위에 동공을 한 번 합성해 캐시하므로,
## 아이콘 슬롯 하나(TextureRect·Button.icon)로도 완성된 공 모습을 쓸 수 있습니다.


const BODY_TEXTURES: Dictionary = {
	&"light": preload("res://Resources/Art/balls/glass_eye_ball.png"),
	&"normal": preload("res://Resources/Art/balls/glass_eye_ball.png"),
	&"heavy": preload("res://Resources/Art/balls/glass_eye_ball.png"),
	&"clockwork": preload(
		"res://Resources/Art/balls/variants/Ball_Clockwork_Body.png"
	),
	&"rubber": preload(
		"res://Resources/Art/balls/variants/Ball_Rubber_Body.png"
	),
	&"gel": preload("res://Resources/Art/balls/variants/Ball_Gel_Body.png"),
	&"lead": preload("res://Resources/Art/balls/variants/Ball_Lead_Body.png"),
	&"hollow_bell": preload(
		"res://Resources/Art/balls/variants/Ball_HollowBell_Body.png"
	),
}

const PUPIL_TEXTURES: Dictionary = {
	&"clockwork": preload(
		"res://Resources/Art/balls/variants/Ball_Clockwork_Pupil.png"
	),
	&"rubber": preload(
		"res://Resources/Art/balls/variants/Ball_Rubber_Pupil.png"
	),
	&"gel": preload("res://Resources/Art/balls/variants/Ball_Gel_Pupil.png"),
	&"lead": preload("res://Resources/Art/balls/variants/Ball_Lead_Pupil.png"),
	&"hollow_bell": preload(
		"res://Resources/Art/balls/variants/Ball_HollowBell_Pupil.png"
	),
}


## 생명 슬롯과 같은 크기입니다. Button.icon처럼 원본 크기로 그려지는
## 슬롯에는 1024px 원본 대신 이 크기로 줄인 아이콘을 씁니다.
const DEFAULT_ICON_SIZE := 56


static var _composite_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}


static func body_of(ball_id: StringName) -> Texture2D:
	return BODY_TEXTURES.get(ball_id, null) as Texture2D


static func pupil_of(ball_id: StringName) -> Texture2D:
	return PUPIL_TEXTURES.get(ball_id, null) as Texture2D


## 본체 위에 동공을 합성한 완성 이미지를 돌려줍니다. 공별로 1회만 합성합니다.
static func composite_of(ball_id: StringName) -> Texture2D:
	if _composite_cache.has(ball_id):
		return _composite_cache[ball_id] as Texture2D
	var body := body_of(ball_id)
	if body == null:
		return null
	var pupil := pupil_of(ball_id)
	var composed: Texture2D = body
	if pupil != null:
		var body_image := body.get_image()
		var pupil_image := pupil.get_image()
		if body_image != null and pupil_image != null:
			body_image.convert(Image.FORMAT_RGBA8)
			pupil_image.convert(Image.FORMAT_RGBA8)
			body_image.blend_rect(
				pupil_image,
				Rect2i(Vector2i.ZERO, pupil_image.get_size()),
				Vector2i.ZERO
			)
			composed = ImageTexture.create_from_image(body_image)
	_composite_cache[ball_id] = composed
	return composed


## 합성 아트를 아이콘 크기로 줄인 텍스처를 돌려줍니다. 공·크기별로 1회만 만듭니다.
static func icon_of(
	ball_id: StringName,
	icon_size := DEFAULT_ICON_SIZE
) -> Texture2D:
	var cache_key := "%s@%d" % [ball_id, icon_size]
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key] as Texture2D
	var composed := composite_of(ball_id)
	if composed == null:
		return null
	var image := composed.get_image()
	if image == null:
		return composed
	image.convert(Image.FORMAT_RGBA8)
	image.resize(icon_size, icon_size, Image.INTERPOLATE_LANCZOS)
	var icon := ImageTexture.create_from_image(image)
	_icon_cache[cache_key] = icon
	return icon
