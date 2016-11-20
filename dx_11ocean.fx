/***********************************************/
/*** automatically-tracked "tweakables" ********/
/***********************************************/

#include "common.fxh"

#define PI (3.14159265)
#define G (9.8)
#define PHASE (2*PI)

// Application constants (updated each frame)
cbuffer UpdatePerFrame : register(b0)
{
	float4x4 ViewInverse 	: ViewInverse 	< string UIWidget = "None"; >;
	float globalTimer 		: TIME 			< string UIWidget = "None"; >;
}

//Object constants
cbuffer UpdatePerObject :register(b1)
{
	float4x4 WorldViewProjection 	: WorldViewProjection 	< string UIWidget = "None"; >;
	float4x4 WorldInverseTranspose 	: WorldInverseTranspose < string UIWidget = "None"; >;
	float4x4 World 					: World 				< string UIWidget = "None"; >;
}

//dx11 style
float4 waterColorA 		<String uiname="Water Color A"; bool color=true;> = { 1.0f,1.0f,1.0f,1.0f };
float tile 				<String uiname="Tile";> = 1.0f;
float specIntensity 	<String uiname="Spec Intensity"; 	float UIMin = 0.0; float UIMax = 10.0; float UIStep = 0.01;> = 0.5;
float timerScale1 		<String uiname="Timer Scale 1"; 	float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.2;
float timerScale2 		<String uiname="Timer Scale 2"; 	float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.2;
float amplitude = 0.1;	// amplitude
float waveLength = 2.5;	// wavelength
int waveCount = 3;
float speed = 2.1;
float dirX = 1.0;
float dirY = 0.0;
float crestFactor;
float fresBias;
float fresScale;
float fresPower;
float reflectPower;

static const float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.1);

Texture2D diffMap;
Texture2D normalMap;
Texture2D foamMap;
Texture2D noiseMap;
TextureCube cubeTexture;

SamplerState LinearSampler
{
 Filter = MIN_MAG_MIP_LINEAR;
 AddressU = Wrap;
 AddressV = Wrap;
};


SamplerState CubeMapSampler
{
	Filter = ANISOTROPIC;
	AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;    
};


/****************************************************/
/********** SHADER STRUCTS **************************/
/****************************************************/

// input from application 
struct app2vertex
{ 
	float4 position			: POSITION;
	float2 texCoord0		: TEXCOORD0;
	float2 texCoord1		: TEXCOORD1;
	float3 tangent			: TANGENT;
	float3 binormal			: BINORMAL;
	float3 normal			: NORMAL;
	//float3 Fresnel : COLOR0;
}; 


// output to pixel shader 
struct vertex2pixel
{ 
    float4 position    		: SV_POSITION;
   	float2 texCoord0		: TEXCOORD0;
	float3 viewVec			: TEXCOORD1;
	float3 worldNormal		: TEXCOORD2;
	float3 worldTangent		: TEXCOORD3;
	float3 worldBinormal	: TEXCOORD4;
	float3 positionW		: TEXCOORD5;
	float3 heightW	 		: TEXCOORD6;
};

/**************************************/
/***** VERTEX SHADER ******************/
/**************************************/

float3 gerstnerNormal(float3 position, float multiplier, float2 direction)
{
	float amp = amplitude*0.025;
	amp *= multiplier;

	float WL = waveLength;
	WL *= multiplier;

	float2 D = direction;
	float w = 2*PI/WL;
	float Q = crestFactor;
	float3 P0 = position.xyz;
	float myPhase = speed * 2*PI/WL;

	float dotX = dot(D, P0.x);
	float dotY = dot(D, P0.y);
	float dotP = dot(D, P0);

	float C = cos(w*dotP + (globalTimer*myPhase));
	float S = sin(w*dotP + (globalTimer*myPhase));
	float WA = w*amp;

	//float3 N = float3(dotX*WA*C, Q*WA*S, dotY*WA*C);
	float3 N = float3(dotX*WA*C, Q*WA*S, dotY*WA*C);
	return N;
}

float3 gerstnerTangent(float3 position, float multiplier, float2 direction)
{
	float amp = amplitude*0.025;
	amp *= multiplier;

	float WL = waveLength;
	WL *= multiplier;

	float2 D = direction;
	float w = 2*PI/WL;
	float Q = crestFactor;
	float3 P0 = position.xyz;
	float myPhase = speed * 2*PI/WL;

	float dotX = dot(D, P0.x);
	float dotY = dot(D, P0.y);
	float powDotY = dot(D, pow(P0.y, 2));
	float dotP = dot(D, P0);

	float C = cos(w*dotP + (globalTimer*myPhase));
	float S = sin(w*dotP + (globalTimer*myPhase));
	float WA = w*amp;

	float3 T = float3(Q*dotX*dotY*WA*S, dotY*WA*C, Q*powDotY*WA*S);
	return T;
}

