#version 300 es
//bufferA
uniform vec2 resolution;
uniform float time;
uniform int frame;
// Ray marching pass
#define iFrame frame
#define iTime time
#define iResolution resolution
#define iMouse vec4(0.0)

#define MIN_DIST 0.001
#define MAX_DIST 20.0
#define ITERATION 200
#define MAT_VOID vec3(-1.)
#define MAT_SHOE_LACE vec3(0.1265, 0.9774, 0.8157)
#define MAT_SKIN vec3(0.4743, 0.9774, 0.7076)
#define MAT_PANTS vec3(0.5000, 1.0000, 0.6375)
#define MAT_WALL vec3(0.7874, 0.6056, 0.6457)
#define MAT_SHOE vec3(0.8900, 0.5034, 0.4153)
#define MAT_TOPS vec3(0.4675, 0.7156, 0.8073)
#define MAT_FLOOR vec3(0.6986, 0.8128, 0.8900)
#define AMB_COL vec3(0.7874, 0.6056, 0.6457)

//#define SHOW_SHOE

vec3 ro = vec3(0), rd = vec3(0), col = vec3(0), camup, ldir = normalize(vec3(-.5, 1.,-.85));

// SDF functions by iq and HG_SDF
// https://iquilezles.org/articles/distfunctions
// https://mercury.sexy/hg_sdf/
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// Cheap Rotation by las:
// http://www.pouet.net/topic.php?which=7931&page=1
#define R(p, a) p=cos(a)*p+sin(a)*vec2(p.y,-p.x)
vec3 rot(vec3 p,vec3 r){
    R(p.xz, r.y);
    R(p.yx, r.z);
    R(p.zy, r.x);
    return p;
}

float vmax(vec3 v){
    return max(max(v.x, v.y), v.z);
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdSphere(in vec3 p,in float r)
{
    return length(p)-r;
}

float sdEllipsoid(in vec3 p, in vec3 r)
{
    return (length(p/r)-1.0)*min(min(r.x,r.y),r.z);
}

float sdCapsule(vec3 p, float r, float c)
{
    return mix(length(p.xz) - r, length(vec3(p.x, abs(p.y) - c, p.z)) - r, step(c, abs(p.y)));
}

float sdTorus( vec3 p, vec2 t )
{
    vec2 q = vec2(length(p.xz)-t.x,p.y);
    return length(q)-t.y;
}

float sdCappedTorus(vec3 p, vec2 r, float per)
{
    p.x = abs(p.x);
    vec2 sc = vec2(sin(per),cos(per));
    float k = (sc.y*p.x>sc.x*p.z) ? dot(p.xz,sc) : length(p.xz);
    return sqrt( dot(p,p) + r.x*r.x - 2.0*r.x*k ) - r.y;
}

float sdCappedCylinder( vec3 p, vec2 h )
{
    vec2 d = abs(vec2(length(p.xz),p.y)) - h;
    return ((min(max(d.x,d.y),0.0) + length(max(d,0.0))))-0.0;
}

float sdConeSection( in vec3 p, in float h, in float r1, in float r2 )
{
    vec2 q = vec2( length(p.xz), p.y );
    vec2 k1 = vec2(r2,h);
    vec2 k2 = vec2(r2-r1,2.0*h);
    vec2 ca = vec2(q.x-min(q.x,(q.y < 0.0)?r1:r2), abs(q.y)-h);
    vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot(k2,k2), 0.0, 1.0 );
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s*sqrt( min(dot(ca,ca),dot(cb,cb)) );
}

float sdBox(vec3 p,vec3 b)
{
    vec3 d=abs(p)-b;
    return length(max(d,vec3(0)))+vmax(min(d,vec3(0.0)));
}

float fOpUnion(in float a,in float b)
{
    return a<b?a:b;
}

vec4 v4OpUnion(in vec4 a,in vec4 b)
{
    return a.x<b.x?a:b;
}

float fOpUnionStep(float a, float b, float r, float n)
{
    float s = r/(n+1.);
    float u = b-r;
    return min(min(a,b), 0.5 * (u + a + abs ((mod (u - a + s, 2.0 * s)) - s)));
}

float fOpUnionSmooth(float a,float b,float r)
{
    vec2 u = max(vec2(r - a,r - b), vec2(0));
    return max(r, min (a, b)) - length(u);
}

vec4 v4OpUnionSmooth(vec4 a,vec4 b,float r)
{
    float h=clamp(0.5+0.5*(b.x-a.x)/r,0.0,1.0);
    float res = mix(b.x,a.x,h)-r*h*(1.0-h);
    return vec4(res, mix(b.yzw,a.yzw,h));
}

