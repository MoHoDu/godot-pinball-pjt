@tool
class_name BallSfxLibrary
extends Resource
## 공 종류 → 사운드 프로파일 표입니다.
##
## `BallDefinition` 을 수정하지 않는 이유가 여기 있습니다. 기존 스크립트를 건드리지 않고,
## 기획서가 지정한 필드명(`hit_material_sfx` / `parry_accent_sfx`)은
## BallAudioProfile 안에 그대로 살아 있습니다.


@export_category("공 SFX 라이브러리")

## 모든 공에 적용되는 기본 충돌 큐입니다. 프로파일이 없는 공은 이걸 그대로 씁니다.
@export var default_hit_cue: SfxCue

## 패링 공용 3레이어입니다. 공별로는 2번째 레이어만 악센트로 갈아끼웁니다.
@export var default_parry_cue: SfxCue

@export var profiles: Array[BallAudioProfile] = []


## ball_id 에 맞는 프로파일입니다. 없으면 null.
func find_profile(ball_id: StringName) -> BallAudioProfile:
	for profile: BallAudioProfile in profiles:
		if profile != null and profile.ball_id == ball_id:
			return profile

	return null


## 이 공이 쓸 충돌 큐입니다. 프로파일이 없으면 기본 큐를 씁니다.
func resolve_hit_cue(ball_id: StringName) -> SfxCue:
	var profile := find_profile(ball_id)
	if profile == null:
		return default_hit_cue

	return profile.build_hit_cue(default_hit_cue)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if default_hit_cue == null:
		warnings.append("기본 충돌 큐가 없으면 프로파일 없는 공은 무음입니다.")

	var seen: Dictionary = {}
	for profile: BallAudioProfile in profiles:
		if profile == null:
			continue
		if seen.has(profile.ball_id):
			warnings.append("ball_id '%s' 가 중복입니다." % profile.ball_id)
		seen[profile.ball_id] = true

	return warnings
