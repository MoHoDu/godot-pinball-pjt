@tool
class_name AmbientDecorRules
extends Resource
## 배경 데코 애니메이션(별 반짝임·구름 숨쉬기)의 배치·타이밍 규칙입니다.
##
## 모든 패치는 원본 배경(cursed_circus_outside_background.png)에서 잘라낸
## 조각이라 색감·명도·채도가 원본과 완전히 일치합니다.
## 재추출은 docs/ambient_guides/extract_bg_decor.py 로 합니다.
##
## 강도의 대원칙: **배경 장식이 공·플리퍼보다 눈에 띄면 FAIL**.
## 별 글린트는 성공·보상 기능색(금색 스파크)과 혼동되지 않게 은은해야 합니다.


const DECOR_DIR := "res://Resources/Art/backgrounds/ambient_decor/"

const MIN_ALPHA: float = 0.0
const MAX_ALPHA: float = 1.0
## "은은하게"(2026-08-08 지시)와 "얇은 띠에서도 읽혀야 함"(실측) 사이의 값입니다.
const DEFAULT_STAR_MAX_ALPHA: float = 0.65

const MIN_PERIOD: float = 1.0
const MAX_PERIOD: float = 30.0
const DEFAULT_STAR_PERIOD_MIN: float = 3.0
const DEFAULT_STAR_PERIOD_MAX: float = 7.0

const MIN_SHARPNESS: float = 1.0
const MAX_SHARPNESS: float = 6.0
## 클수록 "대부분 꺼져 있다가 이따금 반짝"에 가까워집니다.
const DEFAULT_STAR_SHARPNESS: float = 3.0

const MIN_SPIN_PERIOD: float = 5.0
const MAX_SPIN_PERIOD: float = 120.0
## 별 하나가 한 바퀴 도는 시간 범위. "천천히"(2026-08-08 지시)에 맞춘 값입니다.
const DEFAULT_SPIN_PERIOD_MIN: float = 24.0
const DEFAULT_SPIN_PERIOD_MAX: float = 48.0

const MIN_CLOUD_AMP: float = 0.0
const MAX_CLOUD_AMP: float = 0.05
## 코너 고정이라 확대분은 전부 화면 안쪽으로 들어옵니다.
const DEFAULT_CLOUD_SCALE_AMP: float = 0.018

const MIN_CLOUD_PERIOD: float = 2.0
const MAX_CLOUD_PERIOD: float = 60.0
const DEFAULT_CLOUD_PERIOD: float = 16.0

const MIN_RAY_COUNT: int = 2
const MAX_RAY_COUNT: int = 24
const DEFAULT_RAY_COUNT: int = 8

const MIN_RAY_PERIOD: float = 5.0
const MAX_RAY_PERIOD: float = 180.0
## 밴드 패턴이 한 바퀴 도는 시간. 8밴드면 한 지점을 4.5초마다 광선이 지나갑니다.
const DEFAULT_RAY_PERIOD: float = 36.0

const MIN_RAY_ALPHA: float = 0.0
## 배경 조명이라 상한을 낮게 못 박습니다. 게임보다 눈에 띄면 FAIL.
const MAX_RAY_ALPHA: float = 0.4
const DEFAULT_RAY_MAX_ALPHA: float = 0.15

const MIN_RAY_SHARPNESS: float = 0.5
const MAX_RAY_SHARPNESS: float = 8.0
const DEFAULT_RAY_SHARPNESS: float = 2.0

## 중앙 비움 반지름(반높이=1). 보드가 가리는 안쪽에는 광선을 그리지 않습니다.
const DEFAULT_RAY_FADE_START: float = 0.1
const DEFAULT_RAY_FADE_END: float = 0.35

## 채도 낮춘 아이보리 무대 조명. 금색 스파크(보상 기능색)와 혼동될 채도는 피합니다.
const DEFAULT_RAY_COLOR: Color = Color(0.83, 0.78, 0.62, 1.0)

## 별 패치 중심의 텍스처 픽셀 좌표. extract_bg_decor.py 의 STARS 와 같아야 합니다.
const DEFAULT_STAR_POSITIONS: PackedVector2Array = [
	Vector2(1406.0, 125.0),
	Vector2(1370.0, 857.0),
	Vector2(495.0, 66.0),
	Vector2(1330.0, 140.0),
	Vector2(1590.0, 665.0),
	Vector2(434.0, 866.0),
	Vector2(183.0, 152.0),
	Vector2(205.0, 775.0),
	Vector2(1580.0, 296.0),
	Vector2(125.0, 712.0),
	Vector2(62.0, 546.0),
	Vector2(1638.0, 560.0),
	Vector2(154.0, 827.0),
	Vector2(1528.0, 98.0),
]

