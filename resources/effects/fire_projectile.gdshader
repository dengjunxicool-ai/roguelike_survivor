shader_type canvas_item;
render_mode unshaded, blend_mix;

// Host age is the sole clock; never use global shader time.
uniform float effect_age = 0.0;
uniform int style_kind = 0;
uniform float effect_radius = 12.0;
uniform float wake_length = 48.0;
uniform vec2 canvas_origin = vec2(-58.8, -21.6);
uniform vec2 canvas_extent = vec2(78.0, 43.2);
uniform bool ember_pass = false;
uniform int ember_count = 12;
varying vec4 incoming_color;
varying vec4 ember_color;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float turbulence(vec2 p) {
	return noise21(p) * 0.58 + noise21(p * 2.03 + 9.4) * 0.28 + noise21(p * 4.07 + 3.1) * 0.14;
}

void vertex() {
	incoming_color = COLOR;
	ember_color = vec4(1.0);
	if (ember_pass) {
		float index = UV.x;
		float phase = fract(effect_age * (style_kind == 1 ? 1.65 : 2.7) + index * 0.618034);
		float side = sin(index * 2.39996);
		float spread = effect_radius * (0.32 + phase * 0.95);
		float wave = sin(phase * 8.0 + index) * effect_radius * 0.13;
		vec2 center = vec2(-effect_radius * 0.65 - phase * wake_length, side * spread + wave);
		float scale = (style_kind == 2 ? 0.7 : 1.0) * (0.55 + effect_radius * 0.08);
		VERTEX = center + vec2(VERTEX.x * scale * (1.8 - phase * 0.8), VERTEX.y * scale * 0.38);
		float alive = index < float(ember_count) ? 1.0 : 0.0;
		float fade = pow(1.0 - phase, 1.5) * smoothstep(0.0, 0.09, phase) * alive;
		ember_color = vec4(mix(vec3(1.0, 0.73, 0.28), vec3(0.95, 0.21, 0.035), phase), fade * 0.83);
	}
}

void fragment() {
	if (ember_pass) {
		COLOR = ember_color * incoming_color;
	} else {
		vec2 p = (canvas_origin + UV * canvas_extent) / max(effect_radius, 0.01);
		float tail_units = wake_length / max(effect_radius, 0.01);
		float speed = style_kind == 1 ? 3.0 : 5.5;
		float n = turbulence(vec2(p.x * 1.8 + effect_age * speed, p.y * 3.6 - effect_age * 0.9));
		float distance_back = max(-p.x - 0.25, 0.0);
		float progress = clamp(distance_back / tail_units, 0.0, 1.0);
		float taper = pow(1.0 - progress, 0.75);
		float sway = sin(p.x * 2.7 + effect_age * 8.0) * progress * 0.24;
		float tail_width = (style_kind == 1 ? 0.77 : 0.7) * taper;
		float tail_distance = abs(p.y - sway) - tail_width * (0.63 + n * 0.66);
		float tip_mask = 1.0 - smoothstep(0.88, 1.0, progress);
		float tail_mask = (1.0 - smoothstep(-0.045, 0.09, tail_distance)) * tip_mask * (1.0 - smoothstep(-0.15, 0.0, p.x));
		float ribbon = exp(-abs(p.y - sway) * (4.0 + progress * 6.0)) * taper;
		float tongues = smoothstep(0.43, 0.84, n + ribbon * 0.24);
		vec3 tail_rgb = mix(vec3(0.66, 0.075, 0.016), vec3(1.0, 0.35, 0.035), tongues);
		tail_rgb = mix(tail_rgb, vec3(1.0, 0.78, 0.25), ribbon * (0.4 + tongues * 0.5));
		float tail_alpha = tail_mask * (0.7 + tongues * 0.24) * (0.96 - progress * 0.28);
		vec2 head = vec2((p.x - 0.06) / 1.15, p.y / (style_kind == 2 ? 0.65 : 0.84));
		float head_distance = length(head);
		float angle = atan(head.y, head.x);
		float edge = 0.93 + sin(angle * 5.0 + 0.6) * 0.065 + (n - 0.5) * 0.08;
		float body_mask = 1.0 - smoothstep(edge - 0.035, edge + 0.055, head_distance);
		float molten = turbulence(vec2(p.x * 3.5 - effect_age * 1.9, p.y * 4.2 + effect_age * 0.7));
		float heat = clamp(1.0 - head_distance * 0.76 + (molten - 0.5) * 0.4, 0.0, 1.0);
		vec3 body_rgb = mix(vec3(0.89, 0.16, 0.018), vec3(1.0, 0.58, 0.09), smoothstep(0.05, 0.8, heat));
		float hot_core = smoothstep(0.67, 0.91, heat) * (0.73 + 0.27 * molten);
		body_rgb = mix(body_rgb, vec3(1.0, 0.92, 0.59), hot_core);
		if (style_kind == 1) {
			// A chipped, dark armored shell with molten seams and a heated leading edge.
			float facets = cos(angle * 7.0 + 0.25) * 0.055 + cos(angle * 3.0) * 0.025;
			body_mask = 1.0 - smoothstep(0.88 + facets - 0.028, 0.88 + facets + 0.028, head_distance);
			float shell = turbulence(p * 4.3 + vec2(4.0, 8.0));
			float seam = 1.0 - smoothstep(0.015, 0.062, abs(shell - 0.5));
			float rim = smoothstep(0.64, 0.86, head_distance) * (0.42 + smoothstep(-0.3, 0.8, p.x) * 0.58);
			vec3 rock = mix(vec3(0.16, 0.035, 0.029), vec3(0.4, 0.11, 0.045), shell);
			body_rgb = mix(rock, vec3(1.0, 0.32, 0.027), max(seam * 0.9, rim));
			body_rgb = mix(body_rgb, vec3(1.0, 0.75, 0.22), seam * rim * 0.8);
		} else if (style_kind == 2) {
			// An asymmetric, pointed flame seed, visibly smaller than a fireball.
			float seed_shape = abs(p.y) + abs(p.x * 0.52 - 0.05);
			body_mask = 1.0 - smoothstep(0.53, 0.62, seed_shape);
			body_rgb = mix(vec3(1.0, 0.24, 0.018), vec3(1.0, 0.89, 0.38), 1.0 - smoothstep(0.05, 0.48, seed_shape));
		}
		float alpha = body_mask + tail_alpha * (1.0 - body_mask);
		vec3 rgb = (body_rgb * body_mask + tail_rgb * tail_alpha * (1.0 - body_mask)) / max(alpha, 0.001);
		COLOR = vec4(rgb, alpha) * incoming_color;
	}
}
