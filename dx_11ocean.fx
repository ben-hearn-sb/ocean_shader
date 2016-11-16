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
//float4 light0Color 		<String uiname="light0Color"; bool color=true;> = { 1.0f,1.0f,1.0f,1.0f };
float4 waterColorA 		<String uiname="Water Color A"; bool color=true;> = { 1.0f,1.0f,1.0f,1.0f };
float tile 				<String uiname="Tile";> = 1.0f;
float specIntensity 	<String uiname="Spec Intensity"; 	float UIMin = 0.0; float UIMax = 10.0; float UIStep = 0.01;> = 0.5;
float timerScale1 		<String uiname="Timer Scale 1"; 	float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.2;
float timerScale2 		<String uiname="Timer Scale 2"; 	float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.2;
//float sun_alfa;
//float sun_theta;
//float sun_shininess;
//float sun_strength;
//float reflrefr_offset;
//bool diffuseSkyRef;
float amplitude = 0.1;	// amplitude
float waveLength = 2.5;	// wavelength
int waveCount = 3;
float speed = 2.1;
float dirX = 1.0;
float dirY = 0.0;

static const float2x2 octave_m = float2x2(1.6,1.2,-1.2,1.1);

Texture2D normalMap;
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
	AddressU = Clamp;
	AddressV = Clamp;
	AddressW = Clamp;    
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
	float3 screenPos 		: TEXCOORD6;
	float2 cubeCoord		: TEXCOORD7;
};

/**************************************/
/***** VERTEX SHADER ******************/
/**************************************/

// original noise and trace functions from https://www.shadertoy.com/view/Ms2SD1

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

float sea_octave(float2 uv, float choppy) 
{
    uv += customNoise(uv);        
    float2 wv = 1.0-abs(sin(uv));
    float2 swv = abs(cos(uv));    
    wv = lerp(wv,swv,wv);
    return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
}

float3 gerstnerWave(float3 position, float multiplier)
{
	float wL = hash(position.xy);
	float w = 2*PI/waveLength;
	float amp = amplitude;

	float Q = 0.5;
	float3 P0 = position.xyz;
	float3 D = float3(0,0,1);
	float dotD = dot(P0.yz, D.z); // Direction
	float C = cos(w*dotD + globalTimer);
	float S = sin(w*dotD + globalTimer);
	float3 P = float3(Q*amp*C*D.x, amp * S,Q*amp*C*D.y);
	return P;
}

float3 waveFunction(float3 position)
{
	float w = 2*PI/waveLength;
	float myPhase = speed * 2*PI/waveLength;
	float2 waveDir = float2(dirX, dirY);
	float dotY = dot(waveDir, position.xz);
	float Y = amplitude * sin(dotY * w + (globalTimer * myPhase));
	return float3(0, Y, 0);
}

vertex2pixel vertexNormalMap(app2vertex In)
{ 
	vertex2pixel Out = (vertex2pixel)0;
	Out.worldNormal = mul(In.normal, WorldInverseTranspose).xyz;	
	Out.worldTangent = mul(In.tangent, WorldInverseTranspose).xyz;	
	Out.worldBinormal = mul(In.binormal, WorldInverseTranspose).xyz;
    float3 worldSpacePos = mul(In.position, World);
    Out.positionW = worldSpacePos;
    Out.texCoord0 = In.texCoord0;
    //Out.texCoord0.xy += (globalTimer*timerScale1);
    //Out.cubeCoord = In.texCoord1;

    //Out.position = mul(In.position, WorldViewProjection);	
	Out.viewVec = ViewInverse[3] - worldSpacePos;

	float3 sum = float3(0,0,0);
	float h = 0.0;
	for(int i=0; i < 3; i++)
	{
		//sum = gerstnerWave(In.position+globalTimer, i);
		//sum = gerstnerWave(In.position+globalTimer, i);
		//sum += gerstnerWave(In.position-globalTimer, i);
		sum += waveFunction(In.position);
	}
	sum += In.position;
	
	//float3 wavePos = gerstnerWave(In.position, 1);
	//float3 wavePos = waveFunction(worldSpacePos);
	//float3 wavePos = amplitude * sin;
	//Out.position = float4(sum,1);
	//Out.position.y = wavePos.z;
	//wavePos.y += sum.y;
	//wavePos.y *= 10;
	Out.position = mul(float4(sum,1), WorldViewProjection);
    return Out; 
}