float3 gerstnerBinormal(float3 position, float multiplier, float2 direction)
{
	float amp = amplitude*0.025;
	amp *= multiplier;

	float WL = waveLength;
	WL *= multiplier;

	float2 D = direction;
	float w = 2*PI/WL;
	float Q = crestFactor;
	float3 P0 = position.xyz;
	float myPhase = speed * 2*PI/WL;

	float dotX = dot(D, P0.x);
	float dotY = dot(D, P0.y);
	float powDotX = dot(D, pow(P0.x, 2));
	float dotP = dot(D, P0);

	float C = cos(w*dotP + (globalTimer*myPhase));
	float S = sin(w*dotP + (globalTimer*myPhase));
	float WA = w*amp;

	float3 B = float3(Q*powDotX*WA*S, dotX*WA*C, Q*dotX*dotY*WA*S);
	return B;
}

float3 gerstnerWave(float3 position, float multiplier, float2 direction)
{
	// Put te vars in a struct!!
	float amp = amplitude*0.025;
	amp *= multiplier;
	
	float WL = waveLength;
	WL *= multiplier;

	float2 D = direction;

	float w = 2*PI/WL;
	float Q = crestFactor;
	float3 P0 = position.xyz;
	float myPhase = speed * 2*PI/WL;

	float dotD = dot(D, P0.xz);
	float C = cos(w*dotD + (globalTimer*myPhase));
	float S = sin(w*dotD + (globalTimer*myPhase));
	float3 P = float3(Q*amp*D.x*C, amp * S, Q*amp*D.y*C);
	return P;
}

// Static for the time being... Need to make them a bit more dynamic
static float mulArray[3] = {0.561,1.793,0.697};
static float2 dirsArray[3] = {float2(0.0, 1.0), float2(1.0, 0.5), float2(0.25, 1.0)};

vertex2pixel vertexNormalMap(app2vertex In)
{ 
	vertex2pixel Out = (vertex2pixel)0;
	//Out.worldBinormal = mul(In.binormal, WorldInverseTranspose).xyz;
	//Out.worldTangent = mul(In.tangent, WorldInverseTranspose).xyz;	
	//Out.worldNormal = mul(In.normal, WorldInverseTranspose).xyz;	
    float3 worldSpacePos = mul(In.position, World);
    Out.positionW = worldSpacePos;
    Out.texCoord0 = In.texCoord0;
    Out.texCoord0.xy -= (globalTimer*timerScale1);
    //Out.cubeCoord = In.texCoord1;
	Out.viewVec = ViewInverse[3] - worldSpacePos;

	float3 sumW = float3(0,0,0);
	float3 sumB = float3(0,0,0);
	float3 sumT = float3(0,0,0);
	float3 sumN = float3(0,0,0);
	for(int i=0; i < 3; i++)
	{
		float2 dirsXY = float2(dirX, dirY);
		float2 dirsVal = dirsArray[i]*dirsXY;
		float mulVal = mulArray[i];//* customNoise(dirsVal);
		//sumW += gerstnerWave(In.position, mulVal, dirsArray[i]);
		// worldSpacePos gives a much smaller scale to work from. Looks better from long distances.
		// Perhaps a scale value can help achive this same result with in.position....
		sumW += gerstnerWave(In.position, mulArray[i], dirsArray[i]);
		sumB += gerstnerBinormal(sumW, mulArray[i], dirsArray[i]);
		sumT += gerstnerTangent(sumW, mulArray[i], dirsArray[i]);
		sumN += gerstnerNormal(sumW, mulArray[i], dirsArray[i]);
	}

	// Calculate final pos, binorm, tangent and normal
	sumW += In.position;

	sumB.x = 1-sumB.x;
	sumB.z = -sumB.z;

	sumT.x = -sumT.x;
	sumT.y = 1-sumT.y;

	sumN.x = -sumN.x;
	sumN.y = 1-sumN.y;
	sumN.z = -sumN.z;

	Out.heightW = mul(float4(sumW, 1), World);

	//Out.positionW = mul(float4(sumW,In.position.w), World);
	Out.worldBinormal = mul(In.binormal + normalize(sumB), WorldInverseTranspose).xyz;
	Out.worldTangent = mul(In.tangent 	+ normalize(sumT), WorldInverseTranspose).xyz;	
	Out.worldNormal = mul(In.normal 	+ normalize(sumN), WorldInverseTranspose).xyz;
	Out.position = mul(float4(sumW,1), WorldViewProjection);
    return Out; 
}

