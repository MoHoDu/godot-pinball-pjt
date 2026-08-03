shader_type canvas_item;
render_mode blend_mix, unshaded;

// 공을 감싸는 마법의 안개 오라 (비주얼 가이드 VFX ①).
//
// 구조: 극좌표 -> 각도별 혓바닥(edge) -> 방사 falloff -> 극좌표 노이즈(방사 결)
//       -> 밴딩(한 번만) -> 색
//
// ★ 밴딩은 반드시 "누적된 최종 알파"에 한 번만 건다.
//   층마다 따로 걸어 겹치면 계단이 서로 어긋나 다시 매끈한 글로우가 된다.
//
// 길이 단위는 전부 "쿼드 반지름 = 1.0" 으로 정규화돼 있다.
// 공 44px / 64px 문제 때문에 셰이더 안에 px 을 박지 않는다.

uniform float ball_ratio;      // 공 반지름 / 쿼드 반지름
uniform float outer_ratio;     // 안개 최대 도달 반경 / 쿼드 반지름
uniform float peak;            // 안개 최대 알파
uniform float bands;           // 명도 단차 수
uniform float falloff_exp;     // 클수록 바깥이 빨리 옅어진다
uniform float plume;           // 각도별 혓바닥 길이 편차
uniform float plume_lobes;     // 혓바닥 개수
uniform float wisp;            // 방사형 결의 세기
uniform float wisp_lobes;      // 결 개수(각도 분할)
uniform float wisp_radial;     // 반경 분할 — 작을수록 결이 길쭉해진다
uniform float inner_bloom;     // 공 바로 바깥 한 겹 더
uniform float gaze_stretch;    // 진행방향으로 늘리는 정도
uniform float gaze_angle;      // 진행방향(rad)
uniform float gaze_enabled;    // 0 이면 등방
uniform float core_alpha;      // 코어 링 알파
uniform float core_w_norm;     // 코어 링 두께(정규화)
uniform float core_gain;       // 점등 시 코어 배율
uniform float alpha_gain;      // 점등 시 안개 배율
uniform float wobble;          // 코어 링 손그림 흔들림
uniform float drift_phase;     // 시간 위상 (애니메이션)
uniform float seed;

uniform vec4 col_core : source_color;
uniform vec4 col_mist : source_color;
uniform vec4 col_outer : source_color;

const float TAU_ = 6.28318530718;


