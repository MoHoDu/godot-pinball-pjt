shader_type canvas_item;
render_mode blend_add, unshaded;

// 배경 회전 조명 광선 (배경 앰비언트).
//
// 뒷배경이 중앙에서 뻗는 서커스 선버스트라서, 그 위에 각도 밴드 광선을
// 겹쳐 천천히 돌리면 캐러셀 무대 조명이 도는 것처럼 읽힌다.
// 중앙은 보드가 가리므로 안쪽은 페이드로 비운다.
//
// ★ 시간은 셰이더 TIME 이 아니라 CPU 가 phase 유니폼으로 민다 (프로젝트 관례).
//   phase 는 sin 주기(TAU)로 감아도 이음매가 없다.

uniform float phase;            // 회전 위상(rad) — CPU 가 민다
uniform float ray_count;        // 광선 밴드 수
uniform float sharpness;        // 클수록 광선 경계가 또렷해진다
uniform float max_alpha;        // 광선 최대 밝기
uniform float inner_fade_start; // 중앙 비움 시작 (정규화 반지름, 반높이 = 1)
uniform float inner_fade_end;   // 중앙 비움 끝
uniform float aspect;           // 쿼드 가로/세로

uniform vec4 light_color : source_color;


void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * 2.0;
	float r = length(p);
	float th = atan(p.y, p.x);

	// 각도 밴드 : 그림의 선버스트와 같은 극좌표 언어
	float band = 0.5 + 0.5 * sin(th * ray_count + phase);
	band = pow(band, sharpness);

	// 중앙은 보드 밑이라 비운다 — 광선은 보드 둘레 띠에서만 산다
	float radial = smoothstep(inner_fade_start, inner_fade_end, r);

	COLOR = vec4(light_color.rgb, max_alpha * band * radial * light_color.a);
}