/**************************************/
/***** PIXEL SHADER *******************/
/**************************************/

// SV_TARGET is dx11 style pixel shader
float4 pixel(vertex2pixel input) : SV_TARGET 
{	
	//Texture sampling
	float3 worldSpacePix = input.positionW;
	float2 heightWorld = input.heightW;

	float3x3 toWorld 	= float3x3(input.worldTangent, input.worldBinormal, input.worldNormal);
	float3 normal 		= SampleTexture(normalMap, LinearSampler,  input.texCoord0*tile, float3(0.5, 0.5, 1.0))*2-1;
	float3 bumpWorld 	= normalize(mul(normal,toWorld));

	if(heightWorld.y > 2.0)
	{
		float3 diffuseMap 	= SampleTexture(diffMap, LinearSampler, input.texCoord0*tile, float3(1.0, 1.0, 1.0));
	}
	else
	{
		float3 diffuseMap 	= SampleTexture(foamMap, LinearSampler, input.texCoord0*tile, float3(1.0, 1.0, 1.0));
	}
	float3 diffuseMap 	= SampleTexture(diffMap, LinearSampler, input.texCoord0*tile, float3(1.0, 1.0, 1.0));

	float3 foam 		= SampleTexture(foamMap, LinearSampler, input.texCoord0, float3(1.0, 1.0, 1.0));
	float3 noiseM 		= SampleTexture(noiseMap, LinearSampler, input.texCoord0, waterColorA.xyz);
	
	// Light calculation
	LightData light0 = CalculateLight(light0Type, light0AttenScale, light0Pos, worldSpacePix,  ToLinear(light0Color), light0Intensity, light0Dir, light0ConeAngle, light0FallOff);
	light0Dir = light0.dir;
	light0Color = light0.color;
	float3 light0Vec = light0.lightVec;
	
	float3 V = input.viewVec;
	float3 H = normalize(V + light0Dir);
	float3 R = reflect(-V, input.worldNormal);
	float3 refraction = refract(-V, input.worldNormal, 1.3333);

    float4 reflectedColor = cubeTexture.Sample(CubeMapSampler, R);
    float4 refractedColor = cubeTexture.Sample(CubeMapSampler, refraction);
    float3 reflectionCoefficient = max(min(fresBias + fresScale * (1 + refraction)*fresPower,5), 0);

    //float fresnel = pow(1.0-abs(R),5.0);
	//float Rzero = 1.0;
    //float4 fresnel = Rzero + (1.0f - Rzero) * pow(abs(1.0f - dot(input.worldNormal, V)), 5.0 );    

	// Base color of surface with lighting
	float4 color = waterColorA;
	color.xyz = lerp(diffuseMap, waterColorA.xyz, 0.25);
	color.rgb = color.rgb * light0Intensity * light0Color;
	float diffLight = saturate(dot(bumpWorld, light0Dir));

    // Calculate the reflection vector using the normal and the direction of the light.
    float3 reflection = -reflect(bumpWorld*0.25, normalize(light0Dir));	
    // Calculate the specular light based on the reflection and the camera position.
    float4 specular = dot(normalize(reflection), normalize(V));
    //float4 specular = pow(dot(H, bumpWorld), specIntensity);
    specular = pow(specular, 256);
    specular *= specIntensity * float4(light0Color,0);


   /* float3 vRef = normalize(reflect(-light0Vec, bumpWorld));
    float stemp =max(0.0, dot(diffuseMap, vRef) );
    float4 specular = pow(stemp, 64.0); 

	//float4 specular = specIntensity * float4(light0Color,0) * pow(dot(bumpWorld, H),256);
	*/

	color *= diffLight;
	float3 cFinal = reflectionCoefficient * reflectedColor + (1 - reflectionCoefficient) * refractedColor;
	cFinal += color.xyz;
	cFinal *= noiseM.xyz;
	float4 final = float4(cFinal, 0);
	float4 result = lerp(color, final, reflectPower);

	// Foam from height map at the moment. Need to make it based on actual wave crest
	float fm = clamp(pow(noiseM, 7),0,1);
	float3 red = float3(255, 255, 255);
	float3 withFoam = lerp(result.xyz, red, fm);
	float4 finalFoam = float4(withFoam, 1);
	return saturate(color * finalFoam + specular);
} 



/****************************************************/
/********** TECHNIQUES ******************************/
/****************************************************/

RasterizerState CullFront
{
	CullMode = Front;
};

technique11 Shaded {
	pass p0 {
		SetRasterizerState(CullFront);
		SetVertexShader( CompileShader( vs_5_0, vertexNormalMap() ));
		SetPixelShader(CompileShader(ps_5_0, pixel()));
	}
}

