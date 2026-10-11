shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float effect_age = 0.0;
uniform vec2 link_span = vec2(100.0, 0.0);
uniform float link_bend = 8.0;
uniform float link_phase = 0.0;
uniform int link_kind = 0;
varying vec4 incoming_color;
varying vec2 soul_uv;
varying float soul_fade;

void vertex() {
	incoming_color = COLOR;
	soul_uv = VERTEX;
	float index = UV.x;
	float phase = fract(index / 16.0 + effect_age * 1.9);
	float t = link_kind == 0 ? 1.0 - phase : phase;
	float span_length = length(link_span);
	vec2 direction = span_length > 0.001 ? link_span / span_length : vec2(1.0, 0.0);
	vec2 normal = vec2(-direction.y, direction.x);
	vec2 center = link_span * t + normal * link_bend * sin(t * 3.14159265) * sin(t * 6.2831853 + link_phase);
	float scale = link_kind == 0 ? 3.1 : 2.1;
	VERTEX = center + direction * VERTEX.x * scale * (link_kind == 0 ? 1.3 : 3.0) + normal * VERTEX.y * scale;
	soul_fade = smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.96, 1.0, t)) * (span_length > 0.001 ? 1.0 : 0.0);
}

void fragment() {
	float mask = 1.0 - smoothstep(0.55, 1.0, length(soul_uv));
	float core = exp(-dot(soul_uv, soul_uv) * 6.0);
	vec3 color_value = mix(vec3(0.5, 0.17, 0.76), vec3(0.54, 0.95, 0.61), core);
	color_value = mix(color_value, vec3(0.91, 0.95, 0.8), core * 0.5);
	COLOR = vec4(color_value, mask * soul_fade * 0.9) * incoming_color;
}
