shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.0;
uniform float phase=0.0;
varying vec2 p;
void vertex(){p=VERTEX;}
void fragment(){
	float r=length(p), a=atan(p.y,p.x);
	float life=1.0-progress;
	float core=exp(-r*r*80.0)*life;
	float ring=exp(-abs(r-(0.15+progress*0.75))*70.0)*life;
	float spoke=pow(max(0.0,cos(a*7.0+phase+sin(r*35.0)*0.7)),34.0);
	float arc=spoke*(1.0-smoothstep(0.2+progress*0.4,0.8,r))*smoothstep(0.05,0.14,r)*life;
	float glow=exp(-r*r*8.0)*life*0.25;
	vec3 col=mix(vec3(0.24,0.45,1.0),vec3(0.88,1.0,1.0),max(core,max(ring,arc)));
	COLOR=vec4(col,min(1.0,core+ring*0.8+arc+glow))*COLOR;
}
