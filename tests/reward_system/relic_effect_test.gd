extends SceneTree


const FLIPPER_SCENE := preload(
	"res://Resources/Prefabs/flippers/variants/normal_flipper_left.tscn"
)
const LIGHT_BALL := preload("res://Resources/Prefabs/balls/variants/mass/light_ball.tscn")

const EPSILON := 0.0001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var fixture_root := Node2D.new()
	root.add_child(fixture_root)

	var combo := ComboSystem.new()
	var launcher := PinballLauncher.new()
	var inventory := WaveBallInventory.new()
	var flipper := FLIPPER_SCENE.instantiate()
	var runtime := RelicRuntime.new()
	var relics := RelicInventory.new()
	fixture_root.add_child(combo)
	fixture_root.add_child(launcher)
	fixture_root.add_child(inventory)
	fixture_root.add_child(flipper)
	fixture_root.add_child(runtime)
	fixture_root.add_child(relics)
	launcher.spawn_parent_path = ^".."
	inventory.starting_stock = [_make_stock(&"light", 3)]
	inventory.reset_stock()
	await process_frame

	var flippers: Array[Node] = [flipper]
	_expect(
		runtime.bind_board(combo, launcher, inventory, flippers),
		"런타임이 보드 노드에 바인딩되어야 한다."
	)

	var combo_rules: Resource = combo.rules
	var parry_rules: Resource = flipper.get(&"parry_rules")
	var base_score_multiplier := float(combo_rules.get(&"normal_score_multiplier"))
	var base_ultra_multiplier := float(combo_rules.get(&"ultra_score_multiplier"))
	var base_default_speed := float(launcher.default_launch_speed)
	var base_maximum_speed := float(launcher.maximum_launch_speed)
	var base_normal_window := float(parry_rules.get(&"normal_parry_window_time"))
	var base_perfect_window := float(parry_rules.get(&"perfect_parry_window_time"))
	var base_stock_total := inventory.total_remaining
	_expect(base_stock_total == 3, "기준 스톡은 공 3개여야 한다.")

	# 점수 배율 — 1스택
	var brooch := _make_definition(&"star_brooch", 3, RelicEffectScoreMultiplier.new())
	(brooch.effect as RelicEffectScoreMultiplier).bonus_per_stack = 0.25
	relics.acquire(brooch)
	runtime.apply_all(relics)
	_expect(
		is_equal_approx(
			float(combo_rules.get(&"normal_score_multiplier")),
			base_score_multiplier * 1.25
		),
		"1스택이면 점수 배율이 기준값의 1.25배여야 한다."
	)
	_expect(
		is_equal_approx(
			float(combo_rules.get(&"ultra_score_multiplier")),
			base_ultra_multiplier * 1.25
		),
		"울트라 배율도 같은 비율로 올라야 한다."
	)

	# 2스택 — 누적이 아니라 기준값에서 다시 계산한다 (1.5625가 아니라 1.5)
	relics.acquire(brooch)
	runtime.apply_all(relics)
	_expect(
		is_equal_approx(
			float(combo_rules.get(&"normal_score_multiplier")),
			base_score_multiplier * 1.5
		),
		"2스택은 기준값의 1.5배여야 한다. 누적 곱(1.5625)이면 안 된다."
	)

	# 발사 속력
	var gear := _make_definition(&"clockwork_gear", 3, RelicEffectLaunchSpeed.new())
	(gear.effect as RelicEffectLaunchSpeed).bonus_per_stack = 0.1
	relics.acquire(gear)
	runtime.apply_all(relics)
	_expect(
		is_equal_approx(launcher.default_launch_speed, base_default_speed * 1.1),
		"발사 기본 속력이 1.1배여야 한다."
	)
	_expect(
		is_equal_approx(launcher.maximum_launch_speed, base_maximum_speed * 1.1),
		"발사 상한 속력도 함께 올라야 한다."
	)

	# 패링 판정 창 — perfect가 normal에 clamp되므로 순서가 중요하다
	var needle := _make_definition(&"curved_needle", 2, RelicEffectParryWindow.new())
	(needle.effect as RelicEffectParryWindow).bonus_per_stack = 0.35
	relics.acquire(needle)
	runtime.apply_all(relics)
	var scaled_normal := float(parry_rules.get(&"normal_parry_window_time"))
	var scaled_perfect := float(parry_rules.get(&"perfect_parry_window_time"))
	_expect(
		is_equal_approx(scaled_normal, base_normal_window * 1.35),
		"일반 패링 창이 1.35배여야 한다."
	)
	_expect(
		is_equal_approx(scaled_perfect, base_perfect_window * 1.35),
		"정확 패링 창도 1.35배여야 한다. clamp에 잘리면 안 된다."
	)
	_expect(
		scaled_perfect <= scaled_normal + EPSILON,
		"정확 패링 창은 일반 패링 창을 넘을 수 없다."
	)

	# 공 추가 — 라이프 슬롯 상한 5개를 넘지 않는다
	var bell := _make_definition(&"bell", 3, RelicEffectExtraBall.new())
	(bell.effect as RelicEffectExtraBall).balls_per_stack = 1
	relics.acquire(bell)
	runtime.apply_all(relics)
	inventory.reset_stock()
	_expect(inventory.total_remaining == 4, "1스택이면 시작 공이 4개여야 한다.")

	relics.acquire(bell)
	runtime.apply_all(relics)
	inventory.reset_stock()
	_expect(inventory.total_remaining == 5, "2스택이면 시작 공이 5개여야 한다.")

	relics.acquire(bell)
	runtime.apply_all(relics)
	inventory.reset_stock()
	_expect(
		inventory.total_remaining == RelicRuntime.MAX_LIFE_SLOTS,
		"3스택이어도 라이프 슬롯 상한 5개를 넘지 않아야 한다."
	)

	# 복원 — 공유 .tres가 원래 값으로 돌아와야 한다
	runtime.restore_all()
	inventory.reset_stock()
	_expect(
		is_equal_approx(
			float(combo_rules.get(&"normal_score_multiplier")),
			base_score_multiplier
		),
		"복원 후 점수 배율이 기준값이어야 한다."
	)
	_expect(
		is_equal_approx(launcher.default_launch_speed, base_default_speed),
		"복원 후 발사 속력이 기준값이어야 한다."
	)
	_expect(
		is_equal_approx(
			float(parry_rules.get(&"normal_parry_window_time")),
			base_normal_window
		)
		and is_equal_approx(
			float(parry_rules.get(&"perfect_parry_window_time")),
			base_perfect_window
		),
		"복원 후 패링 창이 기준값이어야 한다."
	)
	_expect(
		inventory.total_remaining == base_stock_total,
		"복원 후 시작 공 개수가 기준값이어야 한다."
	)

	fixture_root.queue_free()
	await process_frame
	_finish()


func _make_definition(
	relic_id: StringName,
	max_stack: int,
	effect: RelicEffect
) -> RelicDefinition:
	var definition := RelicDefinition.new()
	definition.relic_id = relic_id
	definition.display_name = String(relic_id)
	definition.max_stack = max_stack
	definition.effect = effect
	return definition


func _make_stock(ball_id: StringName, count: int) -> BallStock:
	var definition := BallDefinition.new()
	definition.ball_id = ball_id
	definition.display_name = String(ball_id)
	definition.ball_scene = LIGHT_BALL
	var stock := BallStock.new()
	stock.definition = definition
	stock.count = count
	return stock


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: relic_effect_test")
		quit(0)
		return
	print("FAIL: relic_effect_test (%d failures)" % _failures.size())
	quit(1)
