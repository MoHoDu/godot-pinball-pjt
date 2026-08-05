class_name WaveRepairCoordinator
extends WaveShopBallCoordinator


## 상점에서 산 수리 부품을 웨이브 첫 발사 전에 배치하는 조립자입니다. (기획서 8-2, 9장)
##
## WaveShopBallCoordinator(상점+공 해금)를 상속만 하고 기존 스크립트는 수정하지 않습니다.
## 소켓 12개와 RepairPartSystem 서브트리는 씬(wave_repair.tscn)에 있고,
## 배치 컨트롤러와 HUD는 코드로 붙입니다.
##
## 흐름: 웨이브 진입 → (재고가 있으면) 배치 단계 → 첫 발사에 예약 확정·재고 차감 →
##       웨이브 동안 부품 작동 → 종료·실패·재시도 시 보드에서 제거.


## 발사 전 공 선택이 확정될 때마다 발화합니다. (기획서 10-3 ball_selected)
signal ball_selected(wave_id: int, launch_index: int, ball_id: StringName)

## 실패 롤백이 끝나면 발화합니다. (기획서 10-3 stage_state_rolled_back)
signal stage_state_rolled_back(
	stage_id: StringName,
	failure_wave: int,
	snapshot_id: StringName
)


const DEFAULT_PART_SCENE_MAP := preload(
	"res://settings/reward_shop/RepairPartSceneMap_Stage01.tres"
)


@export_category("Wave Repair")

@export var part_scene_map: RepairPartSceneMap = DEFAULT_PART_SCENE_MAP


var repair_board: RepairBoardController
var placement_controller: RepairPlacementController
var placement_hud: RepairPlacementHud

## 스테이지 입장 시점 상태입니다. 실패 시 이대로 복원합니다(10-1).
var stage_entry_snapshot: StageEntrySnapshot

## 이번 웨이브에서 몇 번째 발사인지 셉니다. ball_selected 인자용입니다.
var _launch_index := 0


func _ready() -> void:
	super()
	_build_repair_placement()
	_build_debug_key_guide()
	wave_ball_flow.ball_selection_confirmed.connect(
		_on_ball_selection_confirmed
	)
	# 스테이지 입장 시점을 기억해 둡니다. 코인 0·해금 없음·부품 이월분 상태.
	stage_entry_snapshot = StageEntrySnapshot.capture(
		&"stage01_entry", coin_wallet, stage_ball_inventory, part_inventory
	)


## 부모의 스테이지 공 인벤토리를 v0.2 모델로 교체합니다. (기획서 7장)
## 해금 공이 생명 슬롯을 차지하지 않고, 보유 한도 없이 무제한 재선택됩니다.
func _build_stage_ball_inventory() -> void:
	stage_ball_inventory = StageBallInventoryV02.new()
	stage_ball_inventory.name = "StageBallInventory"
	stage_ball_inventory.scene_map = ball_scene_map
	add_child(stage_ball_inventory)
	stage_ball_inventory.capture_base_stock(
		wave_ball_inventory.starting_stock
	)
	stage_ball_inventory.unlocked_balls_changed.connect(_on_unlocked_changed)
	shop_controller.ball_unlocked.connect(_on_ball_unlocked)


## 해금 실패 시 결제를 되돌립니다. (기획서 6-3 검사⑤ — 차감·지급 원자성)
func _on_ball_unlocked(ball_id: StringName) -> void:
	if stage_ball_inventory.unlock(ball_id):
		return
	var refund := _catalog_ball_price_of(ball_id)
	if refund > 0:
		coin_wallet.add(refund)
	var remaining_ids := shop_controller.unlocked_ball_ids
	remaining_ids.erase(ball_id)
	shop_controller.reset_unlocked_balls(remaining_ids)
	_append_event("구매 롤백 · %s 해금 실패 · +%d코인 반환" % [ball_id, refund])


func _on_unlocked_changed(unlocked_ids: Array[StringName]) -> void:
	super(unlocked_ids)
	_sync_unlocked_ball_types()


