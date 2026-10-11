shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int style_kind = 0;
uniform float effect_radius = 12.0;
uniform float effect_age = 0.0;
uniform float effect_seed = 0.0;
uniform float wake_length = 48.0;
uniform vec2 canvas_origin = vec2(-64.0, -20.0);
uniform vec2 canvas_extent = vec2(116.0, 40.0);
uniform bool feather_pass = false;
varying vec2 feather_uv;
varying float feather_fade;

float line_mask(vec2 p, vec2 a, vec2 b, float width) {
	vec2 d = b - a;
	float t = clamp(dot(p - a, d) / max(dot(d, d), 0.0001), 0.0, 1.0);
	return 1.0 - smoothstep(width, width + 0.018, length(p - a - d * t));
}

void vertex() {
	if (feather_pass) {
		float i = UV.x;
		vec2 corner = VERTEX;
		float count = style_kind == 0 ? 12.0 : 20.0;
		float phase = fract(i * 0.6180339 + effect_seed * 0.071 + effect_age * 1.35);
		float side = mod(i, 2.0) * 2.0 - 1.0;
		float wing = side * effect_radius * (0.2 + 0.58 * phase);
		float sway = sin(i * 2.7 + effect_seed + effect_age * 5.0) * effect_radius * 0.08;
		vec2 extent = vec2(effect_radius * (0.28 + phase * 0.12), effect_radius * 0.13);
		float angle = side * (0.4 + phase * 0.4);
		mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		VERTEX = vec2(-effect_radius * 0.65 - phase * wake_length, wing + sway) + turn * (corner * extent);
		feather_uv = corner;
		feather_fade = (1.0 - phase) * (1.0 - phase) * step(i, count - 1.0);
	}
}

void fragment() {
	vec4 inherited = COLOR;
	vec3 platinum = vec3(1.0, 0.98, 0.9);
	vec3 gold = vec3(0.91, 0.74, 0.35);
	vec3 rgb;
	float alpha;
	if (feather_pass) {
		vec2 p = feather_uv;
		float leaf = 1.0 - smoothstep(0.85, 1.0, abs(p.x) + abs(p.y) * 1.3);
		float shaft = (1.0 - smoothstep(0.06, 0.16, abs(p.y))) * (1.0 - smoothstep(0.8, 1.0, abs(p.x)));
		float barbs = (0.5 + 0.5 * cos((p.x - abs(p.y) * 0.65) * 28.0)) * leaf;
		rgb = mix(gold, platinum, 0.6 + shaft * 0.4);
		alpha = (leaf * 0.36 + shaft * 0.5 + barbs * 0.1) * feather_fade;
	} else {
		vec2 p = (canvas_origin + UV * canvas_extent) / effect_radius;
		float aa = max(0.012, 0.75 / effect_radius);
		float core;
		float ornament = 0.0;
		float glint = 0.0;
		if (style_kind == 0) {
			// Faceted hard-light lance, anchored at the actual collision center.
			float diamond = abs((p.x - 0.85) / 2.55) + abs(p.y / 0.55);
			core = 1.0 - smoothstep(0.97, 1.0 + aa, diamond);
			float spine = line_mask(p, vec2(-1.45, 0.0), vec2(3.3, 0.0), 0.065);
			glint = spine + core * (1.0 - smoothstep(0.0, 0.17, abs(p.y)));
			for (int i = 0; i < 2; i++) {
				vec2 q = (p - vec2(-0.4 - float(i) * 0.86, 0.0)) / vec2(0.24, 0.95 - float(i) * 0.17);
				float ring = 1.0 - smoothstep(0.025, 0.025 + aa * 2.0, abs(length(q) - 1.0));
				float marks = pow(max(0.0, cos(atan(q.y, q.x) * 12.0 + effect_age * 0.7)), 12.0);
				ornament += ring * (0.4 + 0.6 * marks);
			}
		} else {
			// Broad feather spear with two pairs of etched pinions.
			float diamond = abs((p.x - 0.2) / 1.8) + abs(p.y / 0.48);
			core = 1.0 - smoothstep(0.94, 1.0 + aa, diamond);
			for (int i = 0; i < 3; i++) {
				float x = -0.42 - float(i) * 0.35;
				float height = 0.86 - float(i) * 0.13;
				ornament += line_mask(p, vec2(x + 0.5, 0.04), vec2(x - 0.35, height), 0.11);
				ornament += line_mask(p, vec2(x + 0.5, -0.04), vec2(x - 0.35, -height), 0.11);
			}
			glint = line_mask(p, vec2(-1.45, 0.0), vec2(1.8, 0.0), 0.06);
			float halo = abs(length(p / vec2(0.42, 0.85)) - 1.0);
			ornament += (1.0 - smoothstep(0.018, 0.018 + aa, halo)) * 0.65;
		}
		float wake_u = clamp((-p.x - 0.65) * effect_radius / max(wake_length, 1.0), 0.0, 1.0);
		float wake_gate = step(p.x, -0.65) * (1.0 - smoothstep(0.75, 1.0, wake_u));
		float ribbon = exp(-abs(p.y) * (12.0 + wake_u * 8.0)) * wake_gate;
		float rail = exp(-abs(abs(p.y) - 0.2 * (1.0 - wake_u)) * 28.0) * wake_gate;
		float pulse = 0.9 + 0.1 * sin(effect_age * 9.0 + effect_seed * 0.13);
		rgb = mix(gold, platinum, clamp(core * 0.7 + glint, 0.0, 1.0));
		alpha = clamp(core * 0.78 + glint * 0.5 + ornament * 0.7 + ribbon * 0.28 + rail * 0.12, 0.0, 1.0) * pulse;
	}
	COLOR = vec4(rgb, alpha) * inherited;
}
