@tool
class_name BallParryWave
extends Node2D
## 패링 성공 원형 파동입니다 (비주얼 가이드 VFX ③). **파일 하나로 끝납니다.**
##
## 셰이더도 규칙도 전부 이 파일 안에 있습니다.
## 씬 아무 데나 이 스크립트를 붙인 Node2D 를 하나 놓으면 그걸로 동작합니다.
## 값은 인스펙터에서 바로 바꿉니다.
##
## ── 무엇을 하는가 ────────────────────────────────────
##
## **정확한 패링(PERFECT)에만** 터집니다. 일반 플리퍼 타격에는 쓰지 않습니다.
## 씬에서 parry_resolved 시그널을 가진 노드를 자동으로 찾아 연결합니다.
##
## ── 왜 공의 자식이 아닌가 ────────────────────────────
##
## 파동은 공을 따라다니지 않습니다. 타격 지점에 월드 고정으로 터지고 사라집니다.
## 패링 직후 공은 1000px/s 이상으로 날아가므로(0.26초에 260px)
## 공을 따라가게 만들면 파동이 끌려가 "그 자리에서 터졌다"로 안 읽힙니다.
##
## 덕분에 기존 공 씬(base_ball.tscn)과 변종 6종을 전혀 건드리지 않습니다.
## 어느 공에서 패링이 나든 이 노드 하나가 받습니다.
##
## ── 확정 이력 ────────────────────────────────────────
##
## 2026-08-04 형락님이 3안 중 **안 A(문서 그대로)** 확정.
## 안 A = 중심 플래시가 꽉 찬 원, 방사선 균등, 중심 이동 없음, 링 대칭.
##
## 같은 날 인게임 확인 후 **가시성 개정**. "가시성이 너무 없어 잘 안 보인다"
## → 1차: 지속 0.16→0.26s, 링 6→9px, 종료 105→95px, 소멸 시작 45%→70%.
## → 2차: 지속 0.26→0.42s, 링 9→12px, 종료 95→90px, 소멸 78%, 소멸 곡선 1.3→2.2.
##       60fps 에서 잘 보이는 구간이 5.9 → 12.3 → **22.3프레임**이 됐습니다.
##
## ★ 종료 반지름을 **줄인 것**이 핵심입니다. 같은 잉크를 좁은 둘레에 모아야
##   선이 굵게 읽힙니다. 크게 만드는 것과 잘 보이는 것은 반대 방향이었습니다.
##
## 지속 0.42s 와 링 12px 은 가이드 권장(0.12~0.20 / 4~8)을 **의도적으로 넘긴 값**입니다.
##
## ★ 지속 0.42초 동안 공은 1200px/s 기준 **약 500px**(보드 폭 2240 의 22%) 를 갑니다.
##   가이드가 "다음 공의 방향을 판단할 시점까지 남지 않는다"고 한 건 이걸 말합니다.
##   플레이에 방해된다고 느껴지면 duration 과 fade_start 를 먼저 내립니다.
## 안개 오라 40px(문서 28~30), 이동 꼬리 140px(문서 60~100)과 같은 종류의 결정입니다.


# ── 확정값 ──────────────────────────────────────────
#
# 길이는 전부 **공 반지름 대비 비율**입니다. 괄호 안은 공 지름 44px(반지름 22px) 환산.
# 기획서 44px 와 코드 기본값 64px 이 다르므로 절대 px 을 박지 않습니다.

const DEFAULT_START_RADIUS_RATIO := 1.227   ## 27px. 가이드 권장 25~30
const DEFAULT_END_RADIUS_RATIO := 4.091     ## 90px. 가이드 권장 90~120 의 하한
const DEFAULT_DURATION := 0.42              ## 가이드 권장 0.12~0.20 을 크게 넘긴 값
const DEFAULT_EXPAND_EXP := 1.35            ## 클수록 초반에 확 커진다
const DEFAULT_FADE_START := 0.78            ## 소멸 시작 진행도. 가시성에 가장 크게 먹힌다
const DEFAULT_FADE_EXP := 2.2               ## 클수록 밝기를 오래 유지하다 끝에서 훅 꺼진다

const DEFAULT_RING_WIDTH_RATIO := 0.545     ## 12px. 가이드 권장 4~8 을 크게 넘긴 값
const DEFAULT_RING_WIDTH_SHRINK := 0.10     ## 커지면서 얇아지는 정도. 끝 10.8px
const DEFAULT_GAP_COUNT := 1                ## 링을 끊는 개수
const DEFAULT_GAP_WIDTH := 0.10
const DEFAULT_WOBBLE := 0.022               ## 0.05 넘으면 44px 에서 톱니바퀴로 읽힌다
const DEFAULT_BAND_COUNT := 5               ## 명도 단차. 크면 매끈한 네온이 된다

const DEFAULT_SUB_DELAY := 0.18             ## 금색 보조 링이 뒤따르는 정도
const DEFAULT_SUB_WIDTH_SCALE := 0.5