/*
//https://code.msdn.microsoft.com/How-to-implement-water-3ca71ecf/sourcecode?fileId=159413&pathId=2085152799
// Per-pixel color data passed through the pixel shader.
struct PixelShaderInput
{
	float4 pos : SV_Position;
	float3 normal : NORMAL0;
	float4 tangent : TANGENT0;
	float4 color : COLOR0;
	float2 tex : TEXCOORD0;
	float4 reflectPosition : TEXCOORD1;
	float4 refractPosition : TEXCOORD2;
};
Texture2D reflectionTexture;
Texture2D refractionTexture;
Texture2D normalTexture;
SamplerState samLinear;
// amplitude pass-through function for the (interpolated) color data.
float4 main(PixelShaderInput input) : SV_TARGET
{	
	float2 reflectTexCoord;
	float2 refractTexCoord;
	reflectTexCoord.x = input.reflectPosition.x / input.reflectPosition.w / 2.0f + 0.5f;
	reflectTexCoord.y = -input.reflectPosition.y / input.reflectPosition.w / 2.0f + 0.5f;

	refractTexCoord.x = input.refractPosition.x / input.refractPosition.w / 2.0f + 0.5f;
	refractTexCoord.y = -input.refractPosition.y / input.refractPosition.w / 2.0f + 0.5f;

	float4 normalTex = normalTexture.Sample(samLinear, input.tex);
	float3 normal = (normalTex.xyz * 2.0f) - 1.0f;
	reflectTexCoord += normal.xy * 0.05;
	refractTexCoord += normal.xy * 0.02;
	float4 reflectTex = reflectionTexture.Sample(samLinear, reflectTexCoord);
	float4 refractTex = refractionTexture.Sample(samLinear, refractTexCoord);
	float4 final = lerp(reflectTex, refractTex, 0.6f);
	return final * input.color;
}

// Simple sine wave function
float3 waveFunction(float3 position)
{
	float amp = amplitude;
	float wl = waveLength;

	float w = 2*PI/waveLength;
	float myPhase = speed * 2*PI/waveLength;
	float2 waveDir = float2(dirX, dirY);
	float dotY = dot(waveDir, position.xz);
	float Y = amplitude * sin(dotY * w + (globalTimer * myPhase));
	return float3(0, Y, 0);
}

float sea_octave(float2 uv, float choppy) 
{
    uv += customNoise(uv);        
    float2 wv = 1.0-abs(sin(uv));
    float2 swv = abs(cos(uv));    
    wv = lerp(wv,swv,wv);
    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
}

	// Lerp between water color and deep water color
	//float3 WaterColor = float3(0, 0.15, 0.115);
	//float3 waterColor = (WaterColor * facing + waterColorA * (1.0 - facing));
*/

    /*
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
	float3 dp1 = ddx(View);
	float3 dp2 = ddy(View);
	float2 duv1 = ddx(UV);
	float2 duv2 = ddy(UV);
	
	float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
	float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
	float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
	float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);
	
	return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}
    // Trying out new spec calc
    float3 eyeVecNorm = normalize(V);
    float3x3 tangentFrame = compute_tangent_frame(input.worldNormal, eyeVecNorm, input.texCoord0);
    float3 N = SampleTexture(normalMap, LinearSampler,  input.texCoord0*tile, float3(0.5, 0.5, 1.0))*2-1;
    float3 newNormal = normalize(mul(2.0f * N - 1.0f, tangentFrame));
	float3 mirrorEye = (2.0 * dot(eyeVecNorm, newNormal) * newNormal - eyeVecNorm);
	float dotSpec = saturate(dot(mirrorEye.xyz, -light0Dir) * 0.5 + 0.5);
	//float4 specular = (1.0 - fresnel) * saturate(-light0Dir.y) * ((pow(dotSpec, 512.0)) * (specIntensity * 1.8 + 0.2));
	//specular += specular * 25 * saturate(specIntensity - 0.05);

float hash( float2 p ) 
{
	float h = dot(p,float2(127.1,311.7));	
    return frac(sin(h)*43758.5453123);
}

float customNoise( float2 p ) 
{
    float2 i = floor( p );
    float2 f = frac( p );	
	float2 u = f*f*(3.0-2.0*f);
    return -1.0+2.0*lerp( lerp( hash( i + float2(0.0,0.0) ),
    							hash( i + float2(1.0,0.0) ), u.x),
        						lerp( hash( i + float2(0.0,1.0) ), 
        						hash( i + float2(1.0,1.0) ), u.x), u.y);
}
	*/