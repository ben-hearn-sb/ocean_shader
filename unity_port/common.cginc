// Header file for dx11 HLSL

#define PI (3.14159265)
#define PHASE (2*PI)

float3 gerstnerWave(float3 position, float multiplier, float2 direction, float amplitude, float waveLength, float crestFactor, float speed, float globalTimer, float outType)
{
	// Returns either position, binormal, tangent or normal
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