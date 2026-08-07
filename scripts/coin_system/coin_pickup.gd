class_name CoinPickup
extends Area2D


## 보드에 배치되는 기본 코인 오브젝트입니다. 공이 닿으면 1회 획득되고 사라집니다.
##
## CoinDefinition에 확정 아트가 있으면 Sprite2D로 표시하고, 없을 때만 원판을 그립니다.
## 감지는 공의 그룹(pinball_balls)으로 하므로 공 씬이 바뀌어도 영향이 없습니다.


signal collected(pickup_id: StringName, value: int)


const PINBALL_GROUP: StringName = &"pinball_balls"

## 자리표시자 색입니다. 확정 팔레트의 금색 계열을 임시로 씁니다.
const FALLBACK_FILL_COLOR := Color(0.90, 0.72, 0.25)
const FALLBACK_RIM_COLOR := Color(0.96, 0.93, 0.82)


@export var definition: CoinDefinition
## 0이면 definition의 값을 사용합니다. 테스트·특수 코인만 양수로 덮어씁니다.
@export_range(0, 999, 1) var value := 0
@export var pickup_id: StringName = &""
@export_range(4.0, 64.0, 1.0) var visual_radius := 32.0


var _collected := false
@onready var _visual: Sprite2D = get_node_or_null(^"Visual") as Sprite2D


func _ready() -> void:
	if definition != null and definition.is_valid():
		visual_radius = definition.visual_radius
	var collision := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		var circle := collision.shape.duplicate() as CircleShape2D
		circle.radius = visual_radius
		collision.shape = circle
	_configure_visual()
	monitorable = false
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	if _visual != null and _visual.texture != null:
		return
	var fill_color := FALLBACK_FILL_COLOR
	var rim_color := FALLBACK_RIM_COLOR
	if definition != null and definition.is_valid():
		fill_color = definition.fill_color
		rim_color = definition.rim_color
	draw_circle(Vector2.ZERO, visual_radius, fill_color)
	draw_arc(
		Vector2.ZERO, visual_radius - 1.5,
		0.0, TAU, 24, rim_color, 3.0, true
	)
	draw_circle(Vector2.ZERO, visual_radius * 0.38, Color(rim_color, 0.42))


func _configure_visual() -> void:
	if _visual == null:
		return
	_visual.texture = definition.visual_texture if definition != null else null
	if _visual.texture == null:
		_visual.visible = false
		return
	_visual.visible = true
	var texture_size := _visual.texture.get_size()
	var source_diameter := maxf(texture_size.x, texture_size.y)
	if source_diameter <= 0.0:
		_visual.visible = false
		return
	var target_diameter := visual_radius * 2.0
	_visual.scale = Vector2.ONE * (target_diameter / source_diameter)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not (body is Pinball or body.is_in_group(PINBALL_GROUP)):
		return
	_collected = true
	# 물리 콜백 중이므로 즉시 끄지 않고 지연시킵니다.
	set_deferred(&"monitoring", false)
	hide()
	var collected_value := value
	if collected_value <= 0 and definition != null:
		collected_value = definition.value
	collected.emit(pickup_id, maxi(collected_value, 0))
	queue_free()
