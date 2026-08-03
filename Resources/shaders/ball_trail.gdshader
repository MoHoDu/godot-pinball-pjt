shader_type canvas_item;
render_mode blend_mix, unshaded;

// 공 이동 꼬리 (비주얼 가이드 VFX ②) — 2겹 구조.
//
//   ① 안쪽 레이저 : 가늘고 흰색, 경계 또렷. 방향을 만드는 건 이쪽이다.
//   ② 바깥 블룸   : 레이저를 감싸는 안개. 넓고 흐리며 끝에서 투명해진다.
//
// 밝기는 길이 방향으로 계단식 4단으로 떨어진다. 공 뒤가 제일 밝고 끝은 블룸만 남는다.
//
// Line2D 위에서 돈다:
//   UV.x = 0 이 공 쪽, 1 이 꼬리 끝   (BallTrail 이 점을 최신순으로 넣는다)
//   UV.y = 폭 방향, 0.5 가 중심선
// Line2D 의 width_curve 를 블룸 테이퍼와 똑같이 맞춰두므로
// across(=|UV.y-0.5|*2) 는 곧 "현재 지점의 블룸 반폭으로 나눈 거리"가 된다.
//
// 길이는 전부 공 반지름 대비 비율. 44px / 64px 문제 때문에 px 을 박지 않는다.

uniform float ball_radius_px;   // 현재 공 반지름(px). 1px 경계를 정규화하는 데만 쓴다

uniform float bloom_root;       // 블룸 뿌리 반폭 / 공 반지름
uniform float bloom_tip;
uniform float bloom_power;
uniform float core_root;        // 레이저 뿌리 반폭 / 공 반지름
uniform float core_tip;
uniform float core_power;

uniform float steps;            // 길이 방향 계단 수
uniform float step_gamma;
// 레이저를 블룸보다 몇 계단 먼저 끄는지. 1이면 마지막 계단은 블룸만 남는다
// (스케치의 마지막 파란 구간 = "투명 상태의 블룸").
uniform float core_step_drop;
uniform float bloom_alpha;
uniform float core_alpha;
uniform float fade;             // 0~1. 정지·소멸 시 전체를 함께 내린다

uniform vec4 laser_hot : source_color;
uniform vec4 laser_tip : source_color;
uniform vec4 bloom_in : source_color;
uniform vec4 bloom_mid : source_color;
uniform vec4 bloom_out : source_color;


// GLSL 의 smoothstep 은 e0 >= e1 이면 결과가 정의되지 않는다. 내림차순용을 직접 만든다.
float sstep(float e0, float e1, float x) {
	float den = e1 - e0;
	den = (abs(den) < 1e-6) ? 1e-6 : den;
	float t = clamp((x - e0) / den, 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

float taper(float t, float root, float tip, float power) {
	return tip + (root - tip) * pow(max(1.0 - t, 0.0), power);
}


void fragment() {
	float t = clamp(UV.x, 0.0, 1.0);          // 0 = 공, 1 = 꼬리 끝
	float across = clamp(abs(UV.y - 0.5) * 2.0, 0.0, 1.0);

	// 길이 방향 계단
	float band = ceil(pow(max(1.0 - t, 0.0), step_gamma) * steps);
	float step_v = band / steps;
	// 레이저는 블룸보다 먼저 꺼진다 — 꼬리 끝을 블룸만 남기기 위해서다
	float core_step_v = max(band - core_step_drop, 0.0) / steps;

	// 현재 지점의 반폭(px). 블룸은 Line2D 폭과 같으므로 across 를 그대로 쓰면 된다.
	float bloom_half = max(taper(t, bloom_root, bloom_tip, bloom_power), 1e-4) * ball_radius_px;
	float core_half = max(taper(t, core_root, core_tip, core_power), 1e-5) * ball_radius_px;
	float core_norm = clamp(core_half / bloom_half, 0.0, 1.0);

	// ── ② 블룸
	float b1 = exp(-pow(across / 0.52, 1.9));
	float b2 = exp(-pow(across, 1.5));
	float a_bloom = clamp((b1 * 0.62 + b2 * 0.48) * step_v * bloom_alpha, 0.0, 1.0);

	vec3 c_bloom = (across < 0.45)
		? mix(bloom_mid.rgb, bloom_in.rgb, 1.0 - across / 0.45)
		: mix(bloom_out.rgb, bloom_mid.rgb, 1.0 - (across - 0.45) / 0.55);

	// ── ① 레이저
	//   경계는 화면상 약 1px 안에서 끊는다. 정규화 폭으로 환산해야 크기에 안 흔들린다.
	//   ★ 꼬리 끝에서는 블룸이 얇아져 1px 이 레이저 자체보다 넓어진다.
	//     그대로 두면 경계 램프가 레이저를 통째로 먹어 밝기 계단이 뭉개진다.
	//     레이저 폭 안쪽으로 반드시 가둔다.
	float edge_norm = clamp(0.9 / bloom_half, 1e-4, core_norm * 0.9);
	float core_edge = sstep(core_norm, core_norm - edge_norm, across);
	float halo_w = max(core_norm * 1.6, edge_norm);
	float rel = max(across - core_norm, 0.0) / halo_w;
	float core_halo = exp(-rel * rel) * 0.45;
	float a_core = clamp((core_edge + core_halo) * core_step_v * core_alpha, 0.0, 1.0);

	vec3 c_core = mix(laser_hot.rgb, laser_tip.rgb, t);

	// ── 합성: 레이저를 블룸 위에
	float a = a_core + a_bloom * (1.0 - a_core);
	vec3 rgb = (c_core * a_core + c_bloom * a_bloom * (1.0 - a_core)) / max(a, 1e-5);

	COLOR = vec4(rgb, clamp(a * fade, 0.0, 1.0));
}
