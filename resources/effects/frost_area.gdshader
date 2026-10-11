shader_type canvas_item;
render_mode unshaded;
uniform int profile = 0;
uniform float effect_age = 0.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform bool transient = false;
uniform bool wide_front = false;
varying vec2 plane_position;
void vertex() { plane_position = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=plane_position;
	float r=length(p);
	float angle=atan(p.y,p.x);
	float edge=1.0-smoothstep(0.88,0.95,r);
	float swirl=noise(p*5.0+vec2(effect_age*0.12,phase))+0.5*noise(p*12.0-effect_age*0.09);
	float cracks=pow(1.0-abs(sin(angle*9.0+r*17.0+noise(p*8.0)*2.0)),22.0);
	float branches=pow(1.0-abs(sin(angle*18.0-r*28.0)),32.0);
	float rim=1.0-smoothstep(0.008,0.032,abs(r-0.91));
	float wake=clamp(progress/0.4,0.0,1.0);
	float front_radius=mix(0.07,0.92,pow(wake,0.55));
	float front=1.0-smoothstep(0.012,0.07,abs(r-front_radius));
	vec3 color=mix(vec3(0.18,0.45,0.66),vec3(0.69,0.91,1.0),clamp(swirl*0.65,0.0,1.0));
	float alpha=edge*(0.065+swirl*0.07+cracks*0.13+branches*0.05)+rim*0.3;
	if (profile==1) { alpha*=0.57; color=mix(color,vec3(0.85,0.96,1.0),0.2); }
	if (profile==2) { alpha=front*0.67+edge*cracks*(1.0-progress)*0.22; color=mix(color,vec3(0.93,1.0,1.0),front); }
	if (profile==3) { alpha=front*0.44+cracks*edge*(1.0-progress)*0.48; color=vec3(0.75,0.96,1.0); }
	if (profile==4) {
		color=mix(vec3(0.3,0.7,0.95),vec3(0.92,1.0,1.0),swirl*0.7);
		alpha=edge*(0.075+cracks*0.13)+rim*0.36;
		if (transient) { alpha=front*(wide_front?0.15:0.6)+edge*swirl*(wide_front?0.028:0.08); }
	}
	COLOR=vec4(color,clamp(alpha,0.0,0.8))*COLOR;
}
