@tool
class_name BackgroundDecorAnimator
extends Node2D
## 맨 뒤 배경 그림의 별·구름을 살짝살짝 움직이는 데코 애니메이터입니다.
##
## 원본 배경(OutsideBackground)은 일절 건드리지 않습니다. 원본에서 잘라낸
## 패치(ambient_decor/)를 **같은 자리 위에 겹쳐 놓고**:
## - 별: 밝힌 패치의 알파를 천천히 맥동 — 이따금 은은하게 반짝입니다.
## - 구름: 코너를 고정한 채 1%만 확대·축소 — 느리게 숨쉽니다.
##   확대는 항상 안쪽으로만 일어나 원본을 늘 덮으므로 고스트가 없습니다.
##
## 구름 사각형 안에 있는 별은 구름 스프라이트의 자식으로 붙입니다.
## 구름이 숨쉴 때 별 글린트도 같이 움직여 어긋남이 생기지 않습니다.
##
## 배경의 위치·스케일·modulate 를 복제해 패치가 원본과 픽셀 단위로 겹칩니다.
## 시간은 _process 에서 sin 으로 직접 계산합니다 (bumper_art_animator 관례).


const DEFAULT_DECOR_RULES: AmbientDecorRules = preload(
	"res://settings/ambient_vfx/AmbientDecorRules.tres"
)

const RAYS_SHADER: Shader = preload(
	"res://Resources/shaders/background_rays.gdshader"
)

## 외경 배경(-20) 바로 위, 보드(-10) 아래입니다.
const Z_INDEX_DECOR: int = -19

## 별마다 주기를 어긋내는 황금비 간격입니다. 규칙적 박자로 안 읽히게 합니다.
const GOLDEN_FRACTION: float = 0.6180339887

## 별마다 위상을 어긋내는 황금각(rad)입니다.
const GOLDEN_ANGLE: float = 2.39996

## 구름 위상 간격(rad)입니다.
const CLOUD_PHASE_STEP: float = 1.7


var _decor_rules: AmbientDecorRules = DEFAULT_DECOR_RULES
var _stars: Array[Sprite2D] = []
var _star_glints: Array[Sprite2D] = []
var _star_covers: Array[Sprite2D] = []
var _clouds: Array[Sprite2D] = []
var _rays: Sprite2D
var _rays_material: ShaderMaterial
var _ray_phase: float = 0.0
var _time: float = 0.0


## 데코 규칙입니다. .tres 프리셋으로 교체할 수 있습니다.
@export var decor_rules: AmbientDecorRules:
	get:
		return _decor_rules
	set(value):
		_decor_rules = value if value != null else DEFAULT_DECOR_RULES
		if is_inside_tree() and not Engine.is_editor_hint():
			_rebuild()
		update_configuration_warnings()

## 겹칠 배경 Sprite2D 경로입니다. 위치·스케일·modulate 를 여기서 복제합니다.
@export var background_path: NodePath = ^"../OutsideBackground"


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = Z_INDEX_DECOR


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_time += delta
	var rules := _decor_rules

	if _rays_material != null:
		# 밴드 패턴이 ray_period_s 에 한 바퀴 돌도록 위상을 민다.
		# sin 은 TAU 주기라 감아도 이음매가 없다.
		_ray_phase = fposmod(
			_ray_phase
			+ delta * TAU * float(rules.ray_count) / rules.ray_period_s,
			TAU
		)
		_rays_material.set_shader_parameter(&"phase", _ray_phase)

	for i in _stars.size():
		if rules.star_spin_enabled:
			_stars[i].rotation = fposmod(
				_stars[i].rotation + get_star_spin_speed(i) * delta,
				TAU
			)
		var wave := sin(TAU * _time / get_star_period(i) + float(i) * GOLDEN_ANGLE)
		var glint := pow(maxf(wave, 0.0), rules.star_sharpness)
		_star_glints[i].self_modulate.a = rules.star_max_alpha * glint

	for i in _clouds.size():
		var breath := 0.5 + 0.5 * sin(
			TAU * _time / rules.cloud_period_s + float(i) * CLOUD_PHASE_STEP
		)
		var cloud_scale := 1.0 + rules.cloud_scale_amp * breath
		_clouds[i].scale = Vector2(cloud_scale, cloud_scale)


