@tool
class_name ComboRules
extends Resource


enum Tier {
	NONE,
	NORMAL,
	SUPER,
	HYPER,
	ULTRA,
}


@export_category("콤보 공용 설정")

@export_group("유지 시간")

## 마지막 유효 충돌 뒤 콤보가 유지되는 시간입니다.
@export_range(0.1, 30.0, 0.1, "suffix:s")
var hold_time: float = 3.0:
	set(value):
		hold_time = maxf(value, 0.1)
		emit_changed()


@export_group("단계 시작 횟수")

@export_range(2, 100, 1)
var super_start_count: int = 11:
	set(value):
		super_start_count = maxi(value, 2)
		emit_changed()

@export_range(3, 100, 1)
var hyper_start_count: int = 21:
	set(value):
		hyper_start_count = maxi(value, super_start_count + 1)
		emit_changed()

@export_range(4, 100, 1)
var ultra_start_count: int = 36:
	set(value):
		ultra_start_count = maxi(value, hyper_start_count + 1)
		emit_changed()


@export_group("점수 배율")

@export_range(0.0, 100.0, 0.1, "suffix:x")
var normal_score_multiplier: float = 1.0

@export_range(0.0, 100.0, 0.1, "suffix:x")
var super_score_multiplier: float = 5.0

@export_range(0.0, 100.0, 0.1, "suffix:x")
var hyper_score_multiplier: float = 10.0

@export_range(0.0, 100.0, 0.1, "suffix:x")
var ultra_score_multiplier: float = 20.0


@export_group("보스 피해 배율")

@export_range(0.0, 10.0, 0.01, "suffix:x")
var normal_damage_multiplier: float = 1.0

@export_range(0.0, 10.0, 0.01, "suffix:x")
var super_damage_multiplier: float = 1.25

@export_range(0.0, 10.0, 0.01, "suffix:x")
var hyper_damage_multiplier: float = 1.6

@export_range(0.0, 10.0, 0.01, "suffix:x")
var ultra_damage_multiplier: float = 2.0

## 첫 충돌 이후 콤보 1회가 늘 때마다 더해지는 피해 배율입니다.
@export_range(0.0, 1.0, 0.001, "suffix:x")
var damage_growth_per_hit: float = 0.025

## 피해의 횟수 계수가 더 증가하지 않는 최대 콤보입니다.
@export_range(1, 1000, 1)
var damage_combo_cap: int = 40


func get_tier(combo_count: int) -> Tier:
	if combo_count <= 0:
		return Tier.NONE
	if combo_count >= ultra_start_count:
		return Tier.ULTRA
	if combo_count >= hyper_start_count:
		return Tier.HYPER
	if combo_count >= super_start_count:
		return Tier.SUPER
	return Tier.NORMAL


func get_tier_label(tier: Tier) -> String:
	match tier:
		Tier.NORMAL:
			return "Normal"
		Tier.SUPER:
			return "Super"
		Tier.HYPER:
			return "Hyper"
		Tier.ULTRA:
			return "Ultra"
		_:
			return "None"


func get_score_multiplier(tier: Tier) -> float:
	match tier:
		Tier.NORMAL:
			return maxf(normal_score_multiplier, 0.0)
		Tier.SUPER:
			return maxf(super_score_multiplier, 0.0)
		Tier.HYPER:
			return maxf(hyper_score_multiplier, 0.0)
		Tier.ULTRA:
			return maxf(ultra_score_multiplier, 0.0)
		_:
			return 0.0


func get_damage_stage_multiplier(tier: Tier) -> float:
	match tier:
		Tier.NORMAL:
			return maxf(normal_damage_multiplier, 0.0)
		Tier.SUPER:
			return maxf(super_damage_multiplier, 0.0)
		Tier.HYPER:
			return maxf(hyper_damage_multiplier, 0.0)
		Tier.ULTRA:
			return maxf(ultra_damage_multiplier, 0.0)
		_:
			return 0.0


## 콤보 하나가 종료될 때 유효 타격 가중치 합계로 한 번 정산합니다.
func calculate_score(
	stage_base_score: int,
	total_score_weight: float,
	combo_count: int
) -> int:
	var tier := get_tier(combo_count)
	return roundi(
		maxi(stage_base_score, 0)
		* maxf(total_score_weight, 0.0)
		* get_score_multiplier(tier)
	)


## 기본 피해에 현재 콤보 횟수 계수와 단계 계수를 적용합니다.
func calculate_damage(base_damage: float, combo_count: int) -> int:
	if base_damage <= 0.0 or combo_count <= 0:
		return 0

	var capped_count := mini(combo_count, maxi(damage_combo_cap, 1))
	var count_multiplier := 1.0 + maxf(damage_growth_per_hit, 0.0) \
		* maxi(capped_count - 1, 0)
	var stage_multiplier := get_damage_stage_multiplier(get_tier(combo_count))
	return roundi(base_damage * count_multiplier * stage_multiplier)


## 보스 체력, 목표 유효 타격 횟수, 공 무게 계수로 기본 피해를 구합니다.
func calculate_base_damage(
	boss_health: float,
	target_hit_count: int,
	ball_weight_multiplier: float
) -> float:
	if boss_health <= 0.0 or target_hit_count <= 0:
		return 0.0
	return boss_health / target_hit_count * maxf(ball_weight_multiplier, 0.0)