float fOpSubstraction(in float a,in float b)
{
    return max(-a, b);
}

float fOpSubstractionSmooth( float a,float b,float r)
{
    vec2 u = max(vec2(r + b,r + -a), vec2(0));
    return min(-r, max (b, -a)) + length(u);
}

float pMirror(float x, float k){
    return sqrt(x * x + k);
}

void pElongate(inout float p, in float h )
{
    p = p-clamp(p,-h,h);
}

void pRepPolar(inout vec2 p, float repetitions) {
    float angle = 2.*PI/repetitions;
    float a = atan(p.y, p.x) + angle/2.;
    a = mod(a,angle) - angle/2.;
    p = vec2(cos(a), sin(a))*length(p);
}

// Shapes.
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vec4 sdFoot(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p), bsr=0.2500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	vec3 cpFoot = p;
	{
		vec3 q = cpFoot;
#ifdef SHOW_SHOE
        float patapata = -q.z*(sin(iTime*5.)*.5+.05)+cos(iTime*5.)*.5;
#else
        float patapata = 0.;
#endif
        q.yz*=mat2(cos(-q.z*1.25+patapata+vec4(0,11,33,0)));
        cpFoot=q;
	}
	vec3 cpFoot_Main = cpFoot;
	cpFoot_Main.xyz += vec3(0.0000, 0.0000, 0.1273);
	pElongate(cpFoot_Main.y, 0.0125);
	{
		vec3 q=cpFoot_Main;
        vec3 pq=q;pq.yz *= mat2(cos(.6 + vec4(0, 11, 33, 0)));
        float ycl = smoothstep(.002,.2,q.y);
        float zcl = 1.-smoothstep(-.2,.5,q.z);
        float zcl2 = smoothstep(-.2,.0,q.z);
        q.z+=fbm(vec2(pq.x*20.5,pq.y*80.), 1)*.05*ycl*zcl*zcl2;
        cpFoot_Main=q;
	}

    // Shoe
	d = fOpUnion(sdEllipsoid(rot(cpFoot_Main+vec3(-0.0005, 0.0274, 0.1042), vec3(0.0818, -0.6861, 0.0566)), vec3(0.1102, 0.1233, 0.1214)), d);
	d = fOpUnionSmooth(sdEllipsoid(rot(cpFoot_Main+vec3(0.0028, -0.0093, -0.1258), vec3(-0.0291, -0.2744, -0.0364)), vec3(0.0870, 0.2295, 0.0880)), d, 0.1438);
	d = fOpSubstractionSmooth(sdBox(cpFoot_Main+vec3(0.0000, 0.1085, 0.0000), vec3(0.1676, 0.1089, 0.2519)), d, 0.0080);
	d = fOpSubstractionSmooth(sdBox(cpFoot+vec3(0.0000, -0.194, 0.0019), vec3(0.1676, 0.0551, 0.1171)), d, 0.0100);
	d = fOpSubstraction(sdBox(rot(cpFoot+vec3(0.0000, 0.0171, 0.1521), vec3(-1.4413, 0.0000, 0.0000)), vec3(0.1676, 0.0912, 0.0116)), d);
	d = fOpUnionSmooth(sdCappedTorus(cpFoot+vec3(0.0028, -0.1578, 0.0014), vec2(0.0519, 0.0264), 3.1413), d, 0.0100);
	res = v4OpUnion(vec4(d,vec3(0.8900, 0.5034, 0.4153)), res);
	d = MAX_DIST;
	// Shoe lace
	d = fOpUnion(sdCappedTorus(rot(cpFoot+vec3(0.0000, -0.0579, 0.1827), vec3(1.5708, 0.0000, 0.0000)), vec2(0.0636, 0.0064), 0.6283), d);
	d = fOpUnion(sdCappedTorus(rot(cpFoot+vec3(0.0000, -0.1001, 0.0608), vec3(2.2401, -0.3407, 0.2843)), vec2(0.0636, 0.0064), 0.6283), d);
	d = fOpUnion(sdCappedTorus(rot(cpFoot+vec3(0.0000, -0.0639, 0.1321), vec3(1.7335, 0.4446, -0.0513)), vec2(0.0636, 0.0064), 0.6283), d);
	d = fOpUnion(sdCappedTorus(rot(cpFoot+vec3(0.0000, -0.1001, 0.0608), vec3(2.2463, 0.3180, -0.2669)), vec2(0.0636, 0.0064), 0.6283), d);
	d = fOpUnion(sdCappedTorus(rot(cpFoot+vec3(0.0000, -0.0639, 0.1321), vec3(1.7334, -0.4468, 0.0515)), vec2(0.0636, 0.0064), 0.6283), d);
	res = v4OpUnion(vec4(d,vec3(0.1265, 0.9774, 0.8157)), res);
	return res;
}

