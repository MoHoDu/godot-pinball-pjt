@tool
class_name WaveRuntimeCoordinatorFullBleedTool
extends WaveRuntimeCoordinatorFullBleed
## WaveAuthoringTools의 Inspector 버튼이 에디터에서 코디네이터 메서드
## (sync_expected_bumper_roster, set_bumper_disabled 등)를 호출할 수 있도록
## @tool로 실체화한 확장 스크립트.
##
## 부모 스크립트에 @tool이 없으면 에디터에서 이 노드가 placeholder 인스턴스가
## 되어 도구의 모든 범퍼 버튼이 "Attempt to call a method on a placeholder
## instance" 오류로 실패한다 (scripts/editor/wave_authoring_tools.gd:94).
##
## 에디터에서는 아래 가드로 런타임 콜백을 전부 차단하므로 게임 로직이 돌지
## 않고, 런타임에서는 부모와 완전히 동일하게 동작한다.
## 프로젝트 규칙에 따라 기존 코디네이터 스크립트는 수정하지 않았다.


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	super._unhandled_input(event)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	super._exit_tree()