## 해금 종류 목록을 v0.2 인벤토리에 반영합니다. 다음 웨이브부터 선택됩니다.
func _sync_unlocked_ball_types() -> void:
	var inventory_v02 := wave_ball_inventory as WaveBallInventoryV02
	var stage_v02 := stage_ball_inventory as StageBallInventoryV02
	if inventory_v02 == null or stage_v02 == null:
		return
	inventory_v02.set_unlocked_definitions(stage_v02.unlocked_definitions())


func _on_ball_selection_confirmed(
	definition: BallDefinition,
	_remaining: int
) -> void:
	if definition == null:
		return
	ball_selected.emit(
		wave_manager.current_wave_index, _launch_index, definition.ball_id
	)
	_launch_index += 1


func _catalog_ball_price_of(ball_id: StringName) -> int:
	if shop_catalog == null:
		return 0
	for offer in shop_catalog.ball_offers:
		if offer != null and offer.ball_id == ball_id:
			return offer.price
	return 0


func _build_repair_placement() -> void:
	repair_board = get_node_or_null(
		^"RepairPartSystem/RepairBoardController"
	) as RepairBoardController
	assert(
		repair_board != null,
		"wave_repair 씬에는 RepairPartSystem/RepairBoardController가 필요합니다."
	)

	placement_controller = RepairPlacementController.new()
	placement_controller.name = "RepairPlacementController"
	add_child(placement_controller)
	var bound := placement_controller.bind(
		repair_board, part_inventory, part_scene_map
	)
	assert(bound, "배치 컨트롤러가 보드·인벤토리에 연결되지 못했습니다.")

	# 상점 레이어(25)보다 아래, 기본 HUD보다 위에 둡니다.
	var placement_layer := CanvasLayer.new()
	placement_layer.name = "RepairPlacementLayer"
	placement_layer.layer = 24
	add_child(placement_layer)
	placement_hud = RepairPlacementHud.new()
	placement_hud.name = "RepairPlacementHud"
	placement_layer.add_child(placement_hud)
	var hud_bound := placement_hud.bind(
		placement_controller, part_inventory, part_scene_map
	)
	assert(hud_bound, "배치 HUD가 컨트롤러에 연결되지 못했습니다.")

	wave_ball_flow.ball_launched.connect(_on_repair_ball_launched)
	wave_manager.wave_entered.connect(_on_repair_wave_entered)
	wave_manager.wave_retried.connect(_on_repair_wave_retried)
	wave_manager.wave_won.connect(_on_repair_wave_won)
	wave_manager.wave_lost.connect(_on_repair_wave_lost)
	placement_controller.repair_layout_committed.connect(
		_on_repair_layout_committed
	)

	# 첫 웨이브는 부모 _ready()의 enter_wave()가 이미 지나갔으므로 직접 엽니다.
	if wave_manager.current_state != WaveManager.State.INACTIVE:
		_try_begin_placement()


## 테스트용 조작키 안내를 화면 우측 상단에 항상 표시합니다.
func _build_debug_key_guide() -> void:
	var guide_layer := CanvasLayer.new()
	guide_layer.name = "DebugKeyGuideLayer"
	guide_layer.layer = 23
	add_child(guide_layer)
	var guide_label := Label.new()
	guide_label.name = "DebugKeyGuideLabel"
	guide_label.text = "\n".join(PackedStringArray([
		"[테스트 키]",
		"C 코인 999 (디버그) · G 즉시 클리어 (디버그)",
		"공 선택 A/D · Space 조준 → Space 발사",
		"클리어 선택 B 클리어 · V 남은 공 계속",
		"상점 A/D 이동 · Space 선택→구매 · B 다음 단계",
		"배치 Q/E 소켓 · 1~4 부품 예약/해제 · X 해제",
	]))
	guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	guide_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	guide_label.add_theme_font_size_override(&"font_size", 18)
	guide_label.add_theme_color_override(
		&"font_color", Color(0.78, 0.82, 0.86)
	)
	guide_label.add_theme_color_override(
		&"font_outline_color", Color(0.05, 0.06, 0.08)
	)
	guide_label.add_theme_constant_override(&"outline_size", 5)
	guide_layer.add_child(guide_label)
	guide_label.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16
	)


