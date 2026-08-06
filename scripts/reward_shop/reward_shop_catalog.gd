class_name RewardShopCatalog
extends Resource


## 상점이 뽑을 수 있는 카드 전체 목록입니다. 공 5종 + 부품 4종. (기획서 4장)


@export var ball_offers: Array[RewardBallOffer] = []
@export var part_offers: Array[RepairPartOffer] = []


func cheapest_ball_price(excluded_ids: Array[StringName] = []) -> int:
	var cheapest := -1
	for offer in ball_offers:
		if offer == null or excluded_ids.has(offer.ball_id):
			continue
		if cheapest < 0 or offer.price < cheapest:
			cheapest = offer.price
	return cheapest


func cheapest_part_price() -> int:
	var cheapest := -1
	for offer in part_offers:
		if offer == null:
			continue
		if cheapest < 0 or offer.price < cheapest:
			cheapest = offer.price
	return cheapest
