#version 300 es
uniform vec2 resolution;
uniform float time;
uniform sampler2D bufferA;
uniform int frame;

#define iTime time
#define iResolution resolution
#define iFrame frame
#define iChannel0 bufferA
float originalSigmoidContrast(float color, float contrast, float mid)
{
    contrast = contrast < 1.0 ? 0.5 + contrast * 0.5 : contrast;
    float scale_l = 1.0 / mid;
    float scale_h = 1.0 / (1.0 - mid);
    float lower = mid * pow(scale_l * color, contrast);
    float upper = 1.0 - (1.0 - mid) * pow(scale_h - scale_h * color, contrast);
    return color < mid ? lower : upper;
}

// Read data from BufA
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vec3 readAlbedo(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    return unpack(data.y);
}

vec3 readNormal(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    return unpack4(data.x).xyz;
}

float readShadow(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    return unpack4(data.x).w;
}

float readDepth(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    return data.w;
}

float readDiffuse(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    vec3 spec_diffuse_ao = unpack(data.z)*.5+.5;
    return spec_diffuse_ao.y;
}

float readSpecular(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    vec3 spec_diffuse_ao = unpack(data.z)*.5+.5;
    return spec_diffuse_ao.x;
}

float readAO(vec2 uv)
{
    vec4 data = texelFetch(iChannel0, ivec2(uv), 0);
    vec3 spec_diffuse_ao = unpack(data.z);
    return spec_diffuse_ao.z;
}

vec3 readSharpenNormal(in vec2 fragCoord, float strength)
{
    vec3 res =
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1,-1)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0,-1)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1,-1)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 0)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 0)), 0).x).xyz*2.-1.) *   9. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 0)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 1)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 1)), 0).x).xyz*2.-1.) *  -1. +
    (unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 1)), 0).x).xyz*2.-1.) *  -1.
    ;
    return mix((unpack4(texelFetch(iChannel0, ivec2(fragCoord+vec2(0, 0)), 0).x).xyz), res , strength);
}

float readSharpenSpecular(in vec2 fragCoord, float strength)
{
    float res =
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1,-1)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0,-1)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1,-1)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 0)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 0)), 0).z)*.5+.5).x *   9. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 0)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 1)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 1)), 0).z)*.5+.5).x *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 1)), 0).z)*.5+.5).x *  -1.
    ;
    return mix((unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(0, 0)), 0).z)*.5+.5).x, res , strength);
}

float readSharpenDiffuse(in vec2 fragCoord, float strength)
{
    float res =
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1,-1)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0,-1)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1,-1)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 0)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 0)), 0).z)*.5+.5).y *   9. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 0)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 1)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 1)), 0).z)*.5+.5).y *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 1)), 0).z)*.5+.5).y *  -1.
    ;
    return mix((unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(0, 0)), 0).z)*.5+.5).y, res , strength);
}

float readSharpenAO(in vec2 fragCoord, float strength)
{
    float res =
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1,-1)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0,-1)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1,-1)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 0)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 0)), 0).z)*.5+.5).z *   9. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 0)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(-1, 1)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 0, 1)), 0).z)*.5+.5).z *  -1. +
    (unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2( 1, 1)), 0).z)*.5+.5).z *  -1.
    ;
    return mix((unpack(texelFetch(iChannel0, ivec2(fragCoord+vec2(0, 0)), 0).z)*.5+.5).z, res , strength);
}


// NPR effects
// Maybe, you can better ways for these effects in somewhere else...
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float dithering(float v, vec2 fragCoord)
{
    v=pow(v, 8.);
    vec2 p = fragCoord;
    p = mod(p.xx + vec2(p.y, -p.y), vec2(.1));
    float res=0.;
    vec2 coords = fragCoord;

    float angle = dot(readSharpenNormal(fragCoord, 1.), vec3(0,0,1));

    coords.xy*= mat2(cos(angle*PI+vec4(0,11,33,0)));
    coords.y *= .75+.25*hash12(p);
    float rand_ditherVal = fbm(coords*.75, 2);
    const float paletteDist = 1.15;
    res=v + (rand_ditherVal - .5) * paletteDist;
    res=smoothstep(0.1,1.,res);
    res=saturate(floor(res*6.)/5.);

    return res;
}

