@tool
class_name BallFlowSfxRules
extends Resource
## 공의 생애 SFX 규칙입니다 — 발사와 낙하.
##
## 두 소리는 웨이브당 몇 번 안 나지만 **흐름의 시작과 끝을 표시합니다.**
## 발사가 없으면 공이 언제 떠났는지 모르고, 낙하가 없으면 잃은 줄 모릅니다.
##
## ★ 발사음의 세기는 파일이 아니라 **당긴 힘(speed)** 이 정합니다.
##   `PinballLauncher.ball_launched(ball, direction, speed)` 가 speed 를 줍니다.
##   살짝 당긴 것과 끝까지 당긴 것이 같은 소리면 조작 피드백이 죽습니다.


## 발사 세기를 음량으로 옮길 때 쓰는 속도 범위입니다.
## 공 기본 발사 속도 700px/s, 최대 2000px/s 를 감안해 잡았습니다.
const DEFAULT_MIN_LAUNCH_SPEED: float = 300.0
const DEFAULT_MAX_LAUNCH_SPEED: float = 2000.0


@export_category("공 흐름 SFX")

## 공을 쏘는 순간. 태엽이 풀리며 튕겨나갑니다.
@export var launch_cue: SfxCue

## 공을 잃는 순간. 가라앉는 느낌이어야 합니다.
@export var drain_cue: SfxCue

## 웨이브 시작 시 쓸 공을 고를 때. 조작 확인음이라 짧고 작습니다.
## `WaveBallFlowController.ball_selection_confirmed` 에 물립니다.
@export var select_cue: SfxCue


@export_group("발사 세기")

## 이 속도에서 가장 작게 울립니다.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s")
var minimum_launch_speed: float = DEFAULT_MIN_LAUNCH_SPEED

## 이 속도에서 가장 크게 울립니다.
@export_range(0.0, 4000.0, 10.0, "suffix:px/s")
var maximum_launch_speed: float = DEFAULT_MAX_LAUNCH_SPEED


## 발사 큐에 넘길 속도입니다.
##
## `SfxCue` 가 자기 `speed_reference_range` 로 음량을 계산하므로 여기서는
## 값을 그대로 넘깁니다. 범위를 두 곳에서 곱하면 이중 적용이 됩니다.
func get_launch_speed(speed: float) -> float:
	return clampf(speed, minimum_launch_speed, maximum_launch_speed)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if launch_cue == null:
		warnings.append("발사음이 없으면 공이 언제 떠났는지 알 수 없습니다.")

	if drain_cue == null:
		warnings.append("낙하음이 없으면 공을 잃은 것을 소리로 모릅니다.")

	if minimum_launch_speed >= maximum_launch_speed:
		warnings.append("발사 세기 범위가 뒤집혔습니다. 음량이 항상 같아집니다.")

	return warnings