vec4 sdHand(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, 0.0000, 0.1000)), bsr=0.1500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	d = fOpUnion(sdEllipsoid(rot(p+vec3(0.0010, -0.0040, 0.0686), vec3(-0.0288, 0.0000, 0.0000)), vec3(0.0688, 0.0519, 0.0687)), d);
	d = fOpUnion(sdEllipsoid(rot(p+vec3(0.0351, 0.0504, 0.2394), vec3(0.6982, -0.1114, -0.0032)), vec3(0.0219, 0.0219, 0.0217)), d);
	d = fOpUnion(sdEllipsoid(rot(p+vec3(-0.0359, 0.0375, 0.2293), vec3(0.6982, 0.2210, -0.0032)), vec3(0.0219, 0.0219, 0.0217)), d);
	d = fOpUnion(sdEllipsoid(rot(p+vec3(-0.0964, 0.0273, 0.1847), vec3(0.6982, 0.4986, -0.0032)), vec3(0.0170, 0.0170, 0.0168)), d);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(0.0264, 0.0006, 0.1607), vec3(0.3540, -0.1114, -0.0032)), vec3(0.0156, 0.0156, 0.0311)), d, 0.0318);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(-0.0176, -0.0145, 0.1488), vec3(0.3540, 0.2210, -0.0032)), vec3(0.0156, 0.0156, 0.0311)), d, 0.0318);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(-0.0657, -0.0072, 0.1285), vec3(0.3540, 0.4986, -0.0032)), vec3(0.0121, 0.0121, 0.0241)), d, 0.0318);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(0.0732, 0.0290, 0.0942), vec3(0.5542, -0.2213, 0.1170)), vec3(0.0176, 0.0176, 0.0361)), d, 0.0250);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(0.0966, 0.0611, 0.1302), vec3(0.5976, 0.0302, 0.2065)), vec3(0.0241, 0.0241, 0.0264)), d, 0.0250);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(0.0320, 0.0270, 0.2116), vec3(0.6982, -0.1114, -0.0032)), vec3(0.0166, 0.0166, 0.0277)), d, 0.0223);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(-0.0297, 0.0141, 0.2021), vec3(0.6982, 0.2210, -0.0032)), vec3(0.0166, 0.0166, 0.0277)), d, 0.0223);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(-0.0865, 0.0100, 0.1666), vec3(0.6982, 0.4986, -0.0032)), vec3(0.0128, 0.0128, 0.0214)), d, 0.0223);
	res = v4OpUnion(vec4(d,vec3(0.4743, 0.9774, 0.7076)), res);
	return res;
}

vec4 sdHead(vec3 p){
	return vec4(sdSphere(p+vec3(0.0000, -0.1000, 0.0000), 0.0646), vec3(0.4743, 0.9774, 0.7076));
}

vec4 sdHip(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p), bsr=0.5000;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	vec3 cpHip = p;
	vec3 cpHip_mir0_Pos = max(vec3(0), sign(cpHip));
	vec3 cpHip_mir0_Neg = max(vec3(0),-sign(cpHip));
	cpHip.x = pMirror(cpHip.x, 0.0050);
	{
		vec3 q=cpHip;
        vec3 pq=p;
        pq.xy*=mat2(cos(1.9*vec4(0,5,8,0)));
        q.y+=cos(pq.y*5.)*.1*sin(p.x*20.)*.1;
        q.x+=sin(p.y*5.)*.25*cos(pq.x*15.)*.1;
        cpHip=q;
	}

	d = fOpUnion(sdEllipsoid(rot(cpHip+vec3(-0.1456, -0.1908, 0.0040), vec3(0.0000, 0.0000, 0.4597)), vec3(0.1544, 0.1207, 0.1090)), d);
	res = v4OpUnion(vec4(d,vec3(0.5000, 1.0000, 0.6375)), res);
	return res;
}

