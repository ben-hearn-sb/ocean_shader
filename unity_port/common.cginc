// Header file for dx11 HLSL

#define PI (3.14159265)
#define PHASE (2*PI)

float3 gerstnerWave(float3 position, float multiplier, float2 direction, float amplitude, float waveLength, float crestFactor, float speed, float globalTimer, float outType, float wave, float inAmp)
{
	// Returns either position, binormal, tangent or normal
	float amp = inAmp;
	amp *= 0.25*amplitude;
	//float amp = amplitude*0.025;
	//amp *= multiplier;
	
	//float WL = waveLength;
	float WL = wave*waveLength;
	WL *= multiplier*0.5;

	float2 D = direction;

	float w = 2*PI/WL;
	float Q = crestFactor;
	float3 P0 = position.xyz;
	float myPhase = speed * 2*PI/WL;

	float dotD = dot(D, P0.xz);
	float C = cos(w*dotD + (globalTimer*myPhase));
	float S = sin(w*dotD + (globalTimer*myPhase));

	float dotX = dot(D, P0.x);
	float dotY = dot(D, P0.y);
	float dotP = dot(D, P0);
	float powDotX = dot(D, pow(P0.x, 2));
	float powDotY = dot(D, pow(P0.y, 2));
	float WA = w*amp;

	if(outType == 0)
		float3 P = float3(Q*amp*D.x*C, amp * S, Q*amp*D.y*C);
		return P;
	if(outType == 1)
		float3 B = float3(Q*powDotX*WA*S, dotX*WA*C, Q*dotX*dotY*WA*S);
		return B;
	if(outType == 2)
		float3 T = float3(Q*dotX*dotY*WA*S, dotY*WA*C, Q*powDotY*WA*S);
		return T;
	if(outType == 3)
		float3 N = float3(dotX*WA*C, Q*WA*S, dotY*WA*C);
		return N;
}

float4 color_to_float (float4 col)
{
    return float4(col.r/255.0, col.g/255.0, col.b/255.0, col.a/255.0);
}

float fresnelCalculation(float3 viewVec, float3 worldNorm)
{
	float fresnelBias 	= 0.3;
	float fresnelScale 	= 1;
	float fresnelPower 	= 5;
	return fresnelBias + fresnelScale * pow(1.0 - dot(normalize(viewVec), worldNorm), fresnelPower);
}

float Fresnel(float3 viewVector, float3 worldNormal)
{
	float fresnelBias 	= 0;
	float fresnelScale 	= 1;
	float fresnelPower 	= 5;
	float facing =  clamp(1.0-max(dot(-viewVector, worldNormal), 0.0), 0.0,1.0);	
	float refl2Refr = saturate(fresnelBias+(1.0-fresnelBias) * pow(facing,fresnelPower));	
	return refl2Refr;	
}

float4 generateHeightMask(float4 posWorld)
{
	// Height Map
	float _HeightMin = 0;
	float _HeightMax = 2;
	float h = (_HeightMax-posWorld.y) / (_HeightMax-_HeightMin);
	return lerp(float4(1,1,1,1), float4(0,0,0,1), pow(h, posWorld.y));
}