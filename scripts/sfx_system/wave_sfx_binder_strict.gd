class_name WaveSfxBinderStrict
extends WaveSfxBinder


## 시그널을 **이름만으로** 잇지 않고 **인자 수까지 맞을 때만** 잇는 바인더입니다.
##
## 부모 WaveSfxBinder 는 "시그널 이름이 있으면 그 노드가 우리가 원하는 노드"라는
## 전제로 훑습니다. 그런데 `ball_launched` 는 두 노드가 서로 다른 모양으로 갖고 있습니다.
##
##   PinballLauncher.ball_launched(ball, direction, speed)          ← 핸들러가 원하는 것
##   WaveBallFlowController.ball_launched(ball, remaining_balls)    ← 인자 2개
##
## 둘 다 이어 버리면 후자가 울릴 때마다
## "Method expected 3 argument(s), but called with 2" 런타임 에러가 나고 발사음이 끊깁니다.
## 인자 수가 다르면 아예 잇지 않아 엉뚱한 노드를 걸러냅니다.
##
## 기존 스크립트는 고치지 않고 이 상속 스크립트를 씬에서 씁니다.


func _connect_once(node: Node, signal_name: StringName, target: Callable) -> bool:
	if not node.has_signal(signal_name):
		return false

	if not _arity_matches(node, signal_name, target):
		return false

	return super(node, signal_name, target)


## 시그널이 넘기는 인자 수와 핸들러가 받는 인자 수가 같은지 봅니다.
func _arity_matches(node: Node, signal_name: StringName, target: Callable) -> bool:
	var signal_arg_count := -1
	for entry: Dictionary in node.get_signal_list():
		if StringName(entry.get("name", "")) != signal_name:
			continue
		signal_arg_count = (entry.get("args", []) as Array).size()
		break

	if signal_arg_count < 0:
		return false

	# 기본값이 있는 인자는 생략할 수 있으므로 허용 구간으로 본다.
	var maximum := target.get_argument_count()
	var minimum := maximum - target.get_bound_arguments_count()
	return signal_arg_count >= minimum and signal_arg_count <= maximum
