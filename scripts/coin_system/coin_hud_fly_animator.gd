class_name CoinHudFlyAnimator
extends Control


const DEFAULT_COIN_TEXTURE := preload("res://Resources/Art/coin/coin.png")


@export_category("Runtime Dependencies")
@export var coin_field: CoinFieldController
@export var wallet_target: Control

@export_category("Fly Animation")
@export_range(0.1, 2.0, 0.01) var duration := 0.55
@export_range(0.0, 400.0, 1.0) var arc_height := 130.0
@export_range(16.0, 128.0, 1.0) var coin_size := 52.0


var _active_fly_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if coin_field != null \
			and not coin_field.coin_visual_collected.is_connected(_on_coin_collected):
		coin_field.coin_visual_collected.connect(_on_coin_collected)


func get_active_fly_count() -> int:
	return _active_fly_count


func play_pickup(
	viewport_position: Vector2,
	texture: Texture2D,
	value: int
) -> bool:
	if wallet_target == null or not is_instance_valid(wallet_target):
		return false
	var fly_coin := TextureRect.new()
	fly_coin.name = "FlyingCoin"
	fly_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_coin.texture = texture if texture != null else DEFAULT_COIN_TEXTURE
	fly_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly_coin.size = Vector2.ONE * coin_size
	fly_coin.pivot_offset = fly_coin.size * 0.5
	add_child(fly_coin)

	var start: Vector2 = _viewport_to_local(viewport_position) \
		- fly_coin.size * 0.5
	var target: Vector2 = _viewport_to_local(
		wallet_target.get_global_rect().get_center()
	) \
		- fly_coin.size * 0.5
	var control: Vector2 = (start + target) * 0.5 \
		+ Vector2(0.0, -arc_height)
	fly_coin.position = start
	_active_fly_count += 1

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		func(weight: float) -> void:
			if is_instance_valid(fly_coin):
				fly_coin.position = _quadratic_bezier(
					start, control, target, weight
				),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		fly_coin, ^"rotation", TAU * 1.25, duration
	)
	tween.parallel().tween_property(
		fly_coin, ^"scale", Vector2.ONE * 0.55, duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(
		func() -> void: _finish_fly(fly_coin, value)
	)
	return true


func _on_coin_collected(
	viewport_position: Vector2,
	texture: Texture2D,
	value: int
) -> void:
	play_pickup(viewport_position, texture, value)


func _finish_fly(fly_coin: TextureRect, value: int) -> void:
	if is_instance_valid(fly_coin):
		fly_coin.queue_free()
	_active_fly_count = maxi(_active_fly_count - 1, 0)
	_show_value_burst(value)


func _show_value_burst(value: int) -> void:
	if wallet_target == null or not is_instance_valid(wallet_target):
		return
	var burst := Label.new()
	burst.name = "CoinValueBurst"
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.text = "+%d" % maxi(value, 0)
	burst.add_theme_color_override(&"font_color", Color("f4d66d"))
	burst.add_theme_color_override(&"font_outline_color", Color(0.08, 0.04, 0.0, 0.9))
	burst.add_theme_constant_override(&"outline_size", 4)
	burst.add_theme_font_size_override(&"font_size", 28)
	burst.position = _viewport_to_local(
		wallet_target.get_global_rect().get_center()
	) \
		+ Vector2(-24.0, -48.0)
	add_child(burst)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(burst, ^"position:y", burst.position.y - 42.0, 0.45)
	tween.tween_property(burst, ^"modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(burst.queue_free)


func _quadratic_bezier(
	start: Vector2,
	control: Vector2,
	target: Vector2,
	weight: float
) -> Vector2:
	var inverse := 1.0 - weight
	return inverse * inverse * start \
		+ 2.0 * inverse * weight * control \
		+ weight * weight * target


func _viewport_to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position
