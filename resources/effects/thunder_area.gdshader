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
uniform vec4 core_bounds = vec4(-60.0, -140.0, 120.0, 150.0);
varying vec2 local_position;
varying vec2 arc_seed;

void vertex() {
	local_position = VERTEX;
	arc_seed = COLOR.rg;
	// Preserve the incoming modulation alpha; vertex RGB is batch metadata.
	if (layer == 2) { COLOR.rgb = vec3(1.0); }
}

float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }
float noise(float p) { float i = floor(p); float f = fract(p); return mix(hash(i), hash(i + 1.0), f*f*(3.0-2.0*f)); }
float glow(float d, float width) { return exp(-abs(d) / max(width, 0.0001)); }
float band(float d, float width) { return 1.0 - smoothstep(width, width * 2.0, abs(d)); }
float segment(vec2 p, vec2 a, vec2 b) { vec2 d = b-a; return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),0.001),0.0,1.0)); }
float jag(float y, float seed) {
	return (noise(y*11.0+seed)*2.0-1.0)*0.095 + (noise(y*29.0+seed*3.0)*2.0-1.0)*0.042;
}

void fragment() {
	vec4 tint = COLOR;
	vec3 violet = vec3(0.30, 0.12, 0.74);
	vec3 blue = vec3(0.12, 0.46, 1.0);
	vec3 cyan = vec3(0.29, 0.88, 1.0);
	vec3 white = vec3(0.92, 0.99, 1.0);
	vec3 color = blue;
	float alpha = 0.0;
	float frame = floor(effect_age * 17.0);
	float clock = effect_age * 3.8 + phase;
	if (layer == 2) {
		float seed = arc_seed.y*37.0+phase;
		float wave = jag(UV.x, seed+floor(effect_age*15.0))*1.65;
		float distance = abs(UV.y - 0.5 - wave);
		float core = band(distance, 0.017);
		float halo = glow(distance, 0.17);
		float tip = smoothstep(0.0,0.12,UV.x)*(1.0-smoothstep(0.87,1.0,UV.x));
		float cycle = fract(effect_age * 1.4 + arc_seed.x + phase * 0.031);
		float pulse = pow(0.5+0.5*sin(clock*3.1+seed),5.0);
		float head = cycle;
		if (profile == 6) { head = 1.0-cycle; }
		float streak = glow(UV.x-head,0.13);
		float moving_core = band(UV.x-head,0.024)*band(distance,0.042);
		alpha = tip*(core*(0.30+pulse*0.55)+halo*0.22);
		color = mix(blue,white,core);
		if (profile == 6) {
			alpha = tip*(core*streak*0.9+halo*streak*0.37+moving_core*0.5);
			color = mix(violet,cyan,streak);
			color = mix(color,white,moving_core);
		} else if (profile == 4 || profile == 5 || profile == 3) {
			alpha *= (1.0-progress)*smoothstep(0.02,0.13,progress)*1.6;
		} else if (profile == 2) {
			alpha *= 0.2;
		}
	} else if (layer == 1) {
		vec2 uv = (local_position-core_bounds.xy)/max(core_bounds.zw,vec2(1.0));
		if (profile == 3) {
			// A continuous jagged trunk descends from cloud height to the ground.
			vec2 p = vec2((uv.x-0.5)*2.0, uv.y);
			float seed = phase+frame*3.0;
			float trunk = abs(p.x-jag(p.y,seed));
			float branches = 10.0;
			for (int i=0; i<5; i++) {
				float start = 0.2+float(i)*0.13;
				float side = mod(float(i),2.0)*2.0-1.0;
				vec2 a = vec2(jag(start,seed),start);
				vec2 b = vec2(side*(0.24+hash(float(i)+phase)*0.30),start+0.24);
				branches = min(branches,segment(p,a,b));
			}
			float core = band(trunk,0.016)+band(branches,0.009)*0.75;
			float halo = glow(trunk,0.12)+glow(branches,0.075)*0.6;
			float ends = smoothstep(0.0,0.015,uv.y)*(1.0-smoothstep(0.94,1.0,uv.y));
			float flash = (0.65+0.35*pow(0.5+0.5*sin(clock*11.0),2.0))*(1.0-smoothstep(0.48,1.0,progress));
			alpha = (core*0.96+halo*0.39)*ends*flash;
			color = mix(blue,white,clamp(core,0.0,1.0));
		} else {
			vec2 center = vec2(0.0,-effect_radius*0.63);
			if (profile == 5) { center = vec2(0.0); }
			vec2 p = (local_position-center)/max(effect_radius,1.0);
			p.y += sin(clock*1.2)*0.035;
			float r = length(p);
			float body = 1.0-smoothstep(0.24,0.29,r);
			float z = sqrt(max(0.0,1.0-pow(r/0.29,2.0)));
			float shading = clamp(dot(normalize(vec3(p/0.29,z)),normalize(vec3(-0.5,-0.7,1.0))),0.0,1.0);
			float filament = pow(1.0-abs(sin(atan(p.y,p.x)*5.0+r*39.0-clock*2.0)),15.0);
			float nucleus = exp(-r*r*95.0);
			float halo = exp(-r*r*9.0);
			float flare = glow(p.x,0.016)*exp(-abs(p.y)*9.0)+glow(p.y,0.013)*exp(-abs(p.x)*8.0);
			color = mix(violet,blue,shading*0.75+0.15);
			color = mix(color,cyan,filament*body*0.75);
			color = mix(color,white,clamp(nucleus+shading*shading*body*0.8+flare*0.55,0.0,1.0));
			alpha = body*0.87+halo*0.24+flare*0.35;
			if (profile == 5) {
				float blast = 1.0-smoothstep(0.12,0.78,progress);
				alpha *= blast;
				color = mix(color,white,blast*0.7);
			}
		}
	} else {
		vec2 q = vec2(dot(local_position,heading),dot(local_position,vec2(-heading.y,heading.x)));
		vec2 p = q/max(effect_radius,1.0);
		float r = length(p);
		float angle = atan(p.y,p.x);
		float measure = r;
		if (shape_kind == 1) {
			p = vec2(q.x/max(footprint_length,1.0)*2.0-1.0,q.y/max(footprint_width*0.5,1.0));
			measure = max(abs(p.x),abs(p.y));
		} else if (shape_kind == 2) {
			vec2 a = abs(q);
			measure = min(max(a.x/max(footprint_length*0.5,1.0),a.y/max(footprint_width*0.5,1.0)),max(a.y/max(footprint_length*0.5,1.0),a.x/max(footprint_width*0.5,1.0)));
		}
		float edge = 1.0-smoothstep(0.95,1.0,measure);
		if (shape_kind == 3) { edge *= 1.0-smoothstep(cone_angle*0.47,cone_angle*0.5,abs(angle)); }
		float threads = pow(1.0-abs(sin(p.x*17.0+p.y*9.0+noise(p.y*5.0+phase)*5.0)),19.0);
		float flicker = 0.57+0.43*noise(frame+phase*4.0);
		float rim = band(measure-0.9,0.013);
		float halo = glow(measure-0.87,0.13);
		alpha = edge*(threads*0.28*flicker+halo*0.10+rim*0.28);
		color = mix(violet,cyan,clamp(threads+rim*0.9,0.0,1.0));
		if (profile == 0) {
			float lanes = abs(p.y-jag(p.x,phase+frame)*2.0);
			float core = band(lanes,0.025);
			alpha = edge*(glow(lanes,0.30)*0.23+core*0.73+threads*0.17);
			color = mix(blue,white,core*0.94);
		} else if (profile == 1) {
			float shadow = exp(-dot(p*vec2(1.0,1.8),p*vec2(1.0,1.8))*5.0);
			alpha = edge*(shadow*0.27+rim*0.16+threads*0.12);
			color = mix(vec3(0.025,0.035,0.11),blue,rim+threads*0.6);
		} else if (profile == 2) {
			float outer = band(r-0.94,0.012);
			float inner = band(r-0.73,0.009);
			float runes = band(r-0.84,0.048)*pow(0.5+0.5*sin(angle*24.0),18.0);
			float spoke = band(sin(angle*6.0),0.012)*smoothstep(0.57,0.64,r)*(1.0-smoothstep(0.70,0.73,r));
			alpha = edge*(outer*0.6+inner*0.35+runes*0.58+spoke*0.55+glow(r-0.84,0.13)*0.08);
			color = mix(violet,cyan,clamp(outer+inner+runes,0.0,1.0));
		} else if (profile == 3 || profile == 4 || profile == 5) {
			float front_r = mix(0.04,0.95,pow(clamp(progress/0.74,0.0,1.0),0.42));
			float front = band(r-front_r,profile == 4 ? 0.015 : 0.028);
			float wake = glow(r-front_r,0.075)*(1.0-progress);
			float shock = exp(-r*r*17.0)*(1.0-smoothstep(0.10,0.58,progress));
			float rays = pow(0.5+0.5*sin(angle*15.0+noise(angle*4.0+phase)*4.0),17.0)*smoothstep(0.16,0.24,r);
			float inside = 1.0-smoothstep(front_r-0.05,front_r,r);
			alpha = edge*(front*0.88+wake*0.35+shock*0.75+threads*inside*(1.0-progress)*0.27);
			if (profile == 5) { alpha += edge*rays*inside*(1.0-progress)*0.52; }
			color = mix(blue,white,clamp(front*0.75+shock+threads*0.3,0.0,1.0));
		} else if (profile == 6) {
			// Bands and arrowheads travel toward r=0 as host age increases.
			float spiral = band(sin(angle*5.0+r*14.0+clock*2.0),0.12);
			float cycle = fract(r*2.3+effect_age*1.6+phase*0.03);
			float inward = exp(-cycle*12.0);
			float sink = exp(-r*r*35.0);
			float teeth = band(sin(angle*12.0+abs(r-0.60)*18.0),0.15)*band(r-0.6,0.11);
			alpha = edge*(spiral*(0.20+inward*0.6)+rim*0.23+teeth*0.45+sink*0.62);
			color = mix(violet,cyan,clamp(spiral*inward+teeth*0.8,0.0,1.0));
			color = mix(color,white,sink*0.85);
		}
		alpha *= edge;
	}
	COLOR = vec4(color,clamp(alpha,0.0,0.98))*tint;
}
