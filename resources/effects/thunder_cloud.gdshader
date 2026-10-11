shader_type canvas_item;
render_mode unshaded;

uniform float effect_age = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform vec4 cloud_bounds = vec4(-94.0,-176.0,188.0,162.0);
varying vec2 local_position;

void vertex() { local_position = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 uv = (local_position-cloud_bounds.xy)/max(cloud_bounds.zw,vec2(1.0));
	vec2 p = (uv-vec2(0.5,0.48))*vec2(2.1,2.8);
	float clock = effect_age*0.24;
	float n = noise(p*4.0+vec2(clock,phase));
	float detail = noise(p*10.0-vec2(clock*0.7,phase));
	float lobes = 0.18*sin(p.x*10.0+phase)+0.13*sin(p.x*17.0-phase);
	float mass = length(p*vec2(0.87,1.0));
	float body = 1.0-smoothstep(0.58+n*0.25+lobes,0.87+n*0.16+lobes,mass);
	float roundness = smoothstep(0.15,0.73,n)*body;
	float lit_rim = pow(detail,3.0)*body*smoothstep(0.6,0.95,mass);
	float frame = floor(effect_age*9.0);
	float pulse = pow(noise(vec2(frame,phase+4.0)),8.0);
	float veins = pow(1.0-abs(sin(p.x*20.0+p.y*13.0+n*7.0)),18.0);
	float internal = veins*body*pulse;
	vec3 color = mix(vec3(0.025,0.030,0.077),vec3(0.13,0.15,0.29),roundness);
	color += vec3(0.24,0.28,0.50)*lit_rim;
	color = mix(color,vec3(0.63,0.83,1.0),clamp(internal*4.0,0.0,1.0));
	float alpha = body*(0.66+roundness*0.23)+internal*0.3;
	// Cloud is decoration; there is no falsely implied bolt before a real strike.
	COLOR = vec4(color,clamp(alpha,0.0,0.93))*tint;
}
