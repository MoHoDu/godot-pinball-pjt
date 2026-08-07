extends SceneTree


## 코인 지갑·픽업·필드 컨트롤러 단위 테스트입니다.


const COIN_PICKUP_SCENE := preload("res://scenes/coin_system/coin_pickup.tscn")
const COIN_SPAWN_POINT_SCENE := preload(
	"res://scenes/coin_system/coin_spawn_point.tscn"
)
const EMPTY_COIN_SYSTEM_SCENE := preload(
	"res://scenes/stage_system/stage_wave_coin_system.tscn"
)


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_wallet()
	_test_editor_authoring_scenes()
	await _test_pickup()
	await _test_field_controller()
	_finish()


func _test_editor_authoring_scenes() -> void:
	var point := COIN_SPAWN_POINT_SCENE.instantiate() as CoinSpawnPoint
	_expect(
		point != null and is_equal_approx(point.editor_radius * 2.0, 64.0),
		"에디터 추가용 코인 포인트는 실제 코인 크기를 표시해야 한다."
	)
	point.free()
	var empty_system := EMPTY_COIN_SYSTEM_SCENE.instantiate() as CoinFieldController
	_expect(
		empty_system != null
			and empty_system.layout == null
			and empty_system.spawn_points_root != null
			and empty_system.get_spawn_points().is_empty(),
		"빈 코인 시스템은 에디터에서 포인트를 직접 추가할 수 있어야 한다."
	)
	empty_system.free()


func _test_wallet() -> void:
	var wallet := CoinWallet.new()
	var changes: Array[int] = []
	wallet.wallet_changed.connect(func(_balance: int, delta: int) -> void:
		changes.append(delta)
	)

	_expect(wallet.balance == 0, "지갑은 0으로 시작해야 한다.")
	_expect(wallet.add(24) == 24, "24를 넣으면 잔액 24를 돌려줘야 한다.")
	_expect(wallet.add(0) == 24, "0 입금은 무시해야 한다.")
	_expect(wallet.add(-5) == 24, "음수 입금은 무시해야 한다.")
	_expect(wallet.can_afford(24), "잔액과 같은 금액은 살 수 있어야 한다.")
	_expect(not wallet.can_afford(25), "잔액보다 큰 금액은 살 수 없어야 한다.")
	_expect(wallet.try_spend(14), "14 차감은 성공해야 한다.")
	_expect(wallet.balance == 10, "차감 후 잔액은 10이어야 한다.")
	_expect(not wallet.try_spend(11), "잔액 초과 차감은 실패해야 한다.")
	_expect(wallet.balance == 10, "실패한 차감은 잔액을 바꾸면 안 된다.")
	_expect(not wallet.try_spend(0), "0 차감은 실패로 처리한다.")
	_expect(changes == [24, -14], "지갑 변화 시그널은 입금·차감만 기록해야 한다.")

	wallet.reset(7)
	_expect(wallet.balance == 7, "reset은 잔액을 지정값으로 바꿔야 한다.")
	wallet.free()


