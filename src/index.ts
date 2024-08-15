import GFX from "./GFX";
const gfx = new GFX('glCanvas');
gfx.addCommon(`
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#pragma optimize(off)

// General
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#define ZERO min(0,iFrame)
#define CHARM min(0,iFrame) /* about 6 sces faster compilation... */
#define PI 3.14159265
#define TAU (2.0*PI)
#define saturate(x) clamp(x, 0.0, 1.0)

// Data Paker/Unpacker
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
uint packSnorm3x10(vec3 x) {
    x = clamp(x,-1., 1.) * 511.;
    uvec3 sig = uvec3(mix(vec3(0), vec3(1), greaterThanEqual(sign(x),vec3(0))));
    uvec3 mag = uvec3(abs(x));
    uvec3 r = sig.xyz << 9 | mag.xyz;
    return r.x << 22 | r.y << 12 | r.z << 2;
}

vec3 unpackSnorm3x10(uint x) {
    uvec3 r = (uvec3(x) >> uvec3(22, 12, 2)) & uvec3(0x3FF);
    uvec3 sig = r >> 9;
    uvec3 mag = r & uvec3(0x1FF);
    vec3 fsig = mix(vec3(-1), vec3(1), greaterThanEqual(sig, uvec3(1)));
    vec3 fmag = vec3(mag) / 511.;
    return fsig * fmag;
}

uint packSnorm4x8(vec4 x) {
    x = clamp(x,-1.0, 1.0) * 127.0;
    uvec4 sig = uvec4(mix(vec4(0), vec4(1), greaterThanEqual(sign(x),vec4(0))));
    uvec4 mag = uvec4(abs(x));
    uvec4 r = sig << 7 | mag;
    return r.x << 24 | r.y << 16 | r.z << 8 | r.w;
}

vec4 unpackSnorm4x8(uint x) {
    uvec4 r = (uvec4(x) >> uvec4(24, 16, 8, 0)) & uvec4(0xFF);
    uvec4 sig = r >> 7;
    uvec4 mag = r & uvec4(0x7F);
    vec4 fsig = mix(vec4(-1), vec4(1), greaterThanEqual(sig,uvec4(1)));
    vec4 fmag = vec4(mag) / 127.0;
    return fsig * fmag;
}
#define pack(x) uintBitsToFloat(packSnorm3x10(x))
#define unpack(x) unpackSnorm3x10(floatBitsToUint(x))
#define pack4(x) uintBitsToFloat(packSnorm4x8(x))
#define unpack4(x) unpackSnorm4x8(floatBitsToUint(x))

// Random & Noise
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// "Hash without Sine" by Dave_Hoskins:
// https://www.shadertoy.com/view/4djSRW

//  1 out, 1 in...
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float hash11(float p)
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

//  1 out, 2 in...
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float hash12(vec2 p)
{
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}


float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

float fbm(vec2 n, int rep){
    float sum = 0.0;
    float amp= 1.0;
    for (int i = 0; i <rep; i++){
        sum += noise(n) * amp;
        n += n*4.0;
        amp *= 0.25;
    }
    return sum;
}
              `)
gfx.addFooter(`
              out vec4 fragColor;

              void main() {
                  vec4 fragment_color;
                  mainImage(fragment_color, gl_FragCoord.xy);
                  fragColor = fragment_color;
              }
              `);
gfx.addBuffer('bufferA', "bufferA.glsl");
gfx.ready.then(() => {

    console.log("ShaderToy gfxironment is ready");
}).catch(error => {
    console.error("Failed to initialize ShaderToyEnvironment:", error);
});
