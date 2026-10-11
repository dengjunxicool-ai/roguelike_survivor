shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform int profile = 0;
varying vec2 point;
void vertex() { point=VERTEX; }
void fragment() {
	float t=clamp(progress,0.0,1.0),r=length(point),a=atan(point.y,point.x);
	float travel=sqrt(t),fade=pow(1.0-t,1.4);
	float lobes=sin(a*7.0+phase+t*8.0)*0.055+sin(a*11.0-phase)*0.028;
	float core=(1.0-smoothstep(0.1+travel*0.27,0.22+travel*0.43,r+lobes))*(1.0-smoothstep(0.05,0.64,t));
	float ring=exp(-pow((r-travel*0.88)/0.021,2.0))*fade*(profile==2?0.65:0.2);
	float flare=0.0;
	for(int i=0;i<16;i++) {
		float fi=float(i),theta=fi*6.2831853/16.0+phase;
		vec2 axis=vec2(cos(theta),sin(theta));
		vec2 off=point-axis*(0.13+travel*(0.49+0.2*sin(fi*4.7)));
		float width=0.012+(1.0-t)*0.024;
		float spark=exp(-pow(dot(off,vec2(-axis.y,axis.x))/width,2.0)-pow(dot(off,axis)/(0.035+(1.0-t)*0.11),2.0));
		flare=max(flare,spark*fade);
	}
	vec3 color=mix(vec3(0.97,0.12,0.012),vec3(1.0,0.77,0.16),core);
	color=mix(color,vec3(1.0,0.96,0.61),core*core*(1.0-t));
	color=mix(color,vec3(1.0,0.7,0.17),max(flare,ring));
	float alpha=max(core*fade*0.8,max(ring,flare));
	COLOR=vec4(color,alpha)*COLOR;
}
