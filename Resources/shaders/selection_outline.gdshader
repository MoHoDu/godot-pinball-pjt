shader_type canvas_item;


uniform bool outline_enabled = false;

uniform vec4 outline_color : source_color = vec4(
	1.0,
	0.75,
	0.05,
	1.0
);

uniform float outline_size : hint_range(1.0, 16.0) = 7.0;
uniform float glow_size : hint_range(1.0, 24.0) = 16.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.65;
uniform float emission_strength : hint_range(1.0, 5.0) = 2.0;


/**
 * 지정한 거리 주변에서 가장 높은 알파값을 반환합니다.
 */
float sample_surrounding_alpha(
	sampler2D source_texture,
	vec2 uv,
	vec2 pixel_size,
	float radius
) {
	vec2 offset = pixel_size * radius;
	float alpha = 0.0;

	// 상하좌우
	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(offset.x, 0.0)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(-offset.x, 0.0)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(0.0, offset.y)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(0.0, -offset.y)
		).a
	);

	// 대각선
	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(offset.x, offset.y)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(-offset.x, offset.y)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(offset.x, -offset.y)
		).a
	);

	alpha = max(
		alpha,
		texture(
			source_texture,
			uv + vec2(-offset.x, -offset.y)
		).a
	);

	return alpha;
}


void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	vec4 final_color = base_color;

	if (outline_enabled) {
		// 원본 이미지에 가까운 굵은 실선 외곽선입니다.
		float inner_alpha = max(
			sample_surrounding_alpha(
				TEXTURE,
				UV,
				TEXTURE_PIXEL_SIZE,
				outline_size
			),
			sample_surrounding_alpha(
				TEXTURE,
				UV,
				TEXTURE_PIXEL_SIZE,
				outline_size * 0.5
			)
		);

		// 외곽선 바깥쪽의 가까운 발광 영역입니다.
		float near_glow_alpha = sample_surrounding_alpha(
			TEXTURE,
			UV,
			TEXTURE_PIXEL_SIZE,
			glow_size * 0.5
		);

		// 외곽선에서 더 멀리 퍼지는 약한 발광 영역입니다.
		float far_glow_alpha = sample_surrounding_alpha(
			TEXTURE,
			UV,
			TEXTURE_PIXEL_SIZE,
			glow_size
		);

		// 원본 이미지 바깥에만 실선 외곽선을 만듭니다.
		float outline_mask = clamp(
			inner_alpha - base_color.a,
			0.0,
			1.0
		);

		// 가까운 발광과 먼 발광을 결합합니다.
		float glow_mask = clamp(
			max(
				near_glow_alpha * 0.7,
				far_glow_alpha * 0.35
			) - base_color.a,
			0.0,
			1.0
		);

		// 실선 외곽선 영역에는 부드러운 발광을 중복 적용하지 않습니다.
		glow_mask *= 1.0 - outline_mask;

		float effect_alpha = max(
			outline_mask,
			glow_mask * glow_strength
		);

		// 1.0보다 높은 색상은 HDR 2D와 Glow가 활성화됐을 때
		// 실제 Bloom 효과를 발생시킵니다.
		vec3 emitted_color = (
			outline_color.rgb
			* emission_strength
		);

		vec4 outline_and_glow = vec4(
			emitted_color,
			effect_alpha
		);

		// 원본 플리퍼는 그대로 유지하고 투명 영역에만 효과를 그립니다.
		final_color = mix(
			outline_and_glow,
			base_color,
			base_color.a
		);
	}

	COLOR = final_color;
}