vec4 sdLowerArm(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, 0.1200, 0.0000)), bsr=0.2500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	vec3 cpLowerArm = p;

	d = fOpUnion(sdEllipsoid(cpLowerArm+vec3(0, 0.1393, 0), vec3(0.1054, 0.2352, 0.1054)), d);
	d = fOpUnionSmooth(sdEllipsoid(rot(cpLowerArm, vec3(0.1191, 1.1406, 0.9428)), vec3(0.1168, 0.1070, 0.1070)), d, 0.0500);
	res = v4OpUnion(vec4(d,vec3(0.4675, 0.7156, 0.8073)), res);
	return res;
}

vec4 sdLowerLeg(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, 0.1500, 0.0000)), bsr=0.2500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	vec3 cpLowerLeg = p;
	vec3 cpLowerLeg_mir0_Pos = max(vec3(0), sign(cpLowerLeg));
	vec3 cpLowerLeg_mir0_Neg = max(vec3(0),-sign(cpLowerLeg));
	cpLowerLeg.x = pMirror(cpLowerLeg.x, 0.0000);
	{
		vec3 q=cpLowerLeg;
        vec3 pq=p;pq.yz *= mat2(cos(-1.1 + vec4(0, 11, 33, 0)));
        q.x+=sin(pq.y*50.)*.01;
        cpLowerLeg=q;
	}
	d = fOpUnion(sdEllipsoid(rot(cpLowerLeg+vec3(0.0240, 0.1194, -0.0009), vec3(0.0000, 0.0004, -0.0041)), vec3(0.1450, 0.2824, 0.1450)), d);
	d = fOpUnionSmooth(sdCappedTorus(rot(cpLowerLeg+vec3(0.0164, 0.0039, -0.0422), vec3(0.1978, 0.0000, -3.1416)), vec2(0.1025, 0.0102), 3.1413), d, 0.0200);
	d = fOpUnionSmooth(sdCappedTorus(rot(cpLowerLeg+vec3(0.0088, 0.0352, -0.0548), vec3(0.5139, -0.0273, 0.0000)), vec2(0.0913, 0.0114), 3.1413), d, 0.0200);
	d = fOpUnionSmooth(sdCappedTorus(rot(cpLowerLeg+vec3(0.0129, 0.0511, -0.0293), vec3(0.0638, -0.0185, 0.0000)), vec2(0.1024, 0.0096), 3.1413), d, 0.0200);
	d = fOpUnionSmooth(sdConeSection(rot(cpLowerLeg+vec3(0.0000, 0.3047, 0.0000), vec3(0.0000, 0.0008, -0.0040)), 0.1353, 0.1402, 0.0670), d, 0.0601);
	res = v4OpUnion(vec4(d,vec3(0.5000, 1.0000, 0.6375)), res);
	return res;
}

vec4 sdSodeguchi(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p), bsr=0.0750;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	vec3 cpSodeguchi = p;

	vec3 cpSodeguchi_Mizo = cpSodeguchi;
	pRepPolar(cpSodeguchi_Mizo.xz, 19.0000);

	d = fOpUnion(sdTorus(cpSodeguchi, vec2(0.0496, 0.0310)), d);
	d = fOpUnionSmooth(sdCappedCylinder(cpSodeguchi, vec2(0.0370, 0.0370)), d, 0.0100);
	d = fOpUnionSmooth(sdCapsule(rot(cpSodeguchi_Mizo+vec3(-0.0380, 0.0266, 0.0000), vec3(0.1747, 0.0000, 0.0000)), 0.0020, 0.0543), d, 0.0010);
	d = fOpUnionSmooth(sdTorus(cpSodeguchi+vec3(0.0000, 0.0852, 0.0000), vec2(0.0393, 0.0045)), d, 0.0250);
	res = v4OpUnion(vec4(d,vec3(0.4675, 0.7156, 0.8073)), res);
	return res;
}

