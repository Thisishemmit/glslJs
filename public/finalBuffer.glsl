#version 330 core

uniform vec2 resolution;
uniform float time;

#define iResolution resolution
#define iTime time
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
     // thank for jolle's comment,the extended glow cause great waste!
     //but it doesn't look so natural on the edge
     vec2 d = (fragCoord-iResolution.xy*0.5)/iResolution.y*0.5;
     if (dot(d, d) > 0.55)
     {
     fragColor = vec4(0.);
     return;
     }

     //Clear base color.
    fragColor-=fragColor;

    vec2 r = iResolution.xy, p,
         t = iTime-vec2(0,11), I = 4.*d;


    //Iterate though 400 points and add them to the output color.
    for(float i=-1.; i<1.; i+=6e-3)
        {
        //Xor's neater code!
        p = sin(i*4e4+t.yx+11.)*sqrt(1.-i*i),
        fragColor += (cos(i+vec4(4,3,2.*sin(t)))+1.)*(1.-p.y) /
        dot(p=I+vec2(i,p/3.)/(p.y+2.),p)/3e4,
        // dot(p=I+vec2(p.x,i)/(p.y+2.),p)/3e4,

        p = sin(i*4e4-t)*sqrt(1.-i*i),
        fragColor += (cos(i+vec4(1,4,6,0))+1.)*(1.-p.y) /
        dot(p=cos(.5*t)*I+vec2(p.x,i)/(p.y+2.),p)/3e5,

        p = sin(i*4e4-t+80.)*sqrt(1.-i*i),
        fragColor += (cos(i+vec4(2,8,6,0))+1.)*(1.-p.y) /
        dot(p=I+vec2(p.x,i)/(p.y+2.),p)/3e5,

        p = sin(i*4e4-t+4e2)*sqrt(1.-i*i),
        fragColor += (cos(i+vec4(2,4,12,0))+1.)*(1.-p.y) /
        dot(p=sin(.25*t)*I+vec2(p.x,i)/(p.y+2.),p)/3e5;
        }
}
out vec4 fragColor;
void main(){
        vec4 fragment_color;
        mainImage(fragment_color, gl_FragCoord.xy);
        fragColor = fragment_color;
    }