## 별마다 3종 세트입니다: Cover(원본 별 지움) / Body(회전 본체) / Glint(반짝임).
## 파일명 규칙이 같아 인덱스로 파생합니다.
const STAR_COVER_PREFIX := DECOR_DIR + "StarCover_"
const STAR_BODY_PREFIX := DECOR_DIR + "StarBody_"
const STAR_GLINT_PREFIX := DECOR_DIR + "StarGlint_"

## 구름 사각형(텍스처 픽셀). extract_bg_decor.py 의 CLOUDS 와 같아야 합니다.
const DEFAULT_CLOUD_ORIGINS: PackedVector2Array = [
	Vector2(0.0, 0.0),
	Vector2(1300.0, 0.0),
	Vector2(0.0, 620.0),
	Vector2(1280.0, 580.0),
]

const DEFAULT_CLOUD_SIZES: PackedVector2Array = [
	Vector2(360.0, 320.0),
	Vector2(372.0, 300.0),
	Vector2(400.0, 321.0),
	Vector2(392.0, 361.0),
]

## 스케일 기준점이 되는 코너입니다. tl/tr/bl/br.
const DEFAULT_CLOUD_PIVOTS: PackedStringArray = ["tl", "tr", "bl", "br"]

const DEFAULT_CLOUD_TEXTURES: PackedStringArray = [
	DECOR_DIR + "Cloud_TL.png",
	DECOR_DIR + "Cloud_TR.png",
	DECOR_DIR + "Cloud_BL.png",
	DECOR_DIR + "Cloud_BR.png",
]


var _star_max_alpha: float = DEFAULT_STAR_MAX_ALPHA
var _star_period_min_s: float = DEFAULT_STAR_PERIOD_MIN
var _star_period_max_s: float = DEFAULT_STAR_PERIOD_MAX
var _star_sharpness: float = DEFAULT_STAR_SHARPNESS
var _star_spin_period_min_s: float = DEFAULT_SPIN_PERIOD_MIN
var _star_spin_period_max_s: float = DEFAULT_SPIN_PERIOD_MAX
var _cloud_scale_amp: float = DEFAULT_CLOUD_SCALE_AMP
var _cloud_period_s: float = DEFAULT_CLOUD_PERIOD
var _ray_count: int = DEFAULT_RAY_COUNT
var _ray_period_s: float = DEFAULT_RAY_PERIOD
var _ray_max_alpha: float = DEFAULT_RAY_MAX_ALPHA
var _ray_sharpness: float = DEFAULT_RAY_SHARPNESS


@export_category("배경 데코")

@export_group("별 반짝임")

## 글린트 최대 알파입니다. 보상 스파크와 혼동되지 않게 낮게 유지합니다.
@export_range(0.0, 1.0, 0.01)
var star_max_alpha: float:
	get:
		return _star_max_alpha
	set(value):
		_star_max_alpha = clampf(value, MIN_ALPHA, MAX_ALPHA)
		emit_changed()

## 별마다 이 범위 안에서 서로 다른 주기를 갖습니다.
@export_range(1.0, 30.0, 0.5, "suffix:s")
var star_period_min_s: float:
	get:
		return _star_period_min_s
	set(value):
		_star_period_min_s = clampf(value, MIN_PERIOD, MAX_PERIOD)
		emit_changed()

@export_range(1.0, 30.0, 0.5, "suffix:s")
var star_period_max_s: float:
	get:
		return _star_period_max_s
	set(value):
		_star_period_max_s = clampf(value, MIN_PERIOD, MAX_PERIOD)
		emit_changed()

## 클수록 "대부분 꺼져 있다가 이따금 반짝"이 됩니다. 1이면 계속 오르내립니다.
@export_range(1.0, 6.0, 0.1)
var star_sharpness: float:
	get:
		return _star_sharpness
	set(value):
		_star_sharpness = clampf(value, MIN_SHARPNESS, MAX_SHARPNESS)
		emit_changed()

## 별 자체 회전을 켜고 끕니다.
@export var star_spin_enabled: bool = true

## 별마다 이 범위 안에서 서로 다른 회전 주기를 갖습니다. 방향은 번호별로 엇갈립니다.
@export_range(5.0, 120.0, 1.0, "suffix:s")
var star_spin_period_min_s: float:
	get:
		return _star_spin_period_min_s
	set(value):
		_star_spin_period_min_s = clampf(value, MIN_SPIN_PERIOD, MAX_SPIN_PERIOD)
		emit_changed()

