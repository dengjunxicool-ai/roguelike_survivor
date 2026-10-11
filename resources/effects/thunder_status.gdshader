shader_type canvas_item;
render_mode unshaded;
uniform float effect_age = 0.0;
uniform float stacks = 1.0;
uniform bool charged = false;
uniform bool core_charge = false;
uniform float charge_fraction = 1.0;
varying vec2 local_point;
float hash(float x){return fract(sin(x*123.45)*4567.89);}
void vertex(){local_point=VERTEX;}
void fragment(){
	vec2 p=vec2(local_point.x/40.0,(local_point.y+24.0)/44.0);
	float age=effect_age;
	float tick=floor(age*12.0);
	float electric=0.0, glow=0.0;
	for(int i=0;i<5;i++){
		float fi=float(i);
		float y=(p.y+1.0)*4.0;
		float cell=floor(y), t=fract(y);
		float offset=mix(hash(cell+fi*19.0+tick*0.17),hash(cell+1.0+fi*19.0+tick*0.17),t);
		float x=(fi-2.0)*0.29+(offset-0.5)*0.28;
		float dist=abs(p.x-x);
		float live=step(fi,stacks-0.5);
		float flicker=0.55+0.45*sin(age*17.0+fi*2.0)*sin(age*17.0+fi*2.0);
		electric=max(electric,(1.0-smoothstep(0.008,0.028,dist))*live*flicker);
		glow=max(glow,exp(-dist*20.0)*live*0.24);
	}
	float edge=(1.0-smoothstep(0.6,1.0,abs(p.y)))*(1.0-smoothstep(0.65,0.92,abs(p.x)));
	float alpha=(electric+glow)*edge*(0.5+stacks*0.08);
	if(charged||core_charge){
		vec2 q=vec2(p.x,p.y*1.25);
		float r=length(q), angle=atan(q.y,q.x);
		float ring=exp(-abs(r-0.74)*70.0);
		float phase=angle+age*2.2;
		float bead=pow(max(0.0,cos(phase*6.0)),24.0);
		float fill=core_charge?step(fract((angle+3.14159)/6.28318),charge_fraction):1.0;
		alpha=max(alpha*(charged?0.35:0.1),ring*(0.25+bead*0.75)*fill);
		glow=max(glow,exp(-abs(r-0.74)*12.0)*0.22*fill);
	}
	vec3 col=mix(vec3(0.15,0.28,1.0),vec3(0.6,0.92,1.0),min(1.0,electric+alpha));
	col=mix(col,vec3(0.96,1.0,1.0),electric*electric);
	COLOR=vec4(col,max(alpha,glow*edge))*COLOR;
}
