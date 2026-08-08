@tool
class_name BgmPlayer
extends AudioStreamPlayer
## 앰비언트 BGM 루프 재생기입니다.
##
## ★ 이 게임의 BGM 은 곡이 아니라 공간의 소리입니다 — 태엽·오르골·낮은
##   공명 3겹을 하나로 섞은 28초 무이음 루프(BGM_Wave_Loop.wav)를
##   그대로 돌립니다. 루프는 파일 임포트(loop_mode=1)가 맡으므로
##   여기서는 시작·음량만 책임집니다.
##
## ★ 가이드 15장 우선순위: 공·패링 > 보스 피격 > 공격 위험음 > 환경음·BGM.
##   파일 자체를 -33dB RMS 로 눌러 뒀지만, 씬에서 더 줄일 일은 있어도
##   **키울 일은 없습니다.** 기본값 0dB 위로 올리지 마세요 —
##   배경음이 공 충돌·패링을 덮는 순간 검수 기준 위반입니다.


const BGM_BUS: StringName = &"BGM"


func _ready() -> void:
	# 인스턴스가 어느 씬에 배치되더라도 설정의 BGM 슬라이더를 우회하지 않습니다.
	bus = BGM_BUS
	if Engine.is_editor_hint():
		return

	# 씬 일시정지 중에도 배경은 흐르는 편이 "공간"답습니다.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if stream != null and not playing:
		play()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if stream == null:
		warnings.append("BGM 스트림이 없습니다. Resources/sfx/bgm/BGM_Wave_Loop.wav 를 물리세요.")

	if volume_db > 0.0:
		warnings.append("BGM 을 키우면 공·패링 소리를 덮습니다 (가이드 15장).")

	if bus != BGM_BUS:
		warnings.append("BgmPlayer 는 설정 시스템의 BGM 버스를 사용해야 합니다.")

	return warnings