vec4 sdTorso(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, -0.3500, 0.0000)), bsr=0.4250;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	vec3 cpTorso = p;
	{
		vec3 q=cpTorso;vec3 pq=p;
        pq.xy*=mat2(cos(-.25+vec4(0,11,33,0)));
        q.z+=fbm(vec2(pq.z*1.5,pq.y*10.+sin(pq.z*13.)*.25), 1)*.125*(1.-smoothstep(0.,1.,q.y));
        q.x+=fbm(vec2(pq.x*1.5,pq.y*10.+sin(pq.x*13.)*.25), 1)*.075*(1.-smoothstep(0.,1.,q.y));
        cpTorso=q;
	}
	vec3 cpTorso_Elongate = cpTorso;
	cpTorso_Elongate.xyz += vec3(-0.0577, -0.0147, -0.0036);
	cpTorso_Elongate.xyz = rot(cpTorso_Elongate, vec3(0.0000, 0.0000, 0.2252));
	pElongate(cpTorso_Elongate.x, 0.1000);

	d = fOpUnion(sdEllipsoid(rot(cpTorso+vec3(-0.0501, -0.0879, -0.0794), vec3(0.2961, 0.0000, 0.0000)), vec3(0.2447, 0.1408, 0.1837)), d);
	d = fOpUnionSmooth(sdTorus(rot(cpTorso_Elongate+vec3(-0.0406, -0.0183, 0.0804), vec3(0.2204, -0.0303, 0.0000)), vec2(0.1647, 0.0776)), d, 0.1720);
	d = fOpUnionSmooth(sdEllipsoid(rot(cpTorso+vec3(0.0000, -0.5773, -0.0088), vec3(0.8164, 0.0000, 0.0000)), vec3(0.2890, 0.2029, 0.1701)), d, 0.4600);
	d = fOpUnionSmooth(sdTorus(rot(cpTorso+vec3(-0.0417, -0.2882, -0.0229), vec3(0.3365, 1.4599, -0.4932)), vec2(0.1800, 0.0540)), d, 0.1100);
	d = fOpUnionSmooth(sdTorus(rot(cpTorso+vec3(-0.0736, -0.4293, -0.0080), vec3(-0.4843, 1.5645, -0.3815)), vec2(0.2008, 0.0301)), d, 0.1120);
	d = fOpUnionSmooth(sdTorus(rot(cpTorso+vec3(0.0594, 0.0184, -0.0297), vec3(-0.2545, 1.4571, 0.1212)), vec2(0.2037, 0.0458)), d, 0.1480);
	res = v4OpUnion(vec4(d,vec3(0.4675, 0.7156, 0.8073)), res);
	return res;
}

vec4 sdUpperArm(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, 0.1600, 0.0000)), bsr=0.2500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	d = fOpUnion(sdEllipsoid(p+vec3(0.0000, 0.2187, 0.0000), vec3(0.1173, 0.2786, 0.1173)), d);
	d = fOpUnionSmooth(sdEllipsoid(rot(p+vec3(0.0814, 0.0000, 0.0000), vec3(-3.3018, -2.1277, 1.2590)), vec3(0.1273, 0.1165, 0.1165)), d, 0.0500);
	res = v4OpUnion(vec4(d,vec3(0.4675, 0.7156, 0.8073)), res);
	return res;
}

vec4 sdUpperLeg(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, 0.1500, 0.0000)), bsr=0.2500;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);

	vec3 cpUpperLeg = p;
	vec3 cpUpperLeg_mir0_Pos = max(vec3(0), sign(cpUpperLeg));
	vec3 cpUpperLeg_mir0_Neg = max(vec3(0),-sign(cpUpperLeg));
	cpUpperLeg.x = pMirror(cpUpperLeg.x, 0.0000);
	{
		vec3 q=cpUpperLeg;
        vec3 pq=p;pq.yz *= mat2(cos(-1.1 + vec4(0, 11, 33, 0)));
        q.x+=sin(pq.y*50.)*.01;
        cpUpperLeg=q;
	}

	d = fOpUnion(sdEllipsoid(cpUpperLeg+vec3(-0.0007, 0.0001, -0.0010), vec3(0.1475, 0.1477, 0.1408)), d);
	d = fOpUnionSmooth(sdEllipsoid(p+vec3(0.1774, -0.0475, 0.0664), vec3(0.0716, 0.0717, 0.0684)), d, 0.0421);
	d = fOpUnionSmooth(sdEllipsoid(cpUpperLeg+vec3(-0.0007, 0.2607, 0.0151), vec3(0.1540, 0.2725, 0.1543)), d, 0.1201);
	res = v4OpUnion(vec4(d,vec3(0.5000, 1.0000, 0.6375)), res);
	return res;
}