float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453123);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// GLSL 의 smoothstep 은 e0 >= e1 이면 결과가 정의되지 않는다.
// 내림차순 falloff 가 필요하므로 직접 만든다.
float sstep(float e0, float e1, float x) {
	float den = e1 - e0;
	den = (abs(den) < 1e-6) ? 1e-6 : den;
	float t = clamp((x - e0) / den, 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// 주기 2pi 를 정확히 지키는 부드러운 1D 노이즈.
float theta_wave(float th, float lobes, float sd, float phase) {
	float o = 0.0;
	float amp = 0.0;
	for (int h = 1; h <= 8; h++) {
		float fh = float(h);
		if (fh > lobes) {
			break;
		}
		float a = (0.5 + 0.5 * hash11(sd + fh * 7.13)) / pow(fh, 0.8);
		o += a * sin(fh * th + hash11(sd + fh * 3.77) * TAU_ + phase * fh * 0.3);
		amp += a;
	}
	return (amp > 0.0) ? o / amp : 0.0;
}

// 극좌표(theta, r) 격자 위의 value noise.
// nt(각도 분할) >> nr(반경 분할) 로 두면 반경 방향으로 길쭉한 결 = 방사형 안개 가닥.
// theta 는 모듈로로 감아 이음매가 안 생긴다.
float polar_noise(float th, float rn, float nt, float nr, float sd, float spin) {
	float acc = 0.0;
	float amp = 1.0;
	float tot = 0.0;
	float s = sd;
	for (int o = 0; o < 3; o++) {
		float oct = exp2(float(o));
		float NT = max(3.0, nt * oct);
		float NR = max(1.0, nr * oct);
		float tt = fract(th / TAU_ + spin) * NT;
		float rr = clamp(rn, 0.0, 1.0) * NR;
		float t0 = floor(tt);
		float r0 = floor(rr);
		float ft = tt - t0;
		ft = ft * ft * (3.0 - 2.0 * ft);
		float fr = rr - r0;
		fr = fr * fr * (3.0 - 2.0 * fr);
		float t0w = mod(t0, NT);
		float t1w = mod(t0 + 1.0, NT);
		float g00 = hash21(vec2(t0w, r0) + s);
		float g01 = hash21(vec2(t1w, r0) + s);
		float g10 = hash21(vec2(t0w, r0 + 1.0) + s);
		float g11 = hash21(vec2(t1w, r0 + 1.0) + s);
		acc += amp * mix(mix(g00, g01, ft), mix(g10, g11, ft), fr);
		tot += amp;
		amp *= 0.5;
		s += 19.7;
	}
	return acc / tot;
}


void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float th = atan(p.y, p.x);

	// --- 1) 각도별 혓바닥 : 이게 "글로우"와 "안개"를 가른다
	//   ★ 정규화 필수. 혓바닥·응시 늘림이 곱해지면 실제 외곽이 outer_ratio 를 크게 넘는다.
	float gs = (gaze_enabled > 0.5) ? gaze_stretch : 0.0;
	float tongue = 0.5 + 0.5 * theta_wave(th, plume_lobes, seed + 13.0, drift_phase * 2.0);
	float norm = (1.0 + plume) * (1.0 + gs);
	float edge = outer_ratio * (1.0 - plume + 2.0 * plume * tongue) / norm;
	edge *= 1.0 + gs * cos(th - gaze_angle);
	edge = max(edge, ball_ratio * 1.12);

	// --- 2) 방사 falloff : 공 표면 1 -> 혓바닥 끝 0
	float fall = pow(sstep(edge, ball_ratio * 0.98, r), falloff_exp);
	//   안쪽 겹은 반드시 edge 기준으로. ball_ratio 배수로 박으면 작은 반경에서 밖으로 샌다.
	float bloom_edge = ball_ratio + 0.45 * (edge - ball_ratio);
	fall += inner_bloom * max(sstep(bloom_edge, ball_ratio * 0.98, r) - fall, 0.0);

	// --- 3) 방사형 결
	float rn = clamp(r / max(outer_ratio, 1e-3), 0.0, 1.0);
	float w = polar_noise(th, rn, wisp_lobes, wisp_radial, seed + 31.0, drift_phase * 0.08);
	float dens = (1.0 - wisp) + wisp * 2.0 * w;

	// --- 4) 밴딩은 최종 알파에 딱 한 번
	float a = clamp(fall * dens, 0.0, 1.0);
	a = ceil(a * bands) / bands;
	float fog = clamp(a * peak * col_mist.a * alpha_gain, 0.0, 1.0);

	// --- 5) 코어 링 : 실루엣을 못 박는 얇고 밝은 테두리 ("원으로 읽힐 것")
	float ring_c = ball_ratio * 1.09 * (1.0 + wobble * theta_wave(th, 4.0, seed + 91.0, 0.0));
	//   pow(음수, 2.0) 은 GLSL 에서 정의되지 않는다. 반드시 곱셈으로.
	float rd = (r - ring_c) / max(core_w_norm, 1e-5);
	float ring = exp(-rd * rd) * core_alpha * col_core.a * core_gain;

	// --- 6) 색 : 안쪽 core -> 중간 mist -> 바깥 outer
	float u = clamp((r - ball_ratio) / max(outer_ratio - ball_ratio, 1e-3), 0.0, 1.0);
	vec3 rgb = (u < 0.5)
		? mix(col_mist.rgb, col_core.rgb, 1.0 - u * 2.0)
		: mix(col_outer.rgb, col_mist.rgb, 2.0 - u * 2.0);

	float total = clamp(fog + ring * (1.0 - fog), 0.0, 1.0);
	float mixv = clamp(ring * (1.0 - fog) / max(total, 1e-4), 0.0, 1.0);
	rgb = mix(rgb, col_core.rgb, mixv);

	// 공 안쪽은 비운다 — 공 본체가 가독성 1순위
	float inner_cut = clamp((r - ball_ratio * 0.90) / max(ball_ratio * 0.16, 1e-5), 0.0, 1.0);

	COLOR = vec4(rgb, total * inner_cut);
}
