shader_type canvas_item;
render_mode unshaded;

uniform int layer = 0;
uniform int profile = 0;
uniform int shape_kind = 0;
uniform float effect_age = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float effect_radius = 100.0;
uniform float footprint_length = 200.0;
uniform float footprint_width = 50.0;
uniform vec2 heading = vec2(1.0, 0.0);
uniform float cone_angle = 6.283185;
varying vec2 local_position;
varying vec2 batch_seed;

void vertex() {
	local_position = VERTEX;
	batch_seed = COLOR.rg;
	// The mesh RGB encodes a deterministic seed; retain incoming host alpha.
	if (layer >= 2) { COLOR.rgb = vec3(1.0); }
}

float line(float d, float width) {
	return 1.0 - smoothstep(width * 0.42, width, abs(d));
}

float glow(float d, float width) {
	return exp(-abs(d) / max(width, 0.0001));
}

float footprint(vec2 q) {
	if (shape_kind == 1) {
		return max(abs(q.x / max(footprint_length, 1.0) * 2.0 - 1.0), abs(q.y) / max(footprint_width * 0.5, 0.5));
	}
	if (shape_kind == 2) {
		vec2 a = abs(q);
		return min(max(a.x / max(footprint_length * 0.5, 0.5), a.y / max(footprint_width * 0.5, 0.5)), max(a.y / max(footprint_length * 0.5, 0.5), a.x / max(footprint_width * 0.5, 0.5)));
	}
	return length(q) / max(effect_radius, 1.0);
}

