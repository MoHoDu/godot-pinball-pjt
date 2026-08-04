@tool
class_name BallVfxProfile
extends Resource
## 공 한 종류가 쓰는 VFX 리소스를 한 덩어리로 묶은 프로필입니다.
##
## 공이 늘어날 때마다 씬 인스펙터에서 규칙·텍스처를 따로따로 꽂으면
## 빠뜨린 슬롯이 생기고 어느 공이 무엇을 쓰는지 한눈에 안 보입니다.
## 프로필 하나만 갈아끼우면 그 공의 연출이 통째로 바뀌도록 모아둡니다.
##
## 우선순위는 **씬에 직접 꽂은 값 > 프로필 > 기본값** 입니다.
## 연출 노드(BallGlowOutline / BallTrail)가 _ready() 에서 한 번만 프로필을 읽으므로,
## 코드로 프로필을 넣을 때는 반드시 add_child() **전에** 대입해야 합니다.
##
## 관련 문서: docs/ai_memory/project_ball_vfx_profile.md


## 공 식별자입니다. 로그와 테스트에서 어느 프로필인지 가리키는 데 씁니다.
@export var ball_id: StringName = &""

## 화면에 띄울 한글 이름입니다. 테스트 씬 HUD에서 씁니다.
@export var display_name: String = ""


@export_group("공 본체")

## 공 껍질 그림입니다. `Visual/Sprite2D` 의 텍스처를 대신합니다.
##
## 알파 경계상자가 캔버스와 정확히 같아야 합니다.
## `refresh_ball_size()` 가 **텍스처의 긴 변**으로 나눠 배율을 내기 때문에,
## 그림 주변에 투명 여백이 있으면 공이 그 비율만큼 작게 그려집니다.
@export var body_texture: Texture2D

## 동공·홍채 그림입니다. 껍질 위에 같은 배율로 겹쳐 그립니다.
##
## 껍질과 같은 캔버스(1024×1024)에 제자리로 그려져 있어야 합니다.
## 위치를 따로 계산하지 않고 껍질과 같은 변환을 씁니다.
## 비우면 동공 스프라이트를 만들지 않습니다.
@export var pupil_texture: Texture2D


@export_group("규칙")

## VFX ① 발광 테두리(안개 오라) 규칙입니다. 비우면 기본 규칙을 씁니다.
@export var glow_rules: BallGlowOutlineRules

## VFX ② 이동 꼬리 규칙입니다. 비우면 기본 규칙을 씁니다.
@export var trail_rules: BallTrailRules


@export_group("아트")

## VFX ③ 패링 원형 파동 텍스처입니다. ※ 아직 소비하는 시스템이 없습니다.
@export var parry_ring: Texture2D

## 충돌 스파크 텍스처입니다. ※ 아직 소비하는 시스템이 없습니다.
@export var hit_spark: Texture2D

## 콤보 별 텍스처입니다. ※ 아직 소비하는 시스템이 없습니다.
@export var combo_star: Texture2D

## 공별 파티클 조각입니다. ※ 아직 소비하는 시스템이 없습니다.
@export var particles: Array[Texture2D] = []


## 규칙이 하나라도 들어 있는지입니다. 둘 다 비면 프로필을 꽂아도 보이는 변화가 없습니다.
func has_any_rules() -> bool:
	return glow_rules != null or trail_rules != null


## 공 본체 그림이 들어 있는지입니다. 없으면 씬에 박힌 기본 공 그림을 그대로 씁니다.
func has_body_art() -> bool:
	return body_texture != null


## 아트가 하나라도 들어 있는지입니다.
func has_any_art() -> bool:
	return (
		body_texture != null
		or pupil_texture != null
		or parry_ring != null
		or hit_spark != null
		or combo_star != null
		or not particles.is_empty()
	)


## 비어 있는 슬롯 이름 목록입니다.
##
## Resource 에는 _get_configuration_warnings() 가 없습니다(Node 전용).
## 그래서 경고를 자동으로 띄우지 못하고, 테스트에서 이 함수를 직접 불러 확인합니다.
func get_missing_slots() -> PackedStringArray:
	var missing := PackedStringArray()
	if body_texture == null:
		missing.append("body_texture")
	if pupil_texture == null:
		missing.append("pupil_texture")
	if glow_rules == null:
		missing.append("glow_rules")
	if trail_rules == null:
		missing.append("trail_rules")
	if parry_ring == null:
		missing.append("parry_ring")
	if hit_spark == null:
		missing.append("hit_spark")
	if combo_star == null:
		missing.append("combo_star")
	if particles.is_empty():
		missing.append("particles")

	return missing