/**************************************/
/***** PIXEL SHADER *******************/
/**************************************/

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

// SV_TARGET is dx11 style pixel shader
float4 pixel(vertex2pixel input, uniform int debugOutput) : SV_TARGET 
{	
	//Texture sampling
	float3 worldSpacePix = input.positionW;
	float4 color = waterColorA;
	float3x3 toWorld = float3x3(input.worldTangent, input.worldBinormal, input.worldNormal);
	float3 normal = SampleTexture(normalMap, LinearSampler,  input.texCoord0*tile, float3(0.5, 0.5, 1.0))*2-1;
	float3 bumpWorld = normalize(mul(normal,toWorld));
	float3 noise = SampleTexture(noiseMap, LinearSampler, input.texCoord0*tile/2, float3(1.0, 1.0, 1.0));
	//float3 cubeTex = cubeTexture.Sample(CubeMapSampler, input.texCoord0);
	float4 cube_lookup = float4(1 - saturate(dot(bumpWorld, input.viewVec)), reflect(input.viewVec, bumpWorld));
	float4 cubeTex = cubeTexture.Sample(CubeMapSampler, cube_lookup);
	
	// Light calculation
	LightData light0 = CalculateLight(light0Type, light0AttenScale, light0Pos, worldSpacePix,  ToLinear(light0Color), light0Intensity, light0Dir, light0ConeAngle, light0FallOff);
	light0Dir = light0.dir;
	light0Color = light0.color;
	
	// Blinn Phong spec term
	float3 H = normalize(input.viewVec + light0Dir);
	float3 V = input.viewVec;
	float3 R = reflect(-V, input.worldNormal);
	float4 specular = specIntensity * float4(light0Color,0) * pow(dot(bumpWorld, H),256);

	//R.y = max(R.y,0); //New, also normalize above
	float4 skyrefl;
	//skyrefl = cubeTexture.SampleLevel(CubeMapSampler, R, 8);
    skyrefl = cubeTexture.Sample(CubeMapSampler, R + bumpWorld*8.0); // + bumpWorld*5.0 blurs the cubemap into the normalmap

	// Compute Fresnel term
	float NdotL = max(dot(V, R), 0);
	float facing = (1.0 - NdotL);

	// Lerp between water color and deep water color
	float3 WaterColor = float3(0, 0.15, 0.115);
	float3 waterColor = (WaterColor * facing + waterColorA * (1.0 - facing));

	float Rzero = 1.0;
    float4 fresnel = Rzero + (1.0f - Rzero) * pow(abs(1.0f - dot(input.worldNormal, V)), 5.0 );    
    //float4 result =  color +  lerp(float4(waterColor,1), skyrefl, fresnel) ;
    //float4 result =  color +  lerp(color, skyrefl, fresnel) ;
    //result.a = 1;

    /*
    // Trying out new spec calc
    float3 eyeVecNorm = normalize(V);
    float3x3 tangentFrame = compute_tangent_frame(input.worldNormal, eyeVecNorm, input.texCoord0);
    float3 N = SampleTexture(normalMap, LinearSampler,  input.texCoord0*tile, float3(0.5, 0.5, 1.0))*2-1;
    float3 newNormal = normalize(mul(2.0f * N - 1.0f, tangentFrame));
	float3 mirrorEye = (2.0 * dot(eyeVecNorm, newNormal) * newNormal - eyeVecNorm);
	float dotSpec = saturate(dot(mirrorEye.xyz, -light0Dir) * 0.5 + 0.5);
	//float4 specular = (1.0 - fresnel) * saturate(-light0Dir.y) * ((pow(dotSpec, 512.0)) * (specIntensity * 1.8 + 0.2));
	//specular += specular * 25 * saturate(specIntensity - 0.05);
	*/

	color.rgb = color.rgb * light0Intensity * light0Color;
	float diffLight = saturate(dot(bumpWorld, light0Dir));

	//float4 waterColorB = lerp(skyrefl, cubeTex, 0.6f);

	color *= diffLight;
	float4 result =  color +  lerp(color, skyrefl, fresnel);
	//color.rgb *= noise;
	//color = lerp(waterColor, color, fresnel.r);
	//color.rgb += waterColor;
	//return color;
	//return fresnel + color;
	return saturate(color * result + specular);
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
		SetPixelShader(CompileShader(ps_5_0, pixel(0)));
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
*/