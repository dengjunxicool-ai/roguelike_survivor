shader_type canvas_item;
render_mode unshaded;

uniform int layer = 0;
uniform int profile = 0;
uniform int shape_kind = 0;
uniform float effect_age = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float effect_radius = 100.0;
uniform float footprint_length = 100.0;
uniform float footprint_width = 30.0;
uniform vec2 heading = vec2(1.0, 0.0);
uniform float cone_angle = 1.0472;
uniform vec4 column_bounds = vec4(-70.0, -165.0, 140.0, 190.0);
varying vec2 plane_position;
varying vec2 ember_seed;

void vertex() {
	plane_position = VERTEX;
	ember_seed = COLOR.rg;
	// Mesh colors carry deterministic per-ember metadata, not a color tint.
	if (layer >= 2) { COLOR.rgb = vec3(1.0); }
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

void fragment() {
	vec4 tint = COLOR;
	vec3 red = vec3(0.81, 0.105, 0.015);
	vec3 orange = vec3(1.0, 0.38, 0.035);
	vec3 gold = vec3(1.0, 0.83, 0.28);
	vec3 color = orange;
	float alpha = 0.0;
	if (layer == 3) {
		// A complete screen-up flame silhouette lives inside each static quad.
		float height = 1.0-UV.y;
		float clock = effect_age*4.8+ember_seed.x*15.0+phase;
		float sway = sin(height*7.0-clock)*height*0.18;
		float taper = pow(max(1.0-height,0.0),0.72)*0.39;
		float flicker = 0.76+0.24*sin(clock*1.3+height*8.0);
		float side = abs(UV.x-0.5-sway);
		float silhouette = 1.0-smoothstep(taper*flicker,taper*flicker+0.045,side);
		float top = smoothstep(0.0,0.08,UV.y);
		float root = 1.0-smoothstep(0.92,1.0,UV.y);
		float core = (1.0-smoothstep(taper*0.12,taper*0.55,side))*pow(UV.y,0.7);
		alpha = silhouette*top*root*(0.45+core*0.25);
		color = mix(red,orange,0.35+UV.y*0.45);
		color = mix(color,gold,core*0.9);
		if (profile == 4) { alpha *= 1.0-smoothstep(0.12,0.92,progress); }
	} else if (layer == 2) {
		float cycle = fract(effect_age * (0.75 + ember_seed.y * 0.45) + ember_seed.x + phase * 0.03);
		float center_x = 0.5 + sin(cycle*5.0 + ember_seed.y*12.0)*0.18;
		vec2 delta = UV - vec2(center_x, 1.0 - cycle * 0.92);
		float spark = 1.0-smoothstep(0.018, 0.065, length(delta*vec2(0.45, 1.0)));
		float diamond = 1.0-smoothstep(0.02, 0.055, abs(delta.x)*0.5 + abs(delta.y));
		alpha = (profile == 4 ? diamond : spark) * sin(cycle*3.14159) * 0.75;
		if (profile == 4) { alpha *= 1.0-smoothstep(0.15, 0.95, progress); }
		color = mix(orange, gold, ember_seed.y);
	} else if (layer == 1) {
		// Screen-up rising helix, tapering at the top; its ground shadow stays separate.
		vec2 column_uv = (plane_position-column_bounds.xy)/max(column_bounds.zw,vec2(1.0));
		float height = 1.0-column_uv.y;
		float taper = mix(0.17, 0.77, pow(1.0-height, 0.6));
		float wave = sin(height*20.0-effect_age*5.8+phase)*taper*0.45;
		float body = 1.0-smoothstep(taper*0.48, taper*0.72, abs((column_uv.x-0.5)*2.0-wave));
		float bands = pow(0.5+0.5*sin(height*27.0-effect_age*6.0+(column_uv.x-0.5)*8.0), 3.0);
		float smoke_noise = noise(vec2(column_uv.x*9.0, height*9.0-effect_age*1.7)+phase);
		float tips = smoothstep(0.015, 0.11, column_uv.y) * smoothstep(0.0, 0.1, height);
		alpha = body*tips*(0.16+bands*0.31+smoke_noise*0.11);
		color = mix(red, gold, bands*0.76+smoke_noise*0.15);
	} else {
		vec2 q = vec2(dot(plane_position, heading), dot(plane_position, vec2(-heading.y, heading.x)));
		vec2 p = q/max(effect_radius, 1.0);
		float r = length(p);
		float angle = atan(p.y, p.x);
		float measure = r;
		if (shape_kind == 1) {
			p = vec2(q.x/max(footprint_length,1.0)*2.0-1.0, q.y/max(footprint_width*0.5,1.0));
			measure = max(abs(p.x), abs(p.y));
		} else if (shape_kind == 2) {
			vec2 a = abs(q);
			float arm_x = max(a.x/max(footprint_length*0.5,1.0), a.y/max(footprint_width*0.5,1.0));
			float arm_y = max(a.y/max(footprint_length*0.5,1.0), a.x/max(footprint_width*0.5,1.0));
			measure = min(arm_x, arm_y);
		}
		float edge = 1.0-smoothstep(0.89,1.0,measure);
		if (shape_kind == 3) { edge *= 1.0-smoothstep(cone_angle*0.46,cone_angle*0.5,abs(angle)); }
		float turbulence = noise(p*6.0+vec2(phase, effect_age*0.45));
		float flicker = noise(p*15.0+vec2(-effect_age*0.4, phase));
		float cracks = pow(1.0-abs(sin(p.x*11.0+p.y*7.0+turbulence*4.0)), 13.0);
		float char = pow(1.0-abs(sin(p.y*13.0-p.x*5.0+flicker*3.0)), 18.0);
		float rim = 1.0-smoothstep(0.014,0.062,abs(measure-0.9));
		float tongues = pow(0.5+0.5*sin(angle*16.0 + turbulence*4.0-effect_age*3.7),3.0);
		float tongue_r = 0.74+0.15*tongues;
		float fire = (1.0-smoothstep(0.02,0.11,abs(measure-tongue_r))) * tongues;
		float hot_patch = smoothstep(0.38,0.76,turbulence) * (0.45+flicker*0.55);
		float thermal = cracks*0.55 + fire*0.55 + hot_patch*0.45;
		color = mix(vec3(0.12,0.043,0.018), red, hot_patch*0.85+cracks*0.3);
		color = mix(color,orange,clamp(thermal,0.0,0.8));
		color = mix(color,gold,cracks*0.35+fire*0.45);
		color = mix(color,vec3(0.055,0.027,0.016),char*0.55);
		alpha = edge*(0.10+hot_patch*0.14+cracks*0.14+fire*0.26+char*0.1)+rim*0.10;
		if (profile == 0) { alpha *= 0.9; }
		if (profile == 1) {
			float crater = 1.0-smoothstep(0.025,0.11,abs(r-0.68-turbulence*0.075));
			alpha += crater*edge*0.23;
			color = mix(color, gold, crater*0.7);
		}
		if (profile == 2) {
			float bend = (noise(vec2(p.x*5.0,phase))*2.0-1.0)*0.2;
			float cross_ribbon = abs(p.y-bend);
			float molten = 1.0-smoothstep(0.24,0.78,cross_ribbon);
			float crust = smoothstep(0.24,0.55,noise(vec2(p.x*12.0,p.y*4.0)+phase));
			float flow = noise(vec2(p.x*9.0-effect_age*0.3,p.y*3.0)+phase);
			float pocket = smoothstep(0.48,0.75,flow)*molten;
			float fissure = cracks*molten*(0.5+crust*0.5);
			float hot = molten*(0.6+flow*0.4)*(1.0-crust*0.42);
			alpha = edge*(0.24+molten*0.29+pocket*0.12);
			color = mix(vec3(0.045,0.024,0.016),red,hot);
			color = mix(color,orange,molten*(0.45+pocket*0.4));
			color = mix(color,gold,pocket*0.72+fissure*0.45);
		}
		if (profile == 3) {
			float spiral = pow(0.5+0.5*sin(angle*3.0+r*17.0-effect_age*5.0),5.0);
			alpha = edge*(0.05+spiral*0.14)+rim*0.13;
			color = mix(red,gold,spiral*0.8);
		}
		if (profile == 4) {
			float front_r = mix(0.08,0.95,pow(clamp(progress/0.7,0.0,1.0),0.5));
			float front = 1.0-smoothstep(0.014,0.075,abs(r-front_r));
			float blast = (1.0-smoothstep(0.0,front_r,r))*turbulence*(1.0-progress);
			alpha = edge*(front*0.55+blast*0.2+cracks*(1.0-progress)*0.15);
			color = mix(orange,gold,front*0.7+blast*0.3);
		}
		alpha *= edge;
	}
	COLOR = vec4(color,clamp(alpha,0.0,0.68))*tint;
}
