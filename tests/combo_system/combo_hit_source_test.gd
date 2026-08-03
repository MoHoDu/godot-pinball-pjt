extends SceneTree


const COMBO_SYSTEM_SCRIPT_PATH := "res://scripts/combo_system/combo_system.gd"
const HIT_SOURCE_SCRIPT_PATH := "res://scripts/combo_system/combo_hit_source.gd"
const EPSILON := 0.001


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var combo_script := load(COMBO_SYSTEM_SCRIPT_PATH) as Script
	var source_script := load(HIT_SOURCE_SCRIPT_PATH) as Script
	_expect(combo_script != null, "콤보 시스템 스크립트가 필요하다.")
	_expect(source_script != null, "유효 타격 소스 스크립트가 필요하다.")
	if combo_script == null or source_script == null:
		_finish()
		return

	var combo_system := combo_script.new() as Node
	var source := source_script.new() as Node
	root.add_child(combo_system)
	root.add_child(source)
	await process_frame

	_test_binding_contract(combo_system, source)
	_test_contact_deduplication(combo_system, source)
	_test_inactive_source(combo_system, source)
	_test_unbinding(combo_system, source)

	source.queue_free()
	combo_system.queue_free()
	await process_frame
	_finish()


func _test_binding_contract(combo_system: Node, source: Node) -> void:
	var unsupported_source := Node.new()
	_expect(not bool(combo_system.call(&"bind_hit_source", unsupported_source)), \
		"유효 타격 신호가 없는 노드는 연결을 거절해야 한다.")
	unsupported_source.free()
	_expect(bool(combo_system.call(&"bind_hit_source", source)), \
		"ComboHitSource를 콤보 시스템에 연결할 수 있어야 한다.")
	_expect(bool(combo_system.call(&"bind_hit_source", source)), \
		"같은 소스를 다시 연결해도 성공하며 중복 연결하지 않아야 한다.")


func _test_contact_deduplication(combo_system: Node, source: Node) -> void:
	combo_system.call(&"reset_run")
	source.set(&"score_weight", 2.5)
	_expect(bool(source.call(&"register_contact", 101)), \
		"새로운 접촉은 유효 타격으로 등록되어야 한다.")
	_expect(int(combo_system.get(&"combo_count")) == 1, \
		"새로운 접촉은 콤보를 정확히 한 번 증가시켜야 한다.")
	_expect_float(float(combo_system.get(&"total_score_weight")), 2.5, \
		"타격 소스의 점수 가중치를 콤보에 전달해야 한다.")

	_expect(not bool(source.call(&"register_contact", 101)), \
		"지속 중인 같은 접촉은 중복 타격으로 거절해야 한다.")
	_expect(int(combo_system.get(&"combo_count")) == 1, \
		"중복 접촉은 콤보를 추가하면 안 된다.")
	_expect(bool(source.call(&"release_contact", 101)), \
		"등록된 접촉을 분리 상태로 전환할 수 있어야 한다.")
	_expect(bool(source.call(&"register_contact", 101)), \
		"분리 후 같은 접촉 ID의 재접촉은 새 타격이어야 한다.")
	_expect(int(combo_system.get(&"combo_count")) == 2, \
		"분리 후 재접촉은 콤보를 다시 증가시켜야 한다.")


func _test_inactive_source(combo_system: Node, source: Node) -> void:
	combo_system.call(&"reset_run")
	source.call(&"reset_contacts")
	source.set(&"is_active", false)
	_expect(not bool(source.call(&"register_contact", 202)), \
		"파괴·복구 대기 상태의 소스는 타격을 등록하면 안 된다.")
	_expect(int(combo_system.get(&"combo_count")) == 0, \
		"비활성 소스는 콤보에 영향을 주면 안 된다.")
	source.set(&"is_active", true)
	_expect(bool(source.call(&"register_contact", 202)), \
		"복구된 소스는 새로운 타격을 다시 등록할 수 있어야 한다.")


func _test_unbinding(combo_system: Node, source: Node) -> void:
	combo_system.call(&"reset_run")
	source.call(&"reset_contacts")
	combo_system.call(&"unbind_hit_source", source)
	_expect(bool(source.call(&"register_contact", 303)), \
		"연결 해제 후에도 소스 자체는 유효 타격을 판정해야 한다.")
	_expect(int(combo_system.get(&"combo_count")) == 0, \
		"연결 해제된 소스는 콤보 시스템을 변경하면 안 된다.")


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON, \
		"%s (expected=%s, actual=%s)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: combo_hit_source_test")
		quit(0)
		return
	print("FAIL: combo_hit_source_test (%d failures)" % _failures.size())
	quit(1)
