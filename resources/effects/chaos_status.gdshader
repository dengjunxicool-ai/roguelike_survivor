shader_type canvas_item;
render_mode unshaded;
uniform float effect_age=0.0;
uniform float stacks=1.0;
uniform int profile=0;
uniform int branch=0;
uniform float charge_fraction=0.0;
uniform float countdown=1.0;
uniform bool ready=false;
varying vec2 point;
void vertex(){point=VERTEX;}
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return exp(-length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),0.00001),0.0,1.0))*130.0);}
void fragment(){
 vec2 p=vec2(point.x/56.0,(point.y+28.0)/58.0);
 float age=effect_age, purple=0.0, white=0.0;
 if(profile==0){
  for(int i=0;i<4;i++){
   float f=float(i);vec2 q=p-vec2((f-1.5)*0.22,-0.70);
   float diamond=abs(q.x)+abs(q.y*0.85);
   float visible_stack=step(f+0.5,stacks);
   purple=max(purple,exp(-abs(diamond-0.09)*100.0)*visible_stack);
   white=max(white,segment(q,vec2(-0.045,-0.02),vec2(0.035,0.045))*visible_stack*0.8);
  }
  vec2 q=vec2(p.x,(p.y-0.59)*3.5);float r=length(q),a=atan(q.y,q.x);
  purple=max(purple,exp(-abs(r-0.64)*85.0)*pow(abs(cos(a*4.0-age*0.28)),9.0)*0.5);
 }else if(profile==1){
  float f=float(branch),angle=-2.35+f*1.57;
  vec2 c=vec2(cos(angle)*0.63,0.57+sin(angle)*0.20);
  vec2 q=vec2(p.x-c.x,(p.y-c.y)*2.4);
  float a=atan(q.y,q.x),r=length(q);
  purple=exp(-abs(r-0.15)*100.0)*(0.45+0.5*countdown);
  float glyph=branch==0?abs(q.x)+abs(q.y):branch==1?max(abs(q.x),abs(q.y)):branch==2?length(q):abs(q.x*0.6)+abs(q.y*1.5);
  white=exp(-abs(glyph-0.065)*150.0)*(0.65+0.18*cos(age*3.0));
  purple=max(purple,exp(-abs(r-0.21)*110.0)*step(fract((a+3.14159)/6.28318),countdown)*0.45);
 }else{
  float radius=profile==2?0.67:profile==3?0.80:0.92;
  vec2 q=vec2(p.x,(p.y-0.59)*3.5);float r=length(q),a=atan(q.y,q.x);
  float divisions=profile==2?5.0:profile==3?4.0:25.0;
  float fill=step(fract((a+3.14159)/6.28318),charge_fraction);
  float gap=step(0.10,fract((a+3.14159)/6.28318*divisions));
  purple=exp(-abs(r-radius)*85.0)*gap*(0.16+fill*0.62);
  white=exp(-abs(r-radius)*115.0)*gap*fill*0.70;
  if(ready){white=exp(-abs(r-radius)*150.0)*(0.75+0.2*sin(age*4.0));}
 }
 COLOR=vec4(mix(vec3(0.71,0.17,1.0),vec3(0.65,1.0,1.0),white/(purple+white+0.001)),clamp(max(white,purple),0.0,0.92));
}