vec4 sdMan_Walking(vec3 p){
	float d = MAX_DIST;
	vec4 res = vec4(MAX_DIST, MAT_VOID);
	float bsd = length(p+vec3(0.0000, -0.9400, 0.0000)), bsr=0.7617;
	if (bsd > 2.*bsr) return vec4(bsd-bsr,MAT_VOID);
	vec3 cpMan_Root = p;

	vec3 cpArm_L = cpMan_Root;
	cpArm_L.xyz += vec3(-0.2285, -1.7683, 0.0147);
	cpArm_L.xyz = rot(cpArm_L, vec3(-0.0259, -0.4911, -0.5401));

	vec3 cpArm_R = cpMan_Root;
	cpArm_R.xyz += vec3(0.2970, -1.7732, -0.0896);
	cpArm_R.xyz = rot(cpArm_R, vec3(0.8591, 0.0411, 0.1902));
	{
		vec3 q = cpArm_R;
        q.x*=-1.;
        cpArm_R=q;
	}
	vec3 cpLeg_L = cpMan_Root;
	cpLeg_L.xyz += vec3(-0.1887, -1.0209, 0.0000);
	cpLeg_L.xyz = rot(cpLeg_L, vec3(0.2961, -0.0255, 0.0072));

	vec3 cpLeg_R = cpMan_Root;
	cpLeg_R.xyz += vec3(0.1440, -1.0291, 0.0000);
	cpLeg_R.xyz = rot(cpLeg_R, vec3(-0.4479, -0.0237, -0.0120));
	{
		vec3 q = cpLeg_R;
        q.x*=-1.;
        cpLeg_R=q;
	}
	vec3 cp003_004 = cpArm_R;
	{
		vec3 q=cp003_004;
        vec3 pq=p;
        pq.yz *= mat2(cos(-1.1 + vec4(0, 11, 33, 0)));
        q.x+=sin(pq.y*30.)*.01;
        cp003_004=q;
	}
    {
		vec3 q=cp003_004;
        vec3 pq=p;
        pq.xy *= mat2(cos(noise(pq.xy*vec2(5,1))*PI*.3+vec4(0,11,33,0)));
        float size = 12.;
        float strength = .1;
        q.x+=(fbm(vec2(pq.x*size,pq.y*size), 1)-.5)*strength*(smoothstep(0.,-1.,q.y));
        q.z+=(fbm(vec2(pq.z*size,pq.y*size), 1)-.5)*strength*(smoothstep(0.,-1.,q.y));
        cp003_004=q;
	}
	vec3 cp003 = cpArm_L;
	{
		vec3 q=cp003;
        vec3 pq=p;
        pq.yz *= mat2(cos(-1.1 + vec4(0, 11, 33, 0)));
        q.x+=sin(pq.y*50.)*.01;
        cp003=q;
	}
    {
		vec3 q=cp003;
        vec3 pq=p;
        pq.xy *= mat2(cos(noise(pq.xy*vec2(2,1))*PI*.3+vec4(0,11,33,0)));
        float size = 12.;
        float strength = .1;
        q.x+=(fbm(vec2(pq.x*size,pq.y*size), 1)-.5)*strength*(smoothstep(0.,-1.,q.y));
        q.z+=(fbm(vec2(pq.z*size,pq.y*size), 1)-.5)*strength*(smoothstep(0.,-1.,q.y));
        cp003=q;
	}
#ifndef SHOW_SHOE
	res = v4OpUnionSmooth(sdUpperLeg(cpLeg_L), res, 0.0100);
	res = v4OpUnionSmooth(sdUpperLeg(cpLeg_R), res, 0.0100);
	res = v4OpUnion(sdHead(rot(cpMan_Root+vec3(0.0000, -1.9264, 0.0946), vec3(0.3161, 0.0000, 0.0000))), res);
	res = v4OpUnionSmooth(sdHip(rot(cpMan_Root+vec3(-0.0025, -0.8238, -0.1085), vec3(0.0000, 0.2785, 0.0000))), res, 0.0500);
	res = v4OpUnionSmooth(sdLowerLeg(rot(cpLeg_L+vec3(0.0000, 0.4296, 0.0000), vec3(0.3358, 0.0429, 0.0051))), res, 0.0500);
	res = v4OpUnionSmooth(sdLowerLeg(rot(cpLeg_R+vec3(0.0000, 0.4296, 0.0000), vec3(0.3358, 0.0429, 0.0051))), res, 0.0500);
    const float fY = 1.0400;
#else
    const float fY = 1.0350;
#endif
	res = v4OpUnion(sdFoot(rot(cpLeg_R+vec3(0.0122, fY, -0.2127), vec3(0.3358, 0.0429, 0.0051))), res);
#ifndef SHOW_SHOE
	res = v4OpUnion(sdFoot(rot(cpLeg_L+vec3(0.0122, 1.0400, -0.2127), vec3(0.3713, 0.0430, 0.0045))), res);
	res = v4OpUnionSmooth(sdSodeguchi(rot(cpArm_L+vec3(0.0494, 0.6329, 0.1930), vec3(-0.6206, 0.0266, 0.3167))), res, 0.0050);
	res = v4OpUnionSmooth(sdSodeguchi(rot(cpArm_R+vec3(0.0184, 0.6838, 0.1199), vec3(-0.7478, -0.0227, 0.2680))), res, 0.0050);
	res = v4OpUnionSmooth(sdTorso(rot(cpMan_Root+vec3(0.0000, -1.1769, -0.0665), vec3(0.0574, 0.0000, 0.0000))), res, 0.0200);
	res = v4OpUnionSmooth(sdUpperArm(cp003), res, 0.0750);
	res = v4OpUnionSmooth(sdUpperArm(cp003_004), res, 0.0500);
	res = v4OpUnionSmooth(sdLowerArm(rot(cp003+vec3(0.0000, 0.3702, 0.0000), vec3(-0.6301, -0.2742, -0.1053))), res, 0.0400);
	res = v4OpUnionSmooth(sdLowerArm(rot(cp003_004+vec3(0.0000, 0.3702, 0.0000), vec3(-0.3764, -0.1114, -0.0029))), res, 0.0250);
	res = v4OpUnion(sdHand(rot(cpArm_L+vec3(0.0702, 0.7357, 0.2618), vec3(0.9016, 0.1943, 0.6602))), res);
	res = v4OpUnion(sdHand(rot(cpArm_R+vec3(0.0368, 0.7749, 0.1977), vec3(1.5493, 0.9155, 0.6787))), res);
#endif
	return res;
}