const DEFAULT_SPOKE_COUNT := 10             ## 방사형 선
const DEFAULT_SPOKE_WIDTH_DEG := 3.4
const DEFAULT_SPARK_COUNT := 5              ## 짧은 별 조각. 셰이더 루프 상한이 8
const DEFAULT_SPARK_LENGTH_RATIO := 0.636   ## 14px

const DEFAULT_FLASH_TIME := 0.06            ## 가이드 권장 0.03~0.06 의 상한
const DEFAULT_CENTER_SHIFT_RATIO := 0.0     ## 안 A 는 중심을 옮기지 않는다
const DEFAULT_MAX_CONCURRENT := 6

# 손댈 일이 거의 없어 인스펙터에 안 내놓은 값들입니다.
const WOBBLE_LOBES := 7.0
const SPOKE_INNER_MUL := 1.06   ## 1.0 미만이면 선이 링을 가로질러 톱니바퀴가 된다
const SPOKE_OUTER_MUL := 1.26
const SPOKE_APPEAR := 0.05
const SPARK_APPEAR := 0.10
const SPARK_VANISH := 0.80
const SPARK_WIDTH_RATIO := 0.180
const SUB_APPEAR := 0.20
## ★ 1.06 이면 별 조각이 쿼드 경계를 스친다.
## 별은 링보다 바깥(최대 1.30배)에 흩어지므로 방사선 끝만으로는 여유가 모자란다.
const QUAD_PADDING := 1.20

## 비주얼 가이드의 레이어 순서입니다.
## 꼬리(5) < 공 본체(6) < 발광 테두리(10) < **파동(12)** < 충돌 스파크.
const Z_INDEX_WAVE: int = 12

## 플리퍼가 보내는 패링 등급입니다. FlipperParryEvaluator.Grade 와 값을 맞춥니다.
const PARRY_GRADE_NONE: int = 0
const PARRY_GRADE_NORMAL: int = 1
const PARRY_GRADE_PERFECT: int = 2

const PARRY_SIGNAL: StringName = &"parry_resolved"

## 공에서 지름을 읽지 못했을 때 쓰는 값입니다. 기획서 기준 22px 반지름.
const FALLBACK_BALL_RADIUS: float = 22.0
const MIN_DIRECTION_SPEED: float = 1.0

## 가이드 3-5 권장 범위입니다. 어디를 넘겼는지 보려고 남겨 둡니다.
const DOC_START_RADIUS_PX := Vector2(25.0, 30.0)
const DOC_END_RADIUS_PX := Vector2(90.0, 120.0)
const DOC_DURATION := Vector2(0.12, 0.20)
const DOC_FLASH_TIME := Vector2(0.03, 0.06)
const DOC_RING_WIDTH_PX := Vector2(4.0, 8.0)
const DOC_BALL_RADIUS := 22.0

# ── 셰이더 ──────────────────────────────────────────
#
# 별도 .gdshader 파일로 빼지 않고 여기에 둡니다. 파일 하나로 끝내기 위해서입니다.
# _ready()에서 Shader.new().code 에 그대로 넣습니다.
const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix, unshaded;

// 패링 성공 원형 파동 (비주얼 가이드 VFX ③) — 정확한 패링에만 발생한다.
//
// 가이드 3-5 가 요구하는 5요소를 쿼드 한 장에 전부 그린다.
// 문서 12-3 의 노드 이름과 1:1 로 대응한다:
//
//   ① Ball_Parry_Flash       중심의 짧은 플래시
//   ② Ball_Parry_Ring_Main   바깥으로 빠르게 확대되는 굵은 링 (밝은 청록)
//   ③ Ball_Parry_Ring_Sub    얇은 보조 링. 금색이 뒤따른다
//   ④ Ball_Parry_RadialLines 링 주변의 방사형 선
//   ⑤ Ball_Parry_Sparks      짧은 별 조각
//
// 노드를 5개 두면 매 프레임 반경·두께를 서로 맞춰야 하고 미세하게 어긋난다.
// 이동 꼬리에서 Line2D 를 2개가 아니라 1개로 합친 것과 같은 이유다.
//
// 길이 단위는 전부 "쿼드 반지름 = 1.0" 으로 정규화돼 있다.
// 공 44px / 64px 문제 때문에 셰이더 안에 px 을 박지 않는다.
//
// ★ 밴딩(명도 단차)은 누적된 최종 알파에 딱 한 번만 건다.
//   요소마다 따로 걸면 계단이 서로 어긋나 다시 매끈한 네온이 된다 (안개 오라 교훈).

uniform float quad_radius_px;   // 쿼드 반지름(px). 1px 경계 완화를 정규화하는 데만 쓴다

