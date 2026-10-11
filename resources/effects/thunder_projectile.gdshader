shader_type canvas_item;
render_mode unshaded, blend_mix;

// The host owns the clock. No global time or random state.
uniform float effect_age = 0.0;
uniform int style_kind = 0;
uniform float effect_radius = 12.0;
uniform float wake_length = 60.0;
uniform vec2 canvas_origin = vec2(-72.0, -24.0);
uniform vec2 canvas_extent = vec2(96.0, 48.0);
uniform bool lightning_pass = false;
varying vec4 incoming_color;
varying vec4 electric_color;

float hash11(float p) {
	return fract(sin(p * 127.1 + 43.7) * 43758.5453);
}

float zigzag(float t, float strand, float tick) {
	float cell = t * 12.0;
	float left = floor(cell);
	return mix(hash11(left + strand * 23.0 + tick * 71.0), hash11(left + 1.0 + strand * 23.0 + tick * 71.0), fract(cell)) * 2.0 - 1.0;
}

void vertex() {
	incoming_color = COLOR;
	electric_color = vec4(1.0);
	if (lightning_pass) {
		float strand = UV.x;
		float t = UV.y;
		float side = VERTEX.y;
		float tick = floor(effect_age * (style_kind == 2 ? 27.0 : 21.0));
		float main_strand = strand < 2.0 ? 1.0 : 0.0;
		float branch = max(strand - 2.0, 0.0);
		float begin = main_strand > 0.5 ? 0.0 : 0.2 + branch * 0.12;
		float travel = main_strand > 0.5 ? t : begin + t * 0.32;
		float spread = effect_radius * (0.15 + travel * 0.48);
		float displacement = zigzag(t, strand, tick) * spread;
		float polarity = mod(strand, 2.0) < 0.5 ? -1.0 : 1.0;
		float fork = (1.0 - main_strand) * polarity * effect_radius * t * (0.5 + branch * 0.13);
		vec2 center = vec2(-effect_radius * 0.35 - travel * wake_length, displacement + fork);
		float width = (main_strand > 0.5 ? 0.9 : 0.5) * (0.55 + effect_radius * 0.035) * (1.0 - t * 0.68);
		VERTEX = center + vec2(0.0, side * width);
		float fade = (1.0 - t) * (main_strand > 0.5 ? 0.94 : 0.65);
		vec3 tint = mix(vec3(0.6, 0.48, 1.0), vec3(0.68, 0.96, 1.0), main_strand);
		electric_color = vec4(tint, fade);
	}
}

void fragment() {
	if (lightning_pass) {
		COLOR = electric_color * incoming_color;
	} else {
		vec2 p = (canvas_origin + UV * canvas_extent) / max(effect_radius, 0.01);
		float tick = floor(effect_age * 21.0);
		float pulse = 0.94 + 0.06 * sin(effect_age * 19.0);
		vec2 head = p;
		float d = length(head * vec2(0.93, 1.08));
		if (style_kind == 1) {
			d = abs(p.x * 0.62) + abs(p.y * 1.5);
		} else if (style_kind == 2) {
			d = length(p * vec2(0.72, 1.42));
		}
		float halo = exp(-d * d * 1.6) * 0.5;
		float body = 1.0 - smoothstep(0.63, 1.0, d);
		float core = 1.0 - smoothstep(0.0, 0.64, d);
		float angle = atan(p.y, p.x);
		float corona_radius = 0.9 + sin(angle * 7.0 + tick * 0.8) * 0.09 + sin(angle * 13.0 - tick) * 0.04;
		float corona = exp(-abs(d - corona_radius) * 30.0);
		float vein_path = sin(p.x * 7.0 + tick * 1.7) * 0.12 + sin(p.x * 15.0 - tick) * 0.06;
		float vein = exp(-abs(p.y - vein_path) * 40.0) * body;
		float tail_t = clamp((-p.x - 0.15) / (wake_length / max(effect_radius, 0.01)), 0.0, 1.0);
		float wake = exp(-abs(p.y) * (3.0 + tail_t * 6.0)) * (1.0 - tail_t) * (1.0 - smoothstep(-0.1, 0.1, p.x)) * 0.28;
		vec3 cyan = vec3(0.18, 0.69, 1.0);
		vec3 purple = vec3(0.4, 0.23, 0.92);
		vec3 white = vec3(0.86, 0.98, 1.0);
		float solid_alpha = body * 0.88;
		float glow_alpha = max(halo * pulse, wake);
		float alpha = max(solid_alpha, max(glow_alpha, corona * 0.85));
		vec3 tint = mix(purple, cyan, max(body, wake * 2.0));
		tint = mix(tint, white, max(core * pulse, max(vein * 0.87, corona * 0.75)));
		COLOR = vec4(tint, alpha) * incoming_color;
	}
}
