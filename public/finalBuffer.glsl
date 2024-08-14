#version 300 es
precision mediump float;
uniform vec2 resolution;
uniform float time;
out vec4 fragColor;

#define iResolution resolution
#define iTime time
const vec2 s = vec2(1, 1.7320508);
float PI = 3.141592;
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c,-s,s,c); }
float scale = 5.;

// from https://www.shadertoy.com/view/wtdSzX
vec4 getHex(vec2 p)
{
    vec4 hC = floor(vec4(p, p - vec2(.5, 1))/s.xyxy) + .5;
    vec4 h = vec4(p - hC.xy*s, p - (hC.zw + .5)*s);
    return dot(h.xy, h.xy) < dot(h.zw, h.zw)
        ? vec4(h.xy, hC.xy)
        : vec4(h.zw, hC.zw + .5);
}

// function to improve colors, found in tdhooper shader : https://www.shadertoy.com/view/fdSGRy
vec3 aces(vec3 x) {
  const float a = 2.51;
  const float b = 0.03;
  const float c = 2.43;
  const float d = 0.59;
  const float e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float mixer;

float getColorComponent(in vec2 fragCoord, float time)
{
	vec2 u = (fragCoord - iResolution.xy*.5)/iResolution.y;

    vec4 h = getHex(u*scale + 0.*s.yx*time/2.);
    float dist = length(h.xy);
    vec2 coords = h.zw;

    float offset = 0.09*length(scale*u*vec2(1.,2.));
    offset = 0.09*length(4.*u*vec2(1.,1.7));

    float rotAmount = 5.5*sin(PI*2.*(0.3*time - offset))*max(0.,1. - 1.985*dist);
    vec2 hDistortion = h.xy*rot(rotAmount);

    float pattern = 6.*atan(hDistortion.y,hDistortion.x);

    float ret = smoothstep(0.7, .8, 0.5 + 0.5*sin(pattern + PI/2.));
    mixer = smoothstep(0.8, .9, 0.5 + 0.5*sin(pattern + PI/2.));

    return ret;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float time = 0.8*iTime;
    vec2 u = (fragCoord - iResolution.xy*.5)/iResolution.y;

    float colorOffset = 0.1;
    float r = getColorComponent(fragCoord,time - colorOffset);
    float g = getColorComponent(fragCoord,time + 0.);
    float b = getColorComponent(fragCoord,time + colorOffset);
    vec3 col0 = vec3(r,g,b);

    col0.zy  = abs(0.25 + 0.75*col0.xy*rot(0.3*time - 0.5*length(scale*u)));
    col0.yz  = abs(0.25 + 0.5*col0.zy*rot(0.23*time - 0.4*length(scale*u)));

    vec3 col = aces(col0.xzy)*0.25 + col0;
    col = mix(col,vec3(1.),mixer);
    col = mix(col,vec3(1.),0.6*length(u));
    col = clamp(1.17*aces(col),0.,1.);

    fragColor = vec4(col, 1);
}

void main() {
    vec4 fragment_color;
    mainImage(fragment_color, gl_FragCoord.xy);
    fragColor = fragment_color;
}