vec4 sdScene(vec3 p)
{
    float d = MAX_DIST;
    vec4 res = vec4(MAX_DIST, MAT_VOID);

    vec4 grnd = res;
    if(length(p.xz)<3.) grnd = vec4(p.y+.03, vec3(0.6986, 0.8128, 0.8900));
	res = v4OpUnion(sdMan_Walking(p-vec3(0,0,.025)), grnd);

    return res;
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vec4 intersect()
{
    float d = MIN_DIST;
    vec3  m = MAT_VOID;

    for (int i = ZERO; i < ITERATION+CHARM; i++)
    {
        vec3 p = ro + d * rd;
        vec4 res = sdScene(p);
        res.x*=.5;
        m = res.yzw;
        if (abs(res.x) < MIN_DIST)break;
        d += res.x;
        if (d >= MAX_DIST) return vec4(MAX_DIST, MAT_VOID);
    }
    if(d>MAX_DIST) return vec4(MAX_DIST, MAT_VOID);
    return vec4(d,m);
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vec3 normal(vec3 p)
{
    // inspired by tdhooper and klems - a way to prevent the compiler from inlining map() 4 times
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4+CHARM; i++ )
    {
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*sdScene(p+0.0005*e).x;
      //if( n.x+n.y+n.z>100.0 ) break;
    }
    return normalize(n);
}

// iq's soft shadow
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float shadow(vec3 o)
{
    float mint=0.01;
    float maxt=30.;
    float k = 64.;
    float res = 1.;
    float ph = 1e20;
    float t=mint;
    for( int i=ZERO; i < 60+CHARM; i++)
    {
        float h = sdScene(o + ldir*t).x;
        if(abs(h)<MIN_DIST) return 0.;

        res = min( res, k*h/t);
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, k*d/max(0.0,t-y));
        ph = h;
        t += h;

        if(t >= maxt) break;
    }
    return res;//smoothstep(.5, .51, res);
}