uniform float main_r;           // 주요 링 반경 / 쿼드 반지름
uniform float main_w;           // 주요 링 두께(정규화)
uniform float sub_r;            // 보조 링 반경
uniform float sub_w;
uniform float sub_on;           // 0 이면 아직 안 나온다

uniform float spoke_count;      // 방사형 선 개수
uniform float spoke_in;         // 안쪽 끝 반경
uniform float spoke_out;        // 바깥 끝 반경
uniform float spoke_w;          // 선 반폭(정규화)
uniform float spoke_on;

uniform float spark_count;      // 별 조각 개수 (최대 8)
uniform float spark_r;          // 별이 흩어지는 기준 반경
uniform float spark_len;
uniform float spark_w;
uniform float spark_on;

uniform float ball_r;           // 공 반지름 / 쿼드 반지름
uniform float flash_r;          // 중심 플래시 반경
uniform float flash_a;          // 중심 플래시 세기 (0 이면 끝)
// 0 = 꽉 찬 원 (가이드 3-5 "중심의 짧은 플래시" 그대로. 확정된 A안)
// 1 = 공 바깥 고리 (가이드 3-2 "파동이 동공을 가리지 않도록" 쪽을 택할 때)
uniform float flash_hollow;

uniform float bands;            // 명도 단차 수
uniform float wobble;           // 카툰형 원 흔들림. 키우면 톱니바퀴가 된다
uniform float wobble_lobes;
uniform float gaps;             // 링을 끊는 개수
uniform float gap_width;
uniform float fade;             // 소멸. 밴딩 뒤에 곱한다

uniform vec4 col_ring : source_color;
uniform vec4 col_sub : source_color;
uniform vec4 col_flash : source_color;
uniform vec4 col_spark : source_color;

const float TAU_ = 6.28318530718;


float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453123);
}


// 매끈한 네온 원이 아니라 약간 흔들리는 카툰형 원 (가이드 3-2).
// 저주파만 섞는다. 고주파를 섞으면 44px 에서 긁힘처럼 읽힌다.
float wob(float th) {
	float w = sin(th * wobble_lobes + 1.1) * 0.6
		+ sin(th * (wobble_lobes * 2.0 + 1.0) - 1.87) * 0.4;
	return 1.0 + w * wobble;
}


// 가장자리 1px 만 완화한 평탄한 고리. 소프트 그라디언트로 흐리지 않는다.
// (완전 평면 정사영 — 광원이 없으므로 그라디언트 음영을 쓰지 않는다)
float annulus(float r, float th, float rc, float w, float soft,
		float gap_n, float gap_ph) {
	float rr = rc * wob(th);
	float d = abs(r - rr);
	float a = clamp((w * 0.5 - d) / soft + 1.0, 0.0, 1.0);

	if (gap_n > 0.5) {
		float g = cos(th * gap_n + gap_ph);
		float cut = clamp((g - (1.0 - gap_width)) / max(gap_width, 1e-6), 0.0, 1.0);
		a *= 1.0 - cut * 0.85;
	}

	return a;
}


vec4 over(vec4 dst, vec4 src) {
	float oa = src.a + dst.a * (1.0 - src.a);
	vec3 rgb = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(oa, 1e-5);
	return vec4(rgb, oa);
}


