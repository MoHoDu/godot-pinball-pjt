@tool
class_name RelicEffect
extends Resource


## 유물 효과의 공통 인터페이스입니다.
## 값 변경은 반드시 RelicRuntime을 거칩니다. RelicRuntime이 기준값을 스냅샷해 두기 때문에
## 스택이 쌓여도 항상 "기준값 × 배율"로 다시 계산되고, 세션이 끝나면 원래 값으로 복원됩니다.
## 공유 리소스(.tres)를 직접 누적 연산하면 플레이를 반복할 때 값이 계속 부풀어 오릅니다.


## stack_count는 현재 보유 개수입니다. 누적이 아니라 매번 기준값에서 다시 계산합니다.
func apply(_runtime: RelicRuntime, _stack_count: int) -> bool:
	push_warning("RelicEffect.apply()를 재정의하지 않았습니다: %s" % resource_path)
	return false


## 선택 카드에 표시할 효과 설명입니다.
func describe(_stack_count: int = 1) -> String:
	return ""
