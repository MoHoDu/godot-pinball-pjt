class_name CoinWallet
extends Node


## 세션 코인 지갑입니다. 잔액 보관과 가감만 담당합니다.
##
## 획득 출처(보드 코인·유예 환산)는 CoinFieldController와
## WaveClearDelayController가 구분해 알려 줍니다. 지갑은 출처를 모릅니다.
## 기획서 「보상 구매·코인·수리 부품 배치 시스템 v0.2」 3장.


signal wallet_changed(balance: int, delta: int)


var _balance := 0


var balance: int:
	get:
		return _balance


## 잔액을 더하고 반영 후 잔액을 돌려줍니다. 음수 입력은 무시합니다.
func add(amount: int) -> int:
	if amount <= 0:
		return _balance
	_balance += amount
	wallet_changed.emit(_balance, amount)
	return _balance


## 잔액이 충분할 때만 차감합니다. 구매 검사 5단계(차감·지급 동일 프레임)의 토대입니다.
func try_spend(amount: int) -> bool:
	if amount <= 0 or amount > _balance:
		return false
	_balance -= amount
	wallet_changed.emit(_balance, -amount)
	return true


func can_afford(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


## 스테이지 전환·실패 롤백에서 사용합니다.
func reset(next_balance := 0) -> void:
	var delta := next_balance - _balance
	_balance = maxi(next_balance, 0)
	if delta != 0:
		wallet_changed.emit(_balance, delta)
