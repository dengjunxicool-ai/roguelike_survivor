shader_type canvas_item;
render_mode blend_mix;

uniform float glow_strength : hint_range(0.0, 5.0, 0.05) = 2.6;
uniform float distort_strength : hint_range(0.0, 0.2, 0.005) = 0.03;
uniform float distort_speed : hint_range(0.0, 8.0, 0.05) = 2.0;
uniform float trail_intensity : hint_range(0.0, 2.0, 0.05) = 0.85;
uniform float edge_softness : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform vec4 color_hot : source_color = vec4(1.0, 0.92, 0.35, 1.0);
uniform vec4 color_rim : source_color = vec4(1.0, 0.48, 0.08, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * distort_speed;

	uv.y += sin(uv.x * 12.0 + t) * distort_strength;
	uv.x += cos(uv.y * 8.0 + t) * distort_strength * 0.45;

	vec4 tex = texture(TEXTURE, uv);
	if (tex.a <= 0.01) {
		COLOR = vec4(0.0);
	} else {
		float forward = smoothstep(0.0, 1.0, uv.x);
		float trail = pow(1.0 - forward, 2.0) * trail_intensity;
		float source_luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float core = smoothstep(0.38, 1.0, source_luma);
		vec3 base_tex_color = tex.rgb;
		vec3 heat_tint = mix(color_rim.rgb, color_hot.rgb, core);
		vec3 color = max(base_tex_color, heat_tint * source_luma);
		color = mix(color, color_hot.rgb, core * 0.18);
		color *= 1.0 + glow_strength * (core * 0.5 + trail * 0.32);

		float soft = smoothstep(0.0, edge_softness, tex.a);
		float alpha = tex.a * soft * (1.0 + trail * 0.35);
		COLOR = vec4(color, alpha);
	}
}