void fragment() {
	vec4 incoming = COLOR;
	vec3 ivory = vec3(0.98, 0.97, 0.88);
	vec3 gold = vec3(0.86, 0.76, 0.46);
	vec3 cool = vec3(0.76, 0.91, 0.93);
	vec2 q = vec2(dot(local_position, heading), dot(local_position, vec2(-heading.y, heading.x)));
	vec2 p = q / max(effect_radius, 1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float measure = footprint(q);
	float edge = 1.0 - smoothstep(0.975, 1.0, measure);
	float cone_border = 0.0;
	if (shape_kind == 3 && cone_angle < 6.28) {
		float margin = cone_angle * 0.5 - abs(angle);
		edge *= smoothstep(0.0, 0.028, margin);
		cone_border = line(margin, 0.026) * smoothstep(0.08, 0.22, r);
	}
	float clock = effect_age * 2.0 + phase;
	float rim = line(measure - 0.94, 0.012) + cone_border;
	float inner = line(measure - 0.80, 0.009);
	float rune_cell = fract((angle + 3.14159) / 6.283185 * 24.0);
	float rune = (line(rune_cell - 0.27, 0.035) + line(rune_cell - 0.64 + (measure - 0.865) * 1.8, 0.032)) * line(measure - 0.865, 0.043);
	float spokes = line(sin(angle * 6.0), 0.04) * smoothstep(0.13, 0.24, r) * (1.0 - smoothstep(0.70, 0.80, r));
	float pulse = 0.82 + 0.14 * sin(clock * 1.4);
	float alpha = 0.0;
	vec3 color = ivory;
	if (layer == 0) {
		if (profile == 0 || profile == 8 || profile == 9) {
			// Sustained protection and healing: restrained gold runes and a quiet floor.
			float floor_light = (1.0 - smoothstep(0.30, 0.95, measure)) * 0.12;
			float seal = line(r - 0.44, 0.012) + spokes * 0.36;
			if (profile == 8) {
				float plus = max(line(p.x, 0.032) * (1.0 - smoothstep(0.16, 0.26, abs(p.y))), line(p.y, 0.032) * (1.0 - smoothstep(0.16, 0.26, abs(p.x))));
				seal = plus + line(r - 0.43, 0.012) * 0.45;
				color = mix(ivory, cool, 0.26);
			} else {
				color = mix(gold, ivory, clamp(rim * 0.80 + floor_light + seal * 0.45, 0.0, 1.0));
			}
			alpha = pulse * (floor_light + rim * 0.67 + inner * 0.37 + rune * 0.65 + seal * 0.35 + glow(measure - 0.94, 0.04) * 0.12);
		} else if (profile == 10) {
			// Warning only: inward countdown and closed boundary, no blast/front/core.
			float inward = line(measure - mix(0.74, 0.16, progress), 0.009);
			alpha = rim * 0.67 + rune * 0.48 + inner * 0.27 + inward * (0.17 + progress * 0.22);
			color = mix(gold, ivory, rim * progress * 0.45);
		} else if (profile == 1) {
			// Individual circular footprints compose the real dash path.
			float sweep = line(p.y - sin(p.x * 4.0) * 0.14, 0.026) * (1.0 - smoothstep(0.16, 0.92, abs(p.x)));
			float wing = line(abs(p.y) - (0.32 - abs(p.x) * 0.20), 0.030) * (1.0 - smoothstep(0.25, 0.80, abs(p.x)));
			alpha = (sweep * 0.8 + wing * 0.55 + glow(measure - 0.65, 0.09) * 0.18) * (1.0 - progress * 0.55);
			color = mix(ivory, gold, wing * 0.36);
		} else if (profile == 7) {
			float lateral = shape_kind == 1 ? q.y / max(footprint_width * 0.5, 0.5) : p.y;
			float spine = line(lateral, 0.055);
			float borders = line(abs(lateral) - 0.74, 0.018);
			float lamina = line(sin(q.x / max(effect_radius, 1.0) * 34.0 - clock * 5.0), 0.17) * glow(lateral, 0.24);
			alpha = spine * 0.86 + glow(lateral, 0.20) * 0.22 + borders * 0.65 + lamina * 0.24;
			color = mix(gold, ivory, clamp(spine + lamina, 0.0, 1.0));
		} else {
			float front_r = mix(0.08, 0.96, pow(clamp(progress / 0.78, 0.0, 1.0), 0.48));
			float front = line(measure - front_r, profile == 6 ? 0.04 : 0.020);
			float wake = glow(measure - front_r, 0.065) * (1.0 - progress);
			float rays = line(sin(angle * (profile == 6 ? 8.0 : 12.0)), 0.045) * smoothstep(0.12, 0.24, r) * (1.0 - smoothstep(front_r - 0.05, front_r, r));
			alpha = front * 0.84 + wake * 0.28 + rays * (1.0 - progress) * 0.40;
			if (profile == 2 || profile == 4) { alpha += rim * 0.42 + rune * 0.28; }
			if (profile == 5) { alpha += line(measure - front_r * 0.75, 0.009) * 0.48; }
			color = mix(gold, ivory, clamp(front + rays * 0.80, 0.0, 1.0));
		}
	} else if (layer == 1) {
		float flash = 1.0 - smoothstep(0.05, 0.64, progress);
		float halo = exp(-r * r * 34.0);
		if (profile == 4) {
			// A narrow, straight descending judgment shaft; never an electric zigzag.
			float shaft = line(p.x, 0.034) * (1.0 - smoothstep(0.24, 0.85, abs(p.y)));
			float crown = line(p.y + 0.24, 0.025) * (1.0 - smoothstep(0.07, 0.20, abs(p.x)));
			alpha = (shaft * 0.96 + crown * 0.8 + halo * 0.48) * flash;
		} else if (profile == 2) {
			float head = (1.0 - smoothstep(0.18, 0.24, abs(p.x))) * (1.0 - smoothstep(0.06, 0.09, abs(p.y + 0.10)));
			float handle = line(p.x, 0.026) * smoothstep(-0.06, -0.02, p.y) * (1.0 - smoothstep(0.19, 0.23, p.y));
			alpha = (head * 0.85 + handle * 0.8 + halo * 0.35) * flash;
		} else if (profile == 7) {
			float lateral = shape_kind == 1 ? q.y / max(footprint_width * 0.5, 0.5) : p.y;
			alpha = (line(lateral, 0.026) * 0.85 + glow(lateral, 0.08) * 0.18) * pulse;
		} else {
			alpha = (halo * 0.65 + line(r - 0.22, 0.018) * 0.55) * flash;
		}
		color = ivory;
	} else if (layer == 2) {
		float id = batch_seed.y;
		float center = 0.50 + sin(UV.x * 3.14159) * sin(clock + id * 15.0) * 0.08;
		float shaft = line(UV.y - center, 0.038);
		float soft = glow(UV.y - center, 0.15);
		float head = profile == 10 ? mix(0.90, 0.05, progress) : mix(0.12, 0.92, progress);
		if (profile == 0 || profile == 8 || profile == 9) { head = 0.34 + 0.22 * sin(clock + id * 13.0); }
		float travel = glow(UV.x - head, 0.28);
		float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
		alpha = (shaft * 0.62 + soft * 0.15) * travel * ends * (profile == 10 ? 0.35 : 0.95);
		color = mix(gold, ivory, shaft);
	} else {
		// Symmetric feather vane, fine barbs and a clean white quill.
		float t = UV.x;
		float center = 0.5 + sin(t * 3.14159) * 0.06 * sin(clock + batch_seed.y * 16.0);
		float vane_width = pow(max(sin(t * 3.14159), 0.0), 0.8) * 0.34;
		float vane = 1.0 - smoothstep(vane_width * 0.55, max(vane_width, 0.001), abs(UV.y - center));
		float quill = line(UV.y - center, 0.032);
		float barbs = line(sin(t * 65.0 + abs(UV.y - center) * 22.0), 0.18) * vane;
		float ends = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.91, 1.0, t));
		float release = profile == 0 || profile == 8 || profile == 9 ? pulse : 1.0 - smoothstep(0.20, 0.93, progress);
		alpha = (vane * 0.22 + quill * 0.6 + barbs * 0.25) * ends * release;
		color = mix(gold, ivory, clamp(quill + vane * 0.75, 0.0, 1.0));
	}
	COLOR = vec4(color, clamp(alpha * edge, 0.0, 0.98)) * incoming;
}