func _test_pickup() -> void:
	var holder := Node2D.new()
	root.add_child(holder)

	var ball := Node2D.new()
	ball.add_to_group(&"pinball_balls")
	holder.add_child(ball)

	var pickup := COIN_PICKUP_SCENE.instantiate() as CoinPickup
	_expect(pickup != null, "픽업 씬 루트는 CoinPickup이어야 한다.")
	pickup.pickup_id = &"coin_test_00"
	pickup.value = 2
	holder.add_child(pickup)
	await process_frame
	var visual := pickup.get_node_or_null(^"Visual") as Sprite2D
	_expect(visual != null, "코인 픽업은 확정 아트용 Visual Sprite2D를 가져야 한다.")
	_expect(
		visual != null
			and visual.texture != null
			and visual.texture.resource_path == "res://Resources/wave_hud/coin_wallet_icon.png",
		"기본 코인 픽업은 생성된 지갑 코인 아이콘을 사용해야 한다."
	)
	_expect(
		visual != null
			and visual.texture != null
			and is_equal_approx(
				visual.scale.x * maxf(
					visual.texture.get_size().x,
					visual.texture.get_size().y
				),
				pickup.visual_radius * 2.0
			),
		"코인 아트 지름은 픽업 visual_radius에 맞춰져야 한다."
	)
	_expect(
		is_equal_approx(pickup.visual_radius * 2.0, Pinball.DEFAULT_BALL_DIAMETER),
		"기본 코인 지름은 기본 공 지름과 같아야 한다."
	)

	var collected_log: Array = []
	pickup.collected.connect(func(pickup_id: StringName, value: int) -> void:
		collected_log.append([pickup_id, value])
	)

	# 공이 아닌 몸체는 무시해야 한다.
	var wall := Node2D.new()
	holder.add_child(wall)
	pickup._on_body_entered(wall)
	_expect(collected_log.is_empty(), "공이 아니면 획득되지 않아야 한다.")

	pickup._on_body_entered(ball)
	_expect(
		collected_log == [[&"coin_test_00", 2]],
		"공이 닿으면 pickup_id와 value로 획득 시그널이 나가야 한다."
	)
	pickup._on_body_entered(ball)
	_expect(collected_log.size() == 1, "이미 획득한 코인은 다시 획득되지 않아야 한다.")

	await process_frame
	_expect(
		not is_instance_valid(pickup) or pickup.is_queued_for_deletion(),
		"획득한 코인은 사라져야 한다."
	)
	holder.queue_free()
	await process_frame


func _test_field_controller() -> void:
	var holder := Node2D.new()
	root.add_child(holder)

	var wallet := CoinWallet.new()
	holder.add_child(wallet)

	var field := CoinFieldController.new()
	field.layout = CoinSpawnLayout.new()
	holder.add_child(field)
	_expect(field.bind_wallet(wallet), "지갑 연결은 성공해야 한다.")

	var events: Array = []
	field.coin_pickup_collected.connect(
		func(wave_id: int, pickup_id: StringName, value: int, after: int) -> void:
			events.append([wave_id, pickup_id, value, after])
	)

	var spawned := field.spawn_for_wave(0)
	await process_frame
	_expect(spawned == 12, "기본 배치는 코인 12개를 스폰해야 한다. (%d)" % spawned)
	_expect(
		field.remaining_pickup_count() == 12,
		"스폰 직후 남은 코인은 12개여야 한다."
	)
	_expect(field.layout.total_coin() == 24, "기본 배치 총액은 24코인이어야 한다.")

	var ball := Node2D.new()
	ball.add_to_group(&"pinball_balls")
	holder.add_child(ball)

	var first_pickup: CoinPickup = null
	for child in field.get_children():
		if child is CoinPickup:
			first_pickup = child
			break
	_expect(first_pickup != null, "스폰된 코인을 찾을 수 있어야 한다.")
	first_pickup._on_body_entered(ball)
	await process_frame

	_expect(wallet.balance == 2, "코인 획득이 지갑에 즉시 반영돼야 한다.")
	_expect(field.board_coin_this_wave == 2, "웨이브 보드 코인 합계가 늘어야 한다.")
	_expect(events.size() == 1, "획득 이벤트가 한 번 나가야 한다.")
	_expect(
		events[0][0] == 0 and events[0][2] == 2 and events[0][3] == 2,
		"획득 이벤트 인자는 (웨이브, 값, 반영 후 잔액)이 맞아야 한다."
	)
	_expect(
		field.remaining_pickup_count() == 11,
		"획득한 코인은 남은 개수에서 빠져야 한다."
	)

	# 다음 웨이브를 깔면 이전 코인은 사라지고 웨이브 합계가 초기화된다.
	field.spawn_for_wave(1)
	await process_frame
	_expect(
		field.remaining_pickup_count() == 12,
		"새 웨이브는 다시 12개로 시작해야 한다."
	)
	_expect(field.board_coin_this_wave == 0, "웨이브 보드 코인 합계는 초기화돼야 한다.")
	_expect(wallet.balance == 2, "지갑 잔액은 웨이브가 바뀌어도 유지돼야 한다.")

	holder.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: coin_wallet_pickup_test")
		quit(0)
		return
	print("FAIL: coin_wallet_pickup_test (%d failures)" % _failures.size())
	quit(1)
