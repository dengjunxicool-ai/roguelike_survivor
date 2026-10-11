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
	// Seed metadata must not tint the independent mesh batches.
	if (layer >= 2) { COLOR.rgb = vec3(1.0); }
}

float stripe(float distance, float width) {
	return 1.0 - smoothstep(width * 0.45, width, abs(distance));
}

float haze(float distance, float width) {
	return exp(-abs(distance) / max(width, 0.0001));
}

float shape_measure(vec2 q) {
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
	vec4 tint = COLOR;
	vec3 ink = vec3(0.026, 0.008, 0.047);
	vec3 purple = vec3(0.46, 0.12, 0.70);
	vec3 soul = vec3(0.27, 0.94, 0.62);
	vec3 bone = vec3(0.94, 0.91, 0.77);
	vec2 q = vec2(dot(local_position, heading), dot(local_position, vec2(-heading.y, heading.x)));
	vec2 p = q / max(effect_radius, 1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float measure = shape_measure(q);
	float edge = 1.0 - smoothstep(0.975, 1.0, measure);
	float cone_border = 0.0;
	if (shape_kind == 3 && cone_angle < 6.28) {
		float angular_margin = cone_angle * 0.5 - abs(angle);
		edge *= smoothstep(0.0, 0.028, angular_margin);
		cone_border = stripe(angular_margin, 0.035) * smoothstep(0.06, 0.16, r);
	}
	float clock = effect_age * 3.0 + phase;
	float rim = stripe(measure - 0.94, 0.018) + cone_border;
	float inner_ring = stripe(measure - 0.77, 0.011);
	float ring_glow = haze(measure - 0.93, 0.047);
	float veins = pow(0.5 + 0.5 * sin(angle * 13.0 + sin(r * 19.0 + phase) * 2.2), 21.0);
	float cracked = stripe(sin(angle * 6.0 + sin(r * 21.0 + phase) * 0.29), 0.055);
	vec3 color = ink;
	float alpha = 0.0;
	if (layer == 0) {
		float stain = (1.0 - smoothstep(0.60, 0.96, measure)) * (0.7 + 0.3 * sin(p.x * 12.0 + sin(p.y * 15.0)));
		if (profile == 0) {
			float sigil = stripe(measure - 0.55, 0.026) * (0.55 + 0.45 * sin(angle * 9.0 + phase));
			float soulmark = veins * smoothstep(0.17, 0.35, r) * (1.0 - smoothstep(0.72, 0.88, r));
			alpha = stain * 0.56 + rim * 0.37 + ring_glow * 0.12 + sigil * 0.45 + soulmark * 0.21;
			color = mix(ink, purple, clamp(rim * 0.6 + sigil + ring_glow * 0.2, 0.0, 1.0));
			color = mix(color, soul, soulmark * 0.8);
		} else if (profile == 1) {
			// Continuous countdown: contracting bands never become outward fronts.
			float charge = progress * progress;
			float inward_r = mix(0.69, 0.13, progress);
			float inward = stripe(measure - inward_r, 0.018);
			float rune_cell = fract((angle + 3.14159) / 6.283185 * 28.0);
			float rune_bar = stripe(rune_cell - 0.35, 0.065) + stripe(rune_cell - 0.67 + (measure - 0.84) * 2.0, 0.052);
			float runes = rune_bar * stripe(measure - 0.85, 0.06);
			float spokes = cracked * smoothstep(0.15, 0.24, measure) * (1.0 - smoothstep(0.72, 0.79, measure));
			float sealed_core = exp(-r * r * 60.0) * charge;
			alpha = stain * 0.48 + rim * (0.70 + charge * 0.22) + inner_ring * 0.52 + runes * 0.68 + ring_glow * 0.23 + inward * 0.72 + spokes * (0.12 + charge * 0.36) + sealed_core * 0.4;
			color = mix(ink, purple, clamp(rim + inner_ring + inward + spokes * 0.7, 0.0, 1.0));
			color = mix(color, bone, clamp(runes * 0.82 + rim * charge * 0.40, 0.0, 0.9));
			color = mix(color, soul, sealed_core * 0.65);
		} else if (profile == 3) {
			float front_r = mix(0.07, 0.96, pow(progress, 0.60));
			float front = stripe(measure - front_r, 0.045);
			float wake = haze(measure - front_r, 0.10) * (1.0 - progress);
			float dark_wake = smoothstep(front_r - 0.23, front_r - 0.07, measure) * (1.0 - smoothstep(front_r, front_r + 0.025, measure));
			float whispers = veins * wake;
			alpha = dark_wake * 0.65 + front * 0.5 + wake * 0.23 + whispers * 0.24;
			color = mix(ink, purple, clamp(front * 0.9 + wake * 0.5, 0.0, 1.0));
			color = mix(color, soul * 0.60, whispers * 0.54);
		} else {
			float front_r = mix(0.05, 0.95, pow(clamp(progress / 0.76, 0.0, 1.0), 0.45));
			float front = stripe(measure - front_r, 0.028);
			float blast = 1.0 - smoothstep(0.03, 0.72, progress);
			float inside = 1.0 - smoothstep(front_r - 0.04, front_r, measure);
			float fractures = cracked * inside * blast;
			float shards = veins * inside * (1.0 - progress);
			alpha = stain * inside * 0.57 + front * 0.89 + haze(measure - front_r, 0.065) * 0.31 + fractures * 0.71 + shards * 0.34;
			color = mix(ink, purple, clamp(front + fractures * 0.6 + shards * 0.3, 0.0, 1.0));
			color = mix(color, profile == 4 ? soul : bone, clamp(front * 0.88 + fractures * 0.93, 0.0, 1.0));
		}
	} else if (layer == 1) {
		float core_r = profile == 0 ? 0.16 : mix(0.10, 0.35, progress);
		float pit = exp(-r * r / (core_r * core_r));
		float contour = stripe(r - core_r, 0.014) * (0.60 + 0.40 * sin(angle * 11.0 + clock));
		float ember = exp(-r * r * 130.0);
		float pulse = profile == 0 ? 0.72 + 0.20 * sin(clock * 2.0) : 1.0 - smoothstep(0.0, 0.65, progress);
		float tear = cracked * pit * (profile == 0 ? 0.3 : 0.9);
		alpha = pulse * (pit * 0.88 + contour * 0.80 + ember * 0.67 + tear * 0.55);
		color = mix(ink, purple, clamp(contour + tear * 0.5, 0.0, 1.0));
		color = mix(color, soul, ember * 0.88);
		color = mix(color, bone, clamp(tear * 0.83 + contour * 0.48, 0.0, 1.0));
	} else if (layer == 2) {
		float id = batch_seed.y;
		float center = 0.5 + sin(UV.x * 10.0 + id * 20.0 + clock * 1.5) * (0.09 + UV.x * 0.15);
		float thin = stripe(UV.y - center, 0.075);
		float smoke = haze(UV.y - center, 0.22);
		float head = profile == 1 ? mix(0.92, 0.03, progress) : mix(0.05, 0.92, progress);
		if (profile == 0) { head = 0.25 + 0.48 * (0.5 + 0.5 * sin(clock + id * 15.0)); }
		float travel = haze(UV.x - head, 0.18);
		float ends = smoothstep(0.0, 0.06, UV.x) * (1.0 - smoothstep(0.91, 1.0, UV.x));
		float strength = profile == 1 ? 0.28 + progress * 0.55 : 1.0 - progress * 0.65;
		alpha = (thin * 0.57 + smoke * 0.17) * travel * ends * strength;
		color = mix(purple, soul, thin * 0.72);
		color = mix(color, bone, thin * travel * 0.40);
	} else {
		float id = batch_seed.y;
		float cycle = 0.5 + 0.5 * sin(effect_age * 8.0 + id * 25.0);
		float tip = UV.x;
		float center = 0.50 + sin(tip * 11.0 + clock * 2.0 + id * 16.0) * tip * 0.24;
		float taper = (1.0 - tip) * (0.30 + cycle * 0.10);
		float fire = 1.0 - smoothstep(taper * 0.4, taper, abs(UV.y - center));
		float outline = stripe(abs(UV.y - center) - taper * 0.66, 0.035);
		float root = smoothstep(0.0, 0.07, tip) * (1.0 - smoothstep(0.76, 1.0, tip));
		float release = profile == 0 ? 0.80 : 1.0 - smoothstep(0.05, 0.85, progress);
		alpha = root * release * (fire * 0.80 + outline * 0.48);
		color = mix(purple, soul, fire * (1.0 - tip) * 0.95);
		color = mix(color, bone, outline * 0.60);
	}
	// Respect the host's fade/modulation for both polygons and mesh batches.
	COLOR = vec4(color, clamp(alpha * edge, 0.0, 0.98)) * tint;
}
