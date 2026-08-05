class_name WaveLifeHudV02
extends WaveLifeHud


## 생명 슬롯의 공 아이콘을 확정본 아트로 최신화한 확장 HUD입니다.
##
## 기존 WaveLifeHud는 수정하지 않고 _rebuild_slots()만 오버라이드합니다.
## 구본 아이콘(ball_cat_eye·ball_industrial_steel)은 폐기된 아트라 쓰지 않고,
## [[BallArtLibrary]]의 확정본 합성 아트(본체+동공)를 씁니다.


func _rebuild_slots(life_slots: Array) -> void:
	for child in _slots.get_children():
		child.queue_free()
	for index in life_slots.size():
		var slot: Dictionary = life_slots[index]
		var ball_type := StringName(slot.get(&"type", &"normal"))
		var icon := TextureRect.new()
		icon.name = "BallSlot%d" % index
		var texture := BallArtLibrary.composite_of(ball_type)
		if texture == null:
			texture = BallArtLibrary.composite_of(&"normal")
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var state := int(slot.get(&"state", WaveHudStateSource.LifeState.UPCOMING))
		icon.modulate.a = 0.26 if state == WaveHudStateSource.LifeState.SPENT else 1.0
		_slots.add_child(icon)
		icon.position = Vector2(LEFT_PADDING + index * (SLOT_SIZE.x + SLOT_GAP), SLOT_Y)
		icon.size = SLOT_SIZE
		if state == WaveHudStateSource.LifeState.CURRENT:
			var outline := TextureRect.new()
			outline.name = "CurrentOutline"
			outline.texture = CURRENT_OUTLINE
			outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slots.add_child(outline)
			outline.position = icon.position - Vector2(6.0, 6.0)
			outline.size = OUTLINE_SIZE
