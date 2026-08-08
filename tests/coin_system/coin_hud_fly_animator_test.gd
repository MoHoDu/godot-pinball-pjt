extends SceneTree


const ANIMATOR_SCENE := preload(
	"res://Resources/Prefabs/ui/coin/coin_hud_fly_animator.tscn"
)
const COIN_TEXTURE := preload("res://Resources/Art/coin/coin.png")

var _failures: Array[String] = []


func _init() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred(&"_run")


func _run() -> void:
	var field := CoinFieldController.new()
	var target := Control.new()
	target.position = Vector2(1600.0, 24.0)
	target.size = Vector2(188.0, 72.0)
	var animator := ANIMATOR_SCENE.instantiate() as Control
	animator.coin_field = field
	animator.wallet_target = target
	animator.duration = 0.12
	root.add_child(field)
	root.add_child(target)
	root.add_child(animator)
	await process_frame

	field.coin_visual_collected.emit(Vector2(300.0, 700.0), COIN_TEXTURE, 2)
	_expect(int(animator.call(&"get_active_fly_count")) == 1,
		"코인 획득 시 HUD로 이동하는 코인 하나가 생성되어야 한다.")
	var fly_coin := animator.get_node_or_null(^"FlyingCoin") as TextureRect
	_expect(fly_coin != null and fly_coin.texture == COIN_TEXTURE,
		"이동 연출은 획득한 코인의 실제 텍스처를 사용해야 한다.")
	await create_timer(0.18, true).timeout
	_expect(int(animator.call(&"get_active_fly_count")) == 0,
		"코인이 지갑에 도착하면 이동 연출을 정리해야 한다.")
	_expect(animator.get_node_or_null(^"CoinValueBurst") != null,
		"도착 지점에는 획득 수량 피드백이 표시되어야 한다.")

	animator.queue_free()
	field.queue_free()
	target.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: coin_hud_fly_animator_test")
		quit(0)
		return
	print("FAIL: coin_hud_fly_animator_test (%d failures)" % _failures.size())
	quit(1)
