shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float effect_age = 0.0;
uniform float effect_seed = 0.0;
uniform int style_kind = 0;
uniform float effect_radius = 12.0;
uniform float wake_length = 48.0;
uniform vec2 canvas_origin = vec2(-63.6, -26.4);
uniform vec2 canvas_extent = vec2(85.2, 52.8);
uniform bool soul_pass = false;
varying vec4 incoming_color;
varying vec2 soul_uv;
varying float soul_phase;
varying float soul_alive;

vec2 turn(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float soft_shape(float distance_value) {
	return 1.0 - smoothstep(-0.035, 0.07, distance_value);
}

float scythe(vec2 p) {
	// Crescent blade plus a diagonal bone shaft; its rotation never changes flight.
	float outer = length(p) - 1.06;
	float hollow = 0.91 - length(p - vec2(0.4, 0.02));
	float crescent = max(outer, hollow);
	vec2 shaft = turn(p, -0.72) - vec2(0.0, -0.09);
	float handle = max(abs(shaft.x) - 0.068, abs(shaft.y) - 0.78);
	return min(crescent, handle);
}

void vertex() {
	incoming_color = COLOR;
	soul_uv = VERTEX;
	soul_phase = 0.0;
	soul_alive = 1.0;
	if (soul_pass) {
		float index = UV.x;
		float phase = fract(effect_age * (style_kind == 3 ? 1.5 : 2.1) + index * 0.618034 + effect_seed * 0.013);
		float count = style_kind == 3 ? 24.0 : (style_kind == 0 ? 8.0 : (style_kind == 1 ? 10.0 : 12.0));
		float spread = style_kind == 3 ? 0.85 : 0.4;
		float side = sin(index * 2.39996 + phase * 4.0);
		vec2 center = vec2(-effect_radius * 0.5 - phase * wake_length, side * effect_radius * spread * (0.4 + phase));
		float scale = effect_radius * (style_kind == 3 ? 0.22 : 0.14) * (1.0 - phase * 0.5);
		VERTEX = center + VERTEX * vec2(scale * 2.0, scale);
		soul_phase = phase;
		soul_alive = index < count ? 1.0 : 0.0;
	}
}

void fragment() {
	vec3 violet = vec3(0.46, 0.16, 0.72);
	vec3 green = vec3(0.39, 0.92, 0.52);
	vec3 bone = vec3(0.92, 0.93, 0.79);
	if (soul_pass) {
		float ghost = soft_shape(length(soul_uv * vec2(0.8, 1.2)) - 0.75);
		float center = exp(-dot(soul_uv, soul_uv) * 5.0);
		float fade = pow(1.0 - soul_phase, 1.6) * smoothstep(0.0, 0.08, soul_phase) * soul_alive;
		COLOR = vec4(mix(violet, green, center), ghost * fade * 0.62) * incoming_color;
	} else {
		vec2 p = (canvas_origin + UV * canvas_extent) / max(effect_radius, 0.01);
		float tail_units = wake_length / max(effect_radius, 0.01);
		float progress = clamp(-p.x / tail_units, 0.0, 1.0);
		float taper = pow(1.0 - progress, 0.7);
		float sway = sin(-p.x * 2.2 - effect_age * 8.0) * 0.26 * progress;
		float smoke = 0.68 + 0.25 * sin(p.x * 5.0 + p.y * 8.0 + effect_age * 4.0) * sin(p.x * 2.0 - p.y * 5.0 - effect_age * 3.0);
		float tail = soft_shape(abs(p.y - sway) - taper * 0.47 * smoke) * (1.0 - smoothstep(-0.3, 0.15, p.x)) * taper;
		float body = 0.0;
		vec3 body_color = violet;
		vec3 tail_color = violet;
		float tail_alpha = tail * 0.58;
		if (style_kind == 0) {
			// Dark scaled snake, wedge head, paired green eyes, continuously curved tail.
			float snake_y = sin(-p.x * 2.25 - effect_age * 8.0) * (0.14 + progress * 0.28);
			float width = 0.34 * taper;
			float trunk = soft_shape(abs(p.y - snake_y) - width) * (1.0 - smoothstep(-0.4, -0.1, p.x)) * taper;
			float head = soft_shape(length(vec2((p.x - 0.16) / 1.1, p.y / 0.52)) - 0.8);
			body = max(trunk, head);
			float scale_pattern = abs(sin(p.x * 11.0 + abs(p.y - snake_y) * 8.0)) * abs(sin((p.y - snake_y) * 13.0));
			body_color = mix(vec3(0.085, 0.034, 0.15), vec3(0.4, 0.12, 0.58), smoothstep(0.5, 0.92, scale_pattern));
			float ridge = exp(-abs(p.y - snake_y) * 28.0) * 0.25;
			body_color += violet * ridge;
			float eyes = max(exp(-length(p - vec2(0.55, 0.21)) * 28.0), exp(-length(p - vec2(0.55, -0.21)) * 28.0));
			float soul = exp(-length((p - vec2(0.06, 0.0)) * vec2(1.5, 2.5)) * 8.0);
			body_color = mix(body_color, green, clamp(eyes * 2.8 + soul * 0.65, 0.0, 1.0));
			tail_alpha *= 0.35;
		} else if (style_kind == 1) {
			vec2 blade_p = turn(p, -effect_age * 8.0);
			float blade_distance = scythe(blade_p);
			body = soft_shape(blade_distance);
			float edge = smoothstep(-0.15, 0.005, blade_distance);
			body_color = mix(bone, violet * 1.6, edge);
			float hub = soft_shape(length(p * vec2(1.0, 1.5)) - 0.2);
			body = max(body, hub);
			body_color = mix(body_color, green, hub * 0.85);
			float echo = 0.0;
			for (int i = 1; i <= 3; i++) {
				echo = max(echo, soft_shape(scythe(turn(p, -effect_age * 8.0 + float(i) * 0.3))) * (0.38 - float(i) * 0.08));
			}
			tail_alpha = max(tail_alpha * 0.36, echo);
		} else if (style_kind == 2) {
			// Leading spirit skull and narrow purple shroud, distinct from a circular orb.
			vec2 q = vec2((p.x - 0.08) / 0.86, p.y / 0.65);
			float hood = length(q) - 0.93;
			body = soft_shape(hood);
			float core = exp(-dot(q, q) * 3.8);
			body_color = mix(violet, mix(green, bone, core * 0.8), smoothstep(0.1, 0.72, core));
			float eyes = max(exp(-length(p - vec2(0.27, 0.15)) * 30.0), exp(-length(p - vec2(0.27, -0.15)) * 30.0));
			body_color *= 1.0 - eyes * 0.85;
			tail_color = mix(violet, green, exp(-abs(p.y - sway) * 10.0) * 0.6);
		} else {
			// A cluster of three split soul cores and braided spectral wake.
			float cluster = 0.0;
			float light = 0.0;
			for (int i = 0; i < 3; i++) {
				float angle = effect_age * 3.3 + float(i) * 2.0944;
				vec2 center = vec2(cos(angle) * 0.38, sin(angle) * 0.52);
				float distance_to_soul = length((p - center) * vec2(1.05, 1.35));
				cluster = max(cluster, soft_shape(distance_to_soul - 0.55));
				light = max(light, exp(-distance_to_soul * distance_to_soul * 15.0));
				float braid_y = sin(-p.x * 2.8 + angle - effect_age * 6.0) * (0.35 + progress * 0.55);
				float braid = exp(-abs(p.y - braid_y) * 14.0) * taper * (1.0 - smoothstep(-0.4, 0.0, p.x));
				tail_alpha = max(tail_alpha, braid * 0.62);
			}
			body = cluster;
			body_color = mix(violet, mix(green, bone, light), smoothstep(0.08, 0.85, light));
			tail_color = mix(violet, green, 0.38);
		}
		float alpha = body + tail_alpha * (1.0 - body);
		vec3 rgb = (body_color * body + tail_color * tail_alpha * (1.0 - body)) / max(alpha, 0.001);
		COLOR = vec4(rgb, alpha) * incoming_color;
	}
}