// "Hemispherical SDF AO" by XT95:
// https://www.shadertoy.com/view/4sdGWN
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
vec3 randomSphereDir(vec2 rnd)
{
    float s = rnd.x*PI*2.;
    float t = rnd.y*2.-1.;
    return vec3(sin(s), cos(s), t) / sqrt(1.0 + t * t);
}
vec3 randomHemisphereDir(vec3 dir, float i)
{
    vec3 v = randomSphereDir( vec2(hash11(i+1.), hash11(i+2.)) );
    return v * sign(dot(v, dir));
}
float ambientOcclusion( in vec3 p, in vec3 n, in float maxDist, in float falloff )
{
    const int nbIte = 12;
    const float nbIteInv = 1./float(nbIte);
    const float rad = 1.-1.*nbIteInv; //Hemispherical factor (self occlusion correction)

    float ao = 0.0;

    for( int i=ZERO; i<nbIte+CHARM; i++ )
    {
        float l = hash11(float(i))*maxDist;
        vec3 aord = normalize(n+randomHemisphereDir(n, l )*rad)*l; // mix direction with the normal// for self occlusion problems!

        ao += (l - max(sdScene( p + aord ).x,0.)) / maxDist * falloff;
    }

    return clamp( 1.-ao*nbIteInv, 0., 1.);
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float specular(vec3 p, vec3 n, vec3 ld, float power)
{
    vec3 to_eye = normalize(p - ro);
    vec3 reflect_light = normalize(reflect(ld, n));
    return pow(max(dot(to_eye, reflect_light), 0.), power);
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
float diffuse = 0.;
float spec = 0.;
float shdw = 1.;
float ao = 1.;
float depth = 0.;
vec3 albedo = vec3(0);
vec3 nml = vec3(0);

void render()
{
    vec4 hit = intersect();
    vec3 p = ro + hit.x * rd;
    albedo = hit.yzw;

    if (hit.x>=MAX_DIST)
    {
        nml = vec3(0);
        albedo = AMB_COL;
        spec = 0.;
        depth = 1.;
        diffuse = 0.;
        return;
    }

    vec3 n = normal(p);
    vec3 offset = n * .005;

    // Camera localized normal
    vec3 up = camup;
    vec3 side = cross(rd, up);
    nml.x = dot(n+offset,  side);
    nml.y = dot(n+offset,  up);
    nml.z = dot(n+offset,  -rd);

    diffuse = dot(n+offset,  ldir)*.5+.5; // Half-Lanbert
    shdw = shadow(p+offset);

    ao = ambientOcclusion(p+n*0.01, n, .5, 2.);
    ao += ambientOcclusion(p+n*0.01, n, .1, 2.);
    ao = smoothstep(0., 2., ao);
    ao = pow(ao, .25);

    depth = distance(ro, p)/MAX_DIST;

    const float thresh = .01;
    if(!(distance(albedo, MAT_SHOE) < thresh) && !(distance(albedo, MAT_FLOOR) < thresh)) return;

    if(distance(albedo, MAT_SHOE) < thresh)
    {
        // Shoe
        spec = specular(p+offset, n, ldir, 10.);
    }

    {
        // Floor
        vec2 uv = vec2(p.z, p.y);

        vec3 q = p;

        uv.x = q.x;
        uv.y = q.z;
        uv.x *= 2.;
        uv*=1.5;

        int offset = int(uv.x)%2;
        vec2 ratio = vec2(1,4);
        float gridGap = 0.001;
        if(offset==0)uv.y+=ratio.y*.5;

        vec2 id = floor(uv/ratio);
        uv = mod(uv, ratio)-ratio*.5;

        float d =sdBox(uv, ratio*.5-gridGap);
        if(noise(uv*5.*id)<.75)
            diffuse *= step(.1, 1.0 - exp(-8.0*abs(d)));
        if(noise(uv*90.)<.75)
        {
            uv.y+=fbm(uv*16., 2)*.025;
            uv *= mat2(cos(noise(uv*vec2(5,1)+id)*PI*.3+vec4(0,11,33,0)));
            diffuse *= smoothstep(.4, .5, abs(sin(uv.x*40.)));
        }

    }
}

// "camera": create camera vectors.
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
void camera(vec2 uv)
{
#ifdef SHOW_SHOE
    const float pY = .5;
    const float cL = 2.;
    const vec3 forcus = vec3(-.15,.1,-.34);
    const float fov = .08;
#else
    const float pY = 1.;
    const float cL = 9.;
    const vec3 forcus = vec3(0,1,0);
    const float fov = .125;
#endif
    vec3 up = vec3(0,1,0);
    vec3 pos = vec3(0,pY,0);
    pos.xz = vec2(sin(iTime),cos(iTime))*cL;
    if(iMouse.z>.5)
        pos.xz = vec2(sin(iMouse.x/iResolution.x*TAU),cos(iMouse.x/iResolution.x*TAU))*cL;
    vec3 dir = normalize(forcus-pos);
    vec3 target = pos-dir;
    vec3 cw = normalize(target - pos);
    vec3 cu = normalize(cross(cw, up));
    vec3 cv = normalize(cross(cu, cw));
	camup = cv;
    mat3 camMat = mat3(cu, cv, cw);
    rd = normalize(camMat * normalize(vec3(sin(fov) * uv.x, sin(fov) * uv.y, -cos(fov))));
    ro = pos;
}

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = (uv*2.-1.);
    uv.x *= iResolution.x / iResolution.y;

    camera(uv);
    render();

    vec3 spec_diffuse_ao = vec3(spec, diffuse, ao)*2.-1.;

    fragColor = vec4(
        pack4(vec4(nml, shdw)),
        pack(albedo),
        pack(spec_diffuse_ao),
        depth
    );
}
