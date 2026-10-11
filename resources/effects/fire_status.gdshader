shader_type canvas_item;
render_mode unshaded;
uniform float effect_age = 0.0;
uniform float stacks = 1.0;
uniform bool overheated = false;
varying vec2 local_point;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { local_point=VERTEX; }
void fragment() {
	vec2 p=vec2(local_point.x/35.0,(12.0-local_point.y)/84.0);
	float age=effect_age;
	float heat=0.0;
	float n=noise(vec2(p.x*6.0,p.y*6.0-age*2.7));
	for(int i=0;i<5;i++) {
		float fi=float(i);
		float height=0.46+0.12*sin(fi*2.4+age*2.1)+stacks*0.052;
		float center=(fi-2.0)*0.29+sin(p.y*7.0-age*3.0+fi)*p.y*0.14;
		float width=max(0.006,(1.0-p.y/height)*(0.12+stacks*0.015));
		float flame=(1.0-smoothstep(width*0.4,width+0.06,abs(p.x-center)))*(1.0-smoothstep(height-0.1,height,p.y+n*0.065));
		heat=max(heat,flame);
	}
	float edge=1.0-smoothstep(0.84,1.0,abs(p.x));
	float foot=smoothstep(-0.015,0.085,p.y);
	float shell=exp(-pow(abs(p.x)-0.59,2.0)*45.0)*exp(-pow(p.y-0.23,2.0)*15.0);
	float aura=overheated?shell*0.34:0.0;
	float alpha=(heat*(0.38+stacks*0.06)+aura)*edge*foot;
	vec3 col=mix(vec3(0.80,0.08,0.015),vec3(1.0,0.55,0.065),heat);
	col=mix(col,vec3(1.0,0.93,0.56),pow(heat,5.0)*(1.0-p.y)*0.75);
	for(int i=0;i<7;i++) {
		float fi=float(i),t=fract(age*(0.35+fi*0.025)+fi*0.618);
		vec2 ember=vec2(sin(fi*3.7+t*2.0)*0.8,0.16+t*0.83);
		float spark=(1.0-smoothstep(0.007,0.025,length((p-ember)*vec2(1.0,1.7))))*sin(t*3.14159);
		col=mix(col,vec3(1.0,0.85,0.3),spark); alpha=max(alpha,spark*0.8);
	}
	COLOR=vec4(col,alpha)*COLOR;
}