void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float th = atan(p.y, p.x);
	// 화면상 1px 을 정규화 단위로. 쿼드 크기가 달라져도 경계 두께가 안 흔들린다.
	float soft = max(1.0 / max(quad_radius_px, 1e-3), 1e-4);

	// ── ④ 방사형 선 : 링 바깥에만 둔다.
	//   링을 가로지르게 두면 파동이 아니라 톱니바퀴로 읽힌다.
	float a_spoke = 0.0;
	if (spoke_on > 0.5 && spoke_count >= 1.0) {
		float step_a = TAU_ / spoke_count;
		float local = mod(th + 0.26 + step_a * 0.5, step_a) - step_a * 0.5;
		float dn = abs(local) * r;
		float tt = clamp((r - spoke_in) / max(spoke_out - spoke_in, 1e-6), 0.0, 1.0);
		float wn = spoke_w * (1.0 - 0.65 * tt);
		float band = clamp((wn - dn) / soft + 1.0, 0.0, 1.0);
		float rad = clamp(min(r - spoke_in, spoke_out - r) / soft + 1.0, 0.0, 1.0);
		a_spoke = band * rad * 0.85;
	}

	// ── ② 주요 링
	float a_main = annulus(r, th, main_r, main_w, soft, gaps, 0.55) * 0.95;

	// ── ③ 보조 링 (금색). 성공 포인트라 금색은 여기서만 쓴다.
	float a_sub = 0.0;
	if (sub_on > 0.5) {
		a_sub = annulus(r, th, sub_r, sub_w, soft, 2.0, -0.20) * 0.92;
	}

	// ── ⑤ 별 조각 : 방사형 선과 구분되도록 십자로 그린다.
	//   같은 선 모양으로 그리면 방사선과 뭉쳐 하나로 읽힌다.
	float a_spark = 0.0;
	if (spark_on > 0.5) {
		for (int i = 0; i < 8; i++) {
			if (float(i) >= spark_count) {
				break;
			}
			float fi = float(i);
			float ang = 0.35 + fi * TAU_ / max(spark_count, 1.0)
				+ (hash11(fi * 3.1 + 1.7) - 0.5) * 0.44;
			float rc = spark_r * (1.12 + hash11(fi * 7.3 + 2.9) * 0.18);
			vec2 d = p - vec2(cos(ang), sin(ang)) * rc;
			float ca = cos(ang);
			float sa = sin(ang);
			float u = d.x * ca + d.y * sa;
			float v = -d.x * sa + d.y * ca;
			float arm1 = clamp((spark_len * 0.5 - abs(u)) / soft + 1.0, 0.0, 1.0)
				* clamp((spark_w * 0.5 - abs(v)) / soft + 1.0, 0.0, 1.0);
			float arm2 = clamp((spark_len * 0.31 - abs(v)) / soft + 1.0, 0.0, 1.0)
				* clamp((spark_w * 0.5 - abs(u)) / soft + 1.0, 0.0, 1.0);
			a_spark = max(a_spark, max(arm1, arm2) * 0.90);
		}
	}

	// ── ① 중심 플래시
	float a_flash = 0.0;
	if (flash_a > 0.0) {
		float fr;
		if (flash_hollow > 0.5) {
			float mid = (ball_r + flash_r) * 0.5;
			float w = max(flash_r - ball_r, soft * 2.0);
			fr = annulus(r, th, mid, w, soft, 0.0, 0.0);
		} else {
			float rr = flash_r * wob(th);
			fr = clamp((rr - r) / soft + 1.0, 0.0, 1.0);
		}
		a_flash = fr * flash_a;
	}

	// ── 합성. 방사선·주요 링은 같은 청록이고 그 위에 금색·아이보리가 얹힌다.
	vec4 acc = vec4(0.0);
	acc = over(acc, vec4(col_ring.rgb, a_spoke * col_ring.a));
	acc = over(acc, vec4(col_ring.rgb, a_main * col_ring.a));
	acc = over(acc, vec4(col_sub.rgb, a_sub * col_sub.a));
	acc = over(acc, vec4(col_spark.rgb, a_spark * col_spark.a));
	acc = over(acc, vec4(col_flash.rgb, a_flash * col_flash.a));

	// ★ 밴딩은 여기서 딱 한 번. 그리고 소멸은 밴딩 뒤에 곱한다.
	//   ceil 밴딩을 페이드 앞에 걸면 사라지는 과정이 계단에 먹혀 끝까지 밝게 남는다.
	float total = ceil(clamp(acc.a, 0.0, 1.0) * bands) / bands;

	COLOR = vec4(acc.rgb, clamp(total * fade, 0.0, 1.0));
}
"""


# ── 인스펙터 ────────────────────────────────────────

@export_category("패링 원형 파동")

@export_group("동작")

## 끄면 시그널을 받아도 파동을 만들지 않습니다. 검수 중 비교용입니다.
@export var enabled: bool = true

## 켜면 씬에서 parry_resolved 시그널을 가진 노드를 찾아 자동으로 연결합니다.
## 끄면 bind_to_flipper()로 직접 붙입니다.
@export var auto_bind_parry: bool = true

## 동시에 살아 있을 수 있는 파동 개수입니다. 넘으면 가장 오래된 것을 재사용합니다.
@export_range(1, 16, 1) var max_concurrent: int = DEFAULT_MAX_CONCURRENT


@export_group("크기와 시간")

## 시작 반지름 / 공 반지름. 기본 1.227은 44px 공 기준 27px입니다.
@export_range(0.5, 12.0, 0.001, "suffix:x")
var start_radius_ratio: float = DEFAULT_START_RADIUS_RATIO

## 종료 반지름 / 공 반지름. 기본 4.091은 44px 공 기준 90px입니다.
## ★ 키우면 링 둘레가 늘어 같은 두께가 더 얇아 보입니다. 가시성을 올리려면 오히려 줄입니다.
@export_range(0.5, 12.0, 0.001, "suffix:x")
var end_radius_ratio: float = DEFAULT_END_RADIUS_RATIO

## 파동 전체 지속 시간입니다.
## 다음 공의 이동 방향을 판단해야 하는 시점까지 화면에 남으면 안 됩니다(가이드 3-5).
@export_range(0.02, 1.0, 0.005, "suffix:s")
var duration: float = DEFAULT_DURATION

## 확대 곡선 지수입니다. 클수록 초반에 확 커지고 뒤가 완만해집니다.
@export_range(0.5, 6.0, 0.05)
var expand_exp: float = DEFAULT_EXPAND_EXP

## 소멸이 시작되는 진행도입니다.
## ★ 가시성에 가장 크게 먹히는 값입니다.
## 0.45 → 6프레임 / 0.70 → 12프레임 / 0.78 + 지속 0.42s → 22프레임.
@export_range(0.0, 1.0, 0.01)
var fade_start: float = DEFAULT_FADE_START

@export_range(0.5, 6.0, 0.05)
var fade_exp: float = DEFAULT_FADE_EXP


@export_group("주요 링")

## 링 두께 / 공 반지름. 기본 0.545는 44px 공 기준 12px입니다(가이드 권장 4~8 초과).
@export_range(0.02, 2.0, 0.001, "suffix:x")
var ring_width_ratio: float = DEFAULT_RING_WIDTH_RATIO

## 커지면서 얇아지는 정도입니다. 두께를 고정하면 큰 원에서 덩어리로 보입니다.
@export_range(0.0, 0.8, 0.01)
var ring_width_shrink: float = DEFAULT_RING_WIDTH_SHRINK

## 링을 몇 군데 끊을지입니다.
## "매끈한 네온 원보다 약간 끊어지고 흔들리는 카툰형 원"(가이드 3-2).
@export_range(0, 6, 1) var gap_count: int = DEFAULT_GAP_COUNT

@export_range(0.02, 0.5, 0.01) var gap_width: float = DEFAULT_GAP_WIDTH

## 손그림 흔들림입니다. 0.05를 넘으면 44px에서 원이 아니라 톱니바퀴로 읽힙니다.
@export_range(0.0, 0.08, 0.001)
var wobble_amount: float = DEFAULT_WOBBLE

## 명도 단차 수입니다. 크면 다크 카툰이 아니라 매끈한 네온이 됩니다.
@export_range(2, 12, 1) var band_count: int = DEFAULT_BAND_COUNT


@export_group("보조 링 · 방사선 · 별")

## 금색 보조 링이 주요 링보다 얼마나 늦게 출발하는지입니다(진행도 기준).
## 가이드 3-5 연출 순서 2단계 "금색 또는 아이보리 보조 링이 뒤따름".
@export_range(0.0, 0.6, 0.01) var sub_delay: float = DEFAULT_SUB_DELAY

## 주요 링 대비 보조 링 두께입니다. 가이드가 "얇은 보조 링"이라고 못 박습니다.
@export_range(0.1, 1.0, 0.01, "suffix:x")
var sub_width_scale: float = DEFAULT_SUB_WIDTH_SCALE

## 링 주변의 방사형 선 개수입니다. 적고 굵은 쪽이 빠른 연출에서 읽힙니다.
@export_range(0, 24, 1) var spoke_count: int = DEFAULT_SPOKE_COUNT

@export_range(0.2, 6.0, 0.1, "suffix:deg")
var spoke_width_deg: float = DEFAULT_SPOKE_WIDTH_DEG

## 짧은 별 조각 개수입니다. 셰이더 루프 상한이 8이라 그 위로는 못 올립니다.
@export_range(0, 8, 1) var spark_count: int = DEFAULT_SPARK_COUNT

@export_range(0.05, 2.0, 0.001, "suffix:x")
var spark_length_ratio: float = DEFAULT_SPARK_LENGTH_RATIO


@export_group("중심 플래시")

## 중심 플래시가 유지되는 시간입니다.
@export_range(0.005, 1.0, 0.005, "suffix:s")
var flash_time: float = DEFAULT_FLASH_TIME

## ★ 되돌릴 수 있게 남긴 스위치입니다.
##
## 가이드 3-5는 "중심의 짧은 플래시"를 요구하고,
## 가이드 3-2는 "원형 파동이 동공을 가리지 않도록 한다"고 합니다. 둘이 부딪힙니다.
##
## false = 꽉 찬 원. 44px 공의 동공(약 14px)이 플래시 동안 덮입니다. **확정된 안 A**
## true  = 공 바깥 고리. 동공이 그대로 보입니다.
##
## 강보현님 검수에서 "파동이 공을 가린다"로 걸리면 이걸 켭니다.
@export var flash_hollow: bool = false

## 파동 중심을 타격 방향으로 옮기는 거리 / 공 반지름입니다.
## 가이드 권장은 2~5px(= 0.091~0.227)이지만 확정된 안 A는 이동 없음(0)입니다.
@export_range(0.0, 0.5, 0.001, "suffix:x")
var center_shift_ratio: float = DEFAULT_CENTER_SHIFT_RATIO


@export_group("색")

## 주요 링. 밝은 청록(가이드 3-5).
@export var ring_color := Color(0.435, 0.890, 0.784, 1.0)

## 보조 링. 금색 = 성공 포인트입니다.
## 발광 테두리에는 금색을 쓰지 않습니다. 겹치면 파동의 언어가 뭉개집니다.
@export var sub_color := Color(1.0, 0.780, 0.120, 1.0)

## 중심 플래시. 아이보리 또는 흰색(가이드 3-5).
@export var flash_color := Color(0.941, 0.878, 0.765, 1.0)

## 별 조각. 청록·아이보리 중심(가이드 3-5).
@export var spark_color := Color(0.941, 0.878, 0.765, 1.0)


## 살아 있는 파동 하나입니다.
class Wave:
	extends RefCounted

	var sprite: Sprite2D
	var material: ShaderMaterial
	var elapsed: float = 0.0
	var life: float = 0.26
	var ball_radius: float = 22.0
	var hit_angle: float = 0.0
	var active: bool = false


var _shader: Shader
var _quad_texture: ImageTexture
var _waves: Array[Wave] = []
var _bound_flippers: Array[Node] = []
var _total_played: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_shader = Shader.new()
	_shader.code = SHADER_CODE

	# 셰이더가 UV 전체에 그려지려면 실제로 픽셀이 있는 텍스처가 필요합니다.
	# 흰색 1x1이면 충분합니다. 셰이더가 COLOR를 통째로 덮어쓰므로 내용은 안 씁니다.
	# 1x1이라 스프라이트 scale이 곧 px 크기가 됩니다.
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_quad_texture = ImageTexture.create_from_image(image)

	if auto_bind_parry:
		_bind_recursive(get_tree().current_scene)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for wave in _waves:
		if not wave.active:
			continue

		wave.elapsed += delta

		if wave.elapsed >= wave.life:
			wave.active = false
			wave.elapsed = 0.0
			wave.sprite.visible = false
			continue

		_apply_uniforms(wave)


# ── 공개 API ────────────────────────────────────────

## 정확한 패링 지점에 파동을 하나 띄웁니다.
##
## world_position 은 공 중심입니다(가이드 3-5 "공 중심에서 시작").
## hit_angle 은 공이 날아가는 방향(rad)입니다.
## 반환값은 파동 슬롯 인덱스이고, 만들지 못하면 -1입니다.
func play_at(
	world_position: Vector2,
	ball_radius: float = FALLBACK_BALL_RADIUS,
	hit_angle: float = 0.0
) -> int:
	if not enabled:
		return -1

	var wave := _acquire_wave()

	if wave == null:
		return -1

	var radius := maxf(ball_radius, 1.0)
	wave.elapsed = 0.0
	wave.life = maxf(duration, 0.001)
	wave.ball_radius = radius
	wave.hit_angle = hit_angle
	wave.active = true

	# 쿼드는 파동이 도달할 최대 크기로 한 번만 잡습니다.
	# 매 프레임 키우면 1px 경계가 흔들려 계단이 떨립니다.
	var quad_radius := radius * get_quad_radius_ratio()
	wave.sprite.scale = Vector2.ONE * (quad_radius * 2.0)

	# 중심을 타격 방향으로 살짝 밉니다. 안 A는 이동 0이라 기본값에서는 안 움직입니다.
	var shift := center_shift_ratio * radius
	wave.sprite.global_position = world_position + Vector2(
		cos(hit_angle) * shift,
		sin(hit_angle) * shift
	)
	wave.sprite.visible = true

	_apply_uniforms(wave)
	_total_played += 1
	return _waves.find(wave)


## 패링 시그널을 가진 노드에 연결합니다.
func bind_to_flipper(flipper: Node) -> void:
	if flipper == null or _bound_flippers.has(flipper):
		return

	if not flipper.has_signal(PARRY_SIGNAL):
		return

	flipper.connect(PARRY_SIGNAL, _on_parry_resolved)
	_bound_flippers.append(flipper)


func get_active_count() -> int:
	var count := 0

	for wave in _waves:
		if wave.active:
			count += 1

	return count


## 지금까지 터진 총 횟수입니다. 테스트용입니다.
func get_total_played() -> int:
	return _total_played


func get_bound_flipper_count() -> int:
	return _bound_flippers.size()


## 진행도 0~1입니다. 슬롯이 비었으면 -1입니다.
func get_wave_progress(index: int) -> float:
	var wave := _get_wave(index)

	if wave == null or not wave.active:
		return -1.0

	return clampf(wave.elapsed / maxf(wave.life, 0.001), 0.0, 1.0)


## 현재 주요 링 반경(px)입니다. 슬롯이 비었으면 -1입니다.
func get_wave_radius_px(index: int) -> float:
	var wave := _get_wave(index)

	if wave == null or not wave.active:
		return -1.0

	var t := clampf(wave.elapsed / maxf(wave.life, 0.001), 0.0, 1.0)
	return get_main_radius_ratio(t) * wave.ball_radius


func get_wave_position(index: int) -> Vector2:
	var wave := _get_wave(index)

	if wave == null or wave.sprite == null:
		return Vector2.ZERO

	return wave.sprite.global_position


## 셰이더에 실제로 들어간 값을 읽습니다. 테스트용입니다.
func get_shader_param(index: int, parameter_name: StringName) -> Variant:
	var wave := _get_wave(index)

	if wave == null or wave.material == null:
		return null

	return wave.material.get_shader_parameter(parameter_name)


## 파동 스프라이트입니다. 테스트에서 레이어를 확인할 때 씁니다.
func get_wave_sprite(index: int) -> Sprite2D:
	var wave := _get_wave(index)
	return wave.sprite if wave != null else null


# ── 곡선 (엔진 없이도 성립하는 순수 계산) ─────────────

## 빠르게 커지고 사라진다(가이드 3-5). 초반에 확 커지는 ease-out 입니다.
func get_expand_curve(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), expand_exp)


## 진행도 t 에서의 주요 링 반경 / 공 반지름입니다.
func get_main_radius_ratio(t: float) -> float:
	return start_radius_ratio + (end_radius_ratio - start_radius_ratio) * get_expand_curve(t)


## 보조 링은 sub_delay 만큼 늦게 출발해 주요 링을 뒤따릅니다.
func get_sub_radius_ratio(t: float) -> float:
	var span := maxf(1.0 - sub_delay, 0.001)
	var ts := clampf((t - sub_delay) / span, 0.0, 1.0)
	return start_radius_ratio + (end_radius_ratio - start_radius_ratio) * get_expand_curve(ts)


## 커지면서 얇아진 현재 두께 / 공 반지름입니다.
func get_ring_width_ratio(t: float) -> float:
	return ring_width_ratio * (1.0 - ring_width_shrink * get_expand_curve(t))


func get_fade(t: float) -> float:
	var span := maxf(1.0 - fade_start, 0.001)
	var x := clampf((t - fade_start) / span, 0.0, 1.0)
	return clampf(1.0 - pow(x, fade_exp), 0.0, 1.0)


## 중심 플래시의 세기입니다. flash_time 이 지나면 0입니다.
func get_flash_amount(elapsed_seconds: float) -> float:
	if flash_time <= 0.0 or elapsed_seconds >= flash_time:
		return 0.0

	return clampf(pow(1.0 - elapsed_seconds / flash_time, 0.8), 0.0, 1.0)


## 쿼드 반지름 / 공 반지름입니다. 별 조각까지 담아야 잘리지 않습니다.
func get_quad_radius_ratio() -> float:
	return end_radius_ratio * SPOKE_OUTER_MUL * QUAD_PADDING


## 60fps 에서 "잘 보이는"(fade >= 0.8) 구간이 몇 프레임인지입니다.
## "지속 0.16초"는 통과해도 실제로 잘 보이는 건 6프레임뿐이었습니다. 그게 개정 이유입니다.
func get_visible_frames(threshold: float = 0.8, fps: float = 60.0) -> float:
	var span := maxf(1.0 - fade_start, 0.001)
	var x := pow(clampf(1.0 - threshold, 0.0, 1.0), 1.0 / maxf(fade_exp, 0.001))
	return minf(fade_start + span * x, 1.0) * duration * fps


# ── 내부 ────────────────────────────────────────────

func _make_wave() -> Wave:
	var wave := Wave.new()

	wave.material = ShaderMaterial.new()
	wave.material.shader = _shader

	wave.sprite = Sprite2D.new()
	wave.sprite.name = "Wave%d" % _waves.size()
	wave.sprite.centered = true
	wave.sprite.texture = _quad_texture
	wave.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wave.sprite.material = wave.material
	# 파동은 월드에 고정됩니다. 이 노드를 어디에 두든 좌표가 안 흔들립니다.
	wave.sprite.top_level = true
	wave.sprite.z_as_relative = false
	wave.sprite.z_index = Z_INDEX_WAVE
	wave.sprite.visible = false

	add_child(wave.sprite)
	_waves.append(wave)
	return wave


## 빈 슬롯을 주고, 없으면 가장 오래된 파동을 밀어냅니다.
func _acquire_wave() -> Wave:
	for wave in _waves:
		if not wave.active:
			return wave

	if _waves.size() < max_concurrent:
		return _make_wave()

	var oldest: Wave = null

	for wave in _waves:
		if oldest == null or wave.elapsed > oldest.elapsed:
			oldest = wave

	return oldest


func _get_wave(index: int) -> Wave:
	if index < 0 or index >= _waves.size():
		return null

	return _waves[index]


func _apply_uniforms(wave: Wave) -> void:
	if wave.material == null:
		return

	var t := clampf(wave.elapsed / maxf(wave.life, 0.001), 0.0, 1.0)
	var quad_radius := maxf(wave.ball_radius * get_quad_radius_ratio(), 0.001)
	# 공 반지름 기준 비율을 쿼드 반지름 1.0 기준으로 옮기는 배율입니다.
	# 셰이더에 px 을 넘기지 않기 위한 정규화입니다.
	var to_quad := wave.ball_radius / quad_radius

	var main_r := get_main_radius_ratio(t) * to_quad
	var main_w := get_ring_width_ratio(t) * to_quad
	var spoke_out := main_r * SPOKE_OUTER_MUL
	var material := wave.material

	material.set_shader_parameter(&"quad_radius_px", quad_radius)
	material.set_shader_parameter(&"ball_r", to_quad)

	material.set_shader_parameter(&"main_r", main_r)
	material.set_shader_parameter(&"main_w", main_w)
	material.set_shader_parameter(&"sub_r", get_sub_radius_ratio(t) * to_quad)
	material.set_shader_parameter(&"sub_w", main_w * sub_width_scale)
	material.set_shader_parameter(&"sub_on", 1.0 if t >= SUB_APPEAR else 0.0)

	material.set_shader_parameter(&"spoke_count", float(spoke_count))
	material.set_shader_parameter(&"spoke_in", main_r * SPOKE_INNER_MUL)
	material.set_shader_parameter(&"spoke_out", spoke_out)
	# 각도 폭을 그 지점의 px 폭으로 환산한 반폭입니다. 끝이 벌어지지 않게 합니다.
	material.set_shader_parameter(
		&"spoke_w",
		deg_to_rad(spoke_width_deg) * 0.5 * spoke_out
	)
	material.set_shader_parameter(
		&"spoke_on",
		1.0 if (t >= SPOKE_APPEAR and spoke_count > 0) else 0.0
	)

	material.set_shader_parameter(&"spark_count", float(spark_count))
	material.set_shader_parameter(&"spark_r", main_r)
	material.set_shader_parameter(&"spark_len", spark_length_ratio * to_quad)
	material.set_shader_parameter(&"spark_w", SPARK_WIDTH_RATIO * to_quad)
	material.set_shader_parameter(
		&"spark_on",
		1.0 if (spark_count > 0 and t >= SPARK_APPEAR and t <= SPARK_VANISH) else 0.0
	)

	material.set_shader_parameter(&"flash_r", start_radius_ratio * 0.92 * to_quad)
	material.set_shader_parameter(&"flash_a", get_flash_amount(wave.elapsed))
	material.set_shader_parameter(&"flash_hollow", 1.0 if flash_hollow else 0.0)

	material.set_shader_parameter(&"bands", float(band_count))
	material.set_shader_parameter(&"wobble", wobble_amount)
	material.set_shader_parameter(&"wobble_lobes", WOBBLE_LOBES)
	material.set_shader_parameter(&"gaps", float(gap_count))
	material.set_shader_parameter(&"gap_width", gap_width)
	material.set_shader_parameter(&"fade", get_fade(t))

	material.set_shader_parameter(&"col_ring", ring_color)
	material.set_shader_parameter(&"col_sub", sub_color)
	material.set_shader_parameter(&"col_flash", flash_color)
	material.set_shader_parameter(&"col_spark", spark_color)


func _bind_recursive(node: Node) -> void:
	if node == null:
		return

	if node.has_signal(PARRY_SIGNAL):
		bind_to_flipper(node)

	for child in node.get_children():
		_bind_recursive(child)


func _on_parry_resolved(
	ball: RigidBody2D,
	grade: int,
	contact_point: Vector2,
	_contact_zone: int,
	_elapsed_time: float,
	_speed_multiplier: float
) -> void:
	# ★ 정확한 패링에만. 일반 패링은 발광 테두리의 약한 점등이 담당합니다.
	if grade != PARRY_GRADE_PERFECT or not is_instance_valid(ball):
		return

	play_at(
		ball.global_position,
		_read_ball_radius(ball),
		_read_hit_angle(ball, contact_point)
	)


## 공 지름은 Pinball 에만 있는 속성이라 정적 타입 접근이 안 됩니다.
## get()으로 읽어야 대상이 Pinball 이 아니어도 파스·실행 모두 안전합니다.
func _read_ball_radius(ball: Node2D) -> float:
	var diameter: Variant = ball.get(&"ball_diameter")

	if diameter == null:
		return FALLBACK_BALL_RADIUS

	return maxf(float(diameter), 1.0) * 0.5


## 공이 날아가는 방향입니다.
## 속도가 아직 안 실렸으면 접촉 지점에서 공 쪽으로 향하는 방향을 씁니다.
func _read_hit_angle(ball: RigidBody2D, contact_point: Vector2) -> float:
	var velocity := ball.linear_velocity

	if velocity.length() > MIN_DIRECTION_SPEED:
		return velocity.angle()

	var away := ball.global_position - contact_point

	if away.length() > MIN_DIRECTION_SPEED:
		return away.angle()

	return 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not auto_bind_parry and _bound_flippers.is_empty():
		warnings.append(
			"Auto Bind Parry가 꺼져 있습니다. bind_to_flipper()로 직접 연결해야 합니다."
		)

	if end_radius_ratio <= start_radius_ratio:
		warnings.append("종료 반지름이 시작 반지름보다 커야 합니다.")

	return warnings
