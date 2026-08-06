@tool
class_name BumperSfxRules
extends Resource
## 범퍼 SFX 규칙입니다. 기획서의 3층 구조 중 **재질음**을 다룹니다.
##
##   어택(공통) + 재질음(범퍼마다 다름) + 기능 악센트(파괴·리스폰)
##
## ★ 5종이 서로 확실히 갈려야 합니다.
##   음색이 겹치면 무엇을 맞혔는지 화면을 봐야 압니다. 소리만으로
##   단추(딱) / 솜(푹) / 용수철(끽팡) / 북(통) / 대포(철컥)가 갈려야 합니다.
##
## ★ 종류는 `BumperSettings.bumper_kind_id` 로 알아봅니다.
##   씬 이름이나 노드 경로로 알아보면 배치가 바뀔 때 조용히 무음이 됩니다.


## 종류를 못 알아봤을 때 쓰는 큐입니다. 무음보다는 낫습니다.
@export_category("범퍼 SFX")

@export_group("재질음 — 종류별")

## 단추 범퍼. 딱.
@export var button_cue: SfxCue

## 솜 범퍼. 푹 — 소리를 먹습니다.
@export var cotton_cue: SfxCue

## 용수철 인형. 끽 + 팡.
@export var spring_doll_cue: SfxCue

## 장난감 북. 통.
@export var toy_drum_cue: SfxCue

## 태엽 장난감 대포에 부딪혔을 때.
@export var cannon_cue: SfxCue

## 위 어디에도 안 걸린 범퍼용입니다. 새 범퍼가 늘어도 무음이 되지 않습니다.
@export var fallback_cue: SfxCue


@export_group("기능 악센트")

## 내구도가 다해 부서질 때. 종류와 무관하게 공통입니다.
@export var destroy_cue: SfxCue

## 다시 나타나기 전 예고. 작아야 합니다 — 알림이지 사건이 아닙니다.
@export var respawn_telegraph_cue: SfxCue


@export_group("태엽 대포 조작")

## 대포가 공을 물어 조준을 시작할 때. 철컥.
@export var cannon_control_cue: SfxCue

## 대포가 공을 쏠 때. 팡.
@export var cannon_fire_cue: SfxCue


## `bumper_kind_id` 에 맞는 재질음입니다.
##
## settings/bumpers/stage_01/*.tres 에 적힌 값과 맞춰야 합니다.
## 새 범퍼가 생기면 여기에 한 줄을 더하거나, 안 더해도 fallback 이 웁니다.
func get_material_cue(kind_id: StringName) -> SfxCue:
	match kind_id:
		&"stage01_button":
			return button_cue if button_cue != null else fallback_cue
		&"stage01_cotton":
			return cotton_cue if cotton_cue != null else fallback_cue
		&"stage01_spring_doll":
			return spring_doll_cue if spring_doll_cue != null else fallback_cue
		&"stage01_toy_drum":
			return toy_drum_cue if toy_drum_cue != null else fallback_cue
		&"stage01_clockwork_cannon":
			return cannon_cue if cannon_cue != null else fallback_cue

	return fallback_cue


## 범퍼 노드에서 종류 id 를 꺼냅니다.
##
## ★ `settings` 는 `@export_storage` 라 인스펙터에 안 보이지만 런타임에는 있습니다.
##   없을 수도 있으므로(테스트용 맨 범퍼 등) 빈 값을 돌려주고, 그때는
##   fallback 이 웁니다. 여기서 죽으면 범퍼 소리가 통째로 사라집니다.
static func kind_id_of(bumper: Node) -> StringName:
	if bumper == null:
		return &""

	var settings: Variant = bumper.get(&"settings")
	if settings == null:
		return &""

	var kind: Variant = settings.get(&"bumper_kind_id")
	return kind if kind is StringName else &""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if fallback_cue == null:
		warnings.append("대체 큐가 없으면 새 범퍼가 조용히 무음이 됩니다.")

	# 5종이 겹치면 무엇을 맞혔는지 소리로 알 수 없습니다.
	var seen: Array[AudioStream] = []
	for cue: SfxCue in [button_cue, cotton_cue, spring_doll_cue,
			toy_drum_cue, cannon_cue]:
		if cue == null or cue.streams.is_empty():
			continue

		if seen.has(cue.streams[0]):
			warnings.append("범퍼 5종의 음원이 겹칩니다. 무엇을 맞혔는지 알 수 없습니다.")
			break

		seen.append(cue.streams[0])

	return warnings