## i번 별의 반짝임 주기입니다. 황금비로 어긋나 서로 박자가 겹치지 않습니다.
func get_star_period(index: int) -> float:
	var rules := _decor_rules
	return lerpf(
		rules.star_period_min_s,
		rules.star_period_max_s,
		fposmod(float(index) * GOLDEN_FRACTION, 1.0)
	)


## i번 별의 회전 각속도(rad/s)입니다. 방향은 번호별로 엇갈립니다.
func get_star_spin_speed(index: int) -> float:
	var rules := _decor_rules
	var period := lerpf(
		rules.star_spin_period_min_s,
		rules.star_spin_period_max_s,
		fposmod(float(index) * GOLDEN_FRACTION + 0.31, 1.0)
	)
	var direction := 1.0 if index % 2 == 0 else -1.0
	return TAU / period * direction


## 배치된 별 수입니다. 테스트용입니다.
func get_star_count() -> int:
	return _stars.size()


## 배치된 구름 수입니다. 테스트용입니다.
func get_cloud_count() -> int:
	return _clouds.size()


## i번 별 스프라이트입니다. 테스트용입니다.
func get_star(index: int) -> Sprite2D:
	if index < 0 or index >= _stars.size():
		return null

	return _stars[index]


## i번 구름 스프라이트입니다. 테스트용입니다.
func get_cloud(index: int) -> Sprite2D:
	if index < 0 or index >= _clouds.size():
		return null

	return _clouds[index]


## i번 별의 반짝임(글린트) 스프라이트입니다. 회전 본체의 자식입니다. 테스트용입니다.
func get_star_glint(index: int) -> Sprite2D:
	if index < 0 or index >= _star_glints.size():
		return null

	return _star_glints[index]


## i번 별의 지움(cover) 스프라이트입니다. 테스트용입니다.
func get_star_cover(index: int) -> Sprite2D:
	if index < 0 or index >= _star_covers.size():
		return null

	return _star_covers[index]


## 회전 광선 쿼드입니다. 꺼져 있으면 null 입니다. 테스트용입니다.
func get_rays() -> Sprite2D:
	return _rays


## 광선 회전 위상입니다. 테스트용입니다.
func get_ray_phase() -> float:
	return _ray_phase


# ── 내부 ────────────────────────────────────────────────────

func _rebuild() -> void:
	for sprite in _clouds:
		sprite.queue_free()
	for sprite in _stars + _star_covers:
		if is_instance_valid(sprite) and sprite.get_parent() == self:
			sprite.queue_free()
	if is_instance_valid(_rays):
		_rays.queue_free()
	_stars.clear()
	_star_glints.clear()
	_star_covers.clear()
	_clouds.clear()
	_time = 0.0

	var background := get_node_or_null(background_path) as Sprite2D
	if background == null or background.texture == null:
		push_warning("BackgroundDecorAnimator: 배경 Sprite2D 를 찾지 못했습니다.")
		visible = false
		return

	visible = true
	# 패치가 원본과 픽셀 단위로 겹치도록 배경의 변환을 통째로 복제합니다.
	global_position = background.global_position
	scale = background.scale
	modulate = background.modulate

	# 자식 좌표계는 "텍스처 픽셀 - 텍스처 중심" 입니다 (배경이 centered 라서).
	var center := background.texture.get_size() * 0.5
	var rules := _decor_rules

	# 그리기 순서: 광선(맨 밑) -> 구름 -> 별 글린트(맨 위)
	_build_rays(rules, background.texture.get_size())
	_build_clouds(rules, center)
	_build_stars(rules, center)


func _build_rays(rules: AmbientDecorRules, texture_size: Vector2) -> void:
	_rays = null
	_rays_material = null
	_ray_phase = 0.0
	if not rules.rays_enabled:
		return

	# 1x1 흰 텍스처 쿼드 — 셰이더가 COLOR 를 통째로 그린다 (BallGlowOutline 방식).
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	_rays_material = ShaderMaterial.new()
	_rays_material.shader = RAYS_SHADER
	_rays_material.set_shader_parameter(&"phase", 0.0)
	_rays_material.set_shader_parameter(&"ray_count", float(rules.ray_count))
	_rays_material.set_shader_parameter(&"sharpness", rules.ray_sharpness)
	_rays_material.set_shader_parameter(&"max_alpha", rules.ray_max_alpha)
	_rays_material.set_shader_parameter(
		&"inner_fade_start", AmbientDecorRules.DEFAULT_RAY_FADE_START
	)
	_rays_material.set_shader_parameter(
		&"inner_fade_end", AmbientDecorRules.DEFAULT_RAY_FADE_END
	)
	_rays_material.set_shader_parameter(
		&"aspect", texture_size.x / maxf(texture_size.y, 1.0)
	)
	_rays_material.set_shader_parameter(&"light_color", rules.ray_color)

	_rays = Sprite2D.new()
	_rays.name = "Rays"
	_rays.centered = true
	_rays.texture = ImageTexture.create_from_image(image)
	_rays.material = _rays_material
	# 배경 텍스처와 정확히 같은 픽셀 영역을 덮는다.
	_rays.scale = texture_size
	add_child(_rays)


