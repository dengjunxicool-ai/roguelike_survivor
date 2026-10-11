shader_type canvas_item;
render_mode unshaded;

// Parent-owned simulation time keeps cloud motion synchronized with pause and pooling.
uniform float effect_age = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform bool ground_layer = false;
varying vec2 plane_position;

void vertex() {
	// Polygon2D has no backing texture: UV is not defined by a texture size.
	plane_position = VERTEX;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), u.x), u.y);
}

float cloud_noise(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	return noise(p) * 0.57 + noise(turn * p * 2.03 + 11.7) * 0.28
		+ noise(turn * turn * p * 4.07 + 23.1) * 0.15;
}

void fragment() {
	vec2 p = plane_position;
	float t = effect_age;
	float r = length(p);
	vec2 flow = vec2(t * 0.19, -t * 0.11) + vec2(phase);
	if (ground_layer) {
		float n = noise(p * 5.0 + flow);
		float fog = (1.0 - smoothstep(0.38, 0.98, r)) * (0.035 + n * 0.08);
		float ring = (1.0 - smoothstep(0.008, 0.025, abs(r - 0.91)))
			* (0.18 + 0.13 * n);
		float angle = atan(p.y, p.x);
		float streak = pow(max(0.0, sin(angle * 7.0 + r * 17.0 - t * 1.8)), 12.0)
			* smoothstep(0.52, 0.75, r) * (1.0 - smoothstep(0.8, 0.97, r)) * 0.12;
		COLOR = vec4(mix(vec3(0.28, 0.55, 0.69), vec3(0.70, 0.94, 1.0), n),
			(fog + ring + streak) * opacity);
	} else {
		vec2 q = mat2(vec2(0.92, 0.39), vec2(-0.39, 0.92)) * (p * vec2(1.0, 1.17));
		q += sin(q.yx * 3.2 + vec2(t * 0.31, -t * 0.23) + phase) * 0.22;
		float n = cloud_noise(q * 3.4 + flow);
		float billow = cloud_noise(q * 2.1 - flow * 0.7 + vec2(8.4));
		float edge = 1.0 - smoothstep(0.62, 1.02, length(q) + (n - 0.5) * 0.25);
		float density = smoothstep(0.25, 0.80, n * 0.7 + billow * 0.3);
		float highlight = smoothstep(0.5, 0.85, billow) * (0.65 - p.y * 0.25);
		vec3 shade = mix(vec3(0.20, 0.34, 0.46), vec3(0.68, 0.83, 0.90), density);
		shade = mix(shade, vec3(0.91, 0.98, 1.0), highlight * 0.65);
		COLOR = vec4(shade, edge * (0.12 + density * 0.29) * opacity);
	}
}