float calcEdge(vec3 nlm1, vec3 nlm2)
{
    vec2 difN = abs(nlm1.xy - nlm2.xy);
    return smoothstep(.41, .3, difN.x + difN.y);
}
float getOutline(vec2 fragCoord)
{
    vec2 coord = fragCoord;
    vec3 offset = vec3(1, -1, 0) * .5;
    float edge = 1.0;
    edge *= calcEdge(readNormal(coord+offset.xx), readNormal(coord+offset.yy));
    edge *= calcEdge(readNormal(coord+offset.xy), readNormal(coord+offset.yx));
    edge *= calcEdge(readNormal(coord+offset.zy), readNormal(coord+offset.zx));
    edge *= calcEdge(readNormal(coord+offset.yz), readNormal(coord+offset.xz));
    return edge;
}

float getShadowEdge( vec2 fragCoord )
{
    vec2 coord = fragCoord;
    float sha = readShadow(coord);
    sha -= .5;
    sha = abs(sha);
    sha = smoothstep(.1,.2,sha);
    return sha;
}

float getDottedShadow(vec2 fragCoord)
{
    vec2 uv = fragCoord;
    uv *= mat2(cos(.8+vec4(0, 11, 33, 0)));
    uv = mod(uv*.25, 1.);
    float res = 0.;
    float shadow = readShadow(fragCoord);
    shadow = max(.65,shadow*.85) + .35*readAO(fragCoord);
    shadow = 1. - shadow;
    res = smoothstep(shadow, shadow+1., pow(length(uv-.5), 4.));
    res = smoothstep(.0, .2, pow(res, .05));
    return res;
}

float hatching(vec2 fragCoord, float tickness, float angle, float dark, float light, bool centered)
{
    vec2 v = fragCoord.xy / iResolution.xy;
    vec3 n = readNormal(fragCoord);

    float f = smoothstep(.1, 1., saturate(-n.y)*saturate(-n.x));
    // tickness /= f+PI;

    v *= mat2(cos(n.z*PI*.25 + angle + vec4(0, 11, 33, 0)));
    v.y = mod(v.y*iResolution.y/tickness, 1.);
    v.y += fbm(fragCoord.yx*.05, 2)*.0005;

    float shading = readSharpenDiffuse(fragCoord, 2.);
    shading = mix(shading, (1.-shading)*.3+.7*readAO(fragCoord), 1.-readShadow(fragCoord));
    shading *= 1.5;
    shading = smoothstep(dark, light, pow(shading, 1.8));
    if(centered)
    {
        shading = (shading-.5)*2.;
        shading = saturate(shading);
        shading = abs(shading-.5)*2.;
    }
    else
        shading = saturate(shading-.5)*2.;

    shading = originalSigmoidContrast(shading*.95+.05*saturate(fbm(fragCoord*.025, 2)), noise(fragCoord*.02)*noise(fragCoord.yx*.03)*.5, .7);
    float face = smoothstep(.5, 1.8, saturate(-n.y)*saturate(-n.x));
    float line = smoothstep(-.3, shading+.5, 1.-abs(v.y-.5)*2.);
    line = saturate(pow(line+shading+face, 5.));

    return line;
}

float getHatching(vec2 fragCoord)
{
    if(readDepth(fragCoord)>.9)
    return 1.;

    float ln = 1.;
    const float mul = 1.;
        ln*= pow(hatching(fragCoord, 4.*mul, .6, .6, .8, true), 10.);
        ln*= pow(hatching(fragCoord, 3.5*mul, -.4, -1.4, 1.4, false), 50.5);
        ln*= pow(hatching(fragCoord, 3.5*mul, .4, -1.4, 1.4, false), 50.5);
    return ln;
}

float hatchingSpecular(vec2 fragCoord, float tickness, float angle, float dark, float light, bool centered)
{
    vec2 v = fragCoord.xy / iResolution.xy;
    vec3 n = readNormal(fragCoord);
    if(length(n)<.1)
        return -1.;
    float f = smoothstep(.1, 1., saturate(-n.y)*saturate(-n.x));
    // tickness /= f+PI;

    v *= mat2(cos(n.z*PI*.25 + angle + vec4(0, 11, 33, 0)));
    v.y = mod(v.y*iResolution.y/tickness, 1.);
    v.y += fbm(fragCoord.yx*.05, 2)*.0005;

    float shading = readSpecular(fragCoord);
    shading *= readShadow(fragCoord);
    //shading *= 1.5;
    shading = smoothstep(dark, light, pow(shading, 1.8));
    if(centered)
    {
        shading = (shading-.5)*2.;
        shading = saturate(shading);
        shading = abs(shading-.5)*2.;
    }
    else
        shading = saturate(shading-.5)*2.;

	shading = originalSigmoidContrast(shading*.98+.03*saturate(fbm(fragCoord*.025, 2)), noise(fragCoord*.02)*noise(fragCoord.yx*.03)*.5, .7);
    shading = 1.-saturate(shading*.55);
    float face = smoothstep(.5, 1.8, saturate(-n.y)*saturate(-n.x));
    float line = smoothstep(-.3, shading+.5, 1.-abs(v.y-.5)*2.);
    line = saturate(pow(line+shading+face, 5.));

    return line;
}