func _try_begin_placement() -> void:
	if placement_controller.begin_placement(wave_manager.current_wave_index):
		_append_event("배치 · Q/E 소켓 · 1~4 부품 예약 · X 해제")


## 첫 발사가 확정되는 순간 예약을 소비 처리합니다(8-2).
func _on_repair_ball_launched(_ball: Pinball, _remaining_balls: int) -> void:
	if placement_controller.is_open:
		placement_controller.commit_layout()


func _on_repair_wave_entered(
	_stage_id: StringName,
	_wave_index: int,
	_target_score: int
) -> void:
	_launch_index = 0
	placement_controller.clear_board()
	_try_begin_placement()


## 재시도 시 이전 배치는 소멸하고, 남은 재고로 다시 배치할 수 있습니다(10-1).
func _on_repair_wave_retried() -> void:
	placement_controller.finish_placement()
	placement_controller.clear_board()
	_try_begin_placement()


func _on_repair_wave_won(_current_score: int, _target_score: int) -> void:
	placement_controller.finish_placement()
	placement_controller.clear_board()


## 실패하면 스테이지 진입 시점으로 롤백하고 일반 웨이브 1부터 재시작합니다(1장·10-1).
func _on_repair_wave_lost(_current_score: int, _target_score: int) -> void:
	placement_controller.finish_placement()
	placement_controller.clear_board()
	# 시그널 체인 안에서 enter_wave를 부르지 않도록 지연 호출합니다.
	call_deferred(&"_rollback_to_stage_entry")


func _rollback_to_stage_entry() -> void:
	if wave_manager.current_state != WaveManager.State.LOST:
		return
	var failure_wave := wave_manager.current_wave_index
	var snapshot := stage_entry_snapshot

	# 코인·해금 공·부품을 스냅샷 전체로 복원합니다(개별 역산 없음).
	coin_wallet.reset(snapshot.coin_balance)
	part_inventory.restore(snapshot.part_counts)
	var stage_v02 := stage_ball_inventory as StageBallInventoryV02
	if stage_v02 != null:
		stage_v02.restore_unlocked(snapshot.unlocked_ball_ids)
	shop_controller.reset_unlocked_balls(snapshot.unlocked_ball_ids)
	wave_ball_inventory.starting_stock = stage_ball_inventory.build_stock()

	# 일반 웨이브 1부터 재시작. 점수는 0에서 시작합니다.
	combo_system.reset_wave()
	if wave_manager.enter_wave(_wave_settings, 0, true):
		_append_event("실패 · 스테이지 진입 상태로 롤백 · 웨이브 01 재시작")
	stage_state_rolled_back.emit(
		StringName(_wave_settings.get(&"stage_id")),
		failure_wave,
		snapshot.snapshot_id
	)


## 스테이지 클리어 시 코인을 0으로 초기화합니다(10-1).
## 기본 공 복귀는 부모가, 미사용 부품 유지는 인벤토리가 그대로 담당합니다.
func _open_shop_after_win() -> void:
	super()
	var next_wave_index := wave_manager.current_wave_index + 1
	if not _has_wave(next_wave_index):
		coin_wallet.reset(0)
		shop_controller.reset_unlocked_balls()
		_append_event("스테이지 정산 · 코인 0 · 미사용 부품 %d개 이월" % [
			part_inventory.total_count
		])


func _on_repair_layout_committed(
	_wave_id: int,
	layout: Dictionary,
	consumed_counts: Dictionary
) -> void:
	var total := 0
	for part_id: StringName in consumed_counts:
		total += int(consumed_counts[part_id])
	if total > 0:
		_append_event("배치 확정 · 부품 %d개 소비 · 소켓 %d곳" % [
			total, layout.size()
		])
