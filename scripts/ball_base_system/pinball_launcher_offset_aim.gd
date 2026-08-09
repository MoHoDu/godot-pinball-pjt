class_name PinballLauncherOffsetAim
extends PinballLauncher
## 무입력 발사가 정중앙 수직(0°)이 되지 않게 하는 확장 발사대.
##
## 기본 조준각을 옆으로 틀어 두고, 0° 주변에는 선택 불가 데드존을 둔다.
## 생각 없이 바로 확정하면 공이 중앙 기둥으로 올라갔다가 하단 플리퍼 사이
## 갭으로 그대로 떨어져 죽는 문제 방지 (2026-08-09 형락님 지시).
## 기존 pinball_launcher.gd는 수정하지 않았다.


## 조준을 시작할 때 선택되는 기본 각도. 0이 아니어야 무입력 발사가 중앙을 피한다.
@export_range(-45.0, 45.0, 1.0, "suffix:°")
var default_launch_angle_degrees := 12.0

## 이 절대각 미만(정중앙 부근)은 선택 불가. 조준으로 지나가면 반대쪽으로 건너뛴다.
@export_range(0.0, 20.0, 0.5, "suffix:°")
var center_dead_zone_degrees := 6.0


func set_current_angle(value: float) -> void:
	var adjusted := value
	if absf(adjusted) < center_dead_zone_degrees:
		adjusted = (
			center_dead_zone_degrees
			if adjusted >= current_angle_degrees
			else -center_dead_zone_degrees
		)
	super.set_current_angle(adjusted)


func _reset_selection() -> void:
	super._reset_selection()
	set_current_angle(default_launch_angle_degrees)