float getHatchingSpecular(vec2 fragCoord)
{
    float ln = 1.;
        ln*= pow(hatchingSpecular(fragCoord, 3.5, -.4, -1.4, 1.4, false), 50.5);
        ln*= pow(hatchingSpecular(fragCoord, 3.5, .4, -1.4, 1.4, false), 50.5);
    return 1.-ln;
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    vec3 col = vec3(.8, .77, .7);

    float shading = readDiffuse(fragCoord);
    shading *= readShadow(fragCoord);
    shading = shading*.7+.3*readAO(fragCoord);
    shading = smoothstep(.3, 1., shading);

    float contrast = 8.8;
    float midpoint = .5;
    shading = originalSigmoidContrast(shading, contrast, midpoint);
    shading = saturate(shading);
	if(readDepth(fragCoord)>.9)
        shading = 1.;

    col*=dithering(shading+smoothstep(.3, .9, readDepth(fragCoord)*.6)*.25, fragCoord);

    col+=.05*dithering((smoothstep(.95,1.,shading)), fragCoord);
    col+=.05*dithering((smoothstep(.97,1.,shading)), fragCoord);
    col+=.05*dithering((smoothstep(.99,1.,shading)), fragCoord);
    col*=.65+.25*shading;
    col+=fbm(fragCoord*.5, 3)*.05;
    col*= getHatching(fragCoord);

    col *= getOutline(fragCoord);
    col *= getShadowEdge(fragCoord);
    col *= getDottedShadow(fragCoord);
    col *= .4 + .6*(readShadow(fragCoord)*.8+.2*readAO(fragCoord));

    col *= dithering(pow(saturate(readSharpenAO(fragCoord, 2.)), 1.5), fragCoord);
    vec3 albedo = readAlbedo(fragCoord);
    col*= albedo;

    float spec = readSharpenSpecular(fragCoord, 1.5)*readShadow(fragCoord);
    if(spec>.1)
    {
    	col+=dithering(spec, fragCoord);
    	col+=getHatchingSpecular(fragCoord);
    }
    col*=.8+.2*pow(1.-smoothstep(.0, 2., readDepth(fragCoord)), 3.);

    col*= dithering(noise(fragCoord*.18+iTime*5.)+noise(fragCoord*.15-iTime*5.)+.8, fragCoord);
    col+= 1.-dithering((1.-noise(fragCoord*.3+iTime*5.)*noise(fragCoord*.1-iTime*5.))+.8, fragCoord);

    col *= vec3(.5+.5*smoothstep(.8, .5, readDepth(fragCoord)));

    col = pow(col, vec3(.4545));
    col = pow(col, vec3(.4545)); // intended one...

    fragColor = vec4(col, 1.);

#ifdef DEBUG_PASSES
    if(iFrame==2)
    fragColor.xyz = vec3(readDiffuse(fragCoord));
    if(iFrame==3)
    fragColor.xyz = vec3(readShadow(fragCoord));
    if(iFrame==4)
    fragColor.xyz = vec3(readSharpenSpecular(fragCoord, 1.5));
    if(iFrame==5)
    fragColor.xyz = vec3(readDepth(fragCoord));
    if(iFrame==6)
    fragColor.xyz = vec3(readAO(fragCoord));
    if(iFrame==7)
    fragColor.xyz = readAlbedo(fragCoord);
    if(iFrame==8)
    fragColor.xyz = readNormal(fragCoord)*.5+.5;
    if(iFrame==9)
    fragColor.xyz = vec3(getOutline(fragCoord));
    if(iFrame==10)
    fragColor.xyz = vec3(getShadowEdge(fragCoord));
    if(iFrame==11)
    fragColor.xyz = vec3(getDottedShadow(fragCoord));
    if(iFrame==12)
    fragColor.xyz = vec3(getHatching(fragCoord));
    if(iFrame==13)
    fragColor.xyz = vec3(getHatchingSpecular(fragCoord));
#endif

    fragColor.w = 1.;
}