@export_range(5.0, 120.0, 1.0, "suffix:s")
var star_spin_period_max_s: float:
	get:
		return _star_spin_period_max_s
	set(value):
		_star_spin_period_max_s = clampf(value, MIN_SPIN_PERIOD, MAX_SPIN_PERIOD)
		emit_changed()


@export_group("구름 숨쉬기")

## 구름 숨쉬기를 켜고 끕니다. 2026-08-08 형락님 지시로 별만 남기고 껐습니다.
@export var clouds_enabled: bool = false

## 숨쉬기 확대량입니다. 코너 고정이라 1.0 밑으로 내려가지 않아 고스트가 없습니다.
@export_range(0.0, 0.05, 0.001, "suffix:x")
var cloud_scale_amp: float:
	get:
		return _cloud_scale_amp
	set(value):
		_cloud_scale_amp = clampf(value, MIN_CLOUD_AMP, MAX_CLOUD_AMP)
		emit_changed()

## 한 번 숨쉬는 주기입니다.
@export_range(2.0, 60.0, 0.5, "suffix:s")
var cloud_period_s: float:
	get:
		return _cloud_period_s
	set(value):
		_cloud_period_s = clampf(value, MIN_CLOUD_PERIOD, MAX_CLOUD_PERIOD)
		emit_changed()


@export_group("회전 조명 광선")

## 광선을 켜고 끕니다. 2026-08-08 형락님 지시로 껐습니다 — 별만 남깁니다.
@export var rays_enabled: bool = false

## 광선 밴드 수입니다.
@export_range(2, 24, 1)
var ray_count: int:
	get:
		return _ray_count
	set(value):
		_ray_count = clampi(value, MIN_RAY_COUNT, MAX_RAY_COUNT)
		emit_changed()

## 밴드 패턴이 한 바퀴 도는 시간입니다.
@export_range(5.0, 180.0, 1.0, "suffix:s")
var ray_period_s: float:
	get:
		return _ray_period_s
	set(value):
		_ray_period_s = clampf(value, MIN_RAY_PERIOD, MAX_RAY_PERIOD)
		emit_changed()

## 광선 최대 밝기입니다. 게임보다 눈에 띄면 FAIL — 상한 0.4로 못 박았습니다.
@export_range(0.0, 0.4, 0.01)
var ray_max_alpha: float:
	get:
		return _ray_max_alpha
	set(value):
		_ray_max_alpha = clampf(value, MIN_RAY_ALPHA, MAX_RAY_ALPHA)
		emit_changed()

## 클수록 광선 경계가 또렷해집니다.
@export_range(0.5, 8.0, 0.1)
var ray_sharpness: float:
	get:
		return _ray_sharpness
	set(value):
		_ray_sharpness = clampf(value, MIN_RAY_SHARPNESS, MAX_RAY_SHARPNESS)
		emit_changed()

## 광선 색입니다. 채도 낮춘 아이보리 — 금색 보상 스파크와 혼동되지 않게 합니다.
@export var ray_color := DEFAULT_RAY_COLOR


@export_group("배치")

## 별 패치 중심(텍스처 픽셀 좌표)입니다.
@export var star_positions: PackedVector2Array = DEFAULT_STAR_POSITIONS:
	set(value):
		star_positions = value
		emit_changed()


## i번 별의 지움 패치 경로입니다.
func star_cover_path(index: int) -> String:
	return "%s%02d.png" % [STAR_COVER_PREFIX, index + 1]


## i번 별의 회전 본체 경로입니다.
func star_body_path(index: int) -> String:
	return "%s%02d.png" % [STAR_BODY_PREFIX, index + 1]


## i번 별의 반짝임(밝힘) 패치 경로입니다.
func star_glint_path(index: int) -> String:
	return "%s%02d.png" % [STAR_GLINT_PREFIX, index + 1]

## 구름 사각형 원점(텍스처 픽셀)입니다.
@export var cloud_origins: PackedVector2Array = DEFAULT_CLOUD_ORIGINS:
	set(value):
		cloud_origins = value
		emit_changed()

## 구름 사각형 크기입니다.
@export var cloud_sizes: PackedVector2Array = DEFAULT_CLOUD_SIZES:
	set(value):
		cloud_sizes = value
		emit_changed()

## 구름 스케일 기준 코너(tl/tr/bl/br)입니다.
@export var cloud_pivots: PackedStringArray = DEFAULT_CLOUD_PIVOTS:
	set(value):
		cloud_pivots = value
		emit_changed()

## 구름 패치 텍스처 경로입니다.
@export var cloud_textures: PackedStringArray = DEFAULT_CLOUD_TEXTURES:
	set(value):
		cloud_textures = value
		emit_changed()
