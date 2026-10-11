shader_type canvas_item;
render_mode unshaded;
uniform bool frozen = false;
uniform float stacks = 1.0;
uniform float effect_age = 0.0;
varying vec2 plane_position;
void vertex() { plane_position=VERTEX; }
void fragment() {
	vec2 p=vec2(plane_position.x/26.0,(plane_position.y+24.0)/34.0);
	float r=length(p);
	float hex=max(abs(p.x)*0.866+abs(p.y)*0.5,abs(p.y));
	float body=1.0-smoothstep(0.91,1.0,hex);
	float frame=1.0-smoothstep(0.012,0.045,abs(hex-0.92));
	float facet=abs(sin(p.x*5.0+p.y*3.0))*0.04;
	float cracks=pow(1.0-abs(sin(p.x*13.0+p.y*9.0+sin(p.y*8.0))),28.0);
	float glint=pow(max(0.0,sin(p.y*7.0-effect_age*1.6)),20.0);
	float foot=exp(-abs(p.y-0.88)*32.0)*(1.0-smoothstep(0.55,0.9,abs(p.x)));
	float alpha=foot*0.4+body*0.012*min(stacks,6.0)+frame*0.025*min(stacks,6.0);
	if(frozen) { alpha=body*(0.08+facet+cracks*0.11+glint*0.07)+frame*0.64; }
	COLOR=vec4(mix(vec3(0.26,0.63,0.87),vec3(0.86,0.99,1.0),clamp(frame+glint,0.0,1.0)),alpha)*COLOR;
}
