shader_type canvas_item;
render_mode unshaded;

uniform int layer = 0;
uniform int profile = 0;
uniform int shape_kind = 0;
uniform bool has_pull = true;
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
	if (layer >= 2) { COLOR.rgb = vec3(1.0); }
}

float stroke(float d, float w) {
	return 1.0 - smoothstep(w * 0.30, w, abs(d));
}

float haze(float d, float w) {
	return exp(-abs(d) / max(w, 0.0001));
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
	vec3 purple = vec3(0.55, 0.12, 0.94);
	vec3 magenta = vec3(0.96, 0.16, 0.63);
	vec3 energy = vec3(0.67, 0.93, 1.0);
	vec3 abyss = vec3(0.006, 0.004, 0.021);
	vec2 q = vec2(dot(local_position, heading), dot(local_position, vec2(-heading.y, heading.x)));
	vec2 p = q / max(effect_radius, 1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float measure = footprint(q);
	float edge = 1.0 - smoothstep(0.978, 1.0, measure);
	if (shape_kind == 3 && cone_angle < 6.28) {
		edge *= smoothstep(0.0, 0.025, cone_angle * 0.5 - abs(angle));
	}
	float clock = effect_age * 2.2 + phase;
	float rim = stroke(measure - 0.955, 0.012);
	float crack_wave = abs(fract(p.y * 5.0 + phase * 0.19) * 2.0 - 1.0) - 0.5;
	float slit = p.x - crack_wave * 0.095;
	float spiral = sin(angle * 3.0 + r * 18.0 + clock * 2.5);
	float front_radius = mix(0.10, 0.96, pow(clamp(progress / 0.86, 0.0, 1.0), 0.52));
	float alpha = 0.0;
	vec3 color = purple;
	if (layer == 0) {
		if (profile == 0) {
			// Dash endpoints and smaller fission rifts: one jagged spatial incision.
			float ends = 1.0 - smoothstep(0.60, 0.91, abs(p.y));
			float incision = stroke(abs(slit) - 0.06, 0.016) * ends;
			float branching = stroke(p.x - sign(p.y) * (0.12 + abs(p.y) * 0.27), 0.009) * stroke(abs(p.y) - 0.42, 0.17);
			alpha = incision * 0.91 + haze(slit, 0.15) * ends * 0.18 + branching * 0.55 + rim * 0.23;
			color = mix(purple, energy, incision * 0.82);
		} else if (profile == 1) {
			if (has_pull) {
				// Only an actual pull action permits inward-turning lenses.
				float rings = stroke(sin(measure * 25.0 + clock * 2.0), 0.12);
				float broken = smoothstep(-0.65, -0.15, sin(angle * 7.0 - clock));
				float curl = stroke(spiral, 0.105) * smoothstep(0.19, 0.45, r);
				alpha = rim * 0.52 + rings * broken * 0.28 + curl * 0.48 + haze(r - 0.25, 0.14) * 0.14;
				color = mix(purple, magenta, clamp(curl + rings * 0.35, 0.0, 1.0));
			} else {
				// A maw attack is a real circular outward pulse, with no suction.
				float pulse_front = stroke(measure - front_radius, 0.025);
				float teeth = stroke(sin(angle * 10.0), 0.075) * stroke(measure - front_radius * 0.83, 0.10);
				alpha = pulse_front * 0.91 + teeth * 0.66 + haze(measure - front_radius, 0.075) * 0.21;
				color = mix(magenta, energy, pulse_front * 0.85);
			}
		} else if (profile == 2) {
			// The short weak hit is a compact three-prong wound, with no field ring.
			float prongs = stroke(sin(angle * 3.0 + 0.35), 0.085) * smoothstep(0.07, 0.17, r) * (1.0 - smoothstep(front_radius * 0.76, front_radius, r));
			alpha = (prongs * 0.90 + haze(r, 0.20) * 0.42) * (1.0 - progress * 0.75);
			color = mix(magenta, energy, prongs * 0.78);
		} else if (profile == 3) {
			// Mutation distorts a three-lobed wave and dislocated inner membrane.
			float warped = measure + sin(angle * 3.0 + phase) * 0.10 * sin(progress * 3.14159);
			float wave = stroke(warped - front_radius, 0.026);
			float membrane = stroke(warped - front_radius * 0.58, 0.012);
			alpha = wave * 0.90 + membrane * 0.55 + haze(warped - front_radius, 0.075) * 0.24;
			color = mix(magenta, energy, wave * 0.82);
		} else if (profile == 4) {
			// Instability fission: six sharp branching spokes, doubled split fronts.
			float branches = stroke(sin(angle * 6.0 + sin(r * 13.0 + phase) * 0.33), 0.065) * smoothstep(0.12, 0.21, r) * (1.0 - smoothstep(front_radius, front_radius + 0.08, r));
			float shock = stroke(measure - front_radius, 0.018);
			alpha = branches * (1.0 - progress) * 0.82 + shock * 0.84 + stroke(measure - front_radius * 0.77, 0.009) * 0.39;
			color = mix(purple, energy, clamp(shock + branches * 0.65, 0.0, 1.0));
		} else if (profile == 5) {
			// Exchange's damage is the actual midpoint circle, not the tearing seam.
			float seam = p.y - (abs(fract(p.x * 6.0 + phase) * 2.0 - 1.0) - 0.5) * 0.12;
			float thread = stroke(seam, 0.014) * (1.0 - smoothstep(0.76, 0.93, abs(p.x)));
			float distortion = stroke(measure - mix(0.44, 0.88, progress), 0.012);
			alpha = rim * 0.72 + distortion * 0.55 + thread * 0.90 + haze(seam, 0.09) * 0.12;
			color = mix(magenta, energy, thread * 0.82);
		} else if (profile == 6) {
			// Actual singularity suction: tight three-arm accretion around black core.
			float winding = stroke(sin(angle * 3.0 + r * 23.0 + clock * 3.0), 0.075);
			float disk_rim = stroke(r - 0.33, 0.022);
			float lens = stroke(measure - 0.82 + sin(angle * 2.0 + clock) * 0.032, 0.012);
			alpha = winding * smoothstep(0.27, 0.39, r) * 0.67 + disk_rim * 0.96 + lens * 0.38 + rim * 0.40;
			color = mix(purple, energy, clamp(disk_rim + winding * 0.56, 0.0, 1.0));
		} else {
			// Singularity release: inverted corona and a broad destructive flash.
			float jagged_front = measure + sin(angle * 17.0 + phase) * 0.022 - front_radius;
			float corona = stroke(jagged_front, 0.037);
			float rupture = stroke(sin(angle * 11.0 + r * 8.0), 0.07) * smoothstep(0.22, 0.40, r) * (1.0 - smoothstep(front_radius, front_radius + 0.03, r));
			alpha = corona * 0.97 + haze(jagged_front, 0.12) * 0.29 + rupture * (1.0 - progress) * 0.65;
			color = mix(magenta, energy, clamp(corona + rupture, 0.0, 1.0));
		}
	} else if (layer == 1) {
		if (profile == 0) {
			alpha = (1.0 - smoothstep(0.025, 0.062, abs(slit))) * (1.0 - smoothstep(0.60, 0.87, abs(p.y))) * 0.88;
			color = abyss;
		} else if (profile == 1 && !has_pull) {
			alpha = exp(-r * r * 27.0) * (1.0 - smoothstep(0.07, 0.58, progress)) * 0.44;
			color = energy;
		} else if (profile == 1 || profile == 6) {
			float core_radius = profile == 6 ? 0.32 : 0.22;
			alpha = (1.0 - smoothstep(core_radius * 0.87, core_radius, r)) * 0.55;
			color = abyss;
		} else if (profile == 5) {
			alpha = haze(r, 0.28) * (1.0 - progress) * 0.40;
			color = magenta;
		} else if (profile == 7) {
			alpha = (1.0 - smoothstep(0.12, max(0.13, 0.38 * (1.0 - progress)), r)) * (1.0 - progress) * 0.82;
			color = abyss;
		} else {
			alpha = exp(-r * r * 27.0) * (1.0 - smoothstep(0.07, 0.68, progress)) * 0.72;
			color = energy;
		}
	} else if (layer == 2) {
		// Fixed tear quads: a broken zigzag filament driven solely by host age.
		float zigzag = (abs(fract(UV.x * 4.0 + batch_seed.y * 2.0) * 2.0 - 1.0) - 0.5) * 0.19;
		float filament = stroke(UV.y - 0.5 - zigzag, 0.027);
		float head = (profile == 1 && has_pull) || profile == 6 ? 1.0 - fract(effect_age * 0.5 + batch_seed.y) : mix(0.09, 0.91, progress);
		float travel = haze(UV.x - head, 0.22);
		float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.91, 1.0, UV.x));
		float strength = profile == 0 || profile == 5 ? 0.28 : 0.78;
		alpha = (filament * 0.78 + haze(UV.y - 0.5 - zigzag, 0.10) * 0.15) * travel * ends * strength;
		color = mix(magenta, energy, filament * 0.82);
	} else {
		// Thin detached crystalline splinters, not holy feathers or curse smoke.
		float t = UV.x;
		float shard_width = max(0.0, 1.0 - abs(t - 0.36) / 0.54) * 0.32;
		float shard = 1.0 - smoothstep(shard_width * 0.82, max(shard_width, 0.001), abs(UV.y - 0.5));
		float facet = stroke(UV.y - 0.5 - t * 0.10, 0.018) * shard;
		float release = (profile == 1 && has_pull) || profile == 6 ? 0.62 + 0.22 * sin(clock + batch_seed.y * 12.0) : 1.0 - smoothstep(0.18, 0.91, progress);
		alpha = (shard * 0.24 + facet * 0.65) * release * (profile == 2 ? 0.40 : 0.82);
		color = mix(purple, energy, facet);
	}
	COLOR = vec4(color, clamp(alpha * edge, 0.0, 0.98)) * incoming;
}
