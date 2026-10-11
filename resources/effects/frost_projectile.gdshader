shader_type canvas_item;
render_mode unshaded, blend_add;

// Driven by Projectile._age, including pause and pool reset.
uniform float effect_age = 0.0;
uniform float profile_strength = 0.9;
uniform bool glint_pass = false;
uniform float effect_radius = 12.0;
uniform float wake_length = 48.0;
uniform int glint_count = 8;
varying vec4 frost_glint_color;

void vertex() {
	frost_glint_color = COLOR;
	if (glint_pass) {
		float index = UV.x;
		float phase = fract(effect_age * 2.3 + index * 0.618034);
		float lateral = sin(index * 2.39996) * effect_radius * (0.24 + phase * 0.7);
		vec2 center = vec2(-effect_radius - phase * wake_length, lateral);
		VERTEX = center + vec2(VERTEX.x * ((1.0 - phase) * 2.3 + 0.5), VERTEX.y * 0.7);
		float active = index < float(glint_count) ? 1.0 : 0.0;
		frost_glint_color *= vec4(0.65, 0.9, 1.0, (1.0 - phase) * 0.58 * active);
	}
}

void fragment() {
	if (glint_pass) {
		COLOR = frost_glint_color;
	} else {
	vec2 p = UV;
	float envelope = pow(p.x, 1.35) * (1.0 - smoothstep(0.86, 1.0, p.x));
	float sway = sin(p.x * 13.0 - effect_age * 8.0) * (1.0 - p.x) * 0.09;
	float ribbon = exp(-pow((p.y - 0.5 - sway) * (8.0 + p.x * 13.0), 2.0));
	float core = exp(-pow((p.y - 0.5) * 30.0, 2.0)) * 0.42;
	float flecks = 0.64 + sin(p.x * 31.0 - effect_age * 13.0) * 0.14;
	float opacity = envelope * (ribbon * flecks + core) * 0.46 * profile_strength;
	vec3 frost = mix(vec3(0.16, 0.48, 0.71), vec3(0.65, 0.91, 1.0), p.x);
	COLOR = vec4(frost, opacity) * frost_glint_color;
	}
}