func _build_clouds(rules: AmbientDecorRules, center: Vector2) -> void:
	if not rules.clouds_enabled:
		return

	var count := mini(
		mini(rules.cloud_origins.size(), rules.cloud_sizes.size()),
		mini(rules.cloud_pivots.size(), rules.cloud_textures.size())
	)
	for i in count:
		var texture := load(rules.cloud_textures[i]) as Texture2D
		if texture == null:
			continue

		var origin := rules.cloud_origins[i]
		var size := rules.cloud_sizes[i]
		var pivot_kind := rules.cloud_pivots[i]

		var sprite := Sprite2D.new()
		sprite.name = "Cloud%d" % (i + 1)
		sprite.texture = texture
		sprite.centered = false

		# 스케일 기준점(코너)이 스프라이트 원점이 되도록 offset 으로 밀어 둡니다.
		var pivot := origin
		var offset := Vector2.ZERO
		if pivot_kind.contains("r"):
			pivot.x = origin.x + size.x
			offset.x = -size.x
		if pivot_kind.contains("b"):
			pivot.y = origin.y + size.y
			offset.y = -size.y
		sprite.offset = offset
		sprite.position = pivot - center
		add_child(sprite)
		_clouds.append(sprite)


func _build_stars(rules: AmbientDecorRules, center: Vector2) -> void:
	var count := rules.star_positions.size()

	# 1) 지움 패치를 전부 먼저 깐다. 패치끼리 겹쳐도 별 밖 픽셀은 원본과
	#    동일해서, 회전 본체보다 항상 아래에만 있으면 이중상이 안 생긴다.
	for i in count:
		var cover_texture := load(rules.star_cover_path(i)) as Texture2D
		if cover_texture == null:
			continue

		var cover := Sprite2D.new()
		cover.name = "StarCover%d" % (i + 1)
		cover.texture = cover_texture
		cover.centered = true
		_place_star_sprite(cover, rules, rules.star_positions[i], center)
		_star_covers.append(cover)

	# 2) 회전 본체 + 반짝임 자식. 본체가 돌면 글린트도 같이 돈다.
	for i in count:
		var body_texture := load(rules.star_body_path(i)) as Texture2D
		var glint_texture := load(rules.star_glint_path(i)) as Texture2D
		if body_texture == null or glint_texture == null:
			continue

		var body := Sprite2D.new()
		body.name = "Star%d" % (i + 1)
		body.texture = body_texture
		body.centered = true
		_place_star_sprite(body, rules, rules.star_positions[i], center)

		var glint := Sprite2D.new()
		glint.name = "Glint"
		glint.texture = glint_texture
		glint.centered = true
		glint.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		body.add_child(glint)

		_stars.append(body)
		_star_glints.append(glint)


## 별 스프라이트를 구름 안이면 구름의 자식으로, 아니면 루트에 놓습니다.
func _place_star_sprite(
	sprite: Sprite2D,
	rules: AmbientDecorRules,
	position_px: Vector2,
	center: Vector2
) -> void:
	var host := _find_hosting_cloud(rules, position_px)
	if host >= 0:
		var pivot_px := _clouds[host].position + center
		sprite.position = position_px - pivot_px
		_clouds[host].add_child(sprite)
		return

	sprite.position = position_px - center
	add_child(sprite)


func _find_hosting_cloud(rules: AmbientDecorRules, position_px: Vector2) -> int:
	for i in _clouds.size():
		var rect := Rect2(rules.cloud_origins[i], rules.cloud_sizes[i])
		if rect.has_point(position_px):
			return i

	return -1


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _decor_rules == null:
		warnings.append("Decor Rules 리소스를 지정해야 합니다.")
		return warnings

	return warnings
