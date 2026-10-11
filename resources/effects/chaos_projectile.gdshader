shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float effect_radius = 14.0;
uniform float effect_age = 0.0;
uniform float effect_seed = 0.0;
uniform float wake_length = 48.0;
uniform int geometry_branch = -1;
uniform vec2 canvas_origin = vec2(-64.0, -25.0);
uniform vec2 canvas_extent = vec2(90.0, 50.0);
uniform bool fragment_pass = false;
varying vec2 crystal_uv;
varying float crystal_fade;

mat2 rotate(float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
}

float segment(vec2 p, vec2 a, vec2 b, float width, float aa) {
	vec2 d = b - a;
	float t = clamp(dot(p - a, d) / max(dot(d, d), 0.0001), 0.0, 1.0);
	return 1.0 - smoothstep(width, width + aa, length(p - a - d * t));
}

float polygon_edge(vec2 p, float sides, float radius, float width, float aa) {
	float sector = 6.2831853 / sides;
	float a = atan(p.y, p.x);
	float edge_distance = cos(floor(0.5 + a / sector) * sector - a) * length(p);
	return 1.0 - smoothstep(width, width + aa, abs(edge_distance - radius));
}

void vertex() {
	if (fragment_pass) {
		float i = UV.x;
		vec2 corner = VERTEX;
		float phase = fract(i * 0.6180339 + effect_seed * 0.017 + effect_age * 1.7);
		float side = mod(i, 2.0) * 2.0 - 1.0;
		float spread = side * effect_radius * (0.12 + phase * 0.62);
		float sway = sin(i * 7.1 + effect_seed * 0.37 + effect_age * 2.7) * effect_radius * 0.12;
		float angle = i * 1.71 + effect_seed * 0.11 + effect_age * side * 1.6;
		vec2 extent = vec2(0.13 + mod(i, 3.0) * 0.022, 0.065) * effect_radius;
		VERTEX = vec2(-effect_radius * 0.9 - phase * wake_length, spread + sway) + rotate(angle) * (corner * extent);
		crystal_uv = corner;
		crystal_fade = (1.0 - phase) * (1.0 - phase);
	}
}

void fragment() {
	vec4 inherited = COLOR;
	vec3 violet = vec3(0.5, 0.09, 0.92);
	vec3 magenta = vec3(0.96, 0.17, 0.54);
	vec3 ice = vec3(0.58, 1.0, 0.98);
	// These colors identify an actual host branch, never spawn a second projectile.
	float branch_tint = geometry_branch == 0 ? 0.8 : (geometry_branch == 2 ? 0.15 : 0.45);
	vec3 glass = mix(violet, magenta, branch_tint);
	vec3 rgb = glass;
	float alpha = 0.0;
	if (fragment_pass) {
		vec2 p = crystal_uv;
		float shard = 1.0 - smoothstep(0.87, 1.0, abs(p.x) + abs(p.y) * 1.45);
		float edge = segment(p, vec2(-0.75, -0.05), vec2(0.6, 0.04), 0.04, 0.06);
		rgb = mix(glass, ice, edge * 0.65);
		alpha = (shard * 0.36 + edge * shard * 0.25) * crystal_fade;
	} else {
		vec2 p = (canvas_origin + UV * canvas_extent) / effect_radius;
		float r = length(p);
		float aa = max(0.014, 0.7 / effect_radius);
		float body = 1.0 - smoothstep(0.94, 1.0 + aa, r);
		float shell = 1.0 - smoothstep(0.025, 0.025 + aa, abs(r - 0.94));
		float depth = sqrt(max(0.0, 1.0 - r * r));
		vec2 glass_p = rotate(effect_seed * 0.071 + effect_age * 0.3) * p;
		float cracks = 0.0;
		for (int i = 0; i < 7; i++) {
			float f = float(i);
			float angle = f * 0.8975979 + effect_seed * 0.031;
			vec2 axis = vec2(cos(angle), sin(angle));
			vec2 tangent = vec2(-axis.y, axis.x);
			vec2 joint = axis * (0.4 + 0.12 * sin(f * 3.7 + effect_seed));
			cracks += segment(glass_p, axis * 0.13, joint, 0.017, aa);
			cracks += segment(glass_p, joint, axis * 0.93 + tangent * 0.13, 0.012, aa);
			cracks += segment(glass_p, joint, joint + axis * 0.17 - tangent * 0.2, 0.009, aa);
		}
		cracks = min(cracks, 1.0) * body;
		float core = exp(-r * r * 16.0) * body;
		float inner_facet = polygon_edge(rotate(-effect_age * 1.3) * p, 3.0, 0.2, 0.023, aa) * body;
		float reflection = exp(-length((p - vec2(-0.35, -0.36)) / vec2(0.16, 0.08)) * 2.8) * body;
		// Counter-rotating pentagonal and triangular rings stay at this collision center.
		float spin = effect_age * 1.4 + effect_seed * 0.021;
		float rings = polygon_edge(rotate(spin) * p, 5.0, 1.16, 0.021, aa) * 0.48;
		vec2 q = rotate(-spin * 0.71) * p;
		q.y *= 1.25;
		rings += polygon_edge(q, 3.0, 0.77, 0.015, aa) * 0.32;
		float core_light = clamp(core * 1.3 + inner_facet * 0.7 + reflection, 0.0, 1.0);
		rgb = mix(glass, ice, core_light);
		rgb = mix(rgb, vec3(0.95, 1.0, 1.0), core * 0.55);
		float pulse = 0.94 + 0.06 * sin(effect_age * 8.0 + effect_seed * 0.19);
		alpha = clamp(body * (0.16 + depth * 0.08) + shell * 0.5 + cracks * 0.38 + core * 0.85 + inner_facet * 0.35 + reflection * 0.4 + rings, 0.0, 1.0) * pulse;
	}
	COLOR = vec4(rgb, alpha) * inherited;
}
