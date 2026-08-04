class_name CoinPickup
extends Area2D


## 보드에 배치되는 기본 코인 오브젝트입니다. 공이 닿으면 1회 획득되고 사라집니다.
##
## 아트 확정 전이라 _draw()로 자리표시자 원판을 그립니다.
## 감지는 공의 그룹(pinball_balls)으로 하므로 공 씬이 바뀌어도 영향이 없습니다.


signal collected(pickup_id: StringName, value: int)


const PINBALL_GROUP: StringName = &"pinball_balls"

## 자리표시자 색입니다. 확정 팔레트의 금색 계열을 임시로 씁니다.
const FILL_COLOR := Color(0.90, 0.72, 0.25)
const RIM_COLOR := Color(0.96, 0.93, 0.82)


@export var value := 2
@export var pickup_id: StringName = &""
@export_range(4.0, 64.0, 1.0) var visual_radius := 14.0


var _collected := false


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, visual_radius, FILL_COLOR)
	draw_arc(
		Vector2.ZERO, visual_radius - 1.5,
		0.0, TAU, 24, RIM_COLOR, 3.0, true
	)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not (body is Pinball or body.is_in_group(PINBALL_GROUP)):
		return
	_collected = true
	# 물리 콜백 중이므로 즉시 끄지 않고 지연시킵니다.
	set_deferred(&"monitoring", false)
	hide()
	collected.emit(pickup_id, value)
	queue_free()
