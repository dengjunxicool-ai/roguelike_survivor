shader_type canvas_item;
render_mode unshaded;
uniform float effect_age=0.0;
uniform float stacks=1.0;
uniform int profile=0;
uniform float charge_fraction=1.0;
uniform float countdown=1.0;
uniform bool ready=false;
varying vec2 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
	vec2 p=vec2(local_point.x/44.0,(local_point.y+22.0)/48.0);
	float age=effect_age, alpha=0.0, soul=0.0;
	vec2 floor_p=vec2(p.x,(p.y-0.64)*2.6);
	float r=length(floor_p),a=atan(floor_p.y,floor_p.x);
	float ring=exp(-abs(r-0.73)*90.0);
	float runes=pow(max(0.0,cos(a*12.0+age*0.25)),14.0);
	alpha=ring*(0.25+runes*0.45);
	if(profile==0){
		for(int i=0;i<3;i++){
			float f=float(i), x=(f-1.0)*0.33+sin(p.y*7.0-age*1.8+f*2.1)*0.07;
			float chain=exp(-abs(p.x-x)*100.0)*(0.35+0.65*pow(abs(sin(p.y*25.0+age)),3.0));
			alpha=max(alpha,chain*step(f,stacks-0.5)*(1.0-smoothstep(0.45,0.9,abs(p.y)))*0.74);
		}
		vec2 q=p-vec2(0,-0.60);
		float rr=length(q);
		float sigil=exp(-abs(rr-0.18)*125.0);
		float slash=exp(-abs(q.x)*150.0)*(1.0-smoothstep(0.12,0.23,abs(q.y)));
		soul=max(sigil,slash)*(0.65+0.16*sin(age*4.0));
	}else if(profile==1){
		float filled=step(fract((a+3.14159)/6.28318),countdown);
		alpha=max(alpha,exp(-abs(r-0.89)*110.0)*filled);
		vec2 q=p-vec2(0,-0.73);
		float diamond=abs(q.x)+abs(q.y*1.1);
		soul=exp(-abs(diamond-0.22)*130.0);
		alpha=max(alpha,exp(-abs(diamond-0.31)*85.0)*0.65);
	}else{
		float filled=step(fract((a+3.14159)/6.28318),charge_fraction);
		alpha*=filled;
		float orbit=pow(max(0.0,cos(a*6.0-age*1.6)),36.0)*exp(-abs(r-0.78)*50.0)*filled;
		soul=orbit*(ready?1.0:0.7);
		if(profile==3){
			vec2 q=p-vec2(0,-0.62);
			float coffin=max(abs(q.x)*0.8,abs(q.y)*0.48);
			alpha=max(alpha,exp(-abs(coffin-0.12)*180.0)*charge_fraction);
		}else if(ready){
			soul=max(soul,exp(-abs(r-0.57)*60.0)*(0.48+0.14*sin(age*5.0)));
		}
	}
	vec3 purple=mix(vec3(0.24,0.055,0.38),vec3(0.73,0.30,0.92),min(alpha*1.1,1.0));
	vec3 color=mix(purple,vec3(0.52,1.0,0.71),clamp(soul,0.0,1.0));
	COLOR=vec4(color,max(alpha,soul)*0.9)*COLOR;
}